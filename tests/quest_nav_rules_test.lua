-- node tools/offline-test.js tests/quest_nav_rules_test.lua
-- จิ้มเควสแล้วไปไหน (สเปก 2026-09-29): ของ → จุดเก็บที่ให้ของนั้นเป็นหลัก · ไม่มี → มอนที่ดรอป · ปลา → เขตตกปลา
local R = require(game.ReplicatedStorage.QuestNavRules)
local GatherConfig = require(game.ReplicatedStorage.GatherConfig)
local out, fails = {}, 0
local function check(ok, text)
	out[#out + 1] = (ok and "ok   " or "FAIL ") .. text
	if not ok then fails += 1 end
end
local function has(list, v) for _, x in ipairs(list) do if x == v then return true end end return false end

local wood = R.NodeKindsFor("WoodScrap")
check(has(wood, "Tree"), "ไม้ → ต้นไม้")
local iron = R.NodeKindsFor("IronOre")
local allIron = #iron > 0
for _, k in ipairs(iron) do if GatherConfig.Nodes[k].item ~= "IronOre" then allIron = false end end
check(allIron, "แร่เหล็ก → สายแร่เหล็กเท่านั้น (ไม่ใช่ก้อนหินที่มีโอกาส 1%)")
check(#R.NodeKindsFor("Slime") == 0, "เมือกไม่มีจุดเก็บ")
check(has(R.MobKindsFor("Slime"), "GreenSlime"), "เมือก → สไลม์เขียว")
local spider = R.MobKindsNamed("แมงมุมยักษ์")
check(#spider == 1 and spider[1] == "Spider", "ชื่อไทยมอน → ชนิด")
check(#R.MobKindsNamed("ไม่มีมอนนี้") == 0, "ชื่อที่ไม่มี = ว่าง")
check(#R.FishZones("Tanker") == 2, "ปลาประจำถิ่น → เขตของมัน + สระบนเกาะ (" .. #R.FishZones("Tanker") .. ")")
check(#R.FishZones("Fish") == 10, "ปลาธรรมดา → ทุกเขต")
check(#R.FishZones("NotAFish") == 0, "ไม่ใช่ปลา = ว่าง")

-- รีวิวรอบท้าย: จิ้มรัวต้องถูกกั้น (หาเป้าเดินแท็กทั้งแมพ) · ริมน้ำต้องไม่ใช่ช่องที่แผนที่บอกว่าเป็นน้ำ
local store = {}
check(R.TryTap(store, 1, 100) == true and R.TryTap(store, 1, 100.4) == false, "จิ้มซ้ำภายใน 1 วิ = ไม่หาเป้าใหม่")
check(R.TryTap(store, 1, 101.2) == true and R.TryTap(store, 2, 100.5) == true, "พ้น 1 วิ = ได้ · คนอื่นไม่เกี่ยว")
local probed = 0
local shore = R.PickShore(Vector2.new(0, 0), function(x, z)
	probed += 1
	return Vector3.new(x, 5, z)
end, function(x, z) return math.sqrt(x * x + z * z) < 70 end)
check(shore ~= nil and Vector2.new(shore.X, shore.Z).Magnitude >= 70, "ริมน้ำข้ามช่องที่แผนที่บอกว่าเป็นน้ำ")
check(probed == 1, "ช่องน้ำไม่ต้องยิงเรย์เลย (ยิง " .. probed .. " ครั้ง)")
check(R.PickShore(Vector2.new(0, 0), function() return nil end, function() return false end) == nil, "หาไม่เจอ = nil")

return (fails == 0 and "PASS\n" or ("FAIL x%d\n"):format(fails)) .. table.concat(out, "\n")
