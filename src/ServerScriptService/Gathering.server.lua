-- Gathering.server.lua: chopping trees, breaking rocks, and everything else tagged as a gathering node.
--
-- Nodes are found by TAG. Anything tagged WOLD_Node with a NodeKind attribute naming an entry in
-- GatherConfig.Nodes becomes gatherable, wherever it came from -- a mapgen phase, a model the user dragged
-- in, or a part they built by hand. Neither side has to know about the other, which is the whole point:
-- the map can be rearranged freely without touching this file.
--
-- The prompt lives on the node and is built HERE, on the server, rather than per-client. A gathering node
-- is the same for everybody -- unlike a class action, whose buttons depend on who is looking -- and a
-- spent node has to look spent to the whole server, which a client-built prompt could not guarantee.
local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ServerConfig = require(game.ServerScriptService.ServerConfig)

if ServerConfig.IsLobby then return end

local GatherConfig = require(game.ReplicatedStorage.GatherConfig)
-- เจ้าของคำว่า "วันนี้" ของทั้งเกม (เที่ยงคืนเวลาไทย) — จุดเก็บรายวันบนเกาะใช้ตัวเดียวกับบอร์ดเควส
local QuestConfig = require(game.ReplicatedStorage.QuestConfig)
local ItemCatalog = require(game.ReplicatedStorage.ItemCatalog)
local Inventory = require(game.ServerScriptService.Inventory)
local Vitals = require(game.ServerScriptService.Vitals)
local ClassPerks = require(game.ServerScriptService.ClassPerks)
local Progression = require(game.ServerScriptService.Progression)
local Remotes = require(game.ReplicatedStorage.Remotes)

local TAG = "WOLD_Node"

-- Which item satisfies each `tool` value, by the name the player sees on it. Derived from the catalog
-- rather than typed out again, so renaming an item renames it here too.
local TOOL_NAMES = {}
for _, item in pairs(ItemCatalog.Items) do
	if item.gathers then TOOL_NAMES[item.gathers] = item.name end
end

-- [node] = os.clock() when it becomes available again. A deadline rather than a timer per node, so a
-- thousand trees cost one table entry each and no running tasks.
local SpentUntil = {}

--------------------------------------------------------------------------------

local function configFor(node)
	local kind = node:GetAttribute("NodeKind")
	return kind and GatherConfig.Nodes[kind], kind
end

