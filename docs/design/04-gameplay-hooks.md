# ข้อกำหนดระบบเกมหลักชุดแรก และจุดเชื่อมต่อที่แมพต้องเตรียมไว้ (บันทึก 2026-09-06 หลังสนามทดสอบผ่าน)

ผู้ใช้อนุมัติสนามทดสอบ (ข้อ 0) พร้อมสั่ง 2 ข้อกำหนดที่มีผลกับทุกขั้นเจนแมพ:

## 1. แมพต้องแก้ด้วยมือคนได้ทีหลัง

| กฎ | วิธีทำในตัวเจน |
|---|---|
| ทุกสิ่งที่เจนอยู่ใต้ `workspace.WOLD.<ชื่อขั้น>` เป็น Model ชื่อสื่อความหมาย (เช่น `Capital/Ironcrest Keep/GateTower`) | ทำอยู่แล้ว เปิด Explorer เลือกแก้ย้ายลบได้ทันที |
| ของที่คนแก้/เพิ่มเองต้องไม่หายเมื่อรันขั้นนั้นซ้ำ | ใส่ Attribute `Manual = true` ที่ Instance ใดก็ได้ ตัวเจนจะย้ายไป `workspace.WOLD.Manual` ก่อนลบโฟลเดอร์ขั้นเดิม และไม่แตะโฟลเดอร์ `Manual` เลย |
| Terrain แก้ด้วยเครื่องมือ Terrain Editor ของ Studio ได้ตรงๆ | รันขั้น Terrain ซ้ำเท่านั้นที่จะทับ ถ้าแก้มือแล้วห้ามรันขั้น 10 อีก (หรือรันแล้วแก้ใหม่) |
| หลังแมพเสร็จ (ข้อ 10) ถือว่า **place คือแหล่งความจริงของรูปทรง** | สคริปต์เจนเก็บไว้เพื่อสร้างซ้ำจากศูนย์เท่านั้น การแก้ละเอียดทำในไฟล์ place |
| ปรับพารามิเตอร์ระดับผังทำใน `world-layout.json` | ตำแหน่ง ขนาด สี วัสดุ ชุดโมเดล อยู่ในไฟล์เดียว |

## 2. ระบบเกมหลักที่จะสร้างต่อจากแมพ (ลำดับที่ผู้ใช้ให้)

1. **ต่อสู้**: กลิ้ง (i-frame) และโจมตีด้วยหมัด ออกแบบให้รองรับอาวุธและท่าโจมตีหลายแบบภายหลัง (WeaponBase → Punch/Sword/Bow, คอมโบ, hitbox)
2. **จุดเกิด**: จุดเกิดแรก, จุดเกิดเมื่อตาย, เซฟตำแหน่งล่าสุดเมื่อออกแล้วเข้าใหม่
3. **ค่าพลัง**: เลือด สตามินา มานา
4. **การเคลื่อนไหวและอนิเมชัน**: เดิน, วิ่ง, วิ่งเร็ว, ว่ายน้ำ, ว่ายเร็ว, กลิ้ง, สไลด์ (วิ่งเร็วแล้วกดกลิ้ง), หมัด
5. **ล้ม / ปั๊มหัวใจให้ลุก / ตาย**
6. **เก็บเกี่ยวทรัพยากร**: ขุดแร่ ตัดไม้ ตกปลา ขุดดิน ค้นหา พร้อมอนิเมชันแต่ละอย่าง

ระบบเหล่านี้เป็นงานออกแบบรอบถัดไป (brainstorm → spec → plan แยกต่างหาก) **ไม่ทำในรอบแมพ** แต่แมพต้องเตรียมจุดเชื่อมต่อให้ครบ:

## 3. จุดเชื่อมต่อที่ตัวเจนแมพต้องใส่ (ทำในไลบรารีและทุกขั้นถัดไป)

ใช้ **CollectionService tag** เป็นหลัก (ระบบเกมค้นหาด้วย `CollectionService:GetTagged`) และ Attribute เป็นข้อมูลประกอบ

