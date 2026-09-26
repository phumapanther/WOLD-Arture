-- BeastGait: ท่าเดินของสัตว์/มอนชุดคิท (ไก่ วัว ม้า หมูป่า หมาป่า ค้างคาว …) ขับจากเซิร์ฟเวอร์
--
-- โมเดลชุดคิทมีสคริปต์ชื่อ BeastGait ติดมาในตัว ซึ่งเขียน `Motor6D.Transform` ทุกเฟรม — **Transform
-- ไม่ส่งไปไคลเอนต์** ใน Studio เห็นขาขยับเพราะอยู่โปรเซสเดียวกัน แต่ในเกมจริงทุกตัวยืนแข็งทั้งที่เดินอยู่
-- โมดูลนี้ปิดสคริปต์นั้นแล้วทำแบบเดียวกันลง `C0` ซึ่งส่งไปไคลเอนต์ปกติ (บทเรียนเดียวกับขาแมงมุมใน MobMotion)
--
-- อ่านแอตทริบิวต์ชุดเดียวกับที่โมเดลมีอยู่แล้ว จึงไม่ต้องแก้โมเดล:
--   ข้อต่อ: Phase (เฟสในรอบก้าว) Swing (องศาสูงสุดตอนเดินเต็มความเร็ว) Fold (งอเพิ่มตอนยกขา)
--           Axis ("X" ก้าวหน้า-หลัง | "Y" | "Z") Idle (แกว่งเบาๆ ตอนยืนนิ่ง = หายใจ)
--   ตัวโมเดล: WalkSpeed StrideRate Bob BaseHipHeight WanderRadius WanderMin WanderMax
--
-- ใช้ได้กับโมเดลทุกขนาด: ระยะยกตัว (BaseHipHeight) กับ Bob คูณด้วย model:GetScale() ส่วนจังหวะก้าวหาร
-- ด้วยมัน — ตัวเล็กก้าวถี่ ตัวใหญ่ก้าวห่าง โดยไม่ต้องแก้แอตทริบิวต์ตอนย่อ/ขยาย
local RunService = game:GetService("RunService")

local BeastGait = {}

local Gaits = {} -- [model] = { humanoid, root, joints, phase, rate, bob, hip }

local function axisCF(axis, a)
	if axis == "Y" then return CFrame.Angles(0, a, 0) end
	if axis == "Z" then return CFrame.Angles(0, 0, a) end
	return CFrame.Angles(a, 0, 0)
end

-- เริ่มขับโมเดลนี้ opts.wander = true ให้เดินเล่นรอบจุดที่ยืนอยู่ตาม WanderRadius (ฝูงสัตว์ใช้ มอนไม่ใช้
-- เพราะมีสมองของตัวเอง) คืน true ถ้าโมเดลนี้เป็นชุดคิทที่มีข้อต่อให้ขับ
function BeastGait.Attach(model, opts)
	if Gaits[model] then return true end
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local root = model:FindFirstChild("HumanoidRootPart")
	if not humanoid or not root then return false end

	local script_ = model:FindFirstChild("BeastGait", true)
	if script_ and script_:IsA("BaseScript") then script_.Enabled = false end

	local joints = {}
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("Motor6D") and d:GetAttribute("Phase") then
			joints[#joints + 1] = { j = d, rest = d.C0 }
		end
	end
	if #joints == 0 and not script_ then return false end

	-- ระยะยกตัวเป็นของเรา ไม่ให้เอนจิ้นคำนวณเองจากโครงกระดูก (คำนวณได้ 0 กับโครงที่เชื่อมเอง แล้วตัวจมดิน)
	humanoid.AutomaticScalingEnabled = false
	local scale = model:GetScale()
	local gait = {
		humanoid = humanoid, root = root, joints = joints, phase = math.random() * math.pi * 2,
		rate = (model:GetAttribute("StrideRate") or 0.55) / scale,
		bob = (model:GetAttribute("Bob") or 0.12) * scale,
		hip = (model:GetAttribute("BaseHipHeight") or humanoid.HipHeight / scale) * scale,
	}
	Gaits[model] = gait
	humanoid.HipHeight = gait.hip

	if opts and opts.wander then
		local radius = model:GetAttribute("WanderRadius") or 0
		if radius > 0 then
			local home = root.Position
			-- วงเดินเล่นเป็นของ Attach ครั้งนี้เท่านั้น: Detach หรือ Attach ใหม่ (อุ้มแล้ววาง) = วงเก่าจบเอง
			-- (QA 2026-09-26: เดิมไม่เช็ค อุ้ม-วางทีละรอบ วงซ้อนกันเรื่อยๆ สัตว์เดินพล่านรอบจุดวางเก่า)
			task.spawn(function()
				while model.Parent and humanoid.Health > 0 and Gaits[model] == gait do
					task.wait(math.random(model:GetAttribute("WanderMin") or 4, model:GetAttribute("WanderMax") or 9))
					if Gaits[model] ~= gait then break end
					local a, r = math.random() * math.pi * 2, math.sqrt(math.random()) * radius
					humanoid:MoveTo(home + Vector3.new(math.cos(a) * r, 0, math.sin(a) * r))
					humanoid.MoveToFinished:Wait()
				end
			end)
		end
	end
	return true
end

function BeastGait.Detach(model)
	Gaits[model] = nil
end

RunService.Heartbeat:Connect(function(dt)
	for model, g in pairs(Gaits) do
		if not model.Parent then
			Gaits[model] = nil
		else
			local vel = g.root.AssemblyLinearVelocity
			local speed = Vector3.new(vel.X, 0, vel.Z).Magnitude
			-- ยืนนิ่งก็ยังขยับช้าๆ คือการหายใจ
			g.phase += dt * (speed > 0.4 and speed * g.rate + 1 or 1.1)
			local drive = math.clamp(speed / 8, 0, 1)
			for _, e in ipairs(g.joints) do
				local j = e.j
				local amp = (j:GetAttribute("Swing") or 0) * drive + (j:GetAttribute("Idle") or 0) * (1 - drive)
				local s = math.sin(g.phase + (j:GetAttribute("Phase") or 0))
				local a = s * amp
				local fold = j:GetAttribute("Fold")
				if fold then a += math.max(0, -s) * fold * drive end
				j.C0 = e.rest * axisCF(j:GetAttribute("Axis") or "X", a)
			end
			-- ตัวขึ้นลงสองครั้งต่อก้าว คือสิ่งที่ทำให้ดูมีน้ำหนัก
			g.humanoid.HipHeight = g.hip + math.sin(g.phase * 2) * g.bob * drive
		end
	end
end)

return BeastGait
