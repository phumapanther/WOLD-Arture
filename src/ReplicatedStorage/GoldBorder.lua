-- GoldBorder (เฟส 2b ผู้ใช้กำหนด 2026-09-26/27): ของขอบทองบนเกาะ — ของชิ้นไหนมีได้ และการเก็บครั้งนี้ได้หรือเปล่า
--
-- ข้อมูลล้วน: ไม่แตะกระเป๋า ไม่รู้จักผู้เล่น · การแจกอยู่ที่ `Inventory.AddHarvest` · ตัวตัดสินว่า "ช่องนี้เป็นของ
-- ขอบทองไหม" อยู่ที่ `ItemCatalog.IsGoldBorder` (ทุกระบบมี ItemCatalog อยู่แล้ว ไม่ต้อง require ไฟล์นี้เพิ่ม)
-- require พี่น้องด้วย script.Parent (ทรงเดียวกับ ItemCatalog) เทสจึงโคลนทั้งชุดแล้วได้ของสดทุกตัว
local IslandConfig = require(script.Parent.IslandConfig)
local GatherConfig = require(script.Parent.GatherConfig)
local ItemCatalog = require(script.Parent.ItemCatalog)

local GoldBorder = {}

-- ผลผลิตสัตว์คอก + แร่ทุกชนิดยกเว้นถ่านหิน/หิน — อ่านจากคอนฟิก สัตว์/แร่ชนิดใหม่ได้กฎนี้เอง
-- ไม้ ปลา เมล็ด หนอน สมุนไพรจากพุ่มป่า ไม่อยู่ในนี้ (ไม่มีขอบทอง)
GoldBorder.GatherItems = {}
for _, a in ipairs(IslandConfig.PenAnimals) do
	local node = GatherConfig.Nodes[a.kind]
	if node and node.item then GoldBorder.GatherItems[node.item] = true end
end
for _, ore in ipairs(GatherConfig.Ores) do
	GoldBorder.GatherItems[ore] = true
end

-- ผลผลิตหลักของแปลงผักทุกชนิด รวมกิ่งเวทมนตร์ · **สมุนไพรจากแปลงได้ จากพุ่มป่าไม่ได้** (ผู้ใช้เลือก 2026-09-27)
-- ของแถมของแปลง (แร่เวทจากต้นเวท เมล็ด หนอน) ไม่มีขอบทอง
GoldBorder.CropItems = {}
for _, c in ipairs(IslandConfig.Crops) do
	GoldBorder.CropItems[c.item] = true
end

GoldBorder.Is = ItemCatalog.IsGoldBorder

function GoldBorder.NewMeta()
	return { gold = true }
end

-- โหนดนี้ (สัตว์คอก/สายแร่บนเกาะ) ให้ของที่มีขอบทองได้ไหม — ใช้ตัดสินว่าแสงแดงขึ้นได้ไหม
-- ตัดสินจากของหลักของโหนด: สายแร่เหล็ก → เหล็ก (ได้) · ก้อนหิน → หิน (ไม่ได้) · สายถ่านหิน → ถ่านหิน (ไม่ได้)
function GoldBorder.NodeCanGold(kind)
	local node = kind and GatherConfig.Nodes[kind]
	return node ~= nil and GoldBorder.GatherItems[node.item] == true
end

-- การเก็บครั้งนี้ได้ขอบทองไหม (หนึ่งชิ้นต่อครั้ง) · แดง = แน่นอน · ทอง = 40% · อื่นๆ = 10%
-- `rand` ไว้ให้เทสส่งตัวสุ่มเองได้ · ปกติใช้ math.random
function GoldBorder.Roll(glow, rand)
	if glow == "red" then return true end
	local c = IslandConfig.GoldBorder
	return (rand or math.random)() < (glow == "gold" and c.goldGlow or c.chance)
end

return GoldBorder
