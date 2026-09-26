# เฟส 0 · แก้บั๊กเดิม — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix the ten existing bugs that the 2026-09-26 audit found (exploits, data loss, mobile slimes, sniper misses) before any v1.5 feature work.

**Architecture:** Each fix goes in the file that already owns that behaviour. Two small extractions make the logic Edit-testable: `BagRanges` (which bag range an item belongs to, plus swap room) and `RayThrough.NearestNear` (sniper miss forgiveness). Everything else is a guarded change verified by reading plus the user's in-game pass.

**Tech Stack:** Roblox Luau · Rojo · tests run in Studio Edit through `node tools/lua.js tests/<file>.lua Edit` (prefix `WOLD_PLACE=<id>` because three Studio windows are open) · push with `node tools/push.js` · verify with scratchpad `dump_all.lua` + `cmp.js`.

**Spec:** `docs/superpowers/specs/2026-09-26-v1.5-roadmap-design.md` (section "เฟส 0")

## Global Constraints
- Places: main 88774255487951 (`default.project.json`) · farming 136992335889132 · arena 134798670267276.
- New server-only scripts for the main game go in the `globIgnorePaths` of farming/arena. Modules never do.
- Never press Play. The user tests in-game after the whole phase is pushed and committed.
- Commit messages end with `Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>`.
- `require` of `Inventory`/`ClanStore` from execute_luau is blocked (Capabilities), so tests only require plain modules through the `fresh()` clone pattern.
- Do not touch `mapgen/90_island_placeables.lua` or `assets/item-icons/สไน.png`.

## Review Focus
- An island shop gem purchase when `PremiumAccess.GetGems/SpendGems` are nil (PremiumStore failed to load). The expected result is refused with a message and nothing given.
- A PVP player who leaves and rejoins twice in one match. The expected result is one row with stats carried over, and one reward.
- A trade that swaps a VIP-bag item while the main bag is full. It should succeed when each receiving range has room.
- An island server shutdown while random resource spots are on the ground. The spots should still be in `Data.nodes` after the restart.
- A sniper shot through tree leaves at a slime 450 studs away. It should hit.

---

### Task 1: Island shop gem purchase cannot hand out free items

**Files:**
- Modify: `src/ServerScriptService/Shop.server.lua:263-294`

**Interfaces:**
- Consumes: `PremiumAccess.GetGems(player)` and `PremiumAccess.SpendGems(player, n) -> bool` (set by PremiumStore.server).
- Produces: nothing new.

- [ ] **Step 1: Refuse a gem purchase when the gem functions are missing.** Replace the purse line so a gem row never falls back to reading coins:

```lua
		local gems = entry.currency == "gems"
		if gems and not (PremiumAccess.GetGems and PremiumAccess.SpendGems) then
			return Remotes.SocialNotify:FireClient(player, "error", "ร้านเพชรยังไม่พร้อม ลองใหม่อีกครั้ง")
		end
		local purse = gems and PremiumAccess.GetGems(player) or state.gold
```

- [ ] **Step 2: Roll back the items if the gem charge fails.** Replace `PremiumAccess.SpendGems(player, entry.price * bought)` with:

```lua
			if not PremiumAccess.SpendGems(player, entry.price * bought) then
				Inventory.RemoveById(player, entry.id, got) -- ทั้งหมดหรือไม่เอาเลย: ของที่เพิ่งใส่ถอดคืน
				return Remotes.SocialNotify:FireClient(player, "error", "เพชรไม่พอ")
			end
```

- [ ] **Step 3: Syntax check.** Run: `WOLD_PLACE=88774255487951 node tools/syntax.js src/ServerScriptService/Shop.server.lua`. Expected: `-> OK`.
- [ ] **Step 4: Commit.** `git commit -am "Shop: gem purchase refuses without gem service and rolls back on failed charge"` (add the Co-Authored-By line).

