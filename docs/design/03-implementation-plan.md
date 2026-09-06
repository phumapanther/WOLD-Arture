# WOLD Arture Map Generator Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** เจนแมพเกาะ Arture ทั้งหมด (Terrain 16k × 16k, เมืองหลวง Brasshaven, หมู่บ้าน 6 แห่ง, สะพาน รถไฟ ลิฟต์ ท่อไอน้ำ หอเวท เกาะเล็ก 5 เกาะ ต้นไม้ 18,000 ต้น) เข้า Roblox Studio ด้วยสคริปต์ Luau ที่รันซ้ำได้ ผ่าน Studio MCP

**Architecture:** สคริปต์ Luau แยกเป็นขั้น (`mapgen/NN_*.lua`) ใช้ไลบรารีร่วม `mapgen/lib.lua` ที่ฝังพิกัดจาก `docs/design/world-layout.json` ตัวส่ง `tools/run-luau.js` ต่อไฟล์เข้าด้วยกันแล้วยิง `execute_luau` ไปที่ Studio งานรันใน `task.spawn` และรายงานความคืบหน้าผ่าน Attribute บน `workspace.WOLD` ตัวส่งวนอ่านจนจบ ทุกขั้นสร้างของใน Folder ของตัวเองและลบของเดิมก่อน

**Tech Stack:** Roblox Studio (Terrain API `WriteVoxels`/`FillBlock`/`FillBall`, Part/WedgePart/Model), Luau, Node 24 (stdio MCP client ต่อ `%LOCALAPPDATA%\Roblox\mcp.bat`), Python pyembed (วาดแผนที่), git

**Spec:** `docs/design/01-world-and-terrain.md` (ส่วน 1-2) และ `docs/design/02-structures-and-generation.md` (ส่วน 3-6) พิกัดใน `docs/design/world-layout.json`

## Global Constraints

- ห้ามฮาร์ดโค้ดพิกัดในโค้ด Luau ทุกตำแหน่งอ่านจาก `world-layout.json` (สัดส่วน -1..1, X ตะวันออก, Z ใต้, เหนือ = -Z, คูณ `half_size_studs` = 8000)
- ระดับน้ำทะเล Y = 0; หน่วยทั้งหมดเป็น studs; Terrain voxel = 4 studs; Region3 ที่ส่ง `WriteVoxels` ต้องอยู่บนกริด 4
- ทุก Part ที่สร้าง `Anchored = true`; ชิ้นตกแต่งเล็กที่ผู้เล่นไม่ควรชน `CanCollide = false`
- ขั้นที่สร้างสิ่งก่อสร้าง (20 ขึ้นไป) รันที่ `SCALE = 1` เท่านั้น (ตรวจแล้ว error ถ้าไม่ใช่); Terrain ทดสอบที่ `SCALE = 0.125` ก่อน
- ชิ้นส่วนรวมทั้งแมพไม่เกิน 70,000 (`generator.part_budget`); ต้นไม้ไม่เกิน 18,000 ต้น (`nature.tree_budget`)
- ทุกขั้นสร้างใน `workspace.WOLD.<PhaseName>` และลบ Folder เดิมก่อน; Terrain ขั้น 10 เริ่มด้วย `Terrain:Clear()`
- ก่อนเจนแต่ละขั้นต้อง **ขออนุมัติผู้ใช้ด้วย AskUserQuestion** (ผู้ใช้สั่งไว้) และหลังขั้นผ่านการตรวจให้ `git commit` ทันที
- ตรวจงานเอง: `get_console_output` ไม่มี error ของขั้นนั้น + self-check ของขั้น + `screen_capture` ตามรายการมุมกล้องท้าย spec 02 แล้วผู้ดำเนินการดูภาพเอง ห้ามให้ผู้ใช้แคปหน้าจอส่ง
- Studio ต้องเปิด place `WOLD Arture` และเปิด MCP server แล้ว (Assistant → … → Manage MCP Servers) ถ้าได้ "Unable to reach Roblox Studio" ให้เรียกซ้ำ
- ตอบผู้ใช้เป็นภาษาไทย

---

## โครงไฟล์ที่จะสร้าง

| ไฟล์ | หน้าที่ | สร้างใน Task |
|---|---|---|
| `tools/mcp-client.js` | โมดูล stdio MCP client ตัวเดียว ใช้ร่วมโดย 2 สคริปต์ล่าง | 0 |
| `tools/mcp-call.js` | CLI เรียกเครื่องมือ MCP ทีละครั้ง (มีอยู่แล้ว เขียนใหม่ให้ใช้โมดูล) + คำสั่ง `shot` เซฟภาพ | 0 |
| `tools/run-luau.js` | รวม JSON + lib + ไฟล์ขั้น → `execute_luau` → วนอ่านความคืบหน้าจนจบ | 0 |
| `mapgen/spike_async.lua` | ทดสอบ task.spawn + ความเร็ว WriteVoxels (ทิ้งหลังใช้) | 0 |
| `mapgen/lib.lua` | ไลบรารีร่วม: พิกัด, noise, ฟังก์ชันความสูง, แม่น้ำ, ตัวเขียน Terrain, ชิ้นส่วน Part, ปรับพื้น, progress, self-check | 1, 4, 5 (เพิ่มทีละส่วน) |
| `mapgen/test_lib.lua` | self-test ของ lib รันใน Studio | 1 |
| `mapgen/00_setup.lua` | ตั้งค่าโลก | 1 |
| `mapgen/10_terrain.lua` | ภูมิประเทศ + ทะเล + เกาะเล็ก + แม่น้ำ (น้ำในแม่น้ำเขียนพร้อม Terrain) | 2 |
| `mapgen/11_caves.lua` | ถ้ำ 3 แห่ง คริสตัล สายแร่ ซากเรือ | 3 |
| `mapgen/20_roads_bridges.lua` | ถนน + สะพาน 5 แห่ง | 4 |
| `mapgen/30_capital.lua` | Brasshaven | 5 |
| `mapgen/40_villages.lua` | หมู่บ้าน 6 แห่ง | 6 |
| `mapgen/50_steam_magic.lua` | ราง สถานี รถไฟจอด ลิฟต์ ท่อ Spire คริสตัล | 7 |
| `mapgen/60_islands.lua` | สิ่งก่อสร้าง 5 เกาะ | 8 |
| `mapgen/70_nature.lua` | ต้นไม้ พุ่มไม้ ก้อนหิน | 9 |
| `mapgen/90_verify.lua` | self-check รวม + รายการมุมกล้อง + เปิด ChangeHistory คืน | 10 |
| `docs/shots/*.png` | ภาพตรวจงานจาก `screen_capture` (commit เฉพาะภาพสรุปขั้น) | ทุก Task |

**สัญญาระหว่างไฟล์ (Interfaces กลาง)** ตัวส่งต่อโค้ดเป็นก้อนเดียวในลำดับนี้:

```lua
local SCALE = <ตัวเลขจาก --scale, ค่าเริ่ม 1>
local LAYOUT_JSON = [==[<เนื้อ world-layout.json ทั้งไฟล์>]==]
<mapgen/lib.lua>      -- ประกาศตาราง L ตัวเดียว (หลีกเลี่ยงลิมิต 200 local ต่อฟังก์ชัน)
<mapgen/NN_phase.lua> -- ใช้ L.* และจบด้วย return L.runPhase("ชื่อ", function(folder) ... end)
```

---

### Task 0: MCP client + runner + spike ความเป็นไปได้ (ขั้น 0)

**Files:**
- Create: `tools/mcp-client.js`
- Modify: `tools/mcp-call.js` (เขียนใหม่ทั้งไฟล์ ให้ CLI เดิมใช้ได้เหมือนเดิม)
- Create: `tools/run-luau.js`
- Create: `mapgen/spike_async.lua` (ลบทิ้งท้าย Task)

**Interfaces:**
- Produces: `connect()` → `{ tools, tool(name, args) → result, text(result) → string, close() }`; CLI `node tools/run-luau.js <file.lua> [--scale n] [--timeout sec]`; CLI `node tools/mcp-call.js shot <name> cx cy cz lx ly lz` → เซฟ `docs/shots/<name>.png`
- Consumes: `%LOCALAPPDATA%\Roblox\mcp.bat` (Studio MCP proxy), Studio เปิดอยู่

- [ ] **Step 0.1: ขออนุมัติผู้ใช้เริ่มข้อ 0** ด้วย AskUserQuestion (ตัวเลือก: อนุมัติ / ขอแก้) แจ้งว่าจะสร้าง Terrain ทดสอบชั่วคราวใน place แล้วลบทิ้ง

- [ ] **Step 0.2: เขียน `tools/mcp-client.js`**

```js
// ponytail: minimal stdio MCP client for the Studio MCP proxy; shared by mcp-call.js and run-luau.js
const { spawn } = require("child_process");
const path = require("path");
module.exports = async function connect() {
  const p = spawn("cmd.exe", ["/c", path.join(process.env.LOCALAPPDATA, "Roblox", "mcp.bat"), ...(process.env.MCP_VERBOSE ? ["-v"] : [])], { stdio: ["pipe", "pipe", "inherit"] });
  let buf = "", id = 0; const pending = {};
  const send = (m) => p.stdin.write(JSON.stringify(m) + "\n");
  const call = (method, params) => new Promise((res) => { pending[++id] = res; send({ jsonrpc: "2.0", id, method, params }); });
  p.stdout.on("data", (d) => {
    buf += d; let i;
    while ((i = buf.indexOf("\n")) >= 0) {
      const line = buf.slice(0, i); buf = buf.slice(i + 1);
      if (!line.trim()) continue;
      try { const m = JSON.parse(line); if (m.id && pending[m.id]) { pending[m.id](m); delete pending[m.id]; } } catch {}
    }
  });
  await call("initialize", { protocolVersion: "2025-06-18", capabilities: {}, clientInfo: { name: "wold", version: "0" } });
  send({ jsonrpc: "2.0", method: "notifications/initialized" });
  // proxy answers "Unable to reach Studio" until its websocket to Studio is up; tools list appears once linked
  let tools = [];
  for (let t = 0; t < 40 && tools.length === 0; t++) { await new Promise((r) => setTimeout(r, 250)); tools = (await call("tools/list", {})).result?.tools ?? []; }
  if (tools.length === 0) throw new Error("Studio MCP not reachable: open the place and enable MCP server");
  const tool = async (name, args) => { const r = await call("tools/call", { name, arguments: args }); return r.result ?? r.error; };
  const text = (r) => (r?.content ?? []).map((c) => c.text ?? "").join("\n");
  return { tools, tool, text, close: () => p.kill() };
};
```

- [ ] **Step 0.3: เขียน `tools/mcp-call.js` ใหม่** (CLI เดิม + คำสั่ง `shot`)

```js
// usage: node tools/mcp-call.js list
//        node tools/mcp-call.js <tool> '<json args>'
//        node tools/mcp-call.js shot <name> cx cy cz lx ly lz   -> docs/shots/<name>.png
const fs = require("fs"), path = require("path");
const connect = require("./mcp-client");
const [cmd = "list", ...rest] = process.argv.slice(2);
(async () => {
  const c = await connect();
  if (cmd === "list") for (const t of c.tools) console.log(t.name, JSON.stringify(t.inputSchema.properties || {}));
  else if (cmd === "shot") {
    const [name, ...nums] = rest; const v = nums.map(Number);
    const r = await c.tool("screen_capture", { capture_id: name, camera_position: v.slice(0, 3), look_at_position: v.slice(3, 6) });
    const img = (r?.content ?? []).find((x) => x.type === "image");
    if (!img) { console.log(JSON.stringify(r, null, 1)); process.exitCode = 1; }
    else { fs.mkdirSync(path.join(__dirname, "..", "docs", "shots"), { recursive: true }); const out = path.join(__dirname, "..", "docs", "shots", name + ".png"); fs.writeFileSync(out, Buffer.from(img.data, "base64")); console.log("saved", out); }
  } else console.log(JSON.stringify(await c.tool(cmd, JSON.parse(rest[0] ?? "{}")), null, 1));
  c.close(); process.exit();
})();
setTimeout(() => { console.error("timeout"); process.exit(1); }, 120000);
```

- [ ] **Step 0.4: เขียน `tools/run-luau.js`**

```js
// usage: node tools/run-luau.js mapgen/10_terrain.lua [--scale 0.125] [--timeout 1800]
// concatenates SCALE + world-layout.json + lib.lua + phase file, runs it in Studio, polls workspace.WOLD attributes until done/error
const fs = require("fs"), path = require("path");
const connect = require("./mcp-client");
const args = process.argv.slice(2);
const file = args.find((a) => !a.startsWith("--") && !/^[\d.]+$/.test(a));
const opt = (k, d) => { const i = args.indexOf(k); return i >= 0 ? args[i + 1] : d; };
const scale = opt("--scale", "1"), timeout = Number(opt("--timeout", "1800"));
const root = path.join(__dirname, "..");
const read = (p) => fs.readFileSync(path.join(root, p), "utf8");
const code = `local SCALE = ${scale}\nlocal LAYOUT_JSON = [==[${read("docs/design/world-layout.json")}]==]\n${read("mapgen/lib.lua")}\n${read(file)}\n`;
const POLL = `local r = workspace:FindFirstChild("WOLD"); return r and ((r:GetAttribute("Status") or "?") .. " | " .. (r:GetAttribute("Progress") or "")) or "no WOLD folder"`;
(async () => {
  const c = await connect();
  console.log(`sending ${file} (${(code.length / 1024).toFixed(0)} KB, SCALE=${scale})`);
  console.log("execute_luau ->", c.text(await c.tool("execute_luau", { datamodel_type: "Edit", code })));
  const t0 = Date.now(); let last = "";
  while (Date.now() - t0 < timeout * 1000) {
    await new Promise((r) => setTimeout(r, 5000));
    const s = c.text(await c.tool("execute_luau", { datamodel_type: "Edit", code: POLL }));
    if (s !== last) { console.log(new Date().toISOString().slice(11, 19), s); last = s; }
    if (/\bdone\b/.test(s)) break;
    if (/error:/.test(s)) { console.log("---- console ----\n" + c.text(await c.tool("get_console_output", {}))); process.exitCode = 1; break; }
  }
  if (Date.now() - t0 >= timeout * 1000) { console.error("timeout waiting for phase"); process.exitCode = 2; }
  c.close(); process.exit();
})();
```

- [ ] **Step 0.5: เขียน `mapgen/spike_async.lua`** (ไม่ใช้ lib; ทดสอบ 2 สมมติฐาน)

```lua
-- throwaway spike: (1) task.spawn keeps running after execute_luau returns, (2) WriteVoxels speed for 60 chunks of 256x256 studs
local root = workspace:FindFirstChild("WOLD") or Instance.new("Folder"); root.Name = "WOLD"; root.Parent = workspace
root:SetAttribute("Status", "running"); root:SetAttribute("Progress", "spike start")
task.spawn(function()
  local ok, err = pcall(function()
    local t0 = os.clock()
    local n, ny = 64, 25
    local mats, occ = {}, {}
    for i = 1, n do mats[i], occ[i] = {}, {}
      for j = 1, ny do mats[i][j], occ[i][j] = table.create(n, Enum.Material.Rock), table.create(n, 1) end end
    for c = 0, 59 do
      local x0, z0 = (c % 8) * 256, math.floor(c / 8) * 256 + 20000   -- far from origin so it is easy to wipe
      workspace.Terrain:WriteVoxels(Region3.new(Vector3.new(x0, 0, z0), Vector3.new(x0 + 256, ny * 4, z0 + 256)), 4, mats, occ)
      root:SetAttribute("Progress", ("chunk %d/60  %.1fs"):format(c + 1, os.clock() - t0)); task.wait()
    end
    root:SetAttribute("Progress", ("60 chunks in %.1fs"):format(os.clock() - t0))
  end)
  root:SetAttribute("Status", ok and "done" or ("error: " .. tostring(err)))
end)
return "spawned"
```

- [ ] **Step 0.6: รัน spike**

Run: `node tools/run-luau.js mapgen/spike_async.lua --timeout 300`
Expected: บรรทัด `execute_luau -> ...spawned...` แล้วบรรทัด progress เพิ่มขึ้นทุก 5 วินาที จนถึง `done | 60 chunks in N s` ถ้า Status ค้าง `running` และ Progress ไม่เพิ่ม = task.spawn ตายหลังคืนค่า → ใช้แผน B (ดูท้าย Task)
บันทึกเวลา N: คาด 60 ก้อน < 30 วินาที → เกาะจริง 2,800 ก้อน ≈ N × 47 (รวมคำนวณความสูงอีกประมาณ 2 เท่า)

- [ ] **Step 0.7: ทดสอบ `shot` และรูปแบบผลลัพธ์**

Run: `node tools/mcp-call.js shot spike 1024 600 21024 1024 0 21024`
Expected: `saved ...docs/shots/spike.png` แล้วเปิดดูด้วย Read เห็นแผ่นหินสี่เหลี่ยม 60 ก้อน ถ้าพิมพ์ JSON แทน = โครงสร้างผลลัพธ์ต่าง ให้แก้ตัวหา `img` ตาม JSON ที่เห็น

- [ ] **Step 0.8: ล้างของทดสอบ**

Run: `node tools/mcp-call.js execute_luau '{"datamodel_type":"Edit","code":"workspace.Terrain:Clear(); local r = workspace:FindFirstChild(\"WOLD\"); if r then r:Destroy() end; local t = workspace:FindFirstChild(\"MCP_Test\"); if t then t:Destroy() end; return \"cleaned\""}'`
Expected: `cleaned`; `node tools/mcp-call.js search_game_tree '{"datamodel_type":"Edit","path":"Workspace","max_depth":1}'` ไม่มี WOLD และ MCP_Test

- [ ] **Step 0.9: ลบ spike และ commit**

```bash
git rm -q --cached mapgen/spike_async.lua 2>/dev/null; rm -f mapgen/spike_async.lua
echo "docs/shots/" >> .gitignore   # ภาพตรวจงานไม่ commit ยกเว้นภาพสรุปที่ระบุ
git add tools/mcp-client.js tools/mcp-call.js tools/run-luau.js .gitignore
git commit -m "tools: shared MCP client, run-luau phase runner with progress polling, shot capture"
```

รายงานผู้ใช้: เวลา WriteVoxels ที่วัดได้ และยืนยันว่า async ทำงาน (เกณฑ์ผ่านข้อ 0)

**แผน B ถ้า task.spawn ไม่รอดหลังคืนค่า:** เปลี่ยน `L.runPhase` ให้รันงานเป็นชิ้น: ไฟล์ขั้นเก็บงานเป็นรายการฟังก์ชันใน `_G.WOLD_JOBS` และตัวส่งเรียก `execute_luau` ซ้ำด้วยโค้ด `return _G.WOLD_STEP(20)` (ทำ 20 งานต่อครั้ง) จนคืน `done` ไฟล์ขั้นไม่ต้องแก้เพราะเรียกผ่าน `L.runPhase` เหมือนเดิม

---

### Task 1: lib.lua แกนหลัก + 00_setup + test_lib (ขั้น 1)

**Files:**
- Modify: `docs/design/world-layout.json` (เพิ่ม `kind` ให้ places, เพิ่ม `dir`/`length` ให้ bridges)
- Create: `mapgen/lib.lua` (ส่วน A: พิกัด คณิต ความสูง แม่น้ำ Terrain progress self-check)
- Create: `mapgen/test_lib.lua`
- Create: `mapgen/00_setup.lua`

**Interfaces:**
- Produces (ใช้ทุก Task ถัดไป):
  - `L.SCALE, L.VS (= sqrt(SCALE) สเกลแนวดิ่งตอนย่อส่วน), L.HALF (studs), L.LAYOUT (ตาราง JSON), L.C (จานสี), MAT = Enum.Material`
  - `L.toWorld({u,v}) → x, z` · `L.placePos(name) → x, z` · `L.pt(entry) → {u,v}` (ชื่อสถานที่หรือจุดผ่าน)
  - `L.base(u, v) → h, forest, cliff, land` · `L.sample(u, v) → h, forest, cliff, land, riverDist(studs), riverSurface, riverWidth`
  - `L.heightAt(x, z) → h` · `L.isLand(x, z) → bool` · `L.riverAt(x, z) → d, surfaceY, width`
  - `L.writeChunk(x0, z0, n)` เขียน Terrain ก้อน n คอลัมน์ (n*4 studs) รวมน้ำแม่น้ำ
  - `L.runPhase(name, fn(folder)) → string` · `L.progress(msg)` · `L.root() → Folder workspace.WOLD`
  - `L.check(list, cond, msg)` · `L.materialAtPoint(x, y, z) → Enum.Material` · `L.countParts(inst) → n`
  - `L.polyDist(pts, total, u, v) → d, t` · `L.isles` (รายการเกาะ+โขดหิน `{pos, r, top, bump, name}`) · `L.rivers`
  - `L.fbm, L.sig, L.smooth, L.gauss`

- [ ] **Step 1.1: เพิ่มข้อมูลใน `world-layout.json`** แก้ด้วย Python (pyembed) เพื่อรักษา UTF-8:

```python
import json
p = "docs/design/world-layout.json"
d = json.load(open(p, encoding="utf-8"))
kinds = {"Brasshaven": "capital", "Ironcrest Keep": "castle", "Goldmeadow": "farm", "Cogsworth": "engineer",
         "Stonemark": "mine", "Elderwood": "lumber", "Saltmere": "fishing", "Astravale": "mage", "Spire of Eld": "spire"}
for n, k in kinds.items(): d["places"][n]["kind"] = k
dirs = {"Crown Bridge": ([-0.10, -0.16], 160), "Iron Rail Bridge": ([0.22, 0.56], 160), "Cogsworth Drawbridge": ([0.22, 0.28], 140),
        "Goldmeadow Footbridge": ([0.18, 0.01], 120), "Elderwood Log Bridge": ([0.38, 0.10], 80)}
for b in d["bridges"]: b["dir"], b["length"] = dirs[b["name"]]
d["_bridges_note"] = "dir = ทิศทางสะพานตามถนน/รางที่ข้าม (สัดส่วน ไม่ต้อง normalize), length = ความยาวสะพาน studs"
json.dump(d, open(p, "w", encoding="utf-8", newline="\n"), ensure_ascii=False, indent=2)
print("ok")
```

Run: `PYTHONUTF8=1 C:/Users/watch/hacker/pyembed/python.exe - <<'EOF' ... EOF` (วางโค้ดข้างบน) แล้ว `cd docs/design && PYTHONUTF8=1 C:/Users/watch/hacker/pyembed/python.exe render-map.py`
Expected: `ok` และ `saved map-arture-v1.png`

- [ ] **Step 1.2: เขียน `mapgen/lib.lua` ส่วน A**

