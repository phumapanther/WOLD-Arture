-- StatusEffects.lua: temporary states weapons inflict — knocked down by an arrow, slowed by a spell.
--
-- Kept apart from Vitals because these are not vitals: they expire on a timer, stack by replacement rather
-- than by accumulation, and must clear cleanly if the victim dies or respawns mid-effect.
--
-- Server-authoritative: the effect is applied here and the client is only told so it can render.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Vitals = require(game.ServerScriptService.Vitals)
local VitalsConfig = require(game.ReplicatedStorage.VitalsConfig)
local Remotes = require(game.ReplicatedStorage.Remotes)
local RescueAccess = require(game.ServerScriptService.RescueAccess)

local StatusEffects = {}

-- [player] = { knockdownUntil = number?, slowUntil = number?, slowFactor = number? }
local Active = {}

local NORMAL_WALK_SPEED = 8

local function stateFor(player)
	Active[player] = Active[player] or {}
	return Active[player]
end

--------------------------------------------------------------------------------
-- Knockdown: flat on the ground, unable to move, for a few seconds.
--------------------------------------------------------------------------------

local function applyKnockdownPosture(player, down)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end

	if down then
		-- PlatformStand rather than a WalkSpeed of 0: it stops the engine driving the rig upright and
		-- ignores input entirely, which is what "ขยับไม่ได้" needs.
		humanoid.PlatformStand = true
		-- But PlatformStand ALONE just goes limp and settles wherever physics puts it, which reads as a
		-- bug rather than as being shot. Lay them deliberately on their back, using the same root-joint
		-- pose the downed crawl uses.
		Vitals.SetProne(player, true, true)
	else
		Vitals.SetProne(player, false)
		humanoid.PlatformStand = false
		-- The engine leaves a platform-standing humanoid lying there; nudge it back onto its feet.
		humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
	end
	Remotes.StatusChanged:FireAllClients(player, "knockdown", down)
end

function StatusEffects.Knockdown(player, seconds)
	-- A downed player is already on the floor; knocking them down again would fight the crawl.
	if Vitals.IsDowned(player) then return end
	local state = stateFor(player)
	local wasDown = state.knockdownUntil ~= nil
	state.knockdownUntil = os.clock() + seconds
	if not wasDown then applyKnockdownPosture(player, true) end
end

--------------------------------------------------------------------------------
-- Dizzy: rooted where you stand, seeing stars, for a few seconds.
--------------------------------------------------------------------------------

-- What a botched minigame costs. Deliberately NOT a knockdown: being shot with an arrow lays you out flat,
-- while fumbling a lock or a repair should leave you standing there swearing at it. So the body stays upright
-- and only the ability to go anywhere is taken away.
--
-- Rooting is done through the speed multiplier PlayerMovement already asks for every tick, rather than with
-- PlatformStand. PlatformStand would fight the movement state machine for the same body, and the crawl and
-- the carry have both already been through that argument.
-- One emoji over a player's head, on or off. The dizzy stars had their own copy of this; three more marks
-- were asked for (tired, asleep, chilled) and four copies of the same twenty lines is how they drift apart.
--
-- Built on the SERVER so everyone nearby sees it, the same way a monster's health bar is: a state other
-- people are meant to react to has to be visible to them.
local function setMark(player, name, emoji, colour, on)
	local character = player and player.Character
	local head = character and character:FindFirstChild("Head")
	if not head then return end

	local existing = head:FindFirstChild(name)
	if not on then
		if existing then existing:Destroy() end
		return
	end
	if existing then return end

	local gui = Instance.new("BillboardGui")
	gui.Name = name
	gui.Size = UDim2.fromOffset(60, 30)
	gui.StudsOffsetWorldSpace = Vector3.new(0, 1.8, 0)
	gui.MaxDistance = 60
	gui.AlwaysOnTop = true
	gui.Parent = head

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.TextColor3 = colour
	label.Text = emoji
	label.Parent = gui
end

-- The three the user asked for, by the state that causes them rather than by what they look like.
local MARK_TIRED = { name = "TiredMark", emoji = "💦", colour = Color3.fromRGB(150, 210, 255) }  -- หมดแรง
local MARK_ASLEEP = { name = "AsleepMark", emoji = "💤", colour = Color3.fromRGB(190, 200, 255) } -- ล้มจากกระสุน/ธนู
local MARK_SLOWED = { name = "SlowedMark", emoji = "💦", colour = Color3.fromRGB(150, 210, 255) } -- โดนคฑาสโลว์

