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
local Vip = require(game.ServerScriptService.Vip)
local AdminRoster = require(game.ServerScriptService.AdminRoster)
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

-- **แอดมินมีเพชร 99,999 เสมอ** (ผู้ใช้สั่ง 2026-09-20)
--
-- เติมกลับให้เต็มหลังทุกการใช้จ่าย ไม่ใช่แจกครั้งเดียวตอนเข้าเกม — จุดประสงค์คือเทสของในร้านได้ไม่รู้จบ
-- ถ้าแจกครั้งเดียว วันที่ทดสอบกาชารัวๆ มันก็หมดอยู่ดีแล้วต้องมาพิมพ์ `/gems` ใหม่ทุกรอบ
--
-- **ตัวเลขนี้ไม่ใช่เพดานของคนทั่วไป** ใครไม่ใช่แอดมินไม่ถูกแตะเลยสักบรรทัด — และคนที่ถูกถอดจากแอดมิน
-- ก็แค่หยุดถูกเติม เพชรที่มีอยู่ไม่ถูกริบ (การริบของที่เคยให้ไปแล้วคือสิ่งที่ไม่มีใครอธิบายได้ตอนเกิดขึ้น)
local ADMIN_GEMS = 99999

local function topUpAdmin(player)
	if not AdminRoster.IsAdmin(player) then return end
	local data = ProfileAccess.Get(player)
	if not data then return end
	if (data.Gems or 0) >= ADMIN_GEMS then return end
	data.Gems = ADMIN_GEMS
end

-- หักเพชร คืน true ถ้าพอ ไม่พอไม่หัก
local function spendGems(player, n)
	if gemsOf(player) < n then return false end
	local ok = addGems(player, -n)
	-- เติมคืนหลังหัก ไม่ใช่ข้ามการหัก: ของที่ซื้อยังต้องเดินผ่านด่าน "เพชรพอไหม" เหมือนคนอื่นทุกประการ
	-- ทางที่ข้ามการหักไปเลยคือทางที่บั๊กเรื่องราคาจะไม่มีวันถูกเจอตอนเทส
	topUpAdmin(player)
	return ok
end

PremiumAccess.GetGems = gemsOf
PremiumAccess.AddGems = addGems
-- ร้านบนเกาะขายของตกแต่ง/สัตว์เลี้ยง/ของผิดกฎหมายด้วยเพชร (ผู้ใช้กำหนด 2026-09-22)
-- **ต้องผ่านตัวนี้ ไม่ใช่ AddGems ติดลบเอง** — ด่าน "พอไหม" กับการเติมคืนแอดมินอยู่ในนี้ที่เดียว
PremiumAccess.SpendGems = spendGems

--------------------------------------------------------------------------------
-- แบทเทิลพาส
--------------------------------------------------------------------------------

local PASS = PremiumConfig.Pass

-- สถานะพาสของซีซันนี้ ซีซันเปลี่ยน = เริ่มใหม่ (ของเก่าที่รับแล้วก็รับไปแล้ว ไม่มีอะไรต้องคืน)
-- **ซีซัน = เดือนไทย** (PremiumConfig.PassSeason · ผู้ใช้สั่ง 2026-09-27) — ถามใหม่ทุกครั้ง ข้ามเที่ยงคืนวันที่ 1 กลางเซสชัน
-- ก็เริ่มซีซันใหม่ให้เองตอนได้ XP/เปิดหน้าต่างครั้งถัดไป
local function passOf(player)
	local data = ProfileAccess.Get(player)
	if not data then return nil end
	local season = PremiumConfig.PassSeason(os.time())
	local bp = data.BattlePass
	if not bp or bp.season ~= season then
		bp = { season = season, xp = 0, premium = false, claimedFree = {}, claimedPremium = {} }
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

