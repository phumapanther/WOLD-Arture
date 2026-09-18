-- PremiumStore.server.lua: เพชร ร้านค้าพรีเมียม กาชา และแบทเทิลพาส — เจ้าของการตัดสินทั้งหมด
--
-- ไคลเอนต์ส่งแค่ "อยากทำอะไร" (ซื้อแถวไหน สุ่มตู้ไหน รับขั้นไหน) เซิร์ฟเวอร์ตรวจเพชร สุ่ม แจกของ แล้วส่งภาพ
-- ทั้งหน้ากลับไปทุกครั้ง ราคา/สระ/รางวัล อ่านจาก PremiumConfig ที่ไคลเอนต์ก็อ่านได้ จึงวาดหน้าได้เองก่อน
-- ที่ภาพจากเซิร์ฟเวอร์จะมาถึง
--
-- **โรบัคยังไม่เปิด** ProcessReceipt เขียนไว้แล้ว รอแค่ product id ใน PremiumConfig.Products
local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")

local ServerConfig = require(game.ServerScriptService.ServerConfig)
if ServerConfig.IsLobby then return end

local PremiumConfig = require(game.ReplicatedStorage.PremiumConfig)
local ItemCatalog = require(game.ReplicatedStorage.ItemCatalog)
local InventoryConfig = require(game.ReplicatedStorage.InventoryConfig)
local Remotes = require(game.ReplicatedStorage.Remotes)
local ProfileAccess = require(game.ServerScriptService.ProfileAccess)
local PremiumAccess = require(game.ServerScriptService.PremiumAccess)
local Inventory = require(game.ServerScriptService.Inventory)
local Vitals = require(game.ServerScriptService.Vitals)

local SILVER = "Silver"

--------------------------------------------------------------------------------
-- เพชร
--------------------------------------------------------------------------------

local function gemsOf(player)
	local data = ProfileAccess.Get(player)
	return data and (data.Gems or 0) or 0
end

local function addGems(player, n)
	local data = ProfileAccess.Get(player)
	if not data then return false end
	data.Gems = math.max(0, (data.Gems or 0) + n)
	return true
end

-- หักเพชร คืน true ถ้าพอ ไม่พอไม่หัก
local function spendGems(player, n)
	if gemsOf(player) < n then return false end
	return addGems(player, -n)
end

PremiumAccess.GetGems = gemsOf
PremiumAccess.AddGems = addGems

--------------------------------------------------------------------------------
-- แบทเทิลพาส
--------------------------------------------------------------------------------

local PASS = PremiumConfig.Pass

-- สถานะพาสของซีซันนี้ ซีซันเปลี่ยน = เริ่มใหม่ (ของเก่าที่รับแล้วก็รับไปแล้ว ไม่มีอะไรต้องคืน)
local function passOf(player)
	local data = ProfileAccess.Get(player)
	if not data then return nil end
	local bp = data.BattlePass
	if not bp or bp.season ~= PASS.season then
		bp = { season = PASS.season, xp = 0, premium = false, claimedFree = {}, claimedPremium = {} }
		data.BattlePass = bp
	end
	return bp
end

local function tierOf(bp)
	return math.min(PASS.tiers, math.floor((bp.xp or 0) / PASS.xpPerTier))
end

PremiumAccess.AddPassXp = function(player, exp)
	local bp = passOf(player)
	if not bp then return end
	local cap = PASS.tiers * PASS.xpPerTier
	if bp.xp >= cap then return end
	local before = tierOf(bp)
	bp.xp = math.min(cap, bp.xp + math.floor(exp * PASS.xpPerExp))
	if tierOf(bp) > before then
		Remotes.SocialNotify:FireClient(player, "info", ("แบทเทิลพาสถึงขั้น %d แล้ว — เปิดเมนูไปรับของ"):format(tierOf(bp)))
	end
end

--------------------------------------------------------------------------------
-- แจกของ (ใช้ร่วมกันทั้งร้าน กาชา และพาส)
--------------------------------------------------------------------------------

-- reward = { item, count } | { gold = n } | { gems = n } คืน true ถ้าลงกระเป๋าได้ครบ
local function give(player, reward)
	if reward.gold then Inventory.AddGold(player, reward.gold) return true end
	if reward.gems then addGems(player, reward.gems) return true end
	if reward.item then
		return Inventory.AddItem(player, reward.item, reward.count or 1) and true or false
	end
	return false
end

local function canHold(player, reward)
	if reward.gold or reward.gems then return true end
	return Inventory.HasRoomFor(player, reward.item, reward.count or 1)
