-- node tools/offline-test.js tests/locale_p2_world_test.lua
-- โลก (เก็บเกี่ยว ตกปลา บอสโลก อีเวนต์ หม้อแปลง ฟาร์มเถื่อน อากาศ แผนที่ มอน เตียง ลาวา มินิเกม เลเวล บัพ) แปลครบ · ไทยเหมือนเดิม
local L = require(game.ReplicatedStorage.Locale)
local GC = require(game.ReplicatedStorage.GatherConfig)
local FC = require(game.ReplicatedStorage.FishingConfig)
local EC = require(game.ReplicatedStorage.EventConfig)
local WC = require(game.ReplicatedStorage.WeatherConfig)
local FarmC = require(game.ReplicatedStorage.FarmConfig)
local MC = require(game.ReplicatedStorage.MapConfig)
local R = require(game.ReplicatedStorage.MapPoiRules)
local IC = require(game.ReplicatedStorage.ItemCatalog)
local out, fails = {}, 0
local function check(ok, text) out[#out + 1] = (ok and "ok   " or "FAIL ") .. text if not ok then fails += 1 end end
local function tr(lang, th, want, label)
	local got = L.Translate(lang, th)
	check(got == want, ("%s %s: %s"):format(label, lang, tostring(got)))
end

-- 1. ป้ายจากคอนฟิก (ปุ่ม E · ชื่อมอน · อีเวนต์ · อากาศ · แผนที่ · ระดับปลา · เขตตกปลา) มีคำแปลครบทุกภาษา
local labels = {}
local function add(v) if type(v) == "string" and v ~= "" then labels[#labels + 1] = v end end
for _, n in pairs(GC.Nodes) do add(n.prompt) add(n.object) end
for _, m in pairs(GC.Mobs) do add(m.name) end
for _, e in pairs(EC.Events) do add(e.message) end
for _, r in ipairs(EC.WorldBoss.Ranks) do add(r.label) end
for _, k in pairs(WC.Kinds) do add(k.name) end
for _, t in ipairs(FC.KgTiers) do add(t.name) end
for _, z in ipairs(FC.Zones) do add(z.name) end
for _, f in pairs(FarmC.Nodes) do add(f.prompt) add(f.object) end
for _, p in ipairs(MC.Places) do add(p.th) end
for _, c in ipairs(R.Categories) do add(c.label) end
for _, lang in ipairs({ "en", "zh", "ja" }) do
	local missing = {}
	for _, th in ipairs(labels) do
		if L.T(lang, th) == th then missing[#missing + 1] = th end
	end
	check(#missing == 0, ("%s ป้ายโลกครบ %d อัน (ขาด: %s)"):format(lang, #labels, tostring(missing[1])))
end
check(#labels > 60, "เก็บป้ายได้ครบพอ: " .. #labels)

-- 2. เก็บเกี่ยว: แม่แบบใหม่ = ข้อความเดิมทุกไบต์ + แปลได้
local old = ("ได้ %s x%d"):format("เศษไม้", 3) .. (" + %s x%d"):format("หนอน", 2) .. " (🌟 ขอบทอง 1 ชิ้น)"
local new = ("%s (🌟 ขอบทอง 1 ชิ้น)"):format(("ได้ %s x%d + %s x%d"):format("เศษไม้", 3, "หนอน", 2))
check(old == new, "เก็บเกี่ยว + ของแถม + ขอบทอง ไทยเท่าเดิม")
tr("en", new, "Got " .. L.T("en", "เศษไม้") .. " x3 + Worm x2 (🌟 1 gold-rimmed)", "เก็บเกี่ยวครบชุด")
tr("en", "ได้ ก้อนหิน x3", "Got Stone x3", "เก็บเกี่ยวธรรมดา")
tr("en", "หายาก! ได้ เพชร x1", "Rare! Got Diamond x1", "ดรอปหายาก")
tr("ja", "ซ่อมสำเร็จ ได้ เฟืองอะไหล่ x2", "修理成功！" .. L.T("ja", "เฟืองอะไหล่") .. " x2 獲得", "รางวัลซ่อมหม้อแปลง")
tr("en", ("ต้องถือ%sก่อน"):format("ขวาน"), "Hold the Axe first", "ต้องถือเครื่องมือ")
check(L.T("en", "ฟาร์มออโต้: เปิด — %s", "กด F เพื่อหยุด") == "Auto-farm ON — press F to stop", "แถบฟาร์มออโต้ (L แปลอาร์กิวเมนต์)")

-- 3. ตกปลา: สี่รูปประโยค = ข้อความเดิม · แปลได้
local function oldCatch(name, kg, tier, zone)
	return ("ตกได้ %s %.1f กก.%s%s"):format(name, kg, tier ~= "" and (" (%s)"):format(tier) or "",
		zone and (" — ปลาประจำถิ่น%s"):format(zone) or "")
end
check(oldCatch("ปลาดุก", 12.34, "ตัวใหญ่", "อ่าวบราสเฮเวน")
	== ("ตกได้ %s %.1f กก. (%s) — ปลาประจำถิ่น%s"):format("ปลาดุก", 12.34, "ตัวใหญ่", "อ่าวบราสเฮเวน"), "ปลาตัวใหญ่ประจำถิ่น ไทยเท่าเดิม")
check(oldCatch("ปลาดุก", 2, "", nil) == ("ตกได้ %s %.1f กก."):format("ปลาดุก", 2), "ปลาธรรมดา ไทยเท่าเดิม")
check(oldCatch("ปลาดุก", 2, "ตำนาน", nil) == ("ตกได้ %s %.1f กก. (%s)"):format("ปลาดุก", 2, "ตำนาน"), "ปลาระดับ ไทยเท่าเดิม")
check(oldCatch("ปลาดุก", 2, "", "สระบนเกาะ") == ("ตกได้ %s %.1f กก. — ปลาประจำถิ่น%s"):format("ปลาดุก", 2, "สระบนเกาะ"), "ปลาประจำถิ่น ไทยเท่าเดิม")
tr("en", "ตกได้ ปลา 12.3 กก. (ตัวใหญ่) — ปลาประจำถิ่นอ่าวบราสเฮเวน", "Caught Fish 12.3 kg (Big) — local fish of Brasshaven Bay", "ปลาประจำถิ่น")
tr("zh", "ตกได้ ปลา 3.0 กก. (ตำนาน)", "钓到 鱼 3.0 公斤（传奇）", "ปลาระดับ")

-- 4. บอสโลก: หัวข้อ + รายชื่อ = ข้อความเดิม
local top = "1. Bob (500)  2. Al (300)"
check(("%s — %s"):format("ฟอร์จวอร์เดนถูกปราบแล้ว!", top) == ("ฟอร์จวอร์เดนถูกปราบแล้ว! — %s"):format(top), "ประกาศจบบอส ไทยเท่าเดิม")
check(("อันดับ " .. 12) == ("อันดับ %d"):format(12), "อันดับสำรอง ไทยเท่าเดิม")
tr("en", ("ฟอร์จวอร์เดนถูกปราบแล้ว! — %s"):format(top), "Forgewarden has been defeated! — " .. top, "ประกาศจบบอส")
tr("en", "รางวัลบอสโลก — อันดับ 2-3", "World boss reward — Rank 2-3", "หัวจดหมายบอส")
tr("ja", "อันดับ 1 (ดาเมจ 4200) — รางวัลส่งเข้ากล่องจดหมายแล้ว (P → กล่องจดหมาย)",
	"1 位（ダメージ 4200）— 報酬を郵便箱に送った（P → 郵便箱）", "แจ้งรางวัลบอส")

-- 5. ฟาร์มเถื่อน: หัวมินิเกม "งาน · ของ" = ข้อความเดิม · แปลทีละชิ้น
check(("%s%s"):format("ผลิต", " · " .. "ชุดกลั่นเคมี") == ("%s · %s"):format("ผลิต", "ชุดกลั่นเคมี"), "หัวมินิเกม ไทยเท่าเดิม")
tr("en", "ผลิต · ชุดกลั่นเคมี", "Brew · Chemical still", "หัวมินิเกม")
tr("en", "ยังใช้ไม่ได้ อีก 4:07", "Not ready yet, 4:07 left", "คูลดาวน์ฟาร์ม")
tr("en", FarmC.ClosedMessage:format(5), "Not yet: needs 5 players on the server, or 1 guard online", "ฟาร์มคนไม่ครบ")

-- 6. หมุดแผนที่: ป้ายจาก Build = ข้อความเดิม · แปลได้
local pins = R.Build({
	npcs = { { kind = "shop", name = "บาร์นาบี", x = 0, z = 0 } },
	spawners = { { kind = "Forgewarden", name = "ฟอร์จวอร์เดน ผู้พิทักษ์เตาหลอม", event = "worldboss", x = 1, z = 1 } },
	ores = { { kind = "IronOre", x = 0, z = 0 }, { kind = "IronOre", x = 1, z = 0 }, { kind = "Crystal", x = 2, z = 0 } },
	boards = { { id = "Brasshaven", name = "บราสเฮเวน", x = 2, z = 2 } },
	fishing = { { id = "BrasshavenBay", name = "อ่าวบราสเฮเวน", fish = "ปลา", x = 3, z = 3 } },
})
local byPrefix = {}
for _, p in ipairs(pins) do byPrefix[p.id:match("^(%a+)")] = p.label end
check(byPrefix.npc == "ร้าน" .. " " .. "บาร์นาบี", "ป้ายร้าน ไทยเท่าเดิม: " .. tostring(byPrefix.npc))
check(byPrefix.boss == "บอสโลก: " .. "ฟอร์จวอร์เดน ผู้พิทักษ์เตาหลอม", "ป้ายบอส ไทยเท่าเดิม")
check(byPrefix.board == "บอร์ดเควส " .. "บราสเฮเวน", "ป้ายบอร์ด ไทยเท่าเดิม")
check(byPrefix.fish == "อ่าวบราสเฮเวน" .. " · " .. "ปลา", "ป้ายจุดตกปลา ไทยเท่าเดิม")
check(byPrefix.mine == "เหมือง: " .. "เหล็ก · คริสตัล", "ป้ายเหมือง ไทยเท่าเดิม: " .. tostring(byPrefix.mine))
tr("en", byPrefix.npc, "Shop Barnaby", "ป้ายร้าน")
tr("en", byPrefix.boss, "World boss: Forgewarden, Keeper of the Foundry", "ป้ายบอส")
tr("zh", byPrefix.board, "任务板 黄铜港", "ป้ายบอร์ด")
tr("en", byPrefix.fish, "Brasshaven Bay · Fish", "ป้ายจุดตกปลา")
tr("en", byPrefix.mine, "Mine: Iron · Crystal", "ป้ายเหมือง")
-- "เงิน" สั้นชนกุญแจเงินตรา → MapGui แปลชื่อแร่ผ่านชื่อไอเทม (แร่เงิน) แทน
check(L.T("en", IC.Get("SilverOre").name) == "Silver Ore", "ชื่อแร่เงินจากไอเทม (MapGui ใช้แทนคำสั้น)")
check(L.T("ja", "เหมือง: %s", "鉄鉱石 · 銀鉱石") == "鉱山：鉄鉱石 · 銀鉱石", "ป้ายเหมืองภาษาญี่ปุ่น")

-- 7. ข้อความอื่น: อีเวนต์ หม้อแปลง เตียง (1% ตัวอักษรจริง) บัพ เลเวล นำทาง มินิเกม
tr("en", "ซ่อมแล้ว 3/7", "Repaired 3/7", "ป้ายหม้อแปลง")
tr("en", "นอนพัก เลือดฟื้น 1% ต่อวินาที — ขยับหรือกด E เพื่อลุก", "Resting: HP +1% per second — move or press E to get up", "นอนพัก")
tr("en", "สภาพอากาศ: พายุทราย", "Weather: Sandstorm", "อากาศ")
tr("zh", "ฟอร์จวอร์เดน ผู้พิทักษ์เตาหลอม ตื่นแล้ว! เหลือเวลา 42 นาที — รางวัลแจกตามดาเมจที่ทำได้",
	"熔炉守卫 福吉沃登 苏醒了！剩余 42 分钟 — 按造成的伤害发放奖励", "บอสตื่น")
tr("en", "12 จุด", "12 waypoints", "จำนวนจุดนำทาง")
tr("en", "จ่าฝูงโครงกระดูก", "Alpha " .. L.T("en", "โครงกระดูก"), "จ่าฝูง")
check(L.T("en", "เลเวล %d · เลือด สตามินา เกราะ เติมเต็ม", 7) == "Level 7 · health, stamina, armor refilled", "แบนเนอร์เลเวลอัพ")
check(L.T("en", "ตี (ปุ่มมินิเกม)") == "HIT" and L.T("en", "ตี") ~= "HIT", "ปุ่มตีมินิเกมใช้กุญแจแยกจาก 'ตี' (ตีบวก)")
check(L.T("th", "ฟาร์มออโต้: เปิด — %s", "กด F เพื่อหยุด") == "ฟาร์มออโต้: เปิด — กด F เพื่อหยุด", "ไทยเหมือนเดิม")

-- 8. รีวิวรอบ 2: แจ้งบัพหลังกิน (PlayerInventory) = แม่แบบเดียวต่อหน่วย · ไทยเท่าเดิม · แปลครบทั้งชื่อบัพหลายตัว
local function oldDuration(s) return s < 60 and ("%d วินาที"):format(math.floor(s)) or ("%d นาที"):format(math.floor(s / 60)) end
local function newBuffText(text, s)
	return s < 60 and ("%s %d วินาที"):format(text, math.floor(s)) or ("%s %d นาที"):format(text, math.floor(s / 60))
end
for _, case in ipairs({ { "บัพทุกอย่าง", 180 }, { "มานาไม่ลด · สตามินาไม่ลด", 60 }, { "เลือดไม่ลด", 10.4 } }) do
	check(("%s %s"):format(case[1], oldDuration(case[2])) == newBuffText(case[1], case[2]), "แจ้งบัพ ไทยเท่าเดิม: " .. case[1])
end
tr("en", newBuffText("บัพทุกอย่าง", 180), "All buffs 3 min", "แจ้งบัพ (นาที)")
tr("en", newBuffText("มานาไม่ลด · สตามินาไม่ลด", 60), "No mana loss · No stamina loss 1 min", "แจ้งบัพหลายตัว")
tr("zh", newBuffText("บัพทุกอย่าง", 45), L.T("zh", "บัพทุกอย่าง") .. " 45 秒", "แจ้งบัพ (วินาที)")

-- 9. ป้ายในโลกที่เซิร์ฟสร้าง (แท็ก WOLD_ShowText → WorldTextController แปล): ชื่อปลาบนการ์ด · หลบของมอน
tr("en", ("%s %.1f กก."):format("ปลาดุก", 12.5), L.T("en", "ปลาดุก") .. " 12.5 kg", "การ์ดตกปลา")
tr("ja", ("%s %.1f กก.\n%s"):format("ปลาดุก", 44, "ตำนาน"), L.T("ja", "ปลาดุก") .. " 44.0 kg\n" .. L.T("ja", "ตำนาน"), "การ์ดตกปลาระดับ")
tr("zh", "หลบ!", "闪避！", "มอนหลบ")
-- แผนที่: ป้ายเหมืองแปลแล้วส่งต่อให้แถบนำทาง · Show ซ้ำบนคำแปลต้องไม่เปลี่ยนอะไร (เดิม Show ป้ายไทย = "Coins")
check(L.Translate("en", "เหมือง: เหล็ก · เงิน") == "Mine: Iron · Coins", "ป้ายเหมืองไทยผ่าน Show ตรงๆ ได้ Coins (เหตุที่ MapGui ส่งคำแปล)")
local mineEn = L.T("en", "เหมือง: %s", "Iron · Silver Ore")
tr("en", mineEn, mineEn, "Show ซ้ำบนป้ายที่แปลแล้ว")

return (fails == 0 and "PASS\n" or ("FAIL x%d\n"):format(fails)) .. table.concat(out, "\n")
