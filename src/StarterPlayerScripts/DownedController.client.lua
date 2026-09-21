-- DownedController: renders the downed state — the darkened screen with its countdown and respawn button, the
-- prone body tilt, and the crawl animation. Presentation only: the server decides who is downed, for how long,
-- and when the countdown ends (it runs its own timer; this one is only what the player reads on screen).
--
-- The prone tilt is NOT done here any more. Writing LowerTorso.Root.Transform from this client only tilted the
-- body locally, so everyone else saw the crawler standing upright. Vitals.lua now lays the body down
-- server-side by swapping in a Motor6D it owns; this file is left with the screen and the animation.
--
-- See docs/superpowers/specs/2026-09-07-vitals-downed-design.md.
local FORCE_SHOW_IN_STUDIO_FOR_TESTING = false -- ponytail: flip to preview this screen in Play; flip back before publishing

while workspace:GetAttribute("IsLobby") == nil do
	task.wait()
end
if workspace:GetAttribute("IsLobby") and not FORCE_SHOW_IN_STUDIO_FOR_TESTING then return end

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local DownedGui = require(game.ReplicatedStorage.UI.DownedGui)
local UiSound = require(game.ReplicatedStorage.UI.UiSound)
local VitalsConfig = require(game.ReplicatedStorage.VitalsConfig)
local Remotes = require(game.ReplicatedStorage.Remotes)

local player = Players.LocalPlayer
local gui = DownedGui.new()
gui.gui.Parent = player:WaitForChild("PlayerGui")

local downed = false
local deadline = 0
local proneConnection = nil
local crawlTrack = nil

-- นับรอบของการเข้าท่าคลาน — ทุกครั้งที่สั่งหยุด เลขนี้เดินหน้า งานที่ค้างอยู่ระหว่าง `task.wait` จึงรู้ว่า
-- ตัวเองถูกยกเลิกไปแล้วและต้องไม่เล่นท่าต่อ
--
-- **นี่คือต้นเหตุของ "เกิดใหม่แล้วค้างท่าว่ายน้ำยืนตั้ง"** (ผู้ใช้แจ้ง 2026-09-20): `CharacterAdded` รอ 0.3 วิ
-- ให้ร่างประกอบเสร็จก่อนเริ่มท่า ถ้าข่าว "ไม่ได้ล้มแล้ว" มาถึงระหว่างรอ การหยุดจะเกิดก่อนการเริ่ม
-- แล้วท่าว่ายน้ำก็ถูกเปิดบนร่างใหม่ที่ยืนอยู่ดีๆ โดยไม่มีอะไรมาปิดมันอีกเลย
local generation = 0

local function stopProne()
	generation += 1
	if proneConnection then
		proneConnection:Disconnect()
		proneConnection = nil
	end
	if crawlTrack then crawlTrack:Stop(0.2) end
	crawlTrack = nil

	-- กวาดท่าคลานที่อาจค้างอยู่บนร่างปัจจุบันด้วย (คนละร่างกับตอนที่เราเปิดไว้ก็ได้ เช่นร่างเพิ่งถูกสร้างใหม่)
	-- `crawlTrack` ชี้ไปที่ Animator ของร่างเก่าเสมอ การหยุดมันจึงไม่ช่วยอะไรกับร่างที่ผู้เล่นกำลังใช้อยู่
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
	if animator then
		for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
			if track.Animation and track.Animation.AnimationId == VitalsConfig.CrawlAnimation then
				track:Stop(0)
			end
		end
	end
end

local function startProne()
	if not downed then return end -- กันการเปิดท่าคลานทับร่างที่ลุกขึ้นแล้ว
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end

	-- Stock swim animations reused as the crawl: the stroke is exactly the face-down paddling motion, and it
	-- only drives the arms, which is why the body tilt has to be applied separately below.
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if animator then
		local function load(id)
			local anim = Instance.new("Animation")
			anim.AnimationId = id
			local ok, track = pcall(function() return animator:LoadAnimation(anim) end)
			if not ok then return nil end
			track.Priority = Enum.AnimationPriority.Action
			track.Looped = true
			return track
		end
		-- Only the forward stroke is used. The stock "swim idle" is a treading-water pose — upright, paddling on
		-- the spot — which is not what crawling should look like.
		crawlTrack = load(VitalsConfig.CrawlAnimation)
		if crawlTrack then
			crawlTrack:Play(0.2)
			crawlTrack:AdjustSpeed(0) -- start held still; the loop below starts it once the player moves
		end
	end

	-- Stroke while dragging forward, hold completely still when stopped. Speed 0 PAUSES the track on its
	-- current frame rather than slowing it: a slow stroke still reads as treading water, which is exactly the
	-- look this animation was chosen to avoid, while a frozen one reads as lying there spent.
	proneConnection = RunService.Heartbeat:Connect(function()
		if not crawlTrack then return end
		local moving = humanoid.MoveDirection.Magnitude > 0.1
		crawlTrack:AdjustSpeed(moving and 1 or 0)
	end)
end

gui:OnRespawnRequested(function()
	if not downed then return end
	UiSound.Play("Respawn")
	Remotes.RequestRespawn:FireServer()
end)

Remotes.DownedStateChanged.OnClientEvent:Connect(function(isDowned, seconds)
	downed = isDowned
	if isDowned then
		-- The blow that put you down. Played here rather than broadcast from the server on purpose: this
		-- event only reaches the person it happened to, which is exactly who should hear it.
		UiSound.Play("LastHit")
		deadline = os.clock() + (seconds or VitalsConfig.DownedSeconds)
		gui:SetRemaining(seconds or VitalsConfig.DownedSeconds)
		gui:Show()
		startProne()
	else
		stopProne()
		gui:Hide()
	end
end)

-- The character is rebuilt on respawn, so the prone hooks must be re-established (or dropped) accordingly.
player.CharacterAdded:Connect(function(character)
	stopProne()
	if not downed then return end
	local mine = generation
	task.wait(0.3) -- let the rig finish assembling before grabbing its joints
	-- ถามใหม่หลังรอ: ระหว่าง 0.3 วินาทีนั้นอาจมีข่าวว่าไม่ได้ล้มแล้ว หรือร่างถูกสร้างใหม่อีกรอบ
	if mine ~= generation or not downed or player.Character ~= character then return end
	startProne()
end)

RunService.Heartbeat:Connect(function()
	if not downed then return end
	gui:SetRemaining(deadline - os.clock())
end)
