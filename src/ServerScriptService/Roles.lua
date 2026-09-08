-- Roles.lua: who holds which role.
--
-- A player has at most one role at a time. Kept as a module in the same shape as Vitals/Inventory/Progression
-- so the phase-4 abilities can ask "what is this player" without reaching into the profile themselves.
local RoleConfig = require(game.ReplicatedStorage.RoleConfig)
local ProfileAccess = require(script.Parent.ProfileAccess)

local Roles = {}

local Held = {} -- [player] = roleId | nil

function Roles.Add(player, saved)
	-- An unknown role in a saved profile (renamed or removed since) is dropped rather than kept as a ghost.
	Held[player] = (saved and RoleConfig.Exists(saved)) and saved or nil
	Roles.Replicate(player)
	return Held[player]
end

function Roles.Remove(player)
	Held[player] = nil
end

function Roles.Get(player)
	return Held[player]
end

function Roles.Has(player, roleId)
	return Held[player] == roleId
end

-- Replicated as an attribute so any client can see who is what (a guard's badge, a priest's aura) without a
-- remote of its own. Attributes replicate automatically and survive rejoins within a session.
function Roles.Replicate(player)
	player:SetAttribute("WOLD_Role", Held[player])
end

-- Returns false for a role that does not exist, so a typo cannot invent one.
function Roles.Set(player, roleId)
	if roleId ~= nil and not RoleConfig.Exists(roleId) then return false end
	Held[player] = roleId
	Roles.Replicate(player)
	-- Straight to the profile: a role handed out by an admin should survive a rejoin even if the server dies
	-- before the next autosave.
	if ProfileAccess.Flush then ProfileAccess.Flush(player) end
	return true
end

function Roles.Clear(player)
	return Roles.Set(player, nil)
end

function Roles.Serialize(player)
	return Held[player]
end

return Roles
