# เกาะฟาร์มมิ่ง ชุด A — แผนลงมือ (Island Placement Implementation Plan)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** เพลส `WOLD Farming` บูตด้วยโค้ดของเกม แล้วเจ้าของเกาะซื้อของจาก NPC มาวางบนตารางช่องละ 4 studs
(ghost เขียว/แดง หมุนได้ เก็บคืนได้ เซฟในโปรไฟล์) และหยอดเมล็ดในแปลง → รอ → เก็บเกี่ยว

**Architecture:** Phase 0 = `farming.project.json` ตัวเดียวที่ข้ามสคริปต์เกมหลักด้วย `globIgnorePaths` (ไม่ย้ายไฟล์) ·
`ServerConfig` รู้จักโหมด `Farming` จาก `game.PlaceId` · ของวาง = ไอเทม `kind="placeable"` ที่มีต้นแบบใน
`ReplicatedStorage.WOLD_Placeables` (แอตทริบิวต์ `Footprint` เป็นแหล่งเดียวของขนาด) · ตรรกะตารางเป็นโมดูล pure
`IslandGrid` ใช้ทั้งสองฝั่ง · เซิร์ฟเวอร์ `Island/IslandBuild` เป็นเจ้าของ `profile.Data.Island` และช่องที่ถูกใช้ ·
ไคลเอนต์วาด ghost + สี่เหลี่ยมต่อช่อง แล้วส่งแค่ `(slot, cx, cz, r)` · `Island/IslandPlots` ต่อปุ่มปลูก/เก็บเกี่ยวกับแปลง

**Tech Stack:** Roblox Luau · Rojo 7.7 (`%USERPROFILE%\tools\rojo\rojo.exe`) · Studio MCP ผ่าน `tools/lua.js` /
`tools/run-luau.js` / `tools/syntax.js` · ProfileStore (มีอยู่แล้ว) · modelkit (`--kit --models`)

**Spec:** `docs/superpowers/specs/2026-09-21-island-placement-design.md`

## Global Constraints

- ตอบ/คอมเมนต์ภาษาไทยตามโค้ดเบส · ห้ามเปลี่ยนชื่อ instance ใน `ServerScriptService` (ทั้งโปรเจ็ค `require(game.ServerScriptService.X)` แบบแบน)
- `default.project.json` **ห้ามแตะ** — เพลสหลักต้องเหมือนเดิม 100%
- เพลส Farming = `136992335889132` · เพลสหลัก = `88774255487951` · universe `10765335572`
- ช่อง = 4 studs · เกาะ: Center `(0, 800, 0)` R `220` Oval `0.90` (ต้องตรงกับ `mapgen/80_sky_island.lua`)
- ไอคอน placeable ทุกชิ้น `icon = ""` (⌛) · `sellable = false` · ราคาทั้งหมดอยู่ที่ `ShopConfig.IslandSells` ที่เดียว
- กฎ StreamingEnabled: ฝั่งไคลเอนต์ **ห้ามผูกครั้งเดียวตอนบูต** กับของที่เซิร์ฟเวอร์สร้าง — ใช้ลูปถามใหม่/`FindFirstChild` ตอนใช้
- ทดสอบใน Studio: เปิดเพลส Farming ด้วย `open-farming.bat` · เมื่อเปิด Studio สองหน้าต่าง ทุกคำสั่ง `tools/*.js` ต้องมี
  `WOLD_PLACE=136992335889132` นำหน้า (bash: `WOLD_PLACE=136992335889132 node tools/lua.js ...`)
- เข้า Play: `node tools/mcp-call.js start_stop_play '{"is_start":true}'` · ออก: `'{"is_start":false}'` · ระหว่าง Play
  ห้ามเรียก datamodel `Edit` (`syntax.js`/`run-luau.js` ต้องหยุด Play ก่อน)
- commit ทุก Task ข้อความสั้นตัวพิมพ์เล็ก + ท้ายด้วย `Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>`

---

## โครงไฟล์

| ไฟล์ | หน้าที่ |
|---|---|
| `farming.project.json` (ใหม่) · `serve-farming.bat` (ใหม่) | Phase 0 — เพลสเกาะได้โค้ดทุกอย่างยกเว้นสคริปต์เกมหลัก 21 ตัว |
| `src/ServerScriptService/ServerConfig.lua` | `IsFarm` / `Mode="Farming"` / `FarmOwnerId` / แอตทริบิวต์ `IslandMode` |
| `src/ServerScriptService/PlayerProfile.server.lua` | บนเกาะไม่อ่าน/ไม่เซฟ `Position` |
| `src/ReplicatedStorage/Remotes.lua` | `IslandPlace` `IslandPickup` |
| `src/ReplicatedStorage/IslandConfig.lua` (ใหม่) | เลขทั้งหมดของเกาะ |
| `src/ReplicatedStorage/IslandGrid.lua` (ใหม่) | ตรรกะตาราง pure — เทสได้ใน Edit |
| `src/ReplicatedStorage/ItemCatalog.lua` · `ShopConfig.lua` · `src/ServerScriptService/Shop.server.lua` | ไอเทม placeable 14 + Seed · สต็อกเกาะ |
| `mapgen/90_island_placeables.lua` (ใหม่) · `mapgen/91_island_setup.lua` (ใหม่) | ต้นแบบ 17 ตัวใน `ReplicatedStorage.WOLD_Placeables` · NPC ร้านบนเกาะ |
| `src/ServerScriptService/Island/IslandAccess.lua` · `IslandBuild.server.lua` · `IslandPlots.server.lua` (ใหม่) | เจ้าของข้อมูล/ตาราง · วาง-เก็บ · ปลูก-เก็บเกี่ยว |
| `src/ReplicatedStorage/UI/IslandBuildGui.lua` · `src/StarterPlayerScripts/IslandBuildController.client.lua` (ใหม่) · `InventoryController.client.lua` | แถบ 3 ปุ่ม · ghost + ช่องสี · ปุ่ม "วางบนเกาะ" ในกระเป๋า |
| `tests/island_grid_test.lua` · `tests/island_build_test.lua` · `tests/island_plots_test.lua` · `tests/island_client_test.lua` (ใหม่) | สคริปต์ตรวจ ยิงด้วย `tools/lua.js` |

---

### Task 1: Phase 0 — `farming.project.json` + `serve-farming.bat`

**Files:**
- Create: `farming.project.json`, `serve-farming.bat`
- Modify: `CLAUDE.md` (เพิ่มกติกา denylist 3 บรรทัด ใต้หัวข้อ "เปิดเพลสใน Studio")

**Interfaces:**
- Produces: Rojo project ที่เพลส Farming ใช้ sync (พอร์ต 34873) — Task 2 เป็นต้นไปต้องมีสิ่งนี้ถึงจะเทสในเพลสเกาะได้

- [ ] **Step 1: สร้าง `farming.project.json`** — tree เดียวกับ `default.project.json` + รายชื่อข้าม (เฉพาะ `.server.lua` **ห้ามใส่โมดูล** ใครก็ require มันได้)

```json
{
  "name": "WOLD Farming",
  "globIgnorePaths": [
    "src/ServerScriptService/AdminChest.server.lua",
    "src/ServerScriptService/AnimalHerds.server.lua",
    "src/ServerScriptService/DevTeleport.server.lua",
    "src/ServerScriptService/Fishing.server.lua",
    "src/ServerScriptService/Gathering.server.lua",
    "src/ServerScriptService/IllegalFarm.server.lua",
    "src/ServerScriptService/Leaderboards.server.lua",
    "src/ServerScriptService/Mobs.server.lua",
    "src/ServerScriptService/Quests.server.lua",
    "src/ServerScriptService/TikTokLive.server.lua",
    "src/ServerScriptService/TownBuyers.server.lua",
    "src/ServerScriptService/TownCapture.server.lua",
    "src/ServerScriptService/TownVault.server.lua",
    "src/ServerScriptService/Transformers.server.lua",
    "src/ServerScriptService/TreasureChests.server.lua",
    "src/ServerScriptService/VehicleMain.server.lua",
    "src/ServerScriptService/WorldBoss.server.lua",
    "src/ServerScriptService/WorldEvents.server.lua",
    "src/ServerScriptService/Lobby/BuildLobbyRoom.server.lua",
    "src/ServerScriptService/Lobby/LobbyServer.server.lua",
    "src/ServerScriptService/Lobby/ChannelServer.server.lua"
  ],
  "tree": {
    "$className": "DataModel",
    "ServerScriptService": { "$path": "src/ServerScriptService" },
    "ReplicatedStorage": { "$path": "src/ReplicatedStorage" },
    "StarterGui": { "$path": "src/StarterGui" },
    "StarterPlayer": {
      "$className": "StarterPlayer",
      "StarterPlayerScripts": { "$path": "src/StarterPlayerScripts" }
    }
  }
}
```

- [ ] **Step 2: สร้าง `serve-farming.bat`** (ลูป restart แบบเดียวกับ `serve-keepalive.bat` แต่พอร์ต 34873 เพื่อเปิดคู่กับเพลสหลักได้)

```bat
@echo off
REM Rojo for the WOLD Farming place, on its own port so it can run beside serve-background.bat (34872).
REM In the Farming Studio window: Rojo plugin -> port 34873 -> Connect.
cd /d "%~dp0"
start "Rojo (WOLD Farming :34873)" /min cmd /c "%~dp0serve-farming-keepalive.bat"
echo Rojo (Farming) started on port 34873 in a background window.
```

และ `serve-farming-keepalive.bat`:

```bat
@echo off
cd /d "%~dp0"
:loop
echo [%date% %time%] starting rojo serve farming.project.json --port 34873 ...
"%USERPROFILE%\tools\rojo\rojo.exe" serve farming.project.json --port 34873
echo [%date% %time%] rojo exited, restarting in 2s...
timeout /t 2 /nobreak >nul
goto loop
```

- [ ] **Step 3: ตรวจว่ารายชื่อข้ามมีผลจริงและเพลสหลักไม่เปลี่ยน**

Run (bash):
```bash
R="$USERPROFILE/tools/rojo/rojo.exe"
"$R" build farming.project.json -o "$TEMP/farm.rbxmx" && "$R" build default.project.json -o "$TEMP/main.rbxmx"
grep -c 'class="Script"' "$TEMP/main.rbxmx"; grep -c 'class="Script"' "$TEMP/farm.rbxmx"
grep -cE 'name="Name">(Mobs|VehicleMain|WorldEvents|LobbyServer)<' "$TEMP/farm.rbxmx"
grep -cE 'name="Name">(Inventory|Shop|Beds|Vitals|ServerConfig)<' "$TEMP/farm.rbxmx"
```
Expected: main นับ Script ได้ N · farm ได้ N−21 · บรรทัดที่สาม = `0` · บรรทัดที่สี่ = `5`

- [ ] **Step 4: เชื่อม Rojo กับเพลส Farming (ผู้ใช้กดเอง)** — รัน `serve-farming.bat` แล้วในหน้าต่าง Studio
"การทำฟาร์ม WOLD" เปิดปลั๊กอิน Rojo → ตั้งพอร์ต `34873` → Connect · ตรวจ:
```bash
WOLD_PLACE=136992335889132 node tools/mcp-call.js execute_luau '{"datamodel_type":"Edit","code":"return #game.ServerScriptService:GetChildren() .. \" \" .. tostring(game.ServerScriptService:FindFirstChild(\"Mobs\")) .. \" \" .. tostring(game.ServerScriptService:FindFirstChild(\"Inventory\"))"}' 2>/dev/null
```
Expected: จำนวน > 80 · `nil` · `Inventory`

- [ ] **Step 5: จดกติกาใน `CLAUDE.md`** ใต้บรรทัด `**เปิดเพลสใน Studio: ...**` เพิ่ม:
```
**Rojo ของเพลสเกาะ = `serve-farming.bat` (พอร์ต 34873, `farming.project.json`)** — ไฟล์เดียวกับเพลสหลักทั้งก้อน
ยกเว้นสคริปต์เกมหลักใน `globIgnorePaths` (denylist เฉพาะ `.server.lua` ห้ามใส่โมดูล) ⚠️ **สคริปต์เซิร์ฟเวอร์ใหม่ที่เป็นของ
เกมหลักเท่านั้น ต้องเติมชื่อลงรายการนั้นเอง** ไม่งั้นมันไปรันบนเกาะโดยดีฟอลต์
```

- [ ] **Step 6: Commit**
```bash
git add farming.project.json serve-farming.bat serve-farming-keepalive.bat CLAUDE.md
git commit -m "phase 0: the farming place gets the whole game minus its main-map scripts"
```

---

### Task 2: ตัวตนเพลส — `ServerConfig` / `PlayerProfile` / `Remotes`

**Files:**
- Modify: `src/ServerScriptService/ServerConfig.lua` (ทั้งบล็อกตัดสิน IsLobby/Mode บรรทัด 14–32)
- Modify: `src/ServerScriptService/PlayerProfile.server.lua` (`resolvedSpawnPosition` บรรทัด 147 · `savePosition` บรรทัด 153 · เทมเพลตบรรทัด ~34)
- Modify: `src/ReplicatedStorage/Remotes.lua` (ท้าย `EVENTS` หลัง `"WeatherChanged",`)

**Interfaces:**
- Produces: `ServerConfig.IsFarm: boolean` · `ServerConfig.Mode == "Farming"` · `ServerConfig.FarmOwnerId: number|nil` ·
  `workspace:GetAttribute("IslandMode") == true` บนเกาะ · `Remotes.IslandPlace` `Remotes.IslandPickup` (RemoteEvent)

- [ ] **Step 1: แก้ `ServerConfig.lua`** — แทนที่ตั้งแต่ `ServerConfig.IsLobby = game.PrivateServerId == ""` ถึง `workspace:SetAttribute("IsLobby", ...)` ด้วย:

```lua
local FarmRegistry = require(script.Parent.Lobby.FarmRegistry)

-- เพลสเกาะฟาร์มรู้ตัวจาก PlaceId ไม่ใช่จาก PrivateServerId: Studio Play ในเพลสนี้จึงเป็นเกาะเสมอโดยไม่ต้องพึ่ง
-- FORCE flag และเซิร์ฟสาธารณะของเพลสนี้ (ถ้ามีใครหลงเข้ามา) ก็ไม่กลายเป็นล็อบบี้
ServerConfig.IsFarm = game.PlaceId == ServerConfig.FarmingPlaceId

ServerConfig.IsLobby = game.PrivateServerId == "" and not ServerConfig.IsFarm
if FORCE_CHANNEL_IN_STUDIO_FOR_TESTING and game:GetService("RunService"):IsStudio() then
	ServerConfig.IsLobby = false
end
if ServerConfig.IsFarm then
	ServerConfig.Mode = "Farming"
	-- nil ใน Studio (ไม่มี Reserved Server) → IslandBuild ให้คนแรกที่เข้าเป็นเจ้าของ · nil ในเซิร์ฟจริง = ไม่ได้มาจากล็อบบี้
	ServerConfig.FarmOwnerId = FarmRegistry.OwnerOfServer(game.PrivateServerId)
	ServerConfig.Channel = ServerConfig.FarmOwnerId or 0
elseif ServerConfig.IsLobby then
	ServerConfig.Mode = nil
	ServerConfig.Channel = nil
elseif FORCE_CHANNEL_IN_STUDIO_FOR_TESTING and game:GetService("RunService"):IsStudio() then
	-- There is no reserved server behind this fake channel, so skip the registry lookup it would fail.
	ServerConfig.Mode, ServerConfig.Channel = "Studio", 0
else
	ServerConfig.Mode, ServerConfig.Channel = ChannelRegistry.IdentifySelf()
end

-- ไคลเอนต์อ่านสองบิตนี้จาก Workspace (PrivateServerId/PlaceId ฝั่งไคลเอนต์เชื่อไม่ได้) — IslandMode ต้องมาก่อน IsLobby
-- เพราะทุก LocalScript รอ IsLobby แล้วอ่าน IslandMode ทันที ถ้ากลับลำดับจะได้ nil ชั่วขณะ
workspace:SetAttribute("IslandMode", ServerConfig.IsFarm)
workspace:SetAttribute("IsLobby", ServerConfig.IsLobby)
```
(คงบรรทัด `local ChannelRegistry = require(...)` และ `print` ท้ายไฟล์ไว้ตามเดิม)

