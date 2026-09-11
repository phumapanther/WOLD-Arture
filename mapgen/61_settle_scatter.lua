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

-- How deep to bury the model.
--
-- Just enough to touch, not a third of the way in. Sinking by a third was tried and previewed first: on a
-- 54-stud pine that is eighteen studs of tree underground, and the preview put the average sink at 5.7
-- studs across thirteen thousand models -- which would have planted the forest rather than settled it.
--
-- What actually stops the daylight is not depth but measuring the ground across the model's whole
-- FOOTPRINT (below) instead of at one point. With that fixed, a small bite is all that is needed: enough to
-- hide the seam where a flat-bottomed mesh meets tilted terrain.
--
-- Scaled a little by size, because a boulder needs a deeper bite than a fern to hide the same tilt, and
-- capped at both ends so nothing disappears and nothing merely kisses the surface.
local SINK_FRACTION = 0.06
local SINK_MIN = 0.4
local SINK_MAX = 2.0

-- How much deeper than intended a model may be before it is left alone.
--
-- Measured against the sink the model is SUPPOSED to have rather than a flat number of studs: now that a
-- tree sinks by a third of its own height, a fixed threshold of three studs would class every correctly
-- planted tree as "already buried" and skip it. Half-sunk boulders and stumps -- genuinely deeper than the
-- rule wants -- still get left where they are.
local EXTRA_SUNK_ALLOWED = 4.0

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

-- Ground-standing props that are not scatter: a well belongs on the ground exactly as a boulder does.
--
-- Buildings are deliberately NOT in this list. Their placement is the user's arrangement, and a hall built
-- to sit on a levelled pad would be dragged down onto the hillside beneath it.
local PROP_WORDS = { "well", "fence", "signpost", "crate", "barrel", "cart", "bench", "lantern" }

local function isProp(name)
	local lower = name:lower()
	for _, word in ipairs(PROP_WORDS) do
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
				if inst:IsA("Model") and (isScatter(inst.Name) or isProp(inst.Name))
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

		-- The ground is sampled across the model's FOOTPRINT, not at its centre alone.
		--
		-- One reading at the centre is what left trees hovering on rough ground: the centre can sit over a
		-- dip while the model straddles a rise a few studs away, and a model settled to the dip hangs over
		-- the rise. Taking the HIGHEST terrain under the footprint plants it against the highest thing it
		-- covers, which is what stops the daylight.
		local cx, cz = box.Position.X, box.Position.Z
		local rx, rz = size.X * 0.35, size.Z * 0.35
		local from = base + size.Y + 4

		local highest = nil
		for _, o in ipairs({ { 0, 0 }, { rx, 0 }, { -rx, 0 }, { 0, rz }, { 0, -rz },
			{ rx, rz }, { -rx, -rz }, { rx, -rz }, { -rx, rz } }) do
			local hit = workspace:Raycast(
				Vector3.new(cx + o[1], from, cz + o[2]), Vector3.new(0, -12000, 0), params)
			if hit and (not highest or hit.Position.Y > highest) then
				highest = hit.Position.Y
			end
		end

		-- Is it standing on something BUILT? Then it is where it belongs, however high that is.
		--
		-- Fifty-one cone roofs sit on parapets, a tower sits on a deck, a gear hangs off an awning. Judged
		-- against the terrain alone every one of them "floats" -- one by 43 studs -- and dropping them to
		-- the ground would dismantle the castle. A short ray straight down finds whatever is carrying it.
		local carried = false
		do
			local solid = RaycastParams.new()
			solid.FilterType = Enum.RaycastFilterType.Exclude
			solid.FilterDescendantsInstances = { inst }
			local under = workspace:Raycast(
				Vector3.new(cx, base - 0.2, cz), Vector3.new(0, -60, 0), solid)
			carried = under ~= nil and under.Instance ~= workspace.Terrain
		end

		if carried then
			alreadyOk += 1
		elseif not highest then
			noGround += 1
		else
			local sink = math.clamp(size.Y * SINK_FRACTION, SINK_MIN, SINK_MAX)
			-- Where the base SHOULD end up, and how far it is from there. Positive means it is hanging
			-- above where it belongs; negative means it is deeper than the rule intends.
			local wanted = highest - sink
			local off = base - wanted

			if off > FLOAT_TOLERANCE then
				inst:PivotTo(inst:GetPivot() + Vector3.new(0, wanted - base, 0))
				moved += 1
				biggest = math.max(biggest, base - highest)
			elseif off < -EXTRA_SUNK_ALLOWED then
				buried += 1
			else
				alreadyOk += 1
			end
		end

		-- Yield often. Each model costs NINE raycasts now rather than one, so the same 300-model stride that
		-- was comfortable before became a quarter of a million rays between breaths -- which locked Studio
		-- hard enough that the run had to be abandoned halfway.
		if i % 60 == 0 then
			if i % 3000 == 0 then L.progress(("settling %d/%d"):format(i, #jobs)) end
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
