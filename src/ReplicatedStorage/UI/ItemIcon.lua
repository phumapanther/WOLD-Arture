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

-- จางลงพร้อมกับรูป: แถบไอเทมหรี่ช่องที่ของหมดด้วย ImageTransparency ซึ่งไม่แตะข้อความของ ⌛ เลย
function ItemIcon.SetFade(image, transparency)
	if not image then return end
	image.ImageTransparency = transparency
	local glyph = image:FindFirstChild(GLYPH_NAME)
	if glyph then glyph.TextTransparency = transparency end
end

return ItemIcon
