-- CombatConfig: every weapon's attack definition in one table, so adding a sword later is a data change here
-- rather than new logic in the combat scripts. Fists are just the first entry.
--
-- Animation IDs: KeyframeSequences are built by animgen/combat.lua into ServerStorage.WOLD_Animations. Until
-- they're published (right-click in Studio -> "Save to Roblox"), leave the id fields as "" — the combat system
-- runs fine without animations, it just won't look right. Paste the published rbxassetid:// strings in here.
local CombatConfig = {}

CombatConfig.Weapons = {
	Fists = {
		-- Guard: held stance entered on the first click, dropped after IdleTimeout with no further clicks.
		guardAnimation = "rbxassetid://78177954414406", -- Combat_Guard
		guardWalkSpeed = 6, -- slower than Normal (8); sprinting is blocked entirely while guarding
		idleTimeout = 4, -- seconds without an attack before the guard drops on its own

		-- Attacks cycle in order, one per click. Fists alternate right/left forever — a weapon can instead
		-- define a 3- or 4-hit chain that ends in a longer recovery, which is why this is a list.
		attacks = {
			{ animation = "rbxassetid://139731608829349", damage = 8, windup = 0.1, active = 0.12, recovery = 0.2, range = 5.5 }, -- Punch_Right
			{ animation = "rbxassetid://79645317544489", damage = 8, windup = 0.1, active = 0.12, recovery = 0.2, range = 5.5 }, -- Punch_Left
		},

		-- After the last attack in the chain, wait this long before the chain can start again. Fists set 0 so
		-- punches stay one-per-second-ish with no forced pause; a sword's 3-hit combo would set 0.5-1.0 here.
		chainResetDelay = 0,
		-- A click landing later than this after the previous one starts the chain over from attack 1 instead
		-- of continuing it.
		chainWindow = 1.2,
	},
}

CombatConfig.DefaultWeapon = "Fists"

-- Hitbox is a sphere in front of the attacker; range comes from the attack. Kept simple deliberately — the
-- RaycastHitboxV4 approach the user referenced is worth revisiting once weapons with real geometry exist.
CombatConfig.HitboxHeightOffset = 0

return CombatConfig
