# WOLD Arture — คู่มือสำหรับ Claude Code

เกม Roblox แนว Roleplay ธีม **ยุคกลาง + แฟนตาซี/เวทมนตร์ + สตีมพังก์/ไซไฟ (เครื่องจักรไอน้ำ)**
Place ใน Roblox Studio ชื่อ `WOLD Arture` (บัญชี phumapanther) ผู้ใช้สื่อสารภาษาไทย ตอบภาษาไทย

## เป้าหมายโปรเจ็ค
1. วิเคราะห์ระบบเกมที่ออกแบบไว้เดิม (เศรษฐกิจ รัฐสภา ภาษี ธนาคาร อาชีพ กฎหมาย UI flow) จาก `docs/chat-history-chatgpt.txt`
   ระบบเดิมออกแบบไว้สำหรับธีมอื่น → **คงระบบเดิม เปลี่ยนธีมใหม่**
2. ออกแบบแมพ NPC วัตถุ ตามธีมใหม่ เป็นลำดับขั้น
3. เจนของเหล่านั้นเข้า Studio ตามลำดับ (ผ่าน Studio MCP หรือปลั๊กอินใน `plugins/`)

**สถานะ (2026-09-06 ค่ำ):** แผน `docs/design/03-implementation-plan.md` ดำเนินถึงข้อ 2 แล้ว
- ข้อ 0 สนามทดสอบ ผ่าน (8+ รอบ) ข้อ 1 ตั้งค่าโลก ผ่าน ข้อ 2 Terrain ขนาดจริง 16k ผ่าน (257 วินาที, git tag `base-terrain-v1`, bundle `dist/arture-base-terrain.lua`, ผู้ใช้ Save As เป็นแมพเปล่าแล้ว) ข้อ 3 ถ้ำ 3 แห่งเจนแล้ว (แร่/หินถ้ำจาก Creator Store ตาม `nature.assets.ore/cave`)
- ถ้ำ: อุโมงค์ถูกบังคับให้อยู่ใต้ผิว (clamp r+8) โถงย่อตามความหนาหิน ปากถ้ำมีคบเพลิง แร่/หินงอกวางชิดผนัง Path เก็บใน Attribute; รีวิวใน Play ด้วยแชท `/tp <ชื่อ>` (`src/ServerScriptService/DevTeleport.server.lua` ติดตั้งใน Studio แล้ว ลบก่อนปล่อยเกม)
- ถัดไป: ผู้ใช้ตรวจถ้ำ → 4 ถนน/สะพาน (`mapgen/20_roads_bridges.lua` เขียนแล้ว) → 5 Brasshaven → 6 หมู่บ้าน → 7 ไอน้ำ/เวท → 8 เกาะ → 9 ธรรมชาติ (ต้นไม้จาก Creator Store) → 10 ตรวจรวม
- รันขั้น: `node tools/run-luau.js mapgen/<ไฟล์>.lua` (exit 3 = ผู้ใช้อยู่ใน Play mode รอแล้วลองใหม่) ภาพ: `node tools/mcp-call.js shot <ชื่อ> cx cy cz lx ly lz` → docs/shots/
- ต้นแบบต้นไม้/พุ่ม/หิน: `node tools/run-luau.js mapgen/assets_setup.lua` (โหลดจาก Creator Store ตาม id ใน JSON เข้า ServerStorage.WOLD_Assets) ต้องรันก่อนข้อ 9 ถ้า place ใหม่
- ข้อกำหนดสำคัญจากผู้ใช้: แมพต้องแก้มือได้ (Attribute Manual=true รอดจากการเจนซ้ำ) และมี hook ระบบเกม (แท็ก Tree/Rock/OreVein/Bush/FishingSpot/DigSpot/SearchPoint/RespawnPoint/Zone) ดู `docs/design/04-gameplay-hooks.md` ระบบเกมชุดแรกทำต่อหลังแมพ
- เอกสารแบบ: `01-world-and-terrain.md`, `02-structures-and-generation.md` (มีส่วน 'ปรับผังหลังสนามทดสอบ'), `04-gameplay-hooks.md`; พิกัดทั้งหมดใน `world-layout.json`; แผนที่ `map-arture-v1.png` (render-map.py)

