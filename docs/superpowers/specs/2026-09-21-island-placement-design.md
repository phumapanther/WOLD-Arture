# เกาะฟาร์มมิ่ง ชุด A — เครื่องวางของบนตาราง + แปลงปลูก (ออกแบบ 2026-09-21)

**สถานะ: ผู้ใช้อนุมัติแบบแล้ว 2026-09-21 ยังไม่เขียนโค้ด**

เปลี่ยนโหมดฟาร์มมิ่งจาก "ผังตายตัว" (ใน `docs/design/05-future-modes.md`) เป็น **ผู้เล่นวางเองทุกอย่าง**
บนตารางช่องละ 4 studs แบบ Animal Crossing — เกาะเริ่มว่างเปล่า มีแค่จุดเกิดกับ NPC ร้าน · บ้าน แปลงผัก
ของตกแต่ง เป็นไอเทมในกระเป๋าที่ซื้อจาก NPC แล้วเอามาวาง/เก็บได้ตลอด · ข้อมูลทั้งหมดอยู่ในโปรไฟล์เจ้าของ

ผู้ใช้ตัดสินไว้แล้วในรอบถาม (2026-09-21):
- วางเองทุกอย่าง (ไม่มีโซนใช้งานตายตัว)
- ของวาง = ไอเทมในกระเป๋า ซื้อจาก NPC บนเกาะ · เข้าเกาะครั้งแรกได้ชุดเริ่มต้นฟรี
- ปลูก = หยอดเมล็ด → รอเวลา → เก็บ (ไม่มีรดน้ำ ไม่มีพรวนดิน)
- ล็อกตารางอย่างเดียว ช่องละ 4 studs (ไม่มีโหมดวางอิสระ)
- Phase 0 ใช้ `globIgnorePaths` ไม่ย้ายโฟลเดอร์
- ตัวเลขทั้งหมดใช้ค่าที่ Claude ตั้งไว้ก่อน จูนหลังเล่น

## ลำดับชุดงาน (ชุดนี้คือ A)

| ชุด | ได้อะไร |
|---|---|
| **A** | Phase 0 → เพลสเกาะบูตได้ → เครื่องวางของ → NPC ร้าน → แปลงปลูก → ของตกแต่งชุดแรก |
| B | บ้านที่ข้างในใช้ได้ (เตียง/เตา/ตู้เย็น) · คอกสัตว์นับเวลา · บ่อตกปลา — เป็นไอเทมวางเพิ่ม |
| C | โซนแร่ปลดด้วยเพชร · ชวนเพื่อน (ด่านฝั่งเกาะ + เกาะตอนเจ้าของออฟไลน์) · คลัง/ตลาด/บอร์ดเควสบนเกาะ |

---

## 1. Phase 0 — แยกโค้ดเกมหลักออกจากเกาะ ด้วย `globIgnorePaths`

**ไม่ย้ายไฟล์ ไม่เปลี่ยนชื่อ instance** — โค้ดทั้งโปรเจ็ค `require(game.ServerScriptService.X)` แบบแบน
(57 จุดสำหรับ ServerConfig อย่างเดียว) และ Rojo รวมสอง `$path` เข้า instance เดียวไม่ได้ การย้ายเป็น
โฟลเดอร์ย่อยตามแผน `06` จึงต้องแก้ require ทั้งโปรเจ็ค ซึ่งแผนนั้นเข้าใจผิด

- `farming.project.json` ใหม่: tree เดียวกับ `default.project.json` ทุกประการ + `"globIgnorePaths": [...]`
  รายชื่อไฟล์เกมหลักที่ห้ามไปเกาะ (ดูรายการข้างล่าง) · `default.project.json` **ไม่แตะ** เพลสหลักเหมือนเดิม 100%
- `serve-farming.bat` — `rojo serve farming.project.json --port 34873` (พอร์ตต่างจากเพลสหลัก จะได้เปิด
  Studio สองหน้าต่างพร้อมกันได้) ทรงเดียวกับ `serve-background.bat`
- **กติกาใหม่ที่ต้องจดใน CLAUDE.md**: ไฟล์เซิร์ฟเวอร์ใหม่ที่เป็นของเกมหลักเท่านั้น ต้องเติมชื่อลง
  `farming.project.json` เอง ไม่งั้นมันไปโผล่บนเกาะโดยดีฟอลต์ (denylist — Rojo ไม่มี allowlist)

