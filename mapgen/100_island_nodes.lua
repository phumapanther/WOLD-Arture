-- 100_island_nodes.lua: ต้นแบบจุดเก็บเกี่ยวที่จะสุ่มโผล่บนผืนดิน → ServerStorage.WOLD_IslandNodes
--
--     WOLD_PLACE=136992335889132 node tools/run-luau.js mapgen/100_island_nodes.lua --furniture --no-lib
--
-- ผู้ใช้สั่ง 2026-09-22: "ตรงพื้นที่เป็นดิน มีโอกาสสุ่มโมเดลจากเกมหลัก ของหิน แร่ และต้นไม้
-- ทุกชนิดที่เก็บเกี่ยวได้ มาเกิด เพื่อให้เก็บ โดยใช้อุปกรณ์แบบเดียวกับเกมหลัก"
--
-- **ต้นไม้ หิน พุ่ม ไม่ต้องคัดลอกมา** — มันคือชุด Creator Store ที่อยู่ใน `ServerStorage.WOLD_Assets`
-- ของเพลสเกาะอยู่แล้ว (ชุดเดียวกับที่แมพหลักใช้ ติดตั้งด้วย `mapgen/assets_setup.lua`)
-- **สายแร่ต้องคัดลอก** เพราะเป็นโมเดลที่ผู้ใช้วางมือไว้ในเพลสหลัก ไม่เคยมาถึงเกาะ
-- (`assets/models-from-main/ores.lua` · รันเฟสนี้ด้วย `--furniture` ซึ่งเป็นตัวฝังไฟล์นั้นเข้ามา)
--
-- โครงที่ได้: `WOLD_IslandNodes/<NodeKind>/<หลายแบบ>` — ตัวสุ่มหยิบแบบไหนก็ได้ในโฟลเดอร์นั้น
-- ทุกต้นแบบ: ฐานอยู่ที่ y = 0 · ทุกชิ้น Anchored · ไม่มี ProximityPrompt ติดมา (Gathering ใส่เอง)

local RS = game:GetService("ReplicatedStorage")
local SS = game:GetService("ServerStorage")

assert(game.PlaceId == 136992335889132 or game.PlaceId == 0, "เฟสนี้สำหรับเพลสเกาะเท่านั้น")

local function status(msg, done)
	local f = workspace:FindFirstChild("WOLD")
	if not f then f = Instance.new("Folder"); f.Name = "WOLD"; f.Parent = workspace end
	f:SetAttribute("Progress", msg)
	f:SetAttribute("Status", done and "done" or "running")
	print("[IslandNodes] " .. msg)
end

local root = SS:FindFirstChild("WOLD_IslandNodes")
if root then root:Destroy() end
root = Instance.new("Folder")
root.Name = "WOLD_IslandNodes"
root.Parent = SS

-- ชื่อโฟลเดอร์ = `NodeKind` ที่ `GatherConfig` รู้จัก ห้ามเปลี่ยน — มันคือสิ่งเดียวที่บอกว่ากด E แล้วได้อะไร
-- และต้องใช้เครื่องมืออะไร (`GatherConfig.Nodes[kind].tool`) ซึ่งคือ "อุปกรณ์แบบเดียวกับเกมหลัก" ที่สั่งมา
local FROM_ASSETS = {
	{ kind = "Tree", set = "oak", take = 9, width = 9 },
	{ kind = "Tree", set = "pine", take = 2, width = 9 },
	{ kind = "Rock", set = "rock", take = 8, width = 4.5 },
	{ kind = "Herb", set = "bush", take = 8, width = 4 },
}
local FROM_MAIN = {
	{ kind = "IronOre", ore = "Iron" },
	{ kind = "Coal", ore = "Coal" },
	{ kind = "SilverOre", ore = "Silver" },
	{ kind = "GoldOre", ore = "Gold" },
	{ kind = "MagicOre", ore = "Magic" },
	{ kind = "DiamondOre", ore = "Diamond" },
	{ kind = "Crystal", ore = "Crystal" },
}

local function folderFor(kind)
	local f = root:FindFirstChild(kind)
	if not f then f = Instance.new("Folder"); f.Name = kind; f.Parent = root end
	return f
end

-- ปิดท้ายทุกต้นแบบ: ตรึงทุกชิ้น ล้างปุ่ม/สคริปต์ และดันฐานลงมาที่ y = 0
local function finish(model)
	local lowest = math.huge
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Anchored = true
			lowest = math.min(lowest, d.Position.Y - d.Size.Y / 2)
		elseif d:IsA("ProximityPrompt") or d:IsA("LuaSourceContainer") then
			d:Destroy()
		end
	end
	if lowest == math.huge then return false end
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then d.CFrame = d.CFrame - Vector3.new(0, lowest, 0) end
	end
	return true
end

local made = {}

-- 1. ต้นไม้ / หิน / พุ่ม — ยืมจากชุดเดียวกับแมพหลัก
local assets = SS:FindFirstChild("WOLD_Assets")
for _, spec in ipairs(FROM_ASSETS) do
	local set = assets and assets:FindFirstChild(spec.set)
	if not set then
		status("⚠ ไม่มี WOLD_Assets." .. spec.set .. " — รัน mapgen/assets_setup.lua ก่อน")
	else
		local picks = set:GetChildren()
		table.sort(picks, function(a, b) return a.Name < b.Name end)
		local dest = folderFor(spec.kind)
		for i = 1, math.min(spec.take, #picks) do
			local m = picks[i]:Clone()
			-- ⚠️ **ต้องย้ายมาที่จุดกำเนิดก่อนวัด** ต้นแบบใน WOLD_Assets เก็บพิกัดโลกเดิมไว้
			-- ไม่ย้ายแล้วกล่องครอบจะกินตั้งแต่จุดกำเนิดไปถึงตรงนั้น (เคยได้ 1290x432 ช่อง)
			local cf, size = m:GetBoundingBox()
			pcall(function() m:PivotTo(m:GetPivot() * cf:Inverse() * CFrame.new(0, size.Y / 2, 0)) end)
			local _, raw = m:GetBoundingBox()
			local widest = math.max(raw.X, raw.Z)
			if widest > 0.1 then pcall(function() m:ScaleTo(spec.width / widest) end) end
			if finish(m) then
				m.Name = ("%s_%s_%d"):format(spec.kind, spec.set, i)
				m.Parent = dest
				made[spec.kind] = (made[spec.kind] or 0) + 1
			else
				m:Destroy()
			end
		end
	end
end

-- 2. สายแร่ — จากข้อมูลที่คัดลอกมาจากเพลสหลัก
local build = _G.WOLD_MAIN_MODELS and _G.WOLD_MAIN_MODELS.ores
if not build then
	status("⚠ ไม่มีข้อมูลสายแร่ — ต้องรันด้วย --furniture")
else
	for _, spec in ipairs(FROM_MAIN) do
		local m = build(spec.ore)
		if m and finish(m) then
			m.Name = spec.kind .. "_1"
			m.Parent = folderFor(spec.kind)
			made[spec.kind] = (made[spec.kind] or 0) + 1
		elseif m then
			m:Destroy()
		end
	end
end

local bits = {}
for kind, n in pairs(made) do bits[#bits + 1] = ("%s x%d"):format(kind, n) end
table.sort(bits)
status(("done: ต้นแบบจุดเก็บเกี่ยว %d ชนิด — %s"):format(#root:GetChildren(), table.concat(bits, " · ")), true)
