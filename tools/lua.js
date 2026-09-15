// usage: node tools/lua.js <file.lua> [Edit|Server|Client]
//
// Runs a Luau file in Studio and prints whatever it returns. No concatenated lib, no world-layout, no polling
// of WOLD attributes -- that is what run-luau.js is for, and a phase is the only thing that needs it.
//
// This exists for the other half of the work: probing. "What is actually in this place", "did the tag land",
// "where is Baron Vane standing" are one-line questions whose answer is a return value, and passing multi-line
// Luau through a shell argument mangles it (every backslash-n arrives as a literal backslash and an n, and
// Studio answers "Failed to parse command code").
//
// Reading the code from a FILE is the whole point: nothing goes through the shell but a path.
const fs = require("fs");
const path = require("path");
const connect = require("./mcp-client");

const [file, datamodel = "Edit"] = process.argv.slice(2);
if (!file) {
  console.error("usage: node tools/lua.js <file.lua> [Edit|Server|Client]");
  process.exit(1);
}

const code = fs.readFileSync(path.resolve(file), "utf8");

(async () => {
  const c = await connect();
  // Three different "not ready yet" answers, none of them a real failure, all of them fixed by asking again:
  //
  //   "No Roblox Studio instances are connected"  the proxy's websocket is still coming up
  //   "Unable to reach Roblox Studio"             same, seen from the other side
  //   "Target is not reachable (...loadCodeAsync)" Studio is linked but its script-running bridge is not warm
  //                                                yet -- measured at five failures then success after a
  //                                                fresh Studio start, and preview-anim.js hits it too
  //
  // Retried here rather than in every caller, because every caller was wrapping it in the same loop.
  const NOT_READY = /No Roblox Studio instances|Unable to reach Roblox Studio|Target is not reachable/;
  let text = "";
  for (let attempt = 1; attempt <= 10; attempt++) {
    text = c.text(await c.tool("execute_luau", { datamodel_type: datamodel, code }));
    if (!NOT_READY.test(text)) break;
    if (attempt < 10) await new Promise((r) => setTimeout(r, 4000));
  }
  console.log(text);
  c.close();
  process.exit();
})().catch((e) => {
  console.error(e.message);
  process.exit(1);
});

setTimeout(() => {
  console.error("timeout");
  process.exit(1);
}, 300000);
