-- AdminChest.server.lua: the counter behind the admin chest -- it hands out items, and nothing else.
--
-- This replaced TestChest.server.lua, which was a noble's chest that gave one of everything once a day. The
-- user asked for three changes and each of them removed a reason the old shape existed: it is for ADMINS
-- rather than nobles, only admins can even see it, and it gives what you ask for as often as you ask rather
-- than a fixed kit on a timer. What is left of the old file is the part worth keeping -- how a vehicle key
-- is minted -- and the rest is new.
--
-- The CHEST is built on each admin's own client (AdminChest.client.lua), because "only admins can see it" is
-- not something a server-side model can do: one model in the workspace is one model for everybody. Nothing
-- is lost by that -- the model was only ever a thing to walk up to, and every item it gives is granted here,
-- where the roster is checked.
local Players = game:GetService("Players")
local ServerConfig = require(game.ServerScriptService.ServerConfig)

if ServerConfig.IsLobby then return end

local ItemCatalog = require(game.ReplicatedStorage.ItemCatalog)
local Inventory = require(game.ServerScriptService.Inventory)
local AdminRoster = require(game.ServerScriptService.AdminRoster)
local Remotes = require(game.ReplicatedStorage.Remotes)

local VehicleConfig = require(game.ReplicatedStorage.Vehicle.Config)
local VehicleService = require(game.ServerScriptService.Vehicle.Service)

-- The most one press may hand over. Not a game rule -- an admin chest is meant to be generous -- but a bound
-- on the loop below, so a forged request for a billion is a slow no rather than a frozen server.
local MAX_PER_PRESS = 999

-- ItemCatalog spells the vehicle lowercase ("car"); Config.Types is keyed "Car". Matched rather than
-- capitalised by hand so a type named differently one day still lines up.
local function vehicleTypeFor(itemId)
	local item = ItemCatalog.Get(itemId)
	if not item or not item.vehicle then return nil end
	for vtype in pairs(VehicleConfig.Types) do
		if vtype:lower() == item.vehicle:lower() then return vtype end
	end
	return nil
end

Remotes.RequestAdminItem.OnServerEvent:Connect(function(player, itemId, count)
	-- The roster, every time. The chest is drawn by the client, so this is the only place the question is
	-- actually asked -- a player who never sees a chest can still fire this remote.
	if not AdminRoster.IsAdmin(player) then return end
	if type(itemId) ~= "string" then return end

	local item = ItemCatalog.Get(itemId)
	if not item then
		return Remotes.SocialNotify:FireClient(player, "error", "ไม่มีไอเทมชื่อนี้")
	end

	-- How many. Clamped rather than trusted: the number comes from a button, and a button can be made to
	-- say anything. A fraction floors, anything at or below zero means one.
	local want = 1
	if type(count) == "number" and count == count then
		want = math.clamp(math.floor(count), 1, MAX_PER_PRESS)
	end

	-- A key goes through the vehicle system, which mints the plate and puts the key in the bag with that
	-- plate in its meta. The chest never builds the item itself: doing half that job by hand is what produced
	-- keys to vehicles that did not exist, plates reading "คข 8660" that nothing could summon or register.
	--
	-- issueKey, NOT register: registering is a separate step taken at Baron Vane, and handing over a
	-- registered vehicle would put back the one-press flow the two-step rule exists to break up.
	local vtype = vehicleTypeFor(itemId)
	if vtype then
		local minted = 0
		for _ = 1, want do
			if not VehicleService.issueKey(player, vtype) then break end
			minted += 1
		end
		return Remotes.SocialNotify:FireClient(player, minted > 0 and "info" or "error",
			minted > 0 and ("ได้กุญแจ %s x%d (ยังไม่จดทะเบียน)"):format(item.name, minted)
			or "กระเป๋าเต็ม")
	end

	local given = 0
	for _ = 1, want do
		if not Inventory.AddItem(player, itemId, 1) then break end
		given += 1
	end

	Remotes.SocialNotify:FireClient(player, given > 0 and "info" or "error",
		given == 0 and "กระเป๋าเต็ม"
		or given < want and ("ได้ %s x%d (กระเป๋าเต็มก่อนครบ)"):format(item.name, given)
		or ("ได้ %s x%d"):format(item.name, given))
end)

-- Gold, from the same counter. It is not an item in the catalogue, and an admin chest that hands out every
-- object in the game but no money would send an admin to the console for the one thing they need most often.
Remotes.RequestAdminGold.OnServerEvent:Connect(function(player, amount)
	if not AdminRoster.IsAdmin(player) then return end
	if type(amount) ~= "number" or amount ~= amount then return end
	local give = math.clamp(math.floor(amount), -1000000, 1000000)
	if give == 0 then return end
	Inventory.AddGold(player, give)
	Remotes.SocialNotify:FireClient(player, "info", ("เงิน %+d"):format(give))
end)
