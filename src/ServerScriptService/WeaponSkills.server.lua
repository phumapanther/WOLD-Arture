-- WeaponSkills.server.lua: the Q skill each weapon grants. One mana pip per cast, plus a per-skill cooldown.
--
-- Server-authoritative like everything else: the client presses Q, the server decides whether the player has
-- the weapon, the mana and the cooldown, then resolves the effect itself.
--
-- The four skills, as specified:
--   Sword      LungeSlash  — leap forward and cleave everything in front
--   Bow        ScatterShot — leap backward and fire a spread
--   Staff      GroupHeal   — heal every ally in a radius
--   Spellbook  Fireball    — hurl an exploding projectile
local Players = game:GetService("Players")
local Debris = game:GetService("Debris")
local ServerConfig = require(game.ServerScriptService.ServerConfig)
local Inventory = require(game.ServerScriptService.Inventory)
local Vitals = require(game.ServerScriptService.Vitals)
local Party = require(game.ServerScriptService.Party)
local ArenaAccess = require(game.ServerScriptService.ArenaAccess)
local CombatConfig = require(game.ReplicatedStorage.CombatConfig)
local Consuming = require(game.ServerScriptService.Consuming)
local StatusEffects = require(game.ServerScriptService.StatusEffects)
local ItemCatalog = require(game.ReplicatedStorage.ItemCatalog)
local ProgressionConfig = require(game.ReplicatedStorage.ProgressionConfig)
local Progression = require(game.ServerScriptService.Progression)
local Remotes = require(game.ReplicatedStorage.Remotes)

if ServerConfig.IsLobby then return end

local Cooldowns = {} -- [player] = { [skillId] = readyAt }

local function characterParts(player)
	local character = player.Character
	local hrp = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	return character, hrp, humanoid
end

-- Shared launcher: gives the caster a burst of velocity, used by the sword's leap and the bow's hop back.
local function launch(hrp, direction, speed, lift)
	local attachment = Instance.new("Attachment")
	attachment.Parent = hrp
	local mover = Instance.new("LinearVelocity")
	mover.Attachment0 = attachment
	mover.MaxForce = math.huge
	mover.RelativeTo = Enum.ActuatorRelativeTo.World
	mover.VectorVelocity = direction * speed + Vector3.new(0, lift or 0, 0)
	mover.Parent = hrp
	Debris:AddItem(mover, 0.25)
	Debris:AddItem(attachment, 0.3)
end

-- Damage that also pays out if it downs someone. Skills previously dealt damage without ever awarding a
-- kill, so finishing an opponent with Q was worth nothing; this routes them through the same level-gap
-- reward the basic attacks use.
local function damageAndScore(caster, victim, amount)
	if Vitals.IsInvulnerable(victim) then return end
	-- สกิลก็คือการตีอย่างหนึ่ง เพื่อนร่วมตี้จึงไม่โดนเหมือนกัน (ท่าฮีลหมู่ไม่ผ่านทางนี้ มันรักษา ไม่ได้ตี)
	if Party.SameParty(caster, victim) then return end
	-- ในสนาม PVP ตี้ของล็อบบี้ไม่ได้เดินทางมาด้วย — ทีมของแมตช์คือด่าน "ตีกันเองไม่ได้" ที่นั่น
	if ArenaAccess.Friendly and ArenaAccess.Friendly(caster, victim) then return end
	local wasDowned = Vitals.IsDowned(victim)
	local landed = Vitals.ApplyDamage(victim, amount, "combat")
	if landed and ArenaAccess.OnHit then ArenaAccess.OnHit(caster, victim, amount) end
	-- A skill landing is a blow like any other, so the music hears about it the same way.
	Remotes.CombatHit:FireClient(caster)
	if victim ~= caster then Remotes.CombatHit:FireClient(victim) end

	-- A skill landing sounds like the weapon that cast it, the same as a swing landing. Without this a
	-- skill dealt damage in total silence, which read as it having missed.
	local victimCharacter = victim.Character
		if victimCharacter and CombatConfig.PlayWeaponHitSound then
		CombatConfig.PlayWeaponHitSound(victimCharacter, caster)
	end
	-- ในสนามไม่มี EXP (ไม่เอาเลเวลมาเกี่ยว เพื่อความเท่าเทียม) และคิลถูกนับตอนร่างตายจริง ไม่ใช่ตอนล้ม
	if not wasDowned and Vitals.IsDowned(victim) and not ArenaAccess.OnKill then
		local multiplier = ProgressionConfig.KillMultiplier(
			Progression.GetLevel(caster), Progression.GetLevel(victim))
		Progression.AwardExp(caster, math.floor(ProgressionConfig.ExpPerPlayerKill * multiplier + 0.5))
	end
