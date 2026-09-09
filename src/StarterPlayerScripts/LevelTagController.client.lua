-- LevelTagController: draws "Lv. N" above every player's head, including your own.
--
-- The level replicates as the WOLD_Level attribute (set by Progression), so this needs no remote of its own
-- and stays correct for players who were already in the server when you joined.
while workspace:GetAttribute("IsLobby") == nil do
	task.wait()
end
if workspace:GetAttribute("IsLobby") then return end -- no levels in the lobby

local Players = game:GetService("Players")
local ClassConfig = require(game.ReplicatedStorage.ClassConfig)

local ACCENT = Color3.fromRGB(244, 197, 66)

-- What colour a name should be, and what it should say. The class replicates as an attribute, so this needs
-- no remote and is already right for players who were here before you joined.
--
-- The mark wins over everything: a thief who failed a robbery is red whatever they otherwise are, which is
-- the whole point of marking them.
local function appearance(player)
	local level = player:GetAttribute("WOLD_Level") or 1
	if player:GetAttribute("WOLD_Marked") then
		return ClassConfig.MarkedColor, ("Lv. %d"):format(level)
	end
	-- The advanced class outranks the basic one: it is the more interesting fact about a player, and the
	-- one whose colour carries authority.
	local classId = player:GetAttribute("WOLD_ClassAdvanced") or player:GetAttribute("WOLD_ClassBasic")
	if not classId then
		return ACCENT, ("Lv. %d"):format(level)
	end
	return ClassConfig.ColorOf(classId),
		("[%s] Lv. %d"):format(ClassConfig.DisplayName(classId), level)
end

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
	local color, text = appearance(player)
	billboard.Label.TextColor3 = color
	billboard.Label.Text = text
end

local function watch(player)
	-- Any of these changes the tag: the level, either class, or the mark going on or coming off.
	for _, attribute in ipairs({ "WOLD_Level", "WOLD_ClassBasic", "WOLD_ClassAdvanced", "WOLD_Marked" }) do
		player:GetAttributeChangedSignal(attribute):Connect(function()
			refresh(player)
		end)
	end
	player.CharacterAdded:Connect(function(character)
		character:WaitForChild("Head", 10)
		refresh(player)
	end)
	refresh(player)
end

for _, player in ipairs(Players:GetPlayers()) do watch(player) end
Players.PlayerAdded:Connect(watch)
