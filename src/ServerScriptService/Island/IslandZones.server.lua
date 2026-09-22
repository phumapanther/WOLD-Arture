-- IslandZones: ของวางที่ "ทำงานเอง" สามอย่าง — คอกสัตว์ · โซนแร่ · ต้นไม้ที่ปลูกเอง
--
-- ทั้งสามใช้โครงเดียวกัน: โมเดลที่ผู้เล่นวาง (IslandBuild เป็นเจ้าของ) + สถานะใน entry ของมันเอง + ลูกที่
-- ระบบปลูกลงไปในโมเดลนั้น ติดแท็ก `WOLD_Node` ให้ **ระบบ Gathering ของเกมหลักเป็นคนแจกของ** —
-- ไฟล์นี้จึงไม่รู้เลยว่าไก่ให้ไข่กี่ฟองหรือแร่เหล็กให้กี่ก้อน (`GatherConfig` เป็นเจ้าของคำตอบนั้นที่เดียว)
--
-- ลูป 3 วิถามใหม่ทุกอย่าง ไม่ผูก event ครั้งเดียวตอนบูต (กฎเหล็ก StreamingEnabled)
local ServerConfig = require(game.ServerScriptService.ServerConfig)
if not ServerConfig.IsFarm then return end

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local Inventory = require(game.ServerScriptService.Inventory)
local IslandAccess = require(script.Parent.IslandAccess)
local IslandConfig = require(ReplicatedStorage.IslandConfig)
local IslandGrid = require(ReplicatedStorage.IslandGrid)
local Remotes = require(ReplicatedStorage.Remotes)

local TICK = 3
local NODE_TAG = "WOLD_Node"
local Wired = {} -- [model] = true (ใส่ปุ่มให้แล้ว)

local function notify(player, kind, text)
	Remotes.SocialNotify:FireClient(player, kind, text)
end

local function prototypeOf(name)
	local folder = ReplicatedStorage:FindFirstChild("WOLD_Placeables")
	return folder and folder:FindFirstChild(name)
end

local function groundAt(wx, wz)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { workspace.Terrain }
	params.IgnoreWater = true
	local hit = workspace:Raycast(Vector3.new(wx, IslandConfig.Center.Y + 80, wz), Vector3.new(0, -300, 0), params)
	return hit and hit.Position.Y or (IslandConfig.Center.Y + 17)
end

-- สุ่มจุดในกรอบของโมเดล (เว้นขอบไว้ ไม่ให้ของไปโผล่ทับรั้ว)
local function randomSpotIn(model, inset)
	local cf, size = model:GetBoundingBox()
	local halfX = math.max(1, size.X / 2 - (inset or 3))
	local halfZ = math.max(1, size.Z / 2 - (inset or 3))
	local x = cf.Position.X + (math.random() * 2 - 1) * halfX
	local z = cf.Position.Z + (math.random() * 2 - 1) * halfZ
	return x, z
end

--------------------------------------------------------------------------------
-- คอกสัตว์
--------------------------------------------------------------------------------

local function penFolder(model)
	local f = model:FindFirstChild("Livestock")
	if not f then f = Instance.new("Folder"); f.Name = "Livestock"; f.Parent = model end
	return f
end

local function penCount(model)
	return #penFolder(model):GetChildren()
end

-- ปล่อยสัตว์หนึ่งตัวลงคอก · ติดแท็กให้ Gathering ของเกมหลักต่อปุ่ม "เก็บไข่/รีดนม/ตัดขน" ให้เอง
local function spawnAnimal(model, kind)
	local proto = prototypeOf("Animal_" .. kind)
	if not proto then
		warn("[IslandZones] ไม่มีต้นแบบ Animal_" .. tostring(kind))
		return false
	end
	local animal = proto:Clone()
	animal.Name = kind
	local x, z = randomSpotIn(model, 4)
	animal:PivotTo(CFrame.new(x, groundAt(x, z), z) * CFrame.Angles(0, math.random() * math.pi * 2, 0))
	animal:SetAttribute("NodeKind", kind)
	-- **นาฬิกาของตัวมันเอง** ไม่ใช่ของคอก — ซื้อคนละเวลา โตคนละเวลา (ผู้ใช้สั่ง "คูลดาวน์ต่อตัว")
	animal:SetAttribute("ReadyAt", os.time() + IslandConfig.PenGrowSeconds)
	-- `HerdAnimal` คือธงที่ Gathering ของเกมหลักอ่านแล้ว **ลบตัวนั้นทิ้งหลังเก็บ** — ตรงกับที่ผู้ใช้สั่ง
	-- ว่า "เก็บแล้วหายไป" พอดี จึงไม่ต้องเขียนตรรกะการลบเองเลย
	animal:SetAttribute("HerdAnimal", true)
	animal:SetAttribute("Spent", true) -- ยังโตไม่พอ: ปุ่มถูกปิดไว้จนกว่า tickPen จะปลดให้
	CollectionService:AddTag(animal, NODE_TAG)
	animal.Parent = penFolder(model)
	return true