end

local function rewardName(reward)
	if reward.gold then return ("เงิน %d"):format(reward.gold) end
	if reward.gems then return ("เพชร %d"):format(reward.gems) end
	local item = ItemCatalog.Get(reward.item)
	return ("%s x%d"):format(item and item.name or reward.item, reward.count or 1)
end

--------------------------------------------------------------------------------
-- ภาพที่ส่งให้ไคลเอนต์
--------------------------------------------------------------------------------

local function snapshot(player)
	local bp = passOf(player)
	return {
		gems = gemsOf(player),
		buffs = Vitals.BuffsLeft and Vitals.BuffsLeft(player) or {},
		robuxEnabled = next(PremiumConfig.Products) ~= nil,
		pass = bp and {
			season = bp.season,
			xp = bp.xp,
			tier = tierOf(bp),
			premium = bp.premium == true,
			claimedFree = bp.claimedFree,
			claimedPremium = bp.claimedPremium,
		} or nil,
	}
end

local function push(player, extra)
	local snap = snapshot(player)
	if extra then for k, v in pairs(extra) do snap[k] = v end end
	Remotes.PremiumUpdate:FireClient(player, snap)
end

--------------------------------------------------------------------------------
-- ร้านค้า
--------------------------------------------------------------------------------

local function buy(player, shopId)
	local row = PremiumConfig.ShopById(shopId)
	if not row then return end
	if not Inventory.HasRoomFor(player, row.item, row.count) then
		return Remotes.SocialNotify:FireClient(player, "error", "กระเป๋าเต็ม")
	end
	if not spendGems(player, row.price) then
		return Remotes.SocialNotify:FireClient(player, "error", ("เพชรไม่พอ (ต้องใช้ %d)"):format(row.price))
	end
	-- หักก่อนแจก: แจกไม่ได้ (ไม่น่าเกิด เช็คที่ว่างแล้ว) ก็คืนเพชร
	if not Inventory.AddItem(player, row.item, row.count) then
		addGems(player, row.price)
		return Remotes.SocialNotify:FireClient(player, "error", "ซื้อไม่สำเร็จ คืนเพชรแล้ว")
	end
	local item = ItemCatalog.Get(row.item)
	Remotes.SocialNotify:FireClient(player, "info", ("ซื้อ %s x%d แล้ว (-%d เพชร)"):format(item and item.name or row.item, row.count, row.price))
	push(player)
end

--------------------------------------------------------------------------------
-- กาชา
--------------------------------------------------------------------------------

