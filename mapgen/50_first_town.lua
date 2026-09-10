-- 50_first_town: the first playable town at Brasshaven, laid out for level design rather than realism.
--
-- What this phase DOES build: the ruined gazebo everyone spawns under, the dirt paths that connect
-- everything, the building PLOTS (flat pads with a sign naming what belongs there), the decorative trees
-- and bushes, the gathering nodes, and the slime spawners in the fields outside.
--
-- What it does NOT build: the buildings. Those are the user's own models, dropped onto the plots by hand.
-- A plot is a levelled pad and a label, so a model can be dragged straight onto it without hunting for the
-- ground height.
--
-- LEVEL DESIGN, which is the part the user asked for specifically:
--   * The gazebo sits at the centre and is visible from every plot, so a new player always has a landmark
--     to orient by and can never be truly lost.
--   * Buildings are scattered off-axis rather than lining a street. A grid reads as a car park; an
--     irregular ring reads as a town that grew.
--   * Every plot is reachable by a path, and every path meets the plaza -- so "follow the path" always
--     leads somewhere, and the plaza is where players meet by accident.
--   * The shop is the CLOSEST plot to spawn. It is the only one a new player actually needs.
--   * Sight lines are kept open: nothing is placed within DECOR_CLEARANCE of a path, so the town never
--     feels like a corridor. The user asked for open space, and the way to get it is to reserve it.
--   * Gathering nodes sit at the town EDGE, not in the plaza: the first thing a player learns is that
--     resources are outside and safety is inside.
--   * Slimes are pushed a further ring out, past the nodes, so a player gathering at the edge can see
--     danger before meeting it.
-- L, and the layout, are concatenated in ahead of this file by tools/run-luau.js -- not required.

--------------------------------------------------------------------------------
-- The shape of the town
--------------------------------------------------------------------------------

-- Scale note (2026-09-10): the plots below were first sized for the small building models. Those
-- models were then rebuilt with 26 stud ceilings and 12 x 18 doorways so a character can run and
-- jump indoors, which made every footprint 2.5-3x wider. The composition described above is
-- unchanged -- same street, same civic quarter, same two house pockets, same uneven distances --
-- only the ruler is bigger. Plot sizes are the model footprint plus a 14 stud margin.
local PLAZA_RADIUS = 110 -- holds the clock tower (56 x 58) with open ground left over
local PATH_WIDTH = 22
local DECOR_CLEARANCE = 16 -- nothing decorative closer than this to a path centre-line

