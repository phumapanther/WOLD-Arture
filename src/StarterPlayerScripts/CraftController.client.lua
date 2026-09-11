-- CraftController: opens the forge window when the server sends a recipe list, and sends taps back.
--
-- Thin on purpose, like ShopController. The server pushes a whole snapshot every time anything changes, so
-- this never patches the window or counts a material -- it draws what it was handed and reports which row was
-- hit.
local Players = game:GetService("Players")

while workspace:GetAttribute("IsLobby") == nil do
	task.wait()
end
if workspace:GetAttribute("IsLobby") then return end

local CraftGui = require(game.ReplicatedStorage.UI.CraftGui)
local UiSound = require(game.ReplicatedStorage.UI.UiSound)
local Remotes = require(game.ReplicatedStorage.Remotes)

local gui = CraftGui.new()

gui:OnCraft(function(index)
	-- The index is the whole request: the server holds the recipe and works out the cost from it. Nothing is
	-- shown yet -- the bar starts on CraftStarted, which only comes back for an attempt the server took the
	-- materials for.
	Remotes.RequestCraft:FireServer(index)
end)

-- Sent both when the prompt is used and after every craft, so the window redraws itself from the server's own
-- counts rather than guessing what the craft consumed.
Remotes.CraftOpen.OnClientEvent:Connect(function(snapshot)
	gui:Show(snapshot)
end)

-- The hammer starts. Fired only for an attempt the server accepted and already charged, so this is the point
-- at which the sound is honest -- a refused craft comes back as a SocialNotify and nothing else, and stays
-- silent.
Remotes.CraftStarted.OnClientEvent:Connect(function(index, seconds)
	UiSound.Play("Hammer")
	gui:Begin(index, seconds)
end)

-- The answer. The window shows it on the row; the wording of what was lost or gained comes separately as a
-- SocialNotify from the server, which is also what reaches a player who closed the window mid-swing.
Remotes.CraftFinished.OnClientEvent:Connect(function(index, success)
	gui:Finish(index, success)
end)

-- Walking away closes the forge. Checked here rather than on the server because it is a matter of
-- presentation -- the server re-checks the distance on every craft regardless, which is the part that has to
-- be trusted.
task.spawn(function()
	while true do
		task.wait(0.5)
		if gui:IsOpen() then
			local character = Players.LocalPlayer.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			if not root then
				gui:Hide()
			else
				local near = false
				for _, npc in ipairs(game:GetService("CollectionService"):GetTagged("WOLD_Npc")) do
					if npc:GetAttribute("NpcKind") == "smith" then
						local position = npc:IsA("BasePart") and npc.Position or npc:GetPivot().Position
						if (position - root.Position).Magnitude <= 16 then near = true break end
					end
				end
				if not near then gui:Hide() end
			end
		end
	end
end)
