-- ProfileCardGui: the card a player raises above their own head for everyone nearby to read.
--
-- A BillboardGui parented to the character, not a screen overlay: that is what makes several cards work at
-- once without any layout code. Each one follows its owner, the engine sorts them by depth, and a crowd of
-- players introducing themselves simply looks like a crowd of cards.
local Players = game:GetService("Players")
local SocialConfig = require(script.Parent.Parent.SocialConfig)
local PvpRankConfig = require(script.Parent.Parent.PvpRankConfig)
local ClassConfig = require(script.Parent.Parent.ClassConfig)
local AvatarThumbnails = require(script.Parent.AvatarThumbnails)

local ProfileCardGui = {}

local STONE_DEEP = Color3.fromRGB(18, 19, 25)
local RUNE = Color3.fromRGB(126, 214, 232)
local TEXT_LIGHT = Color3.fromRGB(238, 240, 246)
local TEXT_MUTED = Color3.fromRGB(150, 156, 172)

local cards = {} -- [userId] = BillboardGui

local function label(parent, text, size, color, align)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Font = Enum.Font.GothamMedium
	l.TextSize = size
	l.TextColor3 = color
	l.TextXAlignment = align or Enum.TextXAlignment.Left
	l.Text = text
	l.Parent = parent
	return l
end

-- Removes the card a player is showing, if any. Safe to call when there is none.
function ProfileCardGui.Hide(userId)
	local card = cards[userId]
	if card then
		card:Destroy()
		cards[userId] = nil
	end
end

function ProfileCardGui.Show(data)
	if not data or not data.userId then return end
	ProfileCardGui.Hide(data.userId)

	local player = Players:GetPlayerByUserId(data.userId)
	local character = player and player.Character
	local head = character and character:FindFirstChild("Head")
	-- No rig yet (still loading, or respawning): nothing to hang the card on. The owner can raise it again.
	if not head then return end

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "WOLD_ProfileCard"
	billboard.Adornee = head
	billboard.Size = UDim2.fromOffset(210, 96)
	billboard.StudsOffsetWorldSpace = Vector3.new(0, 3.4, 0)
	billboard.AlwaysOnTop = false -- a wall between you and them should hide it, like a real sign
	billboard.MaxDistance = SocialConfig.CardRange
	billboard.LightInfluence = 0
	billboard.Parent = character

	local panel = Instance.new("Frame")
	panel.Size = UDim2.fromScale(1, 1)
	panel.BackgroundColor3 = STONE_DEEP
	panel.BackgroundTransparency = 0.15
	panel.BorderSizePixel = 0
	panel.Parent = billboard

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = panel

	local rank = SocialConfig.RankFor(data.level)
	-- **กรอบแร็งก์ PVP แทนกรอบเลเวล** สำหรับคนที่เคยเล่นแร็งก์ (เฟส 3 · roadmap) — สีแร่ของขั้น หนากว่าเล็กน้อย ขั้นสูงเรือง
	local pvpTier = PvpRankConfig.Enabled and type(data.pvpTier) == "number" and PvpRankConfig.Tier(data.pvpTier) or nil
	local stroke = Instance.new("UIStroke")
	stroke.Color = pvpTier and pvpTier.color or rank.color
	stroke.Transparency = (pvpTier and pvpTier.glow or (not pvpTier and rank.glow)) and 0.05 or 0.4
	stroke.Thickness = pvpTier and 3 or 2
	stroke.Parent = panel
	-- ตราแร็งก์ PVP ที่มุมล่างขวาของรูปหน้า (เดิมทับตัวอักษรระดับเลเวลที่มุมขวา) · แร็งก์ล็อกอยู่ (ผู้ใช้สั่ง 2026-09-28) =
	-- ทุกคนโชว์ไอร่อนจางๆ + 🔒 เล็กๆ เฉยๆ
	do
		local shown = pvpTier or PvpRankConfig.Tier(1)
		local badge = Instance.new("TextLabel")
		badge.AnchorPoint = Vector2.new(0, 0)
		badge.Position = UDim2.fromOffset(38, 36)
		badge.Size = UDim2.fromOffset(22, 22)
		badge.ZIndex = 3
		badge.BackgroundTransparency = 1
		badge.TextScaled = true
		badge.Text = shown.emoji
		badge.TextTransparency = PvpRankConfig.Enabled and 0 or 0.35
		badge.Parent = panel
		if not PvpRankConfig.Enabled then
			local lock = Instance.new("TextLabel")
			lock.AnchorPoint = Vector2.new(1, 1)
			lock.Position = UDim2.new(1, 4, 1, 4)
			lock.Size = UDim2.fromOffset(13, 13)
			lock.BackgroundTransparency = 1
			lock.TextScaled = true
			lock.Text = "🔒"
			lock.Parent = badge
		end
	end

	local face = Instance.new("ImageLabel")
	face.Position = UDim2.new(0, 8, 0, 8)
	face.Size = UDim2.fromOffset(46, 46)
	face.BackgroundColor3 = Color3.fromRGB(28, 30, 38)
	face.BorderSizePixel = 0
	face.Parent = panel
	local fc = Instance.new("UICorner")
	fc.CornerRadius = UDim.new(1, 0)
	fc.Parent = face
	-- nil until the fetch lands, false if it failed; only a string is a valid Image.
	AvatarThumbnails.Get(data.userId, function(image)
		if face.Parent and type(image) == "string" then face.Image = image end
	end)

	local name = label(panel, data.name, 14, TEXT_LIGHT)
	name.Position = UDim2.new(0, 62, 0, 8)
	name.Size = UDim2.new(1, -110, 0, 18)
	name.Font = Enum.Font.GothamBold
	name.TextTruncate = Enum.TextTruncate.AtEnd

	-- The rank letter, large and in its band's colour: the one thing readable at a glance across a street.
	local badge = label(panel, rank.id, 22, rank.color, Enum.TextXAlignment.Center)
	badge.AnchorPoint = Vector2.new(1, 0)
	badge.Position = UDim2.new(1, -10, 0, 6)
	badge.Size = UDim2.fromOffset(30, 30)
	badge.Font = Enum.Font.GothamBold

	-- Level and class on one line. Raising the card is the only way anyone learns either of these about a
	-- stranger now, so the card has to carry both.
	local levelText = data.class
		and ("เลเวล %d · %s"):format(data.level or 1, ClassConfig.DisplayName(data.class))
		or ("เลเวล %d"):format(data.level or 1)
	local level = label(panel, levelText, 12,
		data.class and ClassConfig.ColorOf(data.class) or TEXT_MUTED)
	level.Position = UDim2.new(0, 62, 0, 28)
	level.Size = UDim2.new(1, -70, 0, 16)

	local details = label(panel,
		("%s · %s"):format(data.gender or "ยังไม่ระบุ", data.birthday or "ยังไม่ระบุ"),
		11, TEXT_MUTED)
	details.Position = UDim2.new(0, 10, 0, 62)
	details.Size = UDim2.new(1, -20, 0, 26)
	details.TextWrapped = true

	local line = Instance.new("Frame")
	line.Position = UDim2.new(0, 10, 0, 58)
	line.Size = UDim2.new(1, -20, 0, 1)
	line.BackgroundColor3 = RUNE
	line.BackgroundTransparency = 0.7
	line.BorderSizePixel = 0
	line.Parent = panel

	cards[data.userId] = billboard
end

-- A respawn destroys the old character and the card with it, so the owner's card has to be re-raised.
function ProfileCardGui.IsShowing(userId)
	local card = cards[userId]
	return card ~= nil and card.Parent ~= nil
end

return ProfileCardGui