**ระบบเกม (นอกแมพ):** สร้าง "เลือกช่อง+หน้าโหลด" (sub-project 6 จาก `04-gameplay-hooks.md`) เสร็จครบ 6 Task แล้ว
- Spec: `docs/superpowers/specs/2026-09-06-channel-select-and-loading-design.md` แผน: `docs/superpowers/plans/2026-09-06-channel-select-and-loading.md`
- โค้ด: `src/ServerScriptService/{ServerConfig.lua, Lobby/*}`, `src/ReplicatedStorage/{Remotes.lua, SpawnSelector.lua, UI/*}`, `src/StarterPlayerScripts/{ChannelSelectController,LoadingController}.client.lua`
- ทดสอบใน Play ได้ครบยกเว้น Reserved Server/TeleportService จริง (บล็อกใน Studio เสมอ HTTP 403) — **เหลือ Task 7: publish จริงแล้วทดสอบเลือกช่อง/เทเลพอร์ตข้ามเซิร์ฟเวอร์ 2 บัญชี** ตามเช็คลิสต์ในแผน แล้วอัปเดตสถานะตรงนี้
- หลัง publish ผู้ใช้เจอ 4 จุดต้องแก้ (ผู้ใช้แก้เองบางส่วน + Claude แก้ต่อ, commit `0ebd357`): (1) UI ขาว/ดำทึบ → เปลี่ยนเป็นกระจกโปร่งใส่ gradient ธีมยุคกลาง responsive ด้วย Scale (2) ช่องแชท/รายชื่อผู้เล่นฝั่งซ้าย-ขวา → ซ่อนด้วย `StarterGui:SetCoreGuiEnabled` ตอนอยู่ล็อบบี้ (3) กดปุ่ม JOIN ต้องดับหน้าจอทันที กันกดซ้ำ → `ChannelSelectGui:Lock()`/`Unlock()` blackout Frame (4) เข้าเชิฟแล้วไปโผล่ห้องหินไร้ทางออก → `BuildLobbyRoom.server.lua` เช็ค `ServerConfig.IsLobby` ก่อนสร้าง (ห้องเดิมสร้างในทุกเซิร์ฟเวอร์รวมถึงเชิฟจริงด้วย) **และ** เพิ่ม `mapgen/temp_spawn.lua` (แท่นหินชั่วคราวที่พิกัด Brasshaven บนพื้นจริงจาก `L.heightAt`) เพราะ `00_setup.lua` ลบ SpawnLocation เดิมทิ้งและไม่มีอะไรมาแทนจนกว่าจะถึงข้อ 5 — **ต้องลบ `WOLD.TempSpawn` ตอนสร้าง Brasshaven จริง**
- **ต้องเปิด "Enable Studio Access to API Services" ใน Game Settings → Security** ถึงจะทดสอบ DataStore/MessagingService ใน Play ได้ (เปิดแล้วตอนนี้)
- Rojo เชื่อมได้จริง แต่การเชื่อมต่อ (ทั้ง `rojo serve` process และปลั๊กอิน Studio) หลุดเงียบๆ ได้กลางเซสชัน โดยไม่มี error — ถ้าไฟล์ไม่ sync ให้ตรวจด้วย `script_read` เทียบกับไฟล์ local แล้วดันตรงผ่าน `multi_edit` (ลบ instance เดิมแล้วสร้างใหม่ด้วย `old_string: ""`) แทนการรอเชื่อมต่อใหม่
- ระบบถัดไปตามลำดับ: sub-project 1 ข้อมูลผู้เล่น+วงจรชีวิต (เลือด/สตามินา/มานา, จุดเกิด, เซฟตำแหน่งล่าสุด) → 2 เคลื่อนไหว/อนิเมชัน → 3 ต่อสู้ → 4 ล้ม-ปั๊ม-ตาย → 5 เก็บเกี่ยว

