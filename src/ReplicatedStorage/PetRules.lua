-- PetRules (เฟส 2d ผู้ใช้อนุมัติ 2026-09-27): ลูบสัตว์เลี้ยงแล้วได้อะไร — ข้อมูลล้วน เทสใน Edit ได้ (farm_level_test)
--
-- "ลูบทุกครั้งได้ 1-5 ชิ้นจากตารางดรอปมอนตัวนั้น **เฉพาะวัตถุดิบ** (ไม่มีอาวุธ/หีบ/เครื่องราง) · สัตว์ฟาร์มได้ผลผลิตของมัน ·
-- หมา/แมวไม่ดรอป" · จำนวน **1-5 เท่ากันทุกขนาดตัว** (ผู้ใช้เลือก) ถ่วงน้ำหนักชุดเดียวกับผลผลิตคอก (ส่วนใหญ่ 2-3)
--
-- ตารางดรอปอ่านจาก `GatherConfig` ของเกมหลักตรงๆ ไม่มีตารางที่สอง — มอนเปลี่ยนของดรอปเมื่อไหร่ สัตว์เลี้ยงเปลี่ยนตาม
local IslandConfig = require(script.Parent.IslandConfig)
local GatherConfig = require(script.Parent.GatherConfig)
local ItemCatalog = require(script.Parent.ItemCatalog)

local PetRules = {}

-- วัตถุดิบ = ไอเทม kind "junk" (แร่ กระดูก เมือก ผลผลิตสัตว์ ...) — อาวุธ/หีบ/เครื่องราง/ของใช้ไม่ใช่ kind นี้
local function isMaterial(id)
	local item = type(id) == "string" and ItemCatalog.Get(id)
	return item ~= nil and item ~= false and item.kind == "junk"
end

-- { { item, weight } } ของที่ตัวนี้ให้ได้ · น้ำหนัก = โอกาสดรอปเดิมของมอน (ไม่มี = 1) · ว่าง = ไม่ดรอป
function PetRules.Drops(id)
	local spec = IslandConfig.PetSpecies[id]
	if not spec then return {} end
	local out = {}
	if spec.produce then
		local node = GatherConfig.Nodes[spec.produce]
		if node and isMaterial(node.item) then out[1] = { item = node.item, weight = 1 } end
		return out
	end
	local mob = spec.mob and GatherConfig.Mobs[spec.mob]
	for _, drop in ipairs(mob and mob.drops or {}) do
		-- แถวแบบ oneOf (สุ่มอาวุธหนึ่งชิ้น) ไม่มี `item` = ข้ามทั้งแถว
		if drop.item and isMaterial(drop.item) then
			local w = tonumber(drop.chance) or 1
			if w > 0 then out[#out + 1] = { item = drop.item, weight = w } end
		end
	end
	return out
end

-- ชุดวัตถุดิบเรียงชื่อ เช่น "Bone,IronOre" · "" = ไม่ดรอป (ใช้ตรวจกติกา "ให้ของเดียวกัน = ปลดเลเวลเดียวกัน")
function PetRules.Signature(id)
	local t = {}
	for _, d in ipairs(PetRules.Drops(id)) do t[#t + 1] = d.item end
	table.sort(t)
	return table.concat(t, ",")
end

-- จำนวนชิ้นต่อการลูบ 1-5 (น้ำหนักเดียวกับผลผลิตคอก IslandConfig.PenYieldWeights)
function PetRules.RollCount(rng)
	local weights = IslandConfig.PenYieldWeights
	local total = 0
	for n = 1, 5 do total += weights[n] or 0 end
	local pick = rng:NextNumber() * total
	for n = 1, 5 do
		pick -= weights[n] or 0
		if pick < 0 then return n end
	end
	return 5
end

-- ทอยของหนึ่งครั้งที่ลูบ → { [item] = จำนวน } (ว่าง = ตัวนี้ไม่ดรอป) · แต่ละชิ้นสุ่มจากน้ำหนักแยกกัน
function PetRules.Roll(id, rng)
	local drops = PetRules.Drops(id)
	local out = {}
	if #drops == 0 then return out end
	local total = 0
	for _, d in ipairs(drops) do total += d.weight end
	for _ = 1, PetRules.RollCount(rng) do
		local pick = rng:NextNumber() * total
		local chosen = drops[#drops].item
		for _, d in ipairs(drops) do
			pick -= d.weight
			if pick < 0 then chosen = d.item break end
		end
		out[chosen] = (out[chosen] or 0) + 1
	end
	return out
end

return PetRules
