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
    if (!img) { console.log(JSON.stringify(r, null, 1).slice(0, 4000)); process.exitCode = 1; }
    else {
      const dir = path.join(__dirname, "..", "docs", "shots"); fs.mkdirSync(dir, { recursive: true });
      const out = path.join(dir, name + ".png"); fs.writeFileSync(out, Buffer.from(img.data, "base64")); console.log("saved", out);
    }
  } else console.log(JSON.stringify(await c.tool(cmd, JSON.parse(rest[0] ?? "{}")), null, 1));
  c.close(); process.exit();
})().catch((e) => { console.error(e.message); process.exit(1); });
setTimeout(() => { console.error("timeout"); process.exit(1); }, 300000);
