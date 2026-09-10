-- GatherController: what a gathering node looks like to THIS player, and the auto-farm that walks between
-- nodes on its own.
--
-- Three jobs, all of them presentation or convenience -- the server decides every actual gather:
--   1. Hide prompts this player cannot use. A ProximityPrompt is one object shared by the whole server, so
--      it cannot be shown to one person and hidden from another; deciding it here on the client is the only
--      way to make "the prompt appears when you hold the right tool" true per player.
--   2. Play a swing while a hold is running.
--   3. F toggles auto-farm: walk to the nearest node of the kind the held tool works on, gather it, then
--      the next one. If someone takes the target first, retarget without stopping.
--
-- Nothing here is trusted. A player who blocked this script would still gather by walking up and pressing
-- E, and could not gather anything the server would have refused.
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local ProximityPromptService = game:GetService("ProximityPromptService")
local UserInputService = game:GetService("UserInputService")
local PathfindingService = game:GetService("PathfindingService")

while workspace:GetAttribute("IsLobby") == nil do
	task.wait()
end
if workspace:GetAttribute("IsLobby") then return end

local ItemCatalog = require(game.ReplicatedStorage.ItemCatalog)
local GatherConfig = require(game.ReplicatedStorage.GatherConfig)
local Remotes = require(game.ReplicatedStorage.Remotes)

local player = Players.LocalPlayer

local TAG = "WOLD_Node"
-- How close the auto-farm has to get before it stops walking and starts the hold. Comfortably inside the
-- prompt's own range, so a step of drift between frames does not put it out of reach.
local ARRIVE_DISTANCE = 7
-- Give up on a node the pathfinder cannot reach, rather than standing there forever.
local WALK_TIMEOUT = 12

--------------------------------------------------------------------------------
-- Which tool is in hand
--------------------------------------------------------------------------------

-- The `gathers` value of the equipped weapon ("axe", "pickaxe", "shovel"), or nil for anything else.
-- Weapons here are Motor6D models rather than Tool instances, so this comes from the server's own
-- EquipmentChanged rather than from watching the character for a Tool child.
local heldTool = nil

local function setEquipped(weaponId)
	local item = weaponId and ItemCatalog.Get(weaponId)
	heldTool = item and item.gathers or nil
end

Remotes.EquipmentChanged.OnClientEvent:Connect(function(who, weaponId)
	if who ~= player then return end
	setEquipped(weaponId)
end)

--------------------------------------------------------------------------------
-- Hiding prompts this player cannot use
--------------------------------------------------------------------------------

-- A node's own RequiredTool attribute, published by the server. Read from the node rather than looked up in
-- GatherConfig so a renamed node kind carries its own answer.
local function requiredToolOf(node)
	return node:GetAttribute("RequiredTool")
end

local function canUse(node)
	local needed = requiredToolOf(node)
	if not needed then return true end -- a node anyone can gather
	return heldTool == needed
end

-- The server owns Enabled for the SPENT state; this only ever hides a prompt further, never re-enables one
-- the server switched off. `spentPrompts` remembers which those are.
local function refreshPrompts()
	for _, node in ipairs(CollectionService:GetTagged(TAG)) do
		-- BOTH prompts -- the [E] gather and the [F] auto-farm. Taking only the first would have left the
		-- F prompt showing on nodes this player cannot use.
		if node:GetAttribute("Spent") ~= true then
			local usable = canUse(node)
			for _, d in ipairs(node:GetDescendants()) do
				if d:IsA("ProximityPrompt") then d.Enabled = usable end
			end
		end
	end
end

-- Re-evaluated when the held tool changes, and when nodes appear.
Remotes.EquipmentChanged.OnClientEvent:Connect(function(who)
	if who == player then
		task.defer(refreshPrompts)
	end
end)
CollectionService:GetInstanceAddedSignal(TAG):Connect(function()
	task.defer(refreshPrompts)
end)

--------------------------------------------------------------------------------
-- The swing
--------------------------------------------------------------------------------

-- Reuses Sword_Slash rather than a gathering animation of its own, as the user asked: it is a downward
-- two-handed swing, which is what chopping and mining look like.
local SWING_ID = "rbxassetid://138133285610075"
local animation = Instance.new("Animation")
animation.AnimationId = SWING_ID

local track

local function trackFor()
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
	if not animator then return nil end
	if track and track.Parent == animator then return track end
	local ok, loaded = pcall(function() return animator:LoadAnimation(animation) end)
	if not ok then return nil end
	loaded.Looped = true
	loaded:AdjustSpeed(0.7)
	track = loaded
	return track
end

local function isGatherPrompt(prompt)
	return prompt.Name == "GatherPrompt"
end

ProximityPromptService.PromptButtonHoldBegan:Connect(function(prompt, who)
	if who ~= player or not isGatherPrompt(prompt) then return end
	local t = trackFor()
	if t then t:Play(0.15) end
end)

