-- 55_town_buildings — raises the actual buildings onto the plots that 50_first_town levelled.
--
-- 50_first_town builds the pads and labels; this phase drops a model onto each one. Keeping them
-- as two phases means the layout can be re-cut without rebuilding every building, and a building
-- can be swapped for another without touching the streets.
--
-- Run with the modelkit and the model files loaded:
--   node tools/run-luau.js mapgen/55_town_buildings.lua --kit --models
--
-- Each plot part carries PlotKey; that key picks the model. A plot's CFrame already holds the
-- rotation the level design chose, so the building is set down on the pad top with the pad's own
-- facing -- the front (-Z) ends up looking at the street, as intended.

local PLOT_MODEL = {
	shop = "House_Townhouse",       -- the townhouse has a shopfront and an awning on the ground floor
	inn = "Village_Tavern",
	smithy = "Village_Workshop",
	barracks = "Village_Knights",
	clinic = "Village_Clinic",
	warehouse = "House_Longhouse",  -- the byre wing and hay loft read as storage
}

-- the six house plots cycle through the three house types, so no two neighbours are the same build
local HOUSE_CYCLE = { "House_StoneCottage", "House_Roundhouse", "House_PipeWorker" }

-- NPCs: which building each one stands by, and where relative to that plot (plot-local studs)
local NPC_POSTS = {
	{ "Merchant_Barnaby", "shop", 0, -26 },
	{ "Merchant_Zael", "shop", 24, -20 },
	{ "Merchant_Grick", "warehouse", -20, -30 },
	{ "Baron_Vane", "barracks", 26, -34 },
	{ "Madam_Aurelia", "warehouse", 22, -26 },
	{ "Don_Tiberius", "inn", -30, -36 },
	{ "Blacksmith_Brannoc", "smithy", 0, -30 },
	{ "Mechanic_Lyra", "smithy", 26, -22 },
	{ "Gunsmith_Jax", "barracks", -26, -30 },
}

-- slimes belong outside the town, past the gathering ring, in town-local coordinates
local SLIME_POSTS = {
	{ "Monster_SteamSlime", 470, 120 },
	{ "Monster_PlasmaSlime", -430, 300 },
	{ "Monster_BioSlime", 180, -470 },
}

L.runPhase("TownBuildings", function(folder)
	local town = workspace.WOLD:FindFirstChild("FirstTown")
	assert(town, "FirstTown is not built -- run mapgen/50_first_town.lua first")
	local plots = town:FindFirstChild("Plots")
	assert(plots, "FirstTown has no Plots folder")

	-- the town centre, so slime posts can be given in town-local coordinates
	local plaza = town:FindFirstChild("Plaza") and town.Plaza:FindFirstChild("PlazaFloor")
	local centre = plaza and Vector3.new(plaza.Position.X, 0, plaza.Position.Z) or Vector3.new(0, 0, 0)

	local byKey = {}
	local houseIndex = 0
	local built, skipped = 0, {}

	for _, plot in ipairs(plots:GetChildren()) do
		if plot:IsA("BasePart") then
			local key = plot:GetAttribute("PlotKey")
			local name = PLOT_MODEL[key]
			if key == "house" then
				houseIndex += 1
				name = HOUSE_CYCLE[(houseIndex - 1) % #HOUSE_CYCLE + 1]
			end
			byKey[key] = byKey[key] or plot          -- first plot of each key, for placing NPCs against
			if name then
				local seat = plot.CFrame * CFrame.new(0, plot.Size.Y / 2, 0)
				local m = K.place(name, folder, seat)
				if m then
					m.Name = name .. "_" .. key .. (key == "house" and tostring(houseIndex) or "")
					K.tag(m, "Building", { PlotKey = key, PlotName = plot:GetAttribute("PlotName") })
					built += 1
					L.progress(("placed %s on %s (%d)"):format(name, key, built))
				end
			else
				skipped[#skipped + 1] = tostring(key)
			end
		end
	end

	-- The clock tower goes on the plaza, which world-layout.json says the market square should have.
	-- It stands off to one side rather than dead centre: the ruined gazebo phase 50 builds is already
	-- the orienting landmark there, and a square with both reads as one that has a history.
	if plaza then
		local towerAt = CFrame.new(plaza.Position.X + 46, plaza.Position.Y + plaza.Size.Y / 2, plaza.Position.Z - 30)
		local tower = K.place("Village_ClockTower", folder, towerAt * CFrame.Angles(0, math.rad(200), 0))
		if tower then
			K.tag(tower, "Building", { PlotKey = "clocktower", PlotName = "หอนาฬิกา" })
			built += 1
		end
	end

	-- NPCs stand in front of their building, on the ground rather than on the pad
	local npcFolder = Instance.new("Folder")
	npcFolder.Name = "TownNPCs"
	npcFolder.Parent = folder
	for _, post in ipairs(NPC_POSTS) do
		local name, key, ox, oz = post[1], post[2], post[3], post[4]
		local plot = byKey[key]
		if plot then
			local at = plot.CFrame * CFrame.new(ox, 0, oz)
			local ground = L.padY(at.Position.X, at.Position.Z)
			local m = K.place(name, npcFolder, CFrame.new(at.Position.X, ground, at.Position.Z) * (plot.CFrame - plot.CFrame.Position))
			if m then K.tag(m, "NPC", { Post = key }) end
		end
	end
	for _, post in ipairs(SLIME_POSTS) do
		local name, ox, oz = post[1], post[2], post[3]
		local x, z = centre.X + ox, centre.Z + oz
		local m = K.place(name, npcFolder, CFrame.new(x, L.padY(x, z), z))
		if m then K.tag(m, "Monster", {}) end
	end

	if #skipped > 0 then L.progress("no model for plot keys: " .. table.concat(skipped, ", ")) end
	L.progress(("TownBuildings: %d buildings, %d NPCs, %d monsters"):format(built, #NPC_POSTS, #SLIME_POSTS))
end)
