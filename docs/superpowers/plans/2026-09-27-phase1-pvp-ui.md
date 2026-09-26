# เฟส 1 · เก็บ UI PVP — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the PVP arena screen compact and clean: a small score bar, no silver box on the left, and no centre-screen text. Kill banners stay.

**Architecture:** Only UI modules and the arena client controller change. `ArenaHudGui` loses the silver box, the centre banner and the base shop hint, and its score bar shrinks. `ArenaShopGui` gains a short status line (`Flash`) that shows server notices while the shop is open. `ArenaController` stops driving the removed pieces. The ammo row in `AimController` moves to the bottom-left corner on its own.

**Tech Stack:** Roblox Luau UI · Edit-mode test that builds the real `ArenaHudGui`/`ArenaShopGui` and checks their tree.

**Spec:** `docs/superpowers/specs/2026-09-26-v1.5-roadmap-design.md` (section "เฟส 1")

## Global Constraints
- Arena place 134798670267276 (`arena.project.json`). The main place also carries these files (it serves them to nobody in the arena, but keep them identical).
- Kill banners (`KillBannerGui`: FIRST BLOOD / DOUBLE / TRIPLE / ACE) must stay.
- Money stays visible in the shop wallet (`ArenaShopGui.silverLabel`).
- Never press Play. Commit messages end with the Co-Authored-By line.

## Review Focus
- A notice arriving while the shop is closed ("เกราะพังแล้ว", "หยิบ X แล้ว"). Expected: nothing is drawn in the middle of the screen, and no error.
- A phone at 667x375: the score bar and alive dots don't overlap the timer or each other.
- The shop opening mid-round from base: the wallet shows the current silver immediately.

---

### Task 1: Compact score bar; remove silver box, centre banner and base shop hint

**Files:**
- Modify: `src/ReplicatedStorage/UI/ArenaHudGui.lua`
- Test: `tests/arena_hud_test.lua`

**Interfaces:**
- Produces: `ArenaHudGui:SetBanner` and `ArenaHudGui:SetShopHint` are deleted (their callers go in Task 3). `Render` no longer touches silver.

- [ ] **Step 1: Write the failing test** `tests/arena_hud_test.lua`:

```lua
-- node tools/lua.js tests/arena_hud_test.lua Edit
-- เฟส 1 (ผู้ใช้สั่ง 2026-09-26): แถบคะแนนเล็กลง · ไม่มีกล่องเงินซ้าย · ไม่มีข้อความกลางจอ · ร้านมีบรรทัดสถานะ
local function fresh(module)
	local copy = module:Clone()
	copy.Name = module.Name .. "_t" .. math.random(1, 1e9)
	copy.Parent = module.Parent
	local ok, result = pcall(require, copy)
	copy:Destroy()
	assert(ok, result)
	return result
end
local ArenaHudGui = fresh(game.ReplicatedStorage.UI.ArenaHudGui)
local out, fails = {}, 0
local function check(ok, text) out[#out + 1] = (ok and "ok   " or "FAIL ") .. text; if not ok then fails += 1 end end

local hud = ArenaHudGui.new()
local gui = hud.gui
local bar = gui:FindFirstChild("ScoreBar")
check(bar ~= nil and bar.Size.X.Offset <= 280 and bar.Size.Y.Offset <= 44, "แถบคะแนนเล็กลง (≤280x44)")
check(gui:FindFirstChild("Silver", true) == nil, "ไม่มีกล่องซิลเวอร์ซ้าย")
check(gui:FindFirstChild("Banner", true) == nil, "ไม่มีป้ายกลางจอ")
check(gui:FindFirstChild("ShopHint", true) == nil, "ไม่มีข้อความชวนเปิดร้าน")
check(hud.SetBanner == nil and hud.SetShopHint == nil, "ไม่มีทางวาดข้อความกลางจออีก")
local ok, err = pcall(function()
	hud:Render({ phase = "live", round = 2, secondsLeft = 75, wins = { A = 1, B = 0 }, silver = 1200,
		mapName = "ปราสาท", alive = true, mySide = "A", teams = { A = {}, B = {} } })
end)
check(ok, "Render ทำงานได้โดยไม่มีกล่องเงิน " .. tostring(err or ""))
gui:Destroy()

local ArenaShopGui = fresh(game.ReplicatedStorage.UI.ArenaShopGui)
local okShop, shop = pcall(ArenaShopGui.new)
check(okShop and type(shop.Flash) == "function", "ร้านมี Flash สำหรับข้อความจากเซิร์ฟเวอร์")
if okShop and shop.Flash then
	shop:Flash("ซิลเวอร์ไม่พอ", "warn")
	local status = shop.gui:FindFirstChild("Status", true)
	check(status ~= nil and status.Text == "ซิลเวอร์ไม่พอ" and status.Visible, "Flash ขึ้นในบรรทัดสถานะของร้าน")
	shop.gui:Destroy()
end
return ("%s\n%d fail(s)"):format(table.concat(out, "\n"), fails)
```

- [ ] **Step 2: Run it.** `WOLD_PLACE=134798670267276 node tools/lua.js tests/arena_hud_test.lua Edit`. Expected: several FAIL lines (bar too big, Silver/Banner/ShopHint present, no Flash).
- [ ] **Step 3: Shrink the score bar** in `ArenaHudGui.new`: bar `260x40` at `(0.5,0,0,6)` · score boxes `52x30` TextSize 20, inset 6 · timer `120x34` TextSize 20 · phase line `260x18` TextSize 14 · alive holders at `0.5 ± 140`, y 12, size `110x20`. Check the dot size in `Render` (≤16 px).
- [ ] **Step 4: Delete** the silver `TextLabel` block, the `Banner` block, the `ShopHint` builder and the functions `SetShopHint`/`SetBanner`, and the line in `Render` that writes `self.silver.Text`.
- [ ] **Step 5:** Task 2 runs the test again after `Flash` exists. For now, expect the HUD checks to pass and the shop checks to still fail.
- [ ] **Step 6: Commit** `"Arena HUD: compact score bar; no silver box, centre banner or base shop hint"`.

