-- Calls.lua: telepathy calls between friends.
--
-- UI ONLY for now. There is no audio: Roblox voice chat has to be enabled game-wide and each player has to
-- verify their own age, and even then it cannot address one person privately. This models the ringing, the
-- answering and the hanging up so the flow is real and finished; the audio drops in behind it later.
--
-- A player is in at most one call at a time, which is what keeps the state a single pair rather than a graph.
local Calls = {}

-- [player] = { with = otherPlayer, state = "ringing"|"active", caller = boolean, startedAt = os.clock() }
local Active = {}

function Calls.Get(player)
	return Active[player]
end

function Calls.Remove(player)
	local entry = Active[player]
	if entry and Active[entry.with] then
		Active[entry.with] = nil
	end
	Active[player] = nil
	return entry and entry.with or nil
end

-- Starts ringing. Returns false plus a reason, or true plus the player being called.
function Calls.Start(caller, target)
	if not caller or not target or caller == target then return false, "โทรหาตัวเองไม่ได้" end
	if Active[caller] then return false, "คุณอยู่ในสายอยู่แล้ว" end
	if Active[target] then return false, ("%s กำลังคุยสายอื่นอยู่"):format(target.Name) end

	local now = os.clock()
	Active[caller] = { with = target, state = "ringing", caller = true, startedAt = now }
	Active[target] = { with = caller, state = "ringing", caller = false, startedAt = now }
	return true, target
end

-- The person who was called picks up. Only they can: the caller answering their own call is nonsense.
function Calls.Answer(player)
	local entry = Active[player]
	if not entry then return false, "ไม่มีสายเรียกเข้า" end
	if entry.caller then return false, "รอปลายสายรับก่อน" end
	if entry.state ~= "ringing" then return false, "สายนี้รับไปแล้ว" end

	entry.state = "active"
	local other = Active[entry.with]
	if other then other.state = "active" end
	return true, entry.with
end

-- Declining and hanging up are the same operation from the state's point of view: the call ends for both.
function Calls.End(player)
	local entry = Active[player]
	if not entry then return false, "ไม่มีสายที่ต้องวาง" end
	local other = entry.with
	local wasRinging = entry.state == "ringing"
	local wasCaller = entry.caller
	Active[player] = nil
	Active[other] = nil
	return true, other, wasRinging, wasCaller
end

return Calls
