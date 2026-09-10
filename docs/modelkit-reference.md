# modelkit — คู่มืออ้างอิงสำหรับสร้างโมเดลด้วยโค้ด

ชุดเครื่องมือสร้างโมเดลจากพาร์ท พัฒนาในโปรเจ็ค `C:\Users\watch\WOLD-Models` แล้วก๊อปเข้ามาที่นี่
เอกสารนี้คือ**อ้างอิงฉบับเดียว** — ลายเซ็นทุกตัวดึงจากไฟล์จริง ไม่ได้เขียนจากความจำ

## ไฟล์ที่มี

| ไฟล์ | บรรทัด | หน้าที่ |
|---|---|---|
| `modelkit/kit.lua` | 516 | `K` — ทรงพื้นฐาน ชิ้นส่วนสตีมพังก์ เปลือกอาคาร จานสี ตัวรันกริดโชว์ |
| `modelkit/interior.lua` | 204 | ต่อ `K` — ผนังเจาะช่อง พื้น บันได ราวกันตก เฟอร์นิเจอร์ |
| `modelkit/interior2.lua` | 198 | ต่อ `K` — พื้นเจาะช่องบันได บันไดคำนวณขั้นเอง **ประตูเปิดอัตโนมัติ** ซี่กรง |
| `modelkit/rig.lua` | 333 | `R` — ตัวละคร R15 จริง ผม หน้า เชื่อมของเข้าข้อต่อ สคริปต์ idle/walk/เดินสุ่ม |
| `models/village.lua` | 690 | แลนด์มาร์ก 5 หลัง (กองอัศวิน โรงหมอ โรงเตี๊ยม โรงช่าง หอนาฬิกา) |
| `models/houses.lua` | 462 | บ้าน 5 แบบ |
| `models/npcs.lua` | 401 | NPC 12 ตัว (คน 9 บน rig R15 + สไลม์ 3) |
| `models/kit_showcase.lua` | 194 | โชว์ชิ้นส่วน 18 ชิ้นเรียงบนแท่น |
| `tools/model.js` | 264 | CLI: build / shot / overview / export / select / list / clear |
| `mapgen/55_town_buildings.lua` | 119 | ตัวอย่างการเอาโมเดลไปวางลงแปลงจริงในแมพ |

**ต้องมี `interior2.lua` เสมอ** เพราะมันเขียนทับ `K.floorSlab` ของ `interior.lua` (เวอร์ชันที่เจาะช่องบันไดได้)
ลำดับโหลดที่ถูกต้อง: `kit` → `interior` → `interior2` → `rig`

## วิธีรัน

```
node tools/run-luau.js mapgen/<ไฟล์>.lua --kit            เฟส mapgen ที่ใช้ K ได้ (มี L ของ terrain ด้วย)
node tools/run-luau.js mapgen/<ไฟล์>.lua --kit --models   โหลดไฟล์โมเดลแบบลงทะเบียน แล้วเรียก K.place ได้
```
ถ้าเปิด Studio หลายหน้าต่าง ตั้ง `WOLD_PLACE=<ส่วนของชื่อหน้าต่าง>` (ดีฟอลต์ที่นี่ = เพลสเกม `88774255487951`)

---

## ข้อตกลง 5 ข้อ ที่ต้องจำ

1. **ฐานอยู่ที่ y = 0 กึ่งกลางที่ x = 0 / z = 0 หน้าหันไปทาง -Z** (ตรงกับ `CFrame.LookVector`) ทุกโมเดลไม่มีข้อยกเว้น
2. **Part ทรง `Cylinder` วางตามแกน X ของตัวเอง** → `Size.X` คือความยาว ไม่ใช่ความสูง
   ใช้ `K.cyl` เมื่อต้องการทรงกระบอก**ตั้ง** และ `K.cylX` เมื่อต้องการให้**นอนตามแกน X ของ cf**
