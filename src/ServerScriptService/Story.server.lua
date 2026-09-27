-- Story.server: เนื้อเรื่อง "ผู้มากับแสงวิบวับ" (เพลสหลักเท่านั้น · ผู้ใช้อนุมัติร่าง 2026-09-27 · docs/story/01-brasshaven.md)
--
-- ข้อมูลทั้งหมดอยู่ `StoryConfig` (บทพูด ขั้น คัทซีน) · ความคืบหน้าอยู่ `profile.Data.Story` (ดูหัว StoryConfig)
-- · **คัทซีนเข้าเกมครั้งแรก**: ไคลเอนต์ส่ง "ready" หลังจอโหลดจบ → คนใหม่ (เลเวล 1 ยังไม่เคยมีข้อมูลเนื้อเรื่อง) ได้คัทซีน
--   (ย้ายไปนอนกลางวงเวท + ตรึงตัวจนคัทซีนจบ/ข้าม · เพดาน `CutsceneMaxSeconds`) · คนเก่าได้ขั้นที่ 1 เลยโดยไม่มีคัทซีน
-- · คุยกับ NPC = ปุ่ม E `StoryPrompt` บนโมเดลแท็ก `WOLD_StoryNpc` (mapgen/110 วาง) · บทพูดส่งแค่ id ไคลเอนต์อ่านข้อความจาก StoryConfig
-- · ล่ามอน = `StoryAccess.RecordKill` (Mobs.server) · ไปถึงจุดหมาย = ลูป 0.5 วิ ถามระยะถึงหมุดแท็ก `WOLD_StoryMarker`
--   (ลากย้ายได้ใน Studio · หาไม่เจอ = กลางเมืองจาก QuestConfig)
-- · จบบท = EXP + เหรียญ + ฉายาเมือง (`Story.titles` → Achievements) + ปลดบอร์ดเควสเมืองนั้น (`Story.towns` → QuestConfig.TownOpen)
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")

local ServerConfig = require(script.Parent.ServerConfig)
if ServerConfig.IsLobby or ServerConfig.IsArena or ServerConfig.IsFarm then return end

local StoryConfig = require(game.ReplicatedStorage.StoryConfig)
local QuestConfig = require(game.ReplicatedStorage.QuestConfig)
local Remotes = require(game.ReplicatedStorage.Remotes)
local ProfileAccess = require(script.Parent.ProfileAccess)
local Inventory = require(script.Parent.Inventory)
local Progression = require(script.Parent.Progression)
local StatusEffects = require(script.Parent.StatusEffects)
local StoryAccess = require(script.Parent.StoryAccess)

local NPC_TAG = "WOLD_StoryNpc"
local MARKER_TAG = "WOLD_StoryMarker"
local CIRCLE_TAG = "WOLD_MagicCircle"
local PROMPT_DISTANCE = 10

local InCutscene = {} -- [player] = token (ตรึงตัวอยู่)
local LastPushed = {} -- [player] = กุญแจของภาพล่าสุด (ส่งซ้ำเฉพาะตอนเปลี่ยน)

local function storyOf(player)
	local data = ProfileAccess.Get(player)
	if not data then return nil end
	local s = data.Story
	if type(s) ~= "table" then
		s = {}
		data.Story = s
	end
	if type(s.ch) ~= "table" then s.ch = {} end
	if type(s.towns) ~= "table" then s.towns = {} end
	if type(s.titles) ~= "table" then s.titles = {} end
	return s
end

-- บทที่กำลังเล่น (บทแรกที่ยังไม่จบ) + ความคืบหน้าของบทนั้น
local function current(s)
	for _, ch in ipairs(StoryConfig.Chapters) do
		local p = s.ch[ch.id]
		if type(p) ~= "table" then
			p = { step = 1, got = 0 }
			s.ch[ch.id] = p
		end
		if not p.done then return ch, p end
	end
	return nil, nil
end

local function townCenter(townId)
	for _, b in ipairs(QuestConfig.Boards) do
		if b.id == townId then return b.where end
	end
	return nil
end

