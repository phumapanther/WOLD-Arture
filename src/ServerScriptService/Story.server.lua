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
local VipGift = require(script.Parent.VipGift)
local Vip = require(script.Parent.Vip)
local Friends = require(script.Parent.Friends)
local PremiumAccess = require(script.Parent.PremiumAccess)
local QuestNav = require(script.Parent.QuestNav)
local FarmRegistry = require(script.Parent.Lobby.FarmRegistry)
local ItemCatalog = require(game.ReplicatedStorage.ItemCatalog)
local QuestLogRules = require(game.ReplicatedStorage.QuestLogRules)
local QuestNavRules = require(game.ReplicatedStorage.QuestNavRules)
local TeleportService = game:GetService("TeleportService")

local NPC_TAG = "WOLD_StoryNpc"
local MARKER_TAG = "WOLD_StoryMarker"
local CIRCLE_TAG = "WOLD_MagicCircle"
local PROMPT_DISTANCE = 10

local InCutscene = {} -- [player] = token (ตรึงตัวอยู่)
local LastPushed = {} -- [player] = กุญแจของภาพล่าสุด (ส่งซ้ำเฉพาะตอนเปลี่ยน)
local SkyOffered = {} -- [player] = true ระหว่างถามรับพร (กันยิง sky_accept เอง)
local SkyPending = {} -- [player] = token ระหว่างคัทซีนรถ (วาปครั้งเดียว)
local Warping = {} -- [player] = true ระหว่างรอ TeleportService (ไว้บอกตอนวาปไม่สำเร็จ)
local AURAS = VipGift.AuraPool()
local rng = Random.new()

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

-- บทที่กำลังเล่น (บทแรกที่ยังไม่จบ) + ความคืบหน้า · ค่าที่สาม = บทล็อกถัดไป (StoryConfig.Current)
local function current(s)
	return StoryConfig.Current(s)
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

local function hasPremium(player)
	return PremiumAccess.HasPremiumPass ~= nil and PremiumAccess.HasPremiumPass(player) == true
end

local function friendCount(player)
	local state = Friends.Get(player)
	local n = 0
	for _ in pairs(state and state.friends or {}) do n += 1 end
	return n
end

local function sideQuestsOf(player)
	local data = ProfileAccess.Get(player)
	if not data then return {} end
	return VipGift.Quests(data, os.time(), Progression.GetLevel(player), friendCount(player), AURAS, hasPremium(player))
end