- [ ] **Step 2: แก้ `PlayerProfile.server.lua`**

ใน `ProfileTemplate` เพิ่มบรรทัดเอกสาร (ไม่ใส่คีย์จริง — nil ในเทมเพลตคือ nil อยู่แล้ว) ใต้ `Vehicles = nil,`:
```lua
	-- ของบนเกาะฟาร์ม {starter, placed = {{uid,id,x,z,r,crop?,at?}}, nextUid} | nil — Island/IslandBuild เขียนตรง
	-- เข้าตารางเหมือน Vehicles (ไม่มี serializer) ดู docs/superpowers/specs/2026-09-21-island-placement-design.md
```
แทน `resolvedSpawnPosition` และ `savePosition`:
```lua
local function resolvedSpawnPosition(profile)
	-- บนเกาะ พิกัดที่เซฟไว้เป็นของเมืองหลัก ซึ่งบนเกาะคือกลางอากาศ → ใช้ SpawnLocation ของเกาะเสมอ
	if ServerConfig.IsFarm then return SpawnSelector.ResolvePosition(nil) end
	local saved = profile.Data.Position
	local savedVector = saved and Vector3.new(saved.x, saved.y, saved.z)
	return SpawnSelector.ResolvePosition(savedVector)
end

local function savePosition(player)
	-- พิกัดเกมหลักในโปรไฟล์ต้องรอดข้ามการไปเกาะ ไม่งั้นกลับเมืองแล้วโผล่ที่ (0, 817, 0) ของเกาะ
	if ServerConfig.IsFarm then return end
	local profile = Profiles[player]
	local character = player.Character
	local hrp = character and character:FindFirstChild("HumanoidRootPart")
	if not profile or not hrp then return end
	local p = hrp.Position
	profile.Data.Position = { x = p.X, y = p.Y, z = p.Z }
end
```

- [ ] **Step 3: แก้ `Remotes.lua`** — หลัง `"WeatherChanged",` เพิ่ม:
```lua
	-- เกาะฟาร์ม: วาง (slot, cx, cz, r) เข้า → ตอบกลับทางเดียวกัน (ok, remaining) · เก็บ (uid) เข้า
	"IslandPlace", "IslandPickup",
```

- [ ] **Step 4: ตรวจ syntax + ตรวจในเพลสเกาะ** (Rojo ของเกาะต่ออยู่ · Studio อยู่ใน Edit)
```bash
WOLD_PLACE=136992335889132 node tools/syntax.js src/ServerScriptService/ServerConfig.lua src/ServerScriptService/PlayerProfile.server.lua src/ReplicatedStorage/Remotes.lua
WOLD_PLACE=136992335889132 node tools/mcp-call.js start_stop_play '{"is_start":true}'
```
รอ ~10 วิ แล้ว:
```bash
cat > tests/island_boot_test.lua <<'EOF'
-- Play ในเพลส Farming → node tools/lua.js tests/island_boot_test.lua Server
local ServerConfig = require(game.ServerScriptService.ServerConfig)
assert(ServerConfig.IsFarm == true, "IsFarm")
assert(ServerConfig.Mode == "Farming", "Mode=" .. tostring(ServerConfig.Mode))
assert(ServerConfig.IsLobby == false, "IsLobby")
assert(workspace:GetAttribute("IslandMode") == true, "IslandMode attr")
assert(game.ReplicatedStorage.Remotes:FindFirstChild("IslandPlace"), "IslandPlace remote")
local p = game.Players:GetPlayers()[1]
local hrp = p and p.Character and p.Character:FindFirstChild("HumanoidRootPart")
assert(hrp and (hrp.Position - Vector3.new(0, 820, 0)).Magnitude < 30, "spawned on the island: " .. tostring(hrp and hrp.Position))
return "boot ok, owner=" .. tostring(ServerConfig.FarmOwnerId)
EOF
WOLD_PLACE=136992335889132 node tools/lua.js tests/island_boot_test.lua Server
WOLD_PLACE=136992335889132 node tools/mcp-call.js get_console_output '{}' 2>/dev/null | grep -iE "error|\[WOLD\]" | head
WOLD_PLACE=136992335889132 node tools/mcp-call.js start_stop_play '{"is_start":false}'
```
Expected: `boot ok, owner=nil` · บรรทัด `[WOLD] ... ช่อง 0` · ไม่มี error จาก `ServerConfig`/`PlayerProfile` (error จากระบบอื่นที่ยังไม่มีแท็กบนเกาะ ให้จดไว้ แก้ใน Task 9)

- [ ] **Step 5: Commit**
```bash
git add src/ServerScriptService/ServerConfig.lua src/ServerScriptService/PlayerProfile.server.lua src/ReplicatedStorage/Remotes.lua tests/island_boot_test.lua
git commit -m "the farming place knows it is an island, and does not drop you at main-map coordinates"
```

---

### Task 3: `IslandConfig` + `IslandGrid` (ตรรกะตาราง pure, TDD)

**Files:**
- Create: `src/ReplicatedStorage/IslandConfig.lua`, `src/ReplicatedStorage/IslandGrid.lua`, `tests/island_grid_test.lua`

**Interfaces:**
- Produces (ทุกฝั่ง require ได้):
  - `IslandConfig.Cell=4 · Center: Vector3 · Radius · Oval · EdgeMargin · NoBuild = {spawn=16, npc=12} · MaxPlaced=300 · StarterKit · SeedItem · Crops · Stages · MinCallGap`
  - `IslandGrid.cellOf(wx, wz) -> cx, cz` · `worldOf(cx, cz) -> wx, wz` (กึ่งกลางช่อง) · `key(cx, cz) -> "cx,cz"` ·
    `footprintOf(w, d, r) -> fw, fd` · `cellsOf(x, z, w, d, r) -> {key...}` · `inBounds(cx, cz) -> bool` ·
    `blocked(cx, cz, zones) -> bool` (zones = `{ {x, z, radius}... }` พิกัดโลก) ·
    `canPlace(occupied, zones, x, z, w, d, r) -> ok, reason` (reason ∈ `"edge" | "blocked" | "occupied"`) ·
    `pivotFor(x, z, w, d, r, groundY) -> CFrame` · `centreOf(x, z, w, d, r) -> wx, wz` · `anchorFor(wx, wz, w, d, r) -> cx, cz`

- [ ] **Step 1: เขียนเทสก่อน** `tests/island_grid_test.lua`
```lua
-- Edit mode → node tools/lua.js tests/island_grid_test.lua
-- โคลนโมดูลก่อน require: require ใน Edit แคชข้ามคำสั่ง (บทเรียน CLAUDE.md) ตัวโคลนคอมไพล์ Source ปัจจุบันเสมอ
local RS = game.ReplicatedStorage
local src = RS:FindFirstChild("IslandGrid")
assert(src, "IslandGrid ไม่อยู่ใน ReplicatedStorage (Rojo ยังไม่ sync?)")
local clone = src:Clone(); clone.Name = "IslandGrid_Test"; clone.Parent = RS
local G = require(clone)
local C = require(RS.IslandConfig)
local function eq(a, b, msg) if a ~= b then error(("%s: got %s want %s"):format(msg, tostring(a), tostring(b))) end end

local cx, cz = G.cellOf(C.Center.X + 2, C.Center.Z + 2); eq(cx, 0, "cellOf x"); eq(cz, 0, "cellOf z")
local wx, wz = G.worldOf(0, 0); eq(wx, C.Center.X + 2, "worldOf x"); eq(wz, C.Center.Z + 2, "worldOf z")
cx, cz = G.cellOf(C.Center.X - 1, C.Center.Z - 5); eq(cx, -1, "neg x"); eq(cz, -2, "neg z")

local w, d = G.footprintOf(2, 1, 1); eq(w, 1, "rot1 w"); eq(d, 2, "rot1 d")
w, d = G.footprintOf(2, 1, 2); eq(w, 2, "rot2 w"); eq(d, 1, "rot2 d")

local cells = G.cellsOf(3, 4, 2, 1, 0); eq(#cells, 2, "cells n"); eq(cells[1], "3,4", "c1"); eq(cells[2], "4,4", "c2")
cells = G.cellsOf(3, 4, 2, 1, 1); eq(#cells, 2, "cells rot n"); eq(cells[2], "3,5", "c2 rot")

assert(G.inBounds(0, 0), "centre in bounds")
assert(not G.inBounds(60, 0), "x=242 studs out")
assert(not G.inBounds(0, 50), "z=202 studs out (oval)")

local occ = {}
local ok, why = G.canPlace(occ, {}, 10, 10, 2, 2, 0); assert(ok, "empty ok")
ok, why = G.canPlace(occ, {}, 58, 0, 2, 2, 0); eq(ok, false, "edge fails"); eq(why, "edge", "edge reason")
ok, why = G.canPlace(occ, { { x = C.Center.X + 2, z = C.Center.Z + 2, radius = 16 } }, 0, 0, 1, 1, 0); eq(why, "blocked", "blocked reason")
occ["11,11"] = 7
ok, why = G.canPlace(occ, {}, 10, 10, 2, 2, 0); eq(why, "occupied", "occupied reason")
ok = G.canPlace(occ, {}, 12, 12, 2, 2, 0); assert(ok, "beside ok")

local p = G.pivotFor(0, 0, 2, 2, 0, 800)
eq(p.Position.X, C.Center.X + 4, "pivot x"); eq(p.Position.Z, C.Center.Z + 4, "pivot z"); eq(p.Position.Y, 800, "pivot y")
local p1 = G.pivotFor(0, 0, 2, 1, 1, 800) -- หมุนแล้วกิน 1x2 กึ่งกลางอยู่ที่ (+2, +4)
eq(p1.Position.X, C.Center.X + 2, "pivot rot x"); eq(p1.Position.Z, C.Center.Z + 4, "pivot rot z")

local ax, az = G.anchorFor(C.Center.X + 4, C.Center.Z + 4, 2, 2, 0); eq(ax, 0, "anchor x"); eq(az, 0, "anchor z")
ax, az = G.anchorFor(C.Center.X + 2, C.Center.Z + 2, 1, 1, 0); eq(ax, 0, "anchor1 x"); eq(az, 0, "anchor1 z")
ax, az = G.anchorFor(C.Center.X + 4.1, C.Center.Z + 2, 1, 1, 0); eq(ax, 1, "anchor next cell")

clone:Destroy()
return "IslandGrid: all checks passed"
```

- [ ] **Step 2: รันให้เห็นว่าล้ม** (Studio ใน Edit)
```bash
WOLD_PLACE=136992335889132 node tools/lua.js tests/island_grid_test.lua
```
Expected: `IslandGrid ไม่อยู่ใน ReplicatedStorage`

- [ ] **Step 3: เขียน `src/ReplicatedStorage/IslandConfig.lua`**
```lua
-- IslandConfig: เลขทั้งหมดของเกาะฟาร์ม อ่านได้ทั้งสองฝั่ง — ตัวเลขทุกตัว Claude ตั้งไว้ก่อน (2026-09-22) ผู้ใช้ยังไม่ได้กำหนด
local IslandConfig = {}

IslandConfig.Cell = 4 -- ช่องละ 4 studs = วอกเซล Terrain ของ Roblox พอดี

-- ⚠️ สามค่านี้ต้องตรงกับ ORIGIN / R / OVAL ใน mapgen/80_sky_island.lua แก้ที่โน่นต้องแก้ที่นี่
IslandConfig.Center = Vector3.new(0, 800, 0)
IslandConfig.Radius = 220
IslandConfig.Oval = 0.90
IslandConfig.EdgeMargin = 24 -- ห่างขอบหน้าผาอย่างน้อยเท่านี้ (studs)

-- วงห้ามวาง อ่านตำแหน่งจริงตอนใช้: spawn = SpawnLocation · npc = ทุกโมเดลที่ติดแท็ก WOLD_Npc
IslandConfig.NoBuild = { spawn = 16, npc = 12 }

IslandConfig.MaxPlaced = 300 -- กันเซิร์ฟส่วนตัวหนัก
IslandConfig.MinCallGap = 0.2 -- วินาที ระหว่างคำขอวาง/เก็บของคนเดียวกัน

-- เข้าเกาะครั้งแรกได้ชุดนี้ใส่กระเป๋า (ไม่วางให้ ผู้เล่นวางเองตั้งแต่ชิ้นแรก) เมล็ด 5 = พืชรอบแรกฟรี
IslandConfig.StarterKit = {
	{ id = "House_StoneCottage", count = 1 },
	{ id = "FarmPlot", count = 9 },
	{ id = "Deco_Fence", count = 10 },
	{ id = "Seed", count = 5 },
}

IslandConfig.SeedItem = "Seed"
-- หยอดเมล็ดแล้วสุ่มพืชตามน้ำหนัก · seconds = เวลาจนสุก (นับจาก os.time จึงโตต่อตอนออฟไลน์) · ได้ min-max ชิ้น
IslandConfig.Crops = {
	{ item = "Wheat", weight = 50, seconds = 10 * 60, min = 3, max = 5 },
	{ item = "Vegetable", weight = 35, seconds = 15 * 60, min = 2, max = 4 },
	{ item = "Herb", weight = 15, seconds = 20 * 60, min = 2, max = 3 },
}
-- ระยะการโต: สัดส่วนเวลา → สเกลของโมเดลพืช (ระยะสุดท้าย = สุก)
IslandConfig.Stages = {
	{ at = 0, scale = 0.35 },
	{ at = 0.5, scale = 0.7 },
	{ at = 1, scale = 1 },
}

return IslandConfig
```

