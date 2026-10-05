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
local Announce = require(game.ServerScriptService.Announce)

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

	-- ค่าที่สาม true = ติดคูลดาวน์ (ต่างจาก "คนไม่ครบ" ซึ่งไม่ใช่เวลา) → ปุ่มถูกซ่อน
	local since = owner.since
	if since and os.time() - since < COOLDOWN_SECONDS then
		return false, leftText(COOLDOWN_SECONDS - (os.time() - since)), true
	end
	local ready = LocalReadyAt[townId]
	if ready and os.clock() < ready then
		return false, leftText(ready - os.clock()), true
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

local Prompts = {} -- [townId] = ปุ่มยึดเมือง (E)
local VaultPrompts = {} -- [townId] = ปุ่มคลังเมือง (F)
-- ชิ้นที่ปุ่มแขวนอยู่ · คลังเมืองแขวนปุ่ม F ของมันที่ชิ้นเดียวกัน แทนที่จะไปค้นหาเสาเองอีกรอบ
-- (การหาเสากลางของอนุสาวรีย์เป็นโค้ดที่เปราะ มีที่เดียวพอ — ดู `wire` ข้างล่าง)
local Anchors = {} -- [townId] = BasePart
local refreshPrompt -- ข้างล่าง ใช้หลังยึดเพื่อให้ปุ่มเปลี่ยนทันทีโดยไม่ต้องเดินออกแล้วเข้าใหม่

