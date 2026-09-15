-- AdminPanel.server.lua: the F3 roster -- every player, their level and class, and the buttons that change
-- them.
--
-- Everything here already exists as a slash command. This is a second door onto the same rooms, not a second
-- set of rooms: the level maths, the class write, the teleports and the streamer binding are the same calls
-- /level, /role, /tpto and /bring make. A panel that reimplemented any of them would drift from the command
-- the first time either was fixed.
--
-- The roster is re-checked on EVERY message. A RemoteEvent is reachable by any client in the game, so
-- "the panel only opens for admins" is a statement about the interface, never about security.
local Players = game:GetService("Players")

local ServerConfig = require(game.ServerScriptService.ServerConfig)
if ServerConfig.IsLobby then return end

local Remotes = require(game.ReplicatedStorage.Remotes)
local AdminRoster = require(game.ServerScriptService.AdminRoster)
local Progression = require(game.ServerScriptService.Progression)
local ProgressionConfig = require(game.ReplicatedStorage.ProgressionConfig)
local Classes = require(game.ServerScriptService.Classes)
local ClassConfig = require(game.ReplicatedStorage.ClassConfig)
local StreamerTags = require(game.ServerScriptService.StreamerTags)

--------------------------------------------------------------------------------
-- The picture the panel draws
--------------------------------------------------------------------------------

local function snapshot()
	local rows = {}
	for _, player in ipairs(Players:GetPlayers()) do
		local primary = Classes.Primary(player)
		rows[#rows + 1] = {
			userId = player.UserId,
			name = player.Name,
			display = player.DisplayName,
			level = Progression.GetLevel(player) or 1,
			classId = primary,
			className = primary and ClassConfig.DisplayName(primary) or "ยังไม่มีอาชีพ",
			admin = AdminRoster.IsAdmin(player),
			tiktok = StreamerTags.Get(player) or "",
		}
	end
	table.sort(rows, function(a, b) return a.name:lower() < b.name:lower() end)

	-- The class list travels with the roster so the client never has to know which ids exist or what order
	-- to show them in.
	local classes = {}
	for id in pairs(ClassConfig.Classes) do classes[#classes + 1] = id end
	table.sort(classes)
	local options = {}
	for _, id in ipairs(classes) do
		options[#options + 1] = { id = id, name = ClassConfig.DisplayName(id) }
	end

	return { rows = rows, classes = options, maxLevel = ProgressionConfig.MaxLevel }
end

local function push(player)
	Remotes.AdminPanelData:FireClient(player, snapshot())
end

-- Everyone with the panel open sees a change the moment it happens, so two admins working at once are not
-- each looking at a stale list.
local function pushAll()
	for _, player in ipairs(Players:GetPlayers()) do
		if AdminRoster.IsAdmin(player) then push(player) end
	end
end

--------------------------------------------------------------------------------
-- Setting a level
--
-- Lifted from AdminCommands' /level rather than rewritten: going UP awards the exp each level needs so that
-- body growth, max HP and the refill all happen through the one path that already handles levelling, and
-- going DOWN has no natural path so it is written and re-applied. Two copies of this would drift.
--------------------------------------------------------------------------------

local function setLevel(target, wanted)
	local state = Progression.Get(target)
	if not state then return false, "ยังโหลดข้อมูลไม่เสร็จ" end
	wanted = math.clamp(math.floor(wanted), 1, ProgressionConfig.MaxLevel)

	while Progression.GetLevel(target) < wanted do
		local before = Progression.GetLevel(target)
		Progression.AwardExp(target, ProgressionConfig.ExpForNextLevel(before) - state.exp)
		if Progression.GetLevel(target) == before then break end -- a config that cannot advance
	end
	if Progression.GetLevel(target) > wanted then
		state.level = wanted
		state.exp = 0
		Progression.Refresh(target, target.Character)
	end
	return true
end

--------------------------------------------------------------------------------

Remotes.RequestAdminPanel.OnServerEvent:Connect(function(player)
	if not AdminRoster.IsAdmin(player) then return end
	push(player)
end)

Remotes.RequestAdminAction.OnServerEvent:Connect(function(player, action, userId, value)
	if not AdminRoster.IsAdmin(player) then return end
	if type(action) ~= "string" or type(userId) ~= "number" then return end

	local target = Players:GetPlayerByUserId(userId)
	if not target then return push(player) end

	local function notify(text, kind)
		Remotes.SocialNotify:FireClient(player, kind or "info", text)
	end

	if action == "level" then
		local wanted = tonumber(value)
		if not wanted then return end
		local ok, why = setLevel(target, wanted)
		if not ok then return notify(why, "error") end
		notify(("%s เลเวล %d แล้ว"):format(target.Name, Progression.GetLevel(target)))

	elseif action == "class" then
		local classId = ClassConfig.Match(tostring(value or ""))
		if not classId then return notify("ไม่มีอาชีพนี้", "error") end
		local class = ClassConfig.Get(classId)
		Classes.Set(target, class.tier, classId)
		notify(("%s เป็น %s แล้ว"):format(target.Name, ClassConfig.DisplayName(classId)))

	elseif action == "tpto" then
		-- Go to them. Both teleports move the ADMIN or the TARGET by CFrame directly, which is what the
		-- slash commands do.
		local here = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		local there = target.Character and target.Character:FindFirstChild("HumanoidRootPart")
		if not here or not there then return notify("ยังไม่มีตัวละคร", "error") end
		here.CFrame = there.CFrame * CFrame.new(0, 0, 4)
		notify(("วาปไปหา %s"):format(target.Name))

	elseif action == "bring" then
		local here = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		local there = target.Character and target.Character:FindFirstChild("HumanoidRootPart")
		if not here or not there then return notify("ยังไม่มีตัวละคร", "error") end
		there.CFrame = here.CFrame * CFrame.new(0, 0, 4)
		notify(("ดึง %s มาหา"):format(target.Name))

	elseif action == "tiktok" then
		-- Binding to an empty name clears it, which is how a stream is handed from one player to the next.
		local bound = StreamerTags.Set(target, tostring(value or ""))
		notify(bound ~= "" and ("ผูก %s กับ TikTok @%s แล้ว"):format(target.Name, bound)
			or ("ยกเลิกการผูก TikTok ของ %s"):format(target.Name))

	else
		return
	end

	pushAll()
end)

-- A player joining or leaving changes the list under everyone looking at it.
Players.PlayerAdded:Connect(function() task.defer(pushAll) end)
Players.PlayerRemoving:Connect(function() task.defer(pushAll) end)
