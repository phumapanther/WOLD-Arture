# เฟส 2b · ของขอบทอง + บัฟ 3 สี + กระเป๋า VIP 36 ช่อง — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Island harvests can drop one gold-bordered piece (`meta.gold = true`). Gold pieces sit in the VIP bag, sell only on the island at 3× the market price, and can never leave their owner. Glow becomes blue 7% / gold 2.5% / red 0.5%. The VIP bag grows to 36 slots.

**Architecture:**
- `ItemCatalog.IsGoldBorder(meta)` is the single test for "is this a gold piece". Every transfer rule (`IsMailable/IsStorable/IsDroppable`) takes `meta` and refuses gold. Trade and "give" ask the same test.
- A pure module `GoldBorder` (ReplicatedStorage) owns which items can be gold and rolls whether a harvest drops one.
- `IslandConfig.RollGlow(canGold)` owns the three glow chances. `GlowYield/GlowExp` own what each glow does.
- `Inventory` routes gold pieces to the VIP range and never spills them into the vault. `Inventory.AddHarvest` is the one grant path that both `Gathering` and `IslandPlots` call.
- Selling asks `ShopConfig.GoldSellPrice`.

**Tech Stack:** Roblox Luau · Edit-mode tests on fresh clones (`node tools/lua.js <test> Edit`, farming place 136992335889132).

**Spec:** `docs/superpowers/specs/2026-09-26-v1.5-roadmap-design.md` (section "เฟส 2b")

## Global Constraints
- Gold only rolls on the island (`ServerConfig.IsFarm`), at most **1 piece per harvest**. Chances: normal **10%**, gold glow **40%**, red glow **100%**. Blue glow's ×2 does **not** multiply the gold piece.
- Eligible items:
  - pen products: Egg, Milk, Wool, Leather, Meat (derived from `GatherConfig.Nodes[kind].item` for `IslandConfig.PenAnimals`)
  - ores except coal/stone: `GatherConfig.Ores`
  - crop-plot main products: Wheat, Vegetable, Herb, MagicBranch (from `IslandConfig.Crops`)
  - **Herb from wild bushes is not eligible, Herb from a crop plot is** (user 2026-09-27)
  - wood, fish, seeds, worms and every bonus item are not eligible
- Glow: blue 7% · gold 2.5% · red 0.5%. Red only on things that can be gold, so trees and bushes get blue/gold only.
  Blue = items ×2 · gold = EXP ×2 + gold 40% · red = gold certain + items ×2 + EXP ×2.
- **A red ore node always yields its own ore**, skipping the stone/coal roll (user 2026-09-27).
- A gold piece never stacks and lives in the VIP bag. It can't be stored (vault, island crate, clan, town, cabinets, trunk), mailed, traded, given or **dropped** (user 2026-09-27).
  It isn't a crafting material, quest item or enhance material.
- **VIP bag full when a gold piece rolls:** the piece arrives as a normal item and the player is told (user 2026-09-27). It never goes into the vault.
- Sold only on the island, one piece at a time, at **3× the current market price**. Sell-all skips gold. The main-game shop and `TownBuyers` refuse gold.
- VIP bag = 36 slots (37-72). Old saves in 37-54 keep working.
- Never press Play. Commit messages end with `Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>`.

## Review Focus
- Any other path that iterates `state.slots` and consumes or moves items by id (not only the ones listed here) would eat a gold piece or let it leave. Grep for `pairs(state.slots)` and `slots[` across `src/`.
- A VIP bag at 35/36 with a gold roll on a 5-item harvest. Expected: 4 normal + 1 gold, or 5 normal and a "lost" notice when full. Never a vault spill, and never fewer items than rolled.
- A red-glow ore node when the pickaxe breaks or the bag is full. Expected: no gold granted, and the node still spent.
- A save written before this change, with VIP items at 37-54. Expected: those items are still there after the VIP bag becomes 36 slots.
- Blue ×2 on a gold harvest. Expected: `count × 2` total, of which exactly 1 is gold.

---

### Task 1: Gold rules and three-colour glow (pure config + GoldBorder)

