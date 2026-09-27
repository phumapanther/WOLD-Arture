-- IslandSeedController (เฟส 2c): เลือกเมล็ดตอนหยอดแปลง — ขึ้นเฉพาะตอนมีเมล็ดที่ปลูกได้มากกว่าหนึ่งชนิด
--
-- เซิร์ฟ → IslandSeedChoice("ask", uid, ตัวเลือก) = กด E ที่แปลงว่าง แต่ไม่รู้ว่าจะหยอดอะไร → กล่องเลือกเล็กๆ
--        → IslandSeedChoice("active", seedId, วินาที) = จำเมล็ดนี้ไว้แล้ว แปลงถัดไปหยอดเลยไม่ต้องถาม
-- ไคลเอนต์ → IslandPlantSeed(uid, seedId) · IslandSeedChoice("clear") (ปุ่ม "เปลี่ยน")
while workspace:GetAttribute("IsLobby") == nil do task.wait() end
if workspace:GetAttribute("IslandMode") ~= true then return end

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Remotes = require(ReplicatedStorage.Remotes)
local Responsive = require(ReplicatedStorage.UI.Responsive)
local UiSound = require(ReplicatedStorage.UI.UiSound)
local ItemIcon = require(ReplicatedStorage.UI.ItemIcon)
local ItemCatalog = require(ReplicatedStorage.ItemCatalog)

local player = Players.LocalPlayer
local RUNE = Color3.fromRGB(244, 197, 66)
local TEXT = Color3.fromRGB(236, 236, 240)
local MUTED = Color3.fromRGB(160, 162, 172)

local function corner(inst, px)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, px)
	c.Parent = inst
end

local gui = Instance.new("ScreenGui")
gui.Name = "IslandSeedGui"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 30
gui.Parent = player:WaitForChild("PlayerGui")

-- กล่องเลือก (กลางล่าง เหนือแถบไอเทม)
local picker = Instance.new("Frame")
picker.AnchorPoint = Vector2.new(0.5, 1)
picker.Position = UDim2.new(0.5, 0, 1, -170)
picker.Size = UDim2.fromOffset(420, 120)
picker.BackgroundColor3 = Color3.fromRGB(30, 30, 36)
picker.BackgroundTransparency = 0.05
picker.BorderSizePixel = 0
picker.Visible = false
picker.Parent = gui
corner(picker, 12)
local ps = Instance.new("UIStroke"); ps.Color = RUNE; ps.Transparency = 0.4; ps.Thickness = 1.5; ps.Parent = picker
Responsive.Scale(picker, 0.8)

local title = Instance.new("TextLabel")
title.BackgroundTransparency = 1
title.Position = UDim2.fromOffset(14, 6)
title.Size = UDim2.new(1, -60, 0, 26)
title.Font = Enum.Font.GothamBold
title.TextSize = 15
title.TextColor3 = RUNE
title.TextXAlignment = Enum.TextXAlignment.Left
title.Text = "🌱 หยอดเมล็ดอะไรดี?"
title.Parent = picker

local close = Instance.new("TextButton")
close.AnchorPoint = Vector2.new(1, 0)
close.Position = UDim2.new(1, -8, 0, 8)
close.Size = UDim2.fromOffset(30, 26)
close.BackgroundColor3 = Color3.fromRGB(70, 74, 84)
close.BorderSizePixel = 0
close.Font = Enum.Font.GothamBold
close.TextSize = 15
close.TextColor3 = TEXT
close.Text = "\195\151"
close.Parent = picker
corner(close, 6)

local choices = Instance.new("Frame")
choices.Position = UDim2.fromOffset(12, 38)
choices.Size = UDim2.new(1, -24, 0, 72)
choices.BackgroundTransparency = 1
choices.Parent = picker
local cl = Instance.new("UIListLayout")
cl.FillDirection = Enum.FillDirection.Horizontal
cl.Padding = UDim.new(0, 8)
cl.Parent = choices

