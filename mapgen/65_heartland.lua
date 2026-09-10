-- 65_heartland: the country between Goldmeadow, Ironcrest Keep and Brasshaven.
--
-- SCATTER ONLY. The user asked for trees, rocks and bushes on the ground as it already is -- no reshaping,
-- no lakes, no terracing. Nothing here touches L.shapers or writes a terrain height, and the only voxels it
-- writes are the patches of bare ground described below.
--
-- The land stays what it is: open downland with rolling hills. What changes is what stands on it.
--
--   * Riverbank first, but ONE BANK AT A TIME. The thickest planting follows the water -- on whichever
--     side the river happens to favour there. Walk downstream and the wood changes banks, so you get
--     thicket on one shore looking across at open field, which is what a real river looks like.
--   * Copses, not a forest. Trees come in patches with real gaps between them, which is what makes open
--     country read as open rather than as a thin wood.
--   * Bare ground here and there. Not everything is grass: worn earth on the hilltops where the wind gets
--     at it, and gravel along the water.
--
-- L, and the layout, are concatenated in ahead of this file by tools/run-luau.js -- not required.

--------------------------------------------------------------------------------
-- Where
--------------------------------------------------------------------------------

-- The three anchors, in world studs. Read from the layout so moving a settlement moves the countryside
-- with it rather than leaving the trees behind.
local function anchors()
	local bx, bz = L.placePos("Brasshaven")
	local kx, kz = L.placePos("Ironcrest Keep")
	local gx, gz = L.placePos("Goldmeadow")
	return { { bx, bz }, { kx, kz }, { gx, gz } }
end

-- How wide a belt of countryside to dress, either side of the line joining the three places.
local CORRIDOR = 900
-- The bounding box swept for planting. Generous enough to cover the corridor at its widest.
local BAND = { x0 = -2000, x1 = 3200, z0 = 400, z1 = 4400 }

-- Distance from a point to the corridor's spine: the polyline through the three settlements.
local function toSpine(x, z)
	local pts = anchors()
	local best = math.huge
	for i = 1, #pts - 1 do
		local ax, az = pts[i][1], pts[i][2]
		local bx, bz = pts[i + 1][1], pts[i + 1][2]
		local dx, dz = bx - ax, bz - az
		local len2 = dx * dx + dz * dz
		local t = len2 > 0 and math.clamp(((x - ax) * dx + (z - az) * dz) / len2, 0, 1) or 0
		local px, pz = ax + dx * t, az + dz * t
		best = math.min(best, math.sqrt((x - px) ^ 2 + (z - pz) ^ 2))
	end
	return best
end

-- 1 on the spine, fading to 0 at the corridor's edge. Everything below is scaled by this, so the
-- countryside thins out naturally instead of stopping at a line.
local function corridorWeight(x, z)
	local d = toSpine(x, z)
	if d >= CORRIDOR then return 0 end
	-- FULL strength across the inner two thirds, falling away only near the rim.
	--
	-- The first version faded from the spine outward, which multiplied every other weight down almost
	-- everywhere -- 221 trees across the whole corridor, because a copse at half corridor weight is half
	-- a copse. The corridor decides WHERE the countryside is dressed, not how thickly.
	local inner = CORRIDOR * 0.65
	if d <= inner then return 1 end
	return 1 - L.smooth((d - inner) / (CORRIDOR - inner))
end

-- Keep clear of the places themselves. A settlement's own phase owns what stands in it, and scattering
-- oaks through the market square would undo the level design.
local KEEP_CLEAR = { { "Brasshaven", 620 }, { "Ironcrest Keep", 420 }, { "Goldmeadow", 380 } }

local function nearSettlement(x, z)
	for _, entry in ipairs(KEEP_CLEAR) do
		local px, pz = L.placePos(entry[1])
		local d = math.sqrt((x - px) ^ 2 + (z - pz) ^ 2)
		if d < entry[2] then return 1 - L.smooth(d / entry[2]) end
	end
	return 0
end

--------------------------------------------------------------------------------
-- How thick
--------------------------------------------------------------------------------

-- Copses. One slow noise field decides where the trees clump, so the country has thickets and clearings
-- rather than an even dusting -- which is the single strongest tell that a landscape was generated.
--
-- Thresholded rather than used directly: below COPSE_FLOOR nothing grows at all, which is what produces
-- genuine open ground between the patches instead of everywhere being a little bit wooded.
--
-- MEASURED against L.fbm's real output over this corridor, not assumed. The values run 0.254 to 0.748
-- with a median of 0.500 -- a narrow band, nothing like the 0..1 spread the name suggests. That matters:
--
--   0.52 -> 45% of the land wooded (a thin forest, not downland)
--   0.60 ->  9% wooded (islands of trees in open field -- what was asked for)
--   0.72 ->  0.1% wooded (the whole corridor came out empty: 61 trees in total)
--
-- The 0.72 attempt came from guessing the distribution instead of sampling it, and produced a bare map.
local COPSE_FLOOR = 0.60

