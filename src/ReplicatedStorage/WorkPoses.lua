-- WorkPoses: ท่าทำงานหลายจังหวะ (ทำอาหาร ปั่นน้ำ ต้มยา พันแผล)
--
-- **เขียนลง Transform ของข้อต่อเอง ไม่ใช่อนิเมชันที่อัปโหลด** ด้วยเหตุผลเดียวกับที่ ConsumeController เขียนไว้:
-- อนิเมชันต้องอัปโหลดใต้บัญชีที่ถูกต้องและหายไปเองได้ ส่วนโค้ดนี้หายไม่ได้ และเขียนทับหลัง Animator ทำงานแล้ว
-- (RunService.Stepped) ท่าเดินและท่าวิ่งจึงยังขยับขาอยู่ข้างใต้ตามปกติ
--
-- ลำดับจังหวะมาจากคู่มือภาพของผู้ใช้ทีละใบ:
--   stove   ตั้งหม้อ → ใส่วัตถุดิบ → คนหม้อ → เช็คอุณหภูมิ → เสร็จ   (เน้นข้อมือคนและโยกตัวจากสะโพก)
--   still   ใส่สมุนไพร → ตรวจการกลั่น → เติมผง → คนอย่างควบคุม → น้ำยาเปลี่ยนสี → พร้อมริน (เน้นแขน-ถึง-มือ)
--   bandage ล้างแผล → สำลี → ผ้าก๊อซ → กดห้ามเลือด → พันยึด            (เน้นแขน-ถึง-ข้อมือ และแรงกด)
--   blender เทผลไม้ → ปิดฝา → โยกคันโยกไอน้ำ → ริน                      (ไม่มีภาพ แต่งให้เข้าชุดกัน)
--
-- **จังหวะเดียวในแต่ละชุดเป็น `filler`** = จังหวะที่ยืดได้ (คนหม้อ / คนยา / กดห้ามเลือด) เวลาที่เหลือทั้งหมด
-- ตกเป็นของมัน สเต็กที่ใช้เวลา 15 นาทีจึงเป็น "ยืนคนหม้อ 15 นาที" ไม่ใช่ท่าตั้งหม้อค้างไว้สิบห้านาที และ
-- ถ้าเวลาสั้นกว่าจังหวะตายตัวรวมกัน (ข้าวผัด 2.5 วิ) ทุกจังหวะจะถูกย่อตามส่วนให้ครบชุดพอดี
local RunService = game:GetService("RunService")

local WorkPoses = {}

local function rad(d) return math.rad(d) end

-- ข้อต่อ R15 ที่ท่าพวกนี้ใช้ ตัวไหนไม่มี (ริกยังประกอบไม่เสร็จ) ก็ข้ามไปเงียบๆ
local function joints(character)
	local function motor(partName, jointName)
		local part = character:FindFirstChild(partName)
		return part and part:FindFirstChild(jointName) or nil
	end
	local j = {
		ls = motor("LeftUpperArm", "LeftShoulder"),
		rs = motor("RightUpperArm", "RightShoulder"),
		le = motor("LeftLowerArm", "LeftElbow"),
		re = motor("RightLowerArm", "RightElbow"),
		lw = motor("LeftHand", "LeftWrist"),
		rw = motor("RightHand", "RightWrist"),
		neck = motor("Head", "Neck"),
		waist = motor("UpperTorso", "Waist"),
	}
	-- ไหล่สองข้างเป็นอย่างน้อย ไม่งั้นไม่มีอะไรให้ดู
	if not j.ls or not j.rs then return nil end
	return j
end

local function set(joint, cframe)
	if joint then joint.Transform = cframe end
end

-- ท่าพื้นฐานที่หลายจังหวะเริ่มจาก: แขนสองข้างยกมาข้างหน้าระดับเอว เหมือนยืนทำงานอยู่หน้าโต๊ะ
--
-- **X บวกคือแขนกางไปข้างหน้า** บน R15 (บทเรียนจาก ConsumeController: รอบแรกใช้ค่าลบแล้วมือไปอยู่หลังตัว)
-- ส่วนคอใช้ค่าลบเพื่อก้มลงมอง
local function workStance(j, lean)
	set(j.ls, CFrame.Angles(rad(45), 0, rad(18)))
	set(j.rs, CFrame.Angles(rad(45), 0, rad(-18)))
	set(j.le, CFrame.Angles(rad(55), 0, 0))
	set(j.re, CFrame.Angles(rad(55), 0, 0))
	set(j.neck, CFrame.Angles(rad(-(lean or 10)), 0, 0))
