-- 58_kit_yard: one of every model the kit can build, laid out on open ground for the user to arrange.
--
-- This is a PARTS YARD, not a design. Nothing here is placed where it belongs -- the point is to get every
-- landmark, house, castle piece and NPC out of the code and into the world in one go, so the user can drag
-- them where they want them without hunting through builder names.
--
-- What is deliberately NOT here:
--   * the display pad under each model, and the name label over it. Those belong to K.build, which is the
--     showcase path; K.place raises the model alone, which is what a yard wants.
--   * the kit_showcase primitives (gears, barrels, crates, pipes). Those are components other models are
--     assembled FROM, not things to place in a town.
--   * rig prototypes and the smoke test, which exist to check the rig works.
--
-- Rerunning this replaces the yard and nothing else. Everything it makes lives in WOLD.KitYard.
--
-- Run with:  node tools/run-luau.js mapgen/58_kit_yard.lua --kit --models

--------------------------------------------------------------------------------

-- Laid out in rows by category, so the yard reads as a catalogue rather than a heap. Each row is spaced by
-- the widest thing in it; the gaps are generous because these get dragged around by hand.
local GROUPS = {
	{
		label = "Landmarks",
		gap = 200,
		names = { "Village_ClockTower", "Village_Tavern", "Village_Knights", "Village_Clinic",
			"Village_Workshop" },
	},
	{
		label = "Houses",
		gap = 150,
		names = { "House_Roundhouse", "House_Townhouse", "House_Longhouse", "House_PipeWorker",
			"House_StoneCottage" },
	},
	{
		label = "City buildings",
		gap = 200,
		names = { "City_Tenement", "City_MerchantHouse", "City_Guildhall", "City_Foundry" },
	},
	{
		label = "Castle",
		gap = 260,
		names = { "Castle_Keep", "Castle_GreatHall", "Castle_Assembly" },
	},
	{
		label = "Castle walls and towers",
		gap = 150,
		names = { "Castle_WallStraight", "Castle_WallCorner", "Castle_WallGate",
			"Castle_TowerRound", "Castle_TowerSquare", "Castle_RoofKit" },
	},
	{
		label = "NPCs",
		gap = 70,
		names = { "Merchant_Barnaby", "Merchant_Zael", "Merchant_Grick", "Baron_Vane",
			"Madam_Aurelia", "Don_Tiberius", "Blacksmith_Brannoc", "Mechanic_Lyra",
			"Gunsmith_Jax" },
	},
	{
		label = "Monsters",
		gap = 90,
		names = { "Monster_SteamSlime", "Monster_PlasmaSlime", "Monster_BioSlime" },
	},
}

-- Open, flat ground inside the city walls: measured at zero fall across 360 studs, and 260 clear of
-- anything already built.
local ORIGIN_X, ORIGIN_Z = 1000, 3500
local ROW_GAP = 240

--------------------------------------------------------------------------------

return L.runPhase("KitYard", function(folder)
	-- The real surface by raycast, excluding everything the generator built, so a model does not land on
	-- the roof of a neighbour or on a tree canopy.
	local probe = RaycastParams.new()
	probe.FilterType = Enum.RaycastFilterType.Exclude
	probe.FilterDescendantsInstances = { L.root() }

	local function groundAt(x, z)
		local hit = workspace:Raycast(Vector3.new(x, 1200, z), Vector3.new(0, -2000, 0), probe)
		return hit and hit.Position.Y or L.heightAt(x, z)
	end

	local placed, missing = 0, {}
	local z = ORIGIN_Z

	for _, group in ipairs(GROUPS) do
		local x = ORIGIN_X
		local tallest = 0

		for _, name in ipairs(group.names) do
			local y = groundAt(x, z)
			local m = K.place(name, folder, CFrame.new(x, y, z))
			if m then
				-- K.place pivots on a Root part at the model's BASE, so the pivot lands the model on the
				-- ground rather than half-buried -- but only if the builder put its geometry above y=0,
				-- which the kit's convention requires. Measured here rather than assumed: anything sitting
				-- below the ground gets lifted.
				local cf, size = m:GetBoundingBox()
				local bottom = cf.Position.Y - size.Y / 2
				if bottom < y - 0.5 then
					m:PivotTo(m:GetPivot() * CFrame.new(0, y - bottom, 0))
				end
				m:SetAttribute("KitYard", true)
				placed += 1
				tallest = math.max(tallest, size.Z)
				x += math.max(group.gap, size.X + 40)
			else
				table.insert(missing, name)
				x += group.gap
			end
		end

		z += math.max(ROW_GAP, tallest + 80)
	end

	if #missing > 0 then
		L.progress("no builder for: " .. table.concat(missing, ", "))
	end
	print(("[WOLD] KitYard: %d models at (%d, %d), %d missing")
		:format(placed, ORIGIN_X, ORIGIN_Z, #missing))
end)
