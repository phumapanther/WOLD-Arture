// build-map-image.js: วัดโลกจริงทั้งแมพเป็นกริดสำหรับวาดรูปแผนที่ v2 → assets/map/samples.txt.gz
//
//   WOLD_PLACE=88774255487951 node tools/build-map-image.js [cells-per-side]   (default 1024 · Studio เปิดเพลสหลักโหมด Edit)
//
// แล้ววาดรูปด้วย tools/render-map.py · ทีละแถบเพราะ execute_luau ตัดคำตอบที่ 100KB (เหตุผลเดียวกับ build-map-terrain.js)
// ทุกแถวถูกตรวจความยาวก่อนเก็บ — แถบที่ถูกตัดกลางทาง = แบ่งครึ่งแล้วถามใหม่ ไม่เขียนแถวขาดลงไฟล์
const fs = require("fs");
const path = require("path");
const zlib = require("zlib");
const connect = require("./mcp-client");

const N = Number(process.argv[2] || 1024);
if (!Number.isInteger(N) || N < 16 || N > 4095) {
  console.error("cells-per-side must be a whole number between 16 and 4095");
  process.exit(1);
}
const template = fs.readFileSync(path.join(__dirname, "sample-map.lua"), "utf8");
const NOT_READY = /No Roblox Studio instances|Unable to reach Roblox Studio|Target is not reachable/;
const START_ROWS = Math.max(1, Math.floor(16384 / N)); // 4 ตัวต่อช่อง → ~64KB เทอร์เรน + ที่ว่างให้สิ่งก่อสร้าง

function validRow(row) {
  const bar = row.indexOf("|");
  const cells = bar < 0 ? row : row.slice(0, bar);
  const extra = bar < 0 ? "" : row.slice(bar + 1);
  return cells.length === N * 4 && extra.length % 6 === 0 && /^[A-Za-z0-9+/]*$/.test(cells + extra);
}

(async () => {
  const c = await connect();
  const rows = [];
  const totals = { land: 0, water: 0, miss: 0, built: 0 };
  let from = 1, size = START_ROWS;
  while (from <= N) {
    const to = Math.min(N, from + size - 1);
    const code = template
      .replace(/^local N = \d+ *-- __N__$/m, `local N = ${N}`)
      .replace(/^local FROM = \d+ *-- __FROM__$/m, `local FROM = ${from}`)
      .replace(/^local TO = \d+ *-- __TO__$/m, `local TO = ${to}`);
    let text = "";
    for (let attempt = 1; attempt <= 10; attempt++) {
      text = c.text(await c.tool("execute_luau", { datamodel_type: "Edit", code }));
      if (!NOT_READY.test(text)) break;
      await new Promise((r) => setTimeout(r, 4000));
    }
    const nl = text.indexOf("\n");
    const m = text.slice(0, nl).match(/^BAND (\d+) (\d+) (\d+) land=(\d+) water=(\d+) miss=(\d+) built=(\d+)$/);
    const band = nl < 0 ? [] : text.slice(nl + 1).split(";");
    if (!m || band.length !== to - from + 1 || !band.every(validRow)) {
      if (size === 1) {
        console.error(`row ${from} came back wrong:\n${text.slice(0, 400)}`);
        process.exit(1);
      }
      size = Math.max(1, Math.floor(size / 2));
      process.stdout.write(`rows ${from}-${to}: answer cut short, retrying with ${size} rows\n`);
      continue;
    }
    totals.land += +m[4]; totals.water += +m[5]; totals.miss += +m[6]; totals.built += +m[7];
    rows.push(...band);
    from = to + 1;
    size = START_ROWS;
    if (rows.length % 128 === 0 || from > N) process.stdout.write(`rows ${rows.length} of ${N}\n`);
  }
  const dir = path.join(__dirname, "..", "assets", "map");
  fs.mkdirSync(dir, { recursive: true });
  const body = `N ${N}\n` + rows.join("\n") + "\n";
  const target = path.join(dir, "samples.txt.gz");
  fs.writeFileSync(target, zlib.gzipSync(body, { level: 9 }));
  console.log(`\n${N}x${N}: land=${totals.land} water=${totals.water} miss=${totals.miss} built=${totals.built}`);
  console.log(`wrote ${target} (${(fs.statSync(target).size / 1024).toFixed(0)} KB gz, ${(body.length / 1048576).toFixed(1)} MB raw)`);
  c.close();
  process.exit();
})().catch((e) => {
  console.error(e.message);
  process.exit(1);
});
