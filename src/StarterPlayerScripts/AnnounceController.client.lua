-- AnnounceController: แถบเลื่อนประกาศข้ามเซิร์ฟ บนสุดของจอ (ผู้ใช้เลือก 2026-09-25)
--
-- ข้อความวิ่งจากขวาไปซ้ายแบบแถบข่าว · มาติดกันต่อคิว · แถบโผล่เฉพาะตอนมีประกาศ (ไม่บังจอตอนว่าง)
-- วางใต้ป้ายอีเวนต์ (EventBannerGui ยืนที่ y 8 สูงสุด ~64) จึงไม่ทับกันตอนมีทั้งสองอย่าง
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local Remotes = require(game.ReplicatedStorage.Remotes)
local Show = require(game.ReplicatedStorage.Locale).Show

local SPEED = 140 -- พิกเซลต่อวินาที
local BAR_Y, BAR_H = 78, 30
local COLORS = {
	town = Color3.fromRGB(255, 160, 70),
	legend = Color3.fromRGB(255, 210, 80),
	enhance = Color3.fromRGB(200, 150, 255),
	info = Color3.fromRGB(235, 235, 240),
}

local gui = Instance.new("ScreenGui")
gui.Name = "WOLD_Announce"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 14
gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

local bar = Instance.new("Frame")
bar.AnchorPoint = Vector2.new(0.5, 0)
bar.Position = UDim2.new(0.5, 0, 0, BAR_Y)
bar.Size = UDim2.new(0.62, 0, 0, BAR_H)
bar.BackgroundColor3 = Color3.fromRGB(16, 16, 22)
bar.BackgroundTransparency = 0.25
bar.ClipsDescendants = true
bar.Visible = false
bar.Parent = gui
local round = Instance.new("UICorner")
round.CornerRadius = UDim.new(0, 8)
round.Parent = bar
local edge = Instance.new("UIStroke")
edge.Thickness = 1.5
edge.Transparency = 0.3
edge.Parent = bar

local text = Instance.new("TextLabel")
text.AnchorPoint = Vector2.new(0, 0.5)
text.Position = UDim2.new(1, 0, 0.5, 0)
text.AutomaticSize = Enum.AutomaticSize.X
text.Size = UDim2.new(0, 0, 1, -4)
text.BackgroundTransparency = 1
text.Font = Enum.Font.GothamBold
text.TextSize = 17
text.TextStrokeTransparency = 0.5
text.Parent = bar

local queue, running = {}, false

local function playNext()
	running = true
	while #queue > 0 do
		local item = table.remove(queue, 1)
		local color = COLORS[item.kind] or COLORS.info
		text.Text = Show(item.text)
		text.TextColor3 = color
		edge.Color = color
		bar.Visible = true
		task.wait() -- ให้ AutomaticSize คำนวณความกว้างข้อความก่อน
		local width = bar.AbsoluteSize.X
		local textWidth = text.AbsoluteSize.X
		text.Position = UDim2.new(0, width, 0.5, 0)
		local seconds = (width + textWidth) / SPEED
		local tween = TweenService:Create(text, TweenInfo.new(seconds, Enum.EasingStyle.Linear),
			{ Position = UDim2.new(0, -textWidth, 0.5, 0) })
		tween:Play()
		tween.Completed:Wait()
	end
	bar.Visible = false
	running = false
end

Remotes.GlobalAnnounce.OnClientEvent:Connect(function(message, kind)
	if type(message) ~= "string" then return end
	-- คิวไม่ยาวไม่รู้จบ: ประกาศถี่ผิดปกติ (หลายเซิร์ฟพร้อมกัน) เก็บแค่ 6 ข้อความล่าสุด
	table.insert(queue, { text = message, kind = kind })
	while #queue > 6 do table.remove(queue, 1) end
	if not running then task.spawn(playNext) end
end)
