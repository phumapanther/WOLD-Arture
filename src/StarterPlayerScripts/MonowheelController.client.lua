-- MonowheelController: มุมมองบุคคลที่หนึ่งตลอดเวลาที่ขี่จักรยาน
--
-- **กล้องเป็นของไคลเอนต์เสมอ** เซิร์ฟเวอร์สั่งกล้องของเครื่องอื่นไม่ได้ ต่อให้เป็นเจ้าของจักรยานก็ตาม
-- เซิร์ฟเวอร์จึงทำได้แค่บอกว่า "ขึ้นแล้ว/ลงแล้ว" ส่วนการล็อกกล้องเป็นงานของไฟล์นี้
--
-- วิธีล็อก: ตั้ง CameraMinZoomDistance กับ CameraMaxZoomDistance ให้เท่ากันที่ 0.5 ผู้เล่นจะซูมออกไม่ได้เลย
-- ไม่ใช่แค่ CameraMode = LockFirstPerson อย่างเดียว เพราะโหมดนั้นล็อกเมาส์ไว้กลางจอด้วย ซึ่งจะทำให้
-- กดปุ่มอื่นบนจอไม่ได้ระหว่างขี่
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage:WaitForChild("Remotes"))

local player = Players.LocalPlayer

-- ค่าที่ผู้เล่นตั้งไว้เอง เก็บไว้คืนให้ตอนลง — ไม่ใช่เดาว่าทุกคนใช้ค่ามาตรฐาน
local saved = nil

local function lockFirstPerson()
	if saved then return end -- ขี่อยู่แล้ว อย่าเก็บค่าที่ถูกล็อกไว้แล้วทับของจริง
	saved = {
		mode = player.CameraMode,
		minZoom = player.CameraMinZoomDistance,
		maxZoom = player.CameraMaxZoomDistance,
	}
	player.CameraMinZoomDistance = 0.5
	player.CameraMaxZoomDistance = 0.5
	player.CameraMode = Enum.CameraMode.LockFirstPerson
end

local function restore()
	if not saved then return end
	-- คืนลำดับกลับด้าน: ปลดโหมดก่อน ไม่งั้นการคืนระยะซูมจะถูกโหมดที่ยังล็อกอยู่ดึงกลับมาที่ 0.5
	player.CameraMode = saved.mode
	player.CameraMinZoomDistance = saved.minZoom
	player.CameraMaxZoomDistance = saved.maxZoom
	saved = nil
end

-- ล้อจางลงระหว่างขี่ เฉพาะเครื่องคนขี่ (ผู้ใช้สั่ง 2026-10-02): กล้องบุคคลที่หนึ่งอยู่ในวงล้อ ขอบทองเหลือง (Rim)
-- กับยาง (Tyre ผิว Pebble) บังทางข้างหน้าเต็มจอ · LocalTransparencyModifier ตั้งจากไคลเอนต์ = เห็นเครื่องนี้เครื่องเดียว
-- คนอื่นยังเห็นล้อทึบปกติ · ผู้ใช้กำหนด: กงล้อเหลือง (Rim) จาง · ยาง (Tyre) ล่องหนไปเลย · ซี่ล้อ/เฟืองอยู่ข้างๆ ไม่บัง คงเดิม
local WHEEL_FADE = { Rim = 0.7, Tyre = 1 } -- ชื่อชิ้นจาก Monowheel.server build() · 1 = หายหมด
local riding = false
local faded = {} -- [part] = true

-- คันที่เรานั่งอยู่จริง (ดูจากที่นั่ง ไม่ใช่เจ้าของ) · StreamingEnabled: ถามใหม่ทุกรอบ ไม่เก็บไว้ตั้งแต่ตอนขึ้น
local function myWheel()
	local folder = workspace:FindFirstChild("WOLD_Monowheels")
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if not folder or not humanoid then return nil end
	for _, model in ipairs(folder:GetChildren()) do
		local seat = model:FindFirstChild("DriveSeat")
		if seat and seat:IsA("VehicleSeat") and seat.Occupant == humanoid then return model end
	end
	return nil
end

task.spawn(function()
	while true do
		task.wait(0.25)
		local model = riding and myWheel()
		if model then
			for _, p in ipairs(model:GetChildren()) do
				if p:IsA("BasePart") and WHEEL_FADE[p.Name] and not faded[p] then
					p.LocalTransparencyModifier = WHEEL_FADE[p.Name]
					faded[p] = true
				end
			end
		elseif not riding and next(faded) then
			for p in pairs(faded) do
				if p.Parent then p.LocalTransparencyModifier = 0 end
			end
			faded = {}
		end
	end
end)

Remotes.MonowheelRideChanged.OnClientEvent:Connect(function(isRiding)
	riding = isRiding and true or false
	if riding then
		lockFirstPerson()
	else
		restore()
	end
end)

-- ตายคาจักรยาน: เซิร์ฟเวอร์เก็บจักรยานให้อยู่แล้ว แต่ถ้าสัญญาณหายไประหว่างนั้น กล้องจะค้าง
-- ปลดเองตอนได้ตัวละครใหม่ จึงไม่มีทางที่ผู้เล่นจะติดอยู่ในมุมมองบุคคลที่หนึ่งถาวร
player.CharacterAdded:Connect(function()
	riding = false
	restore()
end)