- [ ] **Step 4: เขียน `src/ReplicatedStorage/IslandGrid.lua`**
```lua
-- IslandGrid: ตรรกะตารางของเกาะล้วนๆ ไม่แตะ Instance — ไคลเอนต์ใช้ระบายสี ghost เซิร์ฟเวอร์ใช้ตัดสินจริง
-- ทั้งสองฝั่งต้องคิดเหมือนกันเป๊ะ จึงอยู่ไฟล์เดียว
--
-- ระบบพิกัด: ช่อง (cx, cz) เป็นจำนวนเต็ม ช่อง (0,0) คือช่องที่มุมล่างซ้ายแตะ Center · ช่องกว้าง Cell studs
-- footprint (w, d) = จำนวนช่องตามแกน X และ Z ของโมเดลตอน r = 0 · r = 0..3 หมุนทีละ 90° · (x, z) ของชิ้นที่วาง
-- = ช่องที่ค่า cx/cz น้อยที่สุดที่มันกิน
local Config = require(script.Parent.IslandConfig)

local IslandGrid = {}
local CELL = Config.Cell

function IslandGrid.cellOf(worldX, worldZ)
	return math.floor((worldX - Config.Center.X) / CELL), math.floor((worldZ - Config.Center.Z) / CELL)
end

-- กึ่งกลางช่อง
function IslandGrid.worldOf(cx, cz)
	return Config.Center.X + (cx + 0.5) * CELL, Config.Center.Z + (cz + 0.5) * CELL
end

function IslandGrid.key(cx, cz)
	return cx .. "," .. cz
end

function IslandGrid.footprintOf(w, d, r)
	if r % 2 == 1 then return d, w end
	return w, d
end

function IslandGrid.cellsOf(x, z, w, d, r)
	local fw, fd = IslandGrid.footprintOf(w, d, r)
	local cells = {}
	for i = 0, fw - 1 do
		for j = 0, fd - 1 do
			table.insert(cells, IslandGrid.key(x + i, z + j))
		end
	end
	return cells
end

-- วงรีของเกาะ หดเข้ามาจากขอบ EdgeMargin
function IslandGrid.inBounds(cx, cz)
	local wx, wz = IslandGrid.worldOf(cx, cz)
	local dx, dz = wx - Config.Center.X, wz - Config.Center.Z
	local rx = Config.Radius - Config.EdgeMargin
	local rz = rx * Config.Oval
	return (dx * dx) / (rx * rx) + (dz * dz) / (rz * rz) <= 1
end

-- zones = { { x = worldX, z = worldZ, radius = studs }, ... }
function IslandGrid.blocked(cx, cz, zones)
	local wx, wz = IslandGrid.worldOf(cx, cz)
	for _, zone in ipairs(zones or {}) do
		local dx, dz = wx - zone.x, wz - zone.z
		if dx * dx + dz * dz < zone.radius * zone.radius then return true end
	end
	return false
end

-- occupied = { ["cx,cz"] = uid } · ตอบ ok, reason โดย reason เป็นคำสั้นๆ ให้คนเรียกแปลเป็นข้อความเอง
function IslandGrid.canPlace(occupied, zones, x, z, w, d, r)
	local fw, fd = IslandGrid.footprintOf(w, d, r)
	for i = 0, fw - 1 do
		for j = 0, fd - 1 do
			local cx, cz = x + i, z + j
			if not IslandGrid.inBounds(cx, cz) then return false, "edge" end
			if IslandGrid.blocked(cx, cz, zones) then return false, "blocked" end
			if occupied[IslandGrid.key(cx, cz)] then return false, "occupied" end
		end
	end
	return true
end

-- กึ่งกลาง footprint ในพิกัดโลก (ต้นแบบมี pivot ที่กึ่งกลางฐาน จึงวางที่นี่ได้ตรงๆ)
function IslandGrid.centreOf(x, z, w, d, r)
	local fw, fd = IslandGrid.footprintOf(w, d, r)
	return Config.Center.X + (x + fw / 2) * CELL, Config.Center.Z + (z + fd / 2) * CELL
end

function IslandGrid.pivotFor(x, z, w, d, r, groundY)
	local wx, wz = IslandGrid.centreOf(x, z, w, d, r)
	return CFrame.new(wx, groundY, wz) * CFrame.Angles(0, r * math.pi / 2, 0)
end

-- ช่องมุมที่ทำให้กึ่งกลาง footprint อยู่ใต้ตัวชี้ (ghost ตามเมาส์ด้วยกึ่งกลาง ไม่ใช่มุม)
function IslandGrid.anchorFor(worldX, worldZ, w, d, r)
	local fw, fd = IslandGrid.footprintOf(w, d, r)
	local cx = math.floor((worldX - Config.Center.X) / CELL - fw / 2 + 0.5)
	local cz = math.floor((worldZ - Config.Center.Z) / CELL - fd / 2 + 0.5)
	return cx, cz
end

return IslandGrid
```

- [ ] **Step 5: รันเทสให้ผ่าน** (รอ Rojo sync ~2 วิ)
```bash
WOLD_PLACE=136992335889132 node tools/lua.js tests/island_grid_test.lua
```
Expected: `IslandGrid: all checks passed`

- [ ] **Step 6: Commit**
```bash
git add src/ReplicatedStorage/IslandConfig.lua src/ReplicatedStorage/IslandGrid.lua tests/island_grid_test.lua
git commit -m "island grid: the arithmetic of cells, footprints and rotation, tested on its own"
```

---

### Task 4: ไอเทม placeable + เมล็ด + สต็อกร้านบนเกาะ

**Files:**
- Modify: `src/ReplicatedStorage/ItemCatalog.lua` (ท้ายตาราง `Items` หลัง `Aura_Divine = {...},` ก่อน `}` ปิด)
- Modify: `src/ReplicatedStorage/ShopConfig.lua` (หลัง `ShopConfig.Sells = {...}`)
- Modify: `src/ServerScriptService/Shop.server.lua:143` และ `:212`

**Interfaces:**
- Produces: item ids `FarmPlot Deco_Fence Deco_Lamp Deco_Bench Deco_FlowerPot Deco_Tree Deco_Crate Deco_Barrel Deco_PathTile House_StoneCottage House_Longhouse House_PipeWorker House_Roundhouse House_Townhouse` (`kind="placeable"`, `FarmPlot.plot = true`) · `Seed` (`kind="junk"`) · `ShopConfig.IslandSells`

- [ ] **Step 1: เพิ่มไอเทมใน `ItemCatalog.Items`** (ก่อน `}` ที่ปิดตาราง หลัง `Aura_Divine`)
```lua

	--------------------------------------------------------------------------
	-- ของวางบนเกาะฟาร์ม (2026-09-22) — `kind = "placeable"` ทุกชิ้น
	--
	-- ขนาดเป็นช่อง (Footprint) อยู่บนต้นแบบใน ReplicatedStorage.WOLD_Placeables ไม่ใช่ที่นี่ (คำนวณจากกล่องจริง
	-- ตอนสร้าง — mapgen/90_island_placeables.lua) · icon = "" = ⌛ จนกว่าจะมีรูปจริง · ขายคืนไม่ได้ ·
	-- `plot = true` = แปลงปลูก (Island/IslandPlots ต่อปุ่มให้) · ราคาอยู่ที่ ShopConfig.IslandSells
	FarmPlot = { icon = "", name = "แปลงดิน", kind = "placeable", weight = 2, stackSize = 10, value = 0, sellable = false, plot = true },
	Deco_Fence = { icon = "", name = "รั้วไม้", kind = "placeable", weight = 1, stackSize = 20, value = 0, sellable = false },
	Deco_Lamp = { icon = "", name = "โคมไฟไอน้ำ", kind = "placeable", weight = 1, stackSize = 10, value = 0, sellable = false },
	Deco_Bench = { icon = "", name = "ม้านั่ง", kind = "placeable", weight = 1, stackSize = 5, value = 0, sellable = false },
	Deco_FlowerPot = { icon = "", name = "กระถางดอกไม้", kind = "placeable", weight = 1, stackSize = 10, value = 0, sellable = false },
	Deco_Tree = { icon = "", name = "ต้นไม้", kind = "placeable", weight = 2, stackSize = 5, value = 0, sellable = false },
	Deco_Crate = { icon = "", name = "ลังไม้", kind = "placeable", weight = 1, stackSize = 10, value = 0, sellable = false },
	Deco_Barrel = { icon = "", name = "ถังไม้", kind = "placeable", weight = 1, stackSize = 10, value = 0, sellable = false },
	Deco_PathTile = { icon = "", name = "แผ่นทางเดินหิน", kind = "placeable", weight = 0.5, stackSize = 50, value = 0, sellable = false },
	House_StoneCottage = { icon = "", name = "กระท่อมหิน", kind = "placeable", weight = 2, stackSize = 1, value = 0, sellable = false },
	House_Roundhouse = { icon = "", name = "บ้านทรงกลม", kind = "placeable", weight = 2, stackSize = 1, value = 0, sellable = false },
	House_Longhouse = { icon = "", name = "บ้านยาว", kind = "placeable", weight = 2, stackSize = 1, value = 0, sellable = false },
	House_PipeWorker = { icon = "", name = "บ้านช่างท่อ", kind = "placeable", weight = 2, stackSize = 1, value = 0, sellable = false },
	House_Townhouse = { icon = "", name = "ทาวน์เฮาส์", kind = "placeable", weight = 2, stackSize = 1, value = 0, sellable = false },
	-- เมล็ดพันธุ์ชนิดเดียว หยอดแล้วค่อยรู้ว่าเป็นอะไร (IslandConfig.Crops) — ไม่ใช่ placeable
	Seed = { icon = "", name = "เมล็ดพันธุ์", kind = "junk", weight = 0.05, stackSize = 99, value = 0, sellable = false },
```

- [ ] **Step 2: เพิ่ม `ShopConfig.IslandSells`** (หลังตาราง `Sells`)
```lua
-- ร้านบนเกาะฟาร์ม — Shop.server เลือกตารางนี้เมื่อ ServerConfig.Mode == "Farming" (สต็อกเกมหลักไม่เปลี่ยน)
-- ราคาทั้งหมด Claude ตั้งไว้ก่อน ผู้ใช้ยังไม่ได้กำหนด (2026-09-22)
ShopConfig.IslandSells = {
	{ id = "Seed", price = 50 },
	{ id = "FarmPlot", price = 300 },
	{ id = "Deco_Fence", price = 50 },
	{ id = "Deco_PathTile", price = 30 },
	{ id = "Deco_FlowerPot", price = 150 },
	{ id = "Deco_Crate", price = 200 },
	{ id = "Deco_Barrel", price = 200 },
	{ id = "Deco_Bench", price = 350 },
	{ id = "Deco_Lamp", price = 400 },
	{ id = "Deco_Tree", price = 600 },
	{ id = "House_StoneCottage", price = 20000 },
	{ id = "House_Roundhouse", price = 25000 },
	{ id = "House_Longhouse", price = 30000 },
	{ id = "House_PipeWorker", price = 40000 },
	{ id = "House_Townhouse", price = 50000 },
}
```

- [ ] **Step 3: `Shop.server.lua` เลือกสต็อกตามโหมด** — ใต้ `local MAX_BUY = 999` เพิ่ม:
```lua
-- บนเกาะฟาร์มขายของวาง ไม่ใช่เครื่องมือ — ตารางเดียวที่ต่างกัน ที่เหลือ (ระยะ ราคารับซื้อ) เหมือนร้านเมืองหลัก
local SELLS = ServerConfig.Mode == "Farming" and ShopConfig.IslandSells or ShopConfig.Sells
```
แล้วแทน `ShopConfig.Sells` ทั้งสองจุด (บรรทัด `for index, entry in ipairs(ShopConfig.Sells) do` และ `local entry = ShopConfig.Sells[index]`) ด้วย `SELLS`

- [ ] **Step 4: ตรวจ** (Edit mode)
```bash
WOLD_PLACE=136992335889132 node tools/syntax.js src/ReplicatedStorage/ItemCatalog.lua src/ReplicatedStorage/ShopConfig.lua src/ServerScriptService/Shop.server.lua
cat > "$TEMP/cat_check.lua" <<'EOF'
local RS = game.ReplicatedStorage
local c = RS.ItemCatalog:Clone(); c.Name = "ItemCatalog_Test"; c.Parent = RS -- ต้องอยู่ที่เดิม: มัน require script.Parent.CraftConfig/ShopConfig
local IC = require(c)
local s = RS.ShopConfig:Clone(); s.Name = "ShopConfig_Test"; s.Parent = RS
local SC = require(s)
assert(IC.Get("FarmPlot").kind == "placeable" and IC.Get("FarmPlot").plot == true, "FarmPlot")
assert(IC.Get("Seed").kind == "junk" and not IC.IsSellable("Seed"), "Seed")
for _, e in ipairs(SC.IslandSells) do assert(IC.Exists(e.id), "IslandSells has unknown id " .. e.id) end
assert(IC.StackSize("Deco_Fence") == 20, "fence stack")
c:Destroy(); s:Destroy()
return #SC.IslandSells .. " island stock entries ok"
EOF
WOLD_PLACE=136992335889132 node tools/lua.js "$TEMP/cat_check.lua"
```
Expected: `15 island stock entries ok`

- [ ] **Step 5: Commit**
```bash
git add src/ReplicatedStorage/ItemCatalog.lua src/ReplicatedStorage/ShopConfig.lua src/ServerScriptService/Shop.server.lua
git commit -m "fourteen things you can put on the island, one seed, and a shop that sells them there"
```

---

### Task 5: ต้นแบบ `WOLD_Placeables` + NPC ร้านบนเกาะ (mapgen 90/91)

**Files:**
- Create: `mapgen/90_island_placeables.lua`, `mapgen/91_island_setup.lua`

**Interfaces:**
- Produces: `ReplicatedStorage.WOLD_Placeables/<itemId>` 14 ตัว + `Crop_Wheat` `Crop_Vegetable` `Crop_Herb` — ทุกตัว: `PrimaryPart = Root`
  อยู่ที่กึ่งกลางฐาน (y=0) · ทุกชิ้น Anchored · แอตทริบิวต์ `Footprint: Vector2` · `FarmPlot` มีชิ้นชื่อ `Soil` ·
  `workspace.WOLD_Island.Fixed.Merchant_Barnaby` แท็ก `WOLD_Npc` `NpcKind="shop"`

