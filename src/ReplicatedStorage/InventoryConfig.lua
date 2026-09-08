-- InventoryConfig: bag size, carry weight, and what being overloaded costs you.
local InventoryConfig = {}

InventoryConfig.SlotCount = 36 -- the personal bag grid, 6 columns x 6 rows
InventoryConfig.MaxWeight = 2000 -- carry this much before the penalties below start

-- Overencumbrance. Past MaxWeight you slow down in proportion to the excess, down to a floor so a hoarder can
-- still crawl home rather than being frozen in place.
InventoryConfig.MinSpeedMultiplier = 0.45
-- Past this multiple of MaxWeight, roll and slide are also cut in half: heavy loads should make you commit.
InventoryConfig.HeavyLoadRatio = 1.5
InventoryConfig.HeavyActionPenalty = 0.5

-- Returns the movement multiplier for a given carried weight: 1 up to the limit, then falling away.
function InventoryConfig.SpeedMultiplier(weight)
	if weight <= InventoryConfig.MaxWeight then return 1 end
	local over = weight / InventoryConfig.MaxWeight -- 1.0 at the limit, 2.0 at double
	return math.max(InventoryConfig.MinSpeedMultiplier, 1 / over)
end

function InventoryConfig.IsHeavilyLoaded(weight)
	return weight > InventoryConfig.MaxWeight * InventoryConfig.HeavyLoadRatio
end

return InventoryConfig