```lua
-- mapgen/lib.lua — shared library. Prepended by tools/run-luau.js after `local SCALE` and `local LAYOUT_JSON`.
-- Everything lives on table L to stay under Luau's 200-locals-per-function limit.
local HttpService = game:GetService("HttpService")
local Terrain = workspace.Terrain
local MAT = Enum.Material
local L = {}
L.SCALE = SCALE or 1
L.VS = math.sqrt(L.SCALE)                       -- vertical scale for miniature tests (1 at full scale)
L.LAYOUT = HttpService:JSONDecode(LAYOUT_JSON)
local Y = L.LAYOUT
L.HALF = Y.half_size_studs * L.SCALE
L.MAT = MAT

-- ---------- coordinates ----------
function L.toWorld(p) return p[1] * L.HALF, p[2] * L.HALF end
function L.toNorm(x, z) return x / L.HALF, z / L.HALF end
function L.pt(e) if type(e) == "table" then return e end; return Y.places[e].pos end
function L.placePos(name) return L.toWorld(Y.places[name].pos) end
function L.S(v) return v * (L.SCALE < 1 and L.VS or 1) end   -- shrink structure sizes only in miniature mode

-- ---------- math ----------
local function clamp01(t) return math.clamp(t, 0, 1) end
function L.sig(a) return 1 / (1 + math.exp(-math.clamp(a, -30, 30))) end
function L.gauss(u, v, c, s) local dx, dz = u - c[1], v - c[2]; return math.exp(-(dx * dx + dz * dz) / (2 * s * s)) end
function L.smooth(t) t = clamp01(t); return t * t * (3 - 2 * t) end
function L.fbm(u, v, seed)                       -- 4 octaves, ~[0,1], deterministic
  local s, a, f = 0, 0.5, 2
  for _ = 1, 4 do s += a * (math.noise(u * f + seed, v * f - seed * 1.7, seed * 0.37) + 0.5); a *= 0.5; f *= 2 end
  return clamp01(s / 0.9375)
end
function L.polyLen(pts) local s = 0; for i = 1, #pts - 1 do s += math.sqrt((pts[i + 1][1] - pts[i][1]) ^ 2 + (pts[i + 1][2] - pts[i][2]) ^ 2) end; return s end
function L.polyDist(pts, total, u, v)            -- nearest distance to polyline + fraction 0..1 along it (normalized units)
  local best, bestT, acc = math.huge, 0, 0
  for i = 1, #pts - 1 do
    local a, b = pts[i], pts[i + 1]
    local abx, abz = b[1] - a[1], b[2] - a[2]
    local len2 = abx * abx + abz * abz
    local t = len2 > 0 and math.clamp(((u - a[1]) * abx + (v - a[2]) * abz) / len2, 0, 1) or 0
    local d = math.sqrt((u - a[1] - abx * t) ^ 2 + (v - a[2] - abz * t) ^ 2)
    local segLen = math.sqrt(len2)
    if d < best then best = d; bestT = (acc + segLen * t) / total end
    acc += segLen
  end
  return best, bestT
end

-- ---------- isles + decorative rocks ----------
L.isles = {}
for name, isl in pairs(Y.isles) do L.isles[#L.isles + 1] = { name = name, pos = isl.pos, r = isl.r, top = 15, bump = 90 } end
do
  local rng = Random.new(Y.rocks.seed)
  local made = 0
  while made < Y.rocks.count do
    local a = rng:NextNumber(0, 2 * math.pi); local r = rng:NextNumber(Y.rocks.r_min, Y.rocks.r_max)
    local p = { math.cos(a) * r, math.sin(a) * r }
    local ok = true
    for _, isl in ipairs(L.isles) do if math.sqrt((p[1] - isl.pos[1]) ^ 2 + (p[2] - isl.pos[2]) ^ 2) < isl.r + 0.15 then ok = false end end
    if ok then made += 1; L.isles[#L.isles + 1] = { name = "Rock" .. made, pos = p, r = rng:NextNumber(0.012, 0.02), top = 8, bump = 15, rock = true } end
  end
end

-- ---------- base terrain height (studs) — same formula as render-map.py ----------
local bay, cl, fz, PH = Y.bay, Y.cliffs, Y.forest, Y.peak_height_studs
function L.base(u, v)
  local VS = L.VS
  local r = math.sqrt(u * u + v * v)
  local ang = math.deg(math.atan2(v, u))
  local n1, n2, n3 = L.fbm(u, v, 11), L.fbm(u, v, 23), L.fbm(u, v, 37)
  local rc = Y.coast_radius + Y.coast_noise * (2 * n1 - 1) - bay.depth * math.exp(-(ang - bay.angle_deg) ^ 2 / (2 * bay.sigma_deg ^ 2))
  local land = clamp01((rc - r) / 0.05)
  local plains = 20 + 40 * n2
  local fm = L.sig((fz.x_max - u) / 0.08) * L.sig((fz.z_abs_max - math.abs(v)) / 0.08) * (0.55 + 0.45 * n3)
  local mb = L.sig((Y.mountain_band_z - v) / 0.06)
  local ridge = math.exp(-(v + 0.60) ^ 2 / (2 * 0.07 ^ 2)) * L.sig((0.45 - math.abs(u)) / 0.05)
  local cliff = L.sig((r - cl.r_min) / 0.05) * math.exp(-(math.abs(ang) - cl.center_deg) ^ 2 / (2 * cl.sigma_deg ^ 2)) * 110
  local hl = plains + fm * 30 + mb * (250 + 330 * n3)
    + L.gauss(u, v, Y.peaks.main_NE, 0.10) * (PH.main_NE - 450) + L.gauss(u, v, Y.peaks.second_NW, 0.10) * (PH.second_NW - 450)
    + ridge * 380 + L.gauss(u, v, Y.crown_hill, 0.07) * Y.crown_hill_height_studs + cliff
  local h = land * hl + (1 - land) * Y.sea.seabed_y
  for _, isl in ipairs(L.isles) do
    local dx, dz = u - isl.pos[1], v - isl.pos[2]; local d = math.sqrt(dx * dx + dz * dz)
    if d < isl.r * 1.4 then
      local m = clamp01((isl.r * (0.85 + 0.3 * n1) - d) / 0.015)
      h = m * (isl.top + isl.bump * math.exp(-d * d / (2 * (isl.r * 0.5) ^ 2))) + (1 - m) * h
    end
  end
  return h * VS, fm, cliff * VS, land
end

-- ---------- rivers: surface height monotone downstream, valley carved into height ----------
local function buildRiver(pts, widths, mouthY)
  local R = { pts = pts, total = L.polyLen(pts), w0 = widths[1], w1 = widths[2], h = {}, cum = { 0 } }
  local prev = math.huge
  for i, p in ipairs(pts) do local hb = L.base(p[1], p[2]); R.h[i] = math.min(hb - 6 * L.VS, prev); prev = R.h[i] end
  R.h[#pts] = mouthY
  for i = #pts - 1, 1, -1 do if R.h[i] < R.h[i + 1] then R.h[i] = R.h[i + 1] end end
  for i = 2, #pts do R.cum[i] = R.cum[i - 1] + math.sqrt((pts[i][1] - pts[i - 1][1]) ^ 2 + (pts[i][2] - pts[i - 1][2]) ^ 2) end
  return R
end
local function riverSample(R, t)
  local s = t * R.total
  local i = 1; while i < #R.cum - 1 and R.cum[i + 1] < s do i += 1 end
  local f = (s - R.cum[i]) / math.max(R.cum[i + 1] - R.cum[i], 1e-9)
  return R.h[i] + (R.h[i + 1] - R.h[i]) * f, (R.w0 + (R.w1 - R.w0) * t) * L.VS
end
L.rivers = { buildRiver(Y.river_main, Y.river_width_studs.main, 0) }
do -- tributary ends where it meets the main river: inherit that surface height
  local last = Y.river_tributary[#Y.river_tributary]
  local _, t = L.polyDist(Y.river_main, L.rivers[1].total, last[1], last[2])
  local hs = riverSample(L.rivers[1], t)
  L.rivers[2] = buildRiver(Y.river_tributary, Y.river_width_studs.tributary, hs)
end
function L.river(u, v)                            -- -> dist(studs), surfaceY, width(studs)
  local best, hs, w
  for _, R in ipairs(L.rivers) do
    local d, t = L.polyDist(R.pts, R.total, u, v)
    if not best or d < best then best = d; hs, w = riverSample(R, t) end
  end
  return best * L.HALF, hs, w
end
L.VALLEY = 0.03                                   -- valley half-width, normalized (240 studs at full scale)
function L.sample(u, v)
  local h, fm, cliff, land = L.base(u, v)
  local d, hs, w = L.river(u, v)
  local valley = L.VALLEY * L.HALF
  if land > 0.5 and d < valley then
    local bed = hs - 10 * L.VS
    if d <= w / 2 then h = bed
    else h = bed + (math.max(h, hs + 3 * L.VS) - bed) * L.smooth((d - w / 2) / (valley - w / 2)) end
  end
  return h, fm, cliff, land, d, hs, w
end
function L.heightAt(x, z) return (L.sample(x / L.HALF, z / L.HALF)) end
function L.isLand(x, z) local _, _, _, land = L.base(x / L.HALF, z / L.HALF); return land > 0.5 end
function L.riverAt(x, z) local _, _, _, _, d, hs, w = L.sample(x / L.HALF, z / L.HALF); return d, hs, w end

-- ---------- terrain chunk writer ----------
function L.materialFor(h, yc, fm, cliff, slope, SNOW, MTN)
  if yc < h - 12 * L.VS then return MAT.Rock end
  if h < 4 * L.VS then return MAT.Sand end
  if h >= SNOW then return MAT.Snow end
  if cliff > 60 * L.VS then return MAT.Basalt end
  if h >= MTN or slope > 1.2 then return MAT.Rock end
  if fm > 0.5 then return MAT.LeafyGrass end
  return MAT.Grass
end
function L.writeChunk(x0, z0, n)                   -- x0,z0 multiples of 4; n columns (n*4 studs square)
  local HALF, VS = L.HALF, L.VS
  local H, FM, CL, RD, RH, RW = {}, {}, {}, {}, {}, {}
  local minH, maxH = math.huge, -math.huge
  for i = 1, n + 1 do
    H[i], FM[i], CL[i], RD[i], RH[i], RW[i] = {}, {}, {}, {}, {}, {}
    for k = 1, n + 1 do
      local h, fm, c, d, hs, w = L.sample((x0 + (i - 1) * 4) / HALF, (z0 + (k - 1) * 4) / HALF)
      H[i][k], FM[i][k], CL[i][k], RD[i][k], RH[i][k], RW[i][k] = h, fm, c, d, hs, w
      if h < minH then minH = h end; if h > maxH then maxH = h end
      if d <= w / 2 and hs > maxH then maxH = hs end
    end
  end
  local seabed = Y.sea.seabed_y * VS
  local y0 = math.floor(math.min(minH, seabed) / 4) * 4 - 4
  local y1 = math.ceil(math.max(maxH, 0) / 4) * 4 + 4
  local ny = (y1 - y0) / 4
  if ny * n * n > 1.5e6 and n > 16 then           -- tall mountain chunk: split into 4 to bound table size
    local half = n / 2
    for _, o in ipairs({ { 0, 0 }, { half, 0 }, { 0, half }, { half, half } }) do L.writeChunk(x0 + o[1] * 4, z0 + o[2] * 4, half) end
    return
  end
  local SNOW, MTN = Y.snow_line_studs * VS, 250 * VS
  local mats, occ = table.create(n), table.create(n)
  for i = 1, n do
    mats[i], occ[i] = table.create(ny), table.create(ny)
    for j = 1, ny do mats[i][j], occ[i][j] = table.create(n), table.create(n) end
  end
  for i = 1, n do
    for k = 1, n do
      local h, fm, c = H[i][k], FM[i][k], CL[i][k]
      local slope = math.max(math.abs(H[i + 1][k] - h), math.abs(H[i][k + 1] - h)) / 4
      local d, hs, w = RD[i][k], RH[i][k], RW[i][k]
      local waterTop = (h < 0) and 0 or ((d <= w / 2) and hs or nil)
      for j = 1, ny do
        local ybot = y0 + (j - 1) * 4; local ytop = ybot + 4; local yc = ybot + 2
        local m, o
        if ytop <= h then m, o = L.materialFor(h, yc, fm, c, slope, SNOW, MTN), 1
        elseif ybot < h then m, o = L.materialFor(h, yc, fm, c, slope, SNOW, MTN), (h - ybot) / 4
        elseif waterTop and ybot < waterTop then m, o = MAT.Water, math.min((waterTop - ybot) / 4, 1)
        else m, o = MAT.Air, 0 end
        mats[i][j][k], occ[i][j][k] = m, o
      end
    end
  end
  Terrain:WriteVoxels(Region3.new(Vector3.new(x0, y0, z0), Vector3.new(x0 + n * 4, y1, z0 + n * 4)), 4, mats, occ)
end

-- ---------- phase runner / progress / checks ----------
function L.root()
  local r = workspace:FindFirstChild(Y.generator.workspace_root)
  if not r then r = Instance.new("Folder"); r.Name = Y.generator.workspace_root; r.Parent = workspace end
  return r
end
function L.progress(msg) L.root():SetAttribute("Progress", msg); print("[WOLD] " .. msg) end
function L.runPhase(name, fn)
  local root = L.root()
  local old = root:FindFirstChild(name); if old then old:Destroy() end
  local folder = Instance.new("Folder"); folder.Name = name; folder.Parent = root
  root:SetAttribute("Status", "running"); root:SetAttribute("Phase", name); L.progress(name .. " start")
  task.spawn(function()
    local t0 = os.clock()
    local ok, err = pcall(fn, folder)
    if ok then root:SetAttribute("Status", "done"); L.progress(("%s done in %.0fs"):format(name, os.clock() - t0))
    else root:SetAttribute("Status", "error: " .. tostring(err)); warn("[WOLD] " .. name .. " ERROR " .. tostring(err)) end
  end)
  return "started " .. name
end
function L.check(list, cond, msg) if not cond then list[#list + 1] = msg end; return cond end
function L.materialAtPoint(x, y, z)
  local reg = Region3.new(Vector3.new(x - 2, y - 2, z - 2), Vector3.new(x + 2, y + 2, z + 2)):ExpandToGrid(4)
  return Terrain:ReadVoxels(reg, 4)[1][1][1]
end
function L.countParts(inst) local c = 0; for _, d in ipairs(inst:GetDescendants()) do if d:IsA("BasePart") then c += 1 end end; return c end
function L.requireFullScale() assert(L.SCALE == 1, "this phase must run at SCALE=1 (structures are not scaled)") end

-- ---------- palette ----------
local rgb = Color3.fromRGB
L.C = { stone = rgb(163, 162, 165), darkStone = rgb(99, 95, 98), brick = rgb(136, 72, 58), wood = rgb(86, 66, 54), plank = rgb(159, 124, 90),
  roofRed = rgb(160, 60, 50), roofBlue = rgb(70, 90, 140), roofGreen = rgb(80, 110, 80), plaster = rgb(222, 208, 190), brass = rgb(196, 150, 60),
  copper = rgb(150, 90, 60), iron = rgb(60, 60, 65), rust = rgb(120, 70, 40), crystal = rgb(120, 220, 255), leafDark = rgb(40, 90, 45),
  leafLight = rgb(70, 130, 60), trunk = rgb(80, 55, 35), sail = rgb(235, 230, 210), glass = rgb(150, 200, 220), sea = rgb(28, 70, 120) }
-- (part builders are appended in Task 4 and Task 5 below this line)
```

- [ ] **Step 1.3: เขียน `mapgen/test_lib.lua`** (self-test: รันได้ทุก SCALE พิมพ์ผลและ error ถ้าผิด)

```lua
-- self-test for lib.lua: land/sea/peak/river sanity at known layout points
return L.runPhase("LibTest", function()
  local fails = {}
  local bx, bz = L.placePos("Brasshaven")
  L.check(fails, L.isLand(bx, bz), "Brasshaven must be land")
  L.check(fails, L.heightAt(bx, bz) > 4 * L.VS, "Brasshaven height > 4")
  L.check(fails, not L.isLand(L.HALF * 1.6, 0), "far east must be sea")
  L.check(fails, L.heightAt(L.HALF * 1.6, 0) < 0, "far east height < 0")
  local sx, sz = L.placePos("Spire of Eld")
  local peak = L.heightAt(sx, sz) / L.VS
  L.check(fails, peak > 1800 and peak < 2300, ("Spire height %.0f expected 1800..2300"):format(peak))
  for name, _ in pairs(L.LAYOUT.places) do local x, z = L.placePos(name); L.check(fails, L.isLand(x, z), name .. " must be land") end
  local rx, rz = L.toWorld(L.LAYOUT.river_main[5])
  local d, hs, w = L.riverAt(rx, rz)
  L.check(fails, d < 1, ("river vertex dist %.1f should be ~0"):format(d))
  L.check(fails, L.heightAt(rx, rz) < hs, "river bed below surface")
  L.check(fails, L.heightAt(rx + w, rz) > hs, "river bank above surface")
  for _, isl in ipairs(L.isles) do local x, z = L.toWorld(isl.pos); L.check(fails, L.heightAt(x, z) > 5 * L.VS, isl.name .. " isle must be above water") end
  print(("[WOLD] test_lib: Spire=%.0f Brasshaven=%.0f river(d=%.1f hs=%.1f w=%.0f)"):format(peak, L.heightAt(bx, bz), d, hs, w))
  assert(#fails == 0, "test_lib failed:\n" .. table.concat(fails, "\n"))
end)
```

- [ ] **Step 1.4: รัน test_lib**

Run: `node tools/run-luau.js mapgen/test_lib.lua --timeout 120`
Expected: `done | LibTest done in 0s` ถ้า `error:` อ่านข้อความ เช่น `Spire height 1500 expected 1800..2300` → ปรับสูตร (`- 450`) ใน `L.base` แล้วรันใหม่; ถ้า `X must be land` → ขยับพิกัดใน JSON เล็กน้อยแล้วรัน `render-map.py` ใหม่

- [ ] **Step 1.5: เขียน `mapgen/00_setup.lua`**

```lua
-- world setup: wipe test objects, root folder, streaming, lighting/fog, far sea plane
return L.runPhase("Setup", function(folder)
  local Y = L.LAYOUT
  for _, n in ipairs({ "Baseplate", "MCP_Test" }) do local o = workspace:FindFirstChild(n); if o then o:Destroy() end end
  pcall(function() game:GetService("ChangeHistoryService"):SetEnabled(false) end)  -- huge terrain writes must not fill undo history; re-enabled in 90_verify
  workspace.StreamingEnabled = true
  workspace.StreamingMinRadius = Y.generator.streaming.min_radius
  workspace.StreamingTargetRadius = Y.generator.streaming.target_radius
  local Lighting = game:GetService("Lighting")
  Lighting.ClockTime = 14; Lighting.Brightness = 2; Lighting.GlobalShadows = true
  local atm = Lighting:FindFirstChildOfClass("Atmosphere") or Instance.new("Atmosphere", Lighting)
  atm.Density = 0.35; atm.Haze = 1.5; atm.Color = Color3.fromRGB(199, 210, 230)
  Lighting.FogEnd = Y.sea.fog_end_studs * L.SCALE; Lighting.FogStart = Lighting.FogEnd * 0.5; Lighting.FogColor = Color3.fromRGB(190, 205, 225)
  -- far sea: tiles from terrain-water extent out to part-sea extent (Part max 2048 per axis)
  local inner, outer, T = Y.sea.terrain_water_extent_studs * L.SCALE, Y.sea.part_sea_extent_studs * L.SCALE, 2048
  local n = 0
  for x = -outer, outer - T, T do for z = -outer, outer - T, T do
    if not (x + T <= inner and x >= -inner and z + T <= inner and z >= -inner) then
      local p = Instance.new("Part"); p.Anchored = true; p.Size = Vector3.new(T, 4, T); p.Position = Vector3.new(x + T / 2, -2, z + T / 2)
      p.Material = Enum.Material.Glass; p.Color = L.C.sea; p.Transparency = 0.15; p.Name = "Sea"; p.Parent = folder; n += 1
    end
  end end
  L.progress(("setup done: %d sea tiles"):format(n))
end)
```

- [ ] **Step 1.6: ขออนุมัติผู้ใช้ข้อ 1 แล้วรัน**

Run: `node tools/run-luau.js mapgen/00_setup.lua --timeout 120`
Expected: `done | setup done: 780 sea tiles` (ที่ SCALE 1)
ตรวจ: `node tools/mcp-call.js execute_luau '{"datamodel_type":"Edit","code":"return workspace.StreamingEnabled, #workspace.WOLD.Setup:GetChildren(), workspace:FindFirstChild(\"Baseplate\") == nil"}'` → `true 780 true`
ภาพ: `node tools/mcp-call.js shot setup 0 3000 40000 0 0 20000` เห็นแผ่นทะเลจางไปในหมอก

- [ ] **Step 1.7: Commit**

```bash
git add docs/design/world-layout.json docs/design/map-arture-v1.png mapgen/lib.lua mapgen/test_lib.lua mapgen/00_setup.lua
git commit -m "mapgen: lib core (layout, height function, rivers, terrain chunk writer, phase runner) + setup phase + lib self-test"
```

---

### Task 2: Terrain ย่อส่วนแล้วขนาดจริง (ขั้น 2a และ 2b)

**Files:**
- Create: `mapgen/10_terrain.lua`

**Interfaces:**
- Consumes: `L.writeChunk`, `L.isles`, `L.LAYOUT.sea`, `L.LAYOUT.generator.terrain_chunk_studs`, `L.progress`
- Produces: Terrain ทั้งโลก (แผ่นดิน ทะเล พื้นทะเล แม่น้ำมีน้ำ เกาะเล็ก โขดหิน)

- [ ] **Step 2.1: เขียน `mapgen/10_terrain.lua`**

```lua
-- terrain: clear, sea slab + water, then island + isles chunk by chunk (river water is written inside chunks)
return L.runPhase("Terrain", function()
  local Y, MAT, VS, HALF = L.LAYOUT, L.MAT, L.VS, L.HALF
  local Terrain = workspace.Terrain
  Terrain:Clear()
  local ext = Y.sea.terrain_water_extent_studs * L.SCALE
  local sb, deep = Y.sea.seabed_y * VS, Y.sea.deep_seabed_y * VS
  Terrain:FillBlock(CFrame.new(0, (sb + deep) / 2, 0), Vector3.new(ext * 2, sb - deep, ext * 2), MAT.Sand)
  Terrain:FillBlock(CFrame.new(0, sb / 2, 0), Vector3.new(ext * 2, -sb, ext * 2), MAT.Water)
  L.progress("sea slab done")
  local CH = Y.generator.terrain_chunk_studs
  local n = CH / 4
  local jobs = {}
  local function addArea(cx, cz, rad)
    for x = math.floor((cx - rad) / CH) * CH, math.ceil((cx + rad) / CH) * CH - CH, CH do
      for z = math.floor((cz - rad) / CH) * CH, math.ceil((cz + rad) / CH) * CH - CH, CH do
        local near = false
        for _, c in ipairs({ { x, z }, { x + CH, z }, { x, z + CH }, { x + CH, z + CH }, { x + CH / 2, z + CH / 2 } }) do
          if math.sqrt((c[1] - cx) ^ 2 + (c[2] - cz) ^ 2) < rad then near = true end
        end
        if near then jobs[#jobs + 1] = { x, z } end
      end
    end
  end
  addArea(0, 0, (Y.coast_radius + Y.coast_noise + 0.02) * HALF)
  for _, isl in ipairs(L.isles) do local x, z = L.toWorld(isl.pos); addArea(x, z, isl.r * 1.5 * HALF) end
  local t0 = os.clock()
  for i, j in ipairs(jobs) do
    L.writeChunk(j[1], j[2], n)
    if i % 4 == 0 then L.progress(("terrain %d/%d  %.0fs"):format(i, #jobs, os.clock() - t0)); task.wait() end
  end
  L.progress(("terrain %d chunks in %.0fs"):format(#jobs, os.clock() - t0))
end)
```

- [ ] **Step 2.2: ขออนุมัติผู้ใช้ข้อ 2a แล้วรันย่อส่วน**

Run: `node tools/run-luau.js mapgen/10_terrain.lua --scale 0.125 --timeout 600`
Expected: `done | terrain ~80 chunks in N s`

- [ ] **Step 2.3: ภาพมุมบนเทียบแผนที่**

