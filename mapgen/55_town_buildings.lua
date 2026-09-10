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

-- NPCs. ONLY the shopkeeper, as asked: the smith, the mechanic, the gunsmith and the rest have no
-- systems behind them yet, and an NPC you can walk up to and get nothing from is worse than no NPC.
-- They stay in models/npcs.lua, ready for the day crafting and banking exist.
--
-- Barnaby is the one the shop system actually reads -- tagged WOLD_Npc with NpcKind="shop" below, which
-- is what Shop.server looks for.
local NPC_POSTS = {
	{ "Merchant_Barnaby", "shop", 0, -26 },
}

-- The named slimes, outside the town past the gathering ring, in town-local coordinates.
--
-- These are SPAWNER MARKERS, not models. They used to be decorative props from the modelkit -- a slime you
-- could walk through, with a prompt that did nothing -- while the only monster anyone could actually fight
-- was the plain green one. Tagged as spawners, Mobs.server builds a real monster at each: one that chases,
-- hits back, dies, and drops.
--
-- MobKind names an entry in GatherConfig.Mobs. Count is 1 because a named slime is meant to be a thing you
-- go and find, not a field of them.
local SLIME_POSTS = {
	{ "SteamSlime", 470, 120 },
	{ "PlasmaSlime", -430, 300 },
	{ "BioSlime", 180, -470 },
}

L.runPhase("TownBuildings", function(folder)
	local town = workspace.WOLD:FindFirstChild("FirstTown")
	assert(town, "FirstTown is not built -- run mapgen/50_first_town.lua first")

	-- Plots come from EITHER phase. 50_first_town cuts the small original town; 52_city_districts spreads
	-- the city across its walls. Reading both means the districts can be added without this file caring
	-- which one produced a given pad -- every plot carries a PlotKey either way, and that is all it needs.
	local plots = Instance.new("Folder")
	plots.Name = "AllPlots"
	local sources = { town:FindFirstChild("Plots") }
	local districts = workspace.WOLD:FindFirstChild("CityDistricts")
	if districts then table.insert(sources, districts:FindFirstChild("Plots")) end

	local plotList = {}
	for _, src in ipairs(sources) do
		if src then
			for _, p in ipairs(src:GetChildren()) do
				if p:IsA("BasePart") then table.insert(plotList, p) end
			end
		end
	end
	assert(#plotList > 0, "no plots found -- run 50_first_town or 52_city_districts first")

	-- the town centre, so slime posts can be given in town-local coordinates
	local plaza = town:FindFirstChild("Plaza") and town.Plaza:FindFirstChild("PlazaFloor")
	local centre = plaza and Vector3.new(plaza.Position.X, 0, plaza.Position.Z) or Vector3.new(0, 0, 0)

	-- Excludes everything the world generator built, so a ray dropped near a tree finds the ground
	-- rather than the neighbouring canopy -- a mistake that put a lake floor 240 studs in the air
	-- earlier in this project.
	local probe = RaycastParams.new()
	probe.FilterType = Enum.RaycastFilterType.Exclude
	probe.FilterDescendantsInstances = { L.root() }

	local function groundAt(x, z)
		local hit = workspace:Raycast(Vector3.new(x, 900, z), Vector3.new(0, -1400, 0), probe)
		return hit and hit.Position.Y or nil
	end

	local byKey = {}
	local houseIndex = 0
	local built, skipped = 0, {}

	for _, plot in ipairs(plotList) do
		do
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

	-- Phase 50 stands a box-and-sphere shopkeeper on the plaza as a placeholder. The real model goes in
	-- below, and two tagged shop NPCs would leave the shop system picking whichever it found first --
	-- so the placeholder goes now.
	local placeholder = town:FindFirstChild("Shopkeeper")
	if placeholder then
		placeholder:Destroy()
		L.progress("removed the placeholder shopkeeper from phase 50")
	end
	for _, post in ipairs(NPC_POSTS) do
		local name, key, ox, oz = post[1], post[2], post[3], post[4]
		local plot = byKey[key]
		if plot then
			local at = plot.CFrame * CFrame.new(ox, 0, oz)
			-- The real surface, by raycast. L.padY reads heightAt, which reports where the terrain was
			-- ASKED to go rather than where the voxels landed -- measured up to 2.3 studs out, which is
			-- enough to leave an NPC shin-deep in the ground or hovering above it.
			local ground = groundAt(at.Position.X, at.Position.Z) or L.padY(at.Position.X, at.Position.Z)
			local m = K.place(name, npcFolder, CFrame.new(at.Position.X, ground, at.Position.Z) * (plot.CFrame - plot.CFrame.Position))
			if m then
				K.tag(m, "NPC", { Post = key })
				-- The tags Shop.server actually reads. Without these the model is scenery: the shop
				-- finds its counter by tag, not by name.
				game:GetService("CollectionService"):AddTag(m, "WOLD_Npc")
				m:SetAttribute("NpcKind", "shop")
				m:SetAttribute("NpcName", "เฒ่าแก่")
			end
		end
	end
	for _, post in ipairs(SLIME_POSTS) do
		local kind, ox, oz = post[1], post[2], post[3]
		local x, z = centre.X + ox, centre.Z + oz
		local y = groundAt(x, z) or L.padY(x, z)

		local marker = Instance.new("Part")
		marker.Name = "SlimeSpawner_" .. kind
		marker.Size = Vector3.new(4, 1, 4)
		marker.CFrame = CFrame.new(x, y + 0.5, z)
		marker.Anchored = true
		marker.CanCollide = false
		marker.Transparency = 1
		marker.Parent = npcFolder
		marker:SetAttribute("MobKind", kind)
		marker:SetAttribute("Count", 1)
		marker:SetAttribute("Radius", 30)
		game:GetService("CollectionService"):AddTag(marker, "WOLD_Spawner")
	end

	if #skipped > 0 then L.progress("no model for plot keys: " .. table.concat(skipped, ", ")) end
	L.progress(("TownBuildings: %d buildings, %d NPCs, %d monsters"):format(built, #NPC_POSTS, #SLIME_POSTS))
end)
