-- ClassActions.server.lua: what a class lets you do to the player standing next to you.
--
-- Giving money, begging, robbing, healing, repairing, arresting. Every one is a request from a client that
-- the server re-checks from scratch: the asker's class, the distance, the target's state, and the money.
-- The prompt on screen is a convenience, never the permission -- a crafted request from someone with no
-- class at all must fail exactly as if they had never seen a button.
--
-- Actions that the target should get a say in (being carried, being robbed) go through a two-step: the
-- server asks the target, and only acts on their answer. That handshake lives here rather than on either
-- client, so neither can answer on the other's behalf.
local Players = game:GetService("Players")
local ServerConfig = require(game.ServerScriptService.ServerConfig)
local Classes = require(game.ServerScriptService.Classes)
local Inventory = require(game.ServerScriptService.Inventory)
local Vitals = require(game.ServerScriptService.Vitals)
local Progression = require(game.ServerScriptService.Progression)
local ClassActionConfig = require(game.ReplicatedStorage.ClassActionConfig)
local ItemCatalog = require(game.ReplicatedStorage.ItemCatalog)
local Remotes = require(game.ReplicatedStorage.Remotes)
local RescueAccess = require(game.ServerScriptService.RescueAccess)
local TradeAccess = require(game.ServerScriptService.TradeAccess)
local ArrestAccess = require(game.ServerScriptService.ArrestAccess)

if ServerConfig.IsLobby then return end

--------------------------------------------------------------------------------
-- Shared checks
--------------------------------------------------------------------------------

local function rootOf(player)
	local character = player and player.Character
	return character and character:FindFirstChild("HumanoidRootPart")
end

local function withinRange(a, b)
	local ra, rb = rootOf(a), rootOf(b)
	if not ra or not rb then return false end
	return (ra.Position - rb.Position).Magnitude <= ClassActionConfig.Range
end

-- Every action passes through here first. Whichever tier grants the action is the one that counts, so a
-- Rogue who later becomes a Guard keeps being able to rob.
local function mayAct(actor, target, actionId)
	if not actor or not target or actor == target then return false end
	if not target.Parent or not actor.Parent then return false end
	-- Both must be up. Downed players belong to the rescue prompts, and acting on someone who cannot
	-- respond is exactly what the consent handshake exists to prevent.
	if Vitals.IsDowned(actor) or Vitals.IsDowned(target) then return false end
	if not withinRange(actor, target) then return false end

	local basic = Classes.Get(actor, "basic")
	local advanced = Classes.Get(actor, "advanced")
	return ClassActionConfig.Grants(basic, actionId)
		or ClassActionConfig.Grants(advanced, actionId)
end

-- Tells both parties what happened. One event rather than two so they can never disagree about the outcome.
local function report(actor, target, actionId, ok, message, extra)
	if actor and actor.Parent then
		Remotes.ClassActionResult:FireClient(actor, actionId, ok, message, target, extra)
	end
	if target and target.Parent and target ~= actor then
		Remotes.ClassActionResult:FireClient(target, actionId, ok, message, actor, extra)
	end
end

-- Per-player cooldowns, keyed by action. Kept as deadlines rather than timers, so nothing has to be
-- cancelled when a player leaves.
local Cooldowns = {} -- [player] = { [actionId] = os.clock() deadline }

local function onCooldown(player, actionId)
	local held = Cooldowns[player]
	local until_ = held and held[actionId]
	return until_ ~= nil and os.clock() < until_
end

local function startCooldown(player, actionId, seconds)
	Cooldowns[player] = Cooldowns[player] or {}
	Cooldowns[player][actionId] = os.clock() + seconds
end

--------------------------------------------------------------------------------
-- Give money
--------------------------------------------------------------------------------

