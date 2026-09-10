-- Gathering.server.lua: chopping trees, breaking rocks, and everything else tagged as a gathering node.
--
-- Nodes are found by TAG. Anything tagged WOLD_Node with a NodeKind attribute naming an entry in
-- GatherConfig.Nodes becomes gatherable, wherever it came from -- a mapgen phase, a model the user dragged
-- in, or a part they built by hand. Neither side has to know about the other, which is the whole point:
-- the map can be rearranged freely without touching this file.
--
-- The prompt lives on the node and is built HERE, on the server, rather than per-client. A gathering node
-- is the same for everybody -- unlike a class action, whose buttons depend on who is looking -- and a
-- spent node has to look spent to the whole server, which a client-built prompt could not guarantee.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ServerConfig = require(game.ServerScriptService.ServerConfig)

if ServerConfig.IsLobby then return end

local GatherConfig = require(game.ReplicatedStorage.GatherConfig)
local ItemCatalog = require(game.ReplicatedStorage.ItemCatalog)
local Inventory = require(game.ServerScriptService.Inventory)
local Progression = require(game.ServerScriptService.Progression)
local Remotes = require(game.ReplicatedStorage.Remotes)

local TAG = "WOLD_Node"

-- [node] = os.clock() when it becomes available again. A deadline rather than a timer per node, so a
-- thousand trees cost one table entry each and no running tasks.
local SpentUntil = {}

--------------------------------------------------------------------------------

local function configFor(node)
	local kind = node:GetAttribute("NodeKind")
	return kind and GatherConfig.Nodes[kind], kind
end

-- The part the prompt should hang on. A node is usually a Model, and a prompt on a Model does nothing --
-- it has to be on a BasePart.
local function anchorOf(node)
	if node:IsA("BasePart") then return node end
	if node:IsA("Model") then
		return node.PrimaryPart or node:FindFirstChildWhichIsA("BasePart", true)
	end
	return nil
end

-- Does this player hold the tool this node needs? Reads the EQUIPPED weapon rather than the whole bag: a
-- pickaxe in the bag is not a pickaxe in your hands, and requiring it to be equipped is what makes the
-- gathering tools worth a slot.
local function hasTool(player, needed)
	if not needed then return true end
	local _, slot = Inventory.EquippedWeapon(player)
	local entry = slot and ItemCatalog.Get(slot.id)
	return entry ~= nil and entry.gathers == needed
end

local function isSpent(node)
	local until_ = SpentUntil[node]
	if not until_ then return false end
	if os.clock() >= until_ then
		SpentUntil[node] = nil
		return false
	end
	return true
end

-- A spent node is dimmed and its prompt switched off, so the whole server can see it has been taken
-- rather than walking up to a prompt that refuses. Transparency is remembered per part, because a node
-- may be a model of parts that were not all opaque to begin with.
local Faded = {} -- [node] = { [part] = originalTransparency }

local function setSpent(node, spent)
	local prompt = node:FindFirstChildWhichIsA("ProximityPrompt", true)
	if prompt then prompt.Enabled = not spent end

	if spent then
		if Faded[node] then return end
		local originals = {}
		for _, d in ipairs(node:GetDescendants()) do
			if d:IsA("BasePart") then
				originals[d] = d.Transparency
				d.Transparency = math.min(0.85, d.Transparency + 0.65)
			end
		end
		if node:IsA("BasePart") then
			originals[node] = node.Transparency
			node.Transparency = math.min(0.85, node.Transparency + 0.65)
		end
		Faded[node] = originals
	else
		local originals = Faded[node]
		if not originals then return end
		for part, transparency in pairs(originals) do
			if part.Parent then part.Transparency = transparency end
		end
		Faded[node] = nil
	end
end

--------------------------------------------------------------------------------
-- Gathering
--------------------------------------------------------------------------------

local function gather(node, player)
	local config = configFor(node)
	if not config then return end
	if isSpent(node) then return end

	if not hasTool(player, config.tool) then
		Remotes.SocialNotify:FireClient(player, "error", "ต้องถือเครื่องมือให้ถูกก่อน")
		return
	end

	-- Marked spent BEFORE anything is given, so two players finishing the same hold on the same frame
	-- cannot both be paid for it.
	SpentUntil[node] = os.clock() + GatherConfig.RespawnSeconds
	setSpent(node, true)

	local count = math.random(config.min, config.max)
	local given = Inventory.AddItem(player, config.item, count)
	if not given then
		Remotes.SocialNotify:FireClient(player, "error", "กระเป๋าเต็ม")
		-- Still spent: the node was struck. Letting a full bag leave it fresh would make "stand at a full
		-- bag and re-trigger" a way to hold a node against everyone else.
		return
	end

	if config.xp and config.xp > 0 then
		Progression.AwardExp(player, config.xp)
	end

	local item = ItemCatalog.Get(config.item)
	Remotes.SocialNotify:FireClient(player, "info",
		("ได้ %s x%d"):format(item and item.name or config.item, count))

	task.delay(GatherConfig.RespawnSeconds, function()
		if node.Parent then setSpent(node, false) end
	end)
end

--------------------------------------------------------------------------------
-- Wiring nodes up
--------------------------------------------------------------------------------

local function register(node)
	local config, kind = configFor(node)
	if not config then
		warn(("[Gathering] %s is tagged %s but its NodeKind (%s) is not in GatherConfig")
			:format(node:GetFullName(), TAG, tostring(kind)))
		return
	end

	local anchor = anchorOf(node)
	if not anchor then return end
	if anchor:FindFirstChildWhichIsA("ProximityPrompt") then return end -- already wired

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "GatherPrompt"
	prompt.ActionText = config.prompt or "เก็บ"
	prompt.ObjectText = config.object or kind
	-- F rather than E: E already opens the daily chest and every class action, and the user asked for F.
	prompt.KeyboardKeyCode = Enum.KeyCode.F
	prompt.MaxActivationDistance = GatherConfig.Range
	prompt.HoldDuration = config.seconds or 2
	prompt.RequiresLineOfSight = false
	prompt.Parent = anchor

	prompt.Triggered:Connect(function(player)
		gather(node, player)
	end)
end

for _, node in ipairs(CollectionService:GetTagged(TAG)) do
	task.spawn(register, node)
end
CollectionService:GetInstanceAddedSignal(TAG):Connect(function(node)
	task.spawn(register, node)
end)

CollectionService:GetInstanceRemovedSignal(TAG):Connect(function(node)
	SpentUntil[node] = nil
	Faded[node] = nil
end)

Players.PlayerRemoving:Connect(function()
	-- Nothing per-player is held here: a spent node belongs to the server, not to whoever took it.
end)
