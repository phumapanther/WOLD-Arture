-- 61_settle_scatter: sit every hand-placed tree, bush and rock down onto the ground.
--
-- The user scattered a great many of these by hand, and a lot of them ended up hovering -- dragging in a
-- viewport puts a model where the CURSOR is, not where the ground is, and on a slope the two are rarely the
-- same. Checking thousands by eye is not work a person should do.
--
-- What this does NOT do is move anything sideways, rotate it, or change its scale. The arrangement is the
-- user's design; only the height is touched, and only when it is wrong.
--
-- Run with:  node tools/run-luau.js mapgen/61_settle_scatter.lua

--------------------------------------------------------------------------------

-- How far a model may hover before it counts as floating. Half a stud of daylight under a rock is invisible
-- on a slope; two studs is a rock hanging in the air.
local FLOAT_TOLERANCE = 1.5

-- How deep to bury the base. A tree whose base exactly touches the ground shows a seam wherever the terrain
-- is not perfectly flat under it, so everything sinks a little.
local SINK = 0.4

-- ...but a model that is ALREADY buried deeper than this is left alone. Half-sunk boulders and tree stumps
-- are a deliberate look, and hauling them up to sit neatly on the surface would undo that.
local SUNK_TOLERANCE = 3.0

-- What counts as scatter. Matched on the model's name, which is how the Creator Store assets and the
-- generator's own props are both named.
local SCATTER_WORDS = {
	"tree", "oak", "pine", "birch", "willow", "palm", "trunk", "log",
	"bush", "shrub", "fern", "grass", "flower", "plant",
	"rock", "stone", "boulder", "pebble", "cliff",
}

local function isScatter(name)
	local lower = name:lower()
	for _, word in ipairs(SCATTER_WORDS) do
		if lower:find(word, 1, true) then return true end
	end
	return false
end

--------------------------------------------------------------------------------

return L.runPhase("SettleScatter", function(folder)
	folder:SetAttribute("EditsOnly", true)

	-- Collected first, then moved. Walking the tree while changing it is how you end up skipping half of
	-- what you meant to visit.
	local jobs = {}
	for _, top in ipairs(L.root():GetChildren()) do
		-- The backup folder is a copy of things that already exist elsewhere; settling it would be wasted
		-- work on models nobody sees.
		if top.Name ~= "Backup" and top ~= folder then
			for _, inst in ipairs(top:GetDescendants()) do
				-- PrimaryPart is NOT required. Models imported from the Creator Store usually have none,
				-- and an earlier version of this filter tested for it -- which silently skipped every tree
				-- in the world and reported that there was nothing to do.
				--
				-- A whole tree is one Model containing its trunk and canopy meshes, so only the top-level
				-- Model is settled: walking into it as well would try to settle the canopy separately and
				-- tear the tree apart.
				if inst:IsA("Model") and isScatter(inst.Name)
					and not (inst.Parent and inst.Parent:IsA("Model")) then
					table.insert(jobs, inst)
				end
			end
		end
	end

	L.progress(("SettleScatter: %d scatter models to check"):format(#jobs))

	-- The ground means TERRAIN, and nothing else.
	--
	-- Casting from above and taking the first hit was measured wrong on 220 of 305 sampled models: it
	-- struck the invisible Zone_Elderwood volume that covers the whole forest and called y=269 the floor,
	-- and it struck neighbouring canopies -- so trees were "settled" onto other trees' leaves.
	--
	-- Only Terrain is accepted as a floor, which also means a tree standing against a wall is measured
	-- against the hillside rather than the wall.
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { workspace.Terrain }
	params.IgnoreWater = true

	local moved, alreadyOk, buried, noGround = 0, 0, 0, 0
	local biggest = 0

	for i, inst in ipairs(jobs) do
		local box, size = inst:GetBoundingBox()
		local base = box.Position.Y - size.Y / 2

		-- Cast from a little ABOVE the base, not from high overhead.
		--
		-- High overhead is what found the zone volumes and the canopies. Starting just above the base finds
		-- the hillside this model is standing over -- and the small lift is what lets a model that is
		-- already slightly sunk still see the surface it should be resting on.
		local hit = workspace:Raycast(
			Vector3.new(box.Position.X, base + 4, box.Position.Z),
			Vector3.new(0, -12000, 0), params)

		if not hit then
			noGround += 1
		else
			local gap = base - hit.Position.Y
			if gap > FLOAT_TOLERANCE then
				local wanted = hit.Position.Y - SINK
				inst:PivotTo(inst:GetPivot() + Vector3.new(0, wanted - base, 0))
				moved += 1
				biggest = math.max(biggest, gap)
			elseif gap < -SUNK_TOLERANCE then
				buried += 1
			else
				alreadyOk += 1
			end
		end

		-- Yielding keeps Studio responsive; without it a job this size locks the window for a minute.
		if i % 300 == 0 then
			L.progress(("settling %d/%d"):format(i, #jobs))
			task.wait()
		end
	end

	print(("[WOLD] SettleScatter: %d dropped (worst was %.0f studs up), %d already sitting, %d left buried")
		:format(moved, biggest, alreadyOk, buried))
	if noGround > 0 then
		-- Not an error, and not fixable by dropping: there is no terrain beneath these at all. They are out
		-- past the shoreline or off the edge of the map, mostly left over from an earlier scatter pass, and
		-- moving them down would only send them further into the void.
		print(("[WOLD] SettleScatter: %d models have no terrain under them and were left alone -- they are off the land, not merely hovering")
			:format(noGround))
	end
end)
