-- IslandBadgeController: ป้ายอีโมจิลอยเหนือของที่ "พร้อมเก็บ" บนเกาะฟาร์ม
--
-- ผู้ใช้สั่ง 2026-09-23: "แร่อันไหนพร้อมเก็บให้ขึ้นเป็นป้ายสถานะลอยขึ้นมาเป็นอีโมจิอีเต้อ ·
-- ฟาร์มผักอันไหนพร้อมเก็บเกี่ยวให้ขึ้นเป็นอีโมจิเคียว · ฟาร์มสัตว์อันไหนพร้อมเก็บเกี่ยวขึ้นเป็นอีโมจิ
-- อุ้งเท้าสัตว์ · บอร์ดเควสถ้ามีเควสส่งได้ขึ้นอีโมจิรูปเงิน · พวกอุปกรณ์ฟาร์มผิดกฎหมายขึ้นอีโมจิประแจ"
--
-- **ทำฝั่งไคลเอนต์ทั้งหมด** เพราะคำตอบสองอย่างเป็นรายคน (เควสส่งได้ไหม · ฟาร์มเถื่อนใช้สิทธิ์วันนี้ไปยัง)
-- BillboardGui ที่สร้างฝั่งนี้เห็นคนเดียว จึงตอบรายคนได้โดยไม่ต้องมีป้ายของใครไปโผล่บนจอคนอื่น
--
-- ⚠️ **ลูปถามใหม่ทุกวินาที ไม่ผูก event ครั้งเดียวตอนเริ่ม** (กฎเหล็ก StreamingEnabled ของโปรเจ็ค) —
-- โหนดบนเกาะโผล่/หายตลอดเวลา และแท็กกับชิ้นส่วนมาถึงคนละรอบ
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer

-- IslandMode ถูกตั้งโดย ServerConfig ตอนบูต · รอให้มันมาก่อนแล้วค่อยตัดสิน (ไคลเอนต์อ่าน PlaceId ไม่ได้)
while workspace:GetAttribute("IslandMode") == nil do task.wait(0.2) end
if workspace:GetAttribute("IslandMode") ~= true then return end

local IslandConfig = require(ReplicatedStorage.IslandConfig)
local GatherConfig = require(ReplicatedStorage.GatherConfig)
local QuestConfig = require(ReplicatedStorage.QuestConfig)

local CFG = IslandConfig.Badges
if not (CFG and CFG.enabled) then return end

-- เครื่องมือ -> อีโมจิ · ชนิดที่ไม่มีเครื่องมือ (สัตว์) ถูกดักไว้ก่อนถึงตารางนี้
local BY_TOOL = { pickaxe = CFG.pickaxe, axe = CFG.axe, shovel = CFG.shovel }

local Badges = {} -- [instance] = BillboardGui

--------------------------------------------------------------------------------
-- ป้าย
--------------------------------------------------------------------------------

-- หาชิ้นที่แขวนป้ายได้ + ความสูงของโมเดล (ป้ายต้องลอยเหนือยอด ไม่ใช่เหนือจุดหมุน)
local function anchorOf(inst)
	if inst:IsA("BasePart") then return inst, inst.Size.Y / 2 end
	if not inst:IsA("Model") then return nil end
	local part = inst.PrimaryPart or inst:FindFirstChildWhichIsA("BasePart", true)
	if not part then return nil end
	local ok, cf, size = pcall(function()
		local a, b = inst:GetBoundingBox()
		return a, b
	end)
	if not ok or not cf then return part, part.Size.Y / 2 end
	-- ระยะจากชิ้นที่แขวนไปถึงยอดกล่องครอบ
	return part, (cf.Position.Y + size.Y / 2) - part.Position.Y
end

