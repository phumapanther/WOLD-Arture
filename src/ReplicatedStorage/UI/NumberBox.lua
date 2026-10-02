-- NumberBox: ช่องกรอกตัวเลขที่มีเพดาน (ผู้ใช้สั่ง 2026-10-02) — พิมพ์เกินที่มีอยู่ = เด้งเป็นเลขสูงสุดให้เองทันที
-- (มีเงิน 4,000 พิมพ์ 30000 → 4000) · ตัวอักษรที่ไม่ใช่ตัวเลขถูกตัดทิ้ง · ใช้กับทุกช่องจำนวน/เงินในเกม
-- เป็นการช่วยคนพิมพ์เท่านั้น เซิร์ฟตรวจจำนวนเองทุกคำขอเหมือนเดิม
local NumberBox = {}

local MAX_DIGITS = 12 -- ยาวกว่านี้ tonumber กลายเป็น 1e+20 แล้วตัดตัวอักษรต่อไม่ได้

-- กติกาล้วน (เทส number_box_test): ข้อความที่พิมพ์ + เพดาน → ข้อความที่ควรอยู่ในช่อง · max = nil = ไม่มีเพดาน
function NumberBox.Clean(text, max)
	local digits = tostring(text or ""):gsub("%D", ""):sub(1, MAX_DIGITS)
	if digits == "" then return "" end
	local n = tonumber(digits)
	if max and n > max then n = math.max(0, math.floor(max)) end
	return ("%d"):format(n)
end

-- ตัวเลขในช่อง · ช่องว่าง = nil
function NumberBox.Value(text)
	return tonumber(NumberBox.Clean(text))
end

-- ผูกกับ TextBox · getMax() ถามทุกครั้งที่พิมพ์ (เงิน/ของเปลี่ยนได้ระหว่างหน้าต่างเปิดอยู่) · คืน connection
function NumberBox.Bind(box, getMax)
	return box:GetPropertyChangedSignal("Text"):Connect(function()
		local want = NumberBox.Clean(box.Text, getMax and getMax())
		if want ~= box.Text then box.Text = want end
	end)
end

return NumberBox