local function stopSwing(prompt, who)
	if who ~= player or not isGatherPrompt(prompt) then return end
	if track and track.IsPlaying then track:Stop(0.2) end
end

ProximityPromptService.PromptButtonHoldEnded:Connect(stopSwing)
ProximityPromptService.PromptTriggered:Connect(stopSwing)

--------------------------------------------------------------------------------
-- Auto-farm
--------------------------------------------------------------------------------

local autoFarming = false
local autoThread = nil

-- On-screen state. The first version reported everything through print(), which no player ever sees -- so
-- auto-farm looked broken whether it was running or not.
local banner
local function setBanner(text)
	if not banner then
		local gui = Instance.new("ScreenGui")
		gui.Name = "GatherStatusGui"
		gui.ResetOnSpawn = false
		gui.IgnoreGuiInset = true
		gui.DisplayOrder = 12
		gui.Parent = player:WaitForChild("PlayerGui")

		local label = Instance.new("TextLabel")
		label.AnchorPoint = Vector2.new(0.5, 0)
		label.Position = UDim2.new(0.5, 0, 0, 74)
		label.Size = UDim2.fromOffset(260, 30)
		label.BackgroundColor3 = Color3.fromRGB(26, 28, 34)
		label.BackgroundTransparency = 0.2
		label.BorderSizePixel = 0
		label.Font = Enum.Font.GothamBold
		label.TextSize = 14
		label.TextColor3 = Color3.fromRGB(244, 197, 66)
		label.Text = ""
		label.Visible = false
		label.Parent = gui
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(0, 8)
		c.Parent = label
		banner = label
	end
	banner.Text = text or ""
	banner.Visible = (text ~= nil)
end

local function rootOf()
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart")
end

local function humanoidOf()
	local character = player.Character
	return character and character:FindFirstChildOfClass("Humanoid")
end

-- Is this node still worth walking to? Spent nodes and nodes for the wrong tool are both out.
local function isAvailable(node)
	if not node or not node.Parent then return false end
	if node:GetAttribute("Spent") == true then return false end
	if not canUse(node) then return false end
	local prompt = node:FindFirstChild("GatherPrompt", true)
	return prompt ~= nil
end

-- The nearest node the held tool works on. Nodes are found by TAG rather than from a ResourceNodes folder:
-- that is how the rest of this game locates them, and it means a node dragged in by hand counts too.
local function nearestNode(exclude)
	local root = rootOf()
	if not root then return nil end
	local best, bestDistance
	for _, node in ipairs(CollectionService:GetTagged(TAG)) do
		if node ~= exclude and isAvailable(node) then
			local prompt = node:FindFirstChild("GatherPrompt", true)
			local anchor = prompt and prompt.Parent
			if anchor then
				local d = (anchor.Position - root.Position).Magnitude
				if not bestDistance or d < bestDistance then
					best, bestDistance = node, d
				end
			end
		end
	end
	return best
end

-- Walk to `node`, giving up early if it is taken while we are on the way. Returns true on arrival.
--
-- Pathfinding rather than a straight MoveTo, so the walk goes around the buildings and rocks in the way.
-- The path is recomputed per node rather than once, because the character may be anywhere when it starts.
local function walkTo(node)
	local humanoid = humanoidOf()
	local root = rootOf()
	if not humanoid or not root then return false end
	local prompt = node:FindFirstChild("GatherPrompt", true)
	local anchor = prompt and prompt.Parent
	if not anchor then return false end

	-- Aim BESIDE the node, not at it. The anchor sits at the model's base, which is inside the trunk or the
	-- boulder -- and PathfindingService refuses to route to a point inside solid geometry, so computing to
	-- the anchor itself returned NoPath for every node in the world (measured: 5 of 5).
	--
	-- The approach point is on the near side, so the character stops short rather than walking through.
	local toNode = anchor.Position - root.Position
	local flat = Vector3.new(toNode.X, 0, toNode.Z)
	local approach = anchor.Position
	if flat.Magnitude > 0.1 then
		approach = anchor.Position - flat.Unit * (ARRIVE_DISTANCE - 1)
	end

	local path = PathfindingService:CreatePath({
		AgentRadius = 2,
		AgentHeight = 5,
		AgentCanJump = true,
	})
	local ok = pcall(function() path:ComputeAsync(root.Position, approach) end)

	local started = os.clock()

	-- No path (across water, or inside geometry): walk at it directly rather than refusing. Worst case the
	-- character bumps into something and the timeout moves on to another node.
	local waypoints = (ok and path.Status == Enum.PathStatus.Success) and path:GetWaypoints() or nil

	if not waypoints then
		humanoid:MoveTo(approach)
		while autoFarming and isAvailable(node) do
			if os.clock() - started > WALK_TIMEOUT then return false end
			local r = rootOf()
			if not r then return false end
			if (r.Position - anchor.Position).Magnitude <= ARRIVE_DISTANCE then return true end
			task.wait(0.2)
		end
		return false
	end

	for _, waypoint in ipairs(waypoints) do
		-- Checked every leg, not once at the start: this is the whole point of the retarget rule. If
		-- someone chops the tree while we are walking to it, we stop walking now.
		if not autoFarming or not isAvailable(node) then return false end
		if os.clock() - started > WALK_TIMEOUT then return false end

		local r = rootOf()
		if not r then return false end
		-- Close enough already? Stop walking rather than following the rest of the path into the trunk.
		if (r.Position - anchor.Position).Magnitude <= ARRIVE_DISTANCE then return true end

		if waypoint.Action == Enum.PathWaypointAction.Jump then
			humanoid.Jump = true
		end
		humanoid:MoveTo(waypoint.Position)
		humanoid.MoveToFinished:Wait()
	end

	local r = rootOf()
	return r ~= nil and (r.Position - anchor.Position).Magnitude <= ARRIVE_DISTANCE
