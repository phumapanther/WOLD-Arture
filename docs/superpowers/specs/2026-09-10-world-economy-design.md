# NPC, พาหนะ และเศรษฐกิจในแมพ — ดีไซน์

วันที่ 2026-09-10 · สถานะ: รออนุมัติ

หกระบบที่ผู้ใช้สั่ง: พาหนะ, ฟาร์ม, คราฟ, ธนาคาร/คลัง, ร้านค้า, ฝากขาย
บวกโปรเจ็คแยกสำหรับปั้นโมเดล และผังเมืองแรกที่จุดเกิด

---

## 0. หลักการที่ทุกระบบใช้ร่วมกัน

### โมเดลไม่รู้จักโค้ด โค้ดไม่รู้จักโมเดล

ผู้ใช้จะปั้นโมเดลในโปรเจ็คแยกแล้วส่งออกเป็น `.rbxm` มาวางเอง **โมเดลจะไม่มีสคริปต์อยู่ข้างใน**
ทั้งสองฝั่งเจอกันผ่าน **Tag + Attribute** เท่านั้น:

```
โมเดล (ผู้ใช้วาง)          Tag             Attribute ที่ต้องมี
─────────────────────────────────────────────────────────────────
NPC ช่างฝีมือ              WOLD_Npc        NpcKind="crafter"
NPC คลัง/ธนาคาร            WOLD_Npc        NpcKind="banker"
NPC เฒ่าแก่ (ร้านชำ)        WOLD_Npc        NpcKind="shop"
NPC พ่อค้า (ฝากขาย)         WOLD_Npc        NpcKind="auction"
จุดฟาร์มแร่เหล็ก            WOLD_Node       NodeKind="IronOre"
จุดฟาร์มคริสตัล             WOLD_Node       NodeKind="Crystal"
จุดฟาร์มไม้                 WOLD_Node       NodeKind="Wood"
จุดฟาร์มสมุนไพร             WOLD_Node       NodeKind="Herb"
จุดเรียกพาหนะ               WOLD_Dock       DockKind="car"|"boat"|"airship"
จุดเกิดมอนสเตอร์            WOLD_Spawner    MobKind="Slime"|"Spider"|"Skeleton"
```

**เหตุผล:** ผู้ใช้ย้ายตำแหน่งได้อิสระโดยไม่กระทบโค้ด และเจนแมพซ้ำก็ไม่ลบของที่วางมือ
(กติกาเดิมจาก `04-gameplay-hooks.md` — ระบบนี้ใช้กติกาเดียวกัน ไม่คิดใหม่)

โค้ดฝั่ง server จะ `CollectionService:GetTagged(...)` ตอนเริ่ม แล้วฟัง `GetInstanceAddedSignal`
เพื่อรับของที่วางเพิ่มทีหลัง

### ทุกอย่างเป็น server-authoritative

client บอกได้แค่ "ฉันอยากทำ X" — ไม่เคยส่งจำนวนเงิน จำนวนของ หรือราคา
รูปแบบเดียวกับ `Trading.server.lua` และ `Bank.lua` ที่มีอยู่

### ต่อยอดของเดิม ไม่สร้างซ้ำ

| ต้องการ | ใช้ของที่มีอยู่แล้ว |
|---|---|
| เพิ่มของเข้ากระเป๋า | `Inventory.AddItem` |
| เงินในกระเป๋า | `Inventory.AddGold` |
| เงินในธนาคาร | `Bank.lua` (มีครบแล้ว: ฝาก ถอน โอน) |
| เซฟข้าม session | `ProfileAccess` + `Flush` |
| ปุ่มกดตอนเข้าใกล้ | `ProximityPrompt` (แบบเดียวกับ `TestChest`) |
| ราคาพื้นฐานของไอเทม | `ItemCatalog[id].value` มีอยู่แล้วทุกตัว |
| วัตถุดิบฟาร์ม | `IronOre` `Crystal` `Herb` `Fiber` `Bone` `WoodScrap` `Stone` มีไอคอนครบแล้ว |

**ธนาคารเกือบเสร็จแล้ว** — `Bank.lua` มีฝาก/ถอน/โอนครบ ขาดแค่ NPC กับ UI
คลังสินค้า (ฝากของ) เป็นของใหม่จริง

