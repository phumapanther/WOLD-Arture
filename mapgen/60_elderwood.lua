-- 60_elderwood: the forest around the lumber village, and the ground it grows on.
--
-- Two halves. First the TERRAIN is reshaped -- hillocks, ledges, a few cliffs and a sandy hollow -- and the
-- voxels rewritten. Then the trees and rocks are scattered onto whatever that produced.
--
-- Order matters and cost a rebuild to learn elsewhere: trees planted before the ground moves end up buried
-- or floating, so nothing is placed until the terrain is final.
--
-- L, and the layout, are concatenated in ahead of this file by tools/run-luau.js -- not required.

--------------------------------------------------------------------------------
-- Shape
--------------------------------------------------------------------------------

local RADIUS = 1500 -- how far the forest reaches from the village
local CORE = 700 -- inside this, the ground is broken up; outside it flattens toward the plain

-- The user asked for broken ground CONCENTRATED IN THE MIDDLE and mostly flat around the edges, with a few
-- cliffs. That is one weight -- how "forest-like" a point is -- driving every rule below, so the whole
-- region reads as one place rather than three effects layered on top of each other.
local function coreWeight(x, z)
	local cx, cz = L.placePos("Elderwood")
	local d = math.sqrt((x - cx) ^ 2 + (z - cz) ^ 2)
	if d >= RADIUS then return 0 end
	if d <= CORE then return 1 end
	return 1 - L.smooth((d - CORE) / (RADIUS - CORE))
end

-- The sandy hollow: a small desert in the woods, deliberately off-centre so it is something you FIND rather
-- than something you spawn next to.
local DESERT_OFFSET = { 520, -380 }
local DESERT_RADIUS = 260

local function desertWeight(x, z)
	local cx, cz = L.placePos("Elderwood")
	local dx = x - (cx + DESERT_OFFSET[1])
	local dz = z - (cz + DESERT_OFFSET[2])
	local d = math.sqrt(dx * dx + dz * dz)
	if d >= DESERT_RADIUS then return 0 end
	return 1 - L.smooth(d / DESERT_RADIUS)
end

-- The height shaper. Runs for every terrain column in the region and returns a new height, or nil to leave
-- it alone -- which is what it does everywhere outside the forest.
local function shapeForest(x, z, h, fm, land)
	if land <= 0.5 then return nil end -- never reshape water or seabed
	local w = coreWeight(x, z)
	if w <= 0.001 then return nil end

	local u, v = x / L.HALF, z / L.HALF

	-- Rolling hillocks: low-frequency noise, strongest in the middle. This is the "พื้นต่างระดับ" -- ground
	-- that is never quite level, so walking through the wood is always a small climb or descent.
	local rolling = (L.fbm(u * 26, v * 26, 7701) - 0.5) * 2 -- roughly -1..1
	local height = rolling * 34 * w

	-- Terraces: the ground steps rather than ramping, which is what makes a slope read as LEDGES you can
	-- stand on instead of a smooth hill. Only in the core, and only where the roll is already going up.
	local stepped = math.floor((h + height) / 7) * 7
	local terrace = w * w -- squared, so terracing fades out faster than the hills themselves
	local shaped = (h + height) * (1 - terrace) + stepped * terrace

	-- A handful of genuine cliffs around the rim, where the user asked for them. Sharp, local, and rare:
	-- a second noise field thresholded high, so most of the rim stays walkable.
	local rim = 1 - w -- strongest at the edge of the forest
	local cliffNoise = L.fbm(u * 55, v * 55, 3313)
	if rim > 0.35 and cliffNoise > 0.74 then
		shaped = shaped + (cliffNoise - 0.74) * 240 * rim
	end

	-- The desert hollow: scooped out and flattened, so it sits BELOW the wood around it and reads as a
	-- clearing rather than a sandy hill.
	local dw = desertWeight(x, z)
	if dw > 0 then
		local floor = h - 16
		shaped = shaped * (1 - dw) + floor * dw
	end

	-- Three returns: height, forest density, and a forced material.
	--
	-- Density alone could not make sand: materialFor only lays Sand near sea level, and this hollow sits
	-- around y=61 -- measured Grass all the way through it on the first run. So the hollow names Sand
	-- outright, and drops the density so the leafy ground cover stops at its edge.
	if dw > 0.25 then
		return shaped, 0, Enum.Material.Sand
	end
	return shaped, dw > 0.1 and 0 or nil
