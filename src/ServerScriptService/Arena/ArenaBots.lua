-- ArenaBots.lua: หุ่นที่มาเติมทีมเมื่อหาคนไม่ครบหกคน (ผู้ใช้กำหนด: ครบ 3 นาทีแล้วเติมบอท)
--
-- **บอทถูกตีด้วยทางเดียวกับมอนในเกมหลัก** — `PlayerCombat` ยิง/ฟันใส่โมเดลที่ติดแท็ก `WOLD_Mob`
-- แล้วเรียก `MobAccess.Damage` ซึ่งไฟล์นี้เป็นคนตั้งในเซิร์ฟแมตช์ · ผลคือ **ไม่ต้องแตะระบบต่อสู้เลย**
-- ดาบ ธนู ปืน สกิล Q และเสียงลงเป้า ทำงานกับบอทเหมือนทำกับมอนทุกประการตั้งแต่บรรทัดแรก
--
-- ⚠️ แท็ก `WOLD_Mob` ในเซิร์ฟแมตช์ **ไม่มีใครอื่นอ่าน** เพราะ `Mobs.server` ไม่ได้ถูกส่งมาเพลสนี้
-- (ดู `arena.project.json`) — ถ้าวันหนึ่งมีระบบใหม่ในสนามที่อ่านแท็กนี้ ต้องรู้ว่ามันจะเจอบอทด้วย
local CollectionService = game:GetService("CollectionService")
local PathfindingService = game:GetService("PathfindingService")
local Players = game:GetService("Players")

local Debris = game:GetService("Debris")

local ArenaConfig = require(game.ReplicatedStorage.ArenaConfig)
local CombatConfig = require(game.ReplicatedStorage.CombatConfig)
local ItemCatalog = require(game.ReplicatedStorage.ItemCatalog)
local KitWear = require(game.ServerScriptService.KitWear)
local MobAccess = require(game.ServerScriptService.MobAccess)
local Vitals = require(game.ServerScriptService.Vitals)
local WeaponVisualsAccess = require(game.ServerScriptService.WeaponVisualsAccess)

local ArenaBots = {}

local CFG = ArenaConfig.Bots

-- ร่างต้นแบบที่ `mapgen/100_arena_maps.lua` อบไว้ในเพลส ถ้ามี — ไม่มีก็ปั้นจาก HumanoidDescription เปล่า
-- ซึ่งได้ R15 ที่เดินได้จริง (แต่ไม่มีสคริปต์ Animate ของ Roblox จึงไม่มีท่าเดิน ดูหมายเหตุใน `spawn`)
local PROTOTYPE_FOLDER = "WOLD_ArenaBots"

local Live = {} -- [model] = state
local hooks = {} -- ตั้งโดย ArenaMatch: onHit(botModel, attackerPlayer, amount) · onDied(botModel, killerPlayer)

