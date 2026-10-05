-- KillBannerGui: ป้ายคิลกลางบนจอในสนาม PVP (ผู้ใช้สั่ง 2026-09-25) — เด้งขยายเข้า ค้าง แล้วจางออก
-- มาติดกันหลายอันต่อคิว ไม่ทับกัน · เสียง ArenaConfig.KillSound ทุกคิล ปรับเสียงสูงตามระดับ
-- ถ้ามีเสียงพากย์ใน ArenaConfig.KillSounds[kind] เล่นเพิ่มอีกเสียง
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local ArenaConfig = require(game.ReplicatedStorage.ArenaConfig)
local Show = require(script.Parent.Parent.Locale).Show

local KillBannerGui = {}
KillBannerGui.__index = KillBannerGui

local TITLES = {
	kill = { "ELIMINATED", Color3.fromRGB(245, 232, 200) },
	first = { "FIRST BLOOD", Color3.fromRGB(235, 70, 60) },
	double = { "DOUBLE KILL", Color3.fromRGB(255, 160, 50) },
	triple = { "TRIPLE KILL", Color3.fromRGB(190, 110, 255) },
	ace = { "ACE", Color3.fromRGB(255, 200, 40) },
}
local HOLD, FADE = 1.6, 0.4

local function play(id, speed, parent)
	if not id or id == "" then return end
	local s = Instance.new("Sound")
	s.SoundId = id
	s.Volume = 0.6
	s.PlaybackSpeed = speed or 1
	s.Parent = parent
	SoundService:PlayLocalSound(s)
	task.delay(4, function() s:Destroy() end)
end

function KillBannerGui.new()
	local self = setmetatable({ queue = {}, busy = false }, KillBannerGui)
	local gui = Instance.new("ScreenGui")
	gui.Name = "WOLD_KillBanner"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 20
	self.gui = gui

	local holder = Instance.new("Frame")
	holder.AnchorPoint = Vector2.new(0.5, 0)
	holder.Position = UDim2.fromScale(0.5, 0.13)
	holder.Size = UDim2.fromOffset(560, 96)
	holder.BackgroundTransparency = 1
	holder.Visible = false
	holder.Parent = gui
	self.holder = holder
	local scale = Instance.new("UIScale")
	scale.Parent = holder
	self.scale = scale

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, 0, 0, 60)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBlack
	title.TextSize = 52
	title.TextColor3 = Color3.new(1, 1, 1)
	title.Parent = holder
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 3
	stroke.Color = Color3.fromRGB(20, 14, 8)
	stroke.Parent = title
	local shine = Instance.new("UIGradient")
	shine.Rotation = 90
	shine.Parent = title
	self.title, self.titleStroke, self.shine = title, stroke, shine

	local sub = Instance.new("TextLabel")
	sub.Position = UDim2.fromOffset(0, 62)
	sub.Size = UDim2.new(1, 0, 0, 28)
	sub.BackgroundTransparency = 1
	sub.Font = Enum.Font.GothamBold
	sub.TextSize = 22
	sub.TextColor3 = Color3.fromRGB(235, 235, 235)
	sub.RichText = true
	sub.Parent = holder
	local subStroke = Instance.new("UIStroke")
	subStroke.Thickness = 2
	subStroke.Color = Color3.fromRGB(0, 0, 0)
	subStroke.Parent = sub
	self.sub, self.subStroke = sub, subStroke
	return self
end

function KillBannerGui:_run(info)
	local t = TITLES[info.kind] or TITLES.kill
	self.title.Text = t[1]
	self.shine.Color = ColorSequence.new(Color3.new(1, 1, 1), t[2])
	local tail = info.headshot and '  ·  <font color="#ff5a4a">HEADSHOT</font>' or ""
	self.sub.Text = ("ELIMINATED  %s%s"):format(Show(info.victim or ""), tail) -- ชื่อบอทแปล · ชื่อคนจริงไม่ตรงคีย์ ผ่านตรง
	for _, obj in ipairs({ self.title, self.sub }) do obj.TextTransparency = 0 end
	self.titleStroke.Transparency, self.subStroke.Transparency = 0, 0
	self.holder.Visible = true
	self.scale.Scale = 1.7
	TweenService:Create(self.scale, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()

	play(ArenaConfig.KillSound, ArenaConfig.KillPitch[info.kind] or 1, self.gui)
	play(ArenaConfig.KillSounds[info.kind], 1, self.gui)

	task.wait(HOLD)
	local fade = TweenInfo.new(FADE)
	TweenService:Create(self.title, fade, { TextTransparency = 1 }):Play()
	TweenService:Create(self.sub, fade, { TextTransparency = 1 }):Play()
	TweenService:Create(self.titleStroke, fade, { Transparency = 1 }):Play()
	TweenService:Create(self.subStroke, fade, { Transparency = 1 }):Play()
	task.wait(FADE)
	self.holder.Visible = false
end

function KillBannerGui:Show(info)
	table.insert(self.queue, info)
	if self.busy then return end
	self.busy = true
	task.spawn(function()
		while #self.queue > 0 do
			self:_run(table.remove(self.queue, 1))
		end
		self.busy = false
	end)
end

return KillBannerGui
