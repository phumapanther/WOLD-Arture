-- ArenaRewards.lua: แปลงผลงานในแมตช์เป็นของจริงในเกมหลัก
--
-- **เซิร์ฟแมตช์ไม่เขียนโปรไฟล์ใคร** มันฝากรางวัลไว้ใน `ArenaRegistry` แล้วเกมหลักมารับเองตอนคนนั้น
-- เข้าเกมครั้งถัดไป (`PvpRewards.server.lua` ฝั่งเพลสหลัก) — เหตุผลอยู่ที่หัว `ArenaRegistry`:
-- เซิร์ฟที่เปิดเซสชันโปรไฟล์แล้วเซฟตอนจบ จะทับกระเป๋าจริงของคนเล่นด้วยของในแมตช์
--
-- ผลพลอยได้ที่ตั้งใจ: คนที่ **ออกจากเกมกลางคัน** ก็ยังได้รางวัลของรอบที่เขาเล่นไปแล้ว เพราะรางวัล
-- ไม่ได้ถูกส่งถึงมือตอนนั้น มันถูกฝากไว้กับชื่อเขา
local ArenaConfig = require(game.ReplicatedStorage.ArenaConfig)
local ArenaRegistry = require(game.ServerScriptService.Lobby.ArenaRegistry)

local ArenaRewards = {}

-- `rows` = ตารางอันดับที่ `ArenaMatch` สร้างไว้แล้ว (เรียงจากอันดับ 1) แต่ละแถวมี
--   { userId, name, kills, deaths, assists, damage, side, won }
--
-- คืนรายการเดิมพร้อมช่อง `gold` กับ `chest` เติมเข้าไป เพื่อให้หน้าตารางจบเกมโชว์รางวัลที่ได้จริง
-- **ตัวเลขที่โชว์กับตัวเลขที่ฝาก ต้องมาจากการคำนวณครั้งเดียวกัน** ไม่งั้นวันหนึ่งมันจะไม่ตรงกัน
function ArenaRewards.Grant(rows)
	local R = ArenaConfig.Rewards
	for rank, row in ipairs(rows) do
		local gold = (row.won and R.goldWin or R.goldLoss) + (row.kills or 0) * R.goldPerKill
		local chest = R.chestByRank[rank] or R.chestFallback
		row.gold, row.chest, row.rank = gold, chest, rank

		-- บอทไม่มี userId จึงไม่มีอะไรให้ฝาก — มันอยู่ในตารางเพื่อให้คนอ่านเห็นว่าใครทำอะไรไว้เท่านั้น
		if row.userId then
			ArenaRegistry.QueueReward(row.userId, { gold = gold, chest = chest, rank = rank })
		end
	end
	return rows
end

return ArenaRewards
