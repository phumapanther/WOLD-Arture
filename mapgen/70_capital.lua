-- 70_capital: the walls of Brasshaven and Ironcrest Keep on its hill.
--
-- Built from layout.capital rather than from numbers typed here, so moving the wall in the layout moves it
-- on the ground. The polygon, the height, the thickness and the tower spacing all come from the file.
--
-- Run with the modelkit loaded:
--   node tools/run-luau.js mapgen/70_capital.lua --kit
--
-- Two things, in this order:
--   1. the curtain wall around the city, with towers along it and gates where the roads come in
--   2. the keep on Crown Hill -- inner wall, corner towers, gatehouse, great hall, courtyard
--
-- What it does NOT do: reshape the ground. The hill Crown Hill already is stays as it is, and the wall
-- follows whatever the terrain does under it, which is why every segment measures its own footing.

--------------------------------------------------------------------------------
-- The city wall
--------------------------------------------------------------------------------

local WALL_MAT = Enum.Material.Cobblestone
local WALL_COLOUR = Color3.fromRGB(146, 142, 134)
local TRIM_COLOUR = Color3.fromRGB(118, 114, 108)
local ROOF_COLOUR = Color3.fromRGB(92, 74, 66)

-- Where the roads and the river meet the wall, as a fraction along the polygon's perimeter. A gate is cut
-- at each, and the wall simply stops either side of it.
--
-- Taken as fractions rather than coordinates because the polygon is what the layout owns: if it moves,
-- the gates stay at the same relative points on it rather than floating in a field.
local GATES = { 0.06, 0.30, 0.55, 0.82 }
local GATE_WIDTH = 130

