-- node tools/offline-test.js tests/wyrmsleep_config_test.lua
-- คอนฟิกข้ามระบบของปล่องมังกรหลับต้องตรงกับ WyrmsleepConfig: เรือเหาะ · แผนที่ M · โซนเพลง · ลาวา
local function fresh(module)
	local copy = module:Clone()
	copy.Name = module.Name .. "_t" .. math.random(1, 1e9)
	copy.Parent = module.Parent
	local ok, result = pcall(require, copy)
	copy:Destroy()
	assert(ok, result)
	return result
end

local RS = game.ReplicatedStorage
local W = fresh(RS.WyrmsleepConfig)
local Vehicle = fresh(RS.Vehicle.Config)
local Map = fresh(RS.MapConfig)
local Sound = fresh(RS.SoundscapeConfig)
local Vitals = fresh(RS.VitalsConfig)

local out, fails = {}, 0
local function check(ok, text)
	out[#out + 1] = (ok and "ok   " or "FAIL ") .. text
	if not ok then fails += 1 end
end
local function flat(a, b) return math.sqrt((a.X - b.X) ^ 2 + (a.Z - b.Z) ^ 2) end

-- เรือเหาะ
local airship = Vehicle.Types.Airship
check(airship.maxAlt >= W.RimY + 100, ("เพดานเรือเหาะ %d ≥ ขอบปล่อง+100 (%d)"):format(airship.maxAlt, W.RimY + 100))
local station
for _, s in ipairs(Vehicle.Presets.Arture) do
	if s.id == "WyrmsleepMooring" then station = s end
end
check(station ~= nil and station.vtype == "Airship" and station.surface == "ground", "มีสถานี WyrmsleepMooring (Airship ground)")
if station then
	check(flat(station.pos, W.PadCenter) <= W.PadRadius - 3, ("เสาเรียกอยู่บนลานจอด (ห่างศูนย์ลาน %.1f)"):format(flat(station.pos, W.PadCenter)))
	check(flat(station.spawn, W.PadCenter) <= 5, ("จุดเรือโผล่กลางลานจอด (ห่าง %.1f)"):format(flat(station.spawn, W.PadCenter)))
end

-- แผนที่ M
local want = {
	["Wyrmsleep Crater"] = { W.Center.X, W.Center.Z },
	["Foundry"] = { -1061, 5317 },
	["Runestone Forest"] = { -700, -1160 },
	["World Tree"] = { -4150, 2460 },
	["Hermit Tower"] = { 1586, 238 },
}
local found = {}
for _, p in ipairs(Map.Places) do
	check(Map.Kinds[p.kind] ~= nil, ("หมุด %s ใช้ชนิดที่มีจริง (%s)"):format(p.name, tostring(p.kind)))
	check(p.name ~= "Spire of Eld" and p.name ~= "Crystal Cave", "ไม่มีหมุดเก่า " .. p.name)
	local w = want[p.name]
	if w then
		found[p.name] = true
		local nx, nz = w[1] / Map.HalfSize, w[2] / Map.HalfSize
		check(math.abs(p.pos[1] - nx) <= 0.005 and math.abs(p.pos[2] - nz) <= 0.005,
			("%s อยู่ที่ %.4f, %.4f (ควร %.4f, %.4f)"):format(p.th, p.pos[1], p.pos[2], nx, nz))
	end
end
for name in pairs(want) do check(found[name], "มีหมุด " .. name) end

-- โซนเพลง
local town
for _, t in ipairs(Sound.Towns) do
	check(t.name ~= "Spire of Eld", "ไม่มีโซนเพลงหอเวทเก่า")
	if t.name == "Wyrmsleep" then town = t end
end
check(town ~= nil and town.x == W.Center.X and town.z == W.Center.Z, "โซนเพลง Wyrmsleep อยู่ศูนย์ปล่อง")
check(Sound.WorldMusic.Zones.Wyrmsleep ~= nil and Sound.WorldMusic.Zones["Spire of Eld"] == nil, "เพลงโซน Wyrmsleep แทนหอเวท")

-- ลาวา
check(Vitals.LavaBurnFraction == 0.10, "ลาวาไหม้ 10% ของเลือดเต็มต่อวิ")

return (fails == 0 and "PASS\n" or ("FAIL x%d\n"):format(fails)) .. table.concat(out, "\n")
