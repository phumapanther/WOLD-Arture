-- IslandNight.server.lua: มอนบุกเกาะตอนกลางคืน + อีเวนต์พาเหรดมอนสเตอร์ (ผู้ใช้สั่ง 2026-09-28)
-- สเปก docs/superpowers/specs/2026-09-28-island-night-raid-design.md · กติกาล้วน `IslandNightRules` · ตัวเลข `IslandConfig.NightRaid`
--
-- ไฟล์นี้คุมแค่จังหวะ: เพิ่งมืด → ทอยแล้วปล่อยมอน · คืนพาเหรด → เติมทุก 20 วิ · เพิ่งสว่าง → เก็บหมด
-- AI · ดรอป · EXP · นับเควส/สมุด อยู่กับ `Mobs.server` (ผ่าน `MobAccess.SpawnRaid/Despawn`)
-- ป้ายพาเหรด: เกาะไม่มี `WorldEvents.server` → ยิง `EventStateChanged` เอง ทรงเดียวกับ `WorldEvents.picture()`
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local ServerConfig = require(game.ServerScriptService.ServerConfig)
if not ServerConfig.IsFarm then return end

local IslandConfig = require(game.ReplicatedStorage.IslandConfig)
local IslandGrid = require(game.ReplicatedStorage.IslandGrid)
local GatherConfig = require(game.ReplicatedStorage.GatherConfig)
local Rules = require(game.ReplicatedStorage.IslandNightRules)
local Remotes = require(game.ReplicatedStorage.Remotes)
local MobAccess = require(game.ServerScriptService.MobAccess)
local IslandAccess = require(script.Parent.IslandAccess)

local R = IslandConfig.NightRaid
local Parade = nil -- { startedAt, endsAt } (เวลาเซิร์ฟ) ระหว่างคืนพาเหรด
local nextParadeAt = 0

local function isNight()
	return workspace:GetAttribute("WOLD_IsNight") == true
end

local function farmLevel()
	return IslandAccess.FarmLevel and IslandAccess.FarmLevel() or 1
end