-- Each plot: a name, the angle it sits at (degrees, 0 = +X), its distance from the centre, and the pad
-- size the user's model needs. Distances are deliberately uneven -- an equal ring would read as a dial.
-- Plots are placed by hand in TOWN-LOCAL coordinates (x east, z north, 0,0 = the gazebo) rather than by
-- angle and distance. The first draft used an angle sweep and the result looked exactly like what it was:
-- a dial, twelve spokes radiating evenly from a disc. A town is not radially symmetric.
--
-- What this arrangement is doing instead:
--   * A main street runs roughly north-south past the plaza, with the shop and the inn facing each other
--     across it. Two buildings facing each other make a street; a ring of buildings makes a roundabout.
--   * The civic buildings (barracks, clinic) sit together on the west side, away from the commercial ones.
--     Grouping by purpose gives a player a reason to learn the town rather than wander it.
--   * Houses cluster in two loose pockets with gaps between them, not spaced evenly. Even spacing is the
--     single strongest tell that a layout was generated.
--   * Nothing is at the same distance as its neighbour, and no two buildings share an axis.
local PLOTS = {
	-- The commercial street, east of the plaza. Shop nearest the spawn: it is the only building a new
	-- player actually needs, so it should be the first one they walk into.
	{ name = "ร้านขายของ", key = "shop", x = 177, z = 36, rot = -80, size = Vector3.new(80, 1, 68) },
	{ name = "โรงเตี๊ยม", key = "inn", x = 192, z = -120, rot = -95, size = Vector3.new(156, 1, 134) },
	{ name = "ช่างฝีมือ", key = "smithy", x = 151, z = 192, rot = -68, size = Vector3.new(138, 1, 102) },

	-- The civic quarter, west, set further back so the walk there feels like going somewhere official.
	{ name = "กองอัศวิน", key = "barracks", x = -250, z = -78, rot = 84, size = Vector3.new(180, 1, 170) },
	{ name = "โรงหมอ", key = "clinic", x = -203, z = 135, rot = 72, size = Vector3.new(130, 1, 94) },

	-- The warehouse sits north, on its own, where carts would come in from the road.
	{ name = "คลังสินค้า", key = "warehouse", x = -47, z = -265, rot = 8, size = Vector3.new(158, 1, 114) },

	-- Houses: two pockets, deliberately uneven. The south pocket is denser than the north-east one.
	{ name = "บ้าน", key = "house", x = 78, z = 307, rot = -22, size = Vector3.new(112, 1, 92) },
	{ name = "บ้าน", key = "house", x = -56, z = 350, rot = 12, size = Vector3.new(112, 1, 92) },
	{ name = "บ้าน", key = "house", x = -135, z = 302, rot = 40, size = Vector3.new(112, 1, 92) },
	{ name = "บ้าน", key = "house", x = 290, z = -262, rot = -128, size = Vector3.new(112, 1, 92) },
	{ name = "บ้าน", key = "house", x = 336, z = -151, rot = -104, size = Vector3.new(112, 1, 92) },
	{ name = "บ้าน", key = "house", x = -317, z = -250, rot = 130, size = Vector3.new(112, 1, 92) },
}

local DIRT = Color3.fromRGB(126, 100, 72)
local STONE_PALE = Color3.fromRGB(158, 154, 146)
local STONE_DARK = Color3.fromRGB(118, 114, 108)

--------------------------------------------------------------------------------

local function part(parent, name, size, cframe, colour, material)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cframe
	p.Color = colour
	p.Material = material or Enum.Material.Slate
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