-- แถวทอง (บทที่เล่น หรือบทล็อก) + แถวฟ้า — ไคลเอนต์รวมกับงานบอร์ดเอง (QuestLogRules.Merge)
local function rowsOf(player, s)
	local rows = {}
	local ch, p, locked = current(s)
	if ch then
		local step = ch.steps[p.step]
		local got = p.got or 0
		if step.kind == "deliver" then got = Inventory.CountOf(player, step.item) end
		rows[#rows + 1] = QuestLogRules.MainRow(ch, step, got)
	elseif locked then
		rows[#rows + 1] = QuestLogRules.LockedRow(locked)
	end
	for _, q in ipairs(sideQuestsOf(player)) do
		rows[#rows + 1] = QuestLogRules.SideRow(q, StoryConfig.SideQuests[q.id])
	end
	return rows
end

-- เควสฟ้าโผล่ใหม่ = ข้อความ + เสียง ครั้งเดียวต่อเควส (แถวทองมีเสียงขึ้นขั้นของมันอยู่แล้ว)
local function announce(player, s, rows)
	if type(s.pop) ~= "table" then s.pop = {} end
	for _, row in ipairs(rows) do
		if row.color == "side" and row.state == "active" and not s.pop[row.key] then
			s.pop[row.key] = true
			Remotes.StoryPlay:FireClient(player, "newQuest", row.title)
		end
	end
end

local function stateOf(player)
	local s = storyOf(player)
	if not s then return nil end
	local rows = rowsOf(player, s)
	local ch, p = current(s)
	if not ch then return { done = true, rows = rows } end
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
		rows = rows,
	}
end

local function push(player, force)
	local state = stateOf(player)
	if not state then return end
	local s = storyOf(player)
	if s then announce(player, s, state.rows or {}) end
	local key = (state.done and "done" or table.concat({ state.chapter, state.step, state.got or 0,
		tostring(state.ready), tostring(state.npcAt), tostring(state.target) }, "|"))
		.. "#" .. QuestLogRules.Signature(state.rows)
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
	-- บัญชีใหม่: 150 เพชรที่หุ่นฟางรับได้หลังจบบทแรก (VipGift.GemsAfterChapter) — บอกตรงนี้ว่าไปรับได้แล้ว
	local data = ProfileAccess.Get(player)
	local gift = ch.id == "brasshaven" and data and data.NewbieGems == true and data.NewbieGemsClaimed ~= true
	Remotes.StoryPlay:FireClient(player, "complete", {
		name = ch.name, exp = reward.exp, gold = reward.gold, title = ch.title and ch.title.text, gift = gift or nil,
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
		-- บทล่าสุดที่เปิดแล้ว (ข้ามบทล็อกท้ายตาราง) เป็นคนพูดบทจบ
		for i = #StoryConfig.Chapters, 1, -1 do
			local last = StoryConfig.Chapters[i]
			if not last.locked then
				if last.npc == npcId then play(player, last.doneDialogue) end
				break
			end
		end
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

--------------------------------------------------------------------------------
-- ออฟาเรียน เทพหุ่นฟาง (เควสสีฟ้า · 2026-09-29) — ปุ่มอยู่ VipGiftPrompt.server
--------------------------------------------------------------------------------

-- ให้ของของเควสหนึ่งอัน · คืนข้อความของที่ได้ หรือ nil (ไม่ผ่าน = ไม่เสียสิทธิ์ ตามกติกา VipGift)
local function giveSide(player, data, id)
	if id == "newcomer" then
		local ok = VipGift.ClaimPass(data, hasPremium(player), function()
			return PremiumAccess.GrantPremiumPass ~= nil and PremiumAccess.GrantPremiumPass(player) == true
		end)
		return ok and "🎫 แบทเทิลพาสพรีเมียมเดือนนี้ — เปิดที่เมนู ⋯ → 🎫 แบทเทิลพาส" or nil
	elseif id == "travel" then
		local ok = VipGift.ClaimGems(data, function(n)
			return PremiumAccess.AddGems ~= nil and PremiumAccess.AddGems(player, n) == true
		end)
		return ok and ("💎 %d เพชร"):format(VipGift.Gems) or nil
	elseif id == "friends" then
		local ok, auraId = VipGift.ClaimAura(data, friendCount(player), AURAS, rng, function(itemId)
			if not Inventory.HasRoomFor(player, itemId, 1) then return false end
			return Inventory.AddItem(player, itemId, 1) == true
		end)
		if ok then
			Inventory.Send(player)
			local item = ItemCatalog.Get(auraId)
			return ("✨ %s (ใส่ได้ที่กระเป๋า)"):format(item and item.name or auraId)
		end
		if auraId == "full" then
			Remotes.SocialNotify:FireClient(player, "error", "กระเป๋าเต็ม — เคลียร์ช่องแล้วกลับมาหาออฟาเรียน")
		end
	end
	return nil
end

StoryAccess.TalkOforian = function(player)
	if InCutscene[player] then return end
	local data = ProfileAccess.Get(player)
	if not data then
		return Remotes.SocialNotify:FireClient(player, "error", "ข้อมูลตัวละครยังโหลดไม่เสร็จ ลองใหม่อีกครั้ง")
	end
	local spoke = false
	for _, q in ipairs(sideQuestsOf(player)) do
		local def = StoryConfig.SideQuests[q.id]
		if q.state == "waiting" then
			if q.reason then Remotes.SocialNotify:FireClient(player, "warn", q.reason) end
		elseif q.id == "sky" then
			-- ท้ายสุดเสมอ (VipGift.Quests) · ให้ VIP ตอนกด "รับพร" ไม่ใช่ตอนคุย
			play(player, def.dialogue)
			SkyOffered[player] = true
			Remotes.StoryPlay:FireClient(player, "skyOffer")
			spoke = true
		else
			local got = giveSide(player, data, q.id)
			if got then
				play(player, def.dialogue)
				Remotes.StoryPlay:FireClient(player, "gift", { title = "🎁 " .. def.title, body = "ได้รับ " .. got })
				print(("[Oforian] %s (%d) ได้ %s"):format(player.Name, player.UserId, got))
				spoke = true
			end
		end
	end
	if not spoke then play(player, StoryConfig.OforianIdle) end
	if ProfileAccess.Flush then ProfileAccess.Flush(player) end
	push(player, true)
end

local function skyFailed(player, text)
	Warping[player] = nil
	Remotes.StoryPlay:FireClient(player, "skyFailed", text or "วาปไม่สำเร็จ — เข้าเกาะได้จากล็อบบี้ แท็บฟาร์มมิ่ง")
end

-- ข้อยกเว้นเดียวของกฎ "เปลี่ยนโหมดผ่านล็อบบี้" (ผู้ใช้เลือก 2026-09-29): ครั้งเดียวตอนจบเควสเกาะลอยฟ้า
local function warpToIsland(player)
	if ServerConfig.FarmingPlaceId == 0 then return skyFailed(player) end
	local ok, code = pcall(FarmRegistry.GetOrCreate, player.UserId)
	if not ok or not code then
		warn("[Story] จองเกาะไม่สำเร็จ: " .. tostring(code))
		return skyFailed(player)
	end
	if ProfileAccess.Flush then ProfileAccess.Flush(player) end
	Warping[player] = true
	local okTp, err = pcall(function()
		TeleportService:TeleportToPrivateServer(ServerConfig.FarmingPlaceId, code, { player })
	end)
	if not okTp then
		warn("[Story] วาปไม่สำเร็จ: " .. tostring(err))
		skyFailed(player)
	end
end

TeleportService.TeleportInitFailed:Connect(function(player)
	if Warping[player] then skyFailed(player) end
end)

local function startSkyCutscene(player)
	local token = os.clock()
	InCutscene[player] = token
	SkyPending[player] = token
	StatusEffects.SetRooted(player, true)
	Remotes.StoryPlay:FireClient(player, "skyCutscene", { at = QuestNav.Dummy() })
	task.delay(StoryConfig.CutsceneMaxSeconds, function()
		if SkyPending[player] == token then
			SkyPending[player] = nil
			endCutscene(player)
			warpToIsland(player)
		end
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
	elseif action == "sky_accept" then
		if not SkyOffered[player] or InCutscene[player] then return end
		SkyOffered[player] = nil
		local data = ProfileAccess.Get(player)
		local s = storyOf(player)
		if not (data and s) or not VipGift.Claim(data, os.time(), Progression.GetLevel(player)) then
			return Remotes.SocialNotify:FireClient(player, "warn", "รับพรไม่ได้ตอนนี้ — ลองคุยกับออฟาเรียนอีกครั้ง")
		end
		Vip.Publish(player)
		s.skyWelcome = true
		if ProfileAccess.Flush then ProfileAccess.Flush(player) end
		print(("[Oforian] %s (%d) รับพรเกาะลอยฟ้า (VIP +%d วัน)"):format(player.Name, player.UserId, VipGift.Days))
		push(player, true)
		startSkyCutscene(player)
	elseif action == "sky_warp" then
		if not SkyPending[player] then return end
		SkyPending[player] = nil
		endCutscene(player)
		warpToIsland(player)
	end
end)

-- จิ้มแถวเควสทอง/ฟ้า = หาเป้าให้ (แถวบอร์ด "board:" เป็นของ Quests.server)
local NavTaps = {} -- [userId] = os.clock ของครั้งล่าสุด (QuestNavRules.TryTap กันจิ้มรัว)
Remotes.RequestQuestNav.OnServerEvent:Connect(function(player, key)
	if type(key) ~= "string" then return end
	if key:sub(1, 5) ~= "side:" and key:sub(1, 6) ~= "story:" then return end
	if not QuestNavRules.TryTap(NavTaps, player.UserId, os.clock()) then return end
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not root then return end
	local from = root.Position
	if key:sub(1, 5) == "side:" then
		return QuestNav.Send(player, QuestNav.Dummy(), StoryConfig.Npcs.Oforian.name)
	end
	if key:sub(1, 6) ~= "story:" then return end
	local s = storyOf(player)
	if not s then return end
	local ch, p = current(s)
	if not ch then return Remotes.SocialNotify:FireClient(player, "warn", "เควสนี้ยังไม่เปิด") end
	local step = ch.steps[p.step]
	local npc = npcModel(ch.npc)
	local npcAt = npc and npc:GetPivot().Position or nil
	local npcName = StoryConfig.Npcs[ch.npc] and StoryConfig.Npcs[ch.npc].name or ch.npc
	if step.kind == "talk" then
		QuestNav.Send(player, npcAt, npcName)
	elseif step.kind == "deliver" then
		if Inventory.CountOf(player, step.item) >= (step.need or 0) then
			QuestNav.Send(player, npcAt, npcName)
		else
			QuestNav.Send(player, QuestNav.ForItem(step.item, from), QuestNav.ItemName(step.item))
		end
	elseif step.kind == "hunt" then
		QuestNav.Send(player, QuestNav.Spawner(QuestNavRules.MobKindsNamed(step.mob), from), step.mob)
	elseif step.kind == "reach" then
		QuestNav.Send(player, markerOf(ch), step.goal)
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
			end
			-- แถวเควส (ทอง/ฟ้า) เปลี่ยนได้ทุกขั้น รวมขั้น reach (เลเวลขึ้น เพื่อนเพิ่ม) — ส่งเมื่อเปลี่ยนเท่านั้น (push เทียบกุญแจเอง)
			if s then pcall(push, player) end
		end
	end
end)

Players.PlayerRemoving:Connect(function(player)
	InCutscene[player] = nil
	LastPushed[player] = nil
	SkyOffered[player] = nil
	SkyPending[player] = nil
	Warping[player] = nil
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
	elseif sub == "gifts" then
		-- ทำให้บัญชีนี้เหมือนบัญชีใหม่ที่ยังไม่เคยรับของขวัญออฟาเรียน (ทดสอบเควสฟ้าทั้งสี่)
		local data = ProfileAccess.Get(player)
		data.NewbieGems = true
		data.NewbieGemsClaimed, data.NewbiePassClaimed, data.VipGiftClaimed, data.FriendAuraClaimed = nil, nil, nil, nil
		s.pop = nil
		push(player, true)
		return "ล้างธงของขวัญแล้ว — เควสฟ้าโผล่ตามเงื่อนไข (Lv.5 = เกาะลอยฟ้า · จบบทไลรา = การเดินทาง · เพื่อน 5 = มิตรภาพ)"
	elseif sub == "welcome" then
		s.skyWelcome = true
		return "ตั้งธงป้ายต้อนรับแล้ว — เข้าเกาะ (จากล็อบบี้) ครั้งถัดไปจะเห็น"
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
