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

--------------------------------------------------------------------------------
-- จอดำระหว่างรอเทเลพอร์ต
--
-- เวลาที่ผู้เล่นรอจริงไม่ได้อยู่ที่แถบ 5 วิ แต่อยู่**หลัง**แถบเต็ม: Roblox ต้องหา (หรือปลุก) เซิร์ฟเวอร์
-- ล็อบบี้ให้ก่อน กินเวลาหลายวินาทีและไม่มีทางรู้ล่วงหน้าว่ากี่วินาที ของเดิมช่วงนี้ยังยืนอยู่ในโลกเหมือนเดิม
-- มีแค่แถบเล็กๆ มุมบน ผู้เล่นจึงอ่านว่า "เกมค้าง" ไม่ใช่ "กำลังโหลด" (ผู้ใช้แจ้ง 2026-09-19)
--
-- ทรงเดียวกับปุ่ม JOIN ในล็อบบี้ที่ผู้ใช้สั่งให้ "ดับหน้าจอทันที" · และจอเดียวกันนี้ถูกส่งต่อไปเป็นหน้าโหลด
-- ของปลายทางด้วย `SetTeleportGui` จอจึงไม่กระพริบกลับมาเป็นเกมกลางทางแล้วค่อยดำอีกรอบ
--
-- **สำเนาที่ส่งให้ SetTeleportGui เป็นภาพนิ่ง** — หน้าโหลดของปลายทางไม่มีสคริปต์รัน จุดไข่ปลาที่ขยับได้จึงมี
-- เฉพาะฝั่งนี้ และต้องลงทะเบียน**ตั้งแต่สคริปต์เริ่ม** ไม่ใช่ตอนกดปุ่ม ไม่งั้นเทเลพอร์ตเริ่มไปก่อนแล้วไม่ทัน
local TeleportService = game:GetService("TeleportService")

local function buildVeil()
	local veil = Instance.new("ScreenGui")
	veil.Name = "LobbyTravelVeil"
	veil.ResetOnSpawn = false
	veil.IgnoreGuiInset = true
	veil.DisplayOrder = 1000 -- เหนือทุกอย่างในเกม (แบนเนอร์อีเวนต์ 30 · เลขพิกัด 999)
	veil.Enabled = false

	local sheet = Instance.new("Frame")
	sheet.Name = "Sheet"
	sheet.Size = UDim2.fromScale(1, 1)
	sheet.BackgroundColor3 = Color3.new(0, 0, 0)
	sheet.BorderSizePixel = 0
	sheet.Parent = veil

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.AnchorPoint = Vector2.new(0.5, 0.5)
	title.Position = UDim2.fromScale(0.5, 0.5)
	title.Size = UDim2.new(1, -40, 0, 30)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBold
	title.TextSize = 20
	title.TextColor3 = RUNE
	title.Text = "กำลังพาไปหน้าล็อบบี้"
	title.Parent = sheet

	local sub = Instance.new("TextLabel")
	sub.AnchorPoint = Vector2.new(0.5, 0)
	sub.Position = UDim2.new(0.5, 0, 0.5, 22)
	sub.Size = UDim2.new(1, -40, 0, 20)
	sub.BackgroundTransparency = 1
	sub.Font = Enum.Font.Gotham
	sub.TextSize = 13
	sub.TextColor3 = Color3.fromRGB(176, 178, 188)
	sub.Text = "กำลังหาเซิร์ฟเวอร์ล็อบบี้ รอสักครู่"
	sub.Parent = sheet

	return veil, title
end

local veil, veilTitle = buildVeil()
veil.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

pcall(function()
	local carry = buildVeil()
	carry.Enabled = true
	TeleportService:SetTeleportGui(carry)
end)

local function veilOn()
	veil.Enabled = true
	task.spawn(function()
		local dots = 0
		while veil.Enabled do
			dots = (dots + 1) % 4
			veilTitle.Text = "กำลังพาไปหน้าล็อบบี้" .. string.rep(".", dots)
			task.wait(0.4)
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
		gui.Enabled = false -- แถบเล็กไม่ต้องแล้ว จอดำพูดแทนทั้งจอ
		gui:SetAttribute("HideToken", nil)
		veilOn()

	elseif state == "stopped" then
		stopTicker()
		-- "failed" มาถึงได้หลังจอดำขึ้นแล้ว (TeleportInitFailed) ต้องคืนจอให้เขาก่อน ไม่งั้นดำค้างทั้งที่ยังอยู่ในเกม
		veil.Enabled = false
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
