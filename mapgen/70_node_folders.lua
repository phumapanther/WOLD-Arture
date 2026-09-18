-- 70_node_folders.lua: รวมจุดเก็บของสามชนิดหลักไว้คนละโฟลเดอร์ ตามที่ผู้ใช้กำหนด
--
--   WOLD.Gather.Trees   ← ต้นไม้ที่ตัดได้ (NodeKind = Tree)
--   WOLD.Gather.Rocks   ← หินที่ขุดได้ (NodeKind = Rock)
--   WOLD.Gather.Bushes  ← พุ่มสมุนไพร (NodeKind = Herb)
--
-- แร่ แปลงไร่ พุ่มเวท สัตว์ อยู่ที่เดิม — ผู้ใช้วางเองเป็นจุดๆ และเฟส 64/67 หามันจากชื่อในที่ที่มันอยู่
--
-- **ย้ายแค่ parent** ตำแหน่งในโลก แท็ก แอตทริบิวต์ ไม่แตะ ระบบเก็บของทำงานจากแท็กล้วนๆ จึงไม่รู้สึกอะไร
-- ก่อนย้าย: ต้นไม้ 15,444 หิน 4,600 พุ่ม 4,526 กระจายอยู่ใน 10 โฟลเดอร์ (Elderwood.Nodes/Decor,
-- FirstTown.Graden, Heartland.Nodes/Decor …)
--
-- ⚠️ เฟสธรรมชาติเดิม (60_elderwood, 65_heartland, 50_first_town) ลบโฟลเดอร์ของตัวเองแล้วสร้างใหม่ตอนรัน
-- ของที่ย้ายออกมาแล้วจะไม่ถูกลบ = ถ้ารันเฟสพวกนั้นซ้ำจะได้ต้นไม้ซ้อนสองชุด ต้องลบ WOLD.Gather ก่อน
--
-- รันซ้ำได้: ของที่อยู่ในโฟลเดอร์ถูกแล้วถูกข้าม
if game.PlaceId ~= 88774255487951 then error("REFUSED: wrong place") end
local CollectionService = game:GetService("CollectionService")

local FOLDER_FOR = { Tree = "Trees", Rock = "Rocks", Herb = "Bushes" }

local root = workspace:WaitForChild("WOLD")
local gather = root:FindFirstChild("Gather")
if not gather then
	gather = Instance.new("Folder")
	gather.Name = "Gather"
	gather.Parent = root
end
local folders = {}
for _, name in pairs(FOLDER_FOR) do
	local f = gather:FindFirstChild(name)
	if not f then
		f = Instance.new("Folder")
		f.Name = name
		f.Parent = gather
	end
	folders[name] = f
end

local moved, skipped = { Tree = 0, Rock = 0, Herb = 0 }, 0
local n = 0
for _, node in ipairs(CollectionService:GetTagged("WOLD_Node")) do
	local kind = node:GetAttribute("NodeKind")
	local target = FOLDER_FOR[kind]
	if target and node:IsA("Model") then
		if node.Parent == folders[target] then
			skipped += 1
		else
			node.Parent = folders[target]
			moved[kind] += 1
		end
		-- ย้ายเป็นหมื่นชิ้น พักให้ Studio หายใจบ้าง
		n += 1
		if n % 800 == 0 then task.wait() end
	end
end

print(("[NodeFolders] moved trees=%d rocks=%d bushes=%d (already there=%d) -> WOLD.Gather.{Trees,Rocks,Bushes}")
	:format(moved.Tree, moved.Rock, moved.Herb, skipped))
