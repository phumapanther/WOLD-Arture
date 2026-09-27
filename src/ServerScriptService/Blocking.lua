-- Blocking: ยกการ์ด / ปัดป้อง (แพรี่) ในสนาม PVP — เฟส 3 ข้อแรก (ผู้ใช้กำหนด 2026-09-27 · ตัวเลข ArenaConfig.Block)
--
-- ⚠️ **"การ์ด" (`PlayerCombat.state.guarding`) คือท่าถืออาวุธเตรียมตีจากคลิกซ้ายแรก ไม่กันอะไร** — ของใหม่ชื่อ "blocking"
-- ห้ามปนกัน
--
-- เซิร์ฟเวอร์ตัดสินทั้งหมด: ไคลเอนต์ส่งแค่ "ยก/ปล่อย" (`BlockGuard.server`) · เวลาเริ่มยกจดตอนเซิร์ฟได้รับ ·
-- ตอนดาเมจ **ระยะประชิด** จะลง (`PlayerCombat.resolveHit` คน→คน · `ArenaBots` บอท→คน) ถาม `Judge` → ปัด / ลด / เต็ม
-- (ช่วงจังหวะวัดที่เซิร์ฟ คนปิงสูงจะรู้สึกแคบกว่า — ข้อจำกัดที่รู้อยู่แล้วใน roadmap)
--
-- ส่วน "ตัดสินจังหวะ" เป็นฟังก์ชันข้อมูลล้วน (`Raise` / `JudgeState`) รับตารางสถานะกับเวลา เทสใน Edit ได้ (tests/blocking_test.lua)
local ArenaConfig = require(game.ReplicatedStorage.ArenaConfig)

local Blocking = {}

local States = {} -- [player] = { on, windowUntil, parried, lockUntil, lastWindowUntil, shield }

--------------------------------------------------------------------------------
-- ตัดสินจังหวะ (ข้อมูลล้วน)
--------------------------------------------------------------------------------

-- เริ่มยกการ์ดที่เวลา `now` · `shield` = ถือโล่ (ช่วงจังหวะกว้างกว่า)
-- ยกครั้งก่อนเปิดช่วงปัดไว้แล้วไม่มีอะไรมาโดน = ล็อกการปัดไป parryLock วิหลังช่วงนั้นจบ (กันกดรัว)
function Blocking.Raise(s, now, shield)
	local B = ArenaConfig.Block
	if s.lastWindowUntil and not s.parried then
		s.lockUntil = math.max(s.lockUntil or 0, s.lastWindowUntil + B.parryLock)
	end
	s.on = true
	s.shield = shield == true
	s.parried = false
	if now >= (s.lockUntil or 0) then
		s.windowUntil = now + (shield and B.shieldWindow or B.window)
		s.lastWindowUntil = s.windowUntil
	else
		-- ยังติดล็อก: ยกการ์ดลดดาเมจได้ แต่ครั้งนี้ไม่มีช่วงปัด (และไม่ต่อเวลาล็อก)
		s.windowUntil = nil
		s.lastWindowUntil = nil
	end
end

function Blocking.Lower(s)
	s.on = false
end

-- ดาเมจระยะประชิดมาถึงที่เวลา `now` → "parry" (ไม่เสียเลือด) | "block" + ตัวคูณดาเมจ | nil (ไม่ได้ยก = เต็ม)
function Blocking.JudgeState(s, now)
	if not s or not s.on then return nil, 1 end
	local B = ArenaConfig.Block
	if s.windowUntil and now <= s.windowUntil and not s.parried then
		s.parried = true
		return "parry", 0
	end
	return "block", 1 - (s.shield and B.shieldReduce or B.reduce)
end

--------------------------------------------------------------------------------
-- ต่อกับผู้เล่นจริง
--------------------------------------------------------------------------------

local function stateOf(player)
	local s = States[player]
	if not s then
		s = { on = false }
		States[player] = s
	end
	return s
end

function Blocking.IsBlocking(player)
	local s = States[player]
	return s ~= nil and s.on == true
end

-- แอตทริบิวต์ `WOLD_Blocking` บนตัว Player: PlayerMovement ใช้ลดความเร็ว (ห้ามเขียน WalkSpeed เอง) ·
-- ไคลเอนต์ทุกเครื่องใช้วาดท่ายกการ์ด (BlockController)
function Blocking.Set(player, on, shield)
	local s = stateOf(player)
	if on == s.on then return end
	if on then Blocking.Raise(s, os.clock(), shield) else Blocking.Lower(s) end
	player:SetAttribute("WOLD_Blocking", on or nil)
end

function Blocking.Judge(player)
	return Blocking.JudgeState(States[player], os.clock())
end

function Blocking.Clear(player)
	States[player] = nil
	if player.Parent then player:SetAttribute("WOLD_Blocking", nil) end
end

-- ประกายไฟ + เสียง ตรงจุดที่ปะทะ (ทุกคนเห็น/ได้ยิน) · ไม่มีข้อความกลางจอ (กติกาเฟส 1)
-- ประกายไฟทำด้วย ParticleEmitter เปิดสั้นๆ แล้วปิด (คุณสมบัติ replicate ไปทุกเครื่อง) ไม่ใช้ Emit() ฝั่งเซิร์ฟ
function Blocking.Fx(position, parried)
	local B = ArenaConfig.Block
	local holder = Instance.new("Part")
	holder.Name = "BlockFx"
	holder.Anchored, holder.CanCollide, holder.CanQuery, holder.CanTouch = true, false, false, false
	holder.Transparency = 1
	holder.Size = Vector3.new(0.2, 0.2, 0.2)
	holder.CFrame = CFrame.new(position)
	local att = Instance.new("Attachment")
	att.Parent = holder
	local sparks = Instance.new("ParticleEmitter")
	sparks.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	sparks.Color = ColorSequence.new(parried and Color3.fromRGB(255, 226, 120) or Color3.fromRGB(210, 210, 220))
	sparks.LightEmission = 1
	sparks.LightInfluence = 0
	sparks.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, parried and 0.55 or 0.35), NumberSequenceKeypoint.new(1, 0) })
	sparks.Lifetime = NumberRange.new(0.15, 0.35)
	sparks.Speed = NumberRange.new(parried and 14 or 8, parried and 26 or 14)
	sparks.SpreadAngle = Vector2.new(180, 180)
	sparks.Rate = parried and 220 or 90
	sparks.Drag = 4
	sparks.Parent = att
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 220, 140)
	light.Range = parried and 10 or 5
	light.Brightness = parried and 3 or 1
	light.Parent = holder
	local sound = Instance.new("Sound")
	sound.SoundId = parried and B.parrySound or B.blockSound
	sound.PlaybackSpeed = parried and B.parryPitch or B.blockPitch
	sound.Volume = parried and 0.9 or 0.5
	sound.RollOffMaxDistance = 80
	sound.Parent = holder
	holder.Parent = workspace
	sound:Play()
	task.delay(0.12, function() sparks.Enabled = false; light.Enabled = false end)
	task.delay(2, function() holder:Destroy() end)
end

return Blocking
