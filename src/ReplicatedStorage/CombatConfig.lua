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
		idleAnimation = "rbxassetid://103704114129246", -- Sword_Idle
		guardAnimation = "",
		guardWalkSpeed = 6,
		idleTimeout = 4,
		-- One slash rather than a left/right pair: animgen/sword.lua builds a single Sword_Slash whose stages
		-- are wind-up 0-0.24, strike 0.24-0.36 (the HitStart/HitEnd markers), then follow-through and
		-- recovery out to 0.66. The windup/active numbers below mirror those marker times exactly, so the
		-- hitbox is live precisely while the blade is sweeping.
		attacks = {
			{ animation = "rbxassetid://138133285610075", damage = 18, windup = 0.24, active = 0.12, recovery = 0.3, range = 7 }, -- Sword_Slash
		},
		chainResetDelay = 0.35, -- the user asked for a beat between swings
		chainWindow = 1.4,
	},
	-- The three tools fight exactly as the sword does -- same idle, same slash, same timing -- because that
	-- is what the user asked for, and because a tool is a heavy thing on a stick, which is what the sword
	-- animation already shows. Only the damage differs, and it is lower than the sword's 18: a tool swung at
	-- a person should lose to a weapon built for it.
	Axe = {
		idleAnimation = "rbxassetid://103704114129246", -- Sword_Idle
		guardAnimation = "",
		guardWalkSpeed = 6,
		idleTimeout = 4,
		attacks = {
			{ animation = "rbxassetid://138133285610075", damage = 14, windup = 0.24, active = 0.12, recovery = 0.3, range = 7 }, -- Sword_Slash
		},
		chainResetDelay = 0.35,
		chainWindow = 1.4,
	},
	Pickaxe = {
		idleAnimation = "rbxassetid://103704114129246", -- Sword_Idle
		guardAnimation = "",
		guardWalkSpeed = 6,
		idleTimeout = 4,
		attacks = {
			{ animation = "rbxassetid://138133285610075", damage = 13, windup = 0.24, active = 0.12, recovery = 0.3, range = 7 }, -- Sword_Slash
		},
		chainResetDelay = 0.35,
		chainWindow = 1.4,
	},
	Shovel = {
		idleAnimation = "rbxassetid://103704114129246", -- Sword_Idle
		guardAnimation = "",
		guardWalkSpeed = 6,
		idleTimeout = 4,
		attacks = {
			{ animation = "rbxassetid://138133285610075", damage = 11, windup = 0.24, active = 0.12, recovery = 0.3, range = 7 }, -- Sword_Slash
		},
		chainResetDelay = 0.35,
		chainWindow = 1.4,
	},
	-- The fishing rod. It swings with the sword's animation because a cast IS a swing, and it holds with
	-- the sword's two-handed idle. The damage never lands -- PlayerCombat routes a rod click to the fishing
	-- system and leaves the hitbox shut -- so these numbers only shape the timing of the animation.
	FishingRod = {
		idleAnimation = "rbxassetid://103704114129246", -- Sword_Idle, the two-handed hold
		guardAnimation = "",
		guardWalkSpeed = 7,
		idleTimeout = 4,
		attacks = {
			{ animation = "rbxassetid://138133285610075", damage = 3, windup = 0.24, active = 0.12, recovery = 0.3, range = 6 }, -- Sword_Slash
		},
		chainResetDelay = 0.35,
		chainWindow = 1.4,
	},
	-- The pistol. A projectile weapon, so it gets the crosshair and the auto-turn that come with one, and
	-- the aim point is validated server-side exactly as the bow's is.
	--
	-- Damage 0 on purpose: the shot's whole effect is the five seconds face-down. Something that both
	-- floored a target AND hurt them would be strictly better than every other weapon in the game.
	Pistol = {
		-- Every shot spends one of these from the bag. Named here rather than checked for by name in the
		-- combat code, so a crossbow added later only has to say which bolt it eats.
		ammo = "Bullet",
		idleAnimation = "rbxassetid://109624563861296", -- Bow_Idle, the two-handed ready stance
		guardAnimation = "",
		guardWalkSpeed = 7,
		idleTimeout = 4,
		attacks = {
			-- Windup 0.35 rather than 0.1, so the shot READS. At a tenth of a second the ready stance was
			-- over before it registered and the bullet appeared to leave on the click itself; a third of a
			-- second is long enough to see the pistol come up and be aimed, and short enough that it still
			-- feels like a reaction rather than a wait. The aim is captured at the click and carried
			-- through the windup, so the delay never costs the player the shot they lined up.
			{ animation = "rbxassetid://73671392887806", damage = 0, windup = 0.35, active = 0.05, recovery = 0.55, range = 0, -- Bow_Shoot
				effect = "knockdown", effectSeconds = 5,
				projectile = { kind = "bullet", speed = 320, life = 0.5, size = Vector3.new(0.12, 0.12, 0.6),
					color = Color3.fromRGB(255, 232, 160), material = Enum.Material.Neon,
					-- Sighted above the head rather than from the chest: a head-height line clears the
					-- shoulders of anyone standing between the shooter and what they are aiming at.
					muzzleHeight = 3.2 } },
		},
		chainResetDelay = 0.6,
		chainWindow = 1.4,
	},
	Bow = {
		idleAnimation = "rbxassetid://109624563861296", -- Bow_Idle
		guardAnimation = "",
		guardWalkSpeed = 7,
		idleTimeout = 4,
		attacks = {
			-- Longer than it was, for the same reason as the pistol: a draw that cannot be seen is not a
			-- draw. A fraction more than the pistol's, since drawing a bow is visibly more work than
			-- raising a handgun.
			{ animation = "rbxassetid://73671392887806", damage = 16, windup = 0.4, active = 0.05, recovery = 0.45, range = 0, -- Bow_Shoot
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

-- Attack sounds, one pair per weapon: `cast` plays at the attacker the moment the swing or shot goes off,
-- `hit` plays at whoever it lands on. Generated by tools/make-sounds.py into assets/sounds/ -- upload those
-- and paste the ids here. An empty id is safe: that half simply stays silent, and `hit` falls back to
-- VitalsConfig.HitSoundId so an unconfigured weapon still thumps like a punch.
CombatConfig.Sounds = {
	-- Bare fists. No cast sound -- a punch makes noise when it lands, not when it is thrown. The impact is
	-- much quieter than any weapon: it is the most frequent sound in the game, and at weapon volume it
	-- drowned everything else out. Given its own entry rather than lowering VitalsConfig.HitSoundVolume,
	-- which is the fallback every weapon without its own hitVolume also reads.
	Fists = {
		cast = "",
		hit = "rbxassetid://132299141332172",
		hitVolume = 0.06,
	},
	Sword = {
		cast = "rbxassetid://130522255329953", -- assets/sounds/sword_swing.mp3
		hit = "rbxassetid://114083734266818",  -- assets/sounds/sword_hit.mp3
		-- Steel on a body was the loudest thing in a fight and rang on far too long. Halved and cut short,
		-- per weapon rather than globally, so the other three keep their own balance.
		hitVolume = 0.09,
		hitSeconds = 0.55,
	},
	-- The tools borrow the sword's steel entirely. Without an entry here they would fall back to Fists, and
	-- an axe landing with a bare-knuckle thud is worse than it sharing a sound it plausibly makes.
	Axe = {
		cast = "rbxassetid://130522255329953", -- assets/sounds/sword_swing.mp3
		hit = "rbxassetid://114083734266818",  -- assets/sounds/sword_hit.mp3
		hitVolume = 0.09,
		hitSeconds = 0.55,
	},
	Pickaxe = {
		cast = "rbxassetid://130522255329953",
		hit = "rbxassetid://114083734266818",
		hitVolume = 0.09,
		hitSeconds = 0.55,
	},
	Shovel = {
		cast = "rbxassetid://130522255329953",
		hit = "rbxassetid://114083734266818",
		hitVolume = 0.09,
		hitSeconds = 0.55,
	},
	Pistol = {
		cast = "rbxassetid://110507208537712",
		-- The clip runs 5.95 seconds; a gunshot is a crack, not a drone. Cut to the first half second.
		castSeconds = 0.5,
		hit = "",
	},
	Bow = {
		cast = "rbxassetid://110510289237765", -- assets/sounds/bow_shoot.mp3
		hit = "rbxassetid://95565382064387",  -- assets/sounds/bow_hit.mp3
	},
	Staff = {
		cast = "rbxassetid://103908715700511", -- assets/sounds/laser_shoot.mp3
		hit = "rbxassetid://121322394992211",  -- assets/sounds/laser_hit.mp3
	},
	Spellbook = {
		cast = "rbxassetid://85137139623534", -- assets/sounds/spell_shoot.mp3
		hit = "rbxassetid://121322394992211",  -- assets/sounds/spell_hit.mp3
	},
}

-- The Q skill each weapon grants, which is a bigger, rarer thing than a swing and deserves its own noise.
-- Keyed by SKILL id rather than weapon, so a skill that later moves to another weapon keeps its sound.
CombatConfig.SkillSounds = {
	LungeSlash = "rbxassetid://107584400031007", -- sword_q
	ScatterShot = "rbxassetid://120465457667697", -- arrow_q
	Fireball = "rbxassetid://118145699359127",    -- magic_q
	GroupHeal = "rbxassetid://118799033183305",   -- staff_q
}

-- Volumes here are 0.3x their originally tuned values: everything was 70% too loud in play. The
-- ratios between them are the tuned part -- the sword impact is deliberately quieter than a skill -- so
-- they were scaled together rather than flattened to one number.
CombatConfig.SkillSoundVolume = 0.27

-- Per-skill overrides of the volume above; anything not listed uses it. LungeSlash was much louder than the
-- other three in play, and the sword is the most used weapon, so its cast is the sound heard most often.
CombatConfig.SkillSoundVolumes = {
	LungeSlash = 0.12,
}
CombatConfig.SkillSoundMaxSeconds = 2.5
CombatConfig.SkillSoundDistance = 110 -- a skill should be heard from further off than a swing

-- Equipping a weapon or a piece of armor. One sound for all of them: the feedback is "that went on", not
-- which thing it was.
CombatConfig.EquipSound = "rbxassetid://73684484951222"
CombatConfig.EquipSoundVolume = 0.21
CombatConfig.EquipSoundMaxSeconds = 1.2
CombatConfig.EquipSoundDistance = 40 -- a personal sound; nobody across the square needs to hear it

-- Cast sounds carry further than impacts: you should hear an archer loose an arrow from further away than
-- you hear it land on someone else.
CombatConfig.CastSoundDistance = 90
CombatConfig.HitSoundDistance = 60
CombatConfig.AttackSoundVolume = 0.24

-- How long a weapon clip may run before it is cut off. VitalsConfig.HitSoundMaxSeconds is 0.7s, tuned for
-- the punch sound so repeated hits do not stack into a drone -- but it was silencing most of a weapon clip
-- (measured: the sword swing is 0.79s, the spellbook 8.04s). Weapons get their own limits: long enough for
-- the whole sound, short enough that a fast chain does not pile up.
CombatConfig.CastSoundMaxSeconds = 1.2
CombatConfig.HitSoundMaxSeconds = 1.5

CombatConfig.DefaultWeapon = "Fists"

-- Every swing costs the weapon a point of durability; at zero it breaks and is destroyed, which is what the
-- Architect role and the repair hammer exist to prevent.
CombatConfig.DurabilityPerSwing = 1

-- Hitbox is a sphere in front of the attacker; range comes from the attack. Kept simple deliberately — the
-- RaycastHitboxV4 approach the user referenced is worth revisiting once weapons with real geometry exist.
CombatConfig.HitboxHeightOffset = 0

-- How close a projectile must pass to count as a hit. Measured to the nearest point of the target body
-- rather than to its root, so it does not need to be generous to cope with size differences -- but a
-- level-100 archer fires from ten studs up, and against a level-1 target the line still passes about five
-- studs clear, so this leaves margin above that rather than landing on the edge of it.
CombatConfig.ProjectileHitRadius = 8

return CombatConfig
