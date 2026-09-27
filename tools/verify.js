// usage: node tools/verify.js <project.json> [--push]
//
//   node tools/verify.js default.project.json           เพลสหลัก   (WOLD_PLACE ไม่ต้องตั้ง — ค่าเริ่มต้นของ mcp-client)
//   node tools/verify.js farming.project.json           เพลสเกาะ   (เลือกหน้าต่างจาก servePlaceIds ให้เอง)
//   node tools/verify.js arena.project.json --push      เพลสสนาม + ดันไฟล์ที่ไม่ตรงด้วย tools/push.js
//
// เทียบ "สคริปต์ที่เพลสนี้ควรมี" (ทุกไฟล์ใต้ src/ ที่ project แมป ลบ globIgnorePaths) กับ Source ใน Studio
// ด้วยแฮช FNV-1a 32 บิตหลังแปลง CRLF → LF ทั้งสองฝั่ง · พิมพ์เฉพาะที่ไม่ตรง/หายไป + สรุป `mismatches N`
// (ตัวแทนของ dump_all + cmp ในสแครชแพดของเฟสก่อนๆ ที่ต้องเขียนใหม่ทุกครั้ง)
const fs = require("fs");
const path = require("path");
const { execFileSync } = require("child_process");
const connect = require("./mcp-client");

const [projectFile, ...flags] = process.argv.slice(2);
if (!projectFile) {
  console.error("usage: node tools/verify.js <project.json> [--push]");
  process.exit(1);
}
const project = JSON.parse(fs.readFileSync(projectFile, "utf8"));
const ignore = new Set((project.globIgnorePaths || []).map((p) => p.replace(/\\/g, "/")));
const placeId = (project.servePlaceIds || [])[0];
if (placeId && !process.env.WOLD_PLACE) process.env.WOLD_PLACE = String(placeId);

const ROOTS = {
  "src/ServerScriptService": "game.ServerScriptService",
  "src/ReplicatedStorage": "game.ReplicatedStorage",
  "src/StarterGui": "game.StarterGui",
  "src/StarterPlayerScripts": "game.StarterPlayer.StarterPlayerScripts",
};

function fnv(text) {
  const bytes = Buffer.from(text, "utf8");
  let h = 0x811c9dc5;
  for (const b of bytes) {
    h ^= b;
    h = Math.imul(h, 0x01000193) >>> 0;
  }
  return h >>> 0;
}

function walk(dir, out) {
  if (!fs.existsSync(dir)) return;
  for (const name of fs.readdirSync(dir)) {
    const full = path.join(dir, name);
    if (fs.statSync(full).isDirectory()) walk(full, out);
    else if (name.endsWith(".lua")) out.push(full.replace(/\\/g, "/"));
  }
}

const files = [];
for (const root of Object.keys(ROOTS)) walk(root, files);
const expected = files.filter((f) => !ignore.has(f)).map((f) => {
  const root = Object.keys(ROOTS).find((r) => f.startsWith(r + "/"));
  const parts = f.slice(root.length + 1).split("/");
  parts[parts.length - 1] = parts[parts.length - 1].replace(/\.(server|client)\.lua$/, "").replace(/\.lua$/, "");
  const src = fs.readFileSync(f, "utf8").replace(/\r\n/g, "\n");
  return { file: f, path: ROOTS[root] + parts.map((p) => `["${p}"]`).join(""), hash: fnv(src), len: Buffer.byteLength(src) };
});

// ฝั่ง Studio: แฮชแบบเดียวกัน (bit32 · ไบต์ของสตริง UTF-8) คืนทีละบรรทัด "index hash len" หรือ "index missing"
const LUAU = `
local paths = { ${expected.map((e) => `function() return ${e.path} end`).join(",\n")} }
local out = {}
local function fnv(s)
  local h = 0x811c9dc5
  for i = 1, #s do
    h = bit32.bxor(h, string.byte(s, i))
    -- คูณ 0x01000193 (= 2^24 + 403) แบบ 32 บิต: h*403 < 2^53 จึงแม่นในทศนิยม · h*2^24 mod 2^32 = (h & 0xff) << 24
    h = (h * 403 + bit32.lshift(bit32.band(h, 0xff), 24)) % 4294967296
  end
  return h
end
for i, get in ipairs(paths) do
  local ok, inst = pcall(get)
  if ok and inst and inst:IsA("LuaSourceContainer") then
    local s = string.gsub(inst.Source, "\\r\\n", "\\n")
    out[#out + 1] = i .. " " .. fnv(s) .. " " .. #s
  else
    out[#out + 1] = i .. " missing"
  end
end
return #paths .. "\\n" .. table.concat(out, "\\n")
`;

(async () => {
  const c = await connect();
  let text = "";
  for (let attempt = 0; attempt < 6; attempt++) {
    text = c.text(await c.tool("execute_luau", { datamodel_type: "Edit", code: LUAU }));
    if (!/Target is not reachable|No Roblox Studio|Unable to reach/.test(text)) break;
    await new Promise((r) => setTimeout(r, 3000));
  }
  c.close();
  const lines = text.trim().split(/\r?\n/);
  const count = Number(lines.shift());
  if (count !== expected.length || lines.length !== expected.length) {
    console.error(`คำตอบไม่ครบ (${lines.length}/${expected.length}) — execute_luau อาจตัดผลลัพธ์:\n${text.slice(0, 500)}`);
    process.exit(2);
  }
  const bad = [];
  for (const line of lines) {
    const [i, h, len] = line.split(" ");
    const e = expected[Number(i) - 1];
    if (h === "missing") bad.push({ e, why: "missing" });
    else if (Number(h) !== e.hash) bad.push({ e, why: `hash ${h} ≠ ${e.hash} (len ${len} vs ${e.len})` });
  }
  for (const b of bad) console.log(`${b.e.file}  ${b.why}`);
  console.log(`${process.env.WOLD_PLACE}: ${expected.length} ไฟล์ · mismatches ${bad.length}`);
  if (bad.length && flags.includes("--push")) {
    console.log("ดันไฟล์ที่ไม่ตรง...");
    const out = execFileSync("node", [path.join(__dirname, "push.js"), ...bad.map((b) => b.e.file)], { env: process.env, encoding: "utf8" });
    console.log(out.trim());
  }
  process.exit(bad.length ? 1 : 0);
})().catch((e) => { console.error(e.message); process.exit(1); });
