-- WorldBoss.server.lua: บอสโลก — ตื่นตามนาฬิกา อยู่ได้ตามเวลา แล้วจ่ายรางวัลตามดาเมจที่แต่ละคนทำไว้
--
-- ผู้ใช้กำหนด (2026-09-20):
--   เกิดสองทุ่ม · ประกาศตอนเกิด · อยู่ 59 นาที · รางวัลเรียงจากคนทำดาเมจมากสุดไปน้อยสุด ·
--   **บอสไม่ต้องตายก็ได้** ถ้าตาย อีเวนต์จบทันที · หมดเวลา อีเวนต์ก็จบ · คนฟันไม้สุดท้ายได้กล่องเวทมนตร์ 1 ใบ
--
-- ไฟล์นี้เป็นเจ้าของอีเวนต์ `worldboss` แต่ **ไม่ได้เป็นเจ้าของบอส**:
--   · เวลา (สองทุ่ม / 59 นาที)            → `WorldEvents.server` + `EventConfig.Events.worldboss`
--   · ตัวบอส เลือด ดาเมจ ดรอปตอนตาย      → `GatherConfig.Mobs.Forgewarden` + `Mobs.server`
--   · จะไปโผล่ตรงไหน                      → หมุด `workspace.WOLD.BossSpawns.BossSpawn_Forgewarden`
--   · **ใครทำดาเมจไปเท่าไหร่ และใครได้อะไร → ไฟล์นี้**
--
-- **ยอดดาเมจต้องเก็บไว้ที่นี่ ไม่ใช่ในตัวบอส** เพราะบอสไม่จำเป็นต้องตาย พอหมดเวลาโมเดลถูกลบทิ้งพร้อม
-- สถานะทั้งก้อน ถ้ายอดอยู่ในนั้น รอบที่บอสรอดจะไม่มีใครได้อะไรเลยทั้งที่ตีกันมาชั่วโมงหนึ่ง
local Players = game:GetService("Players")
local ServerConfig = require(game.ServerScriptService.ServerConfig)

if ServerConfig.IsLobby then return end

local EventConfig = require(game.ReplicatedStorage.EventConfig)
local GatherConfig = require(game.ReplicatedStorage.GatherConfig)
local EventState = require(game.ServerScriptService.EventState)
local MobAccess = require(game.ServerScriptService.MobAccess)
local Mail = require(game.ServerScriptService.Mail)
local HttpService = game:GetService("HttpService")
local Remotes = require(game.ReplicatedStorage.Remotes)

local ID = "worldboss"
local WB = EventConfig.WorldBoss or {}

--------------------------------------------------------------------------------
-- ตารางดาเมจของรอบนี้
--------------------------------------------------------------------------------

-- [userId] = { name = ชื่อ, damage = ยอดสะสม }
--
-- คีย์เป็น userId ไม่ใช่ตัว Player: คนที่หลุดแล้วเข้าใหม่กลางอีเวนต์ต้องได้ยอดเดิมต่อ ไม่ใช่เริ่มนับใหม่
-- และตอนประกาศท็อป 3 ต้องขึ้นชื่อได้แม้เจ้าตัวออกไปแล้ว
local Tally = {}
local Killed = false
local LastHitUserId = nil

local function resetRound()
	Tally = {}
	Killed = false
	LastHitUserId = nil
end

--------------------------------------------------------------------------------
-- หลอดเลือดใต้ป้ายประกาศ (ผู้ใช้สั่ง 2026-09-21)
--
-- **โพล ไม่ใช่ผูกกับการโดนตี** — สองเหตุผล:
--   1. เลือดเปลี่ยนได้โดยไม่มีใครตี (ฟื้นตัว · ตายเพราะตกเหว · ถูกเก็บตอนหมดเวลา) การอัปเดตเฉพาะ
--      ตอนโดนตีจะค้างเลขเก่าไว้บนจอทุกกรณีเหล่านั้น
--   2. ตอนบอสโผล่ยังไม่มีใครตีมันสักที แต่หลอดต้องขึ้นแล้ว
--
-- และมันคือลูปที่ถามใหม่เรื่อยๆ ตามกฎเหล็กของโปรเจ็คนี้ ไม่มีจังหวะให้แพ้
--
-- ครึ่งวินาทีคือ "ไวพอจะเห็นหลอดขยับตอนตีจริง" · `EventState.SetHealth` เงียบเมื่อค่าไม่เปลี่ยน
-- ช่วงที่ไม่มีใครตีจึงไม่มีแพ็กเก็ตวิ่งเลย และเพดานจริงคือ 2 ครั้ง/วินาที ไม่ใช่ทุกครั้งที่ดาบโดน
local POLL_SECONDS = 0.5

