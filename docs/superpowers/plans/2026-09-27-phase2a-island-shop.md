# เฟส 2a · ร้านเกาะ 2 ราคา + 5 หมวด — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Every item in the island shop and every pen animal can be bought with gems or with coins (1 gem = 250 coins). The island shop is split into 5 tabs.

**Architecture:** The pricing rule lives in `ShopConfig` as pure functions (`PricesOf`, `PriceFor`, `GemsFor`). Rows declare one or both prices plus a `category`, and the other price is derived. The server (`Shop.server`, `IslandZones.server`) asks those functions for the price in the currency the client picked. `ShopGui` draws a tab bar and two buy buttons per row. The pen window draws two buttons per animal. The main-game shop rows keep `price` and stay coin-only, with an unchanged look.

**Tech Stack:** Roblox Luau · Edit-mode tests that load fresh clones of the modules (`node tools/lua.js <test> Edit`).

**Spec:** `docs/superpowers/specs/2026-09-26-v1.5-roadmap-design.md` (section "เฟส 2a")

## Global Constraints
- **1 gem = 250 coins.** Gems round up, minimum 1: `max(1, ceil(coins / 250))`. Coins from gems = `gems × 250`.
- Tabs, in this order: บ้าน · ของตกแต่ง · ของใช้ · สัตว์ · เพาะปลูก. Every island row must have a category (a test checks this).
- **Nothing sold in the island shop can be mailed, seeds included** (user decision 2026-09-27).
- **Two buy buttons on every row** (💎 and 💰). This applies to the island shop and to the pen window (user decision 2026-09-27).
- The main-game shop (`ShopConfig.Sells`, Barnaby) is unchanged: coins only, one button, no tabs.
- Never press Play. Commit messages end with `Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>`.
- Coins use the 💰 emoji, not 🪙: 💰 already renders in-game (quest badge), while 🪙 is newer and may draw as an empty box.

## Review Focus
- A client sends `currency = "gems"` for a main-game shop row, or a junk currency string. Expected: the request is refused and nothing is charged.
- The shop redraws after every purchase. Expected: the chosen tab stays selected and does not jump back to the first one.
- A phone at 667x375 (panel 0.95 of the screen). Expected: the 5 tabs and the row's two buttons plus the amount box fit, with truncated names rather than overlap.
- A gem pen purchase where `SpendGems` fails after the animals spawned. Expected: the animals are removed and nothing is charged.
- The seed row (3 per press). Expected: 💎 1 / 💰 250 per press, and the amount box buys N presses.

---

### Task 1: Two-price rules, categories, mail rule

**Files:**
- Modify: `src/ReplicatedStorage/ShopConfig.lua` (rewrite `IslandSells`, add the functions after it)
- Modify: `src/ReplicatedStorage/ItemCatalog.lua:879-881` (GemBought loop)
- Create: `tests/island_shop_prices_test.lua`
- Modify (price reads only): `tests/farm_tuning_test.lua:94-98`, `tests/island_pets_test.lua:40-56`, `tests/island_decor_test.lua:28`, `tests/island_tuning_test.lua:134-137`

**Interfaces:**
- Produces: `ShopConfig.GemRate = 250` · `ShopConfig.IslandCategories = { {id, label} ×5 }` · `ShopConfig.GemsFor(coins) -> integer` ·
  `ShopConfig.PricesOf(row) -> coins, gems` (gems nil for main-game rows) · `ShopConfig.PriceFor(row, currency) -> number|nil`
  (`currency` "gems" or anything else = coins).
- Island rows: `{ id, category, coins = N }` / `{ id, category, gems = N }` / both · `count` unchanged.

- [ ] **Step 1: Write the failing test** `tests/island_shop_prices_test.lua`:

```lua
-- node tools/lua.js tests/island_shop_prices_test.lua Edit
-- เฟส 2a (ผู้ใช้กำหนด 2026-09-26/27): ร้านเกาะทุกชิ้นสองราคา 1 เพชร = 250 เหรียญ ปัดขึ้น ขั้นต่ำ 1 · 5 หมวด ·
-- ของร้านเกาะส่งเมลไม่ได้ทั้งร้านรวมเมล็ด
-- โคลนทั้งชุดลงโฟลเดอร์ชั่วคราว: ItemCatalog require พี่น้องด้วย script.Parent ถ้าโคลนตัวเดียว มันจะได้ ShopConfig
-- ตัวที่ Edit แคชไว้ (ของเก่า) แทนตัวที่เพิ่งดันขึ้น
local RS = game.ReplicatedStorage
local temp = Instance.new("Folder")
temp.Name = "PriceTest_" .. math.random(1, 1e9)
temp.Parent = RS
for _, name in ipairs({ "CraftConfig", "ShopConfig", "MailConfig", "PremiumConfig", "ItemCatalog" }) do
	RS[name]:Clone().Parent = temp
end
local okLoad, err = pcall(function()
	return require(temp.ShopConfig), require(temp.ItemCatalog)
end)
local ShopConfig, ItemCatalog
if okLoad then ShopConfig, ItemCatalog = require(temp.ShopConfig), require(temp.ItemCatalog) end
local out, fails = {}, 0
local function check(ok, text)
	out[#out + 1] = (ok and "ok   " or "FAIL ") .. text
	if not ok then fails += 1 end
end
check(okLoad, "โหลดโมดูล " .. tostring(err or ""))
if okLoad then
	check(ShopConfig.GemRate == 250, "1 เพชร = 250 เหรียญ")
	check(type(ShopConfig.PricesOf) == "function" and type(ShopConfig.PriceFor) == "function"
		and type(ShopConfig.GemsFor) == "function", "มีฟังก์ชันราคา")
	local cats, seen = {}, {}
	for _, c in ipairs(ShopConfig.IslandCategories or {}) do cats[c.id] = 0 end
	check(#(ShopConfig.IslandCategories or {}) == 5, "5 หมวด")
	if ShopConfig.PricesOf then
		local byId, plotRows = {}, 0
		for _, row in ipairs(ShopConfig.IslandSells) do
			local coins, gems = ShopConfig.PricesOf(row)
			check(cats[row.category] ~= nil, row.id .. " มีหมวด (" .. tostring(row.category) .. ")")
			if cats[row.category] then cats[row.category] += 1 end
			check(type(coins) == "number" and coins > 0 and coins % 1 == 0, row.id .. " มีราคาเหรียญ")
			check(type(gems) == "number" and gems >= 1 and gems % 1 == 0, row.id .. " มีราคาเพชร")
			if row.coins and not row.gems then check(gems == math.max(1, math.ceil(row.coins / 250)), row.id .. " เพชรปัดขึ้น") end
			if row.gems and not row.coins then check(coins == row.gems * 250, row.id .. " เหรียญ = เพชร x250") end
			check(row.price == nil and row.currency == nil, row.id .. " ไม่ใช้ price/currency แบบเก่า")
			if row.id == "FarmPlot" then plotRows += 1 end
			byId[row.id] = { coins, gems }
			seen[row.id] = true
		end
		for id, n in pairs(cats) do check(n > 0, "หมวด " .. id .. " มีของ") end
		check(plotRows == 1, "แปลงดินแถวเดียว (สองราคาในแถวเดียว)")
		local function is(id, coins, gems)
			local p = byId[id]
			check(p and p[1] == coins and p[2] == gems,
				("%s = 💰%d / 💎%d (ได้ %s)"):format(id, coins, gems, p and (p[1] .. "/" .. p[2]) or "ไม่มี"))
		end
		is("Seed", 250, 1)
		is("FarmPlot", 10000, 40)
		is("Wild_DiamondOre", 62500, 250)
		is("House_StoneCottage", 20000, 80)
		is("AnimalPen", 15000, 60)
		is("MineZone", 30000, 120)
		is("Pet_Cat", 62500, 250)
		check(ShopConfig.GemsFor(400) == 2 and ShopConfig.GemsFor(3000) == 12 and ShopConfig.GemsFor(1) == 1,
			"สัตว์คอก 400 = 2 เพชร · 3000 = 12 · 1 = 1")
		local main = ShopConfig.Sells[1]
		local c, g = ShopConfig.PricesOf(main)
		check(c == main.price and g == nil, "ร้านเกมหลักยังเหรียญอย่างเดียว")
		check(ShopConfig.PriceFor(main, "gems") == nil, "ขอเพชรกับแถวร้านเกมหลัก = ไม่มีราคา")
		check(ShopConfig.PriceFor(main, "coins") == main.price and ShopConfig.PriceFor(main, nil) == main.price,
			"ขอเหรียญ/ไม่ระบุ = ราคาเดิม")
		check(ShopConfig.PriceFor({ id = "X", coins = 500 }, "gems") == 2, "PriceFor เพชรคำนวณให้")
		for id in pairs(seen) do
			check(ItemCatalog.IsMailable(id) == false, id .. " ส่งเมลไม่ได้")
		end
		check(ItemCatalog.IsMailable("Stone") == true, "วัตถุดิบทั่วไปยังส่งได้")
	end
end
temp:Destroy()
return (fails == 0 and "PASS\n" or ("FAIL x%d\n"):format(fails)) .. table.concat(out, "\n")
```

