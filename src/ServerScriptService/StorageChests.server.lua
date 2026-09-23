-- StorageChests.server.lua: หีบ 119 ใบในเมืองที่เคยเป็นแค่ของตกแต่ง ตอนนี้เปิดแล้วใส่ของได้
--
-- **ไม่ใช่หีบสมบัติ** (`TreasureChests.server`) ซึ่งเป็นของที่วางลงพื้น เปิดครั้งเดียวได้ของสุ่ม แล้วหายไป
-- อันนั้นคือ "รางวัล" ส่วนอันนี้คือ "ที่เก็บของ" — เริ่มต้นว่างเปล่า ใครยัดอะไรไว้คนอื่นก็เห็นและหยิบได้
--
-- **ของหายตอนเซิร์ฟเวอร์ปิด** ตามที่ผู้ใช้เลือก เก็บไว้ในหน่วยความจำอย่างเดียว ไม่แตะ DataStore
-- นั่นแปลว่าหีบพวกนี้เหมาะกับการส่งของให้กันในรอบเดียว ไม่ใช่คลังถาวร (คลังถาวรคือของมาดามออเรเลีย)
--
-- **ใครก็หยิบได้** ไม่มีเจ้าของ ไม่มีล็อก — เป็นหีบสาธารณะกลางเมืองจริงๆ เกมนี้มีทหารยามและระบบหัวแดง
-- อยู่แล้ว การขโมยจึงเป็นส่วนหนึ่งของเกม ไม่ใช่ช่องโหว่
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")

local ServerConfig = require(game.ServerScriptService.ServerConfig)
local IslandAccess = require(game.ServerScriptService.Island.IslandAccess)
if ServerConfig.IsLobby then return end

local Inventory = require(game.ServerScriptService.Inventory)
local ItemCatalog = require(game.ReplicatedStorage.ItemCatalog)
local Classes = require(game.ServerScriptService.Classes)
local ClassConfig = require(game.ReplicatedStorage.ClassConfig)
local Remotes = require(game.ReplicatedStorage.Remotes)
local ChestStorageAccess = require(game.ServerScriptService.ChestStorageAccess)

--------------------------------------------------------------------------------
-- ตัวเลข
--------------------------------------------------------------------------------

-- ผู้ใช้กำหนด 3 ช่อง
--
-- จำนวนน้อยโดยตั้งใจ: หีบสาธารณะที่ใส่ได้เยอะจะกลายเป็นคลังฟรีที่ดีกว่าคลังของมาดามออเรเลียซึ่งต้องเดินไปหา
-- และเสียค่าฝาก สามช่องพอสำหรับ "ฝากของให้เพื่อน" แต่ไม่พอสำหรับ "ใช้แทนคลัง"
local SLOTS = 3

-- หีบธรรมดา 3 ช่อง ตู้เย็น/ตู้ยา (CraftStations.server ติดแอตทริบิวต์ให้) 25 ช่องและรับเฉพาะของบางชนิด
local function slotsOf(model)
	return model:GetAttribute("StorageSlots") or SLOTS
end

-- ของชิ้นนี้ใส่ตู้นี้ได้ไหม (ตู้เย็นรับ food ตู้ยารับ medicine หีบธรรมดารับทุกอย่างที่ฝากได้)
local function accepts(model, id)
	local item = ItemCatalog.Get(id)
	if not item or not ItemCatalog.IsStorable(id) then return false end
	local want = model:GetAttribute("StorageAccepts")
	if not want then return true end
	return item[want] == true
end

-- ตู้ที่จำกัดอาชีพ (ตู้ยา = นักบวช)
--
-- **บนเกาะไม่จำกัดอาชีพ** (ผู้ใช้กำหนด 2026-09-22) เหตุผลเดียวกับเตาใน `CraftStations`: เกาะเป็นเซิร์ฟ
-- ส่วนตัวของคนที่ซื้อตู้มาเอง การกันด้วยอาชีพไม่ได้แบ่งงานกับใคร มันแค่ล็อกของที่เขาจ่ายเงินไปแล้ว
local function mayOpen(player, model)
	-- แขกบนเกาะของคนอื่นเปิดตู้ของเขาไม่ได้ (ผู้ใช้สั่ง 2026-09-23) — เจ้าของยังไม่ต้องมีอาชีพเหมือนเดิม
	if ServerConfig.IsFarm then return IslandAccess.MayUseFixtures(player) end
	local class = model:GetAttribute("StorageClass")
	if not class then return true end
	return Classes.Has(player, class)