-- Where the prompt should hang. A prompt on a Model does nothing -- it needs a BasePart -- but which part
-- matters enormously, because a ProximityPrompt measures its range from that PART's origin.
--
-- Taking the first part found put the prompt on a tree's trunk mesh, whose origin sits in the MIDDLE of a
-- 45-stud trunk: measured 13 to 22 studs above the ground on real trees. Against a 10-stud range that made
-- most trees literally unreachable -- a player standing at the base was 18.9 studs from the prompt.
--
-- So the prompt gets its own small invisible part, planted at the model's base. It is the only way to be
-- sure the range is measured from where the player actually stands, whatever shape the model is.
local function anchorOf(node)
	if node:IsA("BasePart") then return node end
	if not node:IsA("Model") then return nil end

	local existing = node:FindFirstChild("GatherAnchor")
	if existing then return existing end

	-- The base: the lowest point of the visible geometry, at the model's own centre in plan.
	--
	-- ⚠️ **`Position.Y - Size.Y/2` คือก้นของชิ้นที่ไม่ถูกหมุนเท่านั้น** — โมเดลต้นไม้จาก Creator Store
	-- ทุกต้นเป็น MeshPart ที่ **นอนตะแคง** (`CFrame.UpVector.Y = 0`) ความยาวจริงในแนวดิ่งจึงอยู่ที่
	-- `Size.Z` ไม่ใช่ `Size.Y` · วัดในเพลสแล้ว: ต้นสนสูง 35.6 สตัด ได้ปุ่มลอยอยู่ **16.4 สตัดเหนือพื้น**
	-- ซึ่งเกินระยะกด 10 = **ตัดไม่ได้เลย** (ผู้ใช้แจ้ง 2026-09-23 "ต้นไม้บางต้นสูงเกินจนตัดไม่ได้")
	-- ต้นโอ๊กรอดมาเพราะเตี้ยกว่า ปุ่มลอย 3.7-5.4 ซึ่งยังพอเอื้อมถึง — บังเอิญ ไม่ใช่เพราะถูก
	--
	-- สูตรกล่องครอบของชิ้นที่ถูกหมุน: ฉายครึ่งขนาดของทั้งสามแกนลงแกน Y แล้วรวมกัน
	local function bottomOf(part)
		local cf, size = part.CFrame, part.Size
		local reach = 0.5 * (math.abs(cf.RightVector.Y) * size.X
			+ math.abs(cf.UpVector.Y) * size.Y
			+ math.abs(cf.LookVector.Y) * size.Z)
		return cf.Position.Y - reach
	end

	local low, minX, maxX, minZ, maxZ = math.huge, math.huge, -math.huge, math.huge, -math.huge
	for _, d in ipairs(node:GetDescendants()) do
		if d:IsA("BasePart") and d.Transparency < 0.9 then
			low = math.min(low, bottomOf(d))
			minX, maxX = math.min(minX, d.Position.X), math.max(maxX, d.Position.X)
			minZ, maxZ = math.min(minZ, d.Position.Z), math.max(maxZ, d.Position.Z)
		end
	end
	if low == math.huge then
		return node.PrimaryPart or node:FindFirstChildWhichIsA("BasePart", true)
	end

	local anchor = Instance.new("Part")
	anchor.Name = "GatherAnchor"
	anchor.Size = Vector3.new(1, 1, 1)
	anchor.Position = Vector3.new((minX + maxX) / 2, low + 2, (minZ + maxZ) / 2)
	anchor.Transparency = 1
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Parent = node

	-- ของที่เดินได้ (สัตว์ฟาร์ม) ต้องพาปุ่มไปด้วย — จุดแขวนที่ปักไว้กับที่จะถูกทิ้งไว้ตรงที่มันเกิด
	-- ขณะที่ตัวมันเดินเล่นไปยี่สิบสตัด แล้วผู้เล่นที่เดินไปหาวัวก็ไม่เจอปุ่ม (วัดได้: ครึ่งฝูงอยู่ห่าง
	-- จากปุ่มตัวเองเกิน 6 สตัดภายในหกวินาทีแรก) เชื่อมกับตัวมันแทน ระดับพื้นเหมือนเดิม
	local humanoid = node:FindFirstChildOfClass("Humanoid")
	local root = humanoid and (humanoid.RootPart or node:FindFirstChild("HumanoidRootPart"))
	if root then
		anchor.Position = Vector3.new(root.Position.X, anchor.Position.Y, root.Position.Z)
		anchor.Anchored = false
		anchor.Massless = true
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = root
		weld.Part1 = anchor
		weld.Parent = anchor
	end
	return anchor
end

-- Does this player hold the tool this node needs? Reads the EQUIPPED weapon rather than the whole bag: a
-- pickaxe in the bag is not a pickaxe in your hands, and requiring it to be equipped is what makes the
-- gathering tools worth a slot.
local function hasTool(player, needed)
	if not needed then return true end
	local _, slot = Inventory.EquippedWeapon(player)
	local entry = slot and ItemCatalog.Get(slot.id)
	return entry ~= nil and entry.gathers == needed
end

-- **จุดที่เก็บได้วันละครั้ง** (ผู้ใช้สั่ง 2026-09-23 สำหรับของตกแต่งชุดใหม่บนเกาะ)
--
-- ⚠️ **ใช้ `QuestConfig.DayNumber()` ซึ่งเป็นเจ้าของคำว่า "วันนี้" ของทั้งเกม** (เที่ยงคืนเวลาไทย)
-- ห้ามคำนวณวันเองที่นี่ ไม่งั้นบอร์ดเควสกับของตกแต่งจะข้ามวันคนละนาที
--
-- เก็บเป็น **แอตทริบิวต์บนตัวโหนด** ไม่ใช่ตารางในหน่วยความจำ — มันจึงรอดข้ามการรีสตาร์ท
-- (ต่างจากคูลดาวน์ปกติที่เป็น `task.delay` ซึ่งตายไปกับเซิร์ฟเวอร์เก่า)
local Daily = {} -- [node] = true · เฉพาะจุดรายวัน จะได้ไม่ต้องวนโหนดสองหมื่นจุดของแมพหลัก
local function dailyBlocked(node)
	return node:GetAttribute("DailyNode") == true
		and node:GetAttribute("HarvestedDay") == QuestConfig.DayNumber()
