-- HurtSoundController: the sound of something taking your blood, and on nobody else's screen.
--
-- A monster's bite fires it, and so does starving once the hunger bar is empty -- to the player those are the
-- same fact, "something is hurting me", so they get the same voice.
--
-- The server used to build a monster's Sound in the world (Mobs.server.lua), which replicates: everyone
-- within sixty studs heard every bite taken out of everyone else, so a field with a few slimes in it sounded
-- like a battlefield. The server now tells only the player it happened to (Remotes.HurtSound) and the noise
-- is made here, on their client, where it goes no further.
--
-- It fires only when damage actually LANDED -- Vitals.ApplyDamage says so -- which is what keeps a player
-- lying in the crawl making no sound while a slime that can no longer hurt them chews away.
--
-- Played flat through UiSound rather than from the character, for the same reason LastHit is: this is not a
-- thing happening somewhere in the world that you happen to be standing next to, it is a thing happening to
-- you, and it should not fade because the camera swung away.
--
-- Player-on-player blows are deliberately NOT routed through here. PlayerCombat still plays those into the
-- world, because a fight between two people is worth overhearing.
local Remotes = require(game.ReplicatedStorage.Remotes)
local UiSound = require(game.ReplicatedStorage.UI.UiSound)

Remotes.HurtSound.OnClientEvent:Connect(function()
	UiSound.Play("Hurt")
end)
