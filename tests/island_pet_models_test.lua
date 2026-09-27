-- WOLD_PLACE=136992335889132 node tools/lua.js tests/island_pet_models_test.lua Edit   (เพลสเกาะ — ต้นแบบอยู่ที่นั่น)
-- เฟส 2d: ต้นแบบสัตว์เลี้ยงทุกตัว (mapgen/103_island_pets.lua) พร้อมให้ IslandPets ขับ
-- ตรวจของที่ Edit ตรวจได้: โครง rig · ไม่มีสคริปต์/แท็ก/ป้ายชื่อ · ข้อต่อ R15 · ขนาดเต็มวัย · ย่อ 30% แล้วเท้ายังอยู่บนพื้น
local RS = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local out, fails = {}, 0
local function check(ok, text)
	out[#out + 1] = (ok and "ok   " or "FAIL ") .. text
	if not ok then fails += 1 end
end

local temp = Instance.new("Folder")
temp.Name = "PetModelTest_" .. math.random(1, 1e9)
temp.Parent = RS
local cfg = RS.IslandConfig:Clone()
cfg.Parent = temp
for _, name in ipairs({ "CraftConfig", "ShopConfig", "MailConfig", "PremiumConfig", "ItemCatalog", "GatherConfig" }) do
	RS[name]:Clone().Parent = temp
end

local stage = Instance.new("Folder")
stage.Name = "PetModelStage"
stage.Parent = workspace

local ok, err = pcall(function()
	local IslandConfig = require(temp.IslandConfig)
	local folder = RS:FindFirstChild("WOLD_Placeables")
	check(folder ~= nil, "มีโฟลเดอร์ WOLD_Placeables")

	local function bottomOf(m)
		local lo = math.huge
		for _, p in ipairs(m:GetDescendants()) do
			if p:IsA("BasePart") and p.Name ~= "Root" then
				local cf, h = p.CFrame, p.Size / 2
				for _, sx in ipairs({ -1, 1 }) do
					for _, sy in ipairs({ -1, 1 }) do
						for _, sz in ipairs({ -1, 1 }) do
							lo = math.min(lo, (cf * Vector3.new(sx * h.X, sy * h.Y, sz * h.Z)).Y)
						end
					end
				end
			end
		end
		return lo
	end

	local problems, checked = {}, 0
	for id, spec in pairs(IslandConfig.PetSpecies) do
		local proto = folder and folder:FindFirstChild(id)
		if not proto then
			problems[#problems + 1] = id .. ":ไม่มีต้นแบบ"
		else
			checked += 1
			local function bad(why) problems[#problems + 1] = id .. ":" .. why end
			if not proto:GetAttribute("Pet") then bad("ไม่มีแอตทริบิวต์ Pet") end
			if typeof(proto:GetAttribute("FullSize")) ~= "Vector3" or not proto:GetAttribute("FullScale") then bad("ไม่มี FullSize/FullScale") end
			if typeof(proto:GetAttribute("Footprint")) ~= "Vector2" then bad("ไม่มี Footprint") end
			if id ~= "Pet_Dog" and id ~= "Pet_Cat" and not proto:GetAttribute("Manual") then bad("ไม่ติด Manual (เฟส 90 จะลบทิ้ง)") end
			local root = proto:FindFirstChild("Root")
			if not root or proto.PrimaryPart ~= root then bad("PrimaryPart ต้องเป็น Root") end
			local hum = proto:FindFirstChildOfClass("Humanoid")
			local hrp = proto:FindFirstChild("HumanoidRootPart")
			if not hum or not hrp then bad("ไม่มี Humanoid/HumanoidRootPart") end
			for _, d in ipairs(proto:GetDescendants()) do
				if d:IsA("Script") or d:IsA("LocalScript") then bad("มีสคริปต์ " .. d.Name) break end
				if d:IsA("ProximityPrompt") then bad("มีปุ่มติดมา") break end
				if d:IsA("BillboardGui") then bad("มีป้ายลอยติดมา") break end
				if CollectionService:HasTag(d, "WOLD_Mob") then bad("ติดแท็ก WOLD_Mob") break end
			end
			if CollectionService:HasTag(proto, "WOLD_Mob") then bad("ติดแท็ก WOLD_Mob") end
			if spec.motion == "humanoid" then
				local motors = 0
				for _, d in ipairs(proto:GetDescendants()) do
					if d:IsA("Motor6D") then motors += 1 end
					if d:IsA("AnimationConstraint") then bad("ยังมี AnimationConstraint") break end
				end
				if motors < 15 then bad("ข้อต่อ R15 ไม่ครบ " .. motors) end
				if hum and not hum:FindFirstChildOfClass("Animator") then bad("ไม่มี Animator") end
			elseif spec.motion == "beast" then
				local phased = 0
				for _, d in ipairs(proto:GetDescendants()) do
					if d:IsA("Motor6D") and d:GetAttribute("Phase") then phased += 1 end
				end
				if phased == 0 then bad("ไม่มีข้อต่อที่ BeastGait ขับได้") end
			elseif spec.motion == "slime" then
				if hrp and not hrp.CanCollide then bad("ลูกบอลแกนต้องชนพื้น") end
				for _, d in ipairs(proto:GetDescendants()) do
					if d:IsA("BasePart") and d ~= hrp and d.Name ~= "Root" and d.CanCollide then bad("ชิ้นประกอบ " .. d.Name .. " ชนได้") break end
				end
			end
			-- ขนาดเต็มวัย: สูงไม่เกินคนมาก ด้านยาวไม่เกิน 8.5
			local fs = proto:GetAttribute("FullSize")
			if typeof(fs) == "Vector3" and (fs.Y > 6 or math.max(fs.X, fs.Z) > 8.5) then
				bad(("ใหญ่เกิน %.1f x %.1f x %.1f"):format(fs.X, fs.Y, fs.Z))
			end
			-- ย่อเหลือ 30% รอบ Root (ทางเดียวกับ IslandPets.setup ตอนเพิ่งวาง) แล้วเท้าต้องอยู่บนพื้นเดิม
			local clone = proto:Clone()
			clone.Parent = stage
			clone:PivotTo(CFrame.new(0, 500, 0))
			local groundBefore = bottomOf(clone)
			local full = clone:GetAttribute("FullScale") or clone:GetScale()
			local rootSize = clone.PrimaryPart.Size
			clone:ScaleTo(full * IslandConfig.PetStartScale)
			clone.PrimaryPart.Size = rootSize
			local groundAfter = bottomOf(clone)
			if math.abs(groundAfter - groundBefore) > 0.3 then
				bad(("ย่อแล้วเท้าลอย/จม %.2f"):format(groundAfter - groundBefore))
			end
			if math.abs(groundBefore - 500) > 0.6 then bad(("ฐานต้นแบบไม่อยู่ที่ Root %.2f"):format(groundBefore - 500)) end
			clone:Destroy()
		end
	end
	check(#problems == 0 and checked == 24, ("ต้นแบบสัตว์เลี้ยง %d/24 ตัวพร้อมใช้ %s"):format(checked, table.concat(problems, " | ")))
end)
check(ok, "ไม่มี error " .. tostring(err))
stage:Destroy()
temp:Destroy()
return ("%s — %d fail\n%s"):format(fails == 0 and "PASS" or "FAIL", fails, table.concat(out, "\n"))
