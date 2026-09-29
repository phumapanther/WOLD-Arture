-- WyrmsleepConfig: เรขาคณิตของ "ปล่องมังกรหลับ" บนยอดเขาหลักเหนือแอสตราเวล — ที่เดียวของตัวเลขทั้งหมด
-- ใช้ร่วม: เฟส mapgen/112_wyrmsleep_crater (เขียนภูมิประเทศ) · เทส · สถานีเรือเหาะ/แผนที่/โซนเพลง (เทสจับถ้าไม่ตรง)
-- · เฟสบอสมังกรในอนาคต (หาศูนย์ลานจากที่นี่) · สเปก docs/superpowers/specs/2026-09-29-wyrmsleep-crater-design.md
-- ข้อมูลล้วน ไม่แตะ Instance — `Target` เทส offline ได้
local W = {}

W.Name = "ปล่องมังกรหลับ"
-- ยอดจริงที่วัดในเพลสแล้ว (ผังเดิมใน world-layout.json บอก 3600,-4800 ซึ่งไม่ตรงกับเทอร์เรนจริง)
W.Center = Vector3.new(3250, 0, -4850)
-- ทางเข้า/ลานจอดหันไปทางแอสตราเวล — ทางที่คนขึ้นมา
W.Towards = Vector3.new(3840, 0, -3360)

-- ลานสู้ (เกาะบะซอลต์กลางปล่อง)
W.FloorY = 2200
W.FloorRadius = 108
-- ชายลาวาลาดลงหาท้องลาวา · ท้องลาวา (CrackedLava) · ผิวลาวาเป็น Part Neon ที่ติดแท็ก WOLD_Lava
W.BedInner = 116
W.BedOuter = 136
W.LavaBedY = 2190
W.LavaSurfaceY = 2192
W.LavaInner = 112
W.LavaOuter = 140
-- ผนังใน → ขอบปล่อง
W.RimRadius = 180
W.RimY = 2262
-- ด้านนอก: กรวยลาด "ยกอย่างเดียว" แล้วจางคืนผิวเดิม
W.OuterSlope = 0.55
W.FadeFrom = 280
W.WorkRadius = 340
W.MeltRadius = 330 -- หิมะละลายในรัศมีนี้ (เฟสสุ่มขอบให้ไม่เป็นเส้นตรง)
-- เปลือกปล่องหนาเท่านี้ใต้ผิวใหม่ — ไม่ถมโพรงถ้ำที่ลึกกว่านี้ (ผู้ใช้สั่ง 2026-09-29)
W.ShellDepth = 16

-- ทางเข้า: สะพานข้ามลาวา → ทางลาดผ่าผนัง → ช่องแยกขอบปล่อง → ลานจอดเรือเหาะ
W.BridgeHalf = 6
W.PathHalf = 8
W.Blend = 6
W.NotchY = 2214
W.PadY = 2208
W.PadDistance = 265
W.PadRadius = 40

do
	local dx, dz = W.Towards.X - W.Center.X, W.Towards.Z - W.Center.Z
	local m = math.sqrt(dx * dx + dz * dz)
	W.AxisX, W.AxisZ = dx / m, dz / m
end

-- จุดบนแกนทางเข้า ห่างศูนย์ `distance` เยื้องข้าง `side` (บวก = ขวามือเมื่อหันออกจากปล่อง)
function W.AtAxis(distance, side)
	side = side or 0
	return Vector3.new(
		W.Center.X + W.AxisX * distance - W.AxisZ * side,
		0,
		W.Center.Z + W.AxisZ * distance + W.AxisX * side
	)
end
W.PadCenter = W.AtAxis(W.PadDistance)

local function clamp01(t) return math.clamp(t, 0, 1) end
local function smooth(t)
	t = clamp01(t)
	return t * t * (3 - 2 * t)
end
local function lerp(a, b, t) return a + (b - a) * t end

