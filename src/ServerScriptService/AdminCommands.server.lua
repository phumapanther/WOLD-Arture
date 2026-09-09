-- AdminCommands.server.lua: chat commands for the owner, for testing the game without grinding for it.
--
-- SECURITY. Everything here can rewrite a player's gold, level and inventory, so:
--   * the allow-list is UserIds, checked server-side on every command -- never a name (names change),
--     never a client-supplied flag, never "is this Studio";
--   * commands arrive either through Player.Chatted or through the AdminCommand remote (the console has to
--     have one: chat is switched off in channel servers, so Chatted may never fire). Both land in the same
--     dispatch, which checks the allow-list BEFORE parsing anything -- so firing the remote grants nothing;
--   * a non-admin typing "/gold 999999", or firing the remote by hand, gets the same silence as typing
--     anything else -- no error, and no hint that the system exists at all.
--
-- Every command acts on the admin unless a player name is added at the end.
local Players = game:GetService("Players")
local ServerConfig = require(game.ServerScriptService.ServerConfig)

if ServerConfig.IsLobby then return end -- nothing to administer in the lobby

local ItemCatalog = require(game.ReplicatedStorage.ItemCatalog)
local RoleConfig = require(game.ReplicatedStorage.RoleConfig)
local ProgressionConfig = require(game.ReplicatedStorage.ProgressionConfig)
local Remotes = require(game.ReplicatedStorage.Remotes)
local Inventory = require(game.ServerScriptService.Inventory)
local Vitals = require(game.ServerScriptService.Vitals)
local Progression = require(game.ServerScriptService.Progression)
local Roles = require(game.ServerScriptService.Roles)

-- The allow-list. UserIds only. There is deliberately no command that grants admin: an admin command that
-- hands out admin is how one leaked account becomes everyone's problem.
local ADMINS = {
	[4871683651] = true, -- phumapanther (owner)
}

local function isAdmin(player)
	return ADMINS[player.UserId] == true
end

--------------------------------------------------------------------------------
-- Feedback
--------------------------------------------------------------------------------

-- Replies go to the admin's own chat. The remote only ever carries text TO the admin; it accepts nothing
-- from the client and grants nothing, so it is not a way in.
local function reply(player, text)
	Remotes.AdminMessage:FireClient(player, text)
end

--------------------------------------------------------------------------------
-- Argument parsing
--------------------------------------------------------------------------------