3. **`gear` `valveWheel` `gauge` `porthole` `propeller` `paddleWheel` หันหน้าตามแกน X ของ cf**
   - หน้าจานหันมาทางหน้าอาคาร (-Z) → คูณ `K.yaw(math.pi / 2)`
   - จานนอนราบ (เช่นมงกุฎเฟืองบนหัว) → คูณ `K.roll(math.pi / 2)`
4. **สเกลภายในต้องอิงตัวละคร ไม่ใช่คนจริง** — ตัวละคร R15 สูง ~5.5 studs กระโดดได้ ~7.5
   ค่าที่ใช้จริง: เพดาน **26** · ประตู **12 × 18** · หน้าต่าง **9 × 11 ธรณี 7** · โถงสูง (โรงช่าง) 44
5. **`Enum.Material.Copper` ไม่มีในโรบล็อกซ์** — สีทองแดงใช้ `MAT.Metal` + `K.C.copper`

---

## K — ทรงพื้นฐาน (`kit.lua`)

```lua
K.part(parent, shape, cf, size, mat, color, opts)   -- ตัวจริงที่ทุกตัวข้างล่างเรียก
K.box(parent, cf, size, mat, color, opts)
K.ball(parent, cf, diameter, mat, color, opts)
K.cyl(parent, cf, radius, height, mat, color, opts)      -- ทรงกระบอกตั้ง
K.cylX(parent, cf, radius, len, mat, color, opts)        -- นอนตามแกน X ของ cf
K.rod(parent, a, b, radius, mat, color, opts)            -- จากจุด a ถึงจุด b (Vector3)
K.wedge(parent, cf, size, mat, color, opts)              -- หน้าสูงอยู่ด้าน +Z ลาดลงไป -Z
K.cwedge(parent, cf, size, mat, color, opts)
K.model(parent, name)                                    -- Model เปล่าไว้จัดกลุ่ม
```
`opts` รับ: `name` · `cancollide = false` · `transparency` · `reflectance` · `massless`
ทุกพาร์ทออกมา **Anchored** และผิวเรียบทั้งบนล่าง

**หมุน** `K.yaw(rad)` `K.pitch(rad)` `K.roll(rad)` `K.at(x,y,z)` `K.deg(องศา)`

## K — ชิ้นส่วนสตีมพังก์

```lua
K.gear(parent, cf, r, teeth, thick, color)
K.boiler(parent, cf, r, h, opts)          -- opts: bands, rivets, firebox, color, name
K.smokestack(parent, cf, r, h, opts)      -- opts: smoke, color, cap  (ฐานอยู่ที่ cf)
K.pipe(parent, pts, radius, color, opts)  -- pts = ลิสต์ Vector3 ต่อกันด้วยข้อต่อลูกกลม
K.valveWheel(parent, cf, r, spokes, color)
K.gauge(parent, cf, r, color)
K.porthole(parent, cf, r, opts)           -- opts: color, glass, rivets
K.propeller(parent, cf, r, blades, color)
K.paddleWheel(parent, cf, r, w, blades)
K.spring(parent, a, b, r, coils, color)
K.chain(parent, a, b, links, r, color)
K.rivets(parent, a, b, n, r, color)       -- แถวหมุดจาก a ถึง b
K.rivetRing(parent, cf, radius, n, r, color)
K.band(parent, cf, radius, thick, color)  -- ห่วงรัดรอบทรงกระบอกตั้ง
K.lantern(parent, cf, s, color)           -- มี PointLight ในตัว ฐานอยู่ที่ cf
```

## K — เปลือกอาคาร

```lua
K.roofGable(parent, cf, w, d, h, mat, color, overhang)   -- สันหลังคาไปตามแกน Z
K.roofCone(parent, cf, r, h, mat, color, steps)          -- กรวยซ้อนชั้น
K.window(parent, cf, w, h, frameColor, lit)              -- lit = true จะมีไฟในตัว
K.doorway(parent, cf, w, h, color, mat)                  -- ประตูตายตัว (ไม่เปิด)
K.timberWall(parent, cf, w, h, d, plaster, beam)         -- ผนังปูนคาดไม้ ครึ่งไม้ครึ่งปูน
K.lampPost(parent, cf, h, color)
K.banner(parent, cf, w, h, color, poleH)
K.sign(parent, cf, text, w, h, color, textColor)         -- อ่านออกทาง -Z ของตัวป้าย
K.plankFloor(parent, cf, w, d, plankW, color, mat)
K.crate(parent, cf, s, color)
K.barrel(parent, cf, r, h, color)
```

