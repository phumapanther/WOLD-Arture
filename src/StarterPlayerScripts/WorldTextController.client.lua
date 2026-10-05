-- ป้ายในโลกที่เซิร์ฟสร้างเป็นไทย (มอนหลบ "หลบ!" · ชื่อปลาบนการ์ดตกปลา) ติดแท็ก WOLD_ShowText ไว้
-- เครื่องนี้แปลเป็นภาษาผู้เล่นทุกครั้งที่ข้อความเปลี่ยน · ค่าที่ไคลเอนต์เขียนไม่ replicate กลับ · ไทย = ไม่แตะ
-- ป้ายใหม่ที่เซิร์ฟสร้างแล้วอยากให้แปล: ติดแท็กนี้ที่ TextLabel อย่างเดียว
local CollectionService = game:GetService("CollectionService")
local Locale = require(game:GetService("ReplicatedStorage"):WaitForChild("Locale"))

local function hook(label)
	if not label:IsA("TextLabel") then return end
	local function apply()
		local shown = Locale.Show(label.Text)
		if shown ~= label.Text then label.Text = shown end
	end
	label:GetPropertyChangedSignal("Text"):Connect(apply)
	apply()
end

CollectionService:GetInstanceAddedSignal("WOLD_ShowText"):Connect(hook)
for _, label in ipairs(CollectionService:GetTagged("WOLD_ShowText")) do hook(label) end