- [ ] **Step 2: Run it.** `WOLD_PLACE=136992335889132 node tools/lua.js tests/island_shop_prices_test.lua Edit`. Expected: FAIL (no `GemRate`/`PricesOf`, rows have no category, Seed/House still mailable).
- [ ] **Step 3: Rewrite `ShopConfig.IslandSells`**, grouped in tab order. Keep every current price in the currency it has now. Keep the existing Thai comments that explain the numbers:

```lua
ShopConfig.IslandSells = {
	-- บ้าน (เหรียญเดิม)
	{ id = "House_StoneCottage", category = "house", coins = 20000 },
	{ id = "House_Roundhouse", category = "house", coins = 25000 },
	{ id = "House_Longhouse", category = "house", coins = 30000 },
	{ id = "House_PipeWorker", category = "house", coins = 40000 },
	{ id = "House_Townhouse", category = "house", coins = 50000 },
	-- ของตกแต่ง + ของป่า (เพชรเดิม)
	{ id = "Deco_PathTile", category = "decor", gems = 2 },
	-- ... every Deco_* and Wild_* row, same gem values as today
	-- ของใช้: เฟอร์นิเจอร์ใช้งานได้จริง + ของผิดกฎหมาย (เพชรเดิม)
	{ id = "IceBox", category = "utility", gems = 120 },
	-- ... ApothecaryCabinet 120 · Stove 180 · SteamBlender 220 · AlchemyStill 220 · Boxs 400 · DistillSet 500 · Reactor 500
	-- สัตว์
	{ id = "Pet_Cat", category = "animal", gems = 250 },
	{ id = "Pet_Dog", category = "animal", gems = 250 },
	{ id = "AnimalPen", category = "animal", coins = 15000 },
	-- เพาะปลูก
	{ id = "FarmPlot", category = "farm", gems = 40, coins = 10000 }, -- สองราคากำหนดเอง (40 x 250 = 10,000 พอดี)
	{ id = "Seed", category = "farm", coins = 250, count = 3 },
	{ id = "MineZone", category = "farm", coins = 30000 },
}
```

Then add after the table:

```lua
-- เฟส 2a (ผู้ใช้กำหนด 2026-09-26): ร้านเกาะทุกชิ้นสองราคา · 1 เพชร = 250 เหรียญ · เพชรปัดขึ้น ขั้นต่ำ 1
-- แถวเขียนราคาสกุลเดียวก็พอ อีกสกุลคำนวณที่นี่ที่เดียว (สัตว์ในคอกก็ใช้ GemsFor ตัวเดียวกัน)
ShopConfig.GemRate = 250
ShopConfig.IslandCategories = {
	{ id = "house", label = "บ้าน" },
	{ id = "decor", label = "ของตกแต่ง" },
	{ id = "utility", label = "ของใช้" },
	{ id = "animal", label = "สัตว์" },
	{ id = "farm", label = "เพาะปลูก" },
}

function ShopConfig.GemsFor(coins)
	return math.max(1, math.ceil(coins / ShopConfig.GemRate))
end

-- ราคาสองสกุลของแถวร้าน · แถวร้านเกมหลัก (`price`) = เหรียญอย่างเดียว เพชรเป็น nil
function ShopConfig.PricesOf(row)
	if row.price then return row.price, nil end
	local coins = row.coins or (row.gems and row.gems * ShopConfig.GemRate)
	local gems = row.gems or (row.coins and ShopConfig.GemsFor(row.coins))
	return coins, gems
end

-- ราคาในสกุลที่ขอ · nil = แถวนี้ขายสกุลนั้นไม่ได้ · "gems" = เพชร อย่างอื่น/ไม่ระบุ = เหรียญ
function ShopConfig.PriceFor(row, currency)
	local coins, gems = ShopConfig.PricesOf(row)
	if currency == "gems" then return gems end
	return coins
end
```

- [ ] **Step 4: ItemCatalog GemBought.** Replace the loop at `:879-881`:

```lua
for _, row in ipairs(ShopConfig.IslandSells or {}) do
	-- เฟส 2a: ทุกแถวในร้านเกาะซื้อด้วยเพชรได้ จึงส่งเมลไม่ได้ทั้งร้าน รวมเมล็ด (ผู้ใช้เลือก 2026-09-27)
	if select(2, ShopConfig.PricesOf(row)) then GemBought[row.id] = true end
end
```

- [ ] **Step 5: Update the old tests' price reads** to `ShopConfig.PricesOf(row)` (coins = first value):
  - `farm_tuning_test.lua:94-98`: `price[row.id] = (ShopConfig.PricesOf(row))`. The assertions stay as they are (AnimalPen 15000, MineZone 30000, FarmPlot 10000).
  - `island_pets_test.lua:40-56`: replace the gem/gold row count with "every row has both prices", `plotRows == 1`,
    Pet_Cat/Deco_Rock/Reactor/Stove carry `row.gems`, Seed/House_StoneCottage carry `row.coins`.
  - `island_decor_test.lua:28`: `inShop[row.id] = true`.
  - `island_tuning_test.lua:134-137`: `price[row.id] = price[row.id] or (ShopConfig.PricesOf(row))`.
- [ ] **Step 6: Run** the new test and `farm_tuning_test.lua` + `mail_config_test.lua` on the farming place (Edit). Expected: `PASS` for all three.
  The Play-only island tests get a syntax check (`node tools/syntax.js`), which should report OK.
- [ ] **Step 7: Commit** `"Island shop: two prices per row (1 gem = 250 coins), 5 categories; island items unmailable"`.

### Task 2: Shop server pays in the chosen currency

**Files:**
- Modify: `src/ServerScriptService/Shop.server.lua` (snapshot `:177-191,209-214` · buy `:239,251-314`)

**Interfaces:**
- Consumes: `ShopConfig.PricesOf/PriceFor/IslandCategories` (Task 1).
- Produces: snapshot `sells[i] = { index, id, name, icon, coins, gems, category, count }` (gems/category nil in the main game) ·
  snapshot `categories` (island only) · snapshot `gems` = the player's gem purse (island only) ·
  `RequestShopAction("buy", index, amount, currency)`. `currency` is "gems" or "coins", and nil means coins.

- [ ] **Step 1:** Snapshot rows: `local coins, gems = ShopConfig.PricesOf(entry)`. Send `coins = coins, gems = gems, category = entry.category`, and drop `price`/`currency`.
  When `SELLS == ShopConfig.IslandSells`, add `categories = ShopConfig.IslandCategories` and `gems = PremiumAccess.GetGems and PremiumAccess.GetGems(player) or 0` to the returned table.
