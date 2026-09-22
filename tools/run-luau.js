// usage: node tools/run-luau.js mapgen/10_terrain.lua [--scale 0.125] [--timeout 1800] [--no-lib]
// concatenates SCALE + world-layout.json + lib.lua + phase file, runs it in Studio, polls workspace.WOLD attributes until done/error
const fs = require("fs"), path = require("path");
const connect = require("./mcp-client");
const args = process.argv.slice(2);
const file = args.find((a) => !a.startsWith("--") && !/^[\d.]+$/.test(a));
const opt = (k, d) => { const i = args.indexOf(k); return i >= 0 ? args[i + 1] : d; };
const scale = opt("--scale", "1"), timeout = Number(opt("--timeout", "1800"));
const root = path.join(__dirname, "..");
const read = (p) => fs.readFileSync(path.join(root, p), "utf8");
const NL = String.fromCharCode(10);
const lib = args.includes("--no-lib") ? "" : read("mapgen/lib.lua");
// --kit also concatenates the modelkit chain, so one phase can shape terrain with L and raise buildings with K
const kit = args.includes("--kit")
  ? `local K = (function()\n${read("modelkit/kit.lua")}\nend)()\n${read("modelkit/interior.lua")}\n${read("modelkit/interior2.lua")}\n${read("modelkit/roofs.lua")}\nlocal R = (function()\n${read("modelkit/rig.lua")}\nend)()\n${read("modelkit/armor.lua")}\n${read("modelkit/beast.lua")}\n`
  : "";
// --models loads the building generators in register-only mode, so a phase can call K.place("Village_Tavern", ...)
const models = args.includes("--models")
  ? `K.REGISTER_ONLY = true\n${["village", "houses", "city", "castle", "castle_parts", "npcs", "animals"].map((n) => read(`models/${n}.lua`)).join("\n")}\nK.REGISTER_ONLY = false\n`
  : "";
// --skins embeds the skin/fashion builders from assets/models-from-factory (each file is `return function() ... end`)
// into _G.WOLD_SKIN_BUILDERS so a phase can call them by name. These models were placed by hand in the main
// place and never travelled with Rojo, which is why the island had none of them.
const skins = args.includes("--skins")
  ? "_G.WOLD_SKIN_BUILDERS = {}" + NL + fs.readdirSync(path.join(root, "assets/models-from-factory"))
      .filter((f) => f.endsWith(".lua"))
      .map((f) => `_G.WOLD_SKIN_BUILDERS["${f.slice(0, -4)}"] = (function()` + NL + read("assets/models-from-factory/" + f) + NL + "end)()" + NL)
      .join("")
  : "";
// --furniture embeds assets/models-from-main (models COPIED OUT OF THE MAIN PLACE, part by part) into
// _G.WOLD_MAIN_MODELS. Same reason as --skins: a model is not code, so Rojo never carried it to the island
// place, and the island ended up with hand-built boxes where the main game has real furniture.
const furniture = args.includes("--furniture")
  ? "_G.WOLD_MAIN_MODELS = {}" + NL + fs.readdirSync(path.join(root, "assets/models-from-main"))
      .filter((f) => f.endsWith(".lua"))
      .map((f) => `_G.WOLD_MAIN_MODELS["${f.slice(0, -4)}"] = (function()` + NL + read("assets/models-from-main/" + f) + NL + "end)()" + NL)
      .join("")
  : "";
const code = `local SCALE = ${scale}\nlocal LAYOUT_JSON = [==[${read("docs/design/world-layout.json")}]==]\n${lib}\n${kit}\n${models}\n${skins}\n${furniture}\n${read(file)}\n`;
const POLL = `local r = workspace:FindFirstChild("WOLD"); return r and ((r:GetAttribute("Status") or "?") .. " | " .. (r:GetAttribute("Progress") or "")) or "no WOLD folder"`;
(async () => {
  const c = await connect();
  console.log(`sending ${file} (${(code.length / 1024).toFixed(0)} KB, SCALE=${scale})`);
  const first = c.text(await c.tool("execute_luau", { datamodel_type: "Edit", code }));
  console.log("execute_luau ->", first);
  if (/Play mode/i.test(first)) { console.error("Studio is in Play mode: stop Play and retry"); c.close(); process.exit(3); }
  const t0 = Date.now(); let last = "";
  while (Date.now() - t0 < timeout * 1000) {
    await new Promise((r) => setTimeout(r, 5000));
    const s = c.text(await c.tool("execute_luau", { datamodel_type: "Edit", code: POLL }));
    if (s !== last) { console.log(new Date().toISOString().slice(11, 19), s); last = s; }
    if (/\bdone\b/.test(s)) break;
    if (/error:/.test(s)) { console.log("---- console ----\n" + c.text(await c.tool("get_console_output", {})).slice(-6000)); process.exitCode = 1; break; }
  }
  if (Date.now() - t0 >= timeout * 1000) { console.error("timeout waiting for phase"); process.exitCode = 2; }
  c.close(); process.exit();
})().catch((e) => { console.error(e.message); process.exit(1); });
