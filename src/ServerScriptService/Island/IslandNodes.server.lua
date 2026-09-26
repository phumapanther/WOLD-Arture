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
-- ฝังลงดินนิดหน่อย — ผิวเทอร์เรนไม่เรียบเป๊ะ วางพอดีเป๊ะแล้วบางจุดจะดูลอย
local SINK = 0.25
-- จังหวะงานบ้าน (คนละตัวกับ `CFG.everySeconds` ที่เป็นจังหวะการเกิด)
local TICK = 5

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

-- ช่องนี้ว่างพอให้ของ **ใหม่** โผล่ไหม — ห้ามทับแปลงผัก ของที่ผู้ใช้วางไว้ หรือจุดที่โผล่ไปแล้ว
local function freeCell(cx, cz)
	if Taken[IslandGrid.key(cx, cz)] then return false end
	-- itemId = nil แปลว่า "ไม่สนกฎดิน" (เราคัดช่องดินมาก่อนแล้ว) แต่ยังเช็คของที่วางทับ ของตกแต่งที่ตรึงไว้
	-- และ "เดินเข้าไปถึงไหม" ตามกติกาเดียวกับการวางของ — จุดที่เดินไม่ถึงก็เก็บไม่ได้อยู่ดี
	return (IslandAccess.CanPlaceAt(cx, cz, 1, 1, 0, nil)) == true
end

-- ⚠️ **ช่องของจุดที่ยืนอยู่แล้ว ต้องถามคนละคำถาม** (ผู้ใช้แจ้ง 2026-09-23 "ออกเข้าใหม่แล้วมันรีเกิดใหม่หมด")
--
-- `CanPlaceAt` นับ**ทุกอย่างที่ชนได้และทึบ**ในช่องนั้นเป็นสิ่งกีดขวาง ซึ่งรวมหินหรือต้นไม้ที่ไฟล์นี้
-- เพิ่งวางไว้เอง — `pruneBlocked` จึงทำลายของตัวเองทุกตัวในรอบถัดไป **แล้วล้างคลังตามไปด้วย**
-- ลำดับในลูปคือ `restoreSaved()` แล้ว `pruneBlocked()` ทันที: ของที่เพิ่งคืนมาจึงถูกฆ่าในบรรทัดถัดไป
-- แล้ว `spawnOne` ก็สุ่มของใหม่มาแทน = อาการ "รีแล้วสุ่มเกิดใหม่ทันที" ตรงตัว
--
-- คำถามที่ `pruneBlocked` ต้องการจริงๆ มีแค่ "มีใครมาวางของทับช่องนี้หรือยัง" ซึ่งคือตาราง `Occupied`
local function cellClaimed(cx, cz)
	return IslandAccess.CellTaken ~= nil and IslandAccess.CellTaken(cx, cz) == true
end

-- วางจุดหนึ่งลงช่องที่ระบุ · ใช้ทั้งตอนสุ่มใหม่และตอนคืนของที่เซฟไว้
-- ⚠️ **จองชื่อไว้ก่อน** `spawnAt` ข้างล่างเรียก `drop` ในตัวจับสัญญาณ `Destroying` แต่ `drop` ถูก
-- ประกาศทีหลัง — ไม่จองไว้ closure จะจับ global ที่เป็น nil แล้วตัวจับสัญญาณตายเงียบทุกครั้ง
-- (บทเรียน "ใช้ก่อนประกาศ" ครั้งที่เจ็ดของโปรเจ็คนี้ · เจอเพราะเทสเหลือค้าง 1 จุดแทนที่จะเป็น 0)
local drop

-- ⚠️ **ตอนเซิร์ฟกำลังปิด ห้ามลบอะไรออกจากคลัง** — เอนจินไล่ทำลายของใน workspace ตอนปิด
-- ถ้า `Destroying` ข้างล่างยิงตอนนั้นด้วย มันจะกวาดจุดที่ยัง *ไม่ถูกเก็บ* ออกจากโปรไฟล์ทั้งหมด
-- **ต้องประกาศก่อน `spawnAt`** (QA 2026-09-26): เดิมประกาศทีหลัง closure จึงจับ global ที่เป็น nil →
-- `not closing` จริงเสมอ → ปิดเซิร์ฟทุกครั้งคลังจุดเก็บเกี่ยวถูกล้างทิ้งหมด (ใช้ก่อนประกาศ ครั้งที่แปด)
local closing = false
game:BindToClose(function() closing = true end)

