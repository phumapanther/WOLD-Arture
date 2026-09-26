-- GatherController: what a gathering node looks like to THIS player, and the auto-farm that walks between
-- nodes on its own.
--
-- Three jobs, all of them presentation or convenience -- the server decides every actual gather:
--   1. Hide prompts this player cannot use. A ProximityPrompt is one object shared by the whole server, so
--      it cannot be shown to one person and hidden from another; deciding it here on the client is the only
--      way to make "the prompt appears when you hold the right tool" true per player.
--   2. Play a swing while a hold is running.
--   3. F toggles auto-farm: walk to the nearest node of the kind the held tool works on, gather it, then
--      the next one. If someone takes the target first, retarget without stopping.
--
-- Nothing here is trusted. A player who blocked this script would still gather by walking up and pressing
-- E, and could not gather anything the server would have refused.
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local ProximityPromptService = game:GetService("ProximityPromptService")
local UserInputService = game:GetService("UserInputService")
local PathfindingService = game:GetService("PathfindingService")

while workspace:GetAttribute("IsLobby") == nil do
	task.wait()
end
if workspace:GetAttribute("IsLobby") then return end
-- ในสนาม PVP ไม่มีจุดเก็บเกี่ยวสักจุด และ **ปุ่ม F ที่นั่นเป็นของ "ใช้ยา"** — ปล่อยให้สคริปต์นี้
-- จองปุ่มไว้ จะกลายเป็นยาที่กดแล้วไม่กิน
if workspace:GetAttribute("ArenaMode") == true then return end

local ItemCatalog = require(game.ReplicatedStorage.ItemCatalog)
local GatherConfig = require(game.ReplicatedStorage.GatherConfig)
local Remotes = require(game.ReplicatedStorage.Remotes)

local player = Players.LocalPlayer

local TAG = "WOLD_Node"
-- How close the auto-farm has to get before it stops walking and starts the hold. Comfortably inside the
-- prompt's own range, so a step of drift between frames does not put it out of reach.
local ARRIVE_DISTANCE = 7
-- Give up on a node the pathfinder cannot reach, rather than standing there forever.
local WALK_TIMEOUT = 12

--------------------------------------------------------------------------------
-- Which tool is in hand
--------------------------------------------------------------------------------

-- The `gathers` value of the equipped weapon ("axe", "pickaxe", "shovel"), or nil for anything else.
-- Weapons here are Motor6D models rather than Tool instances, so this comes from the server's own
-- EquipmentChanged rather than from watching the character for a Tool child.
local heldTool = nil
-- อะไรก็ตามที่ถืออยู่ (ดาบก็นับ) — ฟาร์มออโต้กับสัตว์ต้อง **มือเปล่าจริงๆ** ไม่ใช่แค่ไม่ถือเครื่องมือ
local heldWeapon = nil

local function setEquipped(weaponId)
	local item = weaponId and ItemCatalog.Get(weaponId)
	heldTool = item and item.gathers or nil
	heldWeapon = weaponId
end

-- ฟาร์มออโต้เล็งจุดนี้ไหม (ผู้ใช้กำหนด): ถือเครื่องมือ = เฉพาะจุดของเครื่องมือนั้น · มือเปล่า = เฉพาะสัตว์ฟาร์ม
-- ถือดาบ = ไม่เล็งอะไรเลย — ต่างจากปุ่ม E ที่จุดไม่ต้องใช้เครื่องมือกดได้เสมอ
local function autoTarget(node)
	if heldTool then return node:GetAttribute("RequiredTool") == heldTool end
	if heldWeapon then return false end
	return node:GetAttribute("HerdAnimal") == true
end