return L.runPhase("Capital", function(folder)
	local Y = L.LAYOUT
	local cap = Y.capital
	assert(cap and cap.wall, "layout.capital.wall is missing")

	local HALF = L.HALF
	local WALL_H = cap.wall.height
	local WALL_T = cap.wall.thickness
	local TOWER_EVERY = cap.wall.tower_spacing

	-- The real surface, by raycast: L.heightAt reports where the terrain was ASKED to go, not where the
	-- voxels landed, and the wall has to sit on the ground people walk on.
	local probe = RaycastParams.new()
	probe.FilterType = Enum.RaycastFilterType.Exclude
	probe.FilterDescendantsInstances = { L.root() }

	local function groundAt(x, z)
		local hit = workspace:Raycast(Vector3.new(x, 1200, z), Vector3.new(0, -2000, 0), probe)
		return hit and hit.Position.Y or L.heightAt(x, z)
	end

	----------------------------------------------------------------------------

	-- The polygon in world studs, closed.
	local pts = {}
	for _, p in ipairs(cap.wall.polygon) do
		table.insert(pts, Vector2.new(p[1] * HALF, p[2] * HALF))
	end
	table.insert(pts, pts[1])

	-- Perimeter, so gates can be placed by fraction along it.
	local segLen, total = {}, 0
	for i = 1, #pts - 1 do
		local d = (pts[i + 1] - pts[i]).Magnitude
		segLen[i] = d
		total += d
	end

	-- Is this distance along the perimeter inside a gateway?
	local function inGate(dist)
		for _, g in ipairs(GATES) do
			local at = g * total
			if math.abs(dist - at) < GATE_WIDTH / 2 then return true end
		end
		return false
	end

	local wallFolder = Instance.new("Folder")
	wallFolder.Name = "CityWall"
	wallFolder.Parent = folder

	-- The wall is laid as short blocks along each edge, each sitting on its own footing. One long part per
	-- edge would bury an end wherever the ground rises, and float wherever it falls.
	local STEP = 26
	local blocks, towers, gates = 0, 0, 0
	local walked = 0

	for i = 1, #pts - 1 do
		local a, b = pts[i], pts[i + 1]
		local dir = (b - a).Unit
		local length = segLen[i]
		local heading = math.atan2(dir.X, dir.Y)

		local n = math.max(1, math.floor(length / STEP))
		for k = 0, n - 1 do
			local t = (k + 0.5) / n
			local p = a + (b - a) * t
			local here = walked + length * t

			if not inGate(here) then
				local y = groundAt(p.X, p.Y)
				-- Sunk 4 studs so the base never shows daylight under it on uneven ground.
				local h = WALL_H + 4
				K.box(wallFolder, CFrame.new(p.X, y + h / 2 - 4, p.Y) * CFrame.Angles(0, heading, 0),
					Vector3.new(WALL_T, h, STEP + 2), WALL_MAT, WALL_COLOUR, { name = "Wall" })
				-- The parapet: a thinner run on top, so the wall reads as something with a walkway.
				K.box(wallFolder, CFrame.new(p.X, y + h - 4 + 1.6, p.Y) * CFrame.Angles(0, heading, 0),
					Vector3.new(WALL_T * 0.45, 3.2, STEP + 2), WALL_MAT, TRIM_COLOUR, { name = "Parapet" })
				blocks += 1
			end
		end

		-- Towers along this edge, at the layout's spacing.
		local towerCount = math.floor(length / TOWER_EVERY)
		for k = 0, towerCount do
			local t = towerCount > 0 and (k / towerCount) or 0
			local p = a + (b - a) * t
			local here = walked + length * t
			if not inGate(here) then
				local y = groundAt(p.X, p.Y)
				local r, th = 16, WALL_H + 16
				-- K.cyl CENTRES on the CFrame it is given -- it does not treat it as a base. Passing the
				-- ground height directly sank every tower half its own height and left its crown, cone
				-- and banner hanging in the air by the same amount.
				local top = y - 4 + th
				K.cyl(wallFolder, CFrame.new(p.X, y - 4 + th / 2, p.Y), r, th, WALL_MAT, WALL_COLOUR,
					{ name = "Tower" })
				K.cyl(wallFolder, CFrame.new(p.X, top + 1.75, p.Y), r + 2.5, 3.5, WALL_MAT, TRIM_COLOUR,
					{ name = "TowerCrown" })
				-- roofCone's base IS at its CFrame (see the reference's base-at-y=0 rule), so it sits on
				-- top of the crown rather than being centred like the cylinder.
				K.roofCone(wallFolder, CFrame.new(p.X, top + 3.5, p.Y), r + 1, 22,
					Enum.Material.Slate, ROOF_COLOUR, 5)
				towers += 1
			end
		end

		walked += length
	end

	-- Gatehouses: a pair of drum towers either side of each opening, so a gate reads as a way IN rather
	-- than as a hole where the wall forgot to happen.
	for _, g in ipairs(GATES) do
		local at = g * total
		-- Walk the perimeter to that distance.
		local acc = 0
		for i = 1, #pts - 1 do
			if acc + segLen[i] >= at then
				local t = (at - acc) / segLen[i]
				local a, b = pts[i], pts[i + 1]
				local p = a + (b - a) * t
				local dir = (b - a).Unit
				local heading = math.atan2(dir.X, dir.Y)

				for _, side in ipairs({ -1, 1 }) do
					local q = p + dir * (side * (GATE_WIDTH / 2 + 12))
					local y = groundAt(q.X, q.Y)
					local r, th = 20, WALL_H + 26
					local top = y - 4 + th
					K.cyl(wallFolder, CFrame.new(q.X, y - 4 + th / 2, q.Y), r, th, WALL_MAT, WALL_COLOUR,
						{ name = "GateTower" })
					K.cyl(wallFolder, CFrame.new(q.X, top + 2, q.Y), r + 3, 4, WALL_MAT, TRIM_COLOUR,
						{ name = "GateCrown" })
					K.roofCone(wallFolder, CFrame.new(q.X, top + 4, q.Y), r + 1, 26,
						Enum.Material.Slate, ROOF_COLOUR, 5)
				end

				-- The arch over the road, carried on the two towers.
				local y = groundAt(p.X, p.Y)
				K.box(wallFolder, CFrame.new(p.X, y + WALL_H + 6, p.Y) * CFrame.Angles(0, heading, 0),
					Vector3.new(WALL_T + 4, 14, GATE_WIDTH), WALL_MAT, WALL_COLOUR, { name = "GateArch" })
				gates += 1
				break
			end
			acc += segLen[i]
		end
	end

	L.progress(("Capital: wall %d blocks, %d towers, %d gates"):format(blocks, towers, gates))

	----------------------------------------------------------------------------
	-- Ironcrest Keep
	----------------------------------------------------------------------------

	local keepFolder = Instance.new("Folder")
	keepFolder.Name = "IroncrestKeep"
	keepFolder.Parent = folder

	local kx, kz = L.placePos("Ironcrest Keep")
	local baseY = groundAt(kx, kz)

	-- The inner curtain: a square wall with a tower at each corner, which is what a keep is. Square rather
	-- than following the hill, because a fortress is built, not grown.
	local KEEP_R = 150
	local KEEP_WALL_H = 44

	local corners = {
		Vector2.new(kx - KEEP_R, kz - KEEP_R), Vector2.new(kx + KEEP_R, kz - KEEP_R),
		Vector2.new(kx + KEEP_R, kz + KEEP_R), Vector2.new(kx - KEEP_R, kz + KEEP_R),
	}
	corners[5] = corners[1]

	for i = 1, 4 do
		local a, b = corners[i], corners[i + 1]
		local dir = (b - a).Unit
		local length = (b - a).Magnitude
		local heading = math.atan2(dir.X, dir.Y)
		local n = math.max(1, math.floor(length / 24))

		for k = 0, n - 1 do
			local t = (k + 0.5) / n
			local p = a + (b - a) * t
			-- The south face carries the gatehouse, so its middle is left open.
			local isGate = (i == 1 and t > 0.38 and t < 0.62)
			if not isGate then
				local y = groundAt(p.X, p.Y)
				K.box(keepFolder, CFrame.new(p.X, y + KEEP_WALL_H / 2 - 4, p.Y) * CFrame.Angles(0, heading, 0),
					Vector3.new(10, KEEP_WALL_H + 4, 26), WALL_MAT, WALL_COLOUR, { name = "KeepWall" })
				K.box(keepFolder, CFrame.new(p.X, y + KEEP_WALL_H - 2, p.Y) * CFrame.Angles(0, heading, 0),
					Vector3.new(5, 4, 26), WALL_MAT, TRIM_COLOUR, { name = "KeepParapet" })
			end
		end

		-- A drum tower on each corner, taller than the wall it joins.
		local c = corners[i]
		local y = groundAt(c.X, c.Y)
		local kth = KEEP_WALL_H + 30
		local ktop = y - 4 + kth
		K.cyl(keepFolder, CFrame.new(c.X, y - 4 + kth / 2, c.Y), 22, kth, WALL_MAT, WALL_COLOUR,
			{ name = "KeepTower" })
		K.cyl(keepFolder, CFrame.new(c.X, ktop + 2, c.Y), 25, 4, WALL_MAT, TRIM_COLOUR,
			{ name = "KeepTowerCrown" })
		K.roofCone(keepFolder, CFrame.new(c.X, ktop + 4, c.Y), 23, 34,
			Enum.Material.Slate, ROOF_COLOUR, 6)
		-- The banner hangs from the tower wall just under the crown, not out in the air above the cone.
		K.banner(keepFolder, CFrame.new(c.X, ktop - 20, c.Y - 22), 10, 18,
			Color3.fromRGB(150, 40, 44), 8)
	end

	-- The gatehouse on the south face: two square towers and an arch, facing the city below.
	do
		local gz = kz - KEEP_R
		for _, side in ipairs({ -1, 1 }) do
			local gx = kx + side * 42
			local y = groundAt(gx, gz)
			K.box(keepFolder, CFrame.new(gx, y + (KEEP_WALL_H + 22) / 2 - 4, gz),
				Vector3.new(30, KEEP_WALL_H + 26, 30), WALL_MAT, WALL_COLOUR, { name = "Gatehouse" })
			K.box(keepFolder, CFrame.new(gx, y + KEEP_WALL_H + 20, gz),
				Vector3.new(34, 4, 34), WALL_MAT, TRIM_COLOUR, { name = "GatehouseCrown" })
		end
		local y = groundAt(kx, gz)
		K.box(keepFolder, CFrame.new(kx, y + KEEP_WALL_H + 6, gz),
			Vector3.new(84, 14, 14), WALL_MAT, WALL_COLOUR, { name = "KeepArch" })
	end

	-- The great hall, standing in the courtyard behind the gate.
	do
		local hy = groundAt(kx, kz + 30)
		local w, d, h = 120, 70, 50
		K.box(keepFolder, CFrame.new(kx, hy + h / 2 - 3, kz + 30), Vector3.new(w, h + 6, d),
			WALL_MAT, WALL_COLOUR, { name = "GreatHall" })
		K.roofGable(keepFolder, CFrame.new(kx, hy + h - 3, kz + 30), w + 6, d + 6, 34,
			Enum.Material.Slate, ROOF_COLOUR, 3)
		-- Tall windows down both long sides, which is what makes a hall a hall.
		for _, side in ipairs({ -1, 1 }) do
			for k = -2, 2 do
				K.window(keepFolder,
					CFrame.new(kx + k * 26, hy + 26, kz + 30 + side * (d / 2 + 0.4))
						* CFrame.Angles(0, side > 0 and math.pi or 0, 0),
					9, 20, TRIM_COLOUR, true)
			end
		end
		K.doorway(keepFolder, CFrame.new(kx, hy, kz + 30 - d / 2 - 0.4), 14, 22,
			Color3.fromRGB(96, 68, 44), Enum.Material.WoodPlanks)
	end

	-- The courtyard floor, so the ground inside reads as a yard rather than as hillside.
	do
		local y = groundAt(kx, kz)
		K.box(keepFolder, CFrame.new(kx, y - 1.4, kz), Vector3.new(KEEP_R * 2 - 20, 3, KEEP_R * 2 - 20),
			Enum.Material.Cobblestone, Color3.fromRGB(132, 128, 122), { name = "Courtyard" })
	end

	print(("[WOLD] Capital: %d wall blocks, %d towers, %d gates, keep on Crown Hill")
		:format(blocks, towers, gates))
end)