local function raiders()
	local out = {}
	for _, m in ipairs(CollectionService:GetTagged(R.tag)) do
		if m.Parent then out[#out + 1] = m end
	end
	return out
end

-- ภาพอีเวนต์ทรงเดียวกับ WorldEvents.picture() · ว่าง = ไม่มีป้าย
local function picture()
	if not Parade then return {} end
	local b = R.banner
	return { parade = { icon = b.icon, message = b.message, colour = b.colour, sound = b.sound,
		startedAt = Parade.startedAt, endsAt = Parade.endsAt } }
end

local function publish()
	Remotes.EventStateChanged:FireAllClients(picture())
end

-- คนที่เข้าเกาะกลางคืนพาเหรดก็ต้องเห็นป้าย (EventBannerController ถามตอนเริ่ม)
Remotes.RequestEventState.OnServerEvent:Connect(function(player)
	Remotes.EventStateChanged:FireClient(player, picture())
end)

-- คนบนเกาะที่ยังยืนอยู่
local function standing()
	local out = {}
	for _, p in ipairs(Players:GetPlayers()) do
		local root = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
		if root and not p:GetAttribute("WOLD_Downed") then out[#out + 1] = p end
	end
	return out
end

-- ช่องดินในรั้วที่ว่าง ห่างเป้า 30-60 สตัดก่อน ไม่มีก็ช่องดินว่างไหนก็ได้ · ไม่มีเลย = nil (ไม่เกิด)
local function spawnPoint(target)
	local cells = IslandAccess.SoilCells and IslandAccess.SoilCells() or {}
	if #cells == 0 or not IslandAccess.SoilCellFree then return nil end
	local root = target.Character and target.Character:FindFirstChild("HumanoidRootPart")
	local near, far = {}, {}
	for _, c in ipairs(cells) do
		local x, z = IslandGrid.worldOf(c[1], c[2])
		local d = root and Vector2.new(x - root.Position.X, z - root.Position.Z).Magnitude or 0
		if d >= R.spawnMinDistance and d <= R.spawnMaxDistance then near[#near + 1] = c else far[#far + 1] = c end
	end
	for _, list in ipairs({ near, far }) do
		for _ = 1, math.min(30, #list) do
			local c = list[math.random(#list)]
			if IslandAccess.SoilCellFree(c[1], c[2]) then
				local y = IslandGrid.surfaceAt(c[1], c[2])
				if y then
					local x, z = IslandGrid.worldOf(c[1], c[2])
					return Vector3.new(x, y, z)
				end
			end
		end
	end
	return nil
end

-- ปล่อยหนึ่งตัว · role = nil (ธรรมดา) | "boss" | "special" | "leader" · kind = ชนิดจากชุดตามเลเวล
local function spawn(role, kind)
	local list = standing()
	if #list == 0 or not MobAccess.SpawnRaid then return nil end
	local target = list[math.random(#list)]
	local at = spawnPoint(target)
	if not at then return nil end
	local opts = { maxHitFraction = R.maxHitFraction, tag = R.tag }
	if role == "boss" then
		kind = R.boss.kind
		opts.hp = R.boss.hp
		opts.loot = { only = { { item = R.boss.drop, min = 1, max = 1 } } }
	elseif role == "special" then
		kind = Rules.Pick(R.specials)
		opts.loot = { extra = { { item = R.specialChest, min = 1, max = 1 } } }
	elseif role == "leader" then
		local L, config = R.leader, GatherConfig.Mobs[kind]
		opts.scale = L.scale * (config.scale or 1)
		opts.power = L.power
		opts.title = "👑 หัวหน้าฝูง " .. (config.name or kind)
		opts.loot = { amount = L.amount, xp = L.xp }
	end
	if not kind then return nil end
	return MobAccess.SpawnRaid(kind, at, target, opts)
end

local function startParade()
	local now = workspace:GetServerTimeNow()
	Parade = { startedAt = now, endsAt = now + Rules.SecondsToDawn(Lighting.ClockTime) }
	nextParadeAt = os.clock() + R.paradeEverySeconds
	publish()
end

-- หัวค่ำ: 1-3 ตัว (ตัวแรกเป็นตัวพิเศษถ้าทอยติด) + พาเหรดถ้าทอยติด · คืนจำนวนที่เกิดจริง
local function raid(night)
	local pool = Rules.PoolFor(math.max(farmLevel(), R.minFarmLevel))
	local made = 0
	for i = 1, math.random(R.countMin, R.countMax) do
		if spawn(i == 1 and night.special or nil, Rules.Pick(pool)) then made += 1 end
	end
	if night.parade then startParade() end
	return made
end

-- เช้า: มอนบุกหายหมด ไม่ดรอป + ปิดป้าย
local function dawn()
	local n = 0
	for _, m in ipairs(raiders()) do
		MobAccess.Despawn(m)
		n += 1
	end
	if Parade then
		Parade = nil
		publish()
	end
	return n
end

-- จังหวะคืน (ลูป 1 วิ) · บูตกลางคืนไม่นับว่าเพิ่งมืด (เซิร์ฟเริ่มตอนเช้าเสมอ StartTime 7)
local wasNight = nil
local function tick()
	local night = isNight()
	local changed = wasNight ~= nil and night ~= wasNight
	-- จดก่อนทำงาน: งานข้างล่างพังแล้วรอบหน้าต้องไม่ถือว่า "เพิ่งมืด" ซ้ำ (ไม่งั้นปล่อยมอนซ้ำทุกวินาที)
	wasNight = night
	if changed then
		if night then
			if farmLevel() >= R.minFarmLevel then
				local night0 = Rules.RollNight()
				local made = raid(night0)
				print(("[IslandNight] มืดแล้ว: มอน %d ตัว · พิเศษ %s · พาเหรด %s"):format(
					made, tostring(night0.special), tostring(night0.parade)))
			end
		else
			local n = dawn()
			if n > 0 then print(("[IslandNight] เช้าแล้ว: เก็บมอนบุก %d ตัว"):format(n)) end
		end
	end
	if Parade and night then
		-- นาฬิกาถูกล็อก/กระโดด (/time) = เวลาถึงเช้าเปลี่ยน → ส่งป้ายใหม่ (รีวิว 2026-09-28)
		local fixed = Rules.DawnDrift(Parade.endsAt, workspace:GetServerTimeNow(), Lighting.ClockTime)
		if fixed then
			Parade.endsAt = fixed
			publish()
		end
		if os.clock() >= nextParadeAt then
			nextParadeAt = os.clock() + R.paradeEverySeconds
			if #raiders() < R.paradeMaxAlive then
				local level = math.max(farmLevel(), R.minFarmLevel)
				spawn(nil, Rules.Pick(Rules.PoolAt(level, Rules.Progress(Lighting.ClockTime))))
			end
		end
	end
end

task.spawn(function()
	while true do
		task.wait(1)
		-- รอบหนึ่งพังต้องไม่หยุดทั้งลูป (รีวิว 2026-09-28): ลูปตาย = เช้าไม่มาเก็บมอน มอนไล่ทั้งวัน ป้ายค้าง
		local ok, err = pcall(tick)
		if not ok then warn("[IslandNight] " .. tostring(err)) end
	end
end)

-- /night [raid | parade | boss | special | leader | clear] — เทสในเกม (AdminCommands เรียก)
IslandAccess.NightAdmin = function(_, args)
	local sub = string.lower(args[1] or "")
	local pool = Rules.PoolFor(math.max(farmLevel(), R.minFarmLevel))
	if sub == "raid" then
		return ("ปล่อยมอนบุก %d ตัว"):format(raid({ special = nil, parade = false }))
	elseif sub == "parade" then
		if not isNight() then return "พาเหรดเริ่มได้ตอนกลางคืนเท่านั้น — /time 20 แล้ว /time auto ก่อน" end
		startParade()
		return "เริ่มพาเหรดมอนสเตอร์ถึงเช้า"
	elseif sub == "boss" or sub == "special" or sub == "leader" then
		return spawn(sub, Rules.Pick(pool)) and ("ปล่อย %s แล้ว"):format(sub)
			or "ปล่อยไม่ได้ (ไม่มีช่องดินว่าง · ไม่มีใครยืนอยู่ · หรือไม่มีต้นแบบมอน)"
	elseif sub == "clear" then
		return ("เก็บมอนบุก %d ตัว"):format(dawn())
	elseif sub ~= "" then
		return "ใช้: /night [raid | parade | boss | special | leader | clear]"
	end
	return ("ตอนนี้%s · มอนบุก %d ตัว%s · เลเวลฟาร์ม %d (มอนบุกเริ่มที่ %d) · ช่องดิน %d"):format(
		isNight() and "กลางคืน" or "กลางวัน", #raiders(), Parade and " · พาเหรดอยู่" or "",
		farmLevel(), R.minFarmLevel, IslandAccess.SoilCells and #IslandAccess.SoilCells() or 0)
end