end

--------------------------------------------------------------------------------
-- ชุดท่า
--
-- แต่ละจังหวะคือ { name, seconds, filler, pose(j, u, t) } โดย u = ความคืบหน้าในจังหวะนั้น (0..1)
-- และ t = เวลาจริงตั้งแต่เริ่มท่า (ไว้ทำการแกว่งที่ไม่ผูกกับความยาวจังหวะ เช่น การคน)
--------------------------------------------------------------------------------

local SEQUENCES = {}

-- ทำอาหาร: การต้ม -----------------------------------------------------------
SEQUENCES.stove = {
	{ name = "ตั้งหม้อ", seconds = 2.2, pose = function(j, u)
		-- ยกหม้อขึ้นตั้งบนเตา: สองแขนถือของหนักอยู่หน้าตัวแล้ววางลง
		local lift = 1 - math.abs(u * 2 - 1) -- ขึ้นแล้วลง
		set(j.ls, CFrame.Angles(rad(50 + lift * 22), 0, rad(22)))
		set(j.rs, CFrame.Angles(rad(50 + lift * 22), 0, rad(-22)))
		set(j.le, CFrame.Angles(rad(70 - lift * 15), 0, 0))
		set(j.re, CFrame.Angles(rad(70 - lift * 15), 0, 0))
		set(j.neck, CFrame.Angles(rad(-14), 0, 0))
		set(j.waist, CFrame.Angles(rad(-6 * lift), 0, 0))
	end },
	{ name = "ใส่วัตถุดิบ", seconds = 2.2, pose = function(j, u, t)
		-- มือขวายกของเหนือหม้อแล้วคว่ำข้อมือเทลง มือซ้ายถือจานรอง
		workStance(j, 14)
		local tip = math.clamp((u - 0.35) / 0.5, 0, 1)
		set(j.rs, CFrame.Angles(rad(78 + tip * 8), 0, rad(-14)))
		set(j.re, CFrame.Angles(rad(48), 0, 0))
		set(j.ls, CFrame.Angles(rad(58), 0, rad(24)))
		set(j.le, CFrame.Angles(rad(62), 0, 0))
		-- คว่ำข้อมือเท แล้วสะบัดเบาๆ ตอนท้ายให้ของร่วงหมด
		local flick = tip > 0.6 and 8 * math.sin(t * 22) or 0
		set(j.rw, CFrame.Angles(0, 0, rad(-70 * tip + flick)))
	end },
	{ name = "คนหม้อ", seconds = 3.0, filler = true, pose = function(j, _, t)
		-- **หัวใจของท่านี้** หมุนข้อมือคนวนไปทางเดียว (wrist-to-ladle) และโยกตัวจากสะโพกตามรอบการคน
		local a = t * math.pi * 2 * 0.8 -- ราวหนึ่งรอบต่อวินาทีกว่าๆ คนซุปไม่ใช่ตีไข่
		set(j.rs, CFrame.Angles(rad(68 + 10 * math.sin(a)), rad(8 * math.cos(a)), rad(-16 + 10 * math.cos(a))))
		set(j.re, CFrame.Angles(rad(52 + 12 * math.sin(a)), 0, 0))
		set(j.rw, CFrame.Angles(rad(12 * math.sin(a)), rad(25 * math.cos(a)), rad(-20 + 18 * math.sin(a))))
		-- มือซ้ายจับหูหม้อไว้ให้นิ่ง
		set(j.ls, CFrame.Angles(rad(52), 0, rad(26)))
		set(j.le, CFrame.Angles(rad(66), 0, 0))
		-- โยกจากสะโพก: แรงคนมาจากลำตัว ไม่ใช่ข้อมืออย่างเดียว
		set(j.waist, CFrame.Angles(rad(-5 + 2 * math.sin(a)), rad(4 * math.cos(a)), rad(3 * math.sin(a))))
		set(j.neck, CFrame.Angles(rad(-18), rad(3 * math.cos(a)), 0))
	end },
	{ name = "เช็คอุณหภูมิ", seconds = 2.0, pose = function(j, u)
		-- ก้มลงดูไอ แล้วยกมือขวามาใกล้หน้าเหมือนโบกกลิ่นเข้าจมูก
		workStance(j, 24)
		local wave = math.sin(u * math.pi * 3)
		set(j.rs, CFrame.Angles(rad(72), 0, rad(-26 + 6 * wave)))
		set(j.re, CFrame.Angles(rad(96), 0, 0))
		set(j.rw, CFrame.Angles(0, rad(18 * wave), 0))
		set(j.neck, CFrame.Angles(rad(-28), 0, 0))
		set(j.waist, CFrame.Angles(rad(-8), 0, 0))
	end },
	{ name = "เสร็จแล้ว", seconds = 1.4, pose = function(j, u)
		-- ยกหม้อขึ้นจากเตา ยืดตัวขึ้น
		set(j.ls, CFrame.Angles(rad(58 + u * 14), 0, rad(20)))
		set(j.rs, CFrame.Angles(rad(58 + u * 14), 0, rad(-20)))
		set(j.le, CFrame.Angles(rad(74), 0, 0))
		set(j.re, CFrame.Angles(rad(74), 0, 0))
		set(j.neck, CFrame.Angles(rad(-6 + u * 6), 0, 0))
	end },
}

