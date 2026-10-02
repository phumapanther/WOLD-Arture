-- ItemIcon: ที่เดียวที่ตัดสินว่า "ช่องรูปไอเทม" จะขึ้นอะไร
--
-- ผู้ใช้สั่ง (2026-09-18): **ไอเทมที่ยังไม่มีรูปของตัวเอง — ไม่มีรูปเลย หรือยืมรูปของไอเทมอื่นมาใช้ — ให้ขึ้น ⌛**
-- จะได้กวาดสายตาดูทีเดียวรู้ว่าเหลืออะไรที่ยังต้องวาด/อัปโหลด แทนที่จะเห็นขวานทองหน้าตาเหมือนขวานธรรมดา
-- แล้วนึกว่าอัปโหลดไปแล้ว
--
-- วิธีบอกว่า "ยังไม่มีรูป" คือ `icon = ""` ใน ItemCatalog (ดูหัวข้อ ⌛ ในไฟล์นั้น) ที่นี่ไม่รู้จักไอเทม ไม่รู้จัก
-- แคตตาล็อก รู้จักแค่ "ได้สตริงรูปมา หรือได้ค่าว่าง" — หน้าไหนจะเอาไปแปะที่ ImageLabel ตัวไหนก็เรื่องของหน้านั้น
local ItemIcon = {}

ItemIcon.Glyph = "⌛"
ItemIcon.GlyphColor = Color3.fromRGB(226, 214, 176)

local GLYPH_NAME = "WOLD_IconGlyph"

-- มีรูปจริงไหม
function ItemIcon.Has(icon)
	return type(icon) == "string" and icon ~= ""
end

-- แปะรูปลง ImageLabel ที่ส่งมา ไม่มีรูปก็แขวน ⌛ ไว้ในนั้นแทน
--
-- **เรียกซ้ำได้** ช่องกระเป๋ากับแถบไอเทมวาดทับตัวเดิมทุกครั้งที่ของเปลี่ยน ไม่ได้สร้างใหม่ — ถ้าไม่เก็บกวาด
-- ป้าย ⌛ ของเดิม ช่องที่เคยว่างจะมีนาฬิกาค้างอยู่ใต้รูปไอเทมชิ้นใหม่ตลอดไป
function ItemIcon.Apply(image, icon)
	if not image then return image end
	local has = ItemIcon.Has(icon)
	image.Image = has and icon or ""

	local glyph = image:FindFirstChild(GLYPH_NAME)
	if has then
		if glyph then glyph:Destroy() end
		return image
	end

	if not glyph then
		glyph = Instance.new("TextLabel")
		glyph.Name = GLYPH_NAME
		glyph.BackgroundTransparency = 1
		-- **เกาะขอบบน สูงครึ่งเดียว ไม่ใช่เต็มกรอบ** หลายหน้าต่าง (กระเป๋า แถบไอเทม หีบ คลัง) ใช้กติกาเดิมว่า
		-- "ไม่มีรูป = โชว์ชื่อไอเทมแทน" ซึ่งยังมีประโยชน์อยู่มาก — สกิน 8 ชิ้นกับออร่า 4 ชิ้นที่เป็น ⌛ เหมือนกันหมด
		-- ถ้าไม่มีชื่อกำกับก็แยกไม่ออกเลย นาฬิกาจึงต้องอยู่เหนือข้อความ ไม่ใช่ทับมัน
		glyph.AnchorPoint = Vector2.new(0.5, 0)
		glyph.Position = UDim2.fromScale(0.5, 0)
		glyph.Size = UDim2.fromScale(1, 0.55)
		glyph.Font = Enum.Font.GothamBold
		glyph.TextScaled = true
		glyph.Text = ItemIcon.Glyph
		glyph.TextColor3 = ItemIcon.GlyphColor
		glyph.Parent = image
	end
	-- ZIndex ตามตัวแม่เสมอ ไม่ใช่ตอนสร้างครั้งเดียว: การ์ดบางใบตั้ง ZIndex ของช่องรูปทีหลัง
	glyph.ZIndex = image.ZIndex
	return image
end

