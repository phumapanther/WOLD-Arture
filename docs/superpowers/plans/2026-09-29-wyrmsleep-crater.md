# ปล่องมังกรหลับ Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** ยอดเขาหลักเหนือแอสตราเวลกลายเป็นปล่องภูเขาไฟพร้อมลานบอส ลาวาไหม้ ลานจอดเรือเหาะ บรรยากาศ กระดูกประดับ และหมุดแผนที่ห้าจุด

**Architecture:** เรขาคณิตทั้งหมดอยู่ในโมดูลข้อมูลล้วน `WyrmsleepConfig` (มีฟังก์ชัน `Target(x, z, orig)` ที่เทสได้ offline) เฟส mapgen 112 อ่านโมดูลนั้นแล้วเขียน voxel + วาง Part · ลาวาเป็นระบบกลางจากแท็ก `WOLD_Lava` (`Lava.server`) · คอนฟิกข้ามระบบ (แผนที่ เพลงโซน เรือเหาะ) มีเทสจับความสอดคล้องกับ `WyrmsleepConfig`

**Tech Stack:** Luau (Roblox) · Studio MCP (`tools/run-luau.js`, `tools/lua.js`) · offline Luau (`tools/offline-test.js`) · `tools/verify.js`

**Spec:** `docs/superpowers/specs/2026-09-29-wyrmsleep-crater-design.md`

## Global Constraints
- ศูนย์ปล่อง (3250, -4850) · ลาน y 2200 r ≤ 108 · ท้องลาวา y 2190 r 116-136 · ผิวลาวา y 2192 r 112-140 · ขอบ r 180 y 2262
- ทางเข้าชี้ไปแอสตราเวล (3840, -3360) · สะพานกว้าง 12 · ทาง 16 · ช่องแยก y 2214 · ลานจอดห่าง 265 r 40 y 2208
- ด้านนอกยกอย่างเดียว จางคืนผิวเดิมที่ r 280-340 · หิมะละลายในรัศมี ~330 · เปลือก 16 สตัด ไม่ถมโพรงลึกกว่านั้น
- ลาวาไหม้ 10% ของเลือดเต็มต่อวิ ชนิด `burn` ข้ามเกราะ · เตือนครั้งแรกของแต่ละรอบ
- เรือเหาะ `maxAlt` 2600 · สถานี `WyrmsleepMooring`
- แผนที่: ลบ "Spire of Eld" + "Crystal Cave" · เพิ่ม ปล่องมังกรหลับ เตาหลอม ป่าหินเวท ต้นไม้โลก หอคอยสันโดษ
- เสียง: คำราม 9112775165 (ราว 420 สตัด) · ลาวาเดือด 318794788 (4 จุด ราว 110 สตัด)
- ห้าม FillBlock (ใช้ ReadVoxels/WriteVoxels) · ห้ามใช้สัญลักษณ์ ✦ ในข้อความ UI
- ตอบ/คอมเมนต์ภาษาไทย · ผู้ใช้เทสในเกมเอง (ไม่กด Play) · commit ลงท้าย Co-Authored-By · ห้าม stage `assets/item-icons/Spider.png`

## Review Focus
1. ผิวที่มองเห็นจริงหลัง WriteVoxels ต้องตรงกับ `Target` (±2.5) — เคยเจอผิวสูงกว่าที่เขียน 2 สตัด
2. ชิ้นลาวาห้ามทับสะพาน — ไม่งั้นเดินข้ามสะพานแล้วไหม้
3. ด้านนอกปล่องต้องไม่มีหน้าผาโผล่ที่ขอบรัศมีงาน (จางคืนผิวเดิม)
4. รันเฟสซ้ำต้องไม่ทบ (ภูมิประเทศคงที่ · ลาวาไม่ซ้อน · กระดูก Manual ไม่ถูกสร้างซ้ำ)
5. สถานีเรือเหาะต้องอยู่บนลานจอดที่ปาดไว้ ไม่งั้นเรือโผล่ในเนิน

