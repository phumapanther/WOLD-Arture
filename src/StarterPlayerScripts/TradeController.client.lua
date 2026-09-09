-- TradeController: the client half of a trade.
--
-- Opens the window when the server says a trade started, redraws it from every state the server sends, and
-- closes it when the server says so. It never decides anything: the offer, the agreement and the swap are
-- all server-side, and this is only ever showing the last picture it was given.
local Players = game:GetService("Players")
local TradeGui = require(game.ReplicatedStorage.UI.TradeGui)
local UiSound = require(game.ReplicatedStorage.UI.UiSound)
local Remotes = require(game.ReplicatedStorage.Remotes)

while workspace:GetAttribute("IsLobby") == nil do
	task.wait()
end
if workspace:GetAttribute("IsLobby") then return end

local gui = TradeGui.new()
local latestInventory = nil

-- The bag pane is drawn from the ordinary inventory payload, so it stays right as items are used or picked
-- up while the window is open.
Remotes.InventoryUpdate.OnClientEvent:Connect(function(inventory)
	latestInventory = inventory
	if gui:IsOpen() then gui:RenderBag(inventory) end
end)

gui:On("offer", function(slots, gold)
	Remotes.RequestTradeOffer:FireServer(slots, gold)
end)

gui:On("confirm", function()
	Remotes.RequestTradeConfirm:FireServer()
end)

gui:On("cancel", function()
	Remotes.RequestTradeCancel:FireServer()
end)

Remotes.TradeStateChanged.OnClientEvent:Connect(function(event, partner, payload)
	if event == "opened" then
		gui:Open(partner)
		gui:RenderBag(latestInventory)
		-- Ask for a fresh bag: the window may have opened before any update arrived this session.
		Remotes.RequestInventoryRefresh:FireServer()
	elseif event == "update" then
		if not gui:IsOpen() then gui:Open(partner) end
		gui:RenderBag(latestInventory)
		gui:RenderOffers(payload and payload.mine, payload and payload.theirs)
	elseif event == "completed" then
		-- Coins for a trade that actually closed, the same sound every other transfer makes.
		UiSound.Play("Coin")
		gui:Close()
	elseif event == "closed" then
		gui:Close()
	end
end)