Remotes.EquipmentChanged.OnClientEvent:Connect(function(who, weaponId)
	if who ~= player then return end
	setEquipped(weaponId)
end)
-- ⚠️ ตอนเข้าเซิร์ฟพร้อมถือเครื่องมือ EquipmentChanged ไม่ยิงเลย (โหลดกระเป๋าไม่ใช่ "การเปลี่ยน") → เดิม heldTool ว่าง
-- ปุ่ม E ไม่ขึ้นจนถอดใส่ใหม่ (ผู้ใช้แจ้ง 2026-09-26) · แอตทริบิวต์ `WOLD_Weapon` ที่ Inventory.Send ตั้งคือสถานะที่ค้างอยู่
-- อ่านได้ทุกเมื่อ ไม่มีจังหวะให้พลาด · refreshPrompts ถูกประกาศข้างล่าง จึงเรียกผ่านการ defer ตอนสัญญาณมา
local function syncHeldFromAttribute()
	setEquipped(player:GetAttribute("WOLD_Weapon"))
end
syncHeldFromAttribute()
player:GetAttributeChangedSignal("WOLD_Weapon"):Connect(syncHeldFromAttribute)

--------------------------------------------------------------------------------
-- Hiding prompts this player cannot use
--------------------------------------------------------------------------------

-- A node's own RequiredTool attribute, published by the server. Read from the node rather than looked up in
-- GatherConfig so a renamed node kind carries its own answer.
local function requiredToolOf(node)
	return node:GetAttribute("RequiredTool")
end

-- True while somebody is carrying this player. Tracked from CarryStateChanged, which the server already
-- broadcasts as (carrier, event, target) for every carry that starts and ends.
local beingCarried = false

local function canUse(node)
	-- A passenger gets no prompts at all. Someone slung over another player's shoulder is not chopping a
	-- tree, and offering them the button is offering something the server would refuse anyway -- worse, the
	-- auto-farm one would start walking a character who is not driving.
	if beingCarried then return false end
	local needed = requiredToolOf(node)
	if not needed then return true end -- a node anyone can gather
	return heldTool == needed
end

-- The server owns Enabled for the SPENT state; this only ever hides a prompt further, never re-enables one
-- the server switched off. `spentPrompts` remembers which those are.
local function refreshNode(node)
	-- BOTH prompts -- the [E] gather and the [F] auto-farm. Taking only the first would have left the
	-- F prompt showing on nodes this player cannot use.
	if node:GetAttribute("Spent") == true then return end
	local usable = canUse(node)
	for _, d in ipairs(node:GetDescendants()) do
		if d:IsA("ProximityPrompt") and GatherConfig.OwnPrompts[d.Name] then
			-- ปุ่ม F ขึ้นเฉพาะจุดที่ออโต้จะเล็งจริง ไม่งั้นกดแล้วมันเดินไปที่อื่น
			local want = usable and (d.Name ~= "AutoFarmPrompt" or autoTarget(node))
			if d.Enabled ~= want then d.Enabled = want end
		end
	end
end

-- ⚠️ **เฉพาะจุดที่อยู่ใกล้ตัว** (QA 2026-09-26 มือถือหน่วง) — เดิมไล่ทุกจุดที่โหลดมา (แมพหลักมีต้นไม้/หิน/พุ่ม ~25,000)
-- เปิด GetDescendants ทุกตัวทุกวินาที และทุกจุดที่สตรีมเข้ามาตอนเดินสั่งไล่ใหม่ทั้งหมดอีกรอบ · ปุ่มขึ้นแค่ในระยะ ~10 สตัด
-- จุดไกลกว่า REFRESH_RADIUS จึงไม่ต้องแตะ (เดิน 16 สตัด/วิ ลูปวินาทีละรอบ = ถูกจัดก่อนเดินถึงเสมอ)
-- ponytail: ยังวนรายชื่อทั้งหมดเพื่อวัดระยะ (ถูก) ถ้าวันไหนจุดเป็นแสน ค่อยแบ่งกริดพื้นที่
local REFRESH_RADIUS = 80
local function refreshPrompts()
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then return end
	local here = root.Position
	for _, node in ipairs(CollectionService:GetTagged(TAG)) do
		local pos = node:IsA("BasePart") and node.Position or (node:IsA("Model") and node:GetPivot().Position)
		if pos and (pos - here).Magnitude <= REFRESH_RADIUS then refreshNode(node) end
	end
end

