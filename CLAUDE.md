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
ผู้ใช้สั่งว่า "อ่านประวัติสนทนาเดิมทั้งหมด ใช้เป็นบริบท แต่อย่าเพิ่งสรุปจนกว่าจะถาม"
หมายเหตุ: ไฟล์ประวัติมีแค่ส่วนวิเคราะห์ UI 16 หน้าจอ + UI Flow รายละเอียดระบบเศรษฐกิจ/รัฐฉบับเต็มยังไม่มีในไฟล์ ถ้าผู้ใช้หามาได้จะอยู่ใน `docs/`

## เครื่องมือที่พร้อมใช้
- **Studio MCP** (MCP server ในตัว Roblox Studio) ลงทะเบียน user-scope ชื่อ `Roblox_Studio` → เครื่องมือ `mcp__Roblox_Studio__*`
  ต้องเปิด Studio + place ก่อน และเปิดสวิตช์ที่ Assistant → … → Manage MCP Servers → Enable Studio as MCP server
  เครื่องมือหลัก: `execute_luau` (ใส่ `datamodel_type: "Edit"`), `inspect_instance`, `search_game_tree`, `script_read`/`multi_edit`, `generate_mesh`, `generate_procedural_model`, `insert_asset`, `start_stop_play`, `get_console_output`, `screen_capture`
  ถ้าได้ข้อความ "Unable to reach Roblox Studio" ทั้งที่ Studio เปิดอยู่ = proxy ยังต่อไม่เสร็จ ให้เรียกซ้ำ
- **`tools/mcp-call.js`** เรียก Studio MCP จาก shell ได้โดยไม่ต้องรีสตาร์ท Claude Code:
  `node tools/mcp-call.js list` / `node tools/mcp-call.js execute_luau '{"datamodel_type":"Edit","code":"..."}'`
- **Rojo 7.7.0** portable ที่ `%USERPROFILE%\tools\rojo\rojo.exe` → `serve.bat` แล้วกด Connect ที่ปลั๊กอิน Rojo ใน Studio
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
