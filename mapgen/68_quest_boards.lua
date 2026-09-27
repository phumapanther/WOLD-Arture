-- 68_quest_boards.lua — ปลูกบอร์ดเควสหกแห่ง แห่งละหนึ่งหมู่บ้าน
--
-- รัน: node tools/run-luau.js mapgen/68_quest_boards.lua
--
-- **รันซ้ำได้** บอร์ดที่มีอยู่แล้วจะถูกใช้ซ้ำ ไม่สร้างทับ
--
-- โมเดลสร้างด้วยโค้ดเพราะไม่มีโมเดลบอร์ดในชุด และมันเป็นแค่กระดานไม้กับเสาสองต้น — การปั้นด้วยโค้ด
-- ทำให้ทั้งหกอันเหมือนกันเป๊ะและปรับพร้อมกันได้ที่เดียว
local CollectionService = game:GetService("CollectionService")

local BOARD_TAG = "WOLD_QuestBoard"

-- ตรงกับ QuestConfig.Boards — วางที่โซนหมู่บ้านซึ่งอ่านพิกัดมาจากแมพจริง
local BOARDS = {
	{ id = "Goldmeadow", at = Vector3.new(-960, 154, 960) },
	{ id = "Stonemark", at = Vector3.new(-960, 394, -3360) },
	{ id = "Saltmere", at = Vector3.new(-3600, 146, 5260) },
	{ id = "Elderwood", at = Vector3.new(-4000, 169, 160) },
	{ id = "Cogsworth", at = Vector3.new(970, 162, -1120) },
	{ id = "Astravale", at = Vector3.new(3840, 1270, -3360) },
}

-- โมเดลต้นแบบที่ผู้ใช้วางไว้ในแมพ
--
-- **โคลนจากของจริง ไม่ปั้นเอง** รอบแรกผมสร้างกระดานไม้กับเสาสองต้นด้วยโค้ดเพราะยังไม่มีโมเดล ตอนนี้มี
-- `Guild_QuestBoard` ซึ่งเป็นบอร์ดจริง 243 ชิ้น มีโคมไฟ ใบประกาศ 56 ใบ และตราสมาคม — สวยกว่าที่เขียนได้
--
-- ต้นแบบยังคงอยู่ที่เดิมในแมพ ไม่ได้ถูกย้ายหรือลบ (sandbox ย้ายเข้า ServerStorage ไม่ได้อยู่แล้ว)
-- ตัวมันเองไม่ได้ติดแท็ก จึงไม่มีปุ่ม E และไม่นับเป็นบอร์ดใช้งาน
local PROTOTYPE_NAME = "Guild_QuestBoard"

-- บอร์ดรวมที่ผู้ใช้วางไว้เอง
local MAIN_BOARD_NAME = "MainGuild_QuestBoard"
local MAIN_BOARD_ID = "MainGuild"

-- **หาแบบเจาะลึก** ผู้ใช้ย้ายบอร์ดทั้งหมดเข้าโฟลเดอร์ `WOLD.QuestBoard` แล้ว (พบ 2026-09-27) — หาแค่ลูกตรงของ workspace
-- = ไม่เจอต้นแบบ แล้วเฟสจบก่อนติดแท็กอะไรเลย
local function prototype()
	local m = workspace:FindFirstChild(PROTOTYPE_NAME, true)
	if m and m:IsA("Model") then return m end
	-- ผู้ใช้เปลี่ยนชื่อต้นแบบเป็นบอร์ดรวมแล้ว ใช้ตัวนั้นเป็นต้นแบบต่อได้ รูปทรงเหมือนกัน
	m = workspace:FindFirstChild(MAIN_BOARD_NAME, true)
	if m and m:IsA("Model") then return m end
	return nil
end

