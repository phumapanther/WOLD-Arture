-- EnhanceConfig: ตีบวกอาวุธ +1 ถึง +10 ที่ช่างตีเหล็ก — ข้อมูลล้วน (สเปก docs/superpowers/specs/2026-09-24-enhance-design.md)
--
-- **ทุกตัวเลขผู้ใช้กำหนด** (2026-09-24): ของที่ใช้เพิ่มขึ้นทุกขั้น เน้นแร่ + ของผิดกฎหมาย + ซิลเวอร์หลักพัน ·
-- โอกาสลดจาก 100% ถึง 20% · โบนัสดาเมจ +1..+5 ขั้นละ 3% · +6..+10 ขั้นละ 8% · ตีแตก = ความคงทนลด 10% ขั้นไม่ลด
--
-- ขั้นเก็บที่ `meta.enhance` บนตัวอาวุธ (ที่เดียวกับ meta.skin) จึงเดินทางไปกับอาวุธทุกที่ (สวม/ถอด/คลัง/เมล)
local EnhanceConfig = {}

-- อาวุธต่อสู้เท่านั้น (ผู้ใช้เลือก) · **ไม่มีสไน** — ดาเมจสไนเป็นสัดส่วนของเลือดเต็ม โบนัส % จึงไม่มีผล
EnhanceConfig.Weapons = {
	Sword = true, Bow = true, Staff = true, Spellbook = true, Greatsword = true, Shield = true, Pistol = true,
}

EnhanceConfig.MaxLevel = 10
EnhanceConfig.FailDurabilityFraction = 0.10 -- ตีแตก = ความคงทนลด 10% ของค่าเต็ม (ต่ำสุดเหลือ 1)
EnhanceConfig.Seconds = 4 -- แถบเวลาตอนตี (ผู้ใช้สั่ง "ตีแล้ว รอรู้ผล เหมือนการคราฟ" · ความยาวผมตั้ง)

-- [ขั้นที่กำลังตีขึ้นไป] = { chance = โอกาสสำเร็จ, bonus = ดาเมจรวมที่ขั้นนั้น, cost = ของที่ใช้ต่อการกดหนึ่งครั้ง }
-- วัสดุหายทุกครั้งที่กด ไม่ว่าสำเร็จหรือแตก
EnhanceConfig.Levels = {
	{ chance = 1.00, bonus = 0.03, cost = { Silver = 1000, IronOre = 5, Coal = 5, Chemical = 1 } },
	{ chance = 0.95, bonus = 0.06, cost = { Silver = 1500, IronOre = 8, Coal = 8, Chemical = 2 } },
	{ chance = 0.90, bonus = 0.09, cost = { Silver = 2000, IronOre = 10, Coal = 10, SilverOre = 3, Chemical = 3, GearSpare = 1 } },
	{ chance = 0.80, bonus = 0.12, cost = { Silver = 2500, IronOre = 12, Coal = 12, SilverOre = 5, Chemical = 4, GearSpare = 2 } },
	{ chance = 0.70, bonus = 0.15, cost = { Silver = 3000, IronOre = 15, Coal = 15, SilverOre = 8, GoldOre = 3,
		Chemical = 5, GearSpare = 3 } },
	{ chance = 0.60, bonus = 0.23, cost = { Silver = 4000, IronOre = 20, Coal = 20, SilverOre = 10, GoldOre = 5,
		Chemical = 6, GearSpare = 4, Blueprint = 1 } },
	{ chance = 0.50, bonus = 0.31, cost = { Silver = 5000, IronOre = 25, SilverOre = 12, GoldOre = 8, Crystal = 3,
		Chemical = 8, GearSpare = 5, Blueprint = 1 } },
	{ chance = 0.40, bonus = 0.39, cost = { Silver = 6500, IronOre = 30, SilverOre = 15, GoldOre = 10, MagicOre = 3,
		Chemical = 10, GearSpare = 6, Blueprint = 2 } },
	{ chance = 0.30, bonus = 0.47, cost = { Silver = 8000, IronOre = 35, GoldOre = 12, MagicOre = 5, Diamond = 2,
		Chemical = 12, GearSpare = 8, Blueprint = 2 } },
	{ chance = 0.20, bonus = 0.55, cost = { Silver = 10000, IronOre = 40, GoldOre = 15, MagicOre = 8, Diamond = 5,
		Chemical = 15, GearSpare = 10, Blueprint = 3 } },
}

-- ขั้นของอาวุธชิ้นนี้ 0..10 · meta มาจากเซฟ/ไคลเอนต์ได้ทุกรูป จึงกันค่าแปลก (สตริง NaN ติดลบ เกินเพดาน)
function EnhanceConfig.LevelOf(meta)
	local level = type(meta) == "table" and tonumber(meta.enhance) or nil
	if not level or level ~= level then return 0 end
	return math.clamp(math.floor(level), 0, EnhanceConfig.MaxLevel)
end

-- ดาเมจเพิ่มรวมที่ขั้นนี้ (0.03 = +3%)
function EnhanceConfig.Bonus(level)
	local row = EnhanceConfig.Levels[level]
	return row and row.bonus or 0
end

-- ตัวคูณดาเมจของอาวุธที่ถืออยู่ (`entry` = ช่องอาวุธ { id, meta } หรือ nil = มือเปล่า)
function EnhanceConfig.MultiplierFor(entry)
	if type(entry) ~= "table" or not EnhanceConfig.Weapons[entry.id] then return 1 end
	return 1 + EnhanceConfig.Bonus(EnhanceConfig.LevelOf(entry.meta))
end

return EnhanceConfig
