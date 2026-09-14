-- ChestController: opens the chest window when the server says a chest was opened, and reports taps back.
--
-- Holds no state of its own beyond "is the window up". The loot list belongs to the server and arrives
-- whole every time it changes, so there is nothing here to keep in step.
local Players = game:GetService("Players")
local Remotes = require(game.ReplicatedStorage.Remotes)
local ChestGui = require(game.ReplicatedStorage.UI.ChestGui)

local gui = ChestGui.new()

gui:On("take", function(index)
	Remotes.RequestChestTake:FireServer(index)
end)

gui:On("takeAll", function()
	Remotes.RequestChestTake:FireServer("all")
end)

-- Closing is destructive -- the chest and everything left in it are gone -- so the window is hidden FIRST
-- and the server told after. Waiting for the server to confirm would leave the window up for a round trip
-- after a tap that always succeeds.
gui:On("close", function()
	gui:Hide()
	Remotes.RequestChestClose:FireServer()
end)

Remotes.ChestOpen.OnClientEvent:Connect(function(tier, loot)
	gui:Show(tier, loot)
end)

-- The server closing the window on its own: the chest was emptied, or destroyed underneath us.
Remotes.ChestClose.OnClientEvent:Connect(function()
	gui:Hide()
end)
