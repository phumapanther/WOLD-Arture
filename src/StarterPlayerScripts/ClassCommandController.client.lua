-- ClassCommandController: shows announcements made from the console.
--
-- The commands themselves are typed into the same F2 console the admin commands use -- "/announce ..." --
-- because to the person typing there is no difference between the two: a slash and a word. Who may run
-- what is decided on the server. This file only draws the result.
local Players = game:GetService("Players")
local ClassConfig = require(game.ReplicatedStorage.ClassConfig)
local Responsive = require(game.ReplicatedStorage.UI.Responsive)
local Remotes = require(game.ReplicatedStorage.Remotes)
local Locale = require(game.ReplicatedStorage.Locale)

while workspace:GetAttribute("IsLobby") == nil do
	task.wait()
end
if workspace:GetAttribute("IsLobby") then return end

local player = Players.LocalPlayer

--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- Announcements
--------------------------------------------------------------------------------

local feed = Instance.new("ScreenGui")
feed.Name = "ClassAnnouncementGui"
feed.ResetOnSpawn = false
feed.IgnoreGuiInset = true
feed.DisplayOrder = 12
feed.Parent = player.PlayerGui

-- An announcement is painted by WHO made it. A class uses its own colour -- the same one the board and the
-- profile card use -- and an admin gets red, which no class has, so a server-wide notice never looks like
-- one more guard talking.
local ADMIN_COLOR = Color3.fromRGB(255, 60, 60)

local function appearance(senderId)
	if senderId == "admin" then
		return ADMIN_COLOR, Locale.L("แอดมิน")
	end
	return ClassConfig.ColorOf(senderId), Locale.Show(ClassConfig.DisplayName(senderId))
end

Remotes.ClassAnnouncement.OnClientEvent:Connect(function(classId, name, text)
	local color, label = appearance(classId)

	local line = Instance.new("TextLabel")
	line.AnchorPoint = Vector2.new(0.5, 0)
	line.Position = UDim2.new(0.5, 0, 0, 90)
	line.Size = UDim2.fromOffset(520, 30)
	-- The background is tinted the same colour, heavily darkened: readable at a glance from across the
	-- screen, without the text having to fight a bright panel behind it.
	line.BackgroundColor3 = Color3.new(color.R * 0.25, color.G * 0.25, color.B * 0.25)
	line.BackgroundTransparency = 0.15
	line.Font = Enum.Font.GothamBold
	line.TextSize = 14
	line.TextColor3 = color
	line.Text = ("[%s] %s — %s"):format(label, name, text)
	line.Parent = feed
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 8)
	c.Parent = line
	local edge = Instance.new("UIStroke")
	edge.Color = color
	edge.Transparency = 0.45
	edge.Thickness = 1
	edge.Parent = line
	Responsive.Scale(line)

	task.delay(8, function()
		if line.Parent then line:Destroy() end
	end)
end)
