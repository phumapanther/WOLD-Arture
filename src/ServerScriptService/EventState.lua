-- EventState.lua: what the world is currently doing, for the systems that have to care.
--
-- WorldEvents.server owns the schedule and writes here; the NPC systems (shop, forge, vault, and anything
-- added later) only ever read. A tiny module rather than a require of WorldEvents, for the reason
-- ProfileAccess exists: the shopkeeper must not depend on the event scheduler's lifecycle, and the scheduler
-- must not have to know every system that reacts to it.
local EventState = {}

-- [eventId] = { startedAt, endsAt | nil, ... } for every event running right now. Written by WorldEvents.
EventState.Active = {}

-- The one rule that reaches outside the event system: while the city's engines are down, an NPC will not talk
-- to you. Asked by every NPC prompt, so the answer lives in one place.
function EventState.IsBlackout()
	return EventState.Active.blackout ~= nil
end

-- What to say instead. Exactly the user's wording, kept here so every refusal is worded identically wherever
-- it comes from.
EventState.BlackoutRefusal = "ไฟดับอยากรุณาไปซ่อมไฟก่อน"

-- True when the player may open an NPC's menu at all. Returns the reason as a second value, so a caller can
-- pass it straight to the notification it was going to send anyway.
function EventState.NpcAvailable()
	if EventState.IsBlackout() then return false, EventState.BlackoutRefusal end
	return true
end

return EventState