-- ปั่นเครื่องดื่ม (เครื่องปั่นไอน้ำ) ------------------------------------------
SEQUENCES.blender = {
	{ name = "เทผลไม้ลงโถ", seconds = 2.0, pose = function(j, u)
		workStance(j, 12)
		local tip = math.clamp((u - 0.3) / 0.6, 0, 1)
		set(j.rs, CFrame.Angles(rad(74), 0, rad(-16)))
		set(j.re, CFrame.Angles(rad(52), 0, 0))
		set(j.rw, CFrame.Angles(0, 0, rad(-80 * tip)))
	end },
	{ name = "ปิดฝาแล้วกดล็อก", seconds = 1.6, pose = function(j, u)
		local press = math.sin(u * math.pi)
		set(j.ls, CFrame.Angles(rad(62 - press * 10), 0, rad(16)))
		set(j.rs, CFrame.Angles(rad(62 - press * 10), 0, rad(-16)))
		set(j.le, CFrame.Angles(rad(58 + press * 10), 0, 0))
		set(j.re, CFrame.Angles(rad(58 + press * 10), 0, 0))
		set(j.waist, CFrame.Angles(rad(-8 * press), 0, 0))
		set(j.neck, CFrame.Angles(rad(-16), 0, 0))
	end },
	{ name = "โยกคันโยกไอน้ำ", seconds = 3.0, filler = true, pose = function(j, _, t)
		-- โยกขึ้นลงเป็นจังหวะ ตัวสั่นตามเครื่องนิดหน่อย
		local a = t * math.pi * 2 * 1.1
		local pump = math.sin(a)
		local shake = math.sin(t * 34) * 1.5
		set(j.rs, CFrame.Angles(rad(64 + pump * 20 + shake), 0, rad(-14)))
		set(j.re, CFrame.Angles(rad(60 - pump * 22), 0, 0))
		set(j.ls, CFrame.Angles(rad(46 + shake), 0, rad(22)))
		set(j.le, CFrame.Angles(rad(58), 0, 0))
		set(j.waist, CFrame.Angles(rad(-4 + pump * 3), rad(pump * 4), 0))
		set(j.neck, CFrame.Angles(rad(-12 + shake), 0, 0))
	end },
	{ name = "รินใส่แก้ว", seconds = 2.0, pose = function(j, u)
		local tip = math.clamp((u - 0.2) / 0.6, 0, 1)
		set(j.ls, CFrame.Angles(rad(58), 0, rad(20)))
		set(j.rs, CFrame.Angles(rad(58), 0, rad(-20)))
		set(j.le, CFrame.Angles(rad(64), 0, 0))
		set(j.re, CFrame.Angles(rad(64), 0, 0))
		set(j.lw, CFrame.Angles(0, 0, rad(55 * tip)))
		set(j.rw, CFrame.Angles(0, 0, rad(-55 * tip)))
		set(j.neck, CFrame.Angles(rad(-20), 0, 0))
	end },
}

