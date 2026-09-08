-- HudController: only runs in channel servers (not the lobby, which has its own ChannelSelectController screen).
-- It's always true in Studio Play (Play is always the lobby), so this never shows locally unless you flip the flag.
local FORCE_SHOW_IN_STUDIO_FOR_TESTING = false -- ponytail: flip to true to preview this screen in Play; flip back before publishing

while workspace:GetAttribute("IsLobby") == nil do
	task.wait()
end
if workspace:GetAttribute("IsLobby") and not FORCE_SHOW_IN_STUDIO_FOR_TESTING then return end

local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")
local HudGui = require(game.ReplicatedStorage.UI.HudGui)
local Remotes = require(game.ReplicatedStorage.Remotes)

-- Same as the lobby: no chat/playerlist UI built for this yet.
pcall(function() StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Chat, false) end)
pcall(function() StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false) end)

local player = Players.LocalPlayer
local gui = HudGui.new()
gui.gui.Parent = player:WaitForChild("PlayerGui")
gui:Show()

-- HP, hunger, stamina and armor are all real now, driven by Vitals.lua on the server. Mana is still static
-- (no mana system exists yet).
gui:SetBarFraction("hp", 1)
gui:SetBarFraction("hunger", 1)
gui:SetStaminaFraction(1)
gui:SetArmorFraction(1) -- everyone starts in the bare starter armor, which reads full until it is chipped away
gui:SetManaPips(3) -- real value arrives with the first VitalsUpdate below

-- EXP bar: level and progress toward the next one.
gui:SetExp(1, 0)
Remotes.ProgressionUpdate.OnClientEvent:Connect(function(p)
	local fraction = 0
	if p.expForNext and p.expForNext > 0 and p.expForNext ~= math.huge then
		fraction = p.exp / p.expForNext
	elseif p.expForNext == math.huge then
		fraction = 1 -- level capped: show the bar full rather than empty
	end
	gui:SetExp(p.level, fraction)
end)

Remotes.VitalsUpdate.OnClientEvent:Connect(function(vitals)
	gui:SetBarFraction("hp", vitals.hp)
	gui:SetBarFraction("hunger", vitals.hunger)
	gui:SetStaminaFraction(vitals.stamina)
	gui:SetArmorFraction(vitals.armor)
	gui:SetManaPips(vitals.mana or 0)
end)

-- Hotbar: the first six consumables in the bag, so a potion is one key away without opening it. Keys 1-6 and
-- tapping a slot both use the item; the server re-validates the slot either way.
local ItemCatalog = require(game.ReplicatedStorage.ItemCatalog)
local UserInputService = game:GetService("UserInputService")

local hotbarSlots = {} -- [hotbar index] = inventory slot index, so a press maps back to the real bag

local function refreshHotbar(inventory)
	local entries = {}
	hotbarSlots = {}
	local n = 0
	for index = 1, 24 do
		local slot = inventory.slots and inventory.slots[index]
		if slot then
			local item = ItemCatalog.Get(slot.id)
			if item and item.kind == "consumable" then
				n += 1
				entries[n] = { id = slot.id, count = slot.count, icon = item.icon, name = item.name }
				hotbarSlots[n] = index
				if n >= 6 then break end
			end
		end
	end
	gui:SetHotbar(entries)
end

local function useHotbar(index)
	local slotIndex = hotbarSlots[index]
	if slotIndex then Remotes.RequestUseItem:FireServer(slotIndex) end
end

gui:OnHotbarUsed(useHotbar)

Remotes.InventoryUpdate.OnClientEvent:Connect(refreshHotbar)

local NUMBER_KEYS = {
	[Enum.KeyCode.One] = 1, [Enum.KeyCode.Two] = 2, [Enum.KeyCode.Three] = 3,
	[Enum.KeyCode.Four] = 4, [Enum.KeyCode.Five] = 5, [Enum.KeyCode.Six] = 6,
}
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	local index = NUMBER_KEYS[input.KeyCode]
	if index then useHotbar(index) end
end)

gui:OnLobbyRequested(function()
	-- Server-authoritative: it saves the player's position THEN teleports, because PlayerRemoving does not
	-- reliably fire before a client-initiated Teleport actually removes the character (documented Roblox
	-- behavior) — calling TeleportService directly from here lost the save. See PlayerPosition.server.lua.
	Remotes.RequestReturnToLobby:FireServer()
end)
