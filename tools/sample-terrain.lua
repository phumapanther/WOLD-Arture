-- sample-terrain.lua: one BAND of the world map's ground, sampled from the terrain as it actually is.
--
-- Driven by tools/build-map-terrain.js, which calls this once per band and writes the result to
-- src/ReplicatedStorage/MapTerrain.lua. Run it after the world changes; the map reads the result, so a
-- coastline that moves in the world moves on the map.
--
-- Why bands: execute_luau truncates its answer at 100KB. The whole grid used to come back in one string,
-- which was already close to the limit at 120 cells a side and would have silently lost most of a finer one
-- -- the failure mode is missing rows at the bottom of the map, with no error anywhere. The driver replaces
-- the three numbers below and stitches the answers together.
local N = 120      -- __N__
local FROM = 1     -- __FROM__
local TO = 120     -- __TO__

local HALF = 8000
local STEP = (HALF * 2) / N

-- The map draws the LAND, so only terrain counts. Including parts meant sampling trees, buildings and --
-- as this found -- a batch of cave ore props stranded at y=2859, which reported the mountains as being
-- nearly two thousand studs tall.
local MATCODE = { Grass = "g", LeafyGrass = "f", Rock = "r", Snow = "s", Sand = "d", Basalt = "b" }

local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Include
params.FilterDescendantsInstances = { workspace.Terrain }
params.IgnoreWater = false

local rows = {}
local land, water, miss = 0, 0, 0

for gz = FROM, TO do
	local row = {}
	local z = -HALF + (gz - 0.5) * STEP
	for gx = 1, N do
		local x = -HALF + (gx - 0.5) * STEP
		-- Start well ABOVE the tallest peak. The first sample started at y=500 with summits reaching 497,
		-- so the highest ground was missed entirely and the mountains came out full of holes.
		local hit = workspace:Raycast(Vector3.new(x, 2000, z), Vector3.new(0, -2600, 0), params)
		if hit and hit.Material ~= Enum.Material.Water then
			-- One letter for the material then the height, with no separator: every byte counts against
			-- the transport limit, and "height:MaterialName" per cell overran it outright.
			local mat = tostring(hit.Material):gsub("Enum.Material.", "")
			row[gx] = (MATCODE[mat] or "g") .. math.floor(hit.Position.Y)
			land += 1
		else
			row[gx] = "w0" -- water, or nothing under it at all: open sea
			if hit then water += 1 else miss += 1 end
		end
	end
	rows[#rows + 1] = table.concat(row, ",")
	-- Let the frame breathe. A fine grid is hundreds of thousands of rays and Studio will stop responding
	-- for the whole sample without this.
	if gz % 4 == 0 then task.wait() end
end

return ("BAND %d %d %d land=%d water=%d miss=%d\n%s"):format(N, FROM, TO, land, water, miss,
	table.concat(rows, ";"))
