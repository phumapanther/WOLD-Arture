-- Trading.server.lua: the merchant's two-sided trade.
--
-- One invitation, then a window both people share. Each side puts items and gold up, each side agrees, and
-- only when BOTH have agreed does anything move.
--
-- The offer is server state, and both clients are sent the same picture of it after every change. Neither
-- can be looking at something the other is not, which is the whole problem a trade window has to solve.
--
-- Three rules do most of the work:
--   * an offer names BAG SLOTS, and what is in them is read at the moment of the swap, not when they were
--     put up -- so nothing can be offered, then dropped or used, and still arrive
--   * agreeing is cancelled by any change to either side's offer, so nobody can agree to one thing and
--     receive another
--   * the swap checks both bags have room before it moves anything, so a full bag cannot destroy an item
local Players = game:GetService("Players")
local ServerConfig = require(game.ServerScriptService.ServerConfig)
local Classes = require(game.ServerScriptService.Classes)
local Inventory = require(game.ServerScriptService.Inventory)
local Vitals = require(game.ServerScriptService.Vitals)
local ClassActionConfig = require(game.ReplicatedStorage.ClassActionConfig)
local InventoryConfig = require(game.ReplicatedStorage.InventoryConfig)
local ItemCatalog = require(game.ReplicatedStorage.ItemCatalog)
local Remotes = require(game.ReplicatedStorage.Remotes)

if ServerConfig.IsLobby then return end

local Trades = {} -- [player] = session, both partners pointing at the SAME table
local Invites = {} -- [invitee] = { from, deadline }

--------------------------------------------------------------------------------

local function rootOf(player)
	local character = player and player.Character
	return character and character:FindFirstChild("HumanoidRootPart")
end

local function withinRange(a, b)
	local ra, rb = rootOf(a), rootOf(b)
	if not ra or not rb then return false end
	return (ra.Position - rb.Position).Magnitude <= ClassActionConfig.Trade.range
end

local function otherOf(session, player)
	return session.a == player and session.b or session.a
end

-- What one side is putting up, as the other side needs to see it: the items resolved to names and counts,
-- and the gold. Sent to both, so both are looking at the same thing.
local function describeOffer(session, player)
	local offer = session.offers[player]
	local state = Inventory.Get(player)
	local items = {}
	for _, index in ipairs(offer.slots) do
		local slot = state and state.slots[index]
		if slot then
			local item = ItemCatalog.Get(slot.id)
			table.insert(items, {
				slot = index,
				id = slot.id,
				name = item and item.name or slot.id,
				icon = item and item.icon or "",
				count = slot.count or 1,
			})
		end
	end
	return { items = items, gold = offer.gold, confirmed = offer.confirmed }
end

-- Both sides get the whole picture: their own offer, the partner's, and who has agreed.
local function publish(session)
	for _, player in ipairs({ session.a, session.b }) do
		local partner = otherOf(session, player)
		Remotes.TradeStateChanged:FireClient(player, "update", partner, {
			mine = describeOffer(session, player),
			theirs = describeOffer(session, partner),
		})
	end
end

local function closeSession(session, reason)
	if session.closed then return end
	session.closed = true
	Trades[session.a] = nil
	Trades[session.b] = nil
	for _, player in ipairs({ session.a, session.b }) do
		if player.Parent then
			Remotes.TradeStateChanged:FireClient(player, "closed", otherOf(session, player), reason)
		end
	end
end

-- Any change to either offer withdraws both agreements. Without this, one side could agree, wait for the
-- other to agree, then swap what they were offering in the moment before the swap.
local function unconfirm(session)
	session.offers[session.a].confirmed = false
	session.offers[session.b].confirmed = false
end

--------------------------------------------------------------------------------
-- The swap
--------------------------------------------------------------------------------