local function doGive(actor, target, amount)
	amount = math.floor(tonumber(amount) or 0)
	if amount <= 0 then
		return report(actor, nil, "give", false, "จำนวนเงินไม่ถูกต้อง")
	end

	local state = Inventory.Get(actor)
	if not state or state.gold < amount then
		return report(actor, nil, "give", false, "เงินในกระเป๋าไม่พอ")
	end

	-- Taken before it is handed over, so a failure between the two cannot mint money.
	Inventory.AddGold(actor, -amount)
	Inventory.AddGold(target, amount)
	report(actor, target, "give", true, ("โอนเงิน %d"):format(amount), amount)
end

--------------------------------------------------------------------------------
-- Beg
--------------------------------------------------------------------------------

local function doBeg(actor, target)
	if onCooldown(actor, "beg") then
		return report(actor, nil, "beg", false, "เพิ่งขอไปเมื่อกี้")
	end
	startCooldown(actor, "beg", ClassActionConfig.Beg.cooldownSeconds)
	-- No money moves: begging is a gesture, and whether to give is the other player's business. That is what
	-- makes it roleplay rather than a mechanic that takes.
	report(actor, target, "beg", true, "ขอเงิน")
end

--------------------------------------------------------------------------------
-- Rob
--------------------------------------------------------------------------------

-- [victim] = { thief, deadline, defended }
local Robberies = {}

local function resolveRobbery(victim)
	local entry = Robberies[victim]
	if not entry then return end
	Robberies[victim] = nil
	local thief = entry.thief

	-- The thief may have left, died, or walked away while the countdown ran.
	if not thief or not thief.Parent then return end

	if entry.defended then
		-- Failed: the thief is marked red for everyone for ten minutes.
		Classes.Mark(thief)
		startCooldown(thief, "rob", ClassActionConfig.Rob.cooldownSeconds)
		return report(thief, victim, "rob", false, "ปล้นไม่สำเร็จ ติดชื่อแดง")
	end

	if not withinRange(thief, victim) then
		startCooldown(thief, "rob", ClassActionConfig.Rob.cooldownSeconds)
		return report(thief, victim, "rob", false, "เป้าหมายหนีไปแล้ว")
	end

	local state = Inventory.Get(victim)
	local taken = state and state.gold or 0
	if taken <= 0 then
		startCooldown(thief, "rob", ClassActionConfig.Rob.cooldownSeconds)
		return report(thief, victim, "rob", false, "เป้าหมายไม่มีเงินติดตัว")
	end

	Inventory.AddGold(victim, -taken)
	Inventory.AddGold(thief, taken)
	startCooldown(thief, "rob", ClassActionConfig.Rob.cooldownSeconds)
	report(thief, victim, "rob", true, ("ปล้นได้ %d"):format(taken), taken)
end

local function doRob(actor, target)
	if onCooldown(actor, "rob") then
		return report(actor, nil, "rob", false, "ยังปล้นไม่ได้ตอนนี้")
	end
	if Robberies[target] then
		return report(actor, nil, "rob", false, "คนนี้กำลังโดนปล้นอยู่")
	end

	local seconds = ClassActionConfig.Rob.countdownSeconds
	Robberies[target] = { thief = actor, defended = false }
	-- The victim gets the countdown and a button. Everything about whether they beat it is decided on the
	-- server when the timer runs out, so a client that never answers is simply robbed.
	Remotes.ClassActionPrompt:FireClient(target, "rob", actor, seconds)
	-- Reported as "rob_start", not "rob": the coin sound is keyed off a successful rob, and a robbery that
	-- has only just begun has taken nothing yet. The real result arrives when the countdown resolves.
	report(actor, nil, "rob_start", true, "กำลังปล้น...")

	task.delay(seconds, function()
		resolveRobbery(target)
	end)
end

--------------------------------------------------------------------------------
-- Heal (Priest)
--------------------------------------------------------------------------------