-- รางวัลหลายชิ้นในขั้นเดียว (ขั้นที่มีของประจำเดือน) · **ทั้งหมดหรือไม่เอาเลย**: ชิ้นหลังใส่ไม่ลง = ถอดชิ้นก่อนหน้าคืน
-- (HasRoomFor ถามทีละชิ้น ไม่รู้ว่าสองชิ้นรวมกันพอไหม — ลองให้จริงแล้วย้อนกลับถ้าพลาด)
local function giveAll(player, rewards)
	local given = {}
	for _, reward in ipairs(rewards) do
		if not give(player, reward) then
			for _, done in ipairs(given) do
				if done.item then Inventory.RemoveById(player, done.item, done.count or 1) end
			end
			return false
		end
		given[#given + 1] = reward
	end
	return true
end

--------------------------------------------------------------------------------
-- ภาพที่ส่งให้ไคลเอนต์
--------------------------------------------------------------------------------

local function snapshot(player)
	local bp = passOf(player)
	return {
		gems = gemsOf(player),
		-- วินาทีที่เหลือของ VIP (0 = ไม่ได้เป็น) หน้าร้านเอาไปโชว์บนปุ่มว่า "เหลือ n วัน"
		vipLeft = Vip.SecondsLeft(player),
		vipDays = PremiumConfig.Vip.days,
		vipPrice = PremiumConfig.Vip.price,
		buffs = Vitals.BuffsLeft and Vitals.BuffsLeft(player) or {},
		robuxEnabled = next(PremiumConfig.Products) ~= nil,
		pass = bp and {
			season = bp.season,
			endsAt = PremiumConfig.PassSeasonEnds(bp.season),
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

	-- **แถวที่จ่ายเป็นเงินในเกม** (ผู้ใช้สั่ง 2026-09-24) — ไม่กินช่องกระเป๋า จึงข้ามด่าน HasRoomFor
	-- ที่เหลือเดินทางเดียวกับของทั่วไปเป๊ะ: หักเพชรก่อน จ่ายทีหลัง จ่ายไม่ได้คืนเพชร
	if row.gold then
		if not spendGems(player, row.price) then
			return Remotes.SocialNotify:FireClient(player, "error", ("เพชรไม่พอ (ต้องใช้ %d)"):format(row.price))
		end
		if not Inventory.AddGold(player, row.gold) then
			addGems(player, row.price)
			return Remotes.SocialNotify:FireClient(player, "error", "แลกไม่สำเร็จ คืนเพชรแล้ว")
		end
		if ProfileAccess.Flush then ProfileAccess.Flush(player) end
		Remotes.SocialNotify:FireClient(player, "info",
			("ได้รับ %d เหรียญ (-%d เพชร)"):format(row.gold, row.price))
		return push(player)
	end

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

-- ซื้อ/ต่ออายุ VIP — ผู้ใช้กำหนดให้ขายด้วยเพชรในหน้าร้านนี้ (2026-09-20)
--
-- VIP ไม่ใช่ไอเทม จึงไม่ผ่าน `buy` ที่ต้องมีที่ว่างในกระเป๋า: มันคือเวลาที่เขียนลงโปรไฟล์
-- **หักเพชรก่อนแล้วค่อยเขียน** และถ้าเขียนไม่ได้ต้องคืนเพชร ทรงเดียวกับ `buy` เป๊ะ
local function buyVip(player)
	local vip = PremiumConfig.Vip
	if not spendGems(player, vip.price) then
		return Remotes.SocialNotify:FireClient(player, "error", ("เพชรไม่พอ (ต้องใช้ %d)"):format(vip.price))
	end
	local until_ = Vip.Grant(player, vip.days)
	if not until_ then
		addGems(player, vip.price)
		return Remotes.SocialNotify:FireClient(player, "error", "ซื้อไม่สำเร็จ คืนเพชรแล้ว")
	end
	if ProfileAccess.Flush then ProfileAccess.Flush(player) end
	local left = math.floor(Vip.SecondsLeft(player) / 86400 + 0.5)
	Remotes.SocialNotify:FireClient(player, "info",
		("เป็น VIP แล้ว เหลือ %d วัน (-%d เพชร)"):format(left, vip.price))
	push(player)
end

--------------------------------------------------------------------------------
-- กาชา
--------------------------------------------------------------------------------

-- สุ่มหนึ่งชิ้นจากสระตามน้ำหนัก rarity ของแต่ละไอเทม
-- `uniform` = ทุกชิ้นโอกาสเท่ากัน ใช้กับตู้ที่มีเพดานรายชิ้น (ถ่วงน้ำหนักแล้วเพดานจะแตก)
local function roll(pool, uniform)
	if #pool == 0 then return nil end
	if uniform then return pool[math.random(1, #pool)] end
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

	-- **ตัวนับการันตีอยู่ในโปรไฟล์ ไม่ใช่ตัวแปรในลูป** — ผู้ใช้กำหนดว่า "สุ่ม 10 ครั้งได้ของหลัก 1 ชิ้น"
	-- ถ้านับเฉพาะในชุด 10 ครั้ง คนกดเดี่ยว 10 ครั้งจะไม่ได้การันตีเลย ทั้งที่จ่ายแพงกว่าด้วยซ้ำ
	-- ตัวนับสะสมข้ามการกดและข้ามเซสชัน รีเซ็ตทุกครั้งที่ออกของหลัก
	local data = ProfileAccess.Get(player)
	local pity = data and data.GachaPity or nil
	if data and not pity then pity = {}; data.GachaPity = pity end
	local filler = PremiumConfig.GachaFiller(ItemCatalog)

	local results = {}
	for _ = 1, times do
		-- ของหลักออก 10% หรือออกแน่นอนเมื่อพลาดติดกันครบเพดาน
		-- ตู้ที่ตั้ง `pity = false` ไม่มีการันตี (ตู้รวม) — ตัวนับไม่ถูกใช้และไม่ถูกเขียนด้วย
		local usePity = banner.pity ~= false
		local miss = (pity and pity[bannerId] or 0)
		local jackpot = math.random() < PremiumConfig.JackpotChance(banner)
			or (usePity and miss + 1 >= PremiumConfig.GachaPity)
		if pity and usePity then pity[bannerId] = jackpot and 0 or (miss + 1) end
		local id = roll(jackpot and banner.pool or filler, jackpot and banner.uniform or false)
		if not id then break end
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
	-- ของประจำขั้น + ของประจำเดือน (สายพรีเมียมขั้น 15/30) — ซีซันของตัวพาส ไม่ใช่เดือนตอนนี้ (กันเส้นเที่ยงคืนวันที่ 1)
	local rewards = PremiumConfig.PassRewards(bp.season, premium and "premium" or "free", tier)
	if #rewards == 0 then return end
	for _, reward in ipairs(rewards) do
		if not canHold(player, reward) then
			return Remotes.SocialNotify:FireClient(player, "error", "กระเป๋าเต็ม")
		end
	end
	claimed[tostring(tier)] = true
	if not giveAll(player, rewards) then
		claimed[tostring(tier)] = nil
		return Remotes.SocialNotify:FireClient(player, "error", "กระเป๋าเต็ม — รับของไม่สำเร็จ")
	end
	local names = {}
	for _, reward in ipairs(rewards) do names[#names + 1] = rewardName(reward) end
	-- สองชิ้น (ขั้นของประจำเดือน) = แม่แบบของตัวเอง ไคลเอนต์ย้อนแปลงทีละชื่อได้ · ข้อความไทยเท่าเดิมทุกไบต์
	local text = #names == 2 and ("รับ %s + %s (ขั้น %d)"):format(names[1], names[2], tier)
		or ("รับ %s (ขั้น %d)"):format(table.concat(names, " + "), tier)
	Remotes.SocialNotify:FireClient(player, "info", text)
	push(player)
end

-- ของขวัญหุ่นฟาง (บัญชีใหม่ · ผู้ใช้สั่ง 2026-09-28): ปลดสายพรีเมียมของเดือนนี้ฟรี ไม่หักเพชร
PremiumAccess.HasPremiumPass = function(player)
	local bp = passOf(player)
	return bp ~= nil and bp.premium == true
end
PremiumAccess.GrantPremiumPass = function(player)
	local bp = passOf(player)
	if not bp then return false, "loading" end
	if bp.premium then return false, "owned" end
	bp.premium = true
	push(player)
	return true
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

-- เติมให้ตอนเข้าเกม (โปรไฟล์อาจโหลดช้ากว่าการเข้า จึงลองซ้ำอีกหน่อยแทนที่จะยิงครั้งเดียวแล้วแล้วกัน)
-- และเติมอีกทีทุกครั้งที่เปิดหน้าร้าน เผื่อเพิ่งได้สิทธิ์แอดมินระหว่างเล่น
Players.PlayerAdded:Connect(function(player)
	task.spawn(function()
		for _ = 1, 20 do
			if not player.Parent then return end
			if ProfileAccess.Get(player) then
				topUpAdmin(player)
				push(player)
				return
			end
			task.wait(1)
		end
	end)
end)

Remotes.RequestPremium.OnServerEvent:Connect(function(player, action, a, b)
	topUpAdmin(player)
	if action == "refresh" then push(player)
	elseif action == "buy" then buy(player, tostring(a))
	elseif action == "pull" then pull(player, tostring(a), tonumber(b))
	elseif action == "claim" then claim(player, a, tostring(b))
	elseif action == "unlockpass" then unlockPremium(player)
	elseif action == "buygems" then buyGems(player, a)
	elseif action == "buyvip" then buyVip(player)
	end
end)
