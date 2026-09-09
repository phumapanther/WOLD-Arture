-- PlayerClasses.server.lua: loads each player's classes from their profile, publishes the serializer that
-- saves them back, and offers the choice when a level unlocks one.
--
-- Replaces PlayerRoles.server.lua. A profile holding one of the four old roles is migrated by Classes.Add
-- rather than dropped, so nobody loses a role an admin gave them.
local Players = game:GetService("Players")
local ServerConfig = require(game.ServerScriptService.ServerConfig)
local Classes = require(game.ServerScriptService.Classes)
local Progression = require(game.ServerScriptService.Progression)
local ProfileAccess = require(game.ServerScriptService.ProfileAccess)
local ClassConfig = require(game.ReplicatedStorage.ClassConfig)
local Remotes = require(game.ReplicatedStorage.Remotes)

if ServerConfig.IsLobby then return end

-- PlayerProfile calls this when it saves; publishing it here keeps the profile system free of any dependency
-- on classes.
ProfileAccess.SerializeRole = Classes.Serialize

--------------------------------------------------------------------------------
-- Offering the choice
--------------------------------------------------------------------------------

-- Who has finished loading. An offer decided before this is meaningless: Classes.Get would answer nil for
-- a player who has chosen, and they would be handed the card again on every rejoin. The client asks a few
-- seconds after joining, and the profile can take longer than that to arrive.
local Loaded = {}

-- Whether this player is owed a choice of `tier`, and has not made it. Checked rather than remembered, so a
-- player who was offered the card and closed it is offered it again on their next level-up -- and one who
-- reaches level 50 in a single jump is offered both.
local function pendingTier(player)
	local level = Progression.GetLevel(player)
	if level >= ClassConfig.AdvancedLevel and not Classes.Get(player, "advanced") then
		return "advanced"
	end
	if level >= ClassConfig.BasicLevel and not Classes.Get(player, "basic") then
		return "basic"
	end
	return nil
end

local function offer(player)
	-- Silence rather than a wrong answer. The client asks again on its next level-up, and the join-time ask
	-- below waits for this instead of racing it.
	if not Loaded[player] then return end
	local tier = pendingTier(player)
	if tier then
		Remotes.ClassOffer:FireClient(player, tier, ClassConfig.OfTier(tier))
	end
end

-- No hook into Progression: it already tells the client it levelled up, and the client asks here. That
-- keeps Progression free of any knowledge of classes, and means one request path serves both the level-up
-- and the join case below rather than two.

--------------------------------------------------------------------------------
-- Choosing
--------------------------------------------------------------------------------

Remotes.RequestChooseClass.OnServerEvent:Connect(function(player, classId)
	if type(classId) ~= "string" then return end
	local class = ClassConfig.Get(classId)
	if not class then return end

	-- The level gate is checked here, not trusted from the client: the card is only ever shown when it is
	-- earned, but a crafted request must not be able to hand out an advanced class at level 1.
	local needed = ClassConfig.LevelFor(class.tier)
	if not needed or Progression.GetLevel(player) < needed then return end

	-- One choice per tier per life. Changing your mind means dying and coming back, which is the point:
	-- the class is a commitment, and death is what unmakes it.
	if Classes.Get(player, class.tier) then return end

	if Classes.Set(player, class.tier, classId) then
		Remotes.ClassChanged:FireClient(player, class.tier, classId)
		-- Still owed the other tier? A level-50 player choosing their basic class is offered the advanced
		-- card straight after, rather than having to wait for another level-up that may never come at cap.
		task.defer(offer, player)
	end
end)

-- The client asks on join, once its UI exists: the level-up that unlocked the tier may have happened in a
-- previous session, so there is nothing to react to.
-- Waits for the profile rather than answering nothing: a client that asked too early would otherwise get
-- silence and never ask again until it levelled up.
Remotes.RequestClassOffer.OnServerEvent:Connect(function(player)
	for _ = 1, 100 do
		if Loaded[player] then break end
		if not player.Parent then return end
		task.wait(0.1)
	end
	offer(player)
end)

--------------------------------------------------------------------------------
-- Lifecycle
--------------------------------------------------------------------------------

local function load(player)
	-- Wait briefly for the profile session, so a returning player keeps their classes rather than appearing
	-- with none. If it never arrives (a failed load) they start with none, which is the safe direction.
	local saved
	for _ = 1, 40 do
		local data = ProfileAccess.Get(player)
		if data then
			saved = data.Role
			break
		end
		task.wait(0.1)
	end
	Classes.Add(player, saved)
	Loaded[player] = true
end

Players.PlayerAdded:Connect(function(player)
	task.spawn(load, player)
end)

Players.PlayerRemoving:Connect(function(player)
	Classes.Remove(player)
	Loaded[player] = nil
end)

for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(load, player)
end

--------------------------------------------------------------------------------
-- Letting the mark expire
--------------------------------------------------------------------------------

-- The mark is a deadline rather than a timer, so nothing fires when it passes. This sweep exists only to
-- push the attribute back to false so the red name clears itself. Once a second is far finer than a
-- ten-minute mark needs, and it costs nothing when nobody is marked.
task.spawn(function()
	while true do
		task.wait(1)
		for _, player in ipairs(Players:GetPlayers()) do
			if player:GetAttribute("WOLD_Marked") and not Classes.IsMarked(player) then
				Classes.Replicate(player)
			end
		end
	end
end)
