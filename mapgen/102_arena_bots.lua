-- 102_arena_bots.lua: ร่างบอทของสนาม PVP = NPC คนจากโรงงาน WOLD-Models (ผู้ใช้สั่ง 2026-09-24:
-- "โมเดลบอทให้ดูเป็นคนมากกว่านี้ · เอาโมเดล NPC มาสุ่มใช้แต่ละรอบ")
--
--     WOLD_PLACE=134798670267276 node tools/run-luau.js mapgen/102_arena_bots.lua --no-lib --kit --models
--
-- ปั้น NPC 9 ตัวจาก `models/npcs.lua` (R15 จริง มีผม หมวก แว่น เป้ ฯลฯ) แล้ว **ถอดของที่ไม่ใช่ตัวคน** ออก:
-- แท่นยืน ลัง (ชิ้นที่ไม่ได้เชื่อมกับแขนขา) · ป้ายชื่อ NPC · ปุ่ม E · สคริปต์เดินเล่น
-- เก็บไว้ที่ `ServerStorage.WOLD_ArenaBots` ซึ่ง `ArenaBots.prototype()` สุ่มหยิบทุกครั้งที่บอทเกิด = ทุกรอบ
--
-- รันซ้ำได้: ล้างเฉพาะตัวที่เฟสนี้สร้าง (แอตทริบิวต์ PhaseBuilt) ตัวที่ผู้ใช้วางเองในโฟลเดอร์รอด
local PHASE = "arena_bots"
local HUMANS = { "Merchant_Barnaby", "Merchant_Zael", "Merchant_Grick", "Baron_Vane", "Madam_Aurelia",
	"Don_Tiberius", "Blacksmith_Brannoc", "Mechanic_Lyra", "Gunsmith_Jax" }

local function status(text, done)
	local f = workspace:FindFirstChild("WOLD")
	if not f then
		f = Instance.new("Folder")
		f.Name = "WOLD"
		f.Parent = workspace
	end
	f:SetAttribute("Progress", text)
	f:SetAttribute("Status", done and "done" or "running")
	print("[arena-bots] " .. text)
end

local SS = game:GetService("ServerStorage")
local folder = SS:FindFirstChild("WOLD_ArenaBots")
if not folder then
	folder = Instance.new("Folder")
	folder.Name = "WOLD_ArenaBots"
	folder.Parent = SS
end
for _, child in ipairs(folder:GetChildren()) do
	if child:GetAttribute("PhaseBuilt") == PHASE then child:Destroy() end
end

local LIMB = {}
for _, name in ipairs(R.LIMBS) do LIMB[name] = true end

-- ชิ้นที่ถูกเชื่อมกับแขนขา (ตรงๆ หรือผ่านชิ้นอื่นในพวงเดียวกัน) = ของที่สวมอยู่ เก็บไว้
local function weldedToBody(part)
	for _, w in ipairs(part:GetDescendants()) do
		if w:IsA("WeldConstraint") or w:IsA("Weld") then
			local other = w.Part0 == part and w.Part1 or w.Part0
			if other and (LIMB[other.Name] or other.Parent ~= part.Parent) then return true end
		end
	end
	return false
end

local made = 0
for _, name in ipairs(HUMANS) do
	local m = K.place(name, workspace, CFrame.new(0, 2000, 0))
	if m then
		for _, d in ipairs(m:GetDescendants()) do
			if d:IsA("LuaSourceContainer") or d:IsA("BillboardGui") or d:IsA("ProximityPrompt") then d:Destroy() end
		end
		local root = m:FindFirstChild("Root")
		if root then root:Destroy() end
		for _, d in ipairs(m:GetDescendants()) do
			if d:IsA("BasePart") and d.Parent and not LIMB[d.Name] and not weldedToBody(d) then d:Destroy() end
		end
		for _, d in ipairs(m:GetDescendants()) do
			if d:IsA("BasePart") then
				d.Anchored = false
				if not LIMB[d.Name] then d.CanCollide = false; d.Massless = true end
			end
		end
		m.PrimaryPart = m:FindFirstChild("HumanoidRootPart")
		local hum = m:FindFirstChildOfClass("Humanoid")
		if hum and m.PrimaryPart then
			m.Name = "Bot_" .. name
			m:SetAttribute("PhaseBuilt", PHASE)
			m.Parent = folder
			made += 1
		else
			warn("[arena-bots] " .. name .. " ไม่มี Humanoid/HumanoidRootPart — ข้าม")
			m:Destroy()
		end
	end
end
status(("เสร็จ: ร่างบอท %d ตัวใน ServerStorage.WOLD_ArenaBots"):format(made), true)
