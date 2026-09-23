-- Quests.server.lua: บอร์ดเควสหกแห่ง แต่ละแห่งสุ่มงานจากคลังของตัวเอง
--
-- **งานบนบอร์ดเป็นของเซิร์ฟเวอร์ ไม่ใช่ของแต่ละคน** ทุกคนที่เดินมาที่บอร์ดเดียวกันเห็นงานชุดเดียวกัน
-- ซึ่งทำให้ "ไปบอร์ดสโตนมาร์กสิ มีงานขุดทองอยู่" เป็นประโยคที่คุยกันได้ — ถ้าสุ่มรายคน คำแนะนำแบบนั้น
-- จะไม่มีความหมายเลย
--
-- ส่วนงานที่ **รับไปแล้ว** เป็นของแต่ละคน และเซฟติดตัวข้ามเซสชัน
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")

local IslandAccess = require(game.ServerScriptService.Island.IslandAccess)
local ServerConfig = require(game.ServerScriptService.ServerConfig)
if ServerConfig.IsLobby then return end

local QuestConfig = require(game.ReplicatedStorage.QuestConfig)
local ItemCatalog = require(game.ReplicatedStorage.ItemCatalog)
local Inventory = require(game.ServerScriptService.Inventory)
local Progression = require(game.ServerScriptService.Progression)
local ProfileAccess = require(game.ServerScriptService.ProfileAccess)
local QuestAccess = require(game.ServerScriptService.QuestAccess)
local TownAccess = require(game.ServerScriptService.TownAccess)
local ClanConfig = require(game.ReplicatedStorage.ClanConfig)
local Remotes = require(game.ReplicatedStorage.Remotes)

local BOARD_TAG = "WOLD_QuestBoard"
local PROMPT_DISTANCE = 12

--------------------------------------------------------------------------------
-- งานบนบอร์ด
--------------------------------------------------------------------------------

-- [boardId] = { quests = {...}, day = เลขวันที่สุ่มไว้ }
local Posted = {}

