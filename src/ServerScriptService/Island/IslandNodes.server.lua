-- IslandNodes: จุดเก็บเกี่ยวที่สุ่มโผล่บนผืนดินของเกาะ (ผู้ใช้สั่ง 2026-09-22)
--
-- "ตรงพื้นที่เป็นดิน มีโอกาสสุ่มโมเดลจากเกมหลัก ของหิน แร่ และต้นไม้ ทุกชนิดที่เก็บเกี่ยวได้ มาเกิด
--  เพื่อให้เก็บ โดยใช้อุปกรณ์แบบเดียวกับเกมหลัก ... แต่ที่แตกต่างคืออันนี้เก็บและหายไปเลย
--  และการเกิดเป็นแบบสุ่มทั้งหมด และจะเกิดเฉพาะตรงที่ไม่ได้วางแปลงผักไว้เท่านั้น"
--
-- **ไฟล์นี้ไม่ได้เป็นเจ้าของการเก็บเกี่ยวเลย** มันแค่เอาโมเดลไปวางแล้วติดแท็ก `WOLD_Node` —
-- `Gathering` ของเกมหลักเห็นแท็กก็ใส่ปุ่ม ตรวจเครื่องมือ นับเวลา และแจกของให้เองทั้งหมด
-- "ใช้อุปกรณ์แบบเดียวกับเกมหลัก" จึงได้มาฟรีโดยไม่ต้องเขียนอะไร แค่ตั้ง `NodeKind` ให้ตรง
--
-- **เก็บแล้วหายไปเลย** = แอตทริบิวต์ `OneShot` ซึ่ง `Gathering` ลบตัวนั้นทิ้งหลังแจกของ
-- (ทางเดียวกับ `HerdAnimal` ของฝูงสัตว์ในแมพหลัก) — ต่างจากจุดในแมพหลักที่ตัวเดิมรอเกิดใหม่
local ServerConfig = require(game.ServerScriptService.ServerConfig)
if not ServerConfig.IsFarm then return end

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local IslandConfig = require(ReplicatedStorage.IslandConfig)
local IslandGrid = require(ReplicatedStorage.IslandGrid)
local IslandAccess = require(script.Parent.IslandAccess)

local CFG = IslandConfig.NodeSpawn
local SCAN = 56 -- เกาะกว้าง 440 = ±55 ช่อง

local protoRoot -- ถามใหม่ทุกครั้ง (กฎเหล็ก StreamingEnabled) — เฟสอาจรันหลังเซิร์ฟบูต
local function prototypes(kind)
	protoRoot = ServerStorage:FindFirstChild("WOLD_IslandNodes")
	local f = protoRoot and protoRoot:FindFirstChild(kind)
	return f and f:GetChildren() or nil
end

local function liveFolder()
	local isl = workspace:FindFirstChild("WOLD_Island")
	if not isl then return nil end
	local f = isl:FindFirstChild("Nodes")
	if not f then f = Instance.new("Folder"); f.Name = "Nodes"; f.Parent = isl end
	return f
end

