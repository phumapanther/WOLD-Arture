-- ToastController: shows the short messages the server sends about what just happened.
--
-- SocialNotify has been the game's "tell the player something" channel for a while, but the only thing
-- listening was the speaking stone's own window -- so an "info" or "error" arriving with that window shut
-- was shown to nobody at all. Everything gathering, fishing, the shop and the monsters had to say went
-- into the void, which is how "click does not fish" turned out to be "click said ตรงนี้ไม่มีน้ำ and no
-- one could see it".
--
-- Deliberately dumb: a stack of lines that fade. It draws what it is told and never decides anything.
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

-- ล็อบบี้ก็แสดงด้วย (QA 2026-09-26) — หน้าปาร์ตี้ PVP บอกเหตุผลทุกอย่างผ่าน SocialNotify (ชวนไม่ได้ ปาร์ตี้เต็ม อยู่ในคิว
-- แล้ว) ของเดิมปิดตัวเองในล็อบบี้ ข้อความพวกนั้นเลยไม่เคยขึ้นจอ กดแล้วเหมือนปุ่มพัง
local UserInputService = game:GetService("UserInputService")

local Remotes = require(game.ReplicatedStorage.Remotes)

local player = Players.LocalPlayer

-- The kinds the stone's own window already handles. Those still go there; repeating them here would
-- double every friend request.
local HANDLED_ELSEWHERE = { pigeon = true, friendRequest = true }

local SECONDS = 3.5
local MAX_LINES = 5

local gui = Instance.new("ScreenGui")
gui.Name = "ToastGui"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 14
gui.Parent = player:WaitForChild("PlayerGui")

-- Above the hotbar and clear of the vitals cluster: the bottom left is taken, the bottom middle is the
-- hotbar, so these sit bottom-right where nothing else lives.
-- **มือถือ: กลางบน** (QA 2026-09-26) — มุมขวาล่างของมือถือคือปุ่มโจมตี/สกิล/กลิ้ง ข้อความ "มานาไม่พอ" ขึ้นทับปุ่มที่
-- เพิ่งกดพอดี 3.5 วิ · กลางบนใต้แถบประกาศว่างเสมอ และ TextLabel ไม่กินการแตะ
local touchOnly = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
local holder = Instance.new("Frame")
holder.AnchorPoint = touchOnly and Vector2.new(0.5, 0) or Vector2.new(1, 1)
holder.Position = touchOnly and UDim2.new(0.5, 0, 0, 118) or UDim2.new(1, -16, 1, -120)
holder.Size = UDim2.fromOffset(320, 200)
holder.BackgroundTransparency = 1
holder.Parent = gui

local layout = Instance.new("UIListLayout")
layout.VerticalAlignment = touchOnly and Enum.VerticalAlignment.Top or Enum.VerticalAlignment.Bottom
layout.HorizontalAlignment = touchOnly and Enum.HorizontalAlignment.Center or Enum.HorizontalAlignment.Right
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Padding = UDim.new(0, 4)
layout.Parent = holder

local order = 0

local function toast(message, isError)
	order += 1

	local line = Instance.new("TextLabel")
	line.LayoutOrder = order
	line.AutomaticSize = Enum.AutomaticSize.X
	line.Size = UDim2.fromOffset(0, 26)
	line.BackgroundColor3 = Color3.fromRGB(26, 28, 34)
	line.BackgroundTransparency = 0.15
	line.BorderSizePixel = 0
	line.Font = Enum.Font.GothamBold
	line.TextSize = 13
	line.TextColor3 = isError and Color3.fromRGB(232, 128, 118) or Color3.fromRGB(238, 224, 180)
	line.Text = "  " .. message .. "  "
	line.Parent = holder

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = line

	local stroke = Instance.new("UIStroke")
	stroke.Color = isError and Color3.fromRGB(214, 84, 74) or Color3.fromRGB(244, 197, 66)
	stroke.Transparency = 0.5
	stroke.Parent = line

	-- Oldest first: a burst of catches should not push the newest one off screen.
	local lines = {}
	for _, child in ipairs(holder:GetChildren()) do
		if child:IsA("TextLabel") then table.insert(lines, child) end
	end
	if #lines > MAX_LINES then
		table.sort(lines, function(a, b) return a.LayoutOrder < b.LayoutOrder end)
		for i = 1, #lines - MAX_LINES do lines[i]:Destroy() end
	end

	task.delay(SECONDS, function()
		if not line.Parent then return end
		local fade = TweenService:Create(line, TweenInfo.new(0.4),
			{ BackgroundTransparency = 1, TextTransparency = 1 })
		local fadeStroke = TweenService:Create(stroke, TweenInfo.new(0.4), { Transparency = 1 })
		fade:Play()
		fadeStroke:Play()
		fade.Completed:Wait()
		line:Destroy()
	end)
end

Remotes.SocialNotify.OnClientEvent:Connect(function(kind, message)
	if not message or HANDLED_ELSEWHERE[kind] then return end
	toast(message, kind == "error")
end)