## K — ภายในอาคาร (`interior.lua` + `interior2.lua`)

```lua
-- ผนังที่เจาะเป็นช่องจริง เดินผ่านและมองผ่านได้
K.wallRun(parent, cf, w, h, d, mat, color, openings, opts)
--   openings = { { x = 0, w = 12, h = 18, sill = 0 }, { x = 14, w = 9, h = 11, sill = 7 } }
--   ผนังถูกตัดเป็นเสา (pier) / อกไก่ (apron) / ทับหลัง (lintel) รอบช่อง

-- พื้นมีตงรองรับ opts.hole เจาะช่องบันได
K.floorSlab(parent, cf, w, d, mat, color, opts)
--   opts = { name = "...", hole = { x = 20, z = 4, w = 15, d = 40 } }

-- บันไดหนึ่งช่วง คำนวณจำนวนขั้นจาก rise เอง คืนค่า run ที่ใช้ไป
K.stairFlight(parent, cf, width, rise, mat, color, opts)
--   opts = { run = 26, stepRise = 1.15, rails = false, railColor = ..., name = ... }
--   ไต่ไปทาง +Z ของ cf · ดีฟอลต์ run = rise × 1.05 (ชัน 45°)

K.railing(parent, cf, len, h, color, mat)
K.dormer(parent, cf, w, h, d, wallMat, wallCol, roofMat, roofCol)
K.stairsRun(parent, cf, width, rise, run, steps, mat, color)   -- รุ่นเก่า ต้องระบุ steps เอง
```

### ประตูเปิดเองเมื่อวิ่งชน

```lua
K.autoDoor(parent, cf, w, h, opts)
--   opts = { color, mat, thick, single = true, swing = -95, closeAfter = 2.5, name }
--   w ≥ 9 จะเป็นประตูสองบานเปิดออกสองข้าง (ใส่ single = true เพื่อบังคับบานเดียว)
K.cellDoor(parent, cf, w, h, opts)   -- ซี่เหล็ก ทำงานแบบเดียวกัน
K.bars(parent, cf, w, h, opts)       -- ซี่กรงตายตัว opts: spacing, r, color
```
กลไก: บานประตูเก็บ `SwingDeg` + `HingeX/HingeZ` ไว้ใน Attribute ของตัวเอง มี `Sensor` โปร่งใสคลุมช่องประตู
และ `Script` ชื่อ `AutoDoor` คอย `Touched` — เจอ Humanoid แล้ว tween เปิด ปิดเองเมื่อพ้น `CloseAfter` วินาที
**สคริปต์ทำงานเฉพาะใน Play mode** (Edit จะเห็นประตูปิดนิ่งตามปกติ)

### เฟอร์นิเจอร์

```lua
K.table(parent, cf, w, d, h, color, mat)
K.chair(parent, cf, color, mat)
K.bed(parent, cf, w, len, color, cloth)
K.shelf(parent, cf, w, h, d, color, levels, fill)    -- fill = false จะเป็นชั้นเปล่า
K.chest(parent, cf, s, color)
K.counter(parent, cf, w, d, h, color, mat)
K.fireplace(parent, cf, w, h, color, lit)
K.rug(parent, cf, w, d, color)
```

## K — จานสีและตัวช่วย

`K.C` มี 34 สี:
`brass brassDark copper verdigris iron steel rust coal wood plank plankDark oak leather canvas sail rope glass lamp crystal ember stone darkStone paintRed paintBlue paintGreen white black plaster thatch moss brick grass soil slateRoof`