**Files:**
- Modify: `src/ReplicatedStorage/IslandConfig.lua` (`Glow` table, `RollGlow`, add `GoldBorder` numbers, `GlowYield`, `GlowExp`)
- Create: `src/ReplicatedStorage/GoldBorder.lua`
- Modify: `src/ReplicatedStorage/ItemCatalog.lua` (`IsGoldBorder`, and the `DisplayName` suffix)
- Create: `tests/gold_border_test.lua`

**Interfaces:**
- Produces:
  - `IslandConfig.Glow.rates = { blue = 0.07, gold = 0.025, red = 0.005 }` · `Glow.colors.red`
  - `IslandConfig.RollGlow(canGold) -> "blue"|"gold"|"red"|nil` (never "red" when `canGold` is falsy)
  - `IslandConfig.GlowYield(glow) -> 2|1` · `IslandConfig.GlowExp(glow) -> 2|1`
  - `IslandConfig.GoldBorder = { chance = 0.10, goldGlow = 0.40 }`
  - `ItemCatalog.IsGoldBorder(meta) -> boolean` · `DisplayName(id, { gold = true })` appends " (ขอบทอง)"
  - `GoldBorder.GatherItems` (set) · `GoldBorder.CropItems` (set) · `GoldBorder.Is(meta)` · `GoldBorder.NewMeta() -> { gold = true }` ·
    `GoldBorder.Roll(glow, rand?) -> boolean` · `GoldBorder.NodeCanGold(nodeKind) -> boolean`

- [ ] **Step 1: Write the failing test** `tests/gold_border_test.lua`. It clones `IslandConfig`, `GatherConfig`, `ItemCatalog`, its four config siblings and `GoldBorder` into a temp folder (the same pattern as `island_shop_prices_test`) and checks:
  - `RollGlow(true)` over 200,000 rolls lands within ±0.3 points of blue 7 / gold 2.5 / red 0.5. `RollGlow(false)` gives no red, blue ≈7 and gold ≈2.5.
  - `GoldBorder.Roll("red")` is always true. `Roll("gold")` ≈40% and `Roll(nil)` ≈10% over 100,000 rolls (±1 point).
  - `GatherItems` has Egg, Milk, Wool, Leather, Meat, IronOre, SilverOre, GoldOre, MagicOre, Diamond and Crystal, and does not have Coal, Stone, Herb, Wood or Worm.
  - `CropItems` has Wheat, Vegetable, Herb and MagicBranch.
  - `NodeCanGold("Chicken")` and `NodeCanGold("IronOre")` are true. `NodeCanGold("Rock")`, `NodeCanGold("Coal")`, `NodeCanGold("Tree")` and `NodeCanGold("Herb")` are false.
  - `GlowYield`: blue 2, red 2, gold 1, nil 1. `GlowExp`: gold 2, red 2, blue 1, nil 1. `Glow.colors.red` is a Color3.
  - `ItemCatalog.IsGoldBorder({gold=true})` is true. `IsGoldBorder(nil)` and `IsGoldBorder({kg=3})` are false.
    `DisplayName("Egg", {gold=true})` ends with "(ขอบทอง)".
- [ ] **Step 2: Run it** (Edit, farming place). Expected: FAIL, because GoldBorder doesn't exist yet.
- [ ] **Step 3: Implement.**
  - `IslandConfig.Glow`: replace `chance`/`goldShare` with `rates` and add `colors.red = Color3.fromRGB(255, 84, 84)`. Keep `exp = 2` and `yield = 2`. Then:

```lua
-- ทอยแสงตอนของชิ้นนั้นเริ่มรอบใหม่ · `canGold` = ของชิ้นนี้มีขอบทองได้ไหม (แดงขึ้นเฉพาะของแบบนั้น — เฟส 2b)
-- ของที่มีขอบทองไม่ได้ (ต้นไม้ พุ่ม หิน) ทอยแค่ฟ้ากับทอง โอกาสสองตัวนั้นเท่าเดิม
function IslandConfig.RollGlow(canGold)
	local rates = IslandConfig.Glow.rates
	local r = math.random()
	if r < rates.blue then return "blue" end
	r -= rates.blue
	if r < rates.gold then return "gold" end
	r -= rates.gold
	if canGold and r < rates.red then return "red" end
	return nil
end
function IslandConfig.GlowYield(glow) return (glow == "blue" or glow == "red") and IslandConfig.Glow.yield or 1 end
function IslandConfig.GlowExp(glow) return (glow == "gold" or glow == "red") and IslandConfig.Glow.exp or 1 end
IslandConfig.GoldBorder = { chance = 0.10, goldGlow = 0.40 } -- ผู้ใช้กำหนด 2026-09-26 · แดง = แน่นอน
```

  - `ItemCatalog`:

```lua
-- ของขอบทอง (เฟส 2b): meta.gold = true · ตัวตัดสินตัวเดียวที่กฎโอน/ฝาก/ขาย/วัตถุดิบถาม
function ItemCatalog.IsGoldBorder(meta)
	return type(meta) == "table" and meta.gold == true
end
```

    In `DisplayName`, before the final return, add: `if ItemCatalog.IsGoldBorder(meta) then base ..= " (ขอบทอง)" end`
    (after the enhance/skin handling, so a gold egg reads "ไข่ (ขอบทอง)").
  - `GoldBorder.lua`:

```lua
-- GoldBorder (เฟส 2b): ของขอบทองบนเกาะ — ของชิ้นไหนมีได้ และการเก็บครั้งนี้ได้หรือเปล่า
-- ข้อมูลล้วน: ไม่แตะกระเป๋า ไม่รู้จักผู้เล่น (การแจกอยู่ที่ Inventory.AddHarvest)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local IslandConfig = require(ReplicatedStorage.IslandConfig)
local GatherConfig = require(ReplicatedStorage.GatherConfig)
local ItemCatalog = require(ReplicatedStorage.ItemCatalog)

local GoldBorder = {}

-- ผลผลิตสัตว์คอก + แร่ทุกชนิดยกเว้นถ่านหิน/หิน (อ่านจากคอนฟิก สัตว์/แร่ชนิดใหม่ได้กฎนี้เอง)
GoldBorder.GatherItems = {}
for _, a in ipairs(IslandConfig.PenAnimals) do
	local node = GatherConfig.Nodes[a.kind]
	if node and node.item then GoldBorder.GatherItems[node.item] = true end
end
for _, ore in ipairs(GatherConfig.Ores) do GoldBorder.GatherItems[ore] = true end

-- ผลผลิตหลักของแปลงผักทุกชนิด (สมุนไพรจากแปลงได้ · จากพุ่มป่าไม่ได้ — ผู้ใช้เลือก 2026-09-27)
GoldBorder.CropItems = {}
for _, c in ipairs(IslandConfig.Crops) do GoldBorder.CropItems[c.item] = true end

GoldBorder.Is = ItemCatalog.IsGoldBorder
function GoldBorder.NewMeta() return { gold = true } end

-- โหนดนี้ (สัตว์คอก/สายแร่บนเกาะ) ให้ของที่มีขอบทองได้ไหม — ใช้ตัดสินว่าแสงแดงขึ้นได้ไหม
function GoldBorder.NodeCanGold(kind)
	local node = GatherConfig.Nodes[kind]
	return node ~= nil and GoldBorder.GatherItems[node.item] == true
end

-- การเก็บครั้งนี้ได้ขอบทองไหม (หนึ่งชิ้นต่อครั้ง) · แดง = แน่นอน · ทอง = 40% · อื่นๆ = 10%
function GoldBorder.Roll(glow, rand)
	if glow == "red" then return true end
	local c = IslandConfig.GoldBorder
	return (rand or math.random)() < (glow == "gold" and c.goldGlow or c.chance)
end

return GoldBorder
```

- [ ] **Step 4:** Update the existing glow callers that read `Glow.chance`/`goldShare` (grep them). Also update the glow tests under `tests/` (`island_glow_test`, `island_tuning_test`) only where they assert the removed fields. Those two are Play-only, so they get a syntax check.
- [ ] **Step 5: Run** `gold_border_test` (PASS) and `load_all_modules` on the farming place (ok, except the `Remotes` timeout).
- [ ] **Step 6: Commit** `"Gold border rules and three-colour glow (blue/gold/red)"`.