-- ระยะตามแกน (a) กับระยะเยื้องจากแกน (p) ของจุดหนึ่ง
local function axial(x, z)
	local dx, dz = x - W.Center.X, z - W.Center.Z
	return dx * W.AxisX + dz * W.AxisZ, math.abs(-dx * W.AxisZ + dz * W.AxisX)
end

-- ความสูงของทางเดินตามแกน: สะพาน (ระดับลาน) → ไต่ถึงช่องแยก → ลาดลงเบาๆ ถึงลานจอด
local function pathHeight(a)
	if a <= W.LavaOuter then return W.FloorY end
	if a <= W.RimRadius then return lerp(W.FloorY, W.NotchY, (a - W.LavaOuter) / (W.RimRadius - W.LavaOuter)) end
	return lerp(W.NotchY, W.PadY, smooth((a - W.RimRadius) / (W.PadDistance - W.PadRadius - W.RimRadius)))
end

-- จุดนี้อยู่บนสะพานข้ามลาวาไหม (เผื่อขอบ `margin` สตัด) — ชิ้นลาวาห้ามวางทับ
function W.OnBridge(x, z, margin)
	local a, p = axial(x, z)
	return a > W.FloorRadius - 4 and a < W.LavaOuter + 4 and p <= W.BridgeHalf + (margin or 0)
end

-- ความสูงเป้าหมายของผิวดินที่ (x, z) เมื่อผิวเดิมสูง `orig` · คืน y, ชนิดพื้น, ระยะจากศูนย์ · นอกรัศมีงาน = nil
-- ชนิดพื้น: floor · lava · wall · outer · path · pad (เฟสแปลงเป็นวัสดุ)
function W.Target(x, z, orig)
	local dx, dz = x - W.Center.X, z - W.Center.Z
	local d = math.sqrt(dx * dx + dz * dz)
	if d > W.WorkRadius then return nil end

	local y, kind
	if d <= W.FloorRadius then
		y, kind = W.FloorY, "floor"
	elseif d <= W.BedInner then
		y, kind = lerp(W.FloorY, W.LavaBedY, smooth((d - W.FloorRadius) / (W.BedInner - W.FloorRadius))), "lava"
	elseif d <= W.BedOuter then
		y, kind = W.LavaBedY, "lava"
	elseif d <= W.RimRadius then
		y, kind = lerp(W.LavaBedY, W.RimY, smooth((d - W.BedOuter) / (W.RimRadius - W.BedOuter))), "wall"
	else
		-- ยกอย่างเดียว ไม่ขุด แล้วจางคืนผิวเดิมก่อนถึงขอบรัศมีงาน (กันหน้าผาโผล่ที่ขอบ)
		local cone = W.RimY - W.OuterSlope * (d - W.RimRadius)
		y, kind = math.max(orig, cone), "outer"
		if d > W.FadeFrom then
			y = lerp(y, orig, smooth((d - W.FadeFrom) / (W.WorkRadius - W.FadeFrom)))
		end
	end

	-- ทางเข้าตามแกน: สะพานกว้าง BridgeHalf×2 ข้ามลาวา แล้วทางกว้าง PathHalf×2 ถึงลานจอด (ขอบเกลี่ย Blend)
	local a, p = axial(x, z)
	if a > W.FloorRadius - W.Blend and a < W.PadDistance then
		local core = (a <= W.LavaOuter) and W.BridgeHalf or W.PathHalf
		if p < core + W.Blend then
			y = lerp(y, pathHeight(a), 1 - smooth((p - core) / W.Blend))
			if p <= core then kind = "path" end
		end
	end

	-- ลานจอดเรือเหาะ
	local pdx, pdz = x - W.PadCenter.X, z - W.PadCenter.Z
	local dp = math.sqrt(pdx * pdx + pdz * pdz)
	if dp < W.PadRadius + W.Blend then
		y = lerp(y, W.PadY, 1 - smooth((dp - W.PadRadius) / W.Blend))
		if dp <= W.PadRadius then kind = "pad" end
	end

	return y, kind, d
end

return W
