-- CombatController: turns left-click into an attack request and plays the resulting animations. Like
-- MovementController, it sends intent only — the server decides whether an attack actually happens, what it
-- hits, and when the guard drops. Animations play here (and for other players via CombatStateChanged) purely
-- as presentation.
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local CombatConfig = require(game.ReplicatedStorage.CombatConfig)
local Remotes = require(game.ReplicatedStorage.Remotes)
local AimAccess = require(game.ReplicatedStorage.UI.AimAccess)

local player = Players.LocalPlayer
local equippedWeaponId = nil -- set from EquipmentChanged; drives which animation set is loaded

-- One track cache per character, rebuilt on respawn since Animator is recreated with the character.
local tracks = {}

local function loadTracksFor(character)
	tracks = {}
	local humanoid = character:WaitForChild("Humanoid")
	local animator = humanoid:WaitForChild("Animator")
	-- equippedWeaponId is kept in step by EquipmentChanged below; nil means bare hands.
	local weapon = CombatConfig.Weapons[equippedWeaponId or CombatConfig.DefaultWeapon]
		or CombatConfig.Weapons[CombatConfig.DefaultWeapon]

	local function load(id, priority, looped)
		if not id or id == "" then return nil end -- unpublished animation: system still works, just silent
		local anim = Instance.new("Animation")
		anim.AnimationId = id
		local ok, track = pcall(function() return animator:LoadAnimation(anim) end)
		if not ok then
			warn("[Combat] failed to load animation", id, track)
			return nil
		end
		track.Priority = priority
		track.Looped = looped or false
		return track
	end

	-- The weapon's held stance. Movement priority, NOT Idle: at Idle it ties with Roblox's own idle and mood
	-- animations at equal weight (measured: three tracks all at Idle, w=1.00) and the default wins, so the
	-- stance never showed. Movement still sits below Action, so swings play over it, and because the stance
	-- poses no leg joints the default walk and run keep driving the legs regardless of priority.
	tracks.idle = load(weapon.idleAnimation, Enum.AnimationPriority.Movement, true)
	tracks.guard = load(weapon.guardAnimation, Enum.AnimationPriority.Action)
	tracks.attacks = {}
	for i, attack in ipairs(weapon.attacks) do
		tracks.attacks[i] = load(attack.animation, Enum.AnimationPriority.Action4)
	end
	-- ท่าต่อยสำรอง: ปืนกระสุนหมดแล้วเซิร์ฟเวอร์สั่งให้ต่อยแทน (อาร์กิวเมนต์ท้ายของ "attack")
	tracks.fists = {}
	for i, attack in ipairs(CombatConfig.Weapons[CombatConfig.DefaultWeapon].attacks) do
		tracks.fists[i] = load(attack.animation, Enum.AnimationPriority.Action4)
	end

	-- Every skill animation this character might play, loaded once with the rest. Keyed by skill id, not by
	-- weapon: LungeSlash looks the same whichever blade threw it, which is what the user asked for.
	tracks.skills = {}
	for skillId, animationId in pairs(CombatConfig.SkillAnimations or {}) do
		tracks.skills[skillId] = load(animationId, Enum.AnimationPriority.Action4)
	end
end

-- The weapon's stance is NOT held while simply carrying something.
--
-- It used to play the whole time a weapon was equipped, and it poses both shoulders and the waist at
-- Movement priority -- the same priority Roblox's own walk and run use -- so whoever played last won. A
-- player carrying a sword walked rigid: arms locked in front, no stride, no swing. Stopping it while moving
-- and restarting it when they stopped was the first fix, and it still left the character frozen whenever
-- they stood still.
--
-- So the stance is now only worn AROUND A SWING. Carry a weapon and you move exactly as you would
-- empty-handed; attack and the weapon's own pose takes over; stop attacking and after a few seconds the
-- body goes back to being a body.
--
-- How long the pose lingers after a swing. Deliberately short: it is there to carry one blow into the next,
-- not to be a posture the character adopts. Its own constant rather than the weapon's idleTimeout, which
-- means something different -- how long the SERVER keeps a combat stance alive -- and should not be dragged
-- around by an animation decision.
local STANCE_SECONDS = 1.5

-- Above this the character is running, and a runner does not hold a guard. Halfway between the normal walk
-- (8) and the sprint (16), so it catches a sprint without being tripped by a downhill stumble.
local RUNNING_SPEED = 12

-- Bumped every time a swing lands, so an attack during the countdown extends it rather than the first
-- attack's timer cutting the second one short. Also bumped when the pose is dropped early, so a timer
-- already in flight cannot fire afterwards and stop a pose that a newer swing has since started.
local stanceToken = 0