-- ต้มยา: การกลั่นและผสม ------------------------------------------------------
SEQUENCES.still = {
	{ name = "ใส่สมุนไพร", seconds = 2.0, pose = function(j, u, t)
		workStance(j, 16)
		local drop = math.clamp((u - 0.3) / 0.6, 0, 1)
		set(j.rs, CFrame.Angles(rad(82), 0, rad(-12)))
		set(j.re, CFrame.Angles(rad(44), 0, 0))
		set(j.rw, CFrame.Angles(rad(30 * drop), 0, rad(6 * math.sin(t * 18))))
	end },
	{ name = "ตรวจการกลั่น", seconds = 2.0, pose = function(j, u)
		-- ยกขวดขึ้นส่องระดับสายตา เอียงหัวดู
		local raise = math.min(u * 2, 1)
		set(j.ls, CFrame.Angles(rad(52), 0, rad(24)))
		set(j.le, CFrame.Angles(rad(62), 0, 0))
		set(j.rs, CFrame.Angles(rad(60 + raise * 26), 0, rad(-18)))
		set(j.re, CFrame.Angles(rad(70 + raise * 26), 0, 0))
		set(j.rw, CFrame.Angles(0, rad(20 * raise), 0))
		set(j.neck, CFrame.Angles(rad(4 * raise), rad(-10 * raise), 0))
	end },
	{ name = "เติมผง", seconds = 2.0, pose = function(j, _, t)
		-- ถูปลายนิ้วโรยผงลงหม้อ: ข้อมือบิดกลับไปกลับมาถี่ๆ
		workStance(j, 18)
		local rub = math.sin(t * 16)
		set(j.rs, CFrame.Angles(rad(80), 0, rad(-20)))
		set(j.re, CFrame.Angles(rad(58), 0, 0))
		set(j.rw, CFrame.Angles(rad(14 * rub), rad(18 * rub), 0))
		set(j.ls, CFrame.Angles(rad(56), 0, rad(26)))
		set(j.le, CFrame.Angles(rad(70), 0, 0))
		set(j.neck, CFrame.Angles(rad(-24), 0, 0))
	end },
	{ name = "คนอย่างควบคุม", seconds = 3.0, filler = true, pose = function(j, _, t)
		-- ช้ากว่าการคนหม้อครัวราวครึ่งหนึ่ง: ภาพเน้นว่า "ควบคุม" ไม่ใช่แรง มือซ้ายประคองขวดไว้นิ่งๆ
		local a = t * math.pi * 2 * 0.45
		set(j.rs, CFrame.Angles(rad(70 + 7 * math.sin(a)), rad(6 * math.cos(a)), rad(-18 + 7 * math.cos(a))))
		set(j.re, CFrame.Angles(rad(56 + 9 * math.sin(a)), 0, 0))
		set(j.rw, CFrame.Angles(rad(10 * math.sin(a)), rad(20 * math.cos(a)), 0))
		set(j.ls, CFrame.Angles(rad(64), 0, rad(28)))
		set(j.le, CFrame.Angles(rad(72), 0, 0))
		set(j.lw, CFrame.Angles(0, 0, rad(8 * math.sin(a * 0.5))))
		set(j.waist, CFrame.Angles(rad(-4), rad(3 * math.cos(a)), 0))
		set(j.neck, CFrame.Angles(rad(-22), 0, 0))
	end },
	{ name = "น้ำยาเปลี่ยนสี", seconds = 1.8, pose = function(j, u)
		-- ผงะถอยเล็กน้อย ยกมือขึ้นกันไอ
		local back = math.sin(u * math.pi)
		set(j.ls, CFrame.Angles(rad(56 + back * 20), 0, rad(30)))
		set(j.rs, CFrame.Angles(rad(56 + back * 20), 0, rad(-30)))
		set(j.le, CFrame.Angles(rad(80), 0, 0))
		set(j.re, CFrame.Angles(rad(80), 0, 0))
		set(j.waist, CFrame.Angles(rad(6 * back), 0, 0))
		set(j.neck, CFrame.Angles(rad(8 * back), 0, 0))
	end },
	{ name = "พร้อมริน", seconds = 1.6, pose = function(j, u)
		local tip = math.clamp((u - 0.2) / 0.7, 0, 1)
		set(j.ls, CFrame.Angles(rad(60), 0, rad(22)))
		set(j.rs, CFrame.Angles(rad(64), 0, rad(-22)))
		set(j.le, CFrame.Angles(rad(66), 0, 0))
		set(j.re, CFrame.Angles(rad(70), 0, 0))
		set(j.rw, CFrame.Angles(0, 0, rad(-60 * tip)))
		set(j.neck, CFrame.Angles(rad(-18), 0, 0))
	end },
}