- [ ] **Step 2:** Buy. Change the handler signature to `(player, action, index, amount, currency)`. Validate at the top of the buy branch:

```lua
if currency ~= nil and currency ~= "gems" and currency ~= "coins" then return end
local unitPrice = ShopConfig.PriceFor(entry, currency)
if not unitPrice then
	return Remotes.SocialNotify:FireClient(player, "error", "ของชิ้นนี้ซื้อด้วยสกุลนี้ไม่ได้")
end
local gems = currency == "gems"
```

  Then replace every `entry.price` in the branch with `unitPrice` (affordable, SpendGems amount, AddGold, notify text).
  The notify unit becomes `gems and " เพชร" or " เหรียญ"`.
- [ ] **Step 3:** Syntax check `Shop.server.lua` (farming place). Expected: OK. Run `island_shop_prices_test` again. Expected: PASS.
- [ ] **Step 4: Commit** `"Shop server: buy in the currency the client picked, validated per row"`.

### Task 3: Shop window: 5 tabs, two buy buttons

**Files:**
- Modify: `src/ReplicatedStorage/UI/ShopGui.lua`
- Modify: `src/StarterPlayerScripts/ShopController.client.lua:22-26`
- Create: `tests/shop_gui_test.lua`

**Interfaces:**
- Consumes: the Task 2 snapshot.
- Produces: `ShopGui:OnBuy(callback(index, amount, currency))`. `ShopGui.new()` no longer needs a LocalPlayer: it parents to PlayerGui only when one exists, so Edit tests can build it.

- [ ] **Step 1: Write the failing test** `tests/shop_gui_test.lua`. It builds `ShopGui.new()` from a fresh clone (keep the clone alive until the end, as `arena_hud_test` does) and calls `Show` with a fake island snapshot:
  `categories` = the 5, sells = 1 house row (coins 20000 gems 80) + 1 decor row (coins 500 gems 2) + seeds (coins 250 gems 1 count 3), gems = 10, gold = 5000.
  Checks:
  1. A frame named `Tabs` has 5 `TextButton`s.
  2. The first tab is selected and only the house row shows in `sellList`.
  3. That row has buttons named `BuyGems` and `BuyCoins`.
  4. Firing the decor tab's `Activated` isn't possible from a test, so call `gui:SelectTab("decor")`: only the decor row shows. Then `Show(snapshot)` again: still decor (the tab persists).
  5. The purse text contains both "💰" and "💎".
  6. A main-game snapshot (no categories, rows with `coins` only) shows no `Tabs`, and each row has one `Buy` button.
- [ ] **Step 2: Run** on the farming place (Edit). Expected: FAIL.
- [ ] **Step 3: Implement.**
  - `new()`: `if Players.LocalPlayer then gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui") end`.
  - Tab bar `Tabs` at `UDim2.new(0, 12, 0, 44)` with size `UDim2.new(1, -24, 0, 26)`, using `UIListLayout` horizontal with 4px padding and `Size = UDim2.new(1/5, -4, 1, 0)` per tab.
    The selected tab gets `RUNE` background and dark text. Tabs are built inside `Show` from `snapshot.categories`. The bar is hidden when there are no categories.
  - `self.tab` persists across `Show`. If it is nil, or not one of the categories, use the first category.
  - Add `ShopGui:SelectTab(id)`: set `self.tab`, then call `self:Show(self.last)`.
  - Rows: the price line reads `💎 %s · 💰 %s` when both prices exist, and `ราคา %s` for coins only. Add a `commas(n)` helper that formats 62500 as 62,500.
  - Buttons on the right, when both prices exist: `BuyCoins` (💰 coins, width 74) at x -6, and `BuyGems` (💎 gems, width 52) left of it. The amount box goes left of those.
    The name/price labels shrink to `UDim2.new(1, -(40 + 6 + 74 + 4 + 52 + 4 + 38 + 6), ...)`, with TextTruncate as today.
  - Coins-only rows keep today's single `Buy` button ("ซื้อ").
  - The purse reads `💰 %s · 💎 %s` when `snapshot.gems ~= nil`, otherwise `เงิน %d` as today.
  - `onBuy(entry.index, want, currency)`.
  - Controller: `gui:OnBuy(function(index, amount, currency) ... FireServer("buy", index, amount, currency) end)`.
