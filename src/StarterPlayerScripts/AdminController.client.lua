-- AdminController.client.lua: the admin's command box and its output log.
--
-- Chat is switched off in channel servers (HudController disables the CoreGui chat), so there is nowhere to
-- type a command or read a reply. This gives the admin a small console instead: F2 toggles it, Enter sends,
-- and replies from the server print above the input.
--
-- The console is NOT the security boundary -- the server decides who is an admin and ignores everyone else.
-- This only avoids drawing a box for players whose commands would be refused anyway, and a non-admin who
-- forces it open just types into the void.
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
local Remotes = require(game.ReplicatedStorage.Remotes)
local CommandCatalog = require(game.ReplicatedStorage.CommandCatalog)


local player = Players.LocalPlayer

-- Whether to draw the box at all. The server publishes this as an Attribute (AdminRoster), rather than this
-- file keeping a second copy of the allow-list -- which is what it used to do, and which stopped being
-- possible the day admin could be granted in-game.
--
-- Being wrong here grants nothing: the server re-checks the roster on every command, so a client that sets
-- the attribute on itself has drawn a box whose commands will be ignored.
local function isAdmin()
	return player:GetAttribute("WOLD_Admin") == true
end

while workspace:GetAttribute("IsLobby") == nil do
	task.wait()
end
-- ล็อบบี้ก็มีคอนโซลแล้ว (ผู้ใช้สั่ง 2026-09-26) — คำสั่งชุดที่ใช้ได้ในล็อบบี้ตัดสินที่ AdminCommands (LOBBY_OK)
local LOBBY = workspace:GetAttribute("IsLobby") == true

-- The box is drawn for anyone who has SOMETHING to type: an admin, or a player holding an advanced class,
-- which is what grants /announce. Everyone else never sees it, and F2 does nothing for them.
--
-- This is a convenience, not a permission. The server re-checks who may run what on every command, so being
-- wrong here grants nothing -- it only decides whether a box appears.
local function hasCommands()
	if isAdmin() then return true end
	return player:GetAttribute("WOLD_ClassAdvanced") ~= nil
		or player:GetAttribute("WOLD_ClassElite") ~= nil
end

--------------------------------------------------------------------------------
-- UI
--------------------------------------------------------------------------------

local BG = Color3.fromRGB(14, 13, 18)
local ACCENT = Color3.fromRGB(216, 172, 84)
local TEXT = Color3.fromRGB(240, 240, 245)

local gui = Instance.new("ScreenGui")
gui.Name = "AdminConsole"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 50
gui.Enabled = false
gui.Parent = player:WaitForChild("PlayerGui")

local panel = Instance.new("Frame")
panel.AnchorPoint = Vector2.new(0.5, 1)
panel.Position = UDim2.new(0.5, 0, 1, -90)
panel.Size = UDim2.new(0, 560, 0, 220)
panel.BackgroundColor3 = BG
panel.BackgroundTransparency = 0.15
panel.BorderSizePixel = 0
panel.Parent = gui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 10)
corner.Parent = panel

local stroke = Instance.new("UIStroke")
stroke.Color = ACCENT
stroke.Transparency = 0.55
stroke.Thickness = 1.5
stroke.Parent = panel

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -20, 0, 22)
title.Position = UDim2.new(0, 12, 0, 8)
title.BackgroundTransparency = 1
title.Font = Enum.Font.GothamBold
title.TextSize = 13
title.TextColor3 = ACCENT
title.TextXAlignment = Enum.TextXAlignment.Left
title.Text = "แอดมิน — F2 หรือ Esc ปิด · ลูกศรขึ้นลง = คำสั่งก่อนหน้า · พิมพ์ / เพื่อเลือกคำสั่ง"
title.Parent = panel

-- The log. Newest at the bottom, like a terminal.
local log = Instance.new("ScrollingFrame")
log.Position = UDim2.new(0, 12, 0, 34)
log.Size = UDim2.new(1, -24, 1, -84)
log.BackgroundTransparency = 1
log.BorderSizePixel = 0
log.ScrollBarThickness = 4
log.ScrollingDirection = Enum.ScrollingDirection.Y
log.AutomaticCanvasSize = Enum.AutomaticSize.Y
log.CanvasSize = UDim2.new()
log.Parent = panel

local layout = Instance.new("UIListLayout")
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Padding = UDim.new(0, 2)
layout.Parent = log

