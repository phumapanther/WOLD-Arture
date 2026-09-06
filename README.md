# WOLD Arture — Roblox Studio project

สคริปต์เกม Roblox (Roleplay: ยุคกลาง + แฟนตาซี/เวทมนตร์ + สตีมพังก์/ไซไฟ)
Place ใน Roblox Studio ชื่อ **WOLD Arture**

## โครงสร้าง

| โฟลเดอร์ | ไปอยู่ที่ไหนใน Studio |
|---|---|
| `src/ServerScriptService/` | ServerScriptService (สคริปต์ฝั่งเซิร์ฟเวอร์ `*.server.lua`) |
| `src/ReplicatedStorage/` | ReplicatedStorage (ModuleScript ใช้ร่วมกัน `*.lua`) |
| `src/StarterPlayerScripts/` | StarterPlayer > StarterPlayerScripts (ฝั่งผู้เล่น `*.client.lua`) |
| `src/StarterGui/` | StarterGui (UI) |
| `plugins/` | ปลั๊กอิน Studio — โฟลเดอร์นี้ถูกลิงก์ (junction) ไปที่ `%LOCALAPPDATA%\Roblox\Plugins` อยู่แล้ว วางไฟล์ `.lua` / `.rbxm` แล้ว Studio โหลดเอง |
| `docs/` | เอกสารออกแบบ + ประวัติสนทนาเดิม |

## ซิงก์สคริปต์เข้า Studio (Rojo)

1. ดับเบิลคลิก `serve.bat` (รัน `rojo serve` ที่ port 34872)
2. เปิด place WOLD Arture ใน Studio → แท็บ Plugins → **Rojo** → Connect
3. แก้ไฟล์ใน `src/` แล้ว Studio อัปเดตทันที

Rojo อยู่ที่ `%USERPROFILE%\tools\rojo\rojo.exe` (portable, ไม่ต้องติดตั้ง)

## ปลั๊กอิน

วางไฟล์ `.lua` ใน `plugins/` → เปิด Studio ใหม่ (หรือ Plugins → Manage Plugins → refresh) จะโหลดเป็นปลั๊กอินทันที

## สั่ง Studio จากคอมมานด์ไลน์ (Studio MCP)

Studio มี MCP server ในตัว เปิดที่ Assistant → … → Manage MCP Servers → Enable Studio as MCP server
ลงทะเบียนกับ Claude Code แล้วในชื่อ `Roblox_Studio` (ใช้ `%LOCALAPPDATA%\Roblox\mcp.bat`)

ทดสอบ/สั่งตรงโดยไม่ผ่าน Claude:

```
node tools/mcp-call.js list
node tools/mcp-call.js execute_luau '{"datamodel_type":"Edit","code":"return #workspace:GetChildren()"}'
```
