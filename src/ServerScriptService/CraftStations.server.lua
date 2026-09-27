-- CraftStations.server.lua: เครื่องครัวและเครื่องยาที่กด E ได้
--
--   Stove              ทำอาหาร (ต้องมีตะหลิวเชฟในกระเป๋า)  → หน้าคราฟ station "stove"   มีไฟลุกตอนทำ
--   SteamBlender       ปั่นเครื่องดื่ม (ต้องมีตะหลิวเชฟ)    → station "blender"
--   AlchemyStill       ต้มยา                                  → station "still"
--   IceBox             ตู้เย็น 25 ช่อง เก็บได้เฉพาะอาหาร เชฟเท่านั้น → หีบเก็บของ (StorageChests) ติดแอตทริบิวต์
--   ApothecaryCabinet  ตู้ยา 25 ช่อง เก็บได้เฉพาะยา นักบวชเท่านั้น
--
-- หาโมเดลจาก **ชื่อ** ในลูปถามใหม่ (กฎเหล็ก StreamingEnabled) ผู้ใช้วางเพิ่มที่ไหนก็เจอ — ยกเว้นชิ้นที่อยู่ใน
-- โมเดลฟาร์มผิดกฎหมาย (Reactor มีเตาเป็นส่วนประกอบ) ซึ่งเป็นของตกแต่ง
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")

local ServerConfig = require(game.ServerScriptService.ServerConfig)
local IslandAccess = require(game.ServerScriptService.Island.IslandAccess)
if ServerConfig.IsLobby then return end

local Inventory = require(game.ServerScriptService.Inventory)
local CraftAccess = require(game.ServerScriptService.CraftAccess)
local Remotes = require(game.ReplicatedStorage.Remotes)

-- ระยะกดปุ่ม **วัดจากชิ้นที่ปุ่มแขวนอยู่ ไม่ใช่จากตัวโมเดล** — และเครื่องครัวไม่ได้ตั้งอยู่บนพื้นเสมอไป
--
-- เครื่องปั่นไอน้ำในโรงเตี๊ยมตั้งบนเคาน์เตอร์: ปุ่มแขวนที่ชิ้น "Jar" ที่ Y=54.0 ส่วนพื้นดินรอบเคาน์เตอร์อยู่ที่
-- Y=42.0 ผู้เล่นที่ยืนข้างเคาน์เตอร์จึงมี HRP อยู่ที่ราว 45 = **ห่างจากปุ่ม 9.9 สตัดตั้งแต่ยืนติดเคาน์เตอร์แล้ว**
-- และ 10.9 เมื่อถอยออกมาหนึ่งก้าว ระยะเดิม 10 จึงอยู่พอดีเส้นแบ่ง: เตา (ปุ่มห่าง 3.8) ใช้ได้ ส่วนเครื่องปั่น
-- ติดๆ ดับๆ จนเหมือนใช้ไม่ได้เลย — อาการที่ผู้ใช้เจอ (ทำอาหารได้ แต่ปั่นไม่ได้) 2026-09-18
--
-- 16 เผื่อไว้พอให้ถอยได้ราว 13 สตัดแนวราบ และยัง **แคบกว่า** สองด่านที่วัดจาก pivot ของเครื่อง (16 สตัดเท่ากัน
-- แต่ pivot อยู่ระดับเคาน์เตอร์ จึงเผื่อแนวราบได้ 15.6) แปลว่ากดปุ่มติดเมื่อไหร่ อีกสองด่านผ่านแน่นอน
-- ไม่มีทางเกิดเคส "เปิดหน้าต่างแล้วเด้งปิดทันที"
local RANGE = 16

-- ชื่อโมเดล → การตั้งค่า
local STATIONS = {
	Stove = { station = "stove", action = "ทำอาหาร", object = "เตาทำอาหาร", needs = "Spatula", fire = true },
	SteamBlender = { station = "blender", action = "ปั่นเครื่องดื่ม", object = "เครื่องปั่นไอน้ำ", needs = "Spatula" },
	AlchemyStill = { station = "still", action = "ต้มยา", object = "เครื่องต้มยา" },
	-- เครื่องคราฟขั้นสูง (เฟส 2c) — **บนเกาะเท่านั้น** (`farmOnly`): ชื่อพวกนี้อาจซ้ำกับของตกแต่งในแมพหลัก
	-- (บ้านช่างทอมีกี่ทอ) ถ้าต่อสายที่นั่นด้วย สูตรส่งออกจะคราฟได้ในเมืองโดยไม่มีเลเวลฟาร์มคุม
	BakeryOven = { station = "bakery", action = "อบขนม", object = "เตาอบขนมปัง", fire = true, farmOnly = true },
	MetalBench = { station = "metal", action = "ตีเหล็ก", object = "โต๊ะช่างเหล็ก", farmOnly = true },
	Loom = { station = "loom", action = "ทอผ้า", object = "กี่ทอผ้าไอน้ำ", farmOnly = true },
}

