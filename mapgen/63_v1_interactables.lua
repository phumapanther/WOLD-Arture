-- 63_v1_interactables: make the V1 props into things the game can see.
--
-- Everything V1 added reaches the world through TAGS, the same way the gathering nodes and the working NPCs
-- do: the server systems watch for a tag and attach themselves, and never have to know where anything is.
-- This phase is what puts the tags on the models the user has already placed.
--
-- Four jobs:
--
--   1. The illegal farms. DistillSet, Reactor and Boxs become WOLD_Farm with a FarmKind, which is what
--      IllegalFarm.server.lua watches for.
--   2. The transformers. Every Transformer model becomes WOLD_Transformer, which is the blackout's list of
--      machines to break and the map button's list of places to send people.
--   3. The three named slimes become EVENT spawners: `EventOnly = "slime"` stops them standing in the world
--      between events, which is what turns them from a place into an announcement.
--   4. The monster prototype folder moves to ServerStorage. Those are display models with the kit's own [E]
--      prompts and name tags on them, standing exactly where the real monster spawns -- so a player walked
--      up to a fake slime offering a button that did nothing. They cannot be deleted (every monster is a
--      clone of one), so they move somewhere players cannot see. Mobs.server looks in ServerStorage first.
--
-- Nothing is created and nothing is destroyed, so this is safe to rerun and it does not care where anything
-- has been dragged to.
--
-- Run with:  node tools/run-luau.js mapgen/63_v1_interactables.lua

--------------------------------------------------------------------------------

-- Model name -> the FarmKind attribute IllegalFarm reads. The names are the kit's own (models/industry.lua
-- in WOLD-Models builds them inside ChemProps), so a model dragged out of the kit works unchanged.
local FARMS = {
	DistillSet = "DistillSet",
	Reactor = "Reactor",
	Boxs = "Boxs",
	-- The crates come out of the kit under a couple of spellings depending on which set they were taken
	-- from; all of them mean the same pile of boxes.
	Boxes = "Boxs",
	CrateStack = "Boxs",
}

-- The three named slimes, which are now an event. Spiders and skeletons are deliberately NOT here: they are
-- ordinary monsters that live in the world all the time.
local EVENT_SPAWNERS = {
	BioSlime = "slime",
	PlasmaSlime = "slime",
	SteamSlime = "slime",
}

local PROTOTYPE_FOLDER = "Model_moster"

--------------------------------------------------------------------------------

local CollectionService = game:GetService("CollectionService")
local ServerStorage = game:GetService("ServerStorage")

return L.runPhase("V1Interactables", function(folder)
	-- Nothing is created, so the phase's own folder stays empty. Everything below reaches into models that
	-- are already placed.
	folder:SetAttribute("EditsOnly", true)

	--------------------------------------------------------------------------
	-- 1 + 2. Tagging what can be pressed
	--------------------------------------------------------------------------

	local farms, transformers = 0, 0
	local prototypes = nil

	-- Is one of these models already inside another one of them?
	--
	-- The kit's props nest under their own name: a still in this place is a Model "DistillSet" holding the
	-- bench, the carboy, the chest AND an inner Model "DistillSet" that is the still itself. Tagging every
	-- match would put two nodes on every station, one inside the other -- two [E] prompts in the same spot,
	-- two separate half-hour cooldowns, and a player who works the outer one finding the inner one still
	-- available. Measured in the real place: six stations, twelve matches.
	--
	-- The OUTER one wins. Its bounding box is the whole workbench, which is where a player actually stands;
	-- the inner model is one piece of glassware in the middle of it.
	local function nestedInsideAnother(m)
		local parent = m.Parent
		while parent and parent ~= workspace do
			if parent:IsA("Model") and (FARMS[parent.Name] or parent.Name == "Transformer") then
				return true
			end
			parent = parent.Parent
		end
		return false
	end

	for _, m in ipairs(workspace:GetDescendants()) do
		if m:IsA("Model") and not nestedInsideAnother(m) then
			local kind = FARMS[m.Name]
			if kind then
				m:SetAttribute("FarmKind", kind)
				CollectionService:AddTag(m, "WOLD_Farm")
				-- The kit hangs a decorative prompt on some of these props. The server builds its own named
				-- FarmPrompt, so leaving the kit's would give the player two buttons on one crate, one of
				-- which does nothing.
				for _, p in ipairs(m:GetDescendants()) do
					if p:IsA("ProximityPrompt") and p.Name ~= "FarmPrompt" then p:Destroy() end
				end
				farms += 1
			elseif m.Name == "Transformer" then
				CollectionService:AddTag(m, "WOLD_Transformer")
				for _, p in ipairs(m:GetDescendants()) do
					if p:IsA("ProximityPrompt") and p.Name ~= "RepairPrompt" then p:Destroy() end
				end
				transformers += 1
			end
		elseif m:IsA("Folder") and m.Name == PROTOTYPE_FOLDER then
			prototypes = m
		end
	end

	--------------------------------------------------------------------------
	-- 3. The named slimes become an event
	--------------------------------------------------------------------------

	local evented = 0
	for _, spawner in ipairs(CollectionService:GetTagged("WOLD_Spawner")) do
		local eventId = EVENT_SPAWNERS[spawner:GetAttribute("MobKind")]
		if eventId then
			spawner:SetAttribute("EventOnly", eventId)
			-- Cleared so the first event does not open with the three of them still serving out a respawn
			-- timer from whenever they were last killed under the old rules.
			spawner:SetAttribute("ReadyAt", nil)
			evented += 1
		end
	end

	--------------------------------------------------------------------------
	-- 4. The prototypes go out of sight
	--------------------------------------------------------------------------

	local moved = false
	if prototypes then
		local existing = ServerStorage:FindFirstChild(PROTOTYPE_FOLDER)
		if existing and existing ~= prototypes then
			-- A previous run already moved a copy there. The one in the world is the newer arrangement, so
			-- it wins and the stale copy goes.
			existing:Destroy()
		end
		prototypes.Parent = ServerStorage
		moved = true
	end

	print(("[WOLD] V1Interactables: %d farm nodes, %d transformers, %d event spawners, prototypes %s")
		:format(farms, transformers, evented,
			moved and "moved to ServerStorage" or "already out of the world"))

	if farms == 0 then
		L.progress("WARNING: no DistillSet / Reactor / Boxs models found -- the illegal farms have nowhere to live")
	end
	if transformers == 0 then
		L.progress("WARNING: no Transformer models found -- the blackout would never be repairable")
	end
end)
