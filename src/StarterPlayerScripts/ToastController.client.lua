-- ToastController: shows the short messages the server sends about what just happened.
--
-- SocialNotify has been the game's "tell the player something" channel for a while, but the only thing
-- listening was the speaking stone's own window -- so an "info" or "error" arriving with that window shut
-- was shown to nobody at all. Everything gathering, fishing, the shop and the monsters had to say went
-- into the void, which is how "click does not fish" turned out to be "click said ตรงนี้ไม่มีน้ำ and no
-- one could see it".
--
-- Deliberately dumb: a stack of lines that fade. It draws what it is told and never decides anything.
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

-- ล็อบบี้ก็แสดงด้วย (QA 2026-09-26) — หน้าปาร์ตี้ PVP บอกเหตุผลทุกอย่างผ่าน SocialNotify (ชวนไม่ได้ ปาร์ตี้เต็ม อยู่ในคิว
-- แล้ว) ของเดิมปิดตัวเองในล็อบบี้ ข้อความพวกนั้นเลยไม่เคยขึ้นจอ กดแล้วเหมือนปุ่มพัง
local UserInputService = game:GetService("UserInputService")

local Remotes = require(game.ReplicatedStorage.Remotes)
local UiSound = require(game.ReplicatedStorage.UI.UiSound)
local Locale = require(game.ReplicatedStorage.Locale)

-- **ทุกข้อความมีเสียง** (QA 2026-09-28 "อินเทอแร็กแล้วต้องไม่เงียบ") — ปฏิเสธ = ToastError · ได้ของ/รางวัล = ToastReward ·
-- อื่นๆ = ToastInfo · ข้อความรัวๆ เล่นเสียงไม่เกินทุก 0.3 วิ (หลายข้อความในเฟรมเดียวไม่ซ้อนกันเป็นเสียงแตก)
local REWARD_WORDS = { "ได้รับ", "รับรางวัล", "💎", "🎁", "🎫", "ปลดล็อก", "ปลดสาย", "คราฟสำเร็จ", "ตีบวกสำเร็จ", "ส่งงานสำเร็จ", -- locale: skip (จับคำไทยต้นฉบับ ไม่ได้ขึ้นจอ)
	"ขายได้", "ซื้อ", "จบบท" } -- locale: skip (จับคำไทยต้นฉบับ ไม่ได้ขึ้นจอ)
local lastSoundAt = 0
local function soundFor(message, isError)
	local now = os.clock()
	if now - lastSoundAt < 0.3 then return end
	lastSoundAt = now
	if isError then return UiSound.Play("ToastError") end
	-- ซื้อสำเร็จ (ร้าน/ร้านเพชร/คอก/VIP) = เสียงเหรียญ Purchase (Q15) · "ซื้อไม่สำเร็จ" มาเป็น error ไปแล้วข้างบน
	if (string.find(message, "^ซื้อ") or string.find(message, "เพชร)", 1, true)) and not string.find(message, "ไม่", 1, true) then -- locale: skip (จับคำไทยต้นฉบับ ไม่ได้ขึ้นจอ)
		return UiSound.Play("Purchase")
	end
	-- "ไม่ได้/ไม่สำเร็จ" ไม่ใช่รางวัล แม้มีคำเหล่านั้นอยู่
	local reward = string.sub(message, 1, 1) == "+" and not string.find(message, "ไม่", 1, true) -- locale: skip (จับคำไทยต้นฉบับ ไม่ได้ขึ้นจอ)
	for _, word in ipairs(REWARD_WORDS) do
		if not reward and string.find(message, word, 1, true) and not string.find(message, "ไม่" .. word, 1, true) then -- locale: skip (จับคำไทยต้นฉบับ ไม่ได้ขึ้นจอ)
			reward = true
		end
	end
	UiSound.Play(reward and "ToastReward" or "ToastInfo")
end

local player = Players.LocalPlayer

-- The kinds the stone's own window already handles. Those still go there; repeating them here would
-- double every friend request.
local HANDLED_ELSEWHERE = { pigeon = true, friendRequest = true }

local SECONDS = 3.5
local MAX_LINES = 5

local gui = Instance.new("ScreenGui")
gui.Name = "ToastGui"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 14
gui.Parent = player:WaitForChild("PlayerGui")

