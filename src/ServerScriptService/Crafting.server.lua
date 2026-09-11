-- Crafting.server.lua: the blacksmith who turns a pile of ore and slime into something worth carrying.
--
-- Found by TAG, the same way the shopkeeper is: anything tagged WOLD_Npc with NpcKind="smith" gets a prompt.
-- The user places the NPC model; this file never knows where it is.
--
-- Every recipe lives on the server. The client is sent the list so it can draw it, but a craft request names
-- an INDEX into that list and carries nothing else -- no item id, no material, no quantity. There is nothing
-- in the request for a modified client to lie about.
local CollectionService = game:GetService("CollectionService")
local ServerConfig = require(game.ServerScriptService.ServerConfig)

if ServerConfig.IsLobby then return end

local CraftConfig = require(game.ReplicatedStorage.CraftConfig)
local ItemCatalog = require(game.ReplicatedStorage.ItemCatalog)
local Inventory = require(game.ServerScriptService.Inventory)
local Remotes = require(game.ReplicatedStorage.Remotes)

local TAG = "WOLD_Npc"
local RANGE = 12

-- A recipe naming an item that does not exist would draw a blank row and craft nothing, which looks like a
-- bug in the crafting system rather than a typo in the config. Said once at startup instead.
for index, recipe in ipairs(CraftConfig.Recipes) do
	if not ItemCatalog.Exists(recipe.id) then
		warn(("[WOLD] CraftConfig recipe %d makes unknown item %q"):format(index, tostring(recipe.id)))
	end
	for material in pairs(recipe.cost) do
		if not ItemCatalog.Exists(material) then
			warn(("[WOLD] CraftConfig recipe %d needs unknown material %q"):format(index, tostring(material)))
		end
	end
end

--------------------------------------------------------------------------------
-- Counting what the player has
--------------------------------------------------------------------------------

-- Summed across every slot, not read from one. Ten stone picked up over an afternoon can sit in three
-- part-filled slots and one nearly full one; a recipe asking for twenty would be refused by anything that
-- looked at a single slot, even though the bag plainly holds them.
local function countMaterial(state, id)
	local total = 0
	for _, slot in pairs(state.slots) do
		if slot.id == id then total += slot.count or 1 end
	end
	return total
end

-- Takes `count` of `id` out of the bag, walking slots until the bill is paid. Assumes the caller has already
-- checked that the bag holds enough -- it is called only after the full cost has been verified, so a partial
-- take here would mean the check and the taking disagreed.
--
-- The slot list is collected before anything is removed rather than iterated while removing, for the reason
-- the shop's "sell all" gives: RemoveFromSlot empties slots, and walking a table while emptying it is reading
-- the thing you are changing.
local function takeMaterial(player, state, id, count)
	local found = {}
	for index, slot in pairs(state.slots) do
		if slot.id == id then table.insert(found, { index = index, count = slot.count or 1 }) end
	end
	for _, entry in ipairs(found) do
		if count <= 0 then break end
		local take = math.min(entry.count, count)
		Inventory.RemoveFromSlot(player, entry.index, take)
		count -= take
	end
end

--------------------------------------------------------------------------------
-- Who is close enough
--------------------------------------------------------------------------------

local function nearSmith(player)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not root then return false end
	for _, npc in ipairs(CollectionService:GetTagged(TAG)) do
		if npc:GetAttribute("NpcKind") == "smith" then
			local position = npc:IsA("BasePart") and npc.Position or npc:GetPivot().Position
			if (position - root.Position).Magnitude <= RANGE then return true end
		end
	end
	return false
end

--------------------------------------------------------------------------------
-- Opening the forge
--------------------------------------------------------------------------------

-- Everything the client needs to draw the window: every recipe, what it makes, and how far along the player
-- already is on each material. The have-counts are computed HERE rather than worked out on the client from
-- its own copy of the bag, so the window and the server can never disagree about whether something is
-- craftable -- the greyed-out row and the refusal come from the same numbers.
local function snapshot(player)
	local state = Inventory.Get(player)

	local recipes = {}
	for index, recipe in ipairs(CraftConfig.Recipes) do
		local item = ItemCatalog.Get(recipe.id)
		if item then
			local materials, affordable = {}, true
			for material, need in pairs(recipe.cost) do
				local entry = ItemCatalog.Get(material)
				local have = state and countMaterial(state, material) or 0
				if have < need then affordable = false end
				table.insert(materials, {
					id = material, name = entry and entry.name or material,
					icon = entry and entry.icon, have = have, need = need,
				})
			end
			-- pairs() over the cost table comes out in whatever order Lua feels like, which would shuffle the
			-- materials on a row between one redraw and the next. Sorted by id so a row looks the same twice.
			table.sort(materials, function(a, b) return a.id < b.id end)

			table.insert(recipes, {
				index = index, tab = recipe.tab, id = recipe.id, name = item.name,
				icon = item.icon, materials = materials, affordable = affordable,
			})
		end
	end

	return { tabs = CraftConfig.Tabs, recipes = recipes }