---

### Task 1: WyrmsleepConfig + รูปทรง (offline)

**Files:**
- Create: `src/ReplicatedStorage/WyrmsleepConfig.lua`
- Test: `tests/wyrmsleep_shape_test.lua`

**Interfaces — Produces:**
`W.Center: Vector3` · `W.FloorY/FloorRadius/BedInner/BedOuter/LavaBedY/LavaSurfaceY/LavaInner/LavaOuter/RimRadius/RimY/OuterSlope/FadeFrom/WorkRadius/MeltRadius/ShellDepth/BridgeHalf/PathHalf/Blend/NotchY/PadY/PadDistance/PadRadius: number` ·
`W.AxisX, W.AxisZ: number` · `W.AtAxis(distance, side?) -> Vector3` · `W.PadCenter: Vector3` ·
`W.Target(x, z, orig) -> (y, kind, d) | nil` (kind ∈ floor/lava/wall/outer/path/pad) · `W.OnBridge(x, z, margin) -> boolean`

- [ ] Step 1: เขียนเทส (โค้ดในไฟล์เทสจริง) — ลานกลาง 2200 · ท้องลาวา 2190 · ขอบ 2262 นอกช่องแยก · r>340 = nil ·
  ด้านนอกไม่เคยต่ำกว่าผิวเดิม · ขอบรัศมีงานต่อกับผิวเดิม (±0.5) · ไม่มีขั้น > 3.5 สตัดต่อสตัดในแนวรัศมี (นอก ±20° ของแกน) ·
  ตามแกนทางเข้าชันไม่เกิน 1 ต่อสตัด · สะพาน 2200 · ช่องแยก 2214 · ลานจอด 2208 kind pad · OnBridge จริงบนสะพาน เท็จบนลาวาข้างๆ
- [ ] Step 2: `node tools/offline-test.js tests/wyrmsleep_shape_test.lua` → Expected: ERROR/FAIL (ไม่มีโมดูล)
- [ ] Step 3: เขียน `WyrmsleepConfig.lua` ตามสเปก (ฟังก์ชัน `Target` ตามตาราง ใน Global Constraints)
- [ ] Step 4: รันซ้ำ → Expected: PASS
- [ ] Step 5: commit `feat: WyrmsleepConfig crater geometry + shape test`

### Task 2: คอนฟิกข้ามระบบ (แผนที่ เพลงโซน เรือเหาะ ลาวา)

**Files:**
- Modify: `src/ReplicatedStorage/MapConfig.lua` (Places + Kinds)
- Modify: `src/ReplicatedStorage/SoundscapeConfig.lua` (WorldMusic.Zones key + Towns)
- Modify: `src/ReplicatedStorage/Vehicle/Config.lua` (Airship maxAlt + preset)
- Modify: `src/ReplicatedStorage/VitalsConfig.lua` (`LavaBurnFraction = 0.10`)
- Test: `tests/wyrmsleep_config_test.lua`

**Interfaces — Consumes:** `W.Center`, `W.PadCenter`, `W.PadRadius`, `W.RimY`

- [ ] Step 1: เขียนเทส — maxAlt ≥ RimY+100 · สถานี WyrmsleepMooring (Airship, ground) post อยู่ในลานจอด spawn ห่างศูนย์ลาน ≤ 5 ·
  หมุดแผนที่ห้าจุดมีครบ พิกัดปล่องตรง Center/8000 ±0.005 · ไม่มี Spire of Eld / Crystal Cave · ทุก kind มีใน Kinds ·
  Towns มี Wyrmsleep ที่ Center · WorldMusic.Zones มีคีย์ Wyrmsleep และไม่มี Spire of Eld · LavaBurnFraction = 0.10
