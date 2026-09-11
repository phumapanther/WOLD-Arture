-- 60_npc_setup: make the placed NPCs behave like NPCs.
--
-- The kit's NPC models are built to LOOK right, not to work: a name tag readable from the far side of the
-- map, and a ProximityPrompt whose text describes a shop but which is wired to nothing. Two fixes:
--
--   1. Every name tag gets a distance cap, so a name is something you read by walking up to someone rather
--      than a label hanging over the hills. BillboardGui with no MaxDistance is visible at ANY range, and
--      AlwaysOnTop draws it straight through the terrain.
--
--   2. Barnaby gets tagged WOLD_Npc with NpcKind="shop", which is what Shop.server.lua looks for. Until
--      now nothing in the world carried that tag, so the shop system had no shopkeeper at all and the
--      prompt on his model was pure decoration.
--
-- This phase EDITS what is already placed rather than placing anything, so it is safe to rerun and it does
-- not care where the user dragged anyone.
--
-- Run with:  node tools/run-luau.js mapgen/60_npc_setup.lua

--------------------------------------------------------------------------------

-- Matches R.NAMETAG_DISTANCE in modelkit/rig.lua, which is the fix for models built from here on.
local NAMETAG_DISTANCE = 40

-- Who runs a shop. Keyed by the model name the kit builds, so dragging the model anywhere still works.
local SHOPKEEPERS = {
	Merchant_Barnaby = { name = "บาร์นาบี" },
}

--------------------------------------------------------------------------------

local CollectionService = game:GetService("CollectionService")

return L.runPhase("NpcSetup", function(folder)
	-- Nothing is created, so the phase's own folder stays empty. Everything below reaches into the models
	-- the user has already arranged.
	folder:SetAttribute("EditsOnly", true)

	--------------------------------------------------------------------------
	-- Name tags: readable up close only
	--------------------------------------------------------------------------

	local capped = 0
	for _, d in ipairs(workspace:GetDescendants()) do
		if d:IsA("BillboardGui") and d.Name == "NameTag" then
			d.MaxDistance = NAMETAG_DISTANCE
			capped += 1
		end
	end

	--------------------------------------------------------------------------
	-- Shopkeepers
	--------------------------------------------------------------------------

	local shops, cleaned = 0, 0
	for _, m in ipairs(workspace:GetDescendants()) do
		if m:IsA("Model") then
			local spec = SHOPKEEPERS[m.Name]
			if spec then
				-- The decorative prompt the kit builds: its text promises a shop and it is connected to
				-- nothing. Shop.server adds its own working prompt, so leaving this one would give the
				-- player two buttons on one villager, one of which does nothing.
				for _, p in ipairs(m:GetDescendants()) do
					if p:IsA("ProximityPrompt") and p.Name ~= "ShopPrompt" then
						p:Destroy()
						cleaned += 1
					end
				end

				m:SetAttribute("NpcKind", "shop")
				m:SetAttribute("NpcName", spec.name)
				-- The tag is the part that matters: Shop.server watches for it, and adds the prompt itself
				-- the moment it appears -- in a running game, without this phase being involved.
				CollectionService:AddTag(m, "WOLD_Npc")
				shops += 1
			end
		end
	end

	print(("[WOLD] NpcSetup: %d name tags capped at %d studs, %d shopkeepers tagged, %d dead prompts removed")
		:format(capped, NAMETAG_DISTANCE, shops, cleaned))
end)
