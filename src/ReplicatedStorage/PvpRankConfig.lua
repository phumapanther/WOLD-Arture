-- PvpRankConfig: แร็งก์ PVP 6 ขั้นตามแร่ (เฟส 3 · ผู้ใช้กำหนดใน roadmap + 2026-09-27) — ข้อมูลล้วน เทสใน Edit ได้
--
-- ⚠️ **ชื่อ "PvpRank" ไม่ใช่ "Rank"** — `SocialConfig.RankFor` คือระดับเลเวล S/A/B (กรอบการ์ดตามเลเวล) คนละเรื่องกัน
--
-- · แต้ม: ชนะ +25 · แพ้ −18 · ไม่ติดลบ · ทุกแมตช์ที่ไม่มีบอทนับ (ไม่แยกคิว) · ออกกลางคัน = แพ้ −18
-- · **ซีซันละ 3 เดือนตามไตรมาส** (ผู้ใช้เลือก 2026-09-27: ม.ค.-มี.ค. · เม.ย.-มิ.ย. · ก.ค.-ก.ย. · ต.ค.-ธ.ค. เวลาไทย)
--   ซีซัน 1 = ตอนนี้ถึง 31 ธ.ค. 2026 (ช่วงปลาย ก.ย. นับรวมซีซัน 1 ไม่มีรอบลดขั้นแค่ 3 วัน) · ขึ้นซีซันใหม่ = **ลดลง 2 ขั้น**
-- · ฉายาแร็งก์ (เลือกได้ในรายการฉายา หายเมื่อแร็งก์เปลี่ยน) + กรอบการ์ดโปรไฟล์ตามสีแร่ (แทนกรอบเลเวลของคนที่เคยเล่นแร็งก์)
-- · ข้อมูลอยู่ DataStore คีย์ของตัวเอง (`PvpRankStore`) ไม่ใช่โปรไฟล์ — ล็อบบี้ไม่เคยเปิดเซสชันโปรไฟล์แต่ต้องรู้ว่าเพิ่งเลื่อนขั้น
local PvpRankConfig = {}

-- **ล็อกระบบแร็งก์ไว้ก่อน** (ผู้ใช้สั่ง 2026-09-28) — false = ไม่นับแต้ม ไม่ฉลอง ไม่มีฉายา/กรอบแร็งก์
-- หน้าปาร์ตี้ PVP โชว์ตราแร็งก์ทุกคนเป็นไอคอนล็อก แตะแล้วบอก `LockedText` · เปิดวันไหนเปลี่ยนเป็น true ที่เดียว
PvpRankConfig.Enabled = false
PvpRankConfig.LockedText = "แร็งก์ยังไม่เปิด"

PvpRankConfig.Win = 25
PvpRankConfig.Loss = 18
PvpRankConfig.SeasonDrop = 2

-- emoji สีเท่านั้น (สัญลักษณ์ตัวอักษรอย่าง ✦ ขึ้นกล่องเปล่าในเกมจริง)
PvpRankConfig.Tiers = {
	{ id = "iron", name = "ไอร่อน", min = 0, color = Color3.fromRGB(160, 164, 174), emoji = "🔩" },
	{ id = "silver", name = "ซิลเวอร์", min = 300, color = Color3.fromRGB(214, 222, 232), emoji = "🥈" },
	{ id = "gold", name = "โกลด์", min = 700, color = Color3.fromRGB(255, 204, 72), emoji = "🥇" },
	{ id = "crystal", name = "คริสตัล", min = 1200, color = Color3.fromRGB(110, 225, 255), emoji = "💠", glow = true },
	{ id = "diamond", name = "ไดมอนด์", min = 1800, color = Color3.fromRGB(180, 245, 255), emoji = "💎", glow = true },
	{ id = "magic", name = "เมจิก", min = 2500, color = Color3.fromRGB(205, 120, 255), emoji = "🔮", glow = true },
}

function PvpRankConfig.TierIndex(points)
	points = math.max(0, math.floor(tonumber(points) or 0))
	local index = 1
	for i, tier in ipairs(PvpRankConfig.Tiers) do
		if points >= tier.min then index = i end
	end
	return index
end