local function doHeal(actor, target, size)
	-- Only the two real sizes. Indexing the Heal table by whatever string arrived would also match
	-- reviveFraction and reviveSeconds, which are numbers and would blow up on option.cost.
	local option = (size == "small" or size == "large") and ClassActionConfig.Heal[size] or nil
	if not option then
		return report(actor, nil, "heal", false, "เลือกขนาดการฮีลไม่ถูกต้อง")
	end

	-- The patient pays. A healer who had to pay to heal would simply not heal anyone.
	local state = Inventory.Get(target)
	if not state or state.gold < option.cost then
		return report(actor, target, "heal", false, "ผู้รับมีเงินไม่พอ")
	end

	if not Vitals.Get(target) then
		return report(actor, nil, "heal", false, "ฮีลไม่ได้ตอนนี้")
	end

	Inventory.AddGold(target, -option.cost)
	Inventory.AddGold(actor, option.cost)
	-- A fraction of the patient's OWN maximum, which scales with their level -- healing 25% of a flat 100
	-- would be a rounding error to a level 80 player. Vitals.Heal clamps to the same maximum, so a full heal
	-- cannot overshoot.
	Vitals.Heal(target, Progression.MaxHP(target) * option.fraction)
	report(actor, target, "heal", true, ("%s (%d ทอง)"):format(option.label, option.cost), option.cost)
end

--------------------------------------------------------------------------------
-- Repair (Architect)
--------------------------------------------------------------------------------

local function doRepair(actor, target)
	local cost = ClassActionConfig.Repair.cost
	local state = Inventory.Get(target)
	if not state or state.gold < cost then
		return report(actor, target, "repair", false, "ผู้รับมีเงินไม่พอ")
	end

	if not Inventory.RepairAll(target) then
		return report(actor, target, "repair", false, "ของยังไม่สึกหรอ")
	end
	Inventory.AddGold(target, -cost)
	Inventory.AddGold(actor, cost)
	Vitals.SyncArmorFromEquipment(target)
	report(actor, target, "repair", true, ("ซ่อมของทั้งตัว (%d ทอง)"):format(cost), cost)
end

--------------------------------------------------------------------------------
-- Carry (with consent)
--------------------------------------------------------------------------------

-- [target] = { asker, deadline }. One pending request per target, so a crowd cannot bury someone in
-- popups, and the asker cannot queue several to be answered later.
local CarryRequests = {}

local CARRY_ASK_SECONDS = 15

local function doAskCarry(actor, target)
	if CarryRequests[target] then
		return report(actor, nil, "carry", false, "เขากำลังถูกถามอยู่")
	end
	CarryRequests[target] = { asker = actor, deadline = os.clock() + CARRY_ASK_SECONDS }
	Remotes.ClassActionPrompt:FireClient(target, "carry", actor, CARRY_ASK_SECONDS)
	report(actor, nil, "carry_ask", true, "ขออนุญาตอุ้ม...")

	task.delay(CARRY_ASK_SECONDS, function()
		local entry = CarryRequests[target]
		-- Only clear it if it is still OUR request: the target may have answered and been asked again.
		if entry and entry.asker == actor then
			CarryRequests[target] = nil
			report(actor, nil, "carry", false, "ไม่มีคำตอบ")
		end
	end)
end

-- The target answering. Consent is recorded here and nowhere else: the carry itself is started by the
-- server from this handler, so a client cannot claim to have been given permission.
local function answerCarry(target, accepted)
	local entry = CarryRequests[target]
	if not entry then return end
	CarryRequests[target] = nil
	local asker = entry.asker

	if not accepted then
		return report(asker, nil, "carry", false, "ถูกปฏิเสธ")
	end
	-- Re-checked at the moment of the answer, not the moment of the ask: they may have walked apart, or
	-- either may have gone down, in the fifteen seconds in between.
	if not mayAct(asker, target, "carry") then
		return report(asker, nil, "carry", false, "อยู่ไกลเกินไปแล้ว")
	end
	if not RescueAccess.BeginCarry or not RescueAccess.BeginCarry(asker, target, true) then
		return report(asker, nil, "carry", false, "อุ้มไม่ได้ตอนนี้")
	end
	report(asker, target, "carry", true, "อุ้มขึ้นหลังแล้ว")
