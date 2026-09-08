-- LevelTagController: draws "Lv. N" above every player's head, including your own.
--
-- The level replicates as the WOLD_Level attribute (set by Progression), so this needs no remote of its own
-- and stays correct for players who were already in the server when you joined.
while workspace:GetAttribute("IsLobby") == nil do
	task.wait()
end
if workspace:GetAttribute("IsLobby") then return end -- no levels in the lobby

local Players = game:GetService("Players")

local ACCENT = Color3.fromRGB(244, 197, 66)

local function tagFor(character)
	local head = character:FindFirstChild("Head")
	if not head then return nil end
	local existing = head:FindFirstChild("WOLD_LevelTag")
	if existing then return existing end

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "WOLD_LevelTag"
	billboard.Size = UDim2.fromOffset(120, 26)
	-- Sits above the character's own name tag. StudsOffsetWorldSpace so it stays put as the body scales with
	-- level rather than drifting into the head.
	billboard.StudsOffsetWorldSpace = Vector3.new(0, 3.2, 0)
	billboard.AlwaysOnTop = false
	billboard.MaxDistance = 120
	billboard.Parent = head

	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.TextColor3 = ACCENT
	label.Text = "Lv. 1"
	label.Parent = billboard

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(0, 0, 0)
	stroke.Transparency = 0.35
	stroke.Thickness = 2
	stroke.Parent = label

	return billboard
end

local function refresh(player)
	local character = player.Character
	if not character then return end
	local billboard = tagFor(character)
	if not billboard then return end
	billboard.Label.Text = ("Lv. %d"):format(player:GetAttribute("WOLD_Level") or 1)
end

local function watch(player)
	player:GetAttributeChangedSignal("WOLD_Level"):Connect(function()
		refresh(player)
	end)
	player.CharacterAdded:Connect(function(character)
		character:WaitForChild("Head", 10)
		refresh(player)
	end)
	refresh(player)
end

for _, player in ipairs(Players:GetPlayers()) do watch(player) end
Players.PlayerAdded:Connect(watch)
