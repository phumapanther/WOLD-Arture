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
  const rawTool = async (name, args) => { const r = await call("tools/call", { name, arguments: args }); return r.result ?? r.error; };
  const text = (r) => (r?.content ?? []).map((c) => c.text ?? "").join("\n");

  // with more than one Studio open the proxy demands studio_id on every call. WOLD_PLACE names the
  // target place (its id, or any part of its window title); here it defaults to the game place, so
  // work never lands in the WOLD-Models workshop place by accident.
  let studioId = process.env.WOLD_STUDIO_ID || null;
  if (!studioId) {
    let list = [];
    try { list = JSON.parse(text(await rawTool("list_roblox_studios", {})) || "{}").studios ?? []; } catch {}
    if (list.length > 1) {
      const want = process.env.WOLD_PLACE || "88774255487951";
      const hit = list.find((s) => (s.name || "").includes(want));
      if (!hit) {
        throw new Error(`several Studio windows are open and none matches "${want}":\n  ` +
          list.map((s) => s.name).join("\n  ") + `\nset WOLD_PLACE to part of the right title, or WOLD_STUDIO_ID to its id`);
      }
      studioId = hit.id;
      if (process.env.MCP_VERBOSE) console.error("studio:", hit.name);
    } else if (list.length === 1) studioId = list[0].id;
  }
  const tool = (name, args) => rawTool(name, studioId ? { ...args, studio_id: studioId } : args);
  return { tools, tool, text, studioId, close: () => p.kill() };
};
