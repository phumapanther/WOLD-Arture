-- 66_villages: the six settlements outside the capital, each built around what its people do.
--
-- Run with the modelkit and the model files loaded:
--   node tools/run-luau.js mapgen/66_villages.lua --kit --models
--
-- ONE builder, six data entries. What separates a farming village from a mining one is not the code
-- that lays it out -- it is which buildings stand on it and what is scattered between them. So the
-- layout is shared and only the flavour is per-village.
--
-- What every village gets:
--   * a green with a well at its centre
--   * hand-placed plots, never a ring. An even ring of houses reads as a dial -- the lesson
--     50_first_town already paid for.
--   * dirt lanes painted onto the terrain surface (L.paintRoad), so nothing floats on a slope
--   * its own pad cut under each building, where it stands, rather than terracing the whole hillside
--   * a Zone volume, a RespawnPoint, and the gathering nodes its trade implies
--
-- What it does NOT do: reshape the countryside. Stonemark sits on a mountainside and stays on one.
-- Only Astravale gets a shelf, because a village of towers cannot straddle a 900-stud slope.
--
-- L, K and the layout are concatenated in ahead of this file by tools/run-luau.js -- not required.

--------------------------------------------------------------------------------
-- Data
--------------------------------------------------------------------------------

-- Pad sizes, taken from the plots 50_first_town cut for the same models: the model footprint plus a
-- margin. These ARE those numbers -- restating footprints would mean two sets to keep in step.
local PAD = {
	Village_Tavern = { 156, 134 },
	Village_Workshop = { 138, 102 },
	Village_Knights = { 180, 170 },
	Village_Clinic = { 130, 94 },
	Village_ClockTower = { 76, 78 },
	House_Townhouse = { 80, 68 },
	House_Longhouse = { 158, 114 },
	House_StoneCottage = { 112, 92 },
	House_Roundhouse = { 112, 92 },
	House_PipeWorker = { 112, 92 },
}

