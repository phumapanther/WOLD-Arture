-- Quests.server.lua: บอร์ดเควสหกแห่ง แต่ละแห่งสุ่มงานจากคลังของตัวเอง
--
-- **งานบนบอร์ดเป็นของเซิร์ฟเวอร์ ไม่ใช่ของแต่ละคน** ทุกคนที่เดินมาที่บอร์ดเดียวกันเห็นงานชุดเดียวกัน
-- ซึ่งทำให้ "ไปบอร์ดสโตนมาร์กสิ มีงานขุดทองอยู่" เป็นประโยคที่คุยกันได้ — ถ้าสุ่มรายคน คำแนะนำแบบนั้น
-- จะไม่มีความหมายเลย
--
-- ส่วนงานที่ **รับไปแล้ว** เป็นของแต่ละคน และเซฟติดตัวข้ามเซสชัน
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")

local ServerConfig = require(game.ServerScriptService.ServerConfig)
if ServerConfig.IsLobby then return end

local QuestConfig = require(game.ReplicatedStorage.QuestConfig)
local ItemCatalog = require(game.ReplicatedStorage.ItemCatalog)
local Inventory = require(game.ServerScriptService.Inventory)
local Progression = require(game.ServerScriptService.Progression)
local ProfileAccess = require(game.ServerScriptService.ProfileAccess)
local QuestAccess = require(game.ServerScriptService.QuestAccess)
local Remotes = require(game.ReplicatedStorage.Remotes)

local BOARD_TAG = "WOLD_QuestBoard"
local PROMPT_DISTANCE = 12

--------------------------------------------------------------------------------
-- งานบนบอร์ด
--------------------------------------------------------------------------------

-- [boardId] = { quests = {...}, rerollAt = os.clock() }
local Posted = {}

local function rollBoard(board)
	-- สุ่มหยิบจากคลังโดยไม่ซ้ำ: คัดลอกคลังแล้วหยิบออกทีละอัน
	local pool = {}
	for _, spec in ipairs(board.pool) do pool[#pool + 1] = spec end

	local quests = {}
	for _ = 1, math.min(QuestConfig.SlotsPerBoard, #pool) do
		local pick = table.remove(pool, math.random(#pool))
		-- จำนวนถูกสุ่มตอนโพสต์ ไม่ใช่ตอนรับ — ทุกคนที่เห็นบอร์ดนี้จึงเห็นเลขเดียวกัน
		local need = math.random(pick.min, pick.max)
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
	Posted[board.id] = { quests = quests, rerollAt = os.clock() + QuestConfig.RerollSeconds }
	return quests
end

local function boardById(id)
	for _, b in ipairs(QuestConfig.Boards) do
		if b.id == id then return b end
	end
	return nil
end

local function questsOf(boardId)
	local entry = Posted[boardId]
	if not entry or os.clock() >= entry.rerollAt then
		local board = boardById(boardId)
		if not board then return {} end
		return rollBoard(board)
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

-- ความคืบหน้าของงานหนึ่ง
--
-- **งานเก็บของนับจากกระเป๋าสดๆ ไม่ได้นับสะสม** ของที่มีอยู่แล้วก่อนรับงานจึงใช้ส่งได้ทันที ซึ่งตรงกับ
-- สัญชาตญาณ: ใบประกาศบอกว่า "ต้องการข้าว 10 ถุง" ไม่ได้บอกว่า "ต้องเกี่ยวใหม่ 10 ถุง"
--
-- ส่วนงานล่าและงานตกปลานับสะสมจากตอนรับงาน เพราะย้อนดูของเก่าไม่ได้ — มอนที่ฆ่าไปเมื่อวานไม่เหลือหลักฐาน
local function progressOf(player, quest)
	if quest.kind == "gather" then
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

local function snapshot(player, boardId)
	local board = boardById(boardId)
	if not board then return nil end

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
		}
	end

	local offered = {}
	for _, q in ipairs(questsOf(boardId)) do offered[#offered + 1] = decorate(q) end

	local active = {}
	for _, q in ipairs(activeOf(player) or {}) do active[#active + 1] = decorate(q) end

	return {
		boardId = boardId,
		boardName = board.name,
		blurb = board.blurb,
		notice = QuestConfig.NoticeImage,
		offered = offered,
		active = active,
		maxActive = QuestConfig.MaxActive,
	}
end

--------------------------------------------------------------------------------
-- รับ / ส่ง / ทิ้ง
--------------------------------------------------------------------------------

local function sameQuest(a, b)
	return a.kind == b.kind and a.item == b.item and a.mob == b.mob and a.need == b.need
end

local function accept(player, boardId, index)
	local list = activeOf(player)
	if not list then return end
	if #list >= QuestConfig.MaxActive then
		return Remotes.SocialNotify:FireClient(player, "warn",
			("รับได้สูงสุด %d งาน"):format(QuestConfig.MaxActive))
	end

	local quests = questsOf(boardId)
	local quest = quests[index]
	if not quest then return end

	for _, held in ipairs(list) do
		if sameQuest(held, quest) then
			return Remotes.SocialNotify:FireClient(player, "warn", "รับงานนี้ไปแล้ว")
		end
	end

	-- คัดลอก ไม่ได้อ้างถึงตัวเดียวกับบอร์ด: บอร์ดสุ่มใหม่ทุกครึ่งชั่วโมง งานที่รับไปแล้วต้องไม่หายไปด้วย
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

	-- งานเก็บของ: เอาของออกจากกระเป๋าจริงๆ
	if quest.kind == "gather" then
		local left = quest.need
		local state = Inventory.Get(player)
		if not state then return end
		-- ไล่จากช่องท้ายมาหน้า เพราะการลบทำให้ index ขยับ
		for i = #state.slots, 1, -1 do
			if left <= 0 then break end
			local slot = state.slots[i]
			if slot and slot.id == quest.item then
				local take = math.min(left, slot.count or 1)
				Inventory.RemoveFromSlot(player, i, take)
				left -= take
			end
		end
		if left > 0 then
			return Remotes.SocialNotify:FireClient(player, "error", "ของไม่พอ")
		end
	end

	Inventory.AddItem(player, "Silver", silver)
	table.remove(list, index)
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
QuestAccess.RecordCatch = function(player, itemId) bump(player, "fish", itemId) end

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
