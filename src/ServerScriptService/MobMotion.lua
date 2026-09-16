-- MobMotion: ทำให้มอนขยับข้อต่อเอง แทนที่จะยืนแข็งทื่อ
--
-- **ไม่ใช่ IK และจงใจไม่ใช่** — เรฟที่ผู้ใช้ส่งมาเสนอให้คำนวณตำแหน่งเท้าด้วย raycast ทีละขา ซึ่งเหมาะกับ
-- โมเดลที่ยังไม่มีข้อต่อ แต่แมงมุมในเกมนี้มี Motor6D ครบ 16 ตัวสำหรับขาแปดขาอยู่แล้ว (HipL1-4/HipR1-4 และ
-- KneeL1-4/KneeR1-4) สิ่งที่ขาดคือ "ท่า" ที่รู้จักชื่อข้อต่อพวกนั้น ไม่ใช่ตัวคำนวณตำแหน่ง
--
-- **ทำไมขาแมงมุมไม่ขยับ**: Mobs.server โหลดอนิเมชันเดิน R15 มาตรฐานของ Roblox (913402848) ให้มอนทุกตัว
-- อนิเมชันนั้นขยับข้อต่อชื่อ LeftUpperLeg/RightUpperLeg ซึ่ง **ไม่มีอยู่ในแมงมุม** มันจึงเล่นแล้วไม่โดนอะไรเลย
-- แมงมุมเลยไถลไปตามพื้นโดยขาไม่ขยับ
--
-- วิธีที่ใช้แทน: เขียน C0 ของข้อต่อโดยตรงทุกเฟรม ด้วยคลื่นไซน์ที่เฟสต่างกันไปตามขา ขาจึงสลับกันก้าว
-- เหมือนแมงมุมจริง และ **ความเร็วของท่าผูกกับความเร็วที่ตัวมันเคลื่อนที่จริง** ยืนนิ่งก็ไม่ก้าว
local RunService = game:GetService("RunService")

local MobMotion = {}

--------------------------------------------------------------------------------
-- ตัวเลข
--------------------------------------------------------------------------------

-- ขาแกว่งไปกลับกี่องศา และงอเข่าเท่าไหร่ตอนยกขา
local HIP_SWING = 18
local KNEE_LIFT = 14

-- รอบการก้าวต่อ 1 stud ที่เดินได้ — ผูกกับระยะทาง ไม่ใช่กับเวลา ขาจึงไม่ "ปั่น" ตอนมอนเดินช้า
local STEPS_PER_STUD = 0.55

-- หายใจตอนยืนนิ่ง: ช้าและตื้น พอให้ไม่เหมือนรูปปั้น
local BREATH_SPEED = 1.6
local BREATH_DEPTH = 2.2   -- องศา

-- ถือว่า "กำลังเดิน" เมื่อเร็วกว่านี้
local MOVING_SPEED = 0.8

--------------------------------------------------------------------------------
-- หาข้อต่อ
--------------------------------------------------------------------------------

-- คืนรายการขา แต่ละตัวมี hip/knee และเฟสของมันเอง หรือ nil ถ้าโมเดลนี้ไม่ใช่ขาหลายขา
--
-- เฟสคือหัวใจของท่าเดินแมงมุม: ขาที่อยู่ตรงข้ามกัน (ซ้าย1 กับ ขวา2) ก้าวพร้อมกัน ส่วนขาข้างเดียวกัน
-- ที่อยู่ติดกันก้าวสลับกัน — เป็นท่าเดินจริงของแมลง เรียกว่า alternating tetrapod
local function findLegs(model)
	local legs = {}
	for _, side in ipairs({ "L", "R" }) do
		for i = 1, 4 do
			local hip = model:FindFirstChild("Hip" .. side .. i, true)
			local knee = model:FindFirstChild("Knee" .. side .. i, true)
			if hip and hip:IsA("Motor6D") then
				-- ขาซ้ายคู่/ขาขวาคี่ = กลุ่มหนึ่ง อีกครึ่งเป็นอีกกลุ่ม ต่างเฟสกันครึ่งรอบ
				local group = ((i % 2 == 0) == (side == "L")) and 0 or math.pi
				table.insert(legs, {
					hip = hip,
					knee = (knee and knee:IsA("Motor6D")) and knee or nil,
					hipBase = hip.C0,
					kneeBase = knee and knee:IsA("Motor6D") and knee.C0 or nil,
					phase = group,
					-- ขาหน้าแกว่งมากกว่าขาหลังนิดหน่อย ดูมีชีวิตกว่าขาที่เหมือนกันหมดแปดขา
					gain = 1.15 - (i - 1) * 0.1,
					side = side == "L" and 1 or -1,
				})
			end
		end
	end
	return #legs > 0 and legs or nil
end

--------------------------------------------------------------------------------
-- ผูกกับมอนหนึ่งตัว
--------------------------------------------------------------------------------

local Active = {} -- [model] = connection

