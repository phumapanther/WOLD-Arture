-- ChannelSelectController: only runs in the lobby. game.PrivateServerId cannot be read from the client at all
-- ("PrivateServerId cannot be checked on the client") — ServerConfig.lua replicates IsLobby via a Workspace
-- Attribute instead; wait for it since it may not exist the instant this script starts.
while workspace:GetAttribute("IsLobby") == nil do
	task.wait()
end
if not workspace:GetAttribute("IsLobby") then return end

local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")
local ChannelSelectGui = require(game.ReplicatedStorage.UI.ChannelSelectGui)
local AvatarThumbnails = require(game.ReplicatedStorage.UI.AvatarThumbnails)
local Responsive = require(game.ReplicatedStorage.UI.Responsive)
local Remotes = require(game.ReplicatedStorage.Remotes)

-- Hide the default chat window and player list while the channel-select screen is up (for now, per request —
-- nothing about the lobby needs either yet). This is local-client core GUI state; teleporting into a channel
-- server starts a fresh client so it doesn't carry this over.
pcall(function() StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Chat, false) end)
pcall(function() StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false) end)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Lock the lobby to landscape on phones and tablets. The channel rows are a wide strip — name, avatar
-- gallery, then the count and JOIN — and portrait squeezes all of that into roughly half the width.
-- LandscapeSensor rather than LandscapeLeft so the device can still flip between the two landscape
-- orientations. Joining a channel teleports to a new server, which starts a fresh client with the player's
-- own preference back, so nothing needs restoring here.
playerGui.ScreenOrientation = Enum.ScreenOrientation.LandscapeSensor

-- The GUI branches on portrait vs landscape at BUILD time (rows and the header are arranged differently, not
-- merely scaled), so rotating the phone has to rebuild it. `gui` is therefore reassigned rather than captured:
-- every handler below goes through this upvalue, and `lastSnapshot` replays the channel data into the new
-- instance so a rotation doesn't blank the list until the next server broadcast.
local gui
local lastSnapshot = nil
local locked = false -- survives a rebuild: a rotation must not un-black a screen that is mid-join

local buildGui, applySnapshot

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

function applySnapshot(data)
	lastSnapshot = data
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
	locked = false
	gui:Unlock() -- only a failed/timed-out join reaches here; a successful one blacks out the screen for good
	for channel in pairs(gui.rows.Roleplay) do
		gui:SetRowStatus("Roleplay", channel, "error")
	end
end

Remotes.JoinFailed.OnClientEvent:Connect(function(reason)
	warn("[ChannelSelect] join failed:", reason)
	pendingJoin += 1 -- a real answer arrived; any in-flight timeout for this attempt should no-op
	resetToError()
end)

local function onJoin(mode, channel)
	-- Lock immediately, before firing the remote or waiting on any response: the screen blacks out on this
	-- click, not once the server answers, so a second click during the (network) gap in between is impossible.
	locked = true
	gui:Lock()
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
end

function buildGui()
	local old = gui
	gui = ChannelSelectGui.new()
	gui:OnJoin(onJoin)
	gui:OnRefreshRequested(function()
		gui:FlashRefresh()
		Remotes.RequestChannelRefresh:FireServer()
	end)
	gui.gui.Parent = playerGui
	gui:Show()
	if locked then gui:Lock() end
	if lastSnapshot then applySnapshot(lastSnapshot) end
	if old then old.gui:Destroy() end
end

buildGui()

-- Rebuild on rotation / resize, but only when the portrait-vs-landscape answer actually flips: a plain resize
-- is handled by the UIScale already, and tearing down the screen mid-join would be jarring.
local wasPortrait = Responsive.IsPortrait()
Responsive.OnViewportChanged(function()
	local isPortrait = Responsive.IsPortrait()
	if isPortrait == wasPortrait then return end
	wasPortrait = isPortrait
	buildGui()
end)
