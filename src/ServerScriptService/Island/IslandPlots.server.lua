-- IslandPlots: แปลงดินที่วางแล้ว → ปุ่ม E หยอดเมล็ด / เก็บเกี่ยว · พืชโตตาม os.time (ออฟไลน์โตต่อฟรี)
--
-- ไม่ผูกตอนวางครั้งเดียว: ลูป 2 วิถามโฟลเดอร์ Placed ใหม่ทุกรอบ แปลงไหนยังไม่มีปุ่มก็ใส่ให้ แปลงไหนหายก็ลืม
-- (กฎเหล็ก "ลูปที่ถามใหม่เรื่อยๆ ไม่มีจังหวะให้แพ้") · นาฬิกาอยู่บนตัวปุ่ม (ObjectText) ไม่มีโค้ดไคลเอนต์
local ServerConfig = require(game.ServerScriptService.ServerConfig)
if not ServerConfig.IsFarm then return end

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Inventory = require(game.ServerScriptService.Inventory)
local IslandAccess = require(script.Parent.IslandAccess)
local IslandConfig = require(ReplicatedStorage.IslandConfig)
local GoldBorder = require(ReplicatedStorage.GoldBorder)
local Progression = require(game.ServerScriptService.Progression)
local ItemCatalog = require(ReplicatedStorage.ItemCatalog)
local Remotes = require(ReplicatedStorage.Remotes)
local WorldSound = require(game.ServerScriptService.WorldSound) -- เสียงหยอดเมล็ด/เก็บผัก (QA 2026-09-28)

local TICK = 2
local Plots = {} -- [plotModel] = { prompt = ProximityPrompt, stage = number|nil }

local REASON_TEXT = {
	notowner = "เฉพาะเจ้าของเกาะ",
	noseed = "ไม่มีเมล็ดพันธุ์ในกระเป๋า",
	planted = "แปลงนี้ปลูกอยู่แล้ว",
	empty = "แปลงว่าง หยอดเมล็ดก่อน",
	unripe = "ยังไม่สุก",
	ownerleft = "เจ้าของเกาะไม่อยู่ เก็บของไม่ได้",
	full = "กระเป๋าเต็ม",
	missing = "ไม่พบแปลงนี้แล้ว",
	seedlocked = "เมล็ดชนิดนี้ยังปลูกไม่ได้ (ปลดตามเลเวลฟาร์ม)",
	far = "อยู่ไกลแปลงเกินไป",
}

-- **เลือกเมล็ด** (เฟส 2c — เมล็ดฝ้ายแยกจากเมล็ดสุ่ม ผู้ใช้เลือก 2026-09-27)
-- มีเมล็ดที่ปลูกได้ชนิดเดียว = กด E หยอดเลย (เหมือนเดิม) · มีหลายชนิด = ขึ้นให้เลือกครั้งแรก แล้ว **จำไว้ 90 วินาที**
-- (ต่ออายุทุกครั้งที่หยอด) เดินหยอดทั้งแถวได้โดยไม่ต้องเลือกซ้ำ · ปุ่ม "เปลี่ยน" บนจอล้างที่จำไว้
local CHOICE_SECONDS = 90
local Choice = {} -- [player] = { seed = id, at = os.clock() }

local function notify(player, reason)
	Remotes.SocialNotify:FireClient(player, "error", REASON_TEXT[reason] or reason)
end

local function cropSpec(item)
	for _, c in ipairs(IslandConfig.Crops) do if c.item == item then return c end end
	return nil
end