-- Connected here rather than beside the flag it sets, because it has to call refreshPrompts and a Lua local
-- declared further down the file is a different name to anything above it.
Remotes.CarryStateChanged.OnClientEvent:Connect(function(_carrier, event, target)
	if target ~= player then return end
	if event == "carry_start" then
		beingCarried = true
	elseif event == "carry_end" then
		beingCarried = false
	else
		return
	end
	refreshPrompts()
end)

-- Re-evaluated when the held tool changes, and when nodes appear.
Remotes.EquipmentChanged.OnClientEvent:Connect(function(who)
	if who == player then
		task.defer(refreshPrompts)
	end
end)
-- จุดที่เพิ่งสตรีมเข้ามา: จัดแค่ตัวนั้น (เดิมสั่งไล่ใหม่ทั้งแมพต่อหนึ่งจุด = เดินเข้าป่าแล้วกระตุก)
CollectionService:GetInstanceAddedSignal(TAG):Connect(function(node)
	task.defer(refreshNode, node)
end)

--------------------------------------------------------------------------------
-- The swing
--------------------------------------------------------------------------------

-- ท่าแยกตามชนิดวัตถุดิบ (GatherConfig.Animations: สัตว์/หิน/ไม้/พุ่ม) ชนิดที่ยังไม่มี id ใช้ Sword_Slash
-- แทน — ฟันลงสองมือ ซึ่งพอดูเป็นตัดไม้/ขุดได้ ระบบจึงทำงานเหมือนเดิมจนกว่าจะ publish ท่าจริง
local SWING_ID = "rbxassetid://138133285610075"

local tracks = {} -- [animationId] = AnimationTrack ของตัวละครปัจจุบัน
local track -- ท่าที่กำลังเล่นอยู่

local function trackFor(id)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
	if not animator then return nil end
	local cached = tracks[id]
	if cached and cached.Parent == animator then return cached end
	local animation = Instance.new("Animation")
	animation.AnimationId = id
	local ok, loaded = pcall(function() return animator:LoadAnimation(animation) end)
	if not ok then return nil end
	loaded.Looped = true
	-- ท่าฟันดาบสำรองถูกชะลอให้ดูเหมือนทำงาน ท่าที่ทำมาเฉพาะเล่นตามจังหวะของมันเอง
	if id == SWING_ID then loaded:AdjustSpeed(0.7) end
	tracks[id] = loaded
	return loaded
end

local function isGatherPrompt(prompt)
	return prompt.Name == "GatherPrompt"
end

-- จุดที่ปุ่มนี้แขวนอยู่ (ปุ่มอยู่ใน GatherAnchor ซึ่งอยู่ในโมเดลจุด หรืออยู่บนชิ้นส่วนตรงๆ ถ้าจุดเป็น Part)
local function nodeOfPrompt(prompt)
	local holder = prompt.Parent
	if not holder then return nil end
	if holder.Name == "GatherAnchor" then return holder.Parent end
	if CollectionService:HasTag(holder, TAG) then return holder end
	return holder.Parent
end

ProximityPromptService.PromptButtonHoldBegan:Connect(function(prompt, who)
	if who ~= player or not isGatherPrompt(prompt) then return end
	local node = nodeOfPrompt(prompt)
	local kind = node and node:GetAttribute("NodeKind")
	local id = (kind and GatherConfig.AnimationFor(kind)) or SWING_ID
	if track and track.IsPlaying then track:Stop(0.1) end
	track = trackFor(id)
	if track then track:Play(0.15) end
end)

local function stopSwing(prompt, who)
	if who ~= player or not isGatherPrompt(prompt) then return end
	if track and track.IsPlaying then track:Stop(0.2) end
end

ProximityPromptService.PromptButtonHoldEnded:Connect(stopSwing)
ProximityPromptService.PromptTriggered:Connect(stopSwing)

--------------------------------------------------------------------------------
-- Auto-farm
--------------------------------------------------------------------------------

local autoFarming = false
local autoThread = nil

