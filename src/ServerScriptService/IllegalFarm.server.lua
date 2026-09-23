-- IllegalFarm.server.lua: the still, the pipe and the crates -- the three things you can work without a tool
-- and without anybody's permission.
--
-- Found by TAG, like every other thing in the world worth pressing E at: WOLD_Farm with a FarmKind attribute
-- naming an entry in FarmConfig.Nodes.
--
-- The shape of one attempt:
--   1. E is pressed. The server checks the spot is free, the player is upright, and nothing else is already
--      asking them to press buttons.
--   2. The cooldown starts IMMEDIATELY, for the whole server. This is the user's rule and it is what stops a
--      failed attempt being free -- there is no second try at this crate for half an hour, by anyone.
--   3. The character rummages for a moment, with the sound playing at the node so everyone nearby hears it.
--   4. The arrow minigame runs. The server rolled the sequence and holds the reward; the client only says
--      whether the player kept up.
--   5. Success pays out. Failure leaves them rooted and seeing stars for five seconds.
--
-- The reward is never named by the client and never sent down before it is earned: Minigames.Run hands back
-- one bit, and everything valuable happens on this side of it.
local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ServerConfig = require(game.ServerScriptService.ServerConfig)
local IslandAccess = require(game.ServerScriptService.Island.IslandAccess)
local ProfileAccess = require(game.ServerScriptService.ProfileAccess)

if ServerConfig.IsLobby then return end

local FarmConfig = require(game.ReplicatedStorage.FarmConfig)
local ItemCatalog = require(game.ReplicatedStorage.ItemCatalog)
local Inventory = require(game.ServerScriptService.Inventory)
local Progression = require(game.ServerScriptService.Progression)
local Vitals = require(game.ServerScriptService.Vitals)
local StatusEffects = require(game.ServerScriptService.StatusEffects)
local Minigames = require(game.ServerScriptService.Minigames)
local Classes = require(game.ServerScriptService.Classes)
local ClassConfig = require(game.ReplicatedStorage.ClassConfig)
local Remotes = require(game.ReplicatedStorage.Remotes)

local TAG = "WOLD_Farm"

-- [node] = os.clock() when it is workable again. A deadline per node rather than a running timer, the same
-- way GatherConfig's respawns work: a hundred nodes cost a hundred table entries and no tasks.
local ReadyAt = {}

--------------------------------------------------------------------------------

local function configFor(node)
	local kind = node:GetAttribute("FarmKind")
	return kind and FarmConfig.Nodes[kind], kind
end

local function remaining(node)
	local until_ = ReadyAt[node]
	if not until_ then return 0 end
	local left = until_ - os.clock()
	if left <= 0 then
		ReadyAt[node] = nil
		return 0
	end
	return left
end

-- Where the prompt hangs. The same problem the gathering nodes have, and the same answer: a prompt measures
-- its range from the PART it is parented to, and these models are tall -- a reactor's vessel has its origin
-- three studs up inside a six-stud tank. So the prompt gets its own invisible marker planted at the model's
-- base, and the range means what it says.
local function anchorOf(node)
	if node:IsA("BasePart") then return node end
	if not node:IsA("Model") then return nil end

	local existing = node:FindFirstChild("FarmAnchor")
	if existing then return existing end

	local low, minX, maxX, minZ, maxZ = math.huge, math.huge, -math.huge, math.huge, -math.huge
	for _, d in ipairs(node:GetDescendants()) do
		if d:IsA("BasePart") and d.Transparency < 0.9 then
			low = math.min(low, d.Position.Y - d.Size.Y / 2)
			minX, maxX = math.min(minX, d.Position.X), math.max(maxX, d.Position.X)
			minZ, maxZ = math.min(minZ, d.Position.Z), math.max(maxZ, d.Position.Z)
		end
	end
	if low == math.huge then
		return node.PrimaryPart or node:FindFirstChildWhichIsA("BasePart", true)
	end

	local anchor = Instance.new("Part")
	anchor.Name = "FarmAnchor"
	anchor.Size = Vector3.new(1, 1, 1)
	anchor.Position = Vector3.new((minX + maxX) / 2, low + 2, (minZ + maxZ) / 2)
	anchor.Transparency = 1
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Parent = node
	return anchor
end

