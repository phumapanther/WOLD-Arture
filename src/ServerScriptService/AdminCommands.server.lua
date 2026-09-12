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
local ClassConfig = require(game.ReplicatedStorage.ClassConfig)
local ClassActionConfig = require(game.ReplicatedStorage.ClassActionConfig)
local ProgressionConfig = require(game.ReplicatedStorage.ProgressionConfig)
local Remotes = require(game.ReplicatedStorage.Remotes)
local Inventory = require(game.ServerScriptService.Inventory)
local Vitals = require(game.ServerScriptService.Vitals)
local Progression = require(game.ServerScriptService.Progression)
local Classes = require(game.ServerScriptService.Classes)
local EventState = require(game.ServerScriptService.EventState)
local EventConfig = require(game.ReplicatedStorage.EventConfig)

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

-- /event [name] -- เริ่ม/จบอีเวนต์เดี๋ยวนี้
--
-- The events need ten players and up to forty-five minutes of waiting before they fire on their own, which
-- makes them untestable in a Studio session with one person in it. This is the door round that, and it is
-- admin-only for the same reason every other command here is.
Commands.event = function(admin, args)
	local names = {}
	for id in pairs(EventConfig.Events) do names[#names + 1] = id end
	table.sort(names)

	if not args[1] then
		local running = {}
		for id in pairs(EventState.Active) do running[#running + 1] = id end
		return reply(admin, ("ใช้: /event <%s>  ·  กำลังทำงาน: %s"):format(
			table.concat(names, "|"),
			#running > 0 and table.concat(running, ", ") or "ไม่มี"))
	end

	local id = matchKey(args[1], EventConfig.Events)
	if not id then return reply(admin, ("ไม่มีอีเวนต์ชื่อ %s"):format(args[1])) end

	-- One command, both directions: a running event is stopped and a stopped one is started, because the
	-- thing an admin wants after watching an event is almost always to see it again from the top.
	if EventState.Active[id] then
		if EventState.Stop then EventState.Stop(id) end
		return reply(admin, ("จบอีเวนต์ %s แล้ว"):format(id))
	end
	if EventState.Start then EventState.Start(id) end
	-- Reported from the board rather than assumed: an event whose world effects refuse to apply (a blackout
	-- in a place with no transformers, say) never actually starts.
	reply(admin, EventState.Active[id] and ("เริ่มอีเวนต์ %s แล้ว"):format(id)
		or ("เริ่มอีเวนต์ %s ไม่ได้ ดู Output"):format(id))
end

-- /role <role> [player] -- แอดอาชีพ
Commands.role = function(admin, args)
	if not args[1] then
		local names = {}
		for id in pairs(ClassConfig.Classes) do names[#names + 1] = id end
		table.sort(names)
		return reply(admin, "ใช้: /role <" .. table.concat(names, "|") .. "> [ผู้เล่น]")
	end
	local roleId = ClassConfig.Match(args[1])
	if not roleId then return reply(admin, ("ไม่มีอาชีพชื่อ %s"):format(args[1])) end
	local target = resolveTarget(admin, args[2])
	if not target then return end
	local class = ClassConfig.Get(roleId)
	Classes.Set(target, class.tier, roleId)
	reply(admin, ("%s เป็น %s แล้ว"):format(target.Name, ClassConfig.DisplayName(roleId)))
end

-- /unrole [player] -- ลบอาชีพ
Commands.unrole = function(admin, args)
	local target = resolveTarget(admin, args[1])
	if not target then return end
	-- Clears both tiers: an admin saying "unrole" means all of it, not whichever half they guessed.
	local had = Classes.Primary(target)
	Classes.Clear(target, "basic")
	Classes.Clear(target, "advanced")
	reply(admin, had
		and ("ลบอาชีพ %s ของ %s แล้ว"):format(ClassConfig.DisplayName(had), target.Name)
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

-- /god [player] -- อมตะ. Toggles, and reports which way it went rather than leaving it a guess.
Commands.god = function(admin, args)
	local target = resolveTarget(admin, args[1])
	if not target then return end
	local on = Vitals.SetGodmode(target, not Vitals.IsGodmode(target))
	reply(admin, ("%s %s"):format(target.Name, on and "อมตะแล้ว (เลือดไม่ลด ไม่หิว ไม่จมน้ำ)" or "กลับเป็นปกติ"))
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
		"/god [คน] - อมตะ เปิด/ปิด",
		"/items - รายชื่อไอเทม",
	}, "\n"))
end

--------------------------------------------------------------------------------
-- Dispatch
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- Class commands
--------------------------------------------------------------------------------

-- The commands an advanced class can issue. They live in the SAME table and the same console as the admin
-- commands, because to the person typing there is no difference: "/" then a word. What differs is only who
-- may run it and what it does.
--
-- Listed in ClassCommands rather than Commands so the permission is obvious at the call site: anything in
-- Commands is admin-only, anything here is open to the class that owns it.
local ClassCommands = {}

-- /announce <text> -- ประกาศจากแอดมิน (ทับคำสั่งอาชีพชื่อเดียวกัน: แอดมินประกาศในนามแอดมิน)
Commands.announce = function(admin, args)
	local text = table.concat(args, " ")
	if text == "" then return reply(admin, "ใช้: /announce <ข้อความ>") end
	if #text > 140 then text = text:sub(1, 140) end
	local name = admin.DisplayName ~= "" and admin.DisplayName or admin.Name
	-- "admin" is not a class id, which is exactly how the client knows to paint it red instead of looking
	-- up a class colour that does not exist.
	Remotes.ClassAnnouncement:FireAllClients("admin", name, text)
end

--------------------------------------------------------------------------------
-- The noble's commands of state
--------------------------------------------------------------------------------

-- A noble at the level cap governs, which is not the same as administering. They may move people about,
-- heal, and speak to the server -- the things a ruler does.
--
-- They may NOT conjure items, gold or levels, hand out classes, or become invulnerable. Those are not
-- powers of office, they are powers over the economy: one noble with /give would end item scarcity for the
-- whole server, and there is no way to undo that once it has happened.
--
-- Written as their own functions rather than by pointing at the admin ones, so nobody later adds a
-- dangerous command to a shared list and quietly hands it to every noble.
local NobleCommands = {}

-- /summon <player> -- เรียกตัวมาหา
NobleCommands.summon = function(noble, args)
	local target = findPlayer(args[1])
	if not target then return reply(noble, "ไม่เจอคนชื่อนี้") end
	if target == noble then return reply(noble, "เรียกตัวเองไม่ได้") end
	local mine, theirs = rootOf(noble), rootOf(target)
	if not mine or not theirs then return reply(noble, "ตัวละครยังไม่พร้อม") end
	theirs.CFrame = mine.CFrame * CFrame.new(0, 0, -4)
	reply(noble, ("เรียก %s มาแล้ว"):format(target.Name))
end

-- /goto <player> -- ไปหา
NobleCommands["goto"] = function(noble, args)
	local target = findPlayer(args[1])
	if not target then return reply(noble, "ไม่เจอคนชื่อนี้") end
	if target == noble then return reply(noble, "ไปหาตัวเองไม่ได้") end
	local mine, theirs = rootOf(noble), rootOf(target)
	if not mine or not theirs then return reply(noble, "ตัวละครยังไม่พร้อม") end
	mine.CFrame = theirs.CFrame * CFrame.new(0, 0, 4)
	reply(noble, ("ไปหา %s แล้ว"):format(target.Name))
end

-- /bless <player> -- ฮีลเต็ม
NobleCommands.bless = function(noble, args)
	local target = args[1] and findPlayer(args[1]) or noble
	if not target then return reply(noble, "ไม่เจอคนชื่อนี้") end
	Vitals.Heal(target, Progression.MaxHP(target))
	Vitals.Feed(target, 1000)
	reply(noble, ("ให้พร %s แล้ว"):format(target.Name))
end

-- /fly, /land -- ตรวจการณ์จากที่สูง
NobleCommands.fly = function(noble)
	Remotes.AdminFly:FireClient(noble, true)
	reply(noble, "สลับโหมดบิน (กด Space ขึ้น, Shift ลง, WASD เคลื่อนที่)")
end

NobleCommands.land = function(noble)
	Remotes.AdminFly:FireClient(noble, false)
	reply(noble, "ลงพื้นแล้ว")
end

-- /help -- คำสั่งที่อาชีพของคุณใช้ได้
ClassCommands.help = function(player, args, classId)
	local lines = {
		("คำสั่งของ%s"):format(ClassConfig.DisplayName(classId)),
		"/announce <ข้อความ> - ประกาศให้ทุกคนเห็น",
	}
	-- A noble sees the commands of state on top of the shared ones.
	if Classes.Has(player, "Noble") then
		table.insert(lines, "/summon <คน> - เรียกตัวมาหา")
		table.insert(lines, "/goto <คน> - ไปหา")
		table.insert(lines, "/bless [คน] - ฮีลเต็ม")
		table.insert(lines, "/fly    /land - บิน/ลงพื้น")
	end
	reply(player, table.concat(lines, "\n"))
end

-- /announce <text> -- ประกาศจากอาชีพของคุณ
ClassCommands.announce = function(player, args, classId)
	local text = table.concat(args, " ")
	if text == "" then
		return reply(player, "ใช้: /announce <ข้อความ>")
	end
	if #text > 140 then text = text:sub(1, 140) end

	local name = player.DisplayName ~= "" and player.DisplayName or player.Name
	Remotes.ClassAnnouncement:FireAllClients(classId, name, text)
end

-- Who may run a class command, and how often. An announcement reaches everyone, so the rate limit is the
-- whole point -- without it the console is a way to shout at the server on a loop.
local ClassCooldowns = {} -- [player] = os.clock() deadline

local function mayRunClassCommand(player)
	-- An advanced OR elite class carries commands: a basic one would mean every villager could announce.
	-- Elite first, because it is the higher office and should be the one that speaks.
	local classId = Classes.Get(player, "elite") or Classes.Get(player, "advanced")
	if not classId then return nil end
	local until_ = ClassCooldowns[player]
	if until_ and os.clock() < until_ then
		reply(player, "เพิ่งใช้คำสั่งไปเมื่อกี้")
		return nil
	end
	return classId
end

Players.PlayerRemoving:Connect(function(player)
	ClassCooldowns[player] = nil
end)

--------------------------------------------------------------------------------

local function dispatch(player, message)
	if message:sub(1, 1) ~= "/" then return end

	local parts = {}
	for word in message:sub(2):gmatch("%S+") do
		parts[#parts + 1] = word
	end
	local name = (parts[1] or ""):lower()
	table.remove(parts, 1)

	-- Admin commands first, and ONLY for admins. The check is here rather than at the top of dispatch now
	-- that non-admins have commands of their own -- but it still happens before the command is looked up, so
	-- a non-admin typing "/gold" gets exactly the silence they got before.
	local command = isAdmin(player) and Commands[name] or nil

	if not command then
		-- A noble's commands of state, which only a noble may run. Checked before the shared class commands
		-- so the two tables can hold the same name without one shadowing the other.
		if Classes.Has(player, "Noble") then
			local nobleCommand = NobleCommands[name]
			if nobleCommand then
				local okNoble, errNoble = pcall(nobleCommand, player, parts)
				if not okNoble then
					reply(player, ("คำสั่งพัง: %s"):format(tostring(errNoble)))
				end
				return
			end
		end

		-- Not an admin command they may run: try the class commands, which anyone with the right class may.
		local classCommand = ClassCommands[name]
		if classCommand then
			local classId = mayRunClassCommand(player)
			if not classId then return end
			local okClass, errClass = pcall(classCommand, player, parts, classId)
			if okClass then
				ClassCooldowns[player] = os.clock() + ClassActionConfig.CommandCooldown
			else
				reply(player, ("คำสั่งพัง: %s"):format(tostring(errClass)))
			end
		end
		return -- an unknown "/..." is left alone; other systems use chat commands too
	end

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
