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

-- ของที่ "วางแล้วใช้งานได้จริง" ไม่ใช่ของประดับเฉยๆ — ระบบเจ้าของมันหาจากชื่อโมเดล
-- (`CraftStations.STATIONS` / `CraftStations.STORAGE` / `FarmConfig` ของ `IllegalFarm`)
local FUNCTIONAL = {
	Stove = true, SteamBlender = true, AlchemyStill = true,
	IceBox = true, ApothecaryCabinet = true,
	DistillSet = true, Reactor = true, Boxs = true,
}

-- ในนั้น สามอันนี้ต้องติดแท็ก `WOLD_Farm` เพิ่มด้วย
local FARM_NODES = { DistillSet = true, Reactor = true, Boxs = true }

-- **ของตกแต่งที่เก็บเกี่ยวได้** (ผู้ใช้สั่ง 2026-09-22) — หินกับต้นไม้ที่ซื้อมาวาง ใช้ขวาน/อีเต้อ
-- ทุบเอาของได้เหมือนในเกมหลัก แต่ **คูลดาวน์ 30 นาที** แทน 60 วินาที และ **โมเดลอยู่ที่เดิม**
-- (ผู้ใช้เลือก) — ไม่หายไป ไม่ต้องซื้อใหม่ แค่รอจนกว่าจะเก็บได้อีก
--
-- `NodeKind` คือสิ่งที่ `Gathering` ใช้เปิดตาราง `GatherConfig.Nodes` — ชื่อต้องตรงกับที่นั่น
local HARVESTABLE = {
	Deco_Rock = "Rock",
	Deco_RockBig = "Rock",
	Deco_Tree = "Tree",
	Deco_Stump = "Tree",
	Deco_Bush = "Herb", -- พุ่มไม้ในเกมหลักคือจุดสมุนไพร ไม่ใช่ NodeKind ชื่อ Bush (ไม่มีอยู่จริง)
}

-- ของป่าที่ **ชื่อไม่ตรงกับ NodeKind** — ต้องบอกตรงๆ ว่าอันไหนคืออะไร
-- (`Wild_Pine` เป็นต้นไม้ ไม่ใช่ NodeKind ชื่อ "Pine" ซึ่งไม่มีอยู่จริง)
local WILD_KIND = {
	Wild_Pine = "Tree",
}

-- **ของตกแต่งที่เก็บเกี่ยวได้ = วันละครั้ง ทุกชิ้น** (ผู้ใช้สั่ง 2026-09-23)
--
-- ⚠️ เดิมของตกแต่งชุดแรก (`Deco_*`) ใช้คูลดาวน์ 30 นาทีซึ่งอยู่ใน**หน่วยความจำเซิร์ฟเวอร์**
-- (`SpentUntil` ของ `Gathering` + `task.delay`) — เกาะปิดทุกครั้งที่เจ้าของออกจากเกม ออกแล้วเข้าใหม่
-- จึงเก็บได้ทันทีเสมอ ซึ่งผู้ใช้เจอเอง · ตอนนี้ใช้ตราวันเดียวกับของป่า ซึ่งถูกจดลงโปรไฟล์ (`entry.day`)
-- จึงรอดข้ามการรีสตาร์ทโดยไม่ต้องเขียนกลไกอะไรเพิ่ม
local function harvestKindOf(id)
	if WILD_KIND[id] then return WILD_KIND[id], true end
	if id:sub(1, 5) == "Wild_" then return id:sub(6), true end
	return HARVESTABLE[id], true
end
local Inventory = require(game.ServerScriptService.Inventory)
local ProfileAccess = require(game.ServerScriptService.ProfileAccess)
local PlayerJoin = require(game.ServerScriptService.PlayerJoin)
local IslandAccess = require(script.Parent.IslandAccess)
local IslandConfig = require(ReplicatedStorage.IslandConfig)
local IslandGrid = require(ReplicatedStorage.IslandGrid)
local ItemCatalog = require(ReplicatedStorage.ItemCatalog)
local QuestConfig = require(ReplicatedStorage.QuestConfig)
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
	badground = "วางได้เฉพาะบนพื้นหญ้า",
	obstructed = "ตรงนี้มีของตั้งอยู่แล้ว",
	unreachable = "เดินเข้าไปไม่ได้ วางแล้วเก็บคืนไม่ได้",
	full = "กระเป๋าเต็ม",
	growing = "เก็บเกี่ยวก่อนแล้วค่อยเก็บแปลง",
	livestock = "ยังมีสัตว์อยู่ในคอก เก็บคอกแล้วสัตว์หายหมด",
	harvestedtoday = "เก็บเกี่ยวไปแล้ววันนี้ พรุ่งนี้ถึงจะย้ายได้",
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

