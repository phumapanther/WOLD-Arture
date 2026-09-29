-- node tools/offline-test.js tests/wyrmsleep_shape_test.lua   (หรือ node tools/lua.js tests/wyrmsleep_shape_test.lua Edit)
-- รูปทรงปล่องมังกรหลับจาก WyrmsleepConfig.Target (สเปก docs/superpowers/specs/2026-09-29-wyrmsleep-crater-design.md)
local function fresh(module)
	local copy = module:Clone()
	copy.Name = module.Name .. "_t" .. math.random(1, 1e9)
	copy.Parent = module.Parent
	local ok, result = pcall(require, copy)
	copy:Destroy()
	assert(ok, result)
	return result
end

local W = fresh(game.ReplicatedStorage.WyrmsleepConfig)
local out, fails = {}, 0
local function check(ok, text)
	out[#out + 1] = (ok and "ok   " or "FAIL ") .. text
	if not ok then fails += 1 end
end
local function near(a, b, tol) return a ~= nil and math.abs(a - b) <= tol end

local cx, cz = W.Center.X, W.Center.Z
local ax, az = W.AxisX, W.AxisZ
-- จุดที่ระยะ d มุม deg วัดจากแกนทางเข้า
local function at(d, deg)
	local r = math.rad(deg)
	local dx = ax * math.cos(r) - az * math.sin(r)
	local dz = az * math.cos(r) + ax * math.sin(r)
	return cx + dx * d, cz + dz * d
end
local function dome(d) return 2242 - 0.25 * d end -- ผิวเดิมสมมติ: โดมลาดลง

-- 1. โซนหลัก (ฝั่งตรงข้ามทางเข้า = มุม 180)
local y, kind = W.Target(cx, cz, 2242)
check(near(y, W.FloorY, 0.01) and kind == "floor", ("กลางลาน = %d floor (ได้ %s %s)"):format(W.FloorY, tostring(y), tostring(kind)))
local x, z = at(60, 180)
y, kind = W.Target(x, z, dome(60))
check(near(y, 2200, 0.01) and kind == "floor", "ลาน r60 = 2200")
x, z = at(126, 180)
y, kind = W.Target(x, z, dome(126))
check(near(y, 2190, 0.01) and kind == "lava", ("ท้องลาวา r126 = 2190 lava (ได้ %s %s)"):format(tostring(y), tostring(kind)))
local rimBad = 0
for deg = 30, 330, 15 do
	x, z = at(180, deg)
	y = W.Target(x, z, dome(180))
	if not near(y, 2262, 0.5) then rimBad += 1 end
end
check(rimBad == 0, ("ขอบปล่อง r180 = 2262 ทุกทิศนอกช่องแยก (ผิด %d)"):format(rimBad))
x, z = at(341, 180)
check(W.Target(x, z, 2000) == nil, "นอกรัศมีงาน = nil")

-- 2. ด้านนอกยกอย่างเดียว + จางคืนผิวเดิมที่ขอบรัศมีงาน
local lowered = 0
for d = 181, 339, 2 do
	for _, deg in ipairs({ 60, 120, 180, 240, 300 }) do
		x, z = at(d, deg)
		local orig = 2400 - d * 0.1 -- ผิวสูงกว่ากรวยเสมอ
		local ty = W.Target(x, z, orig)
		if ty < orig - 0.01 then lowered += 1 end
	end
end
check(lowered == 0, ("ด้านนอกไม่เคยขุดต่ำกว่าผิวเดิม (ผิด %d)"):format(lowered))
x, z = at(339.9, 180)
y = W.Target(x, z, 2150)
check(near(y, 2150, 0.5), ("ขอบรัศมีงานต่อกับผิวเดิม (ได้ %.2f)"):format(y or -1))

-- 3. ไม่มีหน้าผาโผล่ในแนวรัศมี (นอก ±20 องศาของแกนทางเข้า)
local worst, worstAt = 0, ""
for deg = 25, 335, 10 do
	local prev
	for d = 0, 339, 1 do
		x, z = at(d, deg)
		local ty = W.Target(x, z, dome(d))
		if prev and math.abs(ty - prev) > worst then worst, worstAt = math.abs(ty - prev), ("%d° r%d"):format(deg, d) end
		prev = ty
	end
end
check(worst <= 3.5, ("ชันสุด %.2f สตัดต่อสตัด ที่ %s (≤ 3.5)"):format(worst, worstAt))

-- 4. ทางเข้า: สะพาน ช่องแยก ลานจอด และทางเดินไม่ชัน
x, z = at(126, 0)
y, kind = W.Target(x, z, dome(126))
check(near(y, W.FloorY, 0.01) and kind == "path", ("สะพาน r126 = 2200 path (ได้ %s %s)"):format(tostring(y), tostring(kind)))
x, z = at(180, 0)
y = W.Target(x, z, dome(180))
check(near(y, W.NotchY, 0.01), ("ช่องแยก = %d (ได้ %s)"):format(W.NotchY, tostring(y)))
y, kind = W.Target(W.PadCenter.X, W.PadCenter.Z, dome(W.PadDistance))
check(near(y, W.PadY, 0.01) and kind == "pad", ("กลางลานจอด = %d pad (ได้ %s %s)"):format(W.PadY, tostring(y), tostring(kind)))
local steep, prev = 0, nil
for d = 0, W.PadDistance, 1 do
	x, z = at(d, 0)
	local ty = W.Target(x, z, dome(d))
	if prev and math.abs(ty - prev) > steep then steep = math.abs(ty - prev) end
	prev = ty
end
check(steep <= 1, ("ทางเดินตามแกนชันสุด %.2f ต่อสตัด (≤ 1)"):format(steep))

-- 5. สะพานไม่มีลาวา
x, z = at(126, 0)
check(W.OnBridge(x, z, 0), "OnBridge จริงกลางสะพาน")
x, z = at(126, 20)
check(not W.OnBridge(x, z, 0), "OnBridge เท็จบนลาวาข้างสะพาน")
x, z = at(126, 180)
check(not W.OnBridge(x, z, 0), "OnBridge เท็จฝั่งตรงข้าม")
local p = W.AtAxis(W.PadDistance)
check(near(p.X, W.PadCenter.X, 0.01) and near(p.Z, W.PadCenter.Z, 0.01), "PadCenter = AtAxis(PadDistance)")

return (fails == 0 and "PASS\n" or ("FAIL x%d\n"):format(fails)) .. table.concat(out, "\n")