---

## 1. ฟาร์มของ + มอนสเตอร์  ← เริ่มที่นี่

### จุดฟาร์ม

`WOLD_Node` + `NodeKind` วางไว้ที่ไหนก็ได้ในแมพ

ไฟล์ใหม่: `src/ReplicatedStorage/GatherConfig.lua`

```lua
GatherConfig.Nodes = {
    IronOre = { item = "IronOre", min = 1, max = 3, seconds = 3.0, respawn = 45,
                tool = "pickaxe", xp = 8 },
    Crystal = { item = "Crystal", min = 1, max = 1, seconds = 5.0, respawn = 180,
                tool = "pickaxe", xp = 25 },
    Wood    = { item = "WoodScrap", min = 2, max = 4, seconds = 2.5, respawn = 30,
                tool = "axe",     xp = 5 },
    Herb    = { item = "Herb", min = 1, max = 2, seconds = 1.5, respawn = 25,
                tool = nil,       xp = 4 },
}
```

การเก็บ: กดค้าง `seconds` ที่ ProximityPrompt → ได้ของ → จุดนั้นหายไป `respawn` วินาที แล้วกลับมา

**`tool` ยังไม่บังคับในเฟสแรก** (ยังไม่มีขวาน/พลั่วในเกม) เขียนไว้ในคอนฟิกเพื่อไม่ต้อง migrate ทีหลัง

**การหายของจุดฟาร์ม** ต้องเป็นรายผู้เล่นหรือรายเซิร์ฟเวอร์? → **รายเซิร์ฟเวอร์**
ทุกคนเห็นตรงกัน คนมาก่อนได้ก่อน ซึ่งเป็นเหตุผลให้ต้องออกไปหาที่ใหม่

### มอนสเตอร์

`WOLD_Spawner` + `MobKind` — สุ่มเกิดในรัศมีรอบจุด

```lua
GatherConfig.Mobs = {
    Slime    = { hp = 40,  damage = 6,  drops = {{ "SlimeMeat", 1, 2 }}, xp = 10, respawn = 30 },
    Spider   = { hp = 60,  damage = 10, drops = {{ "Fiber", 1, 3 }},     xp = 18, respawn = 40 },
    Skeleton = { hp = 100, damage = 16, drops = {{ "Bone", 1, 2 }},      xp = 30, respawn = 60 },
}
```

`SlimeMeat` เป็นไอเทมใหม่ตัวเดียวที่ต้องเพิ่มใน `ItemCatalog` (อีกสองตัวมีแล้ว)

**AI ของมอนสเตอร์:** เดินสุ่มในรัศมี เห็นผู้เล่นในระยะ → เดินเข้าหา → ตีตามคูลดาวน์
ใช้ `Humanoid:MoveTo` ธรรมดา ไม่ใช้ PathfindingService ในเฟสแรก
(ที่โล่งใช้ MoveTo ก็พอ ถ้าติดอุปสรรคค่อยอัปเกรด — YAGNI)

ดาเมจเข้าผู้เล่นผ่าน `Vitals.ApplyDamage(player, amount, "combat")` ทางเดียวที่มีอยู่แล้ว
ผู้เล่นตีมอนสเตอร์: ต่อยอด `PlayerCombat` ที่รู้จัก `WOLD_Dummy` อยู่แล้ว

ไฟล์ใหม่: `src/ServerScriptService/Gathering.server.lua`, `Mobs.server.lua`

---

## 2. ร้านขายของ (เฒ่าแก่)  ← เฟสแรกเช่นกัน

NPC `NpcKind="shop"` มีสองแท็บ

### ขายวัตถุดิบ — ราคาลอยตัว

ราคาสุ่มใหม่ **ทุก 30 นาที** ตามที่สั่ง คูณกับ `ItemCatalog[id].value`

```lua
ShopConfig.PriceSwing = 0.35   -- ±35% รอบราคาฐาน
ShopConfig.RerollSeconds = 1800
```

ราคาเป็นของ**ทั้งเซิร์ฟเวอร์** ไม่ใช่รายคน และประกาศเวลาที่จะเปลี่ยนรอบถัดไปใน UI
เก็บ seed ไว้ใน DataStore เพื่อให้ทุกเซิร์ฟเวอร์เห็นราคาเดียวกัน — **เลื่อนไปเฟสหลัง**
เฟสแรกสุ่มต่อเซิร์ฟเวอร์ (ง่ายกว่ามาก และผลต่างยังไม่สำคัญตอนคนน้อย)

