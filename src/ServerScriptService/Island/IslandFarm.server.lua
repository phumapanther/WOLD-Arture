-- IslandFarm (เฟส 2c ผู้ใช้อนุมัติร่าง 2026-09-27): เลเวลฟาร์ม + รถส่งออก + ฉลองเลเวลขึ้น
--
-- เจ้าของ `profile.Data.Island.farm` ของเจ้าของเกาะ (ตารางเดียวกับที่ ProfileStore เซฟ ผ่าน IslandAccess.Data)
--   farm = { exp, celebrated, nextId, orders = {o1,o2,o3}, ship = {slot, order, startAt, endAt} | nil,
--            gemDay, gemDayCount, gemDayOrders, gemMonth, gemMonthCount, rerollDay }
--
-- วงจร: กด E ที่ท้ายรถ `Car_Cargo` → หน้าต่างใบสั่ง 3 ใบ → "ส่งของ" = ของออกจากกระเป๋าทันที รถ "ออก" 30 นาที
-- (จอดอยู่ที่เดิม มีป้ายเวลา) → ครบเวลา = เหรียญ/เพชร/EXP ฟาร์มเข้าเอง ใบใหม่มาแทน → เลเวลขึ้น = ฉลอง
--
-- กติกาที่ต้องไม่พัง:
--   · **EXP ฟาร์มเข้าทางเดียวคือการจบงานส่งออก** และจบได้ที่นี่ที่เดียว (ลูปเจอว่าครบเวลา) — ตอนเจ้าของอยู่บนเกาะ
--     ส่งเสร็จตอนออฟไลน์ = จบตอนเข้าเกาะครั้งหน้า (โปรไฟล์เปิดอยู่ที่นี่เท่านั้น เกมหลักไม่ต้องคำนวณอะไร)
--   · จบงาน = ล้าง `farm.ship` ก่อนแจก และไม่มี yield ระหว่างทาง → ไม่มีทางได้รางวัลซ้ำ
--   · ฉลอง: จด `celebrated` เมื่อไคลเอนต์ตอบว่าเห็นแบนเนอร์แล้ว → ออกเกมก่อนเห็นก็ไม่หาย และไม่ฉลองซ้ำ
local ServerConfig = require(game.ServerScriptService.ServerConfig)
if not ServerConfig.IsFarm then return end

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")

local Inventory = require(game.ServerScriptService.Inventory)
local ProfileAccess = require(game.ServerScriptService.ProfileAccess)
local PremiumAccess = require(game.ServerScriptService.PremiumAccess)
local Fireworks = require(game.ServerScriptService.Fireworks)
local IslandAccess = require(script.Parent.IslandAccess)
local FarmLevelConfig = require(ReplicatedStorage.FarmLevelConfig)
local ExportConfig = require(ReplicatedStorage.ExportConfig)
local ExportOrders = require(ReplicatedStorage.ExportOrders)
local CraftConfig = require(ReplicatedStorage.CraftConfig) -- ราคา 💎 รถกลับทันที (InstantGems)
local ItemCatalog = require(ReplicatedStorage.ItemCatalog)
local Remotes = require(ReplicatedStorage.Remotes)

local TRUCK_NAME = "Car_Cargo"
local PROMPT_RANGE = 12
-- ด่านระยะของคำสั่งจากหน้าต่าง วัดจากกลางรถ (รถยาว 17 สตัด ปุ่มอยู่ท้ายรถ) — กว้างกว่าปุ่มนิดหน่อยกันเด้ง
local ACTION_RANGE = 26
local MIN_GAP = 0.4 -- วินาที ระหว่างคำสั่งของคนเดียวกัน