local function copseWeight(x, z)
	local n = L.fbm(x / L.HALF * 70, z / L.HALF * 70, 8821)
	if n <= COPSE_FLOOR then return 0 end
	return (n - COPSE_FLOOR) / (1 - COPSE_FLOOR)
end

-- The riverbank -- but ONLY ONE BANK AT A TIME.
--
-- A river with matching banks reads as generated: real ones are wooded on one side and open on the other,
-- and which side that is changes as you walk downstream. So the bank weight answers three questions --
-- how close to the water, WHICH SIDE, and how far along -- and only rewards the side the river happens to
-- favour at that point.
-- Narrow. The wooded bank should be a ribbon along the water, not a belt 300 studs across -- at 150 the
-- two banks together took up more ground than the copses did.
local RIVERBANK = 90

-- Which side of the river's line a point falls on, and how far along the river it is.
-- Returns nil when the point is not near the main river at all.
local function riverSide(x, z)
	local river = L.rivers and L.rivers[1]
	if not river then return nil end
	local u, v = x / L.HALF, z / L.HALF
	local pts = river.pts

	-- The nearest segment, and the cross product against it: positive on one side, negative on the other.
	local best, bestCross, bestT, acc = math.huge, 0, 0, 0
	for i = 1, #pts - 1 do
		local a, b = pts[i], pts[i + 1]
		local abx, abz = b[1] - a[1], b[2] - a[2]
		local len2 = abx * abx + abz * abz
		local t = len2 > 0 and math.clamp(((u - a[1]) * abx + (v - a[2]) * abz) / len2, 0, 1) or 0
		local px, pz = a[1] + abx * t, a[2] + abz * t
		local d = math.sqrt((u - px) ^ 2 + (v - pz) ^ 2)
		if d < best then
			best = d
			-- Sign of the 2D cross product of the segment against the point: the side of the line.
			bestCross = abx * (v - a[2]) - abz * (u - a[1])
			local segLen = math.sqrt(len2)
			bestT = (acc + segLen * t) / math.max(river.total, 1e-6)
		end
		acc += math.sqrt(len2)
	end
	return (bestCross >= 0) and 1 or -1, bestT
end

local function riverWeight(x, z)
	local d = select(1, L.riverAt(x, z))
	if not d or d >= RIVERBANK then return 0 end
	local near = 1 - L.smooth(d / RIVERBANK)

	local side, along = riverSide(x, z)
	if not side then return near * 0.3 end

	-- Which bank is the wooded one, as a slow wave down the length of the river. It swaps every few
	-- hundred studs, so a walk downstream passes wood on the left, then open ground, then wood on the
	-- right -- rather than one side being green for the whole map.
	local favour = math.sin(along * math.pi * 3.4 + 0.7)
	local wooded = (favour >= 0) and 1 or -1

	if side == wooded then
		return near
	end
	-- The far bank is not bare -- a handful of trees still stand there -- but it reads as open field
	-- against the thicket opposite.
	return near * 0.12
end

--------------------------------------------------------------------------------

