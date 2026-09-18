-- MagicBox: กล่องเวทมนตร์ — สุ่ม "ทุกอย่างที่มีในเซิร์ฟ" ตามเรทหมวดใน PremiumConfig.MagicBox
--
-- สระแต่ละหมวดสร้างจาก ItemCatalog ตอนเรียก ไม่ได้เขียนรายชื่อตายตัว: ไอเทมใหม่ที่เพิ่มเข้าแคตตาล็อก
-- จึงเข้ากล่องเองตามชนิดของมัน ยกเว้นของประจำตำแหน่ง กุญแจ กล่องเวทมนตร์เอง และหีบ (หีบในกล่องคือกล่องในกล่อง)
local ItemCatalog = require(game.ReplicatedStorage.ItemCatalog)
local PremiumConfig = require(game.ReplicatedStorage.PremiumConfig)

local MagicBox = {}

local ILLEGAL = {}
for _, id in ipairs(PremiumConfig.MagicBoxIllegal) do ILLEGAL[id] = true end

local function poolFor(category)
	local pool = {}
	for id, item in pairs(ItemCatalog.Items) do
		local ok = false
		if item.bound or item.kind == "key" or id == "MagicBox" or id:match("^Chest_") then
			ok = false
		elseif category == "farm" then
			ok = item.kind == "junk" and item.sellable ~= false and not ILLEGAL[id]
		elseif category == "illegal" then
			ok = ILLEGAL[id] == true
		elseif category == "consumable" then
			ok = item.kind == "consumable"
		elseif category == "weapon" then
			ok = item.kind == "weapon" or item.kind == "armor"
		elseif category == "vehicle" then
			for _, v in ipairs(PremiumConfig.MagicBoxVehicles) do
				if v == id then ok = true end
			end
		elseif category == "skin" then
			ok = item.kind == "skin" or item.kind == "fashion" or item.kind == "aura"
		end
		if ok then pool[#pool + 1] = id end
	end
	table.sort(pool)
	return pool
end

-- คืน { id, count } ที่สุ่มได้ หรือ nil ถ้าหมวดที่ออกไม่มีของเลย
function MagicBox.Roll()
	local total = 0
	for _, c in ipairs(PremiumConfig.MagicBox) do total += c.weight end
	local pick = math.random() * total
	local chosen = PremiumConfig.MagicBox[#PremiumConfig.MagicBox]
	for _, c in ipairs(PremiumConfig.MagicBox) do
		pick -= c.weight
		if pick <= 0 then chosen = c break end
	end
	local pool = poolFor(chosen.id)
	if #pool == 0 then pool = poolFor("farm") end
	if #pool == 0 then return nil end
	local id = pool[math.random(1, #pool)]
	local item = ItemCatalog.Get(id)
	local lo, hi = chosen.count[1], chosen.count[2]
	-- ของที่สแตคไม่ได้ (อาวุธ สกิน) ออกทีละชิ้นเสมอ
	local count = (item.stackSize or 1) > 1 and math.random(lo, hi) or 1
	return { id = id, count = count, category = chosen.id }
end

return MagicBox