-- On-screen state. The first version reported everything through print(), which no player ever sees -- so
-- auto-farm looked broken whether it was running or not.
local banner
-- แถบสถานะเป็น **ปุ่ม** ไม่ใช่ป้าย เพราะบนมือถือไม่มีคีย์ F ให้กดหยุด
--
-- ทางหยุดที่มีอยู่เดิมทั้งหมดต้องใช้คีย์บอร์ด หรือไม่ก็เป็นทางอ้อม (เดินกลับไปแตะปุ่มที่ต้นไม้ · ถอด
-- เครื่องมือ · ตาย) — คนเล่นมือถือเปิดออโต้แล้วหยุดไม่ได้จริงๆ (ผู้ใช้ถาม 2026-09-19)
--
-- ปุ่มหยุดอยู่บนแถบที่ขึ้นมาอยู่แล้วตอนออโต้ทำงาน ไม่ต้องเพิ่มปุ่มถาวรใน `TouchActionGui`: มันโผล่มาเฉพาะ
-- ตอนที่มีอะไรให้หยุด และอยู่ตรงที่ตาจ้องอยู่แล้วพอดี
local bannerTap -- ตั้งค่าหลัง stopAuto ถูกประกาศ (local ใน Lua ยังเป็น nil จนกว่าบรรทัดนั้นจะรัน)
local function setBanner(text)
	if not banner then
		local gui = Instance.new("ScreenGui")
		gui.Name = "GatherStatusGui"
		gui.ResetOnSpawn = false
		gui.IgnoreGuiInset = true
		gui.DisplayOrder = 12
		gui.Parent = player:WaitForChild("PlayerGui")

		local label = Instance.new("TextButton")
		label.AutoButtonColor = false
		label.Activated:Connect(function()
			if bannerTap then bannerTap() end
		end)
		label.AnchorPoint = Vector2.new(0.5, 0)
		label.Position = UDim2.new(0.5, 0, 0, 74)
		label.Size = UDim2.fromOffset(300, 30) -- กว้างขึ้นจาก 260: ข้อความมีคำว่า "แตะแถบนี้เพื่อหยุด" ต่อท้ายแล้ว
		label.BackgroundColor3 = Color3.fromRGB(26, 28, 34)
		label.BackgroundTransparency = 0.2
		label.BorderSizePixel = 0
		label.Font = Enum.Font.GothamBold
		label.TextSize = 14
		label.TextColor3 = Color3.fromRGB(244, 197, 66)
		label.Text = ""
		label.Visible = false
		label.Parent = gui
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(0, 8)
		c.Parent = label
		banner = label
	end
	banner.Text = text or ""
	banner.Visible = (text ~= nil)
end

local function rootOf()
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart")
end

local function humanoidOf()
	local character = player.Character
	return character and character:FindFirstChildOfClass("Humanoid")
end

-- Is this node still worth walking to? Spent nodes and nodes for the wrong tool are both out.
local function isAvailable(node)
	if not node or not node.Parent then return false end
	if node:GetAttribute("Spent") == true then return false end
	if not canUse(node) or not autoTarget(node) then return false end
	local prompt = node:FindFirstChild("GatherPrompt", true)
	return prompt ~= nil
end

-- The nearest node the held tool works on. Nodes are found by TAG rather than from a ResourceNodes folder:
-- that is how the rest of this game locates them, and it means a node dragged in by hand counts too.
local function nearestNode(exclude)
	local root = rootOf()
	if not root then return nil end
	local best, bestDistance
	local here = root.Position
	for _, node in ipairs(CollectionService:GetTagged(TAG)) do
		if node ~= exclude and node.Parent and node:GetAttribute("Spent") ~= true and canUse(node) and autoTarget(node) then
			-- ระยะคร่าวจากจุดหมุนก่อน (ถูก) แล้วค่อยค้นปุ่มแบบลึก (แพง) เฉพาะตัวที่อาจใกล้กว่าตัวที่ดีที่สุดตอนนี้ — เดิมค้นลึก
			-- สองรอบกับต้นไม้ทุกต้นที่โหลดมา มือถือหน่วงทุกครั้งที่ออโต้หาจุดใหม่ (QA 2026-09-26) · เผื่อ 30 สตัดเพราะ
			-- จุดหมุนของต้นไม้ Creator Store เพี้ยนได้ ~20
			local pivot = node:IsA("BasePart") and node.Position or node:GetPivot().Position
			if not bestDistance or (pivot - here).Magnitude - 30 < bestDistance then
				local prompt = node:FindFirstChild("GatherPrompt", true)
				local anchor = prompt and prompt.Parent
				if anchor then
					local d = (anchor.Position - here).Magnitude
					if not bestDistance or d < bestDistance then
						best, bestDistance = node, d
					end
				end
			end
		end
	end
	return best