- [ ] **Step 1: เขียน `mapgen/90_island_placeables.lua`**
```lua
-- 90_island_placeables.lua: ต้นแบบของวางบนเกาะฟาร์ม → ReplicatedStorage.WOLD_Placeables (ไคลเอนต์โคลนทำ ghost ได้)
--
--     WOLD_PLACE=136992335889132 node tools/run-luau.js mapgen/90_island_placeables.lua --kit --models --no-lib
--
-- กติกาทุกต้นแบบ: Root = PrimaryPart ที่ "กึ่งกลางกล่อง ระดับฐาน" (ไม่ใช่จุดกำเนิดของ modelkit เฉยๆ — บ้านหลายหลัง
-- ไม่สมมาตร) · แอตทริบิวต์ Footprint (Vector2 ช่อง) คำนวณจากกล่องจริง เป็นแหล่งเดียวของขนาด · ทุกชิ้น Anchored
-- · ไม่มี ProximityPrompt ตกแต่งของ kit ติดมา (ระบบใส่ปุ่มของมันเอง)
local RS = game:GetService("ReplicatedStorage")
local CELL = 4
local C, MAT = K.C, K.MAT

local function status(msg, done)
	local f = workspace:FindFirstChild("WOLD")
	if not f then f = Instance.new("Folder"); f.Name = "WOLD"; f.Parent = workspace end
	f:SetAttribute("Progress", msg)
	f:SetAttribute("Status", done and "done" or "running")
	print("[Placeables] " .. msg)
end

local folder = RS:FindFirstChild("WOLD_Placeables")
if folder then folder:Destroy() end
folder = Instance.new("Folder"); folder.Name = "WOLD_Placeables"; folder.Parent = RS

local function cells(studs) return math.max(1, math.ceil(studs / CELL - 0.05)) end

-- ปิดท้ายทุกต้นแบบ: ย้าย Root ไปกึ่งกลางกล่อง ตั้ง Footprint ล้างปุ่ม/สคริปต์ของ kit
local function finish(m)
	local root = m:FindFirstChild("Root")
	if not root then
		root = Instance.new("Part"); root.Name = "Root"; root.Size = Vector3.new(1, 1, 1)
		root.Transparency = 1; root.CanCollide = false; root.Anchored = true; root.Massless = true
		root.CFrame = CFrame.new(); root.Parent = m
	end
	root.CanQuery = false; root.CanTouch = false
	m.PrimaryPart = root
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("BasePart") then d.Anchored = true end
		if d:IsA("ProximityPrompt") or d:IsA("LocalScript") then d:Destroy() end
	end
	local cf, size = m:GetBoundingBox()
	root.CFrame = CFrame.new(cf.Position.X, 0, cf.Position.Z)
	m:SetAttribute("Footprint", Vector2.new(cells(size.X), cells(size.Z)))
	m.Parent = folder
	print(("[Placeables] %-20s %2dx%-2d ช่อง (%.1f x %.1f x %.1f) %d ชิ้น"):format(m.Name, cells(size.X), cells(size.Z), size.X, size.Y, size.Z, K.countParts(m)))
end

local function proto(name, fn)
	local m = Instance.new("Model"); m.Name = name
	fn(m)
	finish(m)
end

status("start")

---------------------------------------------------------------- แปลงดิน 2x2 (ชิ้น Soil ให้พืชเกาะ)
proto("FarmPlot", function(m)
	K.box(m, K.at(0, 0.3, 0), Vector3.new(7.6, 0.6, 7.6), MAT.Ground, C.soil, { name = "Soil" })
	for _, s in ipairs({ { 0, 3.8 }, { 0, -3.8 } }) do
		K.box(m, K.at(s[1], 0.45, s[2]), Vector3.new(7.9, 0.9, 0.3), MAT.Wood, C.plankDark)
	end
	for _, s in ipairs({ { 3.8, 0 }, { -3.8, 0 } }) do
		K.box(m, K.at(s[1], 0.45, s[2]), Vector3.new(0.3, 0.9, 7.9), MAT.Wood, C.plankDark)
	end
end)

---------------------------------------------------------------- รั้ว 1x1 (ทอดยาวตาม X หมุน 90° = ตาม Z)
proto("Deco_Fence", function(m)
	for _, x in ipairs({ -1.8, 1.8 }) do
		K.box(m, K.at(x, 1.6, 0), Vector3.new(0.35, 3.2, 0.35), MAT.Wood, C.plankDark)
	end
	K.box(m, K.at(0, 2.5, 0), Vector3.new(3.9, 0.3, 0.2), MAT.Wood, C.plank)
	K.box(m, K.at(0, 1.3, 0), Vector3.new(3.9, 0.3, 0.2), MAT.Wood, C.plank)
end)

---------------------------------------------------------------- โคมไฟ 1x1 · ม้านั่ง 2x1 · กระถาง 1x1
proto("Deco_Lamp", function(m) K.lampPost(m, CFrame.new(), 7, C.lamp) end)

proto("Deco_Bench", function(m)
	K.box(m, K.at(0, 1.5, 0), Vector3.new(7.4, 0.3, 1.6), MAT.Wood, C.plank)
	K.box(m, K.at(0, 2.6, -0.7), Vector3.new(7.4, 1.2, 0.25), MAT.Wood, C.plank)
	for _, x in ipairs({ -3.2, 3.2 }) do
		K.box(m, K.at(x, 0.7, 0), Vector3.new(0.4, 1.4, 1.4), MAT.Metal, C.iron)
	end
end)

proto("Deco_FlowerPot", function(m)
	K.cyl(m, K.at(0, 0.6, 0), 1.1, 1.2, MAT.Slate, C.brick)
	K.cyl(m, K.at(0, 1.3, 0), 0.95, 0.2, MAT.Ground, C.soil, { cancollide = false })
	for i, col in ipairs({ C.paintRed, C.lamp, C.white }) do
		local a = i * 2.1
		K.ball(m, K.at(math.cos(a) * 0.5, 2.0, math.sin(a) * 0.5), 0.9, MAT.Grass, col, { cancollide = false })
	end
end)

---------------------------------------------------------------- ต้นไม้ 2x2 · ลัง · ถัง · แผ่นทางเดิน
proto("Deco_Tree", function(m)
	K.cyl(m, K.at(0, 3, 0), 0.7, 6, MAT.Wood, C.wood)
	K.ball(m, K.at(0, 8, 0), 6.5, MAT.Grass, C.moss, { cancollide = false })
	K.ball(m, K.at(1.8, 6.5, 1.2), 4.2, MAT.Grass, C.grass, { cancollide = false })
	K.ball(m, K.at(-1.6, 7, -1.4), 4.6, MAT.Grass, C.moss, { cancollide = false })
end)

proto("Deco_Crate", function(m) K.crate(m, CFrame.new(), 3.2, C.oak) end)
proto("Deco_Barrel", function(m) K.barrel(m, CFrame.new(), 1.5, 3.4, C.wood) end)
proto("Deco_PathTile", function(m)
	K.box(m, K.at(0, 0.15, 0), Vector3.new(3.9, 0.3, 3.9), MAT.Cobblestone, C.stone)
end)

---------------------------------------------------------------- บ้าน 5 แบบจาก modelkit (K.place ใส่ Root ที่จุดกำเนิดให้แล้ว finish ย้ายไปกึ่งกลาง)
for _, name in ipairs({ "House_StoneCottage", "House_Roundhouse", "House_Longhouse", "House_PipeWorker", "House_Townhouse" }) do
	local m = K.place(name, folder, CFrame.new())
	if m then finish(m) else warn("[Placeables] ไม่มี builder ชื่อ " .. name) end
end

---------------------------------------------------------------- พืช 3 ชนิด (ทรงเต็มโต ระบบ ScaleTo ตามระยะ)
proto("Crop_Wheat", function(m)
	for i = 1, 9 do
		local a, r = i * 0.7, 0.8 + (i % 3) * 0.6
		K.cyl(m, K.at(math.cos(a) * r, 1.4, math.sin(a) * r), 0.12, 2.8, MAT.Grass, C.thatch, { cancollide = false })
		K.ball(m, K.at(math.cos(a) * r, 2.9, math.sin(a) * r), 0.5, MAT.Grass, C.lamp, { cancollide = false })
	end
end)
proto("Crop_Vegetable", function(m)
	for i = 1, 5 do
		local a, r = i * 1.26, i == 5 and 0 or 1.6
		K.ball(m, K.at(math.cos(a) * r, 0.9, math.sin(a) * r), 1.8, MAT.Grass, C.paintGreen, { cancollide = false })
	end
end)
proto("Crop_Herb", function(m)
	for i = 1, 7 do
		local a, r = i * 0.9, 0.6 + (i % 2) * 1.0
		K.box(m, K.at(math.cos(a) * r, 1.0, math.sin(a) * r) * K.yaw(a), Vector3.new(0.6, 2.0, 0.15), MAT.Grass, C.verdigris, { cancollide = false })
	end
end)

status(("done: %d ต้นแบบใน ReplicatedStorage.WOLD_Placeables"):format(#folder:GetChildren()), true)
```

- [ ] **Step 2: เขียน `mapgen/91_island_setup.lua`** (NPC ร้าน — ไม่สร้าง SpawnLocation มีอยู่แล้วที่ (0, 817, 0))
```lua
-- 91_island_setup.lua: ของตายตัวบนเกาะ = NPC ร้าน (บาร์นาบี) ตัวเดียว ห่างจุดเกิด 22 studs หันหน้าเข้าหาจุดเกิด
--
--     WOLD_PLACE=136992335889132 node tools/run-luau.js mapgen/91_island_setup.lua --kit --models --no-lib
--
-- รันซ้ำได้: ลบ WOLD_Island.Fixed เดิมทิ้งแล้วสร้างใหม่ (ไม่แตะ WOLD_Island.Placed ซึ่งเป็นของผู้เล่น)
local CollectionService = game:GetService("CollectionService")

local function status(msg, done)
	local f = workspace:FindFirstChild("WOLD")
	if not f then f = Instance.new("Folder"); f.Name = "WOLD"; f.Parent = workspace end
	f:SetAttribute("Progress", msg)
	f:SetAttribute("Status", done and "done" or "running")
	print("[IslandSetup] " .. msg)
end

local island = workspace:FindFirstChild("WOLD_Island")
if not island then island = Instance.new("Folder"); island.Name = "WOLD_Island"; island.Parent = workspace end
local fixed = island:FindFirstChild("Fixed")
if fixed then fixed:Destroy() end
fixed = Instance.new("Folder"); fixed.Name = "Fixed"; fixed.Parent = island

local function groundAt(x, z)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { workspace.Terrain }
	local hit = workspace:Raycast(Vector3.new(x, 900, z), Vector3.new(0, -300, 0), params)
	return hit and hit.Position.Y
end

local spawnLoc = workspace:FindFirstChildWhichIsA("SpawnLocation", true)
local sx, sz = spawnLoc and spawnLoc.Position.X or 0, spawnLoc and spawnLoc.Position.Z or 0
local nx, nz = sx, sz - 22
local ground = groundAt(nx, nz) or 817
-- โมเดลหันหน้า -Z · NPC อยู่ทางเหนือของจุดเกิด จึงหมุน 180° ให้หันมาทาง +Z (หาจุดเกิด)
local npc = K.place("Merchant_Barnaby", fixed, CFrame.new(nx, ground, nz) * K.yaw(math.pi))
assert(npc, "ไม่มี builder Merchant_Barnaby (ลืม --models?)")
for _, p in ipairs(npc:GetDescendants()) do
	if p:IsA("ProximityPrompt") then p:Destroy() end -- ปุ่มตกแต่งของ kit; Shop.server ใส่ปุ่มจริงเองตอนเห็นแท็ก
end
npc:SetAttribute("NpcKind", "shop")
npc:SetAttribute("NpcName", "บาร์นาบี")
CollectionService:AddTag(npc, "WOLD_Npc")

status(("done: บาร์นาบีที่ (%.0f, %.1f, %.0f)"):format(nx, ground, nz), true)
```

- [ ] **Step 3: รันทั้งสองเฟสในเพลส Farming** (Edit mode)
```bash
WOLD_PLACE=136992335889132 node tools/run-luau.js mapgen/90_island_placeables.lua --kit --models --no-lib
WOLD_PLACE=136992335889132 node tools/run-luau.js mapgen/91_island_setup.lua --kit --models --no-lib
```
Expected: บรรทัด `[Placeables] <ชื่อ> WxD ช่อง ...` 17 บรรทัด — FarmPlot `2x2` · Deco_Fence `1x1` · Deco_Bench `2x1` · Deco_Tree `2x2` ·
บ้านแต่ละหลัง 5–10 ต่อด้าน · `done: 17 ต้นแบบ` · เฟส 91 `done: บาร์นาบีที่ (0, ~817, -22)`

- [ ] **Step 4: ตรวจโครงต้นแบบ**
```bash
cat > "$TEMP/proto_check.lua" <<'EOF'
local f = game.ReplicatedStorage:FindFirstChild("WOLD_Placeables"); assert(f, "no folder")
local IC = require(game.ReplicatedStorage.ItemCatalog)
local n = 0
for _, m in ipairs(f:GetChildren()) do
	assert(m.PrimaryPart and m.PrimaryPart.Name == "Root", m.Name .. ": Root")
	assert(math.abs(m.PrimaryPart.Position.Y) < 0.01, m.Name .. ": Root not at base y=" .. m.PrimaryPart.Position.Y)
	local fp = m:GetAttribute("Footprint"); assert(typeof(fp) == "Vector2" and fp.X >= 1, m.Name .. ": Footprint")
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("BasePart") then assert(d.Anchored, m.Name .. "/" .. d.Name .. " not anchored") end
		assert(not d:IsA("ProximityPrompt"), m.Name .. " has a prompt")
	end
	if not m.Name:match("^Crop_") then assert(IC.Get(m.Name) and IC.Get(m.Name).kind == "placeable", m.Name .. " not in catalog") end
	n += 1
end
assert(f.FarmPlot:FindFirstChild("Soil"), "FarmPlot.Soil")
local npc = workspace.WOLD_Island.Fixed:FindFirstChild("Merchant_Barnaby")
assert(npc and npc:GetAttribute("NpcKind") == "shop" and game.CollectionService:HasTag(npc, "WOLD_Npc"), "npc tag")
return n .. " prototypes ok"
EOF
WOLD_PLACE=136992335889132 node tools/lua.js "$TEMP/proto_check.lua"
```
Expected: `17 prototypes ok`

- [ ] **Step 5: ดูภาพ** — โคลนต้นแบบทุกตัวลง workspace เรียงแถวหน้ากล้อง ถ่าย `screen_capture` แล้วลบ (วิธีตาม CLAUDE.md "วิธีทำภาพเทียบ")
ตรวจด้วยตา: ไม่มีชิ้นไหนจมดิน/ลอย · ประตูบ้านอยู่ระดับพื้น · เก็บภาพไว้ `docs/shots/island-placeables.jpg`

- [ ] **Step 6: Commit**
```bash
git add mapgen/90_island_placeables.lua mapgen/91_island_setup.lua docs/shots/island-placeables.jpg
git commit -m "seventeen prototypes for the island, each knowing how many cells it takes, and a shopkeeper to sell them"
```

---

### Task 6: เซิร์ฟเวอร์ `IslandAccess` + `IslandBuild` (วาง / เก็บ / สร้างคืน / ชุดเริ่มต้น)

**Files:**
- Create: `src/ServerScriptService/Island/IslandAccess.lua`, `src/ServerScriptService/Island/IslandBuild.server.lua`, `tests/island_build_test.lua`

**Interfaces:**
- Consumes: `IslandGrid` `IslandConfig` (Task 3) · `Remotes.IslandPlace/IslandPickup` (Task 2) · `ServerConfig.IsFarm/FarmOwnerId` ·
  `Inventory.AddItem/RemoveFromSlot/HasRoomFor/FindSlotById/CountOf/Get` · `ProfileAccess.Wait` · `PlayerJoin.Each` · ต้นแบบ (Task 5)
- Produces (`IslandAccess` — ตั้งโดย IslandBuild ทั้งหมด ยกเว้นสามตัวท้ายที่ IslandPlots ตั้งใน Task 8):
  - `IslandAccess.IsOwner(player) -> bool` · `IslandAccess.Data() -> IslandTable|nil` · `IslandAccess.EntryOf(model) -> entry|nil` ·
    `IslandAccess.ModelOf(uid) -> Model|nil` · `IslandAccess.Place(player, slotIndex, cx, cz, r) -> ok, reason` ·
    `IslandAccess.Pickup(player, uid) -> ok, reason` · `IslandAccess.FindSlot(player, id) -> index|nil` · `IslandAccess.Count(player, id) -> n`
  - reason ∈ `"notowner" | "noitem" | "noproto" | "limit" | "edge" | "blocked" | "occupied" | "full" | "growing" | "missing"`
  - โมเดลที่วางแล้ว: `workspace.WOLD_Island.Placed/<uid>` แอตทริบิวต์ `Uid ItemId CellX CellZ Rot Footprint` + ProximityPrompt ชื่อ `PickupPrompt` บน `Root`