return L.runPhase("Heartland", function(folder)
	local CollectionService = game:GetService("CollectionService")
	local Terrain = workspace.Terrain

	-- The real surface, by raycast. L.heightAt reports where the terrain was ASKED to go, not where the
	-- voxels landed -- and a ray must ignore everything the generator built, or one dropped beside a tree
	-- finds the neighbouring canopy and calls it the ground.
	local probe = RaycastParams.new()
	probe.FilterType = Enum.RaycastFilterType.Exclude
	probe.FilterDescendantsInstances = { L.root() }

	local function groundAt(x, z)
		local hit = workspace:Raycast(Vector3.new(x, 900, z), Vector3.new(0, -1400, 0), probe)
		if not hit then return nil end
		return hit.Position.Y, hit.Material
	end

	-- Sits a model so a fixed FRACTION of its height is under the surface, correcting in both directions.
	-- A flat stud is wrong for models this varied: it swallowed a 1-stud pebble whole and left an oak
	-- hovering three studs up when this project last tried it.
	local function settle(model)
		if not model then return nil end
		-- Model:GetBoundingBox is the measurement that matches what the eye sees; measuring part by part
		-- puts a MeshPart's base below its visible geometry.
		local box, size = model:GetBoundingBox()
		if size.Y <= 0 then return model end
		local low = box.Position.Y - size.Y / 2
		local allowed = math.min(1.0, size.Y * 0.08)
		local groundY = groundAt(box.Position.X, box.Position.Z)
		if not groundY then return model end
		local shift = (groundY - allowed) - low
		if math.abs(shift) > 0.05 then
			model:PivotTo(model:GetPivot() + Vector3.new(0, shift, 0))
		end
		return model
	end

	local nodes = Instance.new("Folder")
	nodes.Name = "Nodes"
	nodes.Parent = folder
	local decor = Instance.new("Folder")
	decor.Name = "Decor"
	decor.Parent = folder

	----------------------------------------------------------------------------
	-- 1. Bare ground
	----------------------------------------------------------------------------

	-- Patches where the grass gives way, as asked. Two kinds, each in the place it belongs: worn earth on
	-- the high ground where the wind gets at it, and gravel along the water.
	--
	-- Written with FillBall rather than through a height shaper, because the ground itself must not move
	-- -- the user was explicit that the geography stays as it is.
	L.progress("Heartland: bare ground")
	-- Fewer and larger than the first pass, which scattered 260 small dark blots that read as stains on
	-- the grass rather than as worn ground.
	local patches = 0
	for _ = 1, 30 do
		local x = BAND.x0 + math.random() * (BAND.x1 - BAND.x0)
		local z = BAND.z0 + math.random() * (BAND.z1 - BAND.z0)
		local w = corridorWeight(x, z)
		if w > 0.15 and nearSettlement(x, z) < 0.3 and L.isLand(x, z) then
			local y, material = groundAt(x, z)
			if y and material ~= Enum.Material.Water and material ~= Enum.Material.Sand then
				local river = riverWeight(x, z)
				-- Gravel by the water, worn ground up on the slopes. The noise decides which parts of the
				-- open country wear through, so the patches sit where the copses are not.
				-- Ground either way. Slate read as dark round blots on the grass -- a stain rather than
				-- worn earth -- because a hard grey circle on green has no edge to soften it. Ground is
				-- close enough in tone to look like bare soil showing through.
				local mat = Enum.Material.Ground
				local radius = 26 + math.random() * 44
				-- A shallow ball centred just below the surface paints the top without moving it: a
				-- sphere that big is nearly flat where it crosses the ground.
				Terrain:FillBall(Vector3.new(x, y - radius + 2.5, z), radius, mat)
				patches += 1
			end
		end
		if patches % 40 == 0 then task.wait() end
	end

	----------------------------------------------------------------------------
	-- 2. Trees and rocks
	----------------------------------------------------------------------------

	L.progress("Heartland: planting")
	local SPACING = 34
	local trees, rocks, bushes = 0, 0, 0

	for x = BAND.x0, BAND.x1, SPACING do
		for z = BAND.z0, BAND.z1, SPACING do
			local w = corridorWeight(x, z)
			if w > 0.02 then
				local jx = x + (math.random() - 0.5) * SPACING * 0.9
				local jz = z + (math.random() - 0.5) * SPACING * 0.9

				-- Two reasons for a tree to be here: it is in a copse, or it is on the riverbank. The
				-- bank wins where they overlap, which is what makes the water's edge the greenest line
				-- in otherwise open country.
				local river = riverWeight(jx, jz)
				local copse = copseWeight(jx, jz)
				-- The bank is the dense place; a copse is thinner even at its middle, so you can see
				-- through one rather than being walled in by it.
				-- A copse is thick where it exists, because there are few of them. The bank is denser
				-- still. Both are scaled hard by the corridor weight, so this is a ribbon of dressed
				-- country through open downland rather than a blanket.
				local density = math.max(river * 0.85, copse * 0.75) * w
				density = density * (1 - nearSettlement(jx, jz))

				if math.random() < density and L.isLand(jx, jz) then
					local y, material = groundAt(jx, jz)
					if y and material ~= Enum.Material.Water then
						local rng = Random.new(math.floor(jx * 31 + jz * 17))
						-- More stone by the river, where a bank would be strewn with it.
						local isRock = rng:NextNumber() < (river > 0.4 and 0.34 or 0.18)

						local model
						if isRock then
							model = L.placeAsset(nodes, "rock", jx, y, jz, rng, 0.3, 0.55)
						else
							-- Oak in the open, pine on the higher and further ground.
							local kind = (y > 120 or rng:NextNumber() < 0.18) and "pine" or "oak"
							model = L.placeAsset(nodes, kind, jx, y, jz, rng, 0.8, 1.25)
						end

						if model then
							settle(model)
							model:SetAttribute("NodeKind", isRock and "Rock" or "Tree")
							CollectionService:AddTag(model, "WOLD_Node")
							if isRock then rocks += 1 else trees += 1 end
						end
					end
				end
			end
		end
		task.wait()
	end

	----------------------------------------------------------------------------
	-- 3. Undergrowth
	----------------------------------------------------------------------------

	-- Bushes fill the copses and line the water. Fewer than the forest gets: this is open country, and
	-- scrub everywhere would close it in.
	for _ = 1, 1600 do
		local x = BAND.x0 + math.random() * (BAND.x1 - BAND.x0)
		local z = BAND.z0 + math.random() * (BAND.z1 - BAND.z0)
		local w = corridorWeight(x, z)
		local here = math.max(riverWeight(x, z), copseWeight(x, z)) * w
		if here > 0.35 and nearSettlement(x, z) < 0.4 and L.isLand(x, z) then
			local y, material = groundAt(x, z)
			if y and material ~= Enum.Material.Water then
				local rng = Random.new(math.floor(x * 13 + z * 29))
				local b = L.placeAsset(decor, "bush", x, y, z, rng, 0.8, 1.8)
				if b then settle(b) bushes += 1 end
			end
		end
		if bushes % 250 == 0 then task.wait() end
	end

	print(("[WOLD] Heartland: %d trees, %d rocks, %d bushes, %d bare patches")
		:format(trees, rocks, bushes, patches))
end)
