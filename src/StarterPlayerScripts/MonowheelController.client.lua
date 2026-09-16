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

Remotes.MonowheelRideChanged.OnClientEvent:Connect(function(riding)
	if riding then
		lockFirstPerson()
	else
		restore()
	end
end)

-- ตายคาจักรยาน: เซิร์ฟเวอร์เก็บจักรยานให้อยู่แล้ว แต่ถ้าสัญญาณหายไประหว่างนั้น กล้องจะค้าง
-- ปลดเองตอนได้ตัวละครใหม่ จึงไม่มีทางที่ผู้เล่นจะติดอยู่ในมุมมองบุคคลที่หนึ่งถาวร
player.CharacterAdded:Connect(restore)