-- ปฐมพยาบาลแผลสด ------------------------------------------------------------
--
-- แขนซ้ายยื่นออกหน้าเป็น "แขนที่บาดเจ็บ" ตลอดทั้งชุด มือขวาเป็นมือที่ทำงาน ตามคู่มือภาพ
local function woundedArm(j)
	set(j.ls, CFrame.Angles(rad(80), rad(-25), rad(20)))
	set(j.le, CFrame.Angles(rad(35), 0, 0))
	set(j.neck, CFrame.Angles(rad(-22), 0, 0))
end

SEQUENCES.bandage = {
	{ name = "ล้างแผล", seconds = 1.2, pose = function(j, _, t)
		woundedArm(j)
		-- ปาดไปมาตามแนวปลายแขน
		local sweep = math.sin(t * 7)
		set(j.rs, CFrame.Angles(rad(72), rad(10 * sweep), rad(-30 + 10 * sweep)))
		set(j.re, CFrame.Angles(rad(64), 0, 0))
		set(j.rw, CFrame.Angles(0, rad(14 * sweep), 0))
	end },
	{ name = "สำลีชุบแอลกอฮอล์", seconds = 1.2, pose = function(j, _, t)
		woundedArm(j)
		-- แตะเป็นจุดๆ ไม่ปาด: ขยับสั้นแล้วหยุด
		local dab = math.max(0, math.sin(t * 9))
		set(j.rs, CFrame.Angles(rad(70 + dab * 8), 0, rad(-28)))
		set(j.re, CFrame.Angles(rad(60 + dab * 14), 0, 0))
	end },
	{ name = "ปิดผ้าก๊อซ", seconds = 1.2, pose = function(j, u)
		woundedArm(j)
		local lay = math.sin(math.clamp(u, 0, 1) * math.pi)
		set(j.rs, CFrame.Angles(rad(66 + lay * 10), 0, rad(-26)))
		set(j.re, CFrame.Angles(rad(58 + lay * 8), 0, 0))
		set(j.rw, CFrame.Angles(rad(-12 * lay), 0, 0))
	end },
	{ name = "กดห้ามเลือด", seconds = 1.6, filler = true, pose = function(j, _, t)
		-- จังหวะที่ยืดได้: กดค้าง สั่นจากแรงกดนิดเดียว ไม่ใช่ขยับไปมา (ภาพเขียนว่าเน้นแรงกดและการควบคุม)
		woundedArm(j)
		local push = 1 + 0.12 * math.sin(t * 3)
		set(j.rs, CFrame.Angles(rad(74 * push), 0, rad(-24)))
		set(j.re, CFrame.Angles(rad(72 * push), 0, 0))
		set(j.rw, CFrame.Angles(rad(-18), 0, 0))
		set(j.neck, CFrame.Angles(rad(-26), 0, 0))
	end },
	{ name = "พันยึด", seconds = 1.8, pose = function(j, _, t)
		-- มือขวาวนรอบปลายแขนซ้ายเป็นวง = พันผ้า (ท่าเดิมของเกม ยกมาเป็นจังหวะสุดท้าย)
		woundedArm(j)
		local a = t * math.pi * 2 * 2
		set(j.rs, CFrame.Angles(rad(70 + 14 * math.sin(a)), rad(10 * math.cos(a)), rad(-30 + 12 * math.cos(a))))
		set(j.re, CFrame.Angles(rad(60 + 18 * math.sin(a)), 0, 0))
		set(j.rw, CFrame.Angles(0, rad(20 * math.sin(a)), 0))
	end },
}

