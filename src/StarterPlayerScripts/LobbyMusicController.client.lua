-- LobbyMusicController: something to listen to while picking a server.
--
-- The lobby is the one screen where a player is deliberately waiting, so it is the one screen that wants
-- music. The channel servers do not: out in the world the soundscape is the footsteps and the ambience, and
-- a track playing over that would fight it.
--
-- Runs only in the lobby -- the inverse of every other controller's guard, which all return there.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local SoundscapeConfig = require(game.ReplicatedStorage.SoundscapeConfig)

while workspace:GetAttribute("IsLobby") == nil do
	task.wait()
end
if not workspace:GetAttribute("IsLobby") then return end

local Music = SoundscapeConfig.LobbyMusic
if not Music or #Music.Tracks == 0 then return end

--------------------------------------------------------------------------------

-- Parented to SoundService: music is not coming from anywhere in the world, so it should not pan or fade
-- with the camera.
local sound = Instance.new("Sound")
sound.Name = "WOLD_LobbyMusic"
sound.Volume = 0 -- fades up; nothing slams in at full volume on join
sound.Looped = false -- a track ending picks the next one, rather than repeating the same one forever
sound.Parent = SoundService

-- A different track each time someone lands in the lobby, and a different one again when one ends, so a
-- player who bounces in and out is not met by the same opening bar every time.
local lastIndex = 0
local function pickTrack()
	if #Music.Tracks == 1 then return Music.Tracks[1] end
	local index
	repeat
		index = math.random(1, #Music.Tracks)
	until index ~= lastIndex -- never the same track twice in a row
	lastIndex = index
	return Music.Tracks[index]
end

local function playNext()
	sound.SoundId = pickTrack()
	sound:Play()
end

sound.Ended:Connect(playNext)
playNext()

--------------------------------------------------------------------------------

-- Fading out is driven by an attribute rather than by this script watching the UI: the join flow already
-- blacks the screen out and teleports, and it should not have to know a music player exists. Anything that
-- wants the music gone sets WOLD_MusicFadeOut.
local fadingOut = false
workspace:GetAttributeChangedSignal("WOLD_MusicFadeOut"):Connect(function()
	fadingOut = workspace:GetAttribute("WOLD_MusicFadeOut") == true
end)

RunService.Heartbeat:Connect(function(dt)
	local target = fadingOut and 0 or Music.Volume
	local step = dt / Music.FadeSeconds * Music.Volume
	if sound.Volume < target then
		sound.Volume = math.min(target, sound.Volume + step)
	elseif sound.Volume > target then
		sound.Volume = math.max(target, sound.Volume - step)
	end
end)