local function show(inst, emoji)
	local gui = Badges[inst]
	if not gui then
		local part, lift = anchorOf(inst)
		if not part then return end
		gui = Instance.new("BillboardGui")
		gui.Name = "WOLD_Badge"
		-- **Scale ของ BillboardGui มีหน่วยเป็นสตัด** (Offset ถึงจะเป็นพิกเซล) — ป้ายจึงเล็กลง
		-- ตามระยะเหมือนของในโลก ไม่ใช่ป้ายขนาดเท่ากันหมดที่ต้องตัดระยะทิ้งถึงจะไม่รก
		gui.Size = UDim2.fromScale(CFG.sizeStuds, CFG.sizeStuds)
		gui.StudsOffsetWorldSpace = Vector3.new(0, lift + CFG.lift, 0)
		gui.MaxDistance = CFG.maxDistance

		local label = Instance.new("TextLabel")
		label.Name = "Icon"
		label.BackgroundTransparency = 1
		label.Size = UDim2.fromScale(1, 1)
		label.Font = Enum.Font.GothamBold
		label.TextScaled = true
		label.Text = emoji
		-- ขอบดำบางๆ ให้อ่านออกทั้งบนหญ้าสว่างและในเงาหิน
		label.TextStrokeTransparency = 0.4
		label.Parent = gui

		-- **แขวนไว้กับชิ้นนั้นเลย ไม่ใช่ PlayerGui** — ของที่ไคลเอนต์สร้างอยู่แค่บนเครื่องนี้ไม่ว่าจะ
		-- แขวนไว้ที่ไหน (ป้ายรายคนจึงยังเป็นรายคน) แต่แบบนี้มันหายไปพร้อมโหนดที่ถูกเก็บเอง
		-- และไม่ต้องไปยุ่งกับการล้าง PlayerGui ตอนตัวละครเกิดใหม่
		gui.Parent = part
		Badges[inst] = gui
	elseif gui.Icon.Text ~= emoji then
		gui.Icon.Text = emoji
	end
end

local function hide(inst)
	local gui = Badges[inst]
	if gui then gui:Destroy(); Badges[inst] = nil end
end

--------------------------------------------------------------------------------
-- แสงเรือง (ผู้ใช้สั่ง 2026-09-23: ทอง = EXP ×2 · ฟ้า = วัตถุดิบ ×2)
--------------------------------------------------------------------------------
--
-- เซิร์ฟเวอร์ทอยแล้วเขียนไว้ที่แอตทริบิวต์ `Glow` — ตรงนี้แค่แปลงเป็นภาพ · **เป็นสถานะของโลก
-- ไม่ใช่ของใครคนหนึ่ง** ทุกคนที่ยืนอยู่จึงเห็นก้อนเดียวกัน (ทุกเครื่องวาดจากธงเดียวกัน)
local GLOW = IslandConfig.Glow
local Glows = {} -- [instance] = Folder

local function showGlow(inst, tone)
	local color = GLOW.colors[tone]
	if not color then return end
	local holder = Glows[inst]
	if holder then
		if holder:GetAttribute("Tone") ~= tone then
			holder:SetAttribute("Tone", tone)
			holder.Light.Color = color
			holder.Sparkle.Color = ColorSequence.new(color)
		end
		return
	end

	local part = anchorOf(inst)
	if not part then return end
	holder = Instance.new("Folder")
	holder.Name = "WOLD_Glow"
	holder:SetAttribute("Tone", tone)

	local light = Instance.new("PointLight")
	light.Name = "Light"
	light.Color = color
	light.Brightness = GLOW.brightness
	light.Range = GLOW.range
	light.Shadows = false -- แสงนี้มีได้หลายสิบดวงพร้อมกัน เงาคือค่าใช้จ่ายที่ไม่ได้อะไรกลับมา
	light.Parent = holder

	local sparkle = Instance.new("ParticleEmitter")
	sparkle.Name = "Sparkle"
	sparkle.Color = ColorSequence.new(color)
	sparkle.LightEmission = 1
	sparkle.LightInfluence = 0
	sparkle.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.4, 0.55),
		NumberSequenceKeypoint.new(1, 0),
	})
	sparkle.Transparency = NumberSequence.new(0.25)
	sparkle.Rate = 7
	sparkle.Lifetime = NumberRange.new(1.1, 1.8)
	sparkle.Speed = NumberRange.new(0.6, 1.4)
	sparkle.SpreadAngle = Vector2.new(180, 180)
	sparkle.Acceleration = Vector3.new(0, 1.5, 0) -- ลอยขึ้น ไม่ใช่ร่วงลง
	sparkle.Parent = holder

	holder.Parent = part
	Glows[inst] = holder
end

local function hideGlow(inst)
	local holder = Glows[inst]
	if holder then holder:Destroy(); Glows[inst] = nil end
end

--------------------------------------------------------------------------------
-- ใครพร้อมเก็บบ้าง
--------------------------------------------------------------------------------