-- Each plot: model, local x (east), local z (south), and the yaw it faces in degrees. The local origin
-- is the green. Distances are deliberately uneven and no two buildings share an axis.
local VILLAGES = {
	{
		name = "Goldmeadow", th = "หมู่บ้านเกษตร", flavour = "farm",
		green = 92, radius = 460, clear = 420,
		plots = {
			{ "Village_Tavern", 168, -74, -78 },
			{ "House_Longhouse", -232, 128, 24 },      -- the barn
			{ "House_Longhouse", -286, -96, 104 },     -- the granary, apart from the barn: fire
			{ "Village_Workshop", 302, -196, -118 },   -- the mill
			{ "House_StoneCottage", 126, 196, -28 },
			{ "House_StoneCottage", 268, 62, -96 },
			{ "House_StoneCottage", -84, 268, 16 },
			{ "House_Roundhouse", 46, -238, 158 },
			{ "House_Roundhouse", -190, -266, 122 },
		},
		lanes = { { { 0, 0 }, { 170, -70 }, { 300, -190 } }, { { 0, 0 }, { -240, 126 } },
			{ { 0, 0 }, { 60, 250 } }, { { 0, 0 }, { -180, -260 } } },
	},
	{
		-- The river runs north-south straight through the layout point, so the green stands on the east
		-- bank and the village straddles the water. Offset here rather than moved in the layout file:
		-- the layout says where Cogsworth is, this says where its market happens to sit.
		name = "Cogsworth", th = "เมืองช่างกล", flavour = "engineer", offset = { 170, 0 },
		green = 84, radius = 520, clear = 460,
		plots = {
			{ "Village_Workshop", 60, -128, -72 },
			{ "House_PipeWorker", 24, 156, -18 },
			{ "House_PipeWorker", 176, 34, -96 },
			{ "Village_Tavern", 118, -268, -60 },
			{ "House_Townhouse", -18, 286, -10 },
			{ "Village_Workshop", -404, 62, 92 },      -- the mill on the far bank, at the water
			{ "House_PipeWorker", -436, -146, 120 },
			{ "House_PipeWorker", -336, -292, 146 },
			{ "House_Townhouse", -474, 232, 58 },
		},
		lanes = { { { 0, 0 }, { 60, -140 }, { 120, -260 } }, { { 0, 0 }, { 20, 270 } },
			{ { 0, 0 }, { -170, 0 }, { -400, 60 } }, { { -170, 0 }, { -340, -280 } } },
	},
	{
		name = "Stonemark", th = "หมู่บ้านเหมือง", flavour = "mine",
		green = 78, radius = 360, clear = 340,
		plots = {
			{ "Village_Tavern", 152, -66, -74 },
			{ "Village_Workshop", -196, 84, 96 },
			{ "Village_Clinic", -150, -196, 128 },
			{ "House_StoneCottage", 96, 170, -26 },
			{ "House_StoneCottage", 242, 54, -92 },
			{ "House_StoneCottage", -66, 236, 14 },
			{ "House_StoneCottage", 40, -232, 162 },
			{ "House_Roundhouse", -256, -60, 108 },
		},
		lanes = { { { 0, 0 }, { 150, -70 } }, { { 0, 0 }, { -200, 90 } },
			{ { 0, 0 }, { -60, 230 } }, { { 0, 0 }, { 40, -230 } } },
	},
	{
		-- Shifted 300 studs down the beach from the layout point, which sits 600 studs inland. A fishing
		-- village that cannot see the sea is a farm with boats.
		name = "Saltmere", th = "หมู่บ้านชาวประมง", flavour = "fishing", offset = { 0, 300 },
		green = 86, radius = 440, clear = 400,
		plots = {
			{ "Village_Tavern", 150, -80, -76 },
			{ "House_Longhouse", -226, 60, 100 },      -- the net store
			{ "House_Roundhouse", 106, 172, -30 },
			{ "House_Roundhouse", 258, 30, -98 },
			{ "House_Roundhouse", -96, 206, 18 },
			{ "House_Roundhouse", -278, -156, 124 },
			{ "House_StoneCottage", 36, -238, 160 },
			{ "House_StoneCottage", 276, -196, -120 },
		},
		lanes = { { { 0, 0 }, { 150, -80 }, { 270, -190 } }, { { 0, 0 }, { -230, 66 } },
			{ { 0, 0 }, { 90, 190 } }, { { 0, 0 }, { -270, -150 } } },
	},
	{
		-- The one village that gets a shelf cut for it. It stands at 1170 studs on ground that falls 900
		-- studs across the site, and towers cannot be terraced one plot at a time.
		name = "Astravale", th = "หมู่บ้านนักเวท", flavour = "mage", shelf = 280,
		green = 80, radius = 340, clear = 320,
		plots = {
			{ "Village_ClockTower", 130, -132, -40 },  -- the arcane tower
			{ "Village_Clinic", -178, 96, 92 },        -- the library
			{ "House_Townhouse", 92, 152, -28 },
			{ "House_Townhouse", 232, 36, -94 },
			{ "House_Townhouse", -70, 214, 16 },
			{ "House_StoneCottage", -238, -84, 116 },
			{ "House_StoneCottage", 30, -230, 158 },
		},
		lanes = { { { 0, 0 }, { 128, -130 } }, { { 0, 0 }, { -180, 100 } },
			{ { 0, 0 }, { 60, 200 } }, { { 0, 0 }, { -230, -80 } } },
	},
	{
		name = "Elderwood", th = "หมู่บ้านตัดไม้", flavour = "lumber",
		green = 88, radius = 400, clear = 380,
		plots = {
			{ "Village_Workshop", 176, -70, -76 },     -- the sawmill
			{ "Village_Tavern", -204, 110, 92 },
			{ "House_Longhouse", -258, -126, 116 },
			{ "House_Roundhouse", 110, 180, -30 },
			{ "House_Roundhouse", 252, 44, -96 },
			{ "House_Roundhouse", -80, 244, 14 },
			{ "House_StoneCottage", 40, -240, 160 },
		},
		lanes = { { { 0, 0 }, { 175, -75 } }, { { 0, 0 }, { -205, 115 } },
			{ { 0, 0 }, { 80, 210 } }, { { 0, 0 }, { -250, -120 } } },
	},
}

local MAT = L.MAT
local C = L.C

--------------------------------------------------------------------------------
-- The trade of each village: what stands between the houses.
--
-- Each takes the context the builder hands it and adds parts to ctx.folder. They are the only
-- per-village code in the file.
--------------------------------------------------------------------------------

local FLAVOUR = {}

