-- 52_city_districts: spreads Brasshaven across its walls, and lays streets between the districts.
--
-- The town built by 50_first_town packs twelve plots into a 316-stud circle inside walls that enclose
-- 3,300 by 4,000 studs -- about one percent of the ground, with houses fifteen studs apart. This phase
-- uses the districts the layout already defines and gives each one room.
--
-- What it builds: levelled PLOTS with signs, and the streets joining them. The buildings themselves are
-- 55_town_buildings' job, exactly as before -- which is why the plot key vocabulary is unchanged.
--
-- Run with:  node tools/run-luau.js mapgen/52_city_districts.lua
--
-- L, and the layout, are concatenated in ahead of this file by tools/run-luau.js -- not required.

--------------------------------------------------------------------------------

local DIRT = Color3.fromRGB(126, 100, 72)
local STONE_PALE = Color3.fromRGB(158, 154, 146)

-- Wide enough to DRIVE on, two vehicles abreast.
--
-- A Roblox character is about 4 studs across and the steam car in the vehicle spec is a good deal wider,
-- call it 14 with mirrors and fenders. Two of those passing needs 28 plus room not to clip each other and
-- not to scrape the kerb -- so 44 on the main street, which is nearly double layout.road_style's 24. That
-- number was written for a cart track between towns, not for a capital with cars in it.
--
-- The lanes stay narrower: a residential back street is one vehicle wide and that is correct.
local MAIN_W = 44
local LANE_W = 26

-- How far a bridge deck rides above the water, so a boat can pass beneath it.
local BRIDGE_CLEAR = 14

-- How many samples the road takes to climb from the ground up to the deck at each end.
local RAMP_STEPS = 6

-- Painted down the middle of the main street only, so the two lanes read as two lanes.
local CENTRE_LINE = Color3.fromRGB(206, 198, 176)

-- What stands in each district, and how much room each plot needs. Sizes are the footprint the model
-- wants; the pad is cut a little larger so a building never overhangs its own ground.
--
-- Keys match PLOT_MODEL in 55_town_buildings -- that file decides which model, this one decides where.
local DISTRICT_PLOTS = {
	market = {
		{ key = "shop", size = Vector3.new(38, 1, 34) },
		{ key = "inn", size = Vector3.new(52, 1, 44) },
		{ key = "smithy", size = Vector3.new(40, 1, 36) },
		{ key = "house", size = Vector3.new(26, 1, 24) },
		{ key = "house", size = Vector3.new(26, 1, 24) },
	},
	government = {
		{ key = "barracks", size = Vector3.new(58, 1, 50) },
		{ key = "clinic", size = Vector3.new(46, 1, 42) },
	},
	harbor = {
		{ key = "warehouse", size = Vector3.new(44, 1, 40) },
		{ key = "house", size = Vector3.new(26, 1, 24) },
		{ key = "house", size = Vector3.new(26, 1, 24) },
	},
	-- The residential rings get houses only, which is what makes them read as somewhere people live
	-- rather than as more of the same square.
	residential = {
		{ key = "house", size = Vector3.new(26, 1, 24) },
		{ key = "house", size = Vector3.new(26, 1, 24) },
		{ key = "house", size = Vector3.new(26, 1, 24) },
		{ key = "house", size = Vector3.new(26, 1, 24) },
	},
}

local NAMES = {
	shop = "ร้านขายของ", inn = "โรงเตี๊ยม", smithy = "ช่างฝีมือ",
	barracks = "กองอัศวิน", clinic = "โรงหมอ", warehouse = "คลังสินค้า", house = "บ้าน",
}

--------------------------------------------------------------------------------

