-- TouchActionGui: the on-screen action buttons for touch devices — attack, and a roll button that becomes a
-- slide button while sprinting. Pure UI builder; the controller wires up what the presses do.
--
-- Layout, per the user's spec: the attack button sits to the RIGHT of Roblox's own jump button and is twice
-- its size; the jump button is nudged right to make room; the roll/slide button sits ABOVE the attack button
-- at the jump button's size.
--
-- The roll/slide button relabels itself to SLIDE while sprinting; both it and the Ctrl key resolve to the
-- same action, decided server-side from the player's current speed.
local Players = game:GetService("Players")
local Responsive = require(script.Parent.Responsive)

local TouchActionGui = {}
TouchActionGui.__index = TouchActionGui

-- Roblox's own jump button is 90x90 at its smallest and sits a fixed distance from the bottom-right corner.
-- These are matched to it so the cluster reads as one set of controls rather than a separate overlay.
local JUMP_SIZE = 90
-- Both buttons were halved on request: the attack button is still twice the roll button, just a smaller pair
-- overall, so the cluster covers less of a phone screen.
local ATTACK_SIZE = JUMP_SIZE -- was JUMP_SIZE * 2
local ROLL_SIZE = JUMP_SIZE / 2 -- was JUMP_SIZE
local EDGE_MARGIN = 30
local GAP = 14

-- Black glass, exactly the lobby panel's colour and transparency (Responsive.Glass*), so the buttons look
-- like the same material as the rest of the UI rather than a separate grey overlay. No greys and no hues:
-- the two actions are told apart by size, position and glyph.
local ATTACK_COLOR = Responsive.GlassColor
local ROLL_COLOR = Responsive.GlassColor
local SLIDE_COLOR = Responsive.GlassColor
local BUTTON_TRANSPARENCY = Responsive.GlassTransparency
local TEXT_LIGHT = Color3.fromRGB(232, 232, 236)
local RIM = Color3.fromRGB(120, 122, 132)

local function circle(parent, size, color, glyph, glyphSize)
	local btn = Instance.new("ImageButton")
	btn.Size = UDim2.fromOffset(size, size)
	btn.BackgroundColor3 = color
	btn.BackgroundTransparency = BUTTON_TRANSPARENCY
	btn.AutoButtonColor = true
	btn.Image = ""
	btn.Parent = parent

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = btn

	-- No sheen gradient: any lift toward white would stop the fill from matching the lobby panel exactly,
	-- which is the whole point of sharing Responsive.Glass*. The rim alone gives the button its edge.

	local stroke = Instance.new("UIStroke")
	stroke.Name = "Rim"
	stroke.Color = RIM
	stroke.Transparency = 0.45
	stroke.Thickness = 1.5
	stroke.Parent = btn

	local label = Instance.new("TextLabel")
	label.Name = "Glyph"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamMedium
	label.TextSize = glyphSize
	label.TextColor3 = TEXT_LIGHT
	label.Text = glyph
	label.Parent = btn

	return btn, label
end

function TouchActionGui.new()
	local self = setmetatable({}, TouchActionGui)

	local gui = Instance.new("ScreenGui")
	gui.Name = "TouchActionGui"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 5 -- under the downed overlay (20), above the world
	gui.Enabled = false
	self.gui = gui

	-- Anchored to the bottom-right corner so it lands next to the jump button at any screen size.
	local cluster = Instance.new("Frame")
	cluster.Name = "Cluster"
	cluster.AnchorPoint = Vector2.new(1, 1)
	cluster.Position = UDim2.new(1, -EDGE_MARGIN, 1, -EDGE_MARGIN)
	cluster.Size = UDim2.fromOffset(ATTACK_SIZE, ATTACK_SIZE + GAP + ROLL_SIZE)
	cluster.BackgroundTransparency = 1
	cluster.Parent = gui
	self.cluster = cluster

	-- Attack: bottom of the cluster, the big one.
	local attack = circle(cluster, ATTACK_SIZE, ATTACK_COLOR, "\226\154\148", 54) -- crossed swords (⚔)
	attack.Name = "AttackButton"
	attack.AnchorPoint = Vector2.new(1, 1)
	attack.Position = UDim2.new(1, 0, 1, 0)
	self.attackButton = attack

	-- Roll/slide: directly above the attack button, jump-button sized. Right-aligned with it.
	local roll, rollLabel = circle(cluster, ROLL_SIZE, ROLL_COLOR, "ROLL", 20)
	roll.Name = "RollButton"
	roll.AnchorPoint = Vector2.new(1, 1)
	roll.Position = UDim2.new(1, 0, 1, -(ATTACK_SIZE + GAP))
	self.rollButton = roll
	self.rollLabel = rollLabel

	return self
end

-- Nudges Roblox's own jump button left of our attack button, and matches its vertical centre. The jump button
-- is a CoreGui-owned instance that only exists once touch controls are built, so this retries until it shows
-- up and then keeps the offset applied across respawns.
function TouchActionGui:AnchorJumpButton()
	local player = Players.LocalPlayer
	task.spawn(function()
		local playerGui = player:FindFirstChildOfClass("PlayerGui")
		if not playerGui then return end
		local deadline = os.clock() + 20
		while os.clock() < deadline do
			local touchGui = playerGui:FindFirstChild("TouchGui")
			local frame = touchGui and touchGui:FindFirstChild("TouchControlFrame")
			local jump = frame and frame:FindFirstChild("JumpButton")
			if jump then
				-- Sit the jump button just left of the attack button, sharing its centre line ("ทำให้ปุ่ม
				-- กระโดดขยับมาด้านขวาเล็กน้อย" — it moves right relative to its old spot, since the attack
				-- button now occupies the corner).
				jump.AnchorPoint = Vector2.new(1, 1)
				jump.Position = UDim2.new(1, -(EDGE_MARGIN + ATTACK_SIZE + GAP), 1,
					-(EDGE_MARGIN + (ATTACK_SIZE - JUMP_SIZE) / 2))
				return
			end
			task.wait(0.5)
		end
	end)
end

function TouchActionGui:OnAttack(callback)
	self.attackButton.MouseButton1Down:Connect(callback)
end

function TouchActionGui:OnRoll(callback)
	self.rollButton.MouseButton1Down:Connect(callback)
end

-- Roll becomes Slide while the player is sprinting. Presses are not wired to anything yet.
-- Every button now shares one black, so the state change shows in the rim and label rather than the fill.
function TouchActionGui:SetSprinting(sprinting)
	self.rollLabel.Text = sprinting and "SLIDE" or "ROLL"
	local rim = self.rollButton:FindFirstChild("Rim")
	if rim then rim.Transparency = sprinting and 0.1 or 0.45 end
end

function TouchActionGui:Show()
	self.gui.Enabled = true
end

function TouchActionGui:Hide()
	self.gui.Enabled = false
end

return TouchActionGui
