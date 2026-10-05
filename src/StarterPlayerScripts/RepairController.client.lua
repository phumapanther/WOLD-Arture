-- RepairController: the bar that fills while you are fixing a transformer.
--
-- The repair itself is entirely the server's: it holds the clock, it decides that walking away ends it, and
-- it pops the skill checks. This draws what is happening and nothing else, so a client that lied about any
-- of it would be lying to itself.
--
-- The bar is built here rather than in a UI module because it is five frames and one label, used in exactly
-- one place -- the same call the coordinate readout makes.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

while workspace:GetAttribute("IsLobby") == nil do
	task.wait()
end
if workspace:GetAttribute("IsLobby") then return end

local Responsive = require(game.ReplicatedStorage.UI.Responsive)
local UiSound = require(game.ReplicatedStorage.UI.UiSound)
local Remotes = require(game.ReplicatedStorage.Remotes)
local L = require(game.ReplicatedStorage.Locale).L

local RUNE = Color3.fromRGB(244, 197, 66)
local GOOD = Color3.fromRGB(120, 206, 128)
local BAD = Color3.fromRGB(206, 72, 62)

local gui = Instance.new("ScreenGui")
gui.Name = "RepairGui"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 25 -- above the HUD, below the minigame that interrupts it
gui.Enabled = false
gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

local panel = Instance.new("Frame")
panel.AnchorPoint = Vector2.new(0.5, 1)
panel.Position = UDim2.new(0.5, 0, 1, -140)
panel.Size = UDim2.fromOffset(300, 52)
panel.BackgroundColor3 = Color3.fromRGB(20, 22, 28)
panel.BackgroundTransparency = 0.2
panel.BorderSizePixel = 0
panel.Parent = gui
Responsive.Scale(panel)

local round = Instance.new("UICorner")
round.CornerRadius = UDim.new(0, 10)
round.Parent = panel

local caption = Instance.new("TextLabel")
caption.BackgroundTransparency = 1
caption.Position = UDim2.fromOffset(12, 6)
caption.Size = UDim2.new(1, -24, 0, 18)
caption.Font = Enum.Font.GothamBold
caption.TextSize = 13
caption.TextColor3 = RUNE
caption.TextXAlignment = Enum.TextXAlignment.Left
caption.Text = L("กำลังซ่อมหม้อแปลง")
caption.Parent = panel

local track = Instance.new("Frame")
track.Position = UDim2.fromOffset(12, 28)
track.Size = UDim2.new(1, -24, 0, 12)
track.BackgroundColor3 = Color3.fromRGB(38, 40, 48)
track.BorderSizePixel = 0
track.Parent = panel

local trackRound = Instance.new("UICorner")
trackRound.CornerRadius = UDim.new(1, 0)
trackRound.Parent = track

local fill = Instance.new("Frame")
fill.Size = UDim2.fromScale(0, 1)
fill.BackgroundColor3 = RUNE
fill.BorderSizePixel = 0
fill.Parent = track

local fillRound = Instance.new("UICorner")
fillRound.CornerRadius = UDim.new(1, 0)
fillRound.Parent = fill

--------------------------------------------------------------------------------

local endsAt, seconds, loop, ticker = nil, nil, nil, nil

local function stopLoop()
	if loop then
		loop:Destroy()
		loop = nil
	end
	if ticker then
		ticker:Disconnect()
		ticker = nil
	end
end

local function hideSoon(after)
	local token = os.clock()
	gui:SetAttribute("HideToken", token)
	task.delay(after, function()
		if gui:GetAttribute("HideToken") == token then
			gui.Enabled = false
			caption.TextColor3 = RUNE
			fill.BackgroundColor3 = RUNE
		end
	end)
end

Remotes.RepairStateChanged.OnClientEvent:Connect(function(state, detail)
	if state == "started" then
		seconds = tonumber(detail) or 30
		endsAt = os.clock() + seconds
		caption.Text = L("กำลังซ่อมหม้อแปลง — อย่าขยับ")
		caption.TextColor3 = RUNE
		fill.BackgroundColor3 = RUNE
		fill.Size = UDim2.fromScale(0, 1)
		gui.Enabled = true
		gui:SetAttribute("HideToken", nil)

		stopLoop()
		-- The engine sound also plays at the machine for everyone nearby; this is the worker's own, flat and
		-- close, so the thirty seconds have something under them even with the camera pointed away.
		loop = UiSound.Loop("RepairLoop")
		ticker = RunService.RenderStepped:Connect(function()
			if not endsAt then return end
			local left = math.max(0, endsAt - os.clock())
			fill.Size = UDim2.fromScale(1 - left / seconds, 1)
		end)

	elseif state == "stopped" then
		endsAt = nil
		stopLoop()
		local done = detail == "done"
		caption.Text = done and L("ซ่อมเสร็จแล้ว") or L("การซ่อมหลุด")
		caption.TextColor3 = done and GOOD or BAD
		fill.BackgroundColor3 = done and GOOD or BAD
		if done then fill.Size = UDim2.fromScale(1, 1) end
		-- Left on screen for a beat rather than vanishing on the same frame the repair ended: the player
		-- needs to see WHICH of the two things happened.
		hideSoon(1.2)
	end
end)