-- Goldmeadow. Ploughed strips and fences on the open ground north-west of the green, hay in the yards,
-- and DigSpot nodes in the furrows for the gathering system.
function FLAVOUR.farm(ctx)
	local cx, cz, rng = ctx.cx, ctx.cz, ctx.rng
	local m = L.model(ctx.folder, "Fields")

	-- Six strips, each a run of painted furrows. Strips rather than one block: a field is worked in
	-- lands, and parallel lines at slightly different angles read as worked ground rather than as a mat.
	for s = 1, 6 do
		local ang = math.rad(28 + s * 3)
		local ox = -520 + s * 110
		local oz = 260 + math.sin(s) * 60
		for f = -3, 3 do
			local px = cx + ox + math.cos(ang + math.pi / 2) * f * 16
			local pz = cz + oz + math.sin(ang + math.pi / 2) * f * 16
			local a = Vector3.new(px - math.cos(ang) * 130, 0, pz - math.sin(ang) * 130)
			local b = Vector3.new(px + math.cos(ang) * 130, 0, pz + math.sin(ang) * 130)
			L.paintRoad(a, b, 12, MAT.Ground)
		end
		-- A rail fence down one edge, so a strip has a boundary a player can see.
		local fx = cx + ox + math.cos(ang + math.pi / 2) * 4 * 16
		local fz = cz + oz + math.sin(ang + math.pi / 2) * 4 * 16
		for t = -130, 130, 26 do
			local px, pz = fx + math.cos(ang) * t, fz + math.sin(ang) * t
			local y = ctx.groundAt(px, pz)
			L.cyl(m, CFrame.new(px, y + 5, pz), 0.8, 10, MAT.Wood, C.wood, { name = "FencePost" })
			if t < 130 then
				local nx, nz = fx + math.cos(ang) * (t + 26), fz + math.sin(ang) * (t + 26)
				local ny = ctx.groundAt(nx, nz)
				for h = 3, 7, 4 do
					L.rod(m, Vector3.new(px, y + h, pz), Vector3.new(nx, ny + h, nz), 0.5, MAT.Wood, C.plank,
						{ name = "FenceRail", cancollide = false })
				end
			end
		end
		local dx, dz = cx + ox, cz + oz
		L.marker(m, "DigSpot", dx, ctx.groundAt(dx, dz), dz, { GatherType = "Digging", Resource = "Crop" })
		task.wait()
	end

	-- Haystacks and a cart, in the yard between the barn and the granary.
	for i = 1, 5 do
		local a = rng:NextNumber(0, 6.28)
		local hx = cx - 250 + math.cos(a) * rng:NextNumber(40, 120)
		local hz = cz + 20 + math.sin(a) * rng:NextNumber(40, 120)
		local y = ctx.groundAt(hx, hz)
		local stack = L.cyl(m, CFrame.new(hx, y + 7, hz), 11, 14, MAT.Grass, Color3.fromRGB(178, 148, 88),
			{ name = "Haystack" })
		K.roofCone(m, CFrame.new(hx, y + 14, hz), 11, 9, MAT.Grass, Color3.fromRGB(164, 134, 76), 4)
		L.tag(stack, "SearchPoint", { GatherType = "Searching" })
	end
end

-- Cogsworth. A bridge across the river at the green, a mill wheel turning in the water on the far bank,
-- and the pressure gear the town is named for stacked against the workshops.
function FLAVOUR.engineer(ctx)
	local cx, cz = ctx.cx, ctx.cz
	local m = L.model(ctx.folder, "Works")

	-- Where the water ACTUALLY is, found by walking west from the green and asking the ground what it is
	-- made of. L.riverAt reports the channel the layout asked for; the voxels are up to 40 studs off it,
	-- which is the difference between a wheel turning in the current and a wheel standing in a field.
	local function channelAt(z)
		local west, east
		for s = 0, 700, 4 do
			local h = ctx.hitAt(cx - s, z)
			if h and h.Material == MAT.Water then
				east = east or cx - s
				west = cx - s
			elseif east then
				break
			end
		end
		return west, east
	end

	local west, east = channelAt(cz)
	if not west then
		L.progress("Cogsworth: no water found west of the green -- no bridge, no wheel")
		return
	end
	local rx = (west + east) / 2
	local width = east - west
	local _, waterY = L.riverAt(rx, cz)
	local deckY = math.floor(math.max(ctx.groundAt(west - 40, cz), ctx.groundAt(east + 40, cz), waterY + 7) / 2) * 2
	L.woodBridge(m, rx, cz, Vector3.new(1, 0, 0), width + 90, 24, deckY, waterY, false)
	for s = -1, 1, 2 do
		K.lantern(m, CFrame.new(rx + s * (width / 2 + 30), deckY + 8, cz + 11), 4, C.brass)
	end

	-- The mill: a wheel in the current against the west bank, with its house on the dry ground behind it.
	-- The channel is measured again 40 studs downstream, because the river moves between the two.
	local mwest, meast = channelAt(cz + 40)
	if mwest then
		local my = waterY + 12
		K.paddleWheel(m, CFrame.new(mwest + 10, my, cz + 40) * K.yaw(math.rad(90)), 22, 10, 10)
		local hx = mwest - 26
		L.box(m, CFrame.new(hx, ctx.groundAt(hx, cz + 40) + 9, cz + 40), Vector3.new(22, 18, 16), MAT.Wood,
			C.wood, { name = "MillHouse" })
	end

	-- Boiler yard beside the east workshop: a tank, a stack and the pipe run between them.
	local bx, bz = cx + 130, cz - 160
	local by = ctx.groundAt(bx, bz)
	K.boiler(m, CFrame.new(bx, by + 11, bz), 9, 22, {})   -- K.boiler CENTRES; the base is half a boiler down
	K.smokestack(m, CFrame.new(bx + 26, by, bz + 6), 5, 46, {})
	K.pipe(m, { Vector3.new(bx + 8, by + 16, bz), Vector3.new(bx + 20, by + 16, bz + 3),
		Vector3.new(bx + 26, by + 10, bz + 6) }, 1.6, C.copper)
	K.valveWheel(m, CFrame.new(bx + 10, by + 20, bz) * K.yaw(math.rad(90)), 4, 6, C.brass)
	K.gauge(m, CFrame.new(bx, by + 24, bz - 9.4) * K.yaw(math.pi), 3, C.brass)

	-- Spare gears leaning against the yard wall, because a works has spares.
	for i = 1, 4 do
		local gx, gz = bx - 30 - i * 13, bz + 8 + (i % 2) * 9
		local gy = ctx.groundAt(gx, gz)
		K.gear(m, CFrame.new(gx, gy + 9, gz) * K.yaw(math.rad(90)) * K.pitch(math.rad(8)),
			9 - i * 0.8, 12, 1.6, C.brassDark)
	end
	for i = 1, 3 do
		local kx, kz = cx + 40 + i * 18, cz + 110
		local ky = ctx.groundAt(kx, kz)
		local crate = K.crate(m, CFrame.new(kx, ky, kz) * K.yaw(i * 0.7), 10, C.plank)
		L.tag(crate, "SearchPoint", { GatherType = "Searching" })
	end