-- Published so the client can draw the countdown over the node without asking. GetServerTimeNow is shared by
-- every machine in the server, which os.clock is emphatically not -- a clock value sent to a client would be
-- measured from when THAT machine started.
local function publishCooldown(node, seconds)
	if seconds and seconds > 0 then
		node:SetAttribute("FarmReadyAt", workspace:GetServerTimeNow() + seconds)
	else
		node:SetAttribute("FarmReadyAt", nil)
	end
end

local function setPrompts(node, enabled)
	for _, d in ipairs(node:GetDescendants()) do
		if d:IsA("ProximityPrompt") and d.Name == "FarmPrompt" then d.Enabled = enabled end
	end
end

--------------------------------------------------------------------------------
-- The sound of the work
--------------------------------------------------------------------------------

local function playSearch(node)
	local anchor = node:FindFirstChild("FarmAnchor") or node.PrimaryPart
		or node:FindFirstChildWhichIsA("BasePart", true)
	if not anchor or not FarmConfig.SearchSound then return end
	local sound = Instance.new("Sound")
	sound.SoundId = FarmConfig.SearchSound
	sound.Volume = FarmConfig.SearchVolume
	sound.RollOffMaxDistance = FarmConfig.SearchDistance
	sound.Parent = anchor
	sound:Play()
	Debris:AddItem(sound, 6)
	return sound
end

-- The rummaging pose. Loaded onto the character's own Animator so everyone sees it, and stopped by the
-- returned function however the attempt ends. A config with no id at all simply does nothing, which is the
-- state the game ships in until the sequence is published.
local function playSearchAnimation(player)
	local id = FarmConfig.SearchAnimation
	if type(id) ~= "string" or id == "" then return function() end end

	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
	if not animator then return function() end end

	local animation = Instance.new("Animation")
	animation.AnimationId = id
	local ok, track = pcall(function() return animator:LoadAnimation(animation) end)
	if not ok or not track then
		animation:Destroy()
		return function() end
	end
	track.Looped = true
	track:Play(0.2)
	return function()
		track:Stop(0.2)
		animation:Destroy()
	end
end

--------------------------------------------------------------------------------
-- Paying out
--------------------------------------------------------------------------------

local function give(player, entry)
	local count = math.random(entry.min or 1, entry.max or 1)
	if not Inventory.AddItem(player, entry.item, count) then
		Remotes.SocialNotify:FireClient(player, "error", "กระเป๋าเต็ม ของที่ได้หล่นหาย")
		return
	end
	local item = ItemCatalog.Get(entry.item)
	Remotes.SocialNotify:FireClient(player, "info",
		("ได้ %s x%d"):format(item and item.name or entry.item, count))
end