-- จุดเก็บเกี่ยว: หิน แร่ ต้นไม้ พุ่ม และสัตว์ในคอก (ทั้งหมดติดแท็ก WOLD_Node เหมือนกัน)
--
-- อ่านจาก **แอตทริบิวต์ที่เซิร์ฟเวอร์ประกาศ** ไม่ใช่จาก `ProximityPrompt.Enabled` — ปุ่มถูก
-- `GatherController` ปิดฝั่งไคลเอนต์เองเมื่อไม่ได้ถือเครื่องมือ ถ้าอ่านจากปุ่ม ป้ายจะหายไปด้วย
-- ทั้งที่ของยังพร้อมเก็บอยู่ (ซึ่งเป็นสิ่งเดียวที่ป้ายนี้ต้องตอบ)
local function nodeEmoji(node)
	if node:GetAttribute("Spent") then return nil end
	-- ของป่าที่เก็บไปแล้ววันนี้ (Wild_* ที่ซื้อมาวาง) ยังไม่พร้อมจนกว่าจะข้ามวัน
	if node:GetAttribute("DailyNode") and node:GetAttribute("HarvestedDay") == QuestConfig.DayNumber() then
		return nil
	end

	-- สัตว์ในคอก: `BornAt` มีเฉพาะตัวที่ `IslandZones` เลี้ยง · ตัวที่ยังโตไม่เต็มวัยยังเก็บไม่ได้
	if node:GetAttribute("BornAt") then
		return node:GetAttribute("Grown") and CFG.animal or nil
	end

	local config = GatherConfig.Nodes[node:GetAttribute("NodeKind")]
	return config and BY_TOOL[config.tool] or nil
end

local function sweepNodes(seen, lit)
	for _, node in ipairs(CollectionService:GetTagged("WOLD_Node")) do
		if node:IsDescendantOf(workspace) then
			local emoji = nodeEmoji(node)
			if emoji then seen[node] = emoji end
			-- **แสงไม่ได้ผูกกับความพร้อม** สัตว์ที่ยังโตไม่เต็มวัยก็เรืองแสงรอไว้ได้ (ธงถูกทอยตอนมันเกิด)
			local tone = node:GetAttribute("Glow")
			if tone then lit[node] = tone end
		end
	end
end

-- แปลงผักสุกแล้ว — `Ripe` ถูกประกาศโดย `IslandPlots` (ไม่ได้อ่านข้อความบนปุ่ม ซึ่งเป็นคำไทยที่เปลี่ยนได้)
local function sweepPlots(seen, lit)
	local island = workspace:FindFirstChild("WOLD_Island")
	local placed = island and island:FindFirstChild("Placed")
	for _, model in ipairs(placed and placed:GetChildren() or {}) do
		if model:GetAttribute("Ripe") then seen[model] = CFG.crop end
		local tone = model:GetAttribute("Glow")
		if tone then lit[model] = tone end
	end
end

-- บอร์ดเควส: ธงรายคนจาก `Quests.server`
local function sweepQuestBoards(seen)
	if not player:GetAttribute("WOLD_QuestTurnIn") then return end
	for _, board in ipairs(CollectionService:GetTagged("WOLD_QuestBoard")) do
		if board:IsDescendantOf(workspace) then seen[board] = CFG.quest end
	end
end

-- ฟาร์มผิดกฎหมาย: คูลดาวน์อยู่บนโหนด (`FarmReadyAt`) · สิทธิ์รายวันอยู่บนตัวเรา (`WOLD_FarmDone`)
local function sweepFarms(seen)
	local doneList = player:GetAttribute("WOLD_FarmDone")
	local done = {}
	for name in tostring(doneList or ""):gmatch("[^,]+") do done[name] = true end

	local now = workspace:GetServerTimeNow()
	for _, node in ipairs(CollectionService:GetTagged("WOLD_Farm")) do
		if node:IsDescendantOf(workspace) and not done[node.Name] then
			local readyAt = node:GetAttribute("FarmReadyAt")
			if not readyAt or now >= readyAt then seen[node] = CFG.farm end
		end
	end
end

--------------------------------------------------------------------------------
task.spawn(function()
	while true do
		local seen, lit = {}, {}
		local ok, err = pcall(function()
			sweepNodes(seen, lit)
			sweepPlots(seen, lit)
			sweepQuestBoards(seen)
			sweepFarms(seen)
		end)
		if not ok then warn("[IslandBadge] กวาดไม่สำเร็จ:", err) end

		for inst, emoji in pairs(seen) do show(inst, emoji) end
		for inst, tone in pairs(lit) do showGlow(inst, tone) end
		-- เก็บกวาดป้าย/แสงของสิ่งที่ไม่พร้อมแล้ว หรือถูกเก็บไปแล้ว (โหนดหายไปเลยก็มี)
		for inst in pairs(Badges) do
			if not seen[inst] or not inst:IsDescendantOf(workspace) then hide(inst) end
		end
		for inst in pairs(Glows) do
			if not lit[inst] or not inst:IsDescendantOf(workspace) then hideGlow(inst) end
		end

		task.wait(CFG.refreshSeconds)
	end
end)
