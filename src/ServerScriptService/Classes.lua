-- Classes.lua: who holds which class, and who is currently marked.
--
-- A player holds at most one class per tier: one basic (level 5) and one advanced (level 50). Kept in the
-- same shape as Vitals/Inventory/Progression so the class abilities can ask "what is this player" without
-- reaching into the profile themselves.
--
-- This replaces Roles.lua. The four old roles (Guard, Priest, Architect, Merchant) are all classes now, so
-- a profile holding one is migrated into the right tier rather than dropped -- nobody loses a role they
-- were given by an admin.
local ClassConfig = require(game.ReplicatedStorage.ClassConfig)
local ProfileAccess = require(script.Parent.ProfileAccess)

local Classes = {}

local Held = {} -- [player] = { basic = id|nil, advanced = id|nil }
-- The level each tier was last offered at. Saved with the classes because it answers a question the classes
-- cannot: a level-60 player holding a class is either someone who just arrived (offer the card) or someone
-- rejoining (do not), and only this tells them apart across a session boundary.
local Offered = {} -- [player] = { basic = level|nil, advanced = level|nil }
local MarkedUntil = {} -- [player] = os.clock() deadline while marked for a failed robbery

--------------------------------------------------------------------------------

local function blank()
	return { basic = nil, advanced = nil }
end

-- Puts a saved id in the slot its tier belongs to. Unknown ids (renamed or removed since the save) are
-- dropped rather than kept as ghosts.
local function place(state, id)
	local class = id and ClassConfig.Get(id)
	if not class then return end
	state[class.tier] = id
end

-- `saved` is either the new shape ({Basic, Advanced}) or, for a profile written before classes existed, the
-- single role id that Roles.lua used to store. Both are accepted so nothing needs a migration pass.
function Classes.Add(player, saved)
	local state = blank()
	if type(saved) == "table" then
		place(state, saved.Basic)
		place(state, saved.Advanced)
	elseif type(saved) == "string" then
		place(state, saved) -- an old Role value: Guard/Priest/Architect are advanced, Merchant is basic
	end
	Held[player] = state
	Offered[player] = (type(saved) == "table" and type(saved.Offered) == "table") and saved.Offered or {}
	Classes.Replicate(player)
	return state
end

function Classes.Remove(player)
	Held[player] = nil
	Offered[player] = nil
	MarkedUntil[player] = nil
end

function Classes.Get(player, tier)
	local state = Held[player]
	if not state then return nil end
	return state[tier]
end

-- True when the player holds this class in either tier, which is what an ability wants to ask.
function Classes.Has(player, classId)
	local state = Held[player]
	if not state then return false end
	return state.basic == classId or state.advanced == classId
end

-- The class whose colour should paint the name: the advanced one if there is one, since it outranks the
-- basic choice and is the more interesting fact about a player.
function Classes.Primary(player)
	local state = Held[player]
	if not state then return nil end
	return state.advanced or state.basic
end

-- The level `tier` was last offered at, or nil. Nil means "never offered", which is what a fresh
-- character has.
function Classes.OfferedAt(player, tier)
	local seen = Offered[player]
	return seen and seen[tier] or nil
end

function Classes.MarkOffered(player, tier, level)
	Offered[player] = Offered[player] or {}
	Offered[player][tier] = level
	if ProfileAccess.Flush then ProfileAccess.Flush(player) end
end

--------------------------------------------------------------------------------
-- Replication
--------------------------------------------------------------------------------

-- Attributes rather than a remote: they replicate on their own and are already correct for a client that
-- joins later, which is exactly what a nametag needs.
function Classes.Replicate(player)
	local state = Held[player] or blank()
	player:SetAttribute("WOLD_ClassBasic", state.basic)
	player:SetAttribute("WOLD_ClassAdvanced", state.advanced)
	player:SetAttribute("WOLD_Marked", Classes.IsMarked(player) or nil)
end

--------------------------------------------------------------------------------
-- Setting
--------------------------------------------------------------------------------

-- Returns false for a class that does not exist or does not belong to `tier`, so neither a typo nor a
-- client asking for Guard at level 5 can put one in the wrong slot.
function Classes.Set(player, tier, classId)
	local state = Held[player]
	if not state then return false end
	if classId ~= nil then
		local class = ClassConfig.Get(classId)
		if not class or class.tier ~= tier then return false end
	end
	state[tier] = classId
	Classes.Replicate(player)
	-- Straight to the profile: a class chosen from a card should survive a rejoin even if the server dies
	-- before the next autosave.
	if ProfileAccess.Flush then ProfileAccess.Flush(player) end
	return true
end

function Classes.Clear(player, tier)
	return Classes.Set(player, tier, nil)
end

--------------------------------------------------------------------------------
-- The mark
--------------------------------------------------------------------------------

-- A failed robbery paints the thief's name red for everyone, for ten minutes. Stored as a deadline rather
-- than a flag plus a timer, so it needs no upkeep loop and cannot leak a task per marking.
function Classes.Mark(player)
	MarkedUntil[player] = os.clock() + ClassConfig.MarkedSeconds
	Classes.Replicate(player)
end

function Classes.IsMarked(player)
	local until_ = MarkedUntil[player]
	if not until_ then return false end
	if os.clock() >= until_ then
		MarkedUntil[player] = nil
		return false
	end
	return true
end

-- Seconds left on the mark, or 0. The nametag uses this to know when to stop asking.
function Classes.MarkRemaining(player)
	local until_ = MarkedUntil[player]
	if not until_ then return 0 end
	return math.max(0, until_ - os.clock())
end

-- Death takes the classes with the level. Progression already resets the level to 1, and a player who
-- kept their class through that would never be offered the card again: the check is "level 5 and no basic
-- class", and they would arrive at level 5 already holding one.
--
-- This is also what makes the choice worth anything. The class is meant to be a thing you can lose.
function Classes.ResetOnDeath(player)
	local state = Held[player]
	if not state then return end
	state.basic = nil
	state.advanced = nil
	-- Cleared so climbing back to level 5 counts as reaching it again and offers the card.
	Offered[player] = {}
	-- The mark goes too: it is tied to a life, and ten minutes of shame that outlived the death would be
	-- carried by a character who no longer did the thing.
	MarkedUntil[player] = nil
	Classes.Replicate(player)
	if ProfileAccess.Flush then ProfileAccess.Flush(player) end
end

function Classes.Serialize(player)
	local state = Held[player]
	if not state then return nil end
	-- The mark is deliberately NOT saved: ten minutes of shame should not survive a rejoin, or hiding from
	-- it would be a matter of pressing the rejoin button.
	return { Basic = state.basic, Advanced = state.advanced, Offered = Offered[player] or {} }
end

return Classes
