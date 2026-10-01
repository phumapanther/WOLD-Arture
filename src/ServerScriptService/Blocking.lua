-- Blocking: ยกการ์ด / ปัดป้อง (แพรี่) ในสนาม PVP — เฟส 3 ข้อแรก · **กดทีละครั้ง** (ผู้ใช้สั่ง 2026-10-01 · ตัวเลข ArenaConfig.Block)
--
-- ⚠️ **"การ์ด" (`PlayerCombat.state.guarding`) คือท่าถืออาวุธเตรียมตีจากคลิกซ้ายแรก ไม่กันอะไร** — ของใหม่ชื่อ "blocking"
-- ห้ามปนกัน
--
-- เซิร์ฟเวอร์ตัดสินทั้งหมด: ไคลเอนต์ส่งแค่ "กด" (`BlockGuard.server`) · เวลาเริ่มจดตอนเซิร์ฟได้รับ ·
-- กดหนึ่งครั้ง = ยก `windup` → กัน `active` (ช่วงแรก `window` ปัดสมบูรณ์ · ที่เหลือลดดาเมจ) → ลงเอง
-- ตอนดาเมจ **ระยะประชิด** จะลง (`PlayerCombat.resolveHit` คน→คน · `ArenaBots` บอท→คน) ถาม `Judge` → ปัด / ลด / เต็ม
-- (ช่วงจังหวะวัดที่เซิร์ฟ คนปิงสูงจะรู้สึกแคบกว่า — ข้อจำกัดที่รู้อยู่แล้วใน roadmap)
--
-- ส่วน "ตัดสินจังหวะ" เป็นฟังก์ชันข้อมูลล้วน (`Raise` / `JudgeState`) รับตารางสถานะกับเวลา เทสใน Edit ได้ (tests/blocking_test.lua)
local ArenaConfig = require(game.ReplicatedStorage.ArenaConfig)

local Blocking = {}

local States = {} -- [player] = { startAt, parryUntil, endAt, parried, shield }

--------------------------------------------------------------------------------
-- ตัดสินจังหวะ (ข้อมูลล้วน)
--------------------------------------------------------------------------------

-- กดยกการ์ดที่เวลา `now` · `shield` = ถือโล่ · คืน false = การ์ดรอบก่อนยังไม่ลง (กดไม่มีผล)
function Blocking.Raise(s, now, shield)
	if s.endAt and now < s.endAt then return false end
	local B = ArenaConfig.Block
	s.startAt = now + B.windup
	s.parryUntil = s.startAt + (shield and B.shieldWindow or B.window)
	s.endAt = s.startAt + B.active
	s.shield = shield == true
	s.parried = false
	return true
end

-- การ์ดถูกปล่อยก่อนเวลา (ล้ม มึน กลิ้ง เปลี่ยนเป็นสไน)
function Blocking.Lower(s)
	s.endAt = nil
end

-- กำลังยกหรือกันอยู่ (นับช่วง windup ด้วย — เดินช้า/ตีไม่ได้ตั้งแต่กด)
function Blocking.Up(s, now)
	return s ~= nil and s.endAt ~= nil and now < s.endAt
end

-- ดาเมจระยะประชิดมาถึงที่เวลา `now` → "parry" (ไม่เสียเลือด) | "block" + ตัวคูณดาเมจ | nil (ไม่ได้กัน = เต็ม)
-- ปัดได้ทีละครั้งต่อการกด: ไม้ที่สองในช่วงปัด = กันธรรมดา
function Blocking.JudgeState(s, now)
	if not s or not s.endAt or now < s.startAt or now > s.endAt then return nil, 1 end
	local B = ArenaConfig.Block
	if now <= s.parryUntil and not s.parried then
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
		s = {}
		States[player] = s
	end
	return s
end

function Blocking.IsBlocking(player)
	return Blocking.Up(States[player], os.clock())
end

-- แอตทริบิวต์ `WOLD_Blocking` บนตัว Player ตลอด windup+active: PlayerMovement ใช้ลดความเร็ว (ห้ามเขียน WalkSpeed เอง) ·
-- ไคลเอนต์ทุกเครื่องใช้วาดท่ายกการ์ด (BlockController) · ลบเองตอนการ์ดลง · คืน true = กดติด
function Blocking.Press(player, shield)
	local s = stateOf(player)
	if not Blocking.Raise(s, os.clock(), shield) then return false end
	player:SetAttribute("WOLD_Blocking", true)
	local endAt = s.endAt
	task.delay(endAt - os.clock(), function()
		-- กดใหม่หลังการ์ดลง = endAt ใหม่ · ถูกปล่อยก่อน = Drop ลบให้แล้ว
		if States[player] == s and s.endAt == endAt and player.Parent then
			player:SetAttribute("WOLD_Blocking", nil)
		end
	end)
	return true
end

function Blocking.Drop(player)
	local s = States[player]
	if s then Blocking.Lower(s) end
	if player.Parent then player:SetAttribute("WOLD_Blocking", nil) end
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