end

-- Walk to `node`, giving up early if it is taken while we are on the way. Returns true on arrival.
--
-- Pathfinding rather than a straight MoveTo, so the walk goes around the buildings and rocks in the way.
-- The path is recomputed per node rather than once, because the character may be anywhere when it starts.
local function walkTo(node)
	local humanoid = humanoidOf()
	local root = rootOf()
	if not humanoid or not root then return false end
	local prompt = node:FindFirstChild("GatherPrompt", true)
	local anchor = prompt and prompt.Parent
	if not anchor then return false end

	-- Aim BESIDE the node, not at it. The anchor sits at the model's base, which is inside the trunk or the
	-- boulder -- and PathfindingService refuses to route to a point inside solid geometry, so computing to
	-- the anchor itself returned NoPath for every node in the world (measured: 5 of 5).
	--
	-- The approach point is on the near side, so the character stops short rather than walking through.
	local toNode = anchor.Position - root.Position
	local flat = Vector3.new(toNode.X, 0, toNode.Z)
	local approach = anchor.Position
	if flat.Magnitude > 0.1 then
		approach = anchor.Position - flat.Unit * (ARRIVE_DISTANCE - 1)
	end

	local path = PathfindingService:CreatePath({
		AgentRadius = 2,
		AgentHeight = 5,
		AgentCanJump = true,
	})
	local ok = pcall(function() path:ComputeAsync(root.Position, approach) end)

	local started = os.clock()

	-- No path (across water, or inside geometry): walk at it directly rather than refusing. Worst case the
	-- character bumps into something and the timeout moves on to another node.
	local waypoints = (ok and path.Status == Enum.PathStatus.Success) and path:GetWaypoints() or nil

	if not waypoints then
		humanoid:MoveTo(approach)
		while autoFarming and isAvailable(node) do
			if os.clock() - started > WALK_TIMEOUT then return false end
			local r = rootOf()
			if not r then return false end
			if (r.Position - anchor.Position).Magnitude <= ARRIVE_DISTANCE then return true end
			task.wait(0.2)
		end
		return false
	end

	for _, waypoint in ipairs(waypoints) do
		-- Checked every leg, not once at the start: this is the whole point of the retarget rule. If
		-- someone chops the tree while we are walking to it, we stop walking now.
		if not autoFarming or not isAvailable(node) then return false end
		if os.clock() - started > WALK_TIMEOUT then return false end

		local r = rootOf()
		if not r then return false end
		-- Close enough already? Stop walking rather than following the rest of the path into the trunk.
		if (r.Position - anchor.Position).Magnitude <= ARRIVE_DISTANCE then return true end

		if waypoint.Action == Enum.PathWaypointAction.Jump then
			humanoid.Jump = true
		end
		humanoid:MoveTo(waypoint.Position)
		humanoid.MoveToFinished:Wait()
	end

	-- Deliberately generous. gatherNode closes the last few studs itself and refuses if it cannot, so
	-- "near enough to try" is the useful answer here -- reporting failure at 9 studs when the prompt
	-- reaches 10 would abandon a node the character is practically standing at.
	local r = rootOf()
	return r ~= nil and (r.Position - anchor.Position).Magnitude <= ARRIVE_DISTANCE * 3
end