end

-- Hold the prompt for its full duration, the way a player holding E would.
local function gatherNode(node)
	local prompt = node:FindFirstChild("GatherPrompt", true)
	if not prompt or not prompt.Enabled then return end

	prompt:InputHoldBegin()
	local deadline = os.clock() + prompt.HoldDuration + 1
	while os.clock() < deadline do
		if not autoFarming or not node.Parent then break end
		-- Taken by someone else mid-hold: let go and move on rather than finishing a hold on nothing.
		if node:GetAttribute("Spent") == true then break end
		task.wait(0.1)
	end
	prompt:InputHoldEnd()
end

local function stopAuto(reason)
	if not autoFarming then return end
	autoFarming = false
	local humanoid = humanoidOf()
	if humanoid then humanoid:MoveTo(rootOf() and rootOf().Position or humanoid.RootPart.Position) end
	if track and track.IsPlaying then track:Stop(0.2) end
	setBanner(nil)
end

local function startAuto()
	if autoFarming then return end
	if not heldTool then
		setBanner("ต้องถือเครื่องมือก่อน")
		task.delay(2, function() if not autoFarming then setBanner(nil) end end)
		return
	end
	autoFarming = true
	setBanner("ฟาร์มออโต้: เปิด — กด F เพื่อหยุด")

	autoThread = task.spawn(function()
		local lastFailed = nil
		while autoFarming do
			local humanoid = humanoidOf()
			if not humanoid or humanoid.Health <= 0 then break end

			local target = nearestNode(lastFailed)
			-- Nothing reachable: the field may be on cooldown, so wait rather than spinning.
			if not target then
				target = nearestNode(nil) -- try again including the one we just failed on
			end

			if not target then
				task.wait(2)
			else
				if walkTo(target) and isAvailable(target) then
					gatherNode(target)
					lastFailed = nil
				else
					-- Could not get there, or it was taken. Skip it next time round so the loop cannot
					-- lock onto an unreachable node forever.
					lastFailed = target
				end
				task.wait(0.3)
			end
		end
		autoFarming = false
	end)
end

--------------------------------------------------------------------------------
-- F toggles it
--------------------------------------------------------------------------------

local function toggleAuto()
	if autoFarming then stopAuto() else startAuto() end
end

-- Two ways in, on purpose. The prompt is how a player DISCOVERS it -- walking up to a tree and seeing
-- [F] ฟาร์มออโต้ -- and the bare key is how they stop it again once they have walked away from any node.
Remotes.ToggleAutoFarm.OnClientEvent:Connect(toggleAuto)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	if input.KeyCode ~= Enum.KeyCode.F then return end
	-- The prompt already fired for us if one was in range; this only covers being away from a node.
	local nearPrompt = false
	local r = rootOf()
	if r then
		for _, node in ipairs(CollectionService:GetTagged(TAG)) do
			local pr = node:FindFirstChild("AutoFarmPrompt", true)
			if pr and pr.Enabled and (pr.Parent.Position - r.Position).Magnitude <= pr.MaxActivationDistance then
				nearPrompt = true
				break
			end
		end
	end
	if not nearPrompt then toggleAuto() end
end)

-- Putting the tool away stops the run: the prompts it was using are about to vanish anyway.
Remotes.EquipmentChanged.OnClientEvent:Connect(function(who)
	if who == player and not heldTool then
		stopAuto()
	end
end)

player.CharacterAdded:Connect(function()
	track = nil
	stopAuto()
end)

-- Prompt visibility also has to follow the SPENT state, which the server changes as nodes are taken and
-- come back. Once a second rather than on every attribute change: a node's Spent state is read fresh by
-- isAvailable on every pass of the auto loop anyway, and this is only about what is drawn on screen.
task.spawn(function()
	while true do
		task.wait(1)
		refreshPrompts()
	end
end)

refreshPrompts()
