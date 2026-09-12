-- DebugCoords: tiny always-on readout in the bottom-right corner -- the build, and where you are standing.
--
-- Not part of the game HUD design. It is a development aid, kept on deliberately now that the game is open to
-- players: a screenshot sent back says both which version it came from and exactly where in the map
-- (world-layout.json coordinates) it was taken, without anyone having to ask.
--
-- Runs everywhere (lobby and channel servers) since it is only reading the local character's position.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local GameVersion = require(game.ReplicatedStorage.GameVersion)

local player = Players.LocalPlayer

local gui = Instance.new("ScreenGui")
gui.Name = "DebugCoords"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 999

local label = Instance.new("TextLabel")
label.AnchorPoint = Vector2.new(1, 1)
label.Position = UDim2.new(1, -4, 1, -4)
label.Size = UDim2.new(0, 300, 0, 14)
label.BackgroundTransparency = 1
label.Font = Enum.Font.Code
label.TextSize = 10
label.TextColor3 = Color3.fromRGB(180, 180, 180)
label.TextTransparency = 0.25
label.TextXAlignment = Enum.TextXAlignment.Right
label.TextYAlignment = Enum.TextYAlignment.Bottom
-- Shown before the character exists, and left in place afterwards: the version is the half of this line that
-- is worth reading while the map is still loading.
label.Text = GameVersion.Label()
label.Parent = gui

gui.Parent = player:WaitForChild("PlayerGui")

RunService.RenderStepped:Connect(function()
	local character = player.Character
	local hrp = character and character:FindFirstChild("HumanoidRootPart")
	if not hrp then
		label.Text = GameVersion.Label()
		return
	end
	local p = hrp.Position
	label.Text = ("%s   x=%d y=%d z=%d"):format(GameVersion.Label(), p.X, p.Y, p.Z)
end)
