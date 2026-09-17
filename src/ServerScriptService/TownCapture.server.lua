-- TownCapture.server.lua: ยึดเมืองด้วยการกดค้างที่อนุสาวรีย์
--
-- **คูลดาวน์ 12 ชั่วโมงนับจากเวลาจริง และเริ่มนับใหม่เมื่อเซิร์ฟเวอร์เปิดใหม่** ตามที่ผู้ใช้กำหนด
--
-- สองข้อนี้ขัดกันโดยธรรมชาติ: "เวลาจริง" อยากให้ผูกกับ os.time() ซึ่งข้ามเซิร์ฟเวอร์ ส่วน "รีเซ็ตเมื่อ
-- เปิดใหม่" อยากให้ผูกกับอายุเซิร์ฟเวอร์ — เก็บทั้งสองอย่าง แล้วถือว่าปลดล็อกเมื่อผ่าน **ทั้งคู่**
-- ซึ่งเป็นการอ่านที่ปลอดภัยที่สุด: ไม่มีทางที่เมืองจะถูกแย่งเร็วกว่าที่ตั้งใจ
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")

local ServerConfig = require(game.ServerScriptService.ServerConfig)
if ServerConfig.IsLobby then return end

local ClanConfig = require(game.ReplicatedStorage.ClanConfig)
local ClanStore = require(game.ServerScriptService.ClanStore)
local ClanAccess = require(game.ServerScriptService.ClanAccess)
local TownAccess = require(game.ServerScriptService.TownAccess)
local Remotes = require(game.ReplicatedStorage.Remotes)

-- เมืองทั้งหก ชื่อโมเดลตรงกับที่ผู้ใช้วางไว้
local TOWNS = {
	{ id = "Goldmeadow", name = "โกลด์เมโดว์" },
	{ id = "Stonemark", name = "สโตนมาร์ก" },
	{ id = "Saltmere", name = "ซอลต์เมียร์" },
	{ id = "Elderwood", name = "เอลเดอร์วูด" },
	{ id = "Cogsworth", name = "ค็อกส์เวิร์ธ" },
	{ id = "Astravale", name = "แอสตราเวล" },
}

local LANDMARK_PREFIX = "Landmark_"
local PROMPT_DISTANCE = 14

-- คูลดาวน์หลังยึดสำเร็จ ผู้ใช้กำหนด 12 ชั่วโมง
local COOLDOWN_SECONDS = 12 * 60 * 60

--------------------------------------------------------------------------------
-- ใครถือเมืองไหน
--------------------------------------------------------------------------------

-- เจ้าของเมืองเก็บอยู่ใน **ตัวแคลน** (clan.towns) ไม่ใช่ตารางกลางแยก
--
-- เหตุผลเดียวกับที่กุญแจรถเก็บธงไว้บนตัวกุญแจ: ถ้ามีตารางกลาง มันจะไม่ตรงกับความจริงได้ — แคลนถูกลบ
-- แต่ตารางยังบอกว่ามันถือเมืองอยู่ การอ่านจากตัวแคลนทำให้ไม่มีทางไม่ตรงกัน
--
-- ราคาที่จ่ายคือต้องไล่อ่านทุกแคลนเพื่อหาว่าใครถือเมืองนี้ จึงแคชไว้และรีเฟรชเป็นระยะ
local Owner = {}      -- [townId] = { clanId, clanName, since }
local ownerLoadedAt = 0

local function refreshOwners(force)
	if not force and os.clock() - ownerLoadedAt < 30 then return end
	ownerLoadedAt = os.clock()
	local found = {}
	for clanId in pairs(ClanStore.Index(force)) do
		local clan = ClanStore.Get(clanId, force)
		if clan then
			for townId in pairs(clan.towns or {}) do
				found[townId] = { clanId = clan.id, clanName = clan.name, since = clan.townsAt and clan.townsAt[townId] }
			end
		end
	end
	Owner = found
end

--------------------------------------------------------------------------------
-- คูลดาวน์
--------------------------------------------------------------------------------

-- [townId] = os.clock() ที่ปลดล็อกในเซิร์ฟเวอร์นี้
--
-- นับจากตอนเซิร์ฟเวอร์นี้เห็นการยึด ไม่ใช่จากเวลาจริง — เป็นครึ่งหนึ่งของกติกา "เปิดใหม่ก็นับใหม่"
local LocalReadyAt = {}

-- เมืองนี้ยึดได้ไหม คืน ได้/ไม่ได้, เหตุผล
local function canCapture(townId)
	refreshOwners()
	local owner = Owner[townId]
	if not owner then return true end

	-- เวลาจริงตั้งแต่ยึด
	local since = owner.since
	if since and os.time() - since < COOLDOWN_SECONDS then
		local left = COOLDOWN_SECONDS - (os.time() - since)
		return false, ("เมืองนี้เพิ่งถูกยึด รออีก %d ชั่วโมง %d นาที")
			:format(math.floor(left / 3600), math.floor((left % 3600) / 60))
	end

	-- และเวลาในเซิร์ฟเวอร์นี้
	local ready = LocalReadyAt[townId]
	if ready and os.clock() < ready then
		local left = ready - os.clock()
		return false, ("เมืองนี้เพิ่งถูกยึด รออีก %d ชั่วโมง %d นาที")
			:format(math.floor(left / 3600), math.floor((left % 3600) / 60))
	end

	return true
end

--------------------------------------------------------------------------------
-- ยึด
--------------------------------------------------------------------------------

local function townName(townId)
	for _, t in ipairs(TOWNS) do
		if t.id == townId then return t.name end
	end
	return townId
end