local function dropStanceNow()
	stanceToken += 1
	if tracks.idle and tracks.idle.IsPlaying then
		tracks.idle:Stop(0.2)
	end
end

local function dropStanceSoon()
	if not tracks.idle then return end
	stanceToken += 1
	local mine = stanceToken
	task.delay(STANCE_SECONDS, function()
		if stanceToken ~= mine then return end
		if tracks.idle and tracks.idle.IsPlaying then
			tracks.idle:Stop(0.3)
		end
	end)
end

-- Hold the weapon's pose now, and start the countdown that puts it away again.
local function wearStanceBriefly()
	if not tracks.idle then return end
	if not tracks.idle.IsPlaying then tracks.idle:Play(0.15) end
	dropStanceSoon()
end

-- Break out of the pose the moment the player breaks into a run.
--
-- Measured from the character's actual speed rather than from a sprint flag, because the flag lives on the
-- server and there are three ways to ask for a sprint -- shift, a gamepad stick, a touch thumbstick. Speed
-- is the one thing all three end up agreeing on.
local function watchForRunning(character)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end
	local connection
	connection = RunService.RenderStepped:Connect(function()
		if not character.Parent or humanoid.Health <= 0 then
			connection:Disconnect()
			return
		end
		if not tracks.idle or not tracks.idle.IsPlaying then return end
		-- A swing owns the arms while it lasts; interrupting it would cut the attack animation in half.
		for _, track in pairs(tracks.attacks or {}) do
			if track.IsPlaying then return end
		end
		-- And so does a skill. A leap is faster than the running threshold by design, so without this the
		-- watcher would drop the stance and cut the chop halfway through every single time.
		for _, track in pairs(tracks.skills or {}) do
			if track.IsPlaying then return end
		end
		-- **ความเร็วอ่านจาก HumanoidRootPart ไม่ใช่จาก Humanoid** — `AssemblyLinearVelocity` เป็นสมบัติ
		-- ของ BasePart ส่วน Humanoid ไม่มี บรรทัดนี้จึง error ทุกเฟรมที่ท่ายืนการ์ดทำงาน (Output ท่วมจน
		-- error อื่นจมหมด) และท่าการ์ดก็ไม่เคยถูกปลดตอนวิ่งเลยเพราะโค้ดตายก่อนถึง dropStanceNow
		local rootPart = humanoid.RootPart
		if rootPart and rootPart.AssemblyLinearVelocity.Magnitude > RUNNING_SPEED then
			dropStanceNow()
		end
	end)
end

local function onCharacterAdded(character)
	loadTracksFor(character)
	watchForRunning(character)
end

-- The weapon decides which animations play, so a change has to rebuild the cache.
local function useWeapon(weaponId)
	if weaponId == equippedWeaponId then return end
	-- Drop the previous weapon's stance before the new tracks replace the table.
	if tracks.idle then tracks.idle:Stop(0.2) end
	equippedWeaponId = weaponId
	if player.Character then
		loadTracksFor(player.Character)
		-- No pose on equipping. Picking a sword up should not change how you walk; the stance is worn only
		-- around a swing now.
	end
end

-- Fires for every player; only our own matters here.
Remotes.EquipmentChanged.OnClientEvent:Connect(function(who, weaponId)
	if who ~= player then return end
	useWeapon(weaponId)
end)

-- EquipmentChanged only fires when equipment CHANGES, so a player who joins already holding a weapon was
-- never told and loaded the bare-hands animations — which is why attacking looked like a punch until the
-- weapon was taken off and put back on. InventoryUpdate carries the equipped set and does arrive on join, so
-- it is the reliable source for the initial state.
Remotes.InventoryUpdate.OnClientEvent:Connect(function(data)
	useWeapon(data and data.equipped and data.equipped.weapon and data.equipped.weapon.id or nil)
end)

-- The Q skill's animation. Fired for EVERY player, and unlike the attack broadcast this one is worth
-- playing for other people too -- but their characters animate from their own client's tracks, so as with
-- CombatStateChanged only our own is handled here.
--
-- A skill is a swing: it has to stop the stance and the ordinary attack tracks first, exactly as the attack
-- branch does, or it blends underneath them and barely moves.
Remotes.SkillUsed.OnClientEvent:Connect(function(who, skillId)
	if who ~= player then return end
	local track = tracks.skills and tracks.skills[skillId]
	if not track then return end

	for _, other in pairs(tracks.attacks or {}) do other:Stop(0) end
	for _, other in pairs(tracks.skills or {}) do
		if other ~= track then other:Stop(0) end
	end
	if tracks.guard then tracks.guard:Stop(0.05) end
	if tracks.idle then tracks.idle:Stop(0.05) end

	track:Play(0.05)
	track.Stopped:Once(function()
		-- Don't restore the stance if another swing or skill has already started.
		for _, other in pairs(tracks.attacks or {}) do
			if other.IsPlaying then return end
		end
		for _, other in pairs(tracks.skills or {}) do
			if other.IsPlaying then return end
		end
		if tracks.idle then wearStanceBriefly() end
	end)
end)