local rng = Random.new()
local Truck = nil -- โมเดลรถที่ต่อสายแล้ว
local Watching = {} -- [player] = true ระหว่างเปิดหน้าต่าง
local LastAction = {} -- [player] = os.clock()
local Ready = {} -- [player] = true เมื่อจอโหลดจบแล้ว (พร้อมเห็นแบนเนอร์)
local Offered = {} -- [player] = เลเวลที่ส่งแบนเนอร์ไปแล้วรอบนี้ (กันส่งซ้ำทุกวินาที)
local FxAt = {} -- [player] = os.clock() ของพลุครั้งล่าสุด

local function commas(n)
	local s = tostring(math.floor(n))
	repeat
		local k
		s, k = s:gsub("^(-?%d+)(%d%d%d)", "%1,%2")
	until k == 0
	return s
end

local function flush(player)
	if player and ProfileAccess.Flush then ProfileAccess.Flush(player) end
end

--------------------------------------------------------------------------------
-- ข้อมูล
--------------------------------------------------------------------------------

local function levelOf(farm)
	return (FarmLevelConfig.LevelFromExp(farm.exp))
end

local function nextId(farm)
	local id = farm.nextId
	farm.nextId = id + 1
	return id
end

local function othersThan(farm, slot)
	local others = {}
	for s = 1, ExportConfig.OrderSlots do
		if s ~= slot and farm.orders[s] then others[#others + 1] = farm.orders[s] end
	end
	return others
end

-- งานส่งที่โหลดมายังอ่านได้ไหม (ข้อมูลเสีย = ทิ้ง · ของออกจากกระเป๋าไปแล้วก็จริง แต่ไม่มีทางรู้ว่าต้องจ่ายเท่าไหร่)
local function shipValid(ship)
	if not (type(ship) == "table" and type(ship.order) == "table" and type(ship.endAt) == "number"
		and type(ship.startAt) == "number" and tonumber(ship.order.coins) and tonumber(ship.order.exp)
		and type(ship.slot) == "number" and ship.slot >= 1 and ship.slot <= ExportConfig.OrderSlots
		and type(ship.order.lines) == "table") then
		return false
	end
	-- หน้าต่างวาดบรรทัดของใบที่กำลังส่งด้วย — บรรทัดเสียจะทำให้ภาพพังทั้งหน้าต่าง
	for _, line in ipairs(ship.order.lines) do
		if type(line) ~= "table" or type(line.item) ~= "string" or type(line.qty) ~= "number" then return false end
	end
	return true
end

-- ใบสั่งครบ 3 ช่องเสมอ (อาร์เรย์ไม่มีรู — DataStore เก็บเป็น JSON array ได้ตรงๆ) · ใบเสีย/ขาด = สุ่มใหม่
local function ensureOrders(farm)
	local level = levelOf(farm)
	for slot = 1, ExportConfig.OrderSlots do
		local shipping = farm.ship ~= nil and farm.ship.slot == slot
		if not shipping and not ExportOrders.Valid(farm.orders[slot]) then
			farm.orders[slot] = ExportOrders.Fresh(level, rng, nextId(farm), othersThan(farm, slot))
		elseif shipping and type(farm.orders[slot]) ~= "table" then
			farm.orders[slot] = farm.ship.order
		end
	end
	for slot = #farm.orders, ExportConfig.OrderSlots + 1, -1 do farm.orders[slot] = nil end
end

-- ตารางฟาร์มของเจ้าของเกาะ · nil = โปรไฟล์ยังไม่โหลด/เจ้าของไม่อยู่ · สร้างแบบ lazy (Data.Island ก็ lazy)
local function farmData()
	local data = IslandAccess.Data and IslandAccess.Data()
	if not data then return nil end
	local farm = data.farm
	if type(farm) ~= "table" then
		farm = {}
		data.farm = farm
	end
	farm.exp = math.max(0, math.floor(tonumber(farm.exp) or 0))
	farm.nextId = math.max(1, math.floor(tonumber(farm.nextId) or 1))
	-- ผู้เล่นเก่าเริ่ม Lv1 (ผู้ใช้เลือก 2026-09-27) · ฟาร์มใหม่ = ฉลองไปแล้วถึงเลเวลปัจจุบัน ไม่มีแบนเนอร์ตอนเปิดครั้งแรก
	farm.celebrated = math.max(1, math.floor(tonumber(farm.celebrated) or levelOf(farm)))
	if type(farm.orders) ~= "table" then farm.orders = {} end
	if farm.ship ~= nil and not shipValid(farm.ship) then
		warn("[IslandFarm] งานส่งออกในโปรไฟล์อ่านไม่ออก ทิ้ง")
		farm.ship = nil
	end
	ensureOrders(farm)
	return farm
end

local function ownerPlayer()
	if not IslandAccess.IsOwner then return nil end
	for _, p in ipairs(Players:GetPlayers()) do
		if IslandAccess.IsOwner(p) then return p end
	end
	return nil
end

--------------------------------------------------------------------------------
-- สิ่งที่คนอื่นเห็น: แอตทริบิวต์บนตัวเจ้าของ (ป้ายมุมจอ) + บนตัวรถ (ป้ายเหนือรถ ควันปล่อง)
--------------------------------------------------------------------------------

local function publish(farm)
	local level, into, need = FarmLevelConfig.LevelFromExp(farm.exp)
	local owner = ownerPlayer()
	if owner then
		owner:SetAttribute("FarmLevel", level)
		owner:SetAttribute("FarmExpInto", into)
		owner:SetAttribute("FarmExpNeed", need)
		owner:SetAttribute("FarmShipEnd", farm.ship and farm.ship.endAt or nil)
	end
	if Truck and Truck.Parent then
		Truck:SetAttribute("FarmLevel", level)
		Truck:SetAttribute("ShipStart", farm.ship and farm.ship.startAt or nil)
		Truck:SetAttribute("ShipEnd", farm.ship and farm.ship.endAt or nil)
	end
end

--------------------------------------------------------------------------------
-- หน้าต่าง
--------------------------------------------------------------------------------

-- จำนวนที่ผู้เล่นมี "ที่ใบนี้นับให้" — ใบธรรมดาข้ามของขอบทอง (กฎวัตถุดิบ 2b) · ใบขอบทองนับแต่ชิ้นทอง
local function haveFor(player, order, id)
	if order.gold then return Inventory.CountGold(player, id) end
	return Inventory.CountOf(player, id)
end

local function snapshot(player, farm, open)
	local now = os.time()
	ExportOrders.ResetCounters(farm, now)
	local day = ExportOrders.DayMonth(now)
	local level, into, need = FarmLevelConfig.LevelFromExp(farm.exp)
	local cards = {}
	for slot = 1, ExportConfig.OrderSlots do
		local o = farm.orders[slot]
		local shipping = farm.ship ~= nil and farm.ship.slot == slot
		if shipping then o = farm.ship.order end
		local lines, ready = {}, true
		for _, line in ipairs(o.lines) do
			local have = haveFor(player, o, line.item)
			if have < line.qty then ready = false end
			local item = ItemCatalog.Get(line.item)
			lines[#lines + 1] = {
				item = line.item, qty = line.qty, have = have,
				name = ItemCatalog.DisplayName(line.item, o.gold and { gold = true } or nil),
				icon = item and item.icon or "",
			}
		end
		cards[slot] = {
			slot = slot, gold = o.gold == true, coins = o.coins, exp = o.exp,
			gems = ExportOrders.GemHint(farm, o), lines = lines, ready = ready, shipping = shipping,
		}
	end
	return {
		open = open == true,
		level = level, into = into, need = need, max = FarmLevelConfig.IsMax(level),
		gemsToday = farm.gemDayCount, gemsDayCap = ExportConfig.Gems.perDay,
		rerollLeft = farm.rerollDay == day and 0 or ExportConfig.FreeRerollsPerDay,
		ship = farm.ship and { slot = farm.ship.slot, startAt = farm.ship.startAt, endAt = farm.ship.endAt } or nil,
		now = now, shipSeconds = ExportConfig.ShipSeconds,
		orders = cards,
	}
end

-- ภาพใหม่ถึงคนที่เปิดหน้าต่างค้างไว้ · `open` = เปิดหน้าต่างให้ด้วย (กด E เท่านั้น — ภาพอัปเดตห้ามเปิดหน้าต่างเอง)
local function push(player, farm, open)
	if not player or not player.Parent then return end
	if not open and not Watching[player] then return end
	if not Inventory.Get(player) then return end
	Remotes.ExportOpen:FireClient(player, snapshot(player, farm, open))
end

local function nearTruck(player)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not root or not Truck or not Truck.Parent then return false end
	return (Truck:GetPivot().Position - root.Position).Magnitude <= ACTION_RANGE
end

local function notify(player, kind, text)
	Remotes.SocialNotify:FireClient(player, kind, text)
end

local function openFor(player)
	if not IslandAccess.MayUseFixtures(player) then
		return notify(player, "warn", IslandAccess.FixtureDenied)
	end
	local farm = farmData()
	if not farm or not Inventory.Get(player) then
		return notify(player, "warn", "ข้อมูลเกาะยังโหลดไม่เสร็จ ลองอีกครั้ง")
	end
	Watching[player] = true
	push(player, farm, true)
end

--------------------------------------------------------------------------------
-- ส่ง / สุ่มใหม่
--------------------------------------------------------------------------------

local function ship(player, slot)
	if not IslandAccess.MayUseFixtures(player) then return false, IslandAccess.FixtureDenied end
	local farm = farmData()
	if not farm or not Inventory.Get(player) then return false, "ข้อมูลเกาะยังโหลดไม่เสร็จ" end
	if not nearTruck(player) then return false, "อยู่ไกลจากรถเกินไป" end
	if farm.ship then return false, "รถกำลังส่งของอยู่ รอให้กลับมาก่อน" end
	if type(slot) ~= "number" or slot ~= math.floor(slot) or slot < 1 or slot > ExportConfig.OrderSlots then
		return false, nil
	end
	local order = farm.orders[slot]
	if not ExportOrders.Valid(order) then return false, "ใบสั่งนี้ใช้ไม่ได้" end

	-- ตรวจครบทุกบรรทัดก่อนแตะของสักชิ้น
	for _, line in ipairs(order.lines) do
		local have = haveFor(player, order, line.item)
		if have < line.qty then
			return false, ("ของไม่ครบ: %s %d/%d"):format(ItemCatalog.DisplayName(line.item,
				order.gold and { gold = true } or nil), have, line.qty)
		end
	end

	-- ขนขึ้นรถ · ไม่มี yield ตั้งแต่ตรวจจนถึงตรงนี้จึงไม่ควรพลาด — ถ้าพลาดจริง คืนของที่ขนไปแล้วทั้งหมด
	local taken = {}
	for _, line in ipairs(order.lines) do
		local ok
		if order.gold then
			ok = Inventory.RemoveGold(player, line.item, line.qty)
		else
			ok = Inventory.RemoveById(player, line.item, line.qty)
		end
		if not ok then
			for _, back in ipairs(taken) do
				if order.gold then
					for _ = 1, back.qty do Inventory.AddItem(player, back.item, 1, nil, { gold = true }) end
				else
					Inventory.AddItem(player, back.item, back.qty)
				end
			end
			warn(("[IslandFarm] ขนของขึ้นรถไม่สำเร็จ %s x%d (คืนของแล้ว)"):format(line.item, line.qty))
			return false, "ขนของขึ้นรถไม่สำเร็จ ลองอีกครั้ง"
		end
		taken[#taken + 1] = line
	end

	local now = os.time()
	farm.ship = { slot = slot, order = order, startAt = now, endAt = now + ExportConfig.ShipSeconds }
	flush(player)
	publish(farm)
	notify(player, "info", ("🚚 ส่งของขึ้นรถแล้ว — รถกลับมาใน %d นาที"):format(math.floor(ExportConfig.ShipSeconds / 60)))
	return true
end

local function reroll(player, slot)
	if not IslandAccess.MayUseFixtures(player) then return false, IslandAccess.FixtureDenied end
	local farm = farmData()
	if not farm then return false, "ข้อมูลเกาะยังโหลดไม่เสร็จ" end
	if not nearTruck(player) then return false, "อยู่ไกลจากรถเกินไป" end
	if type(slot) ~= "number" or slot ~= math.floor(slot) or slot < 1 or slot > ExportConfig.OrderSlots then
		return false, nil
	end
	if farm.ship and farm.ship.slot == slot then return false, "ใบนี้กำลังส่งอยู่ สุ่มใหม่ไม่ได้" end
	local day = ExportOrders.DayMonth(os.time())
	if farm.rerollDay == day then return false, "สุ่มใบใหม่ฟรีได้วันละครั้ง — พรุ่งนี้สุ่มได้อีก" end
	farm.orders[slot] = ExportOrders.Fresh(levelOf(farm), rng, nextId(farm), othersThan(farm, slot))
	farm.rerollDay = day
	flush(player)
	return true
end

-- 💎 รถกลับทันที (ผู้ใช้สั่ง 2026-10-02): ราคาเดียวกับเสร็จทันทีของเครื่องคราฟ (CraftConfig.InstantGems · 1 เพชร / 5 นาที)
-- จากเวลาที่เหลือฝั่งเซิร์ฟ · หักผ่าน SpendGems แล้วจบงานเดี๋ยวนี้ด้วย resolve ตัวเดียวกับลูป (ล้าง ship ก่อนแจก = ไม่ซ้ำ)
local resolve -- นิยามข้างล่าง (จบงานส่งออก)
local function instant(player)
	if not IslandAccess.MayUseFixtures(player) then return false, IslandAccess.FixtureDenied end
	local farm = farmData()
	if not farm or not Inventory.Get(player) then return false, "ข้อมูลเกาะยังโหลดไม่เสร็จ" end
	if not nearTruck(player) then return false, "อยู่ไกลจากรถเกินไป" end
	if not farm.ship then return false, "รถไม่ได้กำลังส่งของ" end
	local left = farm.ship.endAt - os.time()
	if left > 0 then
		local gems = CraftConfig.InstantGems(left)
		if not (PremiumAccess.SpendGems and PremiumAccess.SpendGems(player, gems)) then
			local have = PremiumAccess.GetGems and PremiumAccess.GetGems(player) or 0
			return false, ("เพชรไม่พอ ต้องใช้ 💎 %d (มี %d)"):format(gems, have)
		end
		farm.ship.endAt = os.time()
		notify(player, "info", ("💎 ใช้ %d เพชร · รถกลับทันที"):format(gems))
	end
	resolve(player, farm)
	return true
end

Remotes.RequestExport.OnServerEvent:Connect(function(player, action, slot)
	if type(action) ~= "string" then return end
	if action == "close" then
		Watching[player] = nil
		return
	end
	local now = os.clock()
	if LastAction[player] and now - LastAction[player] < MIN_GAP then return end
	LastAction[player] = now
	local ok, why
	if action == "ship" then
		ok, why = ship(player, slot)
	elseif action == "reroll" then
		ok, why = reroll(player, slot)
	elseif action == "instant" then
		ok, why = instant(player)
	else
		return
	end
	if not ok and why then notify(player, "error", why) end
	local farm = farmData()
	if farm then push(player, farm, false) end
end)

--------------------------------------------------------------------------------
-- จบงานส่งออก → รางวัล → เลเวล → ฉลอง
--------------------------------------------------------------------------------

local function offerCelebration(player, farm)
	if not Ready[player] then return end
	local level = levelOf(farm)
	local from = math.clamp(farm.celebrated, 1, level)
	if level <= from or Offered[player] == level then return end
	Offered[player] = level
	Remotes.FarmCelebrate:FireClient(player, { from = from, to = level })
end

function resolve(owner, farm)
	local ship = farm.ship
	-- **รับสิทธิ์ก่อนแจก** ล้างงานออกก่อน และไม่มี yield จนแจกครบ = จบได้ครั้งเดียวแน่นอน
	farm.ship = nil
	local order = ship.order
	local coins = math.max(0, math.floor(tonumber(order.coins) or 0))
	local exp = math.max(0, math.floor(tonumber(order.exp) or 0))

	ExportOrders.ResetCounters(farm, os.time())
	-- ระบบเพชรไม่พร้อม (ไม่ควรเกิด) = ไม่นับเข้าเพดาน ดีกว่านับว่าให้ไปแล้วทั้งที่ไม่ได้
	local gems = PremiumAccess.AddGems and ExportOrders.RollGems(farm, order, rng) or 0
	local wasMax = FarmLevelConfig.IsMax(levelOf(farm))
	-- เพดานเลเวล (ผู้ใช้สั่ง 2026-09-27: ตัน Lv19) — AddExp หยุดนับที่เส้นเพดานเอง (หรือสะสมไว้ ตาม BankExpAtMax)
	farm.exp = FarmLevelConfig.AddExp(farm.exp, exp)
	farm.gemDayOrders += 1
	farm.gemDayCount += gems
	farm.gemMonthCount += gems
	-- ใบใหม่แทนใบที่ส่ง ใช้กองของเลเวลใหม่ (ถ้าเพิ่งขึ้นเลเวล ของที่เพิ่งปลดออกได้ทันที)
	farm.orders[ship.slot] = ExportOrders.Fresh(levelOf(farm), rng, nextId(farm), othersThan(farm, ship.slot))

	if coins > 0 then Inventory.AddGold(owner, coins) end
	if gems > 0 then PremiumAccess.AddGems(owner, gems) end
	flush(owner)
	publish(farm)

	local text = wasMax and ("🚚 รถส่งออกกลับมาแล้ว! +%s เหรียญ · ฟาร์มเลเวลสูงสุดแล้ว"):format(commas(coins))
		or ("🚚 รถส่งออกกลับมาแล้ว! +%s เหรียญ · +%s EXP ฟาร์ม"):format(commas(coins), commas(exp))
	if gems > 0 then text ..= (" · +%d 💎"):format(gems) end
	notify(owner, "info", text)
	push(owner, farm, false)
	offerCelebration(owner, farm)
end

-- พลุวงรอบตัว + ประกายรอบร่าง — สร้างฝั่งเซิร์ฟเวอร์ ทุกคนบนเกาะเห็น (รวมแขก) ตามสเปก
local function celebrateFx(player)
	local now = os.clock()
	if FxAt[player] and now - FxAt[player] < 4 then return end
	FxAt[player] = now
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not root then return end
	Fireworks.Ring(root.Position, 22, 6, 38)

	local sparkle = Instance.new("ParticleEmitter")
	sparkle.Name = "WOLD_FarmLevelSparkle"
	sparkle.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	sparkle.Color = ColorSequence.new(Color3.fromRGB(255, 214, 110), Color3.fromRGB(150, 235, 140))
	sparkle.LightEmission = 1
	sparkle.LightInfluence = 0
	sparkle.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.9), NumberSequenceKeypoint.new(1, 0) })
	sparkle.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) })
	sparkle.Lifetime = NumberRange.new(1.2, 2)
	sparkle.Speed = NumberRange.new(6, 12)
	sparkle.SpreadAngle = Vector2.new(180, 180)
	sparkle.Drag = 3
	sparkle.Acceleration = Vector3.new(0, 4, 0)
	sparkle.Rate = 0
	sparkle.Parent = root
	sparkle:Emit(90)
	local light = Instance.new("PointLight")
	light.Name = "WOLD_FarmLevelLight"
	light.Color = Color3.fromRGB(255, 220, 130)
	light.Brightness = 3
	light.Range = 16
	light.Shadows = false
	light.Parent = root
	Debris:AddItem(sparkle, 4)
	Debris:AddItem(light, 2.5)
