// usage: node tools/locale-add.js <translations.json>
// รวมคำแปลเข้า src/ReplicatedStorage/LocaleData/<lang>_<n>.lua แล้วเขียนใหม่เรียงตามกุญแจ (ระบบหลายภาษา 2026-10-05)
// JSON: { "ประโยคไทย": { "en": "...", "zh": "...", "ja": "..." }, ... } · กุญแจที่มีอยู่แล้วถูกแทนที่
// ⚠️ Roblox รับ Source ได้ไม่เกิน 200,000 ตัวอักษร → แต่ละภาษาแบ่งเป็นหลายไฟล์ ไฟล์ละไม่เกิน CHUNK ไบต์ (ขีดของ Roblox นับเป็นไบต์ ไทย 1 ตัว = 3 ไบต์)
//    (Locale.lua รวมทุกไฟล์ที่ชื่อ <lang> หรือ <lang>_<เลข>)
const fs = require("fs");
const path = require("path");

const ROOT = path.resolve(__dirname, "..");
const DIR = path.join(ROOT, "src/ReplicatedStorage/LocaleData");
const NAMES = { en: "อังกฤษ", zh: "จีนตัวย่อ", ja: "ญี่ปุ่น" };
const CHUNK = 150000;
const incoming = JSON.parse(fs.readFileSync(process.argv[2], "utf8"));

// ล็อก: หลายเซสชัน/เอเจนต์รวมคำแปลพร้อมกันได้โดยไม่ทับกัน (mkdir เป็น atomic) · ล็อกค้างเกิน 60 วิ = ทิ้ง
const LOCK = path.join(DIR, ".locale-add.lock");
const sleep = (ms) => Atomics.wait(new Int32Array(new SharedArrayBuffer(4)), 0, 0, ms);
for (let tries = 0; ; tries++) {
  try { fs.mkdirSync(LOCK); break; } catch (e) {
    if (e.code !== "EEXIST") throw e;
    try { if (Date.now() - fs.statSync(LOCK).mtimeMs > 60000) fs.rmSync(LOCK, { recursive: true, force: true }); } catch {}
    if (tries > 600) throw new Error("locale-add: ล็อกค้าง " + LOCK);
    sleep(100);
  }
}
process.on("exit", () => { try { fs.rmdirSync(LOCK); } catch {} });

const filesOf = (lang) => fs.readdirSync(DIR).filter((f) => new RegExp(`^${lang}(_\\d+)?\\.lua$`).test(f));

for (const lang of Object.keys(NAMES)) {
  const map = new Map();
  const re = /\[("(?:[^"\\]|\\.)*")\]\s*=\s*("(?:[^"\\]|\\.)*")/g;
  for (const f of filesOf(lang)) {
    const text = fs.readFileSync(path.join(DIR, f), "utf8");
    let m;
    while ((m = re.exec(text))) map.set(JSON.parse(m[1]), JSON.parse(m[2]));
  }
  let added = 0;
  for (const [thai, tr] of Object.entries(incoming)) {
    if (typeof tr[lang] !== "string") throw new Error(`ขาดคำแปล ${lang}: ${thai}`);
    if (!map.has(thai)) added++;
    map.set(thai, tr[lang]);
  }
  const keys = [...map.keys()].sort();
  const chunks = [[]];
  let size = 0;
  for (const k of keys) {
    const line = `\t[${JSON.stringify(k)}] = ${JSON.stringify(map.get(k))},`;
    if (size + Buffer.byteLength(line) > CHUNK && chunks[chunks.length - 1].length) { chunks.push([]); size = 0; }
    chunks[chunks.length - 1].push(line);
    size += Buffer.byteLength(line) + 1;
  }
  const written = new Set();
  chunks.forEach((lines, i) => {
    const name = `${lang}_${i + 1}.lua`;
    const file = path.join(DIR, name);
    fs.writeFileSync(file + ".tmp",
      `-- ประโยคไทยต้นฉบับ → ${NAMES[lang]} (ส่วนที่ ${i + 1}/${chunks.length}) · ตัวคั่น %… ต้องครบและเรียงเท่าต้นฉบับ (tools/locale-check.js ตรวจ)\n` +
      `-- เพิ่มคำแปลด้วย tools/locale-add.js (ไฟล์นี้ถูกเขียนใหม่เรียงตามกุญแจ · แบ่งไฟล์เพราะ Source เกิน 200,000 ไม่ได้)\nreturn {\n${lines.join("\n")}\n}\n`);
    fs.renameSync(file + ".tmp", file); // แทนที่ทั้งไฟล์ทีเดียว คนอ่านระหว่างนั้นไม่เห็นไฟล์ครึ่งๆ
    written.add(name);
  });
  for (const f of filesOf(lang)) if (!written.has(f)) fs.unlinkSync(path.join(DIR, f)); // ส่วนเก่าที่ไม่ใช้แล้ว
  console.log(`${lang}: ${keys.length} keys (+${added}) · ${chunks.length} files`);
}
