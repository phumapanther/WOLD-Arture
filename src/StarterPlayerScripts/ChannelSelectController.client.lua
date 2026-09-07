-- ChannelSelectController: only runs in the lobby. game.PrivateServerId cannot be read from the client at all
-- ("PrivateServerId cannot be checked on the client") — ServerConfig.lua replicates IsLobby via a Workspace
-- Attribute instead; wait for it since it may not exist the instant this script starts.
while workspace:GetAttribute("IsLobby") == nil do
	task.wait()
end
if not workspace:GetAttribute("IsLobby") then return end

local Players = game:GetService("Players")
local ChannelSelectGui = require(game.ReplicatedStorage.UI.ChannelSelectGui)
local AvatarThumbnails = require(game.ReplicatedStorage.UI.AvatarThumbnails)
local Remotes = require(game.ReplicatedStorage.Remotes)

local player = Players.LocalPlayer
local gui = ChannelSelectGui.new()
gui.gui.Parent = player:WaitForChild("PlayerGui")
gui:Show()

AvatarThumbnails.OnAnyLoaded(function(userId, content)
	-- only Roleplay has real per-channel row tables; Stories/Tanding are { comingSoon = TextLabel }, not indexable this way
	for channel, row in pairs(gui.rows.Roleplay) do
		if row._playerIds then
			for slot, id in ipairs(row._playerIds) do
				if id == userId then
					gui:SetRowAvatarImage("Roleplay", channel, slot, content)
				end
			end
		end
	end
end)

local function applySnapshot(data)
	for mode, channels in pairs(data) do
		for channel, d in pairs(channels) do
			gui:SetChannelData(mode, channel, d)
			for slot, userId in ipairs(d.playerIds) do
				AvatarThumbnails.Get(userId, function(content)
					if content then gui:SetRowAvatarImage(mode, channel, slot, content) end
				end)
			end
		end
	end
end

Remotes.ChannelList.OnClientEvent:Connect(applySnapshot)

local pendingJoin = 0 -- bumped on every click; a timeout only acts if it's still the most recent attempt

local function resetToError()
	-- ponytail: reset every Roleplay row's status rather than tracking which one was mid-join (only ever one in
	-- flight per client); Stories/Tanding aren't real per-channel tables (see ChannelSelectGui.new), so they're excluded.
	for channel in pairs(gui.rows.Roleplay) do
		gui:SetRowStatus("Roleplay", channel, "error")
	end
end

Remotes.JoinFailed.OnClientEvent:Connect(function(reason)
	warn("[ChannelSelect] join failed:", reason)
	pendingJoin += 1 -- a real answer arrived; any in-flight timeout for this attempt should no-op
	resetToError()
end)

gui:OnJoin(function(mode, channel)
	gui:SetRowStatus(mode, channel, "connecting")
	Remotes.JoinChannel:FireServer(mode, channel)
	pendingJoin += 1
	local myAttempt = pendingJoin
	task.delay(15, function()
		-- covers any case the server never answers at all (e.g. Studio's TeleportService 403 doesn't reach
		-- TeleportInitFailed) so the button never gets stuck on "connecting..." forever
		if pendingJoin == myAttempt then
			warn("[ChannelSelect] join timed out waiting for a server response")
			resetToError()
		end
	end)
end)
