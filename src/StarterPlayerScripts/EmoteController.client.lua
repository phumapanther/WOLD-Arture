-- EmoteController: plays the roleplay poses, and knows when to stop.
--
-- The animation runs HERE, on the player's own Animator, because that is the one thing a client is already
-- the authority on: Roblox replicates a track played on your own character to everyone else by itself, with
-- no remote and no round trip. What the client cannot decide is being held still -- PlayerMovement writes
-- WalkSpeed from the server every tick -- so a pose that locks asks the server for the lock and the server
-- grants it (PlayerEmotes.server.lua).
--
-- Published because three things start an emote and they must not each grow their own copy of this: the
-- picker on the speaking stone, the admin's /anim command, and later a hotkey. EmoteAccess is how they reach
-- it without requiring a client script from another client script.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

while workspace:GetAttribute("IsLobby") == nil do
	task.wait()
end
if workspace:GetAttribute("IsLobby") then return end

local EmoteConfig = require(game.ReplicatedStorage.EmoteConfig)
local EmoteAccess = require(game.ReplicatedStorage.UI.EmoteAccess)
local Remotes = require(game.ReplicatedStorage.Remotes)

local player = Players.LocalPlayer

local current = nil   -- { entry, track }
local watching = nil  -- the "did they walk away" connection

local function humanoidOf()
	local character = player.Character
	return character and character:FindFirstChildOfClass("Humanoid")
end

-- Ends whatever is running and hands the body back. Safe to call when nothing is running, which is what lets
-- every exit -- walking, a second emote, a respawn, the stop button -- go through this one door.
local function stop(fade)
	if watching then
		watching:Disconnect()
		watching = nil
	end
	if not current then return end
	local entry, track = current.entry, current.track
	current = nil
	if track and track.IsPlaying then track:Stop(fade or 0.25) end
	if entry.locks then
		Remotes.RequestEmotePose:FireServer(false)
	end
end

-- Moving cancels a pose. Measured off the humanoid's own speed rather than off keypresses, so being shoved,
-- carried or slid down a hill ends it too -- all of which mean "you are not posing any more" just as much as
-- pressing W does.
--
-- Only for poses that neither lock NOR keep. A locked pose has WalkSpeed 0 so it could never trip this, and
-- a kept pose is one the player is meant to walk around in -- ending it on the first step is exactly the
-- behaviour the user asked to be rid of.
-- A `keep` pose rides along while the player walks, and ends once they have walked far enough. Distance is
-- accumulated frame by frame rather than measured from the starting point, so pacing back and forth spends
-- the budget exactly as walking in a straight line does.
--
-- Horizontal only: falling down a cliff in a sitting pose should not be what ends it, and a lift or a
-- vehicle carrying the player is not the player walking.
local function watchDistance()
	local limit = EmoteConfig.KeepDistance or 10
	local travelled = 0
	local last = nil
	watching = RunService.Heartbeat:Connect(function()
		if not current then return end
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if not root then return stop(0) end
		local here = Vector3.new(root.Position.X, 0, root.Position.Z)
		if last then
			travelled += (here - last).Magnitude
			if travelled >= limit then return stop(0.3) end
		end
		last = here
	end)
end

local function watchForMovement()
	local humanoid = humanoidOf()
	if not humanoid then return end
	watching = RunService.Heartbeat:Connect(function()
		if not current then return end
		local h = humanoidOf()
		if not h then return stop(0) end
		if h.MoveDirection.Magnitude > 0.1 and h.WalkSpeed > 0 then stop(0.2) end
	end)
end

function EmoteAccess.Play(id)
	local entry = EmoteConfig.Get(id)
	if not entry then return false, "ไม่มีท่าชื่อนี้" end
	if entry.anim == "" then return false, ("ท่า %s ยังไม่ได้อัปโหลด"):format(entry.label) end

	local humanoid = humanoidOf()
	local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
	if not animator then return false, "ตัวละครยังไม่พร้อม" end

	-- Asking for the pose you are already in means standing up. The button that started it is the button that
	-- ends it, which is what people reach for first.
	--
	-- Only while the track is REALLY still playing, though. Anything else may have stopped it -- a respawn
	-- landing mid-frame, another system reaching for the Animator -- and then this table is describing a pose
	-- that has already gone. Without the check, the next press of that emote is read as "stand up" and does
	-- nothing at all, and the player has to press a second time to get the pose they asked for.
	if current and current.entry.id == id and current.track and current.track.IsPlaying then
		stop()
		return true, ("เลิก%s"):format(entry.label)
	end
	stop(0.15)

	local anim = Instance.new("Animation")
	anim.AnimationId = entry.anim
	local ok, track = pcall(function() return animator:LoadAnimation(anim) end)
	if not ok or not track then return false, "โหลดท่าไม่สำเร็จ" end

	-- Action4 so a pose sits above the walk and idle the default Animate script is running, but below
	-- nothing this game plays: the crawl, the carry and the knockdown all have to win over an emote, and
	-- they do, because being put on the floor is not something a pose should be able to argue with.
	track.Priority = Enum.AnimationPriority.Action4
	track.Looped = entry.loop and true or false
	track:Play(0.2)
	current = { entry = entry, track = track }

	if entry.locks then
		Remotes.RequestEmotePose:FireServer(true)
	elseif entry.keep then
		-- `keep` means the player walks freely AND the pose stays on -- but only for a while. See
		-- watchDistance: a sit with no limit is a sit nobody remembers pressing.
		watchDistance()
	else
		watchForMovement()
	end

	-- A one-shot lets go of the body by itself when it finishes. A loop waits to be cancelled, which is the
	-- whole difference between "wave at someone" and "sit down for a while".
	if not entry.loop then
		track.Stopped:Once(function()
			if current and current.track == track then stop(0) end
		end)
	end

	return true, entry.label
end

function EmoteAccess.Stop()
	stop()
end

function EmoteAccess.Current()
	return current and current.entry.id or nil
end

-- The admin command's leg. The server cannot play an emote ON someone -- a track it starts is fighting the
-- client for the same rig, which the crawl and the carry both lost -- so it asks, and this answers.
--
-- Nothing is checked here: the only thing that reaches this remote is the server, and it already decided the
-- sender was an admin before firing it.
Remotes.PlayEmote.OnClientEvent:Connect(function(id)
	EmoteAccess.Play(id)
end)

-- A respawn destroys the rig the track was loaded on. Cleared rather than restarted: coming back from the
-- dead sitting cross-legged would be a surprise, and the server has already released the lock.
player.CharacterAdded:Connect(function()
	if watching then watching:Disconnect() watching = nil end
	current = nil
end)
