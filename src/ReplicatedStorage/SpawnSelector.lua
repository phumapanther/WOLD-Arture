-- SpawnSelector: sub-project 1 (save/restore last position) will replace this body to check a saved
-- position first. For now, every arrival uses whatever SpawnLocation exists in the world.
local SpawnSelector = {}

function SpawnSelector.GetSpawnPosition(_player)
	local spawn = workspace:FindFirstChildWhichIsA("SpawnLocation", true)
	if spawn then
		return spawn.Position + Vector3.new(0, 3, 0)
	end
	return Vector3.new(0, 50, 0) -- last-resort fallback so an empty/fresh place never errors
end

return SpawnSelector