- [ ] **Step 1: เขียน `Island/IslandAccess.lua`**
```lua
-- IslandAccess: ช่องทางระหว่างสคริปต์ของเกาะ (IslandBuild ↔ IslandPlots) และทางเข้าสำหรับสคริปต์ทดสอบ
-- ทรงเดียวกับ MobAccess: ตารางช่องว่าง เจ้าของแต่ละช่องคือสคริปต์ที่ตั้งมัน · เป็น nil นอกเพลสเกาะ ทุกคนที่เรียกต้องเช็ค
local IslandAccess = {}

-- ตั้งโดย IslandBuild
IslandAccess.IsOwner = nil -- (player) -> bool
IslandAccess.Data = nil -- () -> profile.Data.Island ของเจ้าของ หรือ nil ถ้ายังไม่โหลด
IslandAccess.EntryOf = nil -- (model) -> entry ในตาราง placed
IslandAccess.ModelOf = nil -- (uid) -> model
IslandAccess.Place = nil -- (player, slotIndex, cx, cz, r) -> ok, reason
IslandAccess.Pickup = nil -- (player, uid) -> ok, reason
IslandAccess.FindSlot = nil -- (player, itemId) -> slotIndex   (ให้สคริปต์ทดสอบ ซึ่ง require Inventory ไม่ได้)
IslandAccess.Count = nil -- (player, itemId) -> n

-- ตั้งโดย IslandPlots
IslandAccess.Plant = nil -- (player, plotModel) -> ok, reason
IslandAccess.Harvest = nil -- (player, plotModel) -> ok, reason
IslandAccess.Tick = nil -- () รันการโตหนึ่งรอบทันที

return IslandAccess
```

- [ ] **Step 2: เขียน `Island/IslandBuild.server.lua`**
```lua
-- IslandBuild: เจ้าของ "ของที่วางบนเกาะ" — ตารางช่องที่ถูกใช้ โมเดลในโลก และ profile.Data.Island ของเจ้าของเกาะ
--
-- กติกา: ไคลเอนต์ส่งแค่ (ช่องกระเป๋า, cx, cz, r) เซิร์ฟเวอร์ตรวจทุกอย่างเองแล้วตอบเหตุผลเป็นไทยผ่าน SocialNotify
-- · ไม่มี "ย้าย" (= เก็บแล้ววางใหม่) · ข้อมูลเขียนตรงเข้า Data.Island เหมือน Vehicles — ProfileStore เซฟให้เอง
local ServerConfig = require(game.ServerScriptService.ServerConfig)
if not ServerConfig.IsFarm then return end -- ไฟล์ไปเพลสหลักด้วย แต่ไม่ทำอะไรที่นั่น (ทรงเดียวกับ IsLobby gating)

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local Inventory = require(game.ServerScriptService.Inventory)
local ProfileAccess = require(game.ServerScriptService.ProfileAccess)
local PlayerJoin = require(game.ServerScriptService.PlayerJoin)
local IslandAccess = require(script.Parent.IslandAccess)
local IslandConfig = require(ReplicatedStorage.IslandConfig)
local IslandGrid = require(ReplicatedStorage.IslandGrid)
local ItemCatalog = require(ReplicatedStorage.ItemCatalog)
local Remotes = require(ReplicatedStorage.Remotes)

local REASON_TEXT = {
	notowner = "วางได้เฉพาะเจ้าของเกาะ",
	noitem = "ไม่มีของชิ้นนั้นในกระเป๋า",
	noproto = "ยังไม่มีโมเดลของของชิ้นนี้",
	limit = ("เกาะเต็มแล้ว (%d ชิ้น)"):format(IslandConfig.MaxPlaced),
	edge = "ใกล้ขอบเกาะเกินไป",
	blocked = "ตรงนี้วางไม่ได้",
	occupied = "วางทับของอื่น",
	full = "กระเป๋าเต็ม",
	growing = "เก็บเกี่ยวก่อนแล้วค่อยเก็บแปลง",
	missing = "ไม่พบของชิ้นนั้นแล้ว",
}

--------------------------------------------------------------------------------
-- สถานะ
--------------------------------------------------------------------------------

local ownerId = ServerConfig.FarmOwnerId -- nil ใน Studio → คนแรกที่เข้า
local Data = nil -- profile.Data.Island ของเจ้าของ (ตารางเดียวกับที่ ProfileStore เซฟ)
local Occupied = {} -- ["cx,cz"] = uid
local Models = {} -- [uid] = model
local Entries = {} -- [model] = entry
local LastCall = {} -- [player] = os.clock() กันสแปม

local function placedFolder()
	local island = workspace:FindFirstChild("WOLD_Island")
	if not island then island = Instance.new("Folder"); island.Name = "WOLD_Island"; island.Parent = workspace end
	local placed = island:FindFirstChild("Placed")
	if not placed then placed = Instance.new("Folder"); placed.Name = "Placed"; placed.Parent = island end
	return placed
end

local function isOwner(player)
	return ownerId ~= nil and player.UserId == ownerId
end

local function notify(player, reason)
	Remotes.SocialNotify:FireClient(player, "error", REASON_TEXT[reason] or reason)
end

-- วงห้ามวาง อ่านสดทุกครั้ง (ของน้อย ถูกกว่าการจำแล้วลืมอัปเดต)
local function noBuildZones()
	local zones = {}
	local spawnLoc = workspace:FindFirstChildWhichIsA("SpawnLocation", true)
	if spawnLoc then table.insert(zones, { x = spawnLoc.Position.X, z = spawnLoc.Position.Z, radius = IslandConfig.NoBuild.spawn }) end
	for _, npc in ipairs(CollectionService:GetTagged("WOLD_Npc")) do
		local p = npc:IsA("BasePart") and npc.Position or npc:GetPivot().Position
		table.insert(zones, { x = p.X, z = p.Z, radius = IslandConfig.NoBuild.npc })
	end
	return zones
end

-- ผิวดินจริงที่กึ่งกลาง footprint — Include เฉพาะ Terrain (บทเรียนกล่อง Zone_* ล่องหนที่เรย์ชน)
local function groundAt(wx, wz)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { workspace.Terrain }
	local hit = workspace:Raycast(Vector3.new(wx, IslandConfig.Center.Y + 80, wz), Vector3.new(0, -300, 0), params)
	return hit and hit.Position.Y or (IslandConfig.Center.Y + 17)
end

local function prototypeOf(id)
	local folder = ReplicatedStorage:FindFirstChild("WOLD_Placeables")
	return folder and folder:FindFirstChild(id)
end

local function footprintOf(proto)
	local fp = proto:GetAttribute("Footprint")
	if typeof(fp) == "Vector2" then return fp.X, fp.Y end
	return 1, 1
end

--------------------------------------------------------------------------------
-- โมเดลในโลก
--------------------------------------------------------------------------------

local function spawnEntry(entry)
	local proto = prototypeOf(entry.id)
	if not proto then
		warn(("[Island] ไม่มีต้นแบบ %s (uid %d) ข้าม"):format(tostring(entry.id), entry.uid))
		return nil
	end
	local w, d = footprintOf(proto)
	local model = proto:Clone()
	model.Name = tostring(entry.uid)
	local wx, wz = IslandGrid.centreOf(entry.x, entry.z, w, d, entry.r)
	model:PivotTo(IslandGrid.pivotFor(entry.x, entry.z, w, d, entry.r, groundAt(wx, wz)))
	model:SetAttribute("Uid", entry.uid)
	model:SetAttribute("ItemId", entry.id)
	model:SetAttribute("CellX", entry.x)
	model:SetAttribute("CellZ", entry.z)
	model:SetAttribute("Rot", entry.r)
	model:SetAttribute("Footprint", Vector2.new(w, d))

	-- ปุ่มเก็บ: F กดค้าง ครึ่งวิ กันเผลอ · E ปล่อยไว้ให้ปุ่มของแปลง (ปลูก/เก็บเกี่ยว) ในไฟล์ IslandPlots
	local item = ItemCatalog.Get(entry.id)
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "PickupPrompt"
	prompt.ActionText = "เก็บเข้ากระเป๋า"
	prompt.ObjectText = item and item.name or entry.id
	prompt.KeyboardKeyCode = Enum.KeyCode.F
	prompt.GamepadKeyCode = Enum.KeyCode.ButtonY
	prompt.HoldDuration = 0.5
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = model.PrimaryPart
	prompt.Triggered:Connect(function(player)
		local ok, reason = IslandAccess.Pickup(player, entry.uid)
		if not ok then notify(player, reason) end
	end)

	for _, key in ipairs(IslandGrid.cellsOf(entry.x, entry.z, w, d, entry.r)) do Occupied[key] = entry.uid end
	Models[entry.uid] = model
	Entries[model] = entry
	model.Parent = placedFolder()
	return model
end

local function despawnEntry(entry)
	local model = Models[entry.uid]
	if model then
		Entries[model] = nil
		model:Destroy()
	end
	Models[entry.uid] = nil
	for key, uid in pairs(Occupied) do
		if uid == entry.uid then Occupied[key] = nil end
	end
end

-- สร้างเกาะคืนจากข้อมูล — ล้างของเดิมก่อนเสมอ จึงเรียกซ้ำได้ (เจ้าของออกแล้วเข้าใหม่ = โปรไฟล์ตารางใหม่)
local function rebuild()
	for _, model in ipairs(placedFolder():GetChildren()) do model:Destroy() end
	Occupied, Models, Entries = {}, {}, {}
	if not Data then return end
	for _, entry in ipairs(Data.placed) do spawnEntry(entry) end
	print(("[Island] สร้างคืน %d ชิ้น"):format(#Data.placed))
end

--------------------------------------------------------------------------------
-- วาง / เก็บ
--------------------------------------------------------------------------------

local function rateLimited(player)
	local now = os.clock()
	if LastCall[player] and now - LastCall[player] < IslandConfig.MinCallGap then return true end
	LastCall[player] = now
	return false
end

local function place(player, slotIndex, cx, cz, r)
	if not isOwner(player) or not Data then return false, "notowner" end
	if type(slotIndex) ~= "number" or type(cx) ~= "number" or type(cz) ~= "number" then return false, "noitem" end
	cx, cz = math.floor(cx), math.floor(cz)
	r = (type(r) == "number") and (math.floor(r) % 4) or 0
	local state = Inventory.Get(player)
	local slot = state and state.slots[slotIndex]
	local item = slot and ItemCatalog.Get(slot.id)
	if not item or item.kind ~= "placeable" then return false, "noitem" end
	local proto = prototypeOf(slot.id)
	if not proto then return false, "noproto" end
	if #Data.placed >= IslandConfig.MaxPlaced then return false, "limit" end
	local w, d = footprintOf(proto)
	local ok, reason = IslandGrid.canPlace(Occupied, noBuildZones(), cx, cz, w, d, r)
	if not ok then return false, reason end
	if not Inventory.RemoveFromSlot(player, slotIndex, 1) then return false, "noitem" end

	local entry = { uid = Data.nextUid, id = slot.id, x = cx, z = cz, r = r }
	Data.nextUid += 1
	table.insert(Data.placed, entry)
	spawnEntry(entry)
	return true
end

local function pickup(player, uid)
	if not isOwner(player) or not Data then return false, "notowner" end
	local model = Models[uid]
	local entry = model and Entries[model]
	if not entry then return false, "missing" end
	if entry.crop then return false, "growing" end
	if not Inventory.HasRoomFor(player, entry.id, 1) then return false, "full" end
	if not Inventory.AddItem(player, entry.id, 1) then return false, "full" end
	for i, e in ipairs(Data.placed) do
		if e == entry then table.remove(Data.placed, i) break end
	end
	despawnEntry(entry)
	return true
end

--------------------------------------------------------------------------------
-- เจ้าของเข้ามา → โหลด → ชุดเริ่มต้น → สร้างคืน
--------------------------------------------------------------------------------

local function load(player)
	local data = ProfileAccess.Wait(player)
	if not data then return end
	data.Island = data.Island or { placed = {}, nextUid = 1 }
	data.Island.placed = data.Island.placed or {}
	data.Island.nextUid = data.Island.nextUid or 1
	Data = data.Island

	if not Data.starter then
		-- กระเป๋าโหลดหลังโปรไฟล์อีกจังหวะหนึ่ง (PlayerInventory รอ ProfileAccess เหมือนกัน) — ต้องรอให้มันมาก่อน
		-- ไม่งั้น AddItem คืน false เงียบๆ แล้วธงถูกตั้ง = ชุดเริ่มต้นหายไปตลอดกาล
		local started = os.clock()
		while not Inventory.Get(player) and player:IsDescendantOf(Players) and os.clock() - started < 30 do task.wait(0.2) end
		if Inventory.Get(player) then
			for _, kit in ipairs(IslandConfig.StarterKit) do Inventory.AddItem(player, kit.id, kit.count) end
			Data.starter = true
			print(("[Island] แจกชุดเริ่มต้นให้ %s"):format(player.Name))
		end
	end
	rebuild()
end

PlayerJoin.Each(function(player)
	if ownerId == nil then
		if RunService:IsStudio() then
			ownerId = player.UserId
			print(("[Island] Studio: %s เป็นเจ้าของเกาะ"):format(player.Name))
		else
			player:Kick("เข้าเกาะได้จากหน้าล็อบบี้เท่านั้น")
			return
		end
	end
	if not isOwner(player) then return end -- แขก (ชุด C) ยังทำอะไรไม่ได้
	load(player)
end)

Players.PlayerRemoving:Connect(function(player)
	LastCall[player] = nil
	if isOwner(player) then Data = nil end -- โปรไฟล์ปิดเซสชันแล้ว ตารางนี้เขียนต่อไม่ได้ (โมเดลปล่อยไว้ให้แขกดู)
end)

--------------------------------------------------------------------------------
-- Remote + Access
--------------------------------------------------------------------------------

Remotes.IslandPlace.OnServerEvent:Connect(function(player, slotIndex, cx, cz, r)
	if rateLimited(player) then return end
	local ok, reason = place(player, slotIndex, cx, cz, r)
	if not ok then notify(player, reason) end
	-- ตอบกลับ: ยังเหลือชิ้นเดิมในช่องนั้นกี่ชิ้น ไคลเอนต์ใช้ตัดสินว่าอยู่ในโหมดวางต่อไหม
	local state = Inventory.Get(player)
	local slot = state and state.slots[slotIndex]
	local remaining = (ok and slot and slot.count) or 0
	Remotes.IslandPlace:FireClient(player, ok == true, remaining)
end)

Remotes.IslandPickup.OnServerEvent:Connect(function(player, uid)
	if rateLimited(player) then return end
	local ok, reason = pickup(player, tonumber(uid) or -1)
	if not ok then notify(player, reason) end
end)

IslandAccess.IsOwner = isOwner
IslandAccess.Data = function() return Data end
IslandAccess.EntryOf = function(model) return Entries[model] end
IslandAccess.ModelOf = function(uid) return Models[uid] end
IslandAccess.Place = place
IslandAccess.Pickup = pickup
IslandAccess.FindSlot = Inventory.FindSlotById
IslandAccess.Count = Inventory.CountOf
```