end

Remotes.FarmCelebrate.OnServerEvent:Connect(function(player, what, to)
	if what == "ready" then
		Ready[player] = true
		Offered[player] = nil
		local farm = IslandAccess.IsOwner and IslandAccess.IsOwner(player) and farmData()
		if farm then offerCelebration(player, farm) end
		return
	end
	if what ~= "seen" then return end
	if not (IslandAccess.IsOwner and IslandAccess.IsOwner(player)) then return end
	local farm = farmData()
	if not farm then return end
	to = tonumber(to)
	local level = levelOf(farm)
	if not to or to ~= math.floor(to) or to <= farm.celebrated or to > level then return end
	farm.celebrated = to
	flush(player)
	celebrateFx(player)
end)

--------------------------------------------------------------------------------
-- รถ: หาจากชื่อ (ผู้ใช้ย้ายได้) · ปุ่ม E ท้ายรถ
--------------------------------------------------------------------------------

local function anchorOf(truck)
	return truck:FindFirstChild("Tailgate") or truck:FindFirstChild("Deck", true) or truck.PrimaryPart
		or truck:FindFirstChildWhichIsA("BasePart", true)
end

local function wireTruck(truck)
	local anchor = anchorOf(truck)
	if not anchor then return false end
	local prompt = anchor:FindFirstChild("ExportPrompt")
	if not prompt then
		prompt = Instance.new("ProximityPrompt")
		prompt.Name = "ExportPrompt"
		prompt.ActionText = "ส่งออก"
		prompt.ObjectText = "รถส่งออก"
		prompt.KeyboardKeyCode = Enum.KeyCode.E
		prompt.HoldDuration = 0
		prompt.MaxActivationDistance = PROMPT_RANGE
		prompt.RequiresLineOfSight = false
		prompt.Parent = anchor
		prompt.Triggered:Connect(openFor)
	end
	-- ป้าย/ควันฝั่งไคลเอนต์หารถจากแท็กนี้ (ชื่อโมเดลอาจซ้ำกับของตกแต่งอื่นในอนาคต)
	game:GetService("CollectionService"):AddTag(truck, "WOLD_ExportTruck")
	return true
