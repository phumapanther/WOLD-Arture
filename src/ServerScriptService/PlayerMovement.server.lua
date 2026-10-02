-- PlayerMovement.server.lua: server-authoritative walk/normal/run state machine driven by client intent, tied
-- to stamina. Replaces PlayerSpeed.server.lua's flat WalkSpeed. Runs in every server (lobby included — no
-- DataStore/position concerns here, unlike PlayerProfile.server.lua). See
-- docs/superpowers/specs/2026-09-07-movement-stamina-design.md for the full state machine.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ServerConfig = require(game.ServerScriptService.ServerConfig)
local Vitals = require(game.ServerScriptService.Vitals)
local Inventory = require(game.ServerScriptService.Inventory)
local StatusEffects = require(game.ServerScriptService.StatusEffects)
local Remotes = require(game.ReplicatedStorage.Remotes)
local PlayerJoin = require(game.ServerScriptService.PlayerJoin)

-- Stamina VALUES now live in Vitals.lua (swimming spends it too, and drowning depends on it), and the HUD gets
-- them through VitalsUpdate. This file still owns the walk/normal/run state machine that spends it, and reads
-- the value back through Vitals.GetStamina. The lobby has no vitals at all, so the machine idles there.
local ACTIVE = not ServerConfig.IsLobby

-- วิ่งเร็วขึ้น 50% ตามที่ผู้ใช้สั่ง (16 -> 24) เดินกับปกติคงเดิม
local SPEED = { Normal = 8, Walk = 4, Run = 24 }
-- ฟาร์มออโต้เดินระหว่างจุดด้วยความเร็วเกือบวิ่ง (ผู้ใช้สั่ง 2026-10-01) ไม่กินสตามินา · กด Shift ยังวิ่งเต็มได้
-- ไคลเอนต์บอกผ่าน `SetAutoFarming` (ฟาร์มออโต้อยู่ฝั่งไคลเอนต์) · โกงได้สุดแค่ 20 ซึ่งช้ากว่าวิ่งปกติอยู่แล้ว · สนามไม่รับ
-- เดินอัตโนมัติตามหมุด (T / ปุ่มบนจอ) ใช้ความเร็วเดียวกัน (ผู้ใช้สั่ง 2026-10-02) · ธงแยก `autoWalk` ผ่าน `SetAutoWalking`
-- ไม่ใช้ธงเดียวกับฟาร์มออโต้ ไม่งั้นหยุดอย่างหนึ่งแล้วอีกอย่างช้าลงด้วย
local AUTO_FARM_SPEED = 20
local STAMINA_DRAIN_PER_SEC = 20 -- empties in ~5s from full
-- ฟื้นเร็วขึ้น 50% (33.3 -> 50 ต่อวินาที) เต็มบาร์ใน ~2 วิ จากเดิม ~3 วิ
local STAMINA_REGEN_PER_SEC = 50
local FORCED_WALK_SECONDS = 2

-- **สนาม PVP เท่านั้น: เดินถอยหลังช้าลง** (ผู้ใช้สั่ง 2026-09-25 — ห้ามกระทบโหมดอื่น)
-- ในสนามกล้องล็อกมุมบุคคลที่หนึ่ง ตัวละครหันตามกล้องเสมอ "ทิศที่เดินสวนกับทิศที่ตัวหัน" จึงเท่ากับ
-- "เดินสวนกับจอ" · เดินข้าง (dot ≈ 0) ไม่โดน · ถอยเฉียงหลังโดน · ค่าผมตั้ง ปรับได้สองตัวนี้
-- 2026-09-25 รอบสอง (ผู้ใช้สั่ง): **ถอยหลังวิ่งไม่ได้** (ความเร็วฐานถูกกดไว้ที่เดินปกติ ไม่กินสตามินา) และ
-- **ช้าลงอีก 25%** จากเดิม 0.6 → 0.6 × 0.75 = 0.45 ของความเร็วเดินปกติ
local BACKWARD_FACTOR = 0.45

local States = {} -- [player] = { state, sprintIntent, forcedWalkUntil }

local function humanoidOf(player)
	local character = player.Character
	return character and character:FindFirstChildOfClass("Humanoid")
end

