-- ArenaBots.lua: หุ่นที่มาเติมทีมเมื่อหาคนไม่ครบหกคน (ผู้ใช้กำหนด: ครบ 3 นาทีแล้วเติมบอท)
--
-- **บอทถูกตีด้วยทางเดียวกับมอนในเกมหลัก** — `PlayerCombat` ยิง/ฟันใส่โมเดลที่ติดแท็ก `WOLD_Mob`
-- แล้วเรียก `MobAccess.Damage` ซึ่งไฟล์นี้เป็นคนตั้งในเซิร์ฟแมตช์ · ผลคือ **ไม่ต้องแตะระบบต่อสู้เลย**
-- ดาบ ธนู ปืน สกิล Q และเสียงลงเป้า ทำงานกับบอทเหมือนทำกับมอนทุกประการตั้งแต่บรรทัดแรก
--
-- ⚠️ แท็ก `WOLD_Mob` ในเซิร์ฟแมตช์ **ไม่มีใครอื่นอ่าน** เพราะ `Mobs.server` ไม่ได้ถูกส่งมาเพลสนี้
-- (ดู `arena.project.json`) — ถ้าวันหนึ่งมีระบบใหม่ในสนามที่อ่านแท็กนี้ ต้องรู้ว่ามันจะเจอบอทด้วย
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")

local ArenaConfig = require(game.ReplicatedStorage.ArenaConfig)
local MobAccess = require(game.ServerScriptService.MobAccess)
local Vitals = require(game.ServerScriptService.Vitals)

local ArenaBots = {}

local CFG = ArenaConfig.Bots

-- ร่างต้นแบบที่ `mapgen/100_arena_maps.lua` อบไว้ในเพลส ถ้ามี — ไม่มีก็ปั้นจาก HumanoidDescription เปล่า
-- ซึ่งได้ R15 ที่เดินได้จริง (แต่ไม่มีสคริปต์ Animate ของ Roblox จึงไม่มีท่าเดิน ดูหมายเหตุใน `spawn`)
local PROTOTYPE_FOLDER = "WOLD_ArenaBots"

local Live = {} -- [model] = state
local hooks = {} -- ตั้งโดย ArenaMatch: onHit(botModel, attackerPlayer, amount) · onDied(botModel, killerPlayer)

