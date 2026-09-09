-- sample-terrain.lua: rebuilds src/ReplicatedStorage/MapTerrain.lua from the terrain as it actually is.
--
-- Run it in Studio (Edit mode is fine) after changing the world, then paste the output through the small
-- generator in the commit that added this file. The map reads the result, so a coastline that moves in the
-- world moves on the map.
--
--   node tools/mcp-call.js execute_luau {"datamodel_type":"Edit","code":"<this file>"}
--
-- Sample the real terrain by raycasting a grid: one ray per cell, straight down. Slower than ReadVoxels
-- but it has no region limit and reports exactly what a player would stand on.
local HALF = 8000
local N = 120
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
local minH, maxH = math.huge, -math.huge

for gz = 0, N - 1 do
    local row = {}
    local z = -HALF + (gz + 0.5) * STEP
    for gx = 0, N - 1 do
        local x = -HALF + (gx + 0.5) * STEP
        -- Start well ABOVE the tallest peak. The first sample started at y=500 with summits reaching 497,
        -- so the highest ground was missed entirely and the mountains came out full of holes.
        local hit = workspace:Raycast(Vector3.new(x, 2000, z), Vector3.new(0, -2600, 0), params)
        if hit then
            local h = hit.Position.Y
            local isWater = hit.Material == Enum.Material.Water
            if isWater then
                row[gx + 1] = "w0"
                water += 1
            else
                -- One letter for the material then the height, with no separator: the tool that carries
                -- this back truncates at 100KB, and "height:MaterialName" per cell overran it and silently
                -- lost the last thirteen rows.
                local mat = tostring(hit.Material):gsub("Enum.Material.", "")
                local code = MATCODE[mat] or "g"
                row[gx + 1] = code .. math.floor(h)
                land += 1
                if h < minH then minH = h end
                if h > maxH then maxH = h end
            end
        else
            row[gx + 1] = "w0" -- nothing under it at all: open sea
            miss += 1
        end
    end
    rows[gz + 1] = table.concat(row, ",")
    if gz % 15 == 0 then task.wait() end -- let the frame breathe on a big sample
end

return ("N=%d land=%d water=%d miss=%d heights %d..%d\n%s"):format(
    N, land, water, miss, minH == math.huge and 0 or minH, maxH == -math.huge and 0 or maxH,
    table.concat(rows, ";"))