--------------------------------------------------------------------------------
local function prototype()
	local folder = game:GetService("ServerStorage"):FindFirstChild(PROTOTYPE_FOLDER)
	if not folder then return nil end
	local kids = folder:GetChildren()
	if #kids == 0 then return nil end
	return kids[math.random(#kids)]
end

local function buildRig()
	local proto = prototype()
	if proto then return proto:Clone() end

	-- ทางสำรอง: ร่าง R15 เปล่าจาก Roblox เอง · ใช้ได้ทันทีโดยไม่ต้องรอ mapgen ซึ่งสำคัญมากตอนเทสรอบแรก
	-- (แมตช์ที่เริ่มไม่ได้เพราะยังไม่ได้อบโมเดล = เทสอะไรไม่ได้เลยสักอย่าง)
	local ok, model = pcall(function()
		local description = Instance.new("HumanoidDescription")
		return Players:CreateHumanoidModelFromDescription(description, Enum.HumanoidRigType.R15)
	end)
	if ok and model then return model end
	return nil
end

--------------------------------------------------------------------------------
-- เป้าหมาย
--------------------------------------------------------------------------------
-- บอทเล็งคนที่ **ใกล้ที่สุดในฝั่งตรงข้าม** ไม่ใช่คนที่ตีมันล่าสุด — สนามปิดขนาดนี้ การไล่ตามคนที่
-- วิ่งหนีข้ามแมพไปแล้วแปลว่าบอทจะเดินผ่านศัตรูที่ยืนอยู่ตรงหน้าโดยไม่สนใจ
local function nearestEnemy(state)
	local origin = state.root.Position
	local best, bestDist = nil, CFG.sight

	for _, player in ipairs(Players:GetPlayers()) do
		local side = hooks.sideOfPlayer and hooks.sideOfPlayer(player)
		if side and side ~= state.side and not Vitals.IsDowned(player) then
			local character = player.Character
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			local root = character and character:FindFirstChild("HumanoidRootPart")
			if humanoid and humanoid.Health > 0 and root then
				local d = (root.Position - origin).Magnitude
				if d < bestDist then best, bestDist = root, d end
			end
		end
	end

	for model, other in pairs(Live) do
		if other.side ~= state.side and other.alive and model ~= state.model then
			local d = (other.root.Position - origin).Magnitude
			if d < bestDist then best, bestDist = other.root, d end
		end
	end
	return best, bestDist
end

--------------------------------------------------------------------------------
-- ตีคน
--------------------------------------------------------------------------------


--------------------------------------------------------------------------------
-- เดินหาทาง (2026-09-24: แมพปราสาทมีกำแพง ประตูป้อม หอกลาง — เดินเส้นตรงแล้วติดกำแพงทุกตัว)
--------------------------------------------------------------------------------
local AGENT = { AgentRadius = 2.5, AgentHeight = 5.5, AgentCanJump = true, WaypointSpacing = 6 }
local REPATH_SECONDS = 1.5  -- เป้าเดินอยู่ตลอด ทางเก่าหมดอายุเร็ว
local DIRECT_RANGE = 14     -- ใกล้ขนาดนี้และไม่มีอะไรบัง เดินตรงไปเลย ไม่ต้องคำนวณทาง

local function clearLine(state, goal)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { state.model }
	local from = state.root.Position
	local hit = workspace:Raycast(from, goal - from, params)
	return hit == nil or (hit.Position - goal).Magnitude < 3
end

-- เดินไปหา `goal` ทีละก้าวตามทางที่ PathfindingService คิดให้ · เรียกทุกรอบของ think
local function walkTo(state, goal)
	local now = os.clock()
	local d = (goal - state.root.Position).Magnitude
	if d <= DIRECT_RANGE and clearLine(state, goal) then
		state.waypoints = nil
		state.humanoid:MoveTo(goal)
		return
	end

	-- ติด: ขยับได้ไม่ถึง 1 สตัดในหนึ่งวินาที → กระโดดแล้วคิดทางใหม่
	if now - (state.stuckAt or 0) > 1 then
		if state.lastPos and (state.root.Position - state.lastPos).Magnitude < 1 then
			state.humanoid.Jump = true
			state.waypoints = nil
		end
		state.lastPos, state.stuckAt = state.root.Position, now
	end

	local stale = not state.waypoints or now - state.pathAt > REPATH_SECONDS
		or (state.pathGoal and (state.pathGoal - goal).Magnitude > 8)
	if stale then
		local path = PathfindingService:CreatePath(AGENT)
		local ok = pcall(function() path:ComputeAsync(state.root.Position, goal) end)
		state.pathAt, state.pathGoal = now, goal
		if ok and path.Status == Enum.PathStatus.Success then
			state.waypoints, state.wp = path:GetWaypoints(), 2
		else
			-- ไม่มีทาง (เช่นเป้ายืนบนหลังคา) → เดินตรงไปเท่าที่ไปได้ ดีกว่ายืนนิ่ง
			state.waypoints = nil
			state.humanoid:MoveTo(goal)
			return
		end
	end

	local waypoints = state.waypoints
	local w = waypoints[state.wp]
	while w and (Vector3.new(w.Position.X, 0, w.Position.Z)
		- Vector3.new(state.root.Position.X, 0, state.root.Position.Z)).Magnitude < 3 do
		state.wp += 1
		w = waypoints[state.wp]
	end
	if not w then
		state.waypoints = nil
		return
	end
	if w.Action == Enum.PathWaypointAction.Jump then state.humanoid.Jump = true end
	state.humanoid:MoveTo(w.Position)
end

--------------------------------------------------------------------------------
-- สู้เหมือนคน (ผู้ใช้สั่ง 2026-09-24): อาวุธ/ดาเมจ/ระยะ/ท่า/เสียง จาก CombatConfig ชุดเดียวกับผู้เล่น
-- + ใช้ยาตอนเลือดน้อย + สกิล Q ห้าท่าด้วยเลขเดียวกับ WeaponSkills (พุ่งฟัน 32 · ยิงกระจาย 14x3 ·
-- ลูกไฟ 26 วงกว้าง · ฮีลหมู่ 25% · คำท้าทองคำ เลือดไม่ลด 5 วิ)
--------------------------------------------------------------------------------
local ARMOR_KITS = { LeatherArmor = "Armor_LeatherKit", ChainmailArmor = "Armor_ChainKit", PlateArmor = "Armor_PlateKit" }
local ARMOR_FOLDER = "WOLD_ArmorOn" -- ชื่อเดียวกับ ArmorVisuals
local RANGED_ACCURACY = 0.7 -- บอทยิงไกลโดนกี่ครั้งในร้อย (คนเล็งพลาดได้ บอทก็ต้องพลาดได้)

local function sound(parent, id, volume, seconds)
	if not id or id == "" or not parent then return end
	local s = Instance.new("Sound")
	s.SoundId = id
	s.Volume = volume or 0.25
	s.RollOffMaxDistance = 100
	s.Parent = parent
	s:Play()
	Debris:AddItem(s, seconds or 2)
end

-- โหลดท่าครั้งเดียวต่อบอทต่อ id
local function track(state, id)
	if not id or id == "" or not state.animator then return nil end
	state.tracks = state.tracks or {}
	local t = state.tracks[id]
	if t == nil then
		local a = Instance.new("Animation")
		a.AnimationId = id
		local ok, loaded = pcall(function() return state.animator:LoadAnimation(a) end)
		t = ok and loaded or false
		if t then t.Priority = Enum.AnimationPriority.Action end
		state.tracks[id] = t
	end
	return t or nil
end

local function playAnim(state, id)
	local t = track(state, id)
	if t then t:Play(0.05) end
end

-- เส้นกระสุน/ลูกธนู/ลำแสงให้เห็นว่ายิงจากไหนไปไหน
local function tracer(from, to, colour, width)
	local d = (to - from).Magnitude
	if d < 0.5 then return end
	local p = Instance.new("Part")
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch = true, false, false, false
	p.Material = Enum.Material.Neon
	p.Color = colour
	p.Size = Vector3.new(width or 0.25, width or 0.25, d)
	p.CFrame = CFrame.lookAt((from + to) / 2, to)
	p.Parent = workspace
	Debris:AddItem(p, 0.15)
end

local function flash(position, colour, size, seconds)
	local p = Instance.new("Part")
	p.Shape = Enum.PartType.Ball
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch = true, false, false, false
	p.Material = Enum.Material.Neon
	p.Color = colour
	p.Transparency = 0.35
	p.Size = Vector3.one * size
	p.Position = position
	p.Parent = workspace
	Debris:AddItem(p, seconds or 0.3)
end

-- อาวุธที่ใช้ได้ตอนนี้ + ท่าถัดไปในชุด · ปืนกระสุนหมด = กลับไปต่อย
local function weaponSpec(state)
	local id = state.weapon
	if id == "Pistol" and (state.ammo or 0) <= 0 then id = nil end
	id = id or "Fists"
	local spec = CombatConfig.Weapons[id] or CombatConfig.Weapons.Fists
	local attacks = spec.attacks
	local a = attacks[((state.combo or 0) % #attacks) + 1]
	local p = a.projectile
	local range = p and math.min(60, p.length or (p.speed or 0) * (p.life or 0)) or math.max(a.range or 0, 5)
	local damage = a.damage
	if not damage or damage <= 0 then damage = (ItemCatalog.Items[id] or {}).damage or CFG.damage end
	return {
		id = id, attack = a, ranged = p ~= nil, range = range, damage = damage,
		period = (a.windup or 0.2) + (a.active or 0.1) + (a.recovery or 0.3) + 0.25,
	}
end

-- ทำดาเมจใส่เป้า (คนหรือบอท) แล้วแจ้งสนามว่าใครตีใคร (นับคิล/แอสซิส/ดาเมจ)
local function hitTarget(state, targetRoot, amount)
	local character = targetRoot and targetRoot.Parent
	local player = character and Players:GetPlayerFromCharacter(character)
	if player then
		if Vitals.ApplyDamage(player, amount, "combat") and hooks.onBotHitPlayer then
			hooks.onBotHitPlayer(state.model, player, amount)
		end
		return true
	end
	local other = character and Live[character]
	if other and other.alive and other.side ~= state.side then
		ArenaBots.Damage(other.model, amount, nil)
		if hooks.onBotHitBot then hooks.onBotHitBot(state.model, other.model, amount) end
		return true
	end
	return false
end

-- ศัตรู/เพื่อนรอบจุดหนึ่ง: { root, player?, bot? }
local function near(state, position, radius, enemies)
	local list = {}
	for _, player in ipairs(Players:GetPlayers()) do
		local side = hooks.sideOfPlayer and hooks.sideOfPlayer(player)
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if side and root and humanoid and humanoid.Health > 0 and (side ~= state.side) == enemies
			and (root.Position - position).Magnitude <= radius then
			list[#list + 1] = { root = root, player = player }
		end
	end
	for _, other in pairs(Live) do
		if other.alive and (other.side ~= state.side) == enemies and (other.root.Position - position).Magnitude <= radius then
			list[#list + 1] = { root = other.root, bot = other }
		end
	end
	return list
end

local function attack(state, targetRoot, spec)
	local now = os.clock()
	if now < state.nextSwing then return end
	state.nextSwing = now + spec.period
	state.combo = (state.combo or 0) + 1
	playAnim(state, spec.attack.animation)
	local sounds = CombatConfig.Sounds[spec.id] or {}
	sound(state.root, sounds.cast, CombatConfig.AttackSoundVolume)
	if spec.id == "Pistol" then state.ammo = (state.ammo or 0) - 1 end

	task.delay(spec.attack.windup or 0.2, function()
		if not state.alive or not targetRoot.Parent then return end
		local d = (targetRoot.Position - state.root.Position).Magnitude
		if d > spec.range + 2 then return end
		if spec.ranged then
			local hand = state.model:FindFirstChild("RightHand") or state.root
			tracer(hand.Position, targetRoot.Position, spec.id == "Pistol" and Color3.fromRGB(255, 220, 120)
				or spec.id == "Bow" and Color3.fromRGB(200, 170, 120) or Color3.fromRGB(140, 190, 255), 0.25)
			if math.random() > RANGED_ACCURACY then return end
		end
		if hitTarget(state, targetRoot, spec.damage) then
			sound(targetRoot, sounds.hit, sounds.hitVolume, sounds.hitSeconds)
		end
	end)
end

-- ยา: เลือดต่ำกว่า 40% แล้วมียาติดตัว
local function tryPotion(state)
	if not state.potion or state.hp > CFG.hp * 0.4 then return end
	local use = (ItemCatalog.Items[state.potion] or {}).use or {}
	local heal = (use.stat == "healfull" and CFG.hp) or (use.stat == "hp" and (use.amount or 40)) or 50
	state.hp = math.min(CFG.hp, state.hp + heal)
	state.humanoid.Health = state.hp
	if use.stat == "firstaid" then state.invulnUntil = os.clock() + (use.seconds or 10) end
	state.potion = nil
	flash(state.root.Position, Color3.fromRGB(110, 230, 140), 5, 0.4)
end

local function trySkill(state, targetRoot, distance, spec)
	local item = ItemCatalog.Items[state.weapon or ""]
	local skill = item and item.skill
	if not skill or (state.mana or 0) < (skill.manaCost or 1) or os.clock() < (state.skillReadyAt or 0) then return false end
	local id = skill.id
	if id == "GroupHeal" and state.hp > CFG.hp * 0.6 then return false end
	if id == "Bulwark" and state.hp > CFG.hp * 0.5 then return false end
	if id == "LungeSlash" and distance > 18 then return false end
	if (id == "ScatterShot" or id == "Fireball") and (distance > spec.range or not clearLine(state, targetRoot.Position)) then
		return false
	end

	state.mana -= skill.manaCost or 1
	state.skillReadyAt = os.clock() + (skill.cooldown or 6)
	state.nextSwing = os.clock() + 1.2
	playAnim(state, CombatConfig.SkillAnimations[id] or spec.attack.animation)
	sound(state.root, CombatConfig.SkillSounds[id], CombatConfig.SkillSoundVolumes[id] or CombatConfig.SkillSoundVolume,
		CombatConfig.SkillSoundMaxSeconds)

	if id == "LungeSlash" then
		local dir = (targetRoot.Position - state.root.Position) * Vector3.new(1, 0, 1)
		if dir.Magnitude > 0.1 then state.root.AssemblyLinearVelocity = dir.Unit * 55 + Vector3.new(0, 18, 0) end
		task.delay(0.6, function()
			if state.alive and targetRoot.Parent and (targetRoot.Position - state.root.Position).Magnitude <= spec.range + 5 then
				hitTarget(state, targetRoot, 32)
			end
		end)
	elseif id == "ScatterShot" then
		for i = 1, 3 do
			task.delay(0.35 + i * 0.08, function()
				if not state.alive or not targetRoot.Parent then return end
				local spread = Vector3.new(math.random(-3, 3), math.random(-1, 1), math.random(-3, 3))
				tracer(state.root.Position, targetRoot.Position + spread, Color3.fromRGB(200, 170, 120), 0.2)
				if math.random() <= RANGED_ACCURACY then hitTarget(state, targetRoot, 14) end
			end)
		end
	elseif id == "Fireball" then
		task.delay(0.3, function()
			if not state.alive or not targetRoot.Parent then return end
			local at = targetRoot.Position
			tracer(state.root.Position, at, Color3.fromRGB(255, 130, 50), 1.2)
			flash(at, Color3.fromRGB(255, 120, 40), 12, 0.4)
			for _, e in ipairs(near(state, at, 8, true)) do hitTarget(state, e.root, 26) end
		end)
	elseif id == "GroupHeal" then
		flash(state.root.Position, Color3.fromRGB(120, 240, 160), 24, 0.6)
		state.hp = math.min(CFG.hp, state.hp + CFG.hp * 0.25)
		state.humanoid.Health = state.hp
		for _, a in ipairs(near(state, state.root.Position, 24, false)) do
			if a.player then
				Vitals.HealFraction(a.player, 0.25)
			elseif a.bot and a.bot ~= state then
				a.bot.hp = math.min(CFG.hp, a.bot.hp + CFG.hp * 0.25)
				a.bot.humanoid.Health = a.bot.hp
			end
		end
	elseif id == "Bulwark" then
		state.invulnUntil = os.clock() + 5
		local aura = Instance.new("Part")
		aura.Shape = Enum.PartType.Ball
		aura.Size = Vector3.one * 9
		aura.Material = Enum.Material.Neon
		aura.Color = Color3.fromRGB(255, 205, 90)
		aura.Transparency = 0.7
		aura.CanCollide, aura.CanQuery, aura.CanTouch, aura.Massless = false, false, false, true
		aura.CFrame = state.root.CFrame
		local weld = Instance.new("WeldConstraint")
		weld.Part0, weld.Part1 = aura, state.root
		weld.Parent = aura
		aura.Parent = state.model
		Debris:AddItem(aura, 5)
	end
	return true
end

--------------------------------------------------------------------------------
-- สมอง (หนึ่งเธรดต่อหนึ่งตัว)
--------------------------------------------------------------------------------
-- ท่าเดิน/ยืนของ Roblox มาตรฐาน (ชุดเดียวกับ NPC ในโรงงาน `R.ANIM`) — บอทเป็นโมเดลบนเซิร์ฟ ไม่มีสคริปต์
-- Animate ของผู้เล่นมาขยับให้ เล่นจากเซิร์ฟแล้ว replicate ไปทุกเครื่องเอง
local WALK_ANIM, IDLE_ANIM = "rbxassetid://507777826", "rbxassetid://507766388"

local function loadTracks(state)
	local animator = state.humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = state.humanoid
	end
	local function track(id)
		local a = Instance.new("Animation")
		a.AnimationId = id
		local ok, t = pcall(function() return animator:LoadAnimation(a) end)
		if ok then t.Looped = true end
		return ok and t or nil
	end
	state.walkTrack, state.idleTrack = track(WALK_ANIM), track(IDLE_ANIM)
	state.animator = animator
end

local function animate(state)
	local v = state.root.AssemblyLinearVelocity
	local moving = Vector3.new(v.X, 0, v.Z).Magnitude > 1.5
	local on, off = state.walkTrack, state.idleTrack
	if not moving then on, off = off, on end
	if off and off.IsPlaying then off:Stop(0.2) end
	if on and not on.IsPlaying then on:Play(0.2) end
end

local function think(state)
	loadTracks(state)
	while state.alive and state.model.Parent do
		task.wait(0.35)
		animate(state)
		if not state.free then
			-- ช่วงซื้อของ: ยืนนิ่งอยู่ในฐานเหมือนคนอื่น
			state.humanoid:Move(Vector3.zero)
		else
			tryPotion(state)
			local targetRoot, distance = nearestEnemy(state)
			if targetRoot then
				local spec = weaponSpec(state)
				local inRange = distance <= spec.range and (not spec.ranged or clearLine(state, targetRoot.Position))
				-- อาวุธยิงไกล: ยืนยิงเมื่อเห็นเป้าในระยะ ไม่เดินเข้าไปชิดเหมือนดาบ
				if spec.ranged and inRange and distance <= spec.range * 0.8 then
					state.humanoid:MoveTo(state.root.Position)
				else
					walkTo(state, targetRoot.Position)
				end
				-- หันหน้าเข้าหาเป้า **เฉพาะตอนอยู่ในระยะโจมตี**
				-- ⚠️ ห้ามหันทุกรอบตอนเดิน: เขียน CFrame ของ root ทับทุก 0.35 วิ ฆ่าแรงเดินของ MoveTo
				-- ทันทีที่ทางเดินพาอ้อม (เช่นอ้อมหอนาฬิกา) บอทหยุดนิ่งทั้งที่มีทางอยู่ (เจอจริง 2026-09-24)
				if inRange or distance <= spec.range + 2 then
					local look = Vector3.new(targetRoot.Position.X, state.root.Position.Y, targetRoot.Position.Z)
					if (look - state.root.Position).Magnitude > 0.5 then
						state.root.CFrame = CFrame.lookAt(state.root.Position, look)
					end
				end
				if not trySkill(state, targetRoot, distance, spec) and inRange then attack(state, targetRoot, spec) end
			elseif state.home then
				-- ไม่เห็นใคร: เดินไปแถวกลางแมพ ซึ่งเป็นที่ที่การปะทะเกิดขึ้น — บอทที่ยืนเฝ้าฐานคือรอบที่ไม่มีวันจบ
				-- ⚠️ ห้ามเดินไปจุดกลางเป๊ะ แมพอาจมีของตั้งอยู่ตรงนั้น (ปราสาทมีหอนาฬิกา) — สุ่มจุดรอบๆ ต่อตัว
				walkTo(state, state.home)
			end
		end
	end
end

--------------------------------------------------------------------------------
-- ทางที่ระบบต่อสู้ใช้ตีบอท
--------------------------------------------------------------------------------
-- คืน true เมื่อโมเดลนี้เป็นบอทที่ยังมีชีวิตจริงๆ — `PlayerCombat` ใช้ค่านี้ตัดสินว่าจะเล่นเสียงลงเป้าไหม
function ArenaBots.Damage(model, amount, attacker, pierce)
	local state = Live[model]
	if not state or not state.alive or amount <= 0 then return false end
	if os.clock() < (state.invulnUntil or 0) then return true end -- คำท้าทองคำ / กล่องปฐมพยาบาล
	-- เกราะ: กันดาเมจตามสัดส่วนของชุด จนกว่าแต้มเกราะจะหมด (ทรงเดียวกับเกราะของผู้เล่น)
	if not pierce and (state.armorPool or 0) > 0 and (state.absorb or 0) > 0 then
		local blocked = math.min(state.armorPool, amount * state.absorb)
		state.armorPool -= blocked
		amount -= blocked
	end

	state.hp = math.max(0, state.hp - amount)
	state.humanoid.Health = state.hp
	if attacker and hooks.onPlayerHitBot then
		hooks.onPlayerHitBot(attacker, model, amount)
	end
	if state.hp <= 0 then
		ArenaBots.Kill(model, attacker)
	end
	return true, state.hp <= 0 -- ค่าที่สอง = ไม้นี้ฆ่าไหม (เหมือน Mobs.damage)
end

function ArenaBots.Stun(model, seconds)
	local state = Live[model]
	if not state or not state.alive then return end
	state.free = false
	task.delay(seconds, function()
		if state.alive then state.free = true end
	end)
end

function ArenaBots.Kill(model, killer)
	local state = Live[model]
	if not state or not state.alive then return end
	state.alive = false
	state.humanoid.Health = 0
	if hooks.onDied then hooks.onDied(model, killer) end
	-- ทิ้งร่างไว้ให้เห็นสักครู่แล้วเก็บ — ศพที่หายทันทีทำให้ไม่มีใครรู้ว่าเพิ่งเกิดอะไรขึ้นตรงนั้น
	task.delay(3, function()
		if model.Parent then model:Destroy() end
	end)
end

--------------------------------------------------------------------------------
-- วงจรชีวิต
--------------------------------------------------------------------------------
-- `hookTable` ต้องมี: sideOfPlayer(player) · onPlayerHitBot(player, model, amount)
--                    · onBotHitPlayer(model, player, amount) · onDied(model, killer)
function ArenaBots.Bind(hookTable)
	hooks = hookTable
	MobAccess.Damage = ArenaBots.Damage
	MobAccess.Stun = ArenaBots.Stun
end

function ArenaBots.Spawn(side, name, cframe, home)
	local model = buildRig()
	if not model then
		warn("[ArenaBots] ปั้นร่างบอทไม่ได้ — ทีม", side, "จะขาดคน")
		return nil
	end

	model.Name = name
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local root = model:FindFirstChild("HumanoidRootPart")
	if not humanoid or not root then
		model:Destroy()
		warn("[ArenaBots] ร่างที่ได้ไม่มี Humanoid/HumanoidRootPart")
		return nil
	end

	humanoid.MaxHealth = CFG.hp
	humanoid.Health = CFG.hp
	humanoid.WalkSpeed = CFG.walkSpeed
	humanoid.DisplayName = name
	-- ป้ายชื่อมองเห็นได้ไกลเท่าที่สนามกว้าง: คนต้องแยกออกว่าคนที่วิ่งมาคือบอทหรือเพื่อนร่วมทีม
	humanoid.NameDisplayDistance = 250
	-- ร่าง NPC จากโรงงานปิดป้ายชื่อไว้ (DisplayDistanceType None) — บอทต้องมีชื่อให้เห็นว่าเป็นบอท
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.Viewer
	-- หลอดเลือดของ Roblox เองปิดไว้ — สนามวาดหลอดแดง/เขียวตามทีมให้เองฝั่งไคลเอนต์ (ArenaController)
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	humanoid.BreakJointsOnDeath = false

	model.Parent = workspace
	model:PivotTo(cframe)
	CollectionService:AddTag(model, "WOLD_Mob") -- ทางที่ระบบต่อสู้ใช้หาเป้าที่ไม่ใช่ผู้เล่น
	model:SetAttribute("ArenaSide", side)

	local state = {
		model = model, humanoid = humanoid, root = root,
		side = side, hp = CFG.hp, alive = true, free = false,
		-- สุ่มจุดรอบกลางแมพ รัศมี 25-45 ต่อบอทหนึ่งตัว (คนละจุดกัน ไม่เดินไปกองรวมที่เดียว)
		home = home and (home + CFrame.Angles(0, math.random() * math.pi * 2, 0).LookVector * (25 + math.random() * 20)),
		nextSwing = 0,
	}
	Live[model] = state
	task.spawn(think, state)
	return model
end

-- ใส่ของที่ "ซื้อ" ให้บอท: อาวุธในมือ (ผ่าน WeaponVisuals ตัวเดียวกับคน) ชุดเกราะ ยา มานา กระสุน
-- `loadout` = { weapon, armor, armorPool?, use, mana, ammo }
function ArenaBots.Equip(model, loadout)
	local state = Live[model]
	if not state then return end
	loadout = loadout or {}
	state.weapon, state.ammo, state.potion, state.mana = loadout.weapon, loadout.ammo, loadout.use, loadout.mana or 0
	local armor = loadout.armor and ItemCatalog.Items[loadout.armor]
	state.armorId = loadout.armor
	state.absorb = armor and armor.absorbFraction or 0
	state.armorPool = loadout.armorPool or (armor and armor.armor) or 0
	if WeaponVisualsAccess.HoldOn then WeaponVisualsAccess.HoldOn(model, state.weapon, nil) end
	KitWear.Strip(model, ARMOR_FOLDER)
	local kit = loadout.armor and ARMOR_KITS[loadout.armor]
	if kit then KitWear.Wear(model, kit, nil, ARMOR_FOLDER) end
end

-- ของที่บอทยังเหลือติดตัว (รอดรอบ = พกไปรอบหน้า เหมือนคน)
function ArenaBots.Loadout(model)
	local state = Live[model]
	if not state then return {} end
	return { weapon = state.weapon, armor = state.armorId, armorPool = state.armorPool, use = state.potion,
		mana = state.mana, ammo = state.ammo }
end

-- เปิด/ปิดขาทั้งสนามพร้อมกันตอนเริ่ม/จบรอบ
function ArenaBots.SetFree(free)
	for _, state in pairs(Live) do
		state.free = free and true or false
	end
end

function ArenaBots.AliveCount(side)
	local n = 0
	for _, state in pairs(Live) do
		if state.alive and state.side == side then n += 1 end
	end
	return n
end

function ArenaBots.All()
	local list = {}
	for model, state in pairs(Live) do
		list[#list + 1] = { model = model, side = state.side, alive = state.alive, name = model.Name }
	end
	return list
end

function ArenaBots.Clear()
	for model, state in pairs(Live) do
		state.alive = false
		if model.Parent then model:Destroy() end
	end
	Live = {}
end

return ArenaBots