-- แถบ "กำลังหยอด: X" (หลังเลือกแล้ว) · หายเองเมื่อครบเวลาที่เซิร์ฟจำไว้
local active = Instance.new("Frame")
active.AnchorPoint = Vector2.new(0.5, 1)
active.Position = UDim2.new(0.5, 0, 1, -170)
active.Size = UDim2.fromOffset(300, 36)
active.BackgroundColor3 = Color3.fromRGB(30, 30, 36)
active.BackgroundTransparency = 0.15
active.BorderSizePixel = 0
active.Visible = false
active.Parent = gui
corner(active, 18)
Responsive.Scale(active, 0.8)
local activeIcon = Instance.new("ImageLabel")
activeIcon.BackgroundTransparency = 1
activeIcon.Position = UDim2.fromOffset(8, 4)
activeIcon.Size = UDim2.fromOffset(28, 28)
activeIcon.Parent = active
local activeText = Instance.new("TextLabel")
activeText.BackgroundTransparency = 1
activeText.Position = UDim2.fromOffset(42, 0)
activeText.Size = UDim2.new(1, -130, 1, 0)
activeText.Font = Enum.Font.GothamBold
activeText.TextSize = 13
activeText.TextColor3 = TEXT
activeText.TextXAlignment = Enum.TextXAlignment.Left
activeText.TextTruncate = Enum.TextTruncate.AtEnd
activeText.Parent = active
local change = Instance.new("TextButton")
change.AnchorPoint = Vector2.new(1, 0.5)
change.Position = UDim2.new(1, -6, 0.5, 0)
change.Size = UDim2.fromOffset(80, 26)
change.BackgroundColor3 = Color3.fromRGB(96, 110, 150)
change.BorderSizePixel = 0
change.Font = Enum.Font.GothamBold
change.TextSize = 12
change.TextColor3 = TEXT
change.Text = "เปลี่ยนเมล็ด"
change.Parent = active
corner(change, 13)

local pickUid = nil
local activeUntil = 0

local function hidePicker()
	picker.Visible = false
	pickUid = nil
end

close.Activated:Connect(function()
	UiSound.Play("Click")
	hidePicker()
end)

change.Activated:Connect(function()
	UiSound.Play("Click")
	activeUntil = 0
	active.Visible = false
	Remotes.IslandSeedChoice:FireServer("clear")
end)

local function showPicker(uid, options)
	for _, child in ipairs(choices:GetChildren()) do
		if child:IsA("TextButton") then child:Destroy() end
	end
	pickUid = uid
	for i, opt in ipairs(options) do
		local b = Instance.new("TextButton")
		b.LayoutOrder = i
		b.Size = UDim2.new(1 / #options, -8 * (#options - 1) / #options, 1, 0)
		b.BackgroundColor3 = Color3.fromRGB(48, 52, 44)
		b.BorderSizePixel = 0
		b.Text = ""
		b.Parent = choices
		corner(b, 10)
		local icon = Instance.new("ImageLabel")
		icon.BackgroundTransparency = 1
		icon.Position = UDim2.fromOffset(8, 10)
		icon.Size = UDim2.fromOffset(50, 50)
		ItemIcon.Apply(icon, opt.icon)
		icon.Parent = b
		local name = Instance.new("TextLabel")
		name.BackgroundTransparency = 1
		name.Position = UDim2.fromOffset(64, 10)
		name.Size = UDim2.new(1, -70, 0, 26)
		name.Font = Enum.Font.GothamBold
		name.TextSize = 14
		name.TextColor3 = TEXT
		name.TextXAlignment = Enum.TextXAlignment.Left
		name.TextTruncate = Enum.TextTruncate.AtEnd
		name.Text = opt.name
		name.Parent = b
		local count = Instance.new("TextLabel")
		count.BackgroundTransparency = 1
		count.Position = UDim2.fromOffset(64, 36)
		count.Size = UDim2.new(1, -70, 0, 20)
		count.Font = Enum.Font.Gotham
		count.TextSize = 12
		count.TextColor3 = MUTED
		count.TextXAlignment = Enum.TextXAlignment.Left
		count.Text = ("มี %d เม็ด"):format(opt.count or 0)
		count.Parent = b
		b.Activated:Connect(function()
			UiSound.Play("Click")
			local uidNow = pickUid
			hidePicker()
			if uidNow then Remotes.IslandPlantSeed:FireServer(uidNow, opt.id) end
		end)
	end
	active.Visible = false
	picker.Visible = true
end

Remotes.IslandSeedChoice.OnClientEvent:Connect(function(what, a, b)
	if what == "ask" and type(b) == "table" and #b > 0 then
		showPicker(a, b)
	elseif what == "active" and type(a) == "string" then
		local item = ItemCatalog.Get(a)
		ItemIcon.Apply(activeIcon, item and item.icon or "")
		activeText.Text = ("กำลังหยอด: %s"):format(item and item.name or a)
		activeUntil = os.clock() + (tonumber(b) or 90)
		picker.Visible = false
		active.Visible = true
	end
end)

-- แถบหายเองเมื่อหมดเวลาที่เซิร์ฟจำ · กล่องเลือกปิดเองเมื่อเดินห่างแปลงนั้น
task.spawn(function()
	while true do
		if active.Visible and os.clock() > activeUntil then active.Visible = false end
		if picker.Visible then
			local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
			local placed = workspace:FindFirstChild("WOLD_Island") and workspace.WOLD_Island:FindFirstChild("Placed")
			local plot = placed and pickUid and placed:FindFirstChild(tostring(pickUid))
			if not root or not plot or (plot:GetPivot().Position - root.Position).Magnitude > 20 then hidePicker() end
		end
		task.wait(0.3)
	end
end)
player.CharacterRemoving:Connect(hidePicker)