### Task 2: Shop status line for server notices

**Files:**
- Modify: `src/ReplicatedStorage/UI/ArenaShopGui.lua` (header area, around :210-240)

**Interfaces:**
- Produces: `ArenaShopGui:Flash(text, kind)`. `kind == "warn"` shows red, otherwise gold. It shows for 2.5 s in a `TextLabel` named `Status` in the panel header, between the title and the wallet.

- [ ] **Step 1: Add the label** after the subtitle:

```lua
	-- ข้อความสั้นจากเซิร์ฟเวอร์ (ซื้อแล้ว/ซิลเวอร์ไม่พอ/คืนเงิน) — เดิมขึ้นกลางจอ ผู้ใช้สั่งเอาออก (เฟส 1)
	self.status = label(panel, { text = "", font = Enum.Font.GothamBold, size = 18, colour = GOLD,
		align = Enum.TextXAlignment.Right, pos = UDim2.fromOffset(340, 28), dim = UDim2.fromOffset(390, 26) })
	self.status.Name = "Status"
	self.status.Visible = false
```

(Check that `label` and `GOLD` exist in the file. Use the file's own red constant for warn, or `rgb(230, 120, 112)`.)
- [ ] **Step 2: Add `Flash`** next to the other methods:

```lua
function ArenaShopGui:Flash(text, kind)
	self.status.Text = text or ""
	self.status.TextColor3 = kind == "warn" and rgb(230, 120, 112) or GOLD
	self.status.Visible = text ~= nil and text ~= ""
	local token = {}
	self.flashToken = token
	task.delay(2.5, function()
		if self.flashToken == token then self.status.Visible = false end
	end)
end
```

- [ ] **Step 3: Run** `tests/arena_hud_test.lua`. Expected: `0 fail(s)`.
- [ ] **Step 4: Commit** `"Arena shop: status line for server notices"`.

### Task 3: Controller stops drawing centre text; notices go to the shop

**Files:**
- Modify: `src/StarterPlayerScripts/ArenaController.client.lua` (`bannerFor` :413-429, state handler :440-442, :542, notice handler :553-562)

- [ ] **Step 1:** Delete `bannerFor` and the `hud:SetShopHint(...)`, `hud:SetBanner(...)` lines in the `ArenaState` handler, and `hud:SetBanner(nil)` at :542.
- [ ] **Step 2:** Replace the `ArenaNotice` handler with:

```lua
-- ข้อความสั้นจากเซิร์ฟเวอร์: ขึ้นในบรรทัดสถานะของร้านเฉพาะตอนร้านเปิด (ผู้ใช้สั่ง 2026-09-26: ไม่มีข้อความกลางจอ)
-- ร้านปิดอยู่ = ไม่วาด (เกราะพัง/หยิบของ เห็นได้จากตัวเองอยู่แล้ว)
Remotes.ArenaNotice.OnClientEvent:Connect(function(kind, text)
	if shop:IsVisible() then shop:Flash(text, kind) end
end)
```

- [ ] **Step 3:** Grep the controller for `bannerFor`, `SetBanner` and `SetShopHint`. Expected: no matches. Check that `setShopOpen(true)` calls `shop:Render(snapshot)` so the wallet shows the current silver when the shop opens. If it doesn't, add `if snapshot then shop:Render(snapshot) end` there.
- [ ] **Step 4: Syntax check** the controller. Expected: OK.
- [ ] **Step 5: Commit** `"Arena: no centre-screen text; server notices go to the shop status line"`.

### Task 4: Ammo row takes the bottom-left corner

**Files:**
- Modify: `src/StarterPlayerScripts/AimController.client.lua:221-226`

- [ ] **Step 1:** Change the arena position `UDim2.new(0, 216, 1, -150)` to `UDim2.new(0, 16, 1, -150)` and update the comment. The silver box that it followed no longer exists.
- [ ] **Step 2: Syntax check.** Expected: OK.
- [ ] **Step 3: Commit** `"Arena ammo row sits in the bottom-left corner"`.

### Task 5: Push, verify, document

- [ ] **Step 1:** Push the touched files to the arena and main places (filter by `globIgnorePaths`). Then run `dump_all.lua` + `cmp.js` on each: `mismatches 0`.
- [ ] **Step 2:** Run `load_all_modules.lua` on the arena place: all ok except the `Remotes` timeout.
- [ ] **Step 3:** Run `arena_hud_test` and `arena_config_test`: 0 fail.
- [ ] **Step 4:** Mark phase 1 done in the spec and add a CLAUDE.md line. Commit.
- [ ] **Step 5:** In-game test list for the user:
  1. The score bar is small, and the alive dots don't overlap it on a phone.
  2. There's no silver box on the left, and the ammo count sits in the bottom-left.
  3. No text appears in the middle of the screen during buy phase, at round end, or on death. FIRST BLOOD/ACE still appear.
  4. In the shop, buying shows "ซื้อ ... แล้ว" or "ซิลเวอร์ไม่พอ" in the header line, and the wallet shows the right silver.