**รายชื่อที่ข้าม** (server): `Mobs WorldEvents WorldBoss VehicleMain TownCapture TownVault TownBuyers IllegalFarm Transformers Quests Gathering Fishing AnimalHerds`
`TreasureChests AdminChest DevTeleport TikTokLive Leaderboards Monowheel Arrest Jail DiscordSign`
`Lobby/BuildLobbyRoom Lobby/LobbyServer Lobby/ChannelServer` — รายการสุดท้ายตัดสินตอนเขียนแผน โดยไล่ทีละไฟล์
ว่า "บนเกาะมันจะสร้าง/ประกาศอะไรเองไหมถ้าไม่มีแท็ก" ไฟล์ที่นิ่งเมื่อไม่มีแท็ก (เช่น `Beds` `StorageChests`
`CraftStations`) **ปล่อยไป** เพราะชุด B ต้องใช้อยู่แล้ว
- **โมดูล `Vehicle/*` ต้องไปด้วย** — `AdminCommands` `Trading` `ClassActions` require `Vehicle.Service` ตรงๆ
  การ require อย่างเดียวไม่สร้างอะไร (สร้างตอน `VehicleMain` เรียก `init`/`Stations`) จึงปลอดภัย
- Access-module ทุกตัว (`MobAccess` `TownAccess` `QuestAccess` …) ไปด้วย — ออกแบบให้เป็น nil ในล็อบบี้อยู่แล้ว
  ทุกคนที่เรียกเช็คก่อน บนเกาะจึงเงียบเหมือนล็อบบี้
- `ReplicatedStorage` / `StarterGui` / `StarterPlayerScripts` **ไปทั้งก้อน** ไคลเอนต์ของระบบที่ไม่มีบนเกาะ
  แค่ idle (Remotes ถูกสร้างครบทุกตัวโดย `Remotes.lua` ไม่ว่าเพลสไหน) — ถ้าตัวไหน warn/error ใน F9 ค่อยเติม
  ลงรายการข้ามทีหลัง

**เทสว่า Phase 0 ผ่าน**: `rojo build farming.project.json -o <temp>.rbxl` แล้วเปิดดูว่าไฟล์ในรายการหายจริง
และ `rojo build default.project.json` ได้ instance ครบเท่าเดิม (นับจำนวน)

## 2. ตัวตนเพลส + บูต

**`ServerConfig`** เพิ่มสาขา:
```
if game.PlaceId == ServerConfig.FarmingPlaceId then
    Mode = "Farming"
    FarmOwnerId = FarmRegistry.OwnerOfServer(game.PrivateServerId)   -- มีอยู่แล้วใน Lobby/FarmRegistry
    IsLobby = false
end
```
- Studio + `FORCE_CHANNEL_IN_STUDIO_FOR_TESTING` ในเพลส Farming → `FarmOwnerId = nil` แล้ว **คนแรกที่เข้า
  เป็นเจ้าของ** (IslandBuild ตั้งให้ตอน PlayerAdded) — ทางเดียวที่เทสใน Studio ได้ เพราะ Reserved Server
  ไม่มีใน Studio
- ประกาศ `workspace:SetAttribute("IslandMode", true)` ให้ไคลเอนต์ (ทรงเดียวกับ `IsLobby`)
- `ChannelRegistry.IdentifySelf()` **ไม่ถูกเรียก** ในโหมดนี้ (มันจะ warn แล้วคืน Roleplay/0)

**`PlayerProfile`**: โหมด Farming **ไม่อ่านและไม่เซฟ `Position`** — `resolvedSpawnPosition` คืน
`SpawnSelector.ResolvePosition(nil)` (= SpawnLocation ที่มีอยู่แล้วที่ (0, 817, 0)) และ `savePosition` ข้าม
ไม่งั้นเข้าเกาะแล้วเกิดที่พิกัดเมืองหลักซึ่งเป็นอากาศบนเกาะ · พิกัดเกมหลักในโปรไฟล์จึงรอดไว้ใช้ตอนกลับ

