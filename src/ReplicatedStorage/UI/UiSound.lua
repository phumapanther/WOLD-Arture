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

	-- Play() on a sound Roblox has not finished fetching does nothing, and there is no second attempt: the
	-- asset arrives a moment later and sits there silent. A one-shot can live with that, since it is over
	-- before anyone notices; a loop cannot, because the whole point is that it runs for a while.
	--
	-- So a loop that was not ready is started again when it becomes ready. Loaded already, this never fires.
	if not sound.IsLoaded then
		sound.Loaded:Once(function()
			-- Unless whoever asked for it has already stopped it -- a craft that finished during the fetch
			-- must not leave a loop running behind it.
			if sound.Parent and not sound.IsPlaying then
				sound:Play()
			end
		end)
	end

	return sound
end

return UiSound