local function capture(player, townId)
	local clan = ClanAccess.ClanOf and ClanAccess.ClanOf(player) or nil
	if not clan then
		return Remotes.SocialNotify:FireClient(player, "warn", "ต้องอยู่ในแคลนก่อนถึงจะยึดเมืองได้")
	end

	local ok, why = canCapture(townId)
	if not ok then
		return Remotes.SocialNotify:FireClient(player, "warn", ("ยึดไม่ได้: %s"):format(why))
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
		return Remotes.SocialNotify:FireClient(player, "warn", ("ยึดไม่ได้: %s"):format(refused))
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

	-- แม่แบบเดียวทั้งประโยค (ไคลเอนต์ย้อนแปลได้) — ไทยเหมือนเดิมทุกไบต์
	local message = ("แคลน %s ยึด%sได้แล้ว"):format(clan.name, townName(townId))
	if previous and previous ~= townId then
		message = ("แคลน %s ยึด%sได้แล้ว (ปล่อย%s)"):format(clan.name, townName(townId), townName(previous))
	end
	Remotes.SocialNotify:FireAllClients("info", message)
	for id in pairs(Prompts) do refreshPrompt(id) end
	-- ประกาศข้ามเซิร์ฟ (ผู้ใช้เลือก 2026-09-25) · ชื่อแคลนผู้เล่นตั้งเอง → ผ่านตัวกรองก่อน กรองไม่ได้ = ไม่ประกาศ
	local capturedTown, clanName, byUserId = townName(townId), clan.name, player.UserId
	task.spawn(function()
		local safe = Announce.Filter(clanName, byUserId)
		if safe then Announce.Global(("🏰 แคลน %s ยึด%sได้แล้ว"):format(safe, capturedTown), "town") end
	end)
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
	Anchors[townId] = anchor
	-- ไคลเอนต์ใช้สองอย่างนี้ตัดสินว่าจะโชว์ปุ่มไหนให้เจ้าของจอ (ดู `TownVaultController`):
	-- ไม่มีแคลน = ไม่เห็นปุ่มอะไรเลย · มีแคลนแต่ไม่ใช่เจ้าของเมือง = เห็นแค่ E · เจ้าของเมือง = เห็นแค่ F
	model:SetAttribute("TownId", townId)
	model:SetAttribute("TownName", townName(townId))

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

	-- **ปุ่มคลังเมืองสร้างที่นี่ด้วย ไม่ใช่ในสคริปต์คลัง** — ทั้งสองปุ่มแขวนชิ้นเดียวกัน เกิดพร้อมกัน
	-- และถูกสแตมป์ด้วยข้อมูลชุดเดียวกัน รอบแรกแยกไปสร้างในสคริปต์คลังแล้วรอ `TownAccess.AnchorOf`
	-- ซึ่งเป็นการนัดเวลาข้ามสคริปต์โดยไม่จำเป็น และเป็นทางที่ปุ่ม F หายไปเงียบๆ ได้
	local vault = Instance.new("ProximityPrompt")
	vault.Name = "TownVaultPrompt"
	vault.ActionText = "คลังเมือง"
	vault.ObjectText = townName(townId)
	vault.KeyboardKeyCode = Enum.KeyCode.F
	vault.MaxActivationDistance = PROMPT_DISTANCE
	vault.RequiresLineOfSight = false
	vault.Parent = anchor
	VaultPrompts[townId] = vault
	vault.Triggered:Connect(function(player)
		-- ตรรกะคลังอยู่ที่ `TownVault.server` ที่นี่แค่เป็นปุ่ม — ยังไม่โหลดก็บอกไป ไม่ใช่เงียบ
		if TownAccess.OpenVault then
			TownAccess.OpenVault(player, townId)
		else
			Remotes.SocialNotify:FireClient(player, "warn", "ระบบคลังเมืองยังไม่พร้อม")
		end
	end)

	-- ไคลเอนต์หาปุ่มจากแท็ก ไม่ใช่จากการไล่หาโมเดลในแมพ (ดู `TownVaultController`):
	-- ภายใต้ StreamingEnabled การค้นหาโมเดลจากชื่อเป็นคำตอบที่ถูกบ้างผิดบ้างแล้วแต่จังหวะ
	for _, p in ipairs({ prompt, vault }) do
		p:SetAttribute("TownId", townId)
		CollectionService:AddTag(p, "WOLD_TownPrompt")
	end

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
	local ok, why, cooling = canCapture(townId)
	local owner = Owner[townId]
	-- **ติดคูลดาวน์ = ซ่อนปุ่ม** (ผู้ใช้สั่ง 2026-09-25) · ความมองเห็นเป็นของ `TownVaultController` (รายคน)
	-- เซิร์ฟเวอร์แค่ประกาศ ถ้าตั้ง Enabled ที่นี่ ไคลเอนต์จะเขียนทับทุกวินาที
	prompt:SetAttribute("Cooling", cooling == true)
	local action = ok and "ยึดเมือง" or (why or "ยึดไม่ได้")
	local object = owner and ("%s — แคลน %s"):format(townName(townId), owner.clanName) or townName(townId)
	local hold = ok and ClanConfig.CaptureSeconds or 0
	-- **ประกาศเจ้าของเมืองไว้บนตัวปุ่มเอง** ไม่ใช่บนโมเดลที่ไล่หาขึ้นไปข้างบน: ปุ่มคือสิ่งที่ไคลเอนต์
	-- ถืออยู่ในมือตอนตัดสินว่าจะโชว์หรือซ่อน การเอาคำตอบไปวางไว้คนละที่กับคำถามคือที่มาของรอบที่แล้ว
	-- ที่ปุ่ม E ยังขึ้นให้เจ้าของเมืองและปุ่ม F ไม่ขึ้นให้ใครเลย
	--
	-- `""` = ไม่มีใครถือเมืองนี้ · nil = สคริปต์นี้ยังไม่ได้พูด ซึ่งไคลเอนต์แปลว่า "ยังไม่รู้ อย่าเพิ่งซ่อนอะไร"
	local ownerId = owner and owner.clanId or ""
	prompt:SetAttribute("OwnerClanId", ownerId)
	local vault = VaultPrompts[townId]
	if vault and vault.Parent then vault:SetAttribute("OwnerClanId", ownerId) end
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
-- ซ่อมข้อมูลเก่า: เมืองที่ถูกยึด "ก่อน" จะมีคีย์ `towns`
--
-- เจอจริง 2026-09-19: แคลนถือซอลต์เมียร์อยู่ (หน้าแคลนโชว์ "ยึดเมือง: Saltmere") แต่คีย์ `towns`
-- ไม่มีรายการนั้น — ป้ายบนปุ่มฟ้องตรงๆ ว่าขึ้น "ซอลต์เมียร์" เฉยๆ ไม่มี "— แคลน ..." ต่อท้าย
-- ผลคือทั้งเกมคิดว่าเมืองนี้ไม่มีเจ้าของ: ปุ่ม E ยังขึ้นให้เจ้าของเมือง และปุ่มคลังเมือง F ไม่ขึ้นให้ใครเลย
--
-- ต้นเหตุคือการย้ายตัวตัดสินจาก `clan.towns` มาที่คีย์ `towns` (2026-09-18) ของที่ยึดไว้ก่อนหน้านั้น
-- ไม่เคยถูกเขียนลงคีย์ใหม่ · ตัวซ่อมนี้ยกสำเนาในตัวแคลนขึ้นมาเป็นความจริง **ครั้งเดียวตอนเซิร์ฟบูต**
-- แล้วจะไม่ทำอะไรอีกเลยในรอบถัดๆ ไป เพราะหลังจากนี้คีย์ `towns` จะมีข้อมูลครบแล้ว
--------------------------------------------------------------------------------