**ข้อมูลเกาะ** อยู่ที่ `profile.Data.Island` เขียนตรงเข้าตารางแบบเดียวกับ `Vehicles`/`Collection`
(ไม่มี serializer — ProfileStore เซฟทั้ง Data อยู่แล้ว):
```
Island = {
  starter = true,                  -- ได้ชุดเริ่มต้นไปแล้ว
  placed = {                       -- array
    { uid = 17, id = "FarmPlot", x = -3, z = 5, r = 1, crop = "Wheat", at = 1758400000 },
    { uid = 18, id = "House_StoneCottage", x = 4, z = -8, r = 0 },
  },
  nextUid = 19,
}
```
`x, z` = ช่องมุมที่ค่า cx/cz น้อยที่สุดของ footprint (จำนวนเต็ม อ้างจากกึ่งกลางเกาะ · ช่อง 0,0 คือช่องที่มุมล่างซ้ายแตะ Center) · `r` = 0..3 (×90°) · `crop`/`at`
มีเฉพาะแปลงที่ปลูกอยู่

## 3. ของวางได้ (placeable)

**`ItemCatalog`** เพิ่ม `kind = "placeable"` — ไม่ขายคืน (ไม่อยู่ใน `ShopConfig.Buys`) · `icon = ""` ทุกชิ้น
(⌛ ตามกติกา "ยังไม่มีรูปของตัวเอง") · `weight` เล็ก (1–2) เพราะกระเป๋าคือทางเดียวที่ของเดินทาง

| id | ชื่อ | ช่อง (โดยประมาณ คำนวณจริงตอนสร้าง) | stackSize | ราคา* |
|---|---|---|---|---|
| `FarmPlot` | แปลงดิน | 2×2 | 10 | 300 |
| `Fence` | รั้วไม้ | 1×1 | 20 | 50 |
| `Lamp` | โคมไฟไอน้ำ | 1×1 | 10 | 400 |
| `Bench` | ม้านั่ง | 2×1 | 5 | 350 |
| `FlowerPot` | กระถางดอกไม้ | 1×1 | 10 | 150 |
| `Tree` | ต้นไม้ | 2×2 | 5 | 600 |
| `Crate` / `Barrel` | ลัง / ถัง | 1×1 | 10 | 200 |
| `PathTile` | แผ่นทางเดินหิน | 1×1 | 50 | 30 |
| `House_StoneCottage` … อีก 4 หลังจาก `models/houses.lua` | บ้าน | 6–10 ต่อด้าน | 1 | 20,000–50,000 |
| `Seed` | เมล็ดพันธุ์ (ไม่ใช่ placeable — `kind = "junk"`, `sellable = false`) | — | 99 | 50 |

\* ราคาทั้งหมด **Claude ตั้งเอง ผู้ใช้ยังไม่ได้กำหนด** อยู่ที่ `ShopConfig.IslandSells` ที่เดียว

**ต้นแบบ** อยู่ที่ **`ReplicatedStorage.WOLD_Placeables/<itemId>`** (ไคลเอนต์ต้องโคลนทำ ghost จึงอยู่ใน
ReplicatedStorage ไม่ใช่ ServerStorage · ReplicatedStorage ไม่ถูก stream จึงไม่แพ้จังหวะ)
- สร้างด้วย **`mapgen/90_island_placeables.lua --kit --models`** รันครั้งเดียวในเพลส Farming (ทรงเดียวกับ
  `82_boss_prototype`): บ้านจาก `K.place` ของ modelkit · ของตกแต่งปั้นด้วย `K.*` ในไฟล์นี้เอง ·
  พืช 3 ชนิด `Crop_Wheat` `Crop_Vegetable` `Crop_Herb` (ทรงเต็มโต ระบบย่อเองตามระยะ)
- ทุกต้นแบบ: `Root` = PrimaryPart ที่ฐาน (y=0 กลาง x/z หน้า -Z ตามข้อตกลงข้อ 1 ของ modelkit) · ทุกชิ้น
  Anchored · **แอตทริบิวต์ `Footprint` (Vector2 จำนวนช่อง) เป็นแหล่งเดียว** คำนวณจาก
  `ceil(bounding.X / 4) × ceil(bounding.Z / 4)` ตอนสร้าง — ItemCatalog **ไม่มี** เลขซ้ำ
