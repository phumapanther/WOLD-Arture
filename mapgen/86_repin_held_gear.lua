-- 86_repin_held_gear.lua: ตรึงท่าถืออาวุธ/โล่ให้ "อยู่จริงตอนมอนเกิด" ไม่ใช่แค่สวยใน ServerStorage
--
-- ผู้ใช้แจ้ง 2026-09-20 (รอบสาม): "ดาบของบอสโลกยังแทงหัวไหล่ขึ้นมา · โล่ของมอนให้อยู่แบบเดียวกับที่คนถือ
-- · ดาบมันถือไปข้างหลังไม่ใช่ข้างหน้า" — ทั้งที่เฟส 84 กับ 85 แก้ท่าไปแล้วและวัดแล้วว่าตรง
--
-- **ต้นเหตุจริง: `WeldConstraint` จำระยะห่างตอนที่มันถูกสร้าง ไม่ใช่ตอนที่เราขยับชิ้นส่วน**
-- เฟส 84/85 ขยับ `CFrame` ของดาบในต้นแบบที่นอนอยู่ใน ServerStorage ซึ่งไม่มีฟิสิกส์มาบังคับอะไร ท่าจึง
-- "ดูถูก" ทุกครั้งที่ไปวัด — แต่วินาทีที่โมเดลถูกโคลนลง Workspace ตอนมอนเกิด weld ตัวเดิมก็ดึงดาบกลับไป
-- ท่าเก่าทันที **เฟสก่อนหน้าจึงไม่เคยมีผลในเกมจริงเลยสักครั้ง** (พิสูจน์แล้ว: โคลนต้นแบบลง Workspace
-- แล้ววัด ได้ปลายดาบชี้ไปข้างหลัง +Z ตรงกับภาพที่ผู้ใช้ส่งมา ทั้งที่ต้นแบบใน ServerStorage วัดได้ว่าชี้หน้า)
--
-- เฟสนี้จึงทำสามอย่าง เรียงตามลำดับ:
--   1. ตั้งมุมดาบให้ตรงเป้า (เหมือนเฟส 85 แต่คิดทั้งมุมเอนหน้าและมุมกางออกข้าง)
--   2. ย้ายโล่ไปติด **ท่อนแขนล่าง** ทรงเดียวกับโล่ของผู้เล่นเป๊ะ (`GRIP.Shield` ใน WeaponVisuals)
--   3. **สร้าง weld ใหม่เป็น `Weld` ที่มี C0 เขียนไว้ตรงๆ** — ท่าที่เห็นตอนนี้กลายเป็นท่าที่ถูกบันทึก
--      ไม่ใช่ท่าที่ถูกจำไว้ตั้งแต่ตอนโรงงานปั้น
--
-- รันซ้ำได้: ทุกอย่างตั้งค่าเป็นเป้าหมายสัมบูรณ์ ไม่ใช่การบวกเพิ่มจากของเดิม
local ServerStorage = game:GetService("ServerStorage")

local FOLDERS = { "Model_moster", "Model_mosterV2", "New_moster" }

-- ดาบเอนไปข้างหน้าเท่านี้ (เท่าเฟส 85 ที่ผู้ใช้ไม่ได้ติ) และกางออกข้างตัวเท่านี้
local LEAN_DEGREES = 17
local FLARE_DEGREES = 8
-- **บอสต้องกางกว่านั้นมาก** ไหล่มันมีหนามสามซี่ยื่นออกไปถึง 2.5 studs จากแกนกลาง (วัดในเพลส) และดาบ
-- ยาว 8 studs ที่ตั้งเกือบตรงจะไต่ผ่านแนวหนามพอดี = "ดาบแทงหัวไหล่" ตามภาพ · 32° ดันปลายออกไปพ้นไหล่
local BOSS_FLARE_DEGREES = 32
local BOSS_LEAN_DEGREES = 20

-- ช่องว่างระหว่างใบโล่กับแขน เท่ากับของผู้เล่น (`GRIP.Shield` = 0.75 บนแขนกว้าง 1.0 ใบหนา 0.18)
-- ด้ามอยู่ห่างจากจุดกึ่งกลางมือไปข้างหน้าเท่านี้ (โรงงานใช้ 0.5 กับโครงกระดูก)
local PALM_FORWARD = 0.45
-- เยื้องออกจากลำตัวอีกนิด: การ์ดดาบของบอสกว้าง 3.74 studs วางกลางฝ่ามือเป๊ะแล้วมันเฉี่ยวเกราะอก
-- (วัดได้ -0.07 studs = ซ้อนกันนิดเดียว ซึ่งที่สเกล 3.9 ในเกมจริงกลายเป็น 0.27)
local PALM_OUT = 0.2