-- How many free bag slots a player has, so a swap cannot destroy an item by dropping it into a full bag.
local function freeSlots(player)
	local state = Inventory.Get(player)
	if not state then return 0 end
	local used = 0
	for _ in pairs(state.slots) do used += 1 end
	return InventoryConfig.SlotCount - used
end

local function completeTrade(session)
	local a, b = session.a, session.b
	local offerA, offerB = session.offers[a], session.offers[b]

	-- Everything is re-read HERE, not trusted from when it was offered. In between, either of them could
	-- have used, dropped, sold or broken the very thing they put up.
	local function collect(player, offer)
		local state = Inventory.Get(player)
		if not state then return nil end
		if state.gold < offer.gold then return nil end
		local taking = {}
		local seen = {}
		for _, index in ipairs(offer.slots) do
			if seen[index] then return nil end -- the same slot listed twice would duplicate an item
			seen[index] = true
			local slot = state.slots[index]
			if not slot then return nil end -- it is gone; the trade is off rather than partly done
			table.insert(taking, { index = index, id = slot.id, count = slot.count or 1,
				durability = slot.durability })
		end
		return taking
	end

	local takingA = collect(a, offerA)
	local takingB = collect(b, offerB)
	if not takingA or not takingB then
		return closeSession(session, "ของหรือเงินเปลี่ยนไป การเทรดถูกยกเลิก")
	end

	-- Room to receive, counted before anything moves. Each side frees the slots it gives up, so swapping
	-- one item for one item works even with a full bag.
	if freeSlots(a) + #takingA < #takingB or freeSlots(b) + #takingB < #takingA then
		return closeSession(session, "กระเป๋าไม่พอ")
	end

	-- Take everything from both sides first, then hand it over. Removing before adding means a bag is never
	-- momentarily over capacity, and nothing exists twice.
	for _, entry in ipairs(takingA) do Inventory.RemoveFromSlot(a, entry.index, entry.count) end
	for _, entry in ipairs(takingB) do Inventory.RemoveFromSlot(b, entry.index, entry.count) end
	Inventory.AddGold(a, -offerA.gold)
	Inventory.AddGold(b, -offerB.gold)

	for _, entry in ipairs(takingA) do Inventory.AddItem(b, entry.id, entry.count, entry.durability) end
	for _, entry in ipairs(takingB) do Inventory.AddItem(a, entry.id, entry.count, entry.durability) end
	Inventory.AddGold(a, offerB.gold)
	Inventory.AddGold(b, offerA.gold)

	for _, player in ipairs({ a, b }) do
		if player.Parent then
			Remotes.TradeStateChanged:FireClient(player, "completed", otherOf(session, player))
		end
	end
	session.closed = true
	Trades[a] = nil
	Trades[b] = nil
end

--------------------------------------------------------------------------------
-- Starting one
--------------------------------------------------------------------------------

local function mayTrade(actor, target)
	if not actor or not target or actor == target then return false end
	if not actor.Parent or not target.Parent then return false end
	if Vitals.IsDowned(actor) or Vitals.IsDowned(target) then return false end
	if Trades[actor] or Trades[target] then return false end
	if not withinRange(actor, target) then return false end
	return ClassActionConfig.Grants(Classes.Get(actor, "basic"), "trade")
		or ClassActionConfig.Grants(Classes.Get(actor, "advanced"), "trade")
end

-- Published for ClassActions, which owns the prompt that starts this.
local function invite(actor, target)
	if not mayTrade(actor, target) then return false, "เทรดไม่ได้ตอนนี้" end
	if Invites[target] then return false, "เขากำลังถูกชวนอยู่" end

	local seconds = ClassActionConfig.Trade.askSeconds
	Invites[target] = { from = actor, deadline = os.clock() + seconds }
	Remotes.ClassActionPrompt:FireClient(target, "trade", actor, seconds)

	task.delay(seconds, function()
		local entry = Invites[target]
		if entry and entry.from == actor then
			Invites[target] = nil
			Remotes.TradeStateChanged:FireClient(actor, "closed", target, "ไม่มีคำตอบ")
		end
	end)
	return true