**2026-09-07:** ผู้ใช้สั่งพักแมพ (ทุ่งโล่งพอเทสระบบเกม) ไปทำระบบเกมส์ต่อ เพิ่ม HUD ในเกมแล้ว (`src/ReplicatedStorage/UI/HudGui.lua` + `src/StarterPlayerScripts/HudController.client.lua`, commit `98139a5` และแก้ดีไซน์/responsive อีกหลาย commit ตามหลัง): แถบสถานะกลุ่มซ้ายล่าง (เกราะ/สตามินา/มานา/ความหิว/เลือด ค่าคงที่เต็ม 100% รอ sub-project 1 ผูกค่าจริง, ดีไซน์อ้างอิง `docs/design/hud-ref/vitals-cluster.html`), ช่องของใช้ 6 ช่องกลางล่าง, เมนู 3 จุดชิดมุมขวาบนสุด → "กลับหน้า Lobby" (เทเลพอร์ตจริง) ซ่อนแชท/รายชื่อ, ทั้งชุด responsive ด้วย UIScale (baseline 1280px, หดได้ถึง 0.55 เท่า) รันเฉพาะเซิร์ฟเวอร์ช่อง ทดสอบผ่าน FORCE_SHOW flag เหมือน LoadingController
- เพิ่ม `src/StarterPlayerScripts/DebugCoords.client.lua` (ตัวเลขพิกัด x/y/z มุมขวาล่าง ตัวเล็กมาก) commit `0805ac7` (`PlayerSpeed.server.lua` ที่มาพร้อมกันถูกแทนที่ด้วยระบบเคลื่อนไหวใน sub-project 2 แล้ว)

**sub-project 1 (ข้อมูลผู้เล่น+วงจรชีวิต) เริ่มแล้ว — เสร็จส่วนตำแหน่ง + ย้ายไป ProfileStore แล้ว:**
- v1 (commit `d671c75`, ดีไซน์ `docs/superpowers/specs/2026-09-07-player-position-design.md`): จุดเกิดแรก/จุดเกิดใหม่หลังตาย = `WOLD.TempSpawn` (พิกัด Brasshaven ในอนาคต) เซฟตำแหน่งล่าสุดด้วย DataStore ตรงๆ + `PlayerRemoving`/`BindToClose` มือเขียนเอง — ทดสอบจริงหลัง publish เจอบั๊ก 3 รอบ (teleport ไม่รอ PlayerRemoving เซฟทัน, คนสุดท้ายออกเซิร์ฟเวอร์ปิดก่อนเซฟเสร็จ, ออก-เข้าเร็วเกินไปแข่งกับเซฟ) แก้ไปทีละจุดจนจบด้วย periodic autosave แต่ทดสอบแล้วไม่ช่วยจริง (ออก-เข้าเร็วกว่า interval เสมอ) — ลบตาม YAGNI
- v2 (commit `889d282`+`693f68c`, ดีไซน์ `docs/superpowers/specs/2026-09-07-profile-foundation-design.md`): **เปลี่ยนมาใช้ ProfileStore** (MadStudio, ตัวสืบทอด ProfileService) แทนของมือเขียนเองทั้งหมด — session-locked ป้องกัน race แบบที่เจอใน v1 ได้จริงเชิงโครงสร้าง โค้ด: `src/ServerScriptService/{ProfileStore.lua (vendor จาก temp_refs/), PlayerProfile.server.lua}` schema `{Position, Vitals}` (Vitals ยังไม่ใช้ เตรียมไว้ให้ sub-project ถัดไป) `PlayerPosition.server.lua` เดิมลบทิ้งแล้ว
- ทดสอบใน Play ได้แค่ module โหลดสำเร็จ + DataStore access จริง ส่วน session-lock ข้ามเซิร์ฟเวอร์จริง/รีสปอนหลังตายจริง ต้อง publish จริงถึงทดสอบได้ (TeleportService บล็อกใน Studio เหมือนทุกครั้ง)
- ไฟล์ใหญ่ (>50KB) push เข้า Studio ด้วย `multi_edit` ตรงๆ ไม่ได้ (คำสั่ง shell ยาวเกิน) ต้องเขียนสคริปต์ Node แยกอ่าน args จากไฟล์ JSON แล้วเรียก `tools/mcp-client.js` ตรงแทน `mcp-call.js`