-- สุ่มหนึ่งชิ้นจากสระตามน้ำหนัก rarity ของแต่ละไอเทม
local function roll(pool)
	local total = 0
	local weights = {}
	for i, id in ipairs(pool) do
		local item = ItemCatalog.Get(id)
		local r = item and PremiumConfig.Rarity[item.rarity or "common"] or PremiumConfig.Rarity.common
		weights[i] = r.weight
		total += r.weight
	end
	local pick = math.random() * total
	for i, id in ipairs(pool) do
		pick -= weights[i]
		if pick <= 0 then return id end
	end
	return pool[#pool]
end

local function pull(player, bannerId, times)
	local banner = PremiumConfig.GachaById(bannerId)
	if not banner then return end
	if #banner.pool == 0 then
		return Remotes.SocialNotify:FireClient(player, "warn", "ตู้นี้ยังไม่เปิด เร็วๆ นี้")
	end
	times = times == 10 and 10 or 1
	local cost = times == 10 and banner.cost10 or banner.cost

	-- ต้องมีช่องพอรับทุกชิ้นก่อน: สุ่มแล้วลงไม่ได้คือเสียเพชรฟรี ซึ่งเป็นสิ่งที่ห้ามเกิดที่สุดในระบบจ่ายเงิน
	-- สกินสแตคได้ 99 ออร่าชิ้นละช่อง — นับแบบเลวร้ายสุดว่าทุกชิ้นต้องใช้ช่องใหม่
	local state = Inventory.Get(player)
	if not state then return end
	local free = 0
	for i = 1, InventoryConfig.SlotCount do
		if state.slots[i] == nil then free += 1 end
	end
	if free < times then
		return Remotes.SocialNotify:FireClient(player, "error", ("ต้องมีช่องว่างอย่างน้อย %d ช่อง"):format(times))
	end
	if not spendGems(player, cost) then
		return Remotes.SocialNotify:FireClient(player, "error", ("เพชรไม่พอ (ต้องใช้ %d)"):format(cost))
	end

	local results = {}
	for _ = 1, times do
		local id = roll(banner.pool)
		local item = ItemCatalog.Get(id)
		if not Inventory.AddItem(player, id, 1) then
			-- ที่ว่างหมดกลางทาง (ไม่น่าเกิด) คืนเพชรตามสัดส่วนที่ยังไม่ได้ของ
			addGems(player, math.floor(cost * (times - #results) / times))
			break
		end
		results[#results + 1] = { id = id, name = item and item.name or id, icon = item and item.icon or "",
			rarity = item and item.rarity or "common" }
	end
	push(player, { gacha = { banner = bannerId, results = results } })
end

--------------------------------------------------------------------------------
-- แบทเทิลพาส: รับของ / ปลดพรีเมียม
--------------------------------------------------------------------------------

local function claim(player, tier, track)
	local bp = passOf(player)
	if not bp then return end
	tier = math.floor(tonumber(tier) or 0)
	if tier < 1 or tier > PASS.tiers or tier > tierOf(bp) then
		return Remotes.SocialNotify:FireClient(player, "warn", "ยังไปไม่ถึงขั้นนี้")
	end
	local premium = track == "premium"
	if premium and not bp.premium then
		return Remotes.SocialNotify:FireClient(player, "warn", "ต้องปลดสายพรีเมียมก่อน")
	end
	local claimed = premium and bp.claimedPremium or bp.claimedFree
	if claimed[tostring(tier)] then return end
	local reward = (premium and PASS.Premium or PASS.Free)[tier]
	if not reward then return end
	if not canHold(player, reward) then
		return Remotes.SocialNotify:FireClient(player, "error", "กระเป๋าเต็ม")
	end
	claimed[tostring(tier)] = true
	if not give(player, reward) then
		claimed[tostring(tier)] = nil
		return Remotes.SocialNotify:FireClient(player, "error", "รับของไม่สำเร็จ")
	end
	Remotes.SocialNotify:FireClient(player, "info", ("รับ %s (ขั้น %d)"):format(rewardName(reward), tier))
	push(player)
end

local function unlockPremium(player)
	local bp = passOf(player)
	if not bp or bp.premium then return end
	if not spendGems(player, PASS.premiumCost) then
		return Remotes.SocialNotify:FireClient(player, "error", ("เพชรไม่พอ (ต้องใช้ %d)"):format(PASS.premiumCost))
	end
	bp.premium = true
	Remotes.SocialNotify:FireClient(player, "info", "ปลดสายพรีเมียมแล้ว รับของย้อนหลังได้ทุกขั้นที่ผ่านมา")
	push(player)
end

--------------------------------------------------------------------------------
-- โรบัค → เพชร (พร้อมใช้เมื่อใส่ product id)
--------------------------------------------------------------------------------

MarketplaceService.ProcessReceipt = function(receipt)
	local gems = PremiumConfig.Products[receipt.ProductId]
	if not gems then return Enum.ProductPurchaseDecision.NotProcessedYet end
	local player = Players:GetPlayerByUserId(receipt.PlayerId)
	if not player then return Enum.ProductPurchaseDecision.NotProcessedYet end
	if not addGems(player, gems) then return Enum.ProductPurchaseDecision.NotProcessedYet end
	if ProfileAccess.Flush then ProfileAccess.Flush(player) end
	Remotes.SocialNotify:FireClient(player, "info", ("ได้รับเพชร %d"):format(gems))
	push(player)
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

local function buyGems(player, index)
	local pack = PremiumConfig.GemPacks[math.floor(tonumber(index) or 0)]
	if not pack or not pack.productId or not PremiumConfig.Products[pack.productId] then
		return Remotes.SocialNotify:FireClient(player, "warn", "ยังไม่เปิดขายเพชรด้วยโรบัค")
	end
	MarketplaceService:PromptProductPurchase(player, pack.productId)
end

--------------------------------------------------------------------------------
-- คำขอจากไคลเอนต์
--------------------------------------------------------------------------------

Remotes.RequestPremium.OnServerEvent:Connect(function(player, action, a, b)
	if action == "refresh" then push(player)
	elseif action == "buy" then buy(player, tostring(a))
	elseif action == "pull" then pull(player, tostring(a), tonumber(b))
	elseif action == "claim" then claim(player, a, tostring(b))
	elseif action == "unlockpass" then unlockPremium(player)
	elseif action == "buygems" then buyGems(player, a)
	end
end)
