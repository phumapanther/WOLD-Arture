// ponytail: tiny stdio MCP client for Roblox Studio. usage: node mcp-call.js list | node mcp-call.js <tool> '<json args>'  (MCP_VERBOSE=1 for proxy logs)
const { spawn } = require("child_process");
const [tool = "list", argsJson = "{}"] = process.argv.slice(2);
const p = spawn("cmd.exe", ["/c", require("path").join(process.env.LOCALAPPDATA, "Roblox", "mcp.bat"), ...(process.env.MCP_VERBOSE ? ["-v"] : [])], { stdio: ["pipe", "pipe", "inherit"] });
let buf = "", id = 0;
const pending = {};
const send = (m) => p.stdin.write(JSON.stringify(m) + "\n");
const call = (method, params) => new Promise((res) => { pending[++id] = res; send({ jsonrpc: "2.0", id, method, params }); });
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
p.stdout.on("data", (d) => {
  buf += d;
  let i;
  while ((i = buf.indexOf("\n")) >= 0) {
    const line = buf.slice(0, i); buf = buf.slice(i + 1);
    if (!line.trim()) continue;
    const m = JSON.parse(line);
    if (m.id && pending[m.id]) pending[m.id](m);
  }
});
(async () => {
  await call("initialize", { protocolVersion: "2025-06-18", capabilities: {}, clientInfo: { name: "mcp-call", version: "0" } });
  send({ jsonrpc: "2.0", method: "notifications/initialized" });
  // proxy answers "Unable to reach Studio" if called before its WS link is up; tools list arrives once linked
  let tools = [];
  for (let t = 0; t < 40 && tools.length === 0; t++) { await sleep(250); tools = (await call("tools/list", {})).result.tools; }
  if (tool === "list") for (const t of tools) console.log(t.name, JSON.stringify(t.inputSchema.properties || {}));
  else { const r = await call("tools/call", { name: tool, arguments: JSON.parse(argsJson) }); console.log(JSON.stringify(r.result ?? r.error, null, 1)); }
  p.kill(); process.exit(0);
})();
setTimeout(() => { console.error("timeout"); p.kill(); process.exit(1); }, 60000);
