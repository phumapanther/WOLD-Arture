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
local Remotes = require(game.ReplicatedStorage.Remotes)

local TAG = "WOLD_Npc"
local RANGE = 12

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
local function buyPrice(id)
	local item = ItemCatalog.Get(id)
	if not item or not ShopConfig.Buys[item.kind] then return nil end
	local base = (item.value or 0) * ShopConfig.BuyFraction * (Multipliers[id] or 1)
	return math.max(1, math.floor(base + 0.5))
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
	local sells = {}
	for index, entry in ipairs(ShopConfig.Sells) do
		local item = ItemCatalog.Get(entry.id)
		if item then
			table.insert(sells, {
				index = index, id = entry.id, name = item.name,
				icon = item.icon, price = entry.price,
			})
		end
	end

	local buys = {}
	local state = Inventory.Get(player)
	if state then
		for slotIndex, slot in pairs(state.slots) do
			local price = buyPrice(slot.id)
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

Remotes.RequestShopOpen.OnServerEvent:Connect(function(player)
	if not nearShop(player) then return end
	Remotes.ShopOpen:FireClient(player, snapshot(player))
end)

--------------------------------------------------------------------------------
-- Buying and selling
--------------------------------------------------------------------------------

Remotes.RequestShopAction.OnServerEvent:Connect(function(player, action, index)
	if type(action) ~= "string" or type(index) ~= "number" then return end
	-- Re-checked on every action, not just on opening: a player could walk away with the window still up.
	if not nearShop(player) then
		return Remotes.SocialNotify:FireClient(player, "error", "อยู่ไกลจากร้านเกินไป")
	end

	local state = Inventory.Get(player)
	if not state then return end

	if action == "buy" then
		local entry = ShopConfig.Sells[index]
		if not entry then return end
		if state.gold < entry.price then
			return Remotes.SocialNotify:FireClient(player, "error", "เงินไม่พอ")
		end
		-- Given BEFORE the gold is taken, so a full bag cannot charge the player for nothing.
		if not Inventory.AddItem(player, entry.id, 1) then
			return Remotes.SocialNotify:FireClient(player, "error", "กระเป๋าเต็ม")
		end
		Inventory.AddGold(player, -entry.price)
		local item = ItemCatalog.Get(entry.id)
		Remotes.SocialNotify:FireClient(player, "info",
			("ซื้อ %s ราคา %d"):format(item and item.name or entry.id, entry.price))

	elseif action == "sell" then
		local slot = state.slots[index]
		if not slot then return end
		local price = buyPrice(slot.id)
		if not price then
			return Remotes.SocialNotify:FireClient(player, "error", "ร้านไม่รับซื้อของชิ้นนี้")
		end
		local count = slot.count or 1
		local item = ItemCatalog.Get(slot.id)
		-- Removed first here, the opposite way round from buying, and for the same reason: whichever side
		-- can fail must go first. A slot always removes cleanly, and paying afterwards cannot fail.
		Inventory.RemoveFromSlot(player, index, count)
		Inventory.AddGold(player, price * count)
		Remotes.SocialNotify:FireClient(player, "info",
			("ขาย %s x%d ได้ %d"):format(item and item.name or slot.id, count, price * count))
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
	local anchor = npc:IsA("BasePart") and npc
		or (npc:IsA("Model") and (npc.PrimaryPart or npc:FindFirstChild("HumanoidRootPart")
			or npc:FindFirstChildWhichIsA("BasePart", true)))
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
		Remotes.ShopOpen:FireClient(player, snapshot(player))
	end)
end

for _, npc in ipairs(CollectionService:GetTagged(TAG)) do
	task.spawn(register, npc)
end
CollectionService:GetInstanceAddedSignal(TAG):Connect(function(npc)
	task.spawn(register, npc)
end)
