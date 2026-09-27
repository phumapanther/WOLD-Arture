// usage: node tools/offline-test.js tests/<name>_test.lua [more tests...]
//
// รันเทส "ข้อมูลล้วน" โดยไม่ต้องเปิด Studio (ใช้ตอน MCP หลุด) ด้วย Luau CLI แบบ portable ที่ ~/tools/luau
// จำลองแค่ส่วนที่เทสพวกนี้ใช้: ต้นไม้ instance ขนาดเล็ก (ModuleScript/Folder/Part + Clone/Parent/Destroy/require แบบ
// ไม่แคชข้ามสำเนา เหมือน Studio) · ReplicatedStorage/UI/ServerScriptService จากไฟล์ใน src · Vector3/CFrame(บางส่วน)/
// Color3/Enum/UDim2 · workspace:Raycast กับ Part ที่เทสสร้าง (กล่องแนวแกน) · RunService:IsStudio() = true
// **ไม่แทนเทสใน Studio** — โมดูลที่แตะ API จริง (DataStore, Players, Humanoid) รันที่นี่ไม่ได้ · ผลต่างจาก Studio = สงสัยตัวจำลองก่อน
const fs = require("fs");
const path = require("path");
const os = require("os");
const { execFileSync } = require("child_process");

const ROOT = path.resolve(__dirname, "..");
const LUAU = path.join(os.homedir(), "tools", "luau", "luau.exe");

function collect(dir, rel) {
  const out = [];
  for (const name of fs.readdirSync(dir)) {
    const full = path.join(dir, name);
    if (fs.statSync(full).isDirectory()) out.push(...collect(full, rel.concat(name)));
    else if (name.endsWith(".lua") && !name.endsWith(".server.lua") && !name.endsWith(".client.lua"))
      out.push({ path: rel.concat(name.replace(/\.lua$/, "")), file: full });
  }
  return out;
}

function longString(src) {
  let eq = "=";
  while (src.includes("]" + eq + "]")) eq += "=";
  return `[${eq}[${src}]${eq}]`;
}

const PRELUDE = fs.readFileSync(path.join(__dirname, "offline-test-prelude.lua"), "utf8");

function bundle(testFile) {
  let out = PRELUDE + "\n";
  for (const [service, dir] of [["ReplicatedStorage", "src/ReplicatedStorage"], ["ServerScriptService", "src/ServerScriptService"]]) {
    for (const m of collect(path.join(ROOT, dir), [])) {
      const src = fs.readFileSync(m.file, "utf8").replace(/\r\n/g, "\n");
      out += `__define(${JSON.stringify(service)}, {${m.path.map((x) => JSON.stringify(x)).join(", ")}}, ${longString(src)})\n`;
    }
  }
  const test = fs.readFileSync(path.join(ROOT, testFile), "utf8").replace(/\r\n/g, "\n");
  out += `__runTest(${longString(test)}, ${JSON.stringify(testFile)})\n`;
  return out;
}

let failed = false;
for (const t of process.argv.slice(2)) {
  const tmp = path.join(os.tmpdir(), "wold_offline_" + path.basename(t));
  fs.writeFileSync(tmp, bundle(t));
  try {
    const res = execFileSync(LUAU, [tmp], { encoding: "utf8", stdio: ["ignore", "pipe", "pipe"], timeout: 60000 });
    process.stdout.write(`== ${t}\n${res}\n`);
    if (/^FAIL/m.test(res) || /ERROR/.test(res)) failed = true;
  } catch (e) {
    failed = true;
    process.stdout.write(`== ${t}\nERROR ${(e.stdout || "") + (e.stderr || e.message)}\n`);
  }
}
process.exit(failed ? 1 : 0);
