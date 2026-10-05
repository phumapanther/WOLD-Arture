// usage: node tools/locale-check.js [--server <file> ...] <client-file> ...
//
// ตรวจตารางคำแปล src/ReplicatedStorage/LocaleData/{en,zh,ja}.lua (ระบบหลายภาษา 2026-10-05)
//   MISMATCH  คำแปลมีตัวคั่น %… ไม่ตรง/ไม่เรียงเท่าต้นฉบับไทย          → exit 1
//   MISSING   สตริงไทยในไฟล์ที่ระบุ ไม่มีคำแปลในภาษาใดภาษาหนึ่ง        → exit 1
//   BARE      ไฟล์ไคลเอนต์: สตริงไทยขึ้นจอโดยไม่ผ่าน L(...)/Locale.T     → exit 1
//   CONCAT    สตริงไทยต่อด้วย `..` (แปลทั้งประโยคไม่ได้ ควรเปลี่ยนเป็น format) → เตือนอย่างเดียว
// ไฟล์หลัง --server = ฝั่งเซิร์ฟ/ข้อมูล: ไม่ต้องครอบ L (ไคลเอนต์แปลตอนแสดงด้วย Locale.Show) แต่ทุกสตริงไทยต้องมีคำแปล
// ไม่นับ: คอมเมนต์ · บรรทัด print/warn · บรรทัดที่มี `-- locale: skip`
const fs = require("fs");
const path = require("path");

const ROOT = path.resolve(__dirname, "..");
const LANGS = ["en", "zh", "ja"];
const THAI = /[฀-๿]/;

function readTable(lang) {
  const file = path.join(ROOT, "src/ReplicatedStorage/LocaleData", lang + ".lua");
  const text = fs.readFileSync(file, "utf8");
  const map = new Map();
  const re = /\[("(?:[^"\\]|\\.)*")\]\s*=\s*("(?:[^"\\]|\\.)*")/g;
  let m;
  while ((m = re.exec(text))) map.set(JSON.parse(m[1]), JSON.parse(m[2]));
  return map;
}

const specs = (s) => (s.match(/%[-\d.]*[sdfq%]/g) || []).join(" ");

// สตริงในบรรทัด (ตัดคอมเมนต์ที่อยู่นอกสตริง) → [{ text, start, end }]
function literals(line) {
  const out = [];
  let i = 0;
  while (i < line.length) {
    const c = line[i];
    if (c === "-" && line[i + 1] === "-") break;
    if (c === '"' || c === "'") {
      let j = i + 1, s = "";
      while (j < line.length && line[j] !== c) {
        if (line[j] === "\\") { s += line[j + 1] === "n" ? "\n" : line[j + 1]; j += 2; continue; }
        s += line[j++];
      }
      out.push({ text: s, start: i, end: j + 1 });
      i = j + 1;
      continue;
    }
    i++;
  }
  return out;
}

const tables = Object.fromEntries(LANGS.map((l) => [l, readTable(l)]));
const problems = [];
const warnings = [];

for (const lang of LANGS) {
  for (const [thai, tr] of tables[lang]) {
    if (specs(thai) !== specs(tr)) problems.push(`MISMATCH ${lang} ${JSON.stringify(thai)} → ${JSON.stringify(tr)}`);
  }
}

let server = false;
let used = 0;
for (const arg of process.argv.slice(2)) {
  if (arg === "--server") { server = true; continue; }
  const file = path.resolve(ROOT, arg);
  const lines = fs.readFileSync(file, "utf8").split(/\r?\n/);
  lines.forEach((line, n) => {
    if (/^\s*--/.test(line) || /\b(print|warn)\s*\(/.test(line) || line.includes("locale: skip")) return;
    for (const lit of literals(line)) {
      if (!THAI.test(lit.text)) continue;
      used++;
      const where = `${path.relative(ROOT, file)}:${n + 1}`;
      const before = line.slice(0, lit.start);
      const after = line.slice(lit.end);
      if (/\.\.\s*$/.test(before) || /^\s*\.\./.test(after)) warnings.push(`CONCAT ${where} ${JSON.stringify(lit.text)}`);
      if (!server && !/(\bL|Locale\.T\([^,]*,|Locale\.L)\(\s*$/.test(before) && !/\bLocale\.T\([^,]+,\s*$/.test(before)) {
        problems.push(`BARE ${where} ${JSON.stringify(lit.text)}`);
      }
      for (const lang of LANGS) {
        if (!tables[lang].has(lit.text)) problems.push(`MISSING ${lang} ${where} ${JSON.stringify(lit.text)}`);
      }
    }
  });
}

for (const w of warnings) console.log(w);
for (const p of problems) console.log(p);
const keys = tables.en.size;
console.log(problems.length === 0
  ? `OK ${keys} keys · ${used} Thai strings checked · 0 missing`
  : `FAIL ${problems.length} problems (${keys} keys · ${used} Thai strings checked)`);
process.exit(problems.length === 0 ? 0 : 1);