### Task 2: PVP leavers, rejoiners and visiting admins get no extra rewards

**Files:**
- Modify: `src/ServerScriptService/Arena/ArenaMatch.server.lua` (PlayerJoin.Each around :1040, finishMatch :941-962)
- Modify: `src/ServerScriptService/Arena/ArenaRewards.lua:20-48`

**Interfaces:**
- Produces: row fields `noReward = true` (leaver who never came back, or admin not in the match record). `ArenaRewards.Grant` skips mail and stats for them and shows 0 / no chest.

- [ ] **Step 1: A rejoin reuses the old fighter row.** At the top of `PlayerJoin.Each` (after the BotRoster removal loop) insert:

```lua
	-- **กลับเข้ามาใหม่ = ใช้แถวเดิม** (QA 2026-09-26): เดิมสร้างแถวใหม่ต่อ Player ตัวใหม่ → สองแถว สองรางวัล สองสถิติ
	for oldKey, f in pairs(Fighters) do
		if f.kind == "player" and f.left and f.userId == player.UserId then
			Fighters[oldKey] = nil
			f.player, f.left = player, nil
			Fighters[player] = f
			if State.phase == "warmup" or State.phase == "buy" then spawnPlayer(f, countIn(f.side)) end
			print(("[Arena] %s กลับเข้าทีม %s"):format(player.Name, f.side))
			pushAll()
			return
		end
	end
```

- [ ] **Step 2: Record userId and the visiting-admin flag on new fighters.** In the `Fighters[player] = { ... }` constructor add `userId = player.UserId,` and `visitor = sideOfUserId(player.UserId) == nil,` (true only for an admin who joined without being in the record).
- [ ] **Step 3: Mark rows with no reward.** In `finishMatch`, inside the row constructor, add:

```lua
			-- ออกแล้วไม่กลับมาก่อนจบ = แพ้ ไม่มีรางวัล · แอดมินที่เข้ามาดู = ไม่มีรางวัล/สถิติ (ผู้ใช้กำหนด 2026-09-26)
			noReward = f.kind == "player" and (f.left == true or f.visitor == true) or nil,
```

and change `won = ...` to `won = not f.left and State.wins[f.side] > State.wins[f.side == "A" and "B" or "A"],`.
- [ ] **Step 4: Grant skips them.** In `ArenaRewards.Grant`, right after `row.gold, row.exp, row.chest, row.rank = ...` add:

```lua
		if row.noReward then row.gold, row.exp, row.chest = 0, 0, nil end
```

and change `if row.userId then` to `if row.userId and not row.noReward then`.
- [ ] **Step 5: Syntax check both files** on the arena place (`WOLD_PLACE=134798670267276`). Expected: `-> OK` twice.
- [ ] **Step 6: Commit** `"Arena: rejoin reuses the fighter row; leavers and visiting admins get no reward"`.

### Task 3: Trade room counts each bag range separately

**Files:**
- Create: `src/ServerScriptService/BagRanges.lua`
- Modify: `src/ServerScriptService/Inventory.lua:74-90` (use BagRanges)
- Modify: `src/ServerScriptService/Trading.server.lua:102-110,170-174`
- Test: `tests/bag_ranges_test.lua`

**Interfaces:**
- Produces: `BagRanges.For(id, meta) -> from, to` and `BagRanges.SwapFits(slots, giving, receiving) -> bool`. `giving` and `receiving` are arrays of `{ id, meta }`, one entry per whole slot. Phase 2b extends `For` to send `meta.gold` items to the VIP range.

- [ ] **Step 1: Write the failing test** `tests/bag_ranges_test.lua`:

```lua
-- node tools/lua.js tests/bag_ranges_test.lua Edit
local function fresh(module)
	local copy = module:Clone()
	copy.Name = module.Name .. "_t" .. math.random(1, 1e9)
	copy.Parent = module.Parent
	local ok, result = pcall(require, copy)
	copy:Destroy()
	assert(ok, result)
	return result
end
local BagRanges = fresh(game.ServerScriptService.BagRanges)
local Cfg = require(game.ReplicatedStorage.InventoryConfig)
local out, fails = {}, 0
local function check(ok, text) out[#out + 1] = (ok and "ok   " or "FAIL ") .. text; if not ok then fails += 1 end end

local mf, mt = BagRanges.For("Wheat")
check(mf == 1 and mt == Cfg.SlotCount, "ของเกมหลักอยู่ช่องหลัก")
local vf, vt = BagRanges.For("FarmPlot")
check(vf == Cfg.VipSlotStart and vt == Cfg.VipSlotEnd, "ของวางบนเกาะอยู่ช่อง VIP")

local full = {}
for i = 1, Cfg.SlotCount do full[i] = { id = "Stone", count = 1 } end
check(BagRanges.SwapFits(full, {}, { { id = "FarmPlot" } }) == true, "กระเป๋าหลักเต็ม รับของ VIP ได้")
check(BagRanges.SwapFits(full, {}, { { id = "Wheat" } }) == false, "กระเป๋าหลักเต็ม รับของหลักไม่ได้")
check(BagRanges.SwapFits(full, { { id = "Stone" } }, { { id = "Wheat" } }) == true, "ให้ของหลักหนึ่งช่อง รับของหลักหนึ่งช่องได้")
local vipFull = {}
for i = Cfg.VipSlotStart, Cfg.VipSlotEnd do vipFull[i] = { id = "FarmPlot", count = 1 } end
check(BagRanges.SwapFits(vipFull, {}, { { id = "Wheat" } }) == true, "กระเป๋า VIP เต็ม ไม่ขวางการรับของหลัก (บั๊กเดิม)")
check(BagRanges.SwapFits(vipFull, { { id = "Wheat" } }, { { id = "FarmPlot" } }) == false, "ให้ของหลักไม่ได้ปลดช่อง VIP")
return ("%s\n%d fail(s)"):format(table.concat(out, "\n"), fails)
```

- [ ] **Step 2: Run it.** `WOLD_PLACE=88774255487951 node tools/lua.js tests/bag_ranges_test.lua Edit`. Expected: error `BagRanges is not a valid member`.
- [ ] **Step 3: Create `BagRanges.lua`:**

```lua
-- BagRanges: ของชิ้นนี้อยู่ช่วงช่องไหนของกระเป๋า (หลัก 1..36 / VIP 37..) — เกณฑ์เดียวกับแท็บบนหน้าจอเป๊ะ
-- (`InventoryGui.IsFarmItem`: `vip = true` หรือ `kind == "placeable"`) · ยกออกจาก Inventory ให้เทสได้
local ItemCatalog = require(game.ReplicatedStorage.ItemCatalog)
local InventoryConfig = require(game.ReplicatedStorage.InventoryConfig)

local BagRanges = {}

function BagRanges.For(id, meta)
	local item = ItemCatalog.Get(id)
	if item and (item.vip == true or item.kind == "placeable") then
		return InventoryConfig.VipSlotStart, InventoryConfig.VipSlotEnd
	end
	return 1, InventoryConfig.SlotCount
end

-- แลกของแล้วรับไหวไหม: นับช่องว่างแยกฝั่ง ของที่ให้ออกไปปลดช่องในฝั่งของมันเอง (ทีละช่องเต็ม)
function BagRanges.SwapFits(slots, giving, receiving)
	local need = {}
	local function tally(list, sign)
		for _, e in ipairs(list) do
			local from, to = BagRanges.For(e.id, e.meta)
			local r = need[from] or { from = from, to = to, n = 0 }
			r.n += sign
			need[from] = r
		end
	end
	tally(receiving, 1)
	tally(giving, -1)
	for _, r in pairs(need) do
		local free = 0
		for i = r.from, r.to do if not slots[i] then free += 1 end end
		if free < r.n then return false end
	end
	return true
end

return BagRanges
```

