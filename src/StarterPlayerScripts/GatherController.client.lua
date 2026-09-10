-- GatherController: plays a swing while a gathering prompt is being held.
--
-- Reuses Sword_Slash rather than building a gathering animation of its own, as the user asked. It is a
-- downward two-handed swing, which is what chopping and mining look like; played on a loop for the length
-- of the hold it reads as repeated strikes rather than one flourish.
--
-- Purely cosmetic. The server decides what a hold actually yields, and nothing here is trusted -- a player
-- who blocked this script would gather exactly as well, just silently.
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")

while workspace:GetAttribute("IsLobby") == nil do
	task.wait()
end
if workspace:GetAttribute("IsLobby") then return end

local player = Players.LocalPlayer

-- The same published sequence the sword swings with. Named here rather than read from CombatConfig because
-- this is a deliberate borrowing: if the sword's animation changes, gathering should keep this one.
local SWING_ID = "rbxassetid://138133285610075" -- Sword_Slash

local animation = Instance.new("Animation")
animation.AnimationId = SWING_ID

local track

local function trackFor()
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
	if not animator then return nil end
	-- Rebuilt whenever the character changes: an Animator is recreated with its character, and a track
	-- loaded from the old one plays on nothing.
	if track and track.Parent == animator then return track end
	local ok, loaded = pcall(function() return animator:LoadAnimation(animation) end)
	if not ok then return nil end
	loaded.Looped = true
	-- Slower than a real swing: a 0.66-second slash repeated at full speed looks frantic next to a
	-- two-and-a-half-second chop.
	loaded:AdjustSpeed(0.7)
	track = loaded
	return track
end

player.CharacterAdded:Connect(function()
	track = nil
end)

local function isGatherPrompt(prompt)
	return prompt.Name == "GatherPrompt"
end

ProximityPromptService.PromptButtonHoldBegan:Connect(function(prompt, who)
	if who ~= player or not isGatherPrompt(prompt) then return end
	local t = trackFor()
	if t then t:Play(0.15) end
end)

local function stop(prompt, who)
	if who ~= player or not isGatherPrompt(prompt) then return end
	if track and track.IsPlaying then track:Stop(0.2) end
end

-- Every way a hold can end: released early, or completed. Without both, letting go mid-chop leaves the
-- character swinging at nothing forever.
ProximityPromptService.PromptButtonHoldEnded:Connect(stop)
ProximityPromptService.PromptTriggered:Connect(stop)
