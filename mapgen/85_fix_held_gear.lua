-- 85_fix_held_gear.lua: จัดท่าถืออาวุธและโล่ของมอนทุกตัวให้เป็นมาตรฐานเดียวกัน
--
-- ผู้ใช้แจ้ง 2026-09-20 (รอบสอง): "การถือดาบกับโล่ ของทั้งมอนและบอส ยังกลับด้านกันอยู่ ปลายดาบหันไป
-- ด้านหลัง และโล่ติดกับแขนด้านหน้า อยากให้ไปอยู่กับแขนด้านข้างแทน"
--
-- เฟสนี้ต่างจาก `84_fix_mob_weapons.lua` ตรงที่อันนั้นแก้เคสเดียว (พวงที่ยื่นไปข้างหลังทั้งดุ้น ต้องหมุน 90°)
-- ส่วนอันนี้ **ตั้งมุมให้ตรงเป้าเสมอ ไม่ว่าตอนนี้มันเอียงเท่าไหร่** จึงรันซ้ำได้ไม่มีวันเพี้ยนสะสม
-- และครอบคลุมบอสซึ่งเอียงไปข้างหลัง 12° (วัดแล้ว) ซึ่งน้อยเกินกว่าที่เฟส 84 จะจับได้
--
-- เป้าหมายสองอย่าง:
--   1. **ดาบ** — ปลายชี้ขึ้นตามแขนแล้วเอนไปข้างหน้า 17° (ท่าถือดาบพร้อมรบ ไม่ใช่ดาบพิงบ่า)
--   2. **โล่** — ย้ายจากหน้าแขนไปอยู่ **ข้างแขนด้านนอก** หน้าโล่หันออกจากตัว
local FOLDER = game.ServerStorage:FindFirstChild("Model_moster")

local LEAN_DEGREES = 17 -- ปลายอาวุธเอนไปข้างหน้าเท่านี้ (0 = ตั้งตรง · ลบ = เอนหลัง)

local RIG_PARTS = {
	HumanoidRootPart = true, LowerTorso = true, UpperTorso = true, Head = true,
	LeftUpperArm = true, LeftLowerArm = true, LeftHand = true,
	RightUpperArm = true, RightLowerArm = true, RightHand = true,
	LeftUpperLeg = true, LeftLowerLeg = true, LeftFoot = true,
	RightUpperLeg = true, RightLowerLeg = true, RightFoot = true,
}

