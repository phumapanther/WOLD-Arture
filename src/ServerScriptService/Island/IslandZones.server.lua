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
local HttpService = game:GetService("HttpService")
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

-- ชื่อไทยของสัตว์แต่ละชนิด สร้างจากคอนฟิกเอง ไม่ต้องพิมพ์ซ้ำ
-- ใครเปิดหน้าต่างคอกไหนค้างอยู่ — ส่งภาพใหม่ทุกไม่กี่วินาทีให้แถบโตเดินจริง
-- (ทรงเดียวกับที่บอร์ดเควสให้ไคลเอนต์ถามซ้ำ แต่ที่นี่เซิร์ฟเวอร์ผลักเอง เพราะมันเป็นเจ้าของนาฬิกา)
local Watching = {} -- [player] = penModel

local ANIMAL_NAMES = {}
for _, a in ipairs(IslandConfig.PenAnimals) do ANIMAL_NAMES[a.kind] = a.name end

local function penFolder(model)
	local f = model:FindFirstChild("Livestock")
	if not f then f = Instance.new("Folder"); f.Name = "Livestock"; f.Parent = model end
	return f
end

local function penCount(model)
	return #penFolder(model):GetChildren()
end

-- **เลเวลสัตว์ 1-5 โตเองตามอายุ** (ผู้ใช้กำหนด 2026-09-25) · ตั้งแอตทริบิวต์ `Level` (Gathering อ่านไปจำกัดผลผลิต)
-- แล้วขยายตัวตามเลเวล · ScaleTo เฉพาะตอนเลเวลเปลี่ยน ไม่ใช่ทุกวินาที · เลเวลคิดจาก BornAt จึงไม่ต้องเซฟแยก
local function applyLevel(animal, now)
	local level = IslandConfig.PenLevelOf(animal:GetAttribute("BornAt"), now)
	if animal:GetAttribute("Level") == level then return end
	animal:SetAttribute("Level", level)
	local scale = IslandConfig.PenLevelScale[level] or 1
	pcall(function() animal:ScaleTo(scale) end)
end