### ซื้อของจิปาถะ — ราคาคงที่

`Bread` `Water` `HealthPotion` มีอยู่แล้วใน catalog ราคาคงที่ สต็อกไม่จำกัด

ไฟล์: `src/ReplicatedStorage/ShopConfig.lua`, `src/ServerScriptService/Shop.server.lua`

---

## 3. คลังสินค้า + ธนาคาร

NPC `NpcKind="banker"` สองเมนู

**เมนูการเงิน** — ต่อสายตรงเข้า `Bank.lua` ที่มีอยู่ ไม่เขียนใหม่

**เมนูคลังสินค้า** — ของใหม่ ช่องเก็บของแยกจากกระเป๋า
- ไม่คิดน้ำหนัก (นั่นคือเหตุผลที่ฝาก)
- **ไม่หายตอนตาย** เหมือนเงินในธนาคาร
- เริ่มที่ 40 ช่อง
- เก็บใน profile คีย์ใหม่ `Storage`

ไฟล์: `src/ServerScriptService/Storage.lua`

---

## 4. คราฟของ

NPC `NpcKind="crafter"` — เลือกสูตรจากวัตถุดิบในตัว

```lua
CraftConfig.Recipes = {
    { id = "HealthPotion", cost = {{ "Herb", 3 }}, seconds = 2, fee = 5 },
    { id = "Sword",        cost = {{ "IronOre", 5 }, { "WoodScrap", 2 }}, seconds = 4, fee = 40 },
    { id = "LeatherArmor", cost = {{ "Fiber", 8 }}, seconds = 4, fee = 30 },
}
```

`fee` เป็นค่าจ้างช่าง — ทางระบายเงินออกจากเศรษฐกิจ ไม่งั้นเงินเฟ้อแน่นอน

ไฟล์: `src/ReplicatedStorage/CraftConfig.lua`, `src/ServerScriptService/Crafting.server.lua`

---

## 5. ฝากขาย (ตลาดประมูล)

NPC `NpcKind="auction"` — ตั้งราคาอิสระตามที่สั่ง

- ของถูก**ยึดออกจากกระเป๋าทันที**ตอนฝาก (กันดูป: ฝากแล้วยังถืออยู่ = ปั๊มของ)
- ประกาศได้ 20 รายการต่อคน
- หมดอายุ 3 วัน → ของกลับไปที่ช่องรับคืน
- ค่าธรรมเนียม 5% หักตอนขายได้

**ข้ามเซิร์ฟเวอร์** ต้องใช้ DataStore กลาง + MessagingService ซึ่งเป็นงานใหญ่และเสี่ยง race
→ เฟสแรกทำแบบ**เซิร์ฟเวอร์เดียว** ให้ทำงานถูกต้องก่อน แล้วค่อยขยาย

ไฟล์: `src/ServerScriptService/Auction.server.lua`

---

## 6. พาหนะ

### กุญแจเป็นไอเทมในกระเป๋า — 1 ใบ = 1 ทะเบียน

ไอเทมใหม่ 3 ตัวใน `ItemCatalog`: `CarKey` `BoatKey` `AirshipKey`
**กุญแจแต่ละใบมีทะเบียนของตัวเอง** (เช่น `"BH-1042"`) ถือหลายใบ = มีหลายคัน

ทะเบียนผูกกับ**ใบกุญแจ** ไม่ใช่กับผู้เล่น ผลที่ตามมา:
- กุญแจ**ส่งต่อได้** — ให้เพื่อน ทิ้ง เทรด ขายในตลาดประมูล คนที่ได้ไปก็เรียกคันนั้นได้
- กุญแจหาย = คันนั้นเรียกไม่ได้อีกเลย (ทำสำรองไม่ได้ในเฟสแรก)

#### ปัญหาที่ต้องแก้ก่อน: ระบบกระเป๋าปัจจุบันเก็บทะเบียนไม่ได้ — **แก้แล้ว 2026-09-10**

