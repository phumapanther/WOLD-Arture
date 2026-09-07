-- VitalsConfig: every tunable number for HP, hunger, stamina, drowning, falling, and the downed state.
-- Shared by the server (which owns the values) and the client (which only renders them).
-- See docs/superpowers/specs/2026-09-07-vitals-downed-design.md.
local VitalsConfig = {}

VitalsConfig.MaxHP = 100
VitalsConfig.MaxHunger = 100
VitalsConfig.MaxStamina = 100
VitalsConfig.MaxArmor = 100

-- Hunger drains over 30 minutes; once empty it starves HP away over 2 minutes.
VitalsConfig.HungerDrainPerSec = VitalsConfig.MaxHunger / (30 * 60)
VitalsConfig.StarvationDamagePerSec = VitalsConfig.MaxHP / (2 * 60)

-- Swimming: stamina drains only while actually moving through water. When it hits 0 the player drowns,
-- losing all HP in 10 seconds — and drowning kills outright rather than downing (you can't crawl underwater).
VitalsConfig.SwimStaminaDrainPerSec = 5
VitalsConfig.DrowningDamagePerSec = VitalsConfig.MaxHP / 10

-- Falling: harmless below the safe height, then scaling damage. A fall of about 45 studs exceeds MaxHP and
-- kills outright, which is the "ตกที่สูงตายทันที" case.
VitalsConfig.SafeFallStuds = 12
VitalsConfig.FallDamagePerStud = 3
-- Below this Y the player has left the map entirely: instant death, no damage curve.
VitalsConfig.VoidY = -200

VitalsConfig.DownedSeconds = 10 * 60 -- the countdown shown in the centre of the screen
VitalsConfig.DownedWalkSpeed = 6 -- crawling pace
VitalsConfig.DownedHipHeight = 0.6 -- lowers the capsule so the prone body rests near the floor
VitalsConfig.RespawnInvulnSeconds = 10 -- blinking, immune to every damage source

-- Armor is a one-time pool that never refills — not even on respawn. While it lasts it eats half of each
-- incoming COMBAT hit (falls, drowning and starvation ignore it entirely).
VitalsConfig.ArmorAbsorbFraction = 0.5

-- Stock Roblox animations, reused rather than authored: the swim stroke doubles as the crawl once the body is
-- pitched prone (see the spec — the animation only moves the arms, the tilt is applied separately).
VitalsConfig.CrawlAnimation = "rbxassetid://913384386"
VitalsConfig.CrawlIdleAnimation = "rbxassetid://913389285"

VitalsConfig.HitSoundId = "rbxassetid://3932599903" -- punch impact, plays at the victim

-- The HUD can't show finer than this, and it caps remote traffic per player.
VitalsConfig.SendInterval = 0.15

return VitalsConfig
