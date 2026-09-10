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

-- The forest is the whole DARK GREEN BAND, not a circle around the village.
--
-- layout.forest defines it: everything west of x = -0.25 and within |z| < 0.45, which L.base turns into the
-- leafy ground cover. Measured 4000 x 6250 studs, reaching 4085 studs from the village -- so the first
-- version's 1500-stud circle covered barely a third of it and left most of the band bare.
--
-- Rather than restate those numbers, `forestWeight` asks L.base for the density it already computed. The
-- wood and the ground it grows on then agree by construction.
local FOREST_MIN = 0.35 -- below this the band is only thinly wooded; treat it as the edge

local function forestWeight(x, z)
	local _, fm = L.base(x / L.HALF, z / L.HALF)
	if not fm or fm <= FOREST_MIN then return 0 end
	return math.min(1, (fm - FOREST_MIN) / (1 - FOREST_MIN))
end

-- Where the phase writes terrain. The whole band, in world studs.
local BAND = { x0 = -6600, x1 = -2000, z0 = -3700, z1 = 3500 }

--------------------------------------------------------------------------------
-- Water and sand
--------------------------------------------------------------------------------

-- Two lakes and two sandy places, each with its own character, as asked:
--   * lake 1 sits in DEEP wood, ringed by trees right to the shore
--   * lake 2 sits in the open, with a clearing around it
--   * one desert is wrapped by thick forest, the other has open ground around it
local FEATURES = {
	{ kind = "lake",   x = -4300, z = -900,  radius = 300, depth = 26, clearing = 0 },
	{ kind = "lake",   x = -3300, z = 1500,  radius = 340, depth = 22, clearing = 620 },
	{ kind = "desert", x = -3480, z = -220,  radius = 260, depth = 16, clearing = 0 },
	{ kind = "desert", x = -5200, z = 1100,  radius = 300, depth = 14, clearing = 700 },
}

-- How strongly a feature claims this point: 1 at its middle, 0 at its rim.
local function featureWeight(f, x, z)
	local d = math.sqrt((x - f.x) ^ 2 + (z - f.z) ^ 2)
	if d >= f.radius then return 0 end
	return 1 - L.smooth(d / f.radius)
end

-- How much a feature keeps trees away. Nothing grows IN a lake or on its sand, and a feature with a
-- `clearing` also thins the wood for some distance around it -- which is what makes one lake feel hidden
-- in the trees and the other feel like open country.
local function clearingWeight(x, z)
	local worst = 0
	for _, f in ipairs(FEATURES) do
		local d = math.sqrt((x - f.x) ^ 2 + (z - f.z) ^ 2)
		if d < f.radius then
			worst = math.max(worst, 1)
		elseif f.clearing > 0 and d < f.radius + f.clearing then
			worst = math.max(worst, 1 - L.smooth((d - f.radius) / f.clearing))
		end
	end
	return worst
end

-- The height shaper. Runs for every terrain column in the region and returns a new height, or nil to leave
-- it alone -- which is what it does everywhere outside the forest.
local function shapeForest(x, z, h, fm, land)
	if land <= 0.5 then return nil end -- never reshape water or seabed
	local w = forestWeight(x, z)
	if w <= 0.001 then return nil end
	-- Leave the mountains alone. The forest band overlaps their feet, and rolling and terracing a
	-- mountainside produced a smooth dome hundreds of studs tall in the middle of the wood.
	if h > 220 * L.VS then return nil end

	local u, v = x / L.HALF, z / L.HALF

	-- Rolling hillocks: low-frequency noise, strongest where the wood is thickest. This is the
	-- "พื้นต่างระดับ" -- ground that is never quite level, so walking through the wood is always a small
	-- climb or descent.
	local rolling = (L.fbm(u * 26, v * 26, 7701) - 0.5) * 2 -- roughly -1..1
	local shaped = h + rolling * 34 * w

	-- Terraces: the ground steps rather than ramping, which is what makes a slope read as LEDGES you can
	-- stand on instead of a smooth hill.
	--
	-- Applied to the OFFSET rather than to the absolute height. Snapping the absolute height to a 7-stud
	-- grid moved the ground by up to 7 studs everywhere, including under mountains, which is how the band
	-- ended up spanning 4 to 1127 studs and grew a smooth dome where the hills already were.
	local offset = shaped - h
	local stepped = math.floor(offset / 7) * 7
	local terrace = w * w -- squared, so terracing fades out faster than the hills themselves
	shaped = h + offset * (1 - terrace) + stepped * terrace

	-- A handful of genuine cliffs where the band thins out, which is its edge.
	local rim = 1 - w
	local cliffNoise = L.fbm(u * 55, v * 55, 3313)
	if rim > 0.35 and cliffNoise > 0.74 then
		shaped = shaped + (cliffNoise - 0.74) * 240 * rim
	end

	-- Lakes and hollows. Each is scooped out so it sits BELOW the wood around it -- but they are scooped
	-- to DIFFERENT shapes, and only one of them is sand.
	local forced
	for _, f in ipairs(FEATURES) do
		local fw = featureWeight(f, x, z)
		if fw > 0 then
			if f.kind == "lake" then
				-- Cut DOWN from the surrounding land, and remember how far, so the fill can put the
				-- waterline below the shore rather than above it. The first attempt filled to a height
				-- measured after the terracing had already raised the ground, so the "lake" sat 30 studs
				-- ABOVE its own banks and flooded the wood.
				shaped = shaped - f.depth * (fw ^ 0.6)
				-- NO forced material. The floor keeps whatever the wood has -- rock where it is steep,
				-- grass where it is not -- which is what makes the water read as a mountain lake rather
				-- than a puddle in a sandpit. Sanding it was the mistake: measured 23 sand columns
				-- against 18 of water, so the lakes looked like deserts with a wet middle.
			else
				local floor = h - f.depth
				shaped = shaped * (1 - fw) + floor * fw
				if fw > 0.2 then forced = Enum.Material.Sand end
			end
		end
	end

	if forced then return shaped, 0, forced end
	return shaped
