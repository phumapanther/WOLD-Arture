// usage: node tools/bundle.js [mapgen/base_terrain.lua] [dist/arture-base-terrain.lua]
// Bundles world-layout.json + lib.lua + a phase file into ONE Luau script that runs without the MCP runner
// (paste into a Script under ServerScriptService in any place and press Run, or use the Studio command bar).
const fs = require("fs"), path = require("path");
const root = path.join(__dirname, "..");
const [phase = "mapgen/base_terrain.lua", out = "dist/arture-base-terrain.lua"] = process.argv.slice(2);
const read = (p) => fs.readFileSync(path.join(root, p), "utf8");
const header = `-- WOLD Arture: bundled map generator (${new Date().toISOString().slice(0, 10)}). Source: github WOLD-Arture repo, tag base-terrain-v1.
-- HOW TO USE: Roblox Studio -> open any place -> insert a Script in ServerScriptService -> paste this whole file -> press Run (server) or Play.
--             Progress is shown in the Output window as [WOLD] lines; the island takes ~5 minutes at full scale.
--             Delete the Script afterwards (the terrain stays in the place). Set SCALE = 0.125 below for a 1/8 preview.
local SCALE = 1
`;
const body = `local LAYOUT_JSON = [==[${read("docs/design/world-layout.json")}]==]\n${read("mapgen/lib.lua")}\n${read(phase)}\n`;
fs.mkdirSync(path.join(root, path.dirname(out)), { recursive: true });
fs.writeFileSync(path.join(root, out), header + body);
console.log(`bundled ${phase} -> ${out} (${((header + body).length / 1024).toFixed(0)} KB)`);