end

local function isSpent(node)
	if dailyBlocked(node) then return true end

	-- **แอตทริบิวต์ `Spent` มาก่อนเสมอ** (แก้ 2026-09-22: ซื้อสัตว์มาแล้วเก็บได้ทันทีทั้งที่ยังไม่โต)
	--
	-- ระบบอื่นตั้งธงนี้เพื่อบอกว่า "ยังเก็บไม่ได้" โดยไม่ผ่านคูลดาวน์ของไฟล์นี้ — `IslandZones` ตั้งให้
	-- สัตว์ที่เพิ่งเกิดจนกว่า `ReadyAt` จะถึง · ของเดิมอ่านแต่ตาราง `SpentUntil` ของตัวเอง ธงจึงถูก
	-- มองข้ามทั้งหมด แล้วสัตว์แรกเกิดก็ถูกรีดนมได้ทันที
	--
	-- อ่านจาก **ตัวโหนด** ไม่ใช่จากตารางในหน่วยความจำ = ใครตั้งก็ได้ผลเหมือนกันหมด
	if node:GetAttribute("Spent") then return true end

	local until_ = SpentUntil[node]
	if not until_ then return false end
	if os.clock() >= until_ then
		SpentUntil[node] = nil
		return false
	end
	return true
end

-- A spent node is dimmed and its prompt switched off, so the whole server can see it has been taken
-- rather than walking up to a prompt that refuses. Transparency is remembered per part, because a node
-- may be a model of parts that were not all opaque to begin with.
local Faded = {} -- [node] = { [part] = originalTransparency }

local function setSpent(node, spent)
	-- Both prompts: the gather one and the auto-farm one. FindFirstChildWhichIsA returns only the first,
	-- which would have left the F prompt lit on a node that was already taken.
	for _, d in ipairs(node:GetDescendants()) do
		if d:IsA("ProximityPrompt") and GatherConfig.OwnPrompts[d.Name] then d.Enabled = not spent end
	end
	-- Published so the client can tell "taken by someone else" from "hidden because you hold the wrong
	-- tool". Without it the auto-farm would keep walking to a node that is already gone, and the client's
	-- own prompt hiding would fight the server over Enabled.
	node:SetAttribute("Spent", spent or nil)

	-- **ของเรืองแสงบนเกาะ** (ผู้ใช้สั่ง 2026-09-23) — ทอยตอนโหนด "เริ่มรอบใหม่" ซึ่งก็คือตรงนี้:
	-- คูลดาวน์หมด · ตราวันใหม่ปลดให้ · `IslandZones` ปลดสัตว์ตอนเซิร์ฟบูต — ทุกทางเดินผ่าน `setSpent`
	-- เสมอ จึงไม่ต้องไปไล่ทอยทีละที่ให้เพี้ยนกันเอง
	if not spent and ServerConfig.IsFarm then
		local IslandConfig = require(game.ReplicatedStorage.IslandConfig)
		node:SetAttribute("Glow", IslandConfig.RollGlow())
	end

	-- สัตว์เลี้ยงไม่จาง: มันยังยืนอยู่ตรงนั้นจริงๆ แค่รีดนม/เก็บไข่ซ้ำไม่ได้ชั่วคราว
	--
	-- การทำให้จางเหมาะกับก้อนแร่ที่ "ถูกขุดไปแล้ว" แต่วัวที่โปร่งแสงครึ่งตัวจะดูเหมือนผี
	-- ปุ่ม E ที่ดับไปคือสัญญาณเดียวที่ต้องการแล้ว
	if node:GetAttribute("NoFade") then return end

	if spent then
		if Faded[node] then return end
		local originals = {}
		for _, d in ipairs(node:GetDescendants()) do
			-- Skip the invisible prompt anchor: fading it would make a floating white cube appear.
			if d:IsA("BasePart") and d.Name ~= "GatherAnchor" then
				originals[d] = d.Transparency
				d.Transparency = math.min(0.85, d.Transparency + 0.65)
			end
		end
		if node:IsA("BasePart") then
			originals[node] = node.Transparency
			node.Transparency = math.min(0.85, node.Transparency + 0.65)
		end
		Faded[node] = originals
	else
		local originals = Faded[node]
		if not originals then return end
		for part, transparency in pairs(originals) do
			if part.Parent then part.Transparency = transparency end
		end
		Faded[node] = nil
	end
