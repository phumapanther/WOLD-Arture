-- TownBuyers.server.lua: พ่อค้าประจำเมือง — รับซื้อเฉพาะของที่เมืองนั้นมี
--
-- สามอย่างที่ทำให้เขาต่างจากบาร์นาบี:
--   1. รับซื้อเฉพาะของประจำถิ่น (เมืองเหมืองรับแร่ เมืองประมงรับปลา) ไม่ใช่ทุกอย่าง
--   2. คนในแคลนที่ยึดเมืองนั้นได้ราคาดีกว่า
--   3. ทุกการขายหักภาษีเข้าคลังแคลนที่ยึดเมืองอยู่ เป็นเหรียญซิลเวอร์
--
-- **ราคายังคิดผ่าน buyPrice ของร้านปกติไม่ได้** เพราะมันอยู่ในไฟล์ร้าน เป็น local — จึงคิดจาก
-- `value` ในแคตตาล็อกโดยตรงด้วยสูตรเดียวกัน แล้วบวกโบนัสทับ
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")

local ServerConfig = require(game.ServerScriptService.ServerConfig)
if ServerConfig.IsLobby then return end

local ClanConfig = require(game.ReplicatedStorage.ClanConfig)
local ClanAccess = require(game.ServerScriptService.ClanAccess)
local TownAccess = require(game.ServerScriptService.TownAccess)
local Inventory = require(game.ServerScriptService.Inventory)
local ItemCatalog = require(game.ReplicatedStorage.ItemCatalog)
local ShopConfig = require(game.ReplicatedStorage.ShopConfig)
local Remotes = require(game.ReplicatedStorage.Remotes)

local BUYER_PREFIX = "Buyer_"
local RANGE = 12
local SILVER = "Silver"

--------------------------------------------------------------------------------
-- ใครรับซื้ออะไร
--------------------------------------------------------------------------------

-- ของที่แต่ละเมืองรับซื้อ ตรงกับธีมของเมืองและกับคลังงานของบอร์ดเควสที่นั่น
--
-- **รับเฉพาะรายการนี้** ของนอกรายการขายที่นี่ไม่ได้ ต้องเอาไปขายบาร์นาบี — นั่นคือสิ่งที่ทำให้พ่อค้า
-- ประจำเมืองมีความหมาย ถ้ารับซื้อทุกอย่างก็เป็นแค่บาร์นาบีอีกหกคน
local ACCEPTS = {
	Goldmeadow = { "Wheat", "Vegetable", "Milk", "Egg", "Wool", "Meat", "Leather", "Apple" },
	Stonemark = { "IronOre", "Coal", "Stone", "SilverOre", "GoldOre", "Diamond", "Crystal" },
	Saltmere = { "Fish", "Crab", "Shell", "Shrimp", "Squid", "Pufferfish", "Shark", "Anglerfish",
		"GreenSnakehead", "TigerBarb", "MilkFish", "SilverSalmon", "RainbowFish",
		"LargemouthBass", "Sturgeon", "Tanker", "SwordFish" },
	Elderwood = { "WoodScrap", "Herb", "Apple", "Leather", "Claw", "Bone" },
	Cogsworth = { "GearSpare", "Chemical", "Coal", "Blueprint", "IronOre", "Silver" },
	Astravale = { "MagicOre", "MagicBranch", "RuneStone", "Crystal", "Diamond" },
}

local function acceptsItem(townId, id)
	local list = ACCEPTS[townId]
	if not list then return false end
	for _, want in ipairs(list) do
		if want == id then return true end
	end
	return false
end

--------------------------------------------------------------------------------
-- ราคา
--------------------------------------------------------------------------------

-- ราคาต่อชิ้น คืน ราคา, โบนัสไหม
local function priceFor(player, townId, id, meta)
	if not acceptsItem(townId, id) then return nil end
	local item = ItemCatalog.Get(id)
	if not item or not ItemCatalog.IsSellable(id) then return nil end

	local base = (item.value or 0) * ShopConfig.BuyFraction
	-- ปลาตัวใหญ่แพงกว่า เหมือนที่ร้านปกติคิด — น้ำหนักติดมากับ meta
	if meta and meta.kg then
		base = base * (1 + meta.kg / 50)
	end

	local home = TownAccess.IsHome and TownAccess.IsHome(player, townId) or false
	if home then
		base = base * (1 + ClanConfig.HomeSellBonus)
	end

	return math.max(1, math.floor(base + 0.5)), home
end

--------------------------------------------------------------------------------
-- ภาพที่ส่งให้ไคลเอนต์
--------------------------------------------------------------------------------

local function snapshot(player, townId)
	local state = Inventory.Get(player)
	local rows = {}
	if state then
		for index, slot in pairs(state.slots) do
			local price = priceFor(player, townId, slot.id, slot.meta)
			if price then
				local item = ItemCatalog.Get(slot.id)
				rows[#rows + 1] = {
					index = index, id = slot.id, count = slot.count or 1,
					name = ItemCatalog.DisplayName(slot.id, slot.meta) or slot.id,
					icon = item and item.icon or "",
					price = price,
				}
			end
		end
	end
	table.sort(rows, function(a, b) return a.index < b.index end)

	local ownerId, ownerName = TownAccess.OwnerOf(townId)
	return {
		townId = townId,
		townName = (function()
			for _, t in ipairs(TownAccess.Towns or {}) do
				if t.id == townId then return t.name end
			end
			return townId
		end)(),
		owner = ownerName,
		isHome = TownAccess.IsHome and TownAccess.IsHome(player, townId) or false,
		bonus = ClanConfig.HomeSellBonus,
		tax = ClanConfig.TaxFraction,
		rows = rows,
	}
