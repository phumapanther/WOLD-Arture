-- BagRanges: ของชิ้นนี้อยู่ช่วงช่องไหนของกระเป๋า (หลัก 1..SlotCount / VIP VipSlotStart..VipSlotEnd)
-- เกณฑ์เดียวกับแท็บบนหน้าจอเป๊ะ (`InventoryGui.IsFarmItem`: `vip = true` หรือ `kind == "placeable"`)
-- ไม่งั้นของจะไปลงช่องที่แท็บนั้นมองไม่เห็น แล้วอ่านเหมือนของหาย
--
-- ยกออกจาก Inventory (QA 2026-09-26) ให้เทรดถามที่เดียวกันและเทสได้ (`tests/bag_ranges_test.lua`)
-- เฟส 2b: ของขอบทอง (`meta.gold`) ไปช่อง VIP เสมอ ไม่ว่าของชนิดนั้นปกติอยู่ฝั่งไหน
local ItemCatalog = require(game.ReplicatedStorage.ItemCatalog)
local InventoryConfig = require(game.ReplicatedStorage.InventoryConfig)

local BagRanges = {}

function BagRanges.For(id, meta)
	-- เงื่อนไขเดียวกับ ItemCatalog.IsGoldBorder (ตัวนิยาม) เขียนตรงนี้เพราะเทสใน Edit โหลดไฟล์นี้กับ ItemCatalog
	-- ที่ Studio แคชไว้ (require ด้วยพาธเต็ม) — ถ้าวันไหนเปลี่ยนนิยามขอบทอง ต้องแก้สองที่นี้ด้วยกัน
	if type(meta) == "table" and meta.gold == true then
		return InventoryConfig.VipSlotStart, InventoryConfig.VipSlotEnd
	end
	local item = ItemCatalog.Get(id)
	if item and (item.vip == true or item.kind == "placeable") then
		return InventoryConfig.VipSlotStart, InventoryConfig.VipSlotEnd
	end
	return 1, InventoryConfig.SlotCount
end

-- แลกของแล้วรับไหวไหม: นับช่องว่างแยกฝั่ง ของที่ให้ออกไปปลดช่องในฝั่งของมันเอง
-- `giving`/`receiving` = { { id, meta } } ช่องละหนึ่งแถว (เทรดย้ายทั้งช่องเสมอ)
function BagRanges.SwapFits(slots, giving, receiving)
	local need = {}
	local function tally(list, sign)
		for _, e in ipairs(list) do
			local from, to = BagRanges.For(e.id, e.meta)
			local r = need[from] or { from = from, to = to, n = 0 }
			r.n += sign
			need[from] = r
		end
	end
	tally(receiving, 1)
	tally(giving, -1)
	for _, r in pairs(need) do
		local free = 0
		for i = r.from, r.to do
			if not slots[i] then free += 1 end
		end
		if free < r.n then return false end
	end
	return true
end

return BagRanges