local SHIELD_GAP = 0.16
local SHIELD_RISE = 0.15

local RIG_PARTS = {
	HumanoidRootPart = true, LowerTorso = true, UpperTorso = true, Head = true,
	LeftUpperArm = true, LeftLowerArm = true, LeftHand = true,
	RightUpperArm = true, RightLowerArm = true, RightHand = true,
	LeftUpperLeg = true, LeftLowerLeg = true, LeftFoot = true,
	RightUpperLeg = true, RightLowerLeg = true, RightFoot = true,
}

local lines = {}
local function log(fmt, ...) lines[#lines + 1] = fmt:format(...) end

-- ชิ้นส่วนทั้งหมดของพวงหนึ่ง (โมเดลลูกหนึ่งตัว = ของหนึ่งชิ้นที่แขวนอยู่กับแขนขา)
local function partsOf(group)
	local out = {}
	for _, d in ipairs(group:GetDescendants()) do
		if d:IsA("BasePart") then out[#out + 1] = d end
	end
	return out
end

-- แขนขาที่พวงนี้แขวนอยู่ — ดูจาก weld เส้นไหนก็ได้ที่ปลายข้างหนึ่งเป็นชิ้นของโครง
local function anchorLimb(model, parts)
	local mine = {}
	for _, p in ipairs(parts) do mine[p] = true end
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("WeldConstraint") or d:IsA("Weld") then
			local a, b = d.Part0, d.Part1
			if a and b then
				if mine[a] and RIG_PARTS[b.Name] then return b end
				if mine[b] and RIG_PARTS[a.Name] then return a end
			end
		end
	end
	return nil
end

-- หมุนทั้งพวงรอบจุดกำเนิดของแขนขาที่มันแขวนอยู่
local function turn(parts, limb, rotation)
	for _, p in ipairs(parts) do
		p.CFrame = limb.CFrame * rotation * limb.CFrame:ToObjectSpace(p.CFrame)
	end
end

-- ย้ายทั้งพวงแบบแข็ง โดยให้ชิ้นอ้างอิงไปอยู่ที่ CFrame ใหม่พอดี
local function move(parts, reference, target)
	local shift = target * reference.CFrame:Inverse()
	for _, p in ipairs(parts) do p.CFrame = shift * p.CFrame end
end

-- ทิศที่ต้องการให้ "ปลายอาวุธ" ชี้ ในพิกัดของมือ (ข้างขวา: กางออก = +X)
local function aimVector(side, leanDeg, flareDeg)
	local lean, flare = math.rad(leanDeg), math.rad(flareDeg) * side
	-- **pitch บวกเอนไปข้างหลัง** (`CFrame.Angles(t,0,0).UpVector` = (0, cos t, +sin t) และด้านหน้าคือ -Z)
	-- จึงต้องใส่ค่าลบเพื่อให้ "เอนหน้า 17°" แปลว่าเอนหน้าจริง — วัดจากของที่ขยับแล้ว ไม่ใช่จากที่เดาไว้
	return (CFrame.Angles(-lean, 0, 0) * CFrame.Angles(0, 0, -flare)).UpVector
end

-- หมุนพวงให้ทิศ `from` ไปตรงกับ `to` (ทั้งสองเป็นเวกเตอร์ในพิกัดของแขนขา) ด้วยการหมุนที่สั้นที่สุด
local function aim(parts, limb, from, to)
	local a, b = from.Unit, to.Unit
	local dot = math.clamp(a:Dot(b), -1, 1)
	if dot > 0.9995 then return false end
	local axis = a:Cross(b)
	if axis.Magnitude < 1e-4 then axis = Vector3.new(1, 0, 0) end
	turn(parts, limb, CFrame.fromAxisAngle(axis.Unit, math.acos(dot)))
	return true
end

-- **หัวใจของเฟสนี้** — เขียนท่าปัจจุบันลง weld เส้นใหม่ที่จำ C0 ไว้เอง
--
-- `WeldConstraint` จำระยะตอนสร้าง ส่วน `Weld` ถือ `C0` ที่เราเขียนให้ตรงๆ ท่าที่ตั้งไว้จึงรอดข้าม
-- การโคลนลง Workspace · Part0 เป็นแขนขาเสมอ เพื่อให้ของตามแขนไป ไม่ใช่แขนตามของ
local function repin(model, parts, limb)
	local mine = {}
	for _, p in ipairs(parts) do mine[p] = true end
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("WeldConstraint") or d:IsA("Weld") then
			if (d.Part0 and mine[d.Part0]) or (d.Part1 and mine[d.Part1]) then d:Destroy() end
		end
	end
	for _, p in ipairs(parts) do
		local weld = Instance.new("Weld")
		weld.Name = p.Name .. "Pin"
		weld.Part0 = limb
		weld.Part1 = p
		weld.C0 = limb.CFrame:ToObjectSpace(p.CFrame)
		weld.Parent = limb
	end
end

-- ใบโล่ = แผ่นที่ **กว้างสองด้าน** และบางด้านเดียว
--
-- **ห้ามใช้แค่ "กว้างและบาง"** — ใบดาบก็กว้างและบางเหมือนกัน (0.95 x 4.40 x 0.26) รอบแรกที่เขียนแบบนั้น
-- ดาบของโครงกระดูกทั้งหกตัว ดาบบอส ขวานโจร และคทาวิญญาณ ถูกจับไปแปะข้างแขนเป็นโล่กันหมด
local function shieldPlate(parts)
	local best
	for _, p in ipairs(parts) do
		local s = p.Size
		local dims = { s.X, s.Y, s.Z }
		table.sort(dims)
		local thin, mid, wide = dims[1], dims[2], dims[3]
		if wide >= 1.5 and mid >= 1.5 and thin <= wide * 0.25 then
			if not best or wide > math.max(best.Size.X, best.Size.Y, best.Size.Z) then best = p end
		end
	end
	return best
end

-- ชิ้นที่เป็น "ด้าม" — ใช้หาว่าตรงไหนของอาวุธคือจุดที่มืออยู่
local HANDLE_NAMES = { Grip = true, Haft = true, Handle = true, Hilt = true, Shaft = true, Staff = true,
	Pommel = true, Wrap = true, Rod = true, Pole = true }

-- จุดกึ่งกลางของด้าม (ในพิกัดของแขนขาที่พวงแขวนอยู่) กับปลายที่ไกลจากด้ามที่สุด
-- ไม่มีชิ้นไหนชื่อเหมือนด้ามเลย = ไม่ใช่ของที่ถือด้วยมือ (ปืนใหญ่ติดแขนของยาม) คืน nil ให้ปล่อยไว้ที่เดิม
local function gripAndTip(parts, limb)
	local sum, n = Vector3.zero, 0
	for _, p in ipairs(parts) do
		if HANDLE_NAMES[p.Name] then
			sum += limb.CFrame:PointToObjectSpace(p.Position)
			n += 1
		end
	end
	if n == 0 then return nil end
	local grip = sum / n
	local tip, far
	for _, p in ipairs(parts) do
		local at = limb.CFrame:PointToObjectSpace(p.Position)
		local d = (at - grip).Magnitude
		if not far or d > far then tip, far = at, d end
	end
	if not far or far < 1 then return nil end
	return grip, tip
end

for _, folderName in ipairs(FOLDERS) do
	local folder = ServerStorage:FindFirstChild(folderName)
	for _, model in ipairs(folder and folder:GetChildren() or {}) do
		local isBoss = model.Name:find("Boss") ~= nil
		for _, group in ipairs(model:GetChildren()) do
			if group:IsA("Model") then
				local parts = partsOf(group)
				local limb = #parts > 0 and anchorLimb(model, parts) or nil
				if limb then
					local hand = limb.Name == "RightHand" or limb.Name == "LeftHand"
					local side = limb.Name:sub(1, 4) == "Left" and -1 or 1

					-- ไกลสุดจากมือ = ปลายของสิ่งที่ถืออยู่ ใช้ตัดสินว่าเป็นอาวุธยาวหรือของติดมือ
					local tip, reach
					for _, p in ipairs(parts) do
						local d = (p.Position - limb.Position).Magnitude
						if not reach or d > reach then tip, reach = p, d end
					end

					local plate = hand and shieldPlate(parts) or nil

					local grip, tipAt = nil, nil
					if not plate then grip, tipAt = gripAndTip(parts, limb) end

					if grip and not plate then
						------------------------------------------------ อาวุธที่ถือด้วยมือ: ตั้งมุม + วางด้ามลงฝ่ามือ
						-- ปลายชี้ตามเป้า (เอนหน้า + กางออกข้าง) แล้วเลื่อนทั้งพวงให้ **กึ่งกลางด้ามอยู่ในฝ่ามือ**
						-- เลื่อนทีหลังการหมุนเสมอ ไม่งั้นการหมุนรอบจุดกำเนิดของแขนจะพาด้ามออกจากมืออีก
						local mount = model:FindFirstChild((side < 0 and "Left" or "Right") .. "Hand") or limb
						local dir = (tipAt - grip).Unit
						local want = aimVector(side,
							isBoss and BOSS_LEAN_DEGREES or LEAN_DEGREES,
							isBoss and BOSS_FLARE_DEGREES or FLARE_DEGREES)
						aim(parts, limb, dir, want)

						local gripPart
						for _, p in ipairs(parts) do
							if HANDLE_NAMES[p.Name] and (not gripPart or p.Size.Magnitude > gripPart.Size.Magnitude) then
								gripPart = p
							end
						end
						local palm = mount.CFrame * CFrame.new(side * PALM_OUT, -0.1, -PALM_FORWARD)
						-- ตำแหน่งที่ต้องการของ "จุดกึ่งกลางด้าม" — ขยับทั้งพวงด้วยผลต่าง ไม่ใช่วางชิ้นเดียว
						local gripNow = Vector3.zero
						local n = 0
						for _, p in ipairs(parts) do
							if HANDLE_NAMES[p.Name] then gripNow += p.Position; n += 1 end
						end
						gripNow /= n
						local shift = palm.Position - gripNow
						for _, p in ipairs(parts) do p.CFrame = p.CFrame + shift end

						repin(model, parts, mount)
						-- วัดซ้ำจากของจริงหลังขยับ ไม่ใช่พิมพ์ค่าที่ตั้งใจไว้ — เลขที่ปรินต์คือหลักฐาน
						local gripAfter, tipAfter = gripAndTip(parts, mount)
						local dirAfter = (tipAfter - gripAfter).Unit
						log("%s %s: ด้ามที่ (%.2f %.2f %.2f) ปลายชี้ (%.2f %.2f %.2f)", model.Name, group.Name,
							gripAfter.X, gripAfter.Y, gripAfter.Z, dirAfter.X, dirAfter.Y, dirAfter.Z)

					elseif plate then
						------------------------------------------------ โล่: ย้ายไปท่อนแขนล่าง
						-- ทรงเดียวกับโล่ของผู้เล่น: อยู่ข้างแขนด้านนอก หน้าโล่หันออกจากตัว
						-- ใบห้อยเลยมือลงไป และเว้นช่องว่างจากแขนพอให้เห็นว่ารัดอยู่ ไม่ได้ทาบติดเนื้อ
						local arm = model:FindFirstChild((side < 0 and "Left" or "Right") .. "LowerArm")
						if arm then
							local s = plate.Size
							-- แกนที่บางที่สุดคือหน้าโล่ · กว้าง/สูงคืออีกสองแกน
							local thin = math.min(s.X, s.Y, s.Z)
							local faceOut = math.rad(side < 0 and 90 or -90)
							local out = side * (arm.Size.X * 0.5 + thin * 0.5 + SHIELD_GAP)
							move(parts, plate,
								arm.CFrame * CFrame.new(out, SHIELD_RISE, 0) * CFrame.Angles(0, faceOut, 0))
							repin(model, parts, arm)
							local at = arm.CFrame:PointToObjectSpace(plate.Position)
							log("%s %s: ติดท่อนแขน%s ที่ (%.2f %.2f %.2f)", model.Name, group.Name,
								side < 0 and "ซ้าย" or "ขวา", at.X, at.Y, at.Z)
						end
					else
						------------------------------------------------ ของประดับ: ตรึงท่าเดิมไว้เฉยๆ
						repin(model, parts, limb)
					end
				end
			end
		end
	end
end

local root = workspace:FindFirstChild("WOLD") or workspace
root:SetAttribute("Progress", table.concat(lines, " | "))
root:SetAttribute("Status", "done")
print("[RepinGear] " .. #lines .. " พวง")
for _, l in ipairs(lines) do print("  " .. l) end