-- เดินสวนทิศที่ตัวหันอยู่ไหม (สนามเท่านั้น) · **ไคลเอนต์บอกมา** (`SetBackpedal` · MovementController 2026-10-01)
-- เดิมคิดที่นี่จาก MoveDirection กับทิศตัว ซึ่งมาถึงเซิร์ฟคนละจังหวะ เดินข้างพลางหมุนกล้อง = ค่าแกว่งข้ามเส้น
-- ความเร็วสลับเร็ว↔ช้าทุกเฟรม (เดินกระตุก) · โกงได้แค่ถอยหลังเร็วเท่าเดินหน้า (ไคลเอนต์คุมฟิสิกส์ตัวเองอยู่แล้ว)
local function backpedaling(state)
	return ServerConfig.IsArena and state.backpedal == true
end

-- Applies the current state's speed, scaled by how overloaded the player is. Called on state changes AND
-- every tick, because carry weight changes while the state does not: picking up loot mid-walk has to slow the
-- player without waiting for the next walk/run transition.
local function applySpeed(state, player)
	local humanoid = humanoidOf(player)
	-- Vitals owns WalkSpeed while downed (crawling pace); don't fight it.
	if not humanoid or Vitals.IsDowned(player) then return end
	local base = SPEED[state.state == "ForcedWalk" and "Walk" or state.state]
	-- โหมดเดิน (แตะ Shift ตอนยืน) ก็ถูกทับด้วย — ออโต้ต้องเร็วเท่ากันทุกครั้ง (ผู้ใช้สั่ง 2026-10-02) · หมดแรง (ForcedWalk) ยังช้าตามเดิม
	if (state.autoFarm or state.autoWalk) and (state.state == "Normal" or state.state == "Walk") then base = AUTO_FARM_SPEED end
	local backward = backpedaling(state)
	if backward then base = math.min(base, SPEED.Normal) end -- ถอยหลังวิ่งไม่ได้
	-- Carry weight and any slow effect both scale the same base speed, so neither has to know about the other.
	local wanted = base * Inventory.SpeedMultiplier(player) * StatusEffects.SpeedMultiplier(player)
	-- อุ้มหมา/แมวอยู่ = เดินช้าเท่าโหมดเดิน วิ่งไม่ได้ (ผู้ใช้สั่ง 2026-09-25) · IslandPets ตั้งแอตทริบิวต์บนตัว Player
	-- ponytail: กด Shift ค้างระหว่างอุ้มยังกินสตามินาเหมือนวิ่ง (ความเร็วถูกกดไว้) — ตัดการวิ่งทิ้งถ้าเป็นปัญหา
	if player:GetAttribute("WOLD_CarryingPet") then wanted = math.min(wanted, SPEED.Walk) end
	-- ยกการ์ดอยู่ (สนาม · Blocking) = เดินช้าเท่าโหมดเดิน วิ่งไม่ได้
	if player:GetAttribute("WOLD_Blocking") then wanted = math.min(wanted, SPEED.Walk) end
	if backward then wanted *= BACKWARD_FACTOR end
	-- "กำลังวิ่ง" เป็นแอตทริบิวต์บนตัว Player (สไลด์เริ่มได้จากการวิ่งเท่านั้น) — ไคลเอนต์ใช้เปลี่ยนปุ่มกลิ้งเป็นสไลด์
	-- และ PlayerActions ใช้ตัดสิน · ของเดิมเดาจาก WalkSpeed >= 12 ซึ่งพังเมื่อกระเป๋าหนัก/โดนสโลว์จนวิ่งได้ไม่ถึง 12
	local sprinting = state.state == "Run" and not backward
	if player:GetAttribute("WOLD_Sprinting") ~= sprinting then player:SetAttribute("WOLD_Sprinting", sprinting) end
	-- Only write when it actually differs: WalkSpeed replicates, so setting it every frame is wasteful.
	if math.abs(humanoid.WalkSpeed - wanted) > 0.01 then
		humanoid.WalkSpeed = wanted
	end
end

