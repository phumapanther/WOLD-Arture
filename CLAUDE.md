# WOLD Arture — คู่มือสำหรับ Claude Code

เกม Roblox แนว Roleplay ธีม **ยุคกลาง + แฟนตาซี/เวทมนตร์ + สตีมพังก์/ไซไฟ (เครื่องจักรไอน้ำ)**
Place ใน Roblox Studio ชื่อ `WOLD Arture` (บัญชี phumapanther) ผู้ใช้สื่อสารภาษาไทย ตอบภาษาไทย

## เป้าหมายโปรเจ็ค
1. วิเคราะห์ระบบเกมที่ออกแบบไว้เดิม (เศรษฐกิจ รัฐสภา ภาษี ธนาคาร อาชีพ กฎหมาย UI flow) จาก `docs/chat-history-chatgpt.txt`
   ระบบเดิมออกแบบไว้สำหรับธีมอื่น → **คงระบบเดิม เปลี่ยนธีมใหม่**
2. ออกแบบแมพ NPC วัตถุ ตามธีมใหม่ เป็นลำดับขั้น
3. เจนของเหล่านั้นเข้า Studio ตามลำดับ (ผ่าน Studio MCP หรือปลั๊กอินใน `plugins/`)

**สถานะ (2026-09-06):** เครื่องมือครบ ผู้ใช้อนุมัติแบบแมพครบทั้ง 6 ส่วนแล้ว (โลก/ชื่อ, Terrain, Brasshaven, หมู่บ้าน+ไอน้ำ+เวท+เกาะ, สถาปัตยกรรมตัวเจน, ลำดับขั้น 0-10)
- `docs/design/01-world-and-terrain.md` ส่วน 1-2 และ `docs/design/02-structures-and-generation.md` ส่วน 3-6 (มีตารางสิ่งที่ปรับจากแชท เกณฑ์ผ่านแต่ละขั้น มุมกล้องตรวจงาน)
- `docs/design/world-layout.json` = แหล่งความจริงชุดเดียวของพิกัด (สัดส่วน -1..1, X ตะวันออก, Z ใต้) ตัวเจน Luau ต้องอ่านไฟล์นี้ ห้ามฮาร์ดโค้ดพิกัด
- `docs/design/map-arture-v1.png` วาดด้วย `render-map.py` (รันใน docs/design ด้วย pyembed python + PYTHONUTF8=1) แก้ JSON แล้วรันใหม่ทุกครั้ง
- แผนงานละเอียด 11 Task (ขั้น 0-10) พร้อมโค้ด: `docs/design/03-implementation-plan.md` ผู้ใช้อนุมัติ spec 02 แล้ว
- ขั้นถัดไป: รันแผน Task 0 (spike MCP runner) → ... → Task 10 ขออนุมัติผู้ใช้ก่อนทุก Task, commit หลังทุก Task
- ตัวเจนจะอยู่ใน `mapgen/*.lua` + `tools/run-luau.js` (สร้างตามแผน)
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
