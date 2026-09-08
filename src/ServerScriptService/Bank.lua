-- Bank.lua: banked gold, and transfers between players.
--
-- Pocket gold (Inventory) is lost on death; banked gold is not. That is the whole reason to bank anything,
-- and it is why this balance lives in the profile rather than alongside the bag.
--
-- Every amount is validated and clamped HERE, on the server. The client can only ever say "I would like to
-- move this much" -- it never sends a balance, and it is never believed about one.
local SocialConfig = require(game.ReplicatedStorage.SocialConfig)
local ProfileAccess = require(script.Parent.ProfileAccess)

local Bank = {}

local Balances = {} -- [player] = number, mirrored into the profile on every change

-- Injected by PlayerSocial rather than required, so this module does not depend on the inventory lifecycle.
Bank.Inventory = nil

function Bank.Add(player, saved)
	Balances[player] = math.max(0, math.floor(tonumber(saved) or 0))
	return Balances[player]
end

function Bank.Remove(player)
	Balances[player] = nil
end

function Bank.Get(player)
	return Balances[player] or 0
end

function Bank.Serialize(player)
	return Balances[player]
end

-- Writes a new balance and pushes it straight into the profile: money is too important to lose to the gap
-- between autosave ticks.
local function set(player, amount)
	Balances[player] = math.max(0, math.floor(amount))
	if ProfileAccess.Flush then ProfileAccess.Flush(player) end
end

-- Normalises whatever the client sent into a whole, positive, in-range amount. Returns nil plus a reason
-- rather than clamping silently, so a player who typed nonsense is told rather than surprised.
local function validAmount(raw)
	local amount = tonumber(raw)
	if not amount or amount ~= amount then return nil, "จำนวนเงินไม่ถูกต้อง" end -- nan
	amount = math.floor(amount)
	if amount < SocialConfig.BankMinTransfer then return nil, "จำนวนเงินต้องมากกว่า 0" end
	if amount > SocialConfig.BankMaxTransfer then return nil, "จำนวนเงินเกินขีดจำกัด" end
	return amount
end

--------------------------------------------------------------------------------

-- Pocket -> bank.
function Bank.Deposit(player, raw)
	local amount, reason = validAmount(raw)
	if not amount then return false, reason end

	local inventory = Bank.Inventory
	local state = inventory and inventory.Get(player)
	if not state then return false, "ยังโหลดข้อมูลไม่เสร็จ" end
	if state.gold < amount then return false, "เงินในกระเป๋าไม่พอ" end

	-- Take first, then credit: if anything below were to fail, the player would rather be told than have
	-- gold appear in both places.
	inventory.AddGold(player, -amount)
	set(player, Bank.Get(player) + amount)
	return true, ("ฝาก %d เหรียญ"):format(amount)
end

-- Bank -> pocket.
function Bank.Withdraw(player, raw)
	local amount, reason = validAmount(raw)
	if not amount then return false, reason end

	local inventory = Bank.Inventory
	if not inventory or not inventory.Get(player) then return false, "ยังโหลดข้อมูลไม่เสร็จ" end
	if Bank.Get(player) < amount then return false, "เงินในธนาคารไม่พอ" end

	set(player, Bank.Get(player) - amount)
	inventory.AddGold(player, amount)
	return true, ("ถอน %d เหรียญ"):format(amount)
end

-- Bank -> another player's bank. The recipient must be in this server right now, which is what makes the
-- whole transfer a single in-memory operation that cannot half-complete across a server boundary.
function Bank.Transfer(player, targetName, raw)
	local amount, reason = validAmount(raw)
	if not amount then return false, reason end
	if typeof(targetName) ~= "string" then return false, "ชื่อผู้รับไม่ถูกต้อง" end

	-- "@name" is how the user asked players to type it; accept it with or without the @.
	local wanted = targetName:gsub("^@", ""):gsub("%s", ""):lower()
	if wanted == "" then return false, "ใส่ชื่อผู้รับด้วย" end

	local Players = game:GetService("Players")
	local target
	for _, other in ipairs(Players:GetPlayers()) do
		-- Exact match only. A prefix match on a MONEY transfer is how someone pays the wrong person.
		if other.Name:lower() == wanted or other.DisplayName:lower() == wanted then
			target = other
			break
		end
	end
	if not target then return false, "ไม่เจอผู้เล่นชื่อนี้ในเซิร์ฟเวอร์" end
	if target == player then return false, "โอนให้ตัวเองไม่ได้" end
	if Balances[target] == nil then return false, "ผู้รับยังโหลดข้อมูลไม่เสร็จ" end
	if Bank.Get(player) < amount then return false, "เงินในธนาคารไม่พอ" end

	-- Both sides move together, with no yield in between, so nothing can observe a half-done transfer.
	set(player, Bank.Get(player) - amount)
	set(target, Bank.Get(target) + amount)
	return true, ("โอน %d เหรียญ ให้ %s"):format(amount, target.Name), target
end

return Bank