local MAX_CLANS_TO_SCAN = 40 -- กัน GetAsync ยาวเป็นพรืดถ้าวันหนึ่งมีแคลนเยอะ

local function reconcileFromClans()
	refreshOwners(true)

	local index = ClanStore.Index(true) or {}
	local count = 0
	for _ in pairs(index) do count += 1 end
	if count == 0 then return end
	if count > MAX_CLANS_TO_SCAN then
		warn(("[TownCapture] แคลน %d แคลน มากกว่าเพดานสแกน %d — ข้ามการซ่อมเมือง")
			:format(count, MAX_CLANS_TO_SCAN))
		return
	end

	local missing = {}
	for clanId in pairs(index) do
		local clan = ClanStore.Get(clanId, true)
		task.wait(0.2) -- อ่านทีละแคลนแบบไม่รีบ ไม่ไปแย่งโควตากับการเล่นจริง
		for townId, held in pairs((clan and clan.towns) or {}) do
			if held and not Owner[townId] then
				missing[townId] = {
					clanId = clan.id,
					clanName = clan.name,
					-- ไม่รู้เวลายึดจริงก็ถือว่ายึดตอนนี้ คูลดาวน์เริ่มใหม่ ซึ่งเป็นฝั่งที่ปลอดภัยกว่า
					since = (clan.townsAt and clan.townsAt[townId]) or os.time(),
				}
			end
		end
	end
	if not next(missing) then return end

	local towns = ClanStore.UpdateTowns(function(t)
		local changed = false
		for townId, rec in pairs(missing) do
			if not t[townId] then t[townId] = rec changed = true end
		end
		return changed and t or nil
	end)
	if towns then
		Owner = towns
		ownerLoadedAt = os.clock()
		for townId, rec in pairs(missing) do
			print(("[TownCapture] ซ่อมเจ้าของเมือง %s -> แคลน %s"):format(townId, rec.clanName))
		end
		for id in pairs(Prompts) do refreshPrompt(id) end
	end
end

task.spawn(function()
	task.wait(8) -- ให้ระบบแคลนกับ DataStore ตั้งตัวก่อน แล้วค่อยซ่อม
	local ok, err = pcall(reconcileFromClans)
	if not ok then warn("[TownCapture] ซ่อมเจ้าของเมืองไม่สำเร็จ:", err) end
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

-- ชิ้นที่ปุ่มยึดเมืองแขวนอยู่ — คลังเมืองเอาไปแขวนปุ่ม F และใช้วัดระยะว่าคนกดยืนอยู่ที่อนุสาวรีย์จริง
TownAccess.AnchorOf = function(townId)
	return Anchors[townId]
end

-- ตารางเจ้าของเมืองทั้งหมด (อ่านสด) ไว้ให้คำสั่งแอดมินส่องว่าใครถืออะไรอยู่จริง
TownAccess.Owners = function()
	refreshOwners(true)
	return Owner
end

-- บังคับตั้งเจ้าของ — สำหรับคำสั่งแอดมินเท่านั้น ใช้ตอนข้อมูลเก่าเพี้ยนและไม่อยากรอตัวซ่อมตอนบูต
TownAccess.ForceOwner = function(townId, clanId, clanName)
	local towns = ClanStore.UpdateTowns(function(t)
		if clanId then
			-- หนึ่งแคลนถือได้เมืองเดียว กฎเดียวกับการยึดปกติ
			for id, o in pairs(t) do
				if o.clanId == clanId and id ~= townId then t[id] = nil end
			end
			t[townId] = { clanId = clanId, clanName = clanName, since = os.time() }
		else
			t[townId] = nil
		end
		return t
	end)
	if towns then
		Owner = towns
		ownerLoadedAt = os.clock()
		LocalReadyAt[townId] = os.clock() + COOLDOWN_SECONDS
		for id in pairs(Prompts) do refreshPrompt(id) end
	end
	return towns and towns[townId] or nil
end