### Task 2: Inventory, gold pieces in the VIP bag, VIP bag 36

**Files:**
- Modify: `src/ReplicatedStorage/InventoryConfig.lua:17` (`VipSlotCount = 36`, comment "6 คอลัมน์ x 6 แถว")
- Modify: `src/ServerScriptService/BagRanges.lua` (`For` honours `meta.gold`)
- Modify: `src/ServerScriptService/Inventory.lua` (`rangeFor` callers pass meta · gold never spills · CountOf/RemoveById/FindSlotById skip gold · new `AddHarvest`)
- Modify: `tests/bag_ranges_test.lua` (add cases)

**Interfaces:**
- Produces: `Inventory.AddHarvest(player, id, count, withGold) -> ok, goldResult` where goldResult is `"given"` | `"lost"` | nil.
  When `ok` is false nothing was added (the normal portion didn't fit).

- [ ] **Step 1: Failing tests** in `bag_ranges_test`:
  - `For("Egg", {gold=true})` returns `VipSlotStart, VipSlotEnd`, and `For("Egg")` returns `1, SlotCount`.
  - `VipSlotEnd == 72`.
  - `SwapFits`: receiving a gold egg counts against the VIP range.
- [ ] **Step 2: Run** (Edit). Expected: FAIL.
- [ ] **Step 3: Implement.**
  - `BagRanges.For`: first line `if meta and meta.gold == true then return InventoryConfig.VipSlotStart, InventoryConfig.VipSlotEnd end`.
  - `Inventory`:
    - `firstFreeSlot(state, id, meta)` uses `rangeFor(id, meta)`.
    - `bagRoom` uses `rangeFor(id, meta)`.
    - The AddItem merge loop and the placement loop use `rangeFor(id, meta)` / `firstFreeSlot(state, id, meta)`.
    - `MigrateVipSlots` uses `rangeFor(slot.id, slot.meta)`.
    - `CountOf` and `RemoveById` skip slots where `ItemCatalog.IsGoldBorder(slot.meta)`. So does `FindSlotById`: read it first and add the same guard.
    - `AddItem`: after the spill is computed, `if spill > 0 and ItemCatalog.IsGoldBorder(meta) then return false end`. A gold piece never goes to the vault.
  - `AddHarvest`:

```lua
-- แจกผลผลิตจากการเก็บเกี่ยวบนเกาะ (เฟส 2b) — `count` ชิ้นรวมทั้งหมด ถ้า `withGold` หนึ่งชิ้นในนั้นเป็นขอบทอง
-- กระเป๋า VIP เต็ม = ชิ้นนั้นเป็นของธรรมดาแทน (ผู้ใช้เลือก 2026-09-27) ไม่เข้าคลัง ไม่หาย
-- คืน false = ไม่ได้ให้อะไรเลย (ส่วนธรรมดาใส่ไม่ลง) · ผลที่สองบอกชะตาของชิ้นทอง: "given" / "lost" / nil
function Inventory.AddHarvest(player, id, count, withGold)
	if count < 1 then return false end
	local gold = withGold and Inventory.HasRoomFor(player, id, 1, { gold = true }) or false
	local normal = count - (gold and 1 or 0)
	if normal > 0 and not Inventory.AddItem(player, id, normal) then return false end
	if gold then
		Inventory.AddItem(player, id, 1, nil, { gold = true })
		return true, "given"
	end
	return true, withGold and "lost" or nil
end
```

- [ ] **Step 4:** Grep `src/` for every loop over `state.slots` that consumes by id (`pairs(state.slots)`, `slots[`). List each one in the ledger with its verdict (already skips gold / fixed here / not a consumer).
  `Crafting` and `Quests` are fixed in Task 4. The Vehicle trunk moves items via `RemoveById`, so it already skips gold: verify and note it.
- [ ] **Step 5: Run** `bag_ranges_test` (PASS) and a syntax check of `Inventory.lua` + `BagRanges.lua`.
- [ ] **Step 6: Commit** `"Inventory: gold pieces live in the VIP bag, never spill or count as materials; VIP bag 36"`.

### Task 3: Gold pieces cannot leave their owner

**Files:**
- Modify: `src/ReplicatedStorage/ItemCatalog.lua`. `IsMailable(id, meta)`, `IsStorable(id, meta)` and `IsDroppable(id, meta)` gain the first line
  `if ItemCatalog.IsGoldBorder(meta) then return false end`.
- Modify callers so they pass `slot.meta`:
  - `BankVault.server:195`
  - `Clans.server:578`
  - `TownVault.server:169`
  - `StorageChests.server` (`accepts(model, id, meta)`, plus its caller at :162)
  - `PlayerMail.server:73,90`
  - `UI/SocialGui:2005`
  - `PlayerInventory.server:235`. The message becomes gold-aware: "ของขอบทองทิ้งไม่ได้" for gold, the key message otherwise.
  - `InventoryController.client:280` (drop button), plus `:247` (the "ให้" button also hides for gold).
  - `Trading.server:131`: `if ItemCatalog.IsBound(slot.id) or ItemCatalog.IsGoldBorder(slot.meta) then return nil end`
  - `ClassActions.server:362`: the same guard, with the message "ของขอบทองให้ใครไม่ได้"
- Modify: `tests/gold_border_test.lua`. Add checks that IsMailable, IsStorable and IsDroppable of `("Egg", {gold=true})` are all false, and that `IsMailable("Egg")` stays true.

- [ ] **Step 1:** Add the test checks. Run (Edit). Expected: FAIL.
- [ ] **Step 2:** Implement the three ItemCatalog guards and every caller above.
- [ ] **Step 3:** Run the test (PASS). Run `mail_config_test` (PASS). Syntax-check every touched file.
- [ ] **Step 4: Commit** `"Gold pieces cannot be stored, mailed, traded, given or dropped"`.

### Task 4: Selling and consuming

**Files:**
- Modify: `src/ReplicatedStorage/ShopConfig.lua`: add `ShopConfig.GoldSellMultiplier = 3` and

```lua
-- ราคาขายของขอบทอง: บนเกาะเท่านั้น 3 เท่าของราคาตลาดตอนนั้น (ผู้ใช้กำหนด 2026-09-26) · nil = ร้านนี้ไม่รับ
function ShopConfig.GoldSellPrice(base, onIsland)
	if not onIsland then return nil end
	return math.max(1, math.floor(base * ShopConfig.GoldSellMultiplier + 0.5))
end
```

- Modify: `Shop.server` `buyPrice(id, meta)`. After `base` is computed:
  `if ItemCatalog.IsGoldBorder(meta) then return ShopConfig.GoldSellPrice(base, ServerConfig.IsFarm) end`.
  Sell-all collection skips gold slots, and the notify says "ขายของขอบทองทีละชิ้น" when only gold is left.
- Modify: `TownBuyers.server` `priceFor`: `if ItemCatalog.IsGoldBorder(meta) then return nil end`.
- Modify: `Crafting.server` `countMaterial` and `takeMaterial`, and `Quests.server` `progressOf`: skip gold slots.
- Test: add to `gold_border_test`: `GoldSellPrice(10, true) == 30` and `GoldSellPrice(10, false) == nil`.
- [ ] **Step 1:** Add the test checks. Run. Expected: FAIL.
- [ ] **Step 2:** Implement. **Step 3:** Run the test (PASS) and syntax-check every touched file.
- [ ] **Step 4: Commit** `"Gold pieces sell only on the island at 3x; never count as materials or quest items"`.

### Task 5: Harvests grant gold, and the red glow

**Files:**
- Modify: `src/ServerScriptService/Gathering.server.lua`
  - `:186` → `IslandConfig.RollGlow(GoldBorder.NodeCanGold(node:GetAttribute("NodeKind")))` (read how the kind is known in `setSpent` first).
  - Grant section `:330-430`:
    - **red + ore node**: when `glow == "red"` and `config.roll`, skip the roll. Use `itemId = config.item` with its own min/max.
    - Yield multiplier from `IslandConfig.GlowYield(glow)`, EXP from `GlowExp(glow)`. Both replace the `glow == "blue"`/`"gold"` checks, including the bonus-item one.
    - `withGold = IsFarm and GoldBorder.GatherItems[itemId] and GoldBorder.Roll(glow)`.
    - Replace `Inventory.AddItem(player, itemId, count)` with `Inventory.AddHarvest(player, itemId, count, withGold)`.
    - Append " (✦ขอบทอง 1)" to the notify text when "given". Send an extra notify "กระเป๋า VIP เต็ม — ขอบทองกลายเป็นของธรรมดา" when "lost".
- Modify: `src/ServerScriptService/Island/IslandPlots.server.lua`
  - `ripen`: `RollGlow(true)`.
  - harvest: `amount * GlowYield`, the same for the bonus/seed multipliers, and `xp * GlowExp`.
  - The main grant becomes `AddHarvest(player, entry.crop, amount, GoldBorder.CropItems[entry.crop] and GoldBorder.Roll(glow))`, with the same notices.
  - The glow message has three cases: gold "✨ แสงทอง: EXP สองเท่า" · blue "💠 แสงฟ้า: วัตถุดิบสองเท่า" · red "🔥 แสงแดง: ขอบทอง + วัตถุดิบและ EXP สองเท่า".
- Modify the remaining `RollGlow` callers:
  - `IslandZones:347,358` (pen animals) → `RollGlow(true)`
  - `IslandZones:460` (mine rock) and `IslandNodes:152` → `RollGlow(GoldBorder.NodeCanGold(kind))`, using the kind variable in scope
- Client: `IslandBadgeController` reads `GLOW.colors[tone]`, so red works once the colour exists. Verify there's no `tone == "blue"`-style branch that would treat red as blue.
- [ ] **Step 1:** Implement. **Step 2:** Syntax-check the four files and run `load_all_modules`.
- [ ] **Step 3: Commit** `"Island harvests roll gold pieces; red glow guarantees one (red ore yields its own ore)"`.

### Task 6: Gold piece looks gold in the bag

**Files:**
- Modify: `src/ReplicatedStorage/UI/InventoryGui.lua` Render (`:505-517`). When `ItemCatalog.IsGoldBorder(slot.meta)`:
  - `entry.stroke.Color = Color3.fromRGB(255, 200, 60)`, `Thickness = 2.5`, `Transparency = 0`
  - `entry.count.Text = "✦"`, `TextColor3` gold
  - Reset `Thickness` to its original value on normal/empty slots (read the value set at `:402` first).
- [ ] **Step 1:** Implement. **Step 2:** Syntax check + `load_all_modules`. **Step 3: Commit** `"Bag: gold pieces get a gold frame and a ✦ mark"`.

### Task 7: Push, verify, document
- [ ] Push every touched `src/` file to the farming, main and arena places (filter by `globIgnorePaths`). Run `dump_all` + `cmp`: `mismatches 0` on all three.
- [ ] Run `load_all_modules` (farming). Then run `gold_border_test`, `bag_ranges_test`, `island_shop_prices_test`, `mail_config_test`, `farm_tuning_test`, `starter_kit_test` and `arena_config_test`: all PASS.
- [ ] Update the spec (phase 2b done, the four user decisions of 2026-09-27) and CLAUDE.md (gold rules, the `IsGoldBorder` single test, VIP 37-72, `AddHarvest`). Replace the "37-54" mentions. Commit.
- [ ] In-game test list for the user (farming place):
  1. Harvest pens, crop plots and ore nodes until a gold piece drops: it shows a gold frame and ✦ in the VIP bag.
  2. It can't be mailed, stored in a cabinet or crate, traded, given or dropped.
  3. It sells in the island shop at 3× the normal price, one at a time, and "ขายทั้งหมด" skips it.
  4. Red glow: shows red, and gives a gold piece + ×2. A red ore node gives its own ore.
  5. The VIP bag has 36 slots, and the items that were there are still there.