end

--------------------------------------------------------------------------------

return L.runPhase("Elderwood", function(folder)
	local cx, cz = L.placePos("Elderwood")
	local CollectionService = game:GetService("CollectionService")

	----------------------------------------------------------------------------
	-- 1. The ground
	----------------------------------------------------------------------------

	L.shapers = { shapeForest }
	L.progress("Elderwood: rewriting terrain")
	local chunks = L.writeArea(cx, cz, RADIUS + 200, function(i, n)
		L.progress(("Elderwood terrain %d/%d"):format(i, n))
	end)
	L.progress(("Elderwood terrain done (%d chunks)"):format(chunks))

	----------------------------------------------------------------------------
	-- 2. What grows on it
	----------------------------------------------------------------------------

	-- The REAL surface, by raycast rather than by asking L.heightAt: voxel terrain snaps to its own grid
	-- and lands somewhere else, which buried an entire town's worth of parts once already.
	local probe = RaycastParams.new()
	probe.FilterType = Enum.RaycastFilterType.Exclude
	probe.FilterDescendantsInstances = { folder }

	local function groundAt(x, z)
		local hit = workspace:Raycast(Vector3.new(x, 900, z), Vector3.new(0, -1400, 0), probe)
		if not hit then return nil end
		return hit.Position.Y, hit.Material
	end

	-- Sits a model so a fixed FRACTION of its height is under the surface, correcting in both directions.
	-- A flat stud is wrong for models this varied: it swallowed a 1-stud pebble whole and left a
	-- mismeasured oak hovering three studs up.
	local MAX_SUNK_FRACTION = 0.08
	local MAX_SUNK_STUDS = 1.0

	local function settle(model)
		if not model then return nil end
		-- Model:GetBoundingBox is the measurement that matches what the eye sees. Measuring part by part
		-- puts a MeshPart's "base" below its visible geometry, because the mesh does not fill its box.
		local box, size = model:GetBoundingBox()
		if size.Y <= 0 then return model end
		local low = box.Position.Y - size.Y / 2
		local allowed = math.min(MAX_SUNK_STUDS, size.Y * MAX_SUNK_FRACTION)
		local groundY = groundAt(box.Position.X, box.Position.Z)
		if not groundY then return model end
		local shift = (groundY - allowed) - low
		if math.abs(shift) > 0.05 then
			model:PivotTo(model:GetPivot() + Vector3.new(0, shift, 0))
		end
		return model
	end

	-- Autumn colours, as asked. Applied to a clone's leaves after placing, so one set of prototypes can
	-- produce a mixed wood rather than needing a separate model per colour.
	--
	-- Recoloured by SIZE rather than by name: these prototypes name their parts inconsistently, but the
	-- crown is always far wider than the trunk, so "much wider than it is central" identifies foliage
	-- reliably where a name match would miss half of them.
	local AUTUMN = {
		Color3.fromRGB(198, 96, 40),   -- orange
		Color3.fromRGB(168, 54, 42),   -- red
		Color3.fromRGB(140, 92, 44),   -- brown
		Color3.fromRGB(206, 142, 48),  -- amber
	}

	local function tint(model, colour)
		local _, size = model:GetBoundingBox()
		for _, d in ipairs(model:GetDescendants()) do
			if d:IsA("BasePart") then
				-- Foliage is the wide stuff; a trunk is narrow. Half the model's own width is the line.
				local widest = math.max(d.Size.X, d.Size.Z)
				if widest > size.X * 0.35 then
					d.Color = colour
				end
			end
		end
	end

	local nodes = Instance.new("Folder")
	nodes.Name = "Nodes"
	nodes.Parent = folder
	local decor = Instance.new("Folder")
	decor.Name = "Decor"
	decor.Parent = folder

	-- Density. The user asked for a THICK wood -- trees close enough to touch in places -- so the grid is
	-- tight and most cells fill. Thinning still happens toward the rim, which is what keeps the forest an
	-- edged place rather than a rectangle of trees.
	local SPACING = 22
	local planted, rocks, tinted = 0, 0, 0

	for x = cx - RADIUS, cx + RADIUS, SPACING do
		for z = cz - RADIUS, cz + RADIUS, SPACING do
			local w = coreWeight(x, z)
			if w > 0.02 then
				-- Jittered off the grid, or the wood reads as an orchard.
				local jx = x + (math.random() - 0.5) * SPACING * 0.9
				local jz = z + (math.random() - 0.5) * SPACING * 0.9
				local dw = desertWeight(jx, jz)

				-- Thicker toward the middle, and the sand stays bare.
				--
				-- Clumped rather than evenly spread: a second slow noise field decides where the wood is
				-- thickest, so there are genuine thickets and genuine clearings instead of one uniform
				-- scatter. Evenly-spaced trees are the strongest tell that a forest was generated.
				local clump = L.fbm(jx / L.HALF * 90, jz / L.HALF * 90, 4421)
				local chance = w * (0.45 + clump * 0.85) * (1 - dw)
				if math.random() < chance and L.isLand(jx, jz) then
					local y, material = groundAt(jx, jz)
					if y and material ~= Enum.Material.Water then
						local rng = Random.new(math.floor(jx * 31 + jz * 17))
						local isRock = rng:NextNumber() < 0.22

						local model
						if isRock then
							model = L.placeAsset(nodes, "rock", jx, y, jz, rng, 0.35, 0.6)
						else
							local kind = rng:NextNumber() < 0.8 and "oak" or "pine"
							model = L.placeAsset(nodes, kind, jx, y, jz, rng, 0.85, 1.3)
							-- Roughly a third of the wood turns. Pines are left green: a red conifer
							-- reads as broken rather than as autumn.
							if kind == "oak" and rng:NextNumber() < 0.38 then
								tint(model, AUTUMN[rng:NextInteger(1, #AUTUMN)])
								tinted += 1
							end
						end

						if model then
							settle(model)
							model:SetAttribute("NodeKind", isRock and "Rock" or "Tree")
							CollectionService:AddTag(model, "WOLD_Node")
							if isRock then rocks += 1 else planted += 1 end
						end
					end
				end
			end
		end
	end

	-- Undergrowth. Purely decorative, thickest where the trees are, and a lot of it: the difference
	-- between a wood you look at and a wood you are IN is what fills the space between the trunks.
	local bushes = 0
	for _ = 1, 1400 do
		local a = math.random() * math.pi * 2
		local r = math.sqrt(math.random()) * RADIUS
		local x, z = cx + math.cos(a) * r, cz + math.sin(a) * r
		if L.isLand(x, z) and coreWeight(x, z) > 0.15 and desertWeight(x, z) < 0.2 then
			local y, material = groundAt(x, z)
			if y and material ~= Enum.Material.Water then
				local rng = Random.new(math.floor(x * 13 + z * 29))
				-- A wide scale range rather than one size: the prototypes run from 3 to 24 studs tall, so
				-- letting them vary this much gives everything from ankle scrub to a bush taller than a
				-- player -- which is what the user asked for by "พุ่มใหญ่ๆ".
				local b = L.placeAsset(decor, "bush", x, y, z, rng, 0.9, 2.4)
				if b then settle(b) bushes += 1 end
			end
		end
	end

	-- Cleared so no later phase inherits the forest's shaper and reshapes ground it knows nothing about.
	L.shapers = {}

	print(("[WOLD] Elderwood: %d trees (%d autumn), %d rocks, %d bushes over %d chunks")
		:format(planted, tinted, rocks, bushes, chunks))
end)
