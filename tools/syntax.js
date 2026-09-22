// usage: node tools/syntax.js src/<file>.lua ...
//
// Compiles each file inside Studio (Edit mode) without running it: the source is wrapped in
// `return function() ... end` inside a throwaway, unparented, Sandboxed ModuleScript that the assistant
// thread is allowed to require. A syntax error surfaces as the require error.
const fs = require("fs");
const connect = require("./mcp-client");
(async () => {
  const c = await connect();
  for (const file of process.argv.slice(2)) {
    const src = fs.readFileSync(file, "utf8").replace(/\r\n/g, "\n");
    let eq = "=";
    while (src.includes("]" + eq + "]")) eq += "=";
    const code = `if game.PlaceId ~= 88774255487951 and game.PlaceId ~= 136992335889132 then return "REFUSED" end
local m = Instance.new("ModuleScript")
m.Name = "SyntaxCheck_" .. math.random(1, 1e9)
-- Sandboxed: the assistant thread may only require sandboxed modules (everything in the place carries
-- Capabilities it lacks); a sandboxed module still compiles its whole source on require.
m.Sandboxed = true
m.Source = "return function()" .. string.char(10) .. [${eq}[${src}]${eq}] .. string.char(10) .. "end"
local ok, err = pcall(require, m)
m:Destroy()
return ok and "OK" or ("FAIL " .. tostring(err))`;
    let text = "";
    for (let i = 0; i < 6; i++) {
      text = c.text(await c.tool("execute_luau", { datamodel_type: "Edit", code }));
      if (!/Target is not reachable|No Roblox Studio|Unable to reach/.test(text)) break;
      await new Promise((r) => setTimeout(r, 3000));
    }
    console.log(file, "->", text);
  }
  c.close();
  process.exit();
})().catch((e) => { console.error(e.message); process.exit(1); });
setTimeout(() => { console.error("timeout"); process.exit(1); }, 120000);
