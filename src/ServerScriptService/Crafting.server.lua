-- Crafting.server.lua: the blacksmith who turns a pile of ore and slime into something worth carrying.
--
-- Found by TAG, the same way the shopkeeper is: anything tagged WOLD_Npc with NpcKind="smith" gets a prompt.
-- The user places the NPC model; this file never knows where it is.
--
-- Every recipe lives on the server. The client is sent the list so it can draw it, but a craft request names
-- an INDEX into that list and carries nothing else -- no item id, no material, no quantity. There is nothing
-- in the request for a modified client to lie about.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ServerConfig = require(game.ServerScriptService.ServerConfig)

if ServerConfig.IsLobby then return end

local CraftConfig = require(game.ReplicatedStorage.CraftConfig)
local ItemCatalog = require(game.ReplicatedStorage.ItemCatalog)
local Inventory = require(game.ServerScriptService.Inventory)
local Vitals = require(game.ServerScriptService.Vitals)
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
-- Who is mid-swing. The hammer takes a couple of seconds and the button stays clickable, so without this a
-- player could spend one set of materials several times over.
local Busy = {}

Players.PlayerRemoving:Connect(function(player)
	Busy[player] = nil
end)

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
	local purse = state and state.gold or 0

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

			-- Coin is a cost like any other material, so a row the player cannot pay the smith for is greyed
			-- the same way one they lack iron for is. Without this the button would invite a craft the server
			-- had already decided to refuse.
			local fee = recipe.gold or 0
			if purse < fee then affordable = false end

			-- The odds and the fee ride down with the row for the same reason the have-counts do: the player is
			-- being asked to gamble materials and coin, and the numbers they read before pressing have to be
			-- the ones the server will actually charge and roll. The client never opens CraftConfig itself.
			table.insert(recipes, {
				index = index, tab = recipe.tab, id = recipe.id, name = item.name,
				icon = item.icon, materials = materials, affordable = affordable,
				chance = recipe.chance or 1, gold = fee, goldHave = purse,
				-- So the row can say "x8" before the player commits, rather than the batch being a surprise
				-- that only shows up in the bag afterwards.
				yields = recipe.yields or 1,
			})
		end
	end

	return { tabs = CraftConfig.Tabs, recipes = recipes }
end

-- Same rule as the shop: no smithing from the floor.
local function canCraft(player)
	return not Vitals.IsDowned(player)
end

Remotes.RequestCraftOpen.OnServerEvent:Connect(function(player)
	if not canCraft(player) then return end
	if not nearSmith(player) then return end
	Remotes.CraftOpen:FireClient(player, snapshot(player))
end)

--------------------------------------------------------------------------------
-- Crafting
--------------------------------------------------------------------------------

Remotes.RequestCraft.OnServerEvent:Connect(function(player, index)
	if type(index) ~= "number" then return end
	if not canCraft(player) then return end
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

	-- The smith's fee, checked in the same breath as the materials so a player short of coin is told before
	-- anything is spent rather than after.
	local fee = recipe.gold or 0
	if fee > 0 and (state.gold or 0) < fee then
		return Remotes.SocialNotify:FireClient(player, "error",
			("เงินไม่พอ ต้องมี %d"):format(fee))
	end

	-- Room for the result has to be checked BEFORE the hammer starts, not after.
	--
	-- The materials are consumed whether the attempt works or not, so there is no ordering trick available
	-- any more: the product cannot be handed over first, because most of the time there is no product. What
	-- protects the player instead is asking the bag up front whether the result would fit, and refusing the
	-- whole attempt if it would not -- otherwise a successful craft could burn the materials and then find
	-- nowhere to put the sword.
	-- How many this recipe makes. Read from the recipe rather than assumed to be one, and checked for room
	-- at its full size: a batch of eight bullets needs somewhere to put eight.
	local yields = recipe.yields or 1

	if not Inventory.HasRoomFor(player, recipe.id, yields) then
		return Remotes.SocialNotify:FireClient(player, "error", "กระเป๋าเต็ม")
	end

	-- One craft at a time. The hammer takes a couple of seconds and the player is free to press the button
	-- again during it, which without this would spend the materials twice over from one set.
	if Busy[player] then
		return Remotes.SocialNotify:FireClient(player, "error", "กำลังตีอยู่ รอสักครู่")
	end
	Busy[player] = true

	-- Taken NOW rather than after the wait, so walking away or logging out mid-swing cannot dodge the cost.
	-- The fee goes with them: the smith is paid for the attempt, not for the result.
	for material, need in pairs(recipe.cost) do
		takeMaterial(player, state, material, need)
	end
	if fee > 0 then
		Inventory.AddGold(player, -fee)
	end

	-- Tell the client to run its progress bar, and redraw the window so the materials visibly leave the bag
	-- as the hammer starts.
	Remotes.CraftStarted:FireClient(player, index, CraftConfig.CraftSeconds)
	Remotes.CraftOpen:FireClient(player, snapshot(player))

	task.delay(CraftConfig.CraftSeconds, function()
		Busy[player] = nil
		-- The player may have left while the hammer was swinging.
		if not player.Parent then return end

		-- Rolled on the server, at the END of the wait. Rolling it up front would be the same odds, but the
		-- result would already exist while the bar was still filling -- and anything that exists can leak.
		local chance = recipe.chance or 1
		if math.random() >= chance then
			Remotes.CraftFinished:FireClient(player, index, false)
			Remotes.SocialNotify:FireClient(player, "error",
				fee > 0 and ("สร้าง %s ล้มเหลว เสียวัสดุและเงิน %d"):format(item.name, fee)
					or ("สร้าง %s ล้มเหลว วัสดุเสียไป"):format(item.name))
			Remotes.CraftOpen:FireClient(player, snapshot(player))
			return
		end

		if not Inventory.AddItem(player, recipe.id, yields) then
			-- The bag had room when the attempt started and does not now, which means the player filled it
			-- from somewhere else mid-swing. Rare, and the honest thing is to say so rather than pretend.
			Remotes.CraftFinished:FireClient(player, index, false)
			Remotes.SocialNotify:FireClient(player, "error", "กระเป๋าเต็ม ของที่สร้างหล่นหาย")
			return
		end

		Remotes.CraftFinished:FireClient(player, index, true)
		Remotes.SocialNotify:FireClient(player, "info", yields > 1
			and ("สร้าง %s x%d สำเร็จ"):format(item.name, yields)
			or ("สร้าง %s สำเร็จ"):format(item.name))

		-- The window redraws from a fresh snapshot rather than patching itself, so the have-counts on every
		-- other recipe sharing a material move at the same moment this one's do.
		Remotes.CraftOpen:FireClient(player, snapshot(player))
	end)
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
