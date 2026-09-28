-- Crafting.server.lua: the blacksmith who turns a pile of ore and slime into something worth carrying.
--
-- Found by TAG, the same way the shopkeeper is: anything tagged WOLD_Npc with NpcKind="smith" gets a prompt.
-- The user places the NPC model; this file never knows where it is.
--
-- Every recipe lives on the server. The client is sent the list so it can draw it, but a craft request names
-- an INDEX into that list and carries nothing else -- no item id, no material, no quantity. There is nothing
-- in the request for a modified client to lie about.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ServerConfig = require(game.ServerScriptService.ServerConfig)

if ServerConfig.IsLobby then return end

local CraftConfig = require(game.ReplicatedStorage.CraftConfig)
local ItemCatalog = require(game.ReplicatedStorage.ItemCatalog)
local Inventory = require(game.ServerScriptService.Inventory)
local Vitals = require(game.ServerScriptService.Vitals)
local CraftAccess = require(game.ServerScriptService.CraftAccess)
local EventState = require(game.ServerScriptService.EventState)
local Remotes = require(game.ReplicatedStorage.Remotes)
local EnhanceConfig = require(game.ReplicatedStorage.EnhanceConfig)
local Mail = require(game.ServerScriptService.Mail)
local ProfileAccess = require(game.ServerScriptService.ProfileAccess)
local PlayerJoin = require(game.ServerScriptService.PlayerJoin)
local Achievements = require(game.ServerScriptService.Achievements)
local Announce = require(game.ServerScriptService.Announce)
local IslandAccess = require(game.ServerScriptService.Island.IslandAccess)

-- เลเวลฟาร์มที่ล็อกสูตรของเครื่องบนเกาะ (เฟส 2c) · nil = ไม่ล็อก (นอกเกาะไม่มีสูตรที่มี level อยู่แล้ว)
local function farmLevel()
	return ServerConfig.IsFarm and IslandAccess.FarmLevel() or nil
end

-- สูตรนี้ทำทีละหลายรอบได้ไหม (เฟส 2c) — เฉพาะสูตรที่ติด batch และสำเร็จแน่นอน (ล้มเหลวทีเดียวเสียทั้ง 10 รอบไม่ยุติธรรม)
local function batchOf(recipe)
	return recipe.batch == true and (recipe.chance or 1) >= 1 and CraftConfig.MaxBatch or 1
end

local TAG = "WOLD_Npc"
local RANGE = 12

-- A recipe naming an item that does not exist would draw a blank row and craft nothing, which looks like a
-- bug in the crafting system rather than a typo in the config. Said once at startup instead.
for index, recipe in ipairs(CraftConfig.Recipes) do
	if not ItemCatalog.Exists(recipe.id) then
		warn(("[WOLD] CraftConfig recipe %d makes unknown item %q"):format(index, tostring(recipe.id)))
	end
	for material in pairs(recipe.cost) do
		if not ItemCatalog.Exists(material) then
			warn(("[WOLD] CraftConfig recipe %d needs unknown material %q"):format(index, tostring(material)))
		end
	end
end

--------------------------------------------------------------------------------
-- Counting what the player has
--------------------------------------------------------------------------------

-- Summed across every slot, not read from one. Ten stone picked up over an afternoon can sit in three
-- part-filled slots and one nearly full one; a recipe asking for twenty would be refused by anything that
-- looked at a single slot, even though the bag plainly holds them.
local function countMaterial(state, id)
	local total = 0
	for _, slot in pairs(state.slots) do
		-- ของขอบทอง (เฟส 2b) ไม่ใช่วัตถุดิบ ทั้งคราฟและตีบวก
		if slot.id == id and not ItemCatalog.IsGoldBorder(slot.meta) then total += slot.count or 1 end
	end
	return total
end

-- Takes `count` of `id` out of the bag, walking slots until the bill is paid. Assumes the caller has already
-- checked that the bag holds enough -- it is called only after the full cost has been verified, so a partial
-- take here would mean the check and the taking disagreed.
--
-- The slot list is collected before anything is removed rather than iterated while removing, for the reason
-- the shop's "sell all" gives: RemoveFromSlot empties slots, and walking a table while emptying it is reading
-- the thing you are changing.
local function takeMaterial(player, state, id, count)
	local found = {}
	for index, slot in pairs(state.slots) do
		if slot.id == id and not ItemCatalog.IsGoldBorder(slot.meta) then
			table.insert(found, { index = index, count = slot.count or 1 })
		end
	end
	for _, entry in ipairs(found) do
		if count <= 0 then break end
		local take = math.min(entry.count, count)
		Inventory.RemoveFromSlot(player, entry.index, take)
		count -= take
	end
end

-- หน้าคราฟที่เปิดอยู่ตอนนี้มาจากไหน: ช่างตีเหล็ก (nil) หรือสถานี { station, model }
--
-- เตา/เครื่องปั่น/เครื่องต้มยา (CraftStations.server) เปิดหน้าเดียวกันแต่โชว์เฉพาะสูตรของมัน และตรวจระยะกับ
-- ตัวเครื่องแทน NPC
--
-- **ประกาศไว้ตรงนี้ ไม่ใช่ใต้ nearSmith** เพราะ PlayerRemoving ข้างล่างเขียนถึงมัน ถ้า local มาทีหลัง
-- ตัวที่ closure จับไว้จะเป็นตัวแปร global ที่เป็น nil แล้วคนออกจากเกมทีก็ error ที
local Source = {} -- [player] = { station = "stove", model = Model } | nil

