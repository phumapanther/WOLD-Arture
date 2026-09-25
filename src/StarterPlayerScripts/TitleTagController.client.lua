-- TitleTagController: ฉายาเรืองแสงเหนือหัว (ผู้ใช้สั่ง 2026-09-25 · สเปก 2026-09-25-achievements-design.md)
--
-- เซิร์ฟเวอร์ตัดสินว่าใครขึ้นฉายาอะไร (PlayerAchievements.server ประกาศ `WOLD_Title` + `WOLD_TitleColor` บนตัวผู้เล่น)
-- ไฟล์นี้แค่วาด · **โชว์แค่ฉายา ไม่มีชื่อ/เลเวล** — กติกาเดิมของเกม (LevelTagController): หัวของคนแปลกหน้า
-- ไม่บอกว่าเป็นใคร ฉายาเป็นสิ่งที่เขาเลือกให้คนอื่นเห็นเอง
--
-- **ลูปถามใหม่ทุก 0.5 วิ ไม่ผูก event ครั้งเดียว** (กฎเหล็ก StreamingEnabled: ร่าง/หัว/แอตทริบิวต์มาถึงคนละรอบ)
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

while workspace:GetAttribute("IsLobby") == nil do
	task.wait()
end
if workspace:GetAttribute("IsLobby") then return end

local TAG = "WOLD_TitleTag"
local HEIGHT_STUDS = 2.4 -- ลอยเหนือหัวเท่านี้
local WIDTH_STUDS, TALL_STUDS = 8, 1.1 -- ขนาดป้ายเป็นสตัด (เล็กลงตามระยะเหมือนของในโลก)
local MAX_DISTANCE = 90

-- ป้ายหนึ่งอัน: ตัวหนังสือสีฉายา + ขอบสีเดียวกันที่เต้นช้าๆ = "เรืองแสง"
local function build(head)
	local gui = Instance.new("BillboardGui")
	gui.Name = TAG
	gui.Size = UDim2.fromScale(WIDTH_STUDS, TALL_STUDS)
	gui.StudsOffsetWorldSpace = Vector3.new(0, HEIGHT_STUDS, 0)
	gui.MaxDistance = MAX_DISTANCE
	gui.LightInfluence = 0
	gui.AlwaysOnTop = false
	gui.ResetOnSpawn = false

	local text = Instance.new("TextLabel")
	text.Name = "Title"
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundTransparency = 1
	text.Font = Enum.Font.GothamBlack
	text.TextScaled = true
	text.Parent = gui

	local glow = Instance.new("UIStroke")
	glow.Name = "Glow"
	glow.Thickness = 2.5
	glow.Transparency = 0.15
	glow.Parent = text
	-- ขอบจางลง-เข้มขึ้นวนไป — แสงที่หายใจ อ่านว่าเรืองแสงชัดกว่าขอบนิ่ง
	TweenService:Create(glow, TweenInfo.new(1.1, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{ Transparency = 0.7 }):Play()

	gui.Parent = head
	return gui
end

local function refresh(player)
	local character = player.Character
	local head = character and character:FindFirstChild("Head")
	if not head then return end
	local title = player:GetAttribute("WOLD_Title")
	local existing = head:FindFirstChild(TAG)
	if type(title) ~= "string" or title == "" then
		if existing then existing:Destroy() end
		return
	end
	local gui = existing or build(head)
	local color = player:GetAttribute("WOLD_TitleColor")
	if typeof(color) ~= "Color3" then color = Color3.new(1, 1, 1) end
	local label = gui:FindFirstChild("Title")
	if label.Text ~= title then label.Text = title end
	label.TextColor3 = Color3.new(1, 1, 1):Lerp(color, 0.55) -- ไส้สว่าง ขอบสีฉายา = ดูเปล่งแสง
	label.Glow.Color = color
end

while true do
	for _, player in ipairs(Players:GetPlayers()) do
		pcall(refresh, player)
	end
	task.wait(0.5)
end