Run: `node tools/mcp-call.js shot terrain-mini-top 0 2600 1 0 0 0` และ `node tools/mcp-call.js shot terrain-mini-side 1400 500 2200 0 0 0`
Expected (ดูภาพด้วย Read): อ่าวเว้าที่ SE, ป่าเขียวเข้ม W, แนวเขา N มีหิมะ 2 ยอด, แม่น้ำเป็นเส้นน้ำจากเขาลงอ่าว, เกาะเล็ก 5 เกาะ + โขดหินรอบ, สัดส่วนตรง `docs/design/map-arture-v1.png` ถ้าไม่ตรง แก้ `L.base`/`L.sample` แล้วรันใหม่ (รอบละ 1-2 นาที) จนตรง

- [ ] **Step 2.4: ให้ผู้ใช้อนุมัติรูปเกาะ** ส่งชื่อไฟล์ภาพ `docs/shots/terrain-mini-top.png` ให้ผู้ใช้เปิดดู แล้ว AskUserQuestion (อนุมัติ / ขอแก้: ระบุ) ถ้าขอแก้ วนกลับ Step 2.3

- [ ] **Step 2.5: ขออนุมัติข้อ 2b แล้วรันขนาดจริง**

Run: `node tools/run-luau.js mapgen/10_terrain.lua --timeout 3600`
Expected: progress ทุก 5 วินาที จน `done | terrain ~2800 chunks in N s` (คาด 600-1200 วินาที) ถ้า Studio ค้างเกิน 60 วินาทีโดย progress ไม่ขยับ = ก้อนใหญ่เกิน → ลด `terrain_chunk_studs` เป็น 128 ใน JSON แล้วรันใหม่

- [ ] **Step 2.6: self-check ขนาดจริง**

Run: `node tools/run-luau.js mapgen/test_lib.lua` (ยืนยันสูตร) แล้ว
`node tools/mcp-call.js execute_luau '{"datamodel_type":"Edit","code":"local m = {} for name, p in pairs(L and {} or {}) do end return \"see next\""}'` — ใช้สคริปต์ตรวจจริงด้านล่างแทน (บันทึกเป็น `mapgen/check_terrain.lua`):

```lua
-- check_terrain.lua: every place stands on solid ground; river vertices are water; spire height
return L.runPhase("CheckTerrain", function()
  local fails = {}
  for name, p in pairs(L.LAYOUT.places) do
    local x, z = L.toWorld(p.pos); local h = L.heightAt(x, z)
    local m = L.materialAtPoint(x, h - 3, z)
    L.check(fails, m ~= Enum.Material.Water and m ~= Enum.Material.Air, ("%s ground is %s"):format(name, tostring(m)))
  end
  for i, v in ipairs(L.LAYOUT.river_main) do
    if i < #L.LAYOUT.river_main then
      local x, z = L.toWorld(v); local _, hs = L.riverAt(x, z)
      L.check(fails, L.materialAtPoint(x, hs - 2, z) == Enum.Material.Water, ("river vertex %d not water"):format(i))
    end
  end
  local sx, sz = L.placePos("Spire of Eld"); local peak = L.heightAt(sx, sz)
  L.check(fails, peak > 1900 * L.VS and peak < 2100 * L.VS, ("peak %.0f"):format(peak))
  assert(#fails == 0, table.concat(fails, "\n"))
  L.progress("terrain checks passed")
end)
```

Run: `node tools/run-luau.js mapgen/check_terrain.lua`
Expected: `done | terrain checks passed`

- [ ] **Step 2.7: ภาพขนาดจริง**

Run: `node tools/mcp-call.js shot terrain-top 0 9000 1 0 0 0`, `node tools/mcp-call.js shot terrain-bay 4800 400 4800 2400 100 3000`, `node tools/mcp-call.js shot terrain-spire 3200 2600 -5600 3600 2100 -4800`
Expected: เห็นเกาะทั้งใบ อ่าว หุบแม่น้ำ ยอดหิมะ ถ้ามีรอยต่อก้อน (ขั้นบันได) ระหว่างชิ้น = ค่า y0 ไม่ตรง ให้ตรวจสูตร `y0` ใน `writeChunk`

- [ ] **Step 2.8: Commit**

```bash
cp docs/shots/terrain-top.png docs/design/shot-terrain-v1.png
git add mapgen/10_terrain.lua mapgen/check_terrain.lua docs/design/shot-terrain-v1.png
git commit -m "mapgen: terrain phase (island, sea, isles, rivers) generated at full scale; terrain checks pass"
```

---

### Task 3: ถ้ำ 3 แห่ง (ขั้น 3)

**Files:**
- Modify: `mapgen/lib.lua` (เพิ่ม `L.findShore`, `L.part`, `L.box`, `L.ball`, `L.cyl`, `L.model` ก่อน Task 4 เพราะถ้ำใช้คริสตัล)
- Create: `mapgen/11_caves.lua`

**Interfaces:**
- Produces: `L.findShore(x, z, dx, dz, maxDist) → sx, sz` (จุดสุดท้ายที่ยังเป็นดินเมื่อเดินไปทาง (dx,dz)); `L.part(parent, shape, cf, size, mat, color, opts)`; `L.box(parent, cf, size, mat, color, opts)`; `L.ball(...)`; `L.cyl(parent, cf, radius, height, mat, color, opts)` (แกนตั้ง); `L.rod(parent, a, b, radius, mat, color)` (ทรงกระบอกจากจุด a ไป b); `L.model(parent, name) → Model`; `L.crystal(parent, pos, size, color)`; `L.yaw(rad) → CFrame`
- Consumes: Terrain จาก Task 2

- [ ] **Step 3.1: เพิ่ม primitives ใน `mapgen/lib.lua`** (ต่อท้ายไฟล์)

```lua
-- ---------- part primitives ----------
function L.yaw(a) return CFrame.Angles(0, a, 0) end
function L.part(parent, shape, cf, size, mat, color, opts)
  local p = Instance.new("Part")
  p.Shape = shape or Enum.PartType.Block
  p.Size = size; p.CFrame = cf
  p.Material = mat or MAT.SmoothPlastic; p.Color = color or L.C.stone
  p.Anchored = true; p.TopSurface = Enum.SurfaceType.Smooth; p.BottomSurface = Enum.SurfaceType.Smooth
  if opts then
    if opts.name then p.Name = opts.name end
    if opts.cancollide == false then p.CanCollide = false end
    if opts.transparency then p.Transparency = opts.transparency end
  end
  p.Parent = parent
  return p
end
function L.box(parent, cf, size, mat, color, opts) return L.part(parent, Enum.PartType.Block, cf, size, mat, color, opts) end
function L.ball(parent, cf, size, mat, color, opts) return L.part(parent, Enum.PartType.Ball, cf, size, mat, color, opts) end
function L.cyl(parent, cf, radius, height, mat, color, opts)        -- vertical cylinder (Roblox cylinder axis is X -> roll 90°)
  return L.part(parent, Enum.PartType.Cylinder, cf * CFrame.Angles(0, 0, math.pi / 2), Vector3.new(height, radius * 2, radius * 2), mat, color, opts)
end
function L.rod(parent, a, b, radius, mat, color, opts)              -- cylinder from point a to point b
  local len = (b - a).Magnitude
  local cf = CFrame.lookAt((a + b) / 2, b) * CFrame.Angles(0, math.pi / 2, 0)   -- X axis along a->b
  return L.part(parent, Enum.PartType.Cylinder, cf, Vector3.new(len, radius * 2, radius * 2), mat, color, opts)
end
function L.wedge(parent, cf, size, mat, color)
  local p = Instance.new("WedgePart"); p.Size = size; p.CFrame = cf; p.Material = mat or MAT.Slate; p.Color = color or L.C.roofRed
  p.Anchored = true; p.Parent = parent; return p
end
function L.model(parent, name) local m = Instance.new("Model"); m.Name = name; m.Parent = parent; return m end
function L.crystal(parent, pos, size, color)
  local p = L.box(parent, CFrame.new(pos) * CFrame.Angles(math.rad(35), math.rad(45), 0), Vector3.new(size, size * 2.2, size), MAT.Neon, color or L.C.crystal, { cancollide = false, name = "Crystal" })
  local light = Instance.new("PointLight"); light.Color = color or L.C.crystal; light.Range = size * 8; light.Brightness = 2; light.Parent = p
  return p
end
function L.findShore(x, z, dx, dz, maxDist)     -- walk from (x,z) along (dx,dz) until water; returns last land point
  local len = math.sqrt(dx * dx + dz * dz); dx, dz = dx / len, dz / len
  local lx, lz = x, z
  for s = 0, maxDist or 3000, 8 do
    local px, pz = x + dx * s, z + dz * s
    if L.heightAt(px, pz) < 1 then return lx, lz end
    lx, lz = px, pz
  end
  return lx, lz
end
function L.dirTo(x, z, tx, tz) local dx, dz = tx - x, tz - z; local l = math.sqrt(dx * dx + dz * dz); return dx / l, dz / l end
```

- [ ] **Step 3.2: เขียน `mapgen/11_caves.lua`**

```lua
-- caves: carve air balls along a deterministic tunnel path into the mountain, flat floors, chambers, decorations
return L.runPhase("Caves", function(folder)
  L.requireFullScale()
  local Y, MAT, Terrain = L.LAYOUT, L.MAT, workspace.Terrain
  local function carve(path, r)                       -- path: list of Vector3 centers; air balls every 6 studs + flat floor slab
    for i = 1, #path - 1 do
      local a, b = path[i], path[i + 1]; local len = (b - a).Magnitude
      for s = 0, len, 6 do
        local p = a + (b - a).Unit * s
        Terrain:FillBall(p + Vector3.new(0, r * 0.4, 0), r, MAT.Air)
        Terrain:FillBlock(CFrame.new(p.X, p.Y - r * 0.6 - 2, p.Z), Vector3.new(r * 1.6, 4, r * 1.6), MAT.Rock)  -- walkable floor
      end
    end
  end
  local function chamber(p, r) Terrain:FillBall(p + Vector3.new(0, r * 0.5, 0), r, MAT.Air); Terrain:FillBlock(CFrame.new(p.X, p.Y - 2, p.Z), Vector3.new(r * 1.8, 4, r * 1.8), MAT.Rock) end
  local function tunnel(name, ex, ez, tx, tz, rng, legs, down)   -- entrance (ex,ez) heading toward (tx,tz); returns path
    local ey = L.heightAt(ex, ez) + 1
    local path = { Vector3.new(ex, ey, ez) }
    local dx, dz = L.dirTo(ex, ez, tx, tz)
    local p = path[1]
    for i = 1, legs do
      local a = math.atan2(dz, dx) + rng:NextNumber(-0.6, 0.6)
      local len = rng:NextNumber(60, 120)
      p = p + Vector3.new(math.cos(a) * len, -down * len / 100, math.sin(a) * len)
      path[#path + 1] = p
    end
    return path
  end
  local m = L.model(folder, "Caves")
  -- 1) Stonemark Mine: 3 branches, ore veins, cart rails
  do
    local rng = Random.new(101)
    local ex, ez = L.toWorld(Y.caves["Stonemark Mine"]); local px, pz = L.toWorld(Y.peaks.second_NW)
    local main = tunnel("mine", ex, ez, px, pz, rng, 4, 6); carve(main, 14)
    chamber(main[#main], 40)
    for b = 1, 2 do local br = tunnel("mine" .. b, main[2 + b].X, main[2 + b].Z, px + b * 300, pz, rng, 3, 8); br[1] = main[2 + b]; carve(br, 11); chamber(br[#br], 28) end
    for i = 1, 30 do local p = main[rng:NextInteger(2, #main)] + Vector3.new(rng:NextNumber(-14, 14), rng:NextNumber(0, 10), rng:NextNumber(-14, 14))
      L.box(m, CFrame.new(p) * CFrame.Angles(rng:NextNumber(0, 3), rng:NextNumber(0, 3), 0), Vector3.new(4, 3, 5), MAT.CorrodedMetal, L.C.rust, { name = "OreVein" }) end
    for i = 1, #main - 1 do L.rod(m, main[i] - Vector3.new(0, 0.5, 0), main[i + 1] - Vector3.new(0, 0.5, 0), 0.3, MAT.Metal, L.C.iron); L.rod(m, main[i] + Vector3.new(0, -0.5, 3), main[i + 1] + Vector3.new(0, -0.5, 3), 0.3, MAT.Metal, L.C.iron) end
  end
  -- 2) Crystal Cave: big hall under main peak with floating + standing crystals
  do
    local rng = Random.new(202)
    local ex, ez = L.toWorld(Y.caves["Crystal Cave"]); local px, pz = L.toWorld(Y.peaks.main_NE)
    local path = tunnel("crystal", ex, ez, px, pz, rng, 3, 4); carve(path, 16)
    local hall = path[#path]; chamber(hall, 70)
    for i = 1, 24 do local a, r = rng:NextNumber(0, 6.28), rng:NextNumber(10, 60)
      L.crystal(m, hall + Vector3.new(math.cos(a) * r, rng:NextNumber(0, 6), math.sin(a) * r), rng:NextNumber(3, 7)) end
    for i = 1, 8 do local a, r = rng:NextNumber(0, 6.28), rng:NextNumber(15, 45)
      L.crystal(m, hall + Vector3.new(math.cos(a) * r, rng:NextNumber(20, 45), math.sin(a) * r), rng:NextNumber(4, 9)) end
    L.crystal(m, hall + Vector3.new(0, 30, 0), 14)
  end
  -- 3) Sea Cave: entrance on the west cliff beach, tunnel inland with a shipwreck
  do
    local rng = Random.new(303)
    local hx, hz = L.toWorld(Y.caves["Sea Cave"])
    local ex, ez = L.findShore(0, 0, hx, hz, L.HALF * 1.2)           -- walk from island center toward the hint until water
    local path = tunnel("sea", ex, ez, 0, 0, rng, 3, -2); carve(path, 18)
    local hall = path[#path]; chamber(hall, 45)
    Terrain:FillBlock(CFrame.new(hall.X, hall.Y - 3, hall.Z), Vector3.new(60, 6, 60), MAT.Water)   -- tide pool
    local wreck = L.model(m, "Shipwreck")
    L.box(wreck, CFrame.new(hall + Vector3.new(0, 4, 0)) * CFrame.Angles(0, 0.6, 0.25), Vector3.new(50, 10, 16), MAT.WoodPlanks, L.C.wood)
    L.rod(wreck, hall + Vector3.new(0, 8, 0), hall + Vector3.new(6, 40, 0), 1, MAT.Wood, L.C.wood)
    for i = 1, 6 do L.cyl(wreck, CFrame.new(hall + Vector3.new(rng:NextNumber(-30, 30), 2, rng:NextNumber(-30, 30))), 2, 4, MAT.Wood, L.C.plank) end
  end
  L.progress("caves carved")
end)
```

- [ ] **Step 3.3: ขออนุมัติผู้ใช้ข้อ 3 แล้วรัน**

Run: `node tools/run-luau.js mapgen/11_caves.lua --timeout 600`
Expected: `done | caves carved`

- [ ] **Step 3.4: ตรวจภาพปากถ้ำและโถง**

Run สำหรับแต่ละถ้ำ: `node tools/mcp-call.js shot cave-mine <x+120> <h+60> <z+120> <x> <h> <z>` โดย x,z = พิกัดถ้ำ × 8000 และ h จาก `execute_luau ... return L.heightAt(x,z)` (รัน `mapgen/test_lib.lua` ก่อนเพื่อโหลด L ไม่ได้ เพราะ L เป็น local; ให้ใช้ `node tools/run-luau.js` กับไฟล์เล็ก `mapgen/probe.lua` ที่ `print(L.heightAt(x,z))` แล้วอ่านจาก `get_console_output`)
Expected: เห็นรูเข้าถ้ำบนหน้าเขา; ถ่ายจากในถ้ำ `shot cave-crystal-inside <hall.x> <hall.y+10> <hall.z> ...` เห็นคริสตัลเรืองแสง ถ้าปากถ้ำถูกดินปิด (FillBall ไม่ทะลุผิว) ให้เพิ่มลูกบอลอากาศพิเศษที่จุดแรกด้วยรัศมี 22

- [ ] **Step 3.5: Commit**

```bash
git add mapgen/lib.lua mapgen/11_caves.lua
git commit -m "mapgen: caves phase (mine with ore veins, crystal hall, sea cave with shipwreck) + part primitives"
```

---

### Task 4: ชิ้นส่วนก่อสร้าง + ถนน + สะพาน 5 แห่ง (ขั้น 4)

**Files:**
- Modify: `mapgen/lib.lua` (เพิ่มส่วน B: geometry helpers, house, tower, wallPath, gate, bridges, pipeRun, gear, tree, pier, chimney, sign, flatten)
- Create: `mapgen/20_roads_bridges.lua`

**Interfaces:**
- Produces:
  - `L.segIntersect(p, p2, q, q2) → {x,z}, {dx,dz} | nil` · `L.polyCrossings(poly, path) → {{pt=, dir=Vector3}}` · `L.pointInPoly(poly, x, z) → bool` · `L.wallWorld() → poly studs`
  - `L.flattenDisc(x, z, r, y, mat)` · `L.flattenRect(x, z, w, d, y, mat)` (เว้นแม่น้ำ) · `L.padY(x, z) → y` (ความสูงพื้นปัดกริด 4)
  - `L.house(parent, x, y, z, w, d, floors, opts{yaw, roof, name, stone}) → Model` · `L.tower(parent, x, y, z, r, h, opts{roof, roofColor, name}) → Model`
  - `L.wallPath(parent, pts, h, t, opts{gaps={{x,z,half}}, towerSpacing, name}) → Model` · `L.gate(parent, x, z, dir, width, h)`
  - `L.bridge(parent, spec) → Model` และ `L.stoneBridge/L.trussBridge/L.drawBridge/L.woodBridge(m, x, z, dir, len, w, deckY, waterY, opts)`
  - `L.pipeRun(parent, pts, radius, color, postEvery)` · `L.gear(parent, cf, r, teeth, thick, color)` · `L.chimney(parent, x, y, z, r, h, smoke)` · `L.tree(parent, x, y, z, kind, s)` · `L.pier(parent, x, z, dir, len, w, y)` · `L.sign(parent, x, y, z, text, yaw)` · `L.boat(parent, x, y, z, yaw, len)`
- Consumes: Task 3 primitives, Terrain

- [ ] **Step 4.1: เพิ่ม geometry + flatten helpers ใน `mapgen/lib.lua`**

```lua
-- ---------- 2D geometry ----------
function L.segIntersect(p, p2, q, q2)
  local r = { p2[1] - p[1], p2[2] - p[2] }; local s = { q2[1] - q[1], q2[2] - q[2] }
  local den = r[1] * s[2] - r[2] * s[1]; if math.abs(den) < 1e-9 then return nil end
  local t = ((q[1] - p[1]) * s[2] - (q[2] - p[2]) * s[1]) / den
  local u = ((q[1] - p[1]) * r[2] - (q[2] - p[2]) * r[1]) / den
  if t >= 0 and t <= 1 and u >= 0 and u <= 1 then return { p[1] + r[1] * t, p[2] + r[2] * t }, r end
  return nil
end
function L.polyCrossings(poly, path)
  local out = {}
  for i = 1, #path - 1 do for j = 1, #poly do
    local pt, dir = L.segIntersect(path[i], path[i + 1], poly[j], poly[j % #poly + 1])
    if pt then out[#out + 1] = { pt = pt, dir = Vector3.new(dir[1], 0, dir[2]).Unit } end
  end end
  return out
end
function L.pointInPoly(poly, x, z)
  local inside, j = false, #poly
  for i = 1, #poly do
    local xi, zi, xj, zj = poly[i][1], poly[i][2], poly[j][1], poly[j][2]
    if ((zi > z) ~= (zj > z)) and (x < (xj - xi) * (z - zi) / (zj - zi) + xi) then inside = not inside end
    j = i
  end
  return inside
end
function L.wallWorld() local out = {}; for i, p in ipairs(L.LAYOUT.capital.wall.polygon) do local x, z = L.toWorld(p); out[i] = { x, z } end; return out end
function L.roadWorld(road) local out = {}; for i, e in ipairs(road) do local x, z = L.toWorld(L.pt(e)); out[i] = { x, z } end; return out end
function L.padY(x, z) return math.floor(L.heightAt(x, z) / 4) * 4 end
function L.flattenRect(x, z, w, d, y, mat)        -- fill below y, clear above; skips river cells
  local Terrain = workspace.Terrain
  for cx = x - w / 2 + 4, x + w / 2 - 4, 8 do for cz = z - d / 2 + 4, z + d / 2 - 4, 8 do
    local rd, _, rw = L.riverAt(cx, cz)
    if rd > rw / 2 + 10 and L.heightAt(cx, cz) > 0 then
      Terrain:FillBlock(CFrame.new(cx, y - 8, cz), Vector3.new(8, 16, 8), mat or MAT.Ground)
      Terrain:FillBlock(CFrame.new(cx, y + 30, cz), Vector3.new(8, 60, 8), MAT.Air)
    end
  end end
end
function L.flattenDisc(x, z, r, y, mat)
  local Terrain = workspace.Terrain
  for cx = x - r + 4, x + r - 4, 8 do for cz = z - r + 4, z + r - 4, 8 do
    if (cx - x) ^ 2 + (cz - z) ^ 2 <= r * r then
      local rd, _, rw = L.riverAt(cx, cz)
      if rd > rw / 2 + 10 and L.heightAt(cx, cz) > 0 then
        Terrain:FillBlock(CFrame.new(cx, y - 8, cz), Vector3.new(8, 16, 8), mat or MAT.Ground)
        Terrain:FillBlock(CFrame.new(cx, y + 30, cz), Vector3.new(8, 60, 8), MAT.Air)
      end
    end
  end end
end
```

- [ ] **Step 4.2: เพิ่มตัวสร้างอาคารพื้นฐานใน `mapgen/lib.lua`**

