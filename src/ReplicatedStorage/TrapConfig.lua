-- TrapConfig: อาวุธกับดัก (เฟส 3 ข้อสอง · roadmap + ผู้ใช้อนุมัติสูตร 2026-09-27) — ข้อมูลล้วน เทสใน Edit ได้
--
-- ลักษณะคล้ายระเบิดมือ: **กดค้างปุ่มโจมตี = เล็ง** (เส้นโค้ง + จุดตก) **ปล่อย = เขวี้ยง** · **แตะสั้นๆ = วางหน้าเท้า** ·
-- ตกแล้วติดอยู่ตรงนั้น (พื้น/ผนัง) · มีมอน/คน/บอทเข้าระยะ = ทำงาน · เขวี้ยงโดนตัวใครตรงๆ = ทำงานทันที
-- **กับดักอันเดียว เปลี่ยนแค่กระสุน** (`meta.ammo` บนตัวกับดัก ทรงเดียวกับ `meta.skin`) · เขวี้ยงหนึ่งครั้ง = กระสุนหนึ่งนัด
-- โดนทั้งมอนและคน **ยกเว้นเพื่อนร่วมตี้/ร่วมทีม** · วางค้างได้ 3 อันต่อคน (อันที่ 4 = อันเก่าสุดหาย) · 60 วิไม่มีอะไรมาโดน = หายเอง
-- มองเห็นทุกคน (ไฟกะพริบสีตามกระสุน) · การ์ด (Blocking) ไม่กันกับดัก เพราะไม่ใช่ระยะประชิด
local TrapConfig = {}

TrapConfig.MaxPerOwner = 3
TrapConfig.LifeSeconds = 60
TrapConfig.ArmSeconds = 0.4 -- เพิ่งตก = ยังไม่ทำงานครู่หนึ่ง (กันตกใส่เท้าแล้วระเบิดทันทีแบบงงๆ)
TrapConfig.TriggerRadius = 4 -- เข้าใกล้เท่านี้ = ทำงาน
TrapConfig.EffectRadius = 7 -- ทำงานแล้วโดนทุกคนในวงนี้ (ยกเว้นพวกเดียวกัน)
TrapConfig.Cooldown = 0.8 -- เขวี้ยง/วางถี่สุดเท่านี้
TrapConfig.TapSeconds = 0.25 -- กดสั้นกว่านี้ = วางหน้าเท้า · นานกว่า = เล็งแล้วเขวี้ยง
TrapConfig.ChargeSeconds = 1.2 -- กดค้างนานเท่านี้ = แรงสุด
TrapConfig.MinSpeed = 28
TrapConfig.MaxSpeed = 70
-- แรงโน้มถ่วงของกับดักเอง (ของโลก 196 = เขวี้ยงสุดแรงได้แค่ ~25 สตัด) · 90 = ไกลสุดราว 50 สตัด
TrapConfig.Gravity = 90
TrapConfig.UpBiasDegrees = 18 -- เขวี้ยงเงยขึ้นจากทิศกล้องนิดหนึ่ง (โค้งสวยกว่าขว้างตรง)
TrapConfig.MinPitchDegrees = -20
TrapConfig.MaxPitchDegrees = 70
TrapConfig.MaxFlight = 3 -- วินาทีสูงสุดของวิถี · ไม่ชนอะไรเลย = ตกลงพื้นใต้จุดสุดท้าย
TrapConfig.DirectHitRadius = 2.5 -- วิถีผ่านใกล้ลำตัวเท่านี้ = โดนตรงๆ ทำงานทันที
TrapConfig.PlaceAhead = 2.5 -- แตะ = วางหน้าเท้าห่างเท่านี้
TrapConfig.Scale = 1.6 -- ขนาดกับดักที่ตกบนพื้นเทียบกับที่ถือในมือ

-- ความเร็วตอนปล่อยจากทิศกล้อง (`look`) กับแรง 0..1 — ไคลเอนต์ใช้วาดเส้นเล็ง เซิร์ฟเวอร์ใช้จริง สูตรเดียวกัน
function TrapConfig.Velocity(look, power)
	local flat = Vector3.new(look.X, 0, look.Z)
	if flat.Magnitude < 1e-3 then flat = Vector3.new(0, 0, -1) end
	flat = flat.Unit
	local unit = look.Magnitude > 1e-3 and look.Unit or flat
	local pitch = math.asin(math.clamp(unit.Y, -1, 1)) + math.rad(TrapConfig.UpBiasDegrees)
	pitch = math.clamp(pitch, math.rad(TrapConfig.MinPitchDegrees), math.rad(TrapConfig.MaxPitchDegrees))
	local speed = TrapConfig.MinSpeed + (TrapConfig.MaxSpeed - TrapConfig.MinSpeed) * math.clamp(power or 0, 0, 1)
	return (flat * math.cos(pitch) + Vector3.yAxis * math.sin(pitch)) * speed
end

-- ตำแหน่งบนวิถี ณ เวลา t (ไคลเอนต์วาดกับดักลอยตามเส้นนี้)
function TrapConfig.PositionAt(origin, velocity, t)
	return origin + velocity * t + Vector3.new(0, -TrapConfig.Gravity, 0) * (0.5 * t * t)
end