**sub-project 2 (เคลื่อนไหว) — เสร็จส่วนเดิน/วิ่ง/สตามินา** (ดีไซน์ `docs/superpowers/specs/2026-09-07-movement-stamina-design.md`; อนิเมชันยังไม่ทำ)
- ความเร็ว เดิน 4 / ปกติ 8 / วิ่ง 16 สตามินา 0-100 ลด 20/วิ ตอนวิ่ง (~5 วิหมด) ฟื้น 33.3/วิ (~3 วิเต็ม) วิ่งได้ทันทีที่สตามินา > 0 หมดแล้วบังคับเดิน 2 วิ (กด Shift ค้างต่อก็ยังเดินจนครบ แล้ววิ่งต่ออัตโนมัติ) แตะ Shift ตอนยืนนิ่ง = โหมดเดิน ปล่อยจากวิ่งกลับเป็นปกติเสมอ (ไม่กลับโหมดเดิน)
- โค้ด: `src/StarterPlayerScripts/MovementController.client.lua` (ส่งแค่ intent: `SetSprintIntent`/`ToggleWalk` ไม่แตะ WalkSpeed เอง กัน client โกง) + `src/ServerScriptService/PlayerMovement.server.lua` (state machine ฝั่ง server บน Heartbeat ลูปเดียว, ตั้ง WalkSpeed, ส่ง `StaminaUpdate` ให้ HUD) `HudController` ผูกแถบสตามินาจริงแล้ว
- ทดสอบครบทุก transition ใน Play ได้ (ไม่ต้อง publish — ยิง remote ตรงแทนการกดคีย์จริงเพราะ VirtualInputManager ถูกบล็อก) บั๊กที่เจอ: ส่ง StaminaUpdate ในล็อบบี้ที่ไม่มีคนฟัง → Roblox เตือน queue exhausted ซ้ำๆ แก้ให้ส่งเฉพาะเซิร์ฟเวอร์ช่อง + จำกัด 10 ครั้ง/วิ
**sub-project 3 (เลือด/หิว/จมน้ำ/ล้ม) — เขียนโค้ดเสร็จ ทดสอบใน Play ผ่านหมด รอ publish ทดสอบจริง** (ดีไซน์ `docs/superpowers/specs/2026-09-07-vitals-downed-design.md`)
- `src/ServerScriptService/Vitals.lua` เป็นเจ้าของค่าทุกอย่างคนเดียว (เลือด/หิว/สตามินา/เกราะ + สถานะล้ม) `PlayerVitals.server.lua` แค่ต่อเข้า lifecycle **สตามินาย้ายมาจาก PlayerMovement แล้ว** (ว่ายน้ำก็ใช้ จมน้ำก็ขึ้นกับมัน) `StaminaUpdate` ถูกยุบรวมเข้า `VitalsUpdate`
- ดาเมจทุกทางผ่าน `Vitals.ApplyDamage(player, amount, kind)` ที่เดียว — kind = combat/fall/drown/starve/void
- **เกราะหมดแล้วหมดเลย** (ผู้ใช้ยืนยัน แก้จาก spec เดิม): กันดาเมจครึ่งหนึ่ง เฉพาะ combat, เกิดใหม่ไม่เติม, ยังไม่มีของให้เกราะ เลยเริ่มที่ 0
- ต่อย/ตก/หิว → เลือดหมด = **ล้มไปคลาน** / จมน้ำ+ตกนอกแมพ = **ตายทันที** (คลานใต้น้ำไม่ได้) ล้มแล้วตกน้ำ = เกิดใหม่ทันที
- **ท่าคลานใช้อนิเมชันว่ายน้ำมาตรฐานของ Roblox** (`913384386`/`913389285`) ไม่ต้องทำเอง — แต่ต้องรู้ 2 อย่าง: (1) อนิเมชันว่ายน้ำขยับ**แค่แขน** ตัวเอียงมาจาก humanoid state ไม่ใช่อนิเมชัน และบังคับ state Swimming บนบกไม่ติด (2) **ต้องเอียงแบบ cosmetic เท่านั้น** — หมุนตัวจริงด้วย AlignOrientation ดูถูกแต่ขยับแทบไม่ได้ (วัดได้ 2.88 studs → 0.01) เพราะ mover ดันตัวที่ถูกล็อกทิศไม่ได้ วิธีที่ใช้: humanoid ตั้งตรงเหมือนเดิม เอียงแค่ร่างที่มองเห็นด้วย `LowerTorso.Root.Transform` บน `RunService.Stepped`
- **fall damage ต้องเช็ค `FloorMaterial ~= Air` ไม่ใช่ state Freefall** — กลางอากาศ humanoid เด้งกลับเป็น Running ชั่วครู่ (ตกจาก 30 studs รายงาน Running ตอนตกได้ 3 studs) ถ้าถือว่าลงพื้นแล้วจะคิดดาเมจแค่ 3 studs แล้วทิ้งที่เหลือ
- `PlayerProfile` ไม่ย้ายตำแหน่งตอน respawn แล้ว (เดิมเด้งกลับจุดที่ตาย)
- ทดสอบใน Play ผ่าน 22/22 (เกราะ/invuln/ล้ม/Recover/จมน้ำ/หิว 1800 วิ/อดตาย 120 วิ/ตก 8-30-70 studs/void/ท่าคลาน) — **เหลือทดสอบจริงหลัง publish: จอมืด+นับถอยหลัง+ปุ่มเกิดใหม่, เสียงต่อยโดน, กระพริบตอนเกิดใหม่, ต่อยกันจริง 2 บัญชี**
- ถัดไป: 3b ชุบ/อุ้มคนล้ม (แยก spec) → 4 กลิ้ง/สไลด์ + ปุ่มมือถือ → 5 เก็บเกี่ยว

