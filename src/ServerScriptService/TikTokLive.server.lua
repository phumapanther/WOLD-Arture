-- TikTokLive.server.lua — the live stream reaching into the game.
--
-- Likes conjure monsters around the streamer, gifts drop chests, a subscription buys a boss with the
-- subscriber's name over its head, and viewers type commands that land on the streamer's own body. The top
-- three gifters of the session get the sky.
--
-- WHY THIS POLLS
--
-- A Roblox server cannot receive an inbound HTTP request. There is no listener and no port; HttpService
-- only calls out. So the bridge (tools/tiktok-bridge) holds the events in a numbered queue and this asks
-- for everything after the id it last saw, twice a second. That is not a workaround for something better --
-- there is no "push to Roblox" to fall back to except Open Cloud MessagingService, which does not reach
-- Studio at all and so cannot be the thing developed against.
--
-- The cursor is what makes it safe: a dropped poll, a stalled server or a Studio restart costs nothing,
-- because the next poll asks for the same id again. Nothing is acknowledged and nothing is lost.
--
-- WHY IT DOES ALMOST NOTHING ITSELF
--
-- Every effect here already exists in this game and is owned by a file that knows how to do it properly:
-- MobAccess conjures monsters, ChestAccess drops chests, StatusEffects knocks people down, Vitals revives
-- them, WeatherAccess and DayNightAccess own the sky. This is an adapter. The one thing it truly owns is
-- the JUDGEMENT -- who is allowed to do what, how often, and how much of it the server can survive.
local HttpService = game:GetService("HttpService")
local MessagingService = game:GetService("MessagingService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local ServerConfig = require(script.Parent.ServerConfig)
if ServerConfig.IsLobby then return end -- no monsters, no chests and no weather run in the lobby

local Config = require(game.ReplicatedStorage.TikTokConfig)
local Remotes = require(game.ReplicatedStorage.Remotes)
local EmoteConfig = require(game.ReplicatedStorage.EmoteConfig)
local WeatherConfig = require(game.ReplicatedStorage.WeatherConfig)

local AdminRoster = require(script.Parent.AdminRoster)
local MobAccess = require(script.Parent.MobAccess)
local ChestAccess = require(script.Parent.ChestAccess)
local WeatherAccess = require(script.Parent.WeatherAccess)
local DayNightAccess = require(script.Parent.DayNightAccess)
local StatusEffects = require(script.Parent.StatusEffects)
local Vitals = require(script.Parent.Vitals)

--------------------------------------------------------------------------------
-- Talking to the room
--------------------------------------------------------------------------------

-- Whoever the event came from. A name is never trusted to be there: the bridge fills it in, but a hand-
-- injected test event is allowed to leave it out, and string.format would throw on the nil.
local function who(event)
	local name = event and event.by
	return (type(name) == "string" and name ~= "") and name or "ผู้ชม"
end

local function dbg(fmt, ...)
	if Config.Debug then print("[TikTok] " .. fmt:format(...)) end
end

local function announce(text)
	if not Config.Announce then return end
	-- "admin" is not a class id, which is how the client knows to paint the banner red rather than look up
	-- a class colour that does not exist. AdminCommands' /announce does the same.
	Remotes.ClassAnnouncement:FireAllClients("admin", Config.AnnounceName, text)
end

--------------------------------------------------------------------------------
-- Who the stream happens to
--------------------------------------------------------------------------------

-- The streamer. Named in the config when there is one, and otherwise whichever admin is standing in the
-- server -- which is what a streamer wants on any day they are not on their main account.
--
-- Returns nil when nobody qualifies, and every caller treats that as "hold the event": there is no sensible
-- fallback. Spawning a boss around a random player because the admin stepped out is not a smaller version
-- of the feature, it is a different and much worse one.
local function streamer()
	if Config.AdminName ~= "" then
		local named = Players:FindFirstChild(Config.AdminName)
		if named and named.Character then return named end
		return nil
	end
	for _, player in ipairs(Players:GetPlayers()) do
		if AdminRoster.IsAdmin(player) and player.Character then return player end
	end
	return nil
end

--------------------------------------------------------------------------------
-- What the server can survive
--------------------------------------------------------------------------------

-- Everything this file conjures is counted and kept on a clock. A stream is hours long, and without both
-- halves of that a good night ends with a field full of monsters and a server at four frames a second.
local conjured = {} -- { model = Model, dieAt = number, boss = boolean }

local function census()
	local mobs, bosses = 0, 0
	for i = #conjured, 1, -1 do
		local entry = conjured[i]
		local gone = not entry.model.Parent
		if gone or os.clock() > entry.dieAt then
			if not gone then entry.model:Destroy() end
			table.remove(conjured, i)
		elseif entry.boss then
			bosses += 1
		else
			mobs += 1
		end
	end
	return mobs, bosses
end

local function track(model, lifetime, boss)
	if not model then return end
	conjured[#conjured + 1] = { model = model, dieAt = os.clock() + lifetime, boss = boss or false }
end

-- Gifts arrive in trains. The count is per minute rather than a gap between chests, because the natural
-- shape of a gift train is a burst -- refusing the second chest of a burst would read as broken.
local chestsThisMinute, chestMinuteStartedAt = 0, os.clock()
local function chestBudget()
	if os.clock() - chestMinuteStartedAt > 60 then
		chestsThisMinute, chestMinuteStartedAt = 0, os.clock()
	end
	return chestsThisMinute < Config.Chest.MaxPerMinute
end

--------------------------------------------------------------------------------
-- The four events
--------------------------------------------------------------------------------

local function doMob(event)
	local admin = streamer()
	if not admin or not MobAccess.SpawnHunters then return end

	local mobs, bosses = census()
	local room = math.max(0, Config.Mob.MaxAlive - (mobs + bosses))
	local want = math.clamp(tonumber(event.count) or 1, 1, Config.Mob.MaxPerEvent)
	if room <= 0 then return end

	local before = #conjured
	-- SpawnHunters returns only a count, so the models are picked up by watching the monster folder the way
	-- the rest of the game does -- through the tag every conjured monster already carries.
	local spawned = MobAccess.SpawnHunters(admin, Config.Mob.Distance, math.min(want, room))
	if spawned == 0 then return end

	-- Newest N children of the mob folder are the ones just made. Roblox parents them in order, so this is
	-- reliable without Mobs.server having to hand anything back.
	local folder = workspace:FindFirstChild("WOLD_Mobs")
	if folder then
		local children = folder:GetChildren()
		for i = #children - spawned + 1, #children do
			if children[i] then track(children[i], Config.Mob.LifetimeSeconds, false) end
		end
	end
	if #conjured > before then
		announce(("ไลก์ครบ! เสกมอน %d ตัวรอบตัวแอดมิน"):format(spawned))
	end
end

local function doChest(event)
	local admin = streamer()
	if not admin or not ChestAccess.SpawnNear then return end
	if not chestBudget() then return end

	local tier = Config.Chest.Tiers[event.tier] or Config.Chest.Fallback
	if ChestAccess.SpawnNear(admin, tier) then
		chestsThisMinute += 1
		announce(("%s ส่งของขวัญ %s coins — หีบ%sโผล่แล้ว!")
			:format(who(event), tostring(event.coins or 0), tostring(event.label or "")))
	end
end

local function doBoss(event)
	local admin = streamer()
	if not admin or not MobAccess.SpawnBoss then return end

	local _, bosses = census()
	if bosses >= Config.Boss.MaxAlive then return end

	local name = who(event)
	local model, kindName = MobAccess.SpawnBoss(admin, Config.Boss.Distance, {
		scale = Config.Boss.Scale,
		power = Config.Boss.Power,
		title = Config.Boss.TitlePrefix .. name .. Config.Boss.TitleSuffix,
		modelName = "SubBoss_" .. name,
	})
	if not model then return end
	track(model, Config.Boss.LifetimeSeconds, true)
	announce(("%s กดซับ! %s ร่างยักษ์ของ %s โผล่แล้ว (ใหญ่ %dx โหด %dx)")
		:format(name, tostring(kindName), name, Config.Boss.Scale, Config.Boss.Power))
end

--------------------------------------------------------------------------------
-- Chat commands
--------------------------------------------------------------------------------

local lastUsedAt = {} -- [action] = os.clock()
local lastAnyAt = 0

local function offCooldown(action, gap)
	local now = os.clock()
	if now - lastAnyAt < Config.GlobalCommandCooldown then return false end
	if now - (lastUsedAt[action] or -math.huge) < gap then return false end
	lastUsedAt[action] = now
	lastAnyAt = now
	return true
end

-- Which action a word belongs to. Walks the alias lists rather than keeping a reversed table, because the
-- lists are short and a reversed copy is one more thing to keep in step.
local function actionFor(word)
	for id, spec in pairs(Config.Commands) do
		for _, alias in ipairs(spec.words) do
			if alias == word then return id, spec end
		end
	end
	return nil
end

local function playEmote(admin, word)
	local id = Config.EmoteWords[word] or word
	local entry = EmoteConfig.Get(id)
	if not entry or entry.anim == "" then return false end
	-- The emote plays on the ADMIN'S OWN client. That is not a detail: an animation played on a player's own
	-- Animator is what replicates it to everybody else, and a server-side copy would be overwritten by their
	-- own animation script within the frame. Remotes.PlayEmote exists for exactly this.
	Remotes.PlayEmote:FireClient(admin, id)
	return true, entry.label or id
end

local function doTopCommand(word, argument)
	local time = Config.Top.TimeWords
	local weather = Config.Top.WeatherWords

	if (word == "time" or word == "เวลา") and DayNightAccess.Hold then
		local hour = time[argument]
		if hour == nil then hour = tonumber(argument) end
		if hour == nil then return end
		if not offCooldown("top_time", Config.Top.Cooldown) then return end
		DayNightAccess.Hold(hour or nil) -- false in the table means "let it run again"
		dbg("top: เวลา -> %s", tostring(hour))
		announce(hour and ("ท็อป 3 สั่งเวลา → %.1f น."):format(hour) or "ท็อป 3 ปล่อยเวลาเดินเอง")
		return
	end

	if (word == "weather" or word == "อากาศ") and WeatherAccess.Set then
		local kind = weather[argument]
		if kind == nil then
			for _, id in ipairs(WeatherConfig.Order) do
				if id == argument then kind = id break end
			end
		end
		if kind == nil then return end
		if not offCooldown("top_weather", Config.Top.Cooldown) then return end
		WeatherAccess.Set(kind or nil)
		dbg("top: อากาศ -> %s", tostring(kind))
		local named = kind and WeatherConfig.Kinds[kind]
		announce(kind and ("ท็อป 3 สั่งอากาศ → %s"):format(named and named.name or kind)
			or "ท็อป 3 ปล่อยอากาศให้สุ่มเอง")
	end
end

local function doCommand(event)
	local admin = streamer()
	if not admin then
		dbg("ไม่มีแอดมินในเซิร์ฟ — ข้ามคำสั่ง %q", tostring(event.text))
		return
	end

	-- "!นอน" / "!emote wave" / "!time night". The prefix is stripped by the bridge's own filter only in the
	-- sense that it refused to forward anything without one; the word still carries it.
	local text = tostring(event.text or ""):gsub("^%s+", ""):gsub("%s+$", "")
	local body = text:sub(2) -- drop the prefix character
	local word, argument = body:match("^(%S+)%s*(.*)$")
	if not word then return end
	word, argument = word:lower(), (argument or ""):lower()

	dbg("cmd %q word=%q arg=%q top=%s", text, word, argument, tostring(event.top))

	if event.top then
		doTopCommand(word, argument)
		-- Deliberately falls through: a top-3 gifter is still a viewer, and "!นอน" should work for them too.
	end

	-- "!emote <id>" and the bare Thai words both end here.
	if word == "emote" or word == "ท่า" then
		if not offCooldown("emote", Config.CommandCooldown) then return end
		local ok, label = playEmote(admin, argument)
		dbg("emote %q -> %s", argument, tostring(ok and label or "ไม่รู้จัก/ยังไม่ได้อัปโหลด"))
		if ok then announce(("%s สั่งแอดมินทำท่า %s"):format(who(event), tostring(label))) end
		return
	end

	local action, spec = actionFor(word)
	if not action then
		-- Not a listed command; it may still be an emote word or an emote id.
		if Config.EmoteWords[word] or EmoteConfig.Get(word) then
			if not offCooldown("emote", Config.CommandCooldown) then return end
			local ok, label = playEmote(admin, word)
			dbg("emote %q -> %s", word, tostring(ok and label or "ยังไม่ได้อัปโหลด"))
			if ok then announce(("%s สั่งแอดมินทำท่า %s"):format(who(event), tostring(label))) end
		else
			dbg("ไม่รู้จักคำสั่ง %q", word)
		end
		return
	end

	if not offCooldown(action, Config.CommandCooldown) then
		dbg("%s ติดคูลดาวน์", action)
		return
	end

	if action == "dizzy" then
			StatusEffects.Dizzy(admin, spec.seconds)
		announce(("%s ทำให้แอดมินมึน %d วิ"):format(who(event), spec.seconds))
	elseif action == "lay" then
		StatusEffects.Knockdown(admin, spec.seconds)
		announce(("%s สั่งแอดมินนอนราบ %d วิ"):format(who(event), spec.seconds))
	elseif action == "revive" then
		-- Only means anything while they are down, which is the point: it is a rescue, not a heal button.
		if Vitals.IsDowned(admin) then
			Vitals.Recover(admin, spec.fraction)
			announce(("%s ชุบแอดมินขึ้นมาแล้ว!"):format(who(event)))
		end
	end
end

--------------------------------------------------------------------------------
-- Getting the events in: two ways, because Studio and a published game cannot use the same one
--------------------------------------------------------------------------------
--
-- POLL, over HTTP, for Studio and any server that can reach the bridge's address. This is the only one
-- that works while developing: Open Cloud cannot deliver to Studio at all.
--
-- PUSH, over MessagingService, for the published game. A live Roblox server cannot reach 127.0.0.1 on the
-- streamer's PC, and the usual answer -- a cloudflared tunnel -- hands you a NEW random hostname every time
-- it starts, which would mean editing TikTokConfig and REPUBLISHING the game before every stream. Open
-- Cloud turns the direction around: the bridge publishes with an API key and the game only subscribes, so
-- there is no address in the game to go stale.
--
-- A message reaches EVERY server in the universe, not just the streamer's. The guard against that is the
-- one that was already there: every handler needs `streamer()` to return somebody, so a server with no
-- admin in it drops the event on the floor.

local HANDLERS = { mob = doMob, chest = doChest, boss = doBoss, cmd = doCommand }

local function dispatch(event)
	if type(event) ~= "table" then return end
	local handler = HANDLERS[event.kind]
	if not handler then return end
	-- One bad event must not stop the stream. A monster that could not find ground, an emote id that was
	-- deleted -- the next event still deserves to run.
	local fine, err = pcall(handler, event)
	if not fine then warn("[TikTok] " .. tostring(event.kind) .. " ล้มเหลว: " .. tostring(err)) end
end

local cursor = 0
local session = nil
local failures = 0
local warned = false

local function endpoint()
	local url = ("%s/events?after=%d&max=%d"):format(Config.Url, cursor, Config.BatchSize)
	if Config.Key ~= "" then url ..= "&key=" .. HttpService:UrlEncode(Config.Key) end
	return url
end

local function pollOnce()
	local ok, response = pcall(function()
		return HttpService:RequestAsync({ Url = endpoint(), Method = "GET" })
	end)
	if not ok or not response.Success then
		failures += 1
		if failures == Config.FailuresBeforeBackoff and not warned then
			warned = true
			warn("[TikTok] ต่อสะพานไม่ได้ (" .. tostring(ok and response.StatusCode or response) ..
				") — เช็คว่า tools/tiktok-bridge รันอยู่ และ HttpService เปิดใน Game Settings")
		end
		return false
	end

	local decoded
	ok, decoded = pcall(HttpService.JSONDecode, HttpService, response.Body)
	if not ok or type(decoded) ~= "table" then
		failures += 1
		return false
	end

	if failures >= Config.FailuresBeforeBackoff then
		print("[TikTok] ต่อสะพานได้แล้ว")
	end
	failures, warned = 0, false

	-- The bridge numbers its events from 1 every time it starts. If it has been restarted, our cursor belongs
	-- to a run that no longer exists and is higher than any id the new one will ever issue -- so we would ask
	-- for events after id 500 forever and be told, correctly, that there are none. The session token is how
	-- that is noticed. Take nothing from this response: the next poll re-asks from the start of the new run,
	-- which costs half a second and cannot lose or double anything.
	if decoded.session and decoded.session ~= session then
		if session ~= nil then print("[TikTok] สะพานรีสตาร์ท — เริ่มนับอีเวนต์ใหม่") end
		-- Adopt the run at its HEAD, not at zero. The bridge keeps hundreds of events for replay, and a
		-- server that boots into the middle of a live has no business acting out the ten minutes of it that
		-- happened before it existed -- that arrives as an avalanche of monsters nobody asked for.
		session, cursor = decoded.session, tonumber(decoded.head) or 0
		return true
	end

	for _, event in ipairs(decoded.events or {}) do
		dispatch(event)
	end
	if decoded.cursor and decoded.cursor > cursor then cursor = decoded.cursor end
	return true
end

--------------------------------------------------------------------------------
-- Push: MessagingService, for the published game
--------------------------------------------------------------------------------

-- Open Cloud delivers the string that was published, and it can deliver the same one to a server twice.
-- The ids are already on every event, so remembering the last few hundred is all the dedupe needed.
local seen, seenOrder = {}, {}

local function alreadySeen(id)
	if id == nil then return false end
	if seen[id] then return true end
	seen[id] = true
	seenOrder[#seenOrder + 1] = id
	if #seenOrder > 400 then
		seen[table.remove(seenOrder, 1)] = nil
	end
	return false
end

local function startPush()
	local ok, err = pcall(function()
		MessagingService:SubscribeAsync(Config.Topic, function(message)
			local payload = message and message.Data
			if type(payload) == "string" then
				local fine, decoded = pcall(HttpService.JSONDecode, HttpService, payload)
				payload = fine and decoded or nil
			end
			if type(payload) ~= "table" then return end
			if alreadySeen(payload.id) then return end
			dispatch(payload)
		end)
	end)
	if ok then
		print(("[TikTok] รับอีเวนต์ทาง MessagingService หัวข้อ %q"):format(Config.Topic))
	else
		warn("[TikTok] สมัคร MessagingService ไม่ได้: " .. tostring(err) ..
			" — ต้องเปิด Enable Studio Access to API Services / ต้องเป็นเซิร์ฟเวอร์จริง")
	end
end

--------------------------------------------------------------------------------
-- Which one runs
--------------------------------------------------------------------------------

local mode = Config.Mode
if mode == "auto" then
	-- Studio can only poll: Open Cloud does not deliver to it, so a published-game setting would leave
	-- development with no way to test at all.
	mode = RunService:IsStudio() and "poll" or "push"
end

if mode == "push" then
	startPush()
else
	task.spawn(function()
		-- Nothing is asked of the bridge until somebody is here to see it. A server with no admin in it is a
		-- server where every event would be dropped anyway, and polling an address that is not there for the
		-- length of an empty round is just noise in the log.
		while true do
			if streamer() then
				pollOnce()
				task.wait(failures >= Config.FailuresBeforeBackoff and Config.BackoffSeconds or Config.PollSeconds)
			else
				task.wait(2)
			end
		end
	end)
end

-- The sweeper. Conjured monsters expire on their own clock whether or not more events arrive, so a stream
-- that goes quiet still clears its own field.
task.spawn(function()
	while true do
		task.wait(5)
		census()
	end
end)

print(("[TikTok] พร้อม โหมด %s%s"):format(mode, mode == "poll" and (" จาก " .. Config.Url) or ""))
