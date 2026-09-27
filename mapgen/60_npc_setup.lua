-- 60_npc_setup: make the placed NPCs behave like NPCs.
--
-- The kit's NPC models are built to LOOK right, not to work: a name tag readable from the far side of the
-- map, and a ProximityPrompt whose text describes a shop but which is wired to nothing. Two fixes:
--
--   1. Every name tag gets a distance cap, so a name is something you read by walking up to someone rather
--      than a label hanging over the hills. BillboardGui with no MaxDistance is visible at ANY range, and
--      AlwaysOnTop draws it straight through the terrain.
--
--   2. The villagers who actually do something get tagged WOLD_Npc with an NpcKind, which is what the
--      systems look for: Barnaby is "shop" for Shop.server.lua, Brannoc is "smith" for Crafting.server.lua.
--      Until this ran nothing in the world carried that tag, so those systems had nobody to attach to and
--      the prompts on the models were pure decoration.
--
-- This phase EDITS what is already placed rather than placing anything, so it is safe to rerun and it does
-- not care where the user dragged anyone.
--
-- Run with:  node tools/run-luau.js mapgen/60_npc_setup.lua

--------------------------------------------------------------------------------

-- Matches R.NAMETAG_DISTANCE in modelkit/rig.lua, which is the fix for models built from here on.
local NAMETAG_DISTANCE = 40

-- Who does a job. Keyed by the model name the kit builds, so dragging the model anywhere still works. `kind`
-- is the NpcKind attribute the matching server system watches for.
local WORKERS = {
	Merchant_Barnaby = { kind = "shop", name = "บาร์นาบี" },
	Blacksmith_Brannoc = { kind = "smith", name = "แบรนน็อค" },
	-- V0.5: the banker who also keeps a warehouse, and the man who keeps everyone's vehicles.
	Madam_Aurelia = { kind = "bank", name = "มาดามออเรเลีย" },
	Baron_Vane = { kind = "vehicle", name = "บารอนเวน" },
	-- สมาคมแคลน: รายชื่อแคลน อันดับ และแคลนของตัวเอง
	Guild_Elina = { kind = "guild", name = "เอลิน่า" },
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
	-- The villagers with a job
	--------------------------------------------------------------------------

	-- The prompts the working systems add for themselves. Named here so the cleanup below can tell a live
	-- prompt from the kit's dead one and leave it alone -- rerunning this phase in a running game would
	-- otherwise strip the button the server just built.
	local LIVE_PROMPTS = { ShopPrompt = true, CraftPrompt = true, VaultPrompt = true, VehiclePrompt = true,
		GuildPrompt = true, StoryPrompt = true } -- GuildPrompt: สมาคม (Clans.server) เดิมโดนลบถ้ารันเฟสนี้ซ้ำ (QA 2026-09-26) · StoryPrompt: NPC เนื้อเรื่อง (Story.server)

	local workers, cleaned = 0, 0
	for _, m in ipairs(workspace:GetDescendants()) do
		if m:IsA("Model") then
			local spec = WORKERS[m.Name]
			if spec then
				-- The decorative prompt the kit builds: its text promises a shop or a forge and it is
				-- connected to nothing. The server adds its own working prompt, so leaving this one would
				-- give the player two buttons on one villager, one of which does nothing.
				for _, p in ipairs(m:GetDescendants()) do
					if p:IsA("ProximityPrompt") and not LIVE_PROMPTS[p.Name] then
						p:Destroy()
						cleaned += 1
					end
				end

				m:SetAttribute("NpcKind", spec.kind)
				m:SetAttribute("NpcName", spec.name)
				-- The tag is the part that matters: the server systems watch for it, and add their prompt
				-- the moment it appears -- in a running game, without this phase being involved.
				CollectionService:AddTag(m, "WOLD_Npc")
				workers += 1
			end
		end
	end

	print(("[WOLD] NpcSetup: %d name tags capped at %d studs, %d working NPCs tagged, %d dead prompts removed")
		:format(capped, NAMETAG_DISTANCE, workers, cleaned))
end)