-- Case-insensitive prefix match over a set of keys. Returns the key (or nil) and whether it was ambiguous.
local function matchKey(text, keys)
	if not text or text == "" then return nil, false end
	local lower = text:lower()
	local hit, ambiguous = nil, false
	for key in pairs(keys) do
		if key:lower() == lower then return key, false end -- an exact name always beats a prefix
		if key:lower():sub(1, #lower) == lower then
			if hit then ambiguous = true end
			hit = hit or key
		end
	end
	return hit, ambiguous
end

-- Finds a player by name or display name. Returns false (not nil) when several match, so the caller can
-- tell "nobody" apart from "which one?".
local function findPlayer(text)
	if not text or text == "" then return nil end
	text = text:lower()
	local hit
	for _, p in ipairs(Players:GetPlayers()) do
		if p.Name:lower() == text or p.DisplayName:lower() == text then return p end
		if p.Name:lower():sub(1, #text) == text or p.DisplayName:lower():sub(1, #text) == text then
			if hit and hit ~= p then return false end
			hit = p
		end
	end
	return hit
end

-- Resolves the optional trailing "[player]": absent means the admin themselves.
local function resolveTarget(admin, text)
	if not text or text == "" then return admin end
	local found = findPlayer(text)
	if found == false then
		reply(admin, ("ชื่อ %s ตรงกับหลายคน"):format(text))
		return nil
	end
	if not found then
		reply(admin, ("ไม่เจอผู้เล่นชื่อ %s"):format(text))
		return nil
	end
	return found
end

local function rootOf(player)
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart")
end

--------------------------------------------------------------------------------
-- The commands
--------------------------------------------------------------------------------

local Commands = {}

-- /give <item> [count] [player] -- เสกของ
Commands.give = function(admin, args)
	local id, ambiguous = matchKey(args[1], ItemCatalog.Items)
	if ambiguous then return reply(admin, ("%s ตรงกับหลายไอเทม"):format(args[1])) end
	if not id then return reply(admin, "ใช้: /give <ไอเทม> [จำนวน] [ผู้เล่น]   (/items = รายชื่อ)") end

	local count = math.clamp(math.floor(tonumber(args[2]) or 1), 1, 999)
	local target = resolveTarget(admin, args[3])
	if not target then return end

	-- AddItem returns false when the bag filled up part-way; say so rather than claiming success.
	local ok = Inventory.AddItem(target, id, count)
	reply(admin, ("%s %s x%d -> %s%s"):format(ok and "ให้" or "ให้ได้บางส่วน",
		ItemCatalog.Get(id).name, count, target.Name, ok and "" or " (กระเป๋าเต็ม)"))
end

-- /gold <amount> [player] -- เสกตัง; a negative amount takes it away
Commands.gold = function(admin, args)
	local amount = tonumber(args[1])
	if not amount then return reply(admin, "ใช้: /gold <จำนวน> [ผู้เล่น]  (ติดลบ = ลดตัง)") end
	local target = resolveTarget(admin, args[2])
	if not target then return end
	Inventory.AddGold(target, math.floor(amount))
	local state = Inventory.Get(target)
	reply(admin, ("ตัง %s%d -> %s (ตอนนี้ %d)"):format(amount >= 0 and "+" or "",
		math.floor(amount), target.Name, state and state.gold or 0))
end

-- /tpto <player> -- วาปไปหา
Commands.tpto = function(admin, args)
	if not args[1] then return reply(admin, "ใช้: /tpto <ผู้เล่น>") end
	local target = resolveTarget(admin, args[1])
	if not target then return end
	if target == admin then return reply(admin, "วาปไปหาตัวเองไม่ได้") end
	local theirs, mine = rootOf(target), rootOf(admin)
	if not theirs or not mine then return reply(admin, "ตัวละครยังไม่พร้อม") end
	-- Beside them rather than inside them, or the two rigs shove each other apart.
	mine.CFrame = theirs.CFrame * CFrame.new(0, 0, 4)
	reply(admin, ("วาปไปหา %s"):format(target.Name))
end

-- /bring <player> -- ดึงมาหา
Commands.bring = function(admin, args)
	if not args[1] then return reply(admin, "ใช้: /bring <ผู้เล่น>") end
	local target = resolveTarget(admin, args[1])
	if not target then return end
	if target == admin then return reply(admin, "ดึงตัวเองมาหาตัวเองไม่ได้") end
	local theirs, mine = rootOf(target), rootOf(admin)
	if not theirs or not mine then return reply(admin, "ตัวละครยังไม่พร้อม") end
	theirs.CFrame = mine.CFrame * CFrame.new(0, 0, 4)
	reply(admin, ("ดึง %s มาแล้ว"):format(target.Name))
end

-- /goto <x> <y> <z> -- วาปไปพิกัด. With only two numbers they are x,z and the ground is raycast for.
Commands["goto"] = function(admin, args)
	local first, second, third = tonumber(args[1]), tonumber(args[2]), tonumber(args[3])
	if not first or not second then return reply(admin, "ใช้: /goto <x> <y> <z>  หรือ  /goto <x> <z>") end
	local x, y, z = first, third and second or nil, third or second

	local mine = rootOf(admin)
	if not mine then return reply(admin, "ตัวละครยังไม่พร้อม") end
	if not y then
		local ray = workspace:Raycast(Vector3.new(x, 4000, z), Vector3.new(0, -8000, 0))
		if not ray then return reply(admin, "ไม่เจอพื้นตรงนั้น ใส่ y ด้วย") end
		y = ray.Position.Y + 5
	end
	mine.CFrame = CFrame.new(x, y, z)
	reply(admin, ("วาปไป %.0f, %.0f, %.0f"):format(x, y, z))
end

-- /role <role> [player] -- แอดอาชีพ
Commands.role = function(admin, args)
	if not args[1] then
		local names = {}
		for id in pairs(RoleConfig.Roles) do names[#names + 1] = id end
		table.sort(names)
		return reply(admin, "ใช้: /role <" .. table.concat(names, "|") .. "> [ผู้เล่น]")
	end
	local roleId = RoleConfig.Match(args[1])
	if not roleId then return reply(admin, ("ไม่มีอาชีพชื่อ %s"):format(args[1])) end
	local target = resolveTarget(admin, args[2])
	if not target then return end
	Roles.Set(target, roleId)
	reply(admin, ("%s เป็น %s แล้ว"):format(target.Name, RoleConfig.DisplayName(roleId)))
end

-- /unrole [player] -- ลบอาชีพ
Commands.unrole = function(admin, args)
	local target = resolveTarget(admin, args[1])
	if not target then return end
	local had = Roles.Get(target)
	Roles.Clear(target)
	reply(admin, had
		and ("ลบอาชีพ %s ของ %s แล้ว"):format(RoleConfig.DisplayName(had), target.Name)
		or ("%s ไม่มีอาชีพอยู่แล้ว"):format(target.Name))
end

-- /kill [player] -- ฆ่า
Commands.kill = function(admin, args)
	local target = resolveTarget(admin, args[1])
	if not target then return end
	-- The real death path, so the level reset and every other death hook fire exactly as they would in play.
	Vitals.Kill(target)
	reply(admin, ("ฆ่า %s แล้ว"):format(target.Name))
end

-- /heal [player] -- ฟื้นฟูเต็ม
Commands.heal = function(admin, args)
	local target = resolveTarget(admin, args[1])
	if not target then return end
	if Vitals.IsDowned(target) then
		Vitals.Recover(target, 1) -- standing back up is the only meaningful heal while downed
	else
		Vitals.Heal(target, Progression.MaxHP(target))
		Vitals.Feed(target, Progression.MaxHunger(target))
	end
	Vitals.AddMana(target, 99)
	Vitals.SetStamina(target, 100)
	reply(admin, ("ฟื้นฟู %s เต็มแล้ว"):format(target.Name))
end

-- /level <n> [player] -- ตั้งเลเวล
Commands.level = function(admin, args)
	local wanted = tonumber(args[1])
	if not wanted then return reply(admin, "ใช้: /level <เลเวล> [ผู้เล่น]") end
	wanted = math.clamp(math.floor(wanted), 1, ProgressionConfig.MaxLevel)
	local target = resolveTarget(admin, args[2])
	if not target then return end

	local state = Progression.Get(target)
	if not state then return reply(admin, "ยังโหลดข้อมูลไม่เสร็จ") end

	-- Going UP awards the exp each level needs, so body growth, max HP and the refill all happen through the
	-- one path that already handles levelling. exp resets per level, so this is a loop, not one big award.
	while Progression.GetLevel(target) < wanted do
		local before = Progression.GetLevel(target)
		Progression.AwardExp(target, ProgressionConfig.ExpForNextLevel(before) - state.exp)
		if Progression.GetLevel(target) == before then break end -- guard: a config that cannot advance
	end
	-- Going DOWN has no natural path, so write it and re-apply everything that depends on the level.
	if Progression.GetLevel(target) > wanted then
		state.level = wanted
		state.exp = 0
		Progression.Refresh(target, target.Character)
	end
	reply(admin, ("%s เลเวล %d แล้ว"):format(target.Name, Progression.GetLevel(target)))
end

-- /fly [speed] -- บิน
-- Flight itself runs on the admin's own client (it owns the character's physics); this only grants it,
-- which is the half that must be checked server-side.
Commands.fly = function(admin, args)
	local speed = tonumber(args[1])
	speed = speed and math.clamp(speed, 10, 400) or nil
	Remotes.AdminFly:FireClient(admin, "toggle", speed)
	reply(admin, "สลับโหมดบิน (กด Space ขึ้น, Shift ลง, WASD เคลื่อนที่)")
end

-- /land -- ลงพื้น, for when flight has been left on somewhere awkward
Commands.land = function(admin)
	Remotes.AdminFly:FireClient(admin, "off")
	reply(admin, "ลงพื้นแล้ว")
end

-- /items -- the catalog ids, since /give needs them
Commands.items = function(admin)
	local ids = {}
	for id in pairs(ItemCatalog.Items) do ids[#ids + 1] = id end
	table.sort(ids)
	reply(admin, "ไอเทม: " .. table.concat(ids, ", "))
end

-- /admin -- the list, so nothing has to be remembered
Commands.admin = function(admin)
	reply(admin, table.concat({
		"คำสั่งแอดมิน (ไม่ใส่ชื่อ = ใช้กับตัวเอง)",
		"/give <ไอเทม> [จำนวน] [คน] - เสกของ",
		"/gold <จำนวน> [คน] - เสกตัง (ติดลบ = ลด)",
		"/tpto <คน> - วาปไปหา    /bring <คน> - ดึงมาหา",
		"/goto <x> <y> <z> - วาปไปพิกัด",
		"/role <อาชีพ> [คน]    /unrole [คน]",
		"/kill [คน]    /heal [คน]    /level <n> [คน]",
		"/fly [ความเร็ว]  /land - บิน / ลงพื้น",
		"/items - รายชื่อไอเทม",
	}, "\n"))
end

--------------------------------------------------------------------------------
-- Dispatch
--------------------------------------------------------------------------------

local function dispatch(player, message)
	-- The admin check comes FIRST, before the message is even parsed: a non-admin's chat is never treated as
	-- a command whatever it contains.
	if not isAdmin(player) then return end
	if message:sub(1, 1) ~= "/" then return end

	local parts = {}
	for word in message:sub(2):gmatch("%S+") do
		parts[#parts + 1] = word
	end
	local name = (parts[1] or ""):lower()
	table.remove(parts, 1)

	local command = Commands[name]
	if not command then return end -- an unknown "/..." is left alone; other systems use chat commands too

	-- A command that errors must not kill the Chatted connection, or every later command silently stops.
	local ok, err = pcall(command, player, parts)
	if not ok then
		reply(player, ("คำสั่งพัง: %s"):format(tostring(err)))
		warn(("[AdminCommands] /%s failed: %s"):format(name, tostring(err)))
	end
end

local function watch(player)
	player.Chatted:Connect(function(message)
		dispatch(player, message)
	end)
end

Players.PlayerAdded:Connect(watch)
-- Anyone already in the server when this starts (Studio Play, a hot reload) needs hooking too.
for _, player in ipairs(Players:GetPlayers()) do
	watch(player)
end

-- The admin console sends here as well as through chat. Chat is switched off in channel servers (the HUD
-- disables the CoreGui chat), so Player.Chatted may never fire at all -- this is the path that always works.
--
-- Firing this remote grants NOTHING on its own: dispatch checks the UserId allow-list first, so a non-admin
-- who finds the remote and fires it gets exactly the silence they would get from typing in chat.
Remotes.AdminCommand.OnServerEvent:Connect(function(player, message)
	if typeof(message) ~= "string" then return end -- never trust the shape of anything a client sends
	if #message > 200 then return end -- a command is short; anything longer is someone probing
	dispatch(player, message)
end)