**อนิเมชัน 3b/4 (2026-09-08) — สร้าง KeyframeSequence ครบ 6 ท่าเข้า `ServerStorage.WOLD_Animations` แล้ว รอผู้ใช้ดูท่า/จูนองศา ยังไม่ publish และยังไม่มีโค้ดระบบ** (ท่าทั้งหมดผู้ใช้บรรยายมาเอง)
- `animgen/movement.lua` → `Roll_Forward` (ย่อเข่าลึก ก้มตัวติดขา แล้วม้วนหน้า 1 รอบ), `Slide_Enter`/`Slide_Hold` (เอนหลัง 45° ขาข้างหนึ่งชันเข่า อีกข้างเหยียดตรง แขนกางสองข้าง เอียงไปทางขาที่งอ — สลับข้างด้วยค่าคงที่ `BENT_SIDE`)
- `animgen/revive.lua` → `CPR_Loop` (นั่งทับส้น เข่าติดพื้น ก้มหน้า แขนตรงประสานด้านหน้า ปั๊ม 0.55 วิ/ครั้ง ≈110 ครั้ง/นาที มี KeyframeMarker `Beat` ให้ `GetMarkerReachedSignal` ผูกเสียง/หัวใจบน HUD ตรงจังหวะ), `Carry_Held` + `Carry_Holder` (อุ้มขี่หลังแบบกระเป๋า ไม่ใช่พาดบ่า)
- **ท่าอุ้มต้องมี Motor6D ที่อนิเมชันให้ไม่ได้:** Part0 = คนอุ้ม `UpperTorso`, Part1 = คนถูกอุ้ม `HumanoidRootPart`, C0 ≈ `CFrame.new(0,0.15,1.55)*CFrame.Angles(rad(-8),0,0)` (Motor6D ไม่ใช่ WeldConstraint — Animator ของคนถูกอุ้มถึงจะเล่น `Carry_Held` ทับได้) + `PlatformStand=true` + CollisionGroup ไม่ให้สองตัวชนกัน + `SetNetworkOwner(คนอุ้ม)` ไม่งั้นตัวสั่นหนักตอนเดิน
- **Roblox ไม่มี root motion** — อนิเมชันไม่ขยับตัวละครเลย กลิ้ง/สไลด์ต้องดันด้วย velocity ในโค้ด + `AutoRotate=false`
- เทคนิคในไฟล์: pose `LowerTorso` = RootJoint ใช้ย่อ/หมุน "ร่างที่มองเห็น" ทั้งตัวโดยไม่แตะ HipHeight (humanoid ยังยืนตรงชนปกติ); หมุน 360° ต้องซอยทีละ 90° เพราะ engine lerp เส้นทางสั้นสุด (0→-360 ในคีย์เดียว = ไม่หมุนเลย, ก้าว 180° = สุ่มทิศ) และคีย์เฟรมช่วงหมุนต้องตั้ง easing Linear ไม่งั้นสะดุดเป็น 4 จังหวะ; ไม่ใส่ pose ขา = อนิเมชันเดิน/วิ่งเดิมยังคุมขาต่อ (ใช้กับ `Carry_Holder` เหมือนที่ `Combat_Guard` ใช้)
- แก้ `animgen/combat.lua`: เดิมลบทั้งโฟลเดอร์ `WOLD_Animations` ตอนรัน → ล้างท่าของไฟล์อื่นทิ้ง เปลี่ยนเป็นลบเฉพาะ 3 ท่าของตัวเอง (ไฟล์ใหม่ทั้งสองทำแบบเดียวกัน)
- **พรีวิวโดยไม่ต้องอัปโหลด:** `node tools/preview-anim.js animgen/<ไฟล์>.lua <ชื่อท่า> [--speed 0.4]` — ต้องอยู่ใน **Play** (รันในดาต้าโมเดล Server, ใช้ `KeyframeSequenceProvider:RegisterKeyframeSequence` แล้วเล่นบนตัวละครผู้เล่นคนแรก) มักได้ "Target is not reachable" ครั้งแรก เรียกซ้ำแล้วติด
- publish: right-click ทีละ sequence ใน ServerStorage → Save to Roblox (**ต้องเป็นบัญชีเจ้าของ place** ไม่งั้นโหลดไม่ขึ้น) แล้วเอา id ไปใส่ config แบบเดียวกับ `CombatConfig.Weapons[].guardAnimation` (id ว่าง = ระบบทำงานต่อได้ แค่เงียบ)
- `screen_capture` ระหว่างอยู่ใน Play mode timeout ไม่ได้ภาพ — ตรวจท่าด้วยตาผู้ใช้แทน