-- Published so the systems that own each state can raise and clear their own mark. StatusEffects owns the
-- drawing; it does not own the reasons.
function StatusEffects.SetTired(player, on) setMark(player, MARK_TIRED.name, MARK_TIRED.emoji, MARK_TIRED.colour, on) end
function StatusEffects.SetAsleep(player, on)
	setMark(player, MARK_ASLEEP.name, MARK_ASLEEP.emoji, MARK_ASLEEP.colour, on)
	if not on then return end

	-- ลบเองเมื่อคนนั้นลุกขึ้น โดยดู Attribute ที่ Vitals ตั้งไว้อยู่แล้ว
	--
	-- **ทำแบบนี้เพราะ require กลับไปหา Vitals ไม่ได้** — StatusEffects require Vitals อยู่แล้ว การ require
	-- กลับจะเป็นวงกลมและทั้งสองไฟล์จะโหลดไม่ขึ้น ส่วน Attribute เป็นของที่ Vitals เผยแพร่ออกมาอยู่แล้ว
	-- ไม่ต้องเพิ่มอะไรฝั่งนั้นเลย
	local conn
	conn = player:GetAttributeChangedSignal("WOLD_Downed"):Connect(function()
		if player:GetAttribute("WOLD_Downed") then return end
		conn:Disconnect()
		setMark(player, MARK_ASLEEP.name, MARK_ASLEEP.emoji, MARK_ASLEEP.colour, false)
	end)
end

local function applyDizzyMark(player, dizzy)
	local character = player.Character
	local head = character and character:FindFirstChild("Head")
	if not head then return end

	local existing = head:FindFirstChild("DizzyMark")
	if not dizzy then
		if existing then existing:Destroy() end
		return
	end
	if existing then return end

	-- Built on the server so everyone nearby sees it, the same way a monster's health bar is: being stunned
	-- in front of other people is part of the cost.
	local gui = Instance.new("BillboardGui")
	gui.Name = "DizzyMark"
	gui.Size = UDim2.fromOffset(60, 30)
	gui.StudsOffsetWorldSpace = Vector3.new(0, 1.8, 0)
	gui.MaxDistance = 60
	gui.AlwaysOnTop = true
	gui.Parent = head

	local stars = Instance.new("TextLabel")
	stars.Size = UDim2.fromScale(1, 1)
	stars.BackgroundTransparency = 1
	stars.Font = Enum.Font.GothamBold
	stars.TextScaled = true
	stars.TextColor3 = Color3.fromRGB(255, 232, 140)
	stars.Text = "\240\159\146\171" -- the dizzy-symbol emoji
	stars.Parent = gui
end

-- The pose that goes with the stars: hands to the head, body swaying. Played on the SERVER through the
-- humanoid's own Animator, the same reason the downed posture is -- being stunned in front of other people
-- is part of the cost, and a client-side track would only be seen by the person it happened to.
--
-- The track is kept per player so the same one can be stopped again; loading a second copy on top of the
-- first leaves one playing forever, which is a player stuck clutching their head for the rest of the round.
local DizzyTracks = {}

local function applyDizzyPose(player, dizzy)
	local existing = DizzyTracks[player]
	if not dizzy then
		if existing then
			existing:Stop(0.25)
			DizzyTracks[player] = nil
		end
		return
	end
	if existing or VitalsConfig.DizzyAnimation == "" then return end

	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
	if not animator then return end

	local anim = Instance.new("Animation")
	anim.AnimationId = VitalsConfig.DizzyAnimation
	local ok, track = pcall(function() return animator:LoadAnimation(anim) end)
	if not ok or not track then return end
	track.Priority = Enum.AnimationPriority.Action
	track.Looped = true
	track:Play(0.2)
	DizzyTracks[player] = track
end

