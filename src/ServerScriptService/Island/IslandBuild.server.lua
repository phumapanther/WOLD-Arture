-- IslandBuild: เจ้าของ "ของที่วางบนเกาะ" — ตารางช่องที่ถูกใช้ โมเดลในโลก และ profile.Data.Island ของเจ้าของเกาะ
--
-- กติกา: ไคลเอนต์ส่งแค่ (ช่องกระเป๋า, cx, cz, r) เซิร์ฟเวอร์ตรวจทุกอย่างเองแล้วตอบเหตุผลเป็นไทยผ่าน SocialNotify
-- · ไม่มี "ย้าย" (= เก็บแล้ววางใหม่) · ข้อมูลเขียนตรงเข้า Data.Island เหมือน Vehicles — ProfileStore เซฟให้เอง
local ServerConfig = require(game.ServerScriptService.ServerConfig)
if not ServerConfig.IsFarm then return end -- ไฟล์ไปเพลสหลักด้วย แต่ไม่ทำอะไรที่นั่น (ทรงเดียวกับ IsLobby gating)

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local Inventory = require(game.ServerScriptService.Inventory)
local ProfileAccess = require(game.ServerScriptService.ProfileAccess)
local PlayerJoin = require(game.ServerScriptService.PlayerJoin)
local IslandAccess = require(script.Parent.IslandAccess)
local IslandConfig = require(ReplicatedStorage.IslandConfig)
local IslandGrid = require(ReplicatedStorage.IslandGrid)
local ItemCatalog = require(ReplicatedStorage.ItemCatalog)
local Remotes = require(ReplicatedStorage.Remotes)

local REASON_TEXT = {
	notowner = "วางได้เฉพาะเจ้าของเกาะ",
	noitem = "ไม่มีของชิ้นนั้นในกระเป๋า",
	noproto = "ยังไม่มีโมเดลของของชิ้นนี้",
	limit = ("เกาะเต็มแล้ว (%d ชิ้น)"):format(IslandConfig.MaxPlaced),
	edge = "ใกล้ขอบเกาะเกินไป",
	blocked = "ตรงนี้วางไม่ได้",
	occupied = "วางทับของอื่น",
	needsoil = "แปลงผักวางได้เฉพาะบนผืนดิน",
	onsoil = "ผืนดินไว้ปลูกผักเท่านั้น วางของอื่นไม่ได้",
	steep = "พื้นตรงนี้ชันเกินไป",
	full = "กระเป๋าเต็ม",
	growing = "เก็บเกี่ยวก่อนแล้วค่อยเก็บแปลง",
	missing = "ไม่พบของชิ้นนั้นแล้ว",
}

--------------------------------------------------------------------------------
-- สถานะ
--------------------------------------------------------------------------------

local ownerId = ServerConfig.FarmOwnerId -- nil ใน Studio → คนแรกที่เข้า
local Data = nil -- profile.Data.Island ของเจ้าของ (ตารางเดียวกับที่ ProfileStore เซฟ)
local Occupied = {} -- ["cx,cz"] = uid
local Models = {} -- [uid] = model
local Entries = {} -- [model] = entry
local LastCall = {} -- [player] = os.clock() กันสแปม

local function placedFolder()
	local island = workspace:FindFirstChild("WOLD_Island")
	if not island then island = Instance.new("Folder"); island.Name = "WOLD_Island"; island.Parent = workspace end
	local placed = island:FindFirstChild("Placed")
	if not placed then placed = Instance.new("Folder"); placed.Name = "Placed"; placed.Parent = island end
	return placed
end

local function isOwner(player)
	return ownerId ~= nil and player.UserId == ownerId
end

local function notify(player, reason)
	Remotes.SocialNotify:FireClient(player, "error", REASON_TEXT[reason] or reason)
end