-- จุดหมายของขั้น reach — หมุดที่วางไว้ (ลากย้ายได้) หรือกลางเมือง
local function markerOf(ch)
	for _, m in ipairs(CollectionService:GetTagged(MARKER_TAG)) do
		if m:GetAttribute("Chapter") == ch.id then
			return m:IsA("Model") and m:GetPivot().Position or (m:IsA("BasePart") and m.Position) or nil
		end
	end
	return townCenter(ch.town)
end

local function npcModel(npcId)
	for _, m in ipairs(CollectionService:GetTagged(NPC_TAG)) do
		if m:GetAttribute("StoryNpc") == npcId then return m end
	end
	return nil
end

local function stateOf(player)
	local s = storyOf(player)
	if not s then return nil end
	local ch, p = current(s)
	if not ch then return { done = true } end
	local step = ch.steps[p.step]
	local got = p.got or 0
	if step.kind == "deliver" then got = Inventory.CountOf(player, step.item) end
	local npc = npcModel(ch.npc)
	return {
		chapter = ch.id, name = ch.name, step = p.step, steps = #ch.steps,
		kind = step.kind, goal = step.goal, need = step.need, got = got,
		npc = ch.npc, npcAt = npc and npc:GetPivot().Position or nil,
		target = step.kind == "reach" and markerOf(ch) or nil, radius = step.radius,
		-- ❗ เหนือหัว NPC: มีเรื่องให้คุยจริงตอนนี้
		ready = step.kind == "talk" or (step.kind == "deliver" and got >= (step.need or 0)),
	}
end

local function push(player, force)
	local state = stateOf(player)
	if not state then return end
	local key = state.done and "done" or table.concat({ state.chapter, state.step, state.got or 0,
		tostring(state.ready), tostring(state.npcAt), tostring(state.target) }, "|")
	if not force and LastPushed[player] == key then return end
	LastPushed[player] = key
	Remotes.StoryState:FireClient(player, state)
end

local function play(player, dialogueId)
	if dialogueId and StoryConfig.Dialogues[dialogueId] then
		Remotes.StoryPlay:FireClient(player, "dialogue", dialogueId)
	end
end

local function complete(player, s, ch, p)
	p.done = true
	s.towns[ch.town] = true
	if ch.title then s.titles[ch.title.id] = true end
	local reward = ch.reward or {}
	if reward.exp and reward.exp > 0 then Progression.AwardExp(player, reward.exp) end
	if reward.gold and reward.gold > 0 then
		Inventory.AddGold(player, reward.gold)
		Inventory.Send(player)
	end
	Remotes.StoryPlay:FireClient(player, "complete", {
		name = ch.name, exp = reward.exp, gold = reward.gold, title = ch.title and ch.title.text,
	})
	print(("[Story] %s จบบท %s"):format(player.Name, ch.id))
end

local function advance(player, s, ch, p)
	p.step += 1
	p.got = 0
	if p.step > #ch.steps then complete(player, s, ch, p) end
	if ProfileAccess.Flush then ProfileAccess.Flush(player) end
	push(player, true)
end