- `FarmPlot` มีชิ้น `Soil` ให้พืชเกาะ (พืชวางที่ `Soil.Position + (0, Soil.Size.Y/2, 0)`)
- ⚠️ ถ้าเพลสหาย รันเฟส 90 ใหม่ได้ (ทางอัปเกรด: export เป็น `.rbxmx` ให้ Rojo sync เอง จะได้ไม่ต้องรัน
  ด้วยมือ — ยังไม่ทำ)

**ที่มาของของ**: `Shop.server` เลือกสต็อกตามโหมด — บรรทัดเดียว
`local SELLS = ServerConfig.Mode == "Farming" and ShopConfig.IslandSells or ShopConfig.Sells`
(สต็อกเกมหลักไม่เปลี่ยน) · NPC ร้านบนเกาะ = โมเดล `Merchant_Barnaby` ตัวเดิม แท็ก `WOLD_Npc` `NpcKind="shop"`
วางด้วย **`mapgen/91_island_setup.lua --kit --models`** ห่างจุดเกิด ~20 studs — เฟสเดียวกันนี้ **ไม่สร้าง**
SpawnLocation (มีอยู่แล้ว)

**ชุดเริ่มต้น** (`IslandConfig.StarterKit`): เข้าเกาะครั้งแรก (`Island.starter ~= true`) ได้
`House_StoneCottage` 1 · `FarmPlot` 9 · `Fence` 10 ใส่กระเป๋า (`Inventory.AddItem` ทีละชิ้น ชิ้นที่ไม่ลง
ตกไป `SpillOver` เข้าคลังเหมือนของอื่น) แล้วตั้งธง — ไม่วางให้อัตโนมัติ ผู้เล่นวางเองตั้งแต่ชิ้นแรก

## 4. เครื่องวางของ

### 4.1 `ReplicatedStorage/IslandConfig.lua` — เลขทั้งหมดของเกาะ (แชร์สองฝั่ง)
```
Cell = 4
Center = Vector3.new(0, 800, 0)   -- = ORIGIN ของ mapgen/80_sky_island.lua
Radius = 220, Oval = 0.90          -- = R, OVAL ของไฟล์เดียวกัน  ⚠️ แก้ที่โน่นต้องแก้ที่นี่
EdgeMargin = 24                    -- ห่างขอบหน้าผาอย่างน้อยเท่านี้
NoBuild = { { at = "spawn", radius = 16 }, { at = "npc", radius = 12 } }  -- อ่านตำแหน่งจริงตอนบูต
MaxPlaced = 300
StarterKit = { House_StoneCottage = 1, FarmPlot = 9, Fence = 10 }
Crops = {                          -- น้ำหนักสุ่มตอนหยอดเมล็ด · วินาที · จำนวนที่ได้
  { item = "Wheat",     weight = 50, seconds = 10*60, min = 3, max = 5 },
  { item = "Vegetable", weight = 35, seconds = 15*60, min = 2, max = 4 },
  { item = "Herb",      weight = 15, seconds = 20*60, min = 2, max = 3 },
}
SeedItem = "Seed"
Stages = { 0.0, 0.5, 1.0 }         -- สัดส่วนเวลา → สเกลโมเดล 0.35 / 0.7 / 1.0 · ถึง 1.0 = สุก
```

### 4.2 `ReplicatedStorage/IslandGrid.lua` — ตรรกะตารางล้วนๆ ไม่แตะ Instance (เทสได้ด้วย execute_luau)
- `cellOf(worldX, worldZ) → cx, cz` และ `worldOf(cx, cz) → x, z` (กึ่งกลางช่อง)
- `footprintOf(w, d, r) → w', d'` (r คี่สลับ)
- `cellsOf(x, z, w, d, r) → { "cx,cz", ... }` ช่องที่ footprint กิน
- `inBounds(cx, cz)` วงรี `(x/(R−m))² + (z/((R−m)·Oval))² ≤ 1` บวกวงห้ามที่ส่งเข้ามา
- `canPlace(occupied, noBuild, x, z, w, d, r) → ok, reason` (reason: `"edge"` `"blocked"` `"occupied"`)
- `pivotFor(x, z, w, d, r, groundY) → CFrame` กึ่งกลาง footprint หมุน `r·90°`

### 4.3 เซิร์ฟเวอร์ `ServerScriptService/Island/IslandBuild.server.lua`
- บรรทัดแรก `if ServerConfig.Mode ~= "Farming" then return end` (ไฟล์ไปเพลสหลักด้วยแต่ไม่ทำอะไร —
  ทรงเดียวกับ `IsLobby` gating ที่ใช้อยู่ ไม่ต้องเพิ่มรายการข้ามฝั่งเพลสหลัก)
