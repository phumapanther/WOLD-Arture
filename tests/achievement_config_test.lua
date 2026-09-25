-- node tools/lua.js tests/achievement_config_test.lua Edit
-- ความสำเร็จ + ฉายา (สเปก docs/superpowers/specs/2026-09-25-achievements-design.md)
local function fresh(module)
	local copy = module:Clone()
	copy.Name = module.Name .. "_t" .. math.random(1, 1e9)
	copy.Parent = module.Parent
	local ok, result = pcall(require, copy)
	copy:Destroy()
	assert(ok, result)
	return result
end

local C = fresh(game.ReplicatedStorage.AchievementConfig)
local out, fails = {}, 0
local function check(ok, text)
	out[#out + 1] = (ok and "ok   " or "FAIL ") .. text
	if not ok then fails += 1 end
end

local seen = {}
for _, def in ipairs(C.List) do
	check(not seen[def.id], def.id .. " id ไม่ซ้ำ")
	seen[def.id] = true
	check(type(def.title) == "string" and def.title ~= "", def.id .. " มีฉายา")
	check(C.Stats[def.stat] ~= nil, def.id .. " สถิติ " .. tostring(def.stat) .. " รู้จัก")
	check((def.goal or 0) > 0 and (def.gems or 0) > 0, def.id .. " เป้า/เพชร > 0")
	check(C.Tiers[def.tier] ~= nil, def.id .. " ระดับสีมีจริง")
end
check(#C.List >= 20, ("ความสำเร็จ %d อัน"):format(#C.List))
check(C.Get("level100") and C.Get("level100").goal == 100, "เลเวล 100 = ตำนาน")
check(C.Get("enhance10") and C.Get("enhance10").stat == "maxEnhance" and C.Get("enhance10").goal == 10, "ตีบวก +10")
check(C.IsDone(C.Get("mobs100"), 100) and not C.IsDone(C.Get("mobs100"), 99), "IsDone ครบเป้าพอดี")
check(not C.IsDone(C.Get("mobs100"), 0 / 0) and not C.IsDone(nil, 5), "IsDone ค่าแปลก = ยังไม่ปลด")
check(C.Special.vip.title == "VIP" and C.Special.marked.title == "หัวแดง", "ฉายาพิเศษ VIP / หัวแดง")
check(C.Get("vip") == nil and C.Get("marked") == nil, "ฉายาพิเศษไม่ใช่ความสำเร็จที่ปลดได้")

return (fails == 0 and "PASS\n" or ("FAIL x%d\n"):format(fails)) .. table.concat(out, "\n")