end

-- สกิล Q ในเกมหลัก **ไม่เคยทำดาเมจใส่มอนเลย** (มันวนแต่ `playersNear`) ซึ่งไม่เป็นไรในเมือง
-- แต่ในสนาม PVP ครึ่งทีมอาจเป็นบอท — สกิลที่ฟันทะลุบอทไปเฉยๆ คืออาวุธราคา 1,000 ที่ใช้ไม่ได้ครึ่งหนึ่ง
--
-- ทำงานเฉพาะในสนาม (`ArenaAccess.OnHit` ถูกตั้งที่นั่นที่เดียว) เพลสหลักจึงไม่มีอะไรเปลี่ยน
local function alsoHitBots(caster, origin, radius, amount)
	if not ArenaAccess.OnHit then return end
	local MobAccess = require(game.ServerScriptService.MobAccess)
	if not MobAccess.Damage then return end
	for _, mob in ipairs(game:GetService("CollectionService"):GetTagged("WOLD_Mob")) do
		local root = mob.PrimaryPart or mob:FindFirstChild("HumanoidRootPart")
		if root and (root.Position - origin).Magnitude <= radius then
			MobAccess.Damage(mob, amount, caster)
		end
	end
end

-- Everyone (other than the caster) whose root is within `radius` of `origin`.
local function playersNear(origin, radius, exclude)
	local found = {}
	for _, other in ipairs(Players:GetPlayers()) do
		if other ~= exclude then
			local _, otherHrp = characterParts(other)
			if otherHrp and (otherHrp.Position - origin).Magnitude <= radius then
				table.insert(found, other)
			end
		end
	end
	return found
end

--------------------------------------------------------------------------------
-- The skills
--------------------------------------------------------------------------------

local Skills = {}

-- The three beats of the leap, in the order the user asked for: wind up, THEN jump, and swing only once you
-- have landed on them. They mirror Greatsword_Leap's keyframes exactly -- move one of these and the blow
-- lands somewhere the character is not.
local LAUNCH_AT = 0.45 -- the wind-up finishes and the feet leave the ground
local HIT_AT = 0.95    -- the chop, just as the landing finishes

-- Sword: wind up, leap forward, then cleave everything ahead on landing.
function Skills.LungeSlash(player)
	local _, hrp = characterParts(player)
	if not hrp then return false end
	local forward = (hrp.CFrame.LookVector * Vector3.new(1, 0, 1))
	if forward.Magnitude < 0.1 then return false end
	forward = forward.Unit

	-- The animation starts NOW; the movement and the damage follow it. Firing this first is what lets the
	-- wind-up be visible before anything happens.
	Remotes.SkillUsed:FireAllClients(player, "LungeSlash")

	-- The leap, after the wind-up. Re-read the character rather than closing over `hrp`: half a second is
	-- long enough to die in, and launching a dead player's root throws.
	task.delay(LAUNCH_AT, function()
		local _, readyHrp = characterParts(player)
		if not readyHrp then return end
		-- Aimed where they are pointing WHEN THEY JUMP, not where they were when they pressed the button --
		-- the wind-up is long enough to turn during.
		local heading = (readyHrp.CFrame.LookVector * Vector3.new(1, 0, 1))
		if heading.Magnitude < 0.1 then heading = forward else heading = heading.Unit end
		launch(readyHrp, heading, 55, 22)
	end)

	-- The hit lands with the blade, at the end of the fall.
	task.delay(HIT_AT, function()
		local _, landedHrp = characterParts(player)
		if not landedHrp then return end
		local origin = landedHrp.Position + landedHrp.CFrame.LookVector * 4
		for _, victim in ipairs(playersNear(origin, 9, player)) do
			damageAndScore(player, victim, 32)
		end
		alsoHitBots(player, origin, 9, 32)
	end)
	return true
end