player.CharacterAdded:Connect(onCharacterAdded)
if player.Character then onCharacterAdded(player.Character) end

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end -- don't punch when the click was consumed by a button
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		-- กับดัก: คลิกซ้ายเป็นของ TrapController (กดค้างเล็ง/ปล่อยเขวี้ยง) ไม่ส่งคำขอตี (เฟส 3)
		local held = CombatConfig.Weapons[player:GetAttribute("WOLD_Weapon") or ""]
		if held and held.trap then return end
		-- The aim point rides along with every attack. The server ignores it for a weapon that does not
		-- throw anything, so a sword is unaffected by whatever the camera happens to be looking at.
		local aim = AimAccess.Fire or AimAccess.Point
		Remotes.RequestAttack:FireServer(aim and aim() or nil)
	elseif input.KeyCode == Enum.KeyCode.Q then
		-- Which skill this is depends on the equipped weapon; the server resolves that and the mana cost.
		Remotes.RequestSkill:FireServer()
	end
end)

-- Play animations for whoever the server says did what — including this player, so the local view matches
-- what everyone else sees rather than predicting separately.
Remotes.CombatStateChanged.OnClientEvent:Connect(function(who, event, chainIndex, _windup, moveSet)
	if who ~= player then return end -- other players' characters animate via their own replicated tracks
	-- สไน: การ์ด = ส่องสโคป → ถือท่ายืนของคทา (ปืนกลางอก) ค้างตลอดที่ส่อง ไม่ใช่แค่ 1.5 วิหลังตี
	local spec = CombatConfig.Weapons[equippedWeaponId or CombatConfig.DefaultWeapon]
	local scoped = spec and spec.scope
	if event == "guard_start" then
		if tracks.guard then tracks.guard:Play(0.15) end
		if scoped and tracks.idle then
			stanceToken += 1 -- ตัวนับถอยหลังที่ค้างอยู่ห้ามมาปลดท่าระหว่างส่อง
			if not tracks.idle.IsPlaying then tracks.idle:Play(0.15) end
		end
	elseif event == "guard_end" then
		if tracks.guard then tracks.guard:Stop(0.2) end
		if scoped then dropStanceSoon() end
	elseif event == "attack" then
		-- The looping guard holds every joint at full weight, so a swing playing underneath it barely moves
		-- (measured: 1.22 studs of reach solo, ~0.04 with the guard running). Stop the guard for the swing and
		-- bring it back when the swing ends — the punch animation starts and ends on the guard pose anyway.
		for _, other in pairs(tracks.attacks or {}) do
			other:Stop(0)
		end
		for _, other in pairs(tracks.fists or {}) do
			other:Stop(0)
		end
		if tracks.guard then tracks.guard:Stop(0.05) end
		-- The held stance holds every arm joint, so a swing blended under it barely moves. Same fault the
		-- guard had against the punches; stop it for the swing and bring it back after.
		if tracks.idle then tracks.idle:Stop(0.05) end
		local set = (moveSet == CombatConfig.DefaultWeapon and tracks.fists) or tracks.attacks
		local track = set and set[chainIndex]
		if track then
			track:Play(0.05)
			track.Stopped:Once(function()
				-- Don't restore anything if a newer swing is already running.
				local swinging = false
				for _, other in pairs(tracks.attacks or {}) do
					if other.IsPlaying then swinging = true end
				end
				if swinging then return end
				-- Hold the weapon's pose for a few seconds after the swing, then let the body go back to
				-- normal. Standing ready between blows is what a fight looks like; standing ready while
				-- walking across a field is what made the character look broken.
				if tracks.idle then
					wearStanceBriefly()
				elseif tracks.guard and not tracks.guard.IsPlaying then
					tracks.guard:Play(0.1)
				end
			end)
		else
			-- ท่ายิงไม่มี (สไน: ปืนติดอก ไม่เหวี่ยงอะไร) — ใส่ท่ายืนของอาวุธให้ช่วงยิงแทน ไม่งั้นแขนห้อยปกติ
			if tracks.idle then wearStanceBriefly() end
		end
	end
end)
