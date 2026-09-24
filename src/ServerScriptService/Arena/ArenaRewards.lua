-- ArenaRewards.lua: แปลงผลงานในแมตช์เป็นของจริงในเกมหลัก
--
-- **เซิร์ฟแมตช์ไม่เขียนโปรไฟล์ใคร** มันส่งรางวัลเป็นจดหมายเข้าโปรไฟล์ของคนนั้น (`Mail.Send` →
-- ProfileStore:MessageAsync ไม่ต้องเปิดเซสชัน) แล้วเขากดรับในหินเวทเอง — เหตุผลที่ห้ามเปิดเซสชันอยู่ที่หัว
-- `ArenaRegistry`: เซิร์ฟที่เปิดเซสชันโปรไฟล์แล้วเซฟตอนจบ จะทับกระเป๋าจริงของคนเล่นด้วยของในแมตช์
-- · คิว `arenareward_` เก่ายังถูก `PvpRewards.server` อ่านจนว่าง
--
-- ผลพลอยได้ที่ตั้งใจ: คนที่ **ออกจากเกมกลางคัน** ก็ยังได้รางวัลของรอบที่เขาเล่นไปแล้ว เพราะรางวัล
-- ไม่ได้ถูกส่งถึงมือตอนนั้น มันถูกฝากไว้กับชื่อเขา
local ArenaConfig = require(game.ReplicatedStorage.ArenaConfig)
local Mail = require(game.ServerScriptService.Mail)

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
		local exp = (row.won and R.expWin or R.expLoss) + (row.kills or 0) * R.expPerKill
		local chest = R.chestByRank[rank] or R.chestFallback
		row.gold, row.exp, row.chest, row.rank = gold, exp, chest, rank

		-- บอทไม่มี userId จึงไม่มีอะไรให้ส่ง — มันอยู่ในตารางเพื่อให้คนอ่านเห็นว่าใครทำอะไรไว้เท่านั้น
		if row.userId then
			local letter = {
				from = 0, fromName = "สนามประลอง",
				subject = ("รางวัลสนาม PVP — อันดับ %d"):format(rank),
				body = row.won and "ทีมชนะ" or "ทีมแพ้",
				items = chest and { { id = chest, count = 1 } } or {}, gold = gold, exp = exp,
			}
			task.spawn(function()
				if not Mail.Send(row.userId, letter) then
					warn("[ArenaRewards] ส่งรางวัลถึง", row.userId, "ไม่สำเร็จ", gold, exp, chest)
				end
			end)
		end
	end
	return rows
end

return ArenaRewards