- [ ] **Step 4: Inventory uses it.** Replace `isVipItem` and `rangeFor` (`Inventory.lua:74-90`) with:

```lua
-- ช่วงช่องที่ของชนิดนี้ใช้ได้ — กติกาอยู่ที่ BagRanges ที่เดียว (เทรดกับหน้าจอถามที่เดียวกัน)
local BagRanges = require(script.Parent.BagRanges)
local function rangeFor(id, meta) return BagRanges.For(id, meta) end
```

Grep `isVipItem` in Inventory.lua. If any other caller remains, replace it with `select(1, rangeFor(id)) ~= 1`.
- [ ] **Step 5: Trading uses it.** Delete `freeSlots` and replace the room check at :172 with:

```lua
	local BagRanges = require(game.ServerScriptService.BagRanges)
	local stateA, stateB = Inventory.Get(a), Inventory.Get(b)
	if not (stateA and stateB and BagRanges.SwapFits(stateA.slots, takingA, takingB)
		and BagRanges.SwapFits(stateB.slots, takingB, takingA)) then
		return closeSession(session, "กระเป๋าไม่พอ")
	end
```

- [ ] **Step 6: Run the test.** Expected: `0 fail(s)` (7 ok).
- [ ] **Step 7: Syntax check** Inventory.lua and Trading.server.lua. Expected: OK.
- [ ] **Step 8: Commit** `"Trade room is counted per bag range (VIP bag no longer blocks trades)"`.

### Task 4: Island glow on ore-zone rocks, glow survives restart, spots survive shutdown

**Files:**
- Modify: `src/ServerScriptService/Island/IslandNodes.server.lua` (move `closing` above `spawnAt`, persist glow)
- Modify: `src/ServerScriptService/Island/IslandBuild.server.lua:574-578` (glow store)
- Modify: `src/ServerScriptService/Island/IslandAccess.lua:9` (declare)
- Modify: `src/ServerScriptService/Island/IslandZones.server.lua:394-435` (roll glow on rocks)

**Interfaces:**
- Produces: `IslandAccess.NodeGlowStore() -> Data.nodeGlow` (map `"cx,cz" -> "blue"|"gold"`). `spawnAt(kind, cx, cz, glow)` takes an optional restored glow.

- [ ] **Step 1: Declare before use.** Move `local closing = false` and its `game:BindToClose(...)` line from below `spawnAt` to just above `local drop` (~:104). The `Destroying` closure then captures the local. Today it captures a nil global, so every shutdown wipes `Data.nodes`.
- [ ] **Step 2: Add the glow store.** In IslandAccess.lua under `NodeStore`: `IslandAccess.NodeGlowStore = nil -- () -> Data.nodeGlow ("cx,cz" -> สีแสง)`. In IslandBuild next to NodeStore:

```lua
IslandAccess.NodeGlowStore = function()
	if not Data then return nil end
	if not Data.nodeGlow then Data.nodeGlow = {} end
	return Data.nodeGlow
end
```

- [ ] **Step 3: spawnAt remembers glow.** Change the signature to `spawnAt(kind, cx, cz, glow)` and replace the glow line with:

```lua
	-- แสงทอยครั้งเดียวตอนจุดโผล่ครั้งแรก แล้วจำไว้ในโปรไฟล์ (QA 2026-09-26: เดิมทอยใหม่ทุกครั้งที่เซิร์ฟเปิด)
	local gs = IslandAccess.NodeGlowStore and IslandAccess.NodeGlowStore()
	local key = IslandGrid.key(cx, cz)
	if glow == nil then glow = IslandConfig.RollGlow() end
	model:SetAttribute("Glow", glow)
	if gs then gs[key] = glow end
```