```lua
K.tag(inst, tagName, attrs)     -- CollectionService tag + Attribute ในทีเดียว
K.attrs(inst, table)
K.mirrorX(parent, group)        -- โคลนกลุ่มแบบกระจกข้าม x = 0
K.arrayAlong(a, b, n, fn)       -- เรียก fn(pos, i, t) ที่ n จุดจาก a ถึง b
K.countParts(inst)
K.MAT  K.SHAPE                  -- ทางสั้นไป Enum.Material / Enum.PartType
```

---

## R — ตัวละคร R15 (`rig.lua`)

```lua
R.new(m, opts)         -- opts: baseY, skin, shirt, pants, height, width, head, depth,
                       --       bodyType, proportion, health, walkSpeed, face = false
R.face(m, texture)     -- เดคัลหน้า ดีฟอลต์ rbxasset://textures/face.png (R.new เรียกให้แล้ว)
R.eyes(m, opts)        -- ตาแบบพาร์ท opts: size, color, mat, brow
R.hair(m, style, color, mat)   -- style: "short" "long" "ponytail" "bun" "wild" "bald"
R.beard(m, color, mat, long)
R.paint(m, { "RightUpperArm", "RightHand" }, color, mat)   -- เปลี่ยนแขนเป็นจักรกล
R.attach(m, limbName, fn, holderName)   -- ★ สำคัญที่สุด
R.limb(m, name)  R.weld(part, limb)
R.controller(m, opts)        -- opts: idle, walk, wander, wanderMin, wanderMax, walkSpeed
R.slimeController(m, opts)   -- opts: wander, hopEvery, hopHeight, hopTime (ต้องมีลูกชื่อ "Body")
R.nametag(m, title, role, color, anchor)
R.prompt(m, action, object, anchor)
R.LIMBS   R.ANIM   -- ชื่อข้อต่อ 16 ชิ้น / id อนิเมชันดีฟอลต์
```

**`R.attach` คือหัวใจ** — ของที่สร้างข้างในจะถูก unanchor + `WeldConstraint` ติดข้อต่อนั้น จึงขยับตามอนิเมชัน
ของที่สร้าง**นอก** `R.attach` จะยัง Anchored อยู่กับที่ (ตั้งใจ — ทั่งตีเหล็ก ลังสินค้า ควรอยู่กับร้าน ไม่เดินตาม NPC)

```lua
R.attach(m, "RightHand", function(g, HD)     -- HD = CFrame ของข้อต่อ ณ ตอนสร้าง
  local handle = K.box(g, HD * CFrame.new(0, -0.85, -0.1), Vector3.new(0.22, 2, 0.22), MAT.Wood, C.wood)
  K.box(g, handle.CFrame * CFrame.new(0, -1.1, 0), Vector3.new(1, 0.85, 1.5), MAT.Metal, C.steel)
end, "Hammer")
```

---

## สองโหมดของ K.build

```lua
K.build("ชื่อโมเดล", opts, function(m) ... end)
```
- **โหมดปกติ** (โปรเจ็ค WOLD-Models) — สร้างขึ้นบนแท่นโชว์ในกริด `workspace.MODELKIT` ตามช่องของ set
  ตั้งค่าหัวไฟล์: `K.SET` (ชื่อชุด) `K.SLOT` (ระยะช่อง) `K.PER_ROW` `K.ORIGIN` (มุมเริ่มกริด)
  `opts.pad = false` = ไม่สร้างแท่น
- **โหมดลงทะเบียน** — ตั้ง `K.REGISTER_ONLY = true` ก่อนโหลดไฟล์โมเดล `K.build` จะเก็บตัวสร้างไว้ใน `K.builders`
  แล้วเอาไปวางที่ไหนก็ได้ด้วย:
  ```lua
  K.place("Village_Tavern", parentFolder, cf)   -- ฐานอยู่ที่ cf หน้าหันไปทาง -Z ของ cf
  ```
  `run-luau.js --models` ทำขั้นนี้ให้อัตโนมัติ ดูตัวอย่างครบที่ `mapgen/55_town_buildings.lua`

