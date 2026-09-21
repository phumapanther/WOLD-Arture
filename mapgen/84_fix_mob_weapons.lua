-- 84_fix_mob_weapons.lua: หมุนอาวุธที่มอนถืออยู่ให้ชี้ถูกทาง
--
-- ผู้ใช้แจ้ง 2026-09-20: "อาวุธที่ถือหันไปด้านหลัง การถืออาวุธไม่ตรงไม่ถูก"
--
-- วัดในเพลสแล้ว: ดาบของโครงกระดูกวางอยู่ **หลังมือ 2.45 สตัด** และใบชี้ไปทาง +Z ของมือ ซึ่งคือด้านหลังตัว
-- (กติกาของเกม: -Z คือด้านหน้า) ท่าที่ถูกคือใบชี้ขึ้นตามแขน แล้วเอียงไปข้างหน้านิดหน่อย
--
-- **แก้ที่ต้นแบบ ไม่ใช่ตอนเกิด** — มันเป็นความผิดของท่าในโมเดล ไม่ใช่ของระบบ ถ้าไปหมุนตอนเกิดทุกครั้ง
-- โค้ดระบบจะต้องแบกกฎเฉพาะของโมเดลบางตัวไปตลอด (และโมเดลที่ทำมาถูกอยู่แล้วจะโดนหมุนผิดไปด้วย)
--
-- **รันซ้ำได้** มันหมุนเฉพาะกลุ่มที่ยัง "ยื่นไปข้างหลัง" อยู่ ถ้าหมุนแล้วกลุ่มจะไปอยู่เหนือมือ เงื่อนไขก็ไม่เข้าอีก
local FOLDER = game.ServerStorage:FindFirstChild("Model_moster")

-- หมุนรอบแกน X ของมือ: +Z (หลัง) -> +Y (ขึ้นตามแขน)
local FIX = CFrame.Angles(math.rad(-90), 0, 0)

-- ชิ้นของโครงกระดูก R15 เอง — ห้ามหมุนตาม มันคือแขนขา ไม่ใช่ของที่ถืออยู่
local RIG_PARTS = {
	HumanoidRootPart = true, LowerTorso = true, UpperTorso = true, Head = true,
	LeftUpperArm = true, LeftLowerArm = true, LeftHand = true,
	RightUpperArm = true, RightLowerArm = true, RightHand = true,
	LeftUpperLeg = true, LeftLowerLeg = true, LeftFoot = true,
	RightUpperLeg = true, RightLowerLeg = true, RightFoot = true,
}

local function heldParts(model, hand)
	local found, seen = {}, {}
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("WeldConstraint") or d:IsA("Weld") then
			local other = (d.Part0 == hand) and d.Part1 or ((d.Part1 == hand) and d.Part0 or nil)
			if other and not RIG_PARTS[other.Name] and not seen[other] then
				seen[other] = true
				found[#found + 1] = other
			end
		end
	end
	-- ของที่เชื่อมกันเองต่อจากชิ้นที่เกาะมือ (ด้ามต่อใบ ใบต่อปลาย) ต้องไปด้วยกันทั้งพวง
	local grew = true
	while grew do
		grew = false
		for _, d in ipairs(model:GetDescendants()) do
			if d:IsA("WeldConstraint") or d:IsA("Weld") then
				local a, b = d.Part0, d.Part1
				if a and b and not RIG_PARTS[a.Name] and not RIG_PARTS[b.Name] then
					if seen[a] and not seen[b] then seen[b] = true; found[#found + 1] = b; grew = true end
					if seen[b] and not seen[a] then seen[a] = true; found[#found + 1] = a; grew = true end
				end
			end
		end
	end
	return found
end

local fixed, checked = {}, 0

for _, model in ipairs(FOLDER and FOLDER:GetChildren() or {}) do
	local hand = model:FindFirstChild("RightHand", true)
	if hand and hand:IsA("BasePart") then
		local parts = heldParts(model, hand)
		if #parts > 0 then
			checked += 1
			-- จุดกึ่งกลางของพวงในเฟรมของมือ — ตัวตัดสินว่า "ของชิ้นนี้ยื่นไปทางไหน"
			local sum = Vector3.zero
			for _, p in ipairs(parts) do
				sum += hand.CFrame:PointToObjectSpace(p.Position)
			end
			local centre = sum / #parts

			-- ยื่นไปข้างหลังมากกว่าที่ยื่นขึ้น = ท่าผิด
			if centre.Z > 0.3 and centre.Z > math.abs(centre.Y) then
				for _, p in ipairs(parts) do
					p.CFrame = hand.CFrame * FIX * hand.CFrame:ToObjectSpace(p.CFrame)
				end
				local after = hand.CFrame:PointToObjectSpace(parts[1].Position)
				table.insert(fixed, ("%s (%d ชิ้น: z %.2f -> y %.2f)"):format(model.Name, #parts, centre.Z, after.Y))
			end
		end
	end
end

local root = workspace:FindFirstChild("WOLD") or workspace
root:SetAttribute("Progress", ("ตรวจ %d ตัวที่ถืออาวุธ · หมุนแก้ %d: %s"):format(
	checked, #fixed, #fixed > 0 and table.concat(fixed, " | ") or "ไม่มีตัวไหนผิด"))
root:SetAttribute("Status", "done")
print("[FixMobWeapons] " .. root:GetAttribute("Progress"))