-- Jumping is switched off by TWO different states -- being dizzy, and being held still for a minigame -- so
-- neither may set the property directly. Both set their flag and call this, which works out the answer from
-- everything currently true.
--
-- Written the other way round first, with each state calling setJumping(false) on the way in and (true) on
-- the way out, and it had a hole: a farm minigame that fails hands the legs back as the attempt ends and
-- then takes them away again for the dizzy spell, and if those two ever landed out of order the player
-- finished the sequence able to jump while still rooted.
local function refreshJumping(player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end

	local state = Active[player]
	local held = state ~= nil and (state.rooted == true
		or (state.dizzyUntil ~= nil and os.clock() < state.dizzyUntil)
		-- A pose counts too: jumping out of a cross-legged sit is the obvious way to break one, and it looks
		-- absurd. Walking still ends a pose -- that is the deliberate way out -- but not by leaving the ground.
		or state.posing == true)

	-- Both properties, because which one the engine reads depends on UseJumpPower and a rig may be set either
	-- way. Restoring to Roblox's own defaults rather than to what was there before is safe here: nothing else
	-- in the game changes them.
	humanoid.JumpPower = held and 0 or 50
	humanoid.JumpHeight = held and 0 or 7.2
end

--------------------------------------------------------------------------------
-- Rooted: held where you stand for as long as something is asking you to concentrate.
--------------------------------------------------------------------------------

-- Not a timer, unlike everything else here: it is held while a quick-time minigame is on screen and released
-- when it ends, however it ends. Minigames.lua owns both edges.
--
-- The reason it exists: a repair is cancelled by walking away from the transformer, and the check measured
-- straight-line distance -- so JUMPING moved the player seven studs up, past the six-stud limit, and dropped
-- a repair that was going fine. Measuring flat distance fixes that particular symptom (and is fixed too),
-- but the real answer to "a minigame is asking for your whole attention" is to stop the character moving at
-- all while it is up. No stars over the head: this is not a punishment, and it lasts a second or two.
function StatusEffects.SetRooted(player, rooted)
	local state = stateFor(player)
	if rooted then state.rooted = true else state.rooted = nil end
	refreshJumping(player)
end

function StatusEffects.IsRooted(player)
	local state = Active[player]
	return state ~= nil and state.rooted == true
end

function StatusEffects.Dizzy(player, seconds)
	-- Already on the floor: leave the crawl alone, exactly as Knockdown does.
	if Vitals.IsDowned(player) then return end
	local state = stateFor(player)
	local wasDizzy = state.dizzyUntil ~= nil
	state.dizzyUntil = os.clock() + seconds
	if not wasDizzy then
		applyDizzyMark(player, true)
		applyDizzyPose(player, true)
		refreshJumping(player)
		Remotes.StatusChanged:FireAllClients(player, "dizzy", true)
	end
end

function StatusEffects.IsDizzy(player)
	local state = Active[player]
	return state ~= nil and state.dizzyUntil ~= nil and os.clock() < state.dizzyUntil
end

--------------------------------------------------------------------------------
-- Posing: held still by an emote, until the player says otherwise.
--------------------------------------------------------------------------------

-- Sitting cross-legged or lying down means staying put, and staying put has to be decided here: the client
-- owns the animation but PlayerMovement owns WalkSpeed, and it writes it every tick from SpeedMultiplier.
--
-- No timer. Unlike every other state in this file a pose ends when the player ends it -- they stand up, they
-- walk, they take a hit -- so it is cleared by the same events that clear everything else rather than by the
-- clock, and Tick never looks at it.
function StatusEffects.SetPosing(player, posing)
	local state = stateFor(player)
	if state.posing == posing then return end
	state.posing = posing or nil
	refreshJumping(player)
end

function StatusEffects.IsPosing(player)
	local state = Active[player]
	return state ~= nil and state.posing == true
end

--------------------------------------------------------------------------------
-- Slow: movement speed cut for a few seconds.
--------------------------------------------------------------------------------

function StatusEffects.Slow(player, seconds, factor)
	local state = stateFor(player)
	state.slowUntil = os.clock() + seconds
	state.slowFactor = factor or 0.5
	Remotes.StatusChanged:FireAllClients(player, "slow", true)

	-- The mark is raised here and cleared on a timer rather than by the tick loop, because Slow has no loop
	-- of its own -- SpeedMultiplier just reads the deadline when somebody asks. The guard re-reads the
	-- deadline so a second slow landing mid-way does not have the first one's timer pull the mark off early.
	setMark(player, MARK_SLOWED.name, MARK_SLOWED.emoji, MARK_SLOWED.colour, true)
	task.delay(seconds, function()
		local now = Active[player]
		if not now or not now.slowUntil or os.clock() >= now.slowUntil then
			setMark(player, MARK_SLOWED.name, MARK_SLOWED.emoji, MARK_SLOWED.colour, false)
		end
	end)
end

-- PlayerMovement asks for this every tick, so the slow rides on top of whatever speed the movement state and
-- carry weight already decided rather than fighting them for the WalkSpeed property.
function StatusEffects.SpeedMultiplier(player)
	local state = Active[player]
	if not state then return 1 end
	local now = os.clock()
	-- Rooted first, then dizzy, then slow: strongest wins, and one expiring must never hand the legs back to
	-- someone another state is still holding.
	if state.rooted then return 0 end
	if state.dizzyUntil and now < state.dizzyUntil then return 0 end
	-- Below the two that are done TO a player, above the slow: a pose is chosen, so anything forced on them
	-- outranks it, but it still stops them walking.
	if state.posing then return 0 end
	if state.slowUntil and now < state.slowUntil then return state.slowFactor or 0.5 end
	return 1
end

function StatusEffects.IsKnockedDown(player)
	local state = Active[player]
	return state ~= nil and state.knockdownUntil ~= nil
end

-- **ตี/ใช้สกิล/กลิ้ง ได้ไหมตอนนี้** — ด่านเดียวที่ทุกทางถาม (QA 2026-09-26)
-- เดิมเช็คแค่ "ล้มคลาน" คนที่ถูกจับกุมจึงฟันทหารยามที่ยืนตรงหน้าจนล้มแล้วหนีได้ คนถูกยิงล้ม/มึนหัวก็ยังตีต่อ
-- ได้ทั้งที่นอนอยู่ และคนที่ถูกอุ้มยิงจากหลังคนอุ้มได้ · ล้มคลานยังเช็คที่ผู้เรียกเหมือนเดิม (Vitals เป็นเจ้าของ)
function StatusEffects.CanFight(player)
	if StatusEffects.IsKnockedDown(player) or StatusEffects.IsDizzy(player) then return false end
	if player:GetAttribute("WOLD_Arrested") then return false end
	if RescueAccess.IsCarried and RescueAccess.IsCarried(player) then return false end
	return true
end

--------------------------------------------------------------------------------
-- Expiry and cleanup, driven by PlayerStatusEffects.server.lua
--------------------------------------------------------------------------------

-- Drops every effect a player has. Used on respawn and on leaving; safe when they have none.
--
-- The dizzy pose is stopped by hand here. Everything else in the table is a number that simply stops being
-- read, but a playing AnimationTrack is a real thing holding a real rig: emptying the table around it would
-- leave the player clutching their head with nothing left that knows to stop it.
function StatusEffects.ClearFor(player)
	applyDizzyPose(player, false)
	Active[player] = nil
end

function StatusEffects.Tick()
	local now = os.clock()
	for player, state in pairs(Active) do
		if not player.Parent then
			Active[player] = nil
		else
			if state.knockdownUntil and now >= state.knockdownUntil then
				state.knockdownUntil = nil
				applyKnockdownPosture(player, false)
			end
			if state.slowUntil and now >= state.slowUntil then
				state.slowUntil = nil
				Remotes.StatusChanged:FireAllClients(player, "slow", false)
			end
			if state.dizzyUntil and now >= state.dizzyUntil then
				state.dizzyUntil = nil
				applyDizzyMark(player, false)
				applyDizzyPose(player, false)
				refreshJumping(player)
				Remotes.StatusChanged:FireAllClients(player, "dizzy", false)
			end
			-- Going down overrides being dizzy for the same reason it overrides a knockdown: from then on the
			-- crawl owns the body, and a rooted-in-place multiplier would stop the crawl dead.
			if state.dizzyUntil and Vitals.IsDowned(player) then
				state.dizzyUntil = nil
				applyDizzyMark(player, false)
				applyDizzyPose(player, false)
				refreshJumping(player)
				Remotes.StatusChanged:FireAllClients(player, "dizzy", false)
			end
			-- Going down overrides a knockdown: the crawl owns the body from then on.
			if state.knockdownUntil and Vitals.IsDowned(player) then
				state.knockdownUntil = nil
				applyKnockdownPosture(player, false)
			end
		end
	end
end

return StatusEffects
