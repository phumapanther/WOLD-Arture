-- TownCapture.server.lua: ยึดเมืองด้วยการกดค้างที่อนุสาวรีย์
--
-- **คูลดาวน์ 12 ชั่วโมงนับจากเวลาจริง และเริ่มนับใหม่เมื่อเซิร์ฟเวอร์เปิดใหม่ · ต้องมีคนในเซิร์ฟ 15**
-- ตามที่ผู้ใช้กำหนด
--
-- สองข้อแรกขัดกันโดยธรรมชาติ: "เวลาจริง" อยากให้ผูกกับ os.time() ซึ่งข้ามเซิร์ฟเวอร์ ส่วน "รีเซ็ตเมื่อ
-- เปิดใหม่" อยากให้ผูกกับอายุเซิร์ฟเวอร์ — เก็บทั้งสองอย่าง แล้วถือว่าปลดล็อกเมื่อผ่าน **ทั้งคู่**
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

local COOLDOWN_SECONDS = ClanConfig.CaptureCooldownSeconds

--------------------------------------------------------------------------------
-- ใครถือเมืองไหน
--------------------------------------------------------------------------------

-- อ่านจากคีย์ towns คีย์เดียวใน ClanStore ทุก 30 วิ **อ่านสดจาก DataStore เสมอ** — เวอร์ชันแรกอ่าน
-- ผ่านแคชของแต่ละแคลนซึ่งไม่เคยหมดอายุ เซิร์ฟเวอร์นี้จึงไม่มีทางรู้ว่าอีกเซิร์ฟเวอร์เพิ่งยึดไป และ
-- ปล่อยให้ยึดซ้ำได้ทันที ("ยึดได้แล้วไม่คูลดาวน์")
local Owner = {}      -- [townId] = { clanId, clanName, since }
local ownerLoadedAt = -math.huge

-- [townId] = os.clock() ที่ปลดล็อกในเซิร์ฟเวอร์นี้
--
-- กติกาครึ่งหลังของผู้ใช้: "เซิร์ฟเวอร์เปิดใหม่ก็นับใหม่จาก 12 ชั่วโมง" — เมืองที่ถูกถืออยู่ตอนเซิร์ฟเวอร์
-- นี้เห็นครั้งแรก ก็ล็อกจากตอนนี้ไปอีก 12 ชั่วโมงเช่นกัน ปลดเมื่อผ่าน **ทั้ง** นาฬิกาจริงและนาฬิกา
-- เซิร์ฟเวอร์ ซึ่งเป็นการอ่านที่ปลอดภัยที่สุด: ไม่มีทางที่เมืองจะถูกแย่งเร็วกว่าที่ตั้งใจ
local LocalReadyAt = {}

local function refreshOwners(force)
	if not force and os.clock() - ownerLoadedAt < 30 then return end
	ownerLoadedAt = os.clock()
	Owner = ClanStore.GetTowns(true) or {}
	for townId in pairs(Owner) do
		if not LocalReadyAt[townId] then LocalReadyAt[townId] = os.clock() + COOLDOWN_SECONDS end
	end
end

local function leftText(seconds)
	return ("รออีก %d ชม. %d นาที"):format(math.floor(seconds / 3600), math.floor((seconds % 3600) / 60))
end

-- เมืองนี้ยึดได้ไหม คืน ได้/ไม่ได้, เหตุผล (สั้น เพราะไปโชว์บนปุ่ม)
local function canCapture(townId)
	local here = #Players:GetPlayers()
	if here < ClanConfig.CaptureMinPlayers then
		return false, ("ต้องมีคนในเซิร์ฟ %d (ตอนนี้ %d)"):format(ClanConfig.CaptureMinPlayers, here)
	end

	refreshOwners()
	local owner = Owner[townId]
	if not owner then return true end

	local since = owner.since
	if since and os.time() - since < COOLDOWN_SECONDS then
		return false, leftText(COOLDOWN_SECONDS - (os.time() - since))
	end
	local ready = LocalReadyAt[townId]
	if ready and os.clock() < ready then
		return false, leftText(ready - os.clock())
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

local Prompts = {} -- [townId] = prompt
local refreshPrompt -- ข้างล่าง ใช้หลังยึดเพื่อให้ปุ่มเปลี่ยนทันทีโดยไม่ต้องเดินออกแล้วเข้าใหม่