In `restoreSaved`, pass the stored glow: `spawnAt(kind, cx, cz, (gs and gs[key]) or false)` with `local gs = IslandAccess.NodeGlowStore and IslandAccess.NodeGlowStore()` above the loop. `false` means "rolled, no glow". The `SetAttribute("Glow", false)` must become `SetAttribute("Glow", glow or nil)`. In `drop`, also clear the glow: `local gs = IslandAccess.NodeGlowStore and IslandAccess.NodeGlowStore(); if gs then gs[key] = nil end`.
- [ ] **Step 4: Ore-zone rocks roll glow.** In `IslandZones.spawnRock`, before `CollectionService:AddTag(rock, NODE_TAG)` add `rock:SetAttribute("Glow", IslandConfig.RollGlow())`.
- [ ] **Step 5: Run the existing island tests** on the farming place: `WOLD_PLACE=136992335889132 node tools/lua.js tests/island_nodes_test.lua Edit` and `tests/island_glow_test.lua`. Expected: 0 fail each.
- [ ] **Step 6: Commit** `"Island: random spots survive shutdown, their glow persists, ore-zone rocks can glow"`.

### Task 5: Monsters and arena bots are server-owned and carry no stray scripts

**Files:**
- Modify: `src/ServerScriptService/Mobs.server.lua` (`buildFromModel` :386 and the AI loop :1480)
- Modify: `src/ServerScriptService/Arena/ArenaBots.lua` (`buildRig` :44-46 and after `model.Parent = workspace` :597)

- [ ] **Step 1: Strip server scripts from clones.** Right after `local model = prototype:Clone()` in `buildFromModel`, and after `proto:Clone()` in ArenaBots `buildRig`, add:

```lua
    -- โมเดลโชว์จากโรงงานพกสคริปต์ของตัวเอง (SlimeController ดึงกลับจุดเกิดทุกเฟรม · NPCController เดินสุ่ม)
    -- ซึ่งแย่งกับ AI ที่นี่ — ยืนยันใน ServerStorage ของเพลสหลักแล้ว 2026-09-26 · ถอดก่อนถูกวางลงโลกจึงไม่เคยรัน
    for _, d in ipairs(model:GetDescendants()) do
        if d:IsA("Script") then d:Destroy() end
    end
```

