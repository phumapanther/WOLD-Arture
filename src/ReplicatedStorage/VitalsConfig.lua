-- VitalsConfig: every tunable number for HP, hunger, stamina, drowning, falling, and the downed state.
-- Shared by the server (which owns the values) and the client (which only renders them).
-- See docs/superpowers/specs/2026-09-07-vitals-downed-design.md.
local VitalsConfig = {}

VitalsConfig.MaxHP = 100
VitalsConfig.MaxHunger = 100
VitalsConfig.MaxStamina = 100

-- Mana is spent in whole pips, not a smooth bar: the HUD draws three gems and every weapon skill costs one,
-- so the value is the number of pips rather than a 0-100 pool.
VitalsConfig.MaxMana = 3
VitalsConfig.ManaRegenSeconds = 24 -- seconds to regain one pip
-- The bar is drawn against the armor you are WEARING, not an absolute ceiling: the bare starter armor should
-- read full at 20/20, not a fifth full at 20/100. Better armor raises this along with the value.
VitalsConfig.MaxArmor = 20

-- Hunger drains over 30 minutes; once empty it starves HP away over 2 minutes.
VitalsConfig.HungerDrainPerSec = VitalsConfig.MaxHunger / (30 * 60)
VitalsConfig.StarvationDamagePerSec = VitalsConfig.MaxHP / (2 * 60)

-- How often an empty stomach is allowed to make a noise, in seconds.
--
-- Starving is the one damage source with no event behind it: no blow lands, nothing hits the ground, the bar
-- simply drains. So it borrows the hurt sound to say what is happening -- but it is applied every FRAME, and
-- a sound sixty times a second is not a warning, it is a wall. Roughly a monster's attack pace, which is the
-- rhythm the sound already means.
VitalsConfig.StarveSoundSeconds = 2

-- Swimming: stamina drains only while actually moving through water. When it hits 0 the player drowns,
-- losing all HP in 10 seconds — and drowning kills outright rather than downing (you can't crawl underwater).
VitalsConfig.SwimStaminaDrainPerSec = 5
VitalsConfig.DrowningDamagePerSec = VitalsConfig.MaxHP / 10

-- Falling: harmless below the safe height, then scaling damage. A fall of about 45 studs exceeds MaxHP and
-- kills outright, which is the "ตกที่สูงตายทันที" case.
-- How far you can fall unhurt, in studs. Flat 25 at the user's request.
--
-- This replaces a rule measured in body-lengths. That was fairer to avatars of different sizes, but it made
-- the safe height something a player could not know: two people standing side by side took damage at
-- different heights, and neither could see why. A number everyone shares is easier to build around.
VitalsConfig.SafeFallStuds = 25


-- Cut 80% at the user's request: 3 a stud to 0.6. A fall is now a setback rather than a death sentence --
-- past the safe height of two body-lengths, a 30-stud drop costs about 12 blood instead of 60.
VitalsConfig.FallDamagePerStud = 0.6
-- Below this Y the player has left the map entirely: instant death, no damage curve.
VitalsConfig.VoidY = -200

VitalsConfig.DownedSeconds = 10 * 60 -- the countdown shown in the centre of the screen
VitalsConfig.DownedWalkSpeed = 6 -- crawling pace
VitalsConfig.DownedHipHeight = 0.6 -- lowers the capsule so the prone body rests near the floor
VitalsConfig.RespawnInvulnSeconds = 10 -- blinking, immune to every damage source

-- Armor eats half of each incoming COMBAT hit (falls, drowning and starvation ignore it entirely). It does
-- NOT refill on respawn — only a level-up restores it (Vitals.RefillOnLevelUp).
VitalsConfig.ArmorAbsorbFraction = 0.5
-- The "bare" armor everyone starts with. An 8-damage punch sends half (4) into armor, so 20 points is five
-- punches before it breaks — the fragile starter set the user described. Real armor items come later.
VitalsConfig.StartingArmor = VitalsConfig.MaxArmor

-- Stock Roblox animations, reused rather than authored: the swim stroke doubles as the crawl once the body is
-- pitched prone (see the spec — the animation only moves the arms, the tilt is applied separately).
-- The horizontal forward stroke only. The matching "swim idle" (913389285) is deliberately NOT used: it is a
-- treading-water pose, upright and paddling on the spot, which reads nothing like crawling.
VitalsConfig.CrawlAnimation = "rbxassetid://913384386"

-- Punch impact, played at the victim: the user's own uploaded ตี.mp3.
-- Setting this to "" is safe — combat still works, just silently.
VitalsConfig.HitSoundId = "rbxassetid://132299141332172"
VitalsConfig.HitSoundVolume = 0.3
-- The clip runs 1.35s but punches land about once a second, so trim playback to keep consecutive hits
-- from stacking into a drone.
VitalsConfig.HitSoundMaxSeconds = 0.7

-- Seeing stars: hands clamped to the head, body rolling from side to side. Authored by animgen/status.lua
-- (Dizzy_Loop) rather than borrowed, because Roblox ships no stock animation that reads as dizzy -- the
-- crawl could borrow the swim stroke, but there is nothing here to borrow.
--
VitalsConfig.DizzyAnimation = "rbxassetid://83117086266774"

-- The HUD can't show finer than this, and it caps remote traffic per player.
VitalsConfig.SendInterval = 0.15

return VitalsConfig