local function talk(player, npcId)
	local s = storyOf(player)
	if not s then return end
	local ch, p = current(s)
	if not ch then
		local last = StoryConfig.Chapters[#StoryConfig.Chapters]
		if last and last.npc == npcId then play(player, last.doneDialogue) end
		return
	end
	if ch.npc ~= npcId then return end
	local step = ch.steps[p.step]
	if step.kind == "talk" then
		play(player, step.dialogue)
		advance(player, s, ch, p)
	elseif step.kind == "deliver" then
		-- ของขอบทองไม่นับ (CountOf/RemoveById ข้ามให้แล้ว) · ทั้งหมดหรือไม่เอาเลย
		if Inventory.CountOf(player, step.item) >= step.need and Inventory.RemoveById(player, step.item, step.need) then
			Inventory.Send(player)
			play(player, step.dialogue)
			advance(player, s, ch, p)
		else
			play(player, step.wait)
		end
	else
		play(player, step.wait)
	end
end

StoryAccess.RecordKill = function(player, mobName)
	local s = storyOf(player)
	if not s then return end
	local ch, p = current(s)
	local step = ch and ch.steps[p.step]
	if not (step and step.kind == "hunt" and step.mob == mobName) then return end
	p.got = (p.got or 0) + 1
	if p.got >= step.need then
		play(player, step.after)
		advance(player, s, ch, p)
	else
		push(player)
	end
end

--------------------------------------------------------------------------------
-- คัทซีน
--------------------------------------------------------------------------------
local function circleCenter()
	for _, m in ipairs(CollectionService:GetTagged(CIRCLE_TAG)) do
		if m:IsA("Model") then return m:GetPivot().Position end
	end
	return townCenter("Brasshaven")
end

local function endCutscene(player)
	if not InCutscene[player] then return end
	InCutscene[player] = nil
	StatusEffects.SetRooted(player, false)
end

local function startCutscene(player)
	local center = circleCenter()
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if center and root then
		-- ยืนกลางวงเวท (ไคลเอนต์ทำท่านอนแล้วลุกเอง) · หันหน้าไปทางไลรา
		local npc = npcModel("Lyra")
		local face = npc and npc:GetPivot().Position or (center + Vector3.new(0, 0, -10))
		local at = center + Vector3.new(0, 3, 0)
		player.Character:PivotTo(CFrame.lookAt(at, Vector3.new(face.X, at.Y, face.Z)))
	end
	local token = os.clock()
	InCutscene[player] = token
	StatusEffects.SetRooted(player, true)
	local npc = npcModel("Lyra")
	Remotes.StoryPlay:FireClient(player, "cutscene", { center = center, lyra = npc and npc:GetPivot().Position or nil })
	task.delay(StoryConfig.CutsceneMaxSeconds, function()
		if InCutscene[player] == token then endCutscene(player) end
	end)
end

Remotes.RequestStory.OnServerEvent:Connect(function(player, action)
	if action == "ready" then
		local s = storyOf(player)
		if not s then return end
		if not s.cut then
			s.cut = true
			-- คนใหม่จริง = เลเวล 1 (Progression โหลดเสร็จแล้วเพราะไคลเอนต์ผ่านจอโหลดมาแล้ว) · คนเก่าข้ามคัทซีน
			if Progression.GetLevel(player) <= 1 then startCutscene(player) end
		end
		push(player, true)
	elseif action == "cutscene_done" then
		endCutscene(player)
		push(player, true)
	end
end)

--------------------------------------------------------------------------------
-- ปุ่มคุยบน NPC — ลูปถามใหม่ (กฎเหล็ก StreamingEnabled/ของที่ผู้ใช้วางทีหลัง)
--------------------------------------------------------------------------------
local wired = {}
local function wire(model)
	if wired[model] or not model:IsDescendantOf(workspace) then return end
	local npcId = model:GetAttribute("StoryNpc")
	local info = npcId and StoryConfig.Npcs[npcId]
	if not info then return end
	local anchor = model:FindFirstChild("HumanoidRootPart") or model:FindFirstChild("Head") or model.PrimaryPart
	if not anchor then return end
	wired[model] = true
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "StoryPrompt"
	prompt.ActionText = "คุย"
	prompt.ObjectText = info.name
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = PROMPT_DISTANCE
	prompt.RequiresLineOfSight = false
	prompt.Parent = anchor
	prompt.Triggered:Connect(function(player)
		if InCutscene[player] then return end
		talk(player, npcId)
	end)
	-- ท่ายืนมาตรฐาน R15 (ตัวเดินสุ่มของโรงงานถูกถอดออก ไม่มีใครเล่นท่าให้) — เล่นฝั่งเซิร์ฟ ทุกคนเห็น
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if humanoid then
		local animator = humanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator")
		animator.Parent = humanoid
		local anim = Instance.new("Animation")
		anim.AnimationId = "rbxassetid://507766388"
		local ok, track = pcall(animator.LoadAnimation, animator, anim)
		if ok then
			track.Looped = true
			track:Play()
		end
	end
end

task.spawn(function()
	while true do
		for _, model in ipairs(CollectionService:GetTagged(NPC_TAG)) do
			if model:IsA("Model") then wire(model) end
		end
		task.wait(1)
	end
end)

-- ไปถึงจุดหมาย + ส่งภาพใหม่เมื่อของในกระเป๋าเปลี่ยน (ขั้นส่งของ)
task.spawn(function()
	while true do
		task.wait(0.5)
		for _, player in ipairs(Players:GetPlayers()) do
			local s = ProfileAccess.Get(player) and storyOf(player)
			local ch, p = nil, nil
			if s then ch, p = current(s) end
			local step = ch and ch.steps[p.step]
			if step and step.kind == "reach" and not InCutscene[player] then
				local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
				local target = markerOf(ch)
				if root and target then
					local flat = Vector3.new(root.Position.X - target.X, 0, root.Position.Z - target.Z).Magnitude
					if flat <= (step.radius or 9) and math.abs(root.Position.Y - target.Y) < 14 then
						Remotes.StoryPlay:FireClient(player, "memory", step.memory)
						advance(player, s, ch, p)
					end
				end
			elseif s then
				pcall(push, player)
			end
		end
	end
end)

Players.PlayerRemoving:Connect(function(player)
	InCutscene[player] = nil
	LastPushed[player] = nil
end)

-- คำสั่งแอดมิน /story (AdminCommands) — ผู้ทดสอบเป็นคนเก่าเลเวลสูง จึงไม่มีวันเห็นคัทซีนคนใหม่ถ้าไม่มีทางนี้
-- /story = ดูสถานะ · cutscene = เล่นคัทซีน · memory = ภาพความทรงจำ · step <n> = กระโดดไปขั้นนั้น · done = จบบท (ได้รางวัล) · reset = ล้างทั้งหมด
StoryAccess.Admin = function(player, args)
	local sub = (args[1] or ""):lower()
	local s = storyOf(player)
	if not s then return "ยังโหลดโปรไฟล์ไม่เสร็จ" end
	local ch, p = current(s)
	if sub == "cutscene" then
		startCutscene(player)
		return "เล่นคัทซีนแล้ว (ข้ามได้มุมขวาบน)"
	elseif sub == "memory" then
		Remotes.StoryPlay:FireClient(player, "memory", "m1")
		return "เล่นภาพความทรงจำ m1"
	elseif sub == "reset" then
		local data = ProfileAccess.Get(player)
		data.Story = nil
		LastPushed[player] = nil
		push(player, true)
		return "ล้างเนื้อเรื่องแล้ว — กลับไปขั้น 1 (คัทซีนสั่งเองด้วย /story cutscene)"
	elseif sub == "step" then
		if not ch then return "จบทุกบทแล้ว — /story reset ก่อน" end
		local n = math.clamp(math.floor(tonumber(args[2]) or 1), 1, #ch.steps)
		p.step, p.got = n, 0
		push(player, true)
		return ("ไปขั้น %d/%d: %s"):format(n, #ch.steps, ch.steps[n].goal)
	elseif sub == "done" then
		if not ch then return "จบทุกบทแล้ว" end
		p.step = #ch.steps
		advance(player, s, ch, p)
		return "จบบทแล้ว (ได้รางวัล + ฉายา)"
	end
	if not ch then return "จบทุกบทแล้ว · เมืองที่ปลด: " .. table.concat((function()
		local t = {} for k in pairs(s.towns) do t[#t + 1] = k end return t end)(), ", ") end
	local step = ch.steps[p.step]
	return ("บท %s ขั้น %d/%d: %s (%d/%s) · คัทซีนเห็นแล้ว: %s"):format(ch.name, p.step, #ch.steps, step.goal,
		p.got or 0, tostring(step.need or "-"), tostring(s.cut == true))
end

-- ช่องเทสใน Studio (sandbox ของ execute_luau require ได้สำเนาใหม่ของโมดูล — ทรงเดียวกับ QuestTest)
if game:GetService("RunService"):IsStudio() then
	local bf = Instance.new("BindableFunction")
	bf.Name = "StoryTest"
	bf.OnInvoke = function(op, player, ...)
		if op == "State" then return stateOf(player) end
		if op == "Data" then return storyOf(player) end
		if op == "Talk" then talk(player, ...) return stateOf(player) end
		if op == "Kill" then StoryAccess.RecordKill(player, ...) return stateOf(player) end
		if op == "Reset" then
			local data = ProfileAccess.Get(player)
			if data then data.Story = nil end
			LastPushed[player] = nil
			return true
		end
		error("StoryTest: ไม่มี op " .. tostring(op))
	end
	bf.Parent = game:GetService("ServerStorage")
end
