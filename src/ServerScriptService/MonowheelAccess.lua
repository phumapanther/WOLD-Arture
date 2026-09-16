-- MonowheelAccess: ทางเดียวที่โค้ดนอก Monowheel.server จะเรียก/เก็บจักรยานได้
--
-- ทรงเดียวกับ ChestAccess และ MobAccess ด้วยเหตุผลเดียวกัน: ตัวจัดการไอเทมในกระเป๋าต้องสั่งได้โดยไม่ต้อง
-- require สคริปต์ที่เป็นเจ้าของระบบ และระบบนั้นก็ไม่ต้องรู้จักระบบไอเทม
local MonowheelAccess = {}

-- ตั้งโดย Monowheel.server ตอนบูต รับ (player) คืน (ok, ข้อความ) — ไม่มีอยู่ = เรียก, มีอยู่ = เก็บ
-- เป็น nil ในล็อบบี้ ผู้เรียกต้องเช็คก่อนเสมอ
MonowheelAccess.Toggle = nil

return MonowheelAccess