-- ปล่อยสัตว์หนึ่งตัวลงคอก · ติดแท็กให้ Gathering ของเกมหลักต่อปุ่ม "เก็บไข่/รีดนม/ตัดขน" ให้เอง
--
-- `saved` = สถานะที่เก็บไว้ในโปรไฟล์ (ตอนเซิร์ฟบูตใหม่) — ไม่ส่งมา = ตัวใหม่ที่เพิ่งซื้อ
local function spawnAnimal(model, kind, saved)
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
	animal:SetAttribute("ReadyAt", saved and saved.r or (os.time() + IslandConfig.PenGrowSeconds))

	-- **เก็บซ้ำได้ ไม่ใช่เก็บครั้งเดียวแล้วหาย** (ผู้ใช้เลือก 2026-09-22)
	--
	-- เดิมติดธง `HerdAnimal` ซึ่ง Gathering อ่านแล้ว**ลบตัวนั้นทิ้ง** — วัว 1,800 เหรียญให้นมมูลค่า
	-- 7 เหรียญแล้วจบ · ตอนนี้ปล่อยให้วงจร "เก็บแล้วรอ" ปกติของ Gathering ทำงานแทน โดยตั้งคูลดาวน์
	-- ของตัวเองผ่าน `RespawnSeconds` (แมพหลักไม่มีแอตทริบิวต์นี้ จึงยังใช้ค่ากลางเหมือนเดิม)
	-- **แต่ละชนิดรอไม่เท่ากัน** (ผู้ใช้สั่ง 2026-09-23) — ไก่ 15 นาที ถึง ม้า 45 นาที
	animal:SetAttribute("RespawnSeconds", IslandConfig.PenHarvestFor(kind))
	-- ได้ของมากกว่าฝูงในแมพหลัก เพราะตัวนี้ซื้อมาด้วยเงิน
	-- ผลผลิตสุ่มถ่วงน้ำหนัก 1-5 (IslandConfig.RollPenYield) ทุกชนิด — ล้างช่วงเดิมทิ้งด้วย (สัตว์ที่คืนจากเซฟ)
	animal:SetAttribute("YieldMin", nil)
	animal:SetAttribute("YieldMax", nil)
	animal:SetAttribute("YieldWeighted", true)
	-- สัตว์ที่เพิ่งถูกเก็บไม่ต้องจางเป็นผี — มันยังยืนอยู่ตรงนั้นจริงๆ แค่รีดนมซ้ำไม่ได้ชั่วคราว
	animal:SetAttribute("NoFade", true)
	animal:SetAttribute("BornAt", saved and saved.b or os.time()) -- อายุ = เลเวล (applyLevel)
	-- แสงที่ทอยไว้แล้วรอดข้ามการออก-เข้าเกาะ — ไม่งั้นออกแล้วเข้าใหม่ = ทอยแสงใหม่ได้เรื่อยๆ
	if saved and saved.w then animal:SetAttribute("Glow", saved.w) end

	-- ตัวที่โตแล้วกลับมาโตเหมือนเดิม · ตัวที่ยังโตไม่เสร็จนับต่อจากนาฬิกาเดิม (เวลาเดินตอนออฟไลน์ด้วย
	-- เพราะใช้ `os.time` แบบเดียวกับแปลงผัก) · `a` = เวลาที่เก็บซ้ำได้อีกครั้ง ถ้ากำลังติดคูลดาวน์อยู่
	if saved and saved.g then
		animal:SetAttribute("Grown", true)
		local again = saved.a
		if again and again > os.time() then
			animal:SetAttribute("Spent", true)
			animal:SetAttribute("ReadyAgainAt", again)
		end
		-- ⚠️ **ตัวที่โตแล้วห้ามย่อกลับ** `tickPen` ขยายให้เฉพาะตอนข้ามเส้น "โตเสร็จ" ครั้งเดียว
		-- ตัวที่ถูกคืนมาพร้อมธง `Grown` จะไม่ผ่านทางนั้นอีก ย่อตรงนี้ = ตัวเต็มวัยค้างที่ครึ่งตัวถาวร
	else
		animal:SetAttribute("Spent", true) -- ยังโตไม่พอ: ปุ่มถูกปิดไว้จนกว่า tickPen จะปลดให้
	end
	applyLevel(animal, os.time()) -- ซื้อมา = Lv1 ตัวเล็กมาก · คืนจากเซฟ = เลเวลตามอายุจริง
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
	-- **สถานะรายตัว** (ผู้ใช้สั่ง 2026-09-23: "กดดูได้ด้วยว่าอีกนานไหมกว่าสัตว์แต่ละตัวจะเก็บผลผลิตได้")
	--
	-- สามสถานะ ไม่ใช่สอง: ยังโตไม่เสร็จ · โตแล้วแต่ติดคูลดาวน์หลังเพิ่งเก็บ · เก็บได้เลย
	-- ของเดิมนับสองอย่างหลังรวมกันเป็น "เก็บได้" ซึ่งโกหกทุกครั้งที่เพิ่งรีดนมไป
	local ready, now = 0, os.time()
	local growing = {}
	for _, a in ipairs(penFolder(model):GetChildren()) do
		local name = ANIMAL_NAMES[a.Name] or a.Name
		local readyAt = a:GetAttribute("ReadyAt") or 0
		local again = a:GetAttribute("ReadyAgainAt")
		local bornAt = a:GetAttribute("BornAt")
		local level = IslandConfig.PenLevelOf(bornAt, now)
		local nextLevelIn = IslandConfig.PenNextLevelIn(bornAt, now)
		if readyAt > now then
			bornAt = bornAt or (readyAt - IslandConfig.PenGrowSeconds)
			local span = math.max(1, readyAt - bornAt)
			growing[#growing + 1] = {
				state = "grow",
				name = name,
				level = level,
				nextLevelIn = nextLevelIn,
				progress = math.clamp((now - bornAt) / span, 0, 1),
				secondsLeft = math.max(0, readyAt - now),
			}
		elseif a:GetAttribute("Spent") and again and again > now then
			-- ช่วงคูลดาวน์: ความคืบหน้าคิดจากคูลดาวน์ของ **ชนิดนั้น** ไม่ใช่ค่ากลาง
			local span = math.max(1, IslandConfig.PenHarvestFor(a.Name))
			growing[#growing + 1] = {
				state = "cool",
				name = name,
				level = level,
				nextLevelIn = nextLevelIn,
				progress = math.clamp(1 - (again - now) / span, 0, 1),
				secondsLeft = math.max(0, again - now),
			}
		else
			ready += 1
			growing[#growing + 1] = { state = "ready", name = name, progress = 1, secondsLeft = 0,
				level = level, nextLevelIn = nextLevelIn }
		end
	end
	-- เรียงจากใกล้ได้ที่สุด · ตัวที่เก็บได้แล้วขึ้นก่อนเพื่อน
	table.sort(growing, function(x, y)
		if x.secondsLeft ~= y.secondsLeft then return x.secondsLeft < y.secondsLeft end
		return x.name < y.name
	end)
	return {
		uid = entry and entry.uid,
		animals = rows,
		count = penCount(model),
		ready = ready,
		growing = growing,
		max = IslandConfig.PenMax,
		kind = entry and entry.animal,
	}