```lua
-- ---------- buildings ----------
function L.house(parent, x, y, z, w, d, floors, opts)
  opts = opts or {}
  local m = L.model(parent, opts.name or "House")
  local base = CFrame.new(x, y, z) * L.yaw(opts.yaw or 0)
  local fh = 10
  for f = 0, floors - 1 do
    local stone = (f == 0) or opts.stone
    L.box(m, base * CFrame.new(0, f * fh + fh / 2, 0), Vector3.new(w, fh, d), stone and MAT.Cobblestone or MAT.Plaster, stone and L.C.darkStone or L.C.plaster)
    if not stone then
      for s = -1, 1, 2 do
        L.box(m, base * CFrame.new(s * (w / 2 - 0.4), f * fh + fh / 2, 0), Vector3.new(0.8, fh, d + 0.4), MAT.Wood, L.C.wood, { cancollide = false })
        L.box(m, base * CFrame.new(0, f * fh + fh / 2, s * (d / 2 - 0.4)), Vector3.new(w + 0.4, fh, 0.8), MAT.Wood, L.C.wood, { cancollide = false })
      end
      L.box(m, base * CFrame.new(0, f * fh + 0.4, 0), Vector3.new(w + 0.4, 0.8, d + 0.4), MAT.Wood, L.C.wood, { cancollide = false })
    end
    for s = -1, 1, 2 do L.box(m, base * CFrame.new(s * w / 4, f * fh + 6, d / 2 + 0.2), Vector3.new(3, 3.5, 0.4), MAT.Glass, L.C.glass, { cancollide = false }) end
  end
  L.box(m, base * CFrame.new(0, 4, d / 2 + 0.3), Vector3.new(4, 8, 0.6), MAT.Wood, L.C.wood, { cancollide = false, name = "Door" })
  local rh, top, rc = 7, floors * fh, opts.roof or L.C.roofRed
  L.wedge(m, base * CFrame.new(0, top + rh / 2, d / 4), Vector3.new(w + 2, rh, d / 2 + 1), MAT.Slate, rc)
  L.wedge(m, base * CFrame.new(0, top + rh / 2, -d / 4) * CFrame.Angles(0, math.pi, 0), Vector3.new(w + 2, rh, d / 2 + 1), MAT.Slate, rc)
  L.cyl(m, base * CFrame.new(w / 3, top + rh / 2 + 2, 0), 1.2, rh + 4, MAT.Brick, L.C.brick)
  return m
end
function L.tower(parent, x, y, z, r, h, opts)
  opts = opts or {}
  local m = L.model(parent, opts.name or "Tower")
  L.cyl(m, CFrame.new(x, y + h / 2, z), r, h, MAT.Cobblestone, L.C.stone)
  if opts.roof == false then
    L.cyl(m, CFrame.new(x, y + h + 0.5, z), r + 1, 1, MAT.Cobblestone, L.C.darkStone)
    for i = 0, 7 do local a = i * math.pi / 4; L.box(m, CFrame.new(x + math.cos(a) * r, y + h + 2.5, z + math.sin(a) * r) * L.yaw(-a), Vector3.new(2, 3, 3), MAT.Cobblestone, L.C.stone, { cancollide = false }) end
  else
    for i = 1, 4 do L.cyl(m, CFrame.new(x, y + h + (i - 0.5) * 2.5, z), r * (1.15 - 0.25 * i), 2.5, MAT.Slate, opts.roofColor or L.C.roofRed) end
  end
  return m
end
function L.wallPath(parent, pts, h, t, opts)      -- pts: world {x,z} list (closed if opts.closed); follows terrain; skips water & gaps
  opts = opts or {}
  local m = L.model(parent, opts.name or "Wall")
  local list = {}; for i, p in ipairs(pts) do list[i] = p end
  if opts.closed then list[#list + 1] = pts[1] end
  local since = 0
  for i = 1, #list - 1 do
    local a = Vector3.new(list[i][1], 0, list[i][2]); local b = Vector3.new(list[i + 1][1], 0, list[i + 1][2])
    local len = (b - a).Magnitude; local dir = (b - a).Unit; local yaw = math.atan2(-dir.Z, dir.X)
    local ha = L.heightAt(a.X, a.Z); if ha > 2 then L.tower(m, a.X, ha, a.Z, t * 1.8, h * 1.5, { roof = false }) end
    local s = 0
    while s < len do
      local seg = math.min(10, len - s)
      local p = a + dir * (s + seg / 2)
      local g = L.heightAt(p.X, p.Z)
      local gap = false
      for _, gp in ipairs(opts.gaps or {}) do if (Vector3.new(gp[1], 0, gp[2]) - p).Magnitude < gp[3] then gap = true end end
      if g > 2 and not gap then
        L.box(m, CFrame.new(p.X, g + h / 2 - 2, p.Z) * L.yaw(yaw), Vector3.new(seg + 0.2, h + 4, t), MAT.Cobblestone, L.C.stone)
        L.box(m, CFrame.new(p.X, g + h + 1, p.Z) * L.yaw(yaw) * CFrame.new(0, 0, t / 2 - 0.75), Vector3.new(seg * 0.5, 2, 1.5), MAT.Cobblestone, L.C.stone, { cancollide = false })
        since += seg
        if since >= (opts.towerSpacing or 250) then since = 0; L.tower(m, p.X, g, p.Z, t * 1.8, h * 1.5, { roof = false }) end
      end
      s += seg
    end
  end
  return m
end
function L.gate(parent, x, z, dir, width, h)
  local g = L.heightAt(x, z)
  local side = Vector3.new(-dir.Z, 0, dir.X).Unit
  for s = -1, 1, 2 do local p = Vector3.new(x, 0, z) + side * (width / 2 + 7) * s; L.tower(parent, p.X, g, p.Z, 8, h + 14, { roof = true, name = "GateTower" }) end
  L.box(parent, CFrame.new(x, g + h - 3, z) * L.yaw(math.atan2(-side.Z, side.X)), Vector3.new(width + 14, 8, 10), MAT.Cobblestone, L.C.darkStone, { name = "GateArch" })
  workspace.Terrain:FillBlock(CFrame.new(x, g - 1.5, z) * L.yaw(math.atan2(-dir.Z, dir.X)), Vector3.new(40, 3, width), MAT.Cobblestone)
end
function L.sign(parent, x, y, z, text, yaw)
  local post = L.box(parent, CFrame.new(x, y + 4, z), Vector3.new(0.8, 8, 0.8), MAT.Wood, L.C.wood)
  local board = L.box(parent, CFrame.new(x, y + 8, z) * L.yaw(yaw or 0), Vector3.new(14, 4, 0.6), MAT.WoodPlanks, L.C.plank, { name = "Sign" })
  for _, face in ipairs({ Enum.NormalId.Front, Enum.NormalId.Back }) do
    local gui = Instance.new("SurfaceGui"); gui.Face = face; gui.Parent = board
    local lbl = Instance.new("TextLabel"); lbl.Size = UDim2.fromScale(1, 1); lbl.BackgroundTransparency = 1; lbl.Text = text; lbl.TextScaled = true; lbl.Font = Enum.Font.Antique; lbl.TextColor3 = Color3.fromRGB(40, 30, 20); lbl.Parent = gui
  end
  return board
end
function L.chimney(parent, x, y, z, r, h, smoke)
  local c = L.cyl(parent, CFrame.new(x, y + h / 2, z), r, h, MAT.Brick, L.C.brick, { name = "Chimney" })
  if smoke then
    local att = Instance.new("Attachment"); att.Position = Vector3.new(0, 0, 0); att.CFrame = CFrame.new(h / 2, 0, 0); att.Parent = c
    local pe = Instance.new("ParticleEmitter"); pe.Texture = "rbxassetid://243660364"; pe.Rate = 6; pe.Lifetime = NumberRange.new(4, 7); pe.Speed = NumberRange.new(4, 8)
    pe.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, r * 1.5), NumberSequenceKeypoint.new(1, r * 6) }); pe.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.4), NumberSequenceKeypoint.new(1, 1) })
    pe.Color = ColorSequence.new(Color3.fromRGB(200, 200, 200)); pe.Parent = att
  end
  return c
end
function L.gear(parent, cf, r, teeth, thick, color)
  local m = L.model(parent, "Gear")
  L.part(m, Enum.PartType.Cylinder, cf, Vector3.new(thick, r * 2, r * 2), MAT.Metal, color or L.C.brass, { cancollide = false })
  for i = 0, teeth - 1 do local a = i * 2 * math.pi / teeth
    L.box(m, cf * CFrame.Angles(a, 0, 0) * CFrame.new(0, r + 1, 0), Vector3.new(thick, 2.5, r * 0.35), MAT.Metal, color or L.C.brass, { cancollide = false }) end
  return m
end
function L.pipeRun(parent, pts, radius, color, postEvery)   -- pts: list of Vector3; cylinders + sphere joints + stone posts to ground
  local m = L.model(parent, "Pipe")
  for i = 1, #pts - 1 do
    L.rod(m, pts[i], pts[i + 1], radius, MAT.Metal, color or L.C.brass, { cancollide = false })
    L.ball(m, CFrame.new(pts[i]), Vector3.new(radius * 2.6, radius * 2.6, radius * 2.6), MAT.Metal, L.C.copper, { cancollide = false })
    if postEvery then
      local len = (pts[i + 1] - pts[i]).Magnitude
      for s = 0, len, postEvery do local p = pts[i] + (pts[i + 1] - pts[i]).Unit * s; local g = L.heightAt(p.X, p.Z)
        if p.Y - g > 1 then L.box(m, CFrame.new(p.X, (p.Y + g) / 2, p.Z), Vector3.new(2, p.Y - g, 2), MAT.Cobblestone, L.C.darkStone) end end
    end
  end
  return m
end
function L.tree(parent, x, y, z, kind, s)         -- 2 parts per tree; kind: "pine" | "oak" | "palm"
  s = s or 1
  if kind == "pine" then
    L.cyl(parent, CFrame.new(x, y + 6 * s, z), 1.2 * s, 12 * s, MAT.Wood, L.C.trunk, { name = "Tree" })
    L.ball(parent, CFrame.new(x, y + 22 * s, z), Vector3.new(12 * s, 30 * s, 12 * s), MAT.Grass, L.C.leafDark, { cancollide = false })
  elseif kind == "palm" then
    L.cyl(parent, CFrame.new(x, y + 9 * s, z) * CFrame.Angles(0, 0, 0.12), 0.9 * s, 18 * s, MAT.Wood, L.C.trunk, { name = "Tree" })
    L.ball(parent, CFrame.new(x, y + 19 * s, z), Vector3.new(16 * s, 5 * s, 16 * s), MAT.Grass, L.C.leafLight, { cancollide = false })
  else
    L.cyl(parent, CFrame.new(x, y + 5 * s, z), 1.5 * s, 10 * s, MAT.Wood, L.C.trunk, { name = "Tree" })
    L.ball(parent, CFrame.new(x, y + 15 * s, z), Vector3.new(18 * s, 16 * s, 18 * s), MAT.Grass, L.C.leafLight, { cancollide = false })
  end
end
function L.pier(parent, x, z, dir, len, w, y)     -- planks on posts from (x,z) outward along dir (Vector3)
  local m = L.model(parent, "Pier")
  local yaw = math.atan2(-dir.Z, dir.X)
  L.box(m, CFrame.new(x + dir.X * len / 2, y, z + dir.Z * len / 2) * L.yaw(yaw), Vector3.new(len, 1.5, w), MAT.WoodPlanks, L.C.plank)
  for s = 0, len, 20 do for side = -1, 1, 2 do
    local p = Vector3.new(x, 0, z) + dir * s + Vector3.new(-dir.Z, 0, dir.X) * (w / 2 - 1) * side
    local bottom = math.min(L.heightAt(p.X, p.Z), -2)
    L.cyl(m, CFrame.new(p.X, (y + bottom) / 2, p.Z), 1, y - bottom, MAT.Wood, L.C.wood)
  end end
  return m
end
function L.boat(parent, x, y, z, yaw, len)
  local m = L.model(parent, "Boat"); local base = CFrame.new(x, y, z) * L.yaw(yaw)
  L.box(m, base * CFrame.new(0, 2, 0), Vector3.new(len, 4, len * 0.3), MAT.WoodPlanks, L.C.wood)
  L.wedge(m, base * CFrame.new(len / 2 + len * 0.08, 2, 0) * CFrame.Angles(0, -math.pi / 2, 0), Vector3.new(len * 0.3, 4, len * 0.16), MAT.WoodPlanks, L.C.wood)
  L.rod(m, base * CFrame.new(0, 4, 0).Position, base * CFrame.new(0, 4 + len * 0.6, 0).Position, 0.5, MAT.Wood, L.C.wood)
  L.box(m, base * CFrame.new(0, 4 + len * 0.35, 0), Vector3.new(0.3, len * 0.4, len * 0.25), MAT.Fabric, L.C.sail, { cancollide = false })
  return m
end
```

- [ ] **Step 4.3: เพิ่มตัวสร้างสะพานใน `mapgen/lib.lua`**

```lua
-- ---------- bridges ----------
function L.stoneBridge(m, x, z, dir, len, w, y, waterY, arches)
  local base = CFrame.new(x, 0, z) * L.yaw(math.atan2(-dir.Z, dir.X))
  L.box(m, base * CFrame.new(0, y - 1.5, 0), Vector3.new(len, 3, w), MAT.Cobblestone, L.C.stone, { name = "Deck" })
  for s = -1, 1, 2 do L.box(m, base * CFrame.new(0, y + 1.5, s * (w / 2 - 1)), Vector3.new(len, 3, 2), MAT.Cobblestone, L.C.darkStone) end
  local span = len / arches
  for i = 1, arches - 1 do
    local px = -len / 2 + i * span; local wp = base * CFrame.new(px, 0, 0)
    local bed = L.heightAt(wp.X, wp.Z) - 4
    L.box(m, base * CFrame.new(px, (y - 3 + bed) / 2, 0), Vector3.new(8, y - 3 - bed, w + 4), MAT.Cobblestone, L.C.darkStone)
  end
end
function L.trussBridge(m, x, z, dir, len, w, y, waterY)
  local base = CFrame.new(x, 0, z) * L.yaw(math.atan2(-dir.Z, dir.X))
  L.box(m, base * CFrame.new(0, y - 1, 0), Vector3.new(len, 2, w), MAT.DiamondPlate, L.C.iron, { name = "Deck" })
  for s = -1, 1, 2 do
    local zoff = s * (w / 2 - 0.5)
    L.box(m, base * CFrame.new(0, y + 12, zoff), Vector3.new(len, 1.2, 1.2), MAT.Metal, L.C.iron, { cancollide = false })
    for px = -len / 2, len / 2, 12 do
      L.box(m, base * CFrame.new(px, y + 6, zoff), Vector3.new(1, 12, 1), MAT.Metal, L.C.iron, { cancollide = false })
      if px + 12 <= len / 2 then L.rod(m, (base * CFrame.new(px, y, zoff)).Position, (base * CFrame.new(px + 12, y + 12, zoff)).Position, 0.4, MAT.Metal, L.C.rust, { cancollide = false }) end
    end
  end
  for i = 1, 2 do local px = -len / 2 + i * len / 3; local wp = base * CFrame.new(px, 0, 0); local bed = L.heightAt(wp.X, wp.Z) - 4
    L.box(m, base * CFrame.new(px, (y - 2 + bed) / 2, 0), Vector3.new(6, y - 2 - bed, w + 2), MAT.Cobblestone, L.C.darkStone) end
end
function L.drawBridge(m, x, z, dir, len, w, y, waterY)
  local base = CFrame.new(x, 0, z) * L.yaw(math.atan2(-dir.Z, dir.X))
  for s = -1, 1, 2 do
    L.box(m, base * CFrame.new(s * len / 4, y - 1, 0), Vector3.new(len / 2 - 1, 2, w), MAT.DiamondPlate, L.C.iron, { name = "Leaf" })
    local tp = base * CFrame.new(s * (len / 2 + 6), 0, 0); local g = L.heightAt(tp.X, tp.Z)
    L.box(m, base * CFrame.new(s * (len / 2 + 6), (g + y + 40) / 2, 0), Vector3.new(12, y + 40 - g, w + 8), MAT.Brick, L.C.brick, { name = "MachineTower" })
    L.gear(m, base * CFrame.new(s * (len / 2 + 6), y + 30, (w / 2 + 5)) * CFrame.Angles(0, 0, math.pi / 2), 6, 12, 1.5, L.C.brass)
    L.rod(m, (base * CFrame.new(s * (len / 2 + 6), y + 38, 0)).Position, (base * CFrame.new(s * len / 8, y, 0)).Position, 0.5, MAT.Metal, L.C.iron, { cancollide = false })
    L.chimney(m, tp.X, y + 40, tp.Z, 2, 12, true)
  end
end
function L.woodBridge(m, x, z, dir, len, w, y, waterY, logs)
  local base = CFrame.new(x, 0, z) * L.yaw(math.atan2(-dir.Z, dir.X))
  if logs then
    for zoff = -w / 2 + 1, w / 2 - 1, 2 do L.part(m, Enum.PartType.Cylinder, base * CFrame.new(0, y - 1, zoff), Vector3.new(len, 2, 2), MAT.Wood, L.C.trunk) end
  else
    for px = -len / 2 + 1, len / 2 - 1, 2.2 do L.box(m, base * CFrame.new(px, y - 0.5, 0), Vector3.new(2, 1, w), MAT.WoodPlanks, L.C.plank) end
  end
  for px = -len / 2, len / 2, 10 do for s = -1, 1, 2 do
    local pp = base * CFrame.new(px, 0, s * (w / 2 - 0.5)); local bed = L.heightAt(pp.X, pp.Z) - 2
    L.cyl(m, CFrame.new(pp.X, (y + 3 + bed) / 2, pp.Z), 0.7, y + 3 - bed, MAT.Wood, L.C.wood)
  end end
  for s = -1, 1, 2 do L.box(m, base * CFrame.new(0, y + 3, s * (w / 2 - 0.5)), Vector3.new(len, 0.6, 0.6), MAT.Wood, L.C.wood, { cancollide = false }) end
end
function L.bridge(parent, b)
  local x, z = L.toWorld(b.pos)
  local dir = Vector3.new(b.dir[1], 0, b.dir[2]).Unit
  local len = b.length
  local a = Vector3.new(x, 0, z) - dir * len / 2; local c = Vector3.new(x, 0, z) + dir * len / 2
  local _, hs = L.riverAt(x, z)
  local deckY = math.floor(math.max(L.heightAt(a.X, a.Z), L.heightAt(c.X, c.Z), hs + 10) / 4) * 4 + 2
  local m = L.model(parent, b.name)
  if b.type == "stone_arch" then L.stoneBridge(m, x, z, dir, len, 30, deckY, hs, b.arches or 3)
  elseif b.type == "iron_truss" then L.trussBridge(m, x, z, dir, len, 14, deckY, hs)
  elseif b.type == "mechanical_draw" then L.drawBridge(m, x, z, dir, len, 24, deckY, hs)
  else L.woodBridge(m, x, z, dir, len, b.type == "wood_log" and 10 or 8, deckY, hs, b.type == "wood_log") end
  for _, e in ipairs({ a, c }) do workspace.Terrain:FillBlock(CFrame.new(e.X, deckY - 4, e.Z), Vector3.new(36, 8, 36), MAT.Cobblestone) end  -- approach pads
  return m
end
```

- [ ] **Step 4.4: เขียน `mapgen/20_roads_bridges.lua`**

```lua
-- roads painted onto terrain surface along layout polylines (stop at city wall), then 5 bridges
return L.runPhase("Roads", function(folder)
  L.requireFullScale()
  local Y, MAT, Terrain = L.LAYOUT, L.MAT, workspace.Terrain
  local wall = L.wallWorld()
  local mainSet = {}; for _, n in ipairs(Y.road_style.main_route) do mainSet[n] = true end
  for ri, road in ipairs(Y.roads) do
    local pts = L.roadWorld(road)
    local isMain = true
    for _, e in ipairs(road) do if type(e) == "string" and not mainSet[e] then isMain = false end end
    local style = isMain and Y.road_style.main or Y.road_style.other
    local mat = MAT[style.material]
    for i = 1, #pts - 1 do
      local a = Vector3.new(pts[i][1], 0, pts[i][2]); local b = Vector3.new(pts[i + 1][1], 0, pts[i + 1][2])
      local len = (b - a).Magnitude; local dir = (b - a).Unit; local yaw = math.atan2(-dir.Z, dir.X)
      local bothIn = L.pointInPoly(wall, a.X, a.Z) and L.pointInPoly(wall, b.X, b.Z)
      for s = 0, len, 4 do
        local p = a + dir * s
        local h = L.heightAt(p.X, p.Z); local d, _, w = L.riverAt(p.X, p.Z)
        if h > 1 and d > w / 2 + 6 and (bothIn or not L.pointInPoly(wall, p.X, p.Z)) then
          Terrain:FillBlock(CFrame.new(p.X, h - 1.5, p.Z) * L.yaw(yaw), Vector3.new(6, 3, style.width), mat)
        end
      end
      L.progress(("road %d/%d seg %d"):format(ri, #Y.roads, i)); task.wait()
    end
  end
  for _, b in ipairs(Y.bridges) do L.bridge(folder, b); L.progress("bridge " .. b.name); task.wait() end
end)
```

- [ ] **Step 4.5: ขออนุมัติผู้ใช้ข้อ 4 แล้วรัน**

Run: `node tools/run-luau.js mapgen/20_roads_bridges.lua --timeout 900`
Expected: `done | bridge Elderwood Log Bridge`

- [ ] **Step 4.6: ตรวจ**

Run: `node tools/run-luau.js mapgen/check_roads.lua` โดยไฟล์:

```lua
return L.runPhase("CheckRoads", function()
  local fails = {}
  local f = L.root().Roads
  L.check(fails, #f:GetChildren() == #L.LAYOUT.bridges, "5 bridge models expected")
  for _, b in ipairs(L.LAYOUT.bridges) do
    local x, z = L.toWorld(b.pos); local m = f:FindFirstChild(b.name)
    L.check(fails, m and L.countParts(m) > 5, b.name .. " has parts")
    local deck = m and m:FindFirstChild("Deck", true) or (m and m:FindFirstChildWhichIsA("BasePart"))
    local _, hs = L.riverAt(x, z)
    L.check(fails, deck and deck.Position.Y > hs, b.name .. " deck above water")
  end
  local gx, gz = L.placePos("Goldmeadow")
  L.check(fails, L.materialAtPoint(gx + 40, L.heightAt(gx + 40, gz) - 1, gz) ~= Enum.Material.Water, "road near Goldmeadow not water")
  assert(#fails == 0, table.concat(fails, "\n")); L.progress("roads checks passed")
end)
```

ภาพ: สำหรับสะพานแต่ละแห่ง `shot bridge-<name> x+150 h+80 z+150 x h z` (h = deckY) เห็นสะพานเชื่อมสองฝั่งพ้นน้ำ ถนนต่อเนื่องเข้าสะพาน ถ้าถนนขาดเพราะติดกำแพง = ถูกต้อง (ประตูสร้างใน Task 5)

- [ ] **Step 4.7: Commit**

```bash
git add mapgen/lib.lua mapgen/20_roads_bridges.lua mapgen/check_roads.lua
git commit -m "mapgen: building primitives, bridge builders, roads + 5 bridges phase"
```

---

### Task 5: เมืองหลวง Brasshaven (ขั้น 5)

**Files:**
- Create: `mapgen/30_capital.lua`
- Create: `mapgen/check_capital.lua`

**Interfaces:**
- Consumes: ทุก builder จาก Task 3-4, `L.LAYOUT.capital` (`wall.polygon`, `districts`, `house_count`, `street_width`, `spawn`, `landmarks`)
- Produces: `workspace.WOLD.Capital` มี Model ชื่อ `CityWall`, `Ironcrest Keep`, `Parliament`, `RoyalBank`, `Courthouse`, `Barracks`, `Clocktower`, `MarketHall`, `GuildHall`, `Inn`, `Statue`, `Houses`, `Harbor`, `Factory`, `Workshops`, `Station`, `AirshipDock`, `SpawnLocation`; Attribute `HouseCount` บน Folder

- [ ] **Step 5.1: เขียน `mapgen/30_capital.lua`**

