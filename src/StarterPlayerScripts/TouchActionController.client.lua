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

if not UserInputService.TouchEnabled and not FORCE_SHOW_IN_STUDIO_FOR_TESTING then return end

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

gui:Show()
gui:AnchorJumpButton()

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