-- วงห้ามวาง อ่านสดทุกครั้ง (ของน้อย ถูกกว่าการจำแล้วลืมอัปเดต)
local function noBuildZones()
	local zones = {}
	local spawnLoc = workspace:FindFirstChildWhichIsA("SpawnLocation", true)
	if spawnLoc then table.insert(zones, { x = spawnLoc.Position.X, z = spawnLoc.Position.Z, radius = IslandConfig.NoBuild.spawn }) end
	for _, npc in ipairs(CollectionService:GetTagged("WOLD_Npc")) do
		local p = npc:IsA("BasePart") and npc.Position or npc:GetPivot().Position
		table.insert(zones, { x = p.X, z = p.Z, radius = IslandConfig.NoBuild.npc })
	end
	return zones
end

-- ผิวดินจริงที่กึ่งกลาง footprint — Include เฉพาะ Terrain (บทเรียนกล่อง Zone_* ล่องหนที่เรย์ชน)
local function groundAt(wx, wz)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { workspace.Terrain }
	local hit = workspace:Raycast(Vector3.new(wx, IslandConfig.Center.Y + 80, wz), Vector3.new(0, -300, 0), params)
	return hit and hit.Position.Y or (IslandConfig.Center.Y + 17)
end

local function prototypeOf(id)
	local folder = ReplicatedStorage:FindFirstChild("WOLD_Placeables")
	return folder and folder:FindFirstChild(id)
end

local function footprintOf(proto)
	local fp = proto:GetAttribute("Footprint")
	if typeof(fp) == "Vector2" then return fp.X, fp.Y end
	return 1, 1
end

--------------------------------------------------------------------------------
-- โมเดลในโลก
--------------------------------------------------------------------------------

local function spawnEntry(entry)
	local proto = prototypeOf(entry.id)
	if not proto then
		warn(("[Island] ไม่มีต้นแบบ %s (uid %d) ข้าม"):format(tostring(entry.id), entry.uid))
		return nil
	end
	local w, d = footprintOf(proto)
	local model = proto:Clone()
	model.Name = tostring(entry.uid)
	local wx, wz = IslandGrid.centreOf(entry.x, entry.z, w, d, entry.r)
	model:PivotTo(IslandGrid.pivotFor(entry.x, entry.z, w, d, entry.r, groundAt(wx, wz)))
	model:SetAttribute("Uid", entry.uid)
	model:SetAttribute("ItemId", entry.id)
	model:SetAttribute("CellX", entry.x)
	model:SetAttribute("CellZ", entry.z)
	model:SetAttribute("Rot", entry.r)
	model:SetAttribute("Footprint", Vector2.new(w, d))

	-- ปุ่มเก็บ: F กดค้าง ครึ่งวิ กันเผลอ · E ปล่อยไว้ให้ปุ่มของแปลง (ปลูก/เก็บเกี่ยว) ในไฟล์ IslandPlots
	local item = ItemCatalog.Get(entry.id)
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "PickupPrompt"
	prompt.ActionText = "เก็บเข้ากระเป๋า"
	prompt.ObjectText = item and item.name or entry.id
	prompt.KeyboardKeyCode = Enum.KeyCode.F
	prompt.GamepadKeyCode = Enum.KeyCode.ButtonY
	prompt.HoldDuration = 0.5
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = model.PrimaryPart
	prompt.Triggered:Connect(function(player)
		local ok, reason = IslandAccess.Pickup(player, entry.uid)
		if not ok then notify(player, reason) end
	end)

	for _, key in ipairs(IslandGrid.cellsOf(entry.x, entry.z, w, d, entry.r)) do Occupied[key] = entry.uid end
	Models[entry.uid] = model
	Entries[model] = entry
	model.Parent = placedFolder()
	return model
end

local function despawnEntry(entry)
	local model = Models[entry.uid]
	if model then
		Entries[model] = nil
		model:Destroy()
	end
	Models[entry.uid] = nil
	for key, uid in pairs(Occupied) do
		if uid == entry.uid then Occupied[key] = nil end
	end
end