end

local PROMPT_DISTANCE = 10
local CHEST_TAG = "WOLD_StorageChest"

--------------------------------------------------------------------------------
-- ของในหีบ
--------------------------------------------------------------------------------

-- [model] = { [1..3] = slot }  โดย slot มีรูปเดียวกับช่องกระเป๋าเป๊ะ { id, count, durability, meta }
--
-- **รูปเดียวกับกระเป๋า** ด้วยเหตุผลเดียวกับที่ Vault ใช้: ของทุกชิ้นที่เข้ามาก็มาจากช่องกระเป๋า และขาออก
-- ก็กลับไปเป็นช่องกระเป๋า ถ้าเปลี่ยนรูประหว่างทาง ความคงทนหรือป้ายทะเบียนจะหายเงียบๆ ตรงจุดแปลง
local Contents = setmetatable({}, { __mode = "k" }) -- weak key: หีบที่ถูกลบไปไม่ค้างในตาราง

-- ใครเปิดหีบไหนอยู่ ใช้ส่งภาพให้ตรงกันเมื่อมีคนอื่นหยิบของไปจากหีบเดียวกัน
local Viewers = {} -- [player] = model

local function contentsOf(model)
	local c = Contents[model]
	if not c then
		c = {}
		Contents[model] = c
	end
	return c
end

-- ภาพของหีบสำหรับส่งให้ไคลเอนต์ — ส่งทั้งสามช่องเสมอ ช่องว่างเป็น false
--
-- ส่ง false แทน nil เพราะ nil ในตารางทำให้ช่องหายไปเลยตอนข้ามสายไป ไคลเอนต์จะไม่รู้ว่ามีกี่ช่อง
local function snapshot(model)
	local c = contentsOf(model)
	local view = {}
	for i = 1, slotsOf(model) do
		local slot = c[i]
		view[i] = slot and {
			id = slot.id,
			count = slot.count or 1,
			durability = slot.durability,
			meta = slot.meta,
		} or false
	end
	return view
end

local function pushTo(player, model)
	if not player.Parent then return end
	Remotes.StorageChestUpdate:FireClient(player, snapshot(model), slotsOf(model))
end

-- บอกทุกคนที่กำลังเปิดหีบใบนี้อยู่ ไม่ใช่แค่คนที่เพิ่งทำอะไรไป
local function pushAll(model)
	for player, open in pairs(Viewers) do
		if open == model then pushTo(player, model) end
	end
end

--------------------------------------------------------------------------------
-- ระยะ
--------------------------------------------------------------------------------

local function nearEnough(player, model)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or not model or not model.Parent then return false end
	local pivot = model:GetPivot().Position
	-- เผื่อกว่าระยะปุ่มนิดหน่อย ขยับตัวนิดเดียวระหว่างเปิดอยู่ไม่ควรเด้งปิด
	return (root.Position - pivot).Magnitude <= PROMPT_DISTANCE + 6
end

--------------------------------------------------------------------------------
-- ใส่ / หยิบ
--------------------------------------------------------------------------------

-- ยัดของจากช่องกระเป๋า `bagIndex` ลงหีบ
local function put(player, model, bagIndex, count)
	local state = Inventory.Get(player)
	if not state then return end
	local slot = state.slots[bagIndex]
	if not slot then return end

	count = math.clamp(math.floor(tonumber(count) or 1), 1, slot.count or 1)

	if not accepts(model, slot.id) then
		local want = model:GetAttribute("StorageAccepts")
		return Remotes.SocialNotify:FireClient(player, "warn",
			want == "food" and "ตู้เย็นเก็บได้เฉพาะอาหาร" or want == "medicine" and "ตู้ยาเก็บได้เฉพาะยา" or "ของชิ้นนี้ฝากไม่ได้")
	end

	local c = contentsOf(model)

	-- **ของในหีบไม่รวมกอง** ตามที่ผู้ใช้กำหนด
	--
	-- หนึ่งช่องคือหนึ่งกอง วางแล้ววางเลย ไม่ไปรวมกับกองเดิมที่ชนิดเดียวกัน — สามช่องจึงหมายถึงของสามอย่าง
	-- เสมอ ไม่ใช่ "สามช่องที่อัดของชนิดเดียวได้ไม่จำกัด" ซึ่งจะทำให้หีบสาธารณะกลายเป็นคลังอีกที
	-- (Inventory ฝั่งกระเป๋ายังรวมกองตามปกติ กฎนี้ใช้เฉพาะในหีบ)

	-- ช่องว่าง
	for i = 1, slotsOf(model) do
		if c[i] == nil then
			c[i] = {
				id = slot.id,
				count = count,
				durability = slot.durability,
				meta = slot.meta,
			}
			Inventory.RemoveFromSlot(player, bagIndex, count)
			pushAll(model)
			return
		end
	end

	Remotes.SocialNotify:FireClient(player, "warn", "หีบเต็มแล้ว")
