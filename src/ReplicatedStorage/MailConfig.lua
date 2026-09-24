-- MailConfig: ตัวเลขของกล่องจดหมายในหินเวท (ผู้ใช้กำหนด 2026-09-24)
-- ดีไซน์: docs/superpowers/specs/2026-09-24-mail-design.md
--
-- ข้อมูลล้วน ไม่ require อะไรเลย — ItemCatalog require ไฟล์นี้ ถ้าวันหนึ่งไฟล์นี้ require กลับ ทั้งคู่จะโหลดไม่ขึ้น
local MailConfig = {}

-- ค่าส่งของผู้เล่นต่อฉบับ เป็นไอเทม (ซิลเวอร์) ไม่ใช่เหรียญทอง · เมลจากระบบ/แอดมินไม่เสีย
MailConfig.FeeItem = "Silver"
MailConfig.Fee = 500

-- กล่องจุกี่ฉบับ เต็มแล้วเมลใหม่ **รอคิว** ใน ProfileStore ไม่หาย แต่ค่าส่งไม่คืน (ส่งไปแล้ว)
MailConfig.BoxSize = 50

-- ความยาวข้อความที่ผู้เล่นพิมพ์แนบ เท่ากับนกพิราบ (SocialConfig.MessageMaxLength)
MailConfig.BodyMaxLength = 200

-- ส่งทางเมลไม่ได้ นอกเหนือจากกฎทั่วไปใน ItemCatalog.IsMailable (กดใช้ได้ · คราฟได้ · bound · กุญแจ)
-- ของผิดกฎหมายคือสามอย่างที่ได้จากฟาร์มเถื่อนทางเดียว — **ถ่านหินไม่อยู่ในนี้** เพราะขุดจากเหมืองได้
MailConfig.Contraband = {
	Chemical = true, GearSpare = true, Blueprint = true, -- ผิดกฎหมาย
	Insignia = true, -- เหรียญค้อนแตก (ได้จากคราฟล้มเหลว)
	Silver = true, -- ค่าส่งเอง ส่งไม่ได้
}

return MailConfig