local box = Instance.new("TextBox")
box.AnchorPoint = Vector2.new(0, 1)
box.Position = UDim2.new(0, 12, 1, -12)
box.Size = UDim2.new(1, -24, 0, 32)
box.BackgroundColor3 = Color3.fromRGB(26, 25, 32)
box.BackgroundTransparency = 0.2
box.BorderSizePixel = 0
box.Font = Enum.Font.Code
box.TextSize = 14
box.TextColor3 = TEXT
-- The two event commands sit in the hint because they are the ones an admin reaches for and cannot guess:
-- everything else in here is named after the noun it acts on, while "make the lights go out" is not.
box.PlaceholderText = "/give Sword 1   /gold 1000   /blackout   /slime"
box.ClearTextOnFocus = false
box.Text = ""
box.Parent = panel

local boxCorner = Instance.new("UICorner")
boxCorner.CornerRadius = UDim.new(0, 6)
boxCorner.Parent = box

local lines = 0
local function append(text, color)
	for piece in tostring(text):gmatch("[^\n]+") do
		lines += 1
		local label = Instance.new("TextLabel")
		label.LayoutOrder = lines
		label.Size = UDim2.new(1, 0, 0, 16)
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.Code
		label.TextSize = 13
		label.TextColor3 = color or TEXT
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.TextTruncate = Enum.TextTruncate.AtEnd
		label.Text = piece
		label.Parent = log
	end
	-- Keep the newest line in view.
	task.defer(function()
		log.CanvasPosition = Vector2.new(0, math.max(0, log.AbsoluteCanvasSize.Y - log.AbsoluteWindowSize.Y))
	end)
end

--------------------------------------------------------------------------------
-- Remembering what was typed
--------------------------------------------------------------------------------

-- Every command sent this session, oldest first. Up walks back through it, Down walks forward -- the shell
-- behaviour, because anyone who has typed a command twice already expects it.
--
-- `cursor` is where in that list the box currently sits. #history + 1 means "the empty line past the end",
-- which is where Down returns you and where typing anything puts you back.
local history = {}
local cursor = 1
local draft = "" -- what was half-typed before Up stole the box, given back on the way down

--------------------------------------------------------------------------------
-- The suggestion list
--------------------------------------------------------------------------------

-- Drawn above the box and filtered as the command is typed. A convenience only: the names come from
-- CommandCatalog, which is a list of words, and the server still decides on every line whether this player
-- may run the one they picked.
local SUGGEST_MAX = 6

local suggest = Instance.new("Frame")
suggest.AnchorPoint = Vector2.new(0, 1)
suggest.Position = UDim2.new(0, 12, 1, -48)
suggest.Size = UDim2.new(1, -24, 0, 0)
suggest.AutomaticSize = Enum.AutomaticSize.Y
suggest.BackgroundColor3 = Color3.fromRGB(22, 21, 28)
suggest.BorderSizePixel = 0
suggest.Visible = false
suggest.ZIndex = 5
suggest.Parent = panel

local suggestCorner = Instance.new("UICorner")
suggestCorner.CornerRadius = UDim.new(0, 6)
suggestCorner.Parent = suggest

local suggestStroke = Instance.new("UIStroke")
suggestStroke.Color = ACCENT
suggestStroke.Transparency = 0.65
suggestStroke.Parent = suggest

local suggestLayout = Instance.new("UIListLayout")
suggestLayout.SortOrder = Enum.SortOrder.LayoutOrder
suggestLayout.Parent = suggest

local matches = {} -- the catalogue entries currently shown
local picked = 1   -- which of them is highlighted
local rows = {}    -- the labels, reused rather than rebuilt on every keystroke

-- Which commands this player is even shown. Being wrong here grants nothing -- see the note on ADMINS --
-- but offering a guard the whole admin list would be offering things that will silently do nothing.
local function scopes()
	if isAdmin() then return { admin = true, noble = true, class = true } end
	return {
		noble = (player:GetAttribute("WOLD_ClassBasic") == "Noble"
			or player:GetAttribute("WOLD_ClassAdvanced") == "Noble") or nil,
		class = true,
	}
end

local function paint()
	for index, row in ipairs(rows) do
		row.BackgroundTransparency = index == picked and 0.4 or 1
		row.TextColor3 = index == picked and ACCENT or TEXT
	end