-- Hold the prompt for its full duration, the way a player holding E would.
local function gatherNode(node)
	local prompt = node:FindFirstChild("GatherPrompt", true)
	if not prompt or not prompt.Enabled then return end

	-- Close the last few studs before holding.
	--
	-- The walk ends when MoveToFinished fires on the last waypoint, which is not the same as being within
	-- the prompt's reach: the humanoid stops where the PATH ends, and a path computed to a point beside the
	-- tree regularly left the character 9 to 11 studs from the anchor. Past 10 the hold does nothing at all
	-- -- InputHoldBegin on an out-of-range prompt is silently ignored, with no error and no refusal, which
	-- is exactly what "it runs to the tree but never chops it" looked like.
	local humanoid = humanoidOf()
	local anchor = prompt.Parent
	if humanoid and anchor then
		-- Aim well inside the range rather than at its edge, so a step of drift cannot put it back outside.
		local wanted = prompt.MaxActivationDistance * 0.5
		local deadline = os.clock() + 4
		while os.clock() < deadline do
			local r = rootOf()
			if not r then return end
			local distance = (r.Position - anchor.Position).Magnitude
			if distance <= wanted then break end
			-- Straight at it: this is the last couple of studs on ground already proven walkable, so
			-- pathfinding would be a lot of work to cover a step.
			local toward = (anchor.Position - r.Position)
			local flat = Vector3.new(toward.X, 0, toward.Z)
			if flat.Magnitude < 0.1 then break end
			humanoid:MoveTo(anchor.Position - flat.Unit * (wanted - 1))
			humanoid.MoveToFinished:Wait()
		end

		local r = rootOf()
		if not r or (r.Position - anchor.Position).Magnitude > prompt.MaxActivationDistance then
			return -- still out of reach; the loop will pick another node
		end
	end

	if not prompt.Enabled then return end
	prompt:InputHoldBegin()
	local deadline = os.clock() + prompt.HoldDuration + 1
	while os.clock() < deadline do
		if not autoFarming or not node.Parent then break end
		-- Taken by someone else mid-hold: let go and move on rather than finishing a hold on nothing.
		if node:GetAttribute("Spent") == true then break end
		task.wait(0.1)
	end
	prompt:InputHoldEnd()
end

local function stopAuto(reason)
	if not autoFarming then return end
	autoFarming = false
	local humanoid = humanoidOf()
	if humanoid then humanoid:MoveTo(rootOf() and rootOf().Position or humanoid.RootPart.Position) end
	if track and track.IsPlaying then track:Stop(0.2) end
	setBanner(nil)
end

local function startAuto()
	if autoFarming then return end
	if heldWeapon and not heldTool then
		setBanner("ออโต้ต้องมือเปล่า (สัตว์) หรือถือเครื่องมือฟาร์ม")
		task.delay(2, function() if not autoFarming then setBanner(nil) end end)
		return
	end
	autoFarming = true
	-- บอกทางหยุดที่ **เครื่องนี้** ใช้ได้จริง เครื่องที่มีทั้งสองอย่างบอกทั้งสองทาง
	local how = UserInputService.KeyboardEnabled
		and (UserInputService.TouchEnabled and "กด F หรือแตะแถบนี้เพื่อหยุด" or "กด F เพื่อหยุด")
		or "แตะแถบนี้เพื่อหยุด"
	setBanner((heldTool and "ฟาร์มออโต้: เปิด" or "ฟาร์มออโต้ (สัตว์): เปิด") .. " — " .. how)

	autoThread = task.spawn(function()
		local lastFailed = nil
		while autoFarming do
			local humanoid = humanoidOf()
			if not humanoid or humanoid.Health <= 0 then break end

			local target = nearestNode(lastFailed)
			-- Nothing reachable: the field may be on cooldown, so wait rather than spinning.
			if not target then
				target = nearestNode(nil) -- try again including the one we just failed on
			end

			if not target then
				task.wait(2)
			else
				if walkTo(target) and isAvailable(target) then
					gatherNode(target)
					lastFailed = nil
				else
					-- Could not get there, or it was taken. Skip it next time round so the loop cannot
					-- lock onto an unreachable node forever.
					lastFailed = target
				end
				task.wait(0.3)
			end
		end
		autoFarming = false
	end)
end

--------------------------------------------------------------------------------
-- F toggles it
--------------------------------------------------------------------------------

local function toggleAuto()
	if autoFarming then stopAuto() else startAuto() end
end