| สิ่งในแมพ | Tag | Attributes | ขั้นที่ใส่ |
|---|---|---|---|
| ต้นไม้ทุกต้น (โคลนจาก Store) | `Tree` | `GatherType="Woodcutting"`, `Resource="Wood"`, `Kind=oak/pine/palm` | 9 (และ 0 แล้ว) |
| หินมอส / สายแร่ในถ้ำ | `Rock` / `OreVein` | `GatherType="Mining"`, `Resource="Stone"/"Ore"` | 3, 9 |
| พุ่มไม้ | `Bush` | `GatherType="Searching"` | 9 |
| จุดตกปลา (ปลายท่าเรือ, ริมแม่น้ำ, สะพานปลา) | `FishingSpot` | `GatherType="Fishing"` | 5, 6, 8 |
| จุดขุดดิน (หย่อมดินในทุ่ง/ชายป่า) | `DigSpot` | `GatherType="Digging"` | 9 |
| จุดค้นหา (ลัง ถัง ซากปรักหักพัง) | `SearchPoint` | `GatherType="Searching"` | 5, 6, 8, 9 |
| จุดเกิดแรก | `SpawnLocation` (Instance จริง) ที่ท่าเรือ Brasshaven | `SpawnKind="First"` | 5 |
| จุดเกิดเมื่อตาย / จุดเซฟ | `RespawnPoint` (Part ล่องหน) ที่ทุกหมู่บ้าน ท่าเรือ Crown Plaza | `Place=<ชื่อ>` | 5, 6 |
| โซน (สำหรับ ZoneManager, เพลง, กฎหมาย) | `Zone` (Part ล่องหนทรงกระบอกคลุมลาน) | `ZoneName`, `ZoneType=capital/village/isle/dungeon` | 5, 6, 8 |
| น้ำว่ายได้ | Terrain Water (ระบบว่ายน้ำของ Roblox ใช้ได้ทันที) | | 2 |
| ถ้ำ (ดันเจี้ยน/เหมือง) | `Zone` type `dungeon` ที่ปากถ้ำ | | 3 |

ตัวช่วยในไลบรารี: `L.tag(inst, tag, attrs)`, `L.spawnPoint(parent, place, x, y, z)`, `L.zone(parent, name, kind, x, y, z, r, h)`, `L.marker(parent, tag, x, y, z, attrs)` (Part ล่องหน 4×4×4 Anchored CanCollide=false)

## 4. เรฟที่ผู้ใช้ให้สำหรับระบบเกม (ตรวจแล้ว)

| ที่อ้าง | สถานะ | ใช้ทำอะไร |
|---|---|---|
| Sleitnick/Knit | มีจริง ดึงแล้ว `temp_refs/knit-framework` | โครง Service/Controller + สื่อสาร client-server สำหรับระบบต่อสู้/เคลื่อนไหว |
| Sleitnick/RbxCharacterMovement | **ไม่มีจริง** | ใช้ Humanoid state + อนิเมชันเอง หรือดูตัวอย่างใน creator-docs |
| roblox/profile-service | **ไม่มีจริง** | ตัวจริงคือ MadStudioRoblox/ProfileService (ดึงแล้ว) และตัวใหม่กว่า MadStudioRoblox/ProfileStore (ดึงแล้ว) สำหรับเซฟ HP/MP/สตามินา/ตำแหน่งล่าสุด |
| Kampfkarren/ProfileService | **ไม่มีจริง** | ดูข้างบน |

โค้ดโครงร่างในเอกสารอ้างอิง (WeaponBase/PunchWeapon OOP, MovementController สไลด์เมื่อวิ่ง+กลิ้ง, SpawnManager, ResourceGatheringService ผ่าน ProximityPrompt) เป็นแนวคิดที่ใช้ได้และสอดคล้องกับตารางแท็กข้างบน แต่มีบั๊ก (เช่น `CFrame.fromRGB`) จะเขียนใหม่ตอนออกแบบระบบจริง โฟลเดอร์ `src/` ของ Rojo รองรับโครง `Services/`, `Controllers/`, `Modules/`, `Animations/` ตามที่เสนอ
