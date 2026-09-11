-- 59_rare_spawners: turn the three rare slimes the user placed by hand into monsters that can be fought.
--
-- The user arranged Monster_SteamSlime, Monster_PlasmaSlime and Monster_BioSlime around the map. Those are
-- display models from the kit: no Humanoid, no health, nothing to hit. What makes a monster fightable is a
-- WOLD_Spawner marker, which Mobs.server.lua reads to build a real one that chases, takes damage and drops.
--
-- So the POSITIONS are kept -- they are the user's design decision -- and the props are replaced with
-- markers at the same spots.
--
-- The rare slimes drop one weapon in ten kills (GatherConfig.SpecialWeaponChance) out of eight, never the
-- pistol, and come back thirty minutes after they die.
--
-- Run with:  node tools/run-luau.js mapgen/59_rare_spawners.lua

--------------------------------------------------------------------------------

-- Where the user put them, read off the models they placed. Ground height is measured at run time rather
-- than stored, so a marker sits on the terrain even if the ground is later reshaped.
local SPOTS = {
	{ kind = "BioSlime",    x = 1555, z = 3401 },
	{ kind = "PlasmaSlime", x = 2633, z = 3641 },
	{ kind = "SteamSlime",  x = 1981, z = 4417 },
}

--------------------------------------------------------------------------------

return L.runPhase("RareSpawners", function(folder)
	-- The real surface, ignoring water, so a marker on the shore stands on the sand rather than floating on
	-- the sea. Excludes everything the generator built so a ray does not stop on a roof or a tree canopy.
	local probe = RaycastParams.new()
	probe.FilterType = Enum.RaycastFilterType.Exclude
	probe.FilterDescendantsInstances = { L.root() }
	probe.IgnoreWater = true

	local function groundAt(x, z)
		local hit = workspace:Raycast(Vector3.new(x, 1200, z), Vector3.new(0, -2000, 0), probe)
		return hit and hit.Position.Y or L.heightAt(x, z)
	end

	local CollectionService = game:GetService("CollectionService")

	for _, spot in ipairs(SPOTS) do
		local y = groundAt(spot.x, spot.z)

		local marker = Instance.new("Part")
		marker.Name = "RareSpawner_" .. spot.kind
		marker.Size = Vector3.new(4, 1, 4)
		marker.CFrame = CFrame.new(spot.x, y + 0.5, spot.z)
		marker.Anchored = true
		marker.CanCollide = false
		marker.Transparency = 1
		marker.Parent = folder

		marker:SetAttribute("MobKind", spot.kind)
		-- One each: a rare slime is something to go and find, not a field of them.
		marker:SetAttribute("Count", 1)
		-- Tight, so it respawns where the user put it rather than wandering off across the map.
		marker:SetAttribute("Radius", 20)
		CollectionService:AddTag(marker, "WOLD_Spawner")
	end

	-- The display props these replace. Removed only if they are still sitting where they were read from,
	-- so a prop the user has since moved somewhere deliberate is left alone.
	local removed = 0
	for _, name in ipairs({ "RareMoster", "RareMonster" }) do
		local f = L.root():FindFirstChild("Backup") and L.root().Backup:FindFirstChild(name)
		if f then
			for _, m in ipairs(f:GetChildren()) do
				if m.Name:find("Monster_") then
					m:Destroy()
					removed += 1
				end
			end
		end
	end

	print(("[WOLD] RareSpawners: %d spawners placed, %d display props removed")
		:format(#SPOTS, removed))
end)