local function payout(player, config)
	if config.oneOf and #config.oneOf > 0 then
		give(player, config.oneOf[math.random(1, #config.oneOf)])
	end
	for _, entry in ipairs(config.rewards or {}) do
		give(player, entry)
	end
	if config.xp and config.xp > 0 then
		Progression.AwardExp(player, config.xp)
	end
end

--------------------------------------------------------------------------------
-- One attempt
--------------------------------------------------------------------------------

-- Is anybody around to catch you? Five players, or one guard, as the user set it. See FarmConfig for why.
-- Whether the PRESSER is allowed is a separate question, asked in work() -- this one is only about the room.
--
-- Counted fresh on every press rather than cached: both halves of it change while a node sits there, and a
-- cached answer would either lock a spot that has filled up or open one that has emptied out.
--
-- **บนเกาะฟาร์มมิ่งใช้กฎคนละชุด** (ผู้ใช้กำหนด 2026-09-22): ทำคนเดียวได้เลย ไม่ต้องรอให้ครบ 5 คน
-- แต่ **จุดละครั้งเดียวต่อวัน** แทนคูลดาวน์ 30 นาที
--
-- เหตุผลที่กฎเดิมใช้ที่นั่นไม่ได้: เกาะเป็นเซิร์ฟส่วนตัวรายคน หัวนับจึงเป็น 1 เสมอ และไม่มีทหารยามมาเดินเล่น
-- ในเกาะของคนอื่นได้ — ซื้อของ 18,000 มาวางแล้วกดไม่ได้ตลอดกาล
--
-- ที่เลือก "วันละครั้ง" ไม่ใช่ "คูลดาวน์ 30 นาที" เพราะ 30 นาทีบนเซิร์ฟที่ไม่มีใครมาจับ = เครื่องพิมพ์เงิน
-- ที่เดินทั้งวัน · วันละครั้งยังคุ้มกับการซื้อ แต่ไม่ล้มเศรษฐกิจของเกมหลักที่ของพวกนี้ไหลไปรวมกัน
local function serverAllowsFarming()
	if ServerConfig.IsFarm then return true end
	if #Players:GetPlayers() >= FarmConfig.MinPlayers then return true end
	if FarmConfig.OrClass then
		for _, other in ipairs(Players:GetPlayers()) do
			if Classes.Has(other, FarmConfig.OrClass) then return true end
		end
	end
	return false
end

-- บนเกาะ: จุดนี้ทำไปแล้ววันนี้หรือยัง
--
-- **เก็บในโปรไฟล์ ไม่ใช่ในหน่วยความจำเซิร์ฟเวอร์** เกาะส่วนตัวปิดทุกครั้งที่เจ้าของออก ถ้าเก็บใน
-- หน่วยความจำ ออกแล้วเข้าใหม่ = รีเซ็ตทันที ซึ่งเท่ากับไม่มีลิมิตเลย
--
-- ใช้ `QuestConfig.DayNumber()` ตัวเดียวกับบอร์ดเควส — **ห้ามคำนวณวันเองที่อื่น** (กติกาเดิมของโปรเจ็ค)
-- วันพลิกเที่ยงคืนไทยพร้อมกันทั้งเกม
local QuestConfig = require(game.ReplicatedStorage.QuestConfig)

local function islandDoneToday(player, node, mark)
	local data = ProfileAccess.Get(player)
	if not data then return false end
	local day = QuestConfig.DayNumber()
	local done = data.FarmDone
	if type(done) ~= "table" or done.day ~= day then
		done = { day = day, keys = {} }
		data.FarmDone = done
	end
	done.keys = done.keys or {}
	-- กุญแจ = ชนิดของจุด ไม่ใช่ตัวโมเดล — ย้ายของหรือเก็บแล้ววางใหม่ต้องไม่รีเซ็ตสิทธิ์
	local key = node.Name
	if mark then done.keys[key] = true end
	return done.keys[key] == true
end

local function work(node, player)
	local config = configFor(node)
	if not config then return end

	-- Nothing but crawling, while crawling -- the same rule the gathering nodes follow.
	if Vitals.IsDowned(player) then return end
	-- The guard is the one person who can never work a spot, whoever else is in the server. Asked before the
	-- headcount on purpose: a guard on a busy server would otherwise be waved through by the crowd and never
	-- learn that the class is the reason.
	if FarmConfig.OrClass and Classes.Has(player, FarmConfig.OrClass) then
		return Remotes.SocialNotify:FireClient(player, "error", FarmConfig.BannedMessage)
	end
	-- แขกที่มาเยี่ยมเกาะแตะของผิดกฎหมายของเจ้าบ้านไม่ได้ (ผู้ใช้สั่ง 2026-09-23)
	-- เช็คก่อนหัวนับ เพราะข้อความ "ต้องมีคนให้ครบ" ตอบผิดคำถามสำหรับแขก
	if not IslandAccess.MayUseFixtures(player) then
		return Remotes.SocialNotify:FireClient(player, "error", IslandAccess.FixtureDenied)
	end
	if not serverAllowsFarming() then
		return Remotes.SocialNotify:FireClient(player, "error",
			FarmConfig.ClosedMessage:format(FarmConfig.MinPlayers))
	end
	-- บนเกาะ: วันละครั้งต่อชนิด (แทนคูลดาวน์ 30 นาทีของเกมหลัก)
	if ServerConfig.IsFarm and islandDoneToday(player, node, false) then
		return Remotes.SocialNotify:FireClient(player, "error",
			"วันนี้ใช้ไปแล้ว — บนเกาะทำได้วันละครั้งต่อจุด")
	end
	if StatusEffects.IsDizzy(player) then
		return Remotes.SocialNotify:FireClient(player, "error", "ยังมึนอยู่ รอสักครู่")
	end
	-- One game at a time. Without this, two prompts pressed in the same second would each start an arrow
	-- sequence and the first keypress would answer both.
	if Minigames.IsBusy(player) then return end

	local left = remaining(node)
	if left > 0 then
		return Remotes.SocialNotify:FireClient(player, "error",
			("ยังใช้ไม่ได้ อีก %d:%02d"):format(math.floor(left / 60), math.floor(left % 60)))
	end

	-- Spent BEFORE anything else happens. The user's rule, and it is also what stops two players finishing
	-- the same press on the same frame and both being paid for it.
	--
	-- สิทธิ์รายวันบนเกาะปั๊มตรงนี้ด้วยเหตุผลเดียวกันเป๊ะ — ปั๊มตอนจ่ายรางวัลแทนจะเปิดช่องให้กดรัวๆ
	-- ระหว่างที่มินิเกมยังไม่จบ แล้วได้ของหลายรอบในวันเดียว
	if ServerConfig.IsFarm then islandDoneToday(player, node, true) end
	ReadyAt[node] = os.clock() + FarmConfig.CooldownSeconds
	publishCooldown(node, FarmConfig.CooldownSeconds)
	setPrompts(node, false)
	task.delay(FarmConfig.CooldownSeconds, function()
		if node.Parent then
			ReadyAt[node] = nil
			publishCooldown(node, nil)
			setPrompts(node, true)
		end
	end)

	local stopAnimation = playSearchAnimation(player)
	playSearch(node)

	task.delay(FarmConfig.SearchSeconds, function()
		stopAnimation()
		if not player.Parent then return end
		-- Went down during the rummage. The spot is still spent -- it was pressed -- but there is no game to
		-- play from the floor.
		if Vitals.IsDowned(player) then return end

		Minigames.Run(player, {
			kind = "arrows",
			length = config.sequence,
			title = ("%s%s"):format(config.prompt or "ทำงาน", config.object and (" · " .. config.object) or ""),
		}, function(success)
			if not player.Parent then return end
			if success then
				payout(player, config)
			else
				StatusEffects.Dizzy(player, FarmConfig.DizzySeconds)
				-- หัวแดง 3 นาทีเมื่อทำควิกไทม์อีเวนต์พลาด ตามที่ผู้ใช้สั่ง — ของผิดกฎหมายที่ทำพลาดคือการ
				-- ถูกจับได้ ไม่ใช่แค่เสียของ
				Classes.Mark(player, ClassConfig.MarkedSecondsQte)
				Remotes.SocialNotify:FireClient(player, "error", "พลาด! มึนหัวไปพักหนึ่ง หัวแดง 3 นาที")
			end
		end)
	end)
end

--------------------------------------------------------------------------------
-- Wiring nodes up
--------------------------------------------------------------------------------

local function register(node)
	local config, kind = configFor(node)
	if not config then
		warn(("[IllegalFarm] %s is tagged %s but its FarmKind (%s) is not in FarmConfig")
			:format(node:GetFullName(), TAG, tostring(kind)))
		return
	end

	local anchor = anchorOf(node)
	if not anchor then return end
	if anchor:FindFirstChild("FarmPrompt") then return end

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "FarmPrompt"
	prompt.ActionText = config.prompt or "ทำงาน"
	prompt.ObjectText = config.object or kind
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.MaxActivationDistance = FarmConfig.Range
	-- No hold: the wait is the rummage and then the minigame, and a hold on top of both would be a third
	-- thing to sit through before anything happens.
	prompt.HoldDuration = 0
	prompt.RequiresLineOfSight = false
	prompt.Parent = anchor

	prompt.Triggered:Connect(function(player)
		work(node, player)
	end)

	-- A node tagged while its cooldown is still published (a rerun of the mapgen phase, say) keeps it.
	local readyAt = node:GetAttribute("FarmReadyAt")
	if type(readyAt) == "number" and readyAt > workspace:GetServerTimeNow() then
		ReadyAt[node] = os.clock() + (readyAt - workspace:GetServerTimeNow())
		prompt.Enabled = false
	end
end

for _, node in ipairs(CollectionService:GetTagged(TAG)) do
	task.spawn(register, node)
end
CollectionService:GetInstanceAddedSignal(TAG):Connect(function(node)
	task.spawn(register, node)
end)

CollectionService:GetInstanceRemovedSignal(TAG):Connect(function(node)
	ReadyAt[node] = nil
end)

Players.PlayerRemoving:Connect(function(player)
	-- A game left running for someone who has gone would sit in Minigames until its own timeout; ending it
	-- now frees the entry immediately.
	Minigames.Cancel(player)
end)