-- ใครกำลังทำอะไรค้างอยู่ **แยกตามเครื่อง** ไม่ใช่คนละหนึ่งอย่าง
--
-- สเต็กใช้เวลา 15 นาทีและผู้ใช้สั่งว่าระหว่างนั้นต้องเดินไปทำอย่างอื่นได้ ถ้าล็อกไว้คนละหนึ่งงาน เตาที่ตุ๋น
-- อยู่จะล็อกทั้งเครื่องปั่นและเครื่องต้มยาไปด้วยตลอดสิบห้านาที — ล็อกรายเครื่องจึงเป็นความหมายที่ถูก:
-- เตาหนึ่งใบทำทีละอย่าง แต่คนหนึ่งคนมีหลายเครื่องได้
--
-- [player] = { [stationKey] = { index = ลำดับสูตร, finishAt = os.clock() ตอนเสร็จ } }
local Busy = {}

-- อาวุธที่ยื่นให้ช่างตีบวกอยู่ตอนนี้ (ตีบวก 2026-09-24) — [player] = { id, durability, meta, fromEquipped, level }
-- อาวุธออกจากกระเป๋า/มือไปอยู่ตรงนี้ระหว่างแถบเดิน ไม่งั้นผู้เล่นย้าย/ทิ้ง/เทรดได้ระหว่างรอ แล้วตอนจบ
-- ไม่รู้ว่าต้องบวกชิ้นไหน · ต้องประกาศก่อน snapshot (snapshot วาดแถวของชิ้นนี้ให้เห็นว่าอยู่กับช่าง)
local Enhancing = {}

-- ชื่อช่องของล็อก **รายเครื่อง ไม่ใช่รายชนิด** (QA 2026-09-26): เตาสองใบคือสองงานขนานได้ · ช่างตีเหล็ก = "smith"
-- เครื่องบนเกาะรู้จักกันด้วย `Uid` ของชิ้นที่วาง (ไต่ขึ้นหาเพราะเครื่องถูกห่อด้วย Model ลูกชื่อต้นแบบ) ·
-- ในแมพหลักใช้เส้นทางเต็มของโมเดล · ต้องเป็นสตริงเพราะจดลงงานในโปรไฟล์ด้วย (ล็อกคืนตอนเข้าเกมใหม่)
local function lockKeyOf(player)
	local src = Source[player]
	if not (src and src.station) then return "smith" end
	local model, uid = src.model, nil
	local at = model
	while at and at ~= workspace and not uid do
		uid = at:GetAttribute("Uid")
		at = at.Parent
	end
	return src.station .. "@" .. tostring(uid or (model and model:GetFullName()) or "?")
end

Players.PlayerRemoving:Connect(function(player)
	Busy[player] = nil
	Source[player] = nil
end)

--------------------------------------------------------------------------------
-- Who is close enough
--------------------------------------------------------------------------------

local function nearSmith(player)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not root then return false end
	for _, npc in ipairs(CollectionService:GetTagged(TAG)) do
		if npc:GetAttribute("NpcKind") == "smith" then
			local position = npc:IsA("BasePart") and npc.Position or npc:GetPivot().Position
			if (position - root.Position).Magnitude <= RANGE then return true end
		end
	end
	return false
end

local function nearSource(player)
	local src = Source[player]
	if not src then return nearSmith(player) end
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not root or not src.model.Parent then return false end
	return (src.model:GetPivot().Position - root.Position).Magnitude <= RANGE + 4
end

local function stationOf(player)
	local src = Source[player]
	return src and src.station or nil
end

--------------------------------------------------------------------------------
-- ตีบวก: แถวในหน้าต่าง
--------------------------------------------------------------------------------

-- หนึ่งแถวต่ออาวุธหนึ่งชิ้น · รูปเดียวกับแถวสูตร (CraftGui ใช้ recipeRow ตัวเดียวกัน) บวก note/action/ข้อความผล
-- `key` = "equipped" | เลขช่องกระเป๋าเป็นสตริง | "job" (อยู่กับช่าง)
local function enhanceRow(state, key, entry)
	local item = ItemCatalog.Get(entry.id)
	local level = EnhanceConfig.LevelOf(entry.meta)
	local nextLevel = EnhanceConfig.Levels[level + 1]
	local name = ItemCatalog.DisplayName(entry.id, entry.meta)
	local row = {
		index = "enh:" .. key, tab = "enhance", id = entry.id, icon = item and item.icon,
		materials = {}, affordable = false, chance = 1, gold = 0, goldHave = 0, yields = 1,
		enhance = { slot = key },
	}
	if key == "job" then
		row.name = name .. "  —  อยู่ที่ช่าง"
		row.note = "ช่างกำลังตีอยู่ รอรู้ผล"
		row.action = "รอ"
		return row
	end
	if not nextLevel then
		row.name = name .. "  (สูงสุดแล้ว)"
		row.note = "ตีบวกครบ +10 แล้ว"
		row.action = "สูงสุด"
		return row
	end
	local affordable = true
	for material, need in pairs(nextLevel.cost) do
		local m = ItemCatalog.Get(material)
		local have = countMaterial(state, material)
		if have < need then affordable = false end
		table.insert(row.materials, { id = material, name = m and m.name or material, icon = m and m.icon,
			have = have, need = need })
	end
	table.sort(row.materials, function(a, b) return a.id < b.id end)
	row.affordable = affordable
	row.chance = nextLevel.chance
	row.name = ("%s%s  →  +%d"):format(name, key == "equipped" and " (ถืออยู่)" or "", level + 1)
	row.note = ("โอกาส %d%%  ·  ดาเมจ +%d%% → +%d%%  ·  แตก = ความคงทน -10%%"):format(
		math.floor(nextLevel.chance * 100 + 0.5),
		math.floor(EnhanceConfig.Bonus(level) * 100 + 0.5), math.floor(nextLevel.bonus * 100 + 0.5))
	row.action = "ตี"
	row.winText = "สำเร็จ! ขั้นเพิ่มแล้ว"
	row.failText = "ตีแตก! ความคงทนลด ขั้นเท่าเดิม"
	return row