end

-- ปล่อยฝูงทิ้งทั้งคอก — ทางเดียวที่จะเปลี่ยนชนิดสัตว์ที่เลี้ยง เพราะสัตว์ไม่หายตอนถูกเก็บเกี่ยวแล้ว
-- (และคอกที่ยังมีสัตว์อยู่ก็เก็บคืนกระเป๋าไม่ได้) · **ไม่คืนเงิน** ปล่อยแล้วปล่อยเลย
local function penRelease(player, model)
	if not IslandAccess.IsOwner(player) then return false, "เฉพาะเจ้าของเกาะ" end
	local entry = IslandAccess.EntryOf(model)
	if not entry then return false, "ไม่พบคอกนี้" end
	local live = penFolder(model):GetChildren()
	if #live == 0 and not entry.herd then return false, "คอกนี้ว่างอยู่แล้ว" end
	local gone = 0
	for _, a in ipairs(live) do a:Destroy(); gone += 1 end
	-- ล้างทั้งสองที่ ไม่งั้น tick ถัดไปคืนฝูงกลับมาให้อีก (ทางคืนสัตว์ตอนเซิร์ฟบูตใช้ `herd` เป็นตัวตัดสิน)
	entry.herd, entry.animal = nil, nil
	return true, gone
end

-- ⚠️ **จองชื่อไว้ก่อน** `penBuy` ข้างล่างเรียกตัวนี้ แต่ตัวจริงนิยามอยู่ถัดไปอีก — ประกาศทีหลัง
-- ฟังก์ชันที่ใช้มันเมื่อไหร่ closure จะจับ global ที่เป็น nil แล้วพังตอนรันจริง (บทเรียนซ้ำในโปรเจ็คนี้)
local saveHerd

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
	saveHerd(model, entry) -- จดทันที ไม่รอรอบ tick ถัดไป (ผู้เล่นอาจออกเกมภายในวินาทีนั้น)
	notify(player, "info", ("ซื้อ%s %d ตัว — โตพอให้เก็บใน %d นาที"):format(spec.name, born, IslandConfig.PenGrowSeconds / 60))
	return true
end

-- **ฝูงถูกเซฟลงโปรไฟล์** (แก้ 2026-09-23: ผู้ใช้แจ้งว่าซื้อสัตว์ทิ้งไว้แล้วออกเกม กลับมาสัตว์หาย)
--
-- ของเดิมจงใจไม่เซฟ โดยให้เหตุผลว่า "สัตว์เป็นของชั่วคราวที่หายตอนเก็บ" ซึ่งจริงตอนที่มันยังเก็บได้
-- ครั้งเดียวแล้วหายไป — **แต่ผู้ใช้เปลี่ยนให้เก็บซ้ำได้เมื่อ 2026-09-22** วัวตัวละ 1,800 เหรียญจึงเป็น
-- การลงทุนที่ต้องอยู่ข้ามรอบ ไม่ใช่ของใช้แล้วทิ้ง · เซฟเหมือนที่แปลงผักเซฟ `crop`/`at` มาตลอด
--
-- **ตัวจริงคือสัตว์ที่ยืนอยู่ในคอก โปรไฟล์เป็นแค่สำเนา** — มิเรอร์ทั้งฝูงทุกรอบ tick ที่เดียว
-- ไม่ต้องไล่จดทีละเหตุการณ์ (เกิด/โต/ถูกเก็บ) ซึ่งเป็นที่มาของการซิงก์หลุดเสมอ
function saveHerd(model, entry)
	local herd = {}
	for _, a in ipairs(penFolder(model):GetChildren()) do
		herd[#herd + 1] = {
			b = a:GetAttribute("BornAt"),
			r = a:GetAttribute("ReadyAt"),
			g = a:GetAttribute("Grown") == true or nil,
			a = a:GetAttribute("ReadyAgainAt"),
			w = a:GetAttribute("Glow"),
		}
	end
	entry.herd = #herd > 0 and herd or nil
