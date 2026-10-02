-- AutoWalkController: กด T เดินอัตโนมัติตามเส้นนำทางของหมุด (ผู้ใช้สั่ง 2026-09-29)
-- มือถือ (2026-10-02): ป้ายกลางบนเป็น **ปุ่มแตะ** เริ่ม/หยุด · แตะจอยซ้ายล่าง = เลิกเดินเอง (เท่ากับกด WASD บนคอม)
--
-- เดินความเร็วปกติ กด Shift ค้างวิ่งเองได้ (ระบบวิ่งเดิมทำงานเพราะนี่คือการเดินปกติ ไม่ใช่การย้ายตัว) · หยุดเมื่อ:
-- กด T อีกครั้ง · กด WASD/ลูกศร · ถึงหมุด/หมุดถูกลบ · ตาย/ล้ม/นั่ง · กติกาเลือกจุด `AutoWalk` (เทส `auto_walk_test`)
-- เส้นทางมาจาก `Navigation.Active` (ตัวที่ SocialController ปักหมุด) ซึ่งคำนวณใหม่เองระหว่างทาง ตัวนี้แค่เดินตามเส้นล่าสุด
-- ⚠️ **ปุ่ม T ของ ProximityPrompt (เทรดของพ่อค้า/เชฟ) ที่โชว์อยู่บนจอเป็นเจ้าของ T ก่อน** — กติกาเดียวกับ F ของ GatherController
-- ⚠️ เดินด้วย `Humanoid:Move` ทุกเฟรม **หลัง** ControlModule (มันเรียก Move ทุกเฟรมด้วยค่าจากคีย์บอร์ด ซึ่งเป็นศูนย์ตอนไม่กด
-- อะไร) ผูกลำดับ Input + 1 จึงเขียนทับได้เสมอ · ไม่ใช้ MoveTo (หมดเวลา 8 วิ และแย่งกับ ControlModule)
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

while workspace:GetAttribute("IsLobby") == nil do task.wait(0.2) end
if workspace:GetAttribute("IsLobby") == true then return end
if workspace:GetAttribute("ArenaMode") == true then return end

local Navigation = require(ReplicatedStorage.Navigation)
local NavigationConfig = require(ReplicatedStorage.NavigationConfig)
local AutoWalk = require(ReplicatedStorage.AutoWalk)
local Remotes = require(ReplicatedStorage:WaitForChild("Remotes"))

local player = Players.LocalPlayer
local TOGGLE = Enum.KeyCode.T
local MANUAL = {
	[Enum.KeyCode.W] = true, [Enum.KeyCode.A] = true, [Enum.KeyCode.S] = true, [Enum.KeyCode.D] = true,
	[Enum.KeyCode.Up] = true, [Enum.KeyCode.Down] = true, [Enum.KeyCode.Left] = true, [Enum.KeyCode.Right] = true,
}
local STUCK_SECONDS = 1.2 -- ขยับไม่ถึง 1 สตัดนานเท่านี้ = กระโดดหนึ่งที (ขอบหิน/รากไม้ที่เส้นทางไม่ได้ติดป้ายกระโดด)

local function toast(text)
	local channel = ReplicatedStorage:FindFirstChild("WOLD_Toast")
	if channel then channel:Fire(text) end
end

-- ป้ายกลางบน: "กด T เดินอัตโนมัติ" ตอนมีหมุด · "เดินอัตโนมัติ — กด T เพื่อหยุด" ตอนเดิน
local gui = Instance.new("ScreenGui")
gui.Name = "WOLD_AutoWalk"
gui.ResetOnSpawn = false
gui.DisplayOrder = 5
gui.Parent = player:WaitForChild("PlayerGui")
-- ปุ่ม ไม่ใช่ป้าย: มือถือแตะเริ่ม/หยุดได้ (คอมกด T เหมือนเดิม) · มือถือสูงขึ้นให้นิ้วแตะถนัด
local touch = UserInputService.TouchEnabled
local label = Instance.new("TextButton")
label.AutoButtonColor = false
label.AnchorPoint = Vector2.new(0.5, 0)
-- y 112 ใต้แถบประกาศข้ามเซิร์ฟ (y 78) และใต้แถบฟาร์มออโต้ (y 74-104 ซึ่งเป็นปุ่มแตะหยุดเหมือนกัน ห้ามซ้อน) ·
-- กลางล่างเต็มแล้ว (ช่องลัด EXP บัพ ปุ่มเกาะ) · มือถือ: ข้อความเด้งเริ่ม y 118 อาจบังบางส่วนชั่วครู่ แต่เป็นป้าย (ไม่ Active)
-- นิ้วแตะทะลุถึงปุ่มนี้ได้
label.Position = UDim2.new(0.5, 0, 0, 112)
label.Size = UDim2.fromOffset(300, touch and 40 or 26)
label.BackgroundColor3 = Color3.fromRGB(20, 18, 14)
label.BackgroundTransparency = 0.35
label.Font = Enum.Font.GothamBold
label.TextSize = touch and 16 or 14
label.TextColor3 = Color3.fromRGB(240, 226, 190)
label.Visible = false
label.Parent = gui
local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(1, 0)
corner.Parent = label

-- บอกทางที่เครื่องนี้ใช้ได้จริง (ทรงเดียวกับแถบฟาร์มออโต้ของ GatherController)
local HOW = UserInputService.KeyboardEnabled and (touch and "กด T หรือแตะ " or "กด T ") or "แตะ"

