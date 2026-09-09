-- SocialController: opens the speaking stone (P, or the mobile button), keeps it fed with server data, and
-- turns taps into requests. It also runs the floating board feed, which is visible with the stone closed.
--
-- Every decision belongs to the server. This asks and draws.
while workspace:GetAttribute("IsLobby") == nil do
	task.wait()
end
if workspace:GetAttribute("IsLobby") then return end

local Players = game:GetService("Players")
local ContextActionService = game:GetService("ContextActionService")
local UserInputService = game:GetService("UserInputService")
local SocialGui = require(game.ReplicatedStorage.UI.SocialGui)
local BoardFeedGui = require(game.ReplicatedStorage.UI.BoardFeedGui)
local ProfileCardGui = require(game.ReplicatedStorage.UI.ProfileCardGui)
local CallGui = require(game.ReplicatedStorage.UI.CallGui)
local MapGui = require(game.ReplicatedStorage.UI.MapGui)
local Navigation = require(game.ReplicatedStorage.Navigation)
local Remotes = require(game.ReplicatedStorage.Remotes)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local gui = SocialGui.new()
gui.gui.Parent = playerGui

local feed = BoardFeedGui.new()
feed.gui.Parent = playerGui

local call = CallGui.new()
call.gui.Parent = playerGui

local map = MapGui.new()
map.gui.Parent = playerGui

-- The pin only needs to move while the map is being looked at.
local RunService = game:GetService("RunService")
local sincePin = 0
RunService.Heartbeat:Connect(function(dt)
	if not map:IsOpen() then return end
	sincePin += dt
	if sincePin < 0.2 then return end -- five times a second is smooth enough for a map pin
	sincePin = 0
	map:UpdatePin()
end)

-- Waypoints: tapping the map sets one, and the trail is drawn in the world so it can be followed with the
-- map closed. Entirely client-side -- it is a hint for this player, not a fact the server needs.
local nav = Navigation.new()

map:On("pin", function(position)
	local ok, message = nav:SetDestination(position, ("%.0f, %.0f"):format(position.X, position.Z))
	map:SetStatus(ok and ("ปักหมุดแล้ว (%s) — แตะหมุดเดิมเพื่อยกเลิก"):format(message) or message)
	map:SetWaypoint(ok and position or nil)
end)

-- Keep the path fresh while travelling, and clear it on arrival.
task.spawn(function()
	while true do
		task.wait(1)
		if nav:HasDestination() then
			local state, extra = nav:Update()
			if state == "arrived" then
				map:SetWaypoint(nil)
				map:SetStatus("ถึงจุดหมายแล้ว")
			end
		end
	end
end)

local function toggleMap()
	if map:IsOpen() then
		map:Hide()
	else
		gui:Hide() -- the map wants the whole window
		map:Show()
	end
end

local latest = { board = {}, friends = {}, pending = {}, bank = 0, gold = 0, level = 1 }
local settings = { muteCalls = false, muteChat = false, wallpaper = "rune" }
gui:SetSettings(settings)
gui:On("settingsChanged", function(updated)
	settings = updated
end)
local threads = {} -- [userId] = { messages }

--------------------------------------------------------------------------------
-- Drawing
--------------------------------------------------------------------------------

local function redraw()
	local screen = gui.current
	if screen == "board" then
		gui:RenderBoard(latest.board or {})
	elseif screen == "friends" then
		gui:RenderFriends(latest.friends or {}, latest.pending or {})
		if gui.chatWith then
			gui:RenderChat(threads[gui.chatWith] or {}, player.UserId)
		end
	elseif screen == "bank" then
		gui:RenderBank(latest.gold, latest.bank)
	elseif screen == "profile" then
		gui:RenderProfile(latest)
	end
end

Remotes.SocialUpdate.OnClientEvent:Connect(function(data)
	latest = data
	if gui:IsOpen() then redraw() end
end)

-- A new post reaches every client whether or not the stone is open: the feed is the point.
Remotes.GuildPostAdded.OnClientEvent:Connect(function(post)
	feed:Add(post)
	-- Keep the in-hand copy current so opening the board shows it without another round trip.
	latest.board = latest.board or {}
	table.insert(latest.board, 1, post)
	if gui:IsOpen() and gui.current == "board" then
		gui:RenderBoard(latest.board)
	end
end)

Remotes.PigeonMessage.OnClientEvent:Connect(function(withUserId, message)
	threads[withUserId] = threads[withUserId] or {}
	table.insert(threads[withUserId], message)
	if gui:IsOpen() and gui.chatWith == withUserId then
		gui:RenderChat(threads[withUserId], player.UserId)
	end
end)

