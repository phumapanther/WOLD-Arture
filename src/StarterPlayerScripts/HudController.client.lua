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
gui:SetManaPips(3)

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
end)

gui:OnLobbyRequested(function()
	-- Server-authoritative: it saves the player's position THEN teleports, because PlayerRemoving does not
	-- reliably fire before a client-initiated Teleport actually removes the character (documented Roblox
	-- behavior) — calling TeleportService directly from here lost the save. See PlayerPosition.server.lua.
	Remotes.RequestReturnToLobby:FireServer()
end)