(`Script` only. LocalScripts don't run in workspace, and `BeastGait.Attach` finds none, which is fine because its `script_` is only used to disable it.)
- [ ] **Step 2: Server ownership in the Mobs AI loop.** Inside `for model, state in pairs(Live) do`, in the `else` branch right after `local config = state.config`, add:

```lua
			-- ฟิสิกส์ของมอนเป็นของเซิร์ฟเวอร์เสมอ (QA 2026-09-26): ปล่อยอัตโนมัติ เอนจินยกให้เครื่องผู้เล่นที่ใกล้สุด —
			-- มือถือเป็นเจ้าของแล้วสไลม์ไม่ขยับ และตำแหน่งที่สไนยิงใส่ไม่ตรงกับที่เซิร์ฟเวอร์ตัดสิน
			if not root.Anchored and root:GetNetworkOwnershipAuto() then
				pcall(root.SetNetworkOwner, root, nil)
			end
```

- [ ] **Step 3: Same for bots.** After `model:PivotTo(cframe)` in ArenaBots add:

```lua
	local botRoot = model:FindFirstChild("HumanoidRootPart")
	if botRoot and not botRoot.Anchored then pcall(botRoot.SetNetworkOwner, botRoot, nil) end
```

- [ ] **Step 4: Syntax check** both files. Expected: OK.
- [ ] **Step 5: Commit** `"Mobs/bots: strip showroom scripts from clones and keep physics server-owned"`.

### Task 6: Sniper reaches its crosshair, passes through foliage, forgives a small miss

**Files:**
- Modify: `src/ReplicatedStorage/CombatConfig.lua:193` (length 400 → 500)
- Modify: `src/ReplicatedStorage/RayThrough.lua` (add `NearestNear`)
- Modify: `src/ServerScriptService/PlayerCombat.server.lua:454-492` (skip decor, forgiveness)
- Test: `tests/ray_through_test.lua`

**Interfaces:**
- Produces: `RayThrough.NearestNear(origin, unit, maxDist, candidates, radius) -> candidate?`, where `candidates = { { model = Model, position = Vector3, pad = number? } }`. It returns the candidate closest along the ray whose perpendicular distance is `<= radius + (pad or 0)` and whose projection is in `[0, maxDist]`.

- [ ] **Step 1: Write the failing test** `tests/ray_through_test.lua`:

```lua
-- node tools/lua.js tests/ray_through_test.lua Edit
local RayThrough = require(game.ReplicatedStorage.RayThrough:Clone())
local out, fails = {}, 0
local function check(ok, text) out[#out + 1] = (ok and "ok   " or "FAIL ") .. text; if not ok then fails += 1 end end
local o, u = Vector3.zero, Vector3.new(0, 0, -1)
local near = { model = "A", position = Vector3.new(2, 0, -100) }
local far = { model = "B", position = Vector3.new(1, 0, -300) }
local wide = { model = "C", position = Vector3.new(6, 0, -50) }
check(RayThrough.NearestNear(o, u, 500, { far, near }, 3) == near, "เลือกตัวที่ใกล้ตามแนวยิงก่อน")
check(RayThrough.NearestNear(o, u, 200, { far }, 3) == nil, "เลยจุดที่กระสุนหยุด (กำแพง) = ไม่นับ")
check(RayThrough.NearestNear(o, u, 500, { wide }, 3) == nil, "ห่างแนวยิงเกินรัศมี = ไม่นับ")
check(RayThrough.NearestNear(o, u, 500, { { model = "D", position = Vector3.new(6, 0, -50), pad = 4 } }, 3) ~= nil,
	"บอสตัวใหญ่ (pad) นับระยะเผื่อเพิ่ม")
check(RayThrough.NearestNear(o, u, 500, { { model = "E", position = Vector3.new(0, 0, 20) } }, 3) == nil,
	"อยู่ข้างหลังผู้ยิง = ไม่นับ")
return ("%s\n%d fail(s)"):format(table.concat(out, "\n"), fails)
```

- [ ] **Step 2: Run it.** Expected: error (`NearestNear` nil).
- [ ] **Step 3: Implement** in RayThrough.lua before `return RayThrough`:

```lua
-- กระสุนพลาดนิดเดียว: ใครอยู่ใกล้แนวยิงที่สุด (ระยะตั้งฉาก ≤ radius + pad) ก่อนจุดที่กระสุนหยุด
-- ตำแหน่งมอนบนจอผู้ยิงช้ากว่าเซิร์ฟเวอร์ ~0.1-0.2 วิ มอนวิ่ง 8-16 สตัด/วิ = คลาด 1-3 สตัด (QA 2026-09-26)
function RayThrough.NearestNear(origin, unit, maxDist, candidates, radius)
	local best, bestT = nil, math.huge
	for _, c in ipairs(candidates) do
		local rel = c.position - origin
		local t = rel:Dot(unit)
		if t >= 0 and t <= maxDist and t < bestT then
			local perp = (rel - unit * t).Magnitude
			if perp <= radius + (c.pad or 0) then best, bestT = c, t end
		end
	end
	return best
end
```

- [ ] **Step 4: Run the test.** Expected: `0 fail(s)`.
- [ ] **Step 5: Range.** In CombatConfig.lua:193 change `length = 400` to `length = 500` (matches `AimController` `AIM_DISTANCE = 500`).
- [ ] **Step 6: Skip decor.** In `fireSniper`'s `passThrough`, replace `if not m then return nil end` with:

```lua
		-- ใบไม้ หญ้า หมุดล่องหน: ชนไม่ได้และไม่ใช่ร่างใคร = กระสุนทะลุ (QA 2026-09-26 — เดิมกระสุนหยุดที่ใบไม้)
		if not m then return (not part.CanCollide) and part or nil end
```

and pass `12` as `maxHops`: `RayThrough.Cast(muzzle, forward * spec.length, params, passThrough, 12)`.
- [ ] **Step 7: Forgiveness.** After `local endPoint = ...`, add:

```lua
	-- เฉียดเป้า: ถ้าเรย์ไม่ได้ชนร่างใคร หาเป้าที่อยู่ใกล้แนวยิงภายใน 3 สตัดก่อนจุดที่กระสุนหยุด (นับเป็นโดนลำตัว)
	local forgiven = nil
	if not (result and characterOf(result.Instance)) then
		local candidates = {}
		local function add(model)
			local r = model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart
			if r and model ~= character then
				candidates[#candidates + 1] = { model = model, position = r.Position, pad = model:GetAttribute("WOLD_HitPad") }
			end
		end
		for _, m in ipairs(CollectionService:GetTagged("WOLD_Mob")) do add(m) end
		for _, m in ipairs(CollectionService:GetTagged("WOLD_Dummy")) do add(m) end
		for _, p in ipairs(Players:GetPlayers()) do if p.Character then add(p.Character) end end
		local pick = RayThrough.NearestNear(muzzle, forward, (endPoint - muzzle).Magnitude, candidates, 3)
		forgiven = pick and pick.model
	end
```

Then replace `if not result then return end` / `local model = characterOf(result.Instance)` / `local head = ...` with:

```lua
	local model = forgiven or (result and characterOf(result.Instance))
	if not model then return end
	local head = (not forgiven) and headOwner(result.Instance) == model
```

(`passThrough`'s friendly/dead skip still applies because the existing friendly/party/invulnerable checks below run on `model`.)
- [ ] **Step 8: Syntax check** PlayerCombat.server.lua, CombatConfig.lua and RayThrough.lua. Expected: OK.
- [ ] **Step 9: Commit** `"Sniper: 500-stud reach, passes through foliage/markers, forgives a 3-stud miss"`.

### Task 7: Map phases stop eating the guild prompt and stop building on top of Castle

**Files:**
- Modify: `mapgen/60_npc_setup.lua:65`
- Modify: `mapgen/100_arena_maps.lua:48,56`

- [ ] **Step 1:** Add `GuildPrompt = true` to `LIVE_PROMPTS`.
- [ ] **Step 2:** Move the Foundry/Cistern origins clear of Castle `(0,500,0)`, to `Vector3.new(8000, 500, 0)` and `Vector3.new(12000, 500, 0)`. The test `arena_config_test` requires >1000 studs between map origins.
- [ ] **Step 3: Run** `WOLD_PLACE=134798670267276 node tools/lua.js tests/arena_config_test.lua Edit`. Expected: 0 fail.
- [ ] **Step 4: Commit** `"mapgen: keep GuildPrompt; old arena maps no longer overlap Castle"`.

### Task 8: Crafting locks per machine and survives a rejoin

**Files:**
- Modify: `src/ServerScriptService/Crafting.server.lua` (`stationKeyOf` :104, `OpenAt` :297-303, job start :438-468, rejoin :656-672, and wherever `Busy[player][key] = nil` is cleared)

**Interfaces:**
- Produces: the lock key `station .. "@" .. machineId`, where `machineId = model:GetAttribute("Uid")` or the uid of its nearest ancestor with a `Uid`, else `model:GetFullName()`. Jobs store `job.lock = key`.

- [ ] **Step 1:** Replace `stationKeyOf(station)` with `lockKeyOf(player)`:

```lua
-- ล็อกรายเครื่อง ไม่ใช่รายชนิด (QA 2026-09-26): เตาสองใบคือสองงานขนานได้ · ช่างตีเหล็ก = "smith"
local function lockKeyOf(player)
	local src = Source[player]
	if not (src and src.station) then return "smith" end
	local model, uid = src.model, nil
	local at = model
	while at and at ~= workspace and not uid do uid = at:GetAttribute("Uid"); at = at.Parent end
	return src.station .. "@" .. (uid or (model and model:GetFullName()) or "?")
end
```

Update every `stationKeyOf(station)` call to `lockKeyOf(player)` (grep for it: :272 and :439).
- [ ] **Step 2:** At job creation add `lock = key,` to the `job` table.
- [ ] **Step 3: Rebuild locks on rejoin.** In the rejoin `PlayerJoin.Each`, before `task.delay(...)` for each valid job add:

```lua
				if type(job.lock) == "string" then
					Busy[player] = Busy[player] or {}
					local left = math.max(0, (tonumber(job.readyAt) or 0) - os.time())
					Busy[player][job.lock] = { finishAt = os.clock() + left, seconds = left }
				end
```

and inside its delay callback, after `resolveJob(...)`, clear it: `if Busy[player] and job.lock then Busy[player][job.lock] = nil end`.
- [ ] **Step 4: Syntax check.** Expected: OK.
- [ ] **Step 5: Commit** `"Crafting: lock per machine and keep the lock across a rejoin"`.

### Task 9: Pet wander loops stop on detach; one loop per attach

**Files:**
- Modify: `src/ServerScriptService/BeastGait.lua:54-67`

- [ ] **Step 1:** Keep the gait table in a local (`local gait = { ... }; Gaits[model] = gait`) and change the wander loop condition to `while model.Parent and humanoid.Health > 0 and Gaits[model] == gait do`, also checking right after `task.wait(...)`: `if Gaits[model] ~= gait then break end`.
- [ ] **Step 2: Syntax check.** Run `tests/island_pets_test.lua` on the farming place. Expected: 0 fail.
- [ ] **Step 3: Commit** `"BeastGait: wander loop ends on detach so carry/drop does not stack loops"`.

### Task 10: AddItem gives each slot its own meta copy

**Files:**
- Modify: `src/ServerScriptService/Inventory.lua:241`

- [ ] **Step 1:** Change `meta = meta,` to `meta = meta and table.clone(meta) or nil,` and keep the comment.
- [ ] **Step 2: Syntax check.** Expected: OK.
- [ ] **Step 3: Commit** `"Inventory: each slot gets its own meta table"`.

### Task 11: Push, verify, document

- [ ] **Step 1:** `node tools/syntax.js` for every touched Luau file on its place. Expected: all OK.
- [ ] **Step 2:** Scratchpad `load_all_modules.lua` on all three places. Expected: all load (Remotes timeout is normal).
- [ ] **Step 3:** Push every touched `src/` file to each place whose project includes it (check `globIgnorePaths`), then `dump_all.lua` + `cmp.js` per place. Expected: `mismatches 0`.
- [ ] **Step 4:** Run all new and touched tests again on their places. Expected: 0 fail.
- [ ] **Step 5:** Add a short "เฟส 0 เสร็จ" note to CLAUDE.md and mark phase 0 done in the spec. Commit.
- [ ] **Step 6:** Hand the user this in-game test list:
  1. Slimes move on a phone (all 4 kinds) and skeletons/bandits don't wander randomly while chasing.
  2. Sniper at 400-500 studs and through tree leaves hits.
  3. PVP: leave mid-match and rejoin gives one row and one reward. Leave for good gives no reward.
  4. Trade with a full VIP bag works.
  5. Island: leave and rejoin keeps the random spots and their glow. Ore-zone rocks sometimes glow.
  6. Two stoves on the island cook in parallel. Leave mid-cook and rejoin, and the same stove stays locked until done.
  7. Carry a pet and put it down several times. It wanders normally, not in a frenzy.
