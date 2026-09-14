-- TreasureChests.server.lua: the chests that appear in the world, and what is in them.
--
-- A chest is deliberately the most disposable thing in the game. It is spawned, opened once, and destroyed
-- the moment its window closes -- along with anything the player did not take. Nothing about it is saved:
-- there is no chest table in the profile, no respawn clock, no ownership. That is the whole design, and it
-- is what makes the loot safe to roll at the moment of opening rather than up front.
--
-- Two things put a chest in the world, and neither is a timer: an admin command, and a player using a chest
-- item from their bag. The user asked for exactly that -- no chests lying around the map on their own.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")

local ServerConfig = require(game.ServerScriptService.ServerConfig)
if ServerConfig.IsLobby then return end

local ChestConfig = require(game.ReplicatedStorage.ChestConfig)
local ItemCatalog = require(game.ReplicatedStorage.ItemCatalog)
local Remotes = require(game.ReplicatedStorage.Remotes)
local Inventory = require(game.ServerScriptService.Inventory)

local TAG = "WOLD_Chest"

-- [model] = { tier, loot = { {id, count}, ... }, viewer = player or nil }
local Live = {}

-- [player] = model. One chest at a time: opening a second while the first is up would leave the first
-- orphaned with its loot still unspent.
local Viewing = {}

local folder = workspace:FindFirstChild("WOLD_Chests")
if not folder then
	folder = Instance.new("Folder")
	folder.Name = "WOLD_Chests"
	folder.Parent = workspace
end

--------------------------------------------------------------------------------
-- Prototypes
--------------------------------------------------------------------------------

local function prototypeFor(tier)
	local serverStorage = game:GetService("ServerStorage")
	for _, folderName in ipairs(ChestConfig.FolderNames) do
		local stored = serverStorage:FindFirstChild(folderName)
		local found = stored and stored:FindFirstChild(tier)
		if found then return found end
	end
	-- The user is free to move the folder into the world, so look there too before giving up.
	for _, folderName in ipairs(ChestConfig.FolderNames) do
		local inWorld = workspace:FindFirstChild(folderName, true)
		local found = inWorld and inWorld:FindFirstChild(tier)
		if found then return found end
	end
	return nil
end

--------------------------------------------------------------------------------
-- Rolling the loot
--------------------------------------------------------------------------------