ช่องในกระเป๋าเก็บแค่ `{ id, count, durability }` และ `Inventory.AddItem` **รวมกองโดยดูแค่ `id`**
ถ้ากุญแจสองใบใช้ `id` เดียวกัน มันจะกองรวมกันเป็น "CarKey x2" แล้วทะเบียนจะเหลือใบเดียว

ทางแก้ที่เลือก: **เพิ่มช่อง `meta` ในสล็อต และห้ามของที่มี `meta` รวมกอง**

```lua
-- slot = { id, count, durability, meta = { plate = "BH-1042" } }
```

`AddItem` รับ `meta` เป็นพารามิเตอร์เพิ่ม และข้ามการรวมกองเมื่อมี `meta`
(ทำแบบเดียวกับที่อาวุธ/เกราะไม่รวมกองอยู่แล้วเพราะมี `durability` ของตัวเอง — มีโค้ดรองรับแนวคิดนี้แล้วที่ `Inventory.AutoSort` บรรทัด 143)

**แก้ไปแล้วทั้งชุด:** `AddItem` (รับ `meta` และไม่รวมกอง), `AutoSort` (นับเป็น single),
`Trading`/`Arrest` (ใส่ `meta` ตอนสร้าง entry), `ClassActions` (ตอนให้ของ), `Inventory.Equip`/`Unequip`
`Serialize` ไม่ต้องแก้ — มันส่งทั้งตาราง slot อยู่แล้ว `meta` จึงรอดข้าม session เอง

ทดสอบใน Play แล้ว: กุญแจ 3 ใบ 3 ทะเบียน = 3 ช่อง, ทนต่อ `AutoSort`, และแร่เหล็ก 3+4 ยังรวมเป็นกองเดียว 7 ชิ้น

ตัวรถถูกเรียกออกมาใหม่ทุกครั้ง ไม่ได้จอดค้างในโลก

### เรียกพาหนะ

`WOLD_Dock` + `DockKind` สามจุดตามที่สั่ง:

| จุด | ที่ตั้ง | อ้างอิงพิกัด |
|---|---|---|
| เรียกรถ | ใกล้จุดเกิด | ข้าง `WOLD.TempSpawn` |
| เรียกเรือ | ริมชายฝั่ง | ท่าเรือ Brasshaven (อ่าวทิศ 45°) |
| เรียกเรือเหาะ | บนภูเขา | ยอด `peaks.main_NE` |

กดที่จุด → ถ้ามีกุญแจตรงชนิด → พาหนะถูกสร้างจาก `.rbxm` ที่ผู้ใช้ทำ ใน `ServerStorage.WOLD_Vehicles`
พาหนะเดิมของคนนั้นถูกลบก่อนเสมอ (คนละ 1 คันต่อชนิด ไม่งั้นถล่มเซิร์ฟเวอร์)

### ขับและล็อก

- **ทุกคนขับได้** ตามที่สั่ง — นั่ง VehicleSeat แล้วขับ
- **ทุกคนเปิดดูของได้** เป็นค่าเริ่มต้น
- **คนถือกุญแจที่ทะเบียนตรงกับคันนั้น** สั่งล็อกได้ 2 อย่างแยกกัน: ล็อกไม่ให้ขึ้น / ล็อกไม่ให้เปิดของ

เก็บสถานะล็อกไว้ที่ Attribute บนตัวพาหนะ ตรวจฝั่ง server ทุกครั้งที่มีคนพยายามนั่งหรือเปิด
การตรวจสิทธิ์ = ไล่หาในกระเป๋าว่ามีกุญแจที่ `meta.plate` ตรงกับ `Plate` ของคันนั้นไหม
(ไม่ใช่ดูว่าใครเรียกออกมา — คนเรียกอาจส่งกุญแจต่อไปแล้ว)

ไฟล์: `src/ReplicatedStorage/VehicleConfig.lua`, `src/ServerScriptService/Vehicles.server.lua`

**ฟิสิกส์:** ใช้ `VehicleSeat` + `LinearVelocity`/`AngularVelocity` ของ Roblox
เรือเหาะบินได้เพราะไม่มีแรงโน้มถ่วงกระทำ (`VectorForce` หักล้าง) ไม่ทำ flight model จริง

---

## 7. โปรเจ็คปั้นโมเดล (แยก place)

