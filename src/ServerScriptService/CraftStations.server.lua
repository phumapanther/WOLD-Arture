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
if ServerConfig.IsLobby then return end

local Inventory = require(game.ServerScriptService.Inventory)
local CraftAccess = require(game.ServerScriptService.CraftAccess)
local Remotes = require(game.ReplicatedStorage.Remotes)

local RANGE = 10

-- ชื่อโมเดล → การตั้งค่า
local STATIONS = {
	Stove = { station = "stove", action = "ทำอาหาร", object = "เตาทำอาหาร", needs = "Spatula", fire = true },
	SteamBlender = { station = "blender", action = "ปั่นเครื่องดื่ม", object = "เครื่องปั่นไอน้ำ", needs = "Spatula" },
	AlchemyStill = { station = "still", action = "ต้มยา", object = "เครื่องต้มยา" },
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

local function hasItem(player, id)
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
		if spec.needs and not hasItem(player, spec.needs) then
			return Remotes.SocialNotify:FireClient(player, "warn", "ต้องมีตะหลิวเชฟ (เฉพาะอาชีพเชฟ)")
		end
		if CraftAccess.OpenAt then CraftAccess.OpenAt(player, spec.station, model) end
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
task.spawn(function()
	while true do
		for _, d in ipairs(workspace:GetDescendants()) do
			if d:IsA("Model") and not wired[d] and (STATIONS[d.Name] or STORAGE[d.Name]) and not decorative(d) then
				local spec = STATIONS[d.Name]
				if spec then wireStation(d, spec) end
				local store = STORAGE[d.Name]
				if store then wireStorage(d, store) end
			end
		end
		task.wait(60)
	end
end)