local function rollBoard(board, day)
	-- สุ่มหยิบจากคลังโดยไม่ซ้ำ: คัดลอกคลังแล้วหยิบออกทีละอัน
	local pool = {}
	for _, spec in ipairs(board.pool) do pool[#pool + 1] = spec end

	-- **เมล็ดสุ่มจากวันที่และชื่อบอร์ด ไม่ใช่สุ่มลอยๆ**
	--
	-- ทุกเซิร์ฟเวอร์ต้องเห็นบอร์ดชุดเดียวกันในวันเดียวกัน ไม่งั้นย้ายช่องแล้วงานเปลี่ยน และรีสตาร์ทเซิร์ฟ
	-- จะกลายเป็นปุ่มสุ่มงานใหม่ — เมล็ดที่คำนวณได้จากวันที่ทำให้ทุกเซิร์ฟเวอร์ได้ผลเดียวกันโดยไม่ต้องคุยกัน
	local seed = day
	for i = 1, #board.id do seed += board.id:byte(i) * i end
	local rng = Random.new(seed)

	local quests = {}
	for _ = 1, math.min(QuestConfig.SlotsPerBoard, #pool) do
		local pick = table.remove(pool, rng:NextInteger(1, #pool))
		-- จำนวนถูกสุ่มตอนโพสต์ ไม่ใช่ตอนรับ — ทุกคนที่เห็นบอร์ดนี้จึงเห็นเลขเดียวกัน
		local need = rng:NextInteger(pick.min, pick.max)
		quests[#quests + 1] = {
			kind = pick.kind,
			item = pick.item,
			mob = pick.mob,
			need = need,
			gold = pick.gold,
			xp = pick.xp,
			board = board.id,
		}
	end
	Posted[board.id] = { quests = quests, day = day }
	return quests
end

local function boardById(id)
	for _, b in ipairs(QuestConfig.Boards) do
		if b.id == id then return b end
	end
	return nil
end

local function questsOf(boardId)
	local day = QuestConfig.DayNumber()
	local entry = Posted[boardId]
	if not entry or entry.day ~= day then
		local board = boardById(boardId)
		if not board then return {} end
		return rollBoard(board, day)
	end
	return entry.quests
end

--------------------------------------------------------------------------------
-- งานที่รับไปแล้ว
--------------------------------------------------------------------------------

-- เก็บในโปรไฟล์ จึงติดตัวข้ามเซสชัน
local function activeOf(player)
	local data = ProfileAccess.Get(player)
	if not data then return nil end
	data.Quests = data.Quests or {}
	return data.Quests
end

-- งานที่ **ส่งไปแล้ววันนี้** — กันรับซ้ำ
--
-- ของเดิมไม่มีตารางนี้เลย: พอส่งงานเสร็จ ใบนั้นหลุดจากรายการที่ถืออยู่ ตัวกรอง "รับไปแล้วไม่ต้องโชว์ซ้ำ"
-- จึงเลิกกรองมันทันที แล้วใบเดิมก็เด้งกลับขึ้นบอร์ดให้รับใหม่ได้ไม่จำกัดรอบ (ผู้ใช้แจ้ง 2026-09-19)
-- กติกาที่ผู้ใช้ตั้งไว้คือ **เมืองละ 3 งาน วันละครั้ง** ซึ่งบังคับได้ก็ต่อเมื่อจำว่าใครส่งใบไหนไปแล้ว
--
-- **เก็บในโปรไฟล์และล้างตัวเองเมื่อเลขวันเปลี่ยน** ไม่ต้องมีใครมากวาด — เลขวันมาจาก `QuestConfig.DayNumber`
-- ตัวเดียวกับที่บอร์ดใช้สุ่มงาน บอร์ดสุ่มชุดใหม่เมื่อไหร่ สิทธิ์ก็คืนมาพอดีกันเมื่อนั้น
local function doneOf(player)
	local data = ProfileAccess.Get(player)
	if not data then return nil end
	local day = QuestConfig.DayNumber()
	local done = data.QuestsDone
	if type(done) ~= "table" or done.day ~= day then
		done = { day = day, keys = {} }
		data.QuestsDone = done
	end
	done.keys = done.keys or {}
	return done.keys
end

-- กุญแจของงานหนึ่งใบ: เมืองต้นทาง + ชนิด + ของ/มอน
--
-- **ไม่เอา `need` มาเป็นส่วนหนึ่งของกุญแจ** จำนวนเป็นของที่สุ่มมาพร้อมใบ ถ้าเอามาด้วย ใบที่สุ่มจำนวนใหม่
-- จะนับเป็นคนละงานทันที · ใช้เมืองต้นทาง (`q.board`) ไม่ใช่บอร์ดที่ยืนอยู่ งานที่รับจากบอร์ดรวมจึงตัด
-- สิทธิ์ของเมืองนั้นถูกต้อง
local function questKey(q)
	return ("%s|%s|%s"):format(tostring(q.board), tostring(q.kind), tostring(q.item or q.mob))
end

-- ความคืบหน้าของงานหนึ่ง
--
-- **งานเก็บของนับจากกระเป๋าสดๆ ไม่ได้นับสะสม** ของที่มีอยู่แล้วก่อนรับงานจึงใช้ส่งได้ทันที ซึ่งตรงกับ
-- สัญชาตญาณ: ใบประกาศบอกว่า "ต้องการข้าว 10 ถุง" ไม่ได้บอกว่า "ต้องเกี่ยวใหม่ 10 ถุง"
--
-- **งานตกปลานับแบบเดียวกับงานเก็บของ** — ปลาเป็นของในกระเป๋าเหมือนข้าว ผู้ใช้ที่มีหมึก 3 ตัวอยู่แล้วเห็น
-- ใบงานบอก 0/4 แล้วถือว่าเป็นบั๊ก ซึ่งถูกของเขา ต่างจากงานล่าที่นับสะสมจากตอนรับงาน เพราะย้อนดูของเก่า
-- ไม่ได้ — มอนที่ฆ่าไปเมื่อวานไม่เหลือหลักฐาน
local function countsFromBag(quest)
	return quest.kind == "gather" or quest.kind == "fish"
end

local function progressOf(player, quest)
	if countsFromBag(quest) then
		local state = Inventory.Get(player)
		if not state then return 0 end
		local n = 0
		for _, slot in pairs(state.slots) do
			if slot.id == quest.item then n += (slot.count or 1) end
		end
		return n
	end
	return quest.got or 0
end

-- งานสองอันเป็นงานเดียวกันไหม
--
-- **ต้องนิยามก่อน snapshot** local ใน Lua เป็น nil จนกว่าบรรทัดที่ประกาศจะรัน และ snapshot เรียกใช้มัน
-- เพื่อคัดงานที่รับไปแล้วออกจากรายการที่ยังรับได้
local function sameQuest(a, b)
	return a.kind == b.kind and a.item == b.item and a.mob == b.mob and a.need == b.need
end

-- งานทั้งหมดของทุกบอร์ดในวันนี้ พร้อมชื่อเมืองติดมาด้วย
--
-- เรียกใช้ questsOf ของแต่ละบอร์ดตามปกติ จึงได้งานชุดเดียวกับที่คนยืนอยู่หน้าบอร์ดนั้นเห็น
local function allQuests()
	local everything = {}
	for _, board in ipairs(QuestConfig.Boards) do
		for _, q in ipairs(questsOf(board.id)) do
			everything[#everything + 1] = q
		end
	end
	return everything
end

-- ใบที่ "คนนี้ยังรับได้จริง" ที่บอร์ดนี้ — **ที่เดียว** ใช้ทั้งตอนวาดหน้าจอและตอนกดรับ
--
-- สองฝั่งต้องกรองเหมือนกันเป๊ะ เพราะเลขที่ไคลเอนต์ส่งกลับมาคือเลขในรายการ *ที่กรองแล้ว* ของเดิมเขียนตัวกรอง
-- ไว้สองที่ พอวันนี้ต้องเพิ่มเงื่อนไข "ส่งไปแล้ววันนี้" เข้าไป ถ้าเติมข้างเดียวคนกดใบแรกจะได้ใบอื่นแทน
-- โดยไม่มี error ให้เห็น
--
-- คืนจำนวนใบที่ซ่อนเพราะส่งไปแล้วมาด้วย หน้าจอจะได้บอกได้ว่า "ครบแล้ววันนี้" ไม่ใช่ "บอร์ดว่างเปล่า"
local function offeredFor(player, boardId)
	local held = activeOf(player) or {}
	local done = doneOf(player) or {}
	local source = (boardId == QuestConfig.MainBoardId) and allQuests() or questsOf(boardId)

	local offered, finished = {}, 0
	for _, q in ipairs(source) do
		if done[questKey(q)] then
			finished += 1
		else
			local mine = false
			for _, h in ipairs(held) do
				if sameQuest(h, q) then mine = true break end
			end
			if not mine then offered[#offered + 1] = q end
		end
	end
	return offered, finished
end

local function snapshot(player, boardId)
	local isMain = boardId == QuestConfig.MainBoardId
	local board = not isMain and boardById(boardId) or nil
	if not board and not isMain then return nil end

	local function decorate(q)
		local item = q.item and ItemCatalog.Get(q.item)
		local silver, gold = QuestConfig.RewardFor(q)
		return {
			kind = q.kind, item = q.item, mob = q.mob, need = q.need,
			xp = q.xp, board = q.board,
			-- รางวัลจริง ไม่ใช่ค่าความยาก — ใบประกาศต้องบอกสิ่งที่จะได้
			silver = silver, gold = gold,
			-- รูปบนใบประกาศ: งานล่าใช้รูปมอน งานอื่นใช้ไอคอนไอเทม
			icon = (q.kind == "hunt") and (QuestConfig.MobImages[q.mob] or "")
				or (item and item.icon or ""),
			title = (q.kind == "hunt") and q.mob or (item and item.name or q.item),
			text = QuestConfig.Describe(q, item and item.name),
			got = progressOf(player, q),
			-- ชื่อเมืองที่งานนี้มาจาก บอร์ดรวมต้องบอกได้ว่าต้องไปทำที่ไหน
			from = (function()
				for _, b in ipairs(QuestConfig.Boards) do
					if b.id == q.board then return b.name end
				end
				return nil
			end)(),
		}
	end

	local held = activeOf(player) or {}

	local active = {}
	for _, q in ipairs(held) do active[#active + 1] = decorate(q) end

	-- **ไม่โชว์งานที่รับไปแล้วซ้ำในช่องที่ยังไม่รับ และไม่โชว์งานที่ส่งไปแล้ววันนี้เลย**
	--
	-- บอร์ดเป็นของเซิร์ฟเวอร์ งานยังอยู่บนบอร์ดหลังมีคนรับ (คนอื่นก็รับได้) แต่สำหรับ *คนที่รับไปแล้ว*
	-- มันไม่ใช่ใบประกาศที่รับได้อีก มันคืองานที่กำลังทำอยู่ — การโชว์ทั้งสองที่ทำให้เห็นงานเดียวกันสองใบ
	local raw, finished = offeredFor(player, boardId)
	local offered = {}
	for _, q in ipairs(raw) do offered[#offered + 1] = decorate(q) end

	return {
		-- ส่งครบแล้วกี่ใบวันนี้ หน้าจอใช้แยก "บอร์ดว่าง" ออกจาก "ทำครบแล้ว รอพรุ่งนี้"
		finishedToday = finished,
		boardId = boardId,
		boardName = isMain and QuestConfig.MainBoardName or board.name,
		blurb = isMain and QuestConfig.MainBoardBlurb or board.blurb,
		isMain = isMain,
		notice = QuestConfig.NoticeImage,
		offered = offered,
		active = active,
		maxActive = QuestConfig.MaxActive,
	}
end

--------------------------------------------------------------------------------
-- รับ / ส่ง / ทิ้ง
--------------------------------------------------------------------------------

local function accept(player, boardId, index)
	local list = activeOf(player)
	if not list then return end
	if #list >= QuestConfig.MaxActive then
		return Remotes.SocialNotify:FireClient(player, "warn",
			("รับได้สูงสุด %d งาน"):format(QuestConfig.MaxActive))
	end

	-- **รายการเดียวกับที่ไคลเอนต์เห็น ไม่ใช่รายการดิบของบอร์ด**
	--
	-- หน้าจอโชว์เฉพาะใบที่ยังรับได้ (กรองใบที่ถืออยู่และใบที่ส่งไปแล้ววันนี้ออก) เลขที่ส่งกลับมาจึงเป็นเลข
	-- ของรายการที่กรองแล้ว ถ้าเอาไปเปิดรายการดิบตรงๆ คนที่ถืองานอยู่หนึ่งใบจะกดใบแรกแล้วได้ใบที่สองแทน
	--
	-- บอร์ดรวมยิ่งชัด: เลขของมันมาจากงานทุกเมืองต่อกัน ซึ่งไม่ตรงกับบอร์ดไหนเลย
	local offered = offeredFor(player, boardId)

	local quest = offered[index]
	if not quest then return end

	-- คัดลอก ไม่ได้อ้างถึงตัวเดียวกับบอร์ด: บอร์ดสุ่มใหม่ทุกวัน งานที่รับไปแล้วต้องไม่หายไปด้วย
	list[#list + 1] = {
		kind = quest.kind, item = quest.item, mob = quest.mob, need = quest.need,
		gold = quest.gold, xp = quest.xp, board = quest.board, got = 0,
	}
	Remotes.SocialNotify:FireClient(player, "info", "รับงานแล้ว")
	Remotes.QuestUpdate:FireClient(player, snapshot(player, boardId))
end

local function abandon(player, boardId, index)
	local list = activeOf(player)
	if not list or not list[index] then return end
	table.remove(list, index)
	Remotes.SocialNotify:FireClient(player, "info", "ยกเลิกงานแล้ว")
	Remotes.QuestUpdate:FireClient(player, snapshot(player, boardId))
end

local function turnIn(player, boardId, index)
	local list = activeOf(player)
	local quest = list and list[index]
	if not quest then return end

	local got = progressOf(player, quest)
	if got < quest.need then
		return Remotes.SocialNotify:FireClient(player, "warn",
			("ยังไม่ครบ (%d/%d)"):format(got, quest.need))
	end

	local silver, gold = QuestConfig.RewardFor(quest)

	-- **ซิลเวอร์คูณสองถ้าแคลนตัวเองยึดเมืองที่งานนี้มาจาก** ตามที่ผู้ใช้กำหนด
	--
	-- คิดจาก `quest.board` ซึ่งเป็นเมืองต้นทางของงาน ไม่ใช่บอร์ดที่ยืนส่งอยู่ — งานจากบอร์ดรวมจึงยังได้
	-- โบนัสของเมืองที่มันมาจากอย่างถูกต้อง
	if TownAccess.IsHome and quest.board and TownAccess.IsHome(player, quest.board) then
		silver = silver * ClanConfig.QuestSilverMultiplier
	end

	-- **เช็คที่ว่างก่อนแตะอะไรทั้งนั้น**
	--
	-- ลำดับสำคัญมาก: ถ้าเอาของออกจากกระเป๋าก่อนแล้วค่อยพบว่ารับซิลเวอร์ไม่ได้ ผู้เล่นจะเสียของที่ส่งไป
	-- โดยไม่ได้อะไรเลย — งานเก็บของมักทำให้มีช่องว่างพอดีหลังส่ง จึงเป็นเคสที่เกิดขึ้นจริงได้ง่าย
	--
	-- HasRoomFor ถามโดยไม่เปลี่ยนอะไร จึงถามได้ก่อนตัดสินใจ
	if not Inventory.HasRoomFor(player, "Silver", silver) then
		return Remotes.SocialNotify:FireClient(player, "error",
			("กระเป๋าเต็ม รับเหรียญซิลเวอร์ %d ไม่ได้ — ว่างช่องก่อนแล้วมาส่งใหม่"):format(silver))
	end

	-- งานเก็บของ/ตกปลา: เอาของออกจากกระเป๋าจริงๆ
	if countsFromBag(quest) then
		-- ทั้งหมดหรือไม่เอาเลย — ของเดิมลบไปก่อนแล้วค่อยบอกว่าไม่พอ ผู้เล่นเสียของฟรี
		if not Inventory.RemoveById(player, quest.item, quest.need) then
			return Remotes.SocialNotify:FireClient(player, "error", "ของไม่พอ")
		end
	end

	Inventory.AddItem(player, "Silver", silver)
	table.remove(list, index)

	-- **ปั๊มตราว่าใบนี้ของเมืองนี้ส่งไปแล้ววันนี้** ต้องอยู่หลังจ่ายรางวัลสำเร็จ ไม่ใช่ตอนกด — ทางออกก่อนหน้านี้
	-- (ของไม่ครบ กระเป๋าเต็ม) ต้องไม่กินสิทธิ์ของวันนั้นไป
	local done = doneOf(player)
	if done then done[questKey(quest)] = true end
	if gold > 0 then Inventory.AddGold(player, gold) end
	if quest.xp and quest.xp > 0 then Progression.AwardExp(player, quest.xp) end

	Remotes.SocialNotify:FireClient(player, "info",
		("ส่งงานสำเร็จ +%d ซิลเวอร์ +%d เหรียญ +%d EXP"):format(silver, gold, quest.xp or 0))
	Remotes.QuestUpdate:FireClient(player, snapshot(player, boardId))
end

--------------------------------------------------------------------------------
-- นับความคืบหน้าจากภายนอก
--------------------------------------------------------------------------------

-- เรียกโดย Mobs ตอนฆ่ามอน และ Fishing ตอนตกปลาได้
local function bump(player, kind, key)
	local list = activeOf(player)
	if not list then return end
	local changed = false
	for _, quest in ipairs(list) do
		if quest.kind == kind and (quest.mob == key or quest.item == key) then
			if (quest.got or 0) < quest.need then
				quest.got = (quest.got or 0) + 1
				changed = true
				if quest.got >= quest.need then
					Remotes.SocialNotify:FireClient(player, "info", "งานครบแล้ว กลับไปส่งที่บอร์ด")
				end
			end
		end
	end
	return changed
end

QuestAccess.RecordKill = function(player, mobName) bump(player, "hunt", mobName) end
-- ปลานับจากกระเป๋าแล้ว (progressOf) จึงไม่ต้องนับสะสมอีก คงชื่อไว้ให้ Fishing เรียกได้เหมือนเดิม
QuestAccess.RecordCatch = function() end

--------------------------------------------------------------------------------
-- ปุ่มที่บอร์ด
--------------------------------------------------------------------------------

local Viewing = {} -- [player] = boardId

local wired = {}

local function wire(model)
	if wired[model] or not model.Parent then return end
	local boardId = model:GetAttribute("BoardId")
	if not boardId then return end

	-- **แขวนปุ่มที่ชิ้นที่ใหญ่ที่สุด ไม่ใช่ PrimaryPart**
	--
	-- PrimaryPart ของบอร์ดคือ `Root` ซึ่งเป็นลูกบาศก์ล่องหน 1x1 ที่ก้นโมเดล ปุ่มที่แขวนตรงนั้นจะอยู่
	-- ระดับพื้นและอยู่ห่างจากหน้ากระดานที่ผู้เล่นเดินเข้าไปหา — ซึ่งเป็นเหตุผลที่กดไม่ติด
	--
	-- ชิ้นใหญ่สุดของโมเดลนี้คือเสาสูง 10 studs ที่ระดับอก ปุ่มจึงไปอยู่ตรงที่คนมองหาพอดี
	local anchor
	local bestVolume = 0
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			local v = d.Size.X * d.Size.Y * d.Size.Z
			if v > bestVolume then anchor, bestVolume = d, v end
		end
	end
	if not anchor then return end
	wired[model] = true

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "QuestPrompt"
	prompt.ActionText = "ดูงาน"
	prompt.ObjectText = "บอร์ดเควส"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = PROMPT_DISTANCE
	prompt.RequiresLineOfSight = false
	prompt.Parent = anchor

	prompt.Triggered:Connect(function(player)
		-- แขกบนเกาะของคนอื่นใช้บอร์ดเควสของเจ้าบ้านไม่ได้ (ผู้ใช้สั่ง 2026-09-23)
		if not IslandAccess.MayUseFixtures(player) then
			return Remotes.SocialNotify:FireClient(player, "warn", IslandAccess.FixtureDenied)
		end
		Viewing[player] = boardId
		Remotes.QuestUpdate:FireClient(player, snapshot(player, boardId))
	end)
end

Remotes.RequestQuestAction.OnServerEvent:Connect(function(player, action, index)
	local boardId = Viewing[player]
	if not boardId then return end
	index = math.floor(tonumber(index) or 0)
	if index < 1 then return end

	if action == "accept" then accept(player, boardId, index)
	elseif action == "turnin" then turnIn(player, boardId, index)
	elseif action == "abandon" then abandon(player, boardId, index)
	elseif action == "close" then
		-- เลิกดูแล้ว ปล่อยให้ลืมไปว่ายืนอยู่บอร์ดไหน — ไม่งั้นเดินไปไกลแล้วยังส่งงานที่บอร์ดเดิมได้อยู่
		Viewing[player] = nil
	elseif action == "refresh" then
		Remotes.QuestUpdate:FireClient(player, snapshot(player, boardId))
	end
end)

Players.PlayerRemoving:Connect(function(player)
	Viewing[player] = nil
end)

-- ลูปถามใหม่ กฎเหล็กของโปรเจ็ค: บอร์ดมาถึงคนละรอบกับสคริปต์
task.spawn(function()
	while true do
		for _, model in ipairs(CollectionService:GetTagged(BOARD_TAG)) do
			if model:IsA("Model") then wire(model) end
		end
		task.wait(0.5)
	end
end)

CollectionService:GetInstanceAddedSignal(BOARD_TAG):Connect(function(model)
	if model:IsA("Model") then wire(model) end
end)

--------------------------------------------------------------------------------
-- ช่องเทสใน Studio
--------------------------------------------------------------------------------

-- ทรงเดียวกับ ServerStorage.IslandTest: `execute_luau` ของ MCP รันใน sandbox ที่ `require` ได้สำเนาใหม่
-- ของทุกโมดูล (QuestAccess ที่มันเห็นจึงเป็นตารางว่าง) ส่วน BindableFunction เป็น instance จึงข้าม
-- sandbox ได้ และ callback รันในบริบทของไฟล์นี้ — เทส tests/island_quest_test.lua ใช้ทางนี้
--
-- Studio เท่านั้น เซิร์ฟเวอร์จริงไม่มีช่องนี้
if game:GetService("RunService"):IsStudio() then
	local bf = Instance.new("BindableFunction")
	bf.Name = "QuestTest"
	bf.OnInvoke = function(op, ...)
		if op == "Snapshot" then return snapshot(...) end
		if op == "Offered" then return (offeredFor(...)) end
		if op == "Key" then return questKey(...) end
		-- โปรไฟล์: sandbox require ProfileAccess ได้สำเนาว่าง จึงต้องผ่านทางนี้เหมือนกัน
		if op == "Held" then return activeOf(...) end
		if op == "AddHeld" then
			local player, quest = ...
			local list = activeOf(player)
			if not list then return false end
			list[#list + 1] = quest
			return #list
		end
		if op == "DropHeld" then
			local player, n = ...
			local list = activeOf(player)
			if not list then return false end
			for i = #list, (n or 1) + 1, -1 do table.remove(list, i) end
			return #list
		end
		if op == "MarkDone" then
			local player, k, on = ...
			local done = doneOf(player)
			if not done then return false end
			done[k] = on or nil
			return true
		end
		error("QuestTest: ไม่มี op " .. tostring(op))
	end
	bf.Parent = game:GetService("ServerStorage")
end