end

-- ปลดล็อกสัตว์ที่โตครบแล้วทีละตัว · คอกที่ว่างหมดคืนชนิดให้ว่าง (เลี้ยงชนิดใหม่ได้)
local function tickPen(model, entry)
	local live = penFolder(model):GetChildren()

	-- คอกว่างแต่โปรไฟล์ยังมีฝูงอยู่ = เซิร์ฟเพิ่งบูต ยังไม่มีใครปล่อยสัตว์ลงไป → คืนให้
	-- (สัตว์ไม่ถูกลบตอนเก็บอีกแล้ว คอกว่างจึงไม่ได้แปลว่า "เก็บหมดแล้ว")
	if #live == 0 and entry.herd and entry.animal then
		local back = 0
		for _, saved in ipairs(entry.herd) do
			if spawnAnimal(model, entry.animal, saved) then back += 1 end
		end
		if back > 0 then
			print(("[IslandZones] คืนสัตว์ในคอก %s %d ตัว"):format(tostring(entry.animal), back))
			live = penFolder(model):GetChildren()
		else
			entry.herd = nil -- ต้นแบบหาย คืนไม่ได้ อย่าวนลองใหม่ทุกวินาที
		end
	end

	if #live == 0 then
		if entry.animal then entry.animal = nil end
		entry.herd = nil
		return
	end
	local now = os.time()
	for _, animal in ipairs(live) do
		local readyAt = animal:GetAttribute("ReadyAt") or 0

		-- ⚠️ **ปลดล็อกได้ครั้งเดียว ตอนโตเสร็จเท่านั้น** หลังจากนั้น `Spent` เป็นของ Gathering ล้วนๆ
		-- (มันตั้งตอนเก็บ แล้วล้างเองเมื่อครบ `RespawnSeconds`) — ถ้าตรงนี้ยังล้างให้ด้วย สัตว์ที่เพิ่ง
		-- ถูกรีดนมจะกลับมาเก็บได้ทันทีในวินาทีถัดไป คูลดาวน์จะไม่มีความหมายเลย
		-- **คูลดาวน์ที่ข้ามการรีสตาร์ท** — `Gathering` ล้าง `Spent` ด้วย `task.delay` ซึ่งตายไปพร้อม
		-- เซิร์ฟเวอร์เก่า สัตว์ที่ถูกคืนมาพร้อมคูลดาวน์ค้างจึงไม่มีใครมาปลดให้เลย · ตรงนี้ปลดตามเวลาจริง
		-- (ระหว่างเซสชันปกติก็ไม่ชนกัน ทั้งสองทางทำสิ่งเดียวกันและซ้ำได้)
		local again = animal:GetAttribute("ReadyAgainAt")
		if animal:GetAttribute("Grown") and animal:GetAttribute("Spent") and again and again <= now then
			animal:SetAttribute("Spent", nil)
			animal:SetAttribute("ReadyAgainAt", nil)
			-- รอบใหม่ = ทอยของเรืองแสงใหม่ (ผู้ใช้สั่ง 2026-09-23) · ทางนี้เป็นทางของเซิร์ฟที่เพิ่งบูต
			-- ส่วนทางปกติคือ `Gathering.setSpent(node, false)` ซึ่งทอยให้เองอยู่แล้ว
			animal:SetAttribute("Glow", IslandConfig.RollGlow())
			-- ต้องเปิดปุ่มเองด้วย — ปกติ `Gathering.setSpent(node, false)` เป็นคนเปิด แต่นั่นคือ
			-- `task.delay` ที่ตายไปกับเซิร์ฟเวอร์เก่า ล้างแค่แอตทริบิวต์จะได้สัตว์ที่กดไม่ได้ตลอดไป
			for _, d in ipairs(animal:GetDescendants()) do
				if d:IsA("ProximityPrompt") then d.Enabled = true end
			end
		end

		if not animal:GetAttribute("Grown") and readyAt <= now then
			animal:SetAttribute("Grown", true)
			animal:SetAttribute("Spent", nil)
			animal:SetAttribute("Glow", IslandConfig.RollGlow()) -- โตเสร็จ = รอบแรกของมัน (ทอยตอนเก็บได้พอดี)
			for _, d in ipairs(animal:GetDescendants()) do
				if d:IsA("ProximityPrompt") then d.Enabled = true end
			end
		end
		-- ขนาดตามเลเวล (ไม่ใช่ตามความคืบหน้าสิบนาทีแรกแล้ว) · เปลี่ยนเฉพาะตอนเลเวลขึ้น
		applyLevel(animal, now)

		-- นาฬิกาบนปุ่ม ทรงเดียวกับแปลงผัก (ObjectText) — ไม่ต้องมีโค้ดไคลเอนต์
		local label = ("%s Lv%d"):format(ANIMAL_NAMES[animal.Name] or animal.Name, animal:GetAttribute("Level") or 1)
		for _, d in ipairs(animal:GetDescendants()) do
			if d:IsA("ProximityPrompt") and d.Name == "GatherPrompt" then
				if readyAt > now then
					d.ObjectText = ("%s · โตอีก %d นาที"):format(label, math.max(1, math.ceil((readyAt - now) / 60)))
				elseif animal:GetAttribute("Spent") then
					-- เก็บไปแล้ว รอรอบหน้า · Gathering เป็นเจ้าของนาฬิกานี้ เราแค่ถามมันว่าเหลือเท่าไหร่
					local again = animal:GetAttribute("ReadyAgainAt")
					d.ObjectText = (again and again > now)
						and ("%s · เก็บได้อีก %d นาที"):format(label, math.max(1, math.ceil((again - now) / 60)))
						or (label .. " · เก็บไปแล้ว")
				else
					d.ObjectText = label .. " · เก็บได้"
				end
			end
		end
	end

	-- มิเรอร์ฝูงลงโปรไฟล์ทุกรอบ — ที่เดียว ไม่ต้องไล่จดทีละเหตุการณ์ (เกิด/โต/ถูกเก็บ)
	saveHerd(model, entry)
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
	-- **ขุดแล้วหายไปเลย รอบหน้าค่อยเติม** (QA 2026-09-26) — เดิมไม่มี `OneShot` ก้อนเลยไม่หาย Gathering ให้เกิดซ้ำ
	-- ทุก 60 วิ แถมมีปุ่มฟาร์มออโต้ = ทองคำ/แร่เวท/เพชรไม่จำกัดแบบยืน AFK · `Uid` = ไม่มีปุ่มฟาร์มออโต้
	-- (Gathering ข้ามโหนดที่มี Uid) ทรงเดียวกับจุดสุ่มบนดินของ IslandNodes
	rock:SetAttribute("OneShot", true)
	rock:SetAttribute("Uid", "mine:" .. HttpService:GenerateGUID(false))
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
		-- โซนที่เพิ่งวาง: ให้ก้อนแรกเลย ไม่ต้องรอครึ่งชั่วโมงถึงจะรู้ว่ามันทำงาน — **แต่ครั้งเดียวต่อรอบเวลาของเกาะ**
		-- เก็บโซนแล้ววางใหม่ได้ uid ใหม่ทุกครั้ง ถ้าไม่มีนาฬิกานี้ = วาง/เก็บรัวๆ ได้แร่ฟรีทีละก้อน (QA 2026-09-26)
		local data = IslandAccess.Data and IslandAccess.Data()
		if alive == 0 and data and os.time() >= (data.mineFreeAt or 0) then
			data.mineFreeAt = os.time() + IslandConfig.MineEverySeconds
			spawnRock(model, rollRock())
		end
		return
	end
	if os.time() >= entry.nextAt then
		for _ = 1, math.random(IslandConfig.MinePerRoundMin, IslandConfig.MinePerRoundMax) do
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
	-- ⚠️ **เทียบกับสภาพของโมเดลจริง ไม่ใช่กับ `entry.stage`** (QA 2026-09-26) — entry.stage ถูกเซฟลงโปรไฟล์ พอเข้าเกม
	-- ใหม่ ต้นที่ปลูกใหม่จาก `spawnEntry` ไม่มีแท็กและขนาดเป็นค่าเริ่มต้น แต่ entry.stage ยังเท่าเดิม ของเดิมจึงไม่เคย
	-- ติดแท็กให้อีก = ต้นที่โตแล้วตัดไม่ได้ถาวรหลังออก-เข้าใหม่ · ต้นครึ่งทางโชว์เต็มต้นจนกว่าจะข้ามระยะถัดไป
	local scale = IslandConfig.Stages[stage].scale
	if entry.stage ~= stage or math.abs(model:GetScale() - scale) > 0.01 then
		model:ScaleTo(scale)
		entry.stage = stage
	end
	-- โตเต็มที่ = ตัดได้ · ก่อนหน้านั้นไม่มีแท็ก ปุ่มจึงไม่ขึ้นเลย (ต้นกล้าตัดไม่ได้)
	if progress >= 1 and not CollectionService:HasTag(model, NODE_TAG) then
		model:SetAttribute("NodeKind", "Tree")
		CollectionService:AddTag(model, NODE_TAG)
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
		local snap = penSnapshot(model)
		snap.open = true -- **เฉพาะการกด E เท่านั้นที่เปิดหน้าต่างได้** ดูหมายเหตุที่ลูปส่งภาพใหม่
		Remotes.IslandPenOpen:FireClient(player, snap)
		Watching[player] = model -- แถบความคืบหน้าต้องเดิน จึงต้องส่งภาพใหม่เรื่อยๆ ขณะเปิดอยู่
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

