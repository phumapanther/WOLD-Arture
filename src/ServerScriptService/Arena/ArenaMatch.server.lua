-- ArenaMatch.server.lua: หนึ่งเซิร์ฟ = หนึ่งแมตช์ 3v3 ตั้งแต่คนแรกเข้าจนตารางอันดับขึ้น
--
-- **เซิร์ฟนี้ไม่เปิดเซสชันโปรไฟล์ของใครเลย** — กระเป๋าในสนามเป็นใบเปล่าที่เกิดใหม่ทุกแมตช์ ของในนั้น
-- มาจากร้านในสนามอย่างเดียว และไม่มีอะไรถูกเซฟกลับ (ดู `arena.project.json` ว่าอะไรบ้างไม่ได้มาเพลสนี้)
-- รางวัลตอนจบถูก **ฝาก** ไว้ให้เกมหลักมารับ ดู `ArenaRewards.lua`
--
-- สิ่งที่ยกมาจากเกมหลักทั้งดุ้น: การเคลื่อนไหว อนิเมชัน ระบบต่อสู้ สกิล Q เกราะ ยา —
-- ไม่มีบรรทัดไหนในไฟล์นี้เขียนระบบพวกนั้นใหม่ มันแค่ตั้งกติกาว่ารอบเริ่มเมื่อไหร่และจบยังไง
local ServerConfig = require(game.ServerScriptService.ServerConfig)
if not ServerConfig.IsArena then return end

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")

local ArenaAccess = require(game.ServerScriptService.ArenaAccess)
local ArenaBots = require(script.Parent.ArenaBots)
local ArenaDrops = require(script.Parent.ArenaDrops)
local ArenaConfig = require(game.ReplicatedStorage.ArenaConfig)
local ArenaRegistry = require(game.ServerScriptService.Lobby.ArenaRegistry)
local ArenaRewards = require(script.Parent.ArenaRewards)
local AdminRoster = require(game.ServerScriptService.AdminRoster)
local CombatConfig = require(game.ReplicatedStorage.CombatConfig)
local Inventory = require(game.ServerScriptService.Inventory)
local ItemCatalog = require(game.ReplicatedStorage.ItemCatalog)
local PlayerJoin = require(game.ServerScriptService.PlayerJoin)
local ProfileStore = require(game.ServerScriptService.ProfileStore)
local Remotes = require(game.ReplicatedStorage.Remotes)
local Vitals = require(game.ServerScriptService.Vitals)
local VitalsConfig = require(game.ReplicatedStorage.VitalsConfig)

--------------------------------------------------------------------------------
-- ตั้งกติกาที่ต่างจากเกมหลัก (ทำครั้งเดียวตอนบูต)
--------------------------------------------------------------------------------
-- **เลือดหมด = ตายทันที** ไม่มีท่าคลาน ไม่มีใครมาอุ้ม (ผู้ใช้เลือก: "ตายแล้วออกยาว รอรอบหน้า")
Vitals.NoDownedMode = true

-- **มานาเริ่ม 0 ไม่ฟื้นเอง ได้จากขวดน้ำในร้านเท่านั้น** (ผู้ใช้สั่ง 2026-09-24) ดู `Vitals.ArenaManaMode`
Vitals.ArenaManaMode = true

-- **เราเป็นคนตัดสินว่าใครเกิดเมื่อไหร่** ไม่ใช่ Roblox — คนที่ตายกลางรอบต้องอยู่ในสถานะดูอย่างเดียว
-- จนกว่ารอบใหม่จะเริ่ม ซึ่งเป็นไปไม่ได้เลยถ้าเอนจินเกิดให้เองทุกห้าวินาที
Players.CharacterAutoLoads = false

-- ปืนกับธนูในสนามแรงคนละอย่างกับในเมือง (เหตุผลอยู่ที่ `ArenaConfig.CombatOverrides`)
for weapon, patch in pairs(ArenaConfig.CombatOverrides) do
	local spec = CombatConfig.Weapons[weapon]
	local attack = spec and spec.attacks and spec.attacks[1]
	if attack then
		if patch.damage then attack.damage = patch.damage end
		if patch.effect == false then
			attack.effect, attack.effectSeconds = nil, nil
		elseif patch.effect then
			attack.effect, attack.effectSeconds = patch.effect, patch.effectSeconds
		end
	end
end

--------------------------------------------------------------------------------
-- แมตช์นี้คือแมตช์ไหน
--------------------------------------------------------------------------------
local record = ServerConfig.ArenaMatch

-- Studio Play ของเพลสสนามไม่มีเซิร์ฟจองอยู่เบื้องหลัง (PrivateServerId ว่าง) — ทำแมตช์ปลอมให้เทสได้
-- ทันทีโดยไม่ต้องเผยแพร่: คนที่กด Play ลงทีม A ที่เหลือเป็นบอท
if not record and RunService:IsStudio() then
	record = { mapId = ArenaConfig.Maps[1].id, teams = { A = {}, B = {} }, bots = { A = 2, B = 3 }, studio = true }
	print("[Arena] Studio: สร้างแมตช์ทดสอบ (คุณอยู่ทีม A · ที่เหลือเป็นบอท)")
end

-- เซิร์ฟสาธารณะของเพลสสนาม: ไม่มีแมตช์ ไม่มีอะไรให้ทำ — **ด่านอยู่ที่เซิร์ฟ ไม่ใช่ที่ปุ่ม**
-- (บทเรียนเดียวกับเกาะ: ปุ่มในล็อบบี้คือทางเข้าที่สะดวก ไม่ใช่กฎ ไคลเอนต์ยิงเทเลพอร์ตเองได้)
if not record then
	warn("[Arena] เซิร์ฟนี้ไม่มีแมตช์ — ส่งทุกคนกลับล็อบบี้")
	PlayerJoin.Each(function(player)
		task.wait(1)
		pcall(function() TeleportService:Teleport(ServerConfig.MainPlaceId, player) end)
	end)
	return
end

local MAP = ArenaConfig.MapById(record.mapId) or ArenaConfig.Maps[1]

--------------------------------------------------------------------------------
-- สกินอาวุธจากเกมหลัก (ผู้ใช้สั่ง 2026-09-24: "สวมสกินอะไรอยู่ อาวุธในแมพ PVP ก็สวมสกินนั้นให้ออโต้")
--------------------------------------------------------------------------------
-- อ่านโปรไฟล์ **แบบอ่านอย่างเดียว** (`GetAsync` ไม่ล็อกเซสชัน) — เซิร์ฟนี้ห้ามเปิดเซสชันใคร (ดูหัวไฟล์)
-- ⚠️ ชื่อ store กับรูปคีย์ต้องตรงกับ `PlayerProfile.server.lua` เป๊ะ
-- ⚠️ โมเดลสกินต้องอยู่ใน `ReplicatedStorage.WOLD_Skins` ของเพลสนี้ด้วย (`98_island_skins.lua --skins`)
-- ไม่งั้น `WeaponVisuals` ตกไปใช้รูปทรงมาตรฐานเงียบๆ
local ProfileView = ProfileStore.New("WOLD_PlayerProfile_v1")