-- โล่: คำท้าทองคำ — ออร่าทองแผ่ออกจากตัว มอนรอบตัวหันมาหาคนใช้ และเลือดไม่ลด 5 วินาที
--
-- ผู้ใช้กำหนด 2026-09-20 · นี่คือสกิลแท็งก์ตัวแรกของเกม: มันไม่ได้ทำดาเมจเลยสักหน่วย สิ่งที่มันซื้อคือ
-- **สิบวินาทีที่มอนทุกตัวตีคนที่ทนได้ แทนที่จะตีคนที่ทนไม่ได้**
--
-- บัพ "เลือดไม่ลด" ใช้ตัวเดียวกับของแอดมิน/อาหารเดิม (`Vitals.AddBuff`) ไม่ได้ทำระบบอมตะอันที่สอง —
-- `ApplyDamage` เช็ค noHp อยู่แล้วทุกทางที่ดาเมจเข้า ดังนั้นตกเขา จมน้ำ หรือโดนบอสทุบก็กันได้เหมือนกันหมด
local BULWARK_SECONDS = 5 -- บัพ ❤️ เลือดไม่ลด (ผู้ใช้สั่ง 2026-09-20 — เดิม 10 วิ)
local BULWARK_RADIUS = 60

function Skills.Bulwark(player)
	local character, hrp = characterParts(player)
	if not hrp then return false end

	Remotes.SkillUsed:FireAllClients(player, "Bulwark")
	Vitals.AddBuff(player, "noHp", BULWARK_SECONDS)

	local MobAccess = require(game.ServerScriptService.MobAccess)
	if MobAccess.Taunt then MobAccess.Taunt(player, BULWARK_RADIUS) end

	-- ออร่าทอง: ทำบนเซิร์ฟเวอร์เพื่อให้ **ทุกคนเห็น** ว่าคนนี้กำลังรับแทนอยู่ ไม่ใช่เอฟเฟกต์ส่วนตัวของคนใช้
	--
	-- ทรง Sphere + Volume + Outward ตามบทเรียนของระบบออร่า: `Cylinder` เอาแกนตามแกน X ของพาร์ท
	-- แผ่นแบนที่ตั้งใจให้เป็นวงรอบเอวเลยกลายเป็นเส้นตรงเส้นเดียว
	local glow = Instance.new("Part")
	glow.Name = "BulwarkAura"
	glow.Size = Vector3.new(4.0, 4.4, 4.0)
	glow.Transparency = 1
	glow.Anchored = false
	glow.CanCollide = false
	glow.CanQuery = false
	glow.CanTouch = false
	glow.Massless = true
	glow.CFrame = hrp.CFrame * CFrame.new(0, -0.5, 0)
	glow.Parent = character

	local weld = Instance.new("WeldConstraint")
	weld.Part0 = hrp
	weld.Part1 = glow
	weld.Parent = glow

	local gold = Color3.fromRGB(255, 196, 74)
	local haze = Instance.new("ParticleEmitter")
	haze.Name = "Haze"
	haze.Color = ColorSequence.new(gold)
	haze.Size = NumberSequence.new(2.6)
	haze.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.3, 0.55), NumberSequenceKeypoint.new(1, 1),
	})
	haze.Rate = 26
	haze.Lifetime = NumberRange.new(0.9, 1.4)
	haze.Speed = NumberRange.new(2, 4)
	haze.Shape = Enum.ParticleEmitterShape.Sphere
	haze.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	haze.ShapeInOut = Enum.ParticleEmitterShapeInOut.Outward
	haze.LightEmission = 1
	haze.LightInfluence = 0
	haze.Parent = glow

	local motes = haze:Clone()
	motes.Name = "Motes"
	motes.Size = NumberSequence.new(0.35)
	motes.Rate = 34
	motes.Speed = NumberRange.new(5, 9)
	motes.Transparency = NumberSequence.new(0.1)
	motes.Parent = glow

	local light = Instance.new("PointLight")
	light.Color = gold
	light.Range = 18
	light.Brightness = 2.4
	light.Parent = glow

	Debris:AddItem(glow, BULWARK_SECONDS)
	return true
end