end

-- หน้าต่างเลือกสัตว์ = เมนูของ ClassActionGui? ไม่ — ใช้ปุ่มเดียวแล้ววนชนิดไม่ได้เรื่อง จึงส่งรายการไปให้
-- ไคลเอนต์วาดด้วย Remote เดียวกับร้าน (IslandPenOpen) ทรงเดียวกับที่ Shop ใช้: เซิร์ฟเวอร์ส่งภาพรวมทั้งก้อน
local function penSnapshot(model)
	local entry = IslandAccess.EntryOf(model)
	local rows = {}
	for _, a in ipairs(IslandConfig.PenAnimals) do
		table.insert(rows, { kind = a.kind, name = a.name, price = a.price })
	end
	-- นับตัวที่โตพร้อมเก็บแล้ว ให้หน้าจอบอกได้ว่ารออะไรอยู่
	local ready, now = 0, os.time()
	for _, a in ipairs(penFolder(model):GetChildren()) do
		if (a:GetAttribute("ReadyAt") or 0) <= now then ready += 1 end
	end
	return {
		uid = entry and entry.uid,
		animals = rows,
		count = penCount(model),
		ready = ready,
		max = IslandConfig.PenMax,
		kind = entry and entry.animal,
	}
end

-- ซื้อสัตว์ n ตัว: เกิดในคอกทันที หักเงินตามจำนวนที่เกิดจริง (ผู้ใช้สั่ง "ซื้อแล้วนับสัตว์ในคอกเลย")
local function penBuy(player, model, kind, count)
	if not IslandAccess.IsOwner(player) then return false, "เฉพาะเจ้าของเกาะ" end
	local entry = IslandAccess.EntryOf(model)
	if not entry then return false, "ไม่พบคอกนี้" end
	local spec
	for _, a in ipairs(IslandConfig.PenAnimals) do if a.kind == kind then spec = a break end end
	if not spec then return false, "ไม่มีสัตว์ชนิดนั้น" end

	count = math.clamp(math.floor(tonumber(count) or 1), 1, IslandConfig.PenMax)
	-- **นับจากตัวที่ยืนอยู่จริงในคอก** (ผู้ใช้สั่ง) ไม่มีคิวให้ค้าง ซื้อเท่าไหร่ก็โผล่เท่านั้นทันที
	local room = IslandConfig.PenMax - penCount(model)
	if room <= 0 then return false, ("คอกเต็มแล้ว (%d ตัว)"):format(IslandConfig.PenMax) end
	count = math.min(count, room)

	local state = Inventory.Get(player)
	local cost = spec.price * count
	if not state or state.gold < cost then return false, "เงินไม่พอ" end

	-- คอกหนึ่งเลี้ยงชนิดเดียว: ซื้อชนิดใหม่ทับของเดิมไม่ได้ · คอกที่ว่างแล้วเปลี่ยนชนิดได้เลย
	if entry.animal and entry.animal ~= kind and penCount(model) > 0 then
		return false, "คอกนี้มีสัตว์ชนิดอื่นอยู่ รอเก็บให้หมดก่อน"
	end

	local born = 0
	for _ = 1, count do
		if spawnAnimal(model, kind) then born += 1 end
	end
	if born == 0 then return false, "ปล่อยสัตว์ลงคอกไม่สำเร็จ" end
	Inventory.AddGold(player, -spec.price * born)
	entry.animal = kind
	notify(player, "info", ("ซื้อ%s %d ตัว — โตพอให้เก็บใน %d นาที"):format(spec.name, born, IslandConfig.PenGrowSeconds / 60))
	return true
end