-- สุ่มจากพืชที่เมล็ดนี้ให้ได้ (IslandConfig.CropsFor — กรองเลเวลฟาร์มแล้ว) · น้ำหนักรวมเป็น 0 (เมล็ดเฉพาะชนิด) = ตัวแรก
local function rollCrop(crops)
	local total = 0
	for _, c in ipairs(crops) do total += c.weight or 0 end
	if total <= 0 then return crops[1] end
	local pick = math.random() * total
	for _, c in ipairs(crops) do
		pick -= c.weight or 0
		if pick <= 0 then return c end
	end
	return crops[#crops]
end

-- เลเวลฟาร์มที่เมล็ดนี้เริ่มปลูกได้ (พืชเลเวลต่ำสุดที่มันให้) · nil = ไม่ใช่เมล็ด
local function seedLevel(seedId)
	local best
	for _, c in ipairs(IslandConfig.CropsFor(seedId, nil)) do
		best = math.min(best or math.huge, c.level or 1)
	end
	return best
end

local function isSeed(id)
	for _, s in ipairs(IslandConfig.SeedItems) do
		if s == id then return true end
	end
	return false
end

-- เวลาที่พืชชนิดนี้ต้องใช้ **หลังหักโบนัส** — สัตว์เลี้ยงบนเกาะทำให้โตเร็วขึ้น 10% (ผู้ใช้สั่ง)
--
-- **คิดสดทุกครั้ง ไม่เก็บลงแปลง** ผู้เล่นเอาสัตว์มาวางหรือเก็บคืนได้ตลอดเวลา ถ้าฝังเวลาที่ลดแล้วไว้
-- ตอนหยอดเมล็ด แปลงที่ปลูกก่อนซื้อสัตว์จะไม่ได้โบนัสเลย และแปลงที่ปลูกตอนมีสัตว์จะได้ต่อไปแม้ขายสัตว์ทิ้ง
local function growSeconds(spec)
	local mul = IslandAccess.GrowthMultiplier and IslandAccess.GrowthMultiplier() or 1
	return spec.seconds * mul
end

local function progressOf(entry)
	local spec = cropSpec(entry.crop)
	if not spec or not entry.at then return 1 end
	return math.clamp((os.time() - entry.at) / growSeconds(spec), 0, 1)
end

local function stageOf(progress)
	local stage = 1
	for i, s in ipairs(IslandConfig.Stages) do
		if progress >= s.at then stage = i end
	end
	return stage
end

local function minutesLeft(entry)
	local spec = cropSpec(entry.crop)
	if not spec then return 0 end
	return math.max(0, math.ceil((growSeconds(spec) - (os.time() - entry.at)) / 60))
end

--------------------------------------------------------------------------------
-- โมเดลพืช
--------------------------------------------------------------------------------

local function showCrop(model, entry, stage)
	local soil = model:FindFirstChild("Soil")
	local crop = model:FindFirstChild("Crop")
	if entry.crop == nil then
		if crop then crop:Destroy() end
		return
	end
	if not crop then
		local protos = ReplicatedStorage:FindFirstChild("WOLD_Placeables")
		local proto = protos and protos:FindFirstChild("Crop_" .. entry.crop)
		if not proto or not soil then return end
		crop = proto:Clone()
		crop.Name = "Crop"
		crop:PivotTo(CFrame.new(soil.Position + Vector3.new(0, soil.Size.Y / 2, 0)))
		crop.Parent = model
	end
	-- โตตามขนาดแปลง (แปลงขยาย 1.5 เท่า 2026-09-25 → ผักก็ใหญ่ตาม) · `GetScale` ของแปลงคือสเกลของต้นแบบที่โคลนมา
	crop:ScaleTo(IslandConfig.Stages[stage].scale * model:GetScale())
end

--------------------------------------------------------------------------------
-- ปลูก / เก็บเกี่ยว
--------------------------------------------------------------------------------

-- `seedId` nil = เมล็ดสุ่ม (ทางเดิม · เทสเก่าเรียกแบบนี้)
local function plant(player, model, seedId)
	if not IslandAccess.IsOwner(player) then return false, "notowner" end
	local entry = IslandAccess.EntryOf(model)
	if not entry then return false, "missing" end
	if entry.crop then return false, "planted" end
	seedId = seedId or IslandConfig.SeedItem
	if not isSeed(seedId) then return false, "noseed" end
	local crops = IslandConfig.CropsFor(seedId, IslandAccess.FarmLevel())
	if #crops == 0 then return false, "seedlocked" end
	local slot = Inventory.FindSlotById(player, seedId)
	if not slot then return false, "noseed" end
	if not Inventory.RemoveFromSlot(player, slot, 1) then return false, "noseed" end
	local spec = rollCrop(crops)
	entry.crop, entry.at = spec.item, os.time()
	-- แสงยังไม่ทอยตอนหยอด — ทอยตอนสุก (ripen ข้างล่าง · ผู้ใช้สั่ง 2026-09-25)
	entry.glow = nil
	model:SetAttribute("Glow", nil)
	local state = Plots[model]
	if state then state.stage = nil end -- ให้รอบถัดไปวาดใหม่
	local item = ItemCatalog.Get(spec.item)
	WorldSound.At("Plant", model, 1, 45)
	Remotes.SocialNotify:FireClient(player, "info", ("หยอดเมล็ดแล้ว — ขึ้นเป็น%s ใช้เวลา %d นาที"):format(item and item.name or spec.item, growSeconds(spec) / 60), true) -- true = เงียบ (เสียงหยอดเมล็ดดังแล้ว)
	return true
end

-- **ทอยแสงตอนผักสุก = ตอนที่เก็บได้พอดี** (ผู้ใช้สั่ง 2026-09-25: "ไม่ใช่สุ่มตอนเก็บ แต่สุ่มแสดงผลขึ้น
-- ตอนที่สามารถเก็บได้") · จดใน `entry.glow` (false = ทอยแล้วไม่ติด) ออก-เข้าเกาะจึงทอยใหม่ไม่ได้
-- เรียกซ้ำได้: ทอยครั้งเดียวต่อรอบปลูก แล้วแค่คืนแอตทริบิวต์ให้ตรงกับโปรไฟล์ (หลังเซิร์ฟบูต)
local function ripen(model, entry)
	-- ผลผลิตแปลงผักทุกชนิดมีขอบทองได้ แสงแดงจึงขึ้นได้ทุกแปลง (เฟส 2b) · สีที่ยังไม่ปลดไม่ขึ้น (เฟส 2c)
	if entry.glow == nil then entry.glow = IslandAccess.RollGlow(true) or false end
	local tone = entry.glow or nil
	if model:GetAttribute("Glow") ~= tone then model:SetAttribute("Glow", tone) end
end

local function harvest(player, model)
	-- **แขกเก็บผักของเจ้าบ้านได้** (ผู้ใช้สั่ง 2026-09-23: "เพื่อนที่เข้ามาสามารถมาขโมยเก็บฟาร์มสัตว์
	-- และฟาร์มผักเราได้") — ส่วนการ *ปลูก* ยังเป็นของเจ้าของคนเดียว (เมล็ดเป็นของเขา แปลงเป็นของเขา)
	--
	-- ไม่ต้องเช็คอะไรเลยตรงนี้: คนที่ยืนอยู่บนเกาะนี้ได้ ผ่านด่านล็อบบี้ (เพื่อนกันจริง + เจ้าของอยู่)
	-- กับด่าน `IslandGuests` มาแล้วทั้งคู่ · ทรงเดียวกับ `Gathering` ที่ไม่เคยถามว่าใครเป็นเจ้าของที่
	-- เจ้าของไม่อยู่ = โปรไฟล์ปิด ของที่เก็บไม่ถูกเซฟ (ดู Gathering) QA 2026-09-26
	if not (IslandAccess.Data and IslandAccess.Data()) then return false, "ownerleft" end
	local entry = IslandAccess.EntryOf(model)
	if not entry then return false, "missing" end
	if not entry.crop then return false, "empty" end
	if progressOf(entry) < 1 then return false, "unripe" end
	ripen(model, entry) -- เผื่อเก็บก่อนรอบ tick ที่ทอยให้
	local spec = cropSpec(entry.crop)
	local amount = spec and math.random(spec.min, spec.max) or 1
	-- เพดานเดียวกับที่ `Gathering` ใช้กับสัตว์/แร่ (ผู้ใช้สั่ง 2026-09-23) · หนีบก่อนคูณแสงเช่นกัน
	if IslandConfig.YieldCap then amount = math.min(amount, IslandConfig.YieldCap) end

	-- **ของเรืองแสง** (ผู้ใช้สั่ง 2026-09-23) ฟ้า = วัตถุดิบ ×2 · ทอง = EXP ×2
	-- คูณ **ก่อน** ถามกระเป๋า เพื่อให้กระเป๋าที่ใส่ไม่ครบปฏิเสธทั้งกอง ไม่ใช่รับครึ่งเดียวเงียบๆ
	local glow = entry.glow or nil
	amount = math.floor(amount * IslandConfig.GlowYield(glow) + 0.5)

	-- **ของขอบทอง** (เฟส 2b) หนึ่งชิ้นในกองนี้ · กระเป๋า VIP เต็ม = ได้เป็นของธรรมดา (AddHarvest)
	-- ขอบทองปลดที่เลเวลฟาร์ม 4 (เฟส 2c)
	local withGold = GoldBorder.CropItems[entry.crop] == true and IslandAccess.GoldAllowed() and GoldBorder.Roll(glow)
	if not Inventory.HasRoomFor(player, entry.crop, amount) then return false, "full" end
	local given, goldResult = Inventory.AddHarvest(player, entry.crop, amount, withGold)
	if not given then return false, "full" end
	local item = ItemCatalog.Get(entry.crop)
	WorldSound.At("Harvest", model, 1, 45)
	-- แม่แบบเดียวต่อแบบ (ไคลเอนต์ย้อนแปลทั้งประโยค) · ไทยเหมือนเดิมทุกไบต์
	local harvestText = goldResult == "given" and "เก็บเกี่ยวได้ %s x%d (🌟 ขอบทอง 1 ชิ้น)" or "เก็บเกี่ยวได้ %s x%d"
	Remotes.SocialNotify:FireClient(player, "info", harvestText:format(item and item.name or entry.crop, amount), true) -- เสียงเก็บผักดังแล้ว
	if goldResult == "lost" then
		Remotes.SocialNotify:FireClient(player, "error", "กระเป๋า VIP เต็ม — ขอบทองกลายเป็นของธรรมดา")
	end

	-- ของแถมประจำพืช (`spec.bonus`) — ตอนนี้คือแร่เวทมนตร์ที่ติดมากับต้นเวทมนตร์
	-- แยกจากหนอนข้างล่างที่เป็นของแถมของ **ดิน** ซึ่งติดมาได้กับทุกพืช
	if spec and spec.bonus and math.random() < (spec.bonus.chance or 0.5) then
		local extra = math.random(spec.bonus.min or 1, spec.bonus.max or 1)
		extra = math.floor(extra * IslandConfig.GlowYield(glow) + 0.5)
		if Inventory.HasRoomFor(player, spec.bonus.item, extra) and Inventory.AddItem(player, spec.bonus.item, extra) then
			local bi = ItemCatalog.Get(spec.bonus.item)
			Remotes.SocialNotify:FireClient(player, "info",
				("ติดมาด้วย %s x%d"):format(bi and bi.name or spec.bonus.item, extra))
		end
	end

	-- หนอนติดมากับดิน (ผู้ใช้สั่ง 2026-09-22) — เกณฑ์เดียวกับสมุนไพร/นาข้าวในแมพหลัก
	--
	-- (เดิมใช้ `GatherConfig.WormBonus` ตัวเดียวกัน · 2026-09-29 แยกเป็น `IslandConfig.PlotWormBonus`) · เป็น **ของแถม** เหมือนที่นั่น
	-- ไม่ใช่ของที่ได้ *แทน* ผัก (แปลงผักในแมพหลักใช้ `alt` ซึ่งแลกผักทิ้ง — บนเกาะผู้เล่นจ่ายค่าเมล็ด
	-- กับรอเวลามาแล้ว การเอาผลผลิตของเขาไปทั้งกองเพื่อแจกหนอนไม่ใช่สิ่งที่สั่ง)
	--
	-- กระเป๋าเต็มตรงนี้ = หนอนหายเงียบๆ ไม่ขึ้นเตือนสีแดง เหมือน `Gathering` ทำกับของแถมทุกตัว
	-- เพราะการเก็บเกี่ยวสำเร็จไปแล้ว
	-- **เมล็ดติดมาจากการเก็บเกี่ยว** (ผู้ใช้สั่ง 2026-09-23) — แปลงเลี้ยงตัวเองได้บ้างโดยไม่ต้องวิ่งซื้อทุกรอบ
	-- แสงฟ้าคูณให้ด้วย เพราะมันคือ "วัตถุดิบ" ที่ออกจากแปลงเหมือนกัน
	local seeds = IslandConfig.SeedBonus
	if seeds and math.random() < seeds.chance then
		local n = math.random(seeds.min, seeds.max)
		n = math.floor(n * IslandConfig.GlowYield(glow) + 0.5)
		if Inventory.HasRoomFor(player, IslandConfig.SeedItem, n) and Inventory.AddItem(player, IslandConfig.SeedItem, n) then
			Remotes.SocialNotify:FireClient(player, "info", ("ได้เมล็ดพันธุ์ติดมา x%d"):format(n))
		end
	end

	-- แปลงผักใช้ตัวเลขของตัวเอง (2026-09-29: 1-3 ตัว 20% · พุ่มบนเกาะใช้ตัวเดียวกันตั้งแต่ 2026-10-01)
	local bonus = IslandConfig.PlotWormBonus
	if bonus and math.random() < bonus.chance then
		local extra = math.random(bonus.min, bonus.max)
		if Inventory.HasRoomFor(player, bonus.item, extra) and Inventory.AddItem(player, bonus.item, extra) then
			local worm = ItemCatalog.Get(bonus.item)
			Remotes.SocialNotify:FireClient(player, "info",
				("เจอ%s x%d ในดิน"):format(worm and worm.name or bonus.item, extra))
		end
	end
	-- **EXP จากการเก็บเกี่ยว** — แปลงผักไม่เคยให้มาก่อน ซึ่งทำให้แสงสีทองไม่มีความหมายเลย
	-- ตัวคูณของเกาะ (สัตว์เลี้ยง/ของตกแต่ง) ใช้ตัวเดียวกับที่ `Gathering` ถาม
	local xp = IslandConfig.CropExp or 0
	xp = math.floor(xp * IslandConfig.GlowExp(glow) + 0.5)
	if IslandAccess.FarmExpMultiplier then
		xp = math.floor(xp * IslandAccess.FarmExpMultiplier() + 0.5)
	end
	if xp > 0 then Progression.AwardExp(player, xp) end

	if glow then
		Remotes.SocialNotify:FireClient(player, "info",
			glow == "red" and "🔥 แสงแดง: ขอบทอง + วัตถุดิบและ EXP สองเท่า"
				or glow == "gold" and "✨ แสงทอง: EXP สองเท่า" or "💠 แสงฟ้า: วัตถุดิบสองเท่า")
	end

	entry.crop, entry.at, entry.glow = nil, nil, nil
	model:SetAttribute("Glow", nil) -- ใช้แล้วหมด รอบหน้าทอยใหม่ตอนสุก
	model:SetAttribute("Ripe", nil)
	local state = Plots[model]
	if state then state.stage = nil end
	showCrop(model, entry, 1)
	return true
end

--------------------------------------------------------------------------------
-- ลูป: ใส่ปุ่มให้แปลงที่ยังไม่มี · อัปเดตพืชและป้ายทุกแปลง
--------------------------------------------------------------------------------

-- เมล็ดที่ผู้เล่นมีและปลูกได้ที่เลเวลนี้ · คืน (รายการ, เมล็ดที่มีแต่ยังล็อก)
local function usableSeeds(player)
	local level = IslandAccess.FarmLevel()
	local usable, locked = {}, nil
	for _, seedId in ipairs(IslandConfig.SeedItems) do
		local count = Inventory.CountOf(player, seedId)
		if count > 0 then
			if #IslandConfig.CropsFor(seedId, level) > 0 then
				local item = ItemCatalog.Get(seedId)
				usable[#usable + 1] = { id = seedId, count = count, name = item and item.name or seedId,
					icon = item and item.icon or "" }
			else
				locked = locked or seedId
			end
		end
	end
	return usable, locked
end

-- กด E ที่แปลงว่าง: เมล็ดชนิดเดียว = หยอด · หลายชนิด = ใช้ที่เลือกไว้ (ภายใน 90 วิ) ไม่งั้นถามก่อน
local function plantFromPrompt(player, model)
	if not IslandAccess.IsOwner(player) then return false, "notowner" end
	local usable, locked = usableSeeds(player)
	if #usable == 0 then
		if locked then
			local item = ItemCatalog.Get(locked)
			return false, ("%s ปลูกได้ที่เลเวลฟาร์ม %d"):format(item and item.name or locked, seedLevel(locked) or 1)
		end
		return false, "noseed"
	end
	if #usable == 1 then return plant(player, model, usable[1].id) end
	local choice = Choice[player]
	if choice and os.clock() - choice.at <= CHOICE_SECONDS then
		for _, s in ipairs(usable) do
			if s.id == choice.seed then
				choice.at = os.clock()
				Remotes.IslandSeedChoice:FireClient(player, "active", s.id, CHOICE_SECONDS)
				return plant(player, model, s.id)
			end
		end
	end
	local entry = IslandAccess.EntryOf(model)
	Remotes.IslandSeedChoice:FireClient(player, "ask", entry and entry.uid, usable)
	return true
end

local function ensurePrompt(model)
	local soil = model:FindFirstChild("Soil")
	if not soil then return nil end
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "PlotPrompt"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = soil
	prompt.Triggered:Connect(function(player)
		local entry = IslandAccess.EntryOf(model)
		if not entry then return end
		local ok, reason
		if entry.crop then ok, reason = harvest(player, model) else ok, reason = plantFromPrompt(player, model) end
		if not ok then notify(player, reason) end
	end)
	return prompt
end

local function tick()
	local island = workspace:FindFirstChild("WOLD_Island")
	local folder = island and island:FindFirstChild("Placed")
	for model, _ in pairs(Plots) do
		if not model.Parent then Plots[model] = nil end
	end
	if not folder then return end
	for _, model in ipairs(folder:GetChildren()) do
		if model:GetAttribute("ItemId") == "FarmPlot" then
			local state = Plots[model]
			if not state then
				local prompt = ensurePrompt(model)
				if prompt then
					state = { prompt = prompt }
					Plots[model] = state
				end
			end
			local entry = state and IslandAccess.EntryOf(model)
			if state and entry then
				if entry.crop then
					local progress = progressOf(entry)
					local stage = stageOf(progress)
					if stage ~= state.stage then
						showCrop(model, entry, stage)
						state.stage = stage
					end
					local item = ItemCatalog.Get(entry.crop)
					local name = item and item.name or entry.crop
					if progress >= 1 then ripen(model, entry) end -- แสงก่อนเปิดปุ่ม
					-- **ปุ่มที่กดไม่ได้ต้องซ่อน** (ผู้ใช้สั่ง 2026-09-25) — ระหว่างโตกด E ได้แค่ "ยังไม่สุก"
					state.prompt.Enabled = progress >= 1
					if progress >= 1 then
						state.prompt.ActionText = "เก็บเกี่ยว"
						state.prompt.ObjectText = ("%s · สุกแล้ว"):format(name)
					else
						state.prompt.ActionText = "รอ..."
						state.prompt.ObjectText = ("%s · เหลือ %d นาที"):format(name, minutesLeft(entry))
					end
					-- ประกาศให้ป้ายลอย (`IslandBadgeController`) อ่าน — **ไม่ให้มันอ่านข้อความบนปุ่ม**
					-- ซึ่งเป็นคำไทยที่เปลี่ยนเมื่อไหร่ก็พังเงียบๆ · แอตทริบิวต์ replicate ให้ฟรีอยู่แล้ว
					model:SetAttribute("Ripe", progress >= 1 or nil)
				else
					if state.stage then showCrop(model, entry, 1); state.stage = nil end
					state.prompt.Enabled = true
					state.prompt.ActionText = "หยอดเมล็ด"
					state.prompt.ObjectText = "แปลงว่าง"
					model:SetAttribute("Ripe", nil)
				end
			end
		end
	end
end

task.spawn(function()
	while true do
		local ok, err = pcall(tick)
		if not ok then warn("[IslandPlots] " .. tostring(err)) end
		task.wait(TICK)
	end
end)

-- เลือกเมล็ดจากหน้าต่างเล็ก (ไคลเอนต์ส่ง uid ของแปลง + เมล็ดที่เลือก) → จำไว้ 90 วิ แล้วหยอดแปลงนั้นเลย
Remotes.IslandPlantSeed.OnServerEvent:Connect(function(player, uid, seedId)
	if type(seedId) ~= "string" or not isSeed(seedId) then return end
	local model = IslandAccess.ModelOf and IslandAccess.ModelOf(tonumber(uid) or -1)
	if not model or model:GetAttribute("ItemId") ~= "FarmPlot" then return notify(player, "missing") end
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not root or (model:GetPivot().Position - root.Position).Magnitude > 18 then return notify(player, "far") end
	local ok, reason = plant(player, model, seedId)
	if ok then
		Choice[player] = { seed = seedId, at = os.clock() }
		Remotes.IslandSeedChoice:FireClient(player, "active", seedId, CHOICE_SECONDS)
	elseif reason then
		notify(player, reason)
	end
end)

-- ปุ่ม "เปลี่ยน" บนแถบเมล็ด = ลืมที่เลือกไว้ แปลงถัดไปจะถามใหม่
Remotes.IslandSeedChoice.OnServerEvent:Connect(function(player, what)
	if what == "clear" then Choice[player] = nil end
end)

game:GetService("Players").PlayerRemoving:Connect(function(player)
	Choice[player] = nil
end)

IslandAccess.Plant = plant
IslandAccess.Harvest = harvest
IslandAccess.Tick = tick