-- คืน { [weaponId] = skinId } · อาวุธที่ถืออยู่ในเกมหลักชนะชิ้นที่นอนอยู่ในกระเป๋า
local function mainGameSkins(userId)
	local skins = {}
	local ok, view = pcall(function() return ProfileView:GetAsync("Player_" .. userId) end)
	local inv = ok and view and view.Data and view.Data.Inventory
	if not inv then return skins end
	local function take(entry)
		if type(entry) == "table" and entry.id and type(entry.meta) == "table" and entry.meta.skin then
			skins[entry.id] = skins[entry.id] or entry.meta.skin
		end
	end
	for _, entry in pairs(inv.Equipped or {}) do take(entry) end
	for _, entry in pairs(inv.Slots or {}) do take(entry) end
	return skins
end

--------------------------------------------------------------------------------
-- สนาม
--------------------------------------------------------------------------------
local function mapModel()
	local folder = workspace:FindFirstChild(ArenaConfig.MapFolder)
	return folder and folder:FindFirstChild(MAP.id) or nil
end

-- แมพยังไม่ถูกอบเข้าเพลส (`mapgen/100_arena_maps.lua` ยังไม่ได้รัน) — ปูพื้นชั่วคราวให้เทสได้
-- **ไม่ใช่แมพจริง และไม่ควรกลายเป็นแมพจริง** มันมีไว้เพื่อให้รอบเดินได้ตอนยังไม่มีอะไรเลย
local function buildFallbackArena(origin)
	local folder = workspace:FindFirstChild(ArenaConfig.MapFolder)
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = ArenaConfig.MapFolder
		folder.Parent = workspace
	end
	local model = Instance.new("Model")
	model.Name = MAP.id
	model:SetAttribute("Fallback", true)
	model.Parent = folder

	local floor = Instance.new("Part")
	floor.Anchored, floor.Size = true, Vector3.new(320, 4, 320)
	floor.Position = origin - Vector3.new(0, 2, 0)
	floor.Material, floor.BrickColor = Enum.Material.Slate, BrickColor.new("Dark stone grey")
	floor.Parent = model

	-- กล่องบังสายตาแบบสมมาตร: สนามโล่งคือสนามที่ใครเห็นก่อนยิงก่อนชนะ ไม่ว่าจะแมพชั่วคราวหรือไม่
	for _, offset in ipairs({ Vector3.new(0, 0, 0), Vector3.new(60, 0, 40), Vector3.new(-60, 0, -40),
		Vector3.new(60, 0, -40), Vector3.new(-60, 0, 40) }) do
		local cover = Instance.new("Part")
		cover.Anchored, cover.Size = true, Vector3.new(20, 12, 8)
		cover.Position = origin + offset + Vector3.new(0, 6, 0)
		cover.Material, cover.BrickColor = Enum.Material.Metal, BrickColor.new("Bronze")
		cover.Parent = model
	end

	for side, z in pairs({ A = -140, B = 140 }) do
		local spawns = Instance.new("Folder")
		spawns.Name = "Spawn" .. side
		spawns.Parent = model
		for i = 1, ArenaConfig.TeamSize do
			local pad = Instance.new("Part")
			pad.Anchored, pad.Size = true, Vector3.new(8, 1, 8)
			pad.Position = origin + Vector3.new((i - 2) * 14, 0.5, z)
			pad.Material = Enum.Material.Neon
			pad.Color = ArenaConfig.Teams[side].colour
			pad.Name = ("Pad%d"):format(i)
			pad.Parent = spawns
		end
	end
	warn("[Arena] ยังไม่มีแมพจริงในเพลส — ใช้สนามชั่วคราว (รัน mapgen/100_arena_maps.lua เพื่อสร้างของจริง)")
	return model
end

local Map = mapModel() or buildFallbackArena(MAP.origin)

local function spawnPads(side)
	local folder = Map:FindFirstChild("Spawn" .. side)
	local pads = {}
	for _, child in ipairs(folder and folder:GetChildren() or {}) do
		if child:IsA("BasePart") then table.insert(pads, child) end
	end
	table.sort(pads, function(a, b) return a.Name < b.Name end)
	return pads
end