local function setState(state, player, newState)
	if state.state == newState then return end
	state.state = newState
	-- หยดน้ำบนหัวตอนวิ่งจนหมดแรง ตามที่ผู้ใช้สั่ง
	--
	-- ผูกกับ ForcedWalk ซึ่งเป็นสถานะ "สตามินาหมดจนต้องเดิน" อยู่แล้ว ไม่ได้ผูกกับตัวเลขสตามินาตรงๆ เพราะ
	-- แบบนั้นสัญลักษณ์จะกระพริบทุกครั้งที่บาร์แตะศูนย์แล้วฟื้นขึ้นมาทันที
	StatusEffects.SetTired(player, newState == "ForcedWalk")
	applySpeed(state, player)
end

PlayerJoin.Each(function(player)
	local state = { state = "Normal", sprintIntent = false, forcedWalkUntil = 0 }
	States[player] = state

	player.CharacterAdded:Connect(function()
		state.autoWalk = false -- ตัวใหม่ไม่ได้เดินอัตโนมัติอยู่ (ไคลเอนต์ก็หยุดเองตอนเกิดใหม่ · กันธงค้างถ้าข้อความหาย)
		-- WalkSpeed doesn't persist across respawns, and setState would no-op (the state name is unchanged),
		-- so re-apply it directly. Deferred so the new humanoid exists before we write to it.
		task.defer(applySpeed, state, player)
	end)
end)

Players.PlayerRemoving:Connect(function(player)
	States[player] = nil
end)

Remotes.SetSprintIntent.OnServerEvent:Connect(function(player, intent)
	local state = States[player]
	if not state or type(intent) ~= "boolean" then return end
	if Vitals.IsDowned(player) then return end -- no sprinting while crawling
	state.sprintIntent = intent
	if intent and state.state ~= "ForcedWalk" and Vitals.GetStamina(player) > 0 then
		setState(state, player, "Run")
	elseif not intent and state.state == "Run" then
		setState(state, player, "Normal")
	end
end)

Remotes.SetBackpedal.OnServerEvent:Connect(function(player, on)
	local state = States[player]
	if state then state.backpedal = on == true end
end)

Remotes.SetAutoFarming.OnServerEvent:Connect(function(player, on)
	local state = States[player]
	if state and not ServerConfig.IsArena then state.autoFarm = on == true end
end)

Remotes.SetAutoWalking.OnServerEvent:Connect(function(player, on)
	local state = States[player]
	if state and not ServerConfig.IsArena then state.autoWalk = on == true end
end)

Remotes.ToggleWalk.OnServerEvent:Connect(function(player)
	local state = States[player]
	local humanoid = humanoidOf(player)
	if not state or not humanoid then return end
	if Vitals.IsDowned(player) then return end -- the walk toggle is meaningless while crawling
	if humanoid.MoveDirection.Magnitude > 0 then return end -- server re-verifies "standing still", doesn't trust the client
	if state.state == "Normal" then
		setState(state, player, "Walk")
	end
end)

if ACTIVE then
	RunService.Heartbeat:Connect(function(dt)
		for player, state in pairs(States) do
			local humanoid = humanoidOf(player)
			local swimming = humanoid and humanoid:GetState() == Enum.HumanoidStateType.Swimming

			-- While downed or swimming, Vitals owns stamina entirely: it drains for swimming and must not
			-- regenerate here, or drowning could never start.
			if Vitals.IsDowned(player) or swimming then
				if state.state ~= "Normal" then setState(state, player, "Normal") end
			-- ถอยหลังในสนาม = ไม่ได้วิ่งจริง (ความเร็วถูกกด) จึงไม่กินสตามินา ตกไปฟื้นแทน
			elseif state.state == "Run" and not backpedaling(state) then
				local stamina = Vitals.GetStamina(player) - STAMINA_DRAIN_PER_SEC * dt
				Vitals.SetStamina(player, stamina)
				if stamina <= 0 then
					state.forcedWalkUntil = os.clock() + FORCED_WALK_SECONDS
					setState(state, player, "ForcedWalk")
				end
			else
				Vitals.SetStamina(player, Vitals.GetStamina(player) + STAMINA_REGEN_PER_SEC * dt)
			end

			if state.state == "ForcedWalk" and os.clock() >= state.forcedWalkUntil then
				setState(state, player, (state.sprintIntent and Vitals.GetStamina(player) > 0) and "Run" or "Normal")
			end

			applySpeed(state, player) -- carry weight can change without the state changing
			
		end
	end)
end