-- แตะแถบสถานะ = หยุด (ไม่ใช่สลับ) แถบขึ้นเฉพาะตอนเปิดอยู่ การแตะจึงมีความหมายเดียว และการแตะพลาดตอน
-- แถบเตือน "ต้องมือเปล่า/ถือเครื่องมือ" ก็ไม่ไปเปิดออโต้ให้โดยไม่ตั้งใจ
bannerTap = function()
	if autoFarming then stopAuto() end
end

-- Two ways in, on purpose. The prompt is how a player DISCOVERS it -- walking up to a tree and seeing
-- [F] ฟาร์มออโต้ -- and the bare key is how they stop it again once they have walked away from any node.
Remotes.ToggleAutoFarm.OnClientEvent:Connect(toggleAuto)

-- ปุ่ม F ที่โผล่อยู่บนจอตอนนี้ (ปุ่มไหนก็ได้ ไม่ใช่แค่ของฟาร์มออโต้)
--
-- เดิมที่นี่ไล่หาเฉพาะ `AutoFarmPrompt` ของจุดเก็บของ — พอมีปุ่ม F ของระบบอื่นเกิดขึ้น (คลังเมืองที่
-- อนุสาวรีย์) การกด F ตรงนั้นจะ **เปิดคลังและสั่งฟาร์มออโต้พร้อมกัน** แล้วตัวละครจะเดินออกจาก
-- หน้าต่างที่เพิ่งเปิด ซึ่งอ่านไม่ออกเลยว่าเกิดอะไรขึ้น
--
-- `PromptShown`/`PromptHidden` ยิงที่ไคลเอนต์ของคนที่เห็นปุ่มนั้นอยู่แล้ว จึงเป็นคำตอบที่ถูกเสมอและ
-- ถูกกว่าการไล่วัดระยะทุกจุดในแมพทุกครั้งที่กด F — และครอบคลุมปุ่ม F ที่ใครจะเพิ่มมาในอนาคตเองด้วย
local shownFPrompts = {}
ProximityPromptService.PromptShown:Connect(function(prompt)
	if prompt.KeyboardKeyCode == Enum.KeyCode.F then shownFPrompts[prompt] = true end
end)
ProximityPromptService.PromptHidden:Connect(function(prompt)
	shownFPrompts[prompt] = nil
end)

-- ปุ่มที่ถูกลบทิ้งระหว่างโชว์อยู่ไม่ยิง PromptHidden เสมอไป ตัวที่ตายแล้วจึงถูกคัดทิ้งตอนอ่าน
-- ไม่งั้นมันจะกลืนคีย์ F ของคนนั้นไปทั้งเซสชัน
local function anyFPromptShown()
	for prompt in pairs(shownFPrompts) do
		if prompt.Parent and prompt.Enabled then return true end
		shownFPrompts[prompt] = nil
	end
	return false
end

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	if input.KeyCode ~= Enum.KeyCode.F then return end
	-- ปุ่มบนจอเป็นเจ้าของคีย์เสมอ (มันยิง Triggered ให้เองอยู่แล้ว) คีย์เปล่าใช้ได้เฉพาะตอนไม่มีปุ่มไหนโชว์
	if not anyFPromptShown() then toggleAuto() end
end)

-- Changing what is held changes what the run is allowed to target, so any change stops it.
Remotes.EquipmentChanged.OnClientEvent:Connect(function(who)
	if who == player then stopAuto() end
end)

player.CharacterAdded:Connect(function()
	track = nil
	tracks = {}
	stopAuto()
end)

-- Prompt visibility also has to follow the SPENT state, which the server changes as nodes are taken and
-- come back. Once a second rather than on every attribute change: a node's Spent state is read fresh by
-- isAvailable on every pass of the auto loop anyway, and this is only about what is drawn on screen.
task.spawn(function()
	while true do
		task.wait(1)
		refreshPrompts()
	end
end)

-- ของในมือมาถึงทีหลังตอนเข้าเซิร์ฟ (แอตทริบิวต์) → จัดปุ่มใหม่ทันที ไม่ต้องรอรอบวินาที
player:GetAttributeChangedSignal("WOLD_Weapon"):Connect(function() task.defer(refreshPrompts) end)

refreshPrompts()