- เจ้าของ: `ServerConfig.FarmOwnerId` · ถ้า nil (Studio) = คนแรกที่ `PlayerAdded`
- ตอนโปรไฟล์เจ้าของโหลด (`ProfileAccess.Wait`): `Data.Island = Data.Island or { placed = {}, nextUid = 1 }`
  → แจกชุดเริ่มต้นถ้ายังไม่เคย → **สร้างคืนทุกชิ้น** ลง `workspace.WOLD_Island.Placed` · ช่องที่ใช้อยู่ใน
  `occupied["cx,cz"] = uid` · ต้นแบบหาย (id ที่ถูกลบจากเกม) = ข้ามพร้อม warn ไม่ล้มทั้งเกาะ
- **ความสูง**: raycast ลงจาก `Center.Y + 80` ที่กึ่งกลาง footprint · `FilterType = Include {Terrain}`
  (บทเรียน `Zone_*` กล่องล่องหน) · โดม 16 studs บนรัศมี 220 เอียงน้อย บ้านบนเนินจมมุมหนึ่งเล็กน้อย ยอมรับได้
- โมเดลที่วางแล้ว: แอตทริบิวต์ `Uid CellX CellZ Rot Footprint ItemId` + `ProximityPrompt` "เก็บ" (E)
  บน `Root` · แปลงเพิ่มปุ่มของ IslandPlots (ข้อ 5)
- **Remote** (เพิ่มใน `Remotes.lua`): `IslandPlace(slotIndex, cx, cz, r)` · `IslandPickup(uid)` ·
  `IslandNotify` ไม่ต้องมี — ใช้ `SocialNotify` เดิม (`"error"`, ข้อความ) เหมือนร้าน
- `IslandPlace` ตรวจตามลำดับ: เป็นเจ้าของ → ของในช่องกระเป๋า `kind == "placeable"` → มีต้นแบบ →
  `#placed < MaxPlaced` → `IslandGrid.canPlace` → `Inventory.RemoveFromSlot(1)` สำเร็จ → บันทึก + occupied
  + โคลน · ปฏิเสธข้อไหนตอบเหตุผลเป็นไทย ("วางทับของอื่น" "ใกล้ขอบเกาะเกินไป" "ตรงนี้วางไม่ได้" "เกาะเต็ม 300 ชิ้น")
- `IslandPickup(uid)`: เจ้าของ → มีชิ้นนั้น → แปลงที่ `crop` อยู่ปฏิเสธ ("เก็บเกี่ยวก่อน") →
  `Inventory.HasRoomFor(id, 1)` → `AddItem` → ลบจาก placed/occupied → Destroy
- **ไม่มีปุ่มย้าย** — ย้าย = เก็บแล้ววางใหม่ (ตัดทั้ง remote และเคส "ตรวจช่องโดยไม่นับตัวเอง")
- อัตราเรียก: 5 ครั้ง/วิต่อคน เกินทิ้งเงียบ

### 4.4 ไคลเอนต์ `StarterPlayerScripts/IslandBuildController.client.lua` + `UI/IslandBuildGui.lua`
- ออกจากงานถ้า `workspace:GetAttribute("IslandMode") ~= true` (รอแอตทริบิวต์ก่อนแบบ HudController)
- **ทางเข้า**: ปุ่ม "วางบนเกาะ" ในเมนูกดค้างของกระเป๋า (`InventoryController` เพิ่มสาขา `kind == "placeable"`
  · นอกเกาะขึ้นข้อความ "วางได้บนเกาะฟาร์มเท่านั้น" แทน) → ยิง BindableEvent `WOLD_StartPlacing(slotIndex, id)`
  **ที่ IslandBuildController เป็นคนสร้าง** ฝั่งปุ่มหยิบด้วย `FindFirstChild` ตอนกด (บทเรียน PremiumController)