WorkPoses.Sequences = SEQUENCES

--------------------------------------------------------------------------------
-- เล่นท่า
--------------------------------------------------------------------------------

-- วางแผนความยาวของแต่ละจังหวะให้ลงพอดีกับ `seconds`
--
-- seconds = nil แปลว่า "ยังไม่รู้ว่านานแค่ไหน" จังหวะที่ยืดได้จะยาวไม่จำกัดจนกว่าจะสั่งหยุด
local function planSteps(sequence, seconds)
	local fixed = 0
	local fillers = 0
	for _, step in ipairs(sequence) do
		if step.filler then fillers += 1 else fixed += step.seconds end
	end

	local lengths = {}
	if not seconds or seconds <= 0 then
		for index, step in ipairs(sequence) do
			lengths[index] = step.filler and math.huge or step.seconds
		end
		return lengths
	end

	-- เวลาน้อยกว่าจังหวะตายตัวรวมกัน (ข้าวผัดใช้ 2.5 วิ) → ย่อทุกจังหวะตามส่วน ครบชุดแต่เร็วขึ้น
	if fixed >= seconds then
		local scale = seconds / fixed
		for index, step in ipairs(sequence) do
			lengths[index] = step.filler and 0 or step.seconds * scale
		end
		return lengths
	end

	-- เวลาที่เหลือตกเป็นของจังหวะที่ยืดได้ (ถ้าชุดไหนไม่มีเลย ก็แบ่งเพิ่มให้ทุกจังหวะเท่าๆ กัน)
	local spare = seconds - fixed
	for index, step in ipairs(sequence) do
		if step.filler then
			lengths[index] = spare / fillers
		else
			lengths[index] = step.seconds + (fillers == 0 and spare / #sequence or 0)
		end
	end
	return lengths
end

-- เล่นท่า `kind` บนตัวละคร คืน handle ที่มี :Stop() — คืน nil ถ้าริกยังไม่พร้อมหรือไม่รู้จักท่านี้
--
-- `shouldRun` (ถ้ามี) ถูกถามทุกเฟรม: คืน false เมื่อไหร่ ท่าจะหยุดเขียนข้อต่อชั่วคราว (เช่นเดินออกจากเตา)
-- แล้วกลับมาเล่นต่อเมื่อคืนค่า true อีกครั้ง — นาฬิกายังเดินอยู่ ไม่ได้หยุดรอ เหมือนอาหารที่ตุ๋นต่อไปเอง
function WorkPoses.Play(character, kind, seconds, shouldRun)
	if not character then return nil end
	local sequence = SEQUENCES[kind]
	if not sequence then return nil end
	local j = joints(character)
	if not j then return nil end

	local lengths = planSteps(sequence, seconds)
	local started = os.clock()

	local handle = {}

	function handle:Stop()
		if self.connection then
			self.connection:Disconnect()
			self.connection = nil
		end
	end

	handle.connection = RunService.Stepped:Connect(function()
		if not character.Parent then
			handle:Stop()
			return
		end
		if shouldRun and not shouldRun() then return end

		local elapsed = os.clock() - started
		local cursor = 0
		for index, step in ipairs(sequence) do
			local length = lengths[index] or 0
			-- จังหวะสุดท้ายรับช่วงที่เหลือทั้งหมด: เวลาเกินแผนเมื่อไหร่ก็ค้างท่าจบไว้ ไม่ใช่กลับไปตั้งต้นใหม่
			if elapsed < cursor + length or index == #sequence then
				local u = length > 0 and math.clamp((elapsed - cursor) / length, 0, 1) or 1
				step.pose(j, u, elapsed)
				return
			end
			cursor += length
		end
	end)

	return handle
end

return WorkPoses