end

--------------------------------------------------------------------------------
-- The sound of the work
--------------------------------------------------------------------------------

-- Played AT the node, so everyone nearby hears where the chopping is. Driven from the server rather than
-- the client for the same reason the prompt is: a strike is a thing happening in the world, and the player
-- swinging is not the only one who should hear it.
local function playStrike(node, config)
	local anchor = node:FindFirstChild("GatherAnchor") or node.PrimaryPart
		or node:FindFirstChildWhichIsA("BasePart", true)
	if not anchor or not config.sound then return end
	local sound = Instance.new("Sound")
	sound.SoundId = config.sound
	sound.Volume = GatherConfig.HitVolume
	sound.RollOffMaxDistance = GatherConfig.HitDistance
	-- A little variation so a long chop does not sound like a machine.
	sound.PlaybackSpeed = 1 + (math.random() - 0.5) * 0.12
	sound.Parent = anchor
	sound:Play()
	Debris:AddItem(sound, 4)
end

-- One strike per interval for as long as the hold lasts. Stopped by the hold ending, however it ends --
-- released early, completed, or the player walking out of range.
local Striking = {} -- [player] = true while a hold is running

local function startStriking(node, player, config)
	if Striking[player] then return end
	Striking[player] = true
	task.spawn(function()
		while Striking[player] do
			playStrike(node, config)
			-- Checked again after the wait: the hold usually ends during it.
			local elapsed = 0
			while elapsed < GatherConfig.HitInterval do
				if not Striking[player] then return end
				task.wait(0.1)
				elapsed += 0.1
			end
		end
	end)
end

local function stopStriking(player)
	Striking[player] = nil
end

--------------------------------------------------------------------------------
-- Gathering
--------------------------------------------------------------------------------