```lua
-- Brasshaven: flatten districts, wall + computed gates, keep, government, market, residential grid, harbor/factory, airship dock, spawn
return L.runPhase("Capital", function(folder)
  L.requireFullScale()
  local Y, MAT, Terrain, C = L.LAYOUT, L.MAT, workspace.Terrain, L.LAYOUT.capital
  local D, K = C.districts, C.landmarks
  local rng = Random.new(5)
  local wall = L.wallWorld()
  local function W(p) return L.toWorld(p) end

  -- 1) flatten districts at their own ground height
  local Yd = {}
  for _, key in ipairs({ "keep", "government", "market" }) do
    local x, z = W(D[key].center); Yd[key] = L.padY(x, z)
    L.flattenDisc(x, z, D[key].radius * L.HALF, Yd[key], key == "market" and MAT.Cobblestone or MAT.Ground)
    L.progress("flatten " .. key); task.wait()
  end
  for _, r in ipairs(D.residential) do local x, z = W(r.center); r.y = L.padY(x, z); L.flattenDisc(x, z, r.radius * L.HALF, r.y, MAT.Ground); task.wait() end
  -- harbor: walk from market toward the bay to find the real shoreline
  local mx, mz = W(D.market.center)
  local odx, odz = L.dirTo(0, 0, mx, mz)
  local shoreX, shoreZ = L.findShore(mx, mz, odx, odz, 1500)
  local hx, hz = shoreX - odx * 160, shoreZ - odz * 160
  local harborY = 12
  L.flattenRect(hx, hz, 520, 340, harborY, MAT.Cobblestone)
  local seaDir = Vector3.new(odx, 0, odz); local alongShore = Vector3.new(-odz, 0, odx)
  L.progress("flatten harbor"); task.wait()

  -- 2) wall with gates computed from road/rail/river crossings
  local gates = {}
  local function addCrossings(path, width, isRiver)
    for _, c in ipairs(L.polyCrossings(wall, path)) do
      local dup = false
      for _, g in ipairs(gates) do if math.sqrt((g.pt[1] - c.pt[1]) ^ 2 + (g.pt[2] - c.pt[2]) ^ 2) < 60 then dup = true; g.width = math.max(g.width, 40) end end
      if not dup then gates[#gates + 1] = { pt = c.pt, dir = c.dir, width = width, river = isRiver } end
    end
  end
  for _, road in ipairs(Y.roads) do addCrossings(L.roadWorld(road), 24, false) end
  addCrossings(L.roadWorld(Y.railway), 24, false)
  do local rp = {}; for i, p in ipairs(Y.river_main) do local x, z = L.toWorld(p); rp[i] = { x, z } end; addCrossings(rp, 140, true) end
  local gaps = {}
  for _, g in ipairs(gates) do gaps[#gaps + 1] = { g.pt[1], g.pt[2], g.width / 2 + 8 } end
  L.wallPath(folder, wall, C.wall.height, C.wall.thickness, { closed = true, gaps = gaps, towerSpacing = C.wall.tower_spacing, name = "CityWall" })
  local gm = L.model(folder, "Gates")
  for _, g in ipairs(gates) do
    if g.river then
      local side = Vector3.new(-g.dir.Z, 0, g.dir.X); local _, hs = L.riverAt(g.pt[1], g.pt[2])
      L.box(gm, CFrame.new(g.pt[1], hs + 26, g.pt[2]) * L.yaw(math.atan2(-side.Z, side.X)), Vector3.new(g.width + 16, 12, C.wall.thickness), MAT.Cobblestone, L.C.darkStone, { name = "RiverArch" })
      for s = -1, 1, 2 do local p = Vector3.new(g.pt[1], 0, g.pt[2]) + side * (g.width / 2 + 6) * s; L.tower(gm, p.X, L.heightAt(p.X, p.Z), p.Z, 10, 44, { roof = false, name = "RiverTower" }) end
    else L.gate(gm, g.pt[1], g.pt[2], g.dir, g.width, C.wall.height) end
  end
  folder:SetAttribute("GateCount", #gates)
  L.progress(("wall + %d gates"):format(#gates)); task.wait()

  -- 3) Ironcrest Keep
  do
    local x, z = W(D.keep.center); local y = Yd.keep
    local m = L.model(folder, "Ironcrest Keep"); local s = K.keep_wall_size
    local gx, gz = W(D.government.center); local fdx, fdz = gx - x, gz - z
    local faceSide = math.abs(fdx) > math.abs(fdz) and (fdx > 0 and 2 or 4) or (fdz > 0 and 3 or 1)   -- 1 north(-z) 2 east 3 south 4 west
    local sides = { { CFrame.new(x, 0, z - s / 2), 0 }, { CFrame.new(x + s / 2, 0, z), math.pi / 2 }, { CFrame.new(x, 0, z + s / 2), 0 }, { CFrame.new(x - s / 2, 0, z), math.pi / 2 } }
    for i, sd in ipairs(sides) do
      local cf = sd[1] * L.yaw(sd[2])
      if i == faceSide then
        for h = -1, 1, 2 do L.box(m, cf * CFrame.new(h * (s / 4 + 6), y + 20, 0), Vector3.new(s / 2 - 12, 40, 8), MAT.Cobblestone, L.C.stone) end
        L.gate(m, cf.Position.X, cf.Position.Z, Vector3.new(fdx, 0, fdz).Unit, 24, 34)
      else L.box(m, cf * CFrame.new(0, y + 20, 0), Vector3.new(s, 40, 8), MAT.Cobblestone, L.C.stone) end
    end
    for _, c in ipairs({ { -1, -1 }, { 1, -1 }, { 1, 1 }, { -1, 1 } }) do L.tower(m, x + c[1] * s / 2, y, z + c[2] * s / 2, 14, K.keep_corner_tower_height, { roof = true, roofColor = L.C.roofBlue }) end
    L.box(m, CFrame.new(x, y + 55, z), Vector3.new(120, 110, 120), MAT.Cobblestone, L.C.darkStone, { name = "MainKeep" })
    for i = 0, 5 do for s2 = -1, 1, 2 do L.box(m, CFrame.new(x + s2 * 60.3, y + 25 + i * 14, z - 40 + (i % 3) * 40), Vector3.new(0.6, 6, 3), MAT.Glass, L.C.glass, { cancollide = false }) end end
    L.box(m, CFrame.new(x, y + 6, z + 60.4), Vector3.new(10, 12, 0.8), MAT.Wood, L.C.wood, { cancollide = false, name = "HallDoor" })
    L.tower(m, x, y, z, 20, K.keep_main_tower_height, { roof = true, roofColor = L.C.roofBlue, name = "GreatTower" })
    L.box(m, CFrame.new(x, y + K.keep_main_tower_height + 16, z), Vector3.new(0.5, 12, 8), MAT.Fabric, L.C.roofRed, { cancollide = false, name = "Banner" })
    L.progress("keep"); task.wait()
  end

  -- 4) Crown Plaza (government)
  do
    local x, z = W(D.government.center); local y = Yd.government
    Terrain:FillBlock(CFrame.new(x, y - 1.5, z), Vector3.new(220, 3, 220), MAT.Cobblestone)
    local m = L.model(folder, "Parliament")           -- north side
    local px, pz = x, z - 160
    L.box(m, CFrame.new(px, y + 30, pz), Vector3.new(160, 60, 100), MAT.Limestone, L.C.stone)
    L.ball(m, CFrame.new(px, y + 60, pz), Vector3.new(80, 80, 80), MAT.Metal, L.C.brass, { name = "Dome" })
    for i = -3, 3 do L.cyl(m, CFrame.new(px + i * 20, y + 15, pz + 56), 3, 30, MAT.Marble, L.C.plaster) end
    L.box(m, CFrame.new(px, y + 32, pz + 56), Vector3.new(160, 4, 12), MAT.Limestone, L.C.stone)
    L.box(m, CFrame.new(px, y + 8, pz + 50.5), Vector3.new(14, 16, 1), MAT.Wood, L.C.wood, { cancollide = false, name = "Door" })
    for s = -1, 1, 2 do L.gear(m, CFrame.new(px + s * 60, y + 45, pz + 51) * CFrame.Angles(0, math.pi / 2, 0), 8, 14, 1.5, L.C.brass) end
    L.pipeRun(m, { Vector3.new(px - 80, y + 20, pz + 51), Vector3.new(px - 80, y + 55, pz + 51), Vector3.new(px + 80, y + 55, pz + 51), Vector3.new(px + 80, y + 20, pz + 51) }, 1.5, L.C.copper)
    L.sign(m, px, y, pz + 70, "Parliament of Arture", 0)
    local b = L.model(folder, "RoyalBank")              -- west
    local bx, bz = x - 150, z
    L.box(b, CFrame.new(bx, y + 20, bz), Vector3.new(70, 40, 100), MAT.Limestone, L.C.plaster)
    for i = -2, 2 do L.cyl(b, CFrame.new(bx + 38, y + 14, bz + i * 20), 2.5, 28, MAT.Marble, L.C.plaster) end
    L.box(b, CFrame.new(bx + 38, y + 30, bz), Vector3.new(14, 4, 100), MAT.Limestone, L.C.stone)
    L.box(b, CFrame.new(bx + 45, y + 1, bz), Vector3.new(14, 2, 40), MAT.Marble, L.C.stone)
    L.box(b, CFrame.new(bx + 35.5, y + 7, bz), Vector3.new(1, 14, 12), MAT.Metal, L.C.brass, { cancollide = false, name = "Door" })
    L.box(b, CFrame.new(bx - 20, y + 8, bz), Vector3.new(24, 16, 24), MAT.Metal, L.C.iron, { name = "Vault" })
    L.sign(b, bx + 55, y, bz + 30, "Royal Bank", math.pi / 2)
    local c = L.model(folder, "Courthouse")             -- east
    local cx, cz = x + 150, z
    L.box(c, CFrame.new(cx, y + 15, cz), Vector3.new(60, 30, 80), MAT.Cobblestone, L.C.stone)
    L.wedge(c, CFrame.new(cx, y + 34, cz + 20), Vector3.new(64, 8, 42), MAT.Slate, L.C.roofGreen)
    L.wedge(c, CFrame.new(cx, y + 34, cz - 20) * CFrame.Angles(0, math.pi, 0), Vector3.new(64, 8, 42), MAT.Slate, L.C.roofGreen)
    L.box(c, CFrame.new(cx - 30.5, y + 6, cz), Vector3.new(1, 12, 10), MAT.Wood, L.C.wood, { cancollide = false, name = "Door" })
    local jx, jz = cx + 60, cz
    L.box(c, CFrame.new(jx, y + 10, jz), Vector3.new(60, 20, 40), MAT.Cobblestone, L.C.darkStone, { name = "JailWing" })
    for i = 0, 5 do for k = 0, 4 do L.cyl(c, CFrame.new(jx - 25 + i * 10, y + 15, jz + 20.6 + 0) * CFrame.Angles(0, 0, 0), 0.25, 6, MAT.Metal, L.C.iron, { cancollide = false }) end end
    L.sign(c, cx - 45, y, cz + 30, "Court & Gaol", -math.pi / 2)
    local br = L.model(folder, "Barracks")              -- south
    L.box(br, CFrame.new(x, y + 10, z + 150), Vector3.new(80, 20, 40), MAT.Cobblestone, L.C.stone)
    L.wedge(br, CFrame.new(x, y + 24, z + 160), Vector3.new(84, 8, 22), MAT.Slate, L.C.roofRed)
    L.wedge(br, CFrame.new(x, y + 24, z + 140) * CFrame.Angles(0, math.pi, 0), Vector3.new(84, 8, 22), MAT.Slate, L.C.roofRed)
    L.progress("government"); task.wait()
  end

  -- 5) Market district
  do
    local x, z = W(D.market.center); local y = Yd.market
    local t = L.model(folder, "Clocktower"); local th = K.clocktower_height
    L.box(t, CFrame.new(x, y + th / 2, z), Vector3.new(40, th, 40), MAT.Cobblestone, L.C.stone)
    for i = 0, 3 do
      local cf = CFrame.new(x, y + th - 30, z) * L.yaw(i * math.pi / 2) * CFrame.new(0, 0, 20.5)
      L.part(t, Enum.PartType.Cylinder, cf * CFrame.Angles(0, math.pi / 2, 0), Vector3.new(1, 24, 24), MAT.Metal, L.C.brass, { cancollide = false, name = "ClockFace" })
      L.box(t, cf * CFrame.new(0, 4, 0.7), Vector3.new(1.2, 9, 0.4), MAT.Metal, L.C.iron, { cancollide = false })
      L.box(t, cf * CFrame.new(3, 0, 0.7) * CFrame.Angles(0, 0, math.pi / 2), Vector3.new(1.2, 7, 0.4), MAT.Metal, L.C.iron, { cancollide = false })
    end
    for s = -1, 1, 2 do L.gear(t, CFrame.new(x + s * 21, y + th - 70, z) * CFrame.Angles(0, 0, math.pi / 2), 9, 16, 1.5, L.C.brass) end
    for i = 1, 4 do L.wedge(t, CFrame.new(x, y + th + 6, z) * L.yaw(i * math.pi / 2) * CFrame.new(0, 0, 10), Vector3.new(42, 12, 21), MAT.Metal, L.C.copper) end
    L.crystal(t, Vector3.new(x, y + th + 18, z), 3, L.C.brass)
    local mh = L.model(folder, "MarketHall"); local hx2, hz2 = x + 200, z
    for i = -2, 2 do for k = -1, 1, 2 do L.cyl(mh, CFrame.new(hx2 + i * 28, y + 8, hz2 + k * 28), 1.5, 16, MAT.Wood, L.C.wood) end end
    L.wedge(mh, CFrame.new(hx2, y + 20, hz2 + 16), Vector3.new(124, 8, 32), MAT.Slate, L.C.roofRed)
    L.wedge(mh, CFrame.new(hx2, y + 20, hz2 - 16) * CFrame.Angles(0, math.pi, 0), Vector3.new(124, 8, 32), MAT.Slate, L.C.roofRed)
    for i = 0, 23 do local a = i * 2 * math.pi / 24; local sx, sz = hx2 + math.cos(a) * 110, hz2 + math.sin(a) * 110
      L.box(mh, CFrame.new(sx, y + 2, sz) * L.yaw(-a), Vector3.new(10, 4, 5), MAT.WoodPlanks, L.C.plank, { name = "Stall" })
      L.box(mh, CFrame.new(sx, y + 9, sz) * L.yaw(-a) * CFrame.Angles(0, 0, 0.15), Vector3.new(12, 0.5, 8), MAT.Fabric, (i % 2 == 0) and L.C.roofRed or L.C.sail, { cancollide = false })
    end
    L.sign(mh, hx2, y, hz2 + 60, "Grand Market", 0)
    local g = L.house(folder, x - 200, y, z, 70, 50, 3, { name = "GuildHall", roof = L.C.roofGreen, yaw = math.pi / 2 })
    L.gear(g, CFrame.new(x - 200, y + 34, z + 26) * CFrame.Angles(0, math.pi / 2, 0), 6, 12, 1.2, L.C.brass)
    L.sign(g, x - 160, y, z + 20, "Guild Hall  |  Jobs", math.pi / 2)
    local inn = L.house(folder, x, y, z + 200, 60, 44, 2, { name = "Inn", yaw = math.pi })
    L.sign(inn, x + 40, y, z + 170, "The Brass Kettle Inn", 0)
    local st = L.model(folder, "Statue")
    L.box(st, CFrame.new(x + 90, y + 3, z + 90), Vector3.new(14, 6, 14), MAT.Marble, L.C.stone)
    L.box(st, CFrame.new(x + 90, y + 14, z + 90), Vector3.new(5, 16, 4), MAT.Metal, L.C.copper, { name = "StatuePlaceholder" })
    L.ball(st, CFrame.new(x + 90, y + 24, z + 90), Vector3.new(4, 4, 4), MAT.Metal, L.C.copper)
    local lamps = L.model(folder, "Lamps")
    for i = 0, 15 do local a = i * 2 * math.pi / 16; local lx, lz = x + math.cos(a) * 140, z + math.sin(a) * 140
      L.cyl(lamps, CFrame.new(lx, y + 6, lz), 0.5, 12, MAT.Metal, L.C.brass)
      local bulb = L.ball(lamps, CFrame.new(lx, y + 13, lz), Vector3.new(2.5, 2.5, 2.5), MAT.Neon, Color3.fromRGB(255, 220, 150), { cancollide = false })
      local pl = Instance.new("PointLight"); pl.Range = 30; pl.Color = Color3.fromRGB(255, 220, 150); pl.Parent = bulb
    end
    L.progress("market"); task.wait()
  end

  -- 6) Residential grid: blocks of 4 houses, cobblestone streets, stop at house_count
  do
    local hm = L.model(folder, "Houses"); local count = 0
    local block, street = 120, C.street_width
    local avoid = { { W(D.keep.center) }, { W(D.government.center) }, { W(D.market.center) } }
    local roofs = { L.C.roofRed, L.C.roofBlue, L.C.roofGreen, L.C.copper }
    for _, r in ipairs(D.residential) do
      local cx, cz = W(r.center); local R = r.radius * L.HALF; local y = r.y
      for bx = cx - R, cx + R, block + street do for bz = cz - R, cz + R, block + street do
        if count >= C.house_count then break end
        local ok = (bx - cx) ^ 2 + (bz - cz) ^ 2 < (R - 80) ^ 2
        for _, a in ipairs(avoid) do if (bx - a[1]) ^ 2 + (bz - a[2]) ^ 2 < 480 ^ 2 then ok = false end end
        local rd, _, rw = L.riverAt(bx, bz); if rd < rw / 2 + 100 then ok = false end
        if ok then
          for sx = -1, 1, 2 do for sz = -1, 1, 2 do
            local hx3, hz3 = bx + sx * 32, bz + sz * 32
            L.house(hm, hx3, y, hz3, rng:NextInteger(26, 34), rng:NextInteger(22, 30), rng:NextInteger(2, 3), { yaw = math.atan2(sx, sz), roof = roofs[rng:NextInteger(1, 4)] })
            count += 1
          end end
          Terrain:FillBlock(CFrame.new(bx, y - 1.5, bz + block / 2 + street / 2), Vector3.new(block + street, 3, street), MAT.Cobblestone)
          Terrain:FillBlock(CFrame.new(bx + block / 2 + street / 2, y - 1.5, bz), Vector3.new(street, 3, block + street), MAT.Cobblestone)
          if count % 24 == 0 then L.progress(("houses %d"):format(count)); task.wait() end
        end
      end end
    end
    folder:SetAttribute("HouseCount", count)
    L.progress(("houses %d"):format(count)); task.wait()
  end

  -- 7) Harbor, factory, workshops, station, airship dock, spawn
  do
    local hm = L.model(folder, "Harbor")
    for i = -1.5, 1.5 do
      local px = Vector3.new(shoreX, 0, shoreZ) + alongShore * (i * 110)
      local sx, sz = L.findShore(px.X - odx * 60, px.Z - odz * 60, odx, odz, 400)
      L.pier(hm, sx, sz, seaDir, K.pier_length, 24, harborY)
      local bp = Vector3.new(sx, 0, sz) + seaDir * (K.pier_length - 30) + alongShore * 22
      L.boat(hm, bp.X, 1, bp.Z, math.atan2(-seaDir.Z, seaDir.X), rng:NextInteger(40, 70))
    end
    for i = -2.5, 2.5 do local p = Vector3.new(hx, 0, hz) - seaDir * 120 + alongShore * (i * 70)
      L.box(hm, CFrame.new(p.X, harborY + 15, p.Z) * L.yaw(math.atan2(-alongShore.Z, alongShore.X)), Vector3.new(60, 30, 40), MAT.WoodPlanks, L.C.plank, { name = "Warehouse" }) end
    do local p = Vector3.new(hx, 0, hz) + alongShore * 230
      for i = -1, 1, 2 do for k = -1, 1, 2 do L.cyl(hm, CFrame.new(p.X + i * 20, harborY + 6, p.Z + k * 12), 1.2, 12, MAT.Wood, L.C.wood) end end
      L.box(hm, CFrame.new(p.X, harborY + 12.5, p.Z), Vector3.new(50, 1, 32), MAT.Fabric, L.C.sail, { cancollide = false, name = "FishMarket" }) end
    local f = L.model(folder, "Factory")
    local fp = Vector3.new(hx, 0, hz) - alongShore * 330 - seaDir * 40
    local fyaw = math.atan2(-alongShore.Z, alongShore.X)
    L.flattenRect(fp.X, fp.Z, 260, 200, harborY, MAT.Ground)
    L.box(f, CFrame.new(fp.X, harborY + 20, fp.Z) * L.yaw(fyaw), Vector3.new(K.factory_size[1], 40, K.factory_size[2]), MAT.Brick, L.C.brick, { name = "FactoryHall" })
    for i = 1, K.factory_chimneys do local cp = CFrame.new(fp.X, 0, fp.Z) * L.yaw(fyaw) * CFrame.new(-70 + (i - 1) * 70, 0, -40); L.chimney(f, cp.X, harborY + 40, cp.Z, 6, 80, true) end
    for s = -1, 1, 2 do local gp = CFrame.new(fp.X, 0, fp.Z) * L.yaw(fyaw) * CFrame.new(s * 60, 0, K.factory_size[2] / 2 + 1); L.gear(f, CFrame.new(gp.X, harborY + 30, gp.Z) * L.yaw(fyaw) * CFrame.Angles(0, math.pi / 2, 0), 18, 20, 2, L.C.brass) end
    do local o = CFrame.new(fp.X, 0, fp.Z) * L.yaw(fyaw)
      L.pipeRun(f, { (o * CFrame.new(-100, harborY + 10, 62)).Position, (o * CFrame.new(-100, harborY + 34, 62)).Position, (o * CFrame.new(100, harborY + 34, 62)).Position, (o * CFrame.new(100, harborY + 10, 62)).Position }, 2, L.C.brass)
      for i = -1, 1 do L.cyl(f, o * CFrame.new(i * 30, harborY + 14, -75), 9, 28, MAT.Metal, L.C.copper, { name = "Boiler" }) end end
    local ws = L.model(folder, "Workshops")
    for i = 0, 3 do local wp = CFrame.new(fp.X, 0, fp.Z) * L.yaw(fyaw) * CFrame.new(-90 + i * 60, 0, 130)
      L.box(ws, CFrame.new(wp.X, harborY + 12, wp.Z) * L.yaw(fyaw), Vector3.new(50, 24, 36), MAT.Brick, L.C.brick, { name = "Workshop" })
      L.chimney(ws, wp.X + 15, harborY + 24, wp.Z, 2, 16, true) end
    L.sign(ws, fp.X, harborY, fp.Z + 110, "Brasshaven Ironworks", fyaw)
    -- station: 240 studs inside the rail gate along the rail direction
    do
      local railPts = L.roadWorld(Y.railway); local cross = L.polyCrossings(wall, railPts)
      if #cross > 0 then
        local c = cross[#cross]; local sp = Vector3.new(c.pt[1], 0, c.pt[2]) + c.dir * 240
        local sy = L.padY(sp.X, sp.Z); L.flattenRect(sp.X, sp.Z, 160, 80, sy, MAT.Ground)
        local st = L.model(folder, "Station"); local syaw = math.atan2(-c.dir.Z, c.dir.X)
        L.box(st, CFrame.new(sp.X, sy + 1, sp.Z) * L.yaw(syaw) * CFrame.new(0, 0, 14), Vector3.new(120, 2, 16), MAT.Cobblestone, L.C.stone, { name = "Platform" })
        for i = -2, 2 do L.cyl(st, CFrame.new(sp.X, sy + 8, sp.Z) * L.yaw(syaw) * CFrame.new(i * 25, 0, 14), 1, 14, MAT.Metal, L.C.iron) end
        L.box(st, CFrame.new(sp.X, sy + 15.5, sp.Z) * L.yaw(syaw) * CFrame.new(0, 0, 14), Vector3.new(124, 1, 22), MAT.Metal, L.C.copper, { cancollide = false })
        L.house(st, (CFrame.new(sp.X, 0, sp.Z) * L.yaw(syaw) * CFrame.new(0, 0, 34)).X, sy, (CFrame.new(sp.X, 0, sp.Z) * L.yaw(syaw) * CFrame.new(0, 0, 34)).Z, 40, 20, 1, { yaw = syaw + math.pi, name = "StationHouse", roof = L.C.roofBlue })
        local wt = CFrame.new(sp.X, 0, sp.Z) * L.yaw(syaw) * CFrame.new(70, 0, 30)
        for i = 0, 3 do L.box(st, CFrame.new(wt.X + (i % 2 == 0 and -4 or 4), sy + 10, wt.Z + (i < 2 and -4 or 4)), Vector3.new(1.5, 20, 1.5), MAT.Wood, L.C.wood) end
        L.cyl(st, CFrame.new(wt.X, sy + 26, wt.Z), 7, 12, MAT.Wood, L.C.plank, { name = "WaterTower" })
        folder:SetAttribute("StationPos", sp)
      end
    end
    -- airship dock on the harbor headland
    do
      local ax, az = W(D.airship_dock.pos)
      if not L.isLand(ax, az) then ax, az = L.findShore(mx, mz, L.dirTo(mx, mz, ax, az), 1500) end
      local ay = L.padY(ax, az); L.flattenDisc(ax, az, 60, ay, MAT.Cobblestone)
      local ad = L.model(folder, "AirshipDock"); local th = D.airship_dock.tower_height
      L.cyl(ad, CFrame.new(ax, ay + th / 2, az), 16, th, MAT.Brick, L.C.brick, { name = "DockTower" })
      for i = 0, 11 do L.box(ad, CFrame.new(ax, ay + 10 + i * (th - 20) / 11, az) * L.yaw(i * math.pi / 6) * CFrame.new(18, 0, 0), Vector3.new(10, 1, 6), MAT.Metal, L.C.iron) end
      for s = -1, 1, 2 do L.box(ad, CFrame.new(ax + s * 40, ay + th - 10, az), Vector3.new(80, 6, 6), MAT.Metal, L.C.iron, { name = "MooringArm" }) end
      local ap = Vector3.new(ax, ay + th + 20, az + 60)
      L.ball(ad, CFrame.new(ap), Vector3.new(K.airship_length, 50, 50), MAT.Fabric, L.C.copper, { name = "AirshipPlaceholder" })
      L.box(ad, CFrame.new(ap - Vector3.new(0, 34, 0)), Vector3.new(60, 14, 16), MAT.WoodPlanks, L.C.plank, { name = "Gondola" })
      for s = -1, 1, 2 do L.gear(ad, CFrame.new(ap + Vector3.new(-K.airship_length / 2 - 4, -30, s * 14)) * CFrame.Angles(0, 0, 0), 6, 4, 1, L.C.brass) end
      L.rod(ad, ap - Vector3.new(K.airship_length / 2, 0, 0), Vector3.new(ax + 40, ay + th - 10, az), 0.6, MAT.Metal, L.C.iron, { cancollide = false })
    end
    -- spawn
    local sp = Instance.new("SpawnLocation"); sp.Size = Vector3.new(24, 1, 24); sp.Position = Vector3.new(hx, harborY + 0.5, hz); sp.Anchored = true
    sp.Material = MAT.Cobblestone; sp.Color = L.C.stone; sp.Neutral = true; sp.Duration = 0; sp.Name = "SpawnLocation"; sp.Parent = folder
    local old = workspace:FindFirstChild("SpawnLocation"); if old then old:Destroy() end
    L.progress("harbor + spawn")
  end
end)
```

