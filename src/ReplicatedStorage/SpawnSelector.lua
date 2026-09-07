-- SpawnSelector: pure spawn-position resolution logic, server-side only (no DataStore access itself — that's
-- PlayerPosition.server.lua's job; this just decides what to fall back to when there's no saved position).
local SpawnSelector = {}

-- ResolvePosition: savedPosition is a Vector3 from the player's saved data, or nil (first-ever join, or the
-- lookup failed). Falls back to WOLD.TempSpawn (Brasshaven's future site, real terrain height) so first spawn
-- and channel-server-with-no-save land in the same place; last resort is a hardcoded safety net.
function SpawnSelector.ResolvePosition(savedPosition)
	if savedPosition then
		return savedPosition
	end
	local spawn = workspace:FindFirstChildWhichIsA("SpawnLocation", true)
	if spawn then
		return spawn.Position + Vector3.new(0, 3, 0)
	end
	return Vector3.new(0, 50, 0) -- last-resort fallback so an empty/fresh place never errors
end

return SpawnSelector
