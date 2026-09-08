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
		guardAnimation = "rbxassetid://118766016678017", -- Combat_Guard
		guardWalkSpeed = 6, -- slower than Normal (8); sprinting is blocked entirely while guarding
		idleTimeout = 4, -- seconds without an attack before the guard drops on its own

		-- Attacks cycle in order, one per click. Fists alternate right/left forever — a weapon can instead
		-- define a 3- or 4-hit chain that ends in a longer recovery, which is why this is a list.
		attacks = {
			{ animation = "rbxassetid://123567461001098", damage = 8, windup = 0.1, active = 0.12, recovery = 0.2, range = 5.5 }, -- Punch_Right
			{ animation = "rbxassetid://74899499463368", damage = 8, windup = 0.1, active = 0.12, recovery = 0.2, range = 5.5 }, -- Punch_Left
		},

		-- After the last attack in the chain, wait this long before the chain can start again. Fists set 0 so
		-- punches stay one-per-second-ish with no forced pause; a sword's 3-hit combo would set 0.5-1.0 here.
		chainResetDelay = 0,
		-- A click landing later than this after the previous one starts the chain over from attack 1 instead
		-- of continuing it.
		chainWindow = 1.2,
	},

	-- The four equippable weapons. Each reuses the punch animations for now: code-built swing sequences per
	-- weapon are a separate animgen pass, and an empty id is safe (the attack still lands, it just looks like
	-- a punch). Damage, reach and timing already differ, which is what makes them feel distinct.
	-- Each weapon names its OWN idle and swing animations, built by animgen/weapons.lua. Publish those
	-- sequences and paste the ids here; an empty id is safe, the attack still lands and just looks like a
	-- punch. `projectile` marks the ranged weapons: those fire instead of swinging a melee hitbox.
	Sword = {
		idleAnimation = "rbxassetid://104032619103694", -- Sword_Idle
		guardAnimation = "",
		guardWalkSpeed = 6,
		idleTimeout = 4,
		attacks = {
			{ animation = "rbxassetid://129710823629195", damage = 18, windup = 0.15, active = 0.15, recovery = 0.3, range = 7 }, -- Sword_Swing_Left
			{ animation = "rbxassetid://114792436974678", damage = 18, windup = 0.15, active = 0.15, recovery = 0.35, range = 7 }, -- Sword_Swing_Right
		},
		chainResetDelay = 0.35, -- the user asked for a beat between swings
		chainWindow = 1.4,
	},
	Bow = {
		idleAnimation = "rbxassetid://109624563861296", -- Bow_Idle
		guardAnimation = "",
		guardWalkSpeed = 7,
		idleTimeout = 4,
		attacks = {
			{ animation = "rbxassetid://73671392887806", damage = 16, windup = 0.15, active = 0.05, recovery = 0.45, range = 0, -- Bow_Shoot
				-- An arrow floors whoever it hits for a few seconds.
				effect = "knockdown", effectSeconds = 3,
				projectile = { kind = "arrow", speed = 110, life = 0.7, size = Vector3.new(0.18, 0.18, 2.4),
					color = Color3.fromRGB(222, 198, 152), material = Enum.Material.Wood } },
		},
		chainResetDelay = 0.3,
		chainWindow = 1.2,
	},
	Staff = {
		idleAnimation = "rbxassetid://77326470579844", -- Staff_Idle
		guardAnimation = "",
		guardWalkSpeed = 6,
		idleTimeout = 4,
		attacks = {
			{ animation = "rbxassetid://103928195222614", damage = 14, windup = 0.2, active = 0.05, recovery = 0.4, range = 0, -- Staff_Swing
				-- A beam, not a travelling shot: it reaches its full length at once and fades.
				projectile = { kind = "beam", length = 22, life = 0.25, size = Vector3.new(0.5, 0.5, 1),
					color = Color3.fromRGB(120, 236, 180), material = Enum.Material.Neon } },
		},
		chainResetDelay = 0.35,
		chainWindow = 1.2,
	},
	Spellbook = {
		idleAnimation = "rbxassetid://95948481934811", -- Spellbook_Idle
		guardAnimation = "",
		guardWalkSpeed = 7,
		idleTimeout = 4,
		attacks = {
			{ animation = "rbxassetid://94236406810598", damage = 15, windup = 0.2, active = 0.05, recovery = 0.4, range = 0, -- Spellbook_Cast
				-- Dark magic leaves the target wading through treacle.
				effect = "slow", effectSeconds = 3, effectFactor = 0.45,
				projectile = { kind = "orb", speed = 55, life = 0.9, size = Vector3.new(1.6, 1.6, 1.6),
					color = Color3.fromRGB(58, 26, 86), material = Enum.Material.Neon } },
		},
		chainResetDelay = 0.3,
		chainWindow = 1.2,
	},
}

CombatConfig.DefaultWeapon = "Fists"

-- Every swing costs the weapon a point of durability; at zero it breaks and is destroyed, which is what the
-- Architect role and the repair hammer exist to prevent.
CombatConfig.DurabilityPerSwing = 1

-- Hitbox is a sphere in front of the attacker; range comes from the attack. Kept simple deliberately — the
-- RaycastHitboxV4 approach the user referenced is worth revisiting once weapons with real geometry exist.
CombatConfig.HitboxHeightOffset = 0

return CombatConfig