ตัวรันจะใส่พาร์ทโปร่งใสชื่อ `Root` เป็น `PrimaryPart` ที่จุด origin ให้ทุกโมเดล → `PivotTo` ได้ตรงๆ

---

## โครงไฟล์โมเดลใหม่หนึ่งไฟล์

```lua
K.SET = "myset"
K.SLOT = 150
K.PER_ROW = 3
K.ORIGIN = Vector3.new(0, 0, 1400)

local C, MAT = K.C, K.MAT
local ST = 26                    -- เพดาน
local DOOR_W, DOOR_H = 12, 18

K.build("MyBuilding", nil, function(m)
  K.box(m, CFrame.new(0, -1, 0), Vector3.new(60, 2, 44), MAT.Cobblestone, C.darkStone, { name = "Plinth" })
  K.floorSlab(m, CFrame.new(0, 0, 0), 56, 40, MAT.WoodPlanks, C.plankDark)
  K.wallRun(m, CFrame.new(0, 0, -20), 56, ST, 2.4, MAT.Brick, C.brick,
    { { x = -8, w = DOOR_W, h = DOOR_H }, { x = 12, w = 9, h = 11, sill = 7 } }, { name = "Front" })
  K.autoDoor(m, CFrame.new(-8, 0, -21.4), DOOR_W, DOOR_H, { color = C.wood })
  local run = K.stairFlight(m, CFrame.new(20, 0, -14), 11, ST, MAT.WoodPlanks, C.plankDark)
  K.floorSlab(m, CFrame.new(0, ST, 0), 56, 40, MAT.WoodPlanks, C.plank,
    { name = "Upper", hole = { x = 20, z = -14 + run / 2 + 3, w = 15, d = run + 8 } })
  K.roofGable(m, CFrame.new(0, ST * 2, 0), 56, 40, 20, MAT.Slate, C.slateRoof, 4)
  K.bed(m, CFrame.new(-14, ST, 8) * K.yaw(math.pi / 2), 8, 15, C.wood)
end)
```

---

## บทเรียนที่เสียเวลาไปแล้ว — อ่านก่อนสร้าง

- **บันไดชัน 37° กินพื้น 35 studs ต่อชั้น** ซึ่งห้องขนาดนี้ไม่มีที่พอ → ใช้ 45° (`run = rise × 1.05`)
- **ของที่เผลอวางคร่อมช่องบันไดทำให้ขึ้นไม่ได้** เจอมาแล้ว 5 อย่าง: บันไดยาวเกินห้อง, เตียง, ชั้นวางของ,
  โคมไฟห้อยเพดาน, **และประตู**
  → **ตรวจด้วยการปล่อยตัวละคร R15 จริงเดินขึ้นใน Play mode ไม่ใช่ดูจากภาพนิ่ง** ภาพไม่เห็นปัญหาเหล่านี้เลย
  วิธีตรวจ: `Players:CreateHumanoidModelFromDescription(Instance.new("HumanoidDescription"), Enum.HumanoidRigType.R15)`
  วางที่โคนบันได 4 studs แล้ว `Humanoid:MoveTo(ปลายบันได)` วนจนถึงหรือหมดเวลา แล้วเทียบความสูงที่ไปถึง
- **จานซ้อนกันเป็นชั้นความสูงต่างกัน วงนอกจะกลบวงใน** → พื้นแบบขั้นบันไดต้องทำเป็นวงแหวนกลวงแบ่งส่วนโค้ง
- **`K.sign` / `SurfaceGui`** อ่านออกทาง -Z ถ้าหันผิดจะเห็นแต่แผ่นเปล่า
- **BillboardGui ไม่ติดในภาพ `screen_capture`** ของ MCP (เห็นในวิวพอร์ต Studio ปกติ)
- **`export` เป็น `.lua` ได้แค่รูปทรง** — dump อ่านเฉพาะ BasePart + PointLight + Smoke
  ประตูอัตโนมัติ ParticleEmitter BillboardGui ProximityPrompt **หายทั้งหมด** → อาคาร/NPC ต้องใช้ `.rbxm` หรือรันตัวสร้างซ้ำ