-- ตู้เก็บของ: ส่งต่อให้ StorageChests.server ผ่านแท็ก + แอตทริบิวต์
local STORAGE = {
	IceBox = { slots = 25, accepts = "food", class = "Chef", action = "เปิดตู้เย็น", object = "ตู้เย็น" },
	ApothecaryCabinet = { slots = 25, accepts = "medicine", class = "Priest", action = "เปิดตู้ยา", object = "ตู้ยา" },
}

local IGNORE_UNDER = { DistillSet = true, Reactor = true }

local function decorative(model)
	local p = model.Parent
	while p and p ~= workspace do
		if IGNORE_UNDER[p.Name] then return true end
		p = p.Parent
	end
	return false
end

-- มีของชิ้นนี้ไหม — **นับช่องมือด้วย ไม่ใช่แค่กระเป๋า**
--
-- ตะหลิวถือได้แล้ว (ItemCatalog: kind = "weapon") และการสวมคือการย้ายของออกจากกระเป๋าไปช่องมือ ถ้านับแค่
-- กระเป๋า เชฟที่ถือตะหลิวอยู่ในมือจะโดนเตาไล่ว่า "ต้องมีตะหลิวเชฟ" ซึ่งเป็นคำตอบที่ไม่มีทางเดาถูก
local function hasItem(player, id)
	local _, equipped = Inventory.EquippedWeapon(player)
	if equipped and equipped.id == id then return true end
	local state = Inventory.Get(player)
	if not state then return false end
	for _, slot in pairs(state.slots) do
		if slot.id == id then return true end
	end
	return false
end

-- ชิ้นที่แขวนปุ่ม: ชิ้นใหญ่สุดที่สูงระดับคน (Root ของชุดคิทอยู่ที่พื้น)
local function anchorOf(model)
	local cf, sz = model:GetBoundingBox()
	local bottom = cf.Position.Y - sz.Y * 0.5
	local best, bestScore
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") and d.Transparency < 0.9 then
			local h = d.Position.Y - bottom
			if h >= 1 and h <= 6 then
				local score = d.Size.X * d.Size.Y * d.Size.Z
				if not bestScore or score > bestScore then best, bestScore = d, score end
			end
		end
	end
	return best or model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true)
end

--------------------------------------------------------------------------------
-- ไฟที่เตา
--------------------------------------------------------------------------------

local function lightFire(model, seconds)
	local hearth = model:FindFirstChild("FireboxHearth", true) or model:FindFirstChild("Hotplate", true) or anchorOf(model)
	if not hearth then return end
	local fire = hearth:FindFirstChild("WOLD_StoveFire")
	if not fire then
		fire = Instance.new("Fire")
		fire.Name = "WOLD_StoveFire"
		fire.Size = 4
		fire.Heat = 6
		fire.Color = Color3.fromRGB(255, 150, 60)
		fire.SecondaryColor = Color3.fromRGB(255, 60, 20)
		fire.Parent = hearth
	end
	fire.Enabled = true
	local token = os.clock()
	hearth:SetAttribute("FireToken", token)
	task.delay(seconds, function()
		if hearth.Parent and hearth:GetAttribute("FireToken") == token then fire.Enabled = false end
	end)
end

-- ไฟลุกตลอดเวลาที่ทำอยู่ (+3 วิทิ้งท้ายให้เห็นว่าเพิ่งเสร็จ) สเต็กที่ตุ๋น 15 นาทีจึงเป็นเตาที่ติดไฟอยู่จริง
CraftAccess.OnCraftStarted = function(player, station, model, seconds)
	local spec = model and STATIONS[model.Name]
	if spec and spec.fire then lightFire(model, (seconds or 0) + 3) end
end

-- ตอนเสร็จยังจุดซ้ำสั้นๆ เผื่อกรณีที่ไฟถูกงานอื่นดับไปก่อน (คนสองคนใช้เตาใบเดียวกัน)
CraftAccess.OnCrafted = function(player, station, model)
	local spec = model and STATIONS[model.Name]
	if spec and spec.fire then lightFire(model, 6) end
end

--------------------------------------------------------------------------------
-- ต่อสาย
--------------------------------------------------------------------------------