-- Picks one category name from a weight table. Weights are relative, so they need not total anything.
local function pickCategory(weights)
	local total = 0
	for _, weight in pairs(weights) do total += weight end
	if total <= 0 then return nil end

	local roll = math.random() * total
	-- Sorted so the same weights always walk the categories in the same order. Without this, `pairs` makes
	-- the mapping from roll to category differ between servers -- harmless for fairness, but it would make a
	-- bug here impossible to reproduce.
	local names = {}
	for name in pairs(weights) do names[#names + 1] = name end
	table.sort(names)

	for _, name in ipairs(names) do
		roll -= weights[name]
		if roll <= 0 then return name end
	end
	return names[#names]
end

-- What one chest of this grade happens to contain.
local function rollLoot(tier)
	local spec = ChestConfig.Chests[tier]
	if not spec then return {} end

	local kinds = math.random(ChestConfig.MinKinds, ChestConfig.MaxKinds)
	local loot, seen = {}, {}

	for _ = 1, kinds do
		local category = pickCategory(spec.weights)
		local pool = category and ChestConfig.Pools[category]
		if pool and #pool > 0 then
			local id = pool[math.random(#pool)]
			-- A repeat rolls nothing rather than stacking: three rolls of "iron ore" should read as a chest
			-- that happened to hold one kind of thing, not as a secretly bigger pile.
			if not seen[id] and ItemCatalog.Get(id) then
				seen[id] = true
				local count = ChestConfig.SingleItems[id] and 1
					or math.random(ChestConfig.MinEach, ChestConfig.MaxEach)
				loot[#loot + 1] = { id = id, count = count }
			end
		end
	end

	return loot
end

--------------------------------------------------------------------------------
-- Placing and destroying
--------------------------------------------------------------------------------

-- Ground under (x, z), ignoring the chests themselves and the water surface -- a chest dropped on a river
-- should sit on the riverbed, not float on it.
local function groundAt(x, z)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { folder }
	params.IgnoreWater = true
	local hit = workspace:Raycast(Vector3.new(x, 800, z), Vector3.new(0, -2000, 0), params)
	return hit and hit.Position.Y or nil
end

-- Drops a chest of `tier` near `position`. Returns the model, or nil if there was nowhere to put it.
local function spawnChest(tier, position)
	local prototype = prototypeFor(tier)
	if not prototype then
		warn(("[Chest] ไม่เจอโมเดล %s ใน ServerStorage.Treasure"):format(tier))
		return nil
	end

	-- A few tries at a spot with ground under it, spreading outwards, so two chests asked for at once do not
	-- land inside each other.
	for attempt = 1, 10 do
		local angle = math.random() * math.pi * 2
		local distance = 6 + attempt * 2
		local x = position.X + math.cos(angle) * distance
		local z = position.Z + math.sin(angle) * distance
		local y = groundAt(x, z)
		if y then
			local model = prototype:Clone()
			-- The prototypes are display models: they may carry the kit's own prompts and tags, which would
			-- put a second, dead button next to the real one.
			for _, descendant in ipairs(model:GetDescendants()) do
				if descendant:IsA("ProximityPrompt") then descendant:Destroy() end
			end

			local size = model:GetExtentsSize()
			model:PivotTo(CFrame.new(x, y + size.Y * 0.5, z))
			model.Parent = folder

			-- Anchored, or a 300-part model will settle through the ground and wander off.
			for _, descendant in ipairs(model:GetDescendants()) do
				if descendant:IsA("BasePart") then
					descendant.Anchored = true
				end
			end

			local prompt = Instance.new("ProximityPrompt")
			prompt.ActionText = ChestConfig.PromptText
			prompt.ObjectText = ChestConfig.Chests[tier] and ChestConfig.Chests[tier].name or "หีบสมบัติ"
			prompt.MaxActivationDistance = ChestConfig.Range
			prompt.RequiresLineOfSight = false
			prompt.Parent = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true)

			Live[model] = { tier = tier, loot = rollLoot(tier), viewer = nil }
			CollectionService:AddTag(model, TAG)

			prompt.Triggered:Connect(function(player)
				local state = Live[model]
				if not state then return end
				-- First come, first served: while someone has it open, nobody else can.
				if state.viewer and state.viewer ~= player and state.viewer.Parent then return end
				if Viewing[player] and Viewing[player] ~= model then return end

				state.viewer = player
				Viewing[player] = model
				-- The chest is gone the moment it is opened, as the user asked -- the window is all that is
				-- left of it. Hiding rather than destroying, because destroying now would take the loot
				-- table with it before the player has taken anything.
				model.Parent = nil

				Remotes.ChestOpen:FireClient(player, state.tier, state.loot)
			end)

			return model
		end
	end
	return nil
end

--------------------------------------------------------------------------------
-- The window
--------------------------------------------------------------------------------

-- Hands over one row of the chest's contents. `index` is a position in the loot list the client was sent,
-- and nothing else -- the client never names an item id or a count.
Remotes.RequestChestTake.OnServerEvent:Connect(function(player, index)
	local model = Viewing[player]
	local state = model and Live[model]
	if not state or state.viewer ~= player then return end

	if index == "all" then
		-- Walk backwards: taking a row removes it, and walking forwards would skip the one that slid up.
		for i = #state.loot, 1, -1 do
			local row = state.loot[i]
			if Inventory.AddItem(player, row.id, row.count) then
				table.remove(state.loot, i)
			end
		end
		-- Whatever would not fit stays listed, so the player can see what they are leaving behind.
		if #state.loot > 0 then
			Remotes.SocialNotify:FireClient(player, "error", "กระเป๋าเต็ม เก็บได้ไม่หมด")
			Remotes.ChestOpen:FireClient(player, state.tier, state.loot)
		else
			Remotes.ChestClose:FireClient(player)
		end
		return
	end

	if type(index) ~= "number" then return end
	local row = state.loot[index]
	if not row then return end

	if not Inventory.AddItem(player, row.id, row.count) then
		Remotes.SocialNotify:FireClient(player, "error", "กระเป๋าเต็ม")
		return
	end
	table.remove(state.loot, index)
	Remotes.ChestOpen:FireClient(player, state.tier, state.loot)
end)

-- Closing the window is the end of the chest. Everything still inside is lost, which the user asked for
-- explicitly: the chest is gone permanently and its contents with it.
Remotes.RequestChestClose.OnServerEvent:Connect(function(player)
	local model = Viewing[player]
	if not model then return end
	Viewing[player] = nil
	local state = Live[model]
	if state then state.viewer = nil end
	Live[model] = nil
	model:Destroy()
end)

-- Leaving mid-window is the same as closing it.
Players.PlayerRemoving:Connect(function(player)
	local model = Viewing[player]
	Viewing[player] = nil
	if model then
		Live[model] = nil
		model:Destroy()
	end
end)

--------------------------------------------------------------------------------
-- The two ways a chest gets into the world
--------------------------------------------------------------------------------

local ChestAccess = require(game.ServerScriptService.ChestAccess)

-- Used by the admin command and by the chest items in a player's bag. Returns true if a chest actually
-- landed, so the caller can tell the player when it did not.
ChestAccess.Spawn = function(tier, position)
	if not ChestConfig.Chests[tier] then return false end
	return spawnChest(tier, position) ~= nil
end

ChestAccess.SpawnNear = function(player, tier)
	local character = player and player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then return false end
	return ChestAccess.Spawn(tier, root.Position)
end
