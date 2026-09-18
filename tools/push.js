// usage: node tools/push.js src/<path>.lua [more files...]
//
// Pushes a local script's Source straight into the open place (Edit mode) when the Rojo plugin has dropped
// its connection -- which it does silently mid-session. Maps the src/ path to the instance the same way
// default.project.json does, and writes Source through execute_luau. Verifies by length afterwards.
const fs = require("fs");
const path = require("path");
const connect = require("./mcp-client");

const ROOTS = {
  ServerScriptService: "game.ServerScriptService",
  ReplicatedStorage: "game.ReplicatedStorage",
  StarterGui: "game.StarterGui",
  StarterPlayerScripts: "game.StarterPlayer.StarterPlayerScripts",
};

function instancePath(file) {
  const rel = path.relative("src", path.resolve(file)).split(path.sep);
  const root = ROOTS[rel[0]];
  if (!root) throw new Error("not under a known src root: " + file);
  const parts = rel.slice(1);
  const last = parts[parts.length - 1].replace(/\.(server|client)?\.?lua$/, "").replace(/\.lua$/, "");
  parts[parts.length - 1] = last;
  return root + parts.map((p) => `["${p}"]`).join("");
}

(async () => {
  const c = await connect();
  for (const file of process.argv.slice(2)) {
    const src = fs.readFileSync(file, "utf8").replace(/\r\n/g, "\n");
    const target = instancePath(file);
    // A long bracket the source cannot contain: pick a level no ]=*] in the file matches.
    let eq = "=";
    while (src.includes("]" + eq + "]")) eq += "=";
    const code = `if game.PlaceId ~= 88774255487951 then return "REFUSED" end
local inst = ${target}
inst.Source = [${eq}[${src}]${eq}]
return inst:GetFullName() .. " len=" .. #inst.Source`;
    const text = c.text(await c.tool("execute_luau", { datamodel_type: "Edit", code }));
    console.log(file, "->", text, "(local", Buffer.byteLength(src), ")");
  }
  c.close();
  process.exit();
})().catch((e) => {
  console.error(e.message);
  process.exit(1);
});
setTimeout(() => { console.error("timeout"); process.exit(1); }, 120000);