- **โหมดวาง**: โคลนต้นแบบเป็น ghost (Transparency 0.5 · CanCollide/CanQuery/CanTouch = false · ไม่มี prompt)
  · ทุกเฟรม raycast จากกล้องผ่านเมาส์/นิ้ว ไป Terrain (Include {Terrain}) → `IslandGrid.cellOf` → วาง ghost
  ด้วย `pivotFor` · **ใต้ ghost วางแผ่นแบน 4×0.1×4 หนึ่งแผ่นต่อช่องของ footprint** สีเขียว/แดงตาม `canPlace`
  ฝั่งไคลเอนต์ (ช่องที่ใช้อ่านจากแอตทริบิวต์ `CellX/CellZ/Rot/Footprint` ของโมเดลใน `WOLD_Island.Placed`
  ทุกครั้งที่เข้าโหมด + `ChildAdded/Removed`) — สีเป็นคำแนะนำ **เซิร์ฟเวอร์เป็นคนตัดสิน** (StreamingEnabled
  อาจทำให้ไคลเอนต์ยังไม่เห็นบางชิ้น เซิร์ฟเวอร์จะปฏิเสธพร้อมเหตุผลเอง)
- **แถบล่าง 3 ปุ่ม** `[หมุน] [วาง] [ยกเลิก]` ใช้ได้ทั้งเมาส์และมือถือ + คีย์ลัด R / คลิกซ้าย / Esc ·
  วางสำเร็จ (InventoryUpdate บอกว่าช่องนั้นยังมีของ) → อยู่ในโหมดต่อเพื่อวางชิ้นถัดไป (รั้ว 20 อัน) หมดแล้วออก
- **ไม่ทำกริดคลุมทั้งเกาะ** (โดมโค้ง แผ่นแบนแผ่นเดียวลอย/จม) ถ้าอยากได้ทีหลังทำเป็น Decal บน Terrain
  หรือแผ่นย่อยตามโดม — นอกขอบเขตชุด A
- ปุ่ม "เก็บ" บนของที่วางแล้วเป็น ProximityPrompt ของเซิร์ฟเวอร์ ไคลเอนต์ไม่ต้องทำอะไร

## 5. แปลงปลูก `ServerScriptService/Island/IslandPlots.server.lua`

- gate เดียวกับ IslandBuild · ฟังโมเดลใน `WOLD_Island.Placed` ที่ `ItemId == "FarmPlot"` (ลูป 5 วิถามใหม่
  เรื่อยๆ ตามกฎเหล็ก ไม่ผูกครั้งเดียว) → แขวน `ProximityPrompt` ตัวที่สอง (F) บน `Soil`
- **ว่าง**: ป้าย "หยอดเมล็ด" · กด → มี `Seed` ในกระเป๋า? → หัก 1 → สุ่มพืชจาก `Crops` ตามน้ำหนัก →
  เขียน `crop, at = os.time()` ลง entry ใน `Data.Island.placed` (ตัวเดียวกับที่ IslandBuild ถือ — สองไฟล์แชร์
  ตารางเดียวผ่าน `IslandAccess.Entries()` / `IslandAccess.EntryOf(model)`)
- **โต**: ลูป 5 วิ `progress = (os.time() − at) / seconds` → ระยะ 3 ขั้นตาม `Stages` → โมเดล
  `Crop_<item>` โคลนครั้งเดียวแล้ว `ScaleTo(0.35 / 0.7 / 1.0)` · `ObjectText` = "ข้าว · เหลือ 12 นาที"
  (ไม่มีโค้ดไคลเอนต์ นาฬิกาอยู่บนปุ่มเลย) · **ออฟไลน์โตต่อฟรี** เพราะคิดจาก os.time
- **สุก**: ป้าย "เก็บเกี่ยว" · กด → `AddItem(item, random(min,max))` สำเร็จ → ล้าง `crop/at` ลบโมเดลพืช ·
  กระเป๋าเต็ม → "กระเป๋าเต็ม" พืชยังอยู่
- เจ้าของเท่านั้น (เช็ค UserId ทุกปุ่ม) — แขกยังเข้าไม่ได้อยู่แล้วในชุด A แต่ด่านต้องมีตั้งแต่วันนี้

## 6. ไฟล์ที่แตะ

