-- HudController: only runs in channel servers (not the lobby, which has its own ChannelSelectController screen).
-- It's always true in Studio Play (Play is always the lobby), so this never shows locally unless you flip the flag.
local FORCE_SHOW_IN_STUDIO_FOR_TESTING = false -- ponytail: flip to true to preview this screen in Play; flip back before publishing

while workspace:GetAttribute("IsLobby") == nil do
	task.wait()
end
if workspace:GetAttribute("IsLobby") and not FORCE_SHOW_IN_STUDIO_FOR_TESTING then return end

local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")
local TeleportService = game:GetService("TeleportService")
local HudGui = require(game.ReplicatedStorage.UI.HudGui)

-- Same as the lobby: no chat/playerlist UI built for this yet.
pcall(function() StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Chat, false) end)
pcall(function() StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false) end)

local player = Players.LocalPlayer
local gui = HudGui.new()
gui.gui.Parent = player:WaitForChild("PlayerGui")
gui:Show()

-- Static full vitals until sub-project 1 (player data & life cycle) wires up real values.
for _, key in ipairs({ "hp", "hunger" }) do
	gui:SetBarFraction(key, 1)
end
gui:SetArmorFraction(1)
gui:SetStaminaFraction(1)
gui:SetManaPips(3)

gui:OnLobbyRequested(function()
	-- A non-reserved server (empty PrivateServerId) is exactly what ServerConfig treats as the lobby, so a plain
	-- Teleport back to this same place lands the player in the public lobby pool without needing an access code.
	TeleportService:Teleport(game.PlaceId, player)
end)
