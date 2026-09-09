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
	local wasDowned = Vitals.IsDowned(victim)
	Vitals.ApplyDamage(victim, amount, "combat")
	if not wasDowned and Vitals.IsDowned(victim) then
		local multiplier = ProgressionConfig.KillMultiplier(
			Progression.GetLevel(caster), Progression.GetLevel(victim))
		Progression.AwardExp(caster, math.floor(ProgressionConfig.ExpPerPlayerKill * multiplier + 0.5))
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

-- Sword: leap forward, then damage everything in a cone-ish sphere ahead on landing.
function Skills.LungeSlash(player)
	local _, hrp = characterParts(player)
	if not hrp then return false end
	local forward = (hrp.CFrame.LookVector * Vector3.new(1, 0, 1))
	if forward.Magnitude < 0.1 then return false end
	forward = forward.Unit

	launch(hrp, forward, 55, 22)
	Remotes.SkillUsed:FireAllClients(player, "LungeSlash")

	-- The hit lands as the leap finishes, not on the button press.
	task.delay(0.35, function()
		local _, landedHrp = characterParts(player)
		if not landedHrp then return end
		local origin = landedHrp.Position + landedHrp.CFrame.LookVector * 4
		for _, victim in ipairs(playersNear(origin, 9, player)) do
			damageAndScore(player, victim, 32)
		end
	end)
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

	Vitals.Heal(player, 35)
	for _, ally in ipairs(playersNear(hrp.Position, RADIUS, player)) do
		Vitals.Heal(ally, 35)
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
