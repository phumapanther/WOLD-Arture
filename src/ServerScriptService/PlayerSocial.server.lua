-- PlayerSocial.server.lua: wires the board, the friend list and the bank into the game's lifecycle, and
-- answers the client's requests.
--
-- Everything the client can send arrives here first. Each handler re-checks the request from scratch --
-- who is asking, what they are asking for, and whether the numbers make sense -- because a client can send
-- anything at all, including a perfectly-shaped request for someone else's money.
local Players = game:GetService("Players")
local ServerConfig = require(game.ServerScriptService.ServerConfig)

if ServerConfig.IsLobby then return end

local SocialConfig = require(game.ReplicatedStorage.SocialConfig)
local Remotes = require(game.ReplicatedStorage.Remotes)
local GuildBoard = require(game.ServerScriptService.GuildBoard)
local Friends = require(game.ServerScriptService.Friends)
local Bank = require(game.ServerScriptService.Bank)
local Inventory = require(game.ServerScriptService.Inventory)
local Progression = require(game.ServerScriptService.Progression)
local ProfileAccess = require(game.ServerScriptService.ProfileAccess)

-- Injected rather than required inside Bank, so the money module does not depend on the bag's lifecycle.
Bank.Inventory = Inventory

-- PlayerProfile calls these when it saves.
ProfileAccess.SerializeSocial = function(player)
	local friends = Friends.Serialize(player)
	if not friends then return nil end
	friends.Bank = Bank.Serialize(player)
	return friends
end

--------------------------------------------------------------------------------
-- Lifecycle
--------------------------------------------------------------------------------

local function load(player)
	-- Wait for the profile the same way progression and inventory do; a failed load starts them empty,
	-- which is the safe direction for a bank balance.
	local saved
	for _ = 1, 40 do
		local data = ProfileAccess.Get(player)
		if data then
			saved = data.Social
			break
		end
		task.wait(0.1)
	end
	Friends.Add(player, saved)
	Bank.Add(player, saved and saved.Bank)
	-- A friendship the other side has dropped is cleared now, which is the only moment both halves are here.
	Friends.Reconcile(player)
end

Players.PlayerAdded:Connect(function(player)
	task.spawn(load, player)
end)

Players.PlayerRemoving:Connect(function(player)
	Friends.Remove(player)
	Bank.Remove(player)
	GuildBoard.Remove(player)
end)

for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(load, player)
end

--------------------------------------------------------------------------------
-- Sending state to the client
--------------------------------------------------------------------------------

-- Which of this player's friends are in this server right now, so the UI can show who is reachable.
local function onlineFriends(player)
	local state = Friends.Get(player)
	if not state then return {} end
	local out = {}
	for userId, name in pairs(state.friends) do
		local other = Players:GetPlayerByUserId(userId)
		out[#out + 1] = {
			userId = userId,
			name = name,
			online = other ~= nil,
		}
	end
	table.sort(out, function(a, b)
		if a.online ~= b.online then return a.online end -- online first
		return a.name < b.name
	end)
	return out
end

local function pendingList(player)
	local state = Friends.Get(player)
	if not state then return {} end
	local out = {}
	for userId, name in pairs(state.pending) do
		out[#out + 1] = { userId = userId, name = name }
	end
	return out
end

local function send(player)
	if not player.Parent then return end
	Remotes.SocialUpdate:FireClient(player, {
		board = GuildBoard.All(),
		friends = onlineFriends(player),
		pending = pendingList(player),
		bank = Bank.Get(player),
		gold = (Inventory.Get(player) or {}).gold or 0,
		level = Progression.GetLevel(player),
	})
end

Remotes.RequestSocialData.OnServerEvent:Connect(send)

--------------------------------------------------------------------------------
-- The board
--------------------------------------------------------------------------------

Remotes.RequestGuildPost.OnServerEvent:Connect(function(player, text)
	if typeof(text) ~= "string" then return end
	-- Cheap guard before the real one: a client that sends a megabyte should not have it cleaned first.
	if #text > SocialConfig.BoardMaxLength * 4 then return end

	local post, reason = GuildBoard.Post(player, text)
	if not post then
		Remotes.SocialNotify:FireClient(player, "error", reason)
		return
	end
	-- Everyone gets the new post: it goes on the floating feed as well as the board.
	Remotes.GuildPostAdded:FireAllClients(post)
end)

--------------------------------------------------------------------------------
-- Friends
--------------------------------------------------------------------------------

Remotes.RequestFriendAction.OnServerEvent:Connect(function(player, action, value)
	if typeof(action) ~= "string" then return end

	local ok, message, other
	if action == "request" then
		ok, message, other = Friends.Request(player, value)
		if ok and other then
			Remotes.SocialNotify:FireClient(other, "friendRequest", ("%s ขอเป็นเพื่อน"):format(player.Name))
			send(other)
		end
	elseif action == "accept" then
		ok, message, other = Friends.Accept(player, value)
		if ok and other then
			Remotes.SocialNotify:FireClient(other, "info", ("%s รับคำขอเป็นเพื่อนแล้ว"):format(player.Name))
			send(other)
		end
	elseif action == "decline" then
		ok, message = Friends.Decline(player, value)
	elseif action == "remove" then
		ok, message, other = Friends.RemoveFriend(player, value)
		if ok and other then send(other) end
	else
		return -- an action name nobody defined; ignore it rather than guessing
	end

	Remotes.SocialNotify:FireClient(player, ok and "info" or "error", message)
	send(player)
end)

Remotes.RequestPigeonMessage.OnServerEvent:Connect(function(player, toUserId, text)
	if typeof(text) ~= "string" or #text > SocialConfig.MessageMaxLength * 4 then return end

	local ok, message, target = Friends.Send(player, toUserId, text)
	if not ok then
		Remotes.SocialNotify:FireClient(player, "error", message)
		return
	end
	-- Both ends see the message: the sender so their own line appears, the recipient so they are told.
	Remotes.PigeonMessage:FireClient(player, tonumber(toUserId), message)
	if target then
		Remotes.PigeonMessage:FireClient(target, player.UserId, message)
		Remotes.SocialNotify:FireClient(target, "pigeon", ("%s ส่งข้อความถึงคุณ"):format(player.Name))
	end
end)

--------------------------------------------------------------------------------
-- Bank
--------------------------------------------------------------------------------

Remotes.RequestBankAction.OnServerEvent:Connect(function(player, action, amount, targetName)
	if typeof(action) ~= "string" then return end

	local ok, message, other
	if action == "deposit" then
		ok, message = Bank.Deposit(player, amount)
	elseif action == "withdraw" then
		ok, message = Bank.Withdraw(player, amount)
	elseif action == "transfer" then
		ok, message, other = Bank.Transfer(player, targetName, amount)
		if ok and other then
			Remotes.SocialNotify:FireClient(other, "info",
				("ได้รับเงินโอน %s เหรียญ จาก %s"):format(tostring(math.floor(tonumber(amount) or 0)), player.Name))
			send(other)
		end
	else
		return
	end

	Remotes.SocialNotify:FireClient(player, ok and "info" or "error", message)
	send(player)
end)