end

-- Stonemark. A timber headframe over the shaft, rails running out to the spoil heaps, and ore at the
-- rock face for the mining system to find.
function FLAVOUR.mine(ctx)
	local cx, cz, rng = ctx.cx, ctx.cz, ctx.rng
	local m = L.model(ctx.folder, "Mine")

	-- The head of the shaft sits uphill of the green: a mine follows the rock, and the rock is up.
	local hx, hz = cx + 60, cz - 300
	local hy = ctx.groundAt(hx, hz)
	L.flattenDisc(hx, hz, 90, math.floor(hy / 2) * 2, MAT.Ground)
	hy = ctx.groundAt(hx, hz)

	-- Four legs leaning in to a head, with the winding wheel between them. Not a box: a headframe is a
	-- shape people recognise, and the taper is the whole of it.
	local H = 54
	for _, s in ipairs({ { -1, -1 }, { 1, -1 }, { 1, 1 }, { -1, 1 } }) do
		local ax = hx + s[1] * 20
		local az = hz + s[2] * 20
		L.rod(m, Vector3.new(ax, ctx.groundAt(ax, az), az), Vector3.new(hx + s[1] * 7, hy + H, hz + s[2] * 7),
			1.6, MAT.Wood, C.wood, { name = "HeadframeLeg" })
	end
	for lvl = 0.35, 0.9, 0.28 do
		for _, s in ipairs({ { -1, -1, 1, -1 }, { 1, -1, 1, 1 }, { 1, 1, -1, 1 }, { -1, 1, -1, -1 } }) do
			local t = 20 - 13 * lvl
			L.rod(m, Vector3.new(hx + s[1] * t, hy + H * lvl, hz + s[2] * t),
				Vector3.new(hx + s[3] * t, hy + H * lvl, hz + s[4] * t), 0.9, MAT.Wood, C.plankDark,
				{ cancollide = false })
		end
	end
	K.gear(m, CFrame.new(hx, hy + H + 6, hz) * K.yaw(math.rad(90)), 13, 16, 2.4, C.iron)
	K.chain(m, Vector3.new(hx, hy + H + 6, hz), Vector3.new(hx, hy + 4, hz), 14, 0.6, C.iron)

	-- The mouth of the shaft, timbered, going into the hill.
	local px, pz = hx, hz + 34
	local py = ctx.groundAt(px, pz)
	for s = -1, 1, 2 do
		L.box(m, CFrame.new(px + s * 11, py + 11, pz), Vector3.new(3, 22, 3), MAT.Wood, C.wood)
	end
	L.box(m, CFrame.new(px, py + 23, pz), Vector3.new(26, 3, 4), MAT.Wood, C.wood)
	L.box(m, CFrame.new(px, py + 10, pz + 3), Vector3.new(20, 20, 3), MAT.Slate, Color3.fromRGB(28, 26, 26),
		{ name = "ShaftMouth" })

	-- Rails from the mouth to the spoil, with a cart standing on them.
	for s = 0, 200, 4 do
		local rx2, rz2 = px, pz + s
		local ry = ctx.groundAt(rx2, rz2)
		for side = -1, 1, 2 do
			L.box(m, CFrame.new(rx2 + side * 3.5, ry + 0.6, rz2), Vector3.new(1.2, 1.2, 4.2), MAT.Metal, C.iron,
				{ name = "Rail", cancollide = false })
		end
		if s % 16 == 0 then
			L.box(m, CFrame.new(rx2, ry + 0.3, rz2), Vector3.new(11, 1, 2.4), MAT.Wood, C.plankDark,
				{ cancollide = false })
		end
	end
	do
		local cyx, cyz = px, pz + 120
		local cyy = ctx.groundAt(cyx, cyz)
		local cart = L.model(m, "OreCart")
		L.box(cart, CFrame.new(cyx, cyy + 6, cyz), Vector3.new(10, 8, 14), MAT.Metal, C.rust, { name = "CartBody" })
		for _, s in ipairs({ { -1, -1 }, { 1, -1 }, { 1, 1 }, { -1, 1 } }) do
			L.cyl(cart, CFrame.new(cyx + s[1] * 5, cyy + 2, cyz + s[2] * 5) * CFrame.Angles(0, 0, math.rad(90)),
				2.4, 1.4, MAT.Metal, C.iron, { cancollide = false })
		end
	end

	-- Spoil heaps, and ore at the face. The tags are what the gathering system reads.
	for i = 1, 7 do
		local a = rng:NextNumber(0, 6.28)
		local sx = px + math.cos(a) * rng:NextNumber(60, 210)
		local sz = pz + 60 + math.sin(a) * rng:NextNumber(40, 150)
		local sy = ctx.groundAt(sx, sz)
		L.ball(m, CFrame.new(sx, sy + 2, sz), Vector3.new(rng:NextNumber(14, 26), rng:NextNumber(6, 11),
			rng:NextNumber(14, 26)), MAT.Rock, Color3.fromRGB(84, 78, 72), { name = "Spoil" })
		local vein = L.crystal(m, Vector3.new(sx + 6, sy + 4, sz + 4), 3, Color3.fromRGB(190, 170, 110))
		L.tag(vein, "OreVein", { GatherType = "Mining", Resource = "Iron" })
	end