end

local function hideSuggestions()
	suggest.Visible = false
	matches = {}
	picked = 1
end

-- Rebuilds the list for whatever is in the box. Called on every keystroke, so the labels are reused and only
-- their text changes: destroying and recreating six TextLabels per character typed is visible flicker.
local function refreshSuggestions()
	-- Only while the line is still just a command name. Once there is a space the player has moved on to the
	-- arguments, and a list of commands sitting over the box is then only in the way.
	local word = box.Text:match("^/([%w_]*)$")
	if not word then return hideSuggestions() end

	matches = CommandCatalog.Matching(word, scopes())
	if #matches == 0 then return hideSuggestions() end
	if #matches > SUGGEST_MAX then
		local trimmed = {}
		for i = 1, SUGGEST_MAX do trimmed[i] = matches[i] end
		matches = trimmed
	end
	picked = math.clamp(picked, 1, #matches)

	for index, entry in ipairs(matches) do
		local row = rows[index]
		if not row then
			row = Instance.new("TextLabel")
			row.Size = UDim2.new(1, 0, 0, 18)
			row.BackgroundColor3 = ACCENT
			row.BackgroundTransparency = 1
			row.BorderSizePixel = 0
			row.Font = Enum.Font.Code
			row.TextSize = 13
			row.TextXAlignment = Enum.TextXAlignment.Left
			row.ZIndex = 6
			row.Parent = suggest
			rows[index] = row
		end
		row.LayoutOrder = index
		row.Text = ("  /%s %s  %s"):format(entry.name, entry.args, entry.desc)
		row.Visible = true
	end
	for index = #matches + 1, #rows do rows[index].Visible = false end

	suggest.Visible = true
	paint()
end

-- Puts the highlighted command in the box, ready for its arguments. The trailing space is the point: the
-- next thing typed is an argument, and having to press space first is the sort of small friction that makes
-- an autocomplete feel worse than typing the word out.
local function acceptSuggestion()
	local entry = matches[picked]
	if not entry then return false end
	box.Text = "/" .. entry.name .. (entry.args ~= "" and " " or "")
	box.CursorPosition = #box.Text + 1
	hideSuggestions()
	return true
end

--------------------------------------------------------------------------------
-- Sending
--------------------------------------------------------------------------------

-- Straight down the AdminCommand remote. Going through the chat system instead would be fragile here --
-- channel servers switch chat off, so SendAsync has nowhere to go -- and it buys no safety: the server
-- checks the UserId allow-list on this remote exactly as it does on a chat line.
local function send(text)
	text = text:match("^%s*(.-)%s*$") or text
	if text == "" then return end
	append("> " .. text, ACCENT)
	-- Remembered for the arrow keys. The same command twice running is stored once: a history that repeats
	-- itself makes Up useless for getting past it.
	if history[#history] ~= text then
		table.insert(history, text)
	end
	cursor = #history + 1
	draft = ""
	Remotes.AdminCommand:FireServer(text)
end

box:GetPropertyChangedSignal("Text"):Connect(function()
	-- A space in front of the line is never something anyone meant to type: a command starts with "/", and
	-- dispatch drops anything that does not -- SILENTLY, so a line with a space in front looks like a
	-- command that did nothing. Opening the console with F2 left one there every time (user, 2026-09-20),
	-- and the admin had to notice it and backspace before every single command.
	--
	-- Stripped here rather than only at send time so what is on screen is what will be sent, and because the
	-- suggestion list matches on the raw text: " /gi" offers nothing, "/gi" offers /give.
	local trimmed = box.Text:gsub("^%s+", "")
	if trimmed ~= box.Text then
		local cursorAt = box.CursorPosition
		local removed = #box.Text - #trimmed
		box.Text = trimmed
		-- Keep the caret over the same character it was over, instead of throwing it to the end: the space
		-- may have been removed from under a half-typed line the player is still editing in the middle of.
		box.CursorPosition = cursorAt > 0 and math.max(1, cursorAt - removed) or cursorAt
		return -- assigning Text re-enters this handler; the work below happens on that pass
	end

	-- Typing puts the box back at the end of the history: the line is the player's own again rather than one
	-- that was recalled, so Down should return to it and not to whatever was there before Up was pressed.
	cursor = #history + 1
	refreshSuggestions()
end)

-- Up and Down do two jobs on the same keys, and which one runs depends on whether the suggestion list is up:
-- with commands on screen the arrows move through THEM, otherwise they move through history. That is the
-- arrangement every terminal with completion uses, and it never needs explaining.
local function step(delta)
	if suggest.Visible and #matches > 0 then
		picked = (picked - 1 + delta) % #matches + 1
		paint()
		return
	end
	if #history == 0 then return end
	if cursor == #history + 1 then draft = box.Text end
	cursor = math.clamp(cursor + delta, 1, #history + 1)
	box.Text = cursor > #history and draft or history[cursor]
	box.CursorPosition = #box.Text + 1
	hideSuggestions()
end

box.FocusLost:Connect(function(enterPressed, cause)
	-- Escape reaches the console THROUGH the box, because a focused TextBox swallows the key before anything
	-- else sees it -- the Roblox menu included, which is why pressing it here closes the console instead of
	-- opening that. The InputBegan handler below covers the other case: console open, box not focused.
	if cause and cause.KeyCode == Enum.KeyCode.Escape then
		hideSuggestions()
		gui.Enabled = false
		return
	end
	if not enterPressed then
		hideSuggestions()
		return
	end
	-- Enter on a highlighted suggestion FILLS IT IN rather than sending: the command is only half typed, and
	-- sending it would be sending "/gi".
	if acceptSuggestion() then
		task.defer(function()
			if gui.Enabled then box:CaptureFocus() end
		end)
		return
	end
	local text = box.Text
	box.Text = ""
	hideSuggestions()
	send(text)
	-- Straight back into the box, so several commands can be typed in a row.
	task.defer(function()
		if gui.Enabled then box:CaptureFocus() end
	end)
end)

Remotes.AdminMessage.OnClientEvent:Connect(function(text)
	append(text)
	if not gui.Enabled then
		-- A reply to a command typed elsewhere still deserves to be seen.
		gui.Enabled = true
	end
end)

local function setOpen(open)
	gui.Enabled = open
	if open then
		box:CaptureFocus()
	else
		hideSuggestions()
		box:ReleaseFocus()
	end
end

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if input.KeyCode == Enum.KeyCode.Escape then
		-- Only when the console is open and the box is NOT focused. The focused case is handled in FocusLost
		-- above, and acting on both would close it and then try to close it again.
		if gui.Enabled then setOpen(false) end
		return
	end
	if gameProcessed then return end
	if input.KeyCode ~= Enum.KeyCode.F2 then return end
	-- Checked on every press rather than once at start-up: a class is chosen mid-session, and a player who
	-- becomes a guard at level 50 should get the console without rejoining.
	if not gui.Enabled and not hasCommands() then return end
	setOpen(not gui.Enabled)
end)

-- The arrows go through ContextActionService rather than InputBegan, because a focused TextBox consumes
-- arrow keys for its own cursor and InputBegan never sees them. Sinking them is deliberate: while the
-- console is open the arrows belong to it, and letting them through would walk the character as well.
ContextActionService:BindActionAtPriority("WOLD_ConsoleHistory", function(_, state, input)
	if state ~= Enum.UserInputState.Begin then return Enum.ContextActionResult.Pass end
	if not gui.Enabled then return Enum.ContextActionResult.Pass end
	step(input.KeyCode == Enum.KeyCode.Up and -1 or 1)
	return Enum.ContextActionResult.Sink
end, false, Enum.ContextActionPriority.High.Value + 1, Enum.KeyCode.Up, Enum.KeyCode.Down)

append("พิมพ์ /admin เพื่อดูคำสั่งทั้งหมด", ACCENT)

-- ล็อบบี้บนเครื่องที่ไม่มีคีย์บอร์ด: กด F2 ไม่ได้และแชทถูกซ่อน → ปุ่ม 🛠️ เฉพาะแอดมิน กลมมุมขวาล่าง ถัดจาก 🔮
-- (LobbyButton ช่องที่ 2) หน้าตาเดียวกับปุ่มในเกม · ซ่อนตอนโหมดถ่ายรูป (ไม่อยู่ในรายการ KEEP ของ PhotoMode)
if LOBBY and not UserInputService.KeyboardEnabled then
	local PhotoMode = require(game.ReplicatedStorage.UI.PhotoMode)
	require(game.ReplicatedStorage.UI.LobbyButton).new("WOLD_LobbyAdmin", 2, nil, "🛠️",
		function() return isAdmin() and not PhotoMode.IsOn() end,
		function() setOpen(not gui.Enabled) end)
end

--------------------------------------------------------------------------------
-- Flight
--------------------------------------------------------------------------------
-- Driven here rather than on the server because the client owns its character's physics: a server-side
-- mover fights the client for the same parts and stutters. The SERVER still decides who may fly -- this
-- only listens for permission it granted.
--
-- Built from BodyVelocity/BodyGyro rather than by setting CFrame every frame, so the character keeps
-- colliding with the world instead of passing through it while being scrubbed into place.

local RunService = game:GetService("RunService")

local flying = false
local flySpeed = 90
local flyConnection, velocity, gyro
local flyKeys = {}

local function stopFlying()
	flying = false
	if flyConnection then
		flyConnection:Disconnect()
		flyConnection = nil
	end
	if velocity then velocity:Destroy() velocity = nil end
	if gyro then gyro:Destroy() gyro = nil end

	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.PlatformStand = false
		-- Back to whatever the movement system wants; it sets WalkSpeed every tick anyway.
		humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
	end
	for _, key in ipairs({ "WOLD_FlyUp", "WOLD_FlyDown" }) do
		pcall(function() ContextActionService:UnbindAction(key) end)
	end
	flyKeys = {}
	append("ลงพื้นแล้ว", ACCENT)
end

local function startFlying()
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid then
		append("ตัวละครยังไม่พร้อม", Color3.fromRGB(220, 120, 110))
		return
	end

	flying = true
	-- PlatformStand stops the humanoid trying to walk and fall while the movers hold it up.
	humanoid.PlatformStand = true

	velocity = Instance.new("BodyVelocity")
	velocity.MaxForce = Vector3.new(1, 1, 1) * 1e6
	velocity.Velocity = Vector3.zero
	velocity.Parent = root

	gyro = Instance.new("BodyGyro")
	gyro.MaxTorque = Vector3.new(1, 1, 1) * 1e6
	gyro.P = 9000
	gyro.CFrame = root.CFrame
	gyro.Parent = root

	-- Space and Shift are claimed while flying so jumping does not fight the climb.
	ContextActionService:BindAction("WOLD_FlyUp", function(_, state)
		flyKeys.up = state == Enum.UserInputState.Begin
		return Enum.ContextActionResult.Sink
	end, false, Enum.KeyCode.Space)
	ContextActionService:BindAction("WOLD_FlyDown", function(_, state)
		flyKeys.down = state == Enum.UserInputState.Begin
		return Enum.ContextActionResult.Sink
	end, false, Enum.KeyCode.LeftShift)

	flyConnection = RunService.RenderStepped:Connect(function()
		if not flying then return end
		local char = player.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if not hrp or not hum then
			stopFlying()
			return
		end

		local camera = workspace.CurrentCamera
		-- Move where the camera looks, which is what "fly" means when the point is to survey the map.
		local move = hum.MoveDirection
		local direction = Vector3.zero
		if move.Magnitude > 0.1 then
			-- MoveDirection is already in world space and camera-relative, so it needs no rotating.
			direction = move
		end
		if flyKeys.up then direction = direction + Vector3.new(0, 1, 0) end
		if flyKeys.down then direction = direction - Vector3.new(0, 1, 0) end

		velocity.Velocity = direction.Magnitude > 0 and direction.Unit * flySpeed or Vector3.zero
		gyro.CFrame = CFrame.new(hrp.Position, hrp.Position + camera.CFrame.LookVector)
	end)

	append(("บินอยู่ (ความเร็ว %d) — Space ขึ้น, Shift ลง, /land เพื่อลง"):format(flySpeed), ACCENT)
end

Remotes.AdminFly.OnClientEvent:Connect(function(action, speed)
	if speed then flySpeed = speed end
	if action == "off" then
		if flying then stopFlying() end
	elseif action == "toggle" then
		if flying then stopFlying() else startFlying() end
	end
end)

-- A respawn destroys the movers with the old rig, so the flag has to be cleared or the next /fly toggles
-- flight OFF instead of on.
player.CharacterAdded:Connect(function()
	if flying then
		flying = false
		if flyConnection then flyConnection:Disconnect() flyConnection = nil end
		velocity, gyro = nil, nil
	end
end)
