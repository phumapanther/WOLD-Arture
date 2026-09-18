-- 69_herb_bushes.lua: ทำให้พุ่มไม้ทั่วแมพเป็นจุดเก็บสมุนไพร
--
-- GatherConfig มีจุดชนิด Herb (พลั่ว 1.5 วิ ได้สมุนไพร 1-2) มาตั้งแต่แรก แต่ไม่เคยมีโมเดลไหนถูกแท็กเป็นมัน —
-- เฟสธรรมชาติแท็กแค่ต้นไม้กับหิน พุ่มไม้ ~5,600 พุ่ม (bush_7990107300_*) วางเป็นของตกแต่งล้วน ผู้ใช้ถือพลั่ว
-- เดินไปหาพุ่มแล้วไม่มีปุ่ม E จึงเป็นเรื่องถูกต้องตามข้อมูล แต่ผิดตามความคาดหวัง
--
-- จับจากแท็ก `Bush` ที่ L.placeAsset ติดให้ทุกพุ่มที่เจน (และติดต่อไปยังตัวที่ผู้ใช้ก๊อปเพราะ Clone พาแท็กไปด้วย)
-- บวกชื่อขึ้นต้น bush_ เผื่อพุ่มที่ถูกวางโดยไม่ผ่านเฟส เลขท้ายชื่อไม่มีความหมาย ไม่ต้องสน
--
-- รันซ้ำได้: แท็กซ้ำไม่มีผล ไม่สร้างหรือลบอะไร
if game.PlaceId ~= 88774255487951 then error("REFUSED: wrong place") end
local CollectionService = game:GetService("CollectionService")

local total, already = 0, 0
for _, d in ipairs(workspace:GetDescendants()) do
	if d:IsA("Model") and (CollectionService:HasTag(d, "Bush") or d.Name:match("^bush_") or d.Name == "Bush") then
		if CollectionService:HasTag(d, "WOLD_Node") then
			already += 1
		else
			total += 1
		end
		d:SetAttribute("NodeKind", "Herb")
		CollectionService:AddTag(d, "WOLD_Node")
	end
end

print(("[HerbBushes] tagged %d new bushes as Herb (%d already tagged)"):format(total, already))
