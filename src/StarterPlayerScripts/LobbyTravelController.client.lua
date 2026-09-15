-- LobbyTravelController: the bar that fills while you are on your way back to the lobby.
--
-- Same shape as RepairController, and for the same reason: the server holds the clock and decides what stops
-- the trip, and this draws what it is told. A client that lied about any of it would be lying to itself.
--
-- The bar exists because the wait was invisible. Pressing "back to lobby" saved and teleported, and Roblox
-- takes a few seconds to find or build a lobby server -- seconds in which the game looked untouched, so the
-- button read as broken. Two phases now: a countdown that something can interrupt, and then the teleport
-- itself, which nothing can.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

while workspace:GetAttribute("IsLobby") == nil do
	task.wait()
end
if workspace:GetAttribute("IsLobby") then return end

local Responsive = require(game.ReplicatedStorage.UI.Responsive)
local Remotes = require(game.ReplicatedStorage.Remotes)

local RUNE = Color3.fromRGB(244, 197, 66)
local GOOD = Color3.fromRGB(120, 206, 128)
local BAD = Color3.fromRGB(206, 72, 62)

-- Why a trip ended, in the words the player would use. Anything unlisted falls back to the generic line,
-- so a reason added on the server later is merely vague here rather than blank.
local REASONS = {
	hit = "ยกเลิก — โดนโจมตีระหว่างรอ",
	downed = "ยกเลิก — คุณล้มลงแล้ว",
	failed = "ไปล็อบบี้ไม่สำเร็จ ลองใหม่อีกครั้ง",
}

local gui = Instance.new("ScreenGui")
gui.Name = "LobbyTravelGui"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 26 -- above the repair bar: leaving outranks anything you were doing
gui.Enabled = false
gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

local panel = Instance.new("Frame")
panel.AnchorPoint = Vector2.new(0.5, 0)
panel.Position = UDim2.new(0.5, 0, 0, 96) -- top of the screen: the event banner's half, not the HUD's
panel.Size = UDim2.fromOffset(320, 58)
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
caption.Text = "กำลังกลับหน้าล็อบบี้"
caption.Parent = panel

local hint = Instance.new("TextLabel")
hint.BackgroundTransparency = 1
hint.Position = UDim2.fromOffset(12, 22)
hint.Size = UDim2.new(1, -24, 0, 14)
hint.Font = Enum.Font.Gotham
hint.TextSize = 11
hint.TextColor3 = Color3.fromRGB(176, 178, 188)
hint.TextXAlignment = Enum.TextXAlignment.Left
hint.Text = "ถ้าโดนตีหรือล้มระหว่างนี้ จะยกเลิก"
hint.Parent = panel

local track = Instance.new("Frame")
track.Position = UDim2.fromOffset(12, 40)
track.Size = UDim2.new(1, -24, 0, 10)
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

local ticker = nil

local function stopTicker()
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
		end
	end)
end

Remotes.LobbyTravelChanged.OnClientEvent:Connect(function(state, detail)
	if state == "started" then
		local seconds = tonumber(detail) or 5
		local endsAt = os.clock() + seconds
		caption.Text = "กำลังกลับหน้าล็อบบี้"
		caption.TextColor3 = RUNE
		hint.Text = "ถ้าโดนตีหรือล้มระหว่างนี้ จะยกเลิก"
		hint.Visible = true
		fill.BackgroundColor3 = RUNE
		fill.Size = UDim2.fromScale(0, 1)
		gui.Enabled = true
		gui:SetAttribute("HideToken", nil)

		stopTicker()
		ticker = RunService.RenderStepped:Connect(function()
			local left = math.max(0, endsAt - os.clock())
			fill.Size = UDim2.fromScale(1 - left / seconds, 1)
		end)

	elseif state == "leaving" then
		-- The teleport is running. There is no clock left to draw -- Roblox does not say how long it will
		-- take -- so the bar sits full and the words change instead. Anything that pretended to measure this
		-- would be inventing a number.
		stopTicker()
		caption.Text = "กำลังพาไปหน้าล็อบบี้..."
		caption.TextColor3 = GOOD
		hint.Visible = false
		fill.BackgroundColor3 = GOOD
		fill.Size = UDim2.fromScale(1, 1)
		gui.Enabled = true
		gui:SetAttribute("HideToken", nil)

	elseif state == "stopped" then
		stopTicker()
		caption.Text = REASONS[detail] or "ยกเลิกการกลับหน้าล็อบบี้"
		caption.TextColor3 = BAD
		hint.Visible = false
		fill.BackgroundColor3 = BAD
		gui.Enabled = true
		-- Left up for a moment rather than vanishing on the same frame it stopped: the player pressed a
		-- button and needs to see WHY nothing happened, or they will simply press it again.
		hideSoon(2.5)
	end
end)
