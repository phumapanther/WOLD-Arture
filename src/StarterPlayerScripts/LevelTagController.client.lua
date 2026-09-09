-- LevelTagController: makes sure NOTHING is drawn above anyone's head.
--
-- This file used to draw the "Lv. N" tag it is still named for. That tag is gone: in this game you do not
-- know a stranger's name, level or class by looking at them. You find out by raising their profile card,
-- which is a deliberate act on both sides, or by reading the board in the speaking stone.
--
-- So the job here is the opposite of what it was -- turning off everything Roblox draws overhead by default:
--   * the character's own name and health bar (DisplayDistanceType)
--   * the speech bubble that appears when someone talks
--   * any WOLD_LevelTag left on a rig from before this change
--
-- The profile card (ProfileCardGui) is the one exception, and it is not touched here.
local Players = game:GetService("Players")
local Chat = game:GetService("Chat")
local TextChatService = game:GetService("TextChatService")

while workspace:GetAttribute("IsLobby") == nil do
	task.wait()
end
if workspace:GetAttribute("IsLobby") then return end

--------------------------------------------------------------------------------
-- Speech bubbles
--------------------------------------------------------------------------------

-- Two chat systems exist depending on the place's setting, so both are turned off. Wrapped because the one
-- that is not in use throws on being configured.
--
-- BubbleChatConfiguration is created asynchronously, so it is WAITED for rather than looked up once: a
-- FindFirstChildOfClass at this point ran before it existed and silently did nothing (measured -- bubbles
-- stayed on).
task.spawn(function()
	local ok, bubble = pcall(function()
		return TextChatService:WaitForChild("BubbleChatConfiguration", 15)
	end)
	if ok and bubble then bubble.Enabled = false end
end)
pcall(function()
	Chat:SetBubbleChatSettings({ BubbleDuration = 0, BubblesSpacing = 0, MaxBubbles = 0 })
end)

--------------------------------------------------------------------------------
-- Names and health bars
--------------------------------------------------------------------------------

-- Set on every humanoid rather than once on StarterPlayer, because a rebuilt character comes back with the
-- defaults. None means the name is never drawn at any distance, for anyone including yourself.
local function silence(character)
	local humanoid = character:FindFirstChildOfClass("Humanoid") or character:WaitForChild("Humanoid", 10)
	if not humanoid then return end
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.NameDisplayDistance = 0
	humanoid.HealthDisplayDistance = 0

	-- Anything this file used to draw, cleared off rigs that still carry one.
	local head = character:FindFirstChild("Head")
	local stale = head and head:FindFirstChild("WOLD_LevelTag")
	if stale then stale:Destroy() end
end

local function watch(player)
	player.CharacterAdded:Connect(silence)
	if player.Character then task.spawn(silence, player.Character) end
end

for _, player in ipairs(Players:GetPlayers()) do watch(player) end
Players.PlayerAdded:Connect(watch)
