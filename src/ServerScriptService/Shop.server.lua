-- Shop.server.lua: the shopkeeper who sells tools and bread, and buys whatever you dug up.
--
-- Found by TAG: anything tagged WOLD_Npc with NpcKind="shop" gets a prompt. The user places the NPC model;
-- this file never knows where it is.
--
-- Every price is computed HERE and sent down. The client is shown prices so it can draw them, but it is
-- never believed about one -- a buy request names an index into the sell list, and a sell request names a
-- bag slot. Neither carries a number the server did not decide.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local IslandAccess = require(game.ServerScriptService.Island.IslandAccess)
local ServerConfig = require(game.ServerScriptService.ServerConfig)

if ServerConfig.IsLobby then return end

local ShopConfig = require(game.ReplicatedStorage.ShopConfig)
local ItemCatalog = require(game.ReplicatedStorage.ItemCatalog)
local PremiumAccess = require(game.ServerScriptService.PremiumAccess)
local Inventory = require(game.ServerScriptService.Inventory)
local Vitals = require(game.ServerScriptService.Vitals)
local MarketAccess = require(game.ServerScriptService.MarketAccess)
local EventState = require(game.ServerScriptService.EventState)
local Remotes = require(game.ReplicatedStorage.Remotes)
local FarmLevelConfig = require(game.ReplicatedStorage.FarmLevelConfig)
local Vault = require(game.ServerScriptService.Vault)

local TAG = "WOLD_Npc"
local RANGE = 12

-- The most a single press can buy. Not a game rule so much as a guard: it bounds the loop below, so a
-- request for a billion is a slow no rather than a frozen server.
local MAX_BUY = 999
-- บนเกาะฟาร์มขายของวาง ไม่ใช่เครื่องมือ — ตารางเดียวที่ต่างกัน ที่เหลือ (ระยะ ราคารับซื้อ) เหมือนร้านเมืองหลัก
local SELLS = ServerConfig.Mode == "Farming" and ShopConfig.IslandSells or ShopConfig.Sells

--------------------------------------------------------------------------------
-- Drifting prices
--------------------------------------------------------------------------------

-- [itemId] = multiplier. ราคาเดินตาม **นาฬิกาจริง** ไม่ใช่สุ่มใหม่ตอนเซิร์ฟเวอร์บูต (แก้ 2026-09-23)
--
-- ของเดิมสุ่มครั้งเดียวตอนโมดูลโหลด แล้วเก็บไว้ในหน่วยความจำล้วน — **เกาะฟาร์มเป็นเซิร์ฟส่วนตัวที่ปิดตัว
-- ทุกครั้งที่เจ้าของออก** ออกไปล็อบบี้แล้วเข้าใหม่จึงเท่ากับกดสุ่มราคาใหม่ฟรี กดจนได้ 1.5 เมื่อไหร่ก็ได้
-- ซึ่งทำให้ช่วงสวิง ±50% ไม่มีความหมายอะไรเลย (รูปแบบเดียวกับจุดสุ่มบนผืนดินที่แก้ไปวันก่อน)
--
-- ตอนนี้ตัวคูณมาจาก "ช่องเวลาที่เท่าไหร่แล้ว" ล้วนๆ ทุกเซิร์ฟทั้งเกมจึงเห็นราคาเดียวกันจริง
-- ไม่ใช่แค่คนในเซิร์ฟเดียวกัน — ซึ่งเป็นสิ่งที่หน้า "ราคากลาง" บนหินสื่อสารอ้างอยู่กลายๆ มาตลอด
local Multipliers = {}
local NextRerollAt = 0

