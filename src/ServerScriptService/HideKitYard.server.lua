-- HideKitYard (development only, delete along with the yard when the town is finished): removes
-- workspace.WOLD.KitYard the moment a server starts, so the parts yard is a Studio-only thing.
--
-- The yard is one of every model the kit can build, dropped on open ground for arranging by hand. It is
-- scaffolding: useful to look at while placing buildings, and 28,000 parts of nothing once they are placed.
--
-- Removed rather than merely hidden. Transparency and CanCollide would still ship every part to every
-- player's device and still cost the physics and render budget; deleting it costs them nothing.
--
-- This runs in Play mode too, which is what makes it a real test of the finished town: press Play and the
-- yard vanishes, exactly as it will for a player. In EDIT mode nothing here runs at all -- a Script only
-- executes when a server does -- so the yard stays put in the viewport for as long as it is needed.
local yard = workspace:FindFirstChild("WOLD") and workspace.WOLD:FindFirstChild("KitYard")
if not yard then return end

local parts = 0
for _, d in ipairs(yard:GetDescendants()) do
	if d:IsA("BasePart") then parts += 1 end
end

yard:Destroy()
print(("[WOLD] KitYard removed from the running game (%d parts). It is still there in Studio."):format(parts))