end

-- Saltmere. Two piers into the sea, boats tied off them, racks of drying fish, and the FishingSpot
-- markers the fishing system already knows how to read.
function FLAVOUR.fishing(ctx)
	local cx, cz, rng = ctx.cx, ctx.cz, ctx.rng
	local m = L.model(ctx.folder, "Harbour")

	for i, off in ipairs({ -150, 130 }) do
		-- Walk to the water rather than assuming where it is: the beach is not a straight line.
		local sx, sz = L.findShore(cx + off, cz, 0, 1, 1400)
		local y = math.max(ctx.groundAt(sx, sz), 2) + 3
		L.pier(m, sx, sz, Vector3.new(0, 0, 1), 150, 18, y)
		-- The FishingSpot goes at the pier HEAD, in the water, which is where a player would stand.
		L.marker(m, "FishingSpot", sx, y, sz + 140, { GatherType = "Fishing" })
		L.boat(m, sx + (i == 1 and -26 or 26), y - 2, sz + 90, math.rad(i == 1 and 8 or -12), 34)
		for p = 0, 1 do
			K.lantern(m, CFrame.new(sx - 8 + p * 16, y + 8, sz + 138), 4, C.brass)
		end
	end

	-- Drying racks and crates up on the dry ground, between the shore and the houses.
	for i = 1, 5 do
		local dx = cx - 200 + i * 90 + rng:NextNumber(-20, 20)
		local dz = cz + 190 + rng:NextNumber(-30, 30)
		local dy = ctx.groundAt(dx, dz)
		if dy > 2 then
			for s = -1, 1, 2 do
				L.cyl(m, CFrame.new(dx + s * 14, dy + 8, dz), 0.9, 16, MAT.Wood, C.wood, { name = "RackPost" })
			end
			for h = 10, 14, 4 do
				L.rod(m, Vector3.new(dx - 14, dy + h, dz), Vector3.new(dx + 14, dy + h, dz), 0.5, MAT.Wood,
					C.plank, { cancollide = false })
				for f = -10, 10, 5 do
					L.box(m, CFrame.new(dx + f, dy + h - 2.6, dz) * L.yaw(rng:NextNumber(-0.3, 0.3)),
						Vector3.new(1.4, 5, 3), MAT.SmoothPlastic, Color3.fromRGB(176, 176, 168),
						{ name = "DryingFish", cancollide = false })
				end
			end
			local crate = K.crate(m, CFrame.new(dx + 20, dy, dz + 8) * K.yaw(i * 0.6), 10, C.plank)
			L.tag(crate, "SearchPoint", { GatherType = "Searching" })
		end
	end
end