local shownT = {}
ProximityPromptService.PromptShown:Connect(function(prompt)
	if prompt.KeyboardKeyCode == TOGGLE then shownT[prompt] = true end
end)
ProximityPromptService.PromptHidden:Connect(function(prompt) shownT[prompt] = nil end)
local function anyTPrompt()
	for prompt in pairs(shownT) do
		if prompt.Parent and prompt.Enabled then return true end
		shownT[prompt] = nil
	end
	return false
end

local walking = false
local route, index = nil, nil
local lastDestination = nil
local stuckFrom, stuckAt = nil, 0

local function humanoidAndRoot()
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return humanoid, root
end

local function stop(text)
	if not walking then return end
	walking = false
	Remotes.SetAutoWalking:FireServer(false)
	route, index = nil, nil
	local humanoid = humanoidAndRoot()
	if humanoid then humanoid:Move(Vector3.zero, false) end
	if text then toast(text) end
end

local function start()
	local nav = Navigation.Active
	if not (nav and nav:HasDestination()) then
		return toast("ปักหมุดบนแผนที่ก่อน (กด M) แล้วกด T เพื่อเดินอัตโนมัติ")
	end
	walking = true
	Remotes.SetAutoWalking:FireServer(true) -- เร็วเท่าฟาร์มออโต้ (PlayerMovement · 20) · Shift ยังวิ่งเต็มได้
	route, index = nil, nil
	lastDestination = nav.destination
	stuckFrom, stuckAt = nil, os.clock()
end

label.Activated:Connect(function()
	if walking then stop() else start() end
end)

-- มือถือ/จอย: แตะจอยซ้ายล่าง (ครึ่งซ้าย ต่ำกว่า 40% ของจอ — ปุ่มนี้อยู่บนจึงไม่โดน) หรือดันก้านซ้ายจอย = บังคับเอง เลิกเดินให้
-- ⚠️ ต้องไม่กรอง gameProcessed: จอยมือถือรับนิ้วผ่าน ContextActionService ทุกครั้งเป็น processed = true (บทเรียน MovementController)
UserInputService.TouchStarted:Connect(function(input)
	if not walking then return end
	local camera = workspace.CurrentCamera
	local size = camera and camera.ViewportSize
	if size and input.Position.X < size.X / 2 and input.Position.Y > size.Y * 0.4 then stop() end
end)
UserInputService.InputChanged:Connect(function(input)
	if walking and input.KeyCode == Enum.KeyCode.Thumbstick1
		and Vector2.new(input.Position.X, input.Position.Y).Magnitude > 0.5 then
		stop()
	end
end)

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end -- พิมพ์แชท/ช่องข้อความ
	if input.KeyCode == TOGGLE then
		if anyTPrompt() then return end -- ปุ่มเทรดบนจอเป็นเจ้าของ T
		if walking then stop() else start() end
	elseif walking and MANUAL[input.KeyCode] then
		stop() -- จับบังคับเอง = เลิกเดินให้ ไม่ต้องบอก (คนกดรู้อยู่แล้ว)
	end
end)

RunService:BindToRenderStep("WOLD_AutoWalk", Enum.RenderPriority.Input.Value + 1, function()
	local nav = Navigation.Active
	local hasPin = nav ~= nil and nav:HasDestination()
	label.Visible = walking or hasPin
	label.Text = walking and ("🚶 เดินอัตโนมัติ — %sเพื่อหยุด"):format(HOW) or ("🚶 %sเพื่อเดินอัตโนมัติไปหมุด"):format(HOW)
	if not walking then return end

	if not hasPin then
		-- หมุดหาย = ถึงแล้ว (Navigation ล้างเอง) หรือผู้เล่นลบหมุด
		local _, root = humanoidAndRoot()
		local arrived = root and lastDestination
			and (root.Position - lastDestination).Magnitude <= NavigationConfig.ArriveDistance + 4
		return stop(arrived and "ถึงจุดหมายแล้ว" or nil)
	end
	lastDestination = nav.destination

	local humanoid, root = humanoidAndRoot()
	if not humanoid or not root or humanoid.Health <= 0 then return stop() end
	if player:GetAttribute("WOLD_Downed") then return stop("หยุดเดินอัตโนมัติ (ล้มอยู่)") end
	if humanoid.Sit then return stop() end

	-- เส้นใหม่ (คำนวณใหม่ระหว่างทาง) = หาจุดเริ่มใหม่จากตำแหน่งตอนนี้
	if nav.route ~= route then
		route = nav.route
		index = nil
	end
	if not route then return end -- ยังไม่มีเส้น รอรอบคำนวณ
	index = AutoWalk.NextIndex(route, root.Position, index)
	if not index then
		humanoid:Move(Vector3.zero, false) -- ปลายท่อนนี้ รอ Navigation คำนวณท่อนต่อ
		return
	end
	local point = route[index]
	humanoid:Move(AutoWalk.Direction(root.Position, point.pos), false)
	if AutoWalk.ShouldJump(point, root.Position) then humanoid.Jump = true end

	-- ติดขอบ: ตำแหน่งแทบไม่ขยับ = กระโดดหนึ่งที
	local now = os.clock()
	if not stuckFrom or (root.Position - stuckFrom).Magnitude > 1 then
		stuckFrom, stuckAt = root.Position, now
	elseif now - stuckAt > STUCK_SECONDS then
		humanoid.Jump = true
		stuckFrom, stuckAt = root.Position, now
	end
end)

player.CharacterAdded:Connect(function() stop() end)
