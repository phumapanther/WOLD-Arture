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

local WOOD = Color3.fromRGB(104, 72, 44)
local DARK = Color3.fromRGB(72, 50, 32)
local PAPER = Color3.fromRGB(226, 214, 186)

local function part(parent, name, size, cf, colour, material)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = colour
	p.Material = material or Enum.Material.Wood
	p.Anchored = true
	p.CanCollide = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
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

			local model = Instance.new("Model")
			model.Name = "QuestBoard_" .. spec.id

			-- เสาสองต้น
			for _, side in ipairs({ -1.6, 1.6 }) do
				part(model, "Post", Vector3.new(0.4, 5, 0.4),
					CFrame.new(base + Vector3.new(side, 2.5, 0)), DARK)
			end

			-- กระดาน
			local board = part(model, "Board", Vector3.new(4.2, 3, 0.3),
				CFrame.new(base + Vector3.new(0, 4.2, 0)), WOOD)
			model.PrimaryPart = board

			-- หลังคากันฝน เอียงนิดหน่อย
			part(model, "Roof", Vector3.new(4.8, 0.25, 1.2),
				CFrame.new(base + Vector3.new(0, 5.9, -0.3)) * CFrame.Angles(math.rad(-14), 0, 0), DARK)

			-- กระดาษสามใบติดอยู่ ตรงกับสามช่องงานบนบอร์ด
			for i = -1, 1 do
				part(model, "Notice", Vector3.new(1.1, 1.5, 0.06),
					CFrame.new(base + Vector3.new(i * 1.3, 4.3, 0.19))
						* CFrame.Angles(0, 0, math.rad(math.random(-4, 4))),
					PAPER, Enum.Material.SmoothPlastic)
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

print(("[Quests] เสร็จ — สร้าง %d · มีอยู่แล้ว %d · ล้มเหลว %d"):format(made, skipped, failed))