-- Astravale. A rune circle on the green, standing stones that hold their crystals off the ground, and
-- the light that comes off both after dark.
function FLAVOUR.mage(ctx)
	local cx, cz, rng = ctx.cx, ctx.cz, ctx.rng
	local m = L.model(ctx.folder, "Rites")
	-- ON TOP of the green, not level with the ground it was cut into. The cobble disc is 4 studs thick
	-- and centred 1.6 up, so anything laid at ground level is inside it -- which is where the first
	-- version of this circle went, invisible.
	local y = ctx.y + 3.6

	-- The circle is cut into the green rather than laid on it: a ring of dark slabs, with runes between.
	for i = 0, 23 do
		local a = i * math.pi / 12
		local px, pz = cx + math.cos(a) * 62, cz + math.sin(a) * 62
		L.box(m, CFrame.new(px, y + 0.9, pz) * L.yaw(-a), Vector3.new(9, 1.2, 16), MAT.Slate,
			Color3.fromRGB(56, 54, 64), { name = "CircleSlab", cancollide = false })
		if i % 3 == 0 then
			local r = L.box(m, CFrame.new(px, y + 1.4, pz) * L.yaw(-a), Vector3.new(4, 0.6, 7), MAT.Neon,
				Color3.fromRGB(140, 180, 255), { name = "Rune", cancollide = false })
			local light = Instance.new("PointLight")
			light.Color = Color3.fromRGB(140, 180, 255); light.Range = 22; light.Brightness = 1.2
			light.Parent = r
		end
	end

	-- Standing stones outside the circle, each carrying a crystal that floats a little clear of its top.
	-- Floating is the point: it is the one thing in this village that could not have been built by hand.
	for i = 1, 7 do
		local a = rng:NextNumber(0, 6.28)
		local d = rng:NextNumber(120, 300)
		local px, pz = cx + math.cos(a) * d, cz + math.sin(a) * d
		local py = ctx.groundAt(px, pz)
		local h = rng:NextNumber(22, 40)
		L.box(m, CFrame.new(px, py + h / 2, pz) * L.yaw(rng:NextNumber(0, 3)) * CFrame.Angles(
			math.rad(rng:NextNumber(-4, 4)), 0, math.rad(rng:NextNumber(-4, 4))),
			Vector3.new(rng:NextNumber(7, 11), h, rng:NextNumber(5, 8)), MAT.Slate,
			Color3.fromRGB(74, 72, 84), { name = "StandingStone" })
		local crystal = L.crystal(m, Vector3.new(px, py + h + 10, pz), rng:NextNumber(3, 6))
		L.tag(crystal, "OreVein", { GatherType = "Mining", Resource = "Crystal" })
	end
end

-- Elderwood. A sawmill yard: felled logs, sawn stacks, the stumps they came off, and the saw itself
-- driven off a shaft, because this village runs on the same steam as the rest of the world.
function FLAVOUR.lumber(ctx)
	local cx, cz, rng = ctx.cx, ctx.cz, ctx.rng
	local m = L.model(ctx.folder, "Sawmill")

	-- The yard sits beside the sawmill plot, on the far side from the green.
	local yx, yz = cx + 300, cz - 130

	-- Log piles: stacked cylinders lying along one axis, tiered so the stack narrows as it rises.
	for pile = 1, 3 do
		local bx = yx + (pile - 2) * 62
		local bz = yz + (pile % 2) * 40
		local by = ctx.groundAt(bx, bz)
		local top
		for row = 0, 2 do
			for k = 0, 3 - row do
				local ox = (k - (3 - row) / 2) * 9
				top = L.part(m, Enum.PartType.Cylinder,
					CFrame.new(bx + ox, by + 4.5 + row * 7.6, bz) * L.yaw(math.rad(90)),
					Vector3.new(42, 8.4, 8.4), MAT.Wood, C.trunk, { name = "Log" })
			end
		end
		if top then L.tag(top, "SearchPoint", { GatherType = "Searching" }) end
	end

	-- Sawn timber, squared off, in the other half of the yard.
	for s = 1, 4 do
		local bx, bz = yx - 40, yz + 90 + s * 16
		local by = ctx.groundAt(bx, bz)
		for lvl = 0, 3 do
			L.box(m, CFrame.new(bx, by + 2 + lvl * 4.2, bz), Vector3.new(46, 4, 13), MAT.WoodPlanks,
				C.plank, { name = "SawnTimber" })
		end
	end

	-- The saw: a blade on a shaft, with the gear train that drives it and a bench under it.
	local sx, sz = yx - 110, yz + 20
	local sy = ctx.groundAt(sx, sz)
	L.box(m, CFrame.new(sx, sy + 5, sz), Vector3.new(56, 10, 20), MAT.Wood, C.plankDark, { name = "SawBench" })
	K.gear(m, CFrame.new(sx, sy + 18, sz) * K.yaw(math.rad(90)), 12, 20, 1.4, C.steel)
	K.gear(m, CFrame.new(sx - 16, sy + 13, sz) * K.yaw(math.rad(90)), 6, 12, 1.8, C.brassDark)
	K.smokestack(m, CFrame.new(sx - 30, sy, sz + 12), 4, 34, {})

	-- Stumps, where the wood was taken from. Scattered outward, thicker away from the houses.
	for i = 1, 16 do
		local a = rng:NextNumber(0, 6.28)
		local d = rng:NextNumber(240, 520)
		local px, pz = cx + math.cos(a) * d, cz + math.sin(a) * d
		local py = ctx.groundAt(px, pz)
		L.cyl(m, CFrame.new(px, py + 1.6, pz), rng:NextNumber(4, 7), 3.4, MAT.Wood, C.trunk, { name = "Stump" })
	end