local function watchHealth()
	task.spawn(function()
		while EventState.IsActive(ID) do
			if MobAccess.EventMobHealth then
				EventState.SetHealth(ID, MobAccess.EventMobHealth(ID))
			end
			task.wait(POLL_SECONDS)
		end
	end)
end

--------------------------------------------------------------------------------
-- รับรายงานจากระบบมอน
--------------------------------------------------------------------------------

-- Mobs.server เรียกทุกครั้งที่มอนซึ่งเกิดจากหมุดที่มี `EventOnly` โดนตี — ทิศทางเดียว ไม่มีการถามกลับ
MobAccess.OnEventDamage = function(eventId, player, amount)
	if eventId ~= ID or not player or not amount or amount <= 0 then return end
	-- รับต่อเมื่ออีเวนต์เดินอยู่จริง ตัวที่ยังค้างอยู่หลังอีเวนต์จบจะไม่ไหลเข้ารอบถัดไป
	if not EventState.IsActive(ID) then return end

	local row = Tally[player.UserId]
	if not row then
		row = { name = player.DisplayName or player.Name, damage = 0 }
		Tally[player.UserId] = row
	end
	row.damage += amount
	row.name = player.DisplayName or player.Name
end

MobAccess.OnEventKill = function(eventId, killer)
	if eventId ~= ID then return end
	Killed = true
	LastHitUserId = killer and killer.UserId or nil
end

--------------------------------------------------------------------------------
-- การจ่ายรางวัล
--------------------------------------------------------------------------------

-- เกณฑ์ขั้นต่ำคิดจากเลือดในคอนฟิก ไม่ใช่เลือดจริงของตัวที่เกิด (ตัวกลางคืนเลือดหนากว่า) — เกณฑ์ที่ขยับ
-- ตามเวลากลางวัน/กลางคืนอธิบายให้ผู้เล่นฟังไม่ได้ว่าทำไมรอบนี้ตีเท่าเดิมแล้วไม่ติด
local function minimumDamage()
	local config = GatherConfig.Mobs[WB.kind or ""]
	local hp = config and config.hp or 0
	return hp * (WB.MinDamageFraction or 0)
end

local function bracketFor(rank)
	for _, entry in ipairs(WB.Ranks or {}) do
		if rank <= (entry.upTo or math.huge) then return entry end
	end
	return nil
end