**เดิน/วิ่งบนจอย gamepad + มือถือ แบบ B — เขียนโค้ดแล้ว รอผู้ใช้ทดสอบเองด้วยจอย (Claude ไม่ต้องเทส)** อยู่ใน `MovementController.client.lua` เดิม server ไม่แตะ
- ผู้ใช้เลือก B: ดันจอยสุดขอบ = วิ่ง (threshold ≥0.9 ค้าง ~0.25 วิ, หยุดเมื่อ <0.7 hysteresis — 3 ค่าคงที่บนหัวไฟล์ ปรับได้), ดันเบา = เดินช้า (engine ปรับความเร็วตามแรงดันให้เองอยู่แล้ว), ไม่มีปุ่มเพิ่ม, หลังบังคับเดิน 2 วิถ้ายังดันสุดขอบ → วิ่งต่ออัตโนมัติเหมือนคอม (ผู้ใช้ยืนยันแล้ว)
- **gamepad** อ่านแรงดันตรงจาก `UserInputService.InputChanged` (`Thumbstick1.Position`) แม่นยำ ไม่ยุ่ง PlayerModule / **touch มือถือ** ไม่มี API → อนุมานจาก `ความเร็วแนวราบ / WalkSpeed` เฉพาะตอน `GetLastInputType()==Touch` (WASD ให้ magnitude 1 เสมอ ห้ามใช้กับคีย์บอร์ด) เพี้ยนบนเนิน/ในน้ำ/กลางอากาศ — ทางอัปเกรดจดไว้ในโค้ดและสเปก
- ข้อเท็จจริงที่พิสูจน์แล้วใน Play: `Humanoid.MoveDirection` เป็น unit vector เสมอ (อ่านแรงดันจากมันไม่ได้); `Humanoid:Move` magnitude 0.5 → วิ่ง 4.00 ที่ WalkSpeed 8 (engine scale ตาม magnitude จริง); DynamicThumbstick คำนวณ `magnitude = deflection/radiusOfMaxSpeed` clamp [0,1] (ดันสุด = 1.0 พอดี); PlayerModule ยุคใหม่อยู่ที่ `StarterPlayer.PlayerModule` (ไม่ใช่ PlayerScripts) ไม่มี `GetControls()`/`GetMoveVector()` แล้ว มี field `ControlModule.inputMoveVector` ที่ core VM เขียนทุกเฟรมแทน
- **ห้าม `require(StarterPlayer.PlayerModule.ControlModule)` จากฝั่ง client เด็ดขาด:** ได้สำเนาที่ไม่มีใครเรียก `Update` (inputMoveVector ค้าง 0) และหลักฐานชี้ว่า**ทำระบบเดินของจริงพัง** — โพรบรอบที่มี require บันทึกได้ศูนย์ทั้งที่ผู้ใช้กด W, รอบที่ไม่มี require ได้ MaxVel 8/คีย์เข้า 7 ครั้ง (A/B ในเซสชันเดียวยังไม่ได้ปิดเพราะผู้ใช้ปิดเครื่อง ถือว่าห้ามใช้ไปเลย ไม่คุ้มเสี่ยง) ถ้าอนาคตอยากอ่านค่า touch แม่นๆ: อ่าน GUI ของ thumbstick เอง หรือ fork PlayerModule ทั้งก้อนเข้า StarterPlayerScripts

