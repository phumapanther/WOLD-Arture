-- TouchActionController: shows the touch action buttons (attack, and the roll/slide button) on touch devices
-- and wires the attack button to the same RequestAttack path the mouse uses. Presentation + intent only, like
-- every other controller here — the server decides what an attack actually does.
--
-- The roll/slide button is intentionally inert: sub-project 4 implements rolling and sliding. It renders and
-- swaps its label so the layout can be judged now, but pressing it does nothing.
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
