-- DownedController: renders the downed state — the darkened screen with its countdown and respawn button, the
-- prone body tilt, and the crawl animation. Presentation only: the server decides who is downed, for how long,
-- and when the countdown ends (it runs its own timer; this one is only what the player reads on screen).
--
-- The prone look is deliberately cosmetic. Physically rotating the character looks right but stops the player
-- moving almost entirely — measured 2.88 studs of travel down to 0.01, because the humanoid's mover can't
-- drive a rig whose orientation is pinned. Instead the humanoid stays upright (so walking works normally) and
-- only the visible body is pitched, by writing LowerTorso.Root.Transform each frame.
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
local VitalsConfig = require(game.ReplicatedStorage.VitalsConfig)
local Remotes = require(game.ReplicatedStorage.Remotes)

local player = Players.LocalPlayer
local gui = DownedGui.new()
gui.gui.Parent = player:WaitForChild("PlayerGui")

local downed = false
local deadline = 0
local proneConnection = nil
local crawlTrack = nil

local function stopProne()
	if proneConnection then
		proneConnection:Disconnect()
		proneConnection = nil
	end
	if crawlTrack then crawlTrack:Stop(0.2) end
	crawlTrack = nil
end

local function startProne()
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local lowerTorso = character and character:FindFirstChild("LowerTorso")
	local rootJoint = lowerTorso and lowerTorso:FindFirstChild("Root")
	if not humanoid or not rootJoint then return end

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
		-- Only the forward stroke is used, always at full speed. The stock "swim idle" is a treading-water pose
		-- — upright, paddling on the spot — which is not what crawling should look like.
		crawlTrack = load(VitalsConfig.CrawlAnimation)
		if crawlTrack then crawlTrack:Play(0.2) end
	end

	-- Stepped is the binding that actually holds the tilt. Measured client-side against the swim animation:
	-- Stepped gives uprightDot 0.01 (prone), while BindToRenderStep past RenderPriority.Character gives 1.00
	-- (still standing) — the opposite of what the ordering docs suggest, so don't "fix" this to RenderStep.
	proneConnection = RunService.Stepped:Connect(function()
		-- NEGATIVE pitch puts the character face-DOWN. Positive lays it on its back (which is what the first
		-- attempt did — the swim stroke then reads as backstroke rather than crawling).
		rootJoint.Transform = rootJoint.Transform * CFrame.Angles(math.rad(-90), 0, 0)

		-- The stroke always runs forward at full speed. An earlier version slowed it to 0.15x when the player
		-- stopped, but a barely-moving swim stroke is exactly what treading water looks like — the thing this
		-- animation was chosen to avoid. Stopping simply means the body stops travelling, not that the arms
		-- start paddling on the spot.
	end)
end

gui:OnRespawnRequested(function()
	if not downed then return end
	Remotes.RequestRespawn:FireServer()
end)

Remotes.DownedStateChanged.OnClientEvent:Connect(function(isDowned, seconds)
	downed = isDowned
	if isDowned then
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
player.CharacterAdded:Connect(function()
	stopProne()
	if downed then
		task.wait(0.3) -- let the rig finish assembling before grabbing its joints
		startProne()
	end
end)

RunService.Heartbeat:Connect(function()
	if not downed then return end
	gui:SetRemaining(deadline - os.clock())
end)