end

Remotes.RequestCraftOpen.OnServerEvent:Connect(function(player)
	if not nearSmith(player) then return end
	Remotes.CraftOpen:FireClient(player, snapshot(player))
end)

--------------------------------------------------------------------------------
-- Crafting
--------------------------------------------------------------------------------

Remotes.RequestCraft.OnServerEvent:Connect(function(player, index)
	if type(index) ~= "number" then return end
	-- Re-checked on every craft, not just on opening: a player could walk away with the window still up.
	if not nearSmith(player) then
		return Remotes.SocialNotify:FireClient(player, "error", "อยู่ไกลจากช่างตีเหล็กเกินไป")
	end

	local recipe = CraftConfig.Recipes[index]
	if not recipe then return end
	local item = ItemCatalog.Get(recipe.id)
	if not item then return end

	local state = Inventory.Get(player)
	if not state then return end

	-- Every material checked before ANY is taken. Taking as we go and stopping halfway would eat the
	-- materials for a craft that never happened.
	for material, need in pairs(recipe.cost) do
		if countMaterial(state, material) < need then
			local entry = ItemCatalog.Get(material)
			return Remotes.SocialNotify:FireClient(player, "error",
				("วัสดุไม่พอ: %s"):format(entry and entry.name or material))
		end
	end

	-- The product is given BEFORE the materials are taken, the same way the shop hands over goods before it
	-- charges: whichever side can fail has to go first. Adding can fail on a full bag; removing from a slot
	-- that was just counted cannot. Done the other way round, a full bag would swallow the materials and
	-- hand back nothing.
	--
	-- ponytail: the cost of that ordering is that a completely full bag refuses a craft which would in fact
	-- have freed a slot by consuming a whole stack. Refusing is the safe direction -- the player keeps their
	-- materials and drops one thing -- and the alternative is taking the materials first and needing a way to
	-- put them all back when the add fails. Worth revisiting only if players actually hit it.
	if not Inventory.AddItem(player, recipe.id, 1) then
		return Remotes.SocialNotify:FireClient(player, "error", "กระเป๋าเต็ม")
	end
	for material, need in pairs(recipe.cost) do
		takeMaterial(player, state, material, need)
	end

	Remotes.SocialNotify:FireClient(player, "info", ("สร้าง %s สำเร็จ"):format(item.name))

	-- The window redraws from a fresh snapshot rather than patching itself, so the have-counts on every other
	-- recipe sharing a material move at the same moment this one's do.
	Remotes.CraftOpen:FireClient(player, snapshot(player))
end)

--------------------------------------------------------------------------------
-- The prompt on the NPC
--------------------------------------------------------------------------------

local function register(npc)
	if npc:GetAttribute("NpcKind") ~= "smith" then return end
	-- HumanoidRootPart FIRST, for the reason Shop.server gives: the kit's NPC models set PrimaryPart to a
	-- 1x1 pivot handle at the model's feet, so preferring PrimaryPart puts the button on the ground by the
	-- blacksmith's boots.
	local anchor = npc:IsA("BasePart") and npc
		or (npc:IsA("Model") and (npc:FindFirstChild("HumanoidRootPart") or npc:FindFirstChild("UpperTorso")
			or npc.PrimaryPart or npc:FindFirstChildWhichIsA("BasePart", true)))
	if not anchor then return end
	if anchor:FindFirstChild("CraftPrompt") then return end

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "CraftPrompt"
	prompt.ActionText = "ตีเหล็ก"
	prompt.ObjectText = npc:GetAttribute("NpcName") or "ช่างตีเหล็ก"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.MaxActivationDistance = RANGE
	prompt.RequiresLineOfSight = false
	prompt.HoldDuration = 0
	prompt.Parent = anchor

	prompt.Triggered:Connect(function(player)
		Remotes.CraftOpen:FireClient(player, snapshot(player))
	end)
end

for _, npc in ipairs(CollectionService:GetTagged(TAG)) do
	task.spawn(register, npc)
end
CollectionService:GetInstanceAddedSignal(TAG):Connect(function(npc)
	task.spawn(register, npc)
end)
