-- MarketAccess: a hand-off from Shop.server to anything that wants to quote the shop's prices.
--
-- The same idea as RescueAccess and WeaponVisualsAccess. The speaking stone's "ราคากลาง" screen shows what
-- the shop pays right now, and the one thing it must never do is work out that price itself: the shop's
-- multipliers live in Shop.server's own memory and are rerolled there, so a second copy of the arithmetic
-- would start lying the first time the two drifted apart. The stone asks the shop instead.
--
-- Left as a hand-off rather than PlayerSocial requiring Shop.server (or the reverse) because the two have
-- nothing else to say to each other, and because a .server script is not a module anyone should require.
--
-- Empty until Shop.server has published itself, so every caller must cope with nil; in the lobby Shop.server
-- returns before it ever gets that far, and it is never set at all.
local MarketAccess = {}

-- Quote() -> { prices = { {id, name, icon, price} ... }, rerollIn = seconds }
--
-- The whole board in one call rather than a price at a time: the list is short, it is the same for every
-- player in the server, and asking once means every line on the screen was priced at the same instant.
MarketAccess.Quote = nil

return MarketAccess
