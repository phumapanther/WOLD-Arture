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
local GatherConfig = require(ReplicatedStorage.GatherConfig)
local ItemCatalog = require(ReplicatedStorage.ItemCatalog)
local Remotes = require(ReplicatedStorage.Remotes)

local TICK = 2
local Plots = {} -- [plotModel] = { prompt = ProximityPrompt, stage = number|nil }

local REASON_TEXT = {
	notowner = "เฉพาะเจ้าของเกาะ",
	noseed = "ไม่มีเมล็ดพันธุ์ในกระเป๋า",
	planted = "แปลงนี้ปลูกอยู่แล้ว",
	empty = "แปลงว่าง หยอดเมล็ดก่อน",
	unripe = "ยังไม่สุก",
	full = "กระเป๋าเต็ม",
	missing = "ไม่พบแปลงนี้แล้ว",
}

local function notify(player, reason)
	Remotes.SocialNotify:FireClient(player, "error", REASON_TEXT[reason] or reason)
end

local function cropSpec(item)
	for _, c in ipairs(IslandConfig.Crops) do if c.item == item then return c end end
	return nil
end

local function rollCrop()
	local total = 0
	for _, c in ipairs(IslandConfig.Crops) do total += c.weight end
	local pick = math.random() * total
	for _, c in ipairs(IslandConfig.Crops) do
		pick -= c.weight
		if pick <= 0 then return c end
	end
	return IslandConfig.Crops[#IslandConfig.Crops]
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
	crop:ScaleTo(IslandConfig.Stages[stage].scale)
end

--------------------------------------------------------------------------------
-- ปลูก / เก็บเกี่ยว
--------------------------------------------------------------------------------

local function plant(player, model)
	if not IslandAccess.IsOwner(player) then return false, "notowner" end
	local entry = IslandAccess.EntryOf(model)
	if not entry then return false, "missing" end
	if entry.crop then return false, "planted" end
	local slot = Inventory.FindSlotById(player, IslandConfig.SeedItem)
	if not slot then return false, "noseed" end
	if not Inventory.RemoveFromSlot(player, slot, 1) then return false, "noseed" end
	local spec = rollCrop()
	entry.crop, entry.at = spec.item, os.time()
	local state = Plots[model]
	if state then state.stage = nil end -- ให้รอบถัดไปวาดใหม่
	local item = ItemCatalog.Get(spec.item)
	Remotes.SocialNotify:FireClient(player, "info", ("หยอดเมล็ดแล้ว — ขึ้นเป็น%s ใช้เวลา %d นาที"):format(item and item.name or spec.item, growSeconds(spec) / 60))
	return true
end

local function harvest(player, model)
	-- **แขกเก็บผักของเจ้าบ้านได้** (ผู้ใช้สั่ง 2026-09-23: "เพื่อนที่เข้ามาสามารถมาขโมยเก็บฟาร์มสัตว์
	-- และฟาร์มผักเราได้") — ส่วนการ *ปลูก* ยังเป็นของเจ้าของคนเดียว (เมล็ดเป็นของเขา แปลงเป็นของเขา)
	--
	-- ไม่ต้องเช็คอะไรเลยตรงนี้: คนที่ยืนอยู่บนเกาะนี้ได้ ผ่านด่านล็อบบี้ (เพื่อนกันจริง + เจ้าของอยู่)
	-- กับด่าน `IslandGuests` มาแล้วทั้งคู่ · ทรงเดียวกับ `Gathering` ที่ไม่เคยถามว่าใครเป็นเจ้าของที่
	local entry = IslandAccess.EntryOf(model)
	if not entry then return false, "missing" end
	if not entry.crop then return false, "empty" end
	if progressOf(entry) < 1 then return false, "unripe" end
	local spec = cropSpec(entry.crop)
	local amount = spec and math.random(spec.min, spec.max) or 1
	if not Inventory.HasRoomFor(player, entry.crop, amount) then return false, "full" end
	if not Inventory.AddItem(player, entry.crop, amount) then return false, "full" end
	local item = ItemCatalog.Get(entry.crop)
	Remotes.SocialNotify:FireClient(player, "info", ("เก็บเกี่ยวได้ %s x%d"):format(item and item.name or entry.crop, amount))

	-- หนอนติดมากับดิน (ผู้ใช้สั่ง 2026-09-22) — เกณฑ์เดียวกับสมุนไพร/นาข้าวในแมพหลัก
	--
	-- ใช้ `GatherConfig.WormBonus` ตัวเดียวกันเลย ไม่ได้ตั้งเลขใหม่ · เป็น **ของแถม** เหมือนที่นั่น
	-- ไม่ใช่ของที่ได้ *แทน* ผัก (แปลงผักในแมพหลักใช้ `alt` ซึ่งแลกผักทิ้ง — บนเกาะผู้เล่นจ่ายค่าเมล็ด
	-- กับรอเวลามาแล้ว การเอาผลผลิตของเขาไปทั้งกองเพื่อแจกหนอนไม่ใช่สิ่งที่สั่ง)
	--
	-- กระเป๋าเต็มตรงนี้ = หนอนหายเงียบๆ ไม่ขึ้นเตือนสีแดง เหมือน `Gathering` ทำกับของแถมทุกตัว
	-- เพราะการเก็บเกี่ยวสำเร็จไปแล้ว
	local bonus = GatherConfig.WormBonus
	if bonus and math.random() < bonus.chance then
		local extra = math.random(bonus.min, bonus.max)
		if Inventory.HasRoomFor(player, bonus.item, extra) and Inventory.AddItem(player, bonus.item, extra) then
			local worm = ItemCatalog.Get(bonus.item)
			Remotes.SocialNotify:FireClient(player, "info",
				("เจอ%s x%d ในดิน"):format(worm and worm.name or bonus.item, extra))
		end
	end
	entry.crop, entry.at = nil, nil
	local state = Plots[model]
	if state then state.stage = nil end
	showCrop(model, entry, 1)
	return true
end

--------------------------------------------------------------------------------
-- ลูป: ใส่ปุ่มให้แปลงที่ยังไม่มี · อัปเดตพืชและป้ายทุกแปลง
--------------------------------------------------------------------------------

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
		if entry.crop then ok, reason = harvest(player, model) else ok, reason = plant(player, model) end
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
					if progress >= 1 then
						state.prompt.ActionText = "เก็บเกี่ยว"
						state.prompt.ObjectText = name .. " · สุกแล้ว"
					else
						state.prompt.ActionText = "รอ..."
						state.prompt.ObjectText = ("%s · เหลือ %d นาที"):format(name, minutesLeft(entry))
					end
					-- ประกาศให้ป้ายลอย (`IslandBadgeController`) อ่าน — **ไม่ให้มันอ่านข้อความบนปุ่ม**
					-- ซึ่งเป็นคำไทยที่เปลี่ยนเมื่อไหร่ก็พังเงียบๆ · แอตทริบิวต์ replicate ให้ฟรีอยู่แล้ว
					model:SetAttribute("Ripe", progress >= 1 or nil)
				else
					if state.stage then showCrop(model, entry, 1); state.stage = nil end
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

IslandAccess.Plant = plant
IslandAccess.Harvest = harvest
IslandAccess.Tick = tick