ผู้ใช้สั่งว่า "อ่านประวัติสนทนาเดิมทั้งหมด ใช้เป็นบริบท แต่อย่าเพิ่งสรุปจนกว่าจะถาม"
หมายเหตุ: ไฟล์ประวัติมีแค่ส่วนวิเคราะห์ UI 16 หน้าจอ + UI Flow รายละเอียดระบบเศรษฐกิจ/รัฐฉบับเต็มยังไม่มีในไฟล์ ถ้าผู้ใช้หามาได้จะอยู่ใน `docs/`

## เครื่องมือที่พร้อมใช้
- **Studio MCP** (MCP server ในตัว Roblox Studio) ลงทะเบียน user-scope ชื่อ `Roblox_Studio` → เครื่องมือ `mcp__Roblox_Studio__*`
  ต้องเปิด Studio + place ก่อน และเปิดสวิตช์ที่ Assistant → … → Manage MCP Servers → Enable Studio as MCP server
  เครื่องมือหลัก: `execute_luau` (ใส่ `datamodel_type: "Edit"`), `inspect_instance`, `search_game_tree`, `script_read`/`multi_edit`, `generate_mesh`, `generate_procedural_model`, `insert_asset`, `start_stop_play`, `get_console_output`, `screen_capture`
  ถ้าได้ข้อความ "Unable to reach Roblox Studio" ทั้งที่ Studio เปิดอยู่ = proxy ยังต่อไม่เสร็จ ให้เรียกซ้ำ
- **`tools/mcp-call.js`** เรียก Studio MCP จาก shell ได้โดยไม่ต้องรีสตาร์ท Claude Code:
  `node tools/mcp-call.js list` / `node tools/mcp-call.js execute_luau '{"datamodel_type":"Edit","code":"..."}'`
- **Rojo 7.7.0** portable ที่ `%USERPROFILE%\tools\rojo\rojo.exe` → **`serve-background.bat`** แล้วกด Connect ที่ปลั๊กอิน Rojo ใน Studio
  - **สาเหตุที่ Rojo หลุดบ่อย:** `serve.bat` รันแบบ foreground พอหน้าต่างเทอร์มินัลปิด process ก็ตายเงียบๆ → `serve-background.bat` แยกหน้าต่างและรีสตาร์ทใหม่เองถ้าตาย
  - เช็คว่ารันอยู่ไหม: `tasklist | grep -i rojo` หรือเรียก `http://localhost:34872/api/rojo`
  `default.project.json` แมป `src/` → ServerScriptService, ReplicatedStorage, StarterGui, StarterPlayerScripts
- **`plugins/`** = junction ของ `%LOCALAPPDATA%\Roblox\Plugins` วาง `.lua`/`.rbxm` แล้ว Studio โหลดเป็นปลั๊กอินเอง (มี Rojo.rbxm อยู่แล้ว)

## ข้อจำกัดเครื่อง
winget และตัวติดตั้ง MSI/EXE ถูก Group Policy บล็อก → ใช้ของ portable เท่านั้น
Python ใช้ `C:\Users\watch\hacker\pyembed\python.exe` (มี yt-dlp, faster-whisper) รันด้วย `PYTHONUTF8=1`
Node 24 มีในเครื่อง

## แนวทางทำงาน
- โค้ดเจนแมพ = Luau ที่สร้าง Part/Model แบบ procedural และตั้ง Anchored/CanCollide ให้ถูก (ฟิสิกส์)
- เจนทีละส่วนตามลำดับที่ออกแบบ ตรวจด้วย `screen_capture` + `get_console_output` แล้วแก้เอง ไม่ต้องให้ผู้ใช้แคปรูปส่ง
- เก็บสคริปต์ที่ใช้เจนไว้ใน `src/` หรือ `plugins/` และ commit ทุกขั้น (repo local ยังไม่ push GitHub)
- ตัวอย่างอ้างอิงวิธีทำของคนอื่น: `docs/ref/reel_1743158103607714_transcript.txt` (คลิป Jinn Kode Code ใช้ AI เขียน Luau แล้ววางใน Studio)

## เอกสาร
- `docs/chat-history-chatgpt.txt` ประวัติออกแบบเดิมจาก ChatGPT (บริบทหลัก)
- `docs/session-2026-09-06-claude-code.md` บทสนทนาเซสชันตั้งค่าโปรเจ็ค
- `README.md` วิธีใช้ Rojo / ปลั๊กอิน / MCP