end

local function answerInvite(target, accepted)
	local entry = Invites[target]
	if not entry then return end
	Invites[target] = nil
	local actor = entry.from

	if not accepted then
		if actor.Parent then
			Remotes.TradeStateChanged:FireClient(actor, "closed", target, "ถูกปฏิเสธ")
		end
		return
	end
	-- Re-checked at the answer, not the invitation: twenty seconds is long enough to walk away or go down.
	if not mayTrade(actor, target) then
		if actor.Parent then
			Remotes.TradeStateChanged:FireClient(actor, "closed", target, "เทรดไม่ได้แล้ว")
		end
		return
	end

	local session = {
		a = actor,
		b = target,
		closed = false,
		offers = {
			[actor] = { slots = {}, gold = 0, confirmed = false },
			[target] = { slots = {}, gold = 0, confirmed = false },
		},
	}
	Trades[actor] = session
	Trades[target] = session
	for _, player in ipairs({ actor, target }) do
		Remotes.TradeStateChanged:FireClient(player, "opened", otherOf(session, player))
	end
	publish(session)
end

--------------------------------------------------------------------------------
-- Requests
--------------------------------------------------------------------------------

-- Replacing the whole offer rather than adding one item at a time: the client sends what it wants to be
-- offering, and the server decides whether that is possible. One shape of request, one place to validate.
Remotes.RequestTradeOffer.OnServerEvent:Connect(function(player, slots, gold)
	local session = Trades[player]
	if not session or session.closed then return end
	if type(slots) ~= "table" then return end

	local state = Inventory.Get(player)
	if not state then return end

	local clean, seen = {}, {}
	for _, index in ipairs(slots) do
		if type(index) == "number" and state.slots[index] and not seen[index] then
			seen[index] = true
			table.insert(clean, index)
			if #clean >= ClassActionConfig.Trade.offerSlots then break end
		end
	end

	gold = math.floor(tonumber(gold) or 0)
	gold = math.clamp(gold, 0, state.gold)

	local offer = session.offers[player]
	offer.slots = clean
	offer.gold = gold
	-- Changing what is on the table withdraws both agreements.
	unconfirm(session)
	publish(session)
end)

Remotes.RequestTradeConfirm.OnServerEvent:Connect(function(player)
	local session = Trades[player]
	if not session or session.closed then return end
	-- Still standing next to each other: walking away mid-trade should not complete it.
	if not withinRange(session.a, session.b) then
		return closeSession(session, "อยู่ไกลเกินไป")
	end

	session.offers[player].confirmed = true
	publish(session)

	if session.offers[session.a].confirmed and session.offers[session.b].confirmed then
		completeTrade(session)
	end
end)

Remotes.RequestTradeCancel.OnServerEvent:Connect(function(player)
	local session = Trades[player]
	if session then
		return closeSession(session, "ถูกยกเลิก")
	end
	-- Or refusing the invitation before it ever opened.
	answerInvite(player, false)
end)

-- The invitee accepting. Routed through ClassActions' response remote so every yes/no in the game arrives
-- the same way.
Remotes.RespondClassAction.OnServerEvent:Connect(function(player, actionId, accepted)
	if actionId ~= "trade" then return end
	answerInvite(player, accepted == true)
end)

--------------------------------------------------------------------------------

Players.PlayerRemoving:Connect(function(player)
	local session = Trades[player]
	if session then closeSession(session, "อีกฝ่ายออกจากเกม") end
	Invites[player] = nil
	for invitee, entry in pairs(Invites) do
		if entry.from == player then Invites[invitee] = nil end
	end
end)

-- Published so ClassActions can start one from its prompt without owning any of this.
local TradeAccess = require(game.ServerScriptService.TradeAccess)
TradeAccess.Invite = invite