local function capture(player, townId)
	local clan = ClanAccess.ClanOf and ClanAccess.ClanOf(player) or nil
	if not clan then
		return Remotes.SocialNotify:FireClient(player, "warn", "ต้องอยู่ในแคลนก่อนถึงจะยึดเมืองได้")
	end

	local ok, why = canCapture(townId)
	if not ok then
		return Remotes.SocialNotify:FireClient(player, "warn", "ยึดไม่ได้: " .. why)
	end

	-- ตัดสินจริงใน UpdateAsync ของคีย์ towns — สองเซิร์ฟเวอร์ที่กดจบพร้อมกันจะเห็นกันและกันตรงนี้
	-- **หนึ่งแคลนยึดได้เมืองเดียว** ตามที่ผู้ใช้กำหนด — ยึดเมืองใหม่แปลว่าปล่อยเมืองเดิม
	local refused, previous = nil, nil
	local towns = ClanStore.UpdateTowns(function(t)
		local cur = t[townId]
		if cur and cur.since and os.time() - cur.since < COOLDOWN_SECONDS then
			refused = leftText(COOLDOWN_SECONDS - (os.time() - cur.since))
			return nil
		end
		for id, o in pairs(t) do
			if o.clanId == clan.id and id ~= townId then previous = id t[id] = nil end
		end
		t[townId] = { clanId = clan.id, clanName = clan.name, since = os.time() }
		return t
	end)
	if refused then
		return Remotes.SocialNotify:FireClient(player, "warn", "ยึดไม่ได้: " .. refused)
	end
	if not towns or not towns[townId] or towns[townId].clanId ~= clan.id then
		return Remotes.SocialNotify:FireClient(player, "error", "ยึดเมืองไม่สำเร็จ")
	end

	Owner = towns
	ownerLoadedAt = os.clock()
	LocalReadyAt[townId] = os.clock() + COOLDOWN_SECONDS

	-- สำเนาไว้ที่ตัวแคลนให้หน้าแคลนโชว์ ไม่ใช่ตัวตัดสิน
	ClanStore.Update(clan.id, function(c)
		if not c then return nil end
		c.towns = { [townId] = true }
		c.townsAt = { [townId] = os.time() }
		return c
	end)
	-- แคลนที่เคยถือเมืองนี้ (ถ้ามีและไม่ใช่เรา) เอาออกจากสำเนาของมันด้วย ไล่จากแคลนที่มี towns[townId]
	for clanId in pairs(ClanStore.Index()) do
		if clanId ~= clan.id then
			local c = ClanStore.Get(clanId)
			if c and c.towns and c.towns[townId] then
				ClanStore.Update(clanId, function(cc)
					if not cc then return nil end
					if cc.towns then cc.towns[townId] = nil end
					if cc.townsAt then cc.townsAt[townId] = nil end
					return cc
				end)
			end
		end
	end

	local message = ("แคลน %s ยึด%sได้แล้ว"):format(clan.name, townName(townId))
	if previous and previous ~= townId then
		message = message .. (" (ปล่อย%s)"):format(townName(previous))
	end
	Remotes.SocialNotify:FireAllClients("info", message)
	for id in pairs(Prompts) do refreshPrompt(id) end
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

	Prompts[townId] = prompt
	prompt.Triggered:Connect(function(player)
		capture(player, townId)
	end)
	refreshPrompt(townId)
end

-- บอกเหตุผลบนปุ่มเลย แทนที่จะให้กดค้างจนครบแล้วค่อยปฏิเสธ
--
-- เรียกซ้ำจากลูปข้างล่าง ไม่ใช่แค่ตอน PromptShown — ปุ่มที่โชว์ค้างอยู่ตอนยึดสำเร็จจะได้เปลี่ยนเป็น
-- "รออีก 11 ชม." ทันที และตัวเลขเดินได้ **ตั้งค่าเฉพาะตอนต่างจากเดิม** เพราะการเขียน HoldDuration
-- ระหว่างที่ใครกดค้างอยู่จะยกเลิกการกดนั้น
function refreshPrompt(townId)
	local prompt = Prompts[townId]
	if not prompt or not prompt.Parent then return end
	local ok, why = canCapture(townId)
	local owner = Owner[townId]
	local action = ok and "ยึดเมือง" or (why or "ยึดไม่ได้")
	local object = owner and ("%s — แคลน %s"):format(townName(townId), owner.clanName) or townName(townId)
	local hold = ok and ClanConfig.CaptureSeconds or 0
	if prompt.ActionText ~= action then prompt.ActionText = action end
	if prompt.ObjectText ~= object then prompt.ObjectText = object end
	if prompt.HoldDuration ~= hold then prompt.HoldDuration = hold end
end

-- ลูปถามใหม่ กฎเหล็กของโปรเจ็ค: โมเดลมาถึงคนละรอบกับสคริปต์ภายใต้ StreamingEnabled
task.spawn(function()
	local tick = 0
	while true do
		for _, t in ipairs(TOWNS) do
			local model = workspace:FindFirstChild(LANDMARK_PREFIX .. t.id, true)
			if model and model:IsA("Model") then wire(model, t.id) end
		end
		tick += 1
		if tick % 10 == 0 then
			for id in pairs(Prompts) do refreshPrompt(id) end
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