return L.runPhase("FirstTown", function(folder)
	local cx, cz = L.placePos("Brasshaven")

	local CollectionService = game:GetService("CollectionService")

	-- The REAL surface, found by raycast rather than by asking L.heightAt.
	--
	-- heightAt returns the height the terrain generator was asked to write, but voxel terrain snaps to its
	-- own grid and ends up somewhere else: measured 44.5 from heightAt against an actual walkable surface
	-- at 46.0. Every flat thing this phase builds -- plaza, paths, plots -- was buried by that 1.5 studs.
	--
	-- Falls back to heightAt where nothing is hit (over water, or a gap in the written terrain), which is
	-- no worse than the old behaviour and never returns nil.
	local surfaceParams = RaycastParams.new()
	surfaceParams.FilterType = Enum.RaycastFilterType.Exclude
	surfaceParams.FilterDescendantsInstances = { folder }

	local function groundAt(x, z)
		local hit = workspace:Raycast(Vector3.new(x, 600, z), Vector3.new(0, -900, 0), surfaceParams)
		if hit then return hit.Position.Y end
		return L.heightAt(x, z)
	end

	local groundY = groundAt(cx, cz)

	----------------------------------------------------------------------------
	-- The plaza and the ruined gazebo
	----------------------------------------------------------------------------

	local plaza = Instance.new("Folder")
	plaza.Name = "Plaza"
	plaza.Parent = folder

	local floor = part(plaza, "PlazaFloor", Vector3.new(PLAZA_RADIUS * 2, 1, PLAZA_RADIUS * 2),
		CFrame.new(cx, groundY + 0.5, cz), STONE_PALE, Enum.Material.Cobblestone)
	floor.Shape = Enum.PartType.Cylinder
	-- A cylinder's length runs along X, so it has to be tipped on its side to lie flat.
	-- 4 studs thick, sunk into the ground so its TOP clears the terrain grass. Roblox grass decoration
	-- stands about 3 studs proud of the surface, so a thin slab laid flush has grass growing through it --
	-- which is exactly how the first version looked.
	floor.Size = Vector3.new(4, PLAZA_RADIUS * 2, PLAZA_RADIUS * 2)
	floor.CFrame = CFrame.new(cx, groundY + 1.6, cz) * CFrame.Angles(0, 0, math.rad(90))

	-- The gazebo: a stone platform, six columns, and a roof with a piece missing. The gap is deliberate --
	-- a broken roof tells a player this place is old without a word of text, and the hole lets light in so
	-- the inside is not a dark box.
	local gazebo = Instance.new("Model")
	gazebo.Name = "Gazebo"
	gazebo.Parent = plaza

	local baseY = groundY + 1
	local plinth = part(gazebo, "Plinth", Vector3.new(1, 26, 26),
		CFrame.new(cx, baseY + 0.5, cz) * CFrame.Angles(0, 0, math.rad(90)),
		STONE_PALE, Enum.Material.Cobblestone)
	plinth.Shape = Enum.PartType.Cylinder
	gazebo.PrimaryPart = plinth

	local step = part(gazebo, "Step", Vector3.new(1, 30, 30),
		CFrame.new(cx, baseY - 0.4, cz) * CFrame.Angles(0, 0, math.rad(90)),
		STONE_DARK, Enum.Material.Cobblestone)
	step.Shape = Enum.PartType.Cylinder

	-- Six columns, with the seventh position left as rubble: the ruin reads as a ruin.
	local COLUMN_HEIGHT = 18 -- tall enough to jump under without clipping, per the user's headroom note
	for i = 0, 6 do
		local angle = math.rad(i * (360 / 7))
		local px = cx + math.cos(angle) * 10
		local pz = cz + math.sin(angle) * 10
		if i == 3 then
			-- The fallen one, lying on its side beside its own stump.
			part(gazebo, "FallenColumn", Vector3.new(1.6, 11, 1.6),
				CFrame.new(px + 3, baseY + 1.8, pz + 2) * CFrame.Angles(0, angle, math.rad(88)),
				STONE_PALE, Enum.Material.Cobblestone)
			part(gazebo, "ColumnStump", Vector3.new(1.9, 3, 1.9),
				CFrame.new(px, baseY + 2.5, pz), STONE_PALE, Enum.Material.Cobblestone)
		else
			part(gazebo, "Column", Vector3.new(1.7, COLUMN_HEIGHT, 1.7),
				CFrame.new(px, baseY + COLUMN_HEIGHT / 2 + 1, pz), STONE_PALE, Enum.Material.Cobblestone)
			part(gazebo, "Capital", Vector3.new(2.4, 0.8, 2.4),
				CFrame.new(px, baseY + COLUMN_HEIGHT + 1.4, pz), STONE_DARK, Enum.Material.Cobblestone)
		end
	end

	-- The roof, in wedges, with the wedge over the fallen column missing.
	local roofY = baseY + COLUMN_HEIGHT + 2.4
	for i = 0, 6 do
		if i ~= 3 then
			local angle = math.rad(i * (360 / 7))
			local rx = cx + math.cos(angle) * 6.4
			local rz = cz + math.sin(angle) * 6.4
			part(gazebo, "RoofSlab", Vector3.new(9, 0.7, 6),
				CFrame.new(rx, roofY, rz) * CFrame.Angles(0, -angle, math.rad(-13)),
				STONE_DARK, Enum.Material.Slate)
		end
	end
	-- A little rubble where the roof came down, so the gap has a cause on the ground.
	for i = 1, 5 do
		local a = math.rad(150 + i * 12)
		part(gazebo, "Rubble", Vector3.new(2 + math.random() * 2, 1 + math.random(), 2 + math.random() * 2),
			CFrame.new(cx + math.cos(a) * (12 + math.random() * 5), baseY + 1,
				cz + math.sin(a) * (12 + math.random() * 5)) * CFrame.Angles(0, math.random() * 6, 0),
			STONE_PALE, Enum.Material.Cobblestone)
	end

	-- The spawn itself, under the gazebo.
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "SpawnLocation"
	spawn.Anchored = true
	spawn.Size = Vector3.new(8, 1, 8)
	spawn.Position = Vector3.new(cx, baseY + 1.5, cz)
	spawn.Material = Enum.Material.Cobblestone
	spawn.Color = STONE_DARK
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Transparency = 1 -- the plinth is the visible floor; this is only the anchor
	spawn.Parent = plaza
	CollectionService:AddTag(spawn, "RespawnPoint")

	----------------------------------------------------------------------------
	-- Plots and the paths that reach them
	----------------------------------------------------------------------------

	local plots = Instance.new("Folder")
	plots.Name = "Plots"
	plots.Parent = folder

	local paths = Instance.new("Folder")
	paths.Name = "Paths"
	paths.Parent = folder

	-- Remembered so decoration can keep clear of them.
	local pathSegments = {}

	-- Paths are laid as a NETWORK of segments between named junctions, not as spokes from the plaza. The
	-- spoke version made the town look like a wheel: every route led through the middle, and no two
	-- buildings were connected to each other except through the plaza.
	--
	-- Slabs are short and follow the ground one at a time. A single long part would bury one end of itself
	-- on any slope.
	local function layPath(ax, az, bx, bz, width)
		width = width or PATH_WIDTH
		local dx, dz = bx - ax, bz - az
		local length = math.sqrt(dx * dx + dz * dz)
		if length < 1 then return end
		local steps = math.max(1, math.floor(length / 7))
		local heading = math.atan2(dx, dz)
		for i = 0, steps do
			local t = i / steps
			local px = ax + dx * t
			local pz = az + dz * t
			-- A gentle wobble so the street is not drawn with a ruler. Small enough to still read as a
			-- deliberate path, large enough that the eye does not see a straight line.
			local wobble = math.sin(t * math.pi * 2.2 + ax * 0.01) * 1.6
			px += math.cos(heading) * wobble
			pz -= math.sin(heading) * wobble
			-- A path is a SUNK slab, flush with the ground.
			--
			-- It was briefly a FillBall of Ground, on the theory that it would scoop a hollow. It does the
			-- opposite: FillBall ADDS terrain, so every path point dumped a ball of soil, and wherever the
			-- centre sat above the surface it left a mound hanging in the air -- measured one at y=132
			-- between neighbours at y=53, and the city was full of them.
			--
			-- Carving would mean filling with Air and then repainting the floor, which is a lot of work to
			-- avoid a kerb. Burying a thick slab so its top is level does the same job: no step to trip
			-- over, no terrain touched.
			local py = groundAt(px, pz)
			part(paths, "PathSlab", Vector3.new(width, 6, 8.4),
				CFrame.new(px, py - 2.7, pz) * CFrame.Angles(0, heading, 0),
				DIRT, Enum.Material.Ground)
		end
		table.insert(pathSegments, { ax, az, bx, bz })
	end

	-- Distance from a point to any path, so decoration can stay off them.
	local function distanceToPaths(x, z)
		local best = math.huge
		for _, seg in ipairs(pathSegments) do
			local ax, az, bx, bz = seg[1], seg[2], seg[3], seg[4]
			local dx, dz = bx - ax, bz - az
			local len2 = dx * dx + dz * dz
			local t = len2 > 0 and math.clamp(((x - ax) * dx + (z - az) * dz) / len2, 0, 1) or 0
			local px, pz = ax + dx * t, az + dz * t
			best = math.min(best, math.sqrt((x - px) ^ 2 + (z - pz) ^ 2))
		end
		return best
	end

	local plotCentres = {}

	for _, plot in ipairs(PLOTS) do
		local px = cx + plot.x
		local pz = cz + plot.z
		local py = groundAt(px, pz)

		-- The pad is built 3 studs thick regardless of what the table says, and raised so its top clears
		-- the terrain grass. The table's Y is ignored on purpose: it describes the footprint a model needs,
		-- not how deep the foundation should be.
		local pad = part(plots, "Plot_" .. plot.key,
			Vector3.new(plot.size.X, 3, plot.size.Z),
			CFrame.new(px, py + 1.7, pz) * CFrame.Angles(0, math.rad(plot.rot), 0),
			DIRT, Enum.Material.Ground)
		pad:SetAttribute("PlotKey", plot.key)
		pad:SetAttribute("PlotName", plot.name)

		-- A sign so the user knows what belongs here before any model exists.
		local sign = Instance.new("BillboardGui")
		sign.Size = UDim2.fromOffset(150, 26)
		sign.StudsOffsetWorldSpace = Vector3.new(0, 6, 0)
		sign.MaxDistance = 220
		sign.Parent = pad
		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.GothamBold
		label.TextSize = 13
		label.TextColor3 = Color3.fromRGB(255, 226, 170)
		label.TextStrokeTransparency = 0.4
		label.Text = plot.name
		label.Parent = sign

		table.insert(plotCentres, { px, pz, math.max(plot.size.X, plot.size.Z) * 0.5, plot.key })
	end

	-- The street network.
	--
	-- Two drafts of this looked like a wheel. The first ran a spoke from the plaza to each plot; the second
	-- ran streets to junctions and then spurs from those same junctions, which is the same fan with extra
	-- steps. The fix is that streets must run BETWEEN buildings, and touch the plaza only where they pass
	-- it -- a plaza is a widening in the road, not a hub every route radiates from.
	--
	-- So: three through-streets that each pass the plaza on their way somewhere else, and short lanes that
	-- join one building to its NEIGHBOUR rather than to the middle.
	local function plotAt(key)
		for _, c in ipairs(plotCentres) do
			if c[4] == key then return c[1], c[2] end
		end
	end

	-- The main street: comes in from the north, brushes the east edge of the plaza, carries on south to the
	-- house pocket and out of town. One continuous road, drawn in three legs so it can bend.
	layPath(cx - 26, cz - 150, cx + 16, cz - PLAZA_RADIUS - 4, PATH_WIDTH + 4)
	layPath(cx + 16, cz - PLAZA_RADIUS - 4, cx + 22, cz + PLAZA_RADIUS + 2, PATH_WIDTH + 4)
	layPath(cx + 22, cz + PLAZA_RADIUS + 2, cx - 10, cz + 150, PATH_WIDTH + 4)

	-- The cross street: west civic quarter to east commercial street, passing the plaza on its south side.
	layPath(cx - 120, cz + 22, cx - PLAZA_RADIUS - 2, cz + 16, PATH_WIDTH + 2)
	layPath(cx - PLAZA_RADIUS - 2, cz + 16, cx + PLAZA_RADIUS + 2, cz - 2, PATH_WIDTH + 2)
	layPath(cx + PLAZA_RADIUS + 2, cz - 2, cx + 104, cz - 26, PATH_WIDTH + 2)

	-- The north lane out to the warehouse, leaving the main street rather than the plaza.
	layPath(cx + 4, cz - 96, cx - 18, cz - 102, PATH_WIDTH - 1)

	-- Building lanes. Each joins its plot to a point ON a street, not to the centre -- and buildings that
	-- share a street are joined to each other, which is what makes it read as a street.
	local function lane(key, toX, toZ, width)
		local px, pz = plotAt(key)
		if px then layPath(px, pz, toX, toZ, width or (PATH_WIDTH - 2)) end
	end

	lane("shop", cx + 34, cz + 4)          -- onto the cross street
	lane("inn", cx + 30, cz - 34)          -- onto the main street, opposite the shop
	lane("smithy", cx + 24, cz + 62)       -- onto the main street heading south
	lane("barracks", cx - 88, cz + 16)     -- onto the west end of the cross street
	lane("clinic", cx - 92, cz + 26)       -- and its neighbour joins the same stretch
	lane("warehouse", cx + 2, cz - 98)

	-- House lanes run to the nearest building lane, not to a junction: a cul-de-sac off a street.
	for _, c in ipairs(plotCentres) do
		if c[4] == "house" then
			local tx, tz
			if c[2] > cz + 60 then tx, tz = cx - 4, cz + 128      -- south pocket, off the main street
			elseif c[1] > cx + 60 then tx, tz = cx + 96, cz - 74   -- north-east pocket
			else tx, tz = cx - 100, cz - 60 end                    -- the lone western house
			layPath(c[1], c[2], tx, tz, PATH_WIDTH - 3)
		end
	end

	----------------------------------------------------------------------------
	-- Decoration, and the gathering nodes
	----------------------------------------------------------------------------

	local decor = Instance.new("Folder")
	decor.Name = "Decor"
	decor.Parent = folder

	-- Is this spot free? Nothing on a path, nothing on a plot, nothing in the plaza.
	local function isClear(x, z, margin)
		if (Vector3.new(x, 0, z) - Vector3.new(cx, 0, cz)).Magnitude < PLAZA_RADIUS + 6 then return false end
		if distanceToPaths(x, z) < DECOR_CLEARANCE + (margin or 0) then return false end
		for _, c in ipairs(plotCentres) do
			if math.sqrt((x - c[1]) ^ 2 + (z - c[2]) ^ 2) < c[3] + 8 + (margin or 0) then return false end
		end
		return true
	end

	-- Trees, bushes and rocks come from the APPROVED Creator Store prototypes in
	-- ServerStorage.WOLD_Assets, loaded by mapgen/assets_setup.lua and listed in layout.nature.assets --
	-- 9 oaks, 2 pines, 15 bushes and 16 rocks, already stripped of scripts and measured for base offset.
	--
	-- The first draft built trees out of a cylinder and three spheres, which was wrong twice over: it
	-- looked like a lollipop, and it ignored prototypes the user had already picked and approved for
	-- exactly this. L.placeAsset handles the clone, the random yaw, the scale and the base offset.
	--
	-- Falls back to nothing rather than to home-made parts: if the prototypes are missing, an empty town
	-- is a clearer signal to run assets_setup than a town full of lollipops.
	-- L.placeAsset sinks every model exactly 1 stud, which is right for a 50-stud pine (it hides the seam
	-- where trunk meets ground) and badly wrong for anything small: measured a 1.1-stud rock 93% buried,
	-- and a dozen bushes losing a third of themselves.
	--
	-- So: place it, measure what actually arrived, and lift it back up until no more than a fixed fraction
	-- of its height is under the ground. Measuring afterwards rather than predicting is the only reliable
	-- way -- the prototypes are random sizes, randomly scaled, with their own base offsets.
	local MAX_SUNK_FRACTION = 0.08 -- at most 8% of a model's height may be below ground
	local MAX_SUNK_STUDS = 1.0     -- and never more than the original stud, however tall it is

	local function settle(model)
		if not model then return nil end

		-- Model:GetBoundingBox() rather than each part's Position minus half its Size.
		--
		-- These prototypes are MeshParts, and a MeshPart's mesh does not fill its box: measuring part by
		-- part put the "base" well below the visible geometry, so models that looked like they were
		-- hovering measured as correctly planted. Two were left 1.4 and 3.75 studs in the air by exactly
		-- that mistake. The model bounding box is what the eye sees.
		local box, size = model:GetBoundingBox()
		local low = box.Position.Y - size.Y / 2
		local height = size.Y
		if height <= 0 then return model end
		local allowed = math.min(MAX_SUNK_STUDS, height * MAX_SUNK_FRACTION)

		-- Where the ground under this model actually is. The town's own parts are excluded, or a ray
		-- dropped near a tree finds the neighbouring canopy and calls it the floor -- which is how an
		-- earlier measurement of this reported rocks 40 studs underground.
		local pivot = box.Position
		local probe = RaycastParams.new()
		probe.FilterType = Enum.RaycastFilterType.Exclude
		probe.FilterDescendantsInstances = { L.root() }
		local hit = workspace:Raycast(Vector3.new(pivot.X, low + 60, pivot.Z),
			Vector3.new(0, -200, 0), probe)
		if not hit then return model end

		-- Put the base exactly `allowed` studs under the surface, whichever side of it we started on.
		-- Correcting both directions matters: one oak prototype's measured BaseOffset leaves it hovering
		-- up to 2.7 studs in the air, which no amount of sinking would have fixed.
		local wanted = hit.Position.Y - allowed
		local shift = wanted - low
		if math.abs(shift) > 0.05 then
			model:PivotTo(model:GetPivot() + Vector3.new(0, shift, 0))
		end
		return model
	end

	local function placeTree(parent, x, z, y, seed)
		local rng = Random.new(seed)
		-- Oak near the town, pine occasionally, for a little variety without a rule anyone has to read.
		local kind = rng:NextNumber() < 0.78 and "oak" or "pine"
		return settle(L.placeAsset(parent, kind, x, y, z, rng, 0.85, 1.25))
	end

	local function placeRock(parent, x, z, y, seed)
		local rng = Random.new(seed)
		-- Rock prototypes run from 8 to 38 studs tall; the big ones are cliff pieces, not boulders. The
		-- floor of 0.35 stops a scaled-down one becoming a pebble the sink would swallow whole.
		return settle(L.placeAsset(parent, "rock", x, y, z, rng, 0.35, 0.55))
	end

	local function placeBush(parent, x, z, y, seed)
		local rng = Random.new(seed)
		return settle(L.placeAsset(parent, "bush", x, y, z, rng, 0.8, 1.2))
	end

	-- Gathering nodes ring the town, outside the plots. Tagged so Gathering.server picks them up with no
	-- further wiring: the tag IS the contract.
	local nodes = Instance.new("Folder")
	nodes.Name = "Nodes"
	nodes.Parent = folder

	local placed = 0
	local attempts = 0
	while placed < 34 and attempts < 900 do
		attempts += 1
		local angle = math.random() * math.pi * 2
		local distance = 150 + math.random() * 130
		local x = cx + math.cos(angle) * distance
		local z = cz + math.sin(angle) * distance
		if L.isLand(x, z) and isClear(x, z, 4) then
			local y = groundAt(x, z)
			local isTree = math.random() < 0.62
			local node = isTree and placeTree(nodes, x, z, y, attempts)
				or placeRock(nodes, x, z, y, attempts)
			if node then
				-- placeAsset has already tagged it Tree or Rock with the gathering attributes from
				-- 04-gameplay-hooks. WOLD_Node and NodeKind are what THIS system reads, so only those
				-- are added here.
				node:SetAttribute("NodeKind", isTree and "Tree" or "Rock")
				CollectionService:AddTag(node, "WOLD_Node")
				placed += 1
			end
		end
	end

	-- Purely decorative greenery, inside the town, where nodes would clutter the walkable space.
	local decorated, tries = 0, 0
	while decorated < 46 and tries < 900 do
		tries += 1
		local angle = math.random() * math.pi * 2
		local distance = PLAZA_RADIUS + 10 + math.random() * 110
		local x = cx + math.cos(angle) * distance
		local z = cz + math.sin(angle) * distance
		if L.isLand(x, z) and isClear(x, z, 0) then
			local y = groundAt(x, z)
			local placedOne = (math.random() < 0.45)
				and placeTree(decor, x, z, y, tries + 5000)
				or placeBush(decor, x, z, y, tries + 5000)
			if placedOne then decorated += 1 end
		end
	end

	----------------------------------------------------------------------------
	-- Slimes, in a ring beyond the gathering nodes
	----------------------------------------------------------------------------

	local spawners = Instance.new("Folder")
	spawners.Name = "Spawners"
	spawners.Parent = folder

	-- Three spawners rather than one, spread around the town, so slimes are something you meet in a
	-- direction rather than a single nest everyone farms. Two or three each keeps the total in the 5-10
	-- the user asked for.
	for i = 1, 3 do
		local angle = math.rad(40 + (i - 1) * 120 + math.random() * 30)
		local distance = 300 + math.random() * 70
		local x = cx + math.cos(angle) * distance
		local z = cz + math.sin(angle) * distance
		if L.isLand(x, z) then
			local y = groundAt(x, z)
			local marker = part(spawners, "SlimeSpawner", Vector3.new(4, 1, 4),
				CFrame.new(x, y + 0.5, z), Color3.fromRGB(96, 200, 104), Enum.Material.Slate)
			marker.Transparency = 1
			marker.CanCollide = false
			marker:SetAttribute("MobKind", "GreenSlime")
			marker:SetAttribute("Count", i == 1 and 3 or 2) -- 7 in total
			marker:SetAttribute("Radius", 55)
			CollectionService:AddTag(marker, "WOLD_Spawner")
		end
	end

	----------------------------------------------------------------------------
	-- The shopkeeper
	----------------------------------------------------------------------------

	-- A placeholder body until the user's NPC model arrives. Tagged and attributed the same way the real
	-- one will be, so swapping it out is a matter of deleting this and dropping the model in.
	local shopPlot = plotCentres[1]
	local npcX = shopPlot[1] - 6
	local npcZ = shopPlot[2] - 6
	local npcY = groundAt(npcX, npcZ)

	local keeper = Instance.new("Model")
	keeper.Name = "Shopkeeper"
	keeper.Parent = folder
	local torso = part(keeper, "HumanoidRootPart", Vector3.new(2.4, 3.4, 1.4),
		CFrame.new(npcX, npcY + 2.7, npcZ), Color3.fromRGB(112, 84, 62), Enum.Material.Fabric)
	keeper.PrimaryPart = torso
	part(keeper, "Head", Vector3.new(1.6, 1.6, 1.6),
		CFrame.new(npcX, npcY + 5.2, npcZ), Color3.fromRGB(214, 176, 140), Enum.Material.SmoothPlastic)
	keeper:SetAttribute("NpcKind", "shop")
	keeper:SetAttribute("NpcName", "เฒ่าแก่")
	CollectionService:AddTag(keeper, "WOLD_Npc")

	local sign = Instance.new("BillboardGui")
	sign.Size = UDim2.fromOffset(140, 24)
	sign.StudsOffsetWorldSpace = Vector3.new(0, 3.4, 0)
	sign.MaxDistance = 120
	sign.Parent = torso
	local signText = Instance.new("TextLabel")
	signText.Size = UDim2.fromScale(1, 1)
	signText.BackgroundTransparency = 1
	signText.Font = Enum.Font.GothamBold
	signText.TextSize = 13
	signText.TextColor3 = Color3.fromRGB(255, 226, 170)
	signText.TextStrokeTransparency = 0.4
	signText.Text = "เฒ่าแก่ (ซื้อขาย)"
	signText.Parent = sign

	----------------------------------------------------------------------------

	-- The stopgap pad this town replaces.
	local root = L.root()
	local temp = root:FindFirstChild("TempSpawn")
	if temp then
		temp:Destroy()
		print("[WOLD] removed TempSpawn -- FirstTown provides the real spawn now")
	end

	print(("[WOLD] FirstTown: %d plots, %d gathering nodes, %d decor, 3 slime spawners")
		:format(#PLOTS, placed, decorated))
end)
