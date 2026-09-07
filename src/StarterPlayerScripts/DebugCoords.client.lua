-- DebugCoords: tiny always-on position readout, bottom-right corner. Not part of the game HUD design — a
-- development aid so a screenshot sent back tells exactly where in the map (world-layout.json coordinates) it
-- was taken. Runs everywhere (lobby and channel servers) since it's just reading the local character's position.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer

local gui = Instance.new("ScreenGui")
gui.Name = "DebugCoords"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 999

local label = Instance.new("TextLabel")
label.AnchorPoint = Vector2.new(1, 1)
label.Position = UDim2.new(1, -4, 1, -4)
label.Size = UDim2.new(0, 220, 0, 14)
label.BackgroundTransparency = 1
label.Font = Enum.Font.Code
label.TextSize = 10
label.TextColor3 = Color3.fromRGB(180, 180, 180)
label.TextTransparency = 0.25
label.TextXAlignment = Enum.TextXAlignment.Right
label.TextYAlignment = Enum.TextYAlignment.Bottom
label.Text = ""
label.Parent = gui

gui.Parent = player:WaitForChild("PlayerGui")

RunService.RenderStepped:Connect(function()
	local character = player.Character
	local hrp = character and character:FindFirstChild("HumanoidRootPart")
	if not hrp then
		label.Text = ""
		return
	end
	local p = hrp.Position
	label.Text = ("x=%d y=%d z=%d"):format(p.X, p.Y, p.Z)
end)