-- Bow: hop backwards and fire a spread of arrows, each a fast raycast rather than a physical part.
function Skills.ScatterShot(player)
	local character, hrp = characterParts(player)
	if not hrp then return false end
	local forward = (hrp.CFrame.LookVector * Vector3.new(1, 0, 1))
	if forward.Magnitude < 0.1 then return false end
	forward = forward.Unit

	launch(hrp, -forward, 38, 26) -- backflip away from the target
	Remotes.SkillUsed:FireAllClients(player, "ScatterShot")

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character }

	-- Five arrows fanned across 50 degrees. Real travelling parts rather than instant raycasts, so the spread
	-- is something the player can actually see leave the bow.
	local hitAlready = {}
	for i = -2, 2 do
		local angle = math.rad(i * 12.5)
		local dir = CFrame.Angles(0, angle, 0):VectorToWorldSpace(forward)
		local origin = hrp.Position + Vector3.new(0, 1.5, 0) + dir * 2

		local arrow = Instance.new("Part")
		arrow.Name = "WOLD_Projectile"
		arrow.Anchored = true
		arrow.CanCollide = false
		arrow.CanQuery = false
		arrow.Size = Vector3.new(0.18, 0.18, 2.2)
		arrow.Color = Color3.fromRGB(222, 198, 152)
		arrow.Material = Enum.Material.Wood
		arrow.CFrame = CFrame.lookAt(origin, origin + dir)
		arrow.Parent = workspace
		Debris:AddItem(arrow, 1.2)

		task.spawn(function()
			local travelled = 0
			while arrow.Parent and travelled < 70 do
				local dt = task.wait()
				local step = dir * (110 * dt)
				local result = workspace:Raycast(arrow.Position, step, params)
				if result then
					local victim = Players:GetPlayerFromCharacter(result.Instance.Parent)
					if victim and victim ~= player and not hitAlready[victim] then
						hitAlready[victim] = true
						damageAndScore(player, victim, 14)
						StatusEffects.Knockdown(victim, 3)
					else
						-- ลูกธนูของสกิลพุ่งชนบอท: ทำดาเมจแล้วหยุดที่นั่นเหมือนชนคน
						alsoHitBots(player, arrow.Position, 6, 14)
					end
					arrow:Destroy()
					return
				end
				arrow.CFrame = arrow.CFrame + step
				travelled += step.Magnitude
			end
			if arrow.Parent then arrow:Destroy() end
		end)
	end
	return true
end

-- Staff: heal every ally within range, and the caster.
local HEAL_FRACTION = 0.25 -- ฮีลกี่ % ของเลือดเต็ม (ผู้ใช้กำหนด)

function Skills.GroupHeal(player)
	local _, hrp = characterParts(player)
	if not hrp then return false end

	Remotes.SkillUsed:FireAllClients(player, "GroupHeal")

	-- A visible ring of light so allies can see the heal reach them, rather than health simply changing.
	local RADIUS = 24
	local aura = Instance.new("Part")
	aura.Name = "WOLD_HealAura"
	aura.Shape = Enum.PartType.Ball
	aura.Anchored = true
	aura.CanCollide = false
	aura.CanQuery = false
	aura.Material = Enum.Material.ForceField
	aura.Color = Color3.fromRGB(120, 236, 180)
	aura.Transparency = 0.35
	aura.Size = Vector3.new(2, 2, 2)
	aura.CFrame = CFrame.new(hrp.Position)
	aura.Parent = workspace
	Debris:AddItem(aura, 1.2)

	local light = Instance.new("PointLight")
	light.Color = aura.Color
	light.Range = RADIUS
	light.Brightness = 3
	light.Parent = aura

	-- Expand to the heal's real radius, so the ring shows exactly who was in range.
	task.spawn(function()
		local t0 = os.clock()
		while aura.Parent and os.clock() - t0 < 0.6 do
			local t = (os.clock() - t0) / 0.6
			aura.Size = Vector3.new(1, 1, 1) * (2 + (RADIUS * 2 - 2) * t)
			aura.Transparency = 0.35 + 0.6 * t
			task.wait()
		end
		if aura.Parent then aura:Destroy() end
	end)

	-- **25% ของเลือดเต็ม ไม่ใช่ 35 หน่วยตายตัว** (ผู้ใช้สั่ง 2026-09-20)
	--
	-- เพดานเลือดโตตามเลเวล (`ProgressionConfig.MaxHPPerLevel` +5/เลเวล → 595 ที่เลเวล 100) เลขตายตัว
	-- จึงเป็นท่าฮีลที่แรงมากตอนต้นเกมและไร้ความหมายตอนปลาย · สัดส่วนอ่านค่าจากเพดานของ **แต่ละคน**
	-- คนเลเวลสูงที่มาช่วยจึงได้ฮีลที่คุ้มกับตัวเขาเอง
	Vitals.HealFraction(player, HEAL_FRACTION)
	for _, ally in ipairs(playersNear(hrp.Position, RADIUS, player)) do
		-- ⚠️ ในเกมหลัก "พวกเดียวกัน" ไม่มีความหมาย ท่านี้จึงฮีลทุกคนที่ยืนอยู่ใกล้ — **ในสนาม 3v3
		-- นั่นแปลว่าคทารักษาคนที่กำลังจะฆ่าเรา** · ที่นี่จึงฮีลเฉพาะทีมเดียวกัน (นอกสนาม `Friendly`
		-- เป็น nil เงื่อนไขนี้จึงเป็นจริงเสมอ และท่าฮีลหมู่ในเมืองก็เหมือนเดิมทุกประการ)
		if not ArenaAccess.Friendly or ArenaAccess.Friendly(player, ally) then
			Vitals.HealFraction(ally, HEAL_FRACTION)
		end
	end
	return true