end

--------------------------------------------------------------------------------
-- ขาย
--------------------------------------------------------------------------------

local Viewing = {} -- [player] = townId

local function sell(player, index, amount)
	local townId = Viewing[player]
	if not townId then return end
	local state = Inventory.Get(player)
	local slot = state and state.slots[index]
	if not slot then return end

	local price, home = priceFor(player, townId, slot.id, slot.meta)
	if not price then
		return Remotes.SocialNotify:FireClient(player, "error", "พ่อค้าเมืองนี้ไม่รับซื้อของชิ้นนี้")
	end

	local held = slot.count or 1
	local count = held
	if type(amount) == "number" then count = math.clamp(math.floor(amount), 1, held) end

	local total = price * count

	-- **เอาของออกก่อนจ่ายเงิน** ฝั่งที่ล้มเหลวได้ต้องไปก่อน — ช่องถูกลบได้เสมอ ส่วนการจ่ายเงินไม่ล้มเหลว
	-- (กฎเดียวกับที่ร้านปกติเขียนไว้)
	Inventory.RemoveFromSlot(player, index, count)
	Inventory.AddGold(player, total)

	-- ภาษีเข้าคลังแคลนที่ยึดเมืองนี้อยู่ เป็นเหรียญซิลเวอร์
	--
	-- **หักจากยอดขาย ไม่ได้หักจากเงินผู้เล่น** ผู้เล่นได้เต็มจำนวน ส่วนภาษีเป็นเงินที่ "เกิดขึ้นใหม่"
	-- เข้าคลังแคลน — ถ้าหักจากผู้เล่น การขายในเมืองที่มีเจ้าของจะแย่กว่าขายที่อื่นเสมอ และไม่มีใครมาขาย
	local ownerId = TownAccess.OwnerOf(townId)
	local taxed = 0
	if ownerId and ClanAccess.AddSilver then
		taxed = math.floor(total * ClanConfig.TaxFraction)
		if taxed > 0 then ClanAccess.AddSilver(ownerId, taxed) end
	end

	local item = ItemCatalog.Get(slot.id)
	local name = item and item.name or slot.id
	local note = ("ขาย %s x%d ได้ %d เหรียญ"):format(name, count, total)
	if home then note = note .. (" (+%d%% คนในแคลน)"):format(math.floor(ClanConfig.HomeSellBonus * 100)) end
	if taxed > 0 then note = note .. (" · ภาษี %d ซิลเวอร์เข้าคลังแคลน"):format(taxed) end
	Remotes.SocialNotify:FireClient(player, "info", note)

	Remotes.TownBuyerUpdate:FireClient(player, snapshot(player, townId))
end

--------------------------------------------------------------------------------
-- ปุ่มที่ NPC
--------------------------------------------------------------------------------

local wired = {}

local function wire(npc, townId)
	if wired[npc] or not npc.Parent then return end

	-- HumanoidRootPart ก่อน ไม่ใช่ PrimaryPart — โมเดลชุดคิทวาง PrimaryPart ไว้ที่เท้า
	local anchor = npc:FindFirstChild("HumanoidRootPart")
		or npc:FindFirstChild("UpperTorso")
		or npc.PrimaryPart
		or npc:FindFirstChildWhichIsA("BasePart", true)
	if not anchor then return end
	if anchor:FindFirstChild("BuyerPrompt") then return end
	wired[npc] = true

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "BuyerPrompt"
	prompt.ActionText = "ขายของ"
	prompt.ObjectText = "พ่อค้าประจำเมือง"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.MaxActivationDistance = RANGE
	prompt.RequiresLineOfSight = false
	prompt.HoldDuration = 0
	prompt.Parent = anchor

	prompt.Triggered:Connect(function(player)
		Viewing[player] = townId
		Remotes.TownBuyerUpdate:FireClient(player, snapshot(player, townId))
	end)

	-- ป้ายชื่อของชุดคิทที่เห็นได้ทั้งแมพ ลบทิ้งแบบเดียวกับ NPC อื่น
	for _, g in ipairs(npc:GetDescendants()) do
		if g:IsA("BillboardGui") and g.Name == "NameTag" then
			g.MaxDistance = 40
		end
	end
end

task.spawn(function()
	while true do
		for _, t in ipairs(TownAccess.Towns or {}) do
			local npc = workspace:FindFirstChild(BUYER_PREFIX .. t.id, true)
			if npc and npc:IsA("Model") then wire(npc, t.id) end
		end
		task.wait(0.5)
	end
end)

--------------------------------------------------------------------------------
-- คำขอจากไคลเอนต์
--------------------------------------------------------------------------------

Remotes.RequestTownSell.OnServerEvent:Connect(function(player, action, index, amount)
	if action == "sell" then
		sell(player, math.floor(tonumber(index) or 0), amount)
	elseif action == "refresh" then
		local townId = Viewing[player]
		if townId then
			Remotes.TownBuyerUpdate:FireClient(player, snapshot(player, townId))
		end
	elseif action == "close" then
		Viewing[player] = nil
	end
end)

Players.PlayerRemoving:Connect(function(player)
	Viewing[player] = nil
end)
