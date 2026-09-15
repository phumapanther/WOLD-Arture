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
local CommandCatalog = require(game.ReplicatedStorage.CommandCatalog)
local DayNightAccess = require(game.ServerScriptService.DayNightAccess)
local Inventory = require(game.ServerScriptService.Inventory)
local Vitals = require(game.ServerScriptService.Vitals)
local Progression = require(game.ServerScriptService.Progression)
local Classes = require(game.ServerScriptService.Classes)
local EventState = require(game.ServerScriptService.EventState)
local EventConfig = require(game.ReplicatedStorage.EventConfig)
local VehicleConfig = require(game.ReplicatedStorage.Vehicle.Config)
local VehicleService = require(game.ServerScriptService.Vehicle.Service)
local VehicleStations = require(game.ServerScriptService.Vehicle.Stations)

-- Who is an admin now lives in AdminRoster: it is written in source for the owners, granted in-game for
-- everyone else, and kept in a DataStore so a grant survives a restart. This file only asks.
local AdminRoster = require(game.ServerScriptService.AdminRoster)
local PlayerJoin = require(game.ServerScriptService.PlayerJoin)

local function isAdmin(player)
	return AdminRoster.IsAdmin(player)
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

-- /blackout และ /slime -- บังคับให้อีเวนต์นั้นเกิดเดี๋ยวนี้
--
-- /event ทำได้อยู่แล้ว แต่มันเป็นปุ่มสลับ: กดตอนอีเวนต์ยังไม่เกิด = เริ่ม กดตอนกำลังเกิด = จบ ซึ่งอันตราย
-- เวลาอยากได้แค่ "ให้เกิดเดี๋ยวนี้" แล้วเผลอกดซ้ำ สองคำสั่งนี้จึงมีทิศทางเดียว: เรียกเปล่าๆ = เริ่ม
-- ต้องพิมพ์ off ถึงจะจบ และไม่สนใจเงื่อนไข "ผู้เล่นครบ 10 คน" เลย เพราะทั้งคู่มีไว้ทดสอบคนเดียว
--
-- สถานะที่รายงานกลับอ่านจาก EventState ไม่ใช่จากการเดา: อีเวนต์ที่ผลกับโลกใช้ไม่ได้ (ไฟดับในเพลสที่ยังไม่มี
-- โมเดล Transformer) จะถูก WorldEvents ยกเลิกตัวเองทิ้ง แล้วบรรทัดตอบกลับจะบอกว่าไม่ได้เริ่ม
local function forceEvent(admin, id, args, label)
	local sub = (args[1] or ""):lower()
	local entry = EventState.Active[id]

	if sub == "off" or sub == "stop" or sub == "end" then
		if not entry then return reply(admin, ("%s ไม่ได้เกิดอยู่"):format(label)) end
		if EventState.Stop then EventState.Stop(id) end
		return reply(admin, ("จบ%sแล้ว"):format(label))
	end

	if entry then
		-- กำลังเกิดอยู่แล้ว บอกว่าเหลืออะไรแทนที่จะเริ่มซ้ำ (เริ่มซ้ำไม่ได้อยู่แล้ว WorldEvents กันไว้)
		local detail = entry.detail
		if not detail and entry.endsAt then
			local left = math.max(0, entry.endsAt - workspace:GetServerTimeNow())
			detail = ("เหลืออีก %d:%02d"):format(math.floor(left / 60), math.floor(left % 60))
		end
		return reply(admin, ("%s กำลังเกิดอยู่แล้ว%s  ·  พิมพ์ /%s off เพื่อจบ")
			:format(label, detail and (" (" .. detail .. ")") or "", id))
	end

	if EventState.Start then EventState.Start(id) end
	if not EventState.Active[id] then
		return reply(admin, ("เริ่ม%sไม่ได้ ดูข้อความใน Output"):format(label))
	end
	reply(admin, ("บังคับให้เกิด%sแล้ว  ·  พิมพ์ /%s off เพื่อจบ"):format(label, id))
end

-- /blackout [off] -- บังคับให้ไฟดับทั้งเมืองเดี๋ยวนี้
Commands.blackout = function(admin, args)
	forceEvent(admin, "blackout", args, "อีเวนต์ไฟดับ")
