-- VehicleRepairController: ซ่อนปุ่ม "ซ่อมพาหนะ" จากทุกคนที่ไม่ใช่นักประดิษฐ์
--
-- **ต้องอยู่ฝั่งไคลเอนต์** — ปุ่มหนึ่งอันติดอยู่กับตัวรถและทุกคนที่เดินผ่านเห็นอันเดียวกัน ถ้าเซิร์ฟเวอร์
-- ปิด/เปิด `Enabled` มันจะเปลี่ยนให้ทุกคนพร้อมกัน จึงเป็นไปไม่ได้ที่จะให้คนหนึ่งเห็นและอีกคนไม่เห็น
-- การแก้ `Enabled` จากไคลเอนต์มีผลเฉพาะเครื่องตัวเอง ซึ่งเป็นวิธีเดียวที่ทำได้ และเป็นแบบเดียวกับที่
-- `GatherController` ใช้ซ่อนปุ่มเก็บของที่ผู้เล่นไม่มีเครื่องมือ
--
-- เซิร์ฟเวอร์ยังเช็กคลาสตอนกดอยู่เหมือนเดิม การซ่อนปุ่มเป็นเรื่องของสายตา ไม่ใช่ความปลอดภัย
local Players = game:GetService("Players")

local Config = require(game.ReplicatedStorage.Vehicle.Config)

local player = Players.LocalPlayer
local PROMPT_NAME = "VehicleRepairPrompt"

-- เซิร์ฟเวอร์เป็นคนตัดสินว่า "คันนี้สึกพอให้ซ่อมไหม" ผ่าน Enabled ส่วนไฟล์นี้ปิดทับได้อย่างเดียว
-- ห้ามเปิดปุ่มที่เซิร์ฟเวอร์ปิดไว้ จึงจำสถานะที่เซิร์ฟเวอร์ตั้งไว้ก่อนจะแตะมัน
local serverWants = {} -- [prompt] = boolean

local function isArchitect()
	for _, tier in ipairs({ "WOLD_ClassBasic", "WOLD_ClassAdvanced", "WOLD_ClassElite" }) do
		if player:GetAttribute(tier) == Config.RepairClass then return true end
	end
	return false
end

local function apply(prompt)
	local wanted = serverWants[prompt]
	if wanted == nil then return end
	prompt.Enabled = wanted and isArchitect()
end

local function watch(prompt)
	if serverWants[prompt] ~= nil then return end
	serverWants[prompt] = prompt.Enabled
	-- เซิร์ฟเวอร์เปลี่ยน Enabled ตอนรถสึก/ซ่อมเสร็จ ต้องจำค่าใหม่ไว้ ไม่งั้นการปิดของเราจะถูกอ่านเป็น
	-- "เซิร์ฟเวอร์สั่งปิด" แล้วปุ่มจะไม่กลับมาอีกเลยแม้เปลี่ยนเป็นนักประดิษฐ์
	prompt:GetPropertyChangedSignal("Enabled"):Connect(function()
		local now = prompt.Enabled
		-- ค่าที่เราเพิ่งตั้งเองไม่ใช่เจตนาของเซิร์ฟเวอร์ ข้ามไป
		if now == (serverWants[prompt] and isArchitect()) then return end
		serverWants[prompt] = now
		apply(prompt)
	end)
	apply(prompt)
end

-- **ถามซ้ำ ไม่ใช่ผูก event ครั้งเดียว** — เพลสนี้เปิด StreamingEnabled รถที่เรียกออกมาและปุ่มของมันมาถึง
-- ไคลเอนต์คนละรอบ ห่างกันเป็นวินาที (ดูกฎเหล็กใน CLAUDE.md) ลูปที่ถามใหม่เรื่อยๆ ไม่มีจังหวะให้แพ้
task.spawn(function()
	while true do
		local folder = workspace:FindFirstChild(Config.Folder)
		if folder then
			for _, model in ipairs(folder:GetChildren()) do
				for _, d in ipairs(model:GetDescendants()) do
					if d:IsA("ProximityPrompt") and d.Name == PROMPT_NAME then watch(d) end
				end
			end
		end
		task.wait(0.5)
	end
end)

-- เปลี่ยนอาชีพแล้วปุ่มต้องโผล่/หายทันที ไม่ต้องรอเรียกรถใหม่
for _, tier in ipairs({ "WOLD_ClassBasic", "WOLD_ClassAdvanced", "WOLD_ClassElite" }) do
	player:GetAttributeChangedSignal(tier):Connect(function()
		for prompt in pairs(serverWants) do
			if prompt.Parent then apply(prompt) end
		end
	end)
end