end

--------------------------------------------------------------------------------
-- Handing an item over
--------------------------------------------------------------------------------

-- From the bag's own menu rather than a class action: anyone can hand something to anyone. The class
-- actions are about what your office lets you do TO someone; this is just passing something across.
Remotes.RequestGiveItem.OnServerEvent:Connect(function(player, index, target)
	if type(index) ~= "number" then return end
	if typeof(target) ~= "Instance" or not target:IsA("Player") then return end
	if player == target then return end
	if Vitals.IsDowned(player) or Vitals.IsDowned(target) then return end
	if not withinRange(player, target) then
		return report(player, nil, "giveitem", false, "อยู่ไกลเกินไป")
	end

	local state = Inventory.Get(player)
	local slot = state and state.slots[index]
	if not slot then return end

	-- The whole stack moves. Splitting one would need a number box, and the menu is meant to be two taps.
	local id, count, durability = slot.id, slot.count or 1, slot.durability
	if not Inventory.AddItem(target, id, count, durability) then
		return report(player, nil, "giveitem", false, "กระเป๋าเขาเต็ม")
	end
	-- Removed only after the target has taken it, so a full bag cannot destroy the item.
	Inventory.RemoveFromSlot(player, index, count)

	local item = ItemCatalog.Get(id)
	local shown = (item and item.name) or id
	report(player, target, "giveitem", true, ("ให้ %s x%d"):format(shown, count), count)
end)

--------------------------------------------------------------------------------
-- Requests
--------------------------------------------------------------------------------

Remotes.RequestClassAction.OnServerEvent:Connect(function(actor, actionId, target, argument)
	if type(actionId) ~= "string" then return end
	if typeof(target) ~= "Instance" or not target:IsA("Player") then return end
	if not mayAct(actor, target, actionId) then return end

	if actionId == "give" then
		doGive(actor, target, argument)
	elseif actionId == "beg" then
		doBeg(actor, target)
	elseif actionId == "rob" then
		doRob(actor, target)
	elseif actionId == "heal" then
		doHeal(actor, target, argument)
	elseif actionId == "repair" then
		doRepair(actor, target)
	elseif actionId == "carry" then
		doAskCarry(actor, target)
	elseif actionId == "arrest" then
		-- Arrest owns its own sessions and the hold; this only asks it to start one.
		if ArrestAccess.Begin then
			local ok, message = ArrestAccess.Begin(actor, target)
			if not ok then report(actor, nil, "arrest", false, message) end
		end
	elseif actionId == "trade" then
		-- Trading owns its own sessions; this only asks it to start one.
		if TradeAccess.Invite then
			local ok, message = TradeAccess.Invite(actor, target)
			if not ok then report(actor, nil, "trade", false, message) end
		end
	end

end)

-- The victim of a robbery pressing the defend button.
Remotes.RespondClassAction.OnServerEvent:Connect(function(player, actionId, accepted)
	if actionId == "rob" then
		local entry = Robberies[player]
		if not entry then return end
		if accepted then return end -- "accepted" means letting it happen, which needs no action
		entry.defended = true
	elseif actionId == "carry" then
		answerCarry(player, accepted == true)
	end
end)

Players.PlayerRemoving:Connect(function(player)
	Cooldowns[player] = nil
	Robberies[player] = nil
	CarryRequests[player] = nil
	for target, entry in pairs(CarryRequests) do
		if entry.asker == player then CarryRequests[target] = nil end
	end
	-- A thief who leaves mid-robbery: the countdown still resolves, and finds no thief to pay.
	for victim, entry in pairs(Robberies) do
		if entry.thief == player then Robberies[victim] = nil end
	end
end)
