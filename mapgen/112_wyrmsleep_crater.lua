-- 112_wyrmsleep_crater.lua: ปล่องมังกรหลับ บนยอดเขาหลักเหนือแอสตราเวล — **เพลสหลักเท่านั้น**
-- รัน: node tools/run-luau.js mapgen/112_wyrmsleep_crater.lua --no-lib
-- สเปก docs/superpowers/specs/2026-09-29-wyrmsleep-crater-design.md · เรขาคณิตทั้งหมดอยู่ ReplicatedStorage.WyrmsleepConfig
--
-- ลำดับ: สำรองเทอร์เรน → เขียน voxel (ReadVoxels/WriteVoxels · **ห้าม FillBlock** มันทับทุกอย่างในกรอบ) → รอ collision ใหม่
-- → ผิวลาวา (Part แท็ก WOLD_Lava) → ควัน/ประกาย/แสง/เสียง → กระดูก + ป้าย
--
-- รันซ้ำได้: ภูมิประเทศได้ผลเดิม (ด้านนอกยกอย่างเดียว) · ลาวา/เอฟเฟกต์ติด PhaseBuilt ลบแล้วสร้างใหม่ ·
-- กระดูก/ป้ายติด Manual **สร้างเฉพาะตอนยังไม่มี** ลากย้าย/ลบเองได้ รันซ้ำไม่ทับ
-- ⚠️ ไม่ถมโพรงถ้ำ (ผู้ใช้สั่ง) — เขียนหินตันแค่เปลือก ShellDepth ใต้ผิวใหม่ ลึกกว่านั้นไม่แตะ
-- ย้อนกลับ: workspace.Terrain:PasteRegion(game.ServerStorage.WyrmsleepBackup, <Corner>, true)
--   โดย <Corner> = แอตทริบิวต์ "Corner" บนตัว backup (หน่วย voxel)
local CollectionService = game:GetService("CollectionService")
local SS = game:GetService("ServerStorage")
local T = workspace.Terrain
local RES = 4
local AIR = Enum.Material.Air
-- ⚠️ ผิว smooth terrain ที่มองเห็นสูงกว่าระดับที่เติม voxel ราว 2 สตัด (วัดหลังรันรอบแรก 2026-09-29: +1.55..+2.22)
-- เฟสคิดทุกอย่างเป็น "ความสูงที่มองเห็น" แล้วลบค่านี้ตอนเขียน — ท้องลาวาจึงต่ำกว่าผิวลาวา Neon จริง ไม่จมหายในดิน
-- และคอลัมน์ที่ไม่เปลี่ยนความสูงได้ค่าเดิมเป๊ะ รันซ้ำไม่ทบ
local BIAS = 2

local function status(msg, done)
	local f = workspace:FindFirstChild("WOLD")
	if not f then f = Instance.new("Folder"); f.Name = "WOLD"; f.Parent = workspace end
	f:SetAttribute("Progress", msg)
	f:SetAttribute("Status", done and "done" or "running")
	print("[Wyrmsleep] " .. msg)
end

-- require ใน Edit แคชข้ามรอบ — โคลนแล้ว require ได้ของสดเสมอ
local function fresh(module)
	local copy = module:Clone()
	copy.Name = module.Name .. "_p" .. math.random(1, 1e9)
	copy.Parent = module.Parent
	local ok, result = pcall(require, copy)
	copy:Destroy()
	assert(ok, result)
	return result
end

local MAT = {
	floor = Enum.Material.Basalt,
	lava = Enum.Material.CrackedLava,
	wall = Enum.Material.Basalt,
	path = Enum.Material.Slate,
	pad = Enum.Material.Slate,
}
local BONE = Color3.fromRGB(214, 204, 176)
local BONE_DARK = Color3.fromRGB(160, 148, 120)
local LAVA_COLOR = Color3.fromRGB(255, 98, 24)

