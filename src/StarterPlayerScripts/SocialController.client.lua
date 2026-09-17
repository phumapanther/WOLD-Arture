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
local UiSound = require(game.ReplicatedStorage.UI.UiSound)

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

-- The pose panel the stone opens. Built here rather than in a controller of its own because the stone is the
-- only thing that opens it, and the stone lives here.
local EmoteGui = require(game.ReplicatedStorage.UI.EmoteGui)
local EmoteAccess = require(game.ReplicatedStorage.UI.EmoteAccess)
local emotes = EmoteGui.new()

emotes:On("play", function(id)
	local ok, message = EmoteAccess.Play(id)
	emotes:SetStatus(ok and message or ('ทำไม่ได้: ' .. tostring(message)))
end)
emotes:On("stop", function() EmoteAccess.Stop() end)
gui:On("openEmotes", function() emotes:Show() end)

map:On("pin", function(position)
	local ok, message = nav:SetDestination(position, ("%.0f, %.0f"):format(position.X, position.Z))
	map:SetStatus(ok and ("ปักหมุดแล้ว (%s) — แตะหมุดเดิมเพื่อยกเลิก"):format(message) or message)
	map:SetWaypoint(ok and position or nil)
end)

-- Tapping the pin itself takes it back, which the line above has been promising since the day it was
-- written. The map decides what counts as a tap on the pin, because only it knows where the pin is drawn;
-- clearing the trail is this side's job, because the trail is ours.
map:On("unpin", function()
	nav:Clear()
	map:SetWaypoint(nil)
	map:SetStatus("ยกเลิกหมุดแล้ว")
end)

--------------------------------------------------------------------------------
-- The blackout's "find me a broken machine" button
--------------------------------------------------------------------------------

-- Which transformers still need fixing. Read straight off the world: the server marks each one `Broken` and
-- everything tagged WOLD_Transformer is visible to every client, so the route needs no round trip.
local function brokenMachines()
	local out = {}
	for _, machine in ipairs(game:GetService("CollectionService"):GetTagged("WOLD_Transformer")) do
		if machine:GetAttribute("Broken") == true then table.insert(out, machine) end
	end
	return out
end

-- Remembered so pressing the button twice sends you somewhere NEW rather than rolling the same machine again
-- -- which, with three of them left, would happen a third of the time and read as a broken button.
local lastRouted = nil

map:On("repairRoute", function()
	local candidates = brokenMachines()
	if #candidates == 0 then
		return map:SetStatus("ไม่มีเครื่องที่ต้องซ่อมแล้ว")
	end

	local pick = candidates[math.random(1, #candidates)]
	if #candidates > 1 and pick == lastRouted then
		-- One re-roll is enough: with the previous pick excluded in spirit rather than by filtering, a second
		-- roll lands somewhere else the great majority of the time, and the rare repeat costs nothing.
		pick = candidates[math.random(1, #candidates)]
	end
	lastRouted = pick

	local position = pick:IsA("BasePart") and pick.Position or pick:GetPivot().Position
	local ok, message = nav:SetDestination(position, "หม้อแปลงไฟ")
	map:SetStatus(ok and ("นำทางไปหม้อแปลง (%s) — กดซ้ำเพื่อสุ่มเครื่องใหม่"):format(message) or message)
	map:SetWaypoint(ok and position or nil)
end)

-- The button exists only while the lights are out. Same source of truth as the banner: the server's own
-- picture of what is running.
Remotes.EventStateChanged.OnClientEvent:Connect(function(events)
	map:SetRepairVisible(events ~= nil and events.blackout ~= nil)
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
	elseif screen == "market" then
		-- Nil on the first draw of a freshly-opened stone, and the screen says so rather than showing an
		-- empty board; screenChanged has already asked the server, so the answer redraws this a moment later.
		gui:RenderMarket(latest.market)
	elseif screen == "profile" then
		gui:RenderProfile(latest)
	elseif screen == "collection" then
		-- nil ในครั้งแรก หน้าจอจะบอกว่ากำลังเปิดสมุด แล้ววาดใหม่เมื่อคำตอบมาถึง
		gui:RenderCollection(latestCollection)
	elseif screen == "ranking" then
		gui:RenderRanking(latestRanking)
	end
end

-- สมุดสะสมกับตารางอันดับมาคนละทางกับ SocialUpdate เพราะมันไม่ได้เปลี่ยนบ่อยและไม่ต้องส่งให้ทุกคน
-- ตลอดเวลา — ขอเมื่อเปิดหน้าจอนั้นเท่านั้น
local latestCollection, latestRanking = nil, nil

Remotes.CollectionUpdate.OnClientEvent:Connect(function(data)
	latestCollection = data
	if gui:IsOpen() then gui:RenderCollection(data) end
end)

Remotes.LeaderboardUpdate.OnClientEvent:Connect(function(data)
	latestRanking = data
	if gui:IsOpen() then gui:RenderRanking(data) end
end)

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
	-- Only for messages FROM someone else. Both ends of a conversation receive this event -- the sender so
	-- their own line appears -- and chiming at yourself for typing would be absurd. Muted chat stays silent
	-- but still arrives, unlike a muted call, which is refused outright.
	if message and message.from ~= player.UserId and not settings.muteChat then
		UiSound.Play("Notification")
	end
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
	-- A friend request is a notice worth hearing. Messages chime where they arrive instead, since only that
	-- path knows who sent them and can skip the ones you sent yourself.
	if kind == "friendRequest" then
		UiSound.Play("Notification")
	end
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

-- The ringtone loops until the call is answered, declined or given up on, so it is held rather than fired
-- and forgotten. Only one can be ringing at a time.
local ringing = nil
local function stopRinging()
	if ringing then
		ringing:Destroy()
		ringing = nil
	end
end

Remotes.CallStateChanged.OnClientEvent:Connect(function(state, userId, name)
	-- Muted means the call is turned away, not merely silent: a panel ringing unheard would leave the
	-- caller waiting on someone who never sees it.
	if state == "incoming" and settings.muteCalls then
		Remotes.RequestCall:FireServer("end")
		return
	end
	if state == "ended" then
		stopRinging()
		call:Hide()
		if gui:IsOpen() then gui:SetStatus(("จบสายกับ %s"):format(name or ""), "ok") end
		return
	end

	if state == "calling" then
		-- Dialling out: the tone you hear while waiting for them to pick up.
		stopRinging()
		ringing = UiSound.Loop("Call")
	elseif state == "incoming" then
		stopRinging()
		ringing = UiSound.Loop("Ringtone")
	elseif state == "active" then
		-- Answered, so whichever tone was playing has done its job.
		stopRinging()
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
gui:On("screenChanged", function(screen)
	redraw()
	Remotes.RequestSocialData:FireServer()
	-- ขอเฉพาะหน้าที่เปิด: ทั้งสองอย่างต้องนับใหม่ทุกครั้ง (อันดับเปลี่ยนตลอด สมุดอาจเพิ่งได้ปลาตัวใหม่)
	if screen == "collection" then
		Remotes.RequestCollection:FireServer()
	elseif screen == "ranking" then
		Remotes.RequestLeaderboards:FireServer()
	end
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