- [ ] **Step 3: เขียนเทส `tests/island_build_test.lua`**
```lua
-- Play ในเพลส Farming → node tools/lua.js tests/island_build_test.lua Server
local Players = game:GetService("Players")
local A = require(game.ServerScriptService.Island.IslandAccess)
local G = require(game.ReplicatedStorage.IslandGrid)
local player = assert(Players:GetPlayers()[1], "ไม่มีผู้เล่นใน Play")
assert(A.IsOwner(player), "ใน Studio คนแรกต้องเป็นเจ้าของ")
local t0 = os.clock()
while not A.Data() and os.clock() - t0 < 20 do task.wait(0.2) end
local data = assert(A.Data(), "ข้อมูลเกาะไม่โหลด")
assert(data.starter == true, "ธงชุดเริ่มต้น")
local slot = assert(A.FindSlot(player, "FarmPlot"), "ไม่มี FarmPlot ในกระเป๋า")

local before = #data.placed
local ok, why = A.Place(player, slot, 10, 10, 0); assert(ok, "วางแปลง: " .. tostring(why))
assert(#data.placed == before + 1, "entry ถูกเพิ่ม")
local uid = data.placed[#data.placed].uid
local model = assert(A.ModelOf(uid), "โมเดลโผล่")
assert(model:GetAttribute("ItemId") == "FarmPlot" and model:GetAttribute("CellX") == 10, "แอตทริบิวต์")
assert(model.PrimaryPart:FindFirstChild("PickupPrompt"), "ปุ่มเก็บ")
local wx, wz = G.centreOf(10, 10, 2, 2, 0)
assert((Vector2.new(model:GetPivot().X, model:GetPivot().Z) - Vector2.new(wx, wz)).Magnitude < 0.01, "pivot ที่กึ่งกลาง footprint")
assert(math.abs(model:GetPivot().Y - 817) < 6, "อยู่บนผิวเกาะ y=" .. model:GetPivot().Y)

slot = assert(A.FindSlot(player, "FarmPlot"))
ok, why = A.Place(player, slot, 11, 11, 0); assert(not ok and why == "occupied", "ทับ: " .. tostring(why))
ok, why = A.Place(player, slot, 58, 0, 0); assert(not ok and why == "edge", "ขอบ: " .. tostring(why))
local sp = workspace:FindFirstChildWhichIsA("SpawnLocation", true)
local sx, sz = G.cellOf(sp.Position.X, sp.Position.Z)
ok, why = A.Place(player, slot, sx, sz, 0); assert(not ok and why == "blocked", "จุดเกิด: " .. tostring(why))
ok, why = A.Place(player, 99, 20, 20, 0); assert(not ok and why == "noitem", "ช่องว่าง: " .. tostring(why))

local fence = assert(A.FindSlot(player, "Deco_Fence"), "ไม่มีรั้ว")
local fenceCount = A.Count(player, "Deco_Fence")
ok, why = A.Place(player, fence, 15, 15, 1); assert(ok, "รั้วหมุน: " .. tostring(why))
assert(A.Count(player, "Deco_Fence") == fenceCount - 1, "รั้วถูกหักจากกระเป๋า")

local plotCount = A.Count(player, "FarmPlot")
ok, why = A.Pickup(player, uid); assert(ok, "เก็บ: " .. tostring(why))
assert(A.ModelOf(uid) == nil, "โมเดลหาย")
assert(A.Count(player, "FarmPlot") == plotCount + 1, "แปลงกลับเข้ากระเป๋า")
ok, why = A.Pickup(player, uid); assert(not ok and why == "missing", "เก็บซ้ำ: " .. tostring(why))
ok, why = A.Place(player, A.FindSlot(player, "FarmPlot"), 10, 10, 0); assert(ok, "วางที่เดิมได้อีกหลังเก็บ")

-- เก็บคืนทุกชิ้นที่เทสวาง (โปรไฟล์จริง) — ไล่จากท้ายเพราะ Pickup ถอดออกจาก array
for i = #data.placed, before + 1, -1 do
	local e = data.placed[i]
	assert(A.Pickup(player, e.uid), "เก็บคืน uid " .. e.uid)
end
assert(#data.placed == before, "เกาะกลับมาเท่าก่อนเทส")
return ("build ok: วางอยู่ %d ชิ้น (เท่าก่อนเทส)"):format(#data.placed)
```

- [ ] **Step 4: รัน** (Rojo sync แล้ว → Play → เทส → หยุด Play)
```bash
WOLD_PLACE=136992335889132 node tools/syntax.js src/ServerScriptService/Island/IslandAccess.lua src/ServerScriptService/Island/IslandBuild.server.lua
WOLD_PLACE=136992335889132 node tools/mcp-call.js start_stop_play '{"is_start":true}'
sleep 12
WOLD_PLACE=136992335889132 node tools/lua.js tests/island_build_test.lua Server
WOLD_PLACE=136992335889132 node tools/mcp-call.js get_console_output '{}' 2>/dev/null | grep -E "\[Island\]|IslandBuild" | head
WOLD_PLACE=136992335889132 node tools/mcp-call.js start_stop_play '{"is_start":false}'
```
Expected: `build ok: วางอยู่ N ชิ้น (เท่าก่อนเทส)` · log `[Island] Studio: ... เป็นเจ้าของเกาะ` · `[Island] แจกชุดเริ่มต้น` · `[Island] สร้างคืน 0 ชิ้น` · ไม่มี error จาก IslandBuild
⚠️ Studio Play **เขียน DataStore จริง** (เปิด "Studio Access to API Services" ไว้) — ของที่เทสวางจะอยู่ในโปรไฟล์จริงของผู้ใช้ เทสจึงต้องเก็บคืนทุกชิ้นตอนจบ (ทำแล้วในสคริปต์) และรัน Play ซ้ำได้เพราะช่องว่างกลับมา

- [ ] **Step 5: Commit**
```bash
git add src/ServerScriptService/Island/IslandAccess.lua src/ServerScriptService/Island/IslandBuild.server.lua tests/island_build_test.lua
git commit -m "the island keeps what its owner puts down, and gives it back on request"
```

---

### Task 7: ไคลเอนต์ — ghost + ช่องสี + แถบ 3 ปุ่ม + ปุ่ม "วางบนเกาะ" ในกระเป๋า

**Files:**
- Create: `src/ReplicatedStorage/UI/IslandBuildGui.lua`, `src/StarterPlayerScripts/IslandBuildController.client.lua`, `tests/island_client_test.lua`
- Modify: `src/StarterPlayerScripts/InventoryController.client.lua` (ในฟังก์ชันเมนูกดค้าง หลังสาขา `elseif item.kind == "skin" or item.kind == "fashion" then ... end`)

**Interfaces:**
- Consumes: `IslandGrid` `IslandConfig` · `Remotes.IslandPlace` (FireServer(slot, cx, cz, r) · OnClientEvent(ok, remaining)) ·
  ต้นแบบใน `ReplicatedStorage.WOLD_Placeables` · แอตทริบิวต์ `CellX CellZ Rot Footprint` บนโมเดลใน `workspace.WOLD_Island.Placed`
- Produces: BindableEvent `ReplicatedStorage.WOLD_StartPlacing` (client-only) — `Fire(slotIndex, itemId)` เริ่ม · `Fire(nil)` ยกเลิก ·
  `IslandBuildGui.new(playerGui)` → `:Show(title)` `:Hide()` `:SetStatus(text, ok)` · callback `OnRotate OnPlace OnCancel`

- [ ] **Step 1: เขียน `UI/IslandBuildGui.lua`**
```lua
-- IslandBuildGui: แถบล่างตอนอยู่ในโหมดวางของ — ชื่อของ · สถานะ (วางได้/เหตุผลที่ไม่ได้) · ปุ่ม หมุน/วาง/ยกเลิก
-- ปุ่มมีไว้ให้มือถือเป็นหลัก (คีย์บอร์ดใช้ R / คลิก / Esc ได้เหมือนกัน) จึงเป็นชุดเดียวทุกอุปกรณ์
local Responsive = require(script.Parent.Responsive)

local WIDTH, HEIGHT = 380, 74
local PANEL = Color3.fromRGB(24, 22, 28)
local TEXT = Color3.fromRGB(236, 232, 224)
local OK_COLOR = Color3.fromRGB(111, 224, 122)
local BAD_COLOR = Color3.fromRGB(255, 107, 107)
local BRASS = Color3.fromRGB(196, 150, 60)

local IslandBuildGui = {}
IslandBuildGui.__index = IslandBuildGui

local function corner(inst, px)
	local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, px or 10); c.Parent = inst
end

local function button(parent, x, label, color)
	local b = Instance.new("TextButton")
	b.Size = UDim2.new(0, 108, 0, 30)
	b.Position = UDim2.new(0, x, 1, -38)
	b.BackgroundColor3 = color
	b.BackgroundTransparency = 0.15
	b.BorderSizePixel = 0
	b.Font = Enum.Font.GothamBold
	b.TextSize = 15
	b.TextColor3 = TEXT
	b.Text = label
	b.AutoButtonColor = true
	b.Parent = parent
	corner(b, 8)
	return b
end

function IslandBuildGui.new(playerGui)
	local self = setmetatable({}, IslandBuildGui)
	local gui = Instance.new("ScreenGui")
	gui.Name = "IslandBuildGui"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 40
	gui.Enabled = false
	gui.Parent = playerGui

	local bar = Instance.new("Frame")
	bar.AnchorPoint = Vector2.new(0.5, 1)
	bar.Position = UDim2.new(0.5, 0, 1, -150) -- เหนือช่องของใช้ 6 ช่องของ HUD
	bar.Size = UDim2.new(0, WIDTH, 0, HEIGHT)
	bar.BackgroundColor3 = PANEL
	bar.BackgroundTransparency = 0.2
	bar.BorderSizePixel = 0
	bar.Parent = gui
	corner(bar)
	Responsive.Scale(bar, 0.55)

	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Position = UDim2.new(0, 12, 0, 6)
	title.Size = UDim2.new(0.5, -12, 0, 20)
	title.Font = Enum.Font.GothamBold
	title.TextSize = 16
	title.TextColor3 = BRASS
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Text = ""
	title.Parent = bar

	local status = Instance.new("TextLabel")
	status.BackgroundTransparency = 1
	status.Position = UDim2.new(0.5, 0, 0, 6)
	status.Size = UDim2.new(0.5, -12, 0, 20)
	status.Font = Enum.Font.Gotham
	status.TextSize = 14
	status.TextColor3 = OK_COLOR
	status.TextXAlignment = Enum.TextXAlignment.Right
	status.Text = ""
	status.Parent = bar

	local rotate = button(bar, 12, "หมุน (R)", Color3.fromRGB(58, 86, 128))
	local place = button(bar, 136, "วาง", Color3.fromRGB(72, 104, 78))
	local cancel = button(bar, 260, "ยกเลิก (Esc)", Color3.fromRGB(110, 50, 50))
	rotate.MouseButton1Click:Connect(function() if self.OnRotate then self.OnRotate() end end)
	place.MouseButton1Click:Connect(function() if self.OnPlace then self.OnPlace() end end)
	cancel.MouseButton1Click:Connect(function() if self.OnCancel then self.OnCancel() end end)

	self.gui, self.title, self.status = gui, title, status
	return self
end

function IslandBuildGui:Show(titleText)
	self.title.Text = titleText or ""
	self.status.Text = ""
	self.gui.Enabled = true
end

function IslandBuildGui:Hide()
	self.gui.Enabled = false
end

function IslandBuildGui:SetStatus(text, ok)
	self.status.Text = text or ""
	self.status.TextColor3 = ok and OK_COLOR or BAD_COLOR
end

return IslandBuildGui
```