-- สร้างเกาะคืนจากข้อมูล — ล้างของเดิมก่อนเสมอ จึงเรียกซ้ำได้ (เจ้าของออกแล้วเข้าใหม่ = โปรไฟล์ตารางใหม่)
local function rebuild()
	for _, model in ipairs(placedFolder():GetChildren()) do model:Destroy() end
	Occupied, Models, Entries = {}, {}, {}
	if not Data then return end
	for _, entry in ipairs(Data.placed) do spawnEntry(entry) end
	print(("[Island] สร้างคืน %d ชิ้น"):format(#Data.placed))
end

--------------------------------------------------------------------------------
-- วาง / เก็บ
--------------------------------------------------------------------------------

local function rateLimited(player)
	local now = os.clock()
	if LastCall[player] and now - LastCall[player] < IslandConfig.MinCallGap then return true end
	LastCall[player] = now
	return false
end

local function place(player, slotIndex, cx, cz, r)
	if not isOwner(player) or not Data then return false, "notowner" end
	if type(slotIndex) ~= "number" or type(cx) ~= "number" or type(cz) ~= "number" then return false, "noitem" end
	cx, cz = math.floor(cx), math.floor(cz)
	r = (type(r) == "number") and (math.floor(r) % 4) or 0
	local state = Inventory.Get(player)
	local slot = state and state.slots[slotIndex]
	local item = slot and ItemCatalog.Get(slot.id)
	if not item or item.kind ~= "placeable" then return false, "noitem" end
	local proto = prototypeOf(slot.id)
	if not proto then return false, "noproto" end
	if #Data.placed >= IslandConfig.MaxPlaced then return false, "limit" end
	local w, d = footprintOf(proto)
	local ok, reason = IslandGrid.canPlace(Occupied, noBuildZones(), cx, cz, w, d, r, slot.id)
	if not ok then return false, reason end
	if not Inventory.RemoveFromSlot(player, slotIndex, 1) then return false, "noitem" end

	local entry = { uid = Data.nextUid, id = slot.id, x = cx, z = cz, r = r }
	Data.nextUid += 1
	table.insert(Data.placed, entry)
	spawnEntry(entry)
	return true
end

local function pickup(player, uid)
	if not isOwner(player) or not Data then return false, "notowner" end
	local model = Models[uid]
	local entry = model and Entries[model]
	if not entry then return false, "missing" end
	if entry.crop then return false, "growing" end
	if not Inventory.HasRoomFor(player, entry.id, 1) then return false, "full" end
	if not Inventory.AddItem(player, entry.id, 1) then return false, "full" end
	for i, e in ipairs(Data.placed) do
		if e == entry then table.remove(Data.placed, i) break end
	end
	despawnEntry(entry)
	return true
end

--------------------------------------------------------------------------------
-- เจ้าของเข้ามา → โหลด → ชุดเริ่มต้น → สร้างคืน
--------------------------------------------------------------------------------

local function load(player)
	local data = ProfileAccess.Wait(player)
	if not data then return end
	data.Island = data.Island or { placed = {}, nextUid = 1 }
	data.Island.placed = data.Island.placed or {}
	data.Island.nextUid = data.Island.nextUid or 1
	Data = data.Island

	if not Data.starter then
		-- กระเป๋าโหลดหลังโปรไฟล์อีกจังหวะหนึ่ง (PlayerInventory รอ ProfileAccess เหมือนกัน) — ต้องรอให้มันมาก่อน
		-- ไม่งั้น AddItem คืน false เงียบๆ แล้วธงถูกตั้ง = ชุดเริ่มต้นหายไปตลอดกาล
		local started = os.clock()
		while not Inventory.Get(player) and player:IsDescendantOf(Players) and os.clock() - started < 30 do task.wait(0.2) end
		if Inventory.Get(player) then
			for _, kit in ipairs(IslandConfig.StarterKit) do Inventory.AddItem(player, kit.id, kit.count) end
			Data.starter = true
			print(("[Island] แจกชุดเริ่มต้นให้ %s"):format(player.Name))
		end
	end
	rebuild()
end

PlayerJoin.Each(function(player)
	if ownerId == nil then
		if RunService:IsStudio() then
			ownerId = player.UserId
			print(("[Island] Studio: %s เป็นเจ้าของเกาะ"):format(player.Name))
		else
			player:Kick("เข้าเกาะได้จากหน้าล็อบบี้เท่านั้น")
			return
		end
	end
	if not isOwner(player) then return end -- แขก (ชุด C) ยังทำอะไรไม่ได้
	load(player)
end)

Players.PlayerRemoving:Connect(function(player)
	LastCall[player] = nil
	if isOwner(player) then Data = nil end -- โปรไฟล์ปิดเซสชันแล้ว ตารางนี้เขียนต่อไม่ได้ (โมเดลปล่อยไว้ให้แขกดู)
end)

--------------------------------------------------------------------------------
-- Remote + Access
--------------------------------------------------------------------------------

Remotes.IslandPlace.OnServerEvent:Connect(function(player, slotIndex, cx, cz, r)
	if rateLimited(player) then return end
	local ok, reason = place(player, slotIndex, cx, cz, r)
	if not ok then notify(player, reason) end
	-- ตอบกลับ: ยังเหลือชิ้นเดิมในช่องนั้นกี่ชิ้น ไคลเอนต์ใช้ตัดสินว่าอยู่ในโหมดวางต่อไหม
	local state = Inventory.Get(player)
	local slot = state and type(slotIndex) == "number" and state.slots[slotIndex]
	local remaining = (ok and slot and slot.count) or 0
	Remotes.IslandPlace:FireClient(player, ok == true, remaining)
end)

Remotes.IslandPickup.OnServerEvent:Connect(function(player, uid)
	if rateLimited(player) then return end
	local ok, reason = pickup(player, tonumber(uid) or -1)
	if not ok then notify(player, reason) end
end)

IslandAccess.IsOwner = isOwner
IslandAccess.Data = function() return Data end
IslandAccess.EntryOf = function(model) return Entries[model] end
IslandAccess.ModelOf = function(uid) return Models[uid] end
IslandAccess.Place = place
IslandAccess.Pickup = pickup
IslandAccess.FindSlot = Inventory.FindSlotById
IslandAccess.Count = Inventory.CountOf
-- เสกของเข้ากระเป๋าสำหรับเทส (ของบางชิ้นยังไม่มีในชุดเริ่มต้น เช่นคอก/โซนแร่)
-- ลองดูว่าวางตรงนี้ได้ไหมโดยไม่วางจริง (เทสใช้หาช่องว่าง) — nil itemId = ไม่สนใจกฎดิน
IslandAccess.CanPlaceAt = function(cx, cz, w, d, r, itemId)
	return (IslandGrid.canPlace(Occupied, noBuildZones(), cx, cz, w, d, r or 0, itemId))
end

IslandAccess.Grant = function(player, id, count)
	if id == "gold" then Inventory.AddGold(player, count or 0); return true end
	return Inventory.AddItem(player, id, count or 1)
end

-- ตัวแก้ค่าใน entry สำหรับเทส (เร่งเวลาปลูก) — ตารางที่ส่งข้าม BindableFunction เป็นสำเนา แก้ตรงๆ ไม่ถึงของจริง
IslandAccess.SetEntry = function(uid, field, value)
	local model = Models[uid]
	local entry = model and Entries[model]
	if not entry then return false end
	entry[field] = value
	return true
end

-- ช่องเทสใน Studio: execute_luau ของ MCP รันใน sandbox ที่ require ได้สำเนาใหม่ของ IslandAccess (ช่องว่างทั้งตาราง)
-- BindableFunction เป็น instance จึงข้าม sandbox ได้ และ callback รันในบริบทของไฟล์นี้ — เทส tests/island_*_test.lua ใช้ทางนี้
if RunService:IsStudio() then
	local bf = Instance.new("BindableFunction")
	bf.Name = "IslandTest"
	bf.OnInvoke = function(op, ...)
		local fn = IslandAccess[op]
		if type(fn) ~= "function" then error("IslandTest: ไม่มี op " .. tostring(op)) end
		return fn(...)
	end
	bf.Parent = game:GetService("ServerStorage")
end