-- ไอดีทุกตัวที่ร้านรับซื้อ เรียง — **`pairs` ไม่รับประกันลำดับ** ถ้าวนด้วย `pairs` สองเซิร์ฟ
-- จะหยิบเลขคนละตัวจากตัวสุ่มชุดเดียวกัน = ราคาต่างกันอยู่ดี และการแก้ทั้งหมดนี้จะไม่มีผล
local function sellableIds()
	local ids = {}
	for id, item in pairs(ItemCatalog.Items) do
		if ShopConfig.Buys[item.kind] then ids[#ids + 1] = id end
	end
	table.sort(ids)
	return ids
end

local function reroll()
	local period = ShopConfig.RerollSeconds
	local bucket = math.floor(os.time() / period)
	-- คูณเลขคีย์ก่อนส่งเข้า `Random.new` เพื่อให้ช่วงที่ติดกันไม่เกาะกลุ่มกัน
	local rng = Random.new(bucket * 1013904223 + 1664525)
	for _, id in ipairs(sellableIds()) do
		Multipliers[id] = 1 + (rng:NextNumber() * 2 - 1) * ShopConfig.PriceSwing
	end
	NextRerollAt = (bucket + 1) * period
end

reroll()
task.spawn(function()
	while true do
		-- นอนถึงเส้นแบ่งของช่วงถัดไป ไม่ใช่นอนครบ 30 นาทีจากตอนบูต
		-- ไม่งั้นนาฬิกาของเซิร์ฟนี้จะค่อยๆ เยื้องออกจากของเซิร์ฟอื่น
		task.wait(math.max(1, NextRerollAt - os.time()))
		reroll()
	end
end)

-- What the shop pays for one of `id`. Always at least 1, so a cheap material is never literally worthless.
-- What the shop pays for one of `id`. `meta` is the slot's per-item data when it has any, which is how a
-- trophy fish's weight reaches the price.
--
-- Taking meta rather than reading the slot means every caller goes through the same arithmetic: the price
-- shown in the window, the price paid on a single sell, and the price paid by "sell everything" cannot
-- drift apart, which they would the moment one of the three computed its own.
local function buyPrice(id, meta)
	local item = ItemCatalog.Get(id)
	if not item or not ShopConfig.Buys[item.kind] then return nil end
	-- One item may refuse to be sold even though its whole kind is bought. The steam-age materials do: they
	-- are the price of the new recipes, and a counter that turned them into coin would let a player skip the
	-- farming the recipes exist to ask for. Returning nil here is the single gate -- the window, the single
	-- sell, "sell everything" and the price board all price through this function.
	if not ItemCatalog.IsSellable(id) then return nil end
	local base = (item.value or 0) * ShopConfig.BuyFraction * (Multipliers[id] or 1)

	-- A heavy fish is worth more than a small one, because otherwise the weight is decoration: a 45 kg
	-- legendary and a 1 kg minnow fetched the same coins, and the only reason to keep the big one was to
	-- look at it.
	--
	-- Paid per kilo on top of the base rather than as a multiplier of it, so the size is what is being
	-- bought. A fish with no recorded weight -- every common one, which does not carry meta so that it can
	-- still stack -- is priced exactly as it was before.
	if meta and type(meta.kg) == "number" then
		-- Multiplied by the same drift as the base, so a trophy fish rises and falls with the market like
		-- everything else. Left out of the drift it would have been a fixed floor under the price, and a big
		-- fish would have been oddly steady on a day when every other catch had moved.
		base += meta.kg * ShopConfig.GoldPerKg * (Multipliers[id] or 1)
	end

	-- ของขอบทอง (เฟส 2b): ขายบนเกาะเท่านั้น 3 เท่าของราคาตลาดตอนนี้ · ร้านเกมหลักไม่รับ
	if ItemCatalog.IsGoldBorder(meta) then
		return ShopConfig.GoldSellPrice(base, ServerConfig.IsFarm)
	end

	return math.max(1, math.floor(base + 0.5))
end

--------------------------------------------------------------------------------
-- The price board the speaking stone reads
--------------------------------------------------------------------------------

-- What the shop pays for one of everything it buys, for the "ราคากลาง" screen on the stone.
--
-- Priced through buyPrice with no meta, exactly as an ordinary stack of that item would be: the trophy
-- surcharge depends on the fish in your bag, so a board that included it would be quoting a price nobody
-- could get for the item as listed.
--
-- Sorted by price, dearest first, and not alphabetically: the question a player opens this screen to answer
-- is "what is worth carrying home", and the answer is the top of the list. Ties are broken by name only so
-- the order is stable between rerolls rather than shuffling every half hour.
MarketAccess.Quote = function()
	local prices = {}
	for id, item in pairs(ItemCatalog.Items) do
		local price = buyPrice(id, nil)
		if price then
			table.insert(prices, { id = id, name = item.name, icon = item.icon, price = price })
		end
	end
	table.sort(prices, function(a, b)
		if a.price ~= b.price then return a.price > b.price end
		return a.name < b.name
	end)
	return { prices = prices, rerollIn = math.max(0, NextRerollAt - os.time()) }
end

--------------------------------------------------------------------------------
-- Who is close enough
--------------------------------------------------------------------------------

local function nearShop(player)
	-- แขกบนเกาะของคนอื่นคุยกับ NPC ของเจ้าบ้านไม่ได้ (ผู้ใช้สั่ง 2026-09-23)
	-- ตอบที่นี่ที่เดียวเพราะทั้งปุ่ม E และ remote ทุกตัวถามผ่านฟังก์ชันนี้ — ปิดประตูบานเดียวพอ
	if not IslandAccess.MayUseFixtures(player) then return false end
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not root then return false end
	for _, npc in ipairs(CollectionService:GetTagged(TAG)) do
		if npc:GetAttribute("NpcKind") == "shop" then
			local position = npc:IsA("BasePart") and npc.Position or npc:GetPivot().Position
			if (position - root.Position).Magnitude <= RANGE then return true end
		end
	end
	return false
end

--------------------------------------------------------------------------------
-- เลเวลฟาร์ม (เฟส 2c) — ร้านเกาะขายเฉพาะของที่ปลดแล้ว · บ้านมีเพดานจำนวน
--------------------------------------------------------------------------------

local ISLAND = SELLS == ShopConfig.IslandSells

-- บ้านที่เจ้าของเกาะมีทั้งหมด: วางอยู่บนเกาะ + ในกระเป๋า + ในคลัง (ไม่งั้นซื้อแล้วฝากคลังวนเกินเพดานได้)
local function housesOwned(player)
	local n = 0
	local data = IslandAccess.Data and IslandAccess.Data()
	for _, entry in ipairs(data and data.placed or {}) do
		if FarmLevelConfig.IsHouse(entry.id) then n += 1 end
	end
	for _, holder in ipairs({ Inventory.Get(player), Vault.Get(player) }) do
		for _, slot in pairs(holder and holder.slots or {}) do
			if slot and FarmLevelConfig.IsHouse(slot.id) then n += slot.count or 1 end
		end
	end
	return n
end

-- เลเวลแรกที่เพดานบ้านมากกว่าตอนนี้ (บอกผู้เล่นว่าต้องไปถึงไหน)
local function nextHouseLevel(level)
	local cap = FarmLevelConfig.HouseCap(level)
	for l = level + 1, level + 30 do
		if FarmLevelConfig.HouseCap(l) > cap then return l end
	end
	return nil
end

-- แถวนี้ซื้อได้ไหมที่เลเวลนี้ · คืน (ข้อความที่จะบอก, จำนวนที่ยังซื้อได้ | nil = ไม่จำกัด)
-- ร้านเกมหลักไม่มีเลเวล คืน nil เสมอ
local function farmGate(player, entry)
	if not ISLAND then return nil, nil end
	local level = IslandAccess.FarmLevel()
	local need = FarmLevelConfig.ShopRowLevel(entry)
	if need > level then
		return ("🔒 ปลดที่เลเวลฟาร์ม %d (ตอนนี้ Lv%d) — ส่งของกับรถส่งออกเพื่อเก็บ EXP"):format(need, level), 0
	end
	if FarmLevelConfig.IsHouse(entry.id) then
		local cap = FarmLevelConfig.HouseCap(level)
		local owned = housesOwned(player)
		if owned >= cap then
			local at = nextHouseLevel(level)
			return ("🏠 บ้านเต็มแล้ว (%d/%d หลัง)%s"):format(owned, cap,
				at and (" — เลเวลฟาร์ม %d มีได้ %d หลัง"):format(at, FarmLevelConfig.HouseCap(at)) or ""), 0
		end
		return nil, cap - owned
	end
	return nil, nil
end

--------------------------------------------------------------------------------
-- Opening the counter
--------------------------------------------------------------------------------

-- Everything the client needs to draw the shop: what is for sale at what price, and what each thing in the
-- player's own bag would fetch. Sent whole rather than asked for piecemeal, so the window cannot show a
-- half-updated mixture of old and new prices.
local function snapshot(player)
	-- ป้ายบอกว่าของชิ้นนี้เหมาะตั้งในบ้านหรือนอกบ้าน (ItemCatalog.spot)
	--
	-- **เป็นคำแนะนำ ไม่ใช่กฎ** ระบบวางของไม่รู้ว่าตรงไหนคือ "ในบ้าน" (บ้านเป็นโมเดลที่ผู้เล่นวางเอง
	-- ไม่มีห้องที่เกมรู้จัก) และการห้ามวางเก้าอี้กลางแจ้งก็ไม่ใช่กฎที่ผู้เล่นจะขอบคุณ —
	-- สิ่งที่ช่วยได้จริงคือบอกว่าของชิ้นนี้ตั้งใจทำมาเพื่ออะไร แล้วปล่อยให้เขาตัดสินใจเอง
	local SPOT_TAG = { ["in"] = " (ในบ้าน)", out = " (นอกบ้าน)", both = "" }

	local sells = {}
	for index, entry in ipairs(SELLS) do
		local item = ItemCatalog.Get(entry.id)
		if item then
			-- เฟส 2a: ราคาสองสกุลจากกฎเดียว (ShopConfig.PricesOf) · ร้านเกมหลักได้แต่เหรียญ (gems = nil)
			local coins, gems = ShopConfig.PricesOf(entry)
			-- เฟส 2c: แถวที่ยังไม่ปลด/บ้านเต็ม โชว์ 🔒 พร้อมเหตุผล ปุ่มซื้อปิด (เซิร์ฟตรวจซ้ำตอนซื้ออยู่ดี)
			local lockText = farmGate(player, entry)
			table.insert(sells, {
				index = index, id = entry.id,
				name = item.name .. (SPOT_TAG[item.spot] or ""),
				icon = item.icon, coins = coins, gems = gems,
				lock = lockText,
				category = entry.category, -- แท็บในหน้าร้าน (เฉพาะร้านเกาะ)
				-- **จำนวนที่ได้ต่อหนึ่งครั้งที่กด** (ผู้ใช้สั่ง 2026-09-24: เมล็ด 250 ได้ 3 เม็ด)
				-- nil/1 = ทีละชิ้นเหมือนเดิม จึงไม่ต้องแตะแถวอื่นในคอนฟิกเลย
				count = (entry.count or 1) > 1 and entry.count or nil,
			})
		end
	end

	local buys = {}
	local state = Inventory.Get(player)
	if state then
		for slotIndex, slot in pairs(state.slots) do
			local price = buyPrice(slot.id, slot.meta)
			if price then
				local item = ItemCatalog.Get(slot.id)
				table.insert(buys, {
					-- DisplayName: ของขอบทองอ่านว่า "ไข่ (ขอบทอง)" ไม่ใช่ "ไข่" ซ้ำกับแถวธรรมดา (เฟส 2b)
					slot = slotIndex, id = slot.id, name = ItemCatalog.DisplayName(slot.id, slot.meta), icon = item.icon,
					count = slot.count or 1, each = price, total = price * (slot.count or 1),
				})
			end
		end
		table.sort(buys, function(a, b) return a.slot < b.slot end)
	end

	local island = SELLS == ShopConfig.IslandSells
	return {
		sells = sells,
		buys = buys,
		gold = state and state.gold or 0,
		rerollIn = math.max(0, NextRerollAt - os.time()),
		-- ร้านเกาะเท่านั้น: แท็บ + เพชรที่มี (ร้านเกมหลักไม่มีทั้งสองอย่าง หน้าจอจึงหน้าตาเดิม)
		categories = island and ShopConfig.IslandCategories or nil,
		gems = island and (PremiumAccess.GetGems and PremiumAccess.GetGems(player) or 0) or nil,
		farmLevel = island and IslandAccess.FarmLevel() or nil, -- เฟส 2c: หัวร้านบอกเลเวลฟาร์ม
	}
end

-- Trading is a conversation, and you cannot have one face-down in the dirt. Checked on opening AND on every
-- action, the same way distance is: a player could be knocked down with the counter already up.
local function canTrade(player)
	if Vitals.IsDowned(player) then return false end
	-- And not while the city's engines are down. The blackout is meant to stop the town working, and a
	-- shopkeeper trading by candlelight would leave the event with no teeth at all.
	return EventState.NpcAvailable()
end

Remotes.RequestShopOpen.OnServerEvent:Connect(function(player)
	if not canTrade(player) then return end
	if not nearShop(player) then return end
	Remotes.ShopOpen:FireClient(player, snapshot(player))
end)

--------------------------------------------------------------------------------
-- Buying and selling
--------------------------------------------------------------------------------

-- `amount` is optional. On a sell, nil means the whole stack and a number means that many; on a buy, nil
-- means one. Validated here rather than trusted -- a request to sell 1000 of a stack of 3 sells 3, and a
-- request to buy more than the purse holds buys what it can afford.
Remotes.RequestShopAction.OnServerEvent:Connect(function(player, action, index, amount, currency)
	if type(action) ~= "string" then return end
	if not canTrade(player) then return end
	if action ~= "sellall" and type(index) ~= "number" then return end
	-- Re-checked on every action, not just on opening: a player could walk away with the window still up.
	if not nearShop(player) then
		return Remotes.SocialNotify:FireClient(player, "error", "อยู่ไกลจากร้านเกินไป")
	end

	local state = Inventory.Get(player)
	if not state then return end

	if action == "buy" then
		local entry = SELLS[index]
		if not entry then return end

		-- How many. Clamped here rather than trusted: the client types a number into a box, and a box can
		-- be made to say anything. A fraction floors, a negative or a zero buys one, and the ceiling is
		-- whatever the purse can actually pay for.
		local want = 1
		if type(amount) == "number" and amount == amount then
			want = math.clamp(math.floor(amount), 1, MAX_BUY)
		end

		-- **เลเวลฟาร์ม** (เฟส 2c): ของที่ยังไม่ปลดซื้อไม่ได้ · บ้านซื้อได้ไม่เกินเพดานที่เหลือ
		local lockText, room = farmGate(player, entry)
		if lockText then
			return Remotes.SocialNotify:FireClient(player, "error", lockText)
		end
		if room then want = math.min(want, room) end

		-- **จ่ายด้วยสกุลที่ผู้เล่นกดเลือก** (เฟส 2a · ปุ่ม 💎/💰 ทุกแถว) — ราคามาจากกฎเดียวกับหน้าจอ ไม่เชื่อตัวเลขจากไคลเอนต์
		-- สกุลแปลกๆ = ปฏิเสธเงียบ · ขอเพชรกับแถวร้านเกมหลัก = ไม่มีราคา ปฏิเสธพร้อมบอกเหตุผล
		if currency ~= nil and currency ~= "gems" and currency ~= "coins" then return end
		local unitPrice = ShopConfig.PriceFor(entry, currency)
		if not unitPrice then
			return Remotes.SocialNotify:FireClient(player, "error", "ของชิ้นนี้ซื้อด้วยสกุลนี้ไม่ได้")
		end
		local gems = currency == "gems"
		-- ระบบเพชรยังไม่ตั้ง (PremiumStore โหลดไม่ขึ้น) = ปฏิเสธ (QA 2026-09-26: เดิมตกไปอ่านเหรียญแทนเพชร
		-- แล้วเรียก SpendGems ที่เป็น nil หลังให้ของไปแล้ว = ได้ของฟรี)
		if gems and not (PremiumAccess.GetGems and PremiumAccess.SpendGems) then
			return Remotes.SocialNotify:FireClient(player, "error", "ร้านเพชรยังไม่พร้อม ลองใหม่อีกครั้ง")
		end
		local purse = gems and PremiumAccess.GetGems(player) or state.gold
		local affordable = math.floor(purse / unitPrice)
		if affordable < 1 then
			return Remotes.SocialNotify:FireClient(player, "error", gems and "เพชรไม่พอ" or "เงินไม่พอ")
		end
		local count = math.min(want, affordable)

		-- Given BEFORE the gold is taken, so a full bag cannot charge for nothing. `AddItem` is all-or-nothing
		-- (QA 2026-09-26 — the old one-at-a-time loop was a free-item dupe: a full bag spilled the item into the
		-- vault, reported false, and the purchase was never charged), so ask for the whole order and step down
		-- one bundle at a time until it fits: a part-filled bag still buys what fits, and pays for exactly that.
		-- **หนึ่งครั้งที่กดอาจได้หลายชิ้น** (`entry.count`) — จ่ายตามชุดที่ได้จริงเสมอ
		local per = math.max(1, math.floor(entry.count or 1))
		local bought = 0
		for n = count, 1, -1 do
			if Inventory.AddItem(player, entry.id, n * per) then
				bought = n
				break
			end
		end
		local got = bought * per
		if bought == 0 then
			return Remotes.SocialNotify:FireClient(player, "error", "กระเป๋าและคลังเต็ม")
		end
		if gems then
			-- **หักหลังของเข้ากระเป๋าแล้ว** เหมือนทางเหรียญ — กระเป๋าเต็มกลางคันจะได้จ่ายเท่าที่ได้จริง
			-- หักไม่ผ่าน = ถอดของที่เพิ่งใส่คืน (RemoveById ทั้งหมดหรือไม่เอาเลย) · ปกติไม่เกิด ไม่มี yield คั่นจากตอนเช็ค
			if not PremiumAccess.SpendGems(player, unitPrice * bought) then
				Inventory.RemoveById(player, entry.id, got)
				return Remotes.SocialNotify:FireClient(player, "error", "เพชรไม่พอ")
			end
		else
			Inventory.AddGold(player, -unitPrice * bought)
		end

		local item = ItemCatalog.Get(entry.id)
		local name = item and item.name or entry.id
		local unit = gems and " เพชร" or " เหรียญ"
		if bought < want then
			Remotes.SocialNotify:FireClient(player, "info",
				("ซื้อ %s x%d ราคา %d%s (ได้ไม่ครบ %d)"):format(name, got, unitPrice * bought, unit, want * per))
		else
			Remotes.SocialNotify:FireClient(player, "info",
				("ซื้อ %s x%d ราคา %d%s"):format(name, got, unitPrice * bought, unit))
		end

	elseif action == "sell" then
		local slot = state.slots[index]
		if not slot then return end
		local price = buyPrice(slot.id, slot.meta)
		if not price then
			return Remotes.SocialNotify:FireClient(player, "error", "ร้านไม่รับซื้อของชิ้นนี้")
		end
		local held = slot.count or 1
		-- How many to sell. Clamped to what is actually in the slot, so a request for more than the player
		-- has sells what they have rather than being refused or paying for items that do not exist.
		local count = held
		if type(amount) == "number" then
			count = math.clamp(math.floor(amount), 1, held)
		end
		local item = ItemCatalog.Get(slot.id)
		-- Removed first here, the opposite way round from buying, and for the same reason: whichever side
		-- can fail must go first. A slot always removes cleanly, and paying afterwards cannot fail.
		Inventory.RemoveFromSlot(player, index, count)
		Inventory.AddGold(player, price * count)
		Remotes.SocialNotify:FireClient(player, "info",
			("ขาย %s x%d ได้ %d"):format(item and item.name or slot.id, count, price * count))

	elseif action == "sellall" then
		-- Everything the shop will take, in one press. Collected first and sold afterwards, because
		-- RemoveFromSlot renumbers nothing but the slot it empties -- iterating and removing at the same
		-- time would still be reading the table it is changing.
		local sellable, skippedGold = {}, false
		for slotIndex, slot in pairs(state.slots) do
			local price = buyPrice(slot.id, slot.meta)
			-- ของขอบทองขายทีละชิ้นเท่านั้น (ผู้ใช้กำหนด) ปุ่มขายทั้งหมดข้ามไป
			if price and ItemCatalog.IsGoldBorder(slot.meta) then
				skippedGold, price = true, nil
			end
			if price then
				table.insert(sellable, { index = slotIndex, count = slot.count or 1, price = price })
			end
		end
		if #sellable == 0 then
			return Remotes.SocialNotify:FireClient(player, "error",
				skippedGold and "ของขอบทองขายทีละชิ้น — กดขายที่แถวของมัน" or "ไม่มีของที่ร้านรับซื้อ")
		end

		local earned, items = 0, 0
		for _, entry in ipairs(sellable) do
			Inventory.RemoveFromSlot(player, entry.index, entry.count)
			earned += entry.price * entry.count
			items += entry.count
		end
		Inventory.AddGold(player, earned)
		Remotes.SocialNotify:FireClient(player, "info",
			("ขายทั้งหมด %d ชิ้น ได้ %d"):format(items, earned))
	else
		return
	end

	-- The window redraws from a fresh snapshot rather than patching itself, so gold, bag and prices can
	-- never drift apart on screen.
	Remotes.ShopOpen:FireClient(player, snapshot(player))
end)

--------------------------------------------------------------------------------
-- The prompt on the NPC
--------------------------------------------------------------------------------

local function register(npc)
	if npc:GetAttribute("NpcKind") ~= "shop" then return end
	-- HumanoidRootPart FIRST, because a prompt measures its range and draws its icon from the part it is
	-- parented to. The kit's NPC models set PrimaryPart to a 1x1 pivot handle at the model's feet, so
	-- preferring PrimaryPart put the shop button on the ground by the shopkeeper's shoes.
	local anchor = npc:IsA("BasePart") and npc
		or (npc:IsA("Model") and (npc:FindFirstChild("HumanoidRootPart") or npc:FindFirstChild("UpperTorso")
			or npc.PrimaryPart or npc:FindFirstChildWhichIsA("BasePart", true)))
	if not anchor then return end
	if anchor:FindFirstChild("ShopPrompt") then return end

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "ShopPrompt"
	prompt.ActionText = "ซื้อขาย"
	prompt.ObjectText = npc:GetAttribute("NpcName") or "เฒ่าแก่"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.MaxActivationDistance = RANGE
	prompt.RequiresLineOfSight = false
	prompt.HoldDuration = 0
	prompt.Parent = anchor

	prompt.Triggered:Connect(function(player)
		-- Gated here as well as on the remote, for the reason the forge's prompt gives: E is how the counter
		-- is actually opened, and a window that opens and then refuses everything reads as a bug.
		local ok, reason = canTrade(player)
		if not ok then
			if reason then Remotes.SocialNotify:FireClient(player, "error", reason) end
			return
		end
		Remotes.ShopOpen:FireClient(player, snapshot(player))
	end)
end

for _, npc in ipairs(CollectionService:GetTagged(TAG)) do
	task.spawn(register, npc)
end
CollectionService:GetInstanceAddedSignal(TAG):Connect(function(npc)
	task.spawn(register, npc)
end)