- [ ] **Step 2: เขียน `IslandBuildController.client.lua`**
```lua
-- IslandBuildController: โหมดวางของบนเกาะ — ghost โปร่งใสตามตัวชี้ snap ช่อง 4 studs · สี่เหลี่ยมใต้ ghost หนึ่งแผ่นต่อช่อง
-- เขียว/แดง · R หมุน · คลิก/ปุ่ม "วาง" ส่ง (slot, cx, cz, r) ให้เซิร์ฟเวอร์ ซึ่งเป็นคนตัดสินจริง (สีที่นี่เป็นแค่คำแนะนำ:
-- StreamingEnabled อาจทำให้ยังไม่เห็นบางชิ้น เซิร์ฟเวอร์จะปฏิเสธพร้อมเหตุผลเอง)
--
-- ทางเข้า = BindableEvent WOLD_StartPlacing ที่ไฟล์นี้เป็นคนสร้าง ปุ่มในกระเป๋าไปหยิบตอนกด (บทเรียน PremiumController:
-- คนเปิดหน้าต่างเป็นเจ้าของช่องทาง ไม่ใช่คนกดปุ่ม)
while workspace:GetAttribute("IsLobby") == nil do task.wait() end
if workspace:GetAttribute("IslandMode") ~= true then return end

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local IslandConfig = require(ReplicatedStorage.IslandConfig)
local IslandGrid = require(ReplicatedStorage.IslandGrid)
local ItemCatalog = require(ReplicatedStorage.ItemCatalog)
local Remotes = require(ReplicatedStorage.Remotes)
local IslandBuildGui = require(ReplicatedStorage.UI.IslandBuildGui)

local player = Players.LocalPlayer
local mouse = player:GetMouse() -- ใช้ได้ทั้งเมาส์และนิ้ว (UnitRay ตามจุดแตะล่าสุด)
local gui = IslandBuildGui.new(player:WaitForChild("PlayerGui"))

local GREEN = Color3.fromRGB(90, 220, 110)
local RED = Color3.fromRGB(230, 80, 80)
local REASON_TEXT = { edge = "ใกล้ขอบเกาะเกินไป", blocked = "ตรงนี้วางไม่ได้", occupied = "วางทับของอื่น" }

local starter = Instance.new("BindableEvent")
starter.Name = "WOLD_StartPlacing"
starter.Parent = ReplicatedStorage

local session = nil -- { slotIndex, id, w, d, r, cx, cz, ok, ghost, squares = {}, folder }
local occupied, occupiedDirty = {}, true

--------------------------------------------------------------------------------
-- ช่องที่ถูกใช้แล้ว อ่านจากแอตทริบิวต์ของโมเดลในโลก (ไม่มี state protocol เพิ่ม)
--------------------------------------------------------------------------------

local function placedFolder()
	local island = workspace:FindFirstChild("WOLD_Island")
	return island and island:FindFirstChild("Placed")
end

local function rebuildOccupied()
	occupied = {}
	local folder = placedFolder()
	if not folder then return end
	for _, model in ipairs(folder:GetChildren()) do
		local fp = model:GetAttribute("Footprint")
		local x, z, r = model:GetAttribute("CellX"), model:GetAttribute("CellZ"), model:GetAttribute("Rot")
		if typeof(fp) == "Vector2" and x and z and r then
			for _, key in ipairs(IslandGrid.cellsOf(x, z, fp.X, fp.Y, r)) do occupied[key] = true end
		end
	end
	occupiedDirty = false
end

-- โฟลเดอร์มาถึงเมื่อไหร่ไม่รู้ (StreamingEnabled) → ลูปถามใหม่จนเจอ แล้วค่อยผูก ChildAdded/Removed
task.spawn(function()
	local hooked = nil
	while true do
		local folder = placedFolder()
		if folder and folder ~= hooked then
			hooked = folder
			folder.ChildAdded:Connect(function() occupiedDirty = true end)
			folder.ChildRemoved:Connect(function() occupiedDirty = true end)
			occupiedDirty = true
		end
		task.wait(0.5)
	end
end)

local function noBuildZones()
	local zones = {}
	local spawnLoc = workspace:FindFirstChildWhichIsA("SpawnLocation", true)
	if spawnLoc then table.insert(zones, { x = spawnLoc.Position.X, z = spawnLoc.Position.Z, radius = IslandConfig.NoBuild.spawn }) end
	for _, npc in ipairs(CollectionService:GetTagged("WOLD_Npc")) do
		local p = npc:IsA("BasePart") and npc.Position or npc:GetPivot().Position
		table.insert(zones, { x = p.X, z = p.Z, radius = IslandConfig.NoBuild.npc })
	end
	return zones
end

--------------------------------------------------------------------------------
-- ghost
--------------------------------------------------------------------------------

local function stop()
	if not session then return end
	if session.folder then session.folder:Destroy() end
	session = nil
	gui:Hide()
end

local function start(slotIndex, id)
	stop()
	if slotIndex == nil then return end
	local protos = ReplicatedStorage:FindFirstChild("WOLD_Placeables")
	local proto = protos and protos:FindFirstChild(id)
	if not proto then warn("[IslandBuild] ไม่มีต้นแบบ " .. tostring(id)) return end
	local fp = proto:GetAttribute("Footprint")
	if typeof(fp) ~= "Vector2" then warn("[IslandBuild] ต้นแบบ " .. id .. " ไม่มี Footprint") return end

	local folder = Instance.new("Folder")
	folder.Name = "IslandGhost"
	folder.Parent = workspace

	local ghost = proto:Clone()
	ghost.Name = "Ghost"
	for _, d in ipairs(ghost:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Transparency = math.max(d.Transparency, 0.55)
			d.CanCollide, d.CanQuery, d.CanTouch = false, false, false
		elseif d:IsA("Script") or d:IsA("ProximityPrompt") or d:IsA("Light") then
			d:Destroy()
		end
	end
	ghost.Parent = folder

	local squares = {}
	for i = 1, fp.X * fp.Y do
		local sq = Instance.new("Part")
		sq.Anchored = true
		sq.CanCollide, sq.CanQuery, sq.CanTouch = false, false, false
		sq.Size = Vector3.new(IslandConfig.Cell - 0.2, 0.15, IslandConfig.Cell - 0.2)
		sq.Material = Enum.Material.Neon
		sq.Transparency = 0.45
		sq.Color = GREEN
		sq.Parent = folder
		squares[i] = sq
	end

	local item = ItemCatalog.Get(id)
	session = { slotIndex = slotIndex, id = id, w = fp.X, d = fp.Y, r = 0, ghost = ghost, squares = squares, folder = folder, ok = false }
	gui:Show(item and item.name or id)
	occupiedDirty = true
end

local function tryPlace()
	if not session then return end
	if not session.ok then
		gui:SetStatus(REASON_TEXT[session.reason] or "วางตรงนี้ไม่ได้", false)
		return
	end
	Remotes.IslandPlace:FireServer(session.slotIndex, session.cx, session.cz, session.r)
end

local function rotate()
	if session then session.r = (session.r + 1) % 4 end
end

-- ทุกเฟรม: ตัวชี้ → เรย์ลง Terrain → ช่อง → ตรวจ → วาง ghost + ระบายสี
RunService.RenderStepped:Connect(function()
	if not session then return end
	if occupiedDirty then rebuildOccupied() end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { workspace.Terrain }
	local ray = mouse.UnitRay
	local hit = workspace:Raycast(ray.Origin, ray.Direction * 600, params)
	if not hit then
		session.ok = false
		gui:SetStatus("ชี้ไปที่พื้นเกาะ", false)
		return
	end
	local cx, cz = IslandGrid.anchorFor(hit.Position.X, hit.Position.Z, session.w, session.d, session.r)
	local ok, reason = IslandGrid.canPlace(occupied, noBuildZones(), cx, cz, session.w, session.d, session.r)
	session.cx, session.cz, session.ok, session.reason = cx, cz, ok, reason
	session.ghost:PivotTo(IslandGrid.pivotFor(cx, cz, session.w, session.d, session.r, hit.Position.Y))

	local fw, fd = IslandGrid.footprintOf(session.w, session.d, session.r)
	local n = 0
	for i = 0, fw - 1 do
		for j = 0, fd - 1 do
			n += 1
			local sq = session.squares[n]
			local wx, wz = IslandGrid.worldOf(cx + i, cz + j)
			sq.CFrame = CFrame.new(wx, hit.Position.Y + 0.1, wz)
			sq.Color = ok and GREEN or RED
		end
	end
	gui:SetStatus(ok and "วางได้" or (REASON_TEXT[reason] or "วางไม่ได้"), ok)
end)

--------------------------------------------------------------------------------
-- อินพุต
--------------------------------------------------------------------------------

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if not session or gameProcessed then return end
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		tryPlace()
	elseif input.KeyCode == Enum.KeyCode.R then
		rotate()
	elseif input.KeyCode == Enum.KeyCode.Escape then
		stop()
	end
end)

gui.OnRotate = rotate
gui.OnPlace = tryPlace
gui.OnCancel = stop

-- เซิร์ฟเวอร์ตอบ (ok, remaining): วางสำเร็จและยังมีชิ้นเดิมเหลือ = อยู่ในโหมดต่อ (รั้ว 20 อัน) หมดแล้วออก
Remotes.IslandPlace.OnClientEvent:Connect(function(ok, remaining)
	occupiedDirty = true
	if ok and (remaining or 0) <= 0 then stop() end
end)

starter.Event:Connect(start)

player.CharacterRemoving:Connect(stop)
```

- [ ] **Step 3: แก้ `InventoryController.client.lua`** — หลังบล็อก `elseif item.kind == "skin" or item.kind == "fashion" then ... end` (ก่อน `end` ที่ปิด if-chain) เพิ่มสาขา:
```lua
	elseif item.kind == "placeable" then
		-- ของวางบนเกาะ: ทางเดียวคือเข้าโหมดวาง (IslandBuildController เป็นเจ้าของช่องทาง หยิบตอนกด ไม่รอไว้ล่วงหน้า)
		if workspace:GetAttribute("IslandMode") == true then
			table.insert(entries, { label = "วางบนเกาะ", onClick = function()
				local opener = game.ReplicatedStorage:FindFirstChild("WOLD_StartPlacing")
				if not opener then warn("[Inventory] ไม่พบ WOLD_StartPlacing (IslandBuildController ไม่ได้รัน?)") return end
				gui:Hide()
				opener:Fire(index, slot.id)
			end })
		else
			table.insert(entries, { label = "วางได้บนเกาะฟาร์มเท่านั้น", onClick = function() end })
		end
```
(ถ้า if-chain ปิดด้วย `end` ที่แยกบรรทัด ให้แทรกก่อน `end` นั้น — ดูสาขา `aura` ข้างบนเป็นตัวอย่างของรูปแบบ)

- [ ] **Step 4: เขียนเทส `tests/island_client_test.lua`** (ตรวจ ghost/ช่องสี — การคลิกจริงเป็นของผู้ใช้ ส่วนเส้นทางเซิร์ฟเวอร์ Task 6 คุมแล้ว)
```lua
-- Play ในเพลส Farming → node tools/lua.js tests/island_client_test.lua Client
local RS = game.ReplicatedStorage
local starter = RS:FindFirstChild("WOLD_StartPlacing")
assert(starter, "IslandBuildController ไม่ได้รัน (IslandMode ไม่ใช่ true?)")
starter:Fire(1, "Deco_Fence")
task.wait(0.3)
local folder = assert(workspace:FindFirstChild("IslandGhost"), "ไม่มี ghost")
local squares = 0
for _, c in ipairs(folder:GetChildren()) do if c:IsA("Part") then squares += 1 end end
assert(folder:FindFirstChild("Ghost"), "ไม่มีโมเดล ghost")
assert(squares == 1, "รั้ว 1x1 ต้องมี 1 ช่อง ได้ " .. squares)
starter:Fire(1, "FarmPlot")
task.wait(0.3)
folder = assert(workspace:FindFirstChild("IslandGhost"), "ghost แปลง")
squares = 0
for _, c in ipairs(folder:GetChildren()) do if c:IsA("Part") then squares += 1 end end
assert(squares == 4, "แปลง 2x2 ต้องมี 4 ช่อง ได้ " .. squares)
local gui = game.Players.LocalPlayer.PlayerGui:FindFirstChild("IslandBuildGui")
assert(gui and gui.Enabled, "แถบไม่ขึ้น")
starter:Fire(nil)
task.wait(0.2)
assert(not workspace:FindFirstChild("IslandGhost"), "ยกเลิกแล้ว ghost ต้องหาย")
assert(not gui.Enabled, "ยกเลิกแล้วแถบต้องซ่อน")
return "client ok"
```

- [ ] **Step 5: รัน**
```bash
WOLD_PLACE=136992335889132 node tools/syntax.js src/ReplicatedStorage/UI/IslandBuildGui.lua src/StarterPlayerScripts/IslandBuildController.client.lua src/StarterPlayerScripts/InventoryController.client.lua
WOLD_PLACE=136992335889132 node tools/mcp-call.js start_stop_play '{"is_start":true}'
sleep 12
WOLD_PLACE=136992335889132 node tools/lua.js tests/island_client_test.lua Client
```
Expected: `client ok` · แล้ว**ผู้ใช้ทดสอบมือ** ในหน้าต่าง Play เดียวกัน: เปิดกระเป๋า → กดค้างแปลงดิน → "วางบนเกาะ" → ghost ตามเมาส์ · R หมุน ·
คลิกวาง → โมเดลจริงโผล่ · เลื่อนไปทับ = แดง · ใกล้จุดเกิด = แดง · เดินไปกด F ค้างที่แปลง → กลับเข้ากระเป๋า · จบด้วย
```bash
WOLD_PLACE=136992335889132 node tools/mcp-call.js get_console_output '{}' 2>/dev/null | grep -iE "error|IslandBuild|\[Inventory\]" | head
WOLD_PLACE=136992335889132 node tools/mcp-call.js start_stop_play '{"is_start":false}'
```

- [ ] **Step 6: Commit**
```bash
git add src/ReplicatedStorage/UI/IslandBuildGui.lua src/StarterPlayerScripts/IslandBuildController.client.lua src/StarterPlayerScripts/InventoryController.client.lua tests/island_client_test.lua
git commit -m "a ghost that snaps to the grid and shows, cell by cell, where it may land"
```

---

### Task 8: แปลงปลูก `IslandPlots` (หยอด → โต → เก็บเกี่ยว)

**Files:**
- Create: `src/ServerScriptService/Island/IslandPlots.server.lua`, `tests/island_plots_test.lua`

**Interfaces:**
- Consumes: `IslandAccess.EntryOf/IsOwner/Data` (Task 6) · `IslandConfig.Crops/Stages/SeedItem` · ต้นแบบ `Crop_<item>` (Task 5) · `Inventory.FindSlotById/RemoveFromSlot/AddItem/HasRoomFor`
- Produces: `IslandAccess.Plant(player, model) -> ok, reason` · `IslandAccess.Harvest(player, model) -> ok, reason` · `IslandAccess.Tick()` ·
  entry ของแปลงที่ปลูกมี `crop` (item id) และ `at` (os.time) · โมเดลพืชชื่อ `Crop` ใต้โมเดลแปลง · ProximityPrompt `PlotPrompt` (E) บน `Soil`

- [ ] **Step 1: เขียน `Island/IslandPlots.server.lua`**
```lua
-- IslandPlots: แปลงดินที่วางแล้ว → ปุ่ม E หยอดเมล็ด / เก็บเกี่ยว · พืชโตตาม os.time (ออฟไลน์โตต่อฟรี)
--
-- ไม่ผูกตอนวางครั้งเดียว: ลูป 2 วิถามโฟลเดอร์ Placed ใหม่ทุกรอบ แปลงไหนยังไม่มีปุ่มก็ใส่ให้ แปลงไหนหายก็ลืม
-- (กฎเหล็ก "ลูปที่ถามใหม่เรื่อยๆ ไม่มีจังหวะให้แพ้") · นาฬิกาอยู่บนตัวปุ่ม (ObjectText) ไม่มีโค้ดไคลเอนต์
local ServerConfig = require(game.ServerScriptService.ServerConfig)
if not ServerConfig.IsFarm then return end

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Inventory = require(game.ServerScriptService.Inventory)
local IslandAccess = require(script.Parent.IslandAccess)
local IslandConfig = require(ReplicatedStorage.IslandConfig)
local ItemCatalog = require(ReplicatedStorage.ItemCatalog)
local Remotes = require(ReplicatedStorage.Remotes)

local TICK = 2
local Plots = {} -- [plotModel] = { prompt = ProximityPrompt, stage = number|nil }

local REASON_TEXT = {
	notowner = "เฉพาะเจ้าของเกาะ",
	noseed = "ไม่มีเมล็ดพันธุ์ในกระเป๋า",
	planted = "แปลงนี้ปลูกอยู่แล้ว",
	empty = "แปลงว่าง หยอดเมล็ดก่อน",
	unripe = "ยังไม่สุก",
	full = "กระเป๋าเต็ม",
	missing = "ไม่พบแปลงนี้แล้ว",
}

local function notify(player, reason)
	Remotes.SocialNotify:FireClient(player, "error", REASON_TEXT[reason] or reason)
end

local function cropSpec(item)
	for _, c in ipairs(IslandConfig.Crops) do if c.item == item then return c end end
	return nil
end

local function rollCrop()
	local total = 0
	for _, c in ipairs(IslandConfig.Crops) do total += c.weight end
	local pick = math.random() * total
	for _, c in ipairs(IslandConfig.Crops) do
		pick -= c.weight
		if pick <= 0 then return c end
	end
	return IslandConfig.Crops[#IslandConfig.Crops]
end

local function progressOf(entry)
	local spec = cropSpec(entry.crop)
	if not spec or not entry.at then return 1 end
	return math.clamp((os.time() - entry.at) / spec.seconds, 0, 1)
end

local function stageOf(progress)
	local stage = 1
	for i, s in ipairs(IslandConfig.Stages) do
		if progress >= s.at then stage = i end
	end
	return stage
end

local function minutesLeft(entry)
	local spec = cropSpec(entry.crop)
	if not spec then return 0 end
	return math.max(0, math.ceil((spec.seconds - (os.time() - entry.at)) / 60))
end

--------------------------------------------------------------------------------
-- โมเดลพืช
--------------------------------------------------------------------------------

local function showCrop(model, entry, stage)
	local soil = model:FindFirstChild("Soil")
	local crop = model:FindFirstChild("Crop")
	if entry.crop == nil then
		if crop then crop:Destroy() end
		return
	end
	if not crop then
		local protos = ReplicatedStorage:FindFirstChild("WOLD_Placeables")
		local proto = protos and protos:FindFirstChild("Crop_" .. entry.crop)
		if not proto or not soil then return end
		crop = proto:Clone()
		crop.Name = "Crop"
		crop:PivotTo(CFrame.new(soil.Position + Vector3.new(0, soil.Size.Y / 2, 0)))
		crop.Parent = model
	end
	crop:ScaleTo(IslandConfig.Stages[stage].scale)
end

--------------------------------------------------------------------------------
-- ปลูก / เก็บเกี่ยว
--------------------------------------------------------------------------------

local function plant(player, model)
	if not IslandAccess.IsOwner(player) then return false, "notowner" end
	local entry = IslandAccess.EntryOf(model)
	if not entry then return false, "missing" end
	if entry.crop then return false, "planted" end
	local slot = Inventory.FindSlotById(player, IslandConfig.SeedItem)
	if not slot then return false, "noseed" end
	if not Inventory.RemoveFromSlot(player, slot, 1) then return false, "noseed" end
	local spec = rollCrop()
	entry.crop, entry.at = spec.item, os.time()
	local state = Plots[model]
	if state then state.stage = nil end -- ให้รอบถัดไปวาดใหม่
	local item = ItemCatalog.Get(spec.item)
	Remotes.SocialNotify:FireClient(player, "info", ("หยอดเมล็ดแล้ว — ขึ้นเป็น%s ใช้เวลา %d นาที"):format(item and item.name or spec.item, spec.seconds / 60))
	return true
end

local function harvest(player, model)
	if not IslandAccess.IsOwner(player) then return false, "notowner" end
	local entry = IslandAccess.EntryOf(model)
	if not entry then return false, "missing" end
	if not entry.crop then return false, "empty" end
	if progressOf(entry) < 1 then return false, "unripe" end
	local spec = cropSpec(entry.crop)
	local amount = spec and math.random(spec.min, spec.max) or 1
	if not Inventory.HasRoomFor(player, entry.crop, amount) then return false, "full" end
	if not Inventory.AddItem(player, entry.crop, amount) then return false, "full" end
	local item = ItemCatalog.Get(entry.crop)
	Remotes.SocialNotify:FireClient(player, "info", ("เก็บเกี่ยวได้ %s x%d"):format(item and item.name or entry.crop, amount))
	entry.crop, entry.at = nil, nil
	local state = Plots[model]
	if state then state.stage = nil end
	showCrop(model, entry, 1)
	return true
end

--------------------------------------------------------------------------------
-- ลูป: ใส่ปุ่มให้แปลงที่ยังไม่มี · อัปเดตพืชและป้ายทุกแปลง
--------------------------------------------------------------------------------

local function ensurePrompt(model)
	local soil = model:FindFirstChild("Soil")
	if not soil then return nil end
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "PlotPrompt"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = soil
	prompt.Triggered:Connect(function(player)
		local entry = IslandAccess.EntryOf(model)
		if not entry then return end
		local ok, reason
		if entry.crop then ok, reason = harvest(player, model) else ok, reason = plant(player, model) end
		if not ok then notify(player, reason) end
	end)
	return prompt
end

local function tick()
	local island = workspace:FindFirstChild("WOLD_Island")
	local folder = island and island:FindFirstChild("Placed")
	for model, state in pairs(Plots) do
		if not model.Parent then Plots[model] = nil end
	end
	if not folder then return end
	for _, model in ipairs(folder:GetChildren()) do
		if model:GetAttribute("ItemId") == "FarmPlot" then
			local state = Plots[model]
			if not state then
				local prompt = ensurePrompt(model)
				if prompt then
					state = { prompt = prompt }
					Plots[model] = state
				end
			end
			local entry = state and IslandAccess.EntryOf(model)
			if state and entry then
				if entry.crop then
					local progress = progressOf(entry)
					local stage = stageOf(progress)
					if stage ~= state.stage then
						showCrop(model, entry, stage)
						state.stage = stage
					end
					local item = ItemCatalog.Get(entry.crop)
					local name = item and item.name or entry.crop
					if progress >= 1 then
						state.prompt.ActionText = "เก็บเกี่ยว"
						state.prompt.ObjectText = name .. " · สุกแล้ว"
					else
						state.prompt.ActionText = "รอ..."
						state.prompt.ObjectText = ("%s · เหลือ %d นาที"):format(name, minutesLeft(entry))
					end
				else
					if state.stage then showCrop(model, entry, 1); state.stage = nil end
					state.prompt.ActionText = "หยอดเมล็ด"
					state.prompt.ObjectText = "แปลงว่าง"
				end
			end
		end
	end
end

task.spawn(function()
	while true do
		local ok, err = pcall(tick)
		if not ok then warn("[IslandPlots] " .. tostring(err)) end
		task.wait(TICK)
	end
end)

IslandAccess.Plant = plant
IslandAccess.Harvest = harvest
IslandAccess.Tick = tick
```