-- เดินวิถีทีละ 1/30 วิ ยิงเรย์ทีละช่วง · `probe(position)` (ไม่บังคับ) คืนเป้าที่วิถีผ่านใกล้ = โดนตรงๆ
-- คืน { position, normal, instance, time, points, direct } · ไม่ชนอะไรเลยใน MaxFlight = `fell = true`
function TrapConfig.Simulate(origin, velocity, params, probe)
	local dt = 1 / 30
	local points = { origin }
	local t, pos = 0, origin
	while t < TrapConfig.MaxFlight do
		local nextPos = TrapConfig.PositionAt(origin, velocity, t + dt)
		local step = nextPos - pos
		local hit = step.Magnitude > 1e-4 and workspace:Raycast(pos, step, params) or nil
		if probe then
			local target = probe(hit and hit.Position or nextPos)
			if target then
				points[#points + 1] = hit and hit.Position or nextPos
				return { position = hit and hit.Position or nextPos, normal = Vector3.yAxis, time = t + dt,
					points = points, direct = target }
			end
		end
		if hit then
			local frac = (hit.Position - pos).Magnitude / step.Magnitude
			points[#points + 1] = hit.Position
			return { position = hit.Position, normal = hit.Normal, instance = hit.Instance,
				time = t + dt * frac, points = points }
		end
		pos, t = nextPos, t + dt
		points[#points + 1] = pos
	end
	return { position = pos, normal = Vector3.yAxis, time = t, points = points, fell = true }
end

-- กระสุน 4 แบบ (โหมดหลัก) · สนามใช้ 3 แบบ (ไม่มีล้ม)
-- effect: slow = ช้าลง `factor` นาน `seconds` · stun = เซ (StatusEffects.Stagger — ขยับ/ตีไม่ได้ ไม่มีดาว) ·
-- knockdown = ล้ม · damage = ดาเมจ (คน/บอท `damage` · มอนในเกมหลัก `mobDamage`)
-- มอนไม่มีสถานะช้า/ล้ม → ใช้สตัน `mobStun` วิแทน (หยุดเดินครู่หนึ่ง)
TrapConfig.Ammo = {
	{ id = "TrapAmmo_Slow", kind = "slow", name = "หนืด", color = Color3.fromRGB(110, 230, 120), seconds = 3, factor = 0.5, mobStun = 1 },
	{ id = "TrapAmmo_Stun", kind = "stun", name = "ช็อต", color = Color3.fromRGB(120, 200, 255), seconds = 1.5, mobStun = 1.5 },
	{ id = "TrapAmmo_Knock", kind = "knockdown", name = "ลมกระแทก", color = Color3.fromRGB(245, 235, 170), seconds = 2, mobStun = 2 },
	{ id = "TrapAmmo_Blast", kind = "damage", name = "ระเบิด", color = Color3.fromRGB(255, 120, 70), damage = 35, mobDamage = 80 },
}
TrapConfig.AmmoById = {}
for order, a in ipairs(TrapConfig.Ammo) do
	a.order = order
	TrapConfig.AmmoById[a.id] = a
end

-- ตัวกับดักที่เป็นอาวุธ · กับดักของสนามสามขนาด = กับดักตัวเดียวกัน (รูปทรง/ท่าจับ "Trap") กระสุนติดมาเลย
-- `fixedAmmo` = ใช้กระสุนชนิดนี้เสมอ (สนาม) · ไม่มี = เลือกจาก meta.ammo หรือชนิดแรกที่มีในกระเป๋า (โหมดหลัก)
TrapConfig.Traps = {
	Trap = {},
	TrapSmall = { fixedAmmo = "TrapAmmo_Slow" },
	TrapMedium = { fixedAmmo = "TrapAmmo_Stun" },
	TrapLarge = { fixedAmmo = "TrapAmmo_Blast" },
}

function TrapConfig.IsTrap(id)
	return type(id) == "string" and TrapConfig.Traps[id] ~= nil
end

-- กระสุนที่กับดักชิ้นนี้จะใช้ · `slots` = ช่องกระเป๋า (ตาราง id/count) · คืน ammoDef, จำนวนที่มี
-- เลือกไว้ (`meta.ammo`) แต่หมดแล้ว = ไม่เดาเปลี่ยนชนิดเอง (คนเลือกหนืดไว้ต้องไม่ได้ระเบิดแทนโดยไม่รู้ตัว)
function TrapConfig.SelectedAmmo(trapId, meta, slots)
	local trap = TrapConfig.Traps[trapId]
	if not trap then return nil, 0 end
	local counts = {}
	for _, slot in pairs(slots or {}) do
		if type(slot) == "table" and TrapConfig.AmmoById[slot.id] then
			counts[slot.id] = (counts[slot.id] or 0) + (slot.count or 1)
		end
	end
	local chosen = trap.fixedAmmo or (type(meta) == "table" and TrapConfig.AmmoById[meta.ammo] and meta.ammo) or nil
	if not chosen then
		for _, a in ipairs(TrapConfig.Ammo) do
			if (counts[a.id] or 0) > 0 then chosen = a.id break end
		end
	end
	if not chosen then return nil, 0 end
	return TrapConfig.AmmoById[chosen], counts[chosen] or 0
end

return TrapConfig
