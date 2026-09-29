-- node tools/lua.js tests/wyrmsleep_crater_test.lua Edit   (เพลสหลัก หลังรัน mapgen/112_wyrmsleep_crater.lua)
-- ยิงเรย์วัดผิวจริงของปล่องมังกรหลับ + ตรวจของที่เฟสวาง (สเปก 2026-09-29-wyrmsleep-crater-design.md)
local CollectionService = game:GetService("CollectionService")

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

local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Include
params.FilterDescendantsInstances = { workspace.Terrain }
local function surf(x, z)
	local hit = workspace:Raycast(Vector3.new(x, 3000, z), Vector3.new(0, -2000, 0), params)
	return hit and hit.Position.Y, hit and hit.Material
end
local function at(d, deg)
	local r = math.rad(deg)
	local dx = W.AxisX * math.cos(r) - W.AxisZ * math.sin(r)
	local dz = W.AxisZ * math.cos(r) + W.AxisX * math.sin(r)
	return W.Center.X + dx * d, W.Center.Z + dz * d
end
local function band(name, points, want, tol, material)
	local worst, bad = 0, 0
	for _, pt in ipairs(points) do
		local y, m = surf(pt[1], pt[2])
		local off = y and math.abs(y - want) or math.huge
		if off > worst then worst = off end
		if off > tol or (material and m ~= material) then bad += 1 end
	end
	check(bad == 0, ("%s ≈ %d (เพี้ยนสุด %.2f · ผิด %d จาก %d)"):format(name, want, worst, bad, #points))
end

-- 1. ผิว
local pts = { { W.Center.X, W.Center.Z } }
for _, d in ipairs({ 40, 80, 100 }) do
	for deg = 30, 330, 60 do local x, z = at(d, deg); pts[#pts + 1] = { x, z } end
end
-- ค่าเผื่อ ±1: ผิว smooth terrain ที่เห็นเคยสูงกว่าที่เขียนราว 2 (วัด 2026-09-29) — เฟสต้องชดเชยแล้ว
band("ลานสู้", pts, W.FloorY, 1, Enum.Material.Basalt)
pts = {}
for deg = 30, 330, 40 do local x, z = at(126, deg); pts[#pts + 1] = { x, z } end
band("ท้องลาวา", pts, W.LavaBedY, 1, Enum.Material.CrackedLava)
-- ผิวลาวา Neon ต้องโผล่พ้นท้องลาวา ไม่งั้นจมอยู่ในดินมองไม่เห็น
local buried = 0
for _, pt in ipairs(pts) do
	local y = surf(pt[1], pt[2])
	if not y or y > W.LavaSurfaceY - 1 then buried += 1 end
end
check(buried == 0, ("ผิวลาวาโผล่พ้นท้องลาวา ≥ 1 สตัด (จม %d จาก %d)"):format(buried, #pts))
pts = {}
for deg = 35, 325, 30 do local x, z = at(W.RimRadius, deg); pts[#pts + 1] = { x, z } end
band("ขอบปล่อง", pts, W.RimY, 2)
local x, z = at(W.RimRadius, 0)
band("ช่องแยก", { { x, z } }, W.NotchY, 2)
x, z = at(124, 0)
band("สะพาน", { { x, z } }, W.FloorY, 1)
pts = { { W.PadCenter.X, W.PadCenter.Z } }
for deg = 0, 270, 90 do
	local r = math.rad(deg)
	pts[#pts + 1] = { W.PadCenter.X + math.cos(r) * 30, W.PadCenter.Z + math.sin(r) * 30 }
end
band("ลานจอด", pts, W.PadY, 1)
-- สถานีเรือเหาะ (Vehicle/Config) ต้องตกบนลานจอดที่ปาดไว้ ไม่งั้นเรือโผล่ในเนิน
local Vehicle = fresh(game.ReplicatedStorage.Vehicle.Config)
for _, s in ipairs(Vehicle.Presets.Arture) do
	if s.id == "WyrmsleepMooring" then
		band("เสาเรียก+จุดเรือโผล่", { { s.pos.X, s.pos.Z }, { s.spawn.X, s.spawn.Z } }, W.PadY, 1)
	end
end

-- 2. ทางเดินตามแกนไม่มีขั้นสูง
local worst, prev = 0, nil
for d = 0, W.PadDistance, 4 do
	x, z = at(d, 0)
	local y = surf(x, z)
	if prev and y and math.abs(y - prev) > worst then worst = math.abs(y - prev) end
	prev = y
end
check(worst <= 4, ("ทางเดินจากลานถึงลานจอด ขั้นสูงสุด %.2f ต่อ 4 สตัด (≤ 4)"):format(worst))

-- 3. หิมะละลายรอบปล่อง
local melted = 0
for deg = 30, 330, 40 do
	x, z = at(250, deg)
	local _, m = surf(x, z)
	if m and m ~= Enum.Material.Snow then melted += 1 end
end
check(melted >= 6, ("r250 ไม่ใช่หิมะ %d/8"):format(melted))

-- 4. ของที่เฟสวาง
local wyrm = workspace:FindFirstChild("WOLD") and workspace.WOLD:FindFirstChild("Wyrmsleep")
check(wyrm ~= nil, "มีโฟลเดอร์ WOLD.Wyrmsleep")
local lava, lavaBad, onBridge = 0, 0, 0
for _, p in ipairs(CollectionService:GetTagged("WOLD_Lava")) do
	if wyrm and p:IsDescendantOf(wyrm) then
		lava += 1
		if p.CanCollide or not p.CanQuery or not p.Anchored then lavaBad += 1 end
		if W.OnBridge(p.Position.X, p.Position.Z, 0) then onBridge += 1 end
	end
end
check(lava >= 100 and lavaBad == 0, ("ผิวลาวา %d ชิ้น (ชนได้/Query ไม่ได้ %d)"):format(lava, lavaBad))
check(onBridge == 0, ("ไม่มีลาวาทับสะพาน (ทับ %d)"):format(onBridge))
local smoke = wyrm and wyrm:FindFirstChild("Smoke")
check(smoke and smoke:IsA("Model") and smoke.ModelStreamingMode == Enum.ModelStreamingMode.Persistent
	and smoke:FindFirstChildWhichIsA("ParticleEmitter", true) ~= nil, "เสาควันเป็นโมเดล Persistent มีอนุภาค")
local rumble
if wyrm then
	for _, s in ipairs(wyrm:GetDescendants()) do
		if s:IsA("Sound") and s.SoundId == "rbxassetid://9112775165" then rumble = s end
	end
end
check(rumble and rumble.Looped and rumble.Playing, "เสียงคำรามวนลูปและเล่นอยู่")
local decor = wyrm and wyrm:FindFirstChild("Decor")
check(decor and decor:FindFirstChild("Skull") and decor:FindFirstChild("Ribcage"), "มีกะโหลกกับซี่โครง")
check(decor and decor.Skull:GetAttribute("Manual") == true, "กระดูกติด Manual")
local backup = game.ServerStorage:FindFirstChild("WyrmsleepBackup")
check(backup and backup:GetAttribute("Corner") ~= nil, "มีสำรองภูมิประเทศ + Corner")

return (fails == 0 and "PASS\n" or ("FAIL x%d\n"):format(fails)) .. table.concat(out, "\n")