| ไฟล์ | ใหม่/แก้ | อะไร |
|---|---|---|
| `farming.project.json` `serve-farming.bat` | ใหม่ | Phase 0 |
| `src/ServerScriptService/ServerConfig.lua` | แก้ | สาขา Farming + `FarmOwnerId` + `IslandMode` |
| `src/ServerScriptService/PlayerProfile.server.lua` | แก้ | ไม่อ่าน/เซฟ Position ในโหมด Farming |
| `src/ServerScriptService/Shop.server.lua` · `ReplicatedStorage/ShopConfig.lua` | แก้ | `IslandSells` เลือกตามโหมด |
| `src/ReplicatedStorage/ItemCatalog.lua` | แก้ | placeable 14 ชิ้น + Seed |
| `src/ReplicatedStorage/Remotes.lua` | แก้ | `IslandPlace` `IslandPickup` |
| `src/ReplicatedStorage/IslandConfig.lua` `IslandGrid.lua` | ใหม่ | เลข + ตรรกะตาราง |
| `src/ServerScriptService/Island/IslandAccess.lua` `IslandBuild.server.lua` `IslandPlots.server.lua` | ใหม่ | เซิร์ฟเวอร์ |
| `src/StarterPlayerScripts/IslandBuildController.client.lua` · `ReplicatedStorage/UI/IslandBuildGui.lua` | ใหม่ | โหมดวาง |
| `src/StarterPlayerScripts/InventoryController.client.lua` | แก้ | ปุ่ม "วางบนเกาะ" |
| `mapgen/90_island_placeables.lua` `mapgen/91_island_setup.lua` | ใหม่ | ต้นแบบ + NPC (รันในเพลส Farming) |
| `CLAUDE.md` | แก้ | กติกา denylist + วิธีรันเกาะ |

## 7. การทดสอบ

1. **IslandGrid** (ไม่ต้อง Play): โคลนโมดูลแล้ว require ผ่าน execute_luau — footprint 2×1 หมุน r=1 กิน
   ช่องถูกต้อง · ทับช่องที่มีของ = `"occupied"` · นอกวงรี = `"edge"` · ในวงห้าม = `"blocked"` · `pivotFor`
   หมุนครบ 4 ทิศได้กึ่งกลางเดิม
2. **Phase 0**: `rojo build` ทั้งสองโปรเจ็ค เทียบจำนวน instance · เพลสหลักเล่นได้เหมือนเดิม
3. **ในเพลส Farming (Studio Play + FORCE flag)** เรียงตามความเสี่ยง: เซิร์ฟบูตไม่มี error ใน F9 ทั้งสองฝั่ง →
   เกิดที่ SpawnLocation ไม่ใช่พิกัดเมืองหลัก → ได้ชุดเริ่มต้นครั้งเดียว (ออก-เข้าไม่ได้ซ้ำ) → ซื้อจาก NPC →
   วางบ้าน/รั้ว หมุน 4 ทิศ → วางทับ = แดง+ปฏิเสธ · ขอบเกาะ = แดง · จุดเกิด = แดง → เก็บคืนเข้ากระเป๋า →
   หยอดเมล็ดที่แปลง → แก้ `at` ย้อนหลังด้วย execute_luau ให้สุกทันที → เก็บเกี่ยว → ออก-เข้าใหม่ ทุกชิ้นอยู่ที่เดิม
   พืชระยะเดิม → เพดาน 300 (ตั้ง `MaxPlaced = 3` ชั่วคราว)
4. **Publish จริง** (Reserved Server เทสใน Studio ไม่ได้): เข้าจากล็อบบี้แท็บ Farming → เจ้าของถูกตัวจริง
   (`FarmOwnerId` จาก FarmRegistry) → บัญชีที่สองเข้าไม่ได้ (ด่านล็อบบี้เดิม)

## 8. สิ่งที่ตัดออกโดยตั้งใจ (เพิ่มเมื่อมีคนขอ)

- ปุ่มย้าย (= เก็บ+วาง) · กริดคลุมทั้งเกาะ · กล้องมุมสูงตอนวาง · โหมดวางอิสระไม่ล็อกตาราง
- เช็คความชันของช่อง (โดมเอียงน้อยพอ) · หลายชั้น/วางซ้อน · หมุนละเอียดกว่า 90°
- แขกทำอะไรบนเกาะได้บ้าง · เกาะตอนเจ้าของออฟไลน์ (ต้องใช้ `PeekAsync` อ่านอย่างเดียว) — ชุด C
- รูปไอคอนจริงของ placeable ทุกชิ้น (⌛ ไปก่อน)