-- **ป้ายสกินมุมล่างซ้าย** (ผู้ใช้สั่ง 2026-09-28: "ติดตั้งสกินใส่อาวุธแล้วมีไอคอนรูปสกินอยู่ตรงล่างซ้ายของรูปไอเทม")
-- `badgeIcon` = รูปของสกินที่ติดอยู่ (`meta.skin` → รูปในแคตตาล็อก ผู้เรียกหาให้ — ที่นี่ไม่รู้จักแคตตาล็อก) ·
-- สกินที่ยังไม่มีรูป ("") ขึ้น 🎨 แทน · nil/false = ไม่มีสกิน ถอดป้ายออก · เรียกซ้ำได้เหมือน Apply (ช่องเดิมถูกวาดทับ)
local BADGE_NAME = "WOLD_SkinBadge"
function ItemIcon.SetBadge(image, badgeIcon)
	if not image then return end
	local badge = image:FindFirstChild(BADGE_NAME)
	if badgeIcon == nil or badgeIcon == false then
		if badge then badge:Destroy() end
		return
	end
	if not badge then
		badge = Instance.new("Frame")
		badge.Name = BADGE_NAME
		badge.AnchorPoint = Vector2.new(0, 1)
		badge.Position = UDim2.fromScale(-0.04, 1.04)
		badge.Size = UDim2.fromScale(0.44, 0.44)
		badge.BackgroundColor3 = Color3.fromRGB(24, 22, 30)
		badge.BackgroundTransparency = 0.1
		badge.Parent = image
		local round = Instance.new("UICorner")
		round.CornerRadius = UDim.new(1, 0)
		round.Parent = badge
		local ring = Instance.new("UIStroke")
		ring.Color = Color3.fromRGB(232, 196, 110)
		ring.Thickness = 1.5
		ring.Parent = badge
		local art = Instance.new("ImageLabel")
		art.Name = "Art"
		art.AnchorPoint = Vector2.new(0.5, 0.5)
		art.Position = UDim2.fromScale(0.5, 0.5)
		art.Size = UDim2.fromScale(0.82, 0.82)
		art.BackgroundTransparency = 1
		art.ScaleType = Enum.ScaleType.Fit
		art.Parent = badge
		local glyph = Instance.new("TextLabel")
		glyph.Name = "Glyph"
		glyph.Size = UDim2.fromScale(1, 1)
		glyph.BackgroundTransparency = 1
		glyph.TextScaled = true
		glyph.Text = "🎨"
		glyph.Parent = badge
	end
	local has = ItemIcon.Has(badgeIcon)
	badge.Art.Image = has and badgeIcon or ""
	badge.Glyph.Visible = not has
	-- เหนือรูปไอเทมเสมอ (บางหน้าต่างตั้ง ZIndex ของช่องรูปทีหลัง)
	badge.ZIndex = image.ZIndex + 1
	badge.Art.ZIndex = image.ZIndex + 2
	badge.Glyph.ZIndex = image.ZIndex + 2
end

-- **🍽️ มุมขวาบน = อาหารที่ตั้งให้กินอัตโนมัติ** (ผู้ใช้สั่ง 2026-10-02) · มุมนี้ว่างในทุกช่อง (ซ้ายล่าง = ป้ายสกิน) ·
-- อีโมจิสี ไม่ใช่สัญลักษณ์ตัวอักษร (✦ ขึ้นเป็นกล่องเปล่าในเกมจริง) · เรียกซ้ำได้
local AUTO_EAT_NAME = "WOLD_AutoEatTag"
function ItemIcon.SetAutoEat(image, on)
	if not image then return end
	local tag = image:FindFirstChild(AUTO_EAT_NAME)
	if not on then
		if tag then tag:Destroy() end
		return
	end
	if not tag then
		tag = Instance.new("TextLabel")
		tag.Name = AUTO_EAT_NAME
		tag.AnchorPoint = Vector2.new(1, 0)
		tag.Position = UDim2.fromScale(1.04, -0.04)
		tag.Size = UDim2.fromScale(0.42, 0.42)
		tag.BackgroundColor3 = Color3.fromRGB(24, 22, 30)
		tag.BackgroundTransparency = 0.15
		tag.TextScaled = true
		tag.Text = "🍽️"
		tag.Parent = image
		local round = Instance.new("UICorner")
		round.CornerRadius = UDim.new(1, 0)
		round.Parent = tag
	end
	tag.ZIndex = image.ZIndex + 1
end

-- จางลงพร้อมกับรูป: แถบไอเทมหรี่ช่องที่ของหมดด้วย ImageTransparency ซึ่งไม่แตะข้อความของ ⌛ เลย
function ItemIcon.SetFade(image, transparency)
	if not image then return end
	image.ImageTransparency = transparency
	local glyph = image:FindFirstChild(GLYPH_NAME)
	if glyph then glyph.TextTransparency = transparency end
	local badge = image:FindFirstChild(BADGE_NAME)
	if badge then
		badge.Art.ImageTransparency = transparency
		badge.Glyph.TextTransparency = transparency
	end
end

return ItemIcon
