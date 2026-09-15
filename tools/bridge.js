// bridge: holds one MCP proxy open for the whole session.
//
// The Studio side of the link is a CLIENT: with "Studio as MCP server" on, Studio dials
// ws://127.0.0.1:13469 and keeps retrying with a growing backoff. A proxy that only lives for the
// length of one command (mcp-call.js, model.js) has to win a race against that backoff, and after
// Studio has been retrying for a while it loses. Keep one proxy listening and Studio latches on
// once; every later proxy relays through this one.
//
//   node tools/bridge.js        run it in the background, leave it running
//
// Copied from the WOLD-Models project, which hit this first. Symptom here, before it existed: every call
// through mcp-call.js answered "No Roblox Studio instances are connected" while netstat showed nothing
// LISTENING on 13469 -- only TIME_WAIT leftovers from proxies that had already exited. Occasionally a call
// would work, which is the race being won by luck, and that made it look like Studio was at fault.
const { spawn } = require("child_process");
const path = require("path");

const p = spawn("cmd.exe", ["/c", path.join(process.env.LOCALAPPDATA, "Roblox", "mcp.bat")],
  { stdio: ["pipe", "pipe", "inherit"] });
let buf = "", id = 0;
const pending = {};
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
p.on("exit", (c) => { console.log("proxy exited", c); process.exit(c ?? 1); });

(async () => {
  await call("initialize", { protocolVersion: "2025-06-18", capabilities: {}, clientInfo: { name: "wold-bridge", version: "0" } });
  send({ jsonrpc: "2.0", method: "notifications/initialized" });
  console.log("bridge up, waiting for Studio to dial in...");
  let linked = false;
  for (;;) {
    const tools = (await call("tools/list", {})).result?.tools ?? [];
    if (tools.length > 0 !== linked) {
      linked = tools.length > 0;
      console.log(new Date().toISOString().slice(11, 19), linked ? `LINKED (${tools.length} tools)` : "link lost");
    }
    await new Promise((r) => setTimeout(r, 2000));
  }
})();