Remotes.IslandPenRelease.OnServerEvent:Connect(function(player, uid)
	local model = IslandAccess.ModelOf(tonumber(uid) or -1)
	if not model or model:GetAttribute("ItemId") ~= IslandConfig.PenItem then return end
	local ok, info = penRelease(player, model)
	notify(player, ok and "info" or "error", ok and ("ปล่อยสัตว์ไปแล้ว %d ตัว"):format(info) or info)
	local after = penSnapshot(model)
	after.open = true
	Remotes.IslandPenOpen:FireClient(player, after)
end)

Remotes.IslandPenBuy.OnServerEvent:Connect(function(player, uid, kind, count)
	local model = IslandAccess.ModelOf(tonumber(uid) or -1)
	if not model or model:GetAttribute("ItemId") ~= IslandConfig.PenItem then return end
	local ok, why = penBuy(player, model, tostring(kind), count)
	if not ok then
		notify(player, "error", why)
	end
	local after = penSnapshot(model)
	after.open = true -- ซื้อแล้วหน้าต่างต้องยังอยู่ (สำเร็จหรือไม่ก็ตาม)
	Remotes.IslandPenOpen:FireClient(player, after)
end)

-- ส่งภาพคอกใหม่ให้คนที่เปิดหน้าต่างค้างไว้ — แถบโตจึงเดินจริง ไม่ใช่ค้างที่ % ตอนเปิด
--
-- ⚠️ **ภาพชุดนี้ไม่มีธง `open`** (ผู้ใช้แจ้ง 2026-09-22: ปิดหน้าต่างแล้วมันเด้งกลับมารัวๆ)
-- การปิดหน้าต่างเกิดฝั่งไคลเอนต์ เซิร์ฟเวอร์ไม่มีทางรู้เองว่าปิดไปแล้ว — ถ้าภาพที่ส่งมาอัปเดต
-- แถบความคืบหน้า "เปิด" หน้าต่างได้ด้วย มันก็จะเปิดกลับมาเองทุก 3 วินาที ตลอดที่ยังยืนอยู่ใกล้คอก
--
-- หยุดเองเมื่อผู้เล่นเดินห่างเกินระยะกดปุ่ม หรือคอกถูกเก็บคืน — และเมื่อไคลเอนต์บอกว่าปิดแล้ว
task.spawn(function()
	while true do
		task.wait(3)
		for player, model in pairs(Watching) do
			local char = player.Character
			local hrp = char and char:FindFirstChild("HumanoidRootPart")
			if not player.Parent or not model.Parent or not hrp then
				Watching[player] = nil
			elseif (model:GetPivot().Position - hrp.Position).Magnitude > 40 then
				Watching[player] = nil
			else
				Remotes.IslandPenOpen:FireClient(player, penSnapshot(model))
			end
		end
	end
end)

Remotes.IslandPenClose.OnServerEvent:Connect(function(player)
	Watching[player] = nil
end)

game:GetService("Players").PlayerRemoving:Connect(function(player)
	Watching[player] = nil
end)

IslandAccess.PenBuy = penBuy
IslandAccess.PenRelease = penRelease
IslandAccess.PenSnapshot = penSnapshot
IslandAccess.ZonesTick = tick