-- ช่องดินทั้งหมด · สแกนเป็นรอบ ไม่ใช่ทุกครั้งที่จะเกิด (เรย์ 113x113 = 12,769 เส้น แพงเกินจะทำทุก 90 วิ)
local soilCells, scannedAt = {}, -math.huge
local function rescanSoil()
	soilCells = {}
	for cx = -SCAN, SCAN do
		for cz = -SCAN, SCAN do
			if IslandGrid.isSoil(cx, cz) then soilCells[#soilCells + 1] = { cx, cz } end
		end
	end
	scannedAt = os.clock()
	print(("[IslandNodes] ผืนดิน %d ช่อง"):format(#soilCells))
end

-- ชนิดไหนโผล่ · สุ่มตามน้ำหนัก
local function pickKind()
	local total = 0
	for _, w in pairs(CFG.weights) do total += w end
	if total <= 0 then return nil end
	local roll = math.random() * total
	for kind, w in pairs(CFG.weights) do
		roll -= w
		if roll <= 0 then return kind end
	end
	return nil
end

local Live = {} -- [model] = "cx,cz"
local Taken = {} -- ["cx,cz"] = model

-- **จุดที่โผล่แล้วต้องอยู่ข้ามการรีสตาร์ท** (ผู้ใช้สั่ง 2026-09-23) — ไม่งั้นฟาร์มรีเซ็ตทุกครั้งที่ปิดเกม
-- และคำว่า "ยิ่งนานยิ่งรก" ก็ไม่มีทางเกิดขึ้นจริง · เก็บแค่ชนิดกับช่อง ที่เหลือสร้างใหม่ได้จากต้นแบบ
local function store()
	return IslandAccess.NodeStore and IslandAccess.NodeStore() or nil
end

-- ช่องนี้ว่างพอให้ของโผล่ไหม — **ห้ามทับแปลงผักหรือของที่ผู้ใช้วางไว้**
local function freeCell(cx, cz)
	if Taken[IslandGrid.key(cx, cz)] then return false end
	-- itemId = nil แปลว่า "ไม่สนกฎดิน" (เราคัดช่องดินมาก่อนแล้ว) แต่ยังเช็คของที่วางทับ ของตกแต่งที่ตรึงไว้
	-- และ "เดินเข้าไปถึงไหม" ตามกติกาเดียวกับการวางของ — จุดที่เดินไม่ถึงก็เก็บไม่ได้อยู่ดี
	return (IslandAccess.CanPlaceAt(cx, cz, 1, 1, 0, nil)) == true
end

-- วางจุดหนึ่งลงช่องที่ระบุ · ใช้ทั้งตอนสุ่มใหม่และตอนคืนของที่เซฟไว้
local function spawnAt(kind, cx, cz)
	local picks = prototypes(kind)
	if not picks or #picks == 0 then return false end
	local folder = liveFolder()
	if not folder then return false end
	local y = IslandGrid.surfaceAt(cx, cz)
	if not y then return false end

	local model = picks[math.random(#picks)]:Clone()
	local wx, wz = IslandGrid.worldOf(cx, cz)
	model:PivotTo(CFrame.new(wx, y, wz) * CFrame.Angles(0, math.random() * math.pi * 2, 0))
	model:SetAttribute("NodeKind", kind)
	-- **เก็บแล้วหายไปเลย** (ผู้ใช้สั่ง) ต่างจากจุดในแมพหลักที่ตัวเดิมรอเกิดใหม่ที่เดิม
	model:SetAttribute("OneShot", true)
	-- ไม่ให้ฟาร์มออโต้จับ: มันใช้คีย์ F ชนกับปุ่มเก็บของคืนกระเป๋าของระบบเกาะ
	model:SetAttribute("Uid", "node:" .. IslandGrid.key(cx, cz))
	-- ของเรืองแสง (ผู้ใช้สั่ง 2026-09-23) — จุดที่เพิ่งโผล่ไม่เคยผ่าน `Gathering.setSpent(node, false)`
	-- จึงต้องทอยเองตรงนี้ · จุดที่คืนจากคลังตอนบูตก็ผ่านทางนี้ ได้ทอยใหม่ทุกครั้งที่เซิร์ฟเปิด
	model:SetAttribute("Glow", IslandConfig.RollGlow())
	model.Parent = folder
	CollectionService:AddTag(model, "WOLD_Node")
	Live[model] = IslandGrid.key(cx, cz)
	Taken[IslandGrid.key(cx, cz)] = model
	local st = store()
	if st then st[IslandGrid.key(cx, cz)] = kind end
	return true
end

local function drop(model, key)
	Live[model] = nil
	Taken[key] = nil
	local st = store()
	if st then st[key] = nil end
end

local function countLive()
	local n = 0
	for model, key in pairs(Live) do
		if model.Parent then
			n += 1
		else
			drop(model, key) -- ถูกเก็บไปแล้ว (Gathering ลบทิ้งเพราะ OneShot) บูตหน้าไม่ต้องคืนมาอีก
		end
	end
	return n
end

-- คืนจุดที่เคยโผล่ไว้ ตอนเซิร์ฟบูตใหม่ · ช่องที่ถูกยึดไปแล้ว (ปลูกแปลงทับ) ทิ้งไปเลย
local restored = false
local function restoreSaved()
	local st = store()
	if restored or not st then return end
	if not liveFolder() then return end -- เกาะยังไม่ประกอบ ลองใหม่รอบหน้า
	restored = true
	local back, dropped = 0, 0
	for key, kind in pairs(st) do
		local cx, cz = tostring(key):match("(-?%d+),(-?%d+)")
		cx, cz = tonumber(cx), tonumber(cz)
		if cx and freeCell(cx, cz) and spawnAt(kind, cx, cz) then
			back += 1
		else
			st[key] = nil
			dropped += 1
		end
	end
	if back + dropped > 0 then
		print(("[IslandNodes] คืนจุดเก็บเกี่ยว %d · ทิ้งที่ไม่มีที่ว่างแล้ว %d"):format(back, dropped))
	end
end

local function spawnOne()
	if #soilCells == 0 then return false end
	local kind = pickKind()
	if not kind then return false end
	-- ลองสุ่มช่องสัก 30 ครั้ง — ดินเต็มไปด้วยแปลงผักก็เป็นไปได้ ไม่ต้องไล่ทั้งผืน
	for _ = 1, 30 do
		local cell = soilCells[math.random(#soilCells)]
		if freeCell(cell[1], cell[2]) and spawnAt(kind, cell[1], cell[2]) then return true end
	end
	return false
end

-- ของที่โผล่ไปแล้วแต่ช่องถูกยึดทีหลัง (ผู้เล่นปลูกแปลงผักทับ) — เก็บออกให้ ไม่ปล่อยให้ซ้อนกัน
local function pruneBlocked()
	for model, key in pairs(Live) do
		if model.Parent then
			local cx, cz = key:match("(-?%d+),(-?%d+)")
			cx, cz = tonumber(cx), tonumber(cz)
			-- ตัวมันเองไม่ได้อยู่ใน Occupied ของระบบวางของ ช่องจึงยัง "ว่าง" ถ้าไม่มีใครมาวางทับ
			if not (IslandAccess.CanPlaceAt(cx, cz, 1, 1, 0, nil)) then
				drop(model, key)
				model:Destroy()
			end
		end
	end
end

task.spawn(function()
	-- รอให้เกาะประกอบเสร็จก่อน (IslandBuild ปลูกของจากโปรไฟล์ตอนบูต)
	task.wait(10)
	while true do
		if os.clock() - scannedAt > CFG.rescanSeconds then rescanSoil() end
		restoreSaved() -- ครั้งเดียวต่อเซิร์ฟ — คืนของที่เคยโผล่ก่อนสุ่มเพิ่ม
		pruneBlocked()
		if countLive() < CFG.max then spawnOne() end
		task.wait(CFG.everySeconds)
	end
end)

-- ช่องเทส (Studio เท่านั้น) — ทรงเดียวกับ IslandTest: เรียกผ่าน IslandAccess
IslandAccess.NodeSpawnOnce = function()
	if os.clock() - scannedAt > CFG.rescanSeconds then rescanSoil() end
	return spawnOne()
end
IslandAccess.NodeCount = function() return countLive(), #soilCells end
IslandAccess.NodeClear = function()
	local n = 0
	for model in pairs(Live) do
		if model.Parent then model:Destroy(); n += 1 end
	end
	Live, Taken = {}, {}
	local st = store()
	if st then for k in pairs(st) do st[k] = nil end end -- ล้างคลังด้วย ไม่งั้นรอบหน้าคืนของเทสกลับมา
	return n
end