--------------------------------------------------------------------------------
local function prototype()
	local folder = game:GetService("ServerStorage"):FindFirstChild(PROTOTYPE_FOLDER)
	if not folder then return nil end
	local kids = folder:GetChildren()
	if #kids == 0 then return nil end
	return kids[math.random(#kids)]
end

local function buildRig()
	local proto = prototype()
	if proto then return proto:Clone() end

	-- ทางสำรอง: ร่าง R15 เปล่าจาก Roblox เอง · ใช้ได้ทันทีโดยไม่ต้องรอ mapgen ซึ่งสำคัญมากตอนเทสรอบแรก
	-- (แมตช์ที่เริ่มไม่ได้เพราะยังไม่ได้อบโมเดล = เทสอะไรไม่ได้เลยสักอย่าง)
	local ok, model = pcall(function()
		local description = Instance.new("HumanoidDescription")
		return Players:CreateHumanoidModelFromDescription(description, Enum.HumanoidRigType.R15)
	end)
	if ok and model then return model end
	return nil
end

--------------------------------------------------------------------------------
-- เป้าหมาย
--------------------------------------------------------------------------------
-- บอทเล็งคนที่ **ใกล้ที่สุดในฝั่งตรงข้าม** ไม่ใช่คนที่ตีมันล่าสุด — สนามปิดขนาดนี้ การไล่ตามคนที่
-- วิ่งหนีข้ามแมพไปแล้วแปลว่าบอทจะเดินผ่านศัตรูที่ยืนอยู่ตรงหน้าโดยไม่สนใจ
local function nearestEnemy(state)
	local origin = state.root.Position
	local best, bestDist = nil, CFG.sight

	for _, player in ipairs(Players:GetPlayers()) do
		local side = hooks.sideOfPlayer and hooks.sideOfPlayer(player)
		if side and side ~= state.side and not Vitals.IsDowned(player) then
			local character = player.Character
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			local root = character and character:FindFirstChild("HumanoidRootPart")
			if humanoid and humanoid.Health > 0 and root then
				local d = (root.Position - origin).Magnitude
				if d < bestDist then best, bestDist = root, d end
			end
		end
	end

	for model, other in pairs(Live) do
		if other.side ~= state.side and other.alive and model ~= state.model then
			local d = (other.root.Position - origin).Magnitude
			if d < bestDist then best, bestDist = other.root, d end
		end
	end
	return best, bestDist
end

--------------------------------------------------------------------------------
-- ตีคน
--------------------------------------------------------------------------------
local function swingAt(state, targetRoot)
	local now = os.clock()
	if now < state.nextSwing then return end
	state.nextSwing = now + CFG.attackSeconds

	-- หาว่าปลายทางเป็นผู้เล่นหรือบอทอีกตัว แล้วใช้ทางทำดาเมจของฝั่งนั้น
	local character = targetRoot.Parent
	local player = character and Players:GetPlayerFromCharacter(character)
	if player then
		if Vitals.ApplyDamage(player, CFG.damage, "combat") and hooks.onBotHitPlayer then
			hooks.onBotHitPlayer(state.model, player, CFG.damage)
		end
		return
	end
	local other = character and Live[character]
	if other and other.alive then
		ArenaBots.Damage(other.model, CFG.damage, nil)
	end
end

--------------------------------------------------------------------------------
-- สมอง (หนึ่งเธรดต่อหนึ่งตัว)
--------------------------------------------------------------------------------
local function think(state)
	while state.alive and state.model.Parent do
		task.wait(0.35)
		if not state.free then
			-- ช่วงซื้อของ: ยืนนิ่งอยู่ในฐานเหมือนคนอื่น
			state.humanoid:Move(Vector3.zero)
		else
			local targetRoot, distance = nearestEnemy(state)
			if targetRoot then
				state.humanoid:MoveTo(targetRoot.Position)
				-- หันหน้าเข้าหาเป้าเสมอ ไม่งั้นบอทที่เดินเฉียดจะฟันไปทางที่มันเดิน ไม่ใช่ทางที่ศัตรูอยู่
				local look = Vector3.new(targetRoot.Position.X, state.root.Position.Y, targetRoot.Position.Z)
				if (look - state.root.Position).Magnitude > 0.5 then
					state.root.CFrame = CFrame.lookAt(state.root.Position, look)
				end
				if distance <= CFG.reach then swingAt(state, targetRoot) end
			elseif state.home then
				-- ไม่เห็นใคร: เดินไปกลางแมพ ซึ่งเป็นที่ที่การปะทะเกิดขึ้น — บอทที่ยืนเฝ้าฐานคือรอบที่ไม่มีวันจบ
				state.humanoid:MoveTo(state.home)
			end
		end
	end
end

--------------------------------------------------------------------------------
-- ทางที่ระบบต่อสู้ใช้ตีบอท
--------------------------------------------------------------------------------
-- คืน true เมื่อโมเดลนี้เป็นบอทที่ยังมีชีวิตจริงๆ — `PlayerCombat` ใช้ค่านี้ตัดสินว่าจะเล่นเสียงลงเป้าไหม
function ArenaBots.Damage(model, amount, attacker)
	local state = Live[model]
	if not state or not state.alive or amount <= 0 then return false end

	state.hp = math.max(0, state.hp - amount)
	state.humanoid.Health = state.hp
	if attacker and hooks.onPlayerHitBot then
		hooks.onPlayerHitBot(attacker, model, amount)
	end
	if state.hp <= 0 then
		ArenaBots.Kill(model, attacker)
	end
	return true
end

function ArenaBots.Stun(model, seconds)
	local state = Live[model]
	if not state or not state.alive then return end
	state.free = false
	task.delay(seconds, function()
		if state.alive then state.free = true end
	end)
end

function ArenaBots.Kill(model, killer)
	local state = Live[model]
	if not state or not state.alive then return end
	state.alive = false
	state.humanoid.Health = 0
	if hooks.onDied then hooks.onDied(model, killer) end
	-- ทิ้งร่างไว้ให้เห็นสักครู่แล้วเก็บ — ศพที่หายทันทีทำให้ไม่มีใครรู้ว่าเพิ่งเกิดอะไรขึ้นตรงนั้น
	task.delay(3, function()
		if model.Parent then model:Destroy() end
	end)
end

--------------------------------------------------------------------------------
-- วงจรชีวิต
--------------------------------------------------------------------------------
-- `hookTable` ต้องมี: sideOfPlayer(player) · onPlayerHitBot(player, model, amount)
--                    · onBotHitPlayer(model, player, amount) · onDied(model, killer)
function ArenaBots.Bind(hookTable)
	hooks = hookTable
	MobAccess.Damage = ArenaBots.Damage
	MobAccess.Stun = ArenaBots.Stun
end

function ArenaBots.Spawn(side, name, cframe, home)
	local model = buildRig()
	if not model then
		warn("[ArenaBots] ปั้นร่างบอทไม่ได้ — ทีม", side, "จะขาดคน")
		return nil
	end

	model.Name = name
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local root = model:FindFirstChild("HumanoidRootPart")
	if not humanoid or not root then
		model:Destroy()
		warn("[ArenaBots] ร่างที่ได้ไม่มี Humanoid/HumanoidRootPart")
		return nil
	end

	humanoid.MaxHealth = CFG.hp
	humanoid.Health = CFG.hp
	humanoid.WalkSpeed = CFG.walkSpeed
	humanoid.DisplayName = name
	-- ป้ายชื่อมองเห็นได้ไกลเท่าที่สนามกว้าง: คนต้องแยกออกว่าคนที่วิ่งมาคือบอทหรือเพื่อนร่วมทีม
	humanoid.NameDisplayDistance = 250
	humanoid.HealthDisplayDistance = 250
	humanoid.BreakJointsOnDeath = false

	model.Parent = workspace
	model:PivotTo(cframe)
	CollectionService:AddTag(model, "WOLD_Mob") -- ทางที่ระบบต่อสู้ใช้หาเป้าที่ไม่ใช่ผู้เล่น
	model:SetAttribute("ArenaSide", side)

	local state = {
		model = model, humanoid = humanoid, root = root,
		side = side, hp = CFG.hp, alive = true, free = false,
		home = home, nextSwing = 0,
	}
	Live[model] = state
	task.spawn(think, state)
	return model
end

-- เปิด/ปิดขาทั้งสนามพร้อมกันตอนเริ่ม/จบรอบ
function ArenaBots.SetFree(free)
	for _, state in pairs(Live) do
		state.free = free and true or false
	end
end

function ArenaBots.AliveCount(side)
	local n = 0
	for _, state in pairs(Live) do
		if state.alive and state.side == side then n += 1 end
	end
	return n
end

function ArenaBots.All()
	local list = {}
	for model, state in pairs(Live) do
		list[#list + 1] = { model = model, side = state.side, alive = state.alive, name = model.Name }
	end
	return list
end

function ArenaBots.Clear()
	for model, state in pairs(Live) do
		state.alive = false
		if model.Parent then model:Destroy() end
	end
	Live = {}
end

return ArenaBots