end

local function findTruck()
	if Truck and Truck.Parent and Truck:IsDescendantOf(workspace) then return Truck end
	local island = workspace:FindFirstChild("WOLD_Island")
	local found = island and island:FindFirstChild(TRUCK_NAME, true) or workspace:FindFirstChild(TRUCK_NAME, true)
	if found and found:IsA("Model") and wireTruck(found) then
		Truck = found
		print("[IslandFarm] รถส่งออก: " .. found:GetFullName())
	end
	return Truck
end

--------------------------------------------------------------------------------
-- ลูปหลัก (ทุกวินาที): หารถ · ประกาศสถานะ · จบงานที่ครบเวลา · ส่งแบนเนอร์ที่ค้าง
--------------------------------------------------------------------------------

local lastTruckScan = 0
local warnedNoTruck = false

task.spawn(function()
	while true do
		local ok, err = pcall(function()
			if os.clock() - lastTruckScan > 3 then
				lastTruckScan = os.clock()
				if not findTruck() and not warnedNoTruck then
					warnedNoTruck = true
					warn("[IslandFarm] ไม่เจอรถ " .. TRUCK_NAME .. " ในแมพ — วางโมเดลชื่อนี้ไว้บนเกาะ (ปุ่มส่งออกจะขึ้นเอง)")
				end
			end
			local farm = farmData()
			if not farm then return end
			publish(farm)
			local owner = ownerPlayer()
			if not owner or not Inventory.Get(owner) then return end
			if farm.ship and os.time() >= farm.ship.endAt then resolve(owner, farm) end
			offerCelebration(owner, farm)
		end)
		if not ok then warn("[IslandFarm] " .. tostring(err)) end
		task.wait(1)
	end
end)