-- เริ่มขยับขาให้โมเดลนี้ ถ้ามันมีขาแบบที่รู้จัก
--
-- คืน true ถ้ารับงาน (แปลว่าผู้เรียกไม่ต้องไปเล่นอนิเมชันเดินให้อีก)
function MobMotion.Attach(model)
	if Active[model] then return true end
	local legs = findLegs(model)
	if not legs then return false end

	local root = model.PrimaryPart or model:FindFirstChild("HumanoidRootPart")
	if not root then return false end

	-- ระยะทางสะสม ไม่ใช่เวลา — ท่าเดินจึงตรงกับการเคลื่อนที่จริงเสมอ แม้ WalkSpeed จะเปลี่ยนกลางทาง
	local travelled = 0
	local t0 = os.clock()

	local connection
	connection = RunService.Heartbeat:Connect(function(dt)
		if not model.Parent or not root.Parent then
			connection:Disconnect()
			Active[model] = nil
			return
		end

		local speed = (root.AssemblyLinearVelocity * Vector3.new(1, 0, 1)).Magnitude
		local moving = speed > MOVING_SPEED
		if moving then travelled += speed * dt end

		local walkPhase = travelled * STEPS_PER_STUD * math.pi * 2
		local breath = math.sin((os.clock() - t0) * BREATH_SPEED)

		for _, leg in ipairs(legs) do
			local swing, lift
			if moving then
				local a = walkPhase + leg.phase
				swing = math.sin(a) * HIP_SWING * leg.gain
				-- เข่างอเฉพาะครึ่งรอบที่ขายกขึ้น (ค่าบวกของ cos) อีกครึ่งคือขาที่ยันพื้นอยู่
				lift = math.max(0, math.cos(a)) * KNEE_LIFT * leg.gain
			else
				-- ยืนนิ่ง: หายใจ ขาขยับน้อยมากและพร้อมกันทั้งตัว
				swing = breath * BREATH_DEPTH * leg.gain
				lift = math.abs(breath) * BREATH_DEPTH * 0.6
			end

			-- หมุนรอบแกน Y ของข้อต่อ = ขาแกว่งไปหน้า-หลัง ส่วนแกน Z = ยกขึ้น-ลง
			leg.hip.C0 = leg.hipBase * CFrame.Angles(0, math.rad(swing * leg.side), 0)
			if leg.knee and leg.kneeBase then
				leg.knee.C0 = leg.kneeBase * CFrame.Angles(0, 0, math.rad(lift * leg.side))
			end
		end
	end)

	Active[model] = connection
	return true
end

function MobMotion.Detach(model)
	local c = Active[model]
	if c then
		c:Disconnect()
		Active[model] = nil
	end
end

--------------------------------------------------------------------------------
-- กระตุกตอนโดนตี
--------------------------------------------------------------------------------

-- เอียงตัวและเด้งถอยไปตามทิศที่โดนตี
--
-- ต่างจากเรฟที่ส่งมา 3 จุด ซึ่งทั้งสามจุดจะพังของเดิมถ้าลอกมาตรงๆ:
--
-- 1. **ไม่แตะ WalkSpeed** เรฟตั้งกลับเป็น 16 ตายตัว ซึ่งไม่มีมอนตัวไหนในเกมนี้เดินเท่านั้น (สไลม์เดิน 7)
--    มอนทุกตัวจะเร็วขึ้นถาวรหลังโดนตีครั้งแรก การหยุดใช้ stunnedUntil ที่ลูป AI อ่านอยู่แล้วแทน
-- 2. **ไม่ tween CFrame ของ root** เรฟ tween ทั้ง CFrame และ AssemblyLinearVelocity พร้อมกัน สองอย่างนี้
--    สู้กันเอง (อันหนึ่งสั่งตำแหน่ง อีกอันสั่งความเร็ว) เขียนเฉพาะความเร็ว แล้วเอียงตัวด้วยข้อต่อแทน
-- 3. **แรงเด้งมีเพดาน** เรฟคูณดาเมจตรงๆ ดาเมจ 200 จากบอสจะดีดมอนข้ามแมพ
function MobMotion.Flinch(model, fromPosition, damage, weight)
	local root = model.PrimaryPart or model:FindFirstChild("HumanoidRootPart")
	if not root then return end

	-- ทิศหนีจากคนตี แบนราบ ไม่งั้นการตีจากที่สูงจะกดมอนลงดิน
	local away = root.CFrame.LookVector * -1
	if fromPosition then
		local delta = (root.Position - fromPosition) * Vector3.new(1, 0, 1)
		if delta.Magnitude > 0.1 then away = delta.Unit end
	end

	-- แรงตามดาเมจแต่มีเพดาน และหารด้วยน้ำหนักตัว บอสตัวใหญ่จึงสะเทือนน้อยกว่าสไลม์ตัวเล็ก
	-- ซึ่งเป็นสิ่งที่ผู้ใช้ขอ ("บอสตัวใหญ่ยักษ์มีแรงสะเทือนถอยหลังแบบมีมิติ")
	local push = math.clamp((damage or 10) * 0.55, 3, 22) / math.max(1, weight or 1)
	root.AssemblyLinearVelocity = away * push + Vector3.new(0, push * 0.35, 0)

	-- สะดุ้ง: เอียงตัวแป๊บเดียวแล้วคืนรูป ทำที่ RootJoint ซึ่งเป็นข้อต่อของ "ร่างที่มองเห็น" จึงไม่ไปยุ่งกับ
	-- humanoid ที่ยังยืนตรงและชนกำแพงตามปกติ — เทคนิคเดียวกับท่าคลานที่ DownedController ใช้
	local joint = model:FindFirstChild("RootJoint", true)
	if joint and joint:IsA("Motor6D") then
		local base = joint.C0
		joint.C0 = base * CFrame.Angles(math.rad(-14), 0, math.rad(math.random(-16, 16)))
		task.delay(0.16, function()
			if joint.Parent then joint.C0 = base end
		end)
	end
end

return MobMotion