return L.runPhase("CityDistricts", function(folder)
	local Y = L.LAYOUT
	local HALF = L.HALF
	local cap = Y.capital
	assert(cap and cap.districts, "layout.capital.districts is missing")

	local probe = RaycastParams.new()
	probe.FilterType = Enum.RaycastFilterType.Exclude
	probe.FilterDescendantsInstances = { L.root() }

	local function groundAt(x, z)
		local hit = workspace:Raycast(Vector3.new(x, 1200, z), Vector3.new(0, -2000, 0), probe)
		return hit and hit.Position.Y or L.heightAt(x, z)
	end

	-- The RIVERBED, ignoring water. A plain ground ray stops at the water's surface, which is how the
	-- main street came to be paved straight across the river as though it were a field. Piers need to
	-- stand on the bed, so they need the ray that goes through.
	local bedProbe = RaycastParams.new()
	bedProbe.FilterType = Enum.RaycastFilterType.Exclude
	bedProbe.FilterDescendantsInstances = { L.root() }
	bedProbe.IgnoreWater = true

	local function bedAt(x, z)
		local hit = workspace:Raycast(Vector3.new(x, 1200, z), Vector3.new(0, -2000, 0), bedProbe)
		return hit and hit.Position.Y or L.heightAt(x, z)
	end

	-- Is this point over the river? Half the width is the water's edge; a little past it is the bank the
	-- bridge should land on rather than stop short of.
	local function overRiver(x, z)
		local d, surface, w = L.riverAt(x, z)
		return d < w * 0.5 + 8, surface, w
	end

	local function part(parent, name, size, cf, colour, material)
		local p = Instance.new("Part")
		p.Name = name
		p.Anchored = true
		p.Size = size
		p.CFrame = cf
		p.Color = colour
		p.Material = material or Enum.Material.Ground
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.Parent = parent
		return p
	end

	----------------------------------------------------------------------------
	-- Where each district sits
	----------------------------------------------------------------------------

	-- Flattened out of the layout: the residential entry is a LIST of three rings, the rest are single
	-- circles, so they are normalised here into one shape the placement loop can walk.
	local districts = {}
	for name, entry in pairs(cap.districts) do
		if name ~= "keep" then -- the keep is 70_capital's, and has no plots
			if entry.center then
				table.insert(districts, { name = name, x = entry.center[1] * HALF,
					z = entry.center[2] * HALF, r = (entry.radius or 0.03) * HALF })
			elseif type(entry) == "table" then
				for i, ring in ipairs(entry) do
					if ring.center then
						table.insert(districts, { name = name, index = i, x = ring.center[1] * HALF,
							z = ring.center[2] * HALF, r = (ring.radius or 0.03) * HALF })
					end
				end
			end
		end
	end
	table.sort(districts, function(a, b) return a.name < b.name end)

	----------------------------------------------------------------------------
	-- Streets
	----------------------------------------------------------------------------

	local streets = Instance.new("Folder")
	streets.Name = "Streets"
	streets.Parent = folder

	local laid = {}

	-- A street between two points, in slabs that each sit on their own footing. One long part would bury
	-- an end wherever the ground rises.
	local function street(ax, az, bx, bz, width)
		local dx, dz = bx - ax, bz - az
		local length = math.sqrt(dx * dx + dz * dz)
		if length < 4 then return end
		local heading = math.atan2(dx, dz)
		local steps = math.max(1, math.floor(length / 12))
		-- Find the span of samples that lie over water, so the bridge can be one continuous deck at one
		-- height rather than a road that dips into the river and climbs out again.
		local firstWet, lastWet
		for i = 0, steps do
			local t = i / steps
			if (overRiver(ax + dx * t, az + dz * t)) then
				firstWet = firstWet or i
				lastWet = i
			end
		end

		-- The deck runs level, clear of the water, from the bank on one side to the bank on the other.
		local deckY
		if firstWet then
			-- One stud short of each bank so the road slabs either side overlap the abutment rather than
			-- leaving a seam, and high enough that a boat has headroom under it.
			local _, surface = overRiver(ax + dx * (firstWet / steps), az + dz * (firstWet / steps))
			deckY = surface + BRIDGE_CLEAR
			-- ...but never below the ground it lands on, or the approach ramps down into a hillside.
			local bankA = groundAt(ax + dx * (math.max(0, firstWet - 1) / steps), az + dz * (math.max(0, firstWet - 1) / steps))
			local bankB = groundAt(ax + dx * (math.min(steps, lastWet + 1) / steps), az + dz * (math.min(steps, lastWet + 1) / steps))
			deckY = math.max(deckY, bankA, bankB)
		end

		-- The ground height at every sample, SMOOTHED along the run.
		--
		-- Taken raw, each slab sits at its own spot height, and on a hillside consecutive slabs step apart
		-- far enough to see daylight between them -- the road climbing out of the river read as a flight
		-- of loose stairs. Averaging each height with its neighbours turns the steps into a grade.
		local ys = {}
		for i = 0, steps do
			local t = i / steps
			ys[i] = groundAt(ax + dx * t, az + dz * t)
		end
		local smooth = {}
		for i = 0, steps do
			local sum, cnt = 0, 0
			for k = math.max(0, i - 2), math.min(steps, i + 2) do sum, cnt = sum + ys[k], cnt + 1 end
			smooth[i] = sum / cnt
		end

		for i = 0, steps do
			local t = i / steps
			local x, z = ax + dx * t, az + dz * t

			if firstWet and i >= firstWet and i <= lastWet then
				-- BRIDGE. A road cannot simply be paved across a river -- and it was, because the ground
				-- ray stops at the water's surface and happily reported solid footing mid-channel.
				local deckW = width + 6
				part(streets, "BridgeDeck", Vector3.new(deckW, 3, 13),
					CFrame.new(x, deckY, z) * CFrame.Angles(0, heading, 0),
					STONE_PALE, Enum.Material.Slate)
				-- Parapets down both sides, so you cannot walk off the edge into the water.
				for _, side in ipairs({ -1, 1 }) do
					local off = CFrame.new(x, deckY, z) * CFrame.Angles(0, heading, 0)
						* CFrame.new(side * deckW / 2, 2.6, 0)
					part(streets, "BridgeRail", Vector3.new(2, 5, 13), off, STONE_PALE, Enum.Material.Slate)
				end
				-- Piers every few samples, standing on the riverbed rather than hanging off the deck.
				if (i - firstWet) % 3 == 0 and i ~= firstWet and i ~= lastWet then
					local bed = bedAt(x, z)
					local h = math.max(4, deckY - 1.5 - bed)
					part(streets, "BridgePier", Vector3.new(10, h, 10),
						CFrame.new(x, bed + h / 2, z) * CFrame.Angles(0, heading, 0),
						STONE_PALE, Enum.Material.Slate)
				end
			else
			-- SUNK, not raised. A 3-stud slab set 1.6 above the ground stood proud of the grass with a
			-- visible step along both kerbs -- a road you trip over rather than walk on. Thick and
			-- buried, the top sits just at the surface: 6 studs deep with only the top half stud
			-- showing, which also stops the ends poking out where the ground rises between samples.
			local y = smooth[i]
			if width >= MAIN_W then
				-- The paved main street: a real road surface, sunk so its top is level with the ground
				-- rather than standing proud with a kerb to trip over.
				part(streets, "StreetSlab", Vector3.new(width, 6, 13),
					CFrame.new(x, y - 2.6, z) * CFrame.Angles(0, heading, 0),
					STONE_PALE, Enum.Material.Cobblestone)
			else
				-- Back lanes: bare earth rather than cobbles, but the same sunk slab as the main street.
				-- A FillBall of Ground was tried here and ADDS terrain rather than carving it, which
				-- littered the city with floating mounds of soil.
				part(streets, "LaneSlab", Vector3.new(width, 6, 13),
					CFrame.new(x, y - 2.7, z) * CFrame.Angles(0, heading, 0),
					Color3.fromRGB(126, 100, 72), Enum.Material.Ground)
			end
			-- A dashed centre line, on the main street only. Laid a hair above the road's top so it is
			-- not lost inside it, and dashed by skipping every other slab.
			if width >= MAIN_W and i % 2 == 0 then
				part(streets, "CentreLine", Vector3.new(1.4, 6, 7),
					CFrame.new(x, y - 2.35, z) * CFrame.Angles(0, heading, 0),
					CENTRE_LINE, Enum.Material.Concrete)
			end
			end
		end

		-- Ramp the road up to meet the deck. Without this the road runs along the ground and the bridge
		-- starts 14 studs above it, which is a wall at each end rather than a crossing.
		if firstWet then
			for _, side in ipairs({ { firstWet - 1, -1 }, { lastWet + 1, 1 } }) do
				local from, dir = side[1], side[2]
				for k = 0, RAMP_STEPS do
					local i = from + dir * k
					if i >= 0 and i <= steps then
						local t = i / steps
						local x, z = ax + dx * t, az + dz * t
						local g = smooth[i]
						-- Blend from deck height back down to the ground over the length of the ramp.
						local f = k / RAMP_STEPS
						local y = deckY * (1 - f) + g * f
						part(streets, "BridgeRamp", Vector3.new(width + 6, 6, 13),
							CFrame.new(x, y - 1.5, z) * CFrame.Angles(0, heading, 0),
							STONE_PALE, Enum.Material.Slate)
					end
				end
			end
		end

		table.insert(laid, { ax, az, bx, bz, width })
	end

	-- How close a point is to any street already laid, so nothing is built on the road.
	local function toStreet(x, z)
		local best = math.huge
		for _, s in ipairs(laid) do
			local ax, az, bx, bz = s[1], s[2], s[3], s[4]
			local dx, dz = bx - ax, bz - az
			local len2 = dx * dx + dz * dz
			local t = len2 > 0 and math.clamp(((x - ax) * dx + (z - az) * dz) / len2, 0, 1) or 0
			local px, pz = ax + dx * t, az + dz * t
			best = math.min(best, math.sqrt((x - px) ^ 2 + (z - pz) ^ 2) - s[5] / 2)
		end
		return best
	end

	-- The main street: harbour to market to government to the keep's gate, which is the spine of the
	-- city and the route anyone arriving by sea would walk.
	local function centreOf(name, index)
		for _, d in ipairs(districts) do
			if d.name == name and (index == nil or d.index == index) then return d.x, d.z end
		end
	end

	local hx, hz = centreOf("harbor")
	local mx, mz = centreOf("market")
	local gx, gz = centreOf("government")
	local kx, kz = L.placePos("Ironcrest Keep")

	if hx and mx then street(hx, hz, mx, mz, MAIN_W) end
	if mx and gx then street(mx, mz, gx, gz, MAIN_W) end
	if gx and kx then street(gx, gz, kx, kz + 150, MAIN_W) end

	-- Lanes from the market out to each residential ring, so the housing connects to the centre rather
	-- than sitting in fields of its own.
	for _, d in ipairs(districts) do
		if d.name == "residential" and mx then
			street(mx, mz, d.x, d.z, LANE_W)
		end
	end

	L.progress(("CityDistricts: %d streets"):format(#laid))

	----------------------------------------------------------------------------
	-- Plots
	----------------------------------------------------------------------------

	local plots = Instance.new("Folder")
	plots.Name = "Plots"
	plots.Parent = folder

	local placed = {}
	local built = 0

	-- Is there room here? A plot must clear its neighbours, the streets, and the district's own edge.
	local function clear(x, z, size)
		local reach = math.max(size.X, size.Z) / 2
		if toStreet(x, z) < reach + 10 then return false end
		for _, e in ipairs(placed) do
			local d = math.sqrt((x - e.x) ^ 2 + (z - e.z) ^ 2)
			-- 30 studs of daylight between buildings: the old town left fifteen, which is why it felt
			-- packed. A street should be able to pass between two houses.
			if d < reach + math.max(e.size.X, e.size.Z) / 2 + 30 then return false end
		end
		return true
	end

	for _, d in ipairs(districts) do
		local wanted = DISTRICT_PLOTS[d.name]
		if wanted then
			for _, spec in ipairs(wanted) do
				-- Try a ring of positions inside the district until one has room. Angles are jittered so
				-- the result is not a visible circle of buildings.
				local put = false
				for attempt = 1, 90 do
					local a = math.random() * math.pi * 2
					-- Biased outward: sqrt spreads points evenly over the disc rather than crowding the
					-- middle, and the 0.35 floor keeps the district's own centre open as a yard.
					local rad = (0.35 + math.sqrt(math.random()) * 0.6) * d.r
					local x = d.x + math.cos(a) * rad
					local z = d.z + math.sin(a) * rad

					-- Reject a sloping site outright rather than perching a flat pad on it. A level pad on
					-- a hill stands proud on the downhill side -- measured 8 studs on one -- which reads
					-- as a building on a plinth. Flat ground is what a builder would have chosen anyway.
					local flat = true
					do
						local reach = math.max(spec.size.X, spec.size.Z) / 2
						local lo, hi = math.huge, -math.huge
						for _, o in ipairs({ { reach, 0 }, { -reach, 0 }, { 0, reach }, { 0, -reach } }) do
							local hh = workspace:Raycast(Vector3.new(x + o[1], 1200, z + o[2]),
								Vector3.new(0, -2000, 0), probe)
							if hh then
								lo = math.min(lo, hh.Position.Y)
								hi = math.max(hi, hh.Position.Y)
							end
						end
						-- Three studs of fall across the whole footprint: enough for natural unevenness,
						-- not enough to show a step.
						flat = (hi - lo) <= 3
					end

					if flat and clear(x, z, spec.size) and L.isLand(x, z) then
						local y = groundAt(x, z)
						local hit = workspace:Raycast(Vector3.new(x, 1200, z), Vector3.new(0, -2000, 0), probe)
						if hit and hit.Material ~= Enum.Material.Water then
							-- Facing the district centre, so buildings look inward onto their own square.
							local face = math.atan2(d.x - x, d.z - z)
							-- Sunk like the streets: a pad standing 1.7 studs proud of the grass gives every
							-- building a visible plinth it does not want. Deep and buried, the top is
							-- level with the ground the building stands on.
							local pad = part(plots, "Plot_" .. spec.key,
								Vector3.new(spec.size.X, 6, spec.size.Z),
								CFrame.new(x, y - 2.7, z) * CFrame.Angles(0, face, 0), DIRT)
							pad:SetAttribute("PlotKey", spec.key)
							pad:SetAttribute("PlotName", NAMES[spec.key] or spec.key)
							pad:SetAttribute("District", d.name)

							local sign = Instance.new("BillboardGui")
							sign.Size = UDim2.fromOffset(150, 26)
							sign.StudsOffsetWorldSpace = Vector3.new(0, 7, 0)
							sign.MaxDistance = 260
							sign.Parent = pad
							local label = Instance.new("TextLabel")
							label.Size = UDim2.fromScale(1, 1)
							label.BackgroundTransparency = 1
							label.Font = Enum.Font.GothamBold
							label.TextSize = 13
							label.TextColor3 = Color3.fromRGB(255, 226, 170)
							label.TextStrokeTransparency = 0.4
							label.Text = NAMES[spec.key] or spec.key
							label.Parent = sign

							table.insert(placed, { x = x, z = z, size = spec.size })
							built += 1
							put = true
							break
						end
					end
				end
				if not put then
					L.progress(("no room for %s in %s"):format(spec.key, d.name))
				end
			end
		end
	end

	----------------------------------------------------------------------------
	-- Clear the roadway
	----------------------------------------------------------------------------

	-- Trees and rocks were scattered by the countryside phases, which ran BEFORE any of these streets
	-- existed and so had no way to avoid them. The result is a pine growing up through the middle of a
	-- bridge deck. Anything standing in the roadway now gets removed.
	local cleared = 0
	for _, holder in ipairs({ "Heartland", "Elderwood", "Villages" }) do
		local h = L.root():FindFirstChild(holder)
		if h then
			for _, group in ipairs(h:GetChildren()) do
				if group.Name == "Decor" or group.Name == "Nodes" then
					for _, m in ipairs(group:GetChildren()) do
						local pos = m:IsA("Model") and m:GetPivot().Position
							or (m:IsA("BasePart") and m.Position)
						-- Half the widest street plus its verge: a trunk this close is either in the road
						-- or overhanging it.
						if pos and toStreet(pos.X, pos.Z) < 6 then
							m:Destroy()
							cleared += 1
						end
					end
				end
			end
		end
	end

	print(("[WOLD] CityDistricts: %d plots across %d districts, %d streets, %d cleared from the road")
		:format(built, #districts, #laid, cleared))
end)