end

--------------------------------------------------------------------------------

return L.runPhase("Villages", function(folder)
	local rng = Random.new(66)

	-- The real surface, by raycast. L.heightAt reports where the terrain was ASKED to go, not where the
	-- voxels landed, and the ray must ignore everything the generator built -- one dropped beside a tree
	-- finds the canopy and calls it the ground.
	local probe = RaycastParams.new()
	probe.FilterType = Enum.RaycastFilterType.Exclude
	probe.FilterDescendantsInstances = { L.root() }

	local function hitAt(x, z)
		return workspace:Raycast(Vector3.new(x, 2600, z), Vector3.new(0, -4200, 0), probe)
	end
	local function groundAt(x, z)
		local h = hitAt(x, z)
		return h and h.Position.Y or L.heightAt(x, z)
	end
	local function isWet(x, z)
		local h = hitAt(x, z)
		if h and h.Material == MAT.Water then return true end
		local d, _, w = L.riverAt(x, z)
		return d <= w / 2 + 12
	end

	----------------------------------------------------------------------------
	-- 1. Clear the scatter where the villages are going
	----------------------------------------------------------------------------

	-- The forest and the countryside were planted before anyone decided where the houses go. A tree
	-- standing where a tavern is about to be is not a charming detail, it is a tavern with a tree
	-- through it. One pass over those folders, testing against every village at once -- six passes over
	-- 23,000 models to save writing one loop would be the expensive kind of lazy.
	local sites = {}
	for _, v in ipairs(VILLAGES) do
		local x, z = L.placePos(v.name)
		if v.offset then x, z = x + v.offset[1], z + v.offset[2] end
		sites[#sites + 1] = { v = v, x = x, z = z }
	end

	-- The clearing edge wanders. A village cut out of a wood with a compass leaves a circle, and a
	-- circle is the one shape that tells a player a script did this.
	local function insideAny(x, z)
		for _, s in ipairs(sites) do
			local dx, dz = x - s.x, z - s.z
			local r = s.v.clear * (0.82 + 0.3 * L.fbm(x / 900, z / 900, 66))
			if dx * dx + dz * dz < r * r then return true end
		end
		return false
	end

	local cleared = 0
	for _, phaseName in ipairs({ "Elderwood", "Heartland" }) do
		local ph = L.root():FindFirstChild(phaseName)
		if ph then
			for _, group in ipairs(ph:GetChildren()) do
				for _, thing in ipairs(group:GetChildren()) do
					if not thing:GetAttribute("Manual") then
						local ok, cf = pcall(function() return thing:GetPivot() end)
						if ok and cf and insideAny(cf.Position.X, cf.Position.Z) then
							thing:Destroy()
							cleared += 1
						end
					end
				end
				task.wait()
			end
		end
	end
	L.progress(("cleared %d scattered things from the village sites"):format(cleared))

	----------------------------------------------------------------------------
	-- 2. The villages
	----------------------------------------------------------------------------

	local built, plotted = 0, 0

	for _, site in ipairs(sites) do
		local v, cx, cz = site.v, site.x, site.z
		local vf = Instance.new("Folder")
		vf.Name = v.name
		vf.Parent = folder

		-- A shelf, only where one was asked for.
		if v.shelf then
			L.flattenDisc(cx, cz, v.shelf, math.floor(groundAt(cx, cz) / 4) * 4, MAT.Ground)
			task.wait()
		end

		L.flattenDisc(cx, cz, v.green + 30, math.floor(groundAt(cx, cz) / 2) * 2, MAT.Ground)
		local baseY = groundAt(cx, cz)

		-- The green: flat ground, a disc of cobble, and a well to stand by.
		do
			-- 4 studs thick and sunk, for the reason the plaza in 50_first_town is: Roblox grass stands
			-- about 3 studs proud, so a thin slab laid flush has grass growing through it.
			local floor = L.cyl(vf, CFrame.new(cx, baseY + 1.6, cz), v.green, 4, MAT.Cobblestone,
				Color3.fromRGB(150, 146, 138), { name = "Green" })
			floor.Anchored = true

			-- The well, off centre: dead centre reads as a target rather than as somewhere people go.
			local wx, wz = cx + v.green * 0.34, cz - v.green * 0.22
			local well = L.model(vf, "Well")
			L.cyl(well, CFrame.new(wx, baseY + 4, wz), 9, 8, MAT.Cobblestone, C.stone, { name = "WellRim" })
			L.cyl(well, CFrame.new(wx, baseY + 4.6, wz), 7.4, 7.2, MAT.Water, Color3.fromRGB(40, 70, 90),
				{ name = "WellWater", cancollide = false })
			for s = -1, 1, 2 do
				L.box(well, CFrame.new(wx + s * 8, baseY + 13, wz), Vector3.new(1.6, 18, 1.6), MAT.Wood, C.wood)
			end
			L.box(well, CFrame.new(wx, baseY + 21, wz), Vector3.new(20, 1.4, 1.4), MAT.Wood, C.wood)
			K.roofGable(well, CFrame.new(wx, baseY + 22, wz), 22, 14, 7, MAT.WoodPlanks, C.plankDark, 1)
			K.lantern(well, CFrame.new(wx + 8, baseY + 23, wz), 3, C.brass)
		end

		-- Lanes, painted onto the ground rather than laid as slabs: on a hillside a slab buries one end
		-- of itself and floats the other, and Stonemark is nothing but hillside.
		for _, lane in ipairs(v.lanes) do
			for i = 1, #lane - 1 do
				L.paintRoad(Vector3.new(cx + lane[i][1], 0, cz + lane[i][2]),
					Vector3.new(cx + lane[i + 1][1], 0, cz + lane[i + 1][2]), 16, MAT.Ground)
			end
			task.wait()
		end

		-- The buildings.
		local plots = Instance.new("Folder")
		plots.Name = "Plots"
		plots.Parent = vf

		local placedAt = {}
		for _, p in ipairs(v.plots) do
			local model, lx, lz, rot = p[1], p[2], p[3], p[4]
			local pad = PAD[model] or { 112, 92 }
			local px, pz = cx + lx, cz + lz

			-- Nudge outward until the ground is dry. A plot in the river is not a design choice, and
			-- outward from the green is always away from the water at Cogsworth: the green sits on one
			-- bank, the far-side plots on the other, and neither is pushed across.
			local dx, dz = px - cx, pz - cz
			local len = math.max(1, math.sqrt(dx * dx + dz * dz))
			for _ = 1, 8 do
				if not isWet(px, pz) then break end
				px, pz = px + dx / len * 40, pz + dz / len * 40
			end

			L.flattenRect(px, pz, pad[1] + 24, pad[2] + 24, math.floor(groundAt(px, pz) / 2) * 2, MAT.Ground)
			local y = groundAt(px, pz)

			local m = K.place(model, plots, CFrame.new(px, y, pz) * L.yaw(math.rad(rot)))
			if m then
				m.Name = model
				K.tag(m, "Building", { Village = v.name })
				built += 1
			end
			plotted += 1
			placedAt[#placedAt + 1] = { x = px, z = pz, y = y, model = model }
			task.wait()
		end
		L.progress(("%s: %d buildings"):format(v.name, #placedAt))

		-- The hooks every settlement carries.
		L.zone(vf, v.name, "village", cx, baseY, cz, v.radius)
		L.spawnPoint(vf, v.name, cx - 20, baseY + 2, cz + 20)
		do
			local sx, sz = cx - v.green * 0.5, cz + v.green * 0.5
			local post = L.model(vf, "Signpost")
			L.cyl(post, CFrame.new(sx, baseY + 9, sz), 1.4, 18, MAT.Wood, C.wood, { name = "SignPost" })
			K.sign(post, CFrame.new(sx, baseY + 16, sz) * L.yaw(math.rad(20)), v.th, 26, 8, C.plank,
				Color3.fromRGB(50, 38, 28))
		end

		-- And the part that makes it this village and not the next one.
		local flavour = FLAVOUR[v.flavour]
		if flavour then
			flavour({ folder = vf, v = v, cx = cx, cz = cz, y = baseY, rng = rng,
				groundAt = groundAt, isWet = isWet, hitAt = hitAt, placed = placedAt })
		end
		L.progress(("%s: finished"):format(v.name))
		task.wait()
	end

	print(("[WOLD] Villages: %d settlements, %d/%d buildings placed, %d scatter cleared")
		:format(#VILLAGES, built, plotted, cleared))
end)