Remotes.SocialNotify.OnClientEvent:Connect(function(kind, message)
	if not message then return end
	if gui:IsOpen() then
		gui:SetStatus(message, kind == "error" and "error" or "ok")
	end
	-- A message that arrives with the stone closed still deserves to be seen, so it goes on the feed --
	-- unless the player has muted chat notices, which is the whole point of that switch.
	if settings.muteChat and (kind == "pigeon" or kind == "friendRequest") then return end
	if not gui:IsOpen() and (kind == "pigeon" or kind == "friendRequest") then
		feed:Add({ id = os.clock(), userId = player.UserId, name = "หินเวท", text = message })
	end
end)

-- Someone raised or lowered their profile card. Every client draws every card: the billboard is parented
-- to that player s own character, so several at once need no layout of their own.
Remotes.CardStateChanged.OnClientEvent:Connect(function(who, data)
	if data then
		ProfileCardGui.Show(data)
	else
		ProfileCardGui.Hide(who.UserId)
	end
	-- Keep our own button honest about whether the card is actually up.
	if who == player then
		gui:SetCardButton(data ~= nil)
	end
end)

-- A respawn destroys the character the card hangs on, so our own card has to be re-raised or the button
-- would keep claiming it is showing.
player.CharacterAdded:Connect(function()
	if gui.cardShowing then
		task.wait(1)
		Remotes.RequestShowCard:FireServer(true)
	end
end)

Remotes.CallStateChanged.OnClientEvent:Connect(function(state, userId, name)
	-- Muted means the call is turned away, not merely silent: a panel ringing unheard would leave the
	-- caller waiting on someone who never sees it.
	if state == "incoming" and settings.muteCalls then
		Remotes.RequestCall:FireServer("end")
		return
	end
	if state == "ended" then
		call:Hide()
		if gui:IsOpen() then gui:SetStatus(("จบสายกับ %s"):format(name or ""), "ok") end
		return
	end
	-- calling / incoming / active: the panel sits above everything, so a call is answerable with the stone
	-- closed and while still playing.
	call:Show(state, userId, name)
end)

--------------------------------------------------------------------------------
-- Sending
--------------------------------------------------------------------------------

gui:On("post", function(text)
	Remotes.RequestGuildPost:FireServer(text)
end)

gui:On("friendAction", function(action, value)
	Remotes.RequestFriendAction:FireServer(action, value)
end)

gui:On("pigeon", function(toUserId, text)
	Remotes.RequestPigeonMessage:FireServer(toUserId, text)
end)

gui:On("bank", function(action, amount, target)
	Remotes.RequestBankAction:FireServer(action, amount, target)
end)

gui:On("openMap", function()
	toggleMap()
end)

gui:On("showCard", function(showing)
	Remotes.RequestShowCard:FireServer(showing)
end)

gui:On("call", function(userId)
	Remotes.RequestCall:FireServer("start", userId)
end)

call:On("answer", function()
	Remotes.RequestCall:FireServer("answer")
end)

call:On("hangUp", function()
	Remotes.RequestCall:FireServer("end")
end)

gui:On("openChat", function(userId)
	gui:RenderChat(threads[userId] or {}, player.UserId)
end)

-- Each screen draws from whatever arrived last, and asks for a refresh so it is not stale.
gui:On("screenChanged", function()
	redraw()
	Remotes.RequestSocialData:FireServer()
end)

--------------------------------------------------------------------------------
-- Opening
--------------------------------------------------------------------------------

local function toggle()
	if gui:IsOpen() then
		gui:Hide()
	else
		gui:Show()
		redraw()
		Remotes.RequestSocialData:FireServer()
	end
end

-- Bound through ContextActionService with Sink, the same as the bag's I: it stops the key reaching anything
-- Roblox has bound to it, and leaves every other input alone.
ContextActionService:BindAction("WOLD_ToggleMap", function(_, inputState)
	if inputState == Enum.UserInputState.Begin then
		toggleMap()
	end
	return Enum.ContextActionResult.Sink
end, false, Enum.KeyCode.M)

ContextActionService:BindAction("WOLD_ToggleSocial", function(_, inputState)
	if inputState == Enum.UserInputState.Begin then
		toggle()
	end
	return Enum.ContextActionResult.Sink
end, false, Enum.KeyCode.P)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	if input.KeyCode == Enum.KeyCode.Escape then
		if map:IsOpen() then map:Hide() end
		if gui:IsOpen() then gui:Hide() end
	end
end)

-- Reached by the touch controller through a BindableEvent, the same way the bag button works: a global
-- would depend on load order, and this does not.
local bindable = Instance.new("BindableEvent")
bindable.Name = "WOLD_ToggleSocial"
bindable.Parent = playerGui
bindable.Event:Connect(toggle)

-- Ask once at startup so the board is populated before the stone is ever opened. Retried because the
-- profile may still be loading server-side when this runs.
task.spawn(function()
	for _ = 1, 10 do
		if latest.board and #latest.board > 0 then return end
		Remotes.RequestSocialData:FireServer()
		task.wait(1)
	end
end)