-- ปลดล็อกสัตว์ที่โตครบแล้วทีละตัว · คอกที่ว่างหมดคืนชนิดให้ว่าง (เลี้ยงชนิดใหม่ได้)
--
-- **สถานะอยู่บนตัวสัตว์ ไม่ใช่ในโปรไฟล์** ตั้งใจ: สัตว์เป็นของชั่วคราวที่หายไปตอนเก็บและหายตอนเซิร์ฟปิด
-- (เหมือนสัตว์ในเกมหลักและของในหีบ) ถ้าเก็บลงโปรไฟล์ด้วย จะต้องตามซิงก์สองที่ตลอดชีวิตโปรเจ็ค
local function tickPen(model, entry)
	local live = penFolder(model):GetChildren()
	if #live == 0 then
		if entry.animal then entry.animal = nil end
		return
	end
	local now = os.time()
	for _, animal in ipairs(live) do
		if animal:GetAttribute("Spent") and (animal:GetAttribute("ReadyAt") or 0) <= now then
			animal:SetAttribute("Spent", nil)
			for _, d in ipairs(animal:GetDescendants()) do
				if d:IsA("ProximityPrompt") then d.Enabled = true end
			end
		end
	end
end

--------------------------------------------------------------------------------
-- โซนแร่
--------------------------------------------------------------------------------

local function rockFolder(model)
	local f = model:FindFirstChild("Rocks")
	if not f then f = Instance.new("Folder"); f.Name = "Rocks"; f.Parent = model end
	return f
end

local function rollRock()
	local total = 0
	for _, r in ipairs(IslandConfig.MineRocks) do total += r.weight end
	local pick = math.random() * total
	for _, r in ipairs(IslandConfig.MineRocks) do
		pick -= r.weight
		if pick <= 0 then return r.kind end
	end
	return IslandConfig.MineRocks[1].kind
end

-- ก้อนแร่: ใช้ต้นแบบ Deco_Crate ไม่ได้ (คนละเรื่อง) ปั้นก้อนหินง่ายๆ ตรงนี้ แล้วให้ Gathering แจกของ
local ROCK_COLOUR = {
	Rock = Color3.fromRGB(150, 148, 150),
	IronOre = Color3.fromRGB(150, 110, 90),
	SilverOre = Color3.fromRGB(198, 202, 210),
	GoldOre = Color3.fromRGB(216, 176, 72),
	MagicOre = Color3.fromRGB(120, 140, 220),
	DiamondOre = Color3.fromRGB(150, 226, 235),
}

local function spawnRock(model, kind)
	local rock = Instance.new("Model")
	rock.Name = kind
	local x, z = randomSpotIn(model, 3)
	local y = groundAt(x, z)
	local colour = ROCK_COLOUR[kind] or ROCK_COLOUR.Rock
	local base = Instance.new("Part")
	base.Name = "Chunk"
	base.Anchored = true
	base.Size = Vector3.new(3.2, 2.6, 3.0)
	base.CFrame = CFrame.new(x, y + 1.1, z) * CFrame.Angles(math.random() * 0.3, math.random() * math.pi * 2, math.random() * 0.3)
	base.Material = Enum.Material.Rock
	base.Color = colour
	base.Parent = rock
	-- ก้อนเล็กเกาะข้าง ให้ไม่ใช่กล่องเปล่า · แร่มีค่าเรืองแสงนิดหน่อยให้เห็นแต่ไกล
	local bump = Instance.new("Part")
	bump.Anchored = true
	bump.Size = Vector3.new(1.7, 1.5, 1.6)
	bump.CFrame = base.CFrame * CFrame.new(1.4, -0.5, 0.6) * CFrame.Angles(0.4, 0.8, 0)
	bump.Material = Enum.Material.Rock
	bump.Color = colour
	bump.Parent = rock
	if kind ~= "Rock" then
		local vein = Instance.new("Part")
		vein.Anchored = true
		vein.CanCollide = false
		vein.Size = Vector3.new(0.7, 0.7, 0.7)
		vein.CFrame = base.CFrame * CFrame.new(0, 1.2, 0)
		vein.Material = Enum.Material.Neon
		vein.Color = colour
		vein.Parent = rock
	end
	rock.PrimaryPart = base
	rock:SetAttribute("NodeKind", kind)
	CollectionService:AddTag(rock, NODE_TAG)
	rock.Parent = rockFolder(model)
end