- [ ] **Step 5.2: เขียน `mapgen/check_capital.lua`**

```lua
return L.runPhase("CheckCapital", function()
  local fails = {}; local f = L.root():FindFirstChild("Capital")
  L.check(fails, f ~= nil, "Capital folder")
  for _, n in ipairs({ "CityWall", "Gates", "Ironcrest Keep", "Parliament", "RoyalBank", "Courthouse", "Clocktower", "MarketHall", "GuildHall", "Inn", "Houses", "Harbor", "Factory", "Workshops", "Station", "AirshipDock", "SpawnLocation" }) do
    L.check(fails, f and f:FindFirstChild(n) ~= nil, "missing " .. n)
  end
  L.check(fails, (f:GetAttribute("HouseCount") or 0) >= L.LAYOUT.capital.house_count * 0.8, ("houses %s < 80%% of target"):format(tostring(f:GetAttribute("HouseCount"))))
  L.check(fails, (f:GetAttribute("GateCount") or 0) >= 3, "at least 3 gates")
  local sp = f:FindFirstChild("SpawnLocation")
  L.check(fails, sp and L.materialAtPoint(sp.Position.X, sp.Position.Y - 3, sp.Position.Z) ~= Enum.Material.Water, "spawn stands on ground")
  local low = 0; for _, d in ipairs(f:GetDescendants()) do if d:IsA("BasePart") and d.Position.Y < -100 then low += 1 end end
  L.check(fails, low == 0, ("%d parts below Y=-100"):format(low))
  L.check(fails, L.countParts(L.root()) < L.LAYOUT.generator.part_budget, "part budget")
  assert(#fails == 0, table.concat(fails, "\n")); L.progress(("capital checks passed, parts=%d"):format(L.countParts(f)))
end)
```

- [ ] **Step 5.3: ขออนุมัติผู้ใช้ข้อ 5 แล้วรัน**

Run: `node tools/run-luau.js mapgen/30_capital.lua --timeout 1200` แล้ว `node tools/run-luau.js mapgen/check_capital.lua`
Expected: `done | harbor + spawn` และ `capital checks passed, parts=N`

- [ ] **Step 5.4: ภาพตรวจ**

Run: `shot city-bay 4800 400 4800 2400 100 3000`, `shot city-keep 2400 600 2900 1760 250 2080`, `shot city-spawn <hx+60> <harborY+30> <hz+60> <hx> <harborY> <hz>` (อ่าน hx,hz จาก `SpawnLocation.Position` ด้วย `inspect_instance`), `shot city-top 2200 2500 2700 2200 0 2700`
Expected: จากจุดเกิดเห็นเรือเหาะ หอนาฬิกา และปราสาทบนเนิน กำแพงปิดครบ ประตูตรงถนน บ้านไม่ทับกัน ถ้าบ้านทับแม่น้ำ/ลอย → เพิ่มระยะ `rd < rw/2 + 100` หรือปรับ `avoid`

- [ ] **Step 5.5: Commit**

```bash
cp docs/shots/city-bay.png docs/design/shot-brasshaven-v1.png
git add mapgen/30_capital.lua mapgen/check_capital.lua docs/design/shot-brasshaven-v1.png
git commit -m "mapgen: Brasshaven capital phase (wall+gates, keep, government, market, 250 houses, harbor, factory, airship dock, spawn)"
```

---

### Task 6: หมู่บ้าน 6 แห่ง (ขั้น 6)

**Files:**
- Create: `mapgen/40_villages.lua`

**Interfaces:**
- Consumes: builders จาก Task 3-4, `L.LAYOUT.places[*].kind`, `L.LAYOUT.villages`, `Goldmeadow.fields_center/fields_radius`, `L.LAYOUT.caves["Stonemark Mine"]`
- Produces: `workspace.WOLD.Villages.<ชื่อหมู่บ้าน>` Model ต่อหมู่บ้าน พร้อม Attribute `Houses`

- [ ] **Step 6.1: เขียน `mapgen/40_villages.lua`**

```lua
-- 6 villages: flat pad, ring of houses, dirt ring road, sign, kind-specific landmarks
return L.runPhase("Villages", function(folder)
  L.requireFullScale()
  local Y, MAT, Terrain = L.LAYOUT, L.MAT, workspace.Terrain
  local function ringRoad(x, z, y, r) for i = 0, 71 do local a = i * math.pi / 36; Terrain:FillBlock(CFrame.new(x + math.cos(a) * r, y - 1.5, z + math.sin(a) * r) * L.yaw(-a + math.pi / 2), Vector3.new(16, 3, 14), MAT.Ground) end end
  local function windmill(m, x, y, z)
    L.cyl(m, CFrame.new(x, y + 18, z), 7, 36, MAT.Cobblestone, L.C.stone); L.cyl(m, CFrame.new(x, y + 38, z), 8, 4, MAT.Slate, L.C.roofRed)
    for i = 0, 3 do L.box(m, CFrame.new(x, y + 30, z + 8) * CFrame.Angles(0, 0, i * math.pi / 2) * CFrame.new(0, 14, 0), Vector3.new(3, 26, 0.5), MAT.Fabric, L.C.sail, { cancollide = false }) end
  end
  local function boilerHouse(m, x, y, z, yaw)
    L.box(m, CFrame.new(x, y + 10, z) * L.yaw(yaw), Vector3.new(40, 20, 30), MAT.Brick, L.C.brick); L.chimney(m, x + 12, y + 20, z, 2.5, 24, true)
    L.cyl(m, CFrame.new(x - 26, y + 8, z), 6, 16, MAT.Metal, L.C.copper); L.gear(m, CFrame.new(x, y + 14, z + 15.6) * L.yaw(yaw) * CFrame.Angles(0, math.pi / 2, 0), 5, 10, 1, L.C.brass)
  end
  local KIND = {}
  function KIND.farm(m, x, y, z, rng, p)
    local fx, fz = L.toWorld(p.fields_center); local R = p.fields_radius * L.HALF
    local fields = L.model(m, "Fields"); local n = 0
    for gx = fx - R, fx + R, 14 do for gz = fz - R, fz + R, 110 do
      if (gx - fx) ^ 2 + (gz - fz) ^ 2 < R * R and (gx - x) ^ 2 + (gz - z) ^ 2 > 260 ^ 2 then
        local rd, _, rw = L.riverAt(gx, gz); local h = L.heightAt(gx, gz)
        if rd > rw / 2 + 20 and h > 4 and h < 90 then
          L.box(fields, CFrame.new(gx, h + 1, gz), Vector3.new(8, 2, 100), MAT.Grass, (n % 3 == 0) and Color3.fromRGB(190, 160, 60) or L.C.leafLight, { cancollide = false, name = "CropRow" }); n += 1
          if n % 200 == 0 then task.wait() end
        end
      end
    end end
    windmill(m, x + 120, y, z - 60); windmill(m, x - 140, y, z + 90)
    L.box(m, CFrame.new(x + 60, y + 12, z + 100), Vector3.new(50, 24, 34), MAT.WoodPlanks, L.C.roofRed, { name = "Barn" })
    L.wedge(m, CFrame.new(x + 60, y + 28, z + 108.5), Vector3.new(54, 8, 17), MAT.Slate, L.C.wood); L.wedge(m, CFrame.new(x + 60, y + 28, z + 91.5) * CFrame.Angles(0, math.pi, 0), Vector3.new(54, 8, 17), MAT.Slate, L.C.wood)
    L.cyl(m, CFrame.new(x - 70, y + 16, z - 90), 9, 32, MAT.WoodPlanks, L.C.plank, { name = "Granary" }); L.cyl(m, CFrame.new(x - 70, y + 35, z - 90), 10, 6, MAT.Slate, L.C.roofRed)
    L.box(m, CFrame.new(x + 130, y + 5, z + 30), Vector3.new(16, 10, 12), MAT.Metal, L.C.iron, { name = "SteamPump" }); L.chimney(m, x + 136, y + 10, z + 30, 1.5, 12, true)
    L.pipeRun(m, { Vector3.new(x + 130, y + 6, z + 24), Vector3.new(x + 130, y + 6, z - 40), Vector3.new(x + 200, y + 6, z - 40) }, 1.2, L.C.brass, 40)
  end
  function KIND.mine(m, x, y, z, rng, p)
    local cx, cz = L.toWorld(Y.caves["Stonemark Mine"]); local cy = L.heightAt(cx, cz)
    local dx, dz = L.dirTo(cx, cz, x, z); local yaw = math.atan2(-dz, dx)
    for s = -1, 1, 2 do L.box(m, CFrame.new(cx, cy + 9, cz) * L.yaw(yaw) * CFrame.new(0, 0, s * 11), Vector3.new(4, 18, 3), MAT.Wood, L.C.wood) end
    L.box(m, CFrame.new(cx, cy + 19, cz) * L.yaw(yaw), Vector3.new(4, 3, 26), MAT.Wood, L.C.wood, { name = "MinePortal" })
    for s = -1, 1, 2 do L.rod(m, Vector3.new(cx, cy + 0.3, cz) + Vector3.new(-dz, 0, dx) * s * 1.5, Vector3.new(x, y + 0.3, z) + Vector3.new(-dz, 0, dx) * s * 1.5, 0.3, MAT.Metal, L.C.iron, { cancollide = false }) end
    for i = 1, 3 do local t = i / 4; local px, pz = cx + (x - cx) * t, cz + (z - cz) * t; local py = L.heightAt(px, pz)
      L.box(m, CFrame.new(px, py + 3, pz) * L.yaw(yaw), Vector3.new(8, 4, 5), MAT.Metal, L.C.rust, { name = "OreCart" }); L.ball(m, CFrame.new(px, py + 6, pz), Vector3.new(6, 3, 4), MAT.Rock, L.C.darkStone, { cancollide = false }) end
    L.box(m, CFrame.new(x + 90, y + 12, z + 60), Vector3.new(50, 24, 40), MAT.Brick, L.C.brick, { name = "Smelter" }); L.chimney(m, x + 100, y + 24, z + 60, 4, 40, true)
    for i = 1, 5 do L.ball(m, CFrame.new(x + rng:NextNumber(-60, 60), y + 4, z + rng:NextNumber(120, 170)), Vector3.new(14, 8, 14), MAT.Slate, L.C.darkStone, { name = "OrePile" }) end
  end
  function KIND.lumber(m, x, y, z, rng, p)
    local mx, mz = x + 320, z - 160                                   -- sawmill toward the tributary (river at ~(-0.46, 0))
    local rd, rh, rw = L.riverAt(mx, mz)
    local bankY = L.heightAt(mx, mz)
    L.box(m, CFrame.new(mx, bankY + 8, mz), Vector3.new(40, 16, 30), MAT.WoodPlanks, L.C.plank, { name = "Sawmill" })
    L.wedge(m, CFrame.new(mx, bankY + 20, mz + 8), Vector3.new(44, 8, 16), MAT.Slate, L.C.wood); L.wedge(m, CFrame.new(mx, bankY + 20, mz - 8) * CFrame.Angles(0, math.pi, 0), Vector3.new(44, 8, 16), MAT.Slate, L.C.wood)
    L.part(m, Enum.PartType.Cylinder, CFrame.new(mx + 24, rh + 6, mz), Vector3.new(3, 22, 22), MAT.Wood, L.C.wood, { name = "WaterWheel" })
    for i = 0, 7 do L.box(m, CFrame.new(mx + 24, rh + 6, mz) * CFrame.Angles(i * math.pi / 4, 0, 0) * CFrame.new(0, 11, 0), Vector3.new(3.5, 3, 1), MAT.WoodPlanks, L.C.plank, { cancollide = false }) end
    for i = 1, 12 do L.part(m, Enum.PartType.Cylinder, CFrame.new(x + 80 + (i % 4) * 3, y + 1.5 + math.floor(i / 4) * 2.6, z + 90) , Vector3.new(24, 3, 3), MAT.Wood, L.C.trunk) end
    L.house(m, x - 90, y, z - 90, 40, 30, 1, { name = "HunterLodge", stone = true, roof = L.C.roofGreen, yaw = math.pi / 4 })
    for i = 1, 3 do L.part(m, Enum.PartType.Cylinder, CFrame.new(x + 130, y + 5, z - 60 - i * 12) * CFrame.Angles(0, math.pi / 2, 0), Vector3.new(1, 8, 8), MAT.WoodPlanks, L.C.sail, { name = "Target" }) end
  end
  function KIND.fishing(m, x, y, z, rng, p)
    local dx, dz = L.dirTo(0, 0, x, z); local sx, sz = L.findShore(x, z, dx, dz, 2000); local seaDir = Vector3.new(dx, 0, dz)
    local along = Vector3.new(-dz, 0, dx)
    for i = -1, 1 do local o = Vector3.new(sx, 0, sz) + along * (i * 60); local ox, oz = L.findShore(o.X - dx * 40, o.Z - dz * 40, dx, dz, 300)
      L.pier(m, ox, oz, seaDir, 90, 10, 5) end
    for i = 1, 5 do local o = Vector3.new(sx, 0, sz) + along * rng:NextNumber(-120, 120) + seaDir * rng:NextNumber(60, 140); L.boat(m, o.X, 1, o.Z, rng:NextNumber(0, 6.28), rng:NextInteger(18, 26)) end
    local fm = Vector3.new(sx, 0, sz) - seaDir * 50; local fy = L.heightAt(fm.X, fm.Z)
    for i = -1, 1, 2 do for k = -1, 1, 2 do L.cyl(m, CFrame.new(fm.X + i * 12, fy + 5, fm.Z + k * 8), 1, 10, MAT.Wood, L.C.wood) end end
    L.box(m, CFrame.new(fm.X, fy + 10.5, fm.Z), Vector3.new(30, 1, 22), MAT.Fabric, L.C.roofBlue, { cancollide = false, name = "FishMarket" })
    for i = 1, 4 do local r = fm - seaDir * 40 + along * (i * 14 - 35); local ry = L.heightAt(r.X, r.Z)
      for s = -1, 1, 2 do L.cyl(m, CFrame.new(r.X, ry + 4, r.Z + s * 5), 0.4, 8, MAT.Wood, L.C.wood) end; L.box(m, CFrame.new(r.X, ry + 7.5, r.Z), Vector3.new(0.4, 0.4, 10), MAT.Wood, L.C.wood, { cancollide = false, name = "DryingRack" }) end
    local lp = Vector3.new(sx, 0, sz) + along * 200; local lx, lz = L.findShore(lp.X - dx * 60, lp.Z - dz * 60, dx, dz, 300); local ly = L.heightAt(lx, lz)
    L.cyl(m, CFrame.new(lx, ly + 20, lz), 4, 40, MAT.Plaster, L.C.plaster, { name = "SmallLighthouse" }); L.ball(m, CFrame.new(lx, ly + 42, lz), Vector3.new(6, 6, 6), MAT.Neon, Color3.fromRGB(255, 240, 180))
  end
  function KIND.mage(m, x, y, z, rng, p)
    for i = 1, 8 do local a = rng:NextNumber(0, 6.28); local r = rng:NextNumber(60, 220); L.crystal(m, Vector3.new(x + math.cos(a) * r, y + rng:NextNumber(20, 60), z + math.sin(a) * r), rng:NextNumber(3, 6)) end
    boilerHouse(m, x + 140, y, z - 120, 0); L.sign(m, x + 140, y, z - 95, "Steam Lift to the Spire", 0)
    L.cyl(m, CFrame.new(x - 150, y + 20, z + 120), 10, 40, MAT.Cobblestone, L.C.stone, { name = "Observatory" }); L.ball(m, CFrame.new(x - 150, y + 44, z + 120), Vector3.new(22, 22, 22), MAT.Metal, L.C.brass)
    L.rod(m, Vector3.new(x - 150, y + 48, z + 120), Vector3.new(x - 150, y + 66, z + 132), 1.5, MAT.Metal, L.C.copper)
  end
  function KIND.engineer(m, x, y, z, rng, p)
    for i = 1, 3 do local wx, wz = x + rng:NextNumber(-200, 200), z + rng:NextNumber(-200, 200); local rd, _, rw = L.riverAt(wx, wz)
      if rd > rw / 2 + 40 then local wy = L.heightAt(wx, wz); L.box(m, CFrame.new(wx, wy + 10, wz), Vector3.new(44, 20, 30), MAT.Brick, L.C.brick, { name = "Workshop" }); L.chimney(m, wx + 14, wy + 20, wz, 2, 16, true)
        L.gear(m, CFrame.new(wx, wy + 14, wz + 15.6) * CFrame.Angles(0, math.pi / 2, 0), 6, 12, 1.2, L.C.brass) end end
    local tx, tz = x + 180, z + 150; local ty = L.heightAt(tx, tz)
    for i = 0, 3 do L.box(m, CFrame.new(tx + (i % 2 == 0 and -6 or 6), ty + 15, tz + (i < 2 and -6 or 6)), Vector3.new(2, 30, 2), MAT.Metal, L.C.iron) end
    L.cyl(m, CFrame.new(tx, ty + 38, tz), 10, 16, MAT.Metal, L.C.copper, { name = "WaterTower" })
  end
  local roofByKind = { farm = L.C.roofRed, mine = L.C.darkStone, lumber = L.C.roofGreen, fishing = L.C.roofBlue, mage = L.C.roofBlue, engineer = L.C.copper }
  for name, p in pairs(Y.places) do
    if p.type == "village" then
      local x, z = L.toWorld(p.pos); local y = L.padY(x, z)
      local rng = Random.new(#name * 7919)
      local m = L.model(folder, name)
      L.flattenDisc(x, z, 300, y, MAT.Ground); ringRoad(x, z, y, 190)
      local n = rng:NextInteger(Y.villages.houses[1], Y.villages.houses[2]); local built = 0
      for i = 1, n do
        local a = (i / n) * 2 * math.pi + rng:NextNumber(-0.12, 0.12); local r = rng:NextNumber(215, 260)
        local hx, hz = x + math.cos(a) * r, z + math.sin(a) * r
        local rd, _, rw = L.riverAt(hx, hz)
        if rd > rw / 2 + 30 and L.heightAt(hx, hz) > 2 then
          L.house(m, hx, y, hz, rng:NextInteger(20, 28), rng:NextInteger(16, 22), rng:NextInteger(1, 2), { yaw = math.atan2(-math.cos(a), -math.sin(a)), roof = roofByKind[p.kind], stone = p.kind == "mage" or p.kind == "mine" }); built += 1
        end
      end
      L.sign(m, x + 200, y, z + 200, name, math.pi / 4)
      KIND[p.kind](m, x, y, z, rng, p)
      m:SetAttribute("Houses", built)
      L.progress(name .. " built"); task.wait()
    end
  end
end)
```

- [ ] **Step 6.2: ขออนุมัติผู้ใช้ข้อ 6 แล้วรัน**

Run: `node tools/run-luau.js mapgen/40_villages.lua --timeout 900`
Expected: `done | <หมู่บ้านสุดท้าย> built`

- [ ] **Step 6.3: ตรวจ**

Run: `node tools/run-luau.js mapgen/check_villages.lua` โดยไฟล์:

```lua
return L.runPhase("CheckVillages", function()
  local fails = {}; local f = L.root():FindFirstChild("Villages")
  for name, p in pairs(L.LAYOUT.places) do if p.type == "village" then
    local m = f and f:FindFirstChild(name)
    L.check(fails, m ~= nil, "missing " .. name)
    L.check(fails, m and (m:GetAttribute("Houses") or 0) >= 6, name .. " has >= 6 houses")
    if m then for _, d in ipairs(m:GetDescendants()) do if d:IsA("BasePart") and d.Position.Y < -50 then L.check(fails, false, name .. " part below -50"); break end end end
  end end
  L.check(fails, f.Goldmeadow:FindFirstChild("Fields") and #f.Goldmeadow.Fields:GetChildren() > 100, "Goldmeadow fields")
  L.check(fails, f.Saltmere:FindFirstChild("Pier", true) ~= nil, "Saltmere piers")
  L.check(fails, f.Elderwood:FindFirstChild("WaterWheel", true) ~= nil, "Elderwood water wheel")
  assert(#fails == 0, table.concat(fails, "\n")); L.progress("village checks passed")
end)
```

ภาพ: แต่ละหมู่บ้าน `shot village-<name> x+300 y+200 z+300 x y z` เห็นบ้านเป็นวง ถนนวง ป้าย จุดเด่นตามชนิด ถ้าโรงเลื่อยไม่ติดน้ำ ปรับ offset `mx, mz` ใน `KIND.lumber` ตามตำแหน่งลำน้ำจริง (ใช้ `L.riverAt` หา)

- [ ] **Step 6.4: Commit**

```bash
git add mapgen/40_villages.lua mapgen/check_villages.lua
git commit -m "mapgen: 6 villages phase (farm, mine, lumber, fishing, mage, engineer landmarks)"
```

---

### Task 7: รถไฟ ลิฟต์ ท่อไอน้ำ Spire of Eld (ขั้น 7)

**Files:**
- Create: `mapgen/50_steam_magic.lua`