-- ทุกชิ้นที่ห้อยอยู่กับมือข้างนี้ รวมชิ้นที่เชื่อมต่อกันเองเป็นพวง (ด้าม -> ใบ -> ปลาย)
local function heldParts(model, hand)
	local seen, found = {}, {}
	local function add(p)
		if p and not RIG_PARTS[p.Name] and not seen[p] then
			seen[p] = true
			found[#found + 1] = p
		end
	end
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("WeldConstraint") or d:IsA("Weld") then
			if d.Part0 == hand then add(d.Part1) elseif d.Part1 == hand then add(d.Part0) end
		end
	end
	local grew = true
	while grew do
		grew = false
		for _, d in ipairs(model:GetDescendants()) do
			if d:IsA("WeldConstraint") or d:IsA("Weld") then
				local a, b = d.Part0, d.Part1
				if a and b and not RIG_PARTS[a.Name] and not RIG_PARTS[b.Name] then
					if seen[a] and not seen[b] then add(b) grew = true end
					if seen[b] and not seen[a] then add(a) grew = true end
				end
			end
		end
	end
	return found
end

-- หมุนทั้งพวงรอบจุดกำเนิดของมือ
local function turn(parts, hand, rotation)
	for _, p in ipairs(parts) do
		p.CFrame = hand.CFrame * rotation * hand.CFrame:ToObjectSpace(p.CFrame)
	end
end

local lines = {}

for _, model in ipairs(FOLDER and FOLDER:GetChildren() or {}) do
	local rhand = model:FindFirstChild("RightHand", true)
	local lhand = model:FindFirstChild("LeftHand", true)

	------------------------------------------------------------------ อาวุธในมือขวา
	if rhand and rhand:IsA("BasePart") then
		local parts = heldParts(model, rhand)
		if #parts > 0 then
			-- ปลายอาวุธ = ชิ้นที่อยู่ไกลจากมือที่สุดในพวงนั้น
			local tip, tipD
			for _, p in ipairs(parts) do
				local d = (p.Position - rhand.Position).Magnitude
				if not tipD or d > tipD then tip, tipD = p, d end
			end

			if tip and tipD > 1 then
				local dir = rhand.CFrame:VectorToObjectSpace((tip.Position - rhand.Position).Unit)
				-- มุมเอนในระนาบหน้า-หลังของมือ: บวก = เอนไปข้างหน้า (-Z คือด้านหน้า)
				local lean = math.atan2(-dir.Z, dir.Y)
				local want = math.rad(LEAN_DEGREES)
				-- หมุนรอบแกน X ของมือ เท่ากับส่วนต่างของมุม (พิสูจน์: หมุน a แล้วมุมเอนลดลง a)
				local delta = lean - want
				if math.abs(delta) > math.rad(2) then
					turn(parts, rhand, CFrame.Angles(delta, 0, 0))
					local after = rhand.CFrame:VectorToObjectSpace((tip.Position - rhand.Position).Unit)
					table.insert(lines, ("%s ดาบ: เอน %.0f° -> %.0f° (ปลายชี้ %.2f %.2f %.2f)")
						:format(model.Name, math.deg(lean), math.deg(math.atan2(-after.Z, after.Y)),
							after.X, after.Y, after.Z))
				end
			end
		end
	end

	------------------------------------------------------------------ โล่ในมือซ้าย
	if lhand and lhand:IsA("BasePart") then
		local parts = heldParts(model, lhand)
		-- แผ่นที่กว้างและบาง = โล่ · ไม่ได้ดูจากชื่อ เพราะโมเดลรุ่นหลังอาจตั้งชื่ออย่างอื่น
		local plate
		for _, p in ipairs(parts) do
			local s = p.Size
			local thin = math.min(s.X, s.Y, s.Z)
			local wide = math.max(s.X, s.Y, s.Z)
			if wide >= 1.5 and thin <= wide * 0.25 and (not plate or wide > math.max(plate.Size.X, plate.Size.Y, plate.Size.Z)) then
				plate = p
			end
		end

		if plate then
			-- หน้าโล่คือแกนที่บางที่สุดของแผ่น
			local s = plate.Size
			local axis = Vector3.new(0, 0, 1)
			if s.X <= s.Y and s.X <= s.Z then axis = Vector3.new(1, 0, 0)
			elseif s.Y <= s.X and s.Y <= s.Z then axis = Vector3.new(0, 1, 0) end
			local normal = lhand.CFrame:VectorToObjectSpace(plate.CFrame:VectorToWorldSpace(axis))

			-- ยังหันหน้าไปทางหน้า-หลังอยู่ = ยังติดอยู่หน้าแขน ต้องหมุนไปอยู่ข้างแขน
			--
			-- หมุน +90° รอบแกน Y ของมือ: จุดที่อยู่ข้างหน้า (-Z) ไปอยู่ด้านนอกซ้าย (-X) และหน้าโล่
			-- ที่เคยหันไปข้างหน้าก็หันออกข้างตาม — ทั้งใบจึงไปแปะข้างแขนโดยไม่ต้องขยับมือเลย
			if math.abs(normal.Z) > math.abs(normal.X) then
				turn(parts, lhand, CFrame.Angles(0, math.rad(90), 0))
				local after = lhand.CFrame:PointToObjectSpace(plate.Position)
				table.insert(lines, ("%s โล่: ย้ายไปข้างแขน (อยู่ที่ %.2f %.2f %.2f)")
					:format(model.Name, after.X, after.Y, after.Z))
			end
		end
	end
end

local root = workspace:FindFirstChild("WOLD") or workspace
root:SetAttribute("Progress", #lines > 0 and table.concat(lines, " | ") or "ทุกตัวอยู่ในท่าที่ถูกแล้ว")
root:SetAttribute("Status", "done")
print("[FixHeldGear] " .. root:GetAttribute("Progress"))
