-- 65_storage_chests.lua — ติดแท็กหีบตกแต่งในเมืองให้กลายเป็นหีบเก็บของจริง
--
-- รัน: node tools/run-luau.js mapgen/65_storage_chests.lua
--
-- **รันซ้ำได้** ติดแท็กซ้ำไม่มีผล และ StorageChests.server จะติดปุ่ม E ให้เองเมื่อเห็นแท็ก
--
-- หีบพวกนี้มาจากชุดโมเดลของเมือง (119 ใบตอนเขียน) เดิมเป็นของตกแต่งล้วน ไม่มีปุ่ม ไม่มีแท็ก
local CollectionService = game:GetService("CollectionService")

local CHEST_TAG = "WOLD_StorageChest"

-- ชื่อโมเดลที่ถือว่าเป็นหีบเก็บของ
--
-- เอาเฉพาะ "Chest" ล้วนๆ ไม่รวม Crate/Barrel/Box ซึ่งมีรวมกันพันกว่าใบ — ถ้าเปิดได้หมดทุกลัง เมืองจะ
-- กลายเป็นทุ่งกล่องที่กด E ได้ทุกอัน และปุ่มจะบังกันเองจนกดอะไรไม่ถูก
--
-- **ยกเว้น Tomb_Chest** ซึ่งเป็นโมเดลใหญ่ 24 studs ในสุสาน เป็นฉาก ไม่ใช่เฟอร์นิเจอร์
local NAMES = {
	Chest = true,
}
local SKIP = {
	Tomb_Chest = true,
	ChestReactor = true, -- ชิ้นส่วนของเครื่องจักร ไม่ใช่หีบ
}

local tagged, already = 0, 0

for _, d in ipairs(workspace:GetDescendants()) do
	if d:IsA("Model") and NAMES[d.Name] and not SKIP[d.Name] then
		-- ต้องมีชิ้นส่วนสักชิ้นให้แขวนปุ่ม ไม่งั้นติดแท็กไปก็ไม่มีอะไรเกิดขึ้น
		local hasPart = d.PrimaryPart ~= nil
		if not hasPart then
			for _, c in ipairs(d:GetDescendants()) do
				if c:IsA("BasePart") then hasPart = true break end
			end
		end

		if hasPart then
			if CollectionService:HasTag(d, CHEST_TAG) then
				already += 1
			else
				CollectionService:AddTag(d, CHEST_TAG)
				tagged += 1
			end
		end
	end
end

print(("[StorageChests] ติดแท็กใหม่ %d ใบ | มีอยู่แล้ว %d ใบ | รวม %d ใบ")
	:format(tagged, already, tagged + already))