end

-- /slime [off] -- บังคับให้สไลม์กลายพันธุ์โผล่เดี๋ยวนี้
Commands.slime = function(admin, args)
	forceEvent(admin, "slime", args, "อีเวนต์สไลม์กลายพันธุ์")
end

-- /mob [จำนวน] -- เสกมอนสุ่มรอบตัว ห่าง 15 สตัด ไล่ล่าเฉพาะคนสั่ง ไม่เลิกตาม
--
-- Picks from EVERY monster in the game, both batches: GatherConfig.Mobs is one table, so a kind added
-- tomorrow is in the pool tomorrow with nothing here to change.
Commands.mob = function(admin, args)
	local MobAccess = require(game.ServerScriptService.MobAccess)
	if not MobAccess.SpawnHunters then
		return reply(admin, "ระบบมอนยังไม่พร้อม (อยู่ในล็อบบี้?)")
	end

	-- Capped rather than trusted: a mistyped /mob 9999 would be unrecoverable for whoever typed it.
	local count = math.clamp(tonumber(args[1]) or 1, 1, 20)
	local spawned, names = MobAccess.SpawnHunters(admin, 15, count)
	if spawned == 0 then
		return reply(admin, "หาที่วางมอนไม่ได้ ลองขยับที่")
	end
	reply(admin, ("เสกมอน %d ตัว: %s (ไล่ล่าคุณคนเดียว ไม่เลิกตาม)")
		:format(spawned, table.concat(names, ", ")))
end