-- บอร์ดรวมของสมาคม: รวมงานจากทุกเมืองมาไว้ที่เดียว
--
-- **ไม่ได้สร้างใหม่ ใช้โมเดลที่ผู้ใช้วางไว้เอง** แค่ติดแท็กกับ BoardId ให้ — ตำแหน่งเป็นของผู้ใช้
local function tagMainBoard()
	local m = workspace:FindFirstChild(MAIN_BOARD_NAME, true)
	if not m or not m:IsA("Model") then
		warn("[Quests] ไม่เจอ " .. MAIN_BOARD_NAME .. " — ข้ามบอร์ดรวม")
		return false
	end
	m:SetAttribute("BoardId", MAIN_BOARD_ID)
	if not CollectionService:HasTag(m, BOARD_TAG) then
		CollectionService:AddTag(m, BOARD_TAG)
	end
	local p = m:GetPivot().Position
	print(("[Quests] บอร์ดรวม %s ที่ (%.0f, %.0f, %.0f)"):format(MAIN_BOARD_NAME, p.X, p.Y, p.Z))
	return true
end

-- หาพื้นจริงตรงจุดนั้น ไม่ใช่ใช้ y ที่ให้มา
--
-- พิกัดของโซนคือ "ศูนย์กลางกล่องโซน" ซึ่งลอยอยู่กลางอากาศเหนือหมู่บ้าน ไม่ใช่ผิวดิน
local function groundAt(x, z, fromY)
	-- **ต้องกัน Zone_* ออก** กล่องโซนหมู่บ้านเป็นชิ้นล่องหนที่ลอยอยู่เหนือหมู่บ้านราวร้อยสตัด และมัน
	-- ตอบ raycast ด้วย — รอบแรกบอร์ดทั้งหกจึงไปตั้งอยู่บนหลังคาล่องหนแทนที่จะอยู่บนดิน
	--
	-- ยิงซ้ำโดยตัดสิ่งที่ชนออกทีละชั้น จนกว่าจะเจอของที่ไม่ใช่โซน — ทนกว่าการไล่ชื่อทุกโซนไว้ล่วงหน้า
	local ignore = { workspace:FindFirstChild("WOLD_Mobs") }
	for _ = 1, 8 do
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = ignore
		params.IgnoreWater = true
		local hit = workspace:Raycast(Vector3.new(x, fromY + 400, z), Vector3.new(0, -2000, 0), params)
		if not hit then return nil end
		local inst = hit.Instance
		if not inst.Name:match("^Zone_") then
			return hit.Position.Y, inst
		end
		ignore[#ignore + 1] = inst
	end
	return nil
end

-- จุดที่ตั้งบอร์ดได้จริง: พื้นเป็นภูมิประเทศ และไม่มีอะไรคร่อมอยู่ข้างบน
--
-- **จุดกึ่งกลางหมู่บ้านมีของตั้งอยู่แล้ว** รอบแรกบอร์ดทั้งสี่จากหกไปโผล่กลางหอคอย กองไฟ บ้านหิน และต้นไม้
-- ใหญ่ — พิกัดโซนคือใจกลางหมู่บ้าน ซึ่งเป็นที่ที่ของสำคัญตั้งอยู่พอดี
--
-- จึงวนหาจุดโล่งรอบๆ แทน ขยับออกทีละสิบสตัดจนเจอที่ว่าง
local function clearSpotNear(cx, cz, cy)
	for radius = 20, 140, 10 do
		for angle = 0, 330, 30 do
			local x = cx + math.cos(math.rad(angle)) * radius
			local z = cz + math.sin(math.rad(angle)) * radius
			local y, inst = groundAt(x, z, cy)
			-- ต้องยืนบนภูมิประเทศ ไม่ใช่บนหลังคาบ้าน
			if y and inst and inst:IsA("Terrain") then
				local params = RaycastParams.new()
				params.IgnoreWater = true
				-- สูงพอให้บอร์ด (6 สตัด) ตั้งได้โดยไม่ทะลุอะไร
				-- 14 ไม่ใช่ 8: บอร์ดสูง 6 แต่สะพานท่อที่สโตนมาร์กพาดอยู่สูงกว่านั้น การเช็คแค่ 8
				-- จึงผ่านแล้วบอร์ดไปโผล่ใต้สะพาน เผื่อให้เกินความสูงบอร์ดพอสมควร
				local above = workspace:Raycast(Vector3.new(x, y + 0.5, z), Vector3.new(0, 14, 0), params)
				if not above then
					return Vector3.new(x, y, z)
				end
			end
		end
	end
	return nil
end

local function existing(id)
	for _, m in ipairs(CollectionService:GetTagged(BOARD_TAG)) do
		if m:GetAttribute("BoardId") == id then return m end
	end
	return nil
end

-- **บอร์ดประจำเมืองที่ผู้ใช้วางเอง** (ผู้ใช้สั่ง 2026-09-27: `QuestBoard_FirstTown` ข้างจุดเกิด = บอร์ดบราสเฮเวน)
-- ไม่สร้าง ไม่ย้าย แค่ตั้ง BoardId + แท็ก · ⚠️ ตัวนี้ผู้ใช้คัดลอกมาจากบอร์ดแอสตราเวล จึงติด BoardId เดิมมาด้วย
-- (โชว์งานของแอสตราเวล) — ตั้งทับทุกครั้งที่รัน · ทำก่อนด่านต้นแบบ บอร์ดที่วางเองไม่ต้องใช้ต้นแบบ
local USER_BOARDS = {
	{ name = "QuestBoard_FirstTown", id = "Brasshaven" },
}
for _, u in ipairs(USER_BOARDS) do
	local m = workspace:FindFirstChild(u.name, true)
	if m and m:IsA("Model") then
		m:SetAttribute("BoardId", u.id)
		if not CollectionService:HasTag(m, BOARD_TAG) then CollectionService:AddTag(m, BOARD_TAG) end
		local p = m:GetPivot().Position
		print(("[Quests] บอร์ด %s = %s ที่ (%.0f, %.0f, %.0f)"):format(u.name, u.id, p.X, p.Y, p.Z))
	else
		warn("[Quests] ไม่เจอ " .. u.name .. " — ข้าม")
	end
end

local source = prototype()
if not source then
	warn("[Quests] ไม่เจอโมเดลต้นแบบ " .. PROTOTYPE_NAME .. " ใน workspace — ไม่ทำอะไรเลย")
	return
end

local made, skipped, failed = 0, 0, 0

for _, spec in ipairs(BOARDS) do
	if existing(spec.id) then
		print(("[Quests] มีบอร์ด %s อยู่แล้ว ข้าม"):format(spec.id))
		skipped += 1
	else
		local base = clearSpotNear(spec.at.X, spec.at.Z, spec.at.Y)
		if not base then
			warn(("[Quests] หาที่โล่งใกล้ %s ไม่เจอ — ข้าม"):format(spec.id))
			failed += 1
		else

			local model = source:Clone()
			model.Name = "QuestBoard_" .. spec.id

			-- วางให้ Root อยู่ที่ผิวดินพอดี
			--
			-- Root ของต้นแบบอยู่สูงจากก้นโมเดล 0.5 studs จึงยก 0.5 เพื่อให้ก้นบอร์ดแตะพื้นพอดี ไม่จม
			-- และไม่ลอย — วัดจากโมเดลจริง ไม่ได้เดา
			local srcRoot = model:FindFirstChild("Root")
			local lift = 0.5
			if srcRoot then
				local cf, sz = model:GetBoundingBox()
				lift = srcRoot.Position.Y - (cf.Position.Y - sz.Y * 0.5)
			end
			model:PivotTo(CFrame.new(base + Vector3.new(0, lift, 0)))
			model.PrimaryPart = srcRoot or model.PrimaryPart

			-- หันหน้าเข้าหาใจกลางหมู่บ้าน ไม่ใช่หันไปทางเดียวกันหมดทั้งหกอัน
			local toCentre = Vector3.new(spec.at.X - base.X, 0, spec.at.Z - base.Z)
			if toCentre.Magnitude > 1 then
				model:PivotTo(CFrame.new(base + Vector3.new(0, lift, 0), base + Vector3.new(0, lift, 0) + toCentre.Unit))
			end

			model.Parent = workspace
			model:SetAttribute("BoardId", spec.id)
			CollectionService:AddTag(model, BOARD_TAG)

			print(("[Quests] ปลูกบอร์ด %s ที่ (%.0f, %.0f, %.0f)")
				:format(spec.id, base.X, base.Y, base.Z))
			made += 1
		end
	end
end

tagMainBoard()

print(("[Quests] เสร็จ — สร้าง %d · มีอยู่แล้ว %d · ล้มเหลว %d"):format(made, skipped, failed))
