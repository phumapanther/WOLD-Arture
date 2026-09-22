-- 96_island_crate_vault.lua — ลังไม้บนเกาะ = คลังเก็บของ (คลังเดียวกับมาดามออเรเลียในเกมหลัก)
--
--     WOLD_PLACE=136992335889132 node tools/run-luau.js mapgen/96_island_crate_vault.lua --no-lib
--
-- **ไม่สร้างโมเดล ไม่ย้ายโมเดล** ผู้ใช้วาง `Crate` ไว้เองแล้ว เฟสนี้แค่ติดแท็กให้ — ลากย้ายได้ตลอด
--
-- ## ทำไมแค่ติดแท็กก็พอ
--
-- `BankVault.server` หาที่ทำงานของมันจาก **แท็ก** ไม่ใช่จากชื่อหรือชนิดของโมเดล (`WOLD_Npc` +
-- `NpcKind = "bank"`) ทรงเดียวกับร้านค้าและ NPC อื่นทุกตัว — ลังไม้จึงเป็น "เคาน์เตอร์คลัง" ได้ทันที
-- โดยไม่ต้องมี Humanoid ไม่ต้องเป็นคน
--
-- ## คลังเชื่อมกับเกมหลักอยู่แล้ว ไม่ต้องทำอะไรเพิ่ม
--
-- ของในคลังเก็บที่ `profile.Data.Vault` ซึ่งเป็น **DataStore ก้อนเดียวกันทั้ง universe** (เกาะกับเกมหลัก
-- อยู่ universe 10765335572 เหมือนกัน) ฝากของบนเกาะแล้วไปเบิกที่มาดามออเรเลียได้เลย และกลับกัน
-- — เหมือนกับที่งานเควสและเงินในธนาคารเชื่อมกันอยู่แล้ว
--
-- ต่างจาก **หีบเก็บของ** (`StorageChests`) ซึ่งอยู่ในหน่วยความจำและหายตอนเซิร์ฟปิด — คนละระบบกัน
local CollectionService = game:GetService("CollectionService")

local TAG = "WOLD_Npc"
local NAMES = { "Crate", "Vault_Crate", "Storage_Crate" }

assert(game.PlaceId == 136992335889132 or game.PlaceId == 0, "เฟสนี้สำหรับเพลสเกาะเท่านั้น")

local function status(msg, done)
	local f = workspace:FindFirstChild("WOLD")
	if not f then f = Instance.new("Folder"); f.Name = "WOLD"; f.Parent = workspace end
	f:SetAttribute("Progress", msg)
	f:SetAttribute("Status", done and "done" or "running")
	print("[IslandCrate] " .. msg)
end

-- หาลังที่ **อยู่บนเกาะ** ไม่ใช่ตัวในโชว์รูม (โชว์รูมอยู่ที่ y≈1400 มีลังเป็นของตกแต่งในบ้านหลายใบ)
local crate
for _, name in ipairs(NAMES) do
	for _, m in ipairs(workspace:GetChildren()) do
		if m:IsA("Model") and m.Name == name then
			local y = m:GetPivot().Position.Y
			if y < 1000 then crate = m break end
		end
	end
	if crate then break end
end

if not crate then
	status("ไม่เจอโมเดลลัง (" .. table.concat(NAMES, " / ") .. ") บนเกาะ", true)
	return
end

crate:SetAttribute("NpcKind", "bank")
crate:SetAttribute("NpcName", "ลังเก็บของ")
-- ป้ายปุ่ม: บนเกาะไม่มีธนาคาร มีแต่คลัง — คำว่า "ธนาคาร" จะทำให้คนกดหาเมนูฝากเงินที่ไม่มีประโยชน์ที่นี่
crate:SetAttribute("NpcAction", "เปิดคลัง")
if not CollectionService:HasTag(crate, TAG) then
	CollectionService:AddTag(crate, TAG)
end

local p = crate:GetPivot().Position
status(("done: %s เป็นคลัง ที่ (%.0f, %.0f, %.0f)"):format(crate.Name, p.X, p.Y, p.Z), true)
