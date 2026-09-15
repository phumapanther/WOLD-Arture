-- StreamerTags: who is bound to which TikTok account, and what that looks like in the world.
--
-- One table, because two systems need the same answer and must not each keep their own: the admin panel
-- writes the binding, and TikTokLive reads it to decide who a like spawns a monster around.
--
-- Bound BY USER ID rather than by Player, so a binding survives the streamer rejoining mid-stream -- which
-- is the moment it would hurt most to lose. The nameplate and the glow are rebuilt on their next character.
local Players = game:GetService("Players")

local StreamerTags = {}

-- [userId] = tiktok account name, without the @.
local Bound = {}

-- What the badge says and what colours it pulses between. The user's own.
local LABEL = "🎮 TikTik 🎮"
local COLOUR_A = Color3.fromRGB(255, 62, 82)   -- red
local COLOUR_B = Color3.fromRGB(62, 128, 255)  -- blue

--------------------------------------------------------------------------------
-- The mark in the world
--------------------------------------------------------------------------------

-- Removes both halves of the mark. Safe on a character that never had one.
local function unmark(character)
	if not character then return end
	local head = character:FindFirstChild("Head")
	local tag = head and head:FindFirstChild("StreamerTag")
	if tag then tag:Destroy() end
	local root = character:FindFirstChild("HumanoidRootPart")
	local glow = root and root:FindFirstChild("StreamerGlow")
	if glow then glow:Destroy() end
end

-- Draws the badge over their head and the light around them.
--
-- The colour cycle runs on a TweenService loop rather than a Heartbeat: it is two colours going back and
-- forth forever, and a per-frame loop for that would cost the server a stream's worth of frames for nothing.
local function mark(character)
	if not character then return end
	local head = character:WaitForChild("Head", 5)
	if not head then return end
	unmark(character)

	local gui = Instance.new("BillboardGui")
	gui.Name = "StreamerTag"
	gui.Size = UDim2.fromOffset(190, 34)
	gui.StudsOffsetWorldSpace = Vector3.new(0, 3.2, 0)
	gui.AlwaysOnTop = true
	gui.MaxDistance = 140
	gui.Parent = head

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.Text = LABEL
	label.TextColor3 = COLOUR_A
	label.TextStrokeTransparency = 0.35
	label.TextStrokeColor3 = Color3.new(0, 0, 0)
	label.Parent = gui

	local root = character:FindFirstChild("HumanoidRootPart")
	if root then
		local glow = Instance.new("PointLight")
		glow.Name = "StreamerGlow"
		glow.Color = COLOUR_A
		glow.Brightness = 4
		glow.Range = 16
		glow.Shadows = false
		glow.Parent = root

		-- Both halves pulse together, so the badge and the light read as one thing rather than two effects
		-- that happen to be on the same person.
		task.spawn(function()
			local toB = true
			while glow.Parent and label.Parent do
				local target = toB and COLOUR_B or COLOUR_A
				local tween = game:GetService("TweenService"):Create(glow, TweenInfo.new(0.7), { Color = target })
				local tween2 = game:GetService("TweenService"):Create(label, TweenInfo.new(0.7), { TextColor3 = target })
				tween:Play()
				tween2:Play()
				toB = not toB
				task.wait(0.7)
			end
		end)
	end
end

-- Re-applies the mark on every character they spawn into, for as long as the binding stands.
local function watch(player)
	if player:GetAttribute("WOLD_StreamerWatched") then return end
	player:SetAttribute("WOLD_StreamerWatched", true)
	player.CharacterAdded:Connect(function(character)
		if Bound[player.UserId] then
			-- Deferred: CharacterAdded fires before the Head is necessarily there.
			task.defer(mark, character)
		end
	end)
end

--------------------------------------------------------------------------------
-- The binding
--------------------------------------------------------------------------------

-- Binds `player` to a TikTok account name, or clears it when the name is empty.
function StreamerTags.Set(player, accountName)
	if not player then return end
	accountName = tostring(accountName or ""):gsub("^@", ""):gsub("^%s+", ""):gsub("%s+$", "")

	if accountName == "" then
		Bound[player.UserId] = nil
		unmark(player.Character)
		return ""
	end

	Bound[player.UserId] = accountName
	watch(player)
	mark(player.Character)
	return accountName
end

-- The account this player is bound to, or nil.
function StreamerTags.Get(player)
	return player and Bound[player.UserId] or nil
end

-- The player bound to this account name, if they are in the server. Case-insensitive, because nobody types
-- their own handle the same way twice.
function StreamerTags.PlayerFor(accountName)
	if not accountName or accountName == "" then return nil end
	local wanted = accountName:gsub("^@", ""):lower()
	for userId, bound in pairs(Bound) do
		if bound:lower() == wanted then
			local player = Players:GetPlayerByUserId(userId)
			if player and player.Character then return player end
		end
	end
	return nil
end

-- Anyone bound at all, for the case where the bridge does not say which account an event came from.
function StreamerTags.AnyBound()
	for userId in pairs(Bound) do
		local player = Players:GetPlayerByUserId(userId)
		if player and player.Character then return player end
	end
	return nil
end

Players.PlayerRemoving:Connect(function(player)
	-- The binding itself is KEPT: they may be rejoining mid-stream, and losing it there is worse than a
	-- stale entry that costs one table slot until the server closes.
	unmark(player.Character)
end)

return StreamerTags
