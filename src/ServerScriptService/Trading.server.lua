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
				name = ItemCatalog.DisplayName(slot.id, slot.meta),
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

-- ห้องรับของนับแยกฝั่งกระเป๋า (หลัก/VIP) — เดิมนับช่องที่ใช้ทั้งหมดรวม VIP แล้วเทียบกับกระเป๋าหลัก
-- กระเป๋า VIP เต็มจึงเทรดอะไรไม่ได้เลย (QA 2026-09-26) · กติกาอยู่ที่ BagRanges ที่เดียวกับ Inventory
local BagRanges = require(game.ServerScriptService.BagRanges)

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
			-- **ต้องเป็นของชิ้นเดิมที่อีกฝ่ายเห็นตอนกดตกลง** (QA 2026-09-26): ข้อเสนอเก็บเลขช่อง ของเดิมจึงสลับ
			-- ของในช่องได้หลังอีกฝ่ายตกลงแล้ว (จัดกระเป๋า/ทิ้ง/ขาย ให้ช่องนั้นเหลือหินก้อนเดียว) แล้วได้ของไปฟรี
			local seenThen = offer.snap and offer.snap[index]
			if not seenThen or seenThen.id ~= slot.id or seenThen.count ~= (slot.count or 1)
				or seenThen.meta ~= slot.meta then
				return nil
			end
			if ItemCatalog.IsBound(slot.id) then return nil end -- ของประจำตำแหน่งเทรดไม่ได้
			table.insert(taking, { index = index, id = slot.id, count = slot.count or 1,
				durability = slot.durability, meta = slot.meta })
		end
		return taking
	end

	local takingA = collect(a, offerA)
	local takingB = collect(b, offerB)
	if not takingA or not takingB then
		return closeSession(session, "ของหรือเงินเปลี่ยนไป การเทรดถูกยกเลิก")
	end

	-- กุญแจของรถที่ "เรียกออกมาอยู่" ยกให้กันไม่ได้ ต้องเก็บรถเข้าโรงก่อน ตามที่ผู้ใช้สั่ง
	--
	-- ถ้าปล่อยให้แลกได้ รถจะยังวิ่งอยู่ในโลกโดยที่เจ้าของใหม่ไม่มีทางเก็บมัน และเจ้าของเก่าก็ไม่มีสิทธิ์
	-- แล้ว — คันนั้นจะค้างอยู่กลางแมพจนเซิร์ฟเวอร์ปิด
	--
	-- เช็คก่อนย้ายของทุกชิ้น เหมือนการเช็คช่องกระเป๋า: การเทรดต้องล้มทั้งยกหรือสำเร็จทั้งยก
	local blocked = nil
	pcall(function()
		local VehicleService = require(game.ServerScriptService.Vehicle.Service)
		for _, entry in ipairs({ table.unpack(takingA), table.unpack(takingB) }) do
			local plate = type(entry.meta) == "table" and entry.meta.plate
			if plate and VehicleService.Active and VehicleService.Active[plate] then
				blocked = plate
				break
			end
		end
	end)
	if blocked then
		return closeSession(session, ("เก็บรถ %s เข้าโรงรถก่อนถึงจะยกกุญแจให้กันได้"):format(blocked))
	end

	-- Room to receive, counted before anything moves. Each side frees the slots it gives up, so swapping
	-- one item for one item works even with a full bag.
	local stateA, stateB = Inventory.Get(a), Inventory.Get(b)
	if not (stateA and stateB and BagRanges.SwapFits(stateA.slots, takingA, takingB)
		and BagRanges.SwapFits(stateB.slots, takingB, takingA)) then
		return closeSession(session, "กระเป๋าไม่พอ")
	end

	-- Take everything from both sides first, then hand it over. Removing before adding means a bag is never
	-- momentarily over capacity, and nothing exists twice.
	for _, entry in ipairs(takingA) do Inventory.RemoveFromSlot(a, entry.index, entry.count) end
	for _, entry in ipairs(takingB) do Inventory.RemoveFromSlot(b, entry.index, entry.count) end
	Inventory.AddGold(a, -offerA.gold)
	Inventory.AddGold(b, -offerB.gold)

	for _, entry in ipairs(takingA) do Inventory.AddItem(b, entry.id, entry.count, entry.durability, entry.meta) end
	for _, entry in ipairs(takingB) do Inventory.AddItem(a, entry.id, entry.count, entry.durability, entry.meta) end
	Inventory.AddGold(a, offerB.gold)
	Inventory.AddGold(b, offerA.gold)

	-- กุญแจรถที่ยกให้คนอื่นไปแล้ว รถต้องหายจากโรงรถของคนให้ทันที
	--
	-- เดิม `forgetKeyless` ถูกเรียกตอน "เปิดรายการโรงรถ" เท่านั้น คนให้จึงยังเห็นรถค้างอยู่จนกว่าจะเปิดเมนู
	-- ใหม่ และคนรับก็ไม่เคยถูกกวาดเลย เรียกทั้งสองฝั่งตรงนี้เพราะการแลกคือจังหวะที่กุญแจเปลี่ยนมือจริง
	--
	-- pcall เพราะระบบพาหนะอาจไม่ได้ติดตั้งในเซิร์ฟเวอร์นี้ การเทรดต้องไม่พังตามไปด้วย
	pcall(function()
		local VehicleService = require(game.ServerScriptService.Vehicle.Service)
		-- **กรรมสิทธิ์รถเดินตามกุญแจ** เหมือนทาง "ให้ของ" (QA 2026-09-26) — เดิมไม่โอน `forgetKeyless` ข้างล่างเลย
		-- ลบแถวโรงรถของคนให้ทิ้ง คนรับได้ "รถผี" ที่ไม่มีข้อมูล (ถ่าน/ความคงทนเต็มทุกครั้งที่เรียก ของท้ายรถหาย)
		-- ต้องโอน **ก่อน** forgetKeyless
		if VehicleService.handOver then
			for _, pair in ipairs({ { takingA, a, b }, { takingB, b, a } }) do
				for _, entry in ipairs(pair[1]) do
					local plate = type(entry.meta) == "table" and entry.meta.plate
					if plate then VehicleService.handOver(pair[2], pair[3], plate) end
				end
			end
		end
		if VehicleService.forgetKeyless then
			VehicleService.forgetKeyless(a)
			VehicleService.forgetKeyless(b)
		end
	end)

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

	local clean, seen, snap = {}, {}, {}
	for _, index in ipairs(slots) do
		local slot = type(index) == "number" and state.slots[index]
		if slot and not seen[index] then
			seen[index] = true
			table.insert(clean, index)
			-- จำของชิ้นนั้นไว้ ตอนสรุปต้องยังเป็นชิ้นเดิม (ดู collect)
			snap[index] = { id = slot.id, count = slot.count or 1, meta = slot.meta }
			if #clean >= ClassActionConfig.Trade.offerSlots then break end
		end
	end

	gold = tonumber(gold) or 0
	if gold ~= gold or gold == math.huge then gold = 0 end -- NaN/inf
	gold = math.clamp(math.floor(gold), 0, state.gold)

	local offer = session.offers[player]
	offer.slots = clean
	offer.snap = snap
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