local function capture(player, townId)
	local clan = ClanAccess.ClanOf and ClanAccess.ClanOf(player) or nil
	if not clan then
		return Remotes.SocialNotify:FireClient(player, "warn", "ต้องอยู่ในแคลนก่อนถึงจะยึดเมืองได้")
	end

	local ok, why = canCapture(townId)
	if not ok then
		return Remotes.SocialNotify:FireClient(player, "warn", why)
	end

	-- **หนึ่งแคลนยึดได้เมืองเดียว** ตามที่ผู้ใช้กำหนด — ยึดเมืองใหม่แปลว่าปล่อยเมืองเดิม
	local previous = nil
	for id in pairs(clan.towns or {}) do previous = id break end

	local result = ClanStore.Update(clan.id, function(c)
		if not c then return nil end
		c.towns = {}
		c.townsAt = {}
		c.towns[townId] = true
		c.townsAt[townId] = os.time()
		return c
	end)
	if not result then
		return Remotes.SocialNotify:FireClient(player, "error", "ยึดเมืองไม่สำเร็จ")
	end

	-- ปลดเมืองออกจากแคลนอื่นที่เคยถืออยู่
	refreshOwners(true)
	local old = Owner[townId]
	if old and old.clanId ~= clan.id then
		ClanStore.Update(old.clanId, function(c)
			if not c then return nil end
			if c.towns then c.towns[townId] = nil end
			if c.townsAt then c.townsAt[townId] = nil end
			return c
		end)
	end

	LocalReadyAt[townId] = os.clock() + COOLDOWN_SECONDS
	refreshOwners(true)

	local message = ("แคลน %s ยึด%sได้แล้ว"):format(clan.name, townName(townId))
	if previous and previous ~= townId then
		message = message .. (" (ปล่อย%s)"):format(townName(previous))
	end
	Remotes.SocialNotify:FireAllClients("info", message)
end

--------------------------------------------------------------------------------
-- ปุ่มที่อนุสาวรีย์
--------------------------------------------------------------------------------

local wired = {}

local function wire(model, townId)
	if wired[model] or not model.Parent then return end

	-- **แขวนที่เสากลาง ไม่ใช่ PrimaryPart** PrimaryPart ของ Landmark คือ Root ที่ก้นฐาน ปุ่มจะอยู่ระดับ
	-- พื้น — บทเรียนเดียวกับบอร์ดเควสและ NPC กิลด์
	local anchor = model:FindFirstChild("PlinthShaft", true)
	if not anchor then
		-- ไม่มีเสาก็เอาชิ้นที่อยู่สูงสุดในระดับที่คนมองเห็น
		local cf, sz = model:GetBoundingBox()
		local bottom = cf.Position.Y - sz.Y * 0.5
		local best, bestScore = nil, -1
		for _, d in ipairs(model:GetDescendants()) do
			if d:IsA("BasePart") then
				local h = d.Position.Y - bottom
				if h >= 1.5 and h <= 8 then
					local score = d.Size.X * d.Size.Y * d.Size.Z
					if score > bestScore then best, bestScore = d, score end
				end
			end
		end
		anchor = best or model.PrimaryPart
	end
	if not anchor then return end
	wired[model] = true

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "CapturePrompt"
	prompt.ActionText = "ยึดเมือง"
	prompt.ObjectText = townName(townId)
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.MaxActivationDistance = PROMPT_DISTANCE
	prompt.RequiresLineOfSight = false
	-- กดค้างตามที่ผู้ใช้กำหนด ProximityPrompt วาดวงแหวนนับถอยหลังให้เอง และรองรับมือถือกับจอยฟรี
	prompt.HoldDuration = ClanConfig.CaptureSeconds
	prompt.Parent = anchor

	prompt.Triggered:Connect(function(player)
		capture(player, townId)
	end)

	-- บอกเหตุผลตอนกดไม่ได้ แทนที่จะให้กดค้างจนครบแล้วค่อยปฏิเสธ
	prompt.PromptShown:Connect(function()
		local ok, why = canCapture(townId)
		local owner = Owner[townId]
		prompt.ActionText = ok and "ยึดเมือง" or "ยึดไม่ได้"
		prompt.ObjectText = owner
			and ("%s — แคลน %s"):format(townName(townId), owner.clanName)
			or townName(townId)
		prompt.HoldDuration = ok and ClanConfig.CaptureSeconds or 0
		if not ok then prompt.ActionText = why or "ยึดไม่ได้" end
	end)
end

-- ลูปถามใหม่ กฎเหล็กของโปรเจ็ค: โมเดลมาถึงคนละรอบกับสคริปต์ภายใต้ StreamingEnabled
task.spawn(function()
	while true do
		for _, t in ipairs(TOWNS) do
			local model = workspace:FindFirstChild(LANDMARK_PREFIX .. t.id, true)
			if model and model:IsA("Model") then wire(model, t.id) end
		end
		task.wait(0.5)
	end
end)

--------------------------------------------------------------------------------
-- เผยแพร่ให้ระบบอื่น
--------------------------------------------------------------------------------

-- เมืองนี้เป็นของแคลนไหน คืน clanId, clanName
TownAccess.OwnerOf = function(townId)
	refreshOwners()
	local o = Owner[townId]
	if not o then return nil end
	return o.clanId, o.clanName
end

-- ผู้เล่นคนนี้อยู่แคลนที่ถือเมืองนี้ไหม
TownAccess.IsHome = function(player, townId)
	local clanId = ClanAccess.ClanIdOf and ClanAccess.ClanIdOf(player) or nil
	if not clanId then return false end
	local ownerId = TownAccess.OwnerOf(townId)
	return ownerId == clanId
end

TownAccess.Towns = TOWNS