- [ ] Step 2: รัน → FAIL
- [ ] Step 3: แก้สี่ไฟล์ (พิกัด: เตาหลอม -1061,5317 · ป่าหินเวท -700,-1160 · ต้นไม้โลก -4150,2460 · หอคอย 1586,238 ·
  สถานี post (3314,-4607) face 22 · spawn (3348,-4604) spawnFace 202)
- [ ] Step 4: รัน → PASS · รัน `sell_price_test` ไม่เกี่ยว ข้าม · รัน `farm_level_test` (ใช้ Vehicle? ไม่) ข้าม
- [ ] Step 5: commit `feat: map landmarks, crater music zone, airship ceiling 2600 + crater mooring`

### Task 3: ระบบลาวา

**Files:**
- Create: `src/ServerScriptService/Lava.server.lua`

- [ ] Step 1: เขียนสคริปต์ — ลูป 0.5 วิ · GetPartBoundsInBox รอบเท้า (Include = แท็ก WOLD_Lava) · `Vitals.ApplyDamage(p, MaxHP × fraction × 0.5, "burn")` ·
  เตือนครั้งแรกของรอบผ่าน `Remotes.SocialNotify` · ล้างตอน PlayerRemoving
- [ ] Step 2: `bash tools/offline-check.sh src/ServerScriptService/Lava.server.lua` → Expected: OK
  (พฤติกรรมจริงต้องเทสใน Play — ผู้ใช้เทสเอง)
- [ ] Step 3: commit `feat: Lava.server — tagged lava burns 10% max HP per second`

### Task 4: เฟส 112 + เทสปล่องจริง

**Files:**
- Create: `mapgen/112_wyrmsleep_crater.lua`
- Test: `tests/wyrmsleep_crater_test.lua` (Edit เพลสหลัก)

- [ ] Step 1: เขียนเทส — ยิงเรย์ Include Terrain: ลาน/ท้องลาวา/ขอบ/ช่องแยก/สะพาน/ลานจอด ±2.5 · ทางเดินตามแกนขั้น ≤ 4 ต่อ 4 สตัด ·
  ลาวา ≥ 100 ชิ้น ชนไม่ได้ Query ได้ ไม่ทับสะพาน · ควัน Persistent · เสียงคำราม Looped Playing · กะโหลก/ซี่โครงมี ·
  สำรองภูมิประเทศมี Corner · r 250 นอกแกนไม่ใช่หิมะ ≥ 6/8
- [ ] Step 2: ดัน `WyrmsleepConfig` เข้าเพลสหลัก แล้วรันเทส → Expected: FAIL (ยังไม่มีปล่อง)
- [ ] Step 3: เขียนเฟส: สำรอง → voxel (ReadVoxels/WriteVoxels ทีละก้อน 136) → รอ 10 เฟรม → ลาวา (PhaseBuilt) → ควัน (Persistent)
  ประกาย/แสง/เสียง → กระดูก + ป้าย (Manual สร้างครั้งเดียว) → Status done
- [ ] Step 4: `node tools/run-luau.js mapgen/112_wyrmsleep_crater.lua --no-lib` → Expected: `done`
- [ ] Step 5: รันเทส → Expected: PASS (ผิวเพี้ยน → ปรับการคำนวณ occupancy ในเฟส แล้วรันเฟสซ้ำ)
- [ ] Step 6: รันเฟสซ้ำอีกรอบ + เทสซ้ำ → PASS และจำนวนลาวา/กระดูกไม่เพิ่ม (รันซ้ำไม่ทบ)
- [ ] Step 7: commit `feat: phase 112 Wyrmsleep Crater + crater verification test`

### Task 5: ดันสามเพลส + เอกสาร
- [ ] `node tools/verify.js <default|farming|arena>.project.json --push` แล้วรันซ้ำจน mismatches 0
- [ ] CLAUDE.md หัวข้อใหม่ · commit `docs: Wyrmsleep Crater notes`