function PvpRankConfig.Tier(index)
	return PvpRankConfig.Tiers[math.clamp(math.floor(tonumber(index) or 1), 1, #PvpRankConfig.Tiers)]
end

-- แต้มที่ต้องมีถึงขั้นถัดไป (nil = ขั้นสูงสุดแล้ว)
function PvpRankConfig.NextMin(points)
	local next = PvpRankConfig.Tiers[PvpRankConfig.TierIndex(points) + 1]
	return next and next.min or nil
end

--------------------------------------------------------------------------------
-- ซีซัน (ไตรมาสเวลาไทย)
--------------------------------------------------------------------------------

local TZ = 7 * 3600
PvpRankConfig.BaseQuarter = 2026 * 4 + 3 -- ต.ค.-ธ.ค. 2026 (ไตรมาสนับจาก 0) = ซีซัน 1

local function quarterOf(now)
	local t = os.date("!*t", math.floor(tonumber(now) or os.time()) + TZ)
	return t.year * 4 + math.floor((t.month - 1) / 3)
end

-- ซีซันของเวลา `now` · ก่อน ต.ค. 2026 = ซีซัน 1 (ปลาย ก.ย. นับรวม)
function PvpRankConfig.Season(now)
	return math.max(1, quarterOf(now) - PvpRankConfig.BaseQuarter + 1)
end

-- os.time ที่ซีซันนี้จบ = เที่ยงคืนวันแรกของไตรมาสถัดไป เวลาไทย
function PvpRankConfig.SeasonEnds(season)
	local q = PvpRankConfig.BaseQuarter + math.floor(season)
	local year, month = math.floor(q / 4), (q % 4) * 3 + 1
	return os.time({ year = year, month = month, day = 1, hour = 0, min = 0, sec = 0 }) - TZ
end

--------------------------------------------------------------------------------
-- บันทึกแร็งก์ของคนหนึ่ง (ข้อมูลล้วน — PvpRankStore เอาไปใช้ใน UpdateAsync)
--------------------------------------------------------------------------------
-- { p = แต้ม, s = ซีซันที่บันทึก, seen = ขั้นที่ฉลองไปแล้ว, played = เคยเล่นแร็งก์, m = { รหัสแมตช์ที่นับแล้ว },
--   last = { d = แต้มที่เปลี่ยน, kind = "win"|"loss"|"season", at } }

local MATCH_MEMORY = 30 -- จำรหัสแมตช์ล่าสุดเท่านี้ (กันนับซ้ำ — เซิร์ฟแมตช์หนึ่งเขียนครั้งเดียวอยู่แล้ว)

-- ทำให้เป็นของซีซัน `season`: ข้ามกี่ซีซัน = ลด 2 ขั้นต่อซีซัน · แต้มลงไปอยู่ที่เส้นล่างของขั้นนั้น
function PvpRankConfig.Normalize(record, season)
	local r = type(record) == "table" and record or {}
	r.p = math.max(0, math.floor(tonumber(r.p) or 0))
	r.m = type(r.m) == "table" and r.m or {}
	r.s = tonumber(r.s) or season
	r.seen = tonumber(r.seen) or PvpRankConfig.TierIndex(r.p)
	local passed = math.max(0, season - r.s)
	if passed > 0 and r.played then
		local index = PvpRankConfig.TierIndex(r.p)
		for _ = 1, passed do index = math.max(1, index - PvpRankConfig.SeasonDrop) end
		local before = r.p
		r.p = math.min(r.p, PvpRankConfig.Tiers[index].min)
		if r.p < before then r.last = { d = r.p - before, kind = "season", at = os.time() } end
	end
	r.s = season
	-- ตกขั้น (จบซีซัน/แพ้) = ขั้นที่ฉลองแล้วเลื่อนลงตาม ขึ้นกลับมาใหม่จะได้ฉลองอีก
	r.seen = math.min(r.seen, PvpRankConfig.TierIndex(r.p))
	return r
end

-- นับแมตช์หนึ่ง · คืน record (แก้ในที่) และ false ถ้าแมตช์นี้นับไปแล้ว
function PvpRankConfig.Apply(record, season, matchId, delta)
	local r = PvpRankConfig.Normalize(record, season)
	for _, id in ipairs(r.m) do
		if id == matchId then return r, false end
	end
	table.insert(r.m, matchId)
	while #r.m > MATCH_MEMORY do table.remove(r.m, 1) end
	local before = r.p
	r.p = math.max(0, r.p + math.floor(delta))
	r.played = true
	r.last = { d = r.p - before, kind = delta >= 0 and "win" or "loss", at = os.time() }
	r.seen = math.min(r.seen, PvpRankConfig.TierIndex(r.p))
	return r, true
end

return PvpRankConfig
