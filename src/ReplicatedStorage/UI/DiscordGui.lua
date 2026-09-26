-- DiscordGui: the invite, shown where a player can actually get at it.
--
-- Roblox cannot open an external link. GuiService:OpenBrowserWindow only accepts Roblox's own domains, and
-- there is no API that hands a roblox.com page off to a browser for anything else -- so a "click to open
-- Discord" button is not a thing that can be built, by us or by anyone.
--
-- What CAN be done is put the address in front of them in a form they can take away: a TextBox they can
-- select and copy with the keyboard, and -- on the clients that allow it -- a button that puts it straight
-- on the clipboard. That is why this is a panel rather than a link.
local Players = game:GetService("Players")
local Responsive = require(script.Parent.Responsive)
local UiSound = require(script.Parent.UiSound)

local STONE = Color3.fromRGB(38, 40, 48)
local STONE_DEEP = Color3.fromRGB(26, 28, 34)
local TEXT_LIGHT = Color3.fromRGB(232, 232, 238)
local TEXT_MUTED = Color3.fromRGB(150, 152, 162)
-- Discord's own blurple, so the panel reads as theirs rather than as another stone menu.
local BLURPLE = Color3.fromRGB(88, 101, 242)

local DiscordGui = {}
DiscordGui.__index = DiscordGui

local function corner(inst, radius)
	local c = Instance.new("UICorner")
	c.CornerRadius = radius
	c.Parent = inst
	return c
end

function DiscordGui.new(url)
	local self = setmetatable({}, DiscordGui)
	self.url = url

	local gui = Instance.new("ScreenGui")
	gui.Name = "DiscordGui"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 22
	gui.Enabled = false
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	self.gui = gui

	local backdrop = Instance.new("TextButton")
	backdrop.Size = UDim2.fromScale(1, 1)
	backdrop.BackgroundColor3 = Color3.new(0, 0, 0)
	backdrop.BackgroundTransparency = 0.45
	backdrop.BorderSizePixel = 0
	backdrop.Text = ""
	backdrop.Parent = gui
	backdrop.Activated:Connect(function() self:Hide() end)

	local panel = Instance.new("Frame")
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = Responsive.IsSmallScreen() and UDim2.fromScale(0.9, 0.42)
		or UDim2.fromOffset(440, 250)
	panel.BackgroundColor3 = STONE
	panel.BorderSizePixel = 0
	panel.Parent = gui
	corner(panel, UDim.new(0, 14))
	local stroke = Instance.new("UIStroke")
	stroke.Color = BLURPLE
	stroke.Transparency = 0.35
	stroke.Thickness = 2
	stroke.Parent = panel
	Responsive.Scale(panel, Responsive.IsSmallScreen() and 0.95 or nil) -- มือถือ: แผงเต็มจออยู่แล้ว ห้ามย่อซ้ำ (QA 2026-09-26)

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, -24, 0, 30)
	title.Position = UDim2.new(0, 12, 0, 16)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBold
	title.TextSize = 19
	title.TextColor3 = BLURPLE
	title.Text = "ดิสคอร์ดของ WOLD Arture"
	title.Parent = panel

	local hint = Instance.new("TextLabel")
	hint.Size = UDim2.new(1, -32, 0, 34)
	hint.Position = UDim2.new(0, 16, 0, 48)
	hint.BackgroundTransparency = 1
	hint.Font = Enum.Font.Gotham
	hint.TextSize = 12
	hint.TextWrapped = true
	hint.TextColor3 = TEXT_MUTED
	hint.Text = "Roblox เปิดลิงก์ข้างนอกให้ไม่ได้ — ก๊อปลิงก์ข้างล่างไปวางในเบราว์เซอร์ได้เลย"
	hint.Parent = panel

	-- Selectable, so a desktop player can drag across it and press Ctrl+C. Not editable in any way that
	-- matters: TextEditable is left on because a TextBox cannot be selected without it, and the text is put
	-- back the moment they finish, so nothing they type can survive.
	local box = Instance.new("TextBox")
	box.Size = UDim2.new(1, -32, 0, 38)
	box.Position = UDim2.new(0, 16, 0, 90)
	box.BackgroundColor3 = STONE_DEEP
	box.BorderSizePixel = 0
	box.Font = Enum.Font.Code
	box.TextSize = 14
	box.TextColor3 = TEXT_LIGHT
	box.Text = url
	box.ClearTextOnFocus = false
	box.Parent = panel
	corner(box, UDim.new(0, 8))
	box.FocusLost:Connect(function()
		box.Text = self.url
	end)
	self.box = box

	local copy = Instance.new("TextButton")
	copy.Size = UDim2.new(1, -32, 0, 40)
	copy.Position = UDim2.new(0, 16, 0, 140)
	copy.BackgroundColor3 = BLURPLE
	copy.BorderSizePixel = 0
	copy.Font = Enum.Font.GothamBold
	copy.TextSize = 14
	copy.TextColor3 = Color3.new(1, 1, 1)
	copy.Text = "คัดลอกลิงก์"
	copy.Parent = panel
	corner(copy, UDim.new(0, 8))
	copy.Activated:Connect(function()
		UiSound.Play("Click")
		-- setclipboard exists only in some clients. Where it does not, selecting the box is the fallback --
		-- which is why the box is there at all rather than a plain label.
		local clip = rawget(getfenv(0), "setclipboard") or rawget(getfenv(0), "toclipboard")
		local copied = false
		if type(clip) == "function" then
			copied = pcall(clip, self.url)
		end
		copy.Text = copied and "คัดลอกแล้ว!" or (Responsive.IsTouchOnly() and "กดค้างที่ข้อความข้างบนแล้วเลือกคัดลอก" or "เลือกข้อความข้างบนแล้วกด Ctrl+C")
		task.delay(2.5, function()
			if copy.Parent then copy.Text = "คัดลอกลิงก์" end
		end)
		if not copied then
			box:CaptureFocus()
		end
	end)

	local close = Instance.new("TextButton")
	close.AnchorPoint = Vector2.new(0.5, 1)
	close.Position = UDim2.new(0.5, 0, 1, -14)
	close.Size = UDim2.fromOffset(150, 30)
	close.BackgroundColor3 = Color3.fromRGB(70, 74, 84)
	close.BorderSizePixel = 0
	close.Font = Enum.Font.GothamBold
	close.TextSize = 13
	close.TextColor3 = TEXT_MUTED
	close.Text = "ปิด"
	close.Parent = panel
	corner(close, UDim.new(0, 8))
	close.Activated:Connect(function()
		UiSound.Play("Click")
		self:Hide()
	end)

	return self
end

function DiscordGui:Show()
	self.box.Text = self.url
	self.gui.Enabled = true
end

function DiscordGui:Hide() self.gui.Enabled = false end
function DiscordGui:IsOpen() return self.gui.Enabled end

return DiscordGui