end

-- Spellbook: a fireball that travels, then explodes on whatever it reaches.
function Skills.Fireball(player)
	local character, hrp = characterParts(player)
	if not hrp then return false end
	local forward = (hrp.CFrame.LookVector * Vector3.new(1, 0, 1))
	if forward.Magnitude < 0.1 then return false end
	forward = forward.Unit

	Remotes.SkillUsed:FireAllClients(player, "Fireball")

	local ball = Instance.new("Part")
	ball.Name = "WOLD_Fireball"
	ball.Shape = Enum.PartType.Ball
	ball.Size = Vector3.new(2, 2, 2)
	ball.Material = Enum.Material.Neon
	ball.Color = Color3.fromRGB(255, 138, 46)
	ball.CanCollide = false
	ball.Anchored = true -- stepped by hand below, so it cannot be shoved off course
	ball.CFrame = CFrame.new(hrp.Position + forward * 3 + Vector3.new(0, 2, 0))
	ball.Parent = workspace
	Debris:AddItem(ball, 4)

	local light = Instance.new("PointLight")
	light.Color = ball.Color
	light.Range = 14
	light.Brightness = 3
	light.Parent = ball

	task.spawn(function()
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = { character, ball }

		local travelled = 0
		while travelled < 120 and ball.Parent do
			local step = forward * 3
			local result = workspace:Raycast(ball.Position, step, params)
			if result then
				-- Explode: everything close to the impact takes damage.
				for _, victim in ipairs(playersNear(result.Position, 12, player)) do
					damageAndScore(player, victim, 26)
				end
				alsoHitBots(player, result.Position, 12, 26)
				ball:Destroy()
				return
			end
			ball.CFrame = ball.CFrame + step
			travelled += step.Magnitude
			task.wait()
		end
		if ball.Parent then ball:Destroy() end
	end)
	return true
end

--------------------------------------------------------------------------------
-- Request handling
--------------------------------------------------------------------------------

Remotes.RequestSkill.OnServerEvent:Connect(function(player)
	if Vitals.IsDowned(player) then return end
	-- Same reason attacks are blocked: both hands are busy holding food.
	if Consuming.IsConsuming(player) then return end
	local _, _, humanoid = characterParts(player)
	if not humanoid or humanoid.Health <= 0 then return end

	local item, entry = Inventory.EquippedWeapon(player)
	if not item or not item.skill or not entry then return end -- bare hands have no skill

	local skill = item.skill
	local handler = Skills[skill.id]
	if not handler then return end

	Cooldowns[player] = Cooldowns[player] or {}
	local readyAt = Cooldowns[player][skill.id] or 0
	if os.clock() < readyAt then return end

	-- Mana is spent only once everything else has passed, and TrySpendMana refuses when there is not enough,
	-- so a failed cast never silently eats a pip.
	if not Vitals.TrySpendMana(player, skill.manaCost or 1) then return end

	Cooldowns[player][skill.id] = os.clock() + (skill.cooldown or 5)

	-- The skill sound plays on the cast, not on whatever it hits: a skill that misses should still be heard,
	-- and it is the moment the player committed the mana.
	local soundId = CombatConfig.SkillSounds[skill.id]
	local skillCharacter = player.Character
	local skillRoot = skillCharacter and skillCharacter:FindFirstChild("HumanoidRootPart")
	if soundId and skillRoot then
		local sound = Instance.new("Sound")
		sound.SoundId = soundId
		sound.Volume = CombatConfig.SkillSoundVolumes[skill.id] or CombatConfig.SkillSoundVolume
		sound.RollOffMaxDistance = CombatConfig.SkillSoundDistance
		sound.Parent = skillRoot
		sound:Play()
		game:GetService("Debris"):AddItem(sound, CombatConfig.SkillSoundMaxSeconds)
	end
	if not handler(player) then
		-- The skill could not resolve (no character, no facing): give the mana back rather than charging for
		-- nothing.
		Vitals.AddMana(player, skill.manaCost or 1)
		Cooldowns[player][skill.id] = 0
	end
end)

Players.PlayerRemoving:Connect(function(player)
	Cooldowns[player] = nil
end)