local function run()
	status("เริ่ม")
	local W = fresh(game.ReplicatedStorage.WyrmsleepConfig)
	local C = W.Center
	local root = workspace.WOLD

	----------------------------------------------------------------------------
	-- 1) สำรองเทอร์เรน (ครั้งแรกครั้งเดียว — รันซ้ำบนปล่องแล้วจะได้สำรองของปล่อง = ย้อนไม่ได้อีก)
	----------------------------------------------------------------------------
	local x0 = math.floor((C.X - W.WorkRadius) / RES) * RES
	local z0 = math.floor((C.Z - W.WorkRadius) / RES) * RES
	local SPAN = math.ceil(W.WorkRadius * 2 / RES) * RES + RES
	local Y0, Y1 = 2060, 2300
	if not SS:FindFirstChild("WyrmsleepBackup") then
		local corner = Vector3int16.new(x0 / RES, Y0 / RES, z0 / RES)
		local far = Vector3int16.new((x0 + SPAN) / RES, Y1 / RES, (z0 + SPAN) / RES)
		local backup = T:CopyRegion(Region3int16.new(corner, far))
		backup.Name = "WyrmsleepBackup"
		backup:SetAttribute("Corner", ("%d,%d,%d"):format(corner.X, corner.Y, corner.Z))
		backup.Parent = SS
		status("สำรองเทอร์เรนไว้ที่ ServerStorage.WyrmsleepBackup")
	else
		status("มีสำรองอยู่แล้ว (ไม่ถ่ายใหม่ กันทับของเดิม)")
	end

	----------------------------------------------------------------------------
	-- 2) ภูมิประเทศ ทีละก้อน
	----------------------------------------------------------------------------
	local CHUNK = 136
	local columns = 0
	for bx = x0, x0 + SPAN - 1, CHUNK do
		for bz = z0, z0 + SPAN - 1, CHUNK do
			local region = Region3.new(Vector3.new(bx, Y0, bz), Vector3.new(bx + CHUNK, Y1, bz + CHUNK)):ExpandToGrid(RES)
			local mats, occs = T:ReadVoxels(region, RES)
			local sx, sy, sz = mats.Size.X, mats.Size.Y, mats.Size.Z
			local base = region.CFrame.Position - region.Size / 2
			local touched = false
			for ix = 1, sx do
				for iz = 1, sz do
					local wx, wz = base.X + (ix - 0.5) * RES, base.Z + (iz - 0.5) * RES
					local topIy
					for iy = sy, 1, -1 do
						if mats[ix][iy][iz] ~= AIR and occs[ix][iy][iz] > 0 then topIy = iy break end
					end
					if topIy then
						local topMat = mats[ix][topIy][iz]
						local filled = base.Y + (topIy - 1) * RES + occs[ix][topIy][iz] * RES
						local orig = filled + BIAS -- ผิวที่มองเห็น
						local target, kind, d = W.Target(wx, wz, orig)
						if target then
							local mat = MAT[kind]
							if not mat then
								-- ด้านนอก: หิมะละลายเป็นบะซอลต์/หินชนวนในรัศมี MeltRadius ขอบสุ่มไม่เป็นเส้นตรง · ไกลกว่านั้นคงวัสดุเดิม
								if d + math.noise(wx / 45, wz / 45, 7.3) * 28 < W.MeltRadius then
									mat = math.noise(wx / 18, wz / 18, 2.1) > 0.15 and Enum.Material.Slate or Enum.Material.Basalt
								else
									mat = topMat
								end
							end
							if math.abs(target - orig) > 0.3 or topMat ~= mat then
								touched = true
								columns += 1
								local fill = target - BIAS -- ระดับเติม voxel ที่ให้ผิวที่เห็น = target
								local shellBottom = fill - W.ShellDepth
								local clearTop = math.max(filled, fill) + RES
								for iy = 1, sy do
									local yb = base.Y + (iy - 1) * RES
									if yb >= fill then
										if yb < clearTop then
											mats[ix][iy][iz] = AIR
											occs[ix][iy][iz] = 0
										end
									elseif yb + RES <= fill then
										if yb + RES > shellBottom then
											mats[ix][iy][iz] = mat
											occs[ix][iy][iz] = 1
										end
									else
										mats[ix][iy][iz] = mat
										occs[ix][iy][iz] = math.clamp((fill - yb) / RES, 0, 1)
									end
								end
							end
						end
					end
				end
			end
			if touched then T:WriteVoxels(region, RES, mats, occs) end
			task.wait()
		end
	end
	status(("เขียนภูมิประเทศแล้ว %d คอลัมน์ · รอ collision ใหม่"):format(columns))
	-- ⚠️ WriteVoxels คืนทันที แต่ collision mesh สร้างใหม่นอกเธรด — เรย์ในเฟรมเดียวกันยังชนผิวเก่า
	for _ = 1, 10 do task.wait() end

	local ground = RaycastParams.new()
	ground.FilterType = Enum.RaycastFilterType.Include
	ground.FilterDescendantsInstances = { T }
	local function groundAt(x, z)
		local hit = workspace:Raycast(Vector3.new(x, 3000, z), Vector3.new(0, -2000, 0), ground)
		return hit and hit.Position.Y or W.FloorY
	end

	----------------------------------------------------------------------------
	-- 3) โฟลเดอร์ + ล้างของ PhaseBuilt เดิม
	----------------------------------------------------------------------------
	local wyrm = root:FindFirstChild("Wyrmsleep")
	if not wyrm then
		wyrm = Instance.new("Folder")
		wyrm.Name = "Wyrmsleep"
		wyrm.Parent = root
	end
	for _, child in ipairs(wyrm:GetChildren()) do
		if child:GetAttribute("PhaseBuilt") and not child:GetAttribute("Manual") then child:Destroy() end
	end
	local function built(inst)
		inst:SetAttribute("PhaseBuilt", true)
		return inst
	end
	local function part(parent, name, size, cf, props)
		local p = Instance.new("Part")
		p.Name = name
		p.Size = size
		p.CFrame = cf
		p.Anchored = true
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		for k, v in pairs(props or {}) do p[k] = v end
		p.Parent = parent
		return p
	end

	----------------------------------------------------------------------------
	-- 4) ผิวลาวา: วงแหวน 120 ชิ้น Neon โปร่งนิดๆ เว้นสะพาน · ติดแท็ก WOLD_Lava ให้ Lava.server เผา
	----------------------------------------------------------------------------
	local lavaFolder = built(Instance.new("Folder"))
	lavaFolder.Name = "Lava"
	lavaFolder.Parent = wyrm
	local SEG = 120
	local rMid = (W.LavaInner + W.LavaOuter) / 2
	local width = W.LavaOuter - W.LavaInner
	local length = 2 * math.pi * W.LavaOuter / SEG + 0.4
	local lavaCount = 0
	for i = 0, SEG - 1 do
		local th = i * 2 * math.pi / SEG
		local px, pz = C.X + math.cos(th) * rMid, C.Z + math.sin(th) * rMid
		if not W.OnBridge(px, pz, length / 2 + 1) then
			local p = part(lavaFolder, "LavaSurface",
				Vector3.new(width, 1, length),
				CFrame.new(px, W.LavaSurfaceY - 0.5, pz) * CFrame.Angles(0, -th, 0),
				-- ทึบ: ชิ้นโปร่งแสงที่วางเหลื่อมกันทึบขึ้นตรงรอยซ้อนเป็นลายเส้นทั้งวง (เห็นในภาพรอบแรก)
				{ Material = Enum.Material.Neon, Color = LAVA_COLOR, Transparency = 0,
					CanCollide = false, CanTouch = false, CanQuery = true, CastShadow = false })
			CollectionService:AddTag(p, "WOLD_Lava")
			lavaCount += 1
		end
	end

	----------------------------------------------------------------------------
	-- 5) บรรยากาศ
	----------------------------------------------------------------------------
	-- เสาควัน: Persistent = ไม่ถูกสตรีมทิ้งตามระยะ มองเห็นจากทั่วแมพ
	local smoke = built(Instance.new("Model"))
	smoke.Name = "Smoke"
	smoke.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	smoke.Parent = wyrm
	local vent = part(smoke, "Vent", Vector3.new(30, 2, 30), CFrame.new(C.X, W.RimY + 10, C.Z),
		{ Transparency = 1, CanCollide = false, CanTouch = false, CanQuery = false, CastShadow = false })
	smoke.PrimaryPart = vent
	local plume = Instance.new("ParticleEmitter")
	plume.Name = "Plume"
	plume.Texture = "rbxasset://textures/particles/smoke_main.dds"
	plume.Color = ColorSequence.new(Color3.fromRGB(74, 66, 62), Color3.fromRGB(28, 26, 26))
	plume.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 24), NumberSequenceKeypoint.new(1, 110) })
	plume.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.4), NumberSequenceKeypoint.new(0.7, 0.6),
		NumberSequenceKeypoint.new(1, 1) })
	plume.Lifetime = NumberRange.new(16, 22)
	plume.Rate = 3
	plume.Speed = NumberRange.new(14, 22)
	plume.SpreadAngle = Vector2.new(12, 12)
	plume.Acceleration = Vector3.new(3, 1, 0)
	plume.RotSpeed = NumberRange.new(-10, 10)
	plume.Rotation = NumberRange.new(0, 360)
	plume.LightInfluence = 1
	plume.EmissionDirection = Enum.NormalId.Top
	plume.Parent = vent

	-- เสียงคำราม (ProSoundEffects "Earthquake Rumble 1" · PreloadAsync = Success แล้ว)
	local fx = built(Instance.new("Folder"))
	fx.Name = "FX"
	fx.Parent = wyrm
	local rumbleSource = part(fx, "Rumble", Vector3.new(2, 2, 2), CFrame.new(C.X, W.FloorY + 12, C.Z),
		{ Transparency = 1, CanCollide = false, CanTouch = false, CanQuery = false, CastShadow = false })
	local function loop(parent, id, volume, minD, maxD)
		local s = Instance.new("Sound")
		s.SoundId = id
		s.Volume = volume
		s.Looped = true
		s.RollOffMode = Enum.RollOffMode.InverseTapered
		s.RollOffMinDistance = minD
		s.RollOffMaxDistance = maxD
		s.Playing = true
		s.Parent = parent
		return s
	end
	loop(rumbleSource, "rbxassetid://9112775165", 0.55, 80, 420)

	-- ประกายไฟ + แสงส้ม 8 จุดรอบวงลาวา · 4 จุดมีเสียงลาวาเดือด
	for k = 0, 7 do
		local th = math.rad(k * 45 + 22.5)
		local px, pz = C.X + math.cos(th) * rMid, C.Z + math.sin(th) * rMid
		if not W.OnBridge(px, pz, 10) then
			local anchor = part(fx, "Ember", Vector3.new(4, 1, 4), CFrame.new(px, W.LavaSurfaceY + 0.5, pz),
				{ Transparency = 1, CanCollide = false, CanTouch = false, CanQuery = false, CastShadow = false })
			local em = Instance.new("ParticleEmitter")
			em.Texture = "rbxasset://textures/particles/sparkles_main.dds"
			em.Color = ColorSequence.new(Color3.fromRGB(255, 190, 80), Color3.fromRGB(255, 60, 20))
			em.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0) })
			em.LightEmission = 1
			em.Lifetime = NumberRange.new(2, 4)
			em.Rate = 6
			em.Speed = NumberRange.new(3, 8)
			em.SpreadAngle = Vector2.new(30, 30)
			em.Acceleration = Vector3.new(0, 4, 0)
			em.EmissionDirection = Enum.NormalId.Top
			em.Parent = anchor
			local light = Instance.new("PointLight")
			light.Color = Color3.fromRGB(255, 120, 40)
			light.Range = 45
			light.Brightness = 2.5
			light.Shadows = false
			light.Parent = anchor
			if k % 2 == 0 then loop(anchor, "rbxassetid://318794788", 0.35, 20, 110) end
		end
	end

	----------------------------------------------------------------------------
	-- 6) กระดูก (Manual — สร้างเฉพาะตอนยังไม่มี)
	----------------------------------------------------------------------------
	local decor = wyrm:FindFirstChild("Decor")
	if not decor then
		decor = Instance.new("Folder")
		decor.Name = "Decor"
		decor.Parent = wyrm
	end
	local function bone(parent, name, size, cf, collide, props)
		local p = part(parent, name, size, cf, { Material = Enum.Material.Limestone, Color = BONE, CanCollide = collide })
		for k, v in pairs(props or {}) do p[k] = v end
		return p
	end
	-- ทรงกระบอกจาก a ถึง b (แกนของ Cylinder คือแกน X ของตัวมันเอง)
	local function rod(parent, name, a, b, radius, collide, color)
		local cf = CFrame.lookAt((a + b) / 2, b) * CFrame.Angles(0, math.rad(90), 0)
		return bone(parent, name, Vector3.new((b - a).Magnitude, radius * 2, radius * 2), cf, collide,
			{ Shape = Enum.PartType.Cylinder, Color = color or BONE })
	end
	local axis = Vector3.new(W.AxisX, 0, W.AxisZ)
	local side = Vector3.new(-W.AxisZ, 0, W.AxisX)
	local function onGround(v) return Vector3.new(v.X, groundAt(v.X, v.Z), v.Z) end

	-- กะโหลกมังกร: ฝั่งตรงข้ามทางเข้า หันหน้าหาสะพาน ครึ่งจมพื้น
	if not decor:FindFirstChild("Skull") then
		local m = Instance.new("Model")
		m.Name = "Skull"
		local s = onGround(C - axis * 80)
		local F = CFrame.lookAt(s, s + axis) -- -Z ของเฟรม = หันไปทางสะพาน
		local cranium = bone(m, "Cranium", Vector3.new(16, 16, 16), F * CFrame.new(0, 5, 4), true,
			{ Shape = Enum.PartType.Ball })
		bone(m, "Brow", Vector3.new(15, 4, 8), F * CFrame.new(0, 10, -1), true)
		bone(m, "Snout", Vector3.new(9, 6, 18), F * CFrame.new(0, 4.5, -12), true)
		bone(m, "NoseRidge", Vector3.new(5, 2, 14), F * CFrame.new(0, 8, -11), true, { Color = BONE_DARK })
		bone(m, "Jaw", Vector3.new(8, 2.5, 17), F * CFrame.new(0, 1, -11) * CFrame.Angles(math.rad(-6), 0, 0), true)
		for _, sx in ipairs({ -1, 1 }) do
			bone(m, "Socket", Vector3.new(4.5, 4.5, 4.5), F * CFrame.new(sx * 4.2, 9, -3.5), false,
				{ Shape = Enum.PartType.Ball, Color = Color3.fromRGB(40, 22, 18) })
			bone(m, "Ember", Vector3.new(1.8, 1.8, 1.8), F * CFrame.new(sx * 4.4, 9, -5.2), false,
				{ Shape = Enum.PartType.Ball, Material = Enum.Material.Neon, Color = Color3.fromRGB(150, 26, 16),
					Transparency = 0.35 })
			local h0 = (F * CFrame.new(sx * 6, 11, 6)).Position
			local h1 = (F * CFrame.new(sx * 9, 15, 13)).Position
			local h2 = (F * CFrame.new(sx * 10, 17.5, 21)).Position
			rod(m, "Horn", h0, h1, 1.7, false, BONE_DARK)
			rod(m, "Horn", h1, h2, 1.1, false, BONE_DARK)
			for k = 0, 4 do
				bone(m, "Tooth", Vector3.new(0.8, 2.2, 0.8),
					F * CFrame.new(sx * 3.8, 2.6, -6 - k * 3) * CFrame.Angles(0, 0, math.rad(sx * 8)), false)
			end
		end
		m.PrimaryPart = cranium
		m:SetAttribute("Manual", true)
		m.Parent = decor
	end

	-- ซี่โครง: กระดูกสันหลังยกสูง 16 ซี่โครง 6 คู่โค้งลงถึงพื้นสองข้าง (เดินลอดได้) + หางเลื้อยต่อบนพื้น
	if not decor:FindFirstChild("Ribcage") then
		local m = Instance.new("Model")
		m.Name = "Ribcage"
		local mid = C + side * 70
		local H, SPREAD = 16, 12
		local spinePts = {}
		for k = -3, 3 do
			local g = onGround(mid + axis * (k * 6.5))
			spinePts[#spinePts + 1] = g + Vector3.new(0, H, 0)
		end
		for k = 1, #spinePts - 1 do
			local v = rod(m, "Spine", spinePts[k], spinePts[k + 1], 1.8, true)
			if k == 1 then m.PrimaryPart = v end
		end
		for k = 1, #spinePts do
			bone(m, "Spike", Vector3.new(1, 3, 1), CFrame.new(spinePts[k] + Vector3.new(0, 2.6, 0)), false, { Color = BONE_DARK })
		end
		for k = 2, #spinePts - 1 do
			for _, s in ipairs({ -1, 1 }) do
				local prev = spinePts[k]
				for step = 1, 5 do
					local t = step / 5 * math.pi / 2
					local g = onGround(spinePts[k] + side * s * SPREAD * math.sin(t))
					local pt = Vector3.new(g.X, g.Y - 1.5 + (spinePts[k].Y - g.Y + 1.5) * math.cos(t), g.Z)
					rod(m, "Rib", prev, pt, 1.1, true)
					prev = pt
				end
			end
		end
		-- หาง: กระดูกข้อเล็กๆ ลาดลงพื้นแล้วเลื้อยต่อ
		local tailStart = spinePts[#spinePts]
		local prev = tailStart
		for k = 1, 8 do
			local g = onGround(mid + axis * (3 * 6.5 + k * 4) + side * math.sin(k * 0.6) * 3)
			local pt = Vector3.new(g.X, g.Y + math.max(0.5, H * (1 - k / 3)), g.Z)
			rod(m, "Tail", prev, pt, math.max(0.5, 1.5 - k * 0.12), false)
			prev = pt
		end
		m:SetAttribute("Manual", true)
		m.Parent = decor
	end

	-- กระดูกยาวกับกรงเล็บ กระจายรอบลาน (เดินทะลุได้)
	if not decor:FindFirstChild("Scattered") then
		local m = Instance.new("Model")
		m.Name = "Scattered"
		local rng = Random.new(29)
		local placed = 0
		for _ = 1, 40 do
			if placed >= 4 then break end
			local th = rng:NextNumber(0, math.pi * 2)
			local r = rng:NextNumber(35, 95)
			local p = Vector3.new(C.X + math.cos(th) * r, 0, C.Z + math.sin(th) * r)
			local rel = p - C
			local a = rel:Dot(axis)
			local far = (p - (C - axis * 80)).Magnitude > 30 and (p - (C + side * 70)).Magnitude > 32
			if (a < 0 or math.abs(rel:Dot(side)) > 20) and far then
				local g = onGround(p)
				local dir = Vector3.new(math.cos(th + 1.3), 0, math.sin(th + 1.3))
				local a0, a1 = g + Vector3.new(0, 0.6, 0) - dir * 7, g + Vector3.new(0, 0.6, 0) + dir * 7
				rod(m, "LongBone", a0, a1, 1.1, false)
				bone(m, "Knob", Vector3.new(3.2, 3.2, 3.2), CFrame.new(a0), false, { Shape = Enum.PartType.Ball })
				bone(m, "Knob", Vector3.new(3.2, 3.2, 3.2), CFrame.new(a1), false, { Shape = Enum.PartType.Ball })
				placed += 1
			end
		end
		-- กรงเล็บโค้งสามท่อน
		local g = onGround(C - axis * 40 + side * 45)
		local c0, c1 = g + Vector3.new(0, 0.5, 0), g + Vector3.new(0, 5, 3)
		local c2, c3 = g + Vector3.new(0, 8, 8), g + Vector3.new(0, 7, 13)
		rod(m, "Claw", c0, c1, 1.4, false, BONE_DARK)
		rod(m, "Claw", c1, c2, 1.0, false, BONE_DARK)
		rod(m, "Claw", c2, c3, 0.6, false, BONE_DARK)
		m:SetAttribute("Manual", true)
		m.Parent = decor
	end

	----------------------------------------------------------------------------
	-- 7) ป้ายหน้าช่องแยก (Manual)
	----------------------------------------------------------------------------
	if not decor:FindFirstChild("Sign") then
		local m = Instance.new("Model")
		m.Name = "Sign"
		-- บนลานจอดข้างปากทางขึ้นช่องแยก (ช่วงระหว่างขอบกับลานจอดเป็นหุบ ผนังสองข้างสูง 30-50 ป้ายบนนั้นจะลอยพ้นสายตา)
		local at = W.AtAxis(W.PadDistance - W.PadRadius + 6, W.PathHalf + 4)
		local y = groundAt(at.X, at.Z)
		local faceOut = CFrame.lookAt(Vector3.new(at.X, y + 6, at.Z), Vector3.new(at.X, y + 6, at.Z) + axis)
		for _, sx in ipairs({ -1, 1 }) do
			part(m, "Post", Vector3.new(0.8, 8, 0.8), faceOut * CFrame.new(sx * 5.2, -2, 0),
				{ Material = Enum.Material.Wood, Color = Color3.fromRGB(70, 50, 36) })
		end
		local board = part(m, "Board", Vector3.new(12, 4.2, 0.5), faceOut * CFrame.new(0, 1.2, 0),
			{ Material = Enum.Material.Wood, Color = Color3.fromRGB(86, 60, 40) })
		local gui = Instance.new("SurfaceGui")
		gui.Face = Enum.NormalId.Front
		gui.PixelsPerStud = 40
		gui.LightInfluence = 0
		gui.Parent = board
		local title = Instance.new("TextLabel")
		title.BackgroundTransparency = 1
		title.Size = UDim2.fromScale(1, 0.62)
		title.Font = Enum.Font.GothamBold
		title.TextScaled = true
		title.TextColor3 = Color3.fromRGB(255, 196, 120)
		title.Text = "🔥 " .. W.Name
		title.Parent = gui
		local sub = Instance.new("TextLabel")
		sub.BackgroundTransparency = 1
		sub.Position = UDim2.fromScale(0, 0.62)
		sub.Size = UDim2.fromScale(1, 0.3)
		sub.Font = Enum.Font.Gotham
		sub.TextScaled = true
		sub.TextColor3 = Color3.fromRGB(230, 214, 190)
		sub.Text = "ลานบอส · ระวังลาวา"
		sub.Parent = gui
		m.PrimaryPart = board
		m:SetAttribute("Manual", true)
		m.Parent = decor
	end

	status(("เสร็จ: ภูมิประเทศ %d คอลัมน์ · ลาวา %d ชิ้น · ศูนย์ปล่อง %.0f, %.0f"):format(columns, lavaCount, C.X, C.Z), true)
end

local ok, err = pcall(run)
if not ok then
	local f = workspace:FindFirstChild("WOLD")
	if f then f:SetAttribute("Status", "error: " .. tostring(err)) end
	warn("[Wyrmsleep] " .. tostring(err))
end