-- **หนึ่งไอเทมมีได้หลายแบบ** (ผู้ใช้สั่ง 2026-09-23: เอาต้นไม้/พุ่มที่สุ่มเกิดบนผืนดินมาขายด้วย)
--
-- ต้นไม้มี 11 แบบ พุ่ม 8 หิน 8 — ขายแยกเป็น 27 ไอเทมจะได้ร้านที่เลื่อนไม่จบ และป่าที่ปลูกจากไอเทม
-- เดียวกันทุกต้นก็ดูเป็นแถวเสาไฟ · แบบสำรองถูกเก็บเป็น `<id>__2`, `<id>__3` ... แล้วสุ่มตอนวาง
-- · เงาพรีวิวฝั่งไคลเอนต์ยังเป็นแบบแรกเสมอ (มันคือ "ขนาดเท่านี้ ตรงนี้") ต้นจริงสุ่มเอา
local function prototypeOf(id)
	local folder = ReplicatedStorage:FindFirstChild("WOLD_Placeables")
	return folder and folder:FindFirstChild(id)
end

-- สุ่มแบบหนึ่งครั้ง **ตอนวาง** แล้วจำไว้ใน `entry.variant`
--
-- ⚠️ **ห้ามสุ่มใหม่ตอนปลูกคืนจากโปรไฟล์** สองเหตุผล: ขนาดที่ใช้ตรวจตอนวาง (footprint) ต้องเป็นขนาด
-- ของต้นที่ได้จริง ไม่งั้นต้นใหญ่ไปลงช่องที่ตรวจด้วยต้นเล็ก · และป่าที่ผู้ใช้จัดไว้จะสับเปลี่ยนตัวเอง
-- ทุกครั้งที่เซิร์ฟบูต
local function pickPrototype(id)
	local folder = ReplicatedStorage:FindFirstChild("WOLD_Placeables")
	local base = folder and folder:FindFirstChild(id)
	if not base then return nil end

	local picks = { base }
	local n = 2
	while true do
		local alt = folder:FindFirstChild(id .. "__" .. n)
		if not alt then break end
		picks[#picks + 1] = alt
		n += 1
	end
	return picks[math.random(#picks)]
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
	local proto = (entry.variant and prototypeOf(entry.variant)) or prototypeOf(entry.id)
	if not proto then
		warn(("[Island] ไม่มีต้นแบบ %s (uid %d) ข้าม"):format(tostring(entry.id), entry.uid))
		return nil
	end
	local w, d = footprintOf(proto)
	local model = proto:Clone()
	model.Name = tostring(entry.uid)

	-- **เฟอร์นิเจอร์ที่ใช้งานได้จริงต้องคงชื่อต้นแบบไว้ในลูก**
	--
	-- `CraftStations` (เตา/เครื่องปั่น/เครื่องต้มยา/ตู้เย็น/ตู้ยา) และ `IllegalFarm` หาที่ทำงานของมันจาก
	-- **ชื่อโมเดล** แต่บรรทัดบนเพิ่งเปลี่ยนชื่อเป็น uid ไปแล้ว (ซึ่งจำเป็น ระบบเกาะอ้างของจาก uid)
	-- → ใส่ลูกอีกชั้นที่ชื่อเดิมไว้ข้างใน ระบบพวกนั้นกวาด `GetDescendants` อยู่แล้วจึงเจอเอง
	--
	-- ทำเป็น Model ว่างที่ครอบของจริงไม่ได้ (จะไปยุ่งกับ PivotTo/Footprint) จึงใช้ **Model ลูกที่ชื่อถูก
	-- แล้วย้ายชิ้นส่วนเข้าไป** — โครงข้างนอกยังเป็นตัวที่ระบบเกาะรู้จัก
	if FUNCTIONAL[entry.id] then
		local inner = Instance.new("Model")
		inner.Name = entry.id
		for _, child in ipairs(model:GetChildren()) do
			if child ~= model.PrimaryPart then child.Parent = inner end
		end
		-- แอตทริบิวต์ของตู้ (StorageSlots/Accepts/Class) ต้องตามไปอยู่กับชื่อที่ระบบมองหา
		for key, value in pairs(proto:GetAttributes()) do
			if key:sub(1, 7) == "Storage" then inner:SetAttribute(key, value) end
		end
		inner.Parent = model
		-- ฟาร์มผิดกฎหมายหาจุดจาก **แท็ก** ไม่ใช่ชื่อ (ต่างจากครัว/ตู้) — ในเกมหลักเฟส 63 เป็นคนติดให้
		-- บนเกาะของโผล่มาตอนผู้เล่นวาง จึงต้องติดตรงนี้
		if FARM_NODES[entry.id] then
			-- **ต้องตั้ง `FarmKind` ก่อนติดแท็ก** `IllegalFarm.configFor` อ่านชนิดจาก**แอตทริบิวต์**
			-- ไม่ใช่จากชื่อโมเดล (ต่างจาก CraftStations) — ติดแท็กเปล่าๆ จะได้ warn แล้วไม่มีปุ่ม
			-- และลำดับสำคัญ: แท็กคือตัวจุดชนวน `GetInstanceAddedSignal` ซึ่งอ่านแอตทริบิวต์ทันที
			inner:SetAttribute("FarmKind", entry.id)
			CollectionService:AddTag(inner, "WOLD_Farm")
		end
	end
	local wx, wz = IslandGrid.centreOf(entry.x, entry.z, w, d, entry.r)
	model:PivotTo(IslandGrid.pivotFor(entry.x, entry.z, w, d, entry.r, groundAt(wx, wz)))
	model:SetAttribute("Uid", entry.uid)
	model:SetAttribute("ItemId", entry.id)
	model:SetAttribute("CellX", entry.x)
	model:SetAttribute("CellZ", entry.z)
	model:SetAttribute("Rot", entry.r)
	model:SetAttribute("Footprint", Vector2.new(w, d))

	-- ของตกแต่งที่ทุบเอาของได้ — `Gathering` ของเกมหลักใส่ปุ่มและแจกของให้เอง เห็นแท็กเมื่อไหร่ก็ทำงาน
	-- **ติดที่ตัวโมเดลนอกสุด** ต่างจากเฟอร์นิเจอร์ที่ต้องมีลูกชื่อถูก เพราะ Gathering อ่านจากแอตทริบิวต์
	local harvest, daily = harvestKindOf(entry.id)
	if harvest then
		model:SetAttribute("NodeKind", harvest)
		if daily then
			-- ไม่ต้องตั้ง RespawnSeconds: `Gathering` คิดเวลาถึงเที่ยงคืนวันใหม่ให้เองเมื่อเห็นธงนี้
			model:SetAttribute("DailyNode", true)
			-- ไม่จาง: มันเป็นของตกแต่งที่ผู้เล่นซื้อมาวางด้วย ต้นไม้โปร่งแสงค้างทั้งวันคือของเสีย
			-- ปุ่ม E ที่ดับไปคือสัญญาณเดียวที่ต้องการ (เหตุผลเดียวกับสัตว์ในคอก)
			model:SetAttribute("NoFade", true)
			-- **วันที่เก็บไปแล้วต้องอยู่ในโปรไฟล์ ไม่ใช่บนตัวโมเดลอย่างเดียว** — เกาะปิดทุกครั้งที่
			-- เจ้าของออกจากเกม ถ้าจำไว้แค่บนโมเดล ออก-เข้าใหม่ก็เก็บได้อีกรอบทันที
			if entry.day then model:SetAttribute("HarvestedDay", entry.day) end
			model:GetAttributeChangedSignal("HarvestedDay"):Connect(function()
				entry.day = model:GetAttribute("HarvestedDay")
			end)
		end
		-- ⚠️ **ต้นไม้ที่ปลูกเองไม่ติดแท็กตรงนี้** `IslandZones.tickTree` เป็นคนติดให้ตอนมันโตเต็มที่
		-- ติดตั้งแต่วางลง = ต้นกล้าเพิ่งปลูกก็ตัดได้ทันที แล้วระยะการโตทั้งสามขั้นก็ไม่มีความหมายเลย
		-- (แท็กคือสิ่งเดียวที่ทำให้ `Gathering` ใส่ปุ่มให้ ส่วน NodeKind/RespawnSeconds ตั้งล่วงหน้าได้
		-- ไม่มีใครอ่านจนกว่าจะมีแท็ก)
		if entry.id ~= IslandConfig.TreeItem then CollectionService:AddTag(model, "WOLD_Node") end
	end

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
	local proto = pickPrototype(slot.id)
	if not proto then return false, "noproto" end
	if #Data.placed >= IslandConfig.MaxPlaced then return false, "limit" end
	local w, d = footprintOf(proto)
	local ok, reason = IslandGrid.canPlace(Occupied, noBuildZones(), cx, cz, w, d, r, slot.id)
	if not ok then return false, reason end
	if not Inventory.RemoveFromSlot(player, slotIndex, 1) then return false, "noitem" end

	local entry = { uid = Data.nextUid, id = slot.id, x = cx, z = cz, r = r }
	-- จดแบบที่สุ่มได้ เฉพาะตอนที่มันไม่ใช่แบบแรก (โปรไฟล์จะได้ไม่บวมด้วยค่าที่เดาได้อยู่แล้ว)
	if proto.Name ~= slot.id then entry.variant = proto.Name end
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
	-- **คอกที่ยังมีสัตว์อยู่ เก็บไม่ได้** (เพิ่ม 2026-09-23 พร้อมกับการเซฟฝูง)
	--
	-- เดิมสัตว์หายตอนถูกเก็บเกี่ยว คอกจึงว่างเองอยู่แล้ว — ตอนนี้มันอยู่ถาวร และการเก็บคอกคืนกระเป๋า
	-- จะทิ้งฝูงไปทั้งฝูงแบบเงียบๆ (วัวตัวละ 1,800 เหรียญ) · ทรงเดียวกับแปลงผักที่ยังปลูกอยู่
	if entry.herd and #entry.herd > 0 then return false, "livestock" end
	-- **จุดรายวันที่เก็บไปแล้ววันนี้ ห้ามย้าย** ไม่งั้นคูลดาวน์รายวันไม่มีความหมายเลย:
	-- เก็บ → เอาคืนกระเป๋า → วางใหม่ ได้โหนดใหม่ที่ยังไม่เคยถูกเก็บทันที (สายเพชรก็รัวได้)
	if model:GetAttribute("HarvestedDay") == QuestConfig.DayNumber() then
		return false, "harvestedtoday"
	end
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

-- **บอกให้ชัดว่าเซิร์ฟนี้เป็นเกาะของใคร** (เพิ่ม 2026-09-22 หลังผู้ใช้เข้าเซิร์ฟจริงแล้วยืนนิ่งทำอะไรไม่ได้)
--
-- อาการ "เข้าได้แต่ทำอะไรไม่ได้" มีสาเหตุเดียว: `ownerId` ไม่ตรงกับคนที่เข้ามา แล้ว `PlayerJoin` ก็
-- `return` เงียบๆ — ไม่เตะ ไม่แจกชุดเริ่มต้น ไม่โหลดโปรไฟล์ ไม่มีอะไรบอกเลยว่าทำไม
print(("[Island] เซิร์ฟนี้เป็นเกาะของ userId=%s (PrivateServerId=%s)")
	:format(tostring(ownerId), game.PrivateServerId ~= "" and game.PrivateServerId or "ว่าง"))

PlayerJoin.Each(function(player)
	if ownerId == nil then
		if RunService:IsStudio() then
			ownerId = player.UserId
			print(("[Island] Studio: %s เป็นเจ้าของเกาะ"):format(player.Name))
		else
			-- **เซิร์ฟเกาะที่ระบุเจ้าของไม่ได้ = ให้คนแรกที่เข้าเป็นเจ้าของ** (แก้ 2026-09-22)
			--
			-- ของเดิมเตะทิ้ง ซึ่งตั้งใจกันคนที่พยายามเข้าเพลสตรงๆ ไม่ผ่านล็อบบี้ · แต่มันเตะ **เจ้าของ
			-- ตัวจริง** ด้วยเมื่อ DataStore อ่าน `farmcode_<id>` ไม่ได้ (ล่ม ช้า หรือเขียนไม่ทันตอนจอง)
			-- ซึ่งกลายเป็น "ซื้อ VIP แล้วเข้าเกาะตัวเองไม่ได้" — แย่กว่าการปล่อยคนแปลกหน้าเข้าเซิร์ฟ
			-- ส่วนตัวที่ไม่มีใครรู้ accessCode อยู่แล้ว
			--
			-- เซิร์ฟเกาะเป็น Reserved Server: เข้าได้เฉพาะคนที่ล็อบบี้ส่งมาเท่านั้น ด่านจริงอยู่ที่นั่น
			ownerId = player.UserId
			warn(("[Island] ระบุเจ้าของเกาะไม่ได้ — ให้ %s (userId=%d) เป็นเจ้าของ")
				:format(player.Name, player.UserId))
		end
	end
	if not isOwner(player) then
		-- แขก (ชุด C) ยังทำอะไรไม่ได้ — แต่ต้องบอก ไม่ใช่เงียบ
		warn(("[Island] %s (userId=%d) ไม่ใช่เจ้าของเกาะนี้ (เจ้าของ userId=%s) — เข้าได้แต่ยังทำอะไรไม่ได้")
			:format(player.Name, player.UserId, tostring(ownerId)))
		return
	end
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

-- **เทสเท่านั้น: สวมบทแขก** — Studio ไม่มีคนที่สองให้มายืนบนเกาะ และ `FarmOwnerId` เป็น nil ที่นั่น
-- สลับเฉพาะ `IslandAccess.IsOwner` ซึ่งเป็นตัวที่ด่านของระบบอื่นถาม (ครัว ตู้ NPC บอร์ดเควส แปลงผัก)
-- ส่วนการวาง/เก็บของในไฟล์นี้เรียก `isOwner` ตรงๆ จึงไม่ถูกหลอก — ตั้งใจ ไม่ใช่ของค้าง
if RunService:IsStudio() then
	-- อ่าน EXP จริงให้เทส — **`require` ใน sandbox ของ `execute_luau` คืนสำเนาใหม่ที่ States ว่าง**
	-- (กติกาเดิมของโปรเจ็ค) เทสจึงอ่านเลขจากโมดูลตรงๆ ไม่ได้เลย ต้องถามผ่านสคริปต์เซิร์ฟเวอร์จริง
	IslandAccess.Exp = function(player)
		local Progression = require(game.ServerScriptService.Progression)
		local state = Progression.Get(player)
		return state and state.exp or 0, state and state.level or 1
	end

	IslandAccess.PretendGuest = function(on)
		IslandAccess.IsOwner = on and function() return false end or isOwner
		return on == true
	end
end

-- คลังของ `IslandNodes` — จุดเก็บเกี่ยวที่สุ่มโผล่บนผืนดินต้องอยู่ข้ามการรีสตาร์ท (ผู้ใช้สั่ง 2026-09-23
-- "พอสปอนขึ้นมาแล้วก็อย่าให้หายไป ... ยิ่งนานยิ่งรกขึ้นเรื่อยๆ") · คืน nil ตอนโปรไฟล์ยังไม่โหลด
IslandAccess.NodeStore = function()
	if not Data then return nil end
	if not Data.nodes then Data.nodes = {} end
	return Data.nodes
end
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

-- ช่องนี้ถูก "ของที่วางไว้" ยึดไปหรือยัง — **คนละคำถามกับ `CanPlaceAt`**
--
-- `CanPlaceAt` ถามว่า "วางของ **ใหม่** ตรงนี้ได้ไหม" จึงนับทุกอย่างที่ตั้งอยู่จริงในโลกเป็นสิ่งกีดขวาง
-- รวมถึง**ตัวผู้ถามเอง** — `IslandNodes` เอาไปถามเรื่องจุดที่มันวางไว้แล้ว ก็ได้คำตอบว่า "ไม่ว่าง"
-- ทุกครั้ง แล้วทำลายของตัวเองทิ้งทั้งทุ่ง (ผู้ใช้แจ้ง 2026-09-23 "ออกเข้าใหม่แล้วมันรีเกิดใหม่หมด")
IslandAccess.CellTaken = function(cx, cz)
	return Occupied[IslandGrid.key(cx, cz)] ~= nil
end

-- คืนของออกจากกระเป๋า (เทสเท่านั้น) — คู่กับ Grant เพื่อให้เทสเก็บกวาดตัวเองได้
-- ไม่มีตัวนี้ เทสที่เสกของทุกรอบจะทำกระเป๋าผู้ใช้เต็มจนเก็บของคืนจากเกาะไม่ได้ (เจอจริง 2026-09-22)
-- `count` = เอาออกไม่เกินเท่านี้ · **nil = เอาออกทั้งหมด** (ผู้เรียกเดิมไม่ส่งมา จึงไม่เปลี่ยนพฤติกรรม)
--
-- ⚠️ เทสที่เสกของทับกองเดิมของผู้ใช้ **ต้องส่ง count เป็นส่วนต่าง** ไม่งั้นกองที่เขามีอยู่ก่อนหายไปด้วย
-- (เจอจริง 2026-09-22: เทสหนอนกวาดผัก 52 ชิ้นของผู้ใช้ทิ้งทั้งกอง ทั้งที่ตัวมันเองทำเกิดแค่ 45)
-- ถอดของที่สวมอยู่ (เทสเท่านั้น) — `Equip(player, nil)` ไม่ใช่การถอด มันแค่ไม่ทำอะไร
-- เทสที่ต้องพิสูจน์ "มือเปล่าเก็บไม่ได้" จึงต้องมีทางถอดจริงๆ ไม่งั้นมันยังถืออีเต้อจากขั้นตอนก่อนอยู่
IslandAccess.Unequip = function(player, kind)
	return Inventory.Unequip(player, kind or "weapon")
end

-- สั่งเก็บเกี่ยวจากเทส (เทสเท่านั้น) — กด ProximityPrompt จากสคริปต์ไม่ได้ ดู GatherAccess
IslandAccess.Gather = function(player, node)
	local gather = require(game.ServerScriptService.GatherAccess).Gather
	return gather and gather(player, node) or false
end

IslandAccess.Revoke = function(player, id, count)
	local want = math.min(count or math.huge, Inventory.CountOf(player, id))
	if want <= 0 then return 0 end
	return Inventory.RemoveById(player, id, want) and want or 0
end

-- จัดกระเป๋า + อ่านลำดับช่อง (เทสเท่านั้น) — `require(Inventory)` ใน sandbox คืนสำเนาว่าง
-- สวม/ถอดอาวุธผ่านเซิร์ฟเวอร์จริง (เทสเท่านั้น) — `require(Inventory)` ใน sandbox คืนสำเนาว่าง
IslandAccess.Equip = function(player, slotIndex)
	return Inventory.Equip(player, slotIndex)
end

IslandAccess.Unequip = function(player, kind)
	return Inventory.Unequip(player, kind or "weapon")
end

-- อ่านช่องกระเป๋าดิบทั้งหมด รวมช่วง VIP (เทสเท่านั้น)
IslandAccess.BagRaw = function(player)
	local state = Inventory.Get(player)
	if not state then return nil end
	local IC = require(game.ReplicatedStorage.InventoryConfig)
	local out = {}
	for i = 1, IC.TotalSlotCount do
		local slot = state.slots[i]
		out[i] = slot and slot.id or false
	end
	return out
end

IslandAccess.HasRoom = function(player, id, count)
	return Inventory.HasRoomFor(player, id, count or 1)
end

IslandAccess.SortSide = function(player, which)
	Inventory.AutoSort(player, which)
	return true
end

-- ตารางช่องเป็นรูปทรงอะไร (เทส) — sparse array ข้าม remote แล้วกลายเป็น dict คีย์สตริง
IslandAccess.SlotsShape = function(player)
	local state = Inventory.Get(player)
	if not state then return "ไม่มี state" end
	local IC = require(game.ReplicatedStorage.InventoryConfig)
	local n, maxKey, holes = 0, 0, 0
	for k in pairs(state.slots) do
		n += 1
		if type(k) == "number" and k > maxKey then maxKey = k end
	end
	for i = 1, maxKey do if state.slots[i] == nil then holes += 1 end end
	return ("ช่องที่มีของ %d · ดัชนีสูงสุด %d · ช่องว่างคั่นกลาง %d · #slots (array length) = %d")
		:format(n, maxKey, holes, #state.slots)
end

IslandAccess.DumpSlots = function(player)
	local state = Inventory.Get(player)
	if not state then return "ไม่มี state" end
	local rows = {}
	for k, v in pairs(state.slots) do
		rows[#rows + 1] = ("[%s:%s]=%s x%s"):format(type(k), tostring(k), tostring(v and v.id), tostring(v and v.count))
	end
	table.sort(rows)
	return table.concat(rows, " | ")
end

IslandAccess.Sort = function(player)
	Inventory.AutoSort(player)
	local state = Inventory.Get(player)
	if not state then return nil end
	local out = {}
	for i = 1, 36 do
		local slot = state.slots[i]
		out[i] = slot and slot.id or false
	end
	return out
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
