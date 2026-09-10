-- stow_kit_yard: move the parts yard out of the world and into ServerStorage.
--
-- Run this when the town is arranged and the yard is no longer wanted underfoot. Everything already dragged
-- OUT of the yard and placed in the town stays exactly where it is -- this moves only what is still sitting
-- in WOLD.KitYard.
--
-- In ServerStorage the models are still there to drag out again, still visible in the Explorer, and no
-- longer in the way in the viewport. Nothing in ServerStorage is ever sent to a player, so once the yard
-- lives there HideKitYard.server.lua has nothing left to do and can be deleted with it.
--
-- Run with:  node tools/run-luau.js mapgen/stow_kit_yard.lua
local ServerStorage = game:GetService("ServerStorage")

local root = workspace:FindFirstChild("WOLD")
local yard = root and root:FindFirstChild("KitYard")
if not yard then
	return "no WOLD.KitYard -- either it was already stowed, or it was deleted"
end

local models, parts = 0, 0
for _, m in ipairs(yard:GetChildren()) do
	if m:IsA("Model") then models += 1 end
end
for _, d in ipairs(yard:GetDescendants()) do
	if d:IsA("BasePart") then parts += 1 end
end

-- Replace an older stow rather than ending up with KitYard and KitYard1 side by side.
local existing = ServerStorage:FindFirstChild("KitYard")
if existing then existing:Destroy() end

yard.Parent = ServerStorage
return ("stowed %d models (%d parts) to ServerStorage.KitYard -- drag them out from the Explorer")
	:format(models, parts)