local function spawnCFrame(side, index)
	local pads = spawnPads(side)
	if #pads == 0 then
		return CFrame.new(MAP.origin + Vector3.new(index * 8, 5, side == "A" and -140 or 140))
	end
	local pad = pads[((index - 1) % #pads) + 1]
	-- หันหน้าเข้ากลางแมพเสมอ: คนที่เกิดมาหันหลังให้สนามต้องเสียวินาทีแรกไปกับการหมุนตัว
	local centre = Vector3.new(MAP.origin.X, pad.Position.Y + 3, MAP.origin.Z)
	return CFrame.lookAt(pad.Position + Vector3.new(0, 3.5, 0), centre)
end

--------------------------------------------------------------------------------
-- ผู้เข้าแข่ง
--------------------------------------------------------------------------------
-- key = Player (คน) หรือ Model (บอท)
local Fighters = {}

local function newStats()
	return { kills = 0, deaths = 0, assists = 0, damage = 0, roundKills = 0 }
end

local function sideOfUserId(userId)
	for _, side in ipairs(ArenaConfig.TeamOrder) do
		for _, id in ipairs(record.teams[side] or {}) do
			if id == userId then return side end
		end
	end
	return nil
end

-- **สเตตของบอทต้องข้ามรอบได้** — ร่างบอทถูกลบทิ้งแล้วปั้นใหม่ทุกต้นรอบ ถ้าผูกคะแนนไว้กับร่าง
-- ตารางจบเกมจะมีบอทโผล่มาหกตัวต่อรอบ ตัวละศูนย์คิล · แถวของบอทจึงอยู่ที่นี่ ร่างแค่ยืมไปใช้
local BotRoster = {} -- { { side, name, stats } }

local function sideOfPlayer(player)
	local f = Fighters[player]
	return f and f.side or nil
end

local function countIn(side, onlyAlive)
	local n = 0
	for _, f in pairs(Fighters) do
		if f.side == side and (not onlyAlive or f.alive) then n += 1 end
	end
	return n
end

--------------------------------------------------------------------------------
-- สถานะของแมตช์
--------------------------------------------------------------------------------
local State = {
	round = 0,
	wins = { A = 0, B = 0 },
	phase = "warmup", -- warmup → buy → live → roundEnd → (วน) → matchEnd
	phaseEndsAt = 0,
	lastRoundWinner = nil,
	over = false,
}

local function phaseSecondsLeft()
	return math.max(0, math.ceil(State.phaseEndsAt - os.clock()))
end

-- **ซื้อของได้ตอนอยู่ในฐานตัวเอง** (ผู้ใช้สั่ง 2026-09-24: "อยู่โซนฐานตัวเองกด B เพื่อซื้อของได้")
-- ฐาน = กล่องล่องหน `BaseZone<ทีม>` ในโมเดลแมพ (เฟส 101 สร้างให้) · แมพที่ไม่มีกล่อง = รัศมี 45 จากแท่นเกิด
local BASE_RADIUS = 45
local function inOwnBase(f)
	if f.kind ~= "player" or not f.alive then return false end
	local root = f.player.Character and f.player.Character:FindFirstChild("HumanoidRootPart")
	if not root then return false end
	local zone = Map:FindFirstChild("BaseZone" .. f.side, true)
	if zone then
		local p = zone.CFrame:PointToObjectSpace(root.Position)
		local h = zone.Size / 2
		return math.abs(p.X) <= h.X and math.abs(p.Y) <= h.Y and math.abs(p.Z) <= h.Z
	end
	local pads = spawnPads(f.side)
	if #pads == 0 then return false end
	local centre = Vector3.zero
	for _, pad in ipairs(pads) do centre += pad.Position end
	return (root.Position - centre / #pads).Magnitude <= BASE_RADIUS
end

-- ช่วงเตรียมตัว: ซื้อได้ทุกคน · ระหว่างสู้: เฉพาะคนที่ยังยืนอยู่ในฐานตัวเอง
local function canShop(f)
	return State.phase == "buy" or (State.phase == "live" and inOwnBase(f))
end

-- ใบเสร็จที่ยกเลิกได้ของ id นี้ = ใบท้ายสุดของช่องนั้น และต้องเป็นของ id นี้ · nil = ยกเลิกไม่ได้
local function refundableIndex(f, id)
	local entry = ArenaConfig.ShopEntry(id)
	if not entry or not f.receipts then return nil end
	for i = #f.receipts, 1, -1 do
		local r = f.receipts[i]
		if r.slot == entry.slot then
			return r.id == id and i or nil
		end
	end
	return nil
end

--------------------------------------------------------------------------------
-- ภาพที่ส่งให้หน้าจอ
--------------------------------------------------------------------------------
-- **หนึ่งภาพต่อคน ไม่ใช่ภาพกลาง** — แต่ละคนเห็นซิลเวอร์ของตัวเอง ของที่ตัวเองถือ และฝั่งของตัวเองเป็น "เรา"
local function snapshotFor(player)
	local me = Fighters[player]
	if not me then return nil end

	local roster = {}
	-- ดาเมจที่ "เรา" ทำใส่ศัตรูแต่ละคนในรอบนี้ — การ์ดขวาจอตอนตายแล้วดูเพื่อน (ผู้ใช้สั่ง 2026-09-24)
	local dealt = {}
	for key, f in pairs(Fighters) do
		table.insert(roster, {
			name = f.name,
			side = f.side,
			alive = f.alive,
			bot = f.kind == "bot",
			me = f.player == player,
			kills = f.stats.kills,
			deaths = f.stats.deaths,
			assists = f.stats.assists,
			damage = math.floor(f.stats.damage + 0.5),
			score = math.floor(ArenaConfig.Score(f.stats) + 0.5),
			-- ให้กล้องของคนที่ตายแล้วหาร่างเพื่อนเจอ: คน = userId · บอท = ตัวโมเดลเลย
			userId = f.kind == "player" and f.player.UserId or nil,
			model = f.kind == "bot" and f.model or nil,
		})
		if f.side ~= me.side then
			table.insert(dealt, {
				name = f.name,
				damage = math.floor((me.roundDamage[key] or 0) + 0.5),
				alive = f.alive,
			})
		end
	end
	table.sort(dealt, function(a, b) return a.damage > b.damage end)
	table.sort(roster, function(a, b)
		if a.side ~= b.side then return a.side < b.side end
		return a.name < b.name
	end)

	return {
		phase = State.phase,
		secondsLeft = phaseSecondsLeft(),
		round = State.round,
		wins = State.wins,
		roundsToWin = ArenaConfig.RoundsToWin,
		mapName = MAP.name,
		mapId = MAP.id, -- แผนที่ M วาดจากโมเดลแมพตัวนี้
		-- ให้กล้องของคนที่ยังไม่มีร่าง (รอรอบหน้า / เพิ่งเข้ามา) มีอะไรให้มอง — เซิร์ฟเวอร์ตั้งกล้อง
		-- ของไคลเอนต์อื่นไม่ได้ มันจึงต้องรู้ว่ากลางสนามอยู่ตรงไหน
		centre = MAP.origin,
		mySide = me.side,
		silver = me.silver,
		alive = me.alive,
		loadout = me.loadout,
		-- ซื้อไปแล้วช่องไหนในรอบนี้ — หน้าร้านทำปุ่มเป็นสีเทาโดยไม่ต้องเดาเอง
		bought = me.boughtThisRound, -- [slot] = ซื้อไปแล้วกี่ชิ้นในรอบนี้
		-- [id] = true ของที่กดยกเลิกการซื้อได้ตอนนี้ (ช่วงเตรียมตัวเท่านั้น)
		refundable = (function()
			if State.phase ~= "buy" then return {} end
			local out = {}
			for _, r in ipairs(me.receipts or {}) do
				if refundableIndex(me, r.id) then out[r.id] = true end
			end
			return out
		end)(),
		mana = Vitals.ManaOf(player),
		canShop = canShop(me), -- หน้าจอเปิดร้าน/โชว์ป้าย "กด B" ตามค่านี้ · เซิร์ฟตัดสินซ้ำตอนซื้อทุกครั้ง
		roster = roster,
		dealt = dealt,
		lastWinner = State.lastRoundWinner,
	}
end

local function pushTo(player)
	local snap = snapshotFor(player)
	if snap then Remotes.ArenaState:FireClient(player, snap) end
end

local function pushAll()
	for _, player in ipairs(Players:GetPlayers()) do pushTo(player) end
end

local function notify(player, text, kind)
	Remotes.ArenaNotice:FireClient(player, kind or "info", text)
end

--------------------------------------------------------------------------------
-- ของที่สวมอยู่
--------------------------------------------------------------------------------
local function equipById(player, id)
	local index = Inventory.FindSlotById(player, id)
	if index then Inventory.Equip(player, index) end
end

-- ⚠️ `Inventory.RemoveById` เป็น **ทั้งหมดหรือไม่เอาเลย** — สั่งลบ 99 ตอนมีชิ้นเดียว = ไม่ลบอะไรเลย
local function removeAll(player, id)
	local n = Inventory.CountOf(player, id)
	if n > 0 then Inventory.RemoveById(player, id, n) end
end

-- ตายในรอบไหน = ของที่ซื้อไว้หายหมด รอบหน้าต้องซื้อใหม่ รวมมานา (ผู้ใช้สั่ง 2026-09-24)
local function wipeLoadout(f)
	local player = f.player
	for _, held in pairs(f.loadout) do removeAll(player, held) end
	Inventory.BreakEquipped(player, "weapon")
	Inventory.BreakEquipped(player, "armor")
	removeAll(player, "Bullet")
	f.loadout = {}
	Vitals.SetMana(player, 0)
	Vitals.SyncArmorFromEquipment(player)
	Inventory.Send(player)
end

-- ใส่ของที่ซื้อไว้กลับให้ใหม่หลังเกิด — กระเป๋ารอดข้ามการตาย (มันผูกกับคน ไม่ใช่กับร่าง) แต่ของที่
-- "สวมอยู่" ต้องถูกสั่งสวมอีกครั้งเพื่อให้โมเดลอาวุธกับเกราะกลับไปอยู่บนตัว
local function reapplyLoadout(f)
	if f.kind ~= "player" then return end
	if f.loadout.weapon then equipById(f.player, f.loadout.weapon) end
	if f.loadout.armor then equipById(f.player, f.loadout.armor) end
	Vitals.SyncArmorFromEquipment(f.player)
	Inventory.Send(f.player)
end

--------------------------------------------------------------------------------
-- เกิด / ตาย
--------------------------------------------------------------------------------
local Anchored = {} -- [player] = true ตอนถูกตรึงในช่วงซื้อของ

local function setAnchored(player, on)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then return end
	root.Anchored = on and true or false
	Anchored[player] = on or nil
end

-- ตรึงไว้ที่ฐานระหว่างช่วงซื้อของ **ด้วยการ Anchor ไม่ใช่ตั้ง WalkSpeed = 0**
-- เพราะ `PlayerMovement` เขียน WalkSpeed ใหม่ทุกเฟรมจากสถานะของมันเอง การไปตั้งศูนย์ทับคือการ
-- แย่งกันเขียนค่าเดียวกันซึ่งจะแพ้ในบางเฟรมเสมอ · Anchor ชนะเด็ดขาดและยังหันกล้องมองรอบตัวได้
local function freezeAll(on)
	for _, f in pairs(Fighters) do
		if f.kind == "player" and f.alive then setAnchored(f.player, on) end
	end
	ArenaBots.SetFree(not on)
end

-- คิล = คนที่ตีโดนครั้งสุดท้าย · **แอสซิส = ทุกคนที่เคยทำดาเมจใส่คนนี้ในชีวิตนี้ (รอบนี้) แต่ไม่ได้เป็นคนเก็บ**
-- (ผู้ใช้กำหนด 2026-09-24 — เดิมนับเฉพาะคนที่ตีใน 12 วินาทีสุดท้าย) · นับทั้งคนและบอท
-- แบนเนอร์คิลถึงคนเก็บคนเดียว (ผู้ใช้สั่ง 2026-09-25): คิลแรกของรอบ = FIRST BLOOD · คิลติดกันไม่เกิน
-- MultiKillSeconds = DOUBLE / TRIPLE (3v3 ได้มากสุดสาม) · บอทไม่มีจอ จึงไม่ส่ง
local function announceKill(killer, victimFighter, attackerKey)
	local now = os.clock()
	local streak = 1
	if killer.lastKillAt and now - killer.lastKillAt <= ArenaConfig.MultiKillSeconds then
		streak = (killer.killStreak or 1) + 1
	end
	killer.killStreak, killer.lastKillAt = streak, now
	local kind = "kill"
	if streak >= 3 then
		kind = "triple"
	elseif streak == 2 then
		kind = "double"
	elseif not State.firstBlood then
		kind = "first"
	end
	State.firstBlood = true
	if killer.kind ~= "player" or not killer.player or not killer.player.Parent then return end
	local headshot = victimFighter.headshotBy == attackerKey and now - (victimFighter.headshotAt or 0) < 1
	Remotes.ArenaKillBanner:FireClient(killer.player, { kind = kind, victim = victimFighter.name or "?", headshot = headshot })
end

local function killCredit(victimFighter)
	local attacker = victimFighter.lastHitBy
	if attacker then
		local killer = Fighters[attacker]
		if killer and killer.side ~= victimFighter.side then
			killer.stats.kills += 1
			killer.stats.roundKills += 1
			announceKill(killer, victimFighter, attacker)
		end
	end
	for key in pairs(victimFighter.recentHits or {}) do
		if key ~= attacker then
			local helper = Fighters[key]
			if helper and helper.side ~= victimFighter.side then helper.stats.assists += 1 end
		end
	end
	victimFighter.recentHits = {}
end

-- **คนตาย = อาวุธตกที่จุดตาย** (ผู้ใช้สั่ง 2026-09-25) ใครก็หยิบได้จนรอบจบ · ปืนตกพร้อมกระสุนที่เหลือ
-- ของคนตายหายจากตัวทันที (ตายแล้วของหายอยู่แล้วตามกติกาเดิม แค่ย้ายไปอยู่บนพื้นให้คนอื่นแทน)
local function dropWeapon(f)
	if f.kind == "player" then
		local player = f.player
		local _, entry = Inventory.EquippedWeapon(player)
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if not (entry and root) then return end
		local gun = ArenaConfig.ShopEntry(entry.id)
		local ammo = gun and gun.ammo and Inventory.CountOf(player, "Bullet") or nil
		ArenaDrops.Drop(root.Position, entry.id, entry.meta, ammo)
		Inventory.BreakEquipped(player, "weapon")
		removeAll(player, entry.id)
		if ammo then removeAll(player, "Bullet") end
		f.loadout.weapon = nil
		Inventory.Send(player)
	else
		local loadout = ArenaBots.Loadout(f.model)
		local root = f.model and f.model:FindFirstChild("HumanoidRootPart")
		if loadout.weapon and root then
			local gun = ArenaConfig.ShopEntry(loadout.weapon)
			ArenaDrops.Drop(root.Position, loadout.weapon, nil, gun and gun.ammo and (loadout.ammo or 0) or nil)
		end
	end
end

local function markDead(f)
	if not f.alive then return end
	f.alive = false
	f.diedThisRound = true
	f.stats.deaths += 1
	-- ช่วงสู้เท่านั้น (ตายช่วงรอบจบ/เตรียมตัว เช่นตกแมพ ไม่ต้องมีของกองบนพื้น)
	if State.phase == "live" then dropWeapon(f) end
	killCredit(f)
	pushAll()
end

-- หยิบอาวุธที่ตก: **สลับ** — อาวุธในมือตกลงแทนที่จุดนั้น (มือว่างก็หยิบเฉยๆ) · ช่วงสู้ + ยังไม่ตายเท่านั้น
-- อาวุธที่หยิบมาติดตัวข้ามรอบได้ถ้ารอดเหมือนของที่ซื้อ (อยู่ใน loadout)
ArenaDrops.Bind(function(player, drop)
	local f = Fighters[player]
	if not (f and f.alive and State.phase == "live") then return false end
	local _, entry = Inventory.EquippedWeapon(player)
	if entry then
		local gun = ArenaConfig.ShopEntry(entry.id)
		local ammo = gun and gun.ammo and Inventory.CountOf(player, "Bullet") or nil
		ArenaDrops.Drop(drop.position, entry.id, entry.meta, ammo)
		Inventory.BreakEquipped(player, "weapon")
		removeAll(player, entry.id)
		if ammo then removeAll(player, "Bullet") end
	end
	Inventory.AddItem(player, drop.id, 1, nil, drop.meta)
	if drop.ammo and drop.ammo > 0 then Inventory.AddItem(player, "Bullet", drop.ammo) end
	equipById(player, drop.id)
	f.loadout.weapon = drop.id
	Inventory.Send(player)
	local item = ItemCatalog.Items[drop.id]
	notify(player, ("หยิบ %s แล้ว"):format(item and item.name or drop.id))
	pushTo(player)
	return true
end)

local function spawnPlayer(f, index)
	local player = f.player
	-- คนที่ออกจากเกมไปแล้วเกิดไม่ได้ และ **ต้องไม่ถูกนับว่ายังยืนอยู่** ไม่งั้นรอบจะไม่มีวันจบ
	if f.left or not player or not player.Parent then
		f.alive = false
		return
	end
	-- ปิดธงก่อนสลับร่าง: ระหว่าง `LoadCharacter` ร่างเก่าถูกทิ้ง ถ้าธงยังเปิดอยู่ตอนนั้น เหตุการณ์
	-- ใดๆ ที่หลุดมาจากร่างเก่าจะถูกนับเป็น "ตาย" ของรอบใหม่ทั้งที่รอบยังไม่เริ่ม
	f.alive = false
	player:LoadCharacter()
	f.alive = true
	local character = player.Character
	if character then
		character:PivotTo(spawnCFrame(f.side, index))
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid.Died:Connect(function() markDead(f) end)
		end
	end
	reapplyLoadout(f)
	if State.phase == "buy" then setAnchored(player, true) end
end

--------------------------------------------------------------------------------
-- ทางที่ระบบต่อสู้รายงานเข้ามา
--------------------------------------------------------------------------------
local function registerHit(attackerKey, victimKey, amount)
	local attacker, victim = Fighters[attackerKey], Fighters[victimKey]
	if not victim then return end
	if attacker then
		attacker.stats.damage += amount
		attacker.roundDamage[victimKey] = (attacker.roundDamage[victimKey] or 0) + amount
		victim.lastHitBy, victim.lastHitAt = attackerKey, os.clock()
		victim.recentHits = victim.recentHits or {}
		victim.recentHits[attackerKey] = os.clock()
	end
end

ArenaAccess.Friendly = function(a, b)
	local fa, fb = Fighters[a], Fighters[b]
	return fa ~= nil and fb ~= nil and fa.side == fb.side
end
ArenaAccess.OnHit = function(attacker, victim, amount)
	registerHit(attacker, victim, amount)
end
-- PlayerCombat บอกว่านัดนี้เข้าหัว (ก่อนดาเมจลง) — announceKill ถามว่าคิลนี้มาจากหัวไหม
ArenaAccess.OnHeadshot = function(attacker, victim)
	local f = Fighters[victim]
	if f then f.headshotBy, f.headshotAt = attacker, os.clock() end
end
ArenaAccess.OnKill = function()
	-- ในสนามไม่มี EXP และไม่มีหัวแดง · คิลถูกนับตอนร่างตายจริง (`markDead`) ไม่ใช่ตอนล้ม
end

ArenaBots.Bind({
	sideOfPlayer = sideOfPlayer,
	onPlayerHitBot = function(player, model, amount) registerHit(player, model, amount) end,
	onBotHitPlayer = function(model, player, amount) registerHit(model, player, amount) end,
	onBotHitBot = function(model, other, amount) registerHit(model, other, amount) end,
	onDied = function(model)
		local f = Fighters[model]
		if f then markDead(f) end
	end,
})

--------------------------------------------------------------------------------
-- ร้านในสนาม
--------------------------------------------------------------------------------
Remotes.RequestArenaBuy.OnServerEvent:Connect(function(player, id)
	local f = Fighters[player]
	if not f then return end
	if not canShop(f) then return notify(player, "ซื้อได้ช่วงเตรียมตัว หรือตอนยืนอยู่ในฐานตัวเอง", "warn") end

	local entry = ArenaConfig.ShopEntry(id)
	if not entry then return end
	local count = f.boughtThisRound[entry.slot] or 0
	if count >= ArenaConfig.PerRound(entry) then
		return notify(player, ("รอบนี้ซื้อ%sครบแล้ว"):format(ArenaConfig.SlotLabel[entry.slot] or "ของ"), "warn")
	end
	if f.silver < entry.price then
		return notify(player, "ซิลเวอร์ไม่พอ", "warn")
	end
	if entry.mana and Vitals.ManaOf(player) >= VitalsConfig.MaxMana then
		return notify(player, "มานาเต็มแล้ว", "warn")
	end

	-- ใบเสร็จไว้ยกเลิกการซื้อ (ผู้ใช้สั่ง 2026-09-25) — จดสภาพ "ก่อนซื้อ" ทุกอย่างที่การซื้อนี้จะเปลี่ยน
	local before = f.loadout[entry.slot]
	f.receipts = f.receipts or {}
	table.insert(f.receipts, {
		id = id, slot = entry.slot, price = entry.price,
		previous = before,
		previousCount = before and Inventory.CountOf(player, before) or 0,
		bullets = Inventory.CountOf(player, "Bullet"),
		mana = Vitals.ManaOf(player),
	})

	f.silver -= entry.price
	f.boughtThisRound[entry.slot] = count + 1

	-- ขวดน้ำ: ไม่เข้ากระเป๋า เติมมานาทันที
	if entry.mana then
		Vitals.AddMana(player, entry.mana)
		notify(player, ("มานา %d/%d"):format(Vitals.ManaOf(player), VitalsConfig.MaxMana))
		pushTo(player)
		return
	end

	-- **ซื้อชิ้นใหม่ = ทับของเก่าทิ้ง** (ผู้ใช้สั่ง)
	local previous = f.loadout[entry.slot]
	local wearable = entry.slot == "weapon" or entry.slot == "armor"
	-- ยาเก่าลบ *ก่อน* ใส่ขวดใหม่ (ชนิดเดียวกันกองรวมกัน ลบทีหลังจะลบขวดใหม่ไปด้วย)
	if previous and not wearable then removeAll(player, previous) end
	f.loadout[entry.slot] = id

	-- อาวุธและเกราะใส่สกินจากเกมหลักให้เอง (meta.skin ทางเดียวกับที่ `Skins.server` ติดตั้ง
	-- เกราะใช้ชุดแฟชั่น `Fashion_*Kit` ใน `ServerStorage.Model_Item` ของเพลสนี้)
	local skin = wearable and f.skins[id]
	Inventory.AddItem(player, id, 1, nil, skin and { skin = skin } or nil)
	-- ปืนมากับกระสุนตามแถวร้าน (`entry.ammo` ตอนนี้ 7 นัด) แล้วจบ — ยิงหมดต้องซื้อปืนใหม่ ไม่มีกระสุนขายแยก
	if entry.ammo then
		removeAll(player, "Bullet")
		Inventory.AddItem(player, "Bullet", entry.ammo)
	end

	-- **ซื้อแล้วสวมให้เลย** ไม่ต้องเปิดกระเป๋า (กระเป๋าในสนามใช้ไม่ได้อยู่แล้ว)
	if wearable then
		equipById(player, id)
		-- ⚠️ ลบของเก่า **หลัง** สวมชิ้นใหม่: `Equip` คืนชิ้นที่ถอดลงกระเป๋า ลบก่อนแล้วมันเด้งกลับมากอง
		if previous then removeAll(player, previous) end
		Vitals.SyncArmorFromEquipment(player)
		-- สไน: ซื้อแล้วมานาเต็มหลอด (ผู้ใช้สั่ง 2026-09-25) — มานาในสนามเริ่มที่ 0
		if entry.fillMana then Vitals.SetMana(player, VitalsConfig.MaxMana) end
	end
	Inventory.Send(player)

	local item = ItemCatalog.Items[id]
	notify(player, ("ซื้อ %s แล้ว"):format(item and item.name or id))
	pushTo(player)
end)

-- **ยกเลิกการซื้อ** (ผู้ใช้สั่ง 2026-09-25): เฉพาะช่วงเตรียมตัว · เฉพาะของที่ซื้อรอบนี้ · ได้เงินคืนเต็ม
-- ยกเลิกได้เฉพาะ "ชิ้นล่าสุดของช่องนั้น" (ใบเสร็จท้ายสุด) — ซื้อดาบแล้วเปลี่ยนเป็นดาบใหญ่ ต้องยกเลิกดาบใหญ่ก่อน
-- ไม่งั้นย้อนสภาพไม่ได้ (ของที่อยู่ในมือไม่ใช่ของใบเสร็จนั้นแล้ว)
Remotes.RequestArenaRefund.OnServerEvent:Connect(function(player, id)
	local f = Fighters[player]
	if not f or not f.receipts then return end
	if State.phase ~= "buy" then return notify(player, "ยกเลิกได้เฉพาะช่วงเตรียมตัว", "warn") end
	local index = refundableIndex(f, id)
	if not index then return notify(player, "ยกเลิกได้เฉพาะของที่ซื้อล่าสุดในรอบนี้", "warn") end
	local r = table.remove(f.receipts, index)
	local entry = ArenaConfig.ShopEntry(r.id)

	f.silver += r.price
	f.boughtThisRound[r.slot] = math.max(0, (f.boughtThisRound[r.slot] or 1) - 1)

	if entry.mana then
		Vitals.SetMana(player, math.max(0, Vitals.ManaOf(player) - entry.mana))
	else
		local wearable = r.slot == "weapon" or r.slot == "armor"
		if r.previous ~= r.id then
			if r.previous then
				-- ของเดิมกลับมา (สกินเดิม) · สวมก่อนแล้วค่อยลบของที่ยกเลิก — ทรงเดียวกับตอนซื้อ
				local skin = wearable and f.skins[r.previous]
				Inventory.AddItem(player, r.previous, math.max(1, r.previousCount), nil, skin and { skin = skin } or nil)
				if wearable then equipById(player, r.previous) end
			elseif wearable then
				Inventory.BreakEquipped(player, r.slot)
			end
			removeAll(player, r.id)
		elseif not wearable then
			-- ยาชนิดเดิมซ้ำ: คืนจำนวนเดิม
			removeAll(player, r.id)
			if r.previousCount > 0 then Inventory.AddItem(player, r.id, r.previousCount) end
		end
		-- กระสุนกลับเท่าก่อนซื้อ (ปืนมากับกระสุน) · มานากลับเท่าก่อนซื้อ (สไนเติมมานาเต็ม)
		if entry.ammo then
			removeAll(player, "Bullet")
			if r.bullets > 0 then Inventory.AddItem(player, "Bullet", r.bullets) end
		end
		if entry.fillMana then Vitals.SetMana(player, r.mana) end
		f.loadout[r.slot] = r.previous
		Vitals.SyncArmorFromEquipment(player)
		Inventory.Send(player)
	end

	local item = ItemCatalog.Items[r.id]
	notify(player, ("ยกเลิก %s แล้ว · คืน %d ซิลเวอร์"):format(item and item.name or r.id, r.price))
	pushTo(player)
end)

--------------------------------------------------------------------------------
-- เงินรางวัลประจำรอบ
--------------------------------------------------------------------------------
local function payRound(winner)
	local E = ArenaConfig.Economy
	local best = 0
	for _, f in pairs(Fighters) do
		if f.stats.roundKills > best then best = f.stats.roundKills end
	end

	for _, f in pairs(Fighters) do
		local pay = (f.side == winner) and E.roundWin or E.roundLoss
		pay += f.stats.roundKills * E.perKill
		-- **คนฆ่าได้เยอะสุดของรอบได้เพิ่ม** — เสมอกันได้ทุกคนที่เสมอ (การหักส่วนแบ่งของคนที่ทำได้
		-- เท่ากันเป๊ะ ไม่มีเหตุผลอะไรรองรับนอกจาก "ต้องมีคนเดียว")
		if best > 0 and f.stats.roundKills == best then pay += E.roundTopFragger end
		pay = math.clamp(pay, E.roundMin or 0, E.roundMax or math.huge)
		f.silver = math.min(E.cap, f.silver + pay)
		f.stats.roundKills = 0
	end
end

--------------------------------------------------------------------------------
-- รอบ
--------------------------------------------------------------------------------
local function beginPhase(phase, seconds)
	-- อาวุธที่ตกหยิบได้ถึงรอบจบเท่านั้น (ผู้ใช้สั่ง "ก่อนรอบจะจบลง")
	if phase ~= "live" then ArenaDrops.Clear() end
	State.phase = phase
	State.phaseEndsAt = os.clock() + seconds
	pushAll()
end

-- สร้างแถวของบอทครั้งเดียวตอนบูต ตามจำนวนที่ล็อบบี้สั่งมา
-- บอทเลือกซื้อของตอนต้นรอบ ด้วยเงินและราคาเดียวกับคน (ArenaConfig.Shop)
-- สายระยะใกล้/ไกลสุ่มครั้งเดียวต่อบอท · อาวุธ: ตัวแพงสุดที่ซื้อไหวในสายตัวเอง (ถ้ายังไม่มี) ·
-- เกราะ: อัปเกรดเป็นชุดดีสุดที่ซื้อไหว · ยา: เหลือเงินพอค่อยซื้อ · อาวุธที่มีสกิล: ซื้อน้ำเติมมานาจนเต็ม
local BOT_WEAPONS = { melee = { "Greatsword", "Shield", "Sword" }, ranged = { "Bow", "Spellbook", "Staff", "Pistol" } }
local BOT_ARMORS = { "PlateArmor", "ChainmailArmor", "LeatherArmor" }

local function botShop(entry)
	local L = entry.loadout
	-- บอทที่รอดพร้อมปืน: กระสุนเต็มใหม่ทุกรอบเหมือนคน
	local gun = L.weapon and ArenaConfig.ShopEntry(L.weapon)
	if gun and gun.ammo then L.ammo = gun.ammo end
	local function buy(id)
		local e = ArenaConfig.ShopEntry(id)
		if e and entry.silver >= e.price then
			entry.silver -= e.price
			return e
		end
		return nil
	end
	if not L.weapon then
		for _, id in ipairs(BOT_WEAPONS[entry.style] or BOT_WEAPONS.melee) do
			local e = buy(id)
			if e then
				L.weapon, L.ammo = id, e.ammo
				break
			end
		end
	end
	for _, id in ipairs(BOT_ARMORS) do
		if id == L.armor then break end -- มีชุดนี้หรือดีกว่าอยู่แล้ว
		if buy(id) then
			L.armor, L.armorPool = id, nil
			break
		end
	end
	if not L.use and entry.silver >= 400 and buy("HealthPotion") then L.use = "HealthPotion" end
	local item = L.weapon and ItemCatalog.Items[L.weapon]
	if item and item.skill then
		for _ = 1, 3 do
			if (L.mana or 0) >= VitalsConfig.MaxMana or not buy("Water") then break end
			L.mana = (L.mana or 0) + 1
		end
	end
end

local function buildBotRoster()
	local n = 0
	for _, side in ipairs(ArenaConfig.TeamOrder) do
		local want = (record.bots and record.bots[side]) or 0
		for _ = 1, want do
			n += 1
			table.insert(BotRoster, {
				side = side,
				name = ArenaConfig.Bots.names[((n - 1) % #ArenaConfig.Bots.names) + 1],
				stats = newStats(),
				silver = ArenaConfig.Economy.start,
				loadout = {},
				style = math.random() < 0.5 and "melee" or "ranged",
			})
		end
	end
end

local function startRound()
	State.round += 1
	State.lastRoundWinner = nil
	State.firstBlood = false -- FIRST BLOOD นับใหม่ทุกรอบ

	-- **รอดรอบที่แล้ว = ของที่ซื้อไว้ติดตัวต่อ (รวมยาและมานา) · ตาย = หายหมด ซื้อใหม่** (ผู้ใช้สั่ง 2026-09-24)
	for _, f in pairs(Fighters) do
		if f.kind == "player" and not f.left then
			if State.round == 1 or f.diedThisRound then
				wipeLoadout(f)
			elseif f.loadout.use and Inventory.CountOf(f.player, f.loadout.use) == 0 then
				f.loadout.use = nil -- ใช้ยาไปแล้วในรอบก่อน
			end
			-- ปืนรอดข้ามรอบ = กระสุนเติมกลับเต็มทุกรอบ (ผู้ใช้สั่ง 2026-09-25)
			local gun = f.loadout.weapon and ArenaConfig.ShopEntry(f.loadout.weapon)
			if gun and gun.ammo then
				removeAll(f.player, "Bullet")
				Inventory.AddItem(f.player, "Bullet", gun.ammo)
			end
		end
		-- ต่อเวลา (รอบ 7+): ทุกคนเริ่มรอบด้วยเงินเท่ากัน ทั้งคนและบอท (บอทคัดลอก f.silver ลงแถวของมันข้างล่าง)
		local E = ArenaConfig.Economy
		if E.overtimeRound and State.round >= E.overtimeRound then f.silver = E.overtimeSilver end
		f.diedThisRound = false
		f.boughtThisRound = {}
		f.receipts = {} -- ยกเลิกการซื้อได้เฉพาะของรอบนี้
		f.stats.roundKills = 0
		f.roundDamage = {}
		f.recentHits = {} -- แอสซิสนับต่อชีวิต: รอบใหม่ = ชีวิตใหม่
		f.lastHitBy = nil
		f.killStreak, f.lastKillAt, f.headshotBy = 0, nil, nil
	end

	-- เกิดใหม่ทุกคนทั้งสองฝั่ง รวมคนที่ตายไปเมื่อรอบที่แล้ว
	-- ร่างบอทของรอบก่อนถูกลบทั้งหมด แถวของมันใน `Fighters` จึงต้องถูกลบตามไปด้วย ไม่งั้นการนับ
	-- "ยังเหลือกี่คน" จะนับร่างที่ไม่มีอยู่แล้ว แล้วรอบใหม่จะไม่มีวันจบ
	-- บอท: เก็บเงินกับของที่ยังเหลือกลับลงแถวของมันก่อนลบร่าง — **รอดรอบ = พกของต่อ · ตาย = หายหมด**
	-- กติกาเดียวกับคน (ผู้ใช้สั่ง 2026-09-24 ให้บอทซื้อของได้เหมือนคน)
	for key, f in pairs(Fighters) do
		if f.kind == "bot" and f.entry then
			f.entry.silver = f.silver
			f.entry.loadout = f.alive and ArenaBots.Loadout(key) or {}
		end
	end
	ArenaBots.Clear()
	for key, f in pairs(Fighters) do
		if f.kind == "bot" then Fighters[key] = nil end
	end

	local index = { A = 0, B = 0 }
	for _, f in pairs(Fighters) do
		if f.kind == "player" then
			index[f.side] += 1
			spawnPlayer(f, index[f.side])
		end
	end
	for _, entry in ipairs(BotRoster) do
		index[entry.side] += 1
		local model = ArenaBots.Spawn(entry.side, entry.name, spawnCFrame(entry.side, index[entry.side]), MAP.origin)
		if model then
			botShop(entry)
			ArenaBots.Equip(model, entry.loadout)
			Fighters[model] = {
				kind = "bot", model = model, side = entry.side, name = entry.name,
				silver = entry.silver, alive = true, loadout = {}, boughtThisRound = {},
				stats = entry.stats, -- **ตารางเดียวกับรอบก่อน** คะแนนจึงสะสมต่อ
				recentHits = {}, roundDamage = {}, entry = entry,
			}
		end
	end

	beginPhase("buy", State.round == 1 and ArenaConfig.Phase.buyFirst or ArenaConfig.Phase.buy)
	freezeAll(true)
end

-- คืนฝั่งที่ชนะรอบ หรือ nil ถ้ายังไม่จบ
local function roundWinner()
	local aliveA, aliveB = countIn("A", true), countIn("B", true)
	if aliveA == 0 and aliveB == 0 then return "draw" end
	if aliveA == 0 then return "B" end
	if aliveB == 0 then return "A" end
	if phaseSecondsLeft() > 0 then return nil end

	-- หมดเวลา: ตัดสินด้วยจำนวนคนที่ยังยืนอยู่ ถ้าเท่ากันดูเลือดรวม ถ้ายังเท่ากันอีกถือว่าเสมอ
	if aliveA ~= aliveB then return aliveA > aliveB and "A" or "B" end
	local hp = { A = 0, B = 0 }
	for _, f in pairs(Fighters) do
		if f.alive and f.kind == "player" then
			local fractions = Vitals.Fractions(f.player)
			hp[f.side] += (fractions and fractions.hp or 0)
		elseif f.alive then
			hp[f.side] += 0.5
		end
	end
	if math.abs(hp.A - hp.B) > 0.01 then return hp.A > hp.B and "A" or "B" end
	return "draw"
end

local function finishMatch()
	State.over = true
	freezeAll(true)

	local rows = {}
	for _, f in pairs(Fighters) do
		table.insert(rows, {
			userId = f.kind == "player" and f.player.UserId or nil,
			name = f.name,
			side = f.side,
			bot = f.kind == "bot",
			kills = f.stats.kills,
			deaths = f.stats.deaths,
			assists = f.stats.assists,
			damage = math.floor(f.stats.damage + 0.5),
			won = State.wins[f.side] > State.wins[f.side == "A" and "B" or "A"],
			score = ArenaConfig.Score(f.stats),
		})
	end
	table.sort(rows, function(a, b) return a.score > b.score end)
	ArenaRewards.Grant(rows)

	local winner = State.wins.A > State.wins.B and "A" or (State.wins.B > State.wins.A and "B" or nil)
	beginPhase("matchEnd", ArenaConfig.Phase.matchEnd)
	Remotes.ArenaMatchEnd:FireAllClients({ rows = rows, winner = winner, wins = State.wins })

	task.delay(ArenaConfig.Phase.matchEnd, function()
		for _, player in ipairs(Players:GetPlayers()) do
			pcall(function() TeleportService:Teleport(ServerConfig.MainPlaceId, player) end)
		end
		-- บันทึกแมตช์หมดหน้าที่แล้ว เซิร์ฟนี้กำลังจะว่างและถูกปิด
		ArenaRegistry.ClearMatch(game.PrivateServerId)
	end)
end

--------------------------------------------------------------------------------
-- นาฬิกาของแมตช์
--------------------------------------------------------------------------------
local function matchLoop()
	-- รอให้คนมาถึงก่อน: เซิร์ฟถูกจองไว้ *เพราะ* จะมีคนถูกย้ายมา คนแรกอาจมาถึงตอนสคริปต์ยังไม่จบบรรทัดแรก
	local expected = #(record.teams.A or {}) + #(record.teams.B or {})
	local waitUntil = os.clock() + 25
	while os.clock() < waitUntil do
		local here = 0
		for _, f in pairs(Fighters) do
			if f.kind == "player" then here += 1 end
		end
		if expected > 0 and here >= expected then break end
		if record.studio and here >= 1 then break end
		task.wait(0.5)
	end

	buildBotRoster()
	startRound()

	while not State.over do
		task.wait(0.25)

		if State.phase == "buy" then
			if phaseSecondsLeft() <= 0 then
				freezeAll(false)
				beginPhase("live", ArenaConfig.Phase.live)
			end
		elseif State.phase == "live" then
			local winner = roundWinner()
			if winner then
				State.lastRoundWinner = winner
				if winner ~= "draw" then State.wins[winner] += 1 end
				payRound(winner)
				freezeAll(true)
				beginPhase("roundEnd", ArenaConfig.Phase.roundEnd)
			end
		elseif State.phase == "roundEnd" then
			if phaseSecondsLeft() <= 0 then
				local done = State.wins.A >= ArenaConfig.RoundsToWin
					or State.wins.B >= ArenaConfig.RoundsToWin
					or State.round >= ArenaConfig.MaxRounds
				if done then finishMatch() else startRound() end
			end
		end

		-- ตัวเลขบนจอต้องเดินจริง — ส่งภาพใหม่ทุกวินาที ไม่ใช่เฉพาะตอนเปลี่ยนเฟส
		if os.clock() - (State.lastPush or 0) >= 1 then
			State.lastPush = os.clock()
			pushAll()
		end
	end
end

--------------------------------------------------------------------------------
-- คนเข้า/ออก
--------------------------------------------------------------------------------
local function sendHome(player, reason)
	warn("[Arena] ปฏิเสธ", player.Name, "-", reason)
	task.spawn(function()
		task.wait(1)
		pcall(function() TeleportService:Teleport(ServerConfig.MainPlaceId, player) end)
	end)
end

PlayerJoin.Each(function(player)
	local side = sideOfUserId(player.UserId)

	-- กลับเข้ามาหลังหลุด: ถอดบอทที่ส่งมาแทนเขาออก (มีผลรอบถัดไป ร่างบอทรอบนี้เล่นต่อจนจบรอบ)
	for i, entry in ipairs(BotRoster) do
		if entry.replaces == player.UserId then
			table.remove(BotRoster, i)
			break
		end
	end

	if not side and (record.studio or AdminRoster.IsAdmin(player)) then
		-- แอดมินเข้าดู/เทสแมตช์ไหนก็ได้ — ลงฝั่งที่คนน้อยกว่า
		side = countIn("A") <= countIn("B") and "A" or "B"
	end
	if not side then
		return sendHome(player, "ไม่ได้อยู่ในแมตช์นี้")
	end

	Fighters[player] = {
		kind = "player", player = player, side = side,
		name = player.DisplayName ~= "" and player.DisplayName or player.Name,
		silver = ArenaConfig.Economy.start,
		alive = false,
		loadout = {},
		boughtThisRound = {},
		stats = newStats(),
		recentHits = {},
		roundDamage = {},
		skins = {},
	}
	local f = Fighters[player]
	task.spawn(function() f.skins = mainGameSkins(player.UserId) end)

	-- **เกิดทันทีถ้ารอบยังไม่เริ่ม** — `CharacterAutoLoads` ถูกปิดไว้ คนที่ไม่มีร่างคือคนที่มองเห็น
	-- แต่จอดำ · ระหว่างรออีกห้าคนนั่นคือหน้าจอแรกที่เขาเห็นในโหมดนี้
	-- มาสายกลางรอบ = รอรอบหน้าเหมือนคนที่ตายไปแล้ว (ฝั่งไคลเอนต์ย้ายกล้องไปมองกลางสนามให้)
	if State.phase == "warmup" or State.phase == "buy" then
		spawnPlayer(f, countIn(side))
	end
	print(("[Arena] %s เข้าทีม %s"):format(player.Name, side))
	pushAll()
end)

Players.PlayerRemoving:Connect(function(player)
	local f = Fighters[player]
	if f then
		-- **ไม่ลบทิ้ง** — ตารางอันดับตอนจบต้องมีชื่อคนที่ออกกลางคันอยู่ด้วย และรางวัลของเขาถูกฝากไว้
		-- ตามผลงานที่ทำไปแล้ว (`ArenaRewards` ฝากกับ userId ไม่ได้ยื่นให้ถึงมือตอนนั้น)
		f.alive = false
		f.left = true
		-- **คนออกกลางแมตช์ = ส่งบอทมาแทน** (ผู้ใช้สั่ง 2026-09-24) · เข้าตั้งแต่รอบถัดไป (รอบนี้นับว่าคนนั้นตายแล้ว)
		-- ทีมที่เหลือสองคนสู้สามต่อทั้งแมตช์คือแมตช์ที่แพ้ตั้งแต่ตอนนั้น · กลับเข้ามาใหม่ = บอทตัวนี้ถูกถอด
		if not State.over and f.kind == "player" then
			local used = {}
			for _, entry in ipairs(BotRoster) do used[entry.name] = true end
			local name = nil
			for _, candidate in ipairs(ArenaConfig.Bots.names) do
				if not used[candidate] then name = candidate break end
			end
			table.insert(BotRoster, {
				side = f.side,
				name = name or ("หุ่นไอน้ำ-%02d"):format(#BotRoster + 1),
				stats = newStats(),
				replaces = player.UserId,
				-- บอทแทนรับเงินที่คนนั้นเหลือไว้ (ของที่ถือไปพร้อมคนที่ออก บอทซื้อใหม่เอง)
				silver = f.silver,
				loadout = {},
				style = math.random() < 0.5 and "melee" or "ranged",
			})
			print(("[Arena] %s ออกจากเกม — บอทเข้าแทนในทีม %s ตั้งแต่รอบหน้า"):format(player.Name, f.side))
		end
	end
	Anchored[player] = nil
end)

task.spawn(matchLoop)
print(("[Arena] แมตช์บนแมพ %s · ทีม A %d คน / ทีม B %d คน · บอท A=%d B=%d"):format(
	MAP.name, #(record.teams.A or {}), #(record.teams.B or {}),
	(record.bots and record.bots.A) or 0, (record.bots and record.bots.B) or 0))