- [ ] **Step 4: Run** `shop_gui_test` and `load_all_modules.lua` (farming place). Expected: PASS, and ok for every module except the `Remotes` timeout.
- [ ] **Step 5: Commit** `"Shop window: island tabs and two buy buttons per row"`.

### Task 4: Pen animals: gems or coins

**Files:**
- Modify: `src/ServerScriptService/Island/IslandZones.server.lua` (`penSnapshot :144-146` · `penBuy :224-257` · remote `:562-572`)
- Modify: `src/StarterPlayerScripts/IslandPenController.client.lua:141-189` (row)

**Interfaces:**
- Consumes: `ShopConfig.GemsFor` (Task 1). IslandZones needs `local ShopConfig = require(ReplicatedStorage.ShopConfig)` and `local PremiumAccess = require(ServerScriptService.PremiumAccess)` if they aren't there yet.
- Produces: pen snapshot `animals[i] = { kind, name, price, gems }` · `IslandPenBuy(uid, kind, count, currency)`.

- [ ] **Step 1:** Snapshot rows add `gems = ShopConfig.GemsFor(a.price)`.
- [ ] **Step 2:** `penBuy(player, model, kind, count, currency)`:
  - Reject currencies other than nil/"gems"/"coins".
  - Unit price: `currency == "gems" and ShopConfig.GemsFor(spec.price) or spec.price`.
  - Affordability: gems use `PremiumAccess.GetGems`. If PremiumAccess isn't ready, return false with "ร้านเพชรยังไม่พร้อม". Coins use `state.gold` as today.
  - Remember the animals present before spawning (`penFolder(model):GetChildren()` as a set).
  - After spawning, charge: gems use `SpendGems(player, unit * born)`, coins use `AddGold(-unit * born)`.
  - If `SpendGems` fails, destroy the animals that weren't in the set, then `return false, "เพชรไม่พอ"`, and do not call `saveHerd`.
  - The remote handler passes the 4th argument through.
- [ ] **Step 3:** Client row. The name label shows the animal name only. Two buttons: `💎 %d` (gems) and `💰 %s` (coins). Each buys **1** (`FireServer(uid, kind, 1, currency)`).
  The "เต็มคอก" button goes (ruling: the pen holds only 3, and four buttons don't fit a phone row). The blocked colour logic stays as it is.
- [ ] **Step 4:** Syntax check both files (farming place). Expected: OK.
- [ ] **Step 5: Commit** `"Pen animals: buy with gems or coins"`.

### Task 5: Push, verify, document

- [ ] **Step 1:** Push the touched `src/` files to the farming place, and to the main place if it is open (filter each by `globIgnorePaths`). Then run `dump_all.lua` + `cmp.js`: `mismatches 0`.
- [ ] **Step 2:** Run `load_all_modules.lua` on the farming place: every module ok except the `Remotes` timeout. Then run `island_shop_prices_test`, `shop_gui_test`, `farm_tuning_test` and `mail_config_test`: all PASS.
- [ ] **Step 3:** Mark phase 2a as written and pushed in the spec (with the two user decisions of 2026-09-27), add a CLAUDE.md line, and commit.
- [ ] **Step 4: In-game test list for the user** (farming place):
  1. The island shop has 5 tabs, and each tab holds the right items.
  2. Every row shows 💎 and 💰. Buy with each and check that the right currency goes down by the right amount (seeds: 💎 1 or 💰 250 for 3).
  3. After buying, the shop stays on the same tab.
  4. In the pen window, buying one animal with each currency works.
  5. On a phone, the tabs and buttons don't overlap.
  6. Mailing seeds or a house to a friend is refused.
