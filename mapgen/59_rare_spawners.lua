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

-- Read straight off the models the user placed, rather than copied down here by hand.
--
-- The user arranges a display model where they want the monster, and this phase turns each one into a
-- spawner at the same spot. Reading the positions live means moving a model in Studio moves the monster:
-- there is no second list of coordinates to keep in step with the first.
local PROTOTYPE_FOLDER = "Model_moster"

-- Which model name means which entry in GatherConfig.Mobs, and how many of that monster the spot keeps
-- alive. A named slime is ONE rare thing in one place; spiders and skeletons come in a group.
local SPAWN_KINDS = {
	Monster_BioSlime    = { kind = "BioSlime",    count = 1, radius = 20 },
	Monster_PlasmaSlime = { kind = "PlasmaSlime", count = 1, radius = 20 },
	Monster_SteamSlime  = { kind = "SteamSlime",  count = 1, radius = 20 },
	-- Around the spot rather than on it, which is what the user asked for: a nest you walk into.
	Monster_Spider      = { kind = "Spider",      count = 4, radius = 90 },
	Monster_Skeleton    = { kind = "Skeleton",    count = 4, radius = 90 },
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

	local prototypes = L.root():FindFirstChild(PROTOTYPE_FOLDER, true)
	assert(prototypes, PROTOTYPE_FOLDER .. " not found -- it holds the models each monster is built from")

	local placed, unknown = 0, {}
	for _, model in ipairs(prototypes:GetChildren()) do
		local spec = SPAWN_KINDS[model.Name]
		if not spec then
			table.insert(unknown, model.Name)
		else
			local at = model:IsA("Model") and model:GetPivot().Position
				or (model:IsA("BasePart") and model.Position)
			if at then
				local y = groundAt(at.X, at.Z)

				local marker = Instance.new("Part")
				marker.Name = "Spawner_" .. spec.kind
				marker.Size = Vector3.new(4, 1, 4)
				marker.CFrame = CFrame.new(at.X, y + 0.5, at.Z)
				marker.Anchored = true
				marker.CanCollide = false
				marker.Transparency = 1
				marker.Parent = folder

				marker:SetAttribute("MobKind", spec.kind)
				marker:SetAttribute("Count", spec.count)
				marker:SetAttribute("Radius", spec.radius)
				CollectionService:AddTag(marker, "WOLD_Spawner")
				placed += 1
			end
		end
	end

	if #unknown > 0 then
		L.progress("no monster kind for: " .. table.concat(unknown, ", "))
	end

	-- The prototype models are deliberately LEFT ALONE. They are what Mobs.server clones to build each
	-- monster, so deleting them would leave the spawners with nothing to build from -- and they are the
	-- user's own arrangement besides.
	print(("[WOLD] RareSpawners: %d spawners placed from the models in %s")
		:format(placed, PROTOTYPE_FOLDER))
end)