-- /chest [ไม้|เหล็ก|เงิน|ทอง] -- ทำให้หีบสมบัติเกิดข้างตัว
--
-- The chests have no timer of their own: this and the chest items in a player's bag are the only two ways
-- one gets into the world, which is what the user asked for.
Commands.chest = function(admin, args)
	local ChestAccess = require(game.ServerScriptService.ChestAccess)
	local ChestConfig = require(game.ReplicatedStorage.ChestConfig)
	if not ChestAccess.SpawnNear then
		return reply(admin, "ระบบหีบยังไม่พร้อม (อยู่ในล็อบบี้?)")
	end

	local WORDS = {
		["ไม้"] = "Chest_Wood", wood = "Chest_Wood",
		["เหล็ก"] = "Chest_Ironbound", iron = "Chest_Ironbound",
		["เงิน"] = "Chest_Silver", silver = "Chest_Silver",
		["ทอง"] = "Chest_Gold", gold = "Chest_Gold",
	}
	local word = (args[1] or ""):lower()
	local tier = WORDS[word]
	-- No argument means a random grade, which is what makes the command useful for testing the odds rather
	-- than one chest at a time.
	if word == "" then
		tier = ChestConfig.Order[math.random(#ChestConfig.Order)]
	end
	if not tier then
		return reply(admin, "ใช้: /chest [ไม้|เหล็ก|เงิน|ทอง]")
	end

	local spec = ChestConfig.Chests[tier]
	if ChestAccess.SpawnNear(admin, tier) then
		reply(admin, ("วาง%sไว้ข้างตัวแล้ว"):format(spec and spec.name or tier))
	else
		reply(admin, "หาที่วางหีบไม่ได้ ลองขยับที่")
	end
end

-- /weather <รายการ|auto> -- ตั้งสภาพอากาศ หรือปล่อยให้สุ่มเอง
Commands.weather = function(admin, args)
	local WeatherAccess = require(game.ServerScriptService.WeatherAccess)
	local WeatherConfig = require(game.ReplicatedStorage.WeatherConfig)
	if not WeatherAccess.Set then
		return reply(admin, "ระบบอากาศยังไม่พร้อม (อยู่ในล็อบบี้?)")
	end

	local word = (args[1] or ""):lower()
	if word == "" then
		local names = {}
		for _, id in ipairs(WeatherConfig.Order) do
			names[#names + 1] = ("%s (%s)"):format(id, WeatherConfig.Kinds[id].name)
		end
		return reply(admin, "ใช้: /weather <" .. table.concat(names, " | ") .. " | auto>")
	end

	if word == "auto" then
		WeatherAccess.Set(nil)
		return reply(admin, "อากาศกลับไปสุ่มเองตามเวลา")
	end

	-- Accept the English id or the Thai name, so the admin can type whichever they are looking at.
	local picked
	for _, id in ipairs(WeatherConfig.Order) do
		local kind = WeatherConfig.Kinds[id]
		if id:lower() == word or kind.name == args[1] then picked = id break end
	end
	if not picked then
		return reply(admin, "ไม่รู้จักสภาพอากาศนี้ พิมพ์ /weather เปล่าๆ เพื่อดูรายการ")
	end

	WeatherAccess.Set(picked)
	reply(admin, ("ตั้งอากาศเป็น %s แล้ว (ค้างไว้จนกว่าจะสั่ง /weather auto)"):format(WeatherConfig.Kinds[picked].name))
end

-- /veh <key|reg|here|stow|status> [ชนิด|ทะเบียน] -- เครื่องมือทดสอบพาหนะ
--
-- แทนคำสั่งแชท /veh ของโปรเจ็ค WOLD-Vehicle ที่ไม่ได้ยกมา (ไฟล์นั้นตั้งใจให้ลบก่อนปล่อยเกม) เอาเฉพาะสี่
-- คำสั่งที่จำเป็นต่อการทดสอบจริง และอยู่หลังรั้ว UserId เดียวกับคำสั่งแอดมินอื่นทั้งหมด
Commands.veh = function(admin, args)
	local sub = (args[1] or ""):lower()

	if sub == "key" then
		-- กุญแจอย่างเดียว ยังไม่จดทะเบียน: นี่คือหนึ่งในสองทางที่กุญแจเกิดขึ้นได้ในเกมตอนนี้ (อีกทางคือหีบ
		-- ทดสอบ) การจดเป็นอีกขั้นหนึ่ง ทำที่บารอนเวนหรือด้วย /veh reg
		local vtype = matchKey(args[2] or "Car", VehicleConfig.Types)
		if not vtype then return reply(admin, "ใช้: /veh key <Car|Boat|Airship>") end
		local plate, err = VehicleService.issueKey(admin, vtype)
		if not plate then return reply(admin, tostring(err)) end
		return reply(admin, ("ได้กุญแจ %s แล้ว ยังไม่จดทะเบียน — /veh reg %s หรือไปหาบารอนเวน"):format(plate, plate))

	elseif sub == "reg" then
		-- ขั้นที่สอง จากแชท เพื่อให้ทดสอบวงจรได้ครบโดยไม่ต้องเดินไปหา NPC
		local plate = args[2]
		if not plate then return reply(admin, "ใช้: /veh reg <ทะเบียน>") end
		local done, err = VehicleService.register(admin, plate:upper())
		return reply(admin, done and ("จดทะเบียน %s แล้ว"):format(done) or tostring(err))

	elseif sub == "here" then
		local plate = args[2]
		if not plate then return reply(admin, "ใช้: /veh here <ทะเบียน>") end
		-- ไม่ผ่านสถานี = เกิดข้างหน้าผู้เรียก 20 studs และไม่มีลานจอดให้คิดระยะ ค่าบริการจึงคิดจากจุดนั้น
		local ok, result = VehicleService.summon(admin, plate:upper(), nil)
		return reply(admin, ok and ("เรียก %s มาแล้ว"):format(plate:upper()) or tostring(result))

	elseif sub == "stow" then
		local plate = args[2]
		if plate then
			local ok, err = VehicleService.stow(plate:upper(), admin)
			return reply(admin, ok and ("ฝาก %s แล้ว"):format(plate:upper()) or tostring(err))
		end
		local n = 0
		for active in pairs(VehicleService.Active) do
			if VehicleService.stow(active) then n += 1 end
		end
		return reply(admin, ("เก็บพาหนะในโลกทั้งหมด %d คัน"):format(n))

	elseif sub == "status" then
		local lines = {}
		for _, station in pairs(VehicleStations.List) do
			local at = station.resolvedPos
			lines[#lines + 1] = ("%s %s ที่ %d,%d,%d"):format(station.id, station.vtype,
				at and at.X or 0, at and at.Y or 0, at and at.Z or 0)
		end
		for plate, record in pairs(VehicleService.Active) do
			lines[#lines + 1] = ("%s อยู่ที่ %d,%d,%d เชื้อเพลิง %d%%"):format(plate,
				record.hull.Position.X, record.hull.Position.Y, record.hull.Position.Z,
				VehicleService.fuelPercent(record))
		end
		return reply(admin, #lines > 0 and table.concat(lines, " · ") or "ยังไม่มีจุดเรียกและไม่มีพาหนะในโลก")
	end

	reply(admin, "ใช้: /veh key <ชนิด> · /veh here <ทะเบียน> · /veh stow [ทะเบียน] · /veh status")
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

-- /admin -- the list, so nothing has to be remembered.
--
-- Rendered from CommandCatalog rather than typed out here. The hand-written version had already fallen
-- behind the real command table -- /event, /blackout, /slime, /veh and /announce all existed and none of
-- them were listed -- and the console's autocomplete needs the same list, which a block of Thai inside a
-- reply string could not give it.
Commands.admin = function(admin)
	local lines = { "คำสั่งแอดมิน (ไม่ใส่ชื่อ = ใช้กับตัวเอง)" }
	for _, line in ipairs(CommandCatalog.HelpLines("admin")) do
		table.insert(lines, line)
	end
	reply(admin, table.concat(lines, "\n"))
end

-- /anim <ท่า> [คน] -- สั่งเล่นท่าทาง
--
-- Sent to the target's own client to play, not played from here. An emote on your own Animator replicates to
-- everyone by itself, which is the whole reason the system is built that way -- and a server-side track on a
-- player character is fighting the client for the same rig, which the crawl and the carry both lost.
--
-- "/anim" with no argument lists what there is, including the poses still waiting on an upload: an admin
-- testing the set needs to see the gaps, not have them hidden.
Commands.anim = function(admin, args)
	local EmoteConfig = require(game.ReplicatedStorage.EmoteConfig)

	if not args[1] then
		local ready, waiting = {}, {}
		for _, e in ipairs(EmoteConfig.Emotes) do
			table.insert(e.anim ~= "" and ready or waiting, e.id)
		end
		return reply(admin, ("ท่าที่ใช้ได้: %s%s"):format(table.concat(ready, ", "),
			#waiting > 0 and ("\nยังไม่ได้อัป: " .. table.concat(waiting, ", ")) or ""))
	end

	local name = matchKey(args[1], (function()
		local set = {}
		for _, id in ipairs(EmoteConfig.Names()) do set[id] = true end
		return set
	end)())
	if not name then return reply(admin, ("ไม่มีท่า %s -- /anim ดูรายชื่อ"):format(tostring(args[1]))) end

	local entry = EmoteConfig.Get(name)
	if entry.anim == "" then
		return reply(admin, ("ท่า %s ยังไม่ได้อัปโหลด"):format(entry.label))
	end

	local target = resolveTarget(admin, args[2])
	if not target then return end
	Remotes.PlayEmote:FireClient(target, name)
	reply(admin, ("สั่ง %s ทำท่า %s"):format(target.Name, entry.label))
end

-- /setadmin <คน> -- ตั้งเป็นแอดมิน (เฉพาะเจ้าของเกม)
--
-- Only a ROOT may run this -- the owners written into AdminRoster, not admins it granted. The file this
-- command was added to refused to have one at all, and the reason was sound: an admin command that hands out
-- admin turns one leaked account into everyone's problem. Keeping the grant in the owners' hands is what
-- stops that cascading, while still giving the command that was asked for.
Commands.setadmin = function(admin, args)
	if not AdminRoster.IsRoot(admin) then
		return reply(admin, "เฉพาะเจ้าของเกมเท่านั้นที่ตั้งแอดมินได้")
	end
	local target = resolveTarget(admin, args[1])
	if not target then return end
	if target == admin then return reply(admin, "ตั้งตัวเองไม่ได้") end

	local ok, err = AdminRoster.Grant(target.UserId)
	if not ok then return reply(admin, tostring(err)) end
	reply(admin, ("ตั้ง %s (%d) เป็นแอดมินแล้ว"):format(target.Name, target.UserId))
	Remotes.AdminMessage:FireClient(target, "คุณได้สิทธิ์แอดมินแล้ว -- กด F2 เพื่อเปิดคอนโซล")
end

-- /unadmin <คน> -- ถอนแอดมิน
Commands.unadmin = function(admin, args)
	if not AdminRoster.IsRoot(admin) then
		return reply(admin, "เฉพาะเจ้าของเกมเท่านั้นที่ถอนแอดมินได้")
	end
	local target = resolveTarget(admin, args[1])
	if not target then return end
	local ok, err = AdminRoster.Revoke(target.UserId)
	if not ok then return reply(admin, tostring(err)) end
	reply(admin, ("ถอนแอดมินของ %s แล้ว"):format(target.Name))
end

-- /admins -- ดูรายชื่อแอดมินทั้งหมด
Commands.admins = function(admin)
	local lines = {}
	for _, entry in ipairs(AdminRoster.List()) do
		local name = entry.userId
		local ok, resolved = pcall(function() return Players:GetNameFromUserIdAsync(entry.userId) end)
		if ok then name = resolved end
		table.insert(lines, ("%s (%d)%s"):format(name, entry.userId, entry.root and "  [ถาวร]" or ""))
	end
	reply(admin, "แอดมิน: " .. table.concat(lines, ", "))
end

--------------------------------------------------------------------------------
-- The world clock
--------------------------------------------------------------------------------

-- The words an admin is likely to reach for, and the hour each one means. Morning is the hour players
-- already start at; night is deep night rather than dusk, because "night" asked for as a setting means dark.
local TIME_WORDS = {
	["เช้า"] = 7, morning = 7, day = 12, ["กลางวัน"] = 12, noon = 12,
	["เย็น"] = 18, evening = 18, dusk = 18.5,
	["กลางคืน"] = 0, night = 0, midnight = 0,
}

-- /time <เช้า|กลางคืน|ชั่วโมง|auto> -- ตั้งเวลาของโลก หรือปล่อยให้เดินเอง
Commands.time = function(admin, args)
	if not DayNightAccess.Hold then
		return reply(admin, "ระบบเวลายังไม่พร้อม")
	end

	local word = (args[1] or ""):lower()
	if word == "" then
		local held = DayNightAccess.HeldAt()
		return reply(admin, held
			and ("เวลาถูกล็อกไว้ที่ %.1f น. — /time auto เพื่อปล่อยให้เดินต่อ"):format(held)
			or ("เวลาเดินปกติ ตอนนี้ %.1f น."):format(game:GetService("Lighting").ClockTime))
	end

	if word == "auto" or word == "ปกติ" then
		DayNightAccess.Hold(nil)
		return reply(admin, "เวลากลับมาเดินเองแล้ว")
	end

	-- A word, or an hour typed straight in. Both end up as the same thing: a number to pin the sky to.
	local hour = TIME_WORDS[word] or TIME_WORDS[args[1] or ""] or tonumber(args[1])
	if not hour then
		return reply(admin, "ใช้: /time เช้า | กลางวัน | เย็น | กลางคืน | <ชั่วโมง 0-24> | auto")
	end

	local now = DayNightAccess.Hold(hour)
	reply(admin, ("ล็อกเวลาไว้ที่ %.1f น. แล้ว — /time auto เพื่อปล่อยให้เดินต่อ"):format(now))
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

-- What a noble may run out of the ADMIN table, at the user's request: exactly these seven, no more.
--
-- Naming admin commands rather than reimplementing them is the point. The noble table below used to hold its
-- own /goto and its own /fly, which meant two versions of each to keep in step -- and they had already
-- drifted, since the noble /goto went to a PLAYER while the admin one went to coordinates. One
-- implementation, one behaviour, and the only thing that differs is who is allowed to reach it.
local NOBLE_MAY_RUN = {
	tpto = true, bring = true, ["goto"] = true,
	role = true, unrole = true,
	fly = true, land = true,
}

-- /announce <text> -- ประกาศจากแอดมิน (ทับคำสั่งอาชีพชื่อเดียวกัน: แอดมินประกาศในนามแอดมิน)
-- /fw [จำนวน] [ระยะ] [ความสูง] -- ยิงพลุขึ้นฟ้าเป็นวงรอบตัว
--
-- ค่าตั้งต้น 8 ดอก ห่าง 100 studs สูง 120 ตามที่ผู้ใช้ขอ — **ห่างออกไป ไม่ใช่รอบตัวติดๆ** เพราะพลุที่แตก
-- เหนือหัวพอดีคือการมองเห็นก้นดอกพลุ ต้องยืนห่างถึงจะเห็นทรง
Commands.fw = function(admin, args)
	local Fireworks = require(game.ServerScriptService.Fireworks)
	local character = admin.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then return reply(admin, "ยังไม่มีตัวละคร") end

	-- /fw at <x> <z> [ความสูง] -- ยิงดอกเดียวที่พิกัดนั้น ไม่เกี่ยวกับตำแหน่งตัวเอง
	--
	-- หาพื้นเองจาก x/z เหมือนจุดเรียกพาหนะ คนสั่งจึงไม่ต้องรู้ความสูงของภูมิประเทศตรงนั้น
	if (args[1] or ""):lower() == "at" then
		local x, z = tonumber(args[2]), tonumber(args[3])
		if not x or not z then return reply(admin, "ใช้: /fw at <x> <z> [ความสูง]") end
		local height = math.clamp(tonumber(args[4]) or 120, 30, 400)
		local from = Fireworks.At(x, z, height, root.Position.Y)
		return reply(admin, ("ยิงพลุที่ (%d, %d) สูง %d"):format(from.X, from.Z, height))
	end

	-- จำกัดไว้ทุกตัว: พลุหนึ่งดอกคือ particle 250 ตัวกับแสงหนึ่งดวง ยิงทีละร้อยดอกคือเซิร์ฟกระตุกทั้งเซิร์ฟ
	local count = math.clamp(tonumber(args[1]) or 8, 1, 24)
	local radius = math.clamp(tonumber(args[2]) or 100, 20, 400)
	local height = math.clamp(tonumber(args[3]) or 120, 30, 400)

	Fireworks.Ring(root.Position, radius, count, height)
	reply(admin, ("ยิงพลุ %d ดอก ห่าง %d studs สูง %d"):format(count, radius, height))
end

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
-- Nobles
--------------------------------------------------------------------------------

-- A noble's own command table used to live here -- /summon, /bless, and its own /goto, /fly and /land. It is
-- gone: the user cut the noble's powers to the seven named in NOBLE_MAY_RUN above, and every one of those is
-- an admin command a noble is simply allowed to reach.
--
-- /summon and /bless were the two that were not on that list, so they no longer exist for anyone. Say so if
-- they should come back; nothing else depended on them.

--------------------------------------------------------------------------------
-- Class commands
--------------------------------------------------------------------------------

-- /help -- คำสั่งที่อาชีพของคุณใช้ได้
ClassCommands.help = function(player, args, classId)
	local lines = {
		("คำสั่งของ%s"):format(ClassConfig.DisplayName(classId)),
		"/announce <ข้อความ> - ประกาศให้ทุกคนเห็น",
	}
	-- A noble sees the seven commands of state on top of the shared ones. Built from the same table the
	-- dispatcher checks, so what a noble is shown and what a noble can run cannot drift apart -- which the
	-- hand-written version this replaced already had.
	if Classes.Has(player, "Noble") then
		for _, entry in ipairs(CommandCatalog.Commands) do
			if NOBLE_MAY_RUN[entry.name] then
				table.insert(lines, ("/%s %s- %s"):format(entry.name,
					entry.args == "" and "" or entry.args .. " ", entry.desc))
			end
		end
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

-- The client is TOLD whether it is an admin, rather than keeping its own copy of the list. The console used
-- to hold a second hand-maintained table, which is exactly the kind of thing that drifts -- and the admin
-- chest needs the same answer. Published as an Attribute, which replicates by itself.
--
-- It grants nothing: every command is checked against the roster on the server, so a client that forges the
-- attribute has drawn itself a box that will be ignored.
PlayerJoin.Each(function(player)
	AdminRoster.Publish(player)
end)

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
		-- A noble runs the ADMIN implementation of the seven commands of state, rather than a copy of its
		-- own. Checked before the shared class commands so a name in both does not shadow the other.
		if NOBLE_MAY_RUN[name] and Classes.Has(player, "Noble") then
			local nobleCommand = Commands[name]
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
