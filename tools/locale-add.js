// usage: node tools/locale-add.js <translations.json>
// รวมคำแปลเข้า src/ReplicatedStorage/LocaleData/{en,zh,ja}.lua แล้วเขียนใหม่เรียงตามกุญแจ (ระบบหลายภาษา 2026-10-05)
// JSON: { "ประโยคไทย": { "en": "...", "zh": "...", "ja": "..." }, ... } · กุญแจที่มีอยู่แล้วถูกแทนที่
const fs = require("fs");
const path = require("path");

const ROOT = path.resolve(__dirname, "..");
const NAMES = { en: "อังกฤษ", zh: "จีนตัวย่อ", ja: "ญี่ปุ่น" };
const incoming = JSON.parse(fs.readFileSync(process.argv[2], "utf8"));

for (const lang of Object.keys(NAMES)) {
  const file = path.join(ROOT, "src/ReplicatedStorage/LocaleData", lang + ".lua");
  const map = new Map();
  const re = /\[("(?:[^"\\]|\\.)*")\]\s*=\s*("(?:[^"\\]|\\.)*")/g;
  let m;
  const text = fs.existsSync(file) ? fs.readFileSync(file, "utf8") : "";
  while ((m = re.exec(text))) map.set(JSON.parse(m[1]), JSON.parse(m[2]));
  let added = 0;
  for (const [thai, tr] of Object.entries(incoming)) {
    if (typeof tr[lang] !== "string") throw new Error(`ขาดคำแปล ${lang}: ${thai}`);
    if (!map.has(thai)) added++;
    map.set(thai, tr[lang]);
  }
  const keys = [...map.keys()].sort();
  const body = keys.map((k) => `\t[${JSON.stringify(k)}] = ${JSON.stringify(map.get(k))},`).join("\n");
  fs.writeFileSync(file,
    `-- ประโยคไทยต้นฉบับ → ${NAMES[lang]} · ตัวคั่น %… ต้องครบและเรียงเท่าต้นฉบับ (tools/locale-check.js ตรวจ)\n` +
    `-- เพิ่มคำแปลด้วย tools/locale-add.js (ไฟล์นี้ถูกเขียนใหม่เรียงตามกุญแจ)\nreturn {\n${body}\n}\n`);
  console.log(`${lang}: ${keys.length} keys (+${added})`);
}
