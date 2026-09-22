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
local ServerConfig = require(game.ServerScriptService.ServerConfig)

if ServerConfig.IsLobby then return end

local ShopConfig = require(game.ReplicatedStorage.ShopConfig)
local ItemCatalog = require(game.ReplicatedStorage.ItemCatalog)
local Inventory = require(game.ServerScriptService.Inventory)
local Vitals = require(game.ServerScriptService.Vitals)
local MarketAccess = require(game.ServerScriptService.MarketAccess)
local EventState = require(game.ServerScriptService.EventState)
local Remotes = require(game.ReplicatedStorage.Remotes)

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

-- [itemId] = multiplier. Rerolled on a timer for the whole server at once.
local Multipliers = {}
local NextRerollAt = 0

local function reroll()
	for id, item in pairs(ItemCatalog.Items) do
		if ShopConfig.Buys[item.kind] then
			local swing = ShopConfig.PriceSwing
			Multipliers[id] = 1 + (math.random() * 2 - 1) * swing
		end
	end
	NextRerollAt = os.time() + ShopConfig.RerollSeconds
end

reroll()
task.spawn(function()
	while true do
		task.wait(ShopConfig.RerollSeconds)
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
			table.insert(sells, {
				index = index, id = entry.id,
				name = item.name .. (SPOT_TAG[item.spot] or ""),
				icon = item.icon, price = entry.price,
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
					slot = slotIndex, id = slot.id, name = item.name, icon = item.icon,
					count = slot.count or 1, each = price, total = price * (slot.count or 1),
				})
			end
		end
		table.sort(buys, function(a, b) return a.slot < b.slot end)
	end

	return {
		sells = sells,
		buys = buys,
		gold = state and state.gold or 0,
		rerollIn = math.max(0, NextRerollAt - os.time()),
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
Remotes.RequestShopAction.OnServerEvent:Connect(function(player, action, index, amount)
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

		local affordable = math.floor(state.gold / entry.price)
		if affordable < 1 then
			return Remotes.SocialNotify:FireClient(player, "error", "เงินไม่พอ")
		end
		local count = math.min(want, affordable)

		-- Given one at a time BEFORE the gold is taken, so a full bag cannot charge for nothing. Stopping
		-- at the first refusal and paying only for what landed is what makes a part-filled bag buy what
		-- fits instead of failing outright.
		local bought = 0
		for _ = 1, count do
			if not Inventory.AddItem(player, entry.id, 1) then break end
			bought += 1
		end
		if bought == 0 then
			return Remotes.SocialNotify:FireClient(player, "error", "กระเป๋าเต็ม")
		end
		Inventory.AddGold(player, -entry.price * bought)

		local item = ItemCatalog.Get(entry.id)
		local name = item and item.name or entry.id
		if bought < want then
			Remotes.SocialNotify:FireClient(player, "info",
				("ซื้อ %s x%d ราคา %d (ได้ไม่ครบ %d)"):format(name, bought, entry.price * bought, want))
		else
			Remotes.SocialNotify:FireClient(player, "info",
				("ซื้อ %s x%d ราคา %d"):format(name, bought, entry.price * bought))
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
		local sellable = {}
		for slotIndex, slot in pairs(state.slots) do
			local price = buyPrice(slot.id, slot.meta)
			if price then
				table.insert(sellable, { index = slotIndex, count = slot.count or 1, price = price })
			end
		end
		if #sellable == 0 then
			return Remotes.SocialNotify:FireClient(player, "error", "ไม่มีของที่ร้านรับซื้อ")
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
