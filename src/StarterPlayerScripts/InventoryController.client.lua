-- InventoryController: opens the bag on I (or the touch button), renders what the server sends, and turns
-- clicks into requests. Every decision belongs to the server — this only asks.
--
-- Clicking a slot does the obvious thing for what is in it: weapons and armor equip, consumables are used,
-- junk does nothing. That avoids a context menu, which would be painful on a phone.
while workspace:GetAttribute("IsLobby") == nil do
	task.wait()
end
if workspace:GetAttribute("IsLobby") then return end

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local InventoryGui = require(game.ReplicatedStorage.UI.InventoryGui)
local ItemCatalog = require(game.ReplicatedStorage.ItemCatalog)
local Remotes = require(game.ReplicatedStorage.Remotes)

local player = Players.LocalPlayer
local gui = InventoryGui.new()
gui.gui.Parent = player:WaitForChild("PlayerGui")

local latest = { slots = {}, equipped = {}, gold = 0, weight = 0, maxWeight = 1 }

Remotes.InventoryUpdate.OnClientEvent:Connect(function(data)
	latest = data
	-- Only redraw while open: the panel is hidden most of the time and this fires on every pickup.
	if gui:IsOpen() then gui:Render(latest) end
end)

local function toggle()
	if gui:IsOpen() then
		gui:Hide()
	else
		gui:Render(latest)
		gui:Show()
	end
end

-- Exposed to the touch controller the same way the roll button reaches ActionController: a BindableEvent
-- rather than a global, so load order cannot break it.
local bindable = Instance.new("BindableEvent")
bindable.Name = "WOLD_ToggleInventory"
bindable.Parent = player:WaitForChild("PlayerGui")
bindable.Event:Connect(toggle)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	if input.KeyCode == Enum.KeyCode.I then
		toggle()
	elseif input.KeyCode == Enum.KeyCode.Escape and gui:IsOpen() then
		gui:Hide()
	end
end)

gui:OnCloseRequested(function()
	gui:Hide()
end)

gui:OnSortRequested(function()
	Remotes.RequestAutoSort:FireServer()
end)

gui:OnSlotClicked(function(index)
	local slot = latest.slots and latest.slots[index]
	if not slot then return end
	local item = ItemCatalog.Get(slot.id)
	if not item then return end

	if item.kind == "weapon" or item.kind == "armor" then
		Remotes.RequestEquip:FireServer(index)
	elseif item.kind == "consumable" then
		Remotes.RequestUseItem:FireServer(index)
	end
	-- junk: nothing to do yet; selling arrives with the economy systems
end)

gui:OnEquipSlotClicked(function(kind)
	if latest.equipped and latest.equipped[kind] then
		Remotes.RequestUnequip:FireServer(kind)
	end
end)