end

-- หยิบของจากช่อง `index` ของหีบกลับเข้ากระเป๋า
local function take(player, model, index, count)
	index = math.floor(tonumber(index) or 0)
	if index < 1 or index > slotsOf(model) then return end
	local c = contentsOf(model)
	local slot = c[index]
	if not slot then return end

	count = math.clamp(math.floor(tonumber(count) or 1), 1, slot.count or 1)

	-- **เช็คที่ว่างในกระเป๋าก่อนลบออกจากหีบ** ถ้าลบก่อนแล้วกระเป๋าเต็ม ของจะหายไปเฉยๆ
	if not Inventory.HasRoomFor(player, slot.id, count, slot.meta) then
		Remotes.SocialNotify:FireClient(player, "warn", "กระเป๋าเต็ม")
		return
	end

	local got = Inventory.AddItem(player, slot.id, count, slot.durability, slot.meta)
	if not got then
		Remotes.SocialNotify:FireClient(player, "warn", "กระเป๋าเต็ม")
		return
	end

	local left = (slot.count or 1) - count
	if left > 0 then
		slot.count = left
	else
		c[index] = nil
	end
	pushAll(model)
end

--------------------------------------------------------------------------------
-- ปุ่ม E
--------------------------------------------------------------------------------

local wired = {}

local function wire(model)
	if wired[model] or not model.Parent then return end

	-- ต้องมีชิ้นส่วนสักชิ้นให้แขวนปุ่ม โมเดลตกแต่งบางใบอาจยังไม่มี PrimaryPart
	local anchor = model.PrimaryPart
	if not anchor then
		for _, d in ipairs(model:GetDescendants()) do
			if d:IsA("BasePart") then anchor = d break end
		end
	end
	if not anchor then return end

	wired[model] = true

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "StorageChestPrompt"
	prompt.ActionText = model:GetAttribute("StorageAction") or "เปิดหีบ"
	prompt.ObjectText = model:GetAttribute("StorageName") or "หีบเก็บของ"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = PROMPT_DISTANCE
	prompt.RequiresLineOfSight = false
	prompt.Parent = anchor

	prompt.Triggered:Connect(function(player)
		if not mayOpen(player, model) then
			local class = ClassConfig.Get(model:GetAttribute("StorageClass"))
			return Remotes.SocialNotify:FireClient(player, "warn", ("เฉพาะ%sเท่านั้น"):format(class and class.name or "อาชีพที่กำหนด"))
		end
		Viewers[player] = model
		Remotes.StorageChestOpen:FireClient(player, slotsOf(model))
		pushTo(player, model)
	end)
end

--------------------------------------------------------------------------------
-- คำขอจากไคลเอนต์
--------------------------------------------------------------------------------

Remotes.RequestStorageChestPut.OnServerEvent:Connect(function(player, bagIndex, count)
	local model = Viewers[player]
	if not model or not nearEnough(player, model) then return end
	put(player, model, math.floor(tonumber(bagIndex) or 0), count)
end)

Remotes.RequestStorageChestTake.OnServerEvent:Connect(function(player, index, count)
	local model = Viewers[player]
	if not model or not nearEnough(player, model) then return end
	take(player, model, index, count)
end)

Remotes.RequestStorageChestClose.OnServerEvent:Connect(function(player)
	Viewers[player] = nil
end)

Players.PlayerRemoving:Connect(function(player)
	Viewers[player] = nil
end)

--------------------------------------------------------------------------------
-- แอดมินเสกของกระจายลงหีบ
--------------------------------------------------------------------------------