end

-- แถวทั้งหมดของแท็บตีบวก: อาวุธที่ถือ → อาวุธในกระเป๋าตามลำดับช่อง → ชิ้นที่อยู่กับช่าง
local function enhanceRows(player, state)
	local rows = {}
	local held = state.equipped and state.equipped.weapon
	if held and EnhanceConfig.Weapons[held.id] then table.insert(rows, enhanceRow(state, "equipped", held)) end
	local indices = {}
	for index, slot in pairs(state.slots) do
		if slot and EnhanceConfig.Weapons[slot.id] then table.insert(indices, index) end
	end
	table.sort(indices)
	for _, index in ipairs(indices) do
		table.insert(rows, enhanceRow(state, tostring(index), state.slots[index]))
	end
	local job = Enhancing[player]
	if job then table.insert(rows, enhanceRow(state, "job", job)) end
	return rows
end

--------------------------------------------------------------------------------
-- Opening the forge
--------------------------------------------------------------------------------

-- Everything the client needs to draw the window: every recipe, what it makes, and how far along the player
-- already is on each material. The have-counts are computed HERE rather than worked out on the client from
-- its own copy of the bag, so the window and the server can never disagree about whether something is
-- craftable -- the greyed-out row and the refusal come from the same numbers.
local function snapshot(player)
	local state = Inventory.Get(player)
	local purse = state and state.gold or 0
	local station = stationOf(player)

	local recipes = {}
	local level = farmLevel()
	for index, recipe in ipairs(CraftConfig.Recipes) do
		local item = ItemCatalog.Get(recipe.id)
		-- สูตรของสถานีโชว์เฉพาะที่สถานีนั้น ช่างตีเหล็กโชว์เฉพาะสูตรที่ไม่มี station
		if item and (recipe.station or nil) == station then
			local materials, affordable = {}, true
			for material, need in pairs(recipe.cost) do
				local entry = ItemCatalog.Get(material)
				local have = state and countMaterial(state, material) or 0
				if have < need then affordable = false end
				table.insert(materials, {
					id = material, name = entry and entry.name or material,
					icon = entry and entry.icon, have = have, need = need,
				})
			end
			-- pairs() over the cost table comes out in whatever order Lua feels like, which would shuffle the
			-- materials on a row between one redraw and the next. Sorted by id so a row looks the same twice.
			table.sort(materials, function(a, b) return a.id < b.id end)

			-- Coin is a cost like any other material, so a row the player cannot pay the smith for is greyed
			-- the same way one they lack iron for is. Without this the button would invite a craft the server
			-- had already decided to refuse.
			local fee = recipe.gold or 0
			if purse < fee then affordable = false end
			-- เฟส 2c: สูตรเครื่องบนเกาะที่ยังไม่ปลด = 🔒 กดไม่ได้ (RequestCraft ตรวจซ้ำ)
			local lockLevel = level and recipe.level and recipe.level > level and recipe.level or nil
			if lockLevel then affordable = false end
			-- ของที่ยังไม่เปิด (ผู้ใช้สั่ง 2026-09-28 · CraftConfig.Closed) = โชว์แต่ 🔒 กดไม่ได้ (RequestCraft ปฏิเสธซ้ำ)
			local closed = CraftConfig.IsClosed(recipe)
			if closed then affordable = false end
			-- ทำได้กี่รอบจากของที่มี (ไคลเอนต์ใช้หนีบปุ่ม −/+) · อย่างน้อย 1 ให้แถวยังกดได้เมื่อพอหนึ่งรอบ
			local maxTimes = batchOf(recipe)
			if maxTimes > 1 then
				for _, m in ipairs(materials) do maxTimes = math.min(maxTimes, math.floor(m.have / m.need)) end
				maxTimes = math.max(1, maxTimes)
			end

			-- The odds and the fee ride down with the row for the same reason the have-counts do: the player is
			-- being asked to gamble materials and coin, and the numbers they read before pressing have to be
			-- the ones the server will actually charge and roll. The client never opens CraftConfig itself.
			table.insert(recipes, {
				index = index, tab = recipe.tab, id = recipe.id, name = item.name,
				icon = item.icon, materials = materials, affordable = affordable,
				chance = recipe.chance or 1, gold = fee, goldHave = purse,
				-- So the row can say "x8" before the player commits, rather than the batch being a surprise
				-- that only shows up in the bag afterwards.
				yields = recipe.yields or 1,
				-- เฟส 2c: เวลาต่อรอบ · ทำได้สูงสุดกี่รอบ (nil = ทีละรอบ) · ล็อกเลเวลฟาร์ม
				seconds = recipe.seconds or CraftConfig.CraftSeconds,
				batch = batchOf(recipe) > 1 and maxTimes or nil,
				lockLevel = lockLevel,
				closed = closed or nil,
			})
		end
	end

	-- ตีบวกมีเฉพาะที่ช่างตีเหล็ก (ไม่ใช่เตา/เครื่องปั่น/เครื่องต้มยา)
	if station == nil and state then
		for _, row in ipairs(enhanceRows(player, state)) do table.insert(recipes, row) end
	end

	local tabs = {}
	for _, tab in ipairs(CraftConfig.Tabs) do
		if (tab.station or nil) == station then tabs[#tabs + 1] = tab end
	end
	-- งานที่ยังทำค้างอยู่ที่เครื่องนี้ (ถ้ามี) กลับมายืนที่เตาแล้วต้องเห็นแถบเดินต่อจากเดิม ไม่ใช่หน้าว่าง
	-- ที่ชวนให้กดซ้ำ — สูตร 15 นาทีทำให้เรื่องนี้จำเป็น ไม่ใช่ของแถม
	local busy = Busy[player] and Busy[player][lockKeyOf(player)] or nil
	local remaining = busy and math.max(0, busy.finishAt - os.clock()) or nil

	local src = Source[player]
	return { tabs = tabs, recipes = recipes, station = station,
		title = CraftConfig.StationTitles[station or ""], farmLevel = level,
		busy = busy and { index = busy.index, remaining = remaining, seconds = busy.seconds } or nil,
		stationPosition = src and src.model.Parent and src.model:GetPivot().Position or nil }
end

-- Same rule as the shop: no smithing from the floor.
local function canCraft(player)
	if Vitals.IsDowned(player) then return false end
	-- The forge is cold during a blackout, like every other counter in town. เตาในครัวไม่ใช่ NPC ไม่ดับ
	if Source[player] then return true end
	return EventState.NpcAvailable()
end

Remotes.RequestCraftOpen.OnServerEvent:Connect(function(player)
	Source[player] = nil
	if not canCraft(player) then return end
	if not nearSmith(player) then return end
	Remotes.CraftOpen:FireClient(player, snapshot(player))
end)

-- เปิดจากสถานี (CraftStations.server เรียกหลังตรวจสิทธิ์แล้ว)
CraftAccess.OpenAt = function(player, station, model)
	if Vitals.IsDowned(player) then
		-- ตัวดักชั่วคราว (2026-09-18) ลบเมื่อจบเรื่อง
		print("[Kitchen] ไม่เปิด: " .. player.Name .. " ล้มอยู่")
		return
	end
	Source[player] = { station = station, model = model }
	local snap = snapshot(player)
	print(("[Kitchen] ส่งหน้าคราฟให้ %s — station=%s สูตร=%d แท็บ=%d"):format(
		player.Name, tostring(station), #snap.recipes, #snap.tabs))
	Remotes.CraftOpen:FireClient(player, snap)
end

Remotes.RequestCraftClose.OnServerEvent:Connect(function(player)
	Source[player] = nil
end)

--------------------------------------------------------------------------------
-- Crafting
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- งานคราฟที่ค้างอยู่เซฟในโปรไฟล์ (QA 2026-09-26)
--------------------------------------------------------------------------------
-- กติกาผู้ใช้: "เดินออกจากเครื่อง/ออกเกม อาหารยังทำต่อจนเสร็จแล้วเด้งเข้ากระเป๋า" — ของเดิมงานอยู่ใน task.delay อย่างเดียว
-- ออกเกม = วัตถุดิบถูกหักไปแล้วแต่ไม่มีใครส่งของ (สเต็ก 15 นาทีหายทั้งจาน) · เกาะปิดตามเจ้าของ = เตาบนเกาะเสียทุกงาน
-- ตอนนี้งานอยู่ใน `profile.Data.CraftJobs`: จบในเซิร์ฟนี้ → ส่งตามปกติ · ออกไปก่อน → ส่งตอนเข้าเกมครั้งหน้า (ทุกเพลส
-- ที่มีระบบคราฟ) · **การเอางานออกจากรายการคือสิทธิ์ส่งของ** ใครเอาออกได้คนนั้นส่ง กันส่งซ้ำสองทาง
local function takeJob(data, job)
	local list = data and data.CraftJobs
	if type(list) ~= "table" then return false end
	for i, j in ipairs(list) do
		if j == job then
			table.remove(list, i)
			return true
		end
	end
	return false
end

-- ทอยผล (ตอนงานจบ ไม่ใช่ตอนเริ่ม) แล้วส่งของ · กระเป๋าเต็ม → กล่องจดหมายของตัวเอง (โปรไฟล์เดียวกัน ส่งไม่ล้ม)
-- คืน true = สำเร็จ · ข้อความแจ้งอยู่ในนี้ที่เดียว ทั้งทางปกติและทางส่งตอนเข้าเกมใหม่
local function resolveJob(player, data, job)
	local item = ItemCatalog.Get(job.id)
	local name = item and item.name or job.id
	if math.random() >= (job.chance or 1) then
		-- A failure is not nothing: a consolation (the recipe's own `failGives`, else an Insignia coin for a
		-- recipe that could fail) — quietly skipped when the bag is full, as before.
		local awarded, awardedItem = 0, CraftConfig.InsigniaItem
		if type(job.failGives) == "table" and #job.failGives > 0 then
			local pick = job.failGives[math.random(#job.failGives)]
			if Inventory.AddItem(player, pick, 1) then awarded, awardedItem = 1, pick end
		elseif (job.chance or 1) < 1 then
			local coins = CraftConfig.InsigniaPerFailure or 1
			if Inventory.AddItem(player, CraftConfig.InsigniaItem, coins) then awarded = coins end
		end
		local fee = job.fee or 0
		local reason = fee > 0 and ("สร้าง %s ล้มเหลว เสียวัสดุและเงิน %d"):format(name, fee)
			or ("สร้าง %s ล้มเหลว วัสดุเสียไป"):format(name)
		if awarded > 0 then
			local coin = ItemCatalog.Get(awardedItem)
			reason ..= ("  ·  ได้ %s x%d"):format(coin and coin.name or awardedItem, awarded)
		end
		Remotes.SocialNotify:FireClient(player, "error", reason)
		return false
	end

	local yields = job.yields or 1
	if Inventory.HasRoomFor(player, job.id, yields) and Inventory.AddItem(player, job.id, yields) then
		Remotes.SocialNotify:FireClient(player, "info", yields > 1
			and ("สร้าง %s x%d สำเร็จ"):format(name, yields) or ("สร้าง %s สำเร็จ"):format(name))
	elseif not data then
		Remotes.SocialNotify:FireClient(player, "error", "กระเป๋าเต็ม ของที่สร้างหล่นหาย")
		return false
	else
		-- เดิม "กระเป๋าเต็ม ของที่สร้างหล่นหาย" · ตอนนี้ฝากกล่องจดหมาย
		Mail.PutOwn(player, data, {
			fromName = "โรงงาน", subject = "ของที่สร้างเสร็จ",
			body = ("%s — กระเป๋าเต็ม เลยฝากไว้ในกล่องจดหมาย"):format(name),
			items = { { id = job.id, count = yields } },
		})
		Remotes.SocialNotify:FireClient(player, "info", ("สร้าง %s สำเร็จ — กระเป๋าเต็ม อยู่ในกล่องจดหมายแล้ว"):format(name))
	end
	return true
end


Remotes.RequestCraft.OnServerEvent:Connect(function(player, index, times)
	if type(index) ~= "number" then return end
	if not canCraft(player) then return end
	-- Re-checked on every craft, not just on opening: a player could walk away with the window still up.
	if not nearSource(player) then
		return Remotes.SocialNotify:FireClient(player, "error", "อยู่ไกลเกินไป")
	end

	local recipe = CraftConfig.Recipes[index]
	if not recipe then return end
	-- สูตรต้องเป็นของที่ที่ยืนอยู่: ไคลเอนต์ส่ง index ได้ทุกค่า
	if (recipe.station or nil) ~= stationOf(player) then return end
	local item = ItemCatalog.Get(recipe.id)
	if not item then return end

	local state = Inventory.Get(player)
	if not state then return end

	-- ของที่ยังไม่เปิดให้คราฟ (ผู้ใช้สั่ง 2026-09-28) — ไคลเอนต์ส่ง index ของแถวที่ล็อกมาได้ ต้องปฏิเสธที่นี่
	if CraftConfig.IsClosed(recipe) then
		return Remotes.SocialNotify:FireClient(player, "warn", "🔒 " .. CraftConfig.ClosedText)
	end

	-- เฟส 2c: สูตรเครื่องบนเกาะล็อกตามเลเวลฟาร์ม
	local level = farmLevel()
	if level and recipe.level and recipe.level > level then
		return Remotes.SocialNotify:FireClient(player, "error",
			("🔒 สูตรนี้ปลดที่เลเวลฟาร์ม %d (ตอนนี้ Lv%d)"):format(recipe.level, level))
	end

	-- **ทำหลายรอบในงานเดียว** (เฟส 2c ผู้ใช้เลือก 2026-09-27) — วัตถุดิบ เวลา และของที่ได้คูณตามรอบ
	-- สูตรที่ไม่ติด batch = 1 เสมอ ไม่ว่าไคลเอนต์ส่งอะไรมา
	local rounds = 1
	if batchOf(recipe) > 1 and type(times) == "number" and times == times then
		rounds = math.clamp(math.floor(times), 1, batchOf(recipe))
	end

	-- Every material checked before ANY is taken. Taking as we go and stopping halfway would eat the
	-- materials for a craft that never happened.
	for material, per in pairs(recipe.cost) do
		local need = per * rounds
		if countMaterial(state, material) < need then
			local entry = ItemCatalog.Get(material)
			return Remotes.SocialNotify:FireClient(player, "error",
				("วัสดุไม่พอ: %s"):format(entry and entry.name or material))
		end
	end

	-- The smith's fee, checked in the same breath as the materials so a player short of coin is told before
	-- anything is spent rather than after.
	local fee = (recipe.gold or 0) * rounds
	if fee > 0 and (state.gold or 0) < fee then
		return Remotes.SocialNotify:FireClient(player, "error",
			("เงินไม่พอ ต้องมี %d"):format(fee))
	end

	-- Room for the result has to be checked BEFORE the hammer starts, not after.
	--
	-- The materials are consumed whether the attempt works or not, so there is no ordering trick available
	-- any more: the product cannot be handed over first, because most of the time there is no product. What
	-- protects the player instead is asking the bag up front whether the result would fit, and refusing the
	-- whole attempt if it would not -- otherwise a successful craft could burn the materials and then find
	-- nowhere to put the sword.
	-- How many this recipe makes. Read from the recipe rather than assumed to be one, and checked for room
	-- at its full size: a batch of eight bullets needs somewhere to put eight.
	local yields = (recipe.yields or 1) * rounds

	if not Inventory.HasRoomFor(player, recipe.id, yields) then
		return Remotes.SocialNotify:FireClient(player, "error", "กระเป๋าเต็ม")
	end

	-- One craft at a time PER BENCH. The hammer takes a couple of seconds and the player is free to press the
	-- button again during it, which without this would spend the materials twice over from one set. แยกตาม
	-- เครื่องเพราะเตาที่ตุ๋นสเต็กอยู่ 15 นาทีต้องไม่ล็อกเครื่องต้มยาไปด้วย
	local station = stationOf(player)
	local key = lockKeyOf(player)
	Busy[player] = Busy[player] or {}
	if Busy[player][key] then
		return Remotes.SocialNotify:FireClient(player, "error",
			station and "เครื่องนี้ยังทำงานอยู่ รอสักครู่" or "กำลังตีอยู่ รอสักครู่")
	end

	-- สูตรกำหนดเวลาเองได้ (สเต็ก 15 นาที น้ำแอปเปิล 5 นาที) ที่เหลือใช้ค่ากลางของช่างตีเหล็ก
	local seconds = (recipe.seconds or CraftConfig.CraftSeconds) * rounds
	Busy[player][key] = { index = index, finishAt = os.clock() + seconds, seconds = seconds }

	-- Taken NOW rather than after the wait, so walking away or logging out mid-swing cannot dodge the cost.
	-- The fee goes with them: the smith is paid for the attempt, not for the result.
	for material, per in pairs(recipe.cost) do
		takeMaterial(player, state, material, per * rounds)
	end
	if fee > 0 then
		Inventory.AddGold(player, -fee)
	end

	-- งานเข้าโปรไฟล์ทันทีพร้อมกับที่วัตถุดิบออกจากกระเป๋า — ไม่มีช่วงที่ของไม่อยู่ที่ไหนเลย (ดู resolveJob)
	local data = ProfileAccess.Get(player)
	-- `lock` = เครื่องที่งานนี้จองไว้ · เข้าเกมใหม่ระหว่างทำ ล็อกเครื่องนี้คืนจนงานเสร็จ (QA 2026-09-26)
	local job = { id = recipe.id, yields = yields, chance = recipe.chance or 1, failGives = recipe.failGives,
		fee = fee, readyAt = os.time() + seconds, lock = key }
	if data then
		data.CraftJobs = data.CraftJobs or {}
		table.insert(data.CraftJobs, job)
		if ProfileAccess.Flush then ProfileAccess.Flush(player) end
	end

	-- Tell the client to run its progress bar, and redraw the window so the materials visibly leave the bag
	-- as the hammer starts.
	Remotes.CraftStarted:FireClient(player, index, seconds)
	Remotes.CraftOpen:FireClient(player, snapshot(player))

	-- ท่าทำงาน: บอก **ทุกไคลเอนต์** ไม่ใช่เฉพาะคนทำ คนที่เดินผ่านครัวต้องเห็นเชฟคนหม้ออยู่ ท่าจะหยุดเอง
	-- เมื่อคนทำเดินออกจากเครื่อง (ไคลเอนต์เทียบระยะกับพิกัดที่ส่งไปนี้) แล้วเล่นต่อเมื่อเดินกลับมา
	local src = Source[player]
	local stationPosition = src and src.model.Parent and src.model:GetPivot().Position or nil
	if station then
		Remotes.CraftPoseChanged:FireAllClients(player, station, seconds, stationPosition)
		if src and CraftAccess.OnCraftStarted then
			CraftAccess.OnCraftStarted(player, station, src.model, seconds)
		end
	end

	task.delay(seconds, function()
		if Busy[player] then Busy[player][key] = nil end
		if station then Remotes.CraftPoseChanged:FireAllClients(player, nil) end
		-- ออกเกมไปแล้ว = งานอยู่ในโปรไฟล์ที่เซฟไปแล้ว ส่งตอนเข้าเกมครั้งหน้า · ส่งไปแล้ว (เข้าใหม่ระหว่างรอ) = ไม่ส่งซ้ำ
		if not player.Parent then return end
		-- ไม่มีโปรไฟล์ตอนเริ่ม (ไม่ควรเกิด) = งานไม่ได้เข้าโปรไฟล์ ส่งตรงนี้เลยไม่ต้องทวงสิทธิ์
		if data and (ProfileAccess.Get(player) ~= data or not takeJob(data, job)) then return end

		local ok = resolveJob(player, data, job)
		Remotes.CraftFinished:FireClient(player, index, ok)
		if ok then
			local src = Source[player]
			if src and CraftAccess.OnCrafted then CraftAccess.OnCrafted(player, src.station, src.model, recipe) end
		end
		if ProfileAccess.Flush then ProfileAccess.Flush(player) end
		-- The window redraws from a fresh snapshot rather than patching itself, so the have-counts on every
		-- other recipe sharing a material move at the same moment this one's do.
		Remotes.CraftOpen:FireClient(player, snapshot(player))
	end)
end)

--------------------------------------------------------------------------------
-- ตีบวก (ผู้ใช้สั่ง 2026-09-24 · สเปก docs/superpowers/specs/2026-09-24-enhance-design.md)
--------------------------------------------------------------------------------
--
-- ⚠️ **อาวุธที่อยู่กับช่างเก็บใน `profile.Data.EnhanceJob`** (รีวิว 2026-09-25) ไม่ใช่แค่ในหน่วยความจำ
-- เดิมถ้าออกเกม/เซิร์ฟปิดกลางแถบ 4 วิ กระเป๋าถูกเซฟโดยไม่มีอาวุธ แล้วเมลคืนล้มเพราะ ProfileStore กำลังปิด
-- = อาวุธหายถาวร · ตอนนี้งานถูกเซฟพร้อมกระเป๋าเสมอ: จบในเซิร์ฟนี้ → คืน · ออกไปก่อน → คืนตอนเข้าเกมครั้งหน้า
-- ผลถูกทอยตอนยื่น (ต้องเซฟไปพร้อมงานได้) แต่ไคลเอนต์เห็นตอนแถบเต็มเท่านั้น

-- คืนอาวุธจากช่าง **ไม่มีทางหาย** แล้วล้างงานออกจากโปรไฟล์ · ลำดับ: มาจากมือและมือว่าง → สวมกลับ (ไม่กิน
-- ช่องกระเป๋า) · กระเป๋ามีที่ → ใส่ · ไม่มีที่ → จดหมายลงกล่องตัวเอง (โปรไฟล์เดียวกัน ส่งไม่ล้ม)
-- ⚠️ ห้ามให้ AddItem ล้นเอง — ถาม HasRoomFor ก่อนเสมอ
-- คืน key ของแถวที่อาวุธไปอยู่ ("equipped" / เลขช่อง) หรือ nil ถ้าเข้ากล่องจดหมาย
local function returnWeapon(player, data, job)
	local state = Inventory.Get(player)
	local where = nil
	if state and job.fromEquipped and not state.equipped.weapon
		and Inventory.EquipDirect(player, "weapon", job) then
		where = "equipped"
	elseif state and Inventory.HasRoomFor(player, job.id, 1, job.meta)
		and Inventory.AddItem(player, job.id, 1, job.durability, job.meta) then
		where = "job"
		for index, slot in pairs(state.slots) do
			if slot and slot.meta == job.meta then where = tostring(index) break end
		end
	else
		local name = ItemCatalog.DisplayName(job.id, job.meta)
		Mail.PutOwn(player, data, {
			fromName = "ช่างตีเหล็ก",
			subject = "คืนอาวุธที่ตีบวก",
			body = ("%s — กระเป๋าเต็ม ช่างเลยฝากไว้ในกล่องจดหมาย"):format(name),
			items = { { id = job.id, count = 1, durability = job.durability, meta = job.meta } },
		})
		Remotes.SocialNotify:FireClient(player, "info", ("กระเป๋าเต็ม — %s อยู่ในกล่องจดหมายแล้ว"):format(name))
	end
	data.EnhanceJob = nil
	-- ความสำเร็จ "ช่างฝีมือ/เทพแห่งเตาหลอม" นับตอนอาวุธกลับมาถึงมือ (ไม่ใช่ตอนทอย — ไม่งั้นแจ้งปลดก่อนแถบเต็ม)
	if job.success then Achievements.Record(player, "maxEnhance", EnhanceConfig.LevelOf(job.meta), "max") end
	if ProfileAccess.Flush then ProfileAccess.Flush(player) end
	return where
end

local function announce(player, job)
	local name = ItemCatalog.DisplayName(job.id, job.meta)
	-- ตีบวก +8 ขึ้นไปสำเร็จ = ทุกเซิร์ฟเห็น (ผู้ใช้เลือก)
	if job.success and EnhanceConfig.LevelOf(job.meta) >= EnhanceConfig.AnnounceFrom then
		Announce.Global(("⚒️ %s ตีบวก %s สำเร็จ!"):format(player.DisplayName, name), "enhance")
	end
	Remotes.SocialNotify:FireClient(player, job.success and "info" or "error", job.success
		and ("ตีบวกสำเร็จ! %s"):format(name)
		or ("ตีแตก! %s ขั้นเท่าเดิม ความคงทนลด"):format(name))
end

Remotes.RequestEnhance.OnServerEvent:Connect(function(player, key)
	if type(key) ~= "string" then return end
	if not canCraft(player) then return end
	if Source[player] then return end -- ตีบวกที่ช่างตีเหล็กเท่านั้น ไม่ใช่ที่เตา
	if not nearSmith(player) then
		return Remotes.SocialNotify:FireClient(player, "error", "อยู่ไกลเกินไป")
	end
	local state = Inventory.Get(player)
	local data = ProfileAccess.Get(player)
	if not state or not data then return end
	if data.EnhanceJob then
		return Remotes.SocialNotify:FireClient(player, "error", "ช่างยังถืออาวุธชิ้นก่อนอยู่ รอสักครู่")
	end

	-- ช่องที่ไคลเอนต์ขอ: "equipped" หรือเลขช่องจำนวนเต็มที่มีของอยู่จริง (ค่าอื่น = nil = จบเงียบ)
	local entry, bagIndex
	if key == "equipped" then
		entry = state.equipped.weapon
	else
		bagIndex = tonumber(key)
		if not bagIndex or bagIndex ~= math.floor(bagIndex) then return end
		entry = state.slots[bagIndex]
	end
	if not entry or not EnhanceConfig.Weapons[entry.id] then return end

	local level = EnhanceConfig.LevelOf(entry.meta)
	local nextLevel = EnhanceConfig.Levels[level + 1]
	if not nextLevel then
		return Remotes.SocialNotify:FireClient(player, "error", "ตีบวกครบ +10 แล้ว")
	end

	-- ล็อกตัวเดียวกับการคราฟที่ช่างตีเหล็ก: ตีบวกอยู่ = คราฟไม่ได้ และกลับกัน
	Busy[player] = Busy[player] or {}
	if Busy[player].smith then
		return Remotes.SocialNotify:FireClient(player, "error", "กำลังตีอยู่ รอสักครู่")
	end

	for material, need in pairs(nextLevel.cost) do
		if countMaterial(state, material) < need then
			local m = ItemCatalog.Get(material)
			return Remotes.SocialNotify:FireClient(player, "error",
				("วัสดุไม่พอ: %s"):format(m and m.name or material))
		end
	end

	-- ล็อกก่อนจ่าย (ทรงเดียวกับ RequestCraft) · ไม่มีการ yield จากตรงนี้ถึงการยื่นอาวุธ
	local seconds = EnhanceConfig.Seconds
	Busy[player].smith = { index = "enh:job", finishAt = os.clock() + seconds, seconds = seconds }

	for material, need in pairs(nextLevel.cost) do
		takeMaterial(player, state, material, need)
	end

	-- ทอยตอนยื่น (ต้องเซฟผลไปกับงาน) · ผลแปะลงตัวอาวุธในงานเลย
	local job = {
		id = entry.id, durability = entry.durability,
		-- meta เป็นตารางเสมอ: returnWeapon หาช่องที่อาวุธลงด้วยการเทียบตารางนี้
		meta = type(entry.meta) == "table" and entry.meta or {},
		fromEquipped = key == "equipped", level = level,
		success = math.random() < nextLevel.chance,
	}
	if job.success then
		job.meta.enhance = level + 1
	else
		local item = ItemCatalog.Get(job.id)
		local max = item and item.maxDurability
		if max then
			job.durability = math.max(1, (job.durability or max) - math.ceil(max * EnhanceConfig.FailDurabilityFraction))
		end
	end

	-- ยื่นอาวุธ: ออกจากมือ/ช่อง แล้วเข้าโปรไฟล์ในจังหวะเดียวกัน (ไม่มีช่วงที่อาวุธไม่อยู่ที่ไหนเลย)
	if job.fromEquipped then
		Inventory.BreakEquipped(player, "weapon") -- โมเดลออกจากมือ (อยู่กับช่าง)
	else
		state.slots[bagIndex] = nil
	end
	data.EnhanceJob = job
	Enhancing[player] = job
	Inventory.Send(player)
	if ProfileAccess.Flush then ProfileAccess.Flush(player) end

	Remotes.CraftStarted:FireClient(player, "enh:job", seconds)
	Remotes.CraftOpen:FireClient(player, snapshot(player))

	task.delay(seconds, function()
		if Busy[player] then Busy[player].smith = nil end
		if Enhancing[player] == job then Enhancing[player] = nil end
		-- ออกเกมไปแล้ว = งานอยู่ในโปรไฟล์ที่เซฟไปแล้ว เข้าเกมครั้งหน้าได้คืน (ห้ามคืนตรงนี้ซ้ำ = อาวุธสองชิ้น)
		if not player.Parent or ProfileAccess.Get(player) ~= data or data.EnhanceJob ~= job then return end
		local where = returnWeapon(player, data, job)
		Remotes.CraftFinished:FireClient(player, where and ("enh:" .. where) or "enh:job", job.success)
		announce(player, job)
		Remotes.CraftOpen:FireClient(player, snapshot(player))
	end)
end)

-- เข้าเกมมาแล้วมีงานคราฟค้าง (ออกไประหว่างทำ) → ครบเวลาแล้วส่งเลย ยังไม่ครบรอจนครบแล้วส่ง (ที่ไหนก็ได้ ไม่ต้องยืนที่เตา)
PlayerJoin.Each(function(player)
	task.spawn(function()
		local data = ProfileAccess.Wait(player)
		if not data or type(data.CraftJobs) ~= "table" or #data.CraftJobs == 0 then return end
		while player.Parent and not Inventory.Get(player) do task.wait(0.2) end
		for _, job in ipairs(table.clone(data.CraftJobs)) do
			if type(job) ~= "table" or type(job.id) ~= "string" or not ItemCatalog.Exists(job.id) then
				takeJob(data, job)
			else
				-- ล็อกเครื่องเดิมคืนจนงานเสร็จ (QA 2026-09-26): เดิมล็อกหายตอนออกเกม เข้ามาใหม่เริ่มงานซ้อนที่เครื่องเดิมได้
				-- งานเก่าก่อนมีช่อง `lock` ไม่มีเครื่องให้ล็อก — ส่งของตามเดิมเฉยๆ
				local left = math.max(0, (tonumber(job.readyAt) or 0) - os.time())
				if type(job.lock) == "string" then
					Busy[player] = Busy[player] or {}
					Busy[player][job.lock] = { finishAt = os.clock() + left, seconds = left }
				end
				task.delay(left, function()
					if Busy[player] and job.lock then Busy[player][job.lock] = nil end
					if not player.Parent or ProfileAccess.Get(player) ~= data or not takeJob(data, job) then return end
					resolveJob(player, data, job)
					if ProfileAccess.Flush then ProfileAccess.Flush(player) end
				end)
			end
		end
	end)
end)

-- เข้าเกมมาแล้วมีงานค้างที่ช่าง (ออกไปกลางแถบ / เซิร์ฟปิด) → คืนเลย ผลทอยไว้แล้วตั้งแต่ตอนยื่น
PlayerJoin.Each(function(player)
	task.spawn(function()
		local data = ProfileAccess.Wait(player)
		if not data or type(data.EnhanceJob) ~= "table" then return end
		-- กระเป๋าโหลดทีหลังโปรไฟล์ได้ (PlayerInventory ก็รอโปรไฟล์เหมือนกัน) — รอจนมี
		while player.Parent and not Inventory.Get(player) do task.wait(0.2) end
		if not player.Parent or type(data.EnhanceJob) ~= "table" then return end
		local job = data.EnhanceJob
		if type(job.id) ~= "string" or not ItemCatalog.Exists(job.id) then
			data.EnhanceJob = nil
			return
		end
		if type(job.meta) ~= "table" then job.meta = {} end
		returnWeapon(player, data, job)
		announce(player, job)
	end)
end)

--------------------------------------------------------------------------------
-- The prompt on the NPC
--------------------------------------------------------------------------------

local function register(npc)
	if npc:GetAttribute("NpcKind") ~= "smith" then return end
	-- HumanoidRootPart FIRST, for the reason Shop.server gives: the kit's NPC models set PrimaryPart to a
	-- 1x1 pivot handle at the model's feet, so preferring PrimaryPart puts the button on the ground by the
	-- blacksmith's boots.
	local anchor = npc:IsA("BasePart") and npc
		or (npc:IsA("Model") and (npc:FindFirstChild("HumanoidRootPart") or npc:FindFirstChild("UpperTorso")
			or npc.PrimaryPart or npc:FindFirstChildWhichIsA("BasePart", true)))
	if not anchor then return end
	if anchor:FindFirstChild("CraftPrompt") then return end

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "CraftPrompt"
	prompt.ActionText = "ตีเหล็ก"
	prompt.ObjectText = npc:GetAttribute("NpcName") or "ช่างตีเหล็ก"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.MaxActivationDistance = RANGE
	prompt.RequiresLineOfSight = false
	prompt.HoldDuration = 0
	prompt.Parent = anchor

	prompt.Triggered:Connect(function(player)
		-- Gated here as well as on the remote. Pressing E is the only way most players ever open the forge, so
		-- a check that lived only on RequestCraftOpen would let the window open during a blackout and refuse
		-- every button inside it -- which reads as a broken forge rather than a dark town.
		Source[player] = nil -- ช่างตีเหล็ก ไม่ใช่สถานี
		local ok, reason = canCraft(player)
		if not ok then
			if reason then Remotes.SocialNotify:FireClient(player, "error", reason) end
			return
		end
		Remotes.CraftOpen:FireClient(player, snapshot(player))
	end)
end

for _, npc in ipairs(CollectionService:GetTagged(TAG)) do
	task.spawn(register, npc)
end
CollectionService:GetInstanceAddedSignal(TAG):Connect(function(npc)
	task.spawn(register, npc)
end)
