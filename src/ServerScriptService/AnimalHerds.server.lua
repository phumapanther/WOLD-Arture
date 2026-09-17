-- AnimalHerds.server.lua: ทำให้สัตว์ฟาร์มอยู่กันเป็นฝูง 5-12 ตัว
--
-- **ทำตอนเซิร์ฟเวอร์รัน ไม่ใช่เฟส mapgen** เพราะ sandbox ของ Studio MCP ย้ายสคริปต์ (BeastGait และ
-- Animate ที่อยู่ในตัวสัตว์) เข้าที่ไหนไม่ได้เลย การโคลนสัตว์จากเครื่องมือจึง error ทุกครั้ง
--
-- ผลพลอยได้ที่ดีกว่า: ฝูงถูกสร้างใหม่ทุกครั้งที่เซิร์ฟเวอร์เปิด ตำแหน่งจึงไม่เหมือนเดิมเป๊ะทุกรอบ
-- และไม่มีสัตว์โคลนค้างอยู่ในไฟล์เพลสให้บวมขึ้นเรื่อยๆ
local CollectionService = game:GetService("CollectionService")

local ServerConfig = require(game.ServerScriptService.ServerConfig)
if ServerConfig.IsLobby then return end

local NODE_TAG = "WOLD_Node"

-- ชนิด -> จำนวนในฝูง และรัศมีที่กระจาย
--
-- สัตว์เลี้ยงในคอกอยู่กันแน่นกว่าสัตว์ป่า — กวางกับม้าเดินไกลกว่าไก่
local HERDS = {
	Chicken = { min = 8, max = 12, spread = 26 },
	Duck = { min = 6, max = 10, spread = 24 },
	Pig = { min = 5, max = 9, spread = 30 },
	Sheep = { min = 7, max = 12, spread = 34 },
	Goat = { min = 5, max = 9, spread = 32 },
	Cow = { min = 5, max = 8, spread = 38 },
	Horse = { min = 5, max = 8, spread = 45 },
	Deer = { min = 5, max = 9, spread = 55 },
}

local FOLDER_NAME = "WOLD_Herds"

local function folder()
	local f = workspace:FindFirstChild(FOLDER_NAME)
	if not f then
		f = Instance.new("Folder")
		f.Name = FOLDER_NAME
		f.Parent = workspace
	end
	return f
end

-- พื้นจริงตรงจุดนั้น
--
-- **ต้องกัน Zone_* ออก** กล่องโซนหมู่บ้านลอยอยู่เหนือพื้นราวร้อยสตัดและตอบ raycast ด้วย — บทเรียน
-- เดียวกับตอนวางบอร์ดเควส ซึ่งรอบแรกไปตั้งอยู่บนหลังคาล่องหน
local function groundAt(x, z, fromY)
	local ignore = { workspace:FindFirstChild("WOLD_Mobs"), folder() }
	for _ = 1, 8 do
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = ignore
		params.IgnoreWater = true
		local hit = workspace:Raycast(Vector3.new(x, fromY + 200, z), Vector3.new(0, -800, 0), params)
		if not hit then return nil end
		if not hit.Instance.Name:match("^Zone_") then return hit.Position.Y end
		ignore[#ignore + 1] = hit.Instance
	end
	return nil
end

local function herdOf(kind)
	local found = {}
	for _, n in ipairs(CollectionService:GetTagged(NODE_TAG)) do
		if n:GetAttribute("NodeKind") == kind then found[#found + 1] = n end
	end
	return found
end

local function grow(kind, spec)
	local existing = herdOf(kind)
	if #existing == 0 then return 0 end

	local want = math.random(spec.min, spec.max)
	if #existing >= want then return 0 end

	-- ต้นแบบ = ตัวที่ผู้ใช้วางไว้เอง ซึ่งเป็นตัวเดียวที่ไม่ได้อยู่ในโฟลเดอร์ฝูง
	local source
	for _, a in ipairs(existing) do
		if not a:IsDescendantOf(folder()) then source = a break end
	end
	source = source or existing[1]

	local origin = source:GetPivot().Position
	local made = 0

	for _ = #existing + 1, want do
		local placed = false
		for _ = 1, 12 do
			local angle = math.random() * math.pi * 2
			-- sqrt กระจายทั่วพื้นที่ ไม่กระจุกตรงกลาง
			local dist = math.sqrt(math.random()) * spec.spread
			local x = origin.X + math.cos(angle) * dist
			local z = origin.Z + math.sin(angle) * dist
			local y = groundAt(x, z, origin.Y)

			-- ระดับใกล้เคียงต้นแบบเท่านั้น กันไม่ให้ไปโผล่ก้นหุบเขาหรือบนหลังคา
			if y and math.abs(y - origin.Y) < 25 then
				local clone = source:Clone()
				-- หันคนละทาง ฝูงจะได้ไม่ดูเหมือนแถวทหาร
				clone:PivotTo(CFrame.new(Vector3.new(x, y, z))
					* CFrame.Angles(0, math.random() * math.pi * 2, 0))
				clone:SetAttribute("Spent", nil)
				clone.Parent = folder()
				made += 1
				placed = true
				break
			end
		end
		if not placed then break end
	end
	return made
end

--------------------------------------------------------------------------------

-- รอให้สัตว์ต้นแบบมาถึงก่อน
--
-- **ลูปถามใหม่ ไม่ใช่ทำครั้งเดียวตอนบูต** กฎเหล็กของโปรเจ็ค: เพลสเปิด StreamingEnabled โมเดลกับแท็ก
-- มาถึงคนละรอบ ทำครั้งเดียวตอนเริ่มจะเจอสัตว์ไม่ครบ และเป็นคนละชนิดทุกครั้งที่เปิดเซิร์ฟ
task.spawn(function()
	local done = {}
	for _ = 1, 60 do
		task.wait(0.5)
		local remaining = 0
		for kind, spec in pairs(HERDS) do
			if not done[kind] then
				if #herdOf(kind) > 0 then
					local made = grow(kind, spec)
					done[kind] = true
					if made > 0 then
						print(("[Herds] %s +%d ตัว"):format(kind, made))
					end
				else
					remaining += 1
				end
			end
		end
		if remaining == 0 then return end
	end
end)
