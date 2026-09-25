-- IslandPetController: ปุ่ม "วางลง" ของคนที่อุ้มหมา/แมวอยู่ + หัวใจลอยตอนลูบหัว (ผู้ใช้สั่ง 2026-09-25)
--
-- หัวใจ: เซิร์ฟเวอร์ยิง Remotes.IslandPetHearts ถึงทุกเครื่อง แต่ละเครื่องวาดเอง (ทุกคนรอบๆ เห็น)
-- เป็นอีโมจิบน BillboardGui ไม่ใช่ ParticleEmitter เพราะไม่มีรูปหัวใจที่ตรวจแล้วว่าผ่านการตรวจของ Roblox
--
-- ระหว่างอุ้ม ปุ่ม E/F บนตัวสัตว์ถูกปิด (ไม่งั้นมันลอยอยู่หน้าคนอุ้มตลอดทาง) ทางวางลงจึงย้ายมาอยู่ที่นี่:
-- คีย์ F หรือแตะปุ่มบนจอ (มือถือ) → Remotes.IslandPetDrop · รู้ว่ากำลังอุ้มจากแอตทริบิวต์ CarriedBy บนตัวสัตว์
-- ลูปถามใหม่ทุก 0.25 วิ ไม่ผูกครั้งเดียว (กฎเหล็ก StreamingEnabled)
while workspace:GetAttribute("IsLobby") == nil do task.wait() end
if workspace:GetAttribute("IslandMode") ~= true then return end

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ContextActionService = game:GetService("ContextActionService")
local Remotes = require(game.ReplicatedStorage.Remotes)
local Responsive = require(game.ReplicatedStorage.UI.Responsive)

local player = Players.LocalPlayer

local gui = Instance.new("ScreenGui")
gui.Name = "WOLD_PetCarry"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 30
gui.Enabled = false
gui.Parent = player:WaitForChild("PlayerGui")

local button = Instance.new("TextButton")
button.AnchorPoint = Vector2.new(0.5, 1)
button.Position = UDim2.new(0.5, 0, 1, -160) -- เหนือช่องของใช้ 6 ช่องของ HUD
button.Size = UDim2.new(0, 170, 0, 40)
button.BackgroundColor3 = Color3.fromRGB(24, 22, 28)
button.BackgroundTransparency = 0.2
button.BorderSizePixel = 0
button.Font = Enum.Font.GothamBold
button.TextSize = 16
button.TextColor3 = Color3.fromRGB(236, 232, 224)
button.Text = "🐾 วางลง (F)"
button.Parent = gui
local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 10)
corner.Parent = button
local edge = Instance.new("UIStroke")
edge.Color = Color3.fromRGB(196, 150, 60)
edge.Thickness = 1.5
edge.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
edge.Parent = button
Responsive.Scale(button, 0.55)

local function drop()
	Remotes.IslandPetDrop:FireServer()
end
button.Activated:Connect(drop)

local function carrying()
	local island = workspace:FindFirstChild("WOLD_Island")
	local placed = island and island:FindFirstChild("Placed")
	if not placed then return false end
	for _, model in ipairs(placed:GetChildren()) do
		if model:GetAttribute("CarriedBy") == player.UserId then return true end
	end
	return false
end

-- หัวใจ ---------------------------------------------------------------------------

local HEARTS = { "❤️", "💕", "💗" }
local HEART_COUNT = 7
local HEART_SECONDS = 1.6

local function spawnHeart(root)
	local board = Instance.new("BillboardGui")
	board.Adornee = root
	board.Size = UDim2.fromScale(1.1, 1.1) -- Scale ของ BillboardGui = สตัด: เล็กลงตามระยะเหมือนของในโลก
	board.LightInfluence = 0
	board.MaxDistance = 150
	local start = Vector3.new((math.random() - 0.5) * 2, 0.8, (math.random() - 0.5) * 2)
	board.StudsOffsetWorldSpace = start
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.TextScaled = true
	label.Text = HEARTS[math.random(#HEARTS)]
	label.Parent = board
	board.Parent = root
	local info = TweenInfo.new(HEART_SECONDS, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local rise = start + Vector3.new((math.random() - 0.5) * 2.5, 3 + math.random() * 1.5, (math.random() - 0.5) * 2.5)
	TweenService:Create(board, info, { StudsOffsetWorldSpace = rise, Size = UDim2.fromScale(1.7, 1.7) }):Play()
	TweenService:Create(label, TweenInfo.new(HEART_SECONDS, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		{ TextTransparency = 1 }):Play()
	task.delay(HEART_SECONDS + 0.1, function() board:Destroy() end)
end

Remotes.IslandPetHearts.OnClientEvent:Connect(function(model)
	-- สัตว์อาจยังไม่ถูกสตรีมมาถึงเครื่องนี้ (StreamingEnabled) = ไม่เห็นก็ไม่เป็นไร
	local root = typeof(model) == "Instance" and model:FindFirstChild("HumanoidRootPart")
	if not root then return end
	for i = 1, HEART_COUNT do
		task.delay((i - 1) * 0.09, function()
			if root.Parent then spawnHeart(root) end
		end)
	end
end)

-- ปุ่มวางลง ------------------------------------------------------------------------

local bound = false
while true do
	local now = carrying()
	gui.Enabled = now
	if now and not bound then
		-- เหนือปุ่ม F ของ ProximityPrompt อื่นๆ รอบตัว: ระหว่างอุ้ม F แปลว่า "วางลง" อย่างเดียว
		ContextActionService:BindActionAtPriority("WOLD_PetDrop", function(_, state)
			if state == Enum.UserInputState.Begin then drop() end
			return Enum.ContextActionResult.Sink
		end, false, Enum.ContextActionPriority.High.Value + 100, Enum.KeyCode.F, Enum.KeyCode.ButtonX)
		bound = true
	elseif not now and bound then
		ContextActionService:UnbindAction("WOLD_PetDrop")
		bound = false
	end
	task.wait(0.25)
end