end

--------------------------------------------------------------------------------

return L.runPhase("Elderwood", function(folder)
	local cx, cz = L.placePos("Elderwood")
	local CollectionService = game:GetService("CollectionService")

	----------------------------------------------------------------------------
	-- 1. The ground
	----------------------------------------------------------------------------

	L.shapers = { shapeForest }

	-- Wipe any water a PREVIOUS run left in the lake basins, before the ground is written.
	--
	-- writeChunk lays ground and never removes water, so an old lake survives a rebuild untouched and the
	-- new fill stacks on top of it -- which is why three attempts in a row measured water sitting 60 studs
	-- above its own banks no matter what the fill code did. Clearing to Air here is safe because the
	-- ground is about to be written back over the whole band; clearing it AFTER would leave holes.
	L.progress("Elderwood: clearing old water")
	for _, f in ipairs(FEATURES) do
		if f.kind == "lake" then
			workspace.Terrain:FillCylinder(CFrame.new(f.x, 400, f.z), 1400, f.radius * 2.2,
				Enum.Material.Air)
		end
	end
	task.wait(0.5)

	L.progress("Elderwood: rewriting terrain")

	-- The whole band, written chunk by chunk. writeArea takes a circle, which is the wrong shape here --
	-- the forest is a long strip down the west of the map, and a circle big enough to cover it would
	-- rewrite thousands of chunks of sea and mountain for nothing.
	local CH = L.LAYOUT.generator.terrain_chunk_studs
	local jobs = {}
	for x = math.floor(BAND.x0 / CH) * CH, BAND.x1, CH do
		for z = math.floor(BAND.z0 / CH) * CH, BAND.z1, CH do
			-- Only chunks the band actually touches. Sampling the corners and middle is enough at this
			-- size and skips the ones entirely outside it.
			local touches = false
			for _, c in ipairs({ { x, z }, { x + CH, z }, { x, z + CH }, { x + CH, z + CH },
				{ x + CH / 2, z + CH / 2 } }) do
				if forestWeight(c[1], c[2]) > 0 then touches = true break end
			end
			if touches then table.insert(jobs, { x, z }) end
		end
	end

	for i, j in ipairs(jobs) do
		L.writeChunk(j[1], j[2], CH / 4)
		if i % 4 == 0 then
			L.progress(("Elderwood terrain %d/%d"):format(i, #jobs))
			task.wait()
		end
	end
	local chunks = #jobs
	L.progress(("Elderwood terrain done (%d chunks)"):format(chunks))

	----------------------------------------------------------------------------
	-- 2. What grows on it
	----------------------------------------------------------------------------

	-- The REAL surface, by raycast rather than by asking L.heightAt: voxel terrain snaps to its own grid
	-- and lands somewhere else, which buried an entire town's worth of parts once already.
	-- Excludes THIS PHASE's own folder, so a ray dropped near a tree finds the ground rather than the
	-- neighbouring canopy. Measured a lake "floor" at y=344 against a shore at 101 -- that 344 was a
	-- treetop, and filling from it produced a 240-stud column of water standing in the wood.
	--
	-- The whole generated world is excluded, not just this folder: the town, the dummies and the caves are
	-- all things a ray could land on, and none of them is ground.
	local probe = RaycastParams.new()
	probe.FilterType = Enum.RaycastFilterType.Exclude
	probe.FilterDescendantsInstances = { L.root() }

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

	for x = BAND.x0, BAND.x1, SPACING do
		for z = BAND.z0, BAND.z1, SPACING do
			local w = forestWeight(x, z)
			if w > 0.02 then
				-- Jittered off the grid, or the wood reads as an orchard.
				local jx = x + (math.random() - 0.5) * SPACING * 0.9
				local jz = z + (math.random() - 0.5) * SPACING * 0.9

				-- Nothing grows in a lake, on its sand, or in a clearing. The user asked for bare sand
				-- specifically, and clearingWeight returns 1 inside any feature, so this covers both.
				local clear = clearingWeight(jx, jz)
				if clear < 0.98 then
					-- Clumped rather than evenly spread: a second slow noise field decides where the wood
					-- is thickest, so there are genuine thickets and genuine clearings instead of one
					-- uniform scatter. Evenly-spaced trees are the strongest tell of a generated forest.
					local clump = L.fbm(jx / L.HALF * 90, jz / L.HALF * 90, 4421)
					local chance = w * (0.45 + clump * 0.85) * (1 - clear)

					if math.random() < chance and L.isLand(jx, jz) then
						local y, material = groundAt(jx, jz)
						-- Belt and braces: never plant on water or on sand, whatever the weights said.
						if y and material ~= Enum.Material.Water and material ~= Enum.Material.Sand then
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
		task.wait()
	end

	-- Undergrowth. Purely decorative, thickest where the trees are, and a lot of it: the difference
	-- between a wood you look at and a wood you are IN is what fills the space between the trunks.
	local bushes = 0
	for _ = 1, 5000 do
		local x = BAND.x0 + math.random() * (BAND.x1 - BAND.x0)
		local z = BAND.z0 + math.random() * (BAND.z1 - BAND.z0)
		if L.isLand(x, z) and forestWeight(x, z) > 0.15 and clearingWeight(x, z) < 0.9 then
			local y, material = groundAt(x, z)
			if y and material ~= Enum.Material.Water and material ~= Enum.Material.Sand then
				local rng = Random.new(math.floor(x * 13 + z * 29))
				-- A wide scale range rather than one size: the prototypes run from 3 to 24 studs tall, so
				-- letting them vary this much gives everything from ankle scrub to a bush taller than a
				-- player.
				local b = L.placeAsset(decor, "bush", x, y, z, rng, 0.9, 2.4)
				if b then settle(b) bushes += 1 end
			end
		end
		if bushes % 250 == 0 then task.wait() end
	end

	----------------------------------------------------------------------------
	-- 3. Filling the lakes
	----------------------------------------------------------------------------

	-- The shaper scooped the basins and sanded them; the water goes in afterwards, because WriteVoxels in
	-- writeChunk only lays ground. Each lake is filled to a level just under its rim, so it reads as water
	-- sitting in a hollow rather than a blue disc painted on the floor.
	local Terrain = workspace.Terrain
	local lakes = 0
	for _, f in ipairs(FEATURES) do
		if f.kind == "lake" then
			-- The waterline, measured rather than assumed: the ground here has just been reshaped.
			--
			-- Taken from the shore rather than the rim, and a little BELOW it, so the water stops short of
			-- spilling over -- a lake filled to its rim has no bank, and every tree at the edge ends up
			-- standing in it.
			local floorY = groundAt(f.x, f.z)
			local shoreY
			for _, a in ipairs({ 0, 90, 180, 270 }) do
				local sx = f.x + math.cos(math.rad(a)) * f.radius
				local sz = f.z + math.sin(math.rad(a)) * f.radius
				local y = groundAt(sx, sz)
				if y and (not shoreY or y < shoreY) then shoreY = y end
			end
			if floorY and shoreY and shoreY > floorY + 4 then
				-- Strictly BELOW the lowest shore, so the lake keeps a bank. Filling to a fraction of the
				-- way up is not enough on sloping ground: measured a surface at 152 against banks at 122,
				-- which flooded the wood rather than making a lake.
				local surface = math.min(floorY + (shoreY - floorY) * 0.75, shoreY - 3)
				-- Filled a touch WIDER than the basin so the water meets the bank rather than leaving a
				-- dry ring, and from well below the floor so no shallow spot is missed.
				-- FillCylinder's axis runs along the CFrame's UP vector, so a cylinder built with no
				-- rotation already lies flat with its height vertical. Rotating it 90 degrees stood it on
				-- end and produced a tall column of water instead of a lake (see docs/shots/lake1.png).
				local depth = math.max(4, surface - (floorY - 6))
				Terrain:FillCylinder(
					CFrame.new(f.x, surface - depth / 2, f.z),
					depth, f.radius * 1.02, Enum.Material.Water)
				lakes += 1
			end
		end
	end

	-- Cleared so no later phase inherits the forest's shaper and reshapes ground it knows nothing about.
	L.shapers = {}

	print(("[WOLD] Elderwood: %d trees (%d autumn), %d rocks, %d bushes, %d lakes, %d chunks")
		:format(planted, tinted, rocks, bushes, lakes, chunks))
end)
