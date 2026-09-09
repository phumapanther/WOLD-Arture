-- ClassCommandController: F2, the commands of your office.
--
-- Only an advanced class has any, and only that class sees them. Pressing F2 with no advanced class does
-- nothing at all -- not an empty menu, which would read as broken.
--
-- The menu is built from ClassActionConfig.Commands, so adding a command later is an entry in that list and
-- a branch on the server. Nothing here needs to change.
local Players = game:GetService("Players")
local ContextActionService = game:GetService("ContextActionService")
local ClassActionConfig = require(game.ReplicatedStorage.ClassActionConfig)
local ClassConfig = require(game.ReplicatedStorage.ClassConfig)
local Responsive = require(game.ReplicatedStorage.UI.Responsive)
local UiSound = require(game.ReplicatedStorage.UI.UiSound)
local Remotes = require(game.ReplicatedStorage.Remotes)

while workspace:GetAttribute("IsLobby") == nil do
	task.wait()
end
if workspace:GetAttribute("IsLobby") then return end

local player = Players.LocalPlayer

--------------------------------------------------------------------------------

local gui = Instance.new("ScreenGui")
gui.Name = "ClassCommandGui"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 19
gui.Enabled = false
gui.Parent = player:WaitForChild("PlayerGui")

local panel = Instance.new("Frame")
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.Position = UDim2.fromScale(0.5, 0.45)
panel.Size = UDim2.fromOffset(300, 60)
panel.BackgroundColor3 = Color3.fromRGB(38, 40, 48)
panel.BorderSizePixel = 0
panel.Parent = gui
local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 12)
corner.Parent = panel
local stroke = Instance.new("UIStroke")
stroke.Color = Color3.fromRGB(244, 197, 66)
stroke.Transparency = 0.5
stroke.Thickness = 2
stroke.Parent = panel
Responsive.Scale(panel)

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -20, 0, 26)
title.Position = UDim2.new(0, 10, 0, 10)
title.BackgroundTransparency = 1
title.Font = Enum.Font.GothamBold
title.TextSize = 15
title.TextXAlignment = Enum.TextXAlignment.Left
title.Text = ""
title.Parent = panel

local body = Instance.new("Frame")
body.Position = UDim2.new(0, 10, 0, 40)
body.Size = UDim2.new(1, -20, 1, -50)
body.BackgroundTransparency = 1
body.Parent = panel

local function close()
	gui.Enabled = false
end

local function open()
	local classId = player:GetAttribute("WOLD_ClassAdvanced")
	local commands = ClassActionConfig.CommandsFor(classId)
	-- No advanced class, or a class with nothing to issue: stay silent rather than show an empty box.
	if #commands == 0 then return end

	for _, child in ipairs(body:GetChildren()) do child:Destroy() end

	title.Text = ("คำสั่ง%s"):format(ClassConfig.DisplayName(classId))
	title.TextColor3 = ClassConfig.ColorOf(classId)
	panel.Size = UDim2.fromOffset(320, 50 + #commands * 40 + 44)

	for i, command in ipairs(commands) do
		local b = Instance.new("TextButton")
		b.Size = UDim2.new(1, 0, 0, 34)
		b.Position = UDim2.new(0, 0, 0, (i - 1) * 40)
		b.BackgroundColor3 = Color3.fromRGB(26, 28, 34)
		b.BorderSizePixel = 0
		b.Font = Enum.Font.GothamBold
		b.TextSize = 13
		b.TextColor3 = Color3.fromRGB(232, 232, 238)
		b.Text = command.label
		b.AutoButtonColor = true
		b.Parent = body
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(0, 8)
		c.Parent = b
		b.Activated:Connect(function()
			UiSound.Play("Click")
			close()
			Remotes.RequestClassCommand:FireServer(command.id)
		end)
	end

	local cancel = Instance.new("TextButton")
	cancel.Size = UDim2.new(1, 0, 0, 30)
	cancel.Position = UDim2.new(0, 0, 1, -30)
	cancel.BackgroundColor3 = Color3.fromRGB(70, 74, 84)
	cancel.BorderSizePixel = 0
	cancel.Font = Enum.Font.GothamBold
	cancel.TextSize = 13
	cancel.TextColor3 = Color3.fromRGB(232, 232, 238)
	cancel.Text = "ปิด"
	cancel.Parent = body
	local cc = Instance.new("UICorner")
	cc.CornerRadius = UDim.new(0, 8)
	cc.Parent = cancel
	cancel.Activated:Connect(function()
		UiSound.Play("Click")
		close()
	end)

	gui.Enabled = true
end

-- Sink, like the stone's P and the map's M, so F2 never reaches anything behind it.
ContextActionService:BindAction("WOLD_ClassCommands", function(_, state)
	if state ~= Enum.UserInputState.Begin then return Enum.ContextActionResult.Pass end
	if gui.Enabled then close() else open() end
	return Enum.ContextActionResult.Sink
end, false, Enum.KeyCode.F2)

--------------------------------------------------------------------------------
-- Announcements
--------------------------------------------------------------------------------

local feed = Instance.new("ScreenGui")
feed.Name = "ClassAnnouncementGui"
feed.ResetOnSpawn = false
feed.IgnoreGuiInset = true
feed.DisplayOrder = 12
feed.Parent = player.PlayerGui

Remotes.ClassAnnouncement.OnClientEvent:Connect(function(classId, name, text)
	local line = Instance.new("TextLabel")
	line.AnchorPoint = Vector2.new(0.5, 0)
	line.Position = UDim2.new(0.5, 0, 0, 90)
	line.Size = UDim2.fromOffset(520, 30)
	line.BackgroundColor3 = Color3.fromRGB(26, 28, 34)
	line.BackgroundTransparency = 0.2
	line.Font = Enum.Font.GothamBold
	line.TextSize = 14
	-- The class colour again, the same one the board uses: an announcement should look like it came from
	-- the office it came from.
	line.TextColor3 = ClassConfig.ColorOf(classId)
	line.Text = ("[%s] %s — %s"):format(ClassConfig.DisplayName(classId), name, text)
	line.Parent = feed
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 8)
	c.Parent = line
	Responsive.Scale(line)

	task.delay(8, function()
		if line.Parent then line:Destroy() end
	end)
end)
