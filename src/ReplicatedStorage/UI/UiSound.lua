-- UiSound: one-shot interface sounds.
--
-- A click, a notification, a ringtone. These are not positional -- they are things happening TO the player,
-- not in the world -- so they play from SoundService rather than from a part, at a flat volume with no
-- distance falloff.
--
-- Client-only. Calling this on the server would play nothing and cost a wasted instance.
local SoundService = game:GetService("SoundService")
local Debris = game:GetService("Debris")
local SoundscapeConfig = require(script.Parent.Parent.SoundscapeConfig)

local UiSound = {}

local Config = SoundscapeConfig.Interface

-- Plays `name` from SoundscapeConfig.Interface once. An unknown or unset name is silently ignored, so a
-- caller naming a sound that does not exist yet is harmless rather than an error.
function UiSound.Play(name)
	local id = Config[name]
	if type(id) ~= "string" or id == "" then return end

	local sound = Instance.new("Sound")
	sound.SoundId = id
	sound.Volume = Config.Volume
	sound.Parent = SoundService
	sound:Play()
	-- Cleaned up after a generous margin rather than on Ended: a sound that never loads never fires Ended,
	-- and would sit in SoundService forever.
	Debris:AddItem(sound, 10)
	return sound
end

-- A looping sound that has to be stopped by hand, for the ringtone: it rings until the call is answered or
-- given up on, which this module cannot know. The caller keeps the returned Sound and destroys it.
function UiSound.Loop(name)
	local id = Config[name]
	if type(id) ~= "string" or id == "" then return nil end

	local sound = Instance.new("Sound")
	sound.SoundId = id
	sound.Volume = Config.Volume
	sound.Looped = true
	sound.Parent = SoundService
	sound:Play()
	return sound
end

return UiSound