local wired = {}

local function wireStation(model, spec)
	local anchor = anchorOf(model)
	if not anchor then return end
	wired[model] = true
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "StationPrompt"
	prompt.ActionText = spec.action
	prompt.ObjectText = spec.object
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.MaxActivationDistance = RANGE
	prompt.RequiresLineOfSight = false
	prompt.HoldDuration = 0
	prompt.Parent = anchor
	prompt.Triggered:Connect(function(player)
		-- **ครัวบนเกาะไม่ต้องเป็นเชฟ** (ผู้ใช้กำหนด 2026-09-22: "เกาะตัวเองใช้ได้เลย ไม่ต้องเป็นเชฟ")
		--
		-- เกาะเป็นเซิร์ฟส่วนตัวของคนคนเดียวที่ซื้อเตาด้วยเงินตัวเอง การกันด้วยอาชีพตรงนั้นไม่ได้แบ่งงาน
		-- กันระหว่างผู้เล่น มันแค่ทำให้ของที่ซื้อมาใช้ไม่ได้ · เมืองหลักยังเป็นของเชฟเหมือนเดิม
		if spec.needs and not ServerConfig.IsFarm and not hasItem(player, spec.needs) then
			return Remotes.SocialNotify:FireClient(player, "warn", "ต้องมีตะหลิวเชฟ (เฉพาะอาชีพเชฟ)")
		end
		-- ...แต่แขกที่มาเยี่ยมใช้เครื่องครัวของเจ้าของไม่ได้ (ผู้ใช้สั่ง 2026-09-23)
		if not IslandAccess.MayUseFixtures(player) then
			return Remotes.SocialNotify:FireClient(player, "warn", IslandAccess.FixtureDenied)
		end
		if not CraftAccess.OpenAt then
			-- เดิมเงียบสนิทถ้า Crafting.server ยังไม่ได้เติมฟังก์ชันนี้ ซึ่งอ่านไม่ออกเลยว่าเกิดอะไรขึ้น
			warn("[Kitchen] CraftAccess.OpenAt ยังว่าง — Crafting.server ไม่ได้โหลดหรือโหลดไม่จบ")
			return Remotes.SocialNotify:FireClient(player, "error", "ระบบคราฟยังไม่พร้อม (OpenAt ว่าง)")
		end
		CraftAccess.OpenAt(player, spec.station, model)
	end)
end

local function wireStorage(model, spec)
	wired[model] = true
	model:SetAttribute("StorageSlots", spec.slots)
	model:SetAttribute("StorageAccepts", spec.accepts)
	model:SetAttribute("StorageClass", spec.class)
	model:SetAttribute("StorageAction", spec.action)
	model:SetAttribute("StorageName", spec.object)
	CollectionService:AddTag(model, "WOLD_StorageChest")
end

-- ฝั่งเซิร์ฟเวอร์มีทุกอย่างตั้งแต่บูต (StreamingEnabled เป็นเรื่องของไคลเอนต์) กวาด 380,000 ชิ้นจึงทำ
-- ครั้งแรกแล้วนานๆ ครั้ง ไม่ใช่ทุกครึ่งวิ
--
-- **ยกเว้นบนเกาะฟาร์มมิ่ง** ที่นั่นเตา/ตู้เย็น/ตู้ยาเป็นของที่ผู้เล่น **ซื้อมาวางเอง** ไม่ใช่ของที่ยืนอยู่
-- ตั้งแต่เซิร์ฟบูต — รอ 60 วินาทีหลังวางเตาถึงจะกดได้ อ่านเหมือนของพัง (เจอจริงตอนเทส 2026-09-22)
-- และเกาะเล็กกว่าแมพหลักหลายสิบเท่า (ไม่กี่พันชิ้น) กวาดถี่ๆ จึงถูกมาก
local ServerConfig = require(game.ServerScriptService.ServerConfig)
local SWEEP_SECONDS = ServerConfig.IsFarm and 1 or 60

task.spawn(function()
	while true do
		for _, d in ipairs(workspace:GetDescendants()) do
			if d:IsA("Model") and not wired[d] and (STATIONS[d.Name] or STORAGE[d.Name]) and not decorative(d) then
				local spec = STATIONS[d.Name]
				if spec and spec.farmOnly and not ServerConfig.IsFarm then spec = nil end
				if spec then wireStation(d, spec) end
				local store = STORAGE[d.Name]
				if store then wireStorage(d, store) end
			end
		end
		task.wait(SWEEP_SECONDS)
	end
end)