**Interfaces:**
- Consumes: `L.LAYOUT.railway`, `steam.lift/pipes/train`, `spire`, `Capital` folder Attribute `StationPos` (Vector3 จาก Task 5), builders
- Produces: `workspace.WOLD.Steam` มี Model `Railway`, `Station_Stonemark`, `Station_Cogsworth`, `Train`, `SteamLift`, `SteamPipe`, `Spire of Eld`

- [ ] **Step 7.1: เขียน `mapgen/50_steam_magic.lua`**

```lua
-- rail (smoothed grade, embankment/cut), 2 stations, parked train, inclined steam lift, brass pipe along the King's Road, Spire of Eld
return L.runPhase("Steam", function(folder)
  L.requireFullScale()
  local Y, MAT, Terrain = L.LAYOUT, L.MAT, workspace.Terrain
  local wall = L.wallWorld()
  -- 1) railway path: place centers, last point = Brasshaven station if known
  local pts = L.roadWorld(Y.railway)
  local cap = L.root():FindFirstChild("Capital"); local sp = cap and cap:GetAttribute("StationPos")
  if sp then pts[#pts] = { sp.X, sp.Z } end
  local samples = {}                                     -- {x, z, y, dir}
  for i = 1, #pts - 1 do
    local a = Vector3.new(pts[i][1], 0, pts[i][2]); local b = Vector3.new(pts[i + 1][1], 0, pts[i + 1][2]); local dir = (b - a).Unit
    for s = 0, (b - a).Magnitude, 8 do local p = a + dir * s; samples[#samples + 1] = { x = p.X, z = p.Z, y = L.heightAt(p.X, p.Z), dir = dir } end
  end
  for pass = 1, 3 do                                     -- smooth grade: moving average over ±12 samples (±96 studs)
    local ys = {}
    for i, s in ipairs(samples) do local sum, n = 0, 0; for k = math.max(1, i - 12), math.min(#samples, i + 12) do sum += samples[k].y; n += 1 end; ys[i] = sum / n end
    for i, s in ipairs(samples) do s.y = ys[i] end
  end
  for _, s in ipairs(samples) do local rd, hs, rw = L.riverAt(s.x, s.z); if rd < rw / 2 + 90 then s.y = math.max(s.y, hs + 10) end; s.y = math.floor(s.y / 2) * 2 + 2 end
  local rail = L.model(folder, "Railway")
  for i = 1, #samples - 1 do
    local a, b = samples[i], samples[i + 1]
    local pa, pb = Vector3.new(a.x, a.y, a.z), Vector3.new(b.x, b.y, b.z)
    local side = Vector3.new(-a.dir.Z, 0, a.dir.X)
    for g = -1, 1, 2 do L.rod(rail, pa + side * g * 3, pb + side * g * 3, 0.35, MAT.Metal, L.C.iron, { cancollide = false }) end
    L.box(rail, CFrame.new((pa + pb) / 2 - Vector3.new(0, 0.5, 0)) * L.yaw(math.atan2(-a.dir.Z, a.dir.X)), Vector3.new(2, 0.6, 9), MAT.Wood, L.C.wood)
    local rd, _, rw = L.riverAt(a.x, a.z); local g = L.heightAt(a.x, a.z)
    if rd > rw / 2 + 8 then
      if g < a.y - 1.5 then Terrain:FillBlock(CFrame.new(a.x, (a.y - 1 + g - 4) / 2, a.z) * L.yaw(math.atan2(-a.dir.Z, a.dir.X)), Vector3.new(8, a.y - 1 - g + 4, 14), MAT.Ground)
      elseif g > a.y + 1 then Terrain:FillBlock(CFrame.new(a.x, a.y + 8, a.z) * L.yaw(math.atan2(-a.dir.Z, a.dir.X)), Vector3.new(8, 18, 16), MAT.Air); Terrain:FillBlock(CFrame.new(a.x, a.y - 2, a.z), Vector3.new(8, 2, 14), MAT.Ground) end
    end
    if i % 150 == 0 then L.progress(("rail %d/%d"):format(i, #samples)); task.wait() end
  end
  -- 2) stations at Stonemark and Cogsworth: nearest rail sample to the village center, platform 20 studs to the side
  local function nearestSample(x, z) local best, bi = math.huge, 1; for i, s in ipairs(samples) do local d = (s.x - x) ^ 2 + (s.z - z) ^ 2; if d < best then best, bi = d, i end end; return samples[bi] end
  for _, name in ipairs({ "Stonemark", "Cogsworth" }) do
    local vx, vz = L.placePos(name); local s = nearestSample(vx, vz)
    local side = Vector3.new(-s.dir.Z, 0, s.dir.X); local yaw = math.atan2(-s.dir.Z, s.dir.X)
    local c = Vector3.new(s.x, s.y, s.z) + side * 16
    local m = L.model(folder, "Station_" .. name)
    L.box(m, CFrame.new(c) * L.yaw(yaw), Vector3.new(100, 2, 14), MAT.Cobblestone, L.C.stone, { name = "Platform" })
    for i = -2, 2 do L.cyl(m, CFrame.new(c + s.dir * (i * 22) + Vector3.new(0, 8, 0)), 0.8, 14, MAT.Metal, L.C.iron) end
    L.box(m, CFrame.new(c + Vector3.new(0, 15.5, 0)) * L.yaw(yaw), Vector3.new(104, 1, 20), MAT.Metal, L.C.copper, { cancollide = false })
    local wt = c + side * 24 + s.dir * 60
    for i = 0, 3 do L.box(m, CFrame.new(wt.X + (i % 2 == 0 and -3 or 3), wt.Y + 8, wt.Z + (i < 2 and -3 or 3)), Vector3.new(1.2, 16, 1.2), MAT.Wood, L.C.wood) end
    L.cyl(m, CFrame.new(wt + Vector3.new(0, 21, 0)), 6, 10, MAT.Wood, L.C.plank, { name = "WaterTower" })
    L.sign(m, c.X + side.X * 10, s.y, c.Z + side.Z * 10, name .. " Station", yaw)
  end
  -- 3) parked train at the Brasshaven end (placeholder locomotive = boxes + cylinders)
  do
    local n = #samples; local s = samples[n - 12]; local dir = s.dir; local yaw = math.atan2(-dir.Z, dir.X)
    local m = L.model(folder, "Train")
    local function wheels(p, len) for i = -1, 1 do for g = -1, 1, 2 do L.part(m, Enum.PartType.Cylinder, CFrame.new(p + dir * (i * len / 3) + Vector3.new(-dir.Z, 0, dir.X) * g * 3.4) * L.yaw(yaw) * CFrame.Angles(0, math.pi / 2, 0), Vector3.new(1, 3.6, 3.6), MAT.Metal, L.C.iron) end end end
    local lp = Vector3.new(s.x, s.y + 2, s.z)
    L.box(m, CFrame.new(lp + Vector3.new(0, 3, 0)) * L.yaw(yaw), Vector3.new(30, 3, 8), MAT.Metal, L.C.iron, { name = "LocomotivePlaceholder" })
    L.part(m, Enum.PartType.Cylinder, CFrame.new(lp + dir * 4 + Vector3.new(0, 8, 0)) * L.yaw(yaw), Vector3.new(20, 8, 8), MAT.Metal, L.C.iron)
    L.box(m, CFrame.new(lp - dir * 10 + Vector3.new(0, 9, 0)) * L.yaw(yaw), Vector3.new(9, 10, 8), MAT.Metal, L.C.copper)
    L.cyl(m, CFrame.new(lp + dir * 11 + Vector3.new(0, 15, 0)), 1.5, 6, MAT.Metal, L.C.brass); wheels(lp, 26)
    for c = 1, Y.steam.train.cars do local cp = lp - dir * (c * 34)
      L.box(m, CFrame.new(cp + Vector3.new(0, 6, 0)) * L.yaw(yaw), Vector3.new(30, 9, 8), MAT.WoodPlanks, (c == 2) and L.C.roofRed or L.C.plank, { name = "Car" }); wheels(cp, 26) end
  end
  L.progress("rail + stations + train"); task.wait()
  -- 4) steam lift: Astravale boiler house -> Spire base, rails hugging the slope
  do
    local ax, az = L.placePos(Y.steam.lift.from); local sx, sz = L.placePos(Y.steam.lift.to)
    local a = Vector3.new(ax + 140, 0, az - 120); local b = Vector3.new(sx, 0, sz)
    local dir = (b - a).Unit; local len = (b - a).Magnitude; local side = Vector3.new(-dir.Z, 0, dir.X)
    local m = L.model(folder, "SteamLift")
    local prev
    for s = 0, len - 60, 20 do
      local p = a + dir * s; local y = L.heightAt(p.X, p.Z) + 3; local cur = Vector3.new(p.X, y, p.Z)
      if prev then for g = -1, 1, 2 do L.rod(m, prev + side * g * 4, cur + side * g * 4, 0.5, MAT.Metal, L.C.iron, { cancollide = false }) end
        L.box(m, CFrame.new((prev + cur) / 2 - Vector3.new(0, 1, 0)), Vector3.new(3, 0.6, 10), MAT.Metal, L.C.rust) end
      if s % 100 == 0 then L.box(m, CFrame.new(cur.X, cur.Y - 3, cur.Z), Vector3.new(4, 6, 4), MAT.Cobblestone, L.C.darkStone) end
      prev = cur
    end
    local cab = a + dir * 30; local cy = L.heightAt(cab.X, cab.Z) + 4
    L.box(m, CFrame.new(cab.X, cy + 4, cab.Z) * L.yaw(math.atan2(-dir.Z, dir.X)), Vector3.new(14, 8, 8), MAT.Metal, L.C.brass, { name = "Cabin" })
    L.box(m, CFrame.new(cab.X, cy + 5, cab.Z) * L.yaw(math.atan2(-dir.Z, dir.X)), Vector3.new(14.2, 3, 8.2), MAT.Glass, L.C.glass, { cancollide = false, transparency = 0.4 })
    L.gear(m, CFrame.new(cab.X, cy + 12, cab.Z) * L.yaw(math.atan2(-dir.Z, dir.X)) * CFrame.Angles(0, math.pi / 2, 0), 4, 10, 1, L.C.brass)
    L.sign(m, cab.X + side.X * 10, cy - 4, cab.Z + side.Z * 10, "Steam Lift", math.atan2(-dir.Z, dir.X))
  end
  -- 5) brass pipe along the King's Road from Brasshaven to Goldmeadow (offset 14 studs, posts every 40, valve every 200)
  do
    local road = Y.roads[1]; local rp = {}
    for i, e in ipairs(road) do rp[i] = L.pt(e); if e == Y.steam.pipes.to then break end end
    local m = L.model(folder, "SteamPipe"); local pts = {}; local acc = 0
    for i = 1, #rp - 1 do
      local a = Vector3.new(L.toWorld(rp[i])); local ax2, az2 = L.toWorld(rp[i]); local bx2, bz2 = L.toWorld(rp[i + 1])
      local av, bv = Vector3.new(ax2, 0, az2), Vector3.new(bx2, 0, bz2); local dir = (bv - av).Unit; local side = Vector3.new(-dir.Z, 0, dir.X)
      for s = 0, (bv - av).Magnitude, 40 do
        local p = av + dir * s + side * 14; local rd, _, rw = L.riverAt(p.X, p.Z)
        if rd > rw / 2 + 8 then pts[#pts + 1] = Vector3.new(p.X, L.heightAt(p.X, p.Z) + 4, p.Z); acc += 40
          if acc % 200 == 0 then L.cyl(m, CFrame.new(pts[#pts] + Vector3.new(0, 2, 0)), 1.2, 3, MAT.Metal, L.C.copper); L.gear(m, CFrame.new(pts[#pts] + Vector3.new(0, 4.5, 0)), 1.6, 8, 0.6, L.C.brass) end end
      end
    end
    L.pipeRun(m, pts, 1.5, L.C.brass, 40)
  end
  L.progress("lift + pipe"); task.wait()
  -- 6) Spire of Eld
  do
    local x, z = L.placePos("Spire of Eld"); local y = L.padY(x, z); L.flattenDisc(x, z, 90, y, MAT.Rock)
    local m = L.model(folder, "Spire of Eld"); local S = Y.spire
    L.cyl(m, CFrame.new(x, y + S.height / 2, z), S.base / 2, S.height, MAT.Slate, L.C.darkStone, { name = "SpireBody" })
    local steps = 60
    for i = 0, steps do local a = i * (2.5 * 2 * math.pi / steps); local h = y + 2 + i * ((S.height - 4) / steps)
      L.box(m, CFrame.new(x + math.cos(a) * (S.base / 2 + 5), h, z + math.sin(a) * (S.base / 2 + 5)) * L.yaw(-a) * CFrame.Angles(0, 0, 0), Vector3.new(11, 1.5, 12), MAT.Slate, L.C.stone, { name = "Ramp" }) end
    L.cyl(m, CFrame.new(x, y + S.height + 1, z), S.base / 2 + 8, 2, MAT.Slate, L.C.stone, { name = "TopPlatform" })
    for i = 0, 11 do local a = i * math.pi / 6; L.box(m, CFrame.new(x + math.cos(a) * (S.base / 2 + 7), y + S.height + 4, z + math.sin(a) * (S.base / 2 + 7)) * L.yaw(-a), Vector3.new(2, 4, 4), MAT.Slate, L.C.stone, { cancollide = false }) end
    L.crystal(m, Vector3.new(x, y + S.height + 26, z), 16)
    for i = 0, S.orbit_crystals - 1 do local a = i * 2 * math.pi / S.orbit_crystals; L.crystal(m, Vector3.new(x + math.cos(a) * 30, y + S.height + 18 + math.sin(a * 2) * 4, z + math.sin(a) * 30), 5) end
    L.sign(m, x + 50, y, z + 50, "Spire of Eld", math.pi / 4)
  end
  L.progress("spire")
end)
```

- [ ] **Step 7.2: ขออนุมัติผู้ใช้ข้อ 7 แล้วรัน**

Run: `node tools/run-luau.js mapgen/50_steam_magic.lua --timeout 1200`
Expected: `done | spire`

- [ ] **Step 7.3: ตรวจ**

```lua
-- mapgen/check_steam.lua
return L.runPhase("CheckSteam", function()
  local fails = {}; local f = L.root():FindFirstChild("Steam")
  for _, n in ipairs({ "Railway", "Station_Stonemark", "Station_Cogsworth", "Train", "SteamLift", "SteamPipe", "Spire of Eld" }) do L.check(fails, f and f:FindFirstChild(n), "missing " .. n) end
  L.check(fails, L.countParts(f.Railway) > 1500, "rail has segments")
  local sx, sz = L.placePos("Spire of Eld"); local top = f["Spire of Eld"]:FindFirstChild("TopPlatform")
  L.check(fails, top and top.Position.Y > L.heightAt(sx, sz) + 200, "spire top above 200")
  local under = 0; for _, d in ipairs(f.Railway:GetDescendants()) do if d:IsA("BasePart") and d.Position.Y < L.heightAt(d.Position.X, d.Position.Z) - 6 then under += 1 end end
  L.check(fails, under < L.countParts(f.Railway) * 0.05, ("%d rail parts buried"):format(under))
  assert(#fails == 0, table.concat(fails, "\n")); L.progress("steam checks passed")
end)
```

ภาพ: `shot rail-cogsworth 900 300 -1000 800 60 -1120`, `shot spire 3200 2600 -5600 3600 2100 -4800`, `shot lift <ax+300> <ay+300> <az-300> <sx> <sy> <sz>`, `shot train <StationPos ± 80>` เห็นรางต่อเนื่องไม่ลอยไม่จม สถานีมีชานชาลา ลิฟต์ขึ้นถึงยอด Spire มีคริสตัลเรืองแสง

- [ ] **Step 7.4: Commit**

```bash
git add mapgen/50_steam_magic.lua mapgen/check_steam.lua
git commit -m "mapgen: steam + magic phase (railway, stations, train, steam lift, brass pipe, Spire of Eld)"
```

---

### Task 8: เกาะเล็ก 5 เกาะ (ขั้น 8)

**Files:**
- Create: `mapgen/60_islands.lua`

**Interfaces:**
- Consumes: `L.isles` (เฉพาะที่ไม่ใช่ `rock`), builders
- Produces: `workspace.WOLD.Islands.<ชื่อเกาะ>`

- [ ] **Step 8.1: เขียน `mapgen/60_islands.lua`**

```lua
-- 5 themed isles: small flat pad at the top, structures by name, pier facing the main island
return L.runPhase("Islands", function(folder)
  L.requireFullScale()
  local Y, MAT, Terrain = L.LAYOUT, L.MAT, workspace.Terrain
  local function pierToMain(m, x, z, y)
    local dx, dz = L.dirTo(x, z, 0, 0); local sx, sz = L.findShore(x, z, dx, dz, 1500)
    L.pier(m, sx, sz, Vector3.new(dx, 0, dz), 80, 10, 5); return sx, sz, dx, dz
  end
  local BUILD = {}
  BUILD["Crystal Isle"] = function(m, x, y, z, rng)
    for i = 1, 5 do local a = i * 2 * math.pi / 5; L.crystal(m, Vector3.new(x + math.cos(a) * 60, y + rng:NextNumber(30, 60), z + math.sin(a) * 60), rng:NextNumber(10, 14)) end
    for s = -1, 1, 2 do L.cyl(m, CFrame.new(x + s * 20, y + 14, z - 40), 3, 28, MAT.Marble, L.C.plaster) end
    L.box(m, CFrame.new(x - 6, y + 29, z - 40) * CFrame.Angles(0, 0, 0.12), Vector3.new(30, 4, 5), MAT.Marble, L.C.plaster, { name = "BrokenArch" })
    Terrain:FillBlock(CFrame.new(x, y - 3, z + 40), Vector3.new(44, 6, 44), MAT.Water)
    L.box(m, CFrame.new(x, y - 6.5, z + 40), Vector3.new(44, 1, 44), MAT.Neon, L.C.crystal, { name = "GlowPool" })
  end
  BUILD["Steam Fortress Isle"] = function(m, x, y, z, rng)
    for i = 1, 4 do local a = (i - 0.5) * math.pi / 2; local cx, cz = x + math.cos(a) * 110, z + math.sin(a) * 110
      L.box(m, CFrame.new((x + cx) / 2 + math.cos(a + math.pi / 2) * 0, y + 12, (z + cz) / 2) * L.yaw(-a), Vector3.new(6, 24, 160), MAT.CorrodedMetal, L.C.rust)
      L.cyl(m, CFrame.new(cx, y + 18, cz), 12, 36, MAT.CorrodedMetal, L.C.iron, { name = "Turret" }) end
    for i = -1, 1 do L.cyl(m, CFrame.new(x + i * 30, y + 12, z), 10, 24, MAT.CorrodedMetal, L.C.rust, { name = "Boiler" }); L.chimney(m, x + i * 30, y + 24, z, 2, 18, false) end
    for i = 1, 6 do local a = i * math.pi / 3; local p = Vector3.new(x + math.cos(a) * 100, y + 26, z + math.sin(a) * 100)
      L.rod(m, p, p + Vector3.new(math.cos(a) * 14, 3, math.sin(a) * 14), 1.5, MAT.Metal, L.C.iron, { name = "Cannon" }) end
    pierToMain(m, x, z, y)
  end
  BUILD["Lighthouse Isle"] = function(m, x, y, z, rng)
    L.cyl(m, CFrame.new(x, y + 60, z), 8, 120, MAT.Plaster, L.C.plaster, { name = "Lighthouse" })
    for i = 1, 3 do L.cyl(m, CFrame.new(x, y + 20 + i * 28, z), 8.3, 10, MAT.Plaster, L.C.roofRed) end
    L.cyl(m, CFrame.new(x, y + 123, z), 10, 6, MAT.Glass, L.C.glass, { transparency = 0.4 })
    local lamp = L.ball(m, CFrame.new(x, y + 123, z), Vector3.new(6, 6, 6), MAT.Neon, Color3.fromRGB(255, 240, 180), { cancollide = false })
    local pl = Instance.new("PointLight"); pl.Range = 400; pl.Brightness = 3; pl.Parent = lamp
    L.cyl(m, CFrame.new(x, y + 128, z), 11, 3, MAT.Metal, L.C.iron)
    L.house(m, x + 40, y, z + 20, 30, 24, 1, { name = "KeeperCottage", stone = true, roof = L.C.roofRed })
    pierToMain(m, x, z, y)
  end
  BUILD["Ruins Isle"] = function(m, x, y, z, rng)
    L.box(m, CFrame.new(x, y + 2, z), Vector3.new(90, 4, 70), MAT.Marble, L.C.stone, { name = "TemplePlatform" })
    for i = 1, 12 do local a = i * math.pi / 6; local h = rng:NextNumber(8, 30); local tilt = (rng:NextNumber() < 0.3) and rng:NextNumber(0.05, 0.2) or 0
      L.cyl(m, CFrame.new(x + math.cos(a) * 36, y + 4 + h / 2, z + math.sin(a) * 26) * CFrame.Angles(tilt, 0, tilt), 3, h, MAT.Marble, L.C.plaster, { name = "Column" }) end
    L.box(m, CFrame.new(x, y + 36, z) * CFrame.Angles(0, 0, 0.08), Vector3.new(60, 3, 8), MAT.Marble, L.C.plaster, { name = "Lintel" })
    L.box(m, CFrame.new(x + 60, y + 4, z + 50), Vector3.new(12, 4, 12), MAT.Marble, L.C.stone)
    L.box(m, CFrame.new(x + 60, y + 12, z + 50) * CFrame.Angles(0.3, 0.5, 0), Vector3.new(5, 14, 4), MAT.Marble, L.C.stone, { name = "BrokenStatue" })
  end
  BUILD["Smuggler's Cove"] = function(m, x, y, z, rng)
    for i = 1, 4 do local a = i * math.pi / 2 + 0.4; L.house(m, x + math.cos(a) * 50, y, z + math.sin(a) * 50, 18, 14, 1, { name = "Shack", yaw = -a, roof = L.C.wood }) end
    for i = 1, 12 do L.cyl(m, CFrame.new(x + rng:NextNumber(-40, 40), y + 2, z + rng:NextNumber(-40, 40)), 2, 4, MAT.Wood, L.C.plank, { name = "Barrel" }) end
    local sx, sz, dx, dz = pierToMain(m, x, z, y)
    for i = 1, 2 do L.boat(m, sx + dx * (60 + i * 30) - dz * 14, 1, sz + dz * (60 + i * 30) + dx * 14, math.atan2(-dz, dx), 24) end
  end
  for _, isl in ipairs(L.isles) do
    if not isl.rock then
      local x, z = L.toWorld(isl.pos); local y = L.padY(x, z)
      L.flattenDisc(x, z, 130, y, MAT.Ground)
      local m = L.model(folder, isl.name)
      BUILD[isl.name](m, x, y, z, Random.new(#isl.name * 131))
      L.sign(m, x + 100, y, z + 100, isl.name, math.pi / 4)
      L.progress(isl.name .. " built"); task.wait()
    end
  end
end)
```

- [ ] **Step 8.2: ขออนุมัติผู้ใช้ข้อ 8 แล้วรัน**

Run: `node tools/run-luau.js mapgen/60_islands.lua --timeout 600`
Expected: `done | <เกาะสุดท้าย> built`

- [ ] **Step 8.3: ตรวจ**

```lua
-- mapgen/check_islands.lua
return L.runPhase("CheckIslands", function()
  local fails = {}; local f = L.root():FindFirstChild("Islands")
  for name in pairs(L.LAYOUT.isles) do local m = f and f:FindFirstChild(name); L.check(fails, m and L.countParts(m) > 8, "island " .. name) end
  L.check(fails, f["Lighthouse Isle"]:FindFirstChild("Lighthouse", true), "lighthouse")
  assert(#fails == 0, table.concat(fails, "\n")); L.progress("island checks passed")
end)
```

