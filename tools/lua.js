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
  // The proxy reports "No Roblox Studio instances are connected" for a few seconds after Studio opens, and
  // sometimes between calls, while its websocket is still coming up. It is not a real failure -- the same
  // call succeeds on the next attempt -- so retry rather than making every caller wrap this themselves.
  let text = "";
  for (let attempt = 1; attempt <= 6; attempt++) {
    text = c.text(await c.tool("execute_luau", { datamodel_type: datamodel, code }));
    if (!/No Roblox Studio instances|Unable to reach Roblox Studio/.test(text)) break;
    if (attempt < 6) await new Promise((r) => setTimeout(r, 3000));
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
