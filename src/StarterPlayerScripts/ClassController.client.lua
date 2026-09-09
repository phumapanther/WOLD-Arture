-- ClassController: shows the class card when the server offers one, and sends back the choice.
--
-- The card is offered on a level-up and on join. Join matters because the level that unlocked the tier may
-- be from a previous session -- a player who reached level 5 and logged out without choosing should be
-- asked again rather than quietly never being offered it.
while workspace:GetAttribute("IsLobby") == nil do
	task.wait()
end
if workspace:GetAttribute("IsLobby") then return end

local ClassCardGui = require(game.ReplicatedStorage.UI.ClassCardGui)
local ClassConfig = require(game.ReplicatedStorage.ClassConfig)
local Remotes = require(game.ReplicatedStorage.Remotes)

local gui = ClassCardGui.new()

gui:OnChosen(function(classId)
	-- Closed straight away rather than on the server's confirmation: the request is validated there, and
	-- leaving the card up while the round trip happens invites a second tap on a different class.
	gui:Hide()
	Remotes.RequestChooseClass:FireServer(classId)
end)

Remotes.ClassOffer.OnClientEvent:Connect(function(tier, classIds)
	gui:Show(tier, classIds)
end)

Remotes.ClassChanged.OnClientEvent:Connect(function(tier, classId)
	gui:Hide()
	print(("[Class] คุณเป็น %s แล้ว"):format(ClassConfig.DisplayName(classId)))
end)

-- Levelling up may have crossed an unlock; ask rather than working it out here, so the level gate lives in
-- exactly one place.
Remotes.LevelUp.OnClientEvent:Connect(function()
	Remotes.RequestClassOffer:FireServer()
end)

-- And once on join, after a moment for the server to have loaded the profile.
task.delay(3, function()
	Remotes.RequestClassOffer:FireServer()
end)