ภาพ: แต่ละเกาะ `shot isle-<name> x+600 y+400 z+600 x y z`

- [ ] **Step 8.4: Commit**

```bash
git add mapgen/60_islands.lua mapgen/check_islands.lua
git commit -m "mapgen: 5 themed isles phase"
```

---

### Task 9: ธรรมชาติ ต้นไม้ พุ่มไม้ ก้อนหิน (ขั้น 9)

**Files:**
- Create: `mapgen/70_nature.lua`

**Interfaces:**
- Consumes: `L.LAYOUT.nature`, `L.tree`, `L.base`, `L.pointInPoly`, `L.wallWorld`, `L.polyDist`
- Produces: `workspace.WOLD.Nature` (`Trees`, `Bushes`) Attribute `TreeCount`

- [ ] **Step 9.1: เขียน `mapgen/70_nature.lua`**

```lua
-- trees by zone (dense western forest, sparse plains, mountain pines, beach palms) + bushes/rocks; excludes water, roads, rails, settlements, fields
return L.runPhase("Nature", function(folder)
  L.requireFullScale()
  local Y, MAT = L.LAYOUT, L.MAT
  local N = Y.nature; local rng = Random.new(77)
  local wall = L.wallWorld()
  local avoid = {}
  for name, p in pairs(Y.places) do local x, z = L.toWorld(p.pos); avoid[#avoid + 1] = { x, z, (p.type == "village") and 330 or ((p.type == "capital") and 0 or 160) } end
  do local g = Y.places.Goldmeadow; local x, z = L.toWorld(g.fields_center); avoid[#avoid + 1] = { x, z, g.fields_radius * L.HALF + 20 } end
  for _, isl in ipairs(L.isles) do if not isl.rock then local x, z = L.toWorld(isl.pos); avoid[#avoid + 1] = { x, z, 150 } end end
  local paths = {}
  for _, r in ipairs(Y.roads) do paths[#paths + 1] = L.roadWorld(r) end
  paths[#paths + 1] = L.roadWorld(Y.railway)
  do local a = Y.places.Astravale.pos; local s = Y.places["Spire of Eld"].pos; local ax, az = L.toWorld(a); local sx, sz = L.toWorld(s); paths[#paths + 1] = { { ax + 140, az - 120 }, { sx, sz } } end
  local function blocked(x, z)
    if L.pointInPoly(wall, x, z) then return true end
    for _, a in ipairs(avoid) do if (x - a[1]) ^ 2 + (z - a[2]) ^ 2 < a[3] ^ 2 then return true end end
    local rd, _, rw = L.riverAt(x, z); if rd < rw / 2 + 10 then return true end
    for _, p in ipairs(paths) do if L.polyDist(p, 1, x, z) < 22 then return true end end
    return false
  end
  local trees, bushes = L.model(folder, "Trees"), L.model(folder, "Bushes")
  local count, budget = 0, N.tree_budget
  local R = (Y.coast_radius + Y.coast_noise) * L.HALF
  local function tryTree(x, z, kind, s)
    if count >= budget then return end
    local _, _, _, land = L.base(x / L.HALF, z / L.HALF); if land < 0.6 then return end
    local h = L.heightAt(x, z)
    if kind == "palm" then if h < 1 or h > 6 then return end elseif h < 6 or h > N.mountain_pine_max_y then return end
    if blocked(x, z) then return end
    L.tree(trees, x, h - 0.5, z, kind, s); count += 1
    if count % 500 == 0 then L.progress(("trees %d"):format(count)); task.wait() end
  end
  local fz = Y.forest
  for x = -R, fz.x_max * L.HALF, N.forest_spacing do for z = -fz.z_abs_max * L.HALF, fz.z_abs_max * L.HALF, N.forest_spacing do
    local jx, jz = x + rng:NextNumber(-15, 15), z + rng:NextNumber(-15, 15)
    local _, fm = L.base(jx / L.HALF, jz / L.HALF)
    if fm > 0.45 then tryTree(jx, jz, (rng:NextNumber() < 0.6) and "pine" or "oak", rng:NextNumber(0.8, 1.3)) end
  end end
  L.progress(("forest trees %d"):format(count)); task.wait()
  for x = -R, R, N.plains_spacing do for z = -R, R, N.plains_spacing do
    local jx, jz = x + rng:NextNumber(-80, 80), z + rng:NextNumber(-80, 80); local h = L.heightAt(jx, jz)
    if h > 250 then if rng:NextNumber() < 0.7 then tryTree(jx, jz, "pine", rng:NextNumber(0.7, 1.1)) end
    elseif h > 6 then tryTree(jx, jz, (rng:NextNumber() < 0.5) and "oak" or "pine", rng:NextNumber(0.9, 1.4))
    elseif h > 1 then tryTree(jx, jz, "palm", rng:NextNumber(0.9, 1.2)) end
  end end
  for x = -R, R, 120 do for z = -0.95 * L.HALF, Y.mountain_band_z * L.HALF, 120 do
    local jx, jz = x + rng:NextNumber(-40, 40), z + rng:NextNumber(-40, 40); if L.heightAt(jx, jz) > 250 then tryTree(jx, jz, "pine", rng:NextNumber(0.7, 1.1)) end
  end end
  L.progress(("all trees %d"):format(count)); task.wait()
  local bcount = 0
  for x = -R, R, 400 do for z = -R, R, 400 do
    local jx, jz = x + rng:NextNumber(-150, 150), z + rng:NextNumber(-150, 150); local h = L.heightAt(jx, jz)
    if h > 5 and not blocked(jx, jz) then
      if rng:NextNumber() < 0.5 then L.ball(bushes, CFrame.new(jx, h + 1.5, jz), Vector3.new(6, 4, 6), MAT.LeafyGrass, L.C.leafDark, { cancollide = false, name = "Bush" })
      else L.ball(bushes, CFrame.new(jx, h + 1, jz) * CFrame.Angles(rng:NextNumber(0, 1), rng:NextNumber(0, 3), 0), Vector3.new(rng:NextNumber(4, 10), rng:NextNumber(3, 6), rng:NextNumber(4, 10)), MAT.Slate, L.C.darkStone, { name = "Rock" }) end
      bcount += 1; if bcount % 300 == 0 then task.wait() end
    end
  end end
  folder:SetAttribute("TreeCount", count); folder:SetAttribute("BushCount", bcount)
  L.progress(("nature done: %d trees, %d bushes/rocks"):format(count, bcount))
end)
```

- [ ] **Step 9.2: ขออนุมัติผู้ใช้ข้อ 9 แล้วรัน**

Run: `node tools/run-luau.js mapgen/70_nature.lua --timeout 1800`
Expected: `done | nature done: ~15000-18000 trees, N bushes/rocks`

- [ ] **Step 9.3: ตรวจ**

Run: `node tools/mcp-call.js execute_luau '{"datamodel_type":"Edit","code":"local n=0 for _,d in ipairs(workspace.WOLD:GetDescendants()) do if d:IsA(\"BasePart\") then n+=1 end end return n, workspace.WOLD.Nature:GetAttribute(\"TreeCount\")"}'`
Expected: จำนวนชิ้นรวม < 70000 และ TreeCount ≥ 12000 ถ้าเกินงบ ลด `plains_spacing` ไม่ได้ ให้เพิ่ม `forest_spacing` เป็น 50 ใน JSON แล้วรันใหม่
ภาพ: `shot forest -3800 300 -400 -4200 60 -600`, `shot overview 0 9000 1 0 0 0` ป่าทึบชัดฝั่งตะวันตก ไม่มีต้นไม้บนถนน ในเมือง ในน้ำ

- [ ] **Step 9.4: Commit**

```bash
git add mapgen/70_nature.lua
git commit -m "mapgen: nature phase (18k tree budget by zone, bushes, rocks)"
```

---

### Task 10: ตรวจรวม AI mesh 3 ชิ้น เอกสาร ความจำ (ขั้น 10)

**Files:**
- Create: `mapgen/90_verify.lua`
- Modify: `CLAUDE.md` (สถานะ + วิธีรันตัวเจน), `README.md` (ส่วน mapgen)
- Create: `docs/design/shots-final/*.png` (ภาพสรุป 8-12 ภาพ)
- Memory: อัปเดต `parallel-sessions-scribe.md` และเพิ่ม `mapgen-workflow.md`

**Interfaces:**
- Consumes: ทุก Folder ใต้ `workspace.WOLD`, MCP `run_as_job` + `wait_job_finished` + `generate_mesh`
- Produces: place ที่ตรวจครบ, เอกสารสถานะ, ความจำ

- [ ] **Step 10.1: เขียน `mapgen/90_verify.lua`**

```lua
-- full self-check + camera list; re-enables undo history
return L.runPhase("Verify", function()
  local fails = {}; local root = L.root(); local Y = L.LAYOUT
  for _, n in ipairs({ "Setup", "Caves", "Roads", "Capital", "Villages", "Steam", "Islands", "Nature" }) do L.check(fails, root:FindFirstChild(n) and L.countParts(root[n]) > 0, "phase folder " .. n) end
  local total = L.countParts(root)
  L.check(fails, total <= Y.generator.part_budget, ("parts %d > budget"):format(total))
  for name, p in pairs(Y.places) do local x, z = L.toWorld(p.pos); local m = L.materialAtPoint(x, L.heightAt(x, z) - 3, z); L.check(fails, m ~= Enum.Material.Water and m ~= Enum.Material.Air, name .. " ground") end
  for _, R in ipairs(L.rivers) do for i = 1, #R.pts - 1 do local x, z = L.toWorld(R.pts[i]); local _, hs = L.riverAt(x, z); L.check(fails, L.materialAtPoint(x, hs - 2, z) == Enum.Material.Water, ("river pt %d water"):format(i)) end end
  local sp = root.Capital:FindFirstChild("SpawnLocation"); L.check(fails, sp and L.materialAtPoint(sp.Position.X, sp.Position.Y - 3, sp.Position.Z) ~= Enum.Material.Water, "spawn on ground")
  local low = 0; for _, d in ipairs(root:GetDescendants()) do if d:IsA("BasePart") and d.Position.Y < -100 then low += 1 end end; L.check(fails, low == 0, ("%d parts below -100"):format(low))
  L.check(fails, (root.Nature:GetAttribute("TreeCount") or 0) >= 12000, "trees >= 12000")
  L.check(fails, workspace.StreamingEnabled, "streaming enabled")
  pcall(function() game:GetService("ChangeHistoryService"):SetEnabled(true) end)
  print("[WOLD] camera list:")
  print("overview 0 9000 1 0 0 0"); print("brasshaven_from_bay 4800 400 4800 2400 100 3000"); print("keep 2400 600 2900 1760 250 2080"); print("spire 3200 2600 -5600 3600 2100 -4800")
  for name, p in pairs(Y.places) do local x, z = L.toWorld(p.pos); local y = L.heightAt(x, z); print(("%s %d %d %d %d %d %d"):format(name:gsub(" ", "_"), x + 300, y + 200, z + 300, x, y, z)) end
  for _, b in ipairs(Y.bridges) do local x, z = L.toWorld(b.pos); local y = L.heightAt(x, z); print(("%s %d %d %d %d %d %d"):format(b.name:gsub(" ", "_"), x + 150, y + 80, z + 150, x, y + 10, z)) end
  for name, c in pairs(Y.caves) do local x, z = L.toWorld(c); local y = L.heightAt(x, z); print(("%s %d %d %d %d %d %d"):format(name:gsub(" ", "_"), x + 120, y + 60, z + 120, x, y, z)) end
  for name, isl in pairs(Y.isles) do local x, z = L.toWorld(isl.pos); local y = L.heightAt(x, z); print(("%s %d %d %d %d %d %d"):format(name:gsub("[ ']", "_"), x + 600, y + 400, z + 600, x, y, z)) end
  assert(#fails == 0, table.concat(fails, "\n"))
  L.progress(("verify passed: %d parts"):format(total))
end)
```

- [ ] **Step 10.2: รัน verify และถ่ายภาพทุกมุม**

Run: `node tools/run-luau.js mapgen/90_verify.lua` → `done | verify passed: N parts` แล้ว `node tools/mcp-call.js get_console_output` คัดบรรทัด camera list มารัน `node tools/mcp-call.js shot <บรรทัด>` ทีละบรรทัด (เขียน loop ใน bash: `while read -r l; do node tools/mcp-call.js shot $l; done < cams.txt`) เปิดดูทุกภาพด้วย Read จดสิ่งผิด (ลอย จม ทับ) แล้วแก้ในไฟล์ขั้นนั้น รันขั้นนั้นใหม่ (รันซ้ำได้) จนผ่าน

- [ ] **Step 10.3: AI mesh 3 ชิ้นแทน placeholder** (ขออนุมัติผู้ใช้ก่อน เพราะใช้เวลาหลายนาทีต่อชิ้นและผลไม่แน่นอน)

สำหรับแต่ละชิ้น `{ prompt, size, placeholderPath }`:
1. `node tools/mcp-call.js run_as_job '{"toolName":"generate_mesh","arguments":{"textPrompt":"<prompt>","size":{"x":..,"y":..,"z":..}}}'` → ได้ `jobId`
2. `node tools/mcp-call.js wait_job_finished '{"jobId":"<id>","timeout":600}'` → อ่านชื่อ/ตำแหน่ง Model ที่ถูกใส่ (ปกติอยู่ใต้ Workspace)
3. ย้ายไปแทน placeholder: `execute_luau` โค้ด `local ph = <placeholderPath>; local m = workspace:FindFirstChild("<ชื่อที่ได้>"); m:PivotTo(ph.CFrame); m.Parent = ph.Parent; ph:Destroy(); for _,d in ipairs(m:GetDescendants()) do if d:IsA("BasePart") then d.Anchored = true end end`

| ชิ้น | prompt | size | placeholder |
|---|---|---|---|
| เรือเหาะ | steampunk airship, brass and copper hull, wooden gondola underneath, two propellers, rivets | 160, 70, 50 | `workspace.WOLD.Capital.AirshipDock.AirshipPlaceholder` (ลบ `Gondola` ด้วย) |
| หัวรถจักร | steampunk steam locomotive with tall brass smokestack, black iron boiler, six wheels | 30, 16, 8 | `workspace.WOLD.Steam.Train.LocomotivePlaceholder` |
| รูปปั้น | bronze statue of a robed founder holding a gear and a staff, on no base | 5, 16, 5 | `workspace.WOLD.Capital.Statue.StatuePlaceholder` |

ถ้า generate_mesh ล้มเหลวหรือได้รูปทรงแย่ ให้คง placeholder ไว้และบันทึกใน CLAUDE.md ว่าค้าง

- [ ] **Step 10.4: อัปเดตเอกสารและความจำ**

CLAUDE.md ส่วน "สถานะ": แมพเจนครบ 10 ขั้น, วิธีรันซ้ำ (`node tools/run-luau.js mapgen/<ขั้น>.lua`), ลำดับที่ต้องรันเมื่อเจน Terrain ใหม่ (10 → 11 → 20 → 30 → 40 → 50 → 60 → 70 เพราะ Terrain:Clear ลบทุกอย่างที่ขึ้นกับพื้น), ขั้นถัดไป = ออกแบบ NPC/วัตถุโต้ตอบ
README.md เพิ่มหัวข้อ "เจนแมพ" 5 บรรทัด
ความจำ `mapgen-workflow.md` (type: project): ลำดับรัน, เวลาที่วัดได้จริงต่อขั้น, จุดที่ต้องระวัง (เช่น ประตูคำนวณจากจุดตัด, การเจน Terrain ใหม่ต้องรันทุกขั้นหลังจากนั้นซ้ำ), placeholder AI mesh ที่ค้าง
ภาพสรุป: คัด 8-12 ภาพจาก `docs/shots/` ไป `docs/design/shots-final/`

- [ ] **Step 10.5: Commit และรายงาน**

```bash
git add mapgen/90_verify.lua CLAUDE.md README.md docs/design/shots-final
git commit -m "mapgen: verify phase passes; AI mesh hero pieces; docs + shots for map v1"
```

รายงานผู้ใช้: จำนวนชิ้นรวม เวลาเจนแต่ละขั้น สิ่งที่ค้าง (ถ้ามี) และเสนอเริ่มออกแบบรอบถัดไป (NPC และวัตถุโต้ตอบผูกระบบเดิม)

---

## Self-Review (ทำแล้ว)

**Spec coverage** เทียบ spec 02 ทีละหัวข้อ: ปรับจากแชท 8 ข้อ → JSON/Task 1; ส่วน 3 ทุกเขต/อาคารระบบ/กำแพง/ประตูคำนวณ/สะพานในเมือง/จุดเกิด/AI mesh → Task 5 + 10; ส่วน 4 หมู่บ้าน 6 ชนิด → Task 6, ถนน 2 ระดับ + สะพาน 5 → Task 4, ราง/สถานี/รถไฟ/ลิฟต์/ท่อ/Spire/คริสตัล → Task 7 (คริสตัล Astravale ใน Task 6, ถ้ำใน Task 3, Crystal Isle ใน Task 8), เกาะ 5 → Task 8, ธรรมชาติทุกกฎ → Task 9; ส่วน 5 ทุกหลักการ → Task 0-1 (runner, async, seed, SCALE, flattenPad = `flattenDisc/flattenRect`, self-check); ส่วน 6 ขั้น 0-10 → Task 0-10 ครบ รวมข้อ 2a/2b ใน Task 2 มุมกล้อง → Task 10 พิมพ์จาก verify
**ช่องว่างที่รู้และตั้งใจ:** ภายในอาคารเป็นกล่องทึบ (spec ระบุ deferred), หน้าปัดนาฬิกาไม่มีตัวเลข, "ทางเดินบนกำแพง" คือแนวเชิงเทินไม่ใช่พื้นเดินแยก
**Placeholder scan:** ไม่มี TBD/TODO; ค่าที่ต้องวัดจริง (เวลา WriteVoxels, รูปแบบผลลัพธ์ screen_capture) ระบุวิธีวัดและทางแก้ไว้ใน Task 0
**Type consistency:** ชื่อฟังก์ชันที่ใช้ข้าม Task ตรงกัน: `L.heightAt/L.riverAt/L.isLand/L.base/L.sample`, `L.padY`, `L.flattenDisc(x,z,r,y,mat)`, `L.flattenRect(x,z,w,d,y,mat)`, `L.house(parent,x,y,z,w,d,floors,opts)`, `L.tower(parent,x,y,z,r,h,opts)`, `L.cyl(parent,cf,radius,height,mat,color,opts)` (รับ CFrame), `L.rod(parent,a,b,radius,mat,color,opts)`, `L.gear(parent,cf,r,teeth,thick,color)`, `L.chimney(parent,x,y,z,r,h,smoke)`, `L.pipeRun(parent,pts,radius,color,postEvery)`, `L.sign(parent,x,y,z,text,yaw)`, `L.pier(parent,x,z,dir,len,w,y)`, `L.boat(parent,x,y,z,yaw,len)`, `L.crystal(parent,pos,size,color)`, `L.findShore(x,z,dx,dz,maxDist)`, `L.dirTo(x,z,tx,tz)`, `L.polyDist(pts,total,u,v)`, `L.roadWorld(road)`, `L.wallWorld()`, `L.polyCrossings(poly,path)`, `L.pointInPoly(poly,x,z)`, `L.runPhase(name,fn)`, `L.progress`, `L.check`, `L.materialAtPoint`, `L.countParts`, `L.requireFullScale`, Attribute `StationPos` (Task 5 → 7), `HouseCount`, `GateCount`, `TreeCount`

## การดำเนินการ

รันทีละ Task ตามลำดับ 0 → 10 ทุก Task เริ่มด้วยการขออนุมัติผู้ใช้ และจบด้วย commit ถ้าขั้นใดต้องเจน Terrain ใหม่ (Task 2) หลังจากขั้น 3 ขึ้นไปทำแล้ว ต้องรันขั้น 3-9 ซ้ำทั้งหมดเพราะ `Terrain:Clear()`

---

## ผลจริงของ Task 0 (บันทึก 2026-09-06 หลังสนามทดสอบ 8 รอบ)

ผู้ใช้ขยายข้อ 0 เป็นสนามทดสอบเดินดูจริง (`mapgen/test_yard.lua` เกาะกลม 1,800 studs ตัดจากอ่าว Brasshaven) และอนุมัติหลังปรับ 8 รอบ สิ่งที่เปลี่ยนจากแผนเดิมและมีผลกับ Task ถัดไป:

| เรื่อง | แผนเดิม | ที่ใช้จริง | กระทบ Task |
|---|---|---|---|
| ลานเรียบใต้เมือง/หมู่บ้าน | `flattenDisc` ด้วย FillBlock (เกิดหน้าผา) | `L.pads` ในฟังก์ชันความสูง มีลาดเชิงเนิน น้ำหนัก t^8 ลานห้ามซ้อนกัน (keep 256 / government 320 ห่าง 824) | 2, 5, 6, 8 |
| ถนน | FillBlock แผ่นวัสดุ (ลอยบนพื้นเอียง) | `Terrain:ReplaceMaterial` เปลี่ยนวัสดุผิวดินใน `L.paintRoad` | 4 |
| สะพาน | แท่นเข้าสะพาน FillBlock | พื้นสะพาน = max(ตลิ่ง, น้ำ+6) + บันได `L.stairs` ลงตลิ่งทั้งสองฝั่ง | 4 |
| ปากแม่น้ำ | ไม่มี | บานเป็นปากอ่าวกว้าง 200 ใน 240 studs สุดท้าย (`R.estuary`) | 2 |
| ตลิ่ง | ยกเป็นสัน hs+3 | ตลิ่ง hs+1 และไม่ยกสันใกล้ปากน้ำ (`hs <= 3`) | 2 |
| ต้นไม้ พุ่ม หิน | Part 2 ชิ้นต่อต้น | โคลนต้นแบบ Creator Store จาก `nature.assets` ใน JSON ผ่าน `mapgen/assets_setup.lua` (InsertService) → `ServerStorage.WOLD_Assets` งบชิ้นส่วน 150,000 | 1 (รัน assets_setup), 9 |
| บ้าน | แผ่นไม้เต็มหน้า (z-fight) | เสามุม + คานยื่น 0.5 กรอบหน้าต่าง/ประตู สันหลังคา | 5, 6 |
| ปราสาท | กล่อง + หอ | `L.castle`/`L.castleTower` เชิงเทิน ค้ำยัน ช่องธนู ประตูไม้+ตะแกรง หอกรวย ป้อมมุม บ่อน้ำ ลัง ฐานฝังดิน 3 | 5 |
| สไตล์ภาพ | ไม่มี | `style` ใน JSON (สีวัสดุ Terrain น้ำ แสง บรรยากาศ เมฆ) ผ่าน `L.applyStyle()` | 1 |
| ระบบเวลา | ไม่มี | `src/ServerScriptService/DayNight.server.lua` วันละ 30 นาทีจริง ติดตั้งใน Studio แล้ว | 10 (เอกสาร) |
| น้ำชนพื้นที่ว่าง | ไม่รู้ | ห้ามให้น้ำแตะ chunk ที่ไม่เคยเขียน (spike สามเหลี่ยม) → `waterMargin` + `L.seaSlab` มีขอบทราย | 2 |
| Play mode | ไม่รู้ | ระหว่างผู้ใช้ Play สั่ง Edit ไม่ได้ `run-luau.js` คืน exit 3 → วนรอ | ทุก Task |

ค่าที่วัดได้: WriteVoxels 60 ก้อน 1.0 s; สนามทดสอบ 186 ก้อน + สิ่งก่อสร้าง 10 s; execute_luau payload 55 KB ผ่าน
