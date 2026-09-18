-- Consuming.lua: who is currently eating or drinking something.
--
-- Using a consumable is no longer instant. The item leaves the bag at once -- so it cannot be spent twice --
-- but its effect lands only when the three seconds are up. Interrupting means the item is gone and nothing
-- was gained, which is what makes drinking a potion mid-fight a real decision rather than a free button.
--
-- The server owns this. A client that decided when its own potion landed could land it immediately.
local ItemCatalog = require(game.ReplicatedStorage.ItemCatalog)

local Consuming = {}

-- [player] = { id = itemId, until = os.clock() deadline, token = number }
local Active = {}
local NextToken = 1

function Consuming.Remove(player)
	Active[player] = nil
end

function Consuming.IsConsuming(player)
	local entry = Active[player]
	if not entry then return false end
	if os.clock() >= entry.deadline then
		-- The finish handler should have cleared it; if it somehow did not, do not block the player forever.
		Active[player] = nil
		return false
	end
	return true
end

function Consuming.ItemOf(player)
	local entry = Active[player]
	return entry and entry.id or nil
end

-- Starts the wait. Returns the token that identifies THIS use, so a finish that arrives after an interrupt
-- (or after a second item was started) can tell it is stale and do nothing.
function Consuming.Begin(player, itemId)
	local token = NextToken
	NextToken += 1
	Active[player] = {
		id = itemId,
		deadline = os.clock() + ItemCatalog.HoldSeconds(itemId),
		token = token,
	}
	return token
end

-- True when the wait that started with `token` is still the current one.
function Consuming.StillCurrent(player, token)
	local entry = Active[player]
	return entry ~= nil and entry.token == token
end

function Consuming.Cancel(player)
	local entry = Active[player]
	Active[player] = nil
	return entry ~= nil
end

return Consuming