-- Above the hotbar and clear of the vitals cluster: the bottom left is taken, the bottom middle is the
-- hotbar, so these sit bottom-right where nothing else lives.
-- **มือถือ: กลางบน** (QA 2026-09-26) — มุมขวาล่างของมือถือคือปุ่มโจมตี/สกิล/กลิ้ง ข้อความ "มานาไม่พอ" ขึ้นทับปุ่มที่
-- เพิ่งกดพอดี 3.5 วิ · กลางบนใต้แถบประกาศว่างเสมอ และ TextLabel ไม่กินการแตะ
local touchOnly = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
local holder = Instance.new("Frame")
holder.AnchorPoint = touchOnly and Vector2.new(0.5, 0) or Vector2.new(1, 1)
holder.Position = touchOnly and UDim2.new(0.5, 0, 0, 118) or UDim2.new(1, -16, 1, -120)
holder.Size = UDim2.fromOffset(320, 200)
holder.BackgroundTransparency = 1
holder.Parent = gui

local layout = Instance.new("UIListLayout")
layout.VerticalAlignment = touchOnly and Enum.VerticalAlignment.Top or Enum.VerticalAlignment.Bottom
layout.HorizontalAlignment = touchOnly and Enum.HorizontalAlignment.Center or Enum.HorizontalAlignment.Right
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Padding = UDim.new(0, 4)
layout.Parent = holder

local order = 0

local function toast(message, isError)
	order += 1

	local line = Instance.new("TextLabel")
	line.LayoutOrder = order
	line.AutomaticSize = Enum.AutomaticSize.X
	line.Size = UDim2.fromOffset(0, 26)
	line.BackgroundColor3 = Color3.fromRGB(26, 28, 34)
	line.BackgroundTransparency = 0.15
	line.BorderSizePixel = 0
	line.Font = Enum.Font.GothamBold
	line.TextSize = 13
	line.TextColor3 = isError and Color3.fromRGB(232, 128, 118) or Color3.fromRGB(238, 224, 180)
	-- ข้อความมาเป็นไทยสำเร็จรูป (เสียงด้านล่างเลือกจากคำไทย) แปลตอนแสดงเท่านั้น — ระบบหลายภาษา 2026-10-05
	line.Text = "  " .. Locale.Show(message) .. "  "
	line.Parent = holder

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = line

	local stroke = Instance.new("UIStroke")
	stroke.Color = isError and Color3.fromRGB(214, 84, 74) or Color3.fromRGB(244, 197, 66)
	stroke.Transparency = 0.5
	stroke.Parent = line

	-- Oldest first: a burst of catches should not push the newest one off screen.
	local lines = {}
	for _, child in ipairs(holder:GetChildren()) do
		if child:IsA("TextLabel") then table.insert(lines, child) end
	end
	if #lines > MAX_LINES then
		table.sort(lines, function(a, b) return a.LayoutOrder < b.LayoutOrder end)
		for i = 1, #lines - MAX_LINES do lines[i]:Destroy() end
	end

	task.delay(SECONDS, function()
		if not line.Parent then return end
		local fade = TweenService:Create(line, TweenInfo.new(0.4),
			{ BackgroundTransparency = 1, TextTransparency = 1 })
		local fadeStroke = TweenService:Create(stroke, TweenInfo.new(0.4), { Transparency = 1 })
		fade:Play()
		fadeStroke:Play()
		fade.Completed:Wait()
		line:Destroy()
	end)
end

-- ข้อความจากฝั่งไคลเอนต์เอง (ไม่ต้องถามเซิร์ฟ เช่น แตะไอคอนแร็งก์ที่ล็อก) — ช่องทางอยู่ ReplicatedStorage (PlayerGui ถูกล้างตอนเกิดใหม่)
local localToast = game.ReplicatedStorage:FindFirstChild("WOLD_Toast") or Instance.new("BindableEvent")
localToast.Name = "WOLD_Toast"
localToast.Parent = game.ReplicatedStorage
-- `silent` = คนส่งเล่นเสียงของตัวเองแล้ว (เช่นขั้นเควสเนื้อเรื่อง) ไม่ต้องซ้อนเสียงข้อความ
localToast.Event:Connect(function(message, isError, silent)
	if type(message) == "string" then
		toast(message, isError == true)
		if not silent then soundFor(message, isError == true) end
	end
end)

-- อาร์กิวเมนต์ที่สาม `silent` = เซิร์ฟเวอร์เล่นเสียงของการกระทำนั้นเองแล้ว (WorldSound) ไม่ต้องซ้อนเสียงข้อความ
Remotes.SocialNotify.OnClientEvent:Connect(function(kind, message, silent)
	if not message or HANDLED_ELSEWHERE[kind] then return end
	toast(message, kind == "error")
	if silent ~= true then soundFor(tostring(message), kind == "error" or kind == "warn") end
end)
