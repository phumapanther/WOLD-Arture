-- QuestNavRules: เควสนี้ต้องไปหาอะไร (ข้อมูลล้วน อ่าน GatherConfig/FishingConfig · เทส tests/quest_nav_rules_test.lua)
-- ตัวหาตำแหน่งจริงอยู่ฝั่งเซิร์ฟ (`QuestNav`) — StreamingEnabled ทำให้ไคลเอนต์มองไม่เห็นของไกล
local GatherConfig = require(script.Parent.GatherConfig)
local FishingConfig = require(script.Parent.FishingConfig)

local QuestNavRules = {}
-- ของแถม/ของสุ่มที่โอกาสต่ำกว่านี้ไม่นับเป็น "แหล่ง" (ก้อนหินมีแร่ทุกชนิด 1% — ไม่ใช่ที่ที่ควรพาคนไปหาแร่)
QuestNavRules.MinChance = 0.2

local function sorted(t)
	table.sort(t)
	return t
end

-- ของหลักตรงก่อน · ไม่มีค่อยดู alt/bonus/roll ที่โอกาสถึงเกณฑ์
function QuestNavRules.NodeKindsFor(item)
	local primary, secondary = {}, {}
	for kind, node in pairs(GatherConfig.Nodes) do
		if node.item == item then
			primary[#primary + 1] = kind
		else
			local hit = (node.alt and node.alt.item == item and (node.alt.chance or 1) >= QuestNavRules.MinChance)
				or (node.bonus and node.bonus.item == item and (node.bonus.chance or 1) >= QuestNavRules.MinChance)
			if not hit and node.roll then
				for _, r in ipairs(node.roll) do
					if r.item == item and (r.chance or 0) >= QuestNavRules.MinChance then hit = true break end
				end
			end
			if hit then secondary[#secondary + 1] = kind end
		end
	end
	return sorted(#primary > 0 and primary or secondary)
end

-- มอนที่ดรอปของนี้ (ไม่นับบอส — บอสโลกไม่ใช่ที่ไปเก็บของส่งเควส)
function QuestNavRules.MobKindsFor(item)
	local out = {}
	for kind, mob in pairs(GatherConfig.Mobs) do
		if not mob.boss then
			for _, drop in ipairs(mob.drops or {}) do
				if drop.item == item then out[#out + 1] = kind break end
			end
		end
	end
	return sorted(out)
end

-- ชื่อไทย (ที่เควสเก็บ) → ชนิด
function QuestNavRules.MobKindsNamed(name)
	local out = {}
	for kind, mob in pairs(GatherConfig.Mobs) do
		if mob.name == name then out[#out + 1] = kind end
	end
	return sorted(out)
end

-- ปลาประจำถิ่น → เขตที่มีมัน · ปลาธรรมดา (อยู่ใน Loot) → ทุกเขต (ทุกเขตเป็นน้ำ) · อื่นๆ → ว่าง
function QuestNavRules.FishZones(item)
	local out = {}
	for _, zone in ipairs(FishingConfig.Zones) do
		for _, f in ipairs(zone.fish or {}) do
			if f.item == item then out[#out + 1] = zone.centre break end
		end
	end
	if #out > 0 then return out end
	for _, entry in ipairs(FishingConfig.Loot) do
		if entry.item == item then
			for _, zone in ipairs(FishingConfig.Zones) do out[#out + 1] = zone.centre end
			return out
		end
	end
	return out
end

-- จิ้มถี่เกินไป (กันยิงรีโมตรัว — การหาเป้าเดินแท็กทั้งแมพ) · `store` = ตารางของผู้เรียก · คืน true = หาเป้าได้
-- จิ้มรัวถูกกั้นเงียบๆ ตามกติกาเดิมของเกม ("กดรัว ยังเงียบโดยตั้งใจ")
QuestNavRules.TapSeconds = 1
function QuestNavRules.TryTap(store, key, now)
	local last = store[key]
	if last and now - last < QuestNavRules.TapSeconds then return false end
	store[key] = now
	return true
end

-- ริมน้ำของเขตตกปลา: ไล่วงรอบ (รัศมี 30→120 ทีละ 15 · 16 ทิศ) คืนจุดแรกที่ `isWaterCell(x, z)` บอกว่าไม่ใช่น้ำ
-- (Navigation ปฏิเสธจุดหมายที่แผนที่บอกว่าเป็นน้ำ — ถามก่อน ประหยัดเรย์ด้วย) และ `probe(x, z)` คืนตำแหน่งบนพื้นจริง
function QuestNavRules.PickShore(centre, probe, isWaterCell)
	for radius = 30, 120, 15 do
		for i = 0, 15 do
			local a = i / 16 * math.pi * 2
			local x, z = centre.X + math.cos(a) * radius, centre.Y + math.sin(a) * radius
			if not isWaterCell(x, z) then
				local pos = probe(x, z)
				if pos then return pos end
			end
		end
	end
	return nil
end

return QuestNavRules