- [ ] **Step 2: เขียนเทส `tests/island_plots_test.lua`**
```lua
-- Play ในเพลส Farming → node tools/lua.js tests/island_plots_test.lua Server  (รันหลัง island_build_test หรือเดี่ยวๆ ก็ได้)
local Players = game:GetService("Players")
local A = require(game.ServerScriptService.Island.IslandAccess)
local player = assert(Players:GetPlayers()[1], "ไม่มีผู้เล่น")
local t0 = os.clock()
while not A.Data() and os.clock() - t0 < 20 do task.wait(0.2) end
local data = assert(A.Data(), "ข้อมูลเกาะไม่โหลด")

local entry, placedHere
for _, e in ipairs(data.placed) do if e.id == "FarmPlot" and not e.crop then entry = e break end end
if not entry then
	local s = assert(A.FindSlot(player, "FarmPlot"), "ไม่มีแปลงในกระเป๋า")
	assert(A.Place(player, s, 20, 20, 0))
	entry = data.placed[#data.placed]
	placedHere = true
end
local model = assert(A.ModelOf(entry.uid))
A.Tick()
assert(model.Soil:FindFirstChild("PlotPrompt"), "ปุ่มแปลง")
assert(A.FindSlot(player, "Seed"), "ต้องมีเมล็ด (ชุดเริ่มต้นให้ 5)")

local seeds = A.Count(player, "Seed")
local ok, why = A.Plant(player, model); assert(ok, "หยอด: " .. tostring(why))
assert(entry.crop and entry.at, "บันทึก crop/at")
assert(A.Count(player, "Seed") == seeds - 1, "เมล็ดถูกหัก")
ok, why = A.Plant(player, model); assert(not ok and why == "planted", "หยอดซ้ำ: " .. tostring(why))
ok, why = A.Harvest(player, model); assert(not ok and why == "unripe", "เก็บก่อนสุก: " .. tostring(why))
ok, why = A.Pickup(player, entry.uid); assert(not ok and why == "growing", "เก็บแปลงที่ปลูกอยู่: " .. tostring(why))
A.Tick()
local crop = assert(model:FindFirstChild("Crop"), "โมเดลพืชโผล่")
assert(math.abs(crop:GetScale() - 0.35) < 0.01, "ระยะแรกสเกล 0.35 ได้ " .. crop:GetScale())

entry.at = os.time() - 100000 -- เร่งเวลา
A.Tick()
assert(math.abs(crop:GetScale() - 1) < 0.01, "สุกแล้วสเกล 1")
assert(model.Soil.PlotPrompt.ActionText == "เก็บเกี่ยว", "ป้ายเก็บเกี่ยว")
local cropItem = entry.crop
local before = A.Count(player, cropItem)
ok, why = A.Harvest(player, model); assert(ok, "เก็บเกี่ยว: " .. tostring(why))
assert(A.Count(player, cropItem) > before, "ได้ " .. cropItem .. " เข้ากระเป๋า")
assert(entry.crop == nil and entry.at == nil, "แปลงว่างอีกครั้ง")
assert(not model:FindFirstChild("Crop"), "โมเดลพืชหาย")
A.Tick()
assert(model.Soil.PlotPrompt.ActionText == "หยอดเมล็ด", "ป้ายกลับเป็นหยอดเมล็ด")
if placedHere then assert(A.Pickup(player, entry.uid), "เก็บแปลงที่เทสวางคืน") end -- โปรไฟล์จริง ไม่ทิ้งของเทสไว้
return "plots ok: " .. cropItem
```

- [ ] **Step 3: รัน**
```bash
WOLD_PLACE=136992335889132 node tools/syntax.js src/ServerScriptService/Island/IslandPlots.server.lua
WOLD_PLACE=136992335889132 node tools/mcp-call.js start_stop_play '{"is_start":true}'
sleep 12
WOLD_PLACE=136992335889132 node tools/lua.js tests/island_plots_test.lua Server
WOLD_PLACE=136992335889132 node tools/mcp-call.js get_console_output '{}' 2>/dev/null | grep -iE "error|IslandPlots" | head
WOLD_PLACE=136992335889132 node tools/mcp-call.js start_stop_play '{"is_start":false}'
```
Expected: `plots ok: Wheat` (หรือ Vegetable/Herb ตามที่สุ่มได้) · ไม่มี error

- [ ] **Step 4: Commit**
```bash
git add src/ServerScriptService/Island/IslandPlots.server.lua tests/island_plots_test.lua
git commit -m "seed in, wait, crop out: the plot keeps its own clock on the prompt"
```

---

### Task 9: ตรวจรวม + เอกสาร + เตรียม publish

**Files:**
- Modify: `CLAUDE.md` (หัวข้อสถานะโหมดฟาร์มมิ่ง), `docs/design/06-modes-build-plan.md` (หมายเหตุว่า Phase 0 ใช้ globIgnorePaths แทนการย้ายโฟลเดอร์)
- อาจแก้: `farming.project.json` (เติมสคริปต์ที่ F9 ฟ้องว่าพังบนเกาะ)

- [ ] **Step 1: เล่นครบวงจรใน Studio Play (เพลส Farming) — ผู้ใช้เล่นเอง Claude ดู F9**
ลำดับ: เกิดบนเกาะ → กระเป๋ามีชุดเริ่มต้น (บ้าน 1 แปลง 9 รั้ว 10 เมล็ด 5) → เดินหา NPC (0, ~817, −22) กด E ซื้อเมล็ด 1
(สต็อกเป็นของเกาะ ไม่ใช่พลั่ว) → วางบ้าน หมุน 4 ทิศ → วางแปลง 9 ช่อง → หยอดเมล็ด → เร่งด้วย
`node tools/lua.js` (ตั้ง `entry.at` ย้อนหลังทุกแปลงผ่าน `IslandAccess.Data()`) → เก็บเกี่ยว → เก็บรั้วคืน → ยืนที่ขอบเกาะวาง = แดง ·
จด error ทุกบรรทัดใน F9 (Server + Client) ที่มาจากสคริปต์ที่ไม่ควรรันบนเกาะ → เติมชื่อลง `farming.project.json` → เล่นซ้ำจนเงียบ

- [ ] **Step 2: ทดสอบเซฟข้าม Play** — วาง 3 ชิ้น + หยอด 1 แปลง → หยุด Play → Play ใหม่ → ทั้ง 3 ชิ้นอยู่ที่เดิม พืชโตต่อ
(Studio เขียน DataStore จริง จึงทดสอบได้ตรงนี้เลย) แล้วค่อย **Publish เพื่อทดสอบเจ้าของตัวจริง** (`FarmOwnerId` จาก FarmRegistry ผ่าน Reserved Server ซึ่ง Studio ไม่มี):
ผู้ใช้ Publish เพลส Farming (File → Publish) และเพลสหลัก (ServerConfig/PlayerProfile/Remotes/ItemCatalog/ShopConfig/
InventoryController เปลี่ยน — **ปิด `FORCE_CHANNEL_IN_STUDIO_FOR_TESTING` ก่อน publish เพลสหลัก**) → เข้าเกมจริง → ล็อบบี้ →
แท็บ Farming → เกาะ: วาง 3 ชิ้น + หยอด 1 แปลง → กลับล็อบบี้ → เข้าเกาะใหม่ → ทั้ง 3 ชิ้นอยู่ที่เดิม พืชโตต่อ · จากนั้นเข้า Roleplay →
เกิดที่พิกัดเดิมของเมืองหลัก (ไม่ใช่ 0,817,0)

- [ ] **Step 3: อัปเดต `CLAUDE.md`** — ใต้หัวข้อ "**แท็บ Farming ในล็อบบี้เปิดแล้ว**" แทนบรรทัด `⚠️ **ยังไม่มีสคริปต์ฝั่งเพลสเกาะเลย** ...` ด้วย:
```
**ชุด A ของเกาะทำแล้ว (2026-09-22)** สเปก `docs/superpowers/specs/2026-09-21-island-placement-design.md` แผน
`docs/superpowers/plans/2026-09-22-island-placement.md` — Phase 0 = `farming.project.json` (globIgnorePaths ไม่ย้ายโฟลเดอร์ แผน 06
ข้อนี้ล้าสมัย) · `ServerConfig.IsFarm`/`Mode="Farming"` จาก PlaceId (Studio Play ในเพลสเกาะ = เกาะเสมอ คนแรกที่เข้า = เจ้าของ) ·
ของวาง = `kind="placeable"` ต้นแบบใน `ReplicatedStorage.WOLD_Placeables` (เฟส 90 · `Footprint` บนต้นแบบเป็นแหล่งเดียว) ·
NPC ร้านจากเฟส 91 · `Island/IslandBuild` เจ้าของ `profile.Data.Island` + ช่องที่ใช้ · `Island/IslandPlots` ปลูก/เก็บเกี่ยว ·
ไคลเอนต์ `IslandBuildController` (ghost + ช่องสี + แถบ 3 ปุ่ม; ปุ่ม "วางบนเกาะ" ในกระเป๋า) · เทส: `tests/island_*_test.lua`
ยิงด้วย `WOLD_PLACE=136992335889132 node tools/lua.js <ไฟล์> Server|Client` ระหว่าง Play · เก็บ = F กดค้าง ปลูก/เก็บเกี่ยว = E ·
ไม่มีปุ่มย้าย (เก็บแล้ววางใหม่) · ตัวเลขทั้งหมด (ราคา เวลาปลูก ชุดเริ่มต้น) Claude ตั้ง ยังไม่ได้จูน — ถัดไปชุด B (บ้านใช้ได้ คอก บ่อ)
```
และใน `06-modes-build-plan.md` หัวข้อ Phase 0 เติมบรรทัดแรก: `> **ทำจริงแล้วด้วย globIgnorePaths ใน farming.project.json (2026-09-22) ไม่ได้ย้ายโฟลเดอร์ — ดูสเปกเกาะชุด A**`

- [ ] **Step 4: Commit**
```bash
git add CLAUDE.md docs/design/06-modes-build-plan.md farming.project.json
git commit -m "island chunk a: notes for the next session, and the scripts f9 said should stay home"
```

---

## Self-review

- **Spec coverage:** §1 Phase 0 → Task 1 · §2 ตัวตนเพลส/Position/Data.Island → Task 2 + 6 · §3 ไอเทม/ต้นแบบ/ร้าน/ชุดเริ่มต้น → Task 4, 5, 6 ·
  §4.1–4.2 Config/Grid → Task 3 · §4.3 เซิร์ฟเวอร์ → Task 6 · §4.4 ไคลเอนต์ → Task 7 · §5 แปลง → Task 8 · §7 การทดสอบ → เทสในทุก Task + Task 9 ·
  §8 ตัดออก (ย้าย/กริดทั้งเกาะ/กล้อง) — ไม่มี Task ตามตั้งใจ
- **เพิ่มจากสเปก:** เมล็ด 5 ในชุดเริ่มต้น (ให้เทสปลูกได้โดยไม่ต้องซื้อ และเป็นรอบแรกฟรีของผู้เล่นใหม่) · `IsFarm` ตัดสินจาก PlaceId
  ทำให้ Studio Play ในเพลสเกาะไม่ต้องพึ่ง FORCE flag (สเปกบอกว่าต้องพึ่ง)
- **Type consistency:** `IslandGrid.canPlace(occupied, zones, x, z, w, d, r)` ใช้ลายเซ็นเดียวกันใน Task 3/6/7 · `Footprint` เป็น `Vector2(w=X, d=Z)`
  ทั้งเฟส 90 / IslandBuild / IslandBuildController · reason strings ตรงกันระหว่าง IslandBuild (`notowner noitem noproto limit edge blocked
  occupied full growing missing`) และเทส · `IslandAccess` สล็อตทั้ง 11 ตัวถูกตั้งครบใน Task 6 (8) + Task 8 (3)
