-- MinigameController: plays whichever quick-time game the server asks for, and reports the one bit back.
--
-- Thin by design, like every other controller here. It does not decide that a minigame should happen, what
-- it is worth, or whether the player was allowed to try -- all three were settled on the server before
-- MinigameStart was sent. This picks the right widget, runs it, and answers.
while workspace:GetAttribute("IsLobby") == nil do
	task.wait()
end
if workspace:GetAttribute("IsLobby") then return end

local MinigameGui = require(game.ReplicatedStorage.UI.MinigameGui)
local Remotes = require(game.ReplicatedStorage.Remotes)

local gui = MinigameGui.new()

Remotes.MinigameStart.OnClientEvent:Connect(function(spec)
	if type(spec) ~= "table" or type(spec.token) ~= "string" then return end

	-- The token goes back untouched with the answer. It is what ties this reply to this attempt, so a late
	-- answer from an abandoned game cannot land on the next one.
	local token = spec.token
	local function report(success)
		Remotes.MinigameFinish:FireServer(token, success and true or false)
	end

	if spec.kind == "skillcheck" then
		gui:StartSkillCheck(spec, report)
	else
		gui:StartArrows(spec, report)
	end
end)