place ใหม่ชื่อ `WOLD Arture - Models` **ไม่มีสคริปต์ระบบเลย**

```
ServerStorage/
  WOLD_Models/
    Npc/         Crafter, Banker, Shopkeeper, Auctioneer
    Vehicles/    SteamCar, SteamBoat, Airship
    Nodes/       IronOreVein, CrystalNode, TreeStump, HerbPatch
    Mobs/        Slime, Spider, Skeleton
    Buildings/   Warehouse, GroceryShop, AuctionHouse, Smithy, BankHall
```

**สัญญาที่โมเดลต้องทำตาม** (เขียนไว้ใน `docs/design/05-model-contract.md`):
- มี `PrimaryPart` เสมอ
- จุดหมุนอยู่ที่**ฐานของโมเดล** (เพื่อวางบนพื้นแล้วไม่จม)
- NPC ต้องมี `Humanoid` + `HumanoidRootPart` (ใช้อนิเมชันมาตรฐานได้)
- พาหนะต้องมี `VehicleSeat` ชื่อ `DriverSeat`
- ตั้ง Tag/Attribute ตามตาราง §0 ให้เรียบร้อยก่อนส่งออก

ส่งออก: คลิกขวา → Save to File → `.rbxm` แล้ววางในโฟลเดอร์ `models/` ของโปรเจ็คนี้
นำเข้า: ผู้ใช้ลากเข้า Studio เอง แล้วจัดตำแหน่ง

---

## 8. ผังเมืองแรก

Claude เจนผังรอบจุดเกิดให้ก่อน แล้วผู้ใช้แก้มือทีหลัง (มี `Manual=true` กันการเจนทับ)

วางรอบจัตุรัสตลาด Brasshaven ที่ layout กำหนดไว้แล้ว:

```
        [คลัง/ธนาคาร]
              |
[ร้านชำ] — จัตุรัส — [ช่างฝีมือ]
              |
        [ตลาดประมูล]
              |
         จุดเรียกรถ
```

เจนเป็นแท่นวางเปล่า + ป้ายชื่อ ไม่ใช่ตัวอาคาร — ผู้ใช้เอาโมเดลจริงมาวางทับ
ไฟล์: `mapgen/50_first_town.lua`

---

## ลำดับการทำ

| เฟส | ได้อะไร | ไฟล์หลัก |
|---|---|---|
| **1** | ฟาร์ม + มอนสเตอร์ + ร้านขายของ | `GatherConfig`, `Gathering.server`, `Mobs.server`, `Shop.server` |
| 2 | ผังเมือง + สัญญาโมเดล | `mapgen/50_first_town.lua`, `05-model-contract.md` |
| 3 | คลัง + ธนาคาร (ต่อ `Bank.lua` เดิม) | `Storage.lua` |
| 4 | คราฟ | `CraftConfig`, `Crafting.server` |
| 5 | พาหนะ (`Inventory` รองรับ `meta` แล้ว) | `VehicleConfig`, `Vehicles.server` |
| 6 | ฝากขาย | `Auction.server` |

เฟส 1 ทำให้เกมมีวงจรครบวงแรกทันที: **ออกไปเก็บของ → ตีมอน → เอามาขาย → ได้เงิน**
ซึ่งเล่นได้จริงโดยไม่ต้องรอห้าเฟสที่เหลือ

---

## สิ่งที่จงใจไม่ทำในเฟสแรก

| ไม่ทำ | เพราะ |
|---|---|
| ราคาร้านค้าข้ามเซิร์ฟเวอร์ | ต้อง DataStore กลาง ตอนคนน้อยยังไม่ต่างกัน |
| ฝากขายข้ามเซิร์ฟเวอร์ | race ข้ามเซิร์ฟเวอร์เป็นงานใหญ่แยกต่างหาก |
| PathfindingService ให้มอนสเตอร์ | ที่โล่ง `MoveTo` พอ อัปเกรดเมื่อเจอปัญหาจริง |
| ต้องมีเครื่องมือถึงจะฟาร์มได้ | ยังไม่มีขวาน/พลั่วในเกม เขียนคอนฟิกรอไว้แล้ว |
| flight model เรือเหาะ | หักแรงโน้มถ่วงพอ ไม่ต้องจำลองอากาศพลศาสตร์ |