-- รางวัลหนึ่งคน = จดหมายหนึ่งฉบับ ส่งถึงทุกคนในอันดับ **รวมคนที่ออกเกมไปแล้ว** และกระเป๋าเต็มก็ไม่หาย
-- (เดิมจ่ายตรงเข้ากระเป๋า ข้ามคนออฟไลน์ และทิ้งของเมื่อกระเป๋าเต็ม)
-- EXP ในจดหมายไม่แชร์เข้าตี้: การแชร์ผูกกับ "ฆ่ามอนหนึ่งตัว" (`AwardExpParty`) ส่วนนี่คือรางวัลอีเวนต์ที่
-- คนในตี้ทุกคนได้ของตัวเองตามดาเมจของตัวเองอยู่แล้ว
local function letterFor(rank, row, bracket, extraItems)
	local items = {}
	for _, item in ipairs(bracket.items or {}) do items[#items + 1] = { id = item.id, count = item.count or 1 } end
	for _, item in ipairs(extraItems or {}) do items[#items + 1] = { id = item.id, count = item.count or 1 } end
	return {
		from = 0, fromName = "สมาคมนักล่า",
		subject = ("รางวัลบอสโลก — %s"):format(bracket.label or ("อันดับ " .. rank)),
		body = ("ดาเมจ %d"):format(math.floor(row.damage)),
		items = items, gold = bracket.gold, exp = bracket.xp,
	}
end

local function payout()
	local ranked = {}
	local least = minimumDamage()
	for userId, row in pairs(Tally) do
		if row.damage >= least then
			table.insert(ranked, { userId = userId, name = row.name, damage = row.damage })
		end
	end
	-- มากไปน้อย เสมอกันตัดด้วย userId ให้ลำดับคงที่ ไม่ใช่ลำดับของ pairs ซึ่งสลับได้ทุกครั้ง
	table.sort(ranked, function(a, b)
		if a.damage == b.damage then return a.userId < b.userId end
		return a.damage > b.damage
	end)

	if #ranked == 0 then
		Remotes.SocialNotify:FireAllClients("info", "ฟอร์จวอร์เดนกลับลงเตาหลอม — ไม่มีใครเข้าเกณฑ์รับรางวัล")
		return
	end

	for rank, row in ipairs(ranked) do
		local bracket = bracketFor(rank)
		if bracket then
			local extra = {}
			local lastHit = Killed and LastHitUserId == row.userId and WB.LastHit ~= nil
			if lastHit then
				table.insert(extra, { id = WB.LastHit.item, count = WB.LastHit.count or 1 })
			end
			-- อันดับ 1-5 ได้เครื่องรางคุ้มครองแน่นอน (ผู้ใช้สั่ง 2026-09-25)
			if WB.CharmTopRanks and rank <= WB.CharmTopRanks then
				table.insert(extra, { id = WB.CharmItem or "GuardianCharm", count = 1 })
			end
			local letter = letterFor(rank, row, bracket, extra)
			-- ส่งแยกเธรด: MessageAsync ค้างได้หลายวินาทีต่อคน ไม่ให้ถ่วง stop hook ที่ต้องเก็บบอสออก
			local stats = { bossJoins = 1, bossTop1 = rank == 1 and 1 or 0, bossLastHits = lastHit and 1 or 0 }
			task.spawn(function()
				if not Mail.Send(row.userId, letter) then
					warn(("[WorldBoss] ส่งรางวัลถึง %s (%d) ไม่สำเร็จ:"):format(row.name, row.userId), letter.subject)
				end
				-- สถิติไปความสำเร็จ (ติดอันดับ/อันดับ 1/ไม้สุดท้าย) — ทางเดียวกับสนาม PVP ถึงคนที่ออกไปแล้วด้วย
				Mail.Transport(row.userId, { kind = "stats", id = HttpService:GenerateGUID(false), stats = stats })
			end)
			local player = Players:GetPlayerByUserId(row.userId)
			if player then
				Remotes.SocialNotify:FireClient(player, "info",
					("%s (ดาเมจ %d) — รางวัลส่งเข้ากล่องจดหมายแล้ว (P → กล่องจดหมาย)")
						:format(bracket.label or ("อันดับ " .. rank), math.floor(row.damage)))
				if lastHit then
					Remotes.SocialNotify:FireClient(player, "info", "ไม้สุดท้ายเป็นของคุณ! กล่องเวทมนตร์อยู่ในจดหมายฉบับเดียวกัน")
				end
			end
		end
	end

	-- ประกาศท็อปให้ทั้งเซิร์ฟเห็น: ตารางอันดับที่ไม่มีใครเห็นไม่ใช่ตารางอันดับ
	local top = {}
	for i = 1, math.min(WB.AnnounceTop or 3, #ranked) do
		table.insert(top, ("%d. %s (%d)"):format(i, ranked[i].name, math.floor(ranked[i].damage)))
	end
	Remotes.SocialNotify:FireAllClients("info", ("%s — %s"):format(
		Killed and "ฟอร์จวอร์เดนถูกปราบแล้ว!" or "ฟอร์จวอร์เดนถอยกลับเตาหลอม",
		table.concat(top, "  ")))
end

--------------------------------------------------------------------------------
-- อีเวนต์
--------------------------------------------------------------------------------

EventState.Register(ID, {
	start = function()
		resetRound()
		if not MobAccess.StartEventSpawners then
			-- ไม่มีระบบมอน = ประกาศที่ไม่มีบอสอยู่ข้างหลัง ซึ่งแย่กว่าไม่ประกาศ · โยนให้ WorldEvents
			-- ยกเลิกอีเวนต์ทิ้ง (มันจับ error ของ start hook ไว้อยู่แล้ว)
			error("[WorldBoss] MobAccess.StartEventSpawners ยังไม่ถูกตั้ง (Mobs.server ไม่ได้รัน?)", 0)
		end
		local spawners = MobAccess.StartEventSpawners(ID)
		if not spawners or spawners == 0 then
			-- เพลสนี้ไม่มีหมุดบอสเลย (ยังไม่ได้รัน `mapgen/83_boss_spawner.lua` หรืออยู่คนละเพลส)
			-- ล้มตั้งแต่ตรงนี้ดีกว่าประกาศแล้วให้คนวิ่งหาทั้งชั่วโมง
			error("[WorldBoss] ไม่มีหมุดที่ติด EventOnly = worldboss ในเพลสนี้", 0)
		end

		local config = GatherConfig.Mobs[WB.kind or ""]
		-- อ่านเวลาที่เหลือ **จากตัวอีเวนต์** ไม่ใช่จาก durationSeconds ในคอนฟิก: เซิร์ฟที่บูตมากลางรอบ
		-- ได้เวลาที่เหลือจริง (ดู `minRemainingSeconds`) ประกาศว่า 59 นาทีทุกครั้งจะโกหกในกรณีนั้น
		local entry = EventState.Active[ID]
		local left = entry and entry.endsAt and (entry.endsAt - workspace:GetServerTimeNow())
			or ((EventConfig.Events[ID] or {}).durationSeconds or 0)
		local minutes = math.floor(left / 60)
		Remotes.SocialNotify:FireAllClients("info",
			("%s ตื่นแล้ว! เหลือเวลา %d นาที — รางวัลแจกตามดาเมจที่ทำได้")
				:format(config and config.name or "บอสโลก", minutes))

		watchHealth()
	end,

	stop = function()
		-- จ่ายรางวัล **ก่อน** เก็บบอสออก และทั้งสองทางออกใช้ทางเดียวกัน: ตายก็จบ หมดเวลาก็จบ
		-- (ผู้ใช้กำหนดว่าบอสไม่ต้องตายก็ได้ รางวัลจึงผูกกับดาเมจ ไม่ได้ผูกกับการฆ่า)
		local ok, err = pcall(payout)
		if not ok then warn("[WorldBoss] จ่ายรางวัลไม่สำเร็จ:", err) end

		if MobAccess.StopEventSpawners then MobAccess.StopEventSpawners(ID) end
		resetRound()
		-- ไม่ต้องล้างหลอดเลือดตรงนี้: `WorldEvents.stop` ลบ `EventState.Active[ID]` ทิ้งไป **ก่อน**
		-- เรียก hook นี้ ค่าที่ค้างอยู่จึงหายไปพร้อมกันทั้งก้อน และลูปโพลเห็น `IsActive` เป็นเท็จ
		-- แล้วหยุดเองในครึ่งวินาทีถัดไป
	end,
})

--------------------------------------------------------------------------------
-- ทางเข้าสำหรับคำสั่งแอดมิน
--------------------------------------------------------------------------------

-- ผ่าน `MobAccess` เหมือนทุกอย่างที่ข้ามไฟล์ในระบบนี้ — `AdminCommands` require ไฟล์ .server.lua ไม่ได้
MobAccess.WorldBoss = {
	Id = ID,

	Start = function()
		if EventState.IsActive(ID) then return false, "บอสโลกกำลังเกิดอยู่แล้ว" end
		if not EventState.Start then return false, "ระบบอีเวนต์ยังไม่พร้อม" end
		EventState.Start(ID)
		if not EventState.IsActive(ID) then return false, "เริ่มไม่สำเร็จ (ดู Output)" end
		return true
	end,

	Stop = function()
		if not EventState.IsActive(ID) then return false, "ตอนนี้ไม่มีบอสโลก" end
		EventState.Stop(ID)
		return true
	end,

	-- ตารางดาเมจตอนนี้ เรียงแล้ว — ใช้ดูว่าใครนำอยู่ระหว่างสู้
	Standings = function()
		local out = {}
		for userId, row in pairs(Tally) do
			table.insert(out, { userId = userId, name = row.name, damage = row.damage })
		end
		table.sort(out, function(a, b)
			if a.damage == b.damage then return a.userId < b.userId end
			return a.damage > b.damage
		end)
		return out
	end,
}