-- ใส่ของ `id` ลงหีบ `model` หนึ่งชิ้น คืน true ถ้าลงได้
--
-- หนึ่งชิ้นต่อหนึ่งช่องเสมอ ไม่รวมกอง ตามกฎเดียวกับที่คนยัดเอง — หีบหนึ่งใบจึงรับได้สูงสุด 3 ชิ้นพอดี
local function dropOne(model, id, durability, meta)
	local c = contentsOf(model)
	for i = 1, slotsOf(model) do
		if c[i] == nil then
			c[i] = { id = id, count = 1, durability = durability, meta = meta }
			return true
		end
	end
	return false
end

-- หีบที่ยังมีที่ว่าง — จำกัดรัศมีรอบ `origin` ได้ถ้าส่งมา
local function chestsWithRoom(origin, radius)
	local list = {}
	for _, model in ipairs(CollectionService:GetTagged(CHEST_TAG)) do
		if model:IsA("Model") and model.Parent then
			local ok = true
			if origin and radius then
				ok = (model:GetPivot().Position - origin).Magnitude <= radius
			end
			if ok then
				local c = contentsOf(model)
				local free = 0
				for i = 1, slotsOf(model) do
					if c[i] == nil then free += 1 end
				end
				if free > 0 then list[#list + 1] = model end
			end
		end
	end
	return list
end

-- โปรยของ `count` ชิ้นลงหีบทั่วแมพแบบสุ่ม
--
-- **สุ่มหีบใหม่ทุกชิ้น ไม่ใช่สุ่มหีบแล้วเทลงใบเดียว** ผู้ใช้ขอให้ "กระจายกันไป กล่องหนึ่ง 2 ชิ้น อีกกล่อง
-- 1 ชิ้น" การสุ่มรายชิ้นให้ผลแบบนั้นเอง โดยไม่ต้องกำหนดสูตรแบ่งเอง และเพดาน 3 ช่องต่อใบก็บังคับให้
-- ของล้นไปใบอื่นโดยอัตโนมัติ
--
-- คืน จำนวนที่ลงได้จริง, จำนวนหีบที่โดนใช้
-- `origin` + `radius` จำกัดให้โปรยเฉพาะหีบแถวนั้น (ไม่ส่ง = ทั้งแมพ)
--
-- **มีไว้เพราะวัดแล้ว**: แมพนี้มีหีบ 119 ใบ ถ้าโปรยทั้งแมพ ของ 3 ชิ้นจะลงคนละใบ 98% ของครั้ง
-- แทบไม่มีทางได้ "ใบหนึ่ง 2 ชิ้น อีกใบ 1 ชิ้น" อย่างที่ผู้ใช้อยากเห็น การจำกัดรัศมีให้เหลือหีบไม่กี่ใบ
-- คือสิ่งที่ทำให้ของกระจุกกันจริง — วัดได้: เหลือ 5 ใบ ได้ 2+1 ราว 47% ของครั้ง
function ChestStorageAccess.Scatter(id, count, durability, meta, origin, radius)
	count = math.max(1, math.floor(tonumber(count) or 1))
	local placed, used = 0, {}

	for _ = 1, count do
		local pool = chestsWithRoom(origin, radius)
		if #pool == 0 then break end
		local model = pool[math.random(#pool)]
		if dropOne(model, id, durability, meta) then
			placed += 1
			used[model] = true
			pushAll(model)
		end
	end

	local chests = 0
	for _ in pairs(used) do chests += 1 end
	return placed, chests
end

--------------------------------------------------------------------------------
-- หาหีบในแมพ
--------------------------------------------------------------------------------

-- ติดปุ่มให้หีบทุกใบที่ติดแท็กไว้
--
-- **ลูปถามใหม่ทุก 0.5 วินาที ไม่ใช่ผูกครั้งเดียวตอนบูต** กฎเหล็กของโปรเจ็คนี้: เพลสเปิด StreamingEnabled
-- โมเดล/แท็กมาถึงคนละรอบ ห่างกันเป็นวินาที และคนละลำดับทุกครั้ง โค้ดที่ผูกรอบเดียวจะแพ้จังหวะกับบางใบเสมอ
-- และเป็นคนละใบทุกรอบ ตาราง `wired` กันการติดซ้ำ
task.spawn(function()
	while true do
		for _, model in ipairs(CollectionService:GetTagged(CHEST_TAG)) do
			if model:IsA("Model") then wire(model) end
		end
		task.wait(0.5)
	end
end)

CollectionService:GetInstanceAddedSignal(CHEST_TAG):Connect(function(model)
	if model:IsA("Model") then wire(model) end
end)