Players.PlayerRemoving:Connect(function(player)
	Watching[player], LastAction[player], Ready[player], Offered[player], FxAt[player] = nil, nil, nil, nil, nil
end)

--------------------------------------------------------------------------------
-- คำสั่งแอดมิน /farm (เทสในเกม) — AdminCommands เรียกผ่าน IslandAccess.FarmAdmin
--------------------------------------------------------------------------------


IslandAccess.FarmAdmin = function(admin, args)
	local farm = farmData()
	if not farm then return "ข้อมูลเกาะยังไม่โหลด (ต้องเป็นเกาะของคุณ และเจ้าของต้องอยู่)" end
	local sub = args[1]
	local n = tonumber(args[2])
	if sub == "exp" and n then
		farm.exp = math.max(0, farm.exp + math.floor(n))
		if not FarmLevelConfig.BankExpAtMax then
			farm.exp = math.min(farm.exp, FarmLevelConfig.ExpForLevel(FarmLevelConfig.Ceiling()))
		end
	elseif sub == "level" and n then
		local target = math.clamp(math.floor(n), 1, FarmLevelConfig.Ceiling()) -- เพดานที่เปิดอยู่ (ตอนนี้ 20)
		farm.exp = FarmLevelConfig.ExpForLevel(target)
		-- ลดเลเวล (เทส) = ถือว่าฉลองถึงตรงนั้นแล้ว ไม่งั้นขึ้นใหม่ครั้งหน้าจะไม่มีแบนเนอร์
		if target < farm.celebrated then farm.celebrated = target end
	elseif sub == "ship" then
		if not farm.ship then return "รถไม่ได้กำลังส่งของ" end
		farm.ship.endAt = os.time()
	elseif sub == "orders" then
		for slot = 1, ExportConfig.OrderSlots do
			if not (farm.ship and farm.ship.slot == slot) then farm.orders[slot] = nil end
		end
		ensureOrders(farm)
	elseif sub == "reroll" then
		farm.rerollDay = nil
	elseif sub == "gems" then
		farm.gemDay, farm.gemMonth = nil, nil
		ExportOrders.ResetCounters(farm, os.time())
	elseif sub == "reset" then
		for key in pairs(farm) do farm[key] = nil end
		farmData()
		Offered[admin] = nil
	elseif sub == "pets" then
		-- สัตว์เลี้ยงเป็นของ IslandPets (เฟส 2d) · ไม่แตะข้อมูลฟาร์ม จึงตอบกลับเลยไม่ต้องส่งภาพรถใหม่
		return IslandAccess.PetAdmin and IslandAccess.PetAdmin(args[2]) or "ระบบสัตว์เลี้ยงยังไม่พร้อม"
	elseif sub ~= nil and sub ~= "" then
		return "ใช้: /farm [exp <n> | level <n> | ship | orders | reroll | gems | reset | pets ready|<n>]"
	end
	Offered[admin] = nil
	publish(farm)
	push(admin, farm, false)
	local level, into, need = FarmLevelConfig.LevelFromExp(farm.exp)
	return ("ฟาร์ม Lv%d (%d/%d · รวม %d EXP) · ฉลองแล้วถึง Lv%d · รถ%s · เพชรวันนี้ %d/%d"):format(
		level, into, need, farm.exp, farm.celebrated,
		farm.ship and (" กลับใน %d วิ"):format(math.max(0, farm.ship.endAt - os.time())) or "ว่าง",
		farm.gemDayCount or 0, ExportConfig.Gems.perDay)
end
