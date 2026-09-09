-- AdminController.client.lua: the admin's command box and its output log.
--
-- Chat is switched off in channel servers (HudController disables the CoreGui chat), so there is nowhere to
-- type a command or read a reply. This gives the admin a small console instead: F2 toggles it, Enter sends,
-- and replies from the server print above the input.
--
-- The console is NOT the security boundary -- the server decides who is an admin and ignores everyone else.
-- This only avoids drawing a box for players whose commands would be refused anyway, and a non-admin who
-- forces it open just types into the void.
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local Remotes = require(game.ReplicatedStorage.Remotes)

-- Same allow-list as the server's, for deciding whether to draw the box at all. Kept in sync by hand; being
-- wrong here grants nothing, because the server checks again on every command.
local ADMINS = {
	[4871683651] = true, -- phumapanther (owner)
}

local player = Players.LocalPlayer

while workspace:GetAttribute("IsLobby") == nil do
	task.wait()
end
if workspace:GetAttribute("IsLobby") then return end -- commands only exist in channel servers

-- The box is drawn for anyone who has SOMETHING to type: an admin, or a player holding an advanced class,
-- which is what grants /announce. Everyone else never sees it, and F2 does nothing for them.
--
-- This is a convenience, not a permission. The server re-checks who may run what on every command, so being
-- wrong here grants nothing -- it only decides whether a box appears.
local function hasCommands()
	if ADMINS[player.UserId] then return true end
	return player:GetAttribute("WOLD_ClassAdvanced") ~= nil
		or player:GetAttribute("WOLD_ClassElite") ~= nil
end

--------------------------------------------------------------------------------
-- UI
--------------------------------------------------------------------------------

local BG = Color3.fromRGB(14, 13, 18)
local ACCENT = Color3.fromRGB(216, 172, 84)
local TEXT = Color3.fromRGB(240, 240, 245)

local gui = Instance.new("ScreenGui")
gui.Name = "AdminConsole"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 50
gui.Enabled = false
gui.Parent = player:WaitForChild("PlayerGui")

local panel = Instance.new("Frame")
panel.AnchorPoint = Vector2.new(0.5, 1)
panel.Position = UDim2.new(0.5, 0, 1, -90)
panel.Size = UDim2.new(0, 560, 0, 220)
panel.BackgroundColor3 = BG
panel.BackgroundTransparency = 0.15
panel.BorderSizePixel = 0
panel.Parent = gui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 10)
corner.Parent = panel

local stroke = Instance.new("UIStroke")
stroke.Color = ACCENT
stroke.Transparency = 0.55
stroke.Thickness = 1.5
stroke.Parent = panel

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -20, 0, 22)
title.Position = UDim2.new(0, 12, 0, 8)
title.BackgroundTransparency = 1
title.Font = Enum.Font.GothamBold
title.TextSize = 13
title.TextColor3 = ACCENT
title.TextXAlignment = Enum.TextXAlignment.Left
title.Text = "แอดมิน — F2 ปิด/เปิด, /admin ดูคำสั่งทั้งหมด"
title.Parent = panel

-- The log. Newest at the bottom, like a terminal.
local log = Instance.new("ScrollingFrame")
log.Position = UDim2.new(0, 12, 0, 34)
log.Size = UDim2.new(1, -24, 1, -84)
log.BackgroundTransparency = 1
log.BorderSizePixel = 0
log.ScrollBarThickness = 4
log.ScrollingDirection = Enum.ScrollingDirection.Y
log.AutomaticCanvasSize = Enum.AutomaticSize.Y
log.CanvasSize = UDim2.new()
log.Parent = panel

local layout = Instance.new("UIListLayout")
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Padding = UDim.new(0, 2)
layout.Parent = log

local box = Instance.new("TextBox")
box.AnchorPoint = Vector2.new(0, 1)
box.Position = UDim2.new(0, 12, 1, -12)
box.Size = UDim2.new(1, -24, 0, 32)
box.BackgroundColor3 = Color3.fromRGB(26, 25, 32)
box.BackgroundTransparency = 0.2
box.BorderSizePixel = 0
box.Font = Enum.Font.Code
box.TextSize = 14
box.TextColor3 = TEXT
box.PlaceholderText = "/give Sword 1     /gold 1000     /tpto ชื่อ"
box.ClearTextOnFocus = false
box.Text = ""
box.Parent = panel

local boxCorner = Instance.new("UICorner")
boxCorner.CornerRadius = UDim.new(0, 6)
boxCorner.Parent = box

local lines = 0
local function append(text, color)
	for piece in tostring(text):gmatch("[^\n]+") do
		lines += 1
		local label = Instance.new("TextLabel")
		label.LayoutOrder = lines
		label.Size = UDim2.new(1, 0, 0, 16)
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.Code
		label.TextSize = 13
		label.TextColor3 = color or TEXT
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.TextTruncate = Enum.TextTruncate.AtEnd
		label.Text = piece
		label.Parent = log
	end
	-- Keep the newest line in view.
	task.defer(function()
		log.CanvasPosition = Vector2.new(0, math.max(0, log.AbsoluteCanvasSize.Y - log.AbsoluteWindowSize.Y))
	end)
end

--------------------------------------------------------------------------------
-- Sending
--------------------------------------------------------------------------------

