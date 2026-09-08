-- TouchActionController: shows the touch action buttons (attack, and the roll/slide button) on touch devices
-- and wires the attack button to the same RequestAttack path the mouse uses. Presentation + intent only, like
-- every other controller here — the server decides what an attack actually does.
--
-- The roll/slide button routes through ActionController's BindableEvent, so touch and keyboard share one
-- code path; the server decides whether the press becomes a roll or a slide.
local FORCE_SHOW_IN_STUDIO_FOR_TESTING = false -- ponytail: flip to preview the buttons on a desktop Play session

while workspace:GetAttribute("IsLobby") == nil do
	task.wait()
end
if workspace:GetAttribute("IsLobby") then return end -- lobby has no gameplay controls

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TouchActionGui = require(game.ReplicatedStorage.UI.TouchActionGui)
local Remotes = require(game.ReplicatedStorage.Remotes)

-- Phones and tablets ONLY. TouchEnabled alone is not enough: a touchscreen laptop, a 2-in-1, and Studio's
-- device emulator all report it true while still having a keyboard and mouse, and those players use Ctrl and
-- left-click. A real phone or tablet has touch and NO keyboard, so require that combination.
local function isTouchOnlyDevice()
	return UserInputService.TouchEnabled
		and not UserInputService.KeyboardEnabled
		and not UserInputService.MouseEnabled
end

if not isTouchOnlyDevice() and not FORCE_SHOW_IN_STUDIO_FOR_TESTING then return end

local player = Players.LocalPlayer
local gui = TouchActionGui.new()
gui.gui.Parent = player:WaitForChild("PlayerGui")

gui:OnAttack(function()
	Remotes.RequestAttack:FireServer()
end)

-- The roll/slide button drives the same path as the Ctrl key, through ActionController's BindableEvent, so
-- the two input routes cannot drift apart. It resolves to a slide while sprinting and a roll otherwise.
gui:OnRoll(function()
	local bindable = player:FindFirstChild("PlayerGui")
	bindable = bindable and bindable:FindFirstChild("WOLD_RequestAction")
	if bindable then bindable:Fire() end
end)

-- Dropping a carried player is bound to F on desktop, which touch cannot press. This button drives the same
-- remote. Carry state comes straight from the server event, so it matches RescueController without either
-- script having to reach into the other.
gui:OnDrop(function()
	Remotes.RequestDrop:FireServer()
end)

Remotes.CarryStateChanged.OnClientEvent:Connect(function(actor, event)
	if actor ~= player then return end
	if event == "carry_start" then
		gui:SetCarrying(true)
	elseif event == "carry_end" then
		gui:SetCarrying(false)
	end
end)

gui:Show()
gui:AnchorJumpButton()

-- A tablet can gain a keyboard mid-session (a docked iPad, a Surface folded around), which turns it into a
-- device that should be using Ctrl and left-click instead. Follow that rather than deciding once at startup.
local function refreshVisibility()
	if isTouchOnlyDevice() then
		gui:Show()
		gui:AnchorJumpButton()
	else
		gui:Hide()
	end
end
UserInputService:GetPropertyChangedSignal("KeyboardEnabled"):Connect(refreshVisibility)
UserInputService:GetPropertyChangedSignal("MouseEnabled"):Connect(refreshVisibility)
UserInputService:GetPropertyChangedSignal("TouchEnabled"):Connect(refreshVisibility)

-- Roblox rebuilds its touch controls with the character, so the jump button has to be re-positioned each time.
player.CharacterAdded:Connect(function()
	gui:AnchorJumpButton()
end)

-- Swap ROLL -> SLIDE while sprinting. Sprinting isn't replicated to the client as a flag, but WalkSpeed is,
-- and the run speed (16) is unambiguous against normal (8) and walk (4).
local RUN_SPEED_THRESHOLD = 12
local sprinting = false
RunService.Heartbeat:Connect(function()
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local now = humanoid ~= nil and humanoid.WalkSpeed >= RUN_SPEED_THRESHOLD
	if now ~= sprinting then
		sprinting = now
		gui:SetSprinting(sprinting)
	end
end)