local function tickMine(model, entry)
	local folder = rockFolder(model)
	local alive = #folder:GetChildren()
	if alive >= IslandConfig.MineMax then
		entry.nextAt = entry.nextAt or (os.time() + IslandConfig.MineEverySeconds)
		return
	end
	if not entry.nextAt then
		entry.nextAt = os.time() + IslandConfig.MineEverySeconds
		-- โซนที่เพิ่งวาง: ให้ก้อนแรกเลย ไม่ต้องรอสิบนาทีถึงจะรู้ว่ามันทำงาน
		if alive == 0 then spawnRock(model, rollRock()) end
		return
	end
	if os.time() >= entry.nextAt then
		for _ = 1, IslandConfig.MinePerRound do
			if #folder:GetChildren() >= IslandConfig.MineMax then break end
			spawnRock(model, rollRock())
		end
		entry.nextAt = os.time() + IslandConfig.MineEverySeconds
	end
end

--------------------------------------------------------------------------------
-- ต้นไม้ที่ปลูกเอง
--------------------------------------------------------------------------------

-- ต้นไม้วางแล้วเล็กก่อน โตเต็มที่จึงตัดได้ · ตัดแล้ว Gathering ซ่อนชิ้นส่วนไว้ชั่วคราวตามกติกาของมัน
-- (`respawnSeconds` ของ GatherConfig) — ไฟล์นี้แค่คุมขนาดกับแท็ก ไม่ยุ่งกับของที่ได้
local function tickTree(model, entry)
	if not entry.at then entry.at = os.time() end
	local progress = math.clamp((os.time() - entry.at) / IslandConfig.TreeGrowSeconds, 0, 1)
	local stage = 1
	for i, s in ipairs(IslandConfig.Stages) do
		if progress >= s.at then stage = i end
	end
	if entry.stage ~= stage then
		model:ScaleTo(IslandConfig.Stages[stage].scale)
		entry.stage = stage
		-- โตเต็มที่ = ตัดได้ · ก่อนหน้านั้นไม่มีแท็ก ปุ่มจึงไม่ขึ้นเลย (ต้นกล้าตัดไม่ได้)
		if progress >= 1 then
			model:SetAttribute("NodeKind", "Tree")
			if not CollectionService:HasTag(model, NODE_TAG) then CollectionService:AddTag(model, NODE_TAG) end
		end
	end
end

--------------------------------------------------------------------------------
-- ปุ่มของคอก + ลูปรวม
--------------------------------------------------------------------------------

local function wirePen(model)
	local anchor = model:FindFirstChild("PenAnchor", true) or model.PrimaryPart
	if not anchor then return end
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "PenPrompt"
	prompt.ActionText = "เลือกสัตว์"
	prompt.ObjectText = "คอกสัตว์"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 14
	prompt.RequiresLineOfSight = false
	prompt.Parent = anchor
	prompt.Triggered:Connect(function(player)
		if not IslandAccess.IsOwner(player) then return notify(player, "error", "เฉพาะเจ้าของเกาะ") end
		Remotes.IslandPenOpen:FireClient(player, penSnapshot(model))
	end)
end

local function tick()
	local island = workspace:FindFirstChild("WOLD_Island")
	local folder = island and island:FindFirstChild("Placed")
	if not folder then return end
	for model in pairs(Wired) do
		if not model.Parent then Wired[model] = nil end
	end
	for _, model in ipairs(folder:GetChildren()) do
		local id = model:GetAttribute("ItemId")
		local entry = IslandAccess.EntryOf(model)
		if entry then
			if id == IslandConfig.PenItem then
				if not Wired[model] then wirePen(model); Wired[model] = true end
				tickPen(model, entry)
			elseif id == IslandConfig.MineItem then
				Wired[model] = true
				tickMine(model, entry)
			elseif id == IslandConfig.TreeItem then
				Wired[model] = true
				tickTree(model, entry)
			end
		end
	end
end

task.spawn(function()
	while true do
		local ok, err = pcall(tick)
		if not ok then warn("[IslandZones] " .. tostring(err)) end
		task.wait(TICK)
	end
end)

Remotes.IslandPenBuy.OnServerEvent:Connect(function(player, uid, kind, count)
	local model = IslandAccess.ModelOf(tonumber(uid) or -1)
	if not model or model:GetAttribute("ItemId") ~= IslandConfig.PenItem then return end
	local ok, why = penBuy(player, model, tostring(kind), count)
	if not ok then
		notify(player, "error", why)
	end
	Remotes.IslandPenOpen:FireClient(player, penSnapshot(model)) -- วาดใหม่เสมอ สำเร็จหรือไม่ก็ตาม
end)

IslandAccess.PenBuy = penBuy
IslandAccess.PenSnapshot = penSnapshot
IslandAccess.ZonesTick = tick