-- แสงของจุดที่โผล่ จำไว้ในโปรไฟล์แยกจากชนิด ("cx,cz" -> สี · false = ทอยแล้วไม่ติด)
local function glowStore()
	return IslandAccess.NodeGlowStore and IslandAccess.NodeGlowStore() or nil
end

-- `glow` = สีที่คืนจากโปรไฟล์ (false = ทอยแล้วไม่ติด) · nil = จุดใหม่ ทอยเอง
local function spawnAt(kind, cx, cz, glow)
	local picks = prototypes(kind)
	if not picks or #picks == 0 then return false end
	local folder = liveFolder()
	if not folder then return false end
	local y = IslandGrid.surfaceAt(cx, cz)
	if not y then return false end

	local model = picks[math.random(#picks)]:Clone()
	local wx, wz = IslandGrid.worldOf(cx, cz)
	model:PivotTo(CFrame.new(wx, y, wz) * CFrame.Angles(0, math.random() * math.pi * 2, 0))

	-- ⚠️ **วางให้ก้นโมเดลอยู่ที่ผิวดิน ไม่ใช่วางจุดหมุนไว้ที่ผิวดิน** (ผู้ใช้แจ้ง 2026-09-23: โมเดลจมดิน)
	--
	-- ต้นแบบใน `WOLD_IslandNodes` **ไม่มี `PrimaryPart` สักตัว** `PivotTo` จึงใช้ `WorldPivot` ซึ่งเป็น
	-- ค่าที่ติดมาจากตอนโมเดลถูกสร้าง — วัดแล้วมั่วสิ้นดี: หินจม 19.1 สตัด · ต้นไม้ 19.9 · สมุนไพร 7.7
	-- (ทุ่งเลยดูโล่งเหลือแต่ป้ายอีโมจิลอยอยู่ ซึ่งวัดจากกล่องครอบจึงอยู่ถูกที่)
	--
	-- วัด **หลังหมุนแล้ว** เพราะกล่องครอบเปลี่ยนตามการหมุน · และเชื่อ `GetBoundingBox` ไม่ใช่ตัวเลข
	-- ในต้นแบบ (เฟส 100 เลื่อนฐานจาก `Position.Y - Size.Y/2` ซึ่งไม่ใช่ก้นจริงของชิ้นที่ถูกหมุน —
	-- ต้นไม้จึงมีฐานอยู่ที่ -3.40 ทั้งที่เฟสตั้งใจให้เป็น 0)
	local cf, size = model:GetBoundingBox()
	local bottom = cf.Position.Y - size.Y / 2
	model:PivotTo(model:GetPivot() + Vector3.new(0, y - bottom - SINK, 0))
	model:SetAttribute("NodeKind", kind)
	-- **เก็บแล้วหายไปเลย** (ผู้ใช้สั่ง) ต่างจากจุดในแมพหลักที่ตัวเดิมรอเกิดใหม่ที่เดิม
	model:SetAttribute("OneShot", true)
	-- ไม่ให้ฟาร์มออโต้จับ: มันใช้คีย์ F ชนกับปุ่มเก็บของคืนกระเป๋าของระบบเกาะ
	model:SetAttribute("Uid", "node:" .. IslandGrid.key(cx, cz))
	-- ของเรืองแสง (ผู้ใช้สั่ง 2026-09-23) — จุดที่เพิ่งโผล่ไม่เคยผ่าน `Gathering.setSpent(node, false)`
	-- จึงต้องทอยเองตรงนี้ **ครั้งเดียวตอนโผล่ครั้งแรก** แล้วจำไว้ (QA 2026-09-26: เดิมทอยใหม่ทุกครั้งที่เซิร์ฟเปิด
	-- = ออกเข้าใหม่จนได้สีที่อยากได้)
	if glow == nil then glow = IslandConfig.RollGlow() or false end
	model:SetAttribute("Glow", glow or nil)
	local gs = glowStore()
	if gs then gs[IslandGrid.key(cx, cz)] = glow end
	model.Parent = folder
	CollectionService:AddTag(model, "WOLD_Node")
	Live[model] = IslandGrid.key(cx, cz)
	Taken[IslandGrid.key(cx, cz)] = model
	local st = store()
	if st then st[IslandGrid.key(cx, cz)] = kind end

	-- ⚠️ **ลืมมันทันทีที่ถูกเก็บ ไม่ใช่รอรอบกวาด** (ผู้ใช้แจ้ง 2026-09-23 · พิสูจน์แล้ว)
	--
	-- `Gathering` ลบโมเดลทิ้งตอนเก็บ (`OneShot`) แต่ของเดิมล้างคลังใน `countLive()` ซึ่งถูกเรียก
	-- **ในลูปที่วนทุก `everySeconds` = ชั่วโมงละครั้ง** · เก็บของจนเกลี้ยงแล้วออกจากเซิร์ฟภายใน
	-- ชั่วโมงนั้น คลังยังจำไว้ครบ → `restoreSaved` คืนกลับมาทั้งหมดตอนเข้าใหม่
	-- = **เก็บหมด ออก เข้าใหม่ ปั๊มได้ไม่จำกัด** (วัดแล้ว: เก็บ 6 จุด โลกเหลือ 0 คลังยังเป็น 6)
	--
	-- `Destroying` ยิงตอนถูกทำลายจริงๆ จึงไม่มีช่องว่างให้แทรกเลย · กันเคสเซิร์ฟปิดด้วยธง `closing`
	model.Destroying:Connect(function()
		if not closing then drop(model, IslandGrid.key(cx, cz)) end
	end)
	return true
end

function drop(model, key)
	Live[model] = nil
	Taken[key] = nil
	local st = store()
	if st then st[key] = nil end
	local gs = glowStore()
	if gs then gs[key] = nil end
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
--
-- ⚠️ **ถามด้วย `cellClaimed` ไม่ใช่ `freeCell`** — ของชุดนี้เคยผ่านด่านเต็มมาแล้วตอนโผล่ครั้งแรก
-- ต้นไม้ใหญ่ที่คืนมาก่อนจะล้นไปทับช่องข้างๆ ทำให้เพื่อนบ้านสอบตก `obstructed` แล้ว**หลุดจากคลังถาวร**
-- (ป่าจะบางลงทุกครั้งที่รีสตาร์ท ซึ่งตรงข้ามกับ "ยิ่งนานยิ่งรก" ที่ผู้ใช้สั่งไว้)
local restored = false
local function restoreSaved()
	local st = store()
	if restored or not st then return end
	if not liveFolder() then return end -- เกาะยังไม่ประกอบ ลองใหม่รอบหน้า
	restored = true
	local back, dropped = 0, 0
	local gs = glowStore()
	for key, kind in pairs(st) do
		local cx, cz = tostring(key):match("(-?%d+),(-?%d+)")
		cx, cz = tonumber(cx), tonumber(cz)
		-- สีเดิมจากโปรไฟล์ · ไม่มีบันทึก (จุดจากก่อนมีคลังสี) = false ไม่ใช่ทอยใหม่ ไม่งั้นทุกจุดเก่าได้ลุ้นซ้ำ
		local glow = false
		if gs and gs[key] ~= nil then glow = gs[key] end
		if cx and not Taken[IslandGrid.key(cx, cz)] and not cellClaimed(cx, cz)
			and spawnAt(kind, cx, cz, glow) then
			back += 1
		else
			st[key] = nil
			if gs then gs[key] = nil end
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
			if cellClaimed(cx, cz) then
				drop(model, key)
				model:Destroy()
			end
		end
	end
end

-- ถึงรอบเกิดหรือยัง — นับจาก `os.time` ที่เก็บไว้ในโปรไฟล์ นาฬิกาจึงข้ามการรีสตาร์ทได้
--
-- รอบที่ค้างตอนออฟไลน์จ่ายชดตอนเข้าเกม — หายสามวันกลับมาเจอฟาร์มรกขึ้น นี่คือ "ยิ่งนานยิ่งรก"
-- ตามตัวอักร · เพดาน `CFG.max` คุมปริมาณงานไว้อยู่แล้ว หายไปสิบวันก็ไม่ได้เกินนั้น
local function spawnDue()
	local clock = IslandAccess.NodeClock
	if not clock then return end
	local last = tonumber(clock())
	local period = CFG.everySeconds
	if last == nil then
		-- โปรไฟล์ยังไม่โหลด = รอรอบหน้า · เกาะใหม่ที่ยังไม่เคยมีนาฬิกา = ให้ครบรอบพอดี
		-- (ไม่งั้นเกาะใหม่จะว่างเปล่า 30 นาทีแรก ซึ่งเป็นอาการเดียวกันกับบั๊กที่เพิ่งแก้)
		if not IslandAccess.NodeStore or not IslandAccess.NodeStore() then return end
		last = os.time() - period
	end
	local rounds = math.floor((os.time() - last) / period)
	if rounds < 1 then return end
	-- เดินเป็นช่องๆ ไม่เท่ากับ `os.time()` เปล่าๆ — ไม่งั้นเศษเวลาทุกรอบจะหายไป
	clock(last + rounds * period)
	local per = math.random(CFG.perRoundMin or 1, CFG.perRoundMax or 1)
	local made = 0
	for _ = 1, rounds * per do
		if countLive() >= CFG.max then break end
		if spawnOne() then made += 1 end
	end
	if made > 0 then
		print(("[IslandNodes] เกิดใหม่ %d จุด (ค้างอยู่ %d รอบ) · รวมทั้งหมด %d")
			:format(made, rounds, countLive()))
	end
end

task.spawn(function()
	-- รอให้เกาะประกอบเสร็จก่อน (IslandBuild ปลูกของจากโปรไฟล์ตอนบูต)
	task.wait(10)
	-- **งานบ้านเดินถี่ การเกิดเดินช้า** — สองจังหวะนี้คนละเรื่องกัน เอามามัดรวมไว้ที่ `everySeconds`
	-- ไม่ได้: ชั่วโมงละครั้งคือจังหวะที่ผู้ใช้สั่งไว้ว่าของควรงอกขึ้นมาใหม่ ไม่ใช่จังหวะที่ระบบควร
	-- ตื่นมาดูว่าโลกเปลี่ยนไปยัง (แปลงผักที่ปลูกทับจะค้างอยู่ใต้หินได้ทั้งชั่วโมง)
	-- ⚠️ **นาฬิการอบเกิดอยู่ในโปรไฟล์ ไม่ใช่ `os.clock()` อีกแล้ว** (แก้ 2026-09-24)
	-- ของเดิมนับจากตอนเซิร์ฟบูต แต่เกาะเป็นเซิร์ฟส่วนตัวที่ปิดทุกครั้งที่เจ้าของออก นาฬิกาจึง
	-- เริ่มนับหนึ่งใหม่ทุกครั้ง — คนที่เล่นรอบละครึ่งชั่วโมง **จึงไม่เคยเห็นอะไรเกิดเลยสักครั้ง**
	-- (ผู้ใช้แจ้ง 2026-09-24 "ครบ ชม.แล้วเกินแล้วด้วยซ้ำ ไม่มีอะไรเกิดเลย")
	while true do
		if os.clock() - scannedAt > CFG.rescanSeconds then rescanSoil() end
		restoreSaved() -- ครั้งเดียวต่อเซิร์ฟ — คืนของที่เคยโผล่ก่อนสุ่มเพิ่ม
		countLive() -- เก็บกวาดจุดที่หายไปแล้วออกจากคลัง (ตาข่ายรองรับของ Destroying ข้างบน)
		pruneBlocked()
		spawnDue()
		task.wait(TICK)
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
