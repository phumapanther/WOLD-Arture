-- ActionConfig: tunables for the movement actions (roll, slide) and the downed interactions (revive, carry).
-- Shared by server and client; the server owns every decision, the client only renders and sends intent.
--
-- Animation IDs were published from animgen/movement.lua and animgen/revive.lua. An empty string is safe
-- everywhere below: the system still works, it just plays no animation.
local ActionConfig = {}

--------------------------------------------------------------------------------
-- Roll: WASD + Ctrl. Travels in the direction the player is moving.
--------------------------------------------------------------------------------
ActionConfig.Roll = {
	animation = "rbxassetid://135335739335023", -- Roll_Forward, 0.66s
	staminaCost = 25,
	duration = 0.6, -- slightly under the clip so the player isn't locked out after it visually ends
	speed = 34, -- studs/sec while rolling
	-- From the START of a roll. Longer than the roll itself so there is a real beat between them rather than
	-- one rolling straight into the next.
	cooldown = 1.2,
	sound = "rbxassetid://125698568439738", -- assets/sounds/roll.mp3
}

--------------------------------------------------------------------------------
-- Slide: W + Shift (sprinting) + Ctrl. Distance scales with the stamina left, and spends all of it.
--------------------------------------------------------------------------------
ActionConfig.Slide = {
	enterAnimation = "rbxassetid://124112023078211", -- Slide_Enter, 0.26s
	holdAnimation = "rbxassetid://72891274710530", -- Slide_Hold, 0.90s (looped while sliding)
	-- Doubled from 30 on request: a slide is meant to feel like a launch, not a slow scoot. Because distance
	-- under the friction curve is linear in the starting speed, doubling this alone also doubles the distance
	-- (measured: 29.6 -> 59.3 studs on a full bar), so the durations below are unchanged.
	startSpeed = 60,
	-- A slide on a full stamina bar runs for maxDuration; on a near-empty one it barely happens. The server
	-- scales between these by the stamina fraction at the moment the slide starts.
	minDuration = 0.25,
	maxDuration = 1.1,
	friction = 0.82, -- per-second velocity multiplier, so the slide decelerates instead of stopping dead
	cooldown = 0.9,
	minStaminaToStart = 15, -- below this there is nothing to spend and the slide would look broken
	sound = "rbxassetid://111559181369898", -- assets/sounds/slide.mp3
}

-- Both action sounds start when the action does and are cut off when it ends, so a slide is heard for
-- exactly as long as it lasts. The clips open on a moment of silence, which would make a short slide sound
-- like nothing at all; TimePosition skips past it so the sound is there from the first frame.
ActionConfig.SoundStartOffset = 0.06
-- Per action: a roll happens constantly while a slide is occasional, so the roll was the sound that wore
-- thin first. They shared one value until the roll alone needed to come down.
ActionConfig.RollVolume = 0.054
ActionConfig.SlideVolume = 0.18
ActionConfig.SoundDistance = 60

--------------------------------------------------------------------------------
-- Reviving and carrying a downed player.
--------------------------------------------------------------------------------
ActionConfig.Revive = {
	animation = "rbxassetid://110800092274059", -- CPR_Loop, 0.55s (looped through the revive)
	range = 8, -- studs; also the range the prompt appears at
	duration = 5, -- seconds of CPR before the downed player is back up
	hpFraction = 0.35, -- how much HP the revived player wakes with
}

ActionConfig.Carry = {
	holderAnimation = "rbxassetid://92068579403761", -- Carry_Holder, 1.80s (arms/torso only, legs keep walking)
	heldAnimation = "rbxassetid://135226135071936", -- Carry_Held, 2.40s
	range = 8,
	-- Picking someone up takes a moment of holding the key rather than a tap. A tap meant anyone walking
	-- past a downed player could scoop them up instantly, which made carrying feel like theft; the hold is
	-- long enough that the person being carried, and anyone nearby, can see it happening.
	holdSeconds = 5,
	walkSpeed = 6, -- the carrier is slowed while holding someone
	-- Where the carried player sits relative to the carrier's UpperTorso. From animgen/revive.lua's notes.
	jointC0 = CFrame.new(0, 0.15, 1.55) * CFrame.Angles(math.rad(-8), 0, 0),
}

return ActionConfig
