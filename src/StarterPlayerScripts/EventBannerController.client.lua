-- EventBannerController: shows what the world is doing, and darkens the screen when the lights go out.
--
-- The server sends the WHOLE set of live events every time anything changes, so this never has to work out
-- what started or stopped -- it compares what it was just sent against what it was showing. That also means
-- a player joining mid-event gets the full picture from one request rather than having missed the
-- announcement forever.
local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")

while workspace:GetAttribute("IsLobby") == nil do
	task.wait()
end
if workspace:GetAttribute("IsLobby") then return end

local EventConfig = require(game.ReplicatedStorage.EventConfig)
local EventBannerGui = require(game.ReplicatedStorage.UI.EventBannerGui)
local UiSound = require(game.ReplicatedStorage.UI.UiSound)
local Remotes = require(game.ReplicatedStorage.Remotes)

local gui = EventBannerGui.new()

-- What is on screen right now, so a resend of the same picture does not replay the announcement sound. The
-- server pushes a fresh snapshot on every change, including changes to an event already running (a repaired
-- transformer moves the blackout's count), and each of those would otherwise blare the horn again.
local showing = {}

--------------------------------------------------------------------------------
-- The lights going out
--------------------------------------------------------------------------------

-- A ColorCorrection on the CLIENT, not a change to Lighting on the server: Lighting replicates to everyone
-- including players in the lobby, and it would fight the day/night cycle for the same properties. This sits
-- on top of whatever DayNight has decided and is removed cleanly when the power comes back.
local darkness = Instance.new("ColorCorrectionEffect")
darkness.Name = "WOLD_Blackout"
darkness.Brightness = 0
darkness.Contrast = 0
darkness.Saturation = 0
darkness.Enabled = false
darkness.Parent = Lighting

local darkened = false

local function setBlackout(on)
	if darkened == on then return end
	darkened = on

	darkness.Enabled = true
	local target = on and {
		Brightness = -EventConfig.BlackoutDarkness,
		-- Colour drains with the light, which is what makes it read as a power cut rather than as sunglasses.
		Saturation = -EventConfig.BlackoutDarkness * 0.8,
	} or { Brightness = 0, Saturation = 0 }

	local tween = TweenService:Create(darkness,
		TweenInfo.new(EventConfig.BlackoutFadeSeconds, Enum.EasingStyle.Quad), target)
	tween:Play()
	if not on then
		tween.Completed:Once(function()
			-- Left enabled while it fades, switched off at the end: an enabled effect at zero still costs a
			-- post-processing pass for nothing.
			if not darkened then darkness.Enabled = false end
		end)
	end
end

--------------------------------------------------------------------------------
-- The banners
--------------------------------------------------------------------------------

local function apply(events)
	events = events or {}

	for id, spec in pairs(events) do
		if not showing[id] then
			-- New since the last picture: this is the moment the announcement actually happens.
			local config = EventConfig.Events[id]
			if config and config.sound then UiSound.Play(config.sound) end
		end
	end

	showing = {}
	for id in pairs(events) do showing[id] = true end

	gui:Set(events)
	setBlackout(events.blackout ~= nil)
end

Remotes.EventStateChanged.OnClientEvent:Connect(apply)

-- Asked for on join. The broadcast that started an event may have been fired before this client existed, and
-- an event with no clock on it (the blackout) would otherwise be invisible to a latecomer for as long as it
-- lasts.
task.spawn(function()
	task.wait(1)
	Remotes.RequestEventState:FireServer()
end)

-- The countdown is redrawn locally rather than pushed: the server already said when the event ends, and
-- sending a new string every second to every player is a lot of traffic for a clock they can read themselves.
task.spawn(function()
	while true do
		task.wait(1)
		gui:refresh()
	end
end)