local function gather(node, player)
	-- Nothing but crawling, while crawling. A player on their hands and knees with the last of their blood
	-- draining should not be chopping a tree, and both prompts -- the manual one and the auto-farm -- come
	-- through here, so one check covers both.
	if Vitals.IsDowned(player) then return end

	local config = configFor(node)
	if not config then return end
	if isSpent(node) then return end

	if not hasTool(player, config.tool) then
		-- Name the tool. "Wrong tool" leaves the player to guess which of three it wants, and the whole
		-- point of the gate is to send them to the shop for a specific thing.
		local needed = TOOL_NAMES[config.tool] or config.tool
		Remotes.SocialNotify:FireClient(player, "error", ("ต้องถือ%sก่อน"):format(needed))
		return
	end

	-- Marked spent BEFORE anything is given, so two players finishing the same hold on the same frame
	-- cannot both be paid for it.
	-- **คูลดาวน์ต่อจุดได้** แอตทริบิวต์ `RespawnSeconds` บนตัวโหนดชนะค่ากลาง — ของตกแต่งบนเกาะ
	-- (หิน/ต้นไม้ที่ซื้อมาวาง) ใช้ 30 นาทีตามที่ผู้ใช้กำหนด ส่วนจุดในแมพหลักไม่มีแอตทริบิวต์นี้
	-- จึงยังเป็น 60 วินาทีเท่าเดิมทุกจุด
	-- จุดรายวัน: ปั๊มวันที่เก็บไว้บนตัวโหนด แล้วให้คูลดาวน์ยาวไปถึงเช้าวันใหม่
	local respawn = node:GetAttribute("RespawnSeconds") or GatherConfig.RespawnSeconds
	if node:GetAttribute("DailyNode") then
		node:SetAttribute("HarvestedDay", QuestConfig.DayNumber())
		local day = QuestConfig.RerollSeconds
		local into = (os.time() + QuestConfig.TimeZoneOffsetSeconds) % day
		respawn = day - into -- เหลือกี่วินาทีถึงวันใหม่
	end
	SpentUntil[node] = os.clock() + respawn
	-- ประกาศเวลาที่เก็บได้อีกครั้งไว้บนตัวโหนด เพื่อให้ระบบอื่นเขียนป้ายนับถอยหลังได้โดยไม่ต้องรู้จัก
	-- ตาราง `SpentUntil` ที่เป็นของไฟล์นี้คนเดียว (คอกสัตว์บนเกาะใช้อยู่) · `os.time` ไม่ใช่ `os.clock`
	-- เพราะอีกฝั่งเทียบกับนาฬิกาเดียวกับ `ReadyAt`
	node:SetAttribute("ReadyAgainAt", os.time() + respawn)
	setSpent(node, true)

	-- เก็บแล้วหายไปเลย ไม่ใช่ตัวเดิมยืนโปร่งแสงรอเกิดใหม่:
	--   · `HerdAnimal` — สัตว์ในฝูงแมพหลัก (AnimalHerds เติมตัวใหม่ให้เองหลัง RespawnSeconds)
	--   · `OneShot`    — จุดที่สุ่มโผล่บนผืนดินของเกาะ (ผู้ใช้สั่ง "เก็บและหายไปเลย") ไม่มีใครเติมที่เดิม
	--                    ตัวสุ่มจะไปเกิดที่ช่องใหม่แทน
	if node:GetAttribute("HerdAnimal") or node:GetAttribute("OneShot") then
		task.delay(0.15, function() if node.Parent then node:Destroy() end end)
	end

	-- ของที่จะได้ ปกติคือ config.item แต่บางจุดสุ่มได้ของอีกอย่างแทน
	--
	-- `alt` มีไว้ให้แปลงผักซึ่งผู้ใช้กำหนดว่าได้ "หนอนที่เป็นเหยื่อตกปลา หรือ ผักรวม" — เป็นของคนละชิ้น
	-- ที่ออกจากจุดเดียวกัน ไม่ใช่ของชิ้นเดียวที่จำนวนต่างกัน จึงต้องสุ่มทั้ง id และจำนวนไปด้วยกัน
	--
	-- `roll` (การขุด) มาก่อน `alt`: มันไม่ใช่ "ของหลักหรือของสำรอง" แต่เป็นตารางที่ครอบทุกผลลัพธ์อยู่แล้ว
	-- ตั้งแต่หินยันเพชร ของหลัก `config.item` เหลือเป็นแค่ตัวสำรองถ้าตารางสุ่มพลาด (ดู GatherConfig.roll)
	local itemId, minCount, maxCount = config.item, config.min, config.max
	if config.roll then
		-- หารด้วยผลรวมจริง ไม่ใช่สมมติว่าเป็น 1 พอดี — ตารางถูกประกอบจากการหารเศษ ผลบวกทศนิยมจึง
		-- อาจขาดไปเศษเสี้ยว และการสุ่มที่ตกร่องนั้นจะเงียบๆ คืนของผิดทุกครั้งที่เกิด
		local total = 0
		for _, entry in ipairs(config.roll) do total += entry.chance end
		local pick = math.random() * total
		local chosen = config.roll[#config.roll]
		for _, entry in ipairs(config.roll) do
			pick -= entry.chance
			if pick <= 0 then
				chosen = entry
				break
			end
		end
		itemId, minCount, maxCount = chosen.item, chosen.min, chosen.max
	elseif config.alt and math.random() < (config.alt.chance or 0.5) then
		itemId = config.alt.item
		minCount = config.alt.min or minCount
		maxCount = config.alt.max or maxCount
	end

	-- **จำนวนต่อจุดได้** แอตทริบิวต์ `YieldMin`/`YieldMax` บนตัวโหนดชนะค่ากลาง — ทรงเดียวกับ
	-- `RespawnSeconds` ข้างบน · สัตว์ในคอกบนเกาะใช้ตัวนี้ให้ของมากกว่าฝูงในแมพหลัก เพราะมันต้องซื้อ
	-- ด้วยเงิน ส่วนฝูงในแมพหลักเดินไปเก็บฟรี — **แมพหลักไม่มีแอตทริบิวต์นี้ จึงไม่ถูกแตะเลย**
	local overMin, overMax = node:GetAttribute("YieldMin"), node:GetAttribute("YieldMax")
	if overMin and overMax then minCount, maxCount = overMin, overMax end

	local count = math.random(minCount, maxCount)

	-- **เพดานของเกาะ** (ผู้ใช้สั่ง 2026-09-23) — หนีบ **ก่อน** คูณแสง เพื่อให้แสงเป็นทางเดียวที่เกิน 5 ได้
	-- · แมพหลักไม่ถูกแตะ (ค่าที่นั่นอยู่ที่ 1-4 อยู่แล้ว แต่นี่คือเพดานที่บังคับจริง ไม่ใช่ความบังเอิญ)
	if ServerConfig.IsFarm then
		local cap = require(game.ReplicatedStorage.IslandConfig).YieldCap
		if cap then count = math.min(count, cap) end
	end

	-- **ของเรืองแสง** (เกาะเท่านั้น · ธงถูกทอยไว้ตั้งแต่โหนดเริ่มรอบนี้) ฟ้า = วัตถุดิบ ×2 · ทอง = EXP ×2
	-- คูณ **ก่อน** `AddItem` เพื่อให้กระเป๋าที่ใส่ไม่ครบปฏิเสธทั้งกอง ไม่ใช่รับครึ่งเดียวเงียบๆ
	local glow = ServerConfig.IsFarm and node:GetAttribute("Glow") or nil
	local GlowCfg = glow and require(game.ReplicatedStorage.IslandConfig).Glow or nil
	if glow == "blue" then count = math.floor(count * GlowCfg.yield + 0.5) end
	-- The merchant's sharp eye. Doubled before the bag is asked, so a full bag refuses the whole doubled
	-- amount rather than quietly handing over half of it.
	count = ClassPerks.HarvestFor(player, count)
	local given = Inventory.AddItem(player, itemId, count)
	if not given then
		Remotes.SocialNotify:FireClient(player, "error", "กระเป๋าเต็ม")
		-- Still spent: the node was struck. Letting a full bag leave it fresh would make "stand at a full
		-- bag and re-trigger" a way to hold a node against everyone else.
		return
	end

	if config.xp and config.xp > 0 then
		-- **บนเกาะ: EXP เพิ่มตามสัตว์เลี้ยงและจำนวนของตกแต่ง** (ผู้ใช้สั่ง 2026-09-22)
		-- ตัวคูณอยู่กับ `IslandPets` ซึ่งเป็นเจ้าของคำถาม "ตอนนี้เกาะมีอะไรอยู่บ้าง" — ไฟล์นี้แค่ถาม
		-- นอกเพลสเกาะ ช่องนี้เป็น nil ตัวคูณจึงเป็น 1 และเกมหลักไม่เปลี่ยนแปลงอะไรเลย
		local xp = config.xp
		if glow == "gold" then xp = math.floor(xp * GlowCfg.exp + 0.5) end
		local IslandAccess = ServerConfig.IsFarm
			and require(game.ServerScriptService.Island.IslandAccess) or nil
		if IslandAccess and IslandAccess.FarmExpMultiplier then
			xp = math.floor(xp * IslandAccess.FarmExpMultiplier() + 0.5)
		end
		Progression.AwardExp(player, xp)
	end

	-- เครื่องมือสึกครั้งละ 1 ทุกครั้งที่เก็บสำเร็จ (ผู้ใช้กำหนด) เฉพาะจุดที่ต้องใช้เครื่องมือ — เก็บไข่ด้วยมือ
	-- เปล่าไม่มีอะไรให้สึก ของนักประดิษฐ์ไม่สึกเหมือนอาวุธ
	if config.tool and not ClassPerks.Has(player, "weaponNeverBreaks") then
		Inventory.WearEquipped(player, 1)
	end

	-- ของแถม (`bonus`): ได้ **เพิ่ม** จากของหลัก ไม่ใช่ **แทน** อย่าง `alt` — ตอนนี้คือเศษหินจากสายแร่
	--
	-- แจกทีหลังของหลักเสมอ และกระเป๋าเต็มตรงนี้ไม่ใช่ความล้มเหลว: การขุดสำเร็จไปแล้ว ของหลักอยู่ในมือแล้ว
	-- ของแถมที่ใส่ไม่ลงจึงหายไปเงียบๆ ไม่ใช่ขึ้น "กระเป๋าเต็ม" สีแดงให้คนที่เพิ่งขุดได้ตกใจเล่น
	local bonusId, bonusCount = nil, nil
	local bonus = config.bonus
	if bonus and math.random() < (bonus.chance or 0.25) then
		local amount = ClassPerks.HarvestFor(player, math.random(bonus.min or 1, bonus.max or 1))
		if glow == "blue" then amount = math.floor(amount * GlowCfg.yield + 0.5) end
		if Inventory.AddItem(player, bonus.item, amount) then
			bonusId, bonusCount = bonus.item, amount
		end
	end

	local item = ItemCatalog.Get(itemId)
	local text = ("ได้ %s x%d"):format(item and item.name or itemId, count)
	if bonusId then
		local extra = ItemCatalog.Get(bonusId)
		text ..= (" + %s x%d"):format(extra and extra.name or bonusId, bonusCount)
	end
	Remotes.SocialNotify:FireClient(player, "info", text)

	task.delay(respawn, function()
		if node.Parent then setSpent(node, false) end
	end)
	-- ทางออกอื่นทุกทาง `return` เปล่า (ยังไม่ถึงเวลา / ไม่มีเครื่องมือ / กระเป๋าเต็ม) — บอกว่า "สำเร็จ"
	-- ให้ `GatherAccess.Gather` เอาไปใช้ได้ ปุ่มที่เรียกมาไม่ได้สนใจค่านี้อยู่แล้ว
	return true
end

--------------------------------------------------------------------------------
-- Wiring nodes up
--------------------------------------------------------------------------------

-- Declared ahead of `register`, which calls it, because it is defined below alongside the rest of the
-- per-player visibility handling.
local publishRequirementLater

local function register(node)
	local config, kind = configFor(node)
	if not config then
		warn(("[Gathering] %s is tagged %s but its NodeKind (%s) is not in GatherConfig")
			:format(node:GetFullName(), TAG, tostring(kind)))
		return
	end

	local anchor = anchorOf(node)
	if not anchor then return end
	if anchor:FindFirstChild("GatherPrompt") then return end -- already wired

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "GatherPrompt"
	prompt.ActionText = config.prompt or "เก็บ"
	prompt.ObjectText = config.object or kind
	-- E for a normal gather; F is the auto-farm toggle and is handled on the client, not by a prompt.
	-- E is shared with the chest, the shopkeeper and the class actions, which is fine: those are prompts
	-- on different objects, and Roblox offers whichever is nearest.
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.MaxActivationDistance = GatherConfig.Range
	prompt.HoldDuration = config.seconds or 2
	prompt.RequiresLineOfSight = false
	-- **โหนดที่ติดธง `Spent` มาก่อนแล้วต้องเกิดมาพร้อมปุ่มที่ปิดอยู่** (แก้ 2026-09-22)
	--
	-- `setSpent` เป็นตัวเดียวที่เคยปิดปุ่ม ซึ่งครอบคลุมเฉพาะโหนดที่ "เพิ่งถูกเก็บไป" — แต่สัตว์ที่
	-- `IslandZones` เพิ่งให้เกิดติดธงมาตั้งแต่ต้นโดยไม่เคยผ่าน `setSpent` เลย ปุ่มจึงเปิดค้าง
	-- แล้วรีดนมลูกไก่แรกเกิดได้ทันที
	-- จุดรายวันที่เก็บไปแล้ววันนี้ ต้องเกิดมาพร้อมปุ่มที่ปิดอยู่ด้วย (แอตทริบิวต์รอดข้ามรีสตาร์ท)
	if node:GetAttribute("DailyNode") then Daily[node] = true end
	prompt.Enabled = not (node:GetAttribute("Spent") or dailyBlocked(node))
	prompt.Parent = anchor
	publishRequirementLater(node)

	-- The strike sound runs for as long as the hold does, on whichever way it ends.
	prompt.PromptButtonHoldBegan:Connect(function(player)
		startStriking(node, player, config)
	end)
	prompt.PromptButtonHoldEnded:Connect(function(player)
		stopStriking(player)
	end)

	prompt.Triggered:Connect(function(player)
		stopStriking(player)
		gather(node, player)
	end)

	-- A second prompt for auto-farm, so the F key is VISIBLE. The first version bound F on the client with
	-- nothing on screen to say so, and a key nobody is told about may as well not exist -- the user pressed
	-- it and reasonably concluded it was broken.
	--
	-- The server only draws it. Firing it tells the client to toggle its own loop, which is where auto-farm
	-- has to live: it drives the local character's movement.
	-- **ของตกแต่งบนเกาะไม่มีปุ่มฟาร์มออโต้**
	--
	-- ฟาร์มออโต้มีไว้เดินไล่เก็บโหนดหลายพันจุดในแมพหลัก บนเกาะมีก้อนหินที่ซื้อมาวางไม่กี่ก้อน
	-- ซึ่งไม่มีอะไรให้ไล่ · และมันใช้ **F ชนกับปุ่มเก็บของคืนกระเป๋า** ของระบบเกาะพอดี
	-- (วัดในเพลสแล้ว: ก้อนหินตกแต่งมี PickupPrompt[F] + GatherPrompt[E] + AutoFarmPrompt[F])
	if node:GetAttribute("Uid") then return end
	local auto = Instance.new("ProximityPrompt")
	auto.Name = "AutoFarmPrompt"
	auto.ActionText = "ฟาร์มออโต้"
	auto.ObjectText = config.object or kind
	auto.KeyboardKeyCode = Enum.KeyCode.F
	auto.MaxActivationDistance = GatherConfig.Range
	auto.HoldDuration = 0
	auto.RequiresLineOfSight = false
	-- Under the gather prompt rather than over it, so [E] reads first.
	auto.UIOffset = Vector2.new(0, 44)
	-- ปุ่มฟาร์มออโต้ต้องเกิดมาปิดเหมือนปุ่มเก็บ ไม่งั้นสัตว์แรกเกิดยังมีปุ่ม F ค้างให้กด
	auto.Enabled = not node:GetAttribute("Spent")
	auto.Parent = anchor

	auto.Triggered:Connect(function(player)
		Remotes.ToggleAutoFarm:FireClient(player)
	end)
end

--------------------------------------------------------------------------------
-- Showing the prompt only to someone holding the right tool
--------------------------------------------------------------------------------

-- A ProximityPrompt is one object shared by the whole server: it cannot be shown to one player and hidden
-- from another. What CAN be done is decide it per player on the client, which is what GatherController
-- does -- it reads the node's RequiredTool attribute and hides prompts it cannot use.
--
-- The attribute is published here rather than looked up in GatherConfig by the client, so a node whose
-- kind is renamed carries its own answer with it.
function publishRequirementLater(node)
	local config = configFor(node)
	if config then node:SetAttribute("RequiredTool", config.tool) end
end

-- ประตูให้ระบบอื่น/เทสสั่งเก็บเกี่ยวได้ — กด ProximityPrompt จากสคริปต์ไม่ได้ (ดู GatherAccess)
require(game.ServerScriptService.GatherAccess).Gather = function(player, node)
	return gather(node, player)
end

for _, node in ipairs(CollectionService:GetTagged(TAG)) do
	task.spawn(register, node)
end
CollectionService:GetInstanceAddedSignal(TAG):Connect(function(node)
	task.spawn(register, node)
end)

CollectionService:GetInstanceRemovedSignal(TAG):Connect(function(node)
	SpentUntil[node] = nil
	Faded[node] = nil
	Daily[node] = nil
end)

-- **ปลดจุดรายวันเมื่อวันพลิก** — `task.delay` ที่ตั้งไว้ตอนเก็บตายไปกับเซิร์ฟเวอร์เก่า จุดที่เก็บไป
-- เมื่อวานจึงต้องมีคนมาปลดให้ตอนบูตใหม่ · วนเฉพาะตาราง `Daily` ไม่ใช่โหนดสองหมื่นจุดของแมพหลัก
task.spawn(function()
	while true do
		task.wait(60)
		for node in pairs(Daily) do
			if not node.Parent then
				Daily[node] = nil
			elseif node:GetAttribute("HarvestedDay") and not dailyBlocked(node) then
				node:SetAttribute("HarvestedDay", nil)
				setSpent(node, false)
			end
		end
	end
end)

Players.PlayerRemoving:Connect(function(player)
	-- A spent node belongs to the server rather than to whoever took it, so nothing else is per-player --
	-- but a strike loop left running for a player who has gone would never stop.
	stopStriking(player)
end)