-- Straight down the AdminCommand remote. Going through the chat system instead would be fragile here --
-- channel servers switch chat off, so SendAsync has nowhere to go -- and it buys no safety: the server
-- checks the UserId allow-list on this remote exactly as it does on a chat line.
local function send(text)
	if text == "" then return end
	append("> " .. text, ACCENT)
	Remotes.AdminCommand:FireServer(text)
end

box.FocusLost:Connect(function(enterPressed)
	if not enterPressed then return end
	local text = box.Text
	box.Text = ""
	send(text)
	-- Straight back into the box, so several commands can be typed in a row.
	task.defer(function()
		if gui.Enabled then box:CaptureFocus() end
	end)
end)

Remotes.AdminMessage.OnClientEvent:Connect(function(text)
	append(text)
	if not gui.Enabled then
		-- A reply to a command typed elsewhere still deserves to be seen.
		gui.Enabled = true
	end
end)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	if input.KeyCode ~= Enum.KeyCode.F2 then return end
	-- Checked on every press rather than once at start-up: a class is chosen mid-session, and a player who
	-- becomes a guard at level 50 should get the console without rejoining.
	if not gui.Enabled and not hasCommands() then return end
	gui.Enabled = not gui.Enabled
	if gui.Enabled then
		box:CaptureFocus()
	else
		box:ReleaseFocus()
	end
end)

append("พิมพ์ /admin เพื่อดูคำสั่งทั้งหมด", ACCENT)

--------------------------------------------------------------------------------
-- Flight
--------------------------------------------------------------------------------
-- Driven here rather than on the server because the client owns its character's physics: a server-side
-- mover fights the client for the same parts and stutters. The SERVER still decides who may fly -- this
-- only listens for permission it granted.
--
-- Built from BodyVelocity/BodyGyro rather than by setting CFrame every frame, so the character keeps
-- colliding with the world instead of passing through it while being scrubbed into place.

local RunService = game:GetService("RunService")
local ContextActionService = game:GetService("ContextActionService")

local flying = false
local flySpeed = 90
local flyConnection, velocity, gyro
local flyKeys = {}

local function stopFlying()
	flying = false
	if flyConnection then
		flyConnection:Disconnect()
		flyConnection = nil
	end
	if velocity then velocity:Destroy() velocity = nil end
	if gyro then gyro:Destroy() gyro = nil end

	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.PlatformStand = false
		-- Back to whatever the movement system wants; it sets WalkSpeed every tick anyway.
		humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
	end
	for _, key in ipairs({ "WOLD_FlyUp", "WOLD_FlyDown" }) do
		pcall(function() ContextActionService:UnbindAction(key) end)
	end
	flyKeys = {}
	append("ลงพื้นแล้ว", ACCENT)
end

local function startFlying()
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid then
		append("ตัวละครยังไม่พร้อม", Color3.fromRGB(220, 120, 110))
		return
	end

	flying = true
	-- PlatformStand stops the humanoid trying to walk and fall while the movers hold it up.
	humanoid.PlatformStand = true

	velocity = Instance.new("BodyVelocity")
	velocity.MaxForce = Vector3.new(1, 1, 1) * 1e6
	velocity.Velocity = Vector3.zero
	velocity.Parent = root

	gyro = Instance.new("BodyGyro")
	gyro.MaxTorque = Vector3.new(1, 1, 1) * 1e6
	gyro.P = 9000
	gyro.CFrame = root.CFrame
	gyro.Parent = root

	-- Space and Shift are claimed while flying so jumping does not fight the climb.
	ContextActionService:BindAction("WOLD_FlyUp", function(_, state)
		flyKeys.up = state == Enum.UserInputState.Begin
		return Enum.ContextActionResult.Sink
	end, false, Enum.KeyCode.Space)
	ContextActionService:BindAction("WOLD_FlyDown", function(_, state)
		flyKeys.down = state == Enum.UserInputState.Begin
		return Enum.ContextActionResult.Sink
	end, false, Enum.KeyCode.LeftShift)

	flyConnection = RunService.RenderStepped:Connect(function()
		if not flying then return end
		local char = player.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if not hrp or not hum then
			stopFlying()
			return
		end

		local camera = workspace.CurrentCamera
		-- Move where the camera looks, which is what "fly" means when the point is to survey the map.
		local move = hum.MoveDirection
		local direction = Vector3.zero
		if move.Magnitude > 0.1 then
			-- MoveDirection is already in world space and camera-relative, so it needs no rotating.
			direction = move
		end
		if flyKeys.up then direction = direction + Vector3.new(0, 1, 0) end
		if flyKeys.down then direction = direction - Vector3.new(0, 1, 0) end

		velocity.Velocity = direction.Magnitude > 0 and direction.Unit * flySpeed or Vector3.zero
		gyro.CFrame = CFrame.new(hrp.Position, hrp.Position + camera.CFrame.LookVector)
	end)

	append(("บินอยู่ (ความเร็ว %d) — Space ขึ้น, Shift ลง, /land เพื่อลง"):format(flySpeed), ACCENT)
end

Remotes.AdminFly.OnClientEvent:Connect(function(action, speed)
	if speed then flySpeed = speed end
	if action == "off" then
		if flying then stopFlying() end
	elseif action == "toggle" then
		if flying then stopFlying() else startFlying() end
	end
end)

-- A respawn destroys the movers with the old rig, so the flag has to be cleared or the next /fly toggles
-- flight OFF instead of on.
player.CharacterAdded:Connect(function()
	if flying then
		flying = false
		if flyConnection then flyConnection:Disconnect() flyConnection = nil end
		velocity, gyro = nil, nil
	end
end)
