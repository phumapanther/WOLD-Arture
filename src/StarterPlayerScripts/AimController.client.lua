-- AimController: the crosshair, and where a ranged weapon is actually pointed.
--
-- Only appears while a projectile weapon is held. A sword needs no crosshair -- it hits what is in front of
-- the character -- and drawing one for it would suggest an aim that does nothing.
--
-- The aim point is worked out here and sent with the attack, because only the client knows where its own
-- camera is looking. The server still decides everything else: whether the shot is legal, what it hits, and
-- what that costs. A lie about the aim point can only ever miss differently -- it cannot fire faster, spend
-- less mana, or hit someone out of range.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ItemCatalog = require(game.ReplicatedStorage.ItemCatalog)
local CombatConfig = require(game.ReplicatedStorage.CombatConfig)
local Remotes = require(game.ReplicatedStorage.Remotes)

while workspace:GetAttribute("IsLobby") == nil do
	task.wait()
end
if workspace:GetAttribute("IsLobby") then return end

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

-- How far the aim ray reaches before giving up and aiming at empty air.
local AIM_DISTANCE = 500

--------------------------------------------------------------------------------
-- The crosshair
--------------------------------------------------------------------------------

local gui = Instance.new("ScreenGui")
gui.Name = "WOLD_Crosshair"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 5 -- under every panel: this is world furniture, not interface
gui.Enabled = false
gui.Parent = player:WaitForChild("PlayerGui")

-- Drawn from four ticks around a centre dot rather than an uploaded image, for the same reason the touch
-- buttons are: nothing to upload, nothing to go missing.
local function tick(size, position, anchor)
	local f = Instance.new("Frame")
	f.Size = size
	f.Position = position
	f.AnchorPoint = anchor
	f.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	f.BackgroundTransparency = 0.25
	f.BorderSizePixel = 0
	f.Parent = gui
	local s = Instance.new("UIStroke")
	s.Color = Color3.fromRGB(0, 0, 0)
	s.Transparency = 0.55
	s.Thickness = 1
	s.Parent = f
	return f
end

local GAP, LEN, THICK = 8, 7, 2
tick(UDim2.fromOffset(THICK, THICK), UDim2.fromScale(0.5, 0.5), Vector2.new(0.5, 0.5)) -- centre dot
tick(UDim2.fromOffset(THICK, LEN), UDim2.new(0.5, 0, 0.5, -GAP), Vector2.new(0.5, 1)) -- up
tick(UDim2.fromOffset(THICK, LEN), UDim2.new(0.5, 0, 0.5, GAP), Vector2.new(0.5, 0)) -- down
tick(UDim2.fromOffset(LEN, THICK), UDim2.new(0.5, -GAP, 0.5, 0), Vector2.new(1, 0.5)) -- left
tick(UDim2.fromOffset(LEN, THICK), UDim2.new(0.5, GAP, 0.5, 0), Vector2.new(0, 0.5)) -- right

--------------------------------------------------------------------------------
-- Where the weapon is pointed
--------------------------------------------------------------------------------

-- The world point under the middle of the screen. A ray from the camera through the screen centre, out to
-- whatever it hits first -- or a point far away along it, so aiming at open sky still gives a direction.
--
-- The character is excluded, or the ray would stop on the shooter's own back in third person.
local function aimPoint()
	local viewport = camera.ViewportSize
	local ray = camera:ViewportPointToRay(viewport.X / 2, viewport.Y / 2)

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local filter = {}
	if player.Character then table.insert(filter, player.Character) end
	params.FilterDescendantsInstances = filter
	params.IgnoreWater = true

	local result = workspace:Raycast(ray.Origin, ray.Direction * AIM_DISTANCE, params)
	return result and result.Position or (ray.Origin + ray.Direction * AIM_DISTANCE)
end

-- Published so the combat controller can send it with an attack without duplicating any of this.
local AimAccess = require(game.ReplicatedStorage.UI.AimAccess)
AimAccess.Point = aimPoint

--------------------------------------------------------------------------------
-- Showing it only for the weapons that use it
--------------------------------------------------------------------------------

local function usesAim(itemId)
	local item = itemId and ItemCatalog.Get(itemId)
	if not item or item.kind ~= "weapon" then return false end
	local weapon = CombatConfig.Weapons[itemId]
	if not weapon then return false end
	-- A weapon aims if any of its attacks throws something.
	for _, attack in ipairs(weapon.attacks or {}) do
		if attack.projectile then return true end
	end
	return false
end

local function refresh(equipped)
	local weapon = equipped and equipped.weapon
	gui.Enabled = usesAim(weapon and weapon.id)
end

Remotes.InventoryUpdate.OnClientEvent:Connect(function(inventory)
	refresh(inventory and inventory.equipped)
end)

-- The bag may not have been sent yet when this starts.
Remotes.RequestInventoryRefresh:FireServer()

-- Hidden while dead or downed: there is nothing to aim.
Remotes.DownedStateChanged.OnClientEvent:Connect(function(isDowned)
	if isDowned then gui.Enabled = false end
end)
