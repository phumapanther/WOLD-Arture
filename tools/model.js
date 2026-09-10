#!/usr/bin/env node
// WOLD-Models CLI — drive one model at a time through Roblox Studio (Edit mode) over the Studio MCP bridge.
//
//   node tools/model.js build  <name|path>     run modelkit + models/<name>.lua into Studio
//   node tools/model.js shot   <Name> [views]  screenshots -> docs/shots/<Name>_<view>.png  (views: front,side,back,top,iso  default front,iso,side)
//   node tools/model.js export <Name>          read the model back out of Studio -> export/<Name>.lua (self-contained rebuild script)
//   node tools/model.js select <Name>          select it in Studio, ready for right-click > Save to File -> export/<Name>.rbxm
//   node tools/model.js list                   models currently in workspace.MODELKIT
//   node tools/model.js clear  [Name]          delete one model (or the whole MODELKIT folder)
const fs = require("fs");
const path = require("path");
const connect = require("./mcp-client");

const ROOT = path.join(__dirname, "..");
const read = (p) => fs.readFileSync(path.join(ROOT, p), "utf8");
const [cmd, ...rest] = process.argv.slice(2);

const lua = (c) => ({ datamodel_type: "Edit", code: c });
// kit.lua returns K; interior.lua just hangs more functions off it; rig.lua returns R and may use K
const KIT = () => `local K = (function()\n${read("modelkit/kit.lua")}\nend)()\n${read("modelkit/interior.lua")}\n${read("modelkit/interior2.lua")}\nlocal R = (function()\n${read("modelkit/rig.lua")}\nend)()\n`;

function modelPath(arg) {
  if (!arg) throw new Error("need a model name");
  const p = arg.endsWith(".lua") ? arg : path.join("models", arg + ".lua");
  if (!fs.existsSync(path.join(ROOT, p))) throw new Error(`no such model file: ${p}`);
  return p;
}

async function build(c, arg) {
  const p = modelPath(arg);
  const code = KIT() + read(p);
  console.log(`build ${p} (${(code.length / 1024).toFixed(0)} KB)`);
  const first = c.text(await c.tool("execute_luau", lua(code)));
  if (/Play mode/i.test(first)) { console.error("Studio is in Play mode — stop Play and retry"); process.exitCode = 3; return; }
  const POLL = `local r = workspace:FindFirstChild("MODELKIT"); return r and ((r:GetAttribute("Status") or "?") .. " | " .. (r:GetAttribute("Progress") or "")) or "no MODELKIT folder"`;
  let last = "";
  for (let i = 0; i < 60; i++) {
    const s = c.text(await c.tool("execute_luau", lua(POLL)));
    if (s !== last) { console.log(s); last = s; }
    if (/^done \|/.test(s) || /\| .* done - /.test(s)) break;
    if (/error:/.test(s)) {
      console.log("---- console ----\n" + c.text(await c.tool("get_console_output", {})).slice(-4000));
      process.exitCode = 1; return;
    }
    await new Promise((r) => setTimeout(r, 1000));
  }
}

const VIEWS = {                                   // unit direction the camera sits in, relative to the model centre
  front: [0, 0.18, -1], back: [0, 0.18, 1], side: [-1, 0.18, 0], right: [1, 0.18, 0],
  iso: [-0.75, 0.55, -0.75], top: [0.01, 1, 0.01], low: [-0.6, 0.12, -0.8],
  hero: [-0.42, 0.5, -1],                        // three-quarter, slightly above eye line — reads best for characters
};

const BOOTH = [-900, 8, 0];                       // empty ground far from the grid, so neighbours never block the lens

async function toBooth(c, name) {                 // park the model alone in the booth; returns its old pivot + bounds there
  const code = `local m = workspace:FindFirstChild("MODELKIT") and workspace.MODELKIT:FindFirstChild("${name}")
if not m then return "missing" end
local was = m:GetPivot()
m:PivotTo(CFrame.new(${BOOTH[0]}, ${BOOTH[1]}, ${BOOTH[2]}))
local cf, s = m:GetBoundingBox()
return string.format("%f %f %f %f %f %f %f %f %f", was.X, was.Y, was.Z, cf.X, cf.Y, cf.Z, s.X, s.Y, s.Z)`;
  const t = c.text(await c.tool("execute_luau", lua(code))).trim();
  if (t.startsWith("missing")) throw new Error(`model "${name}" is not in workspace.MODELKIT — build it first`);
  const n = t.split(/\s+/).map(Number).filter((x) => !Number.isNaN(x));
  if (n.length < 9) throw new Error("could not read bounds: " + t);
  return { was: n.slice(0, 3), c: n.slice(3, 6), s: n.slice(6, 9) };
}
const fromBooth = (c, name, was) => c.tool("execute_luau", lua(
  `local m = workspace.MODELKIT:FindFirstChild("${name}"); if m then m:PivotTo(CFrame.new(${was.join(", ")})) end; return "back"`));

async function shot(c, name, viewArg) {
  const views = (viewArg || "front,iso,side").split(",").map((v) => v.trim()).filter(Boolean);
  const b = await toBooth(c, name);
  const dir = path.join(ROOT, "docs", "shots");
  fs.mkdirSync(dir, { recursive: true });
  try {
    const radius = Math.hypot(b.s[0], b.s[1], b.s[2]) / 2;   // bounding sphere: frames any angle without clipping
    const d = radius / Math.tan(Math.PI * 35 / 180) * 1.15 + 6;   // Studio's default 70 degree FOV, small margin
    for (const v of views) {
      const u = VIEWS[v];
      if (!u) { console.error(`unknown view "${v}" — use ${Object.keys(VIEWS).join(",")}`); continue; }
      const len = Math.hypot(u[0], u[1], u[2]);
      const cam = [b.c[0] + (u[0] / len) * d, b.c[1] + (u[1] / len) * d, b.c[2] + (u[2] / len) * d];
      const id = `${name}_${v}`;
      const r = await c.tool("screen_capture", { capture_id: id, camera_position: cam, look_at_position: b.c });
      const img = (r?.content ?? []).find((x) => x.type === "image");
      if (!img) { console.error(`${id}: no image returned`, JSON.stringify(r).slice(0, 300)); continue; }
      const out = path.join(dir, id + ".png");
      fs.writeFileSync(out, Buffer.from(img.data, "base64"));
      console.log("saved", path.relative(ROOT, out));
    }
  } finally { await fromBooth(c, name, b.was); }
}

async function overview(c, name, set) {           // one shot of a whole grid; pass a set name to frame just that set
  const t = c.text(await c.tool("execute_luau", lua(`local r = workspace:FindFirstChild("MODELKIT")
if not r then return "missing" end
local want = ${set ? `"${set}"` : "nil"}
local lo, hi
for _, m in ipairs(r:GetChildren()) do
  if m:IsA("Model") and m:GetAttribute("Kit") and (want == nil or m:GetAttribute("Set") == want) then
    local cf, s = m:GetBoundingBox()
    local a, b = cf.Position - s / 2, cf.Position + s / 2
    lo = lo and Vector3.new(math.min(lo.X, a.X), math.min(lo.Y, a.Y), math.min(lo.Z, a.Z)) or a
    hi = hi and Vector3.new(math.max(hi.X, b.X), math.max(hi.Y, b.Y), math.max(hi.Z, b.Z)) or b
  end
end
if not lo then return "empty" end
local c2, s2 = (lo + hi) / 2, hi - lo
return string.format("%f %f %f %f %f %f", c2.X, c2.Y, c2.Z, s2.X, s2.Y, s2.Z)`))).trim();
  if (t.startsWith("missing") || t.startsWith("empty")) throw new Error("nothing built in workspace.MODELKIT");
  const n = t.split(/\s+/).map(Number);
  const [cx, cy, cz, sx, sy, sz] = n;
  const d = Math.max(sx, sz) * 0.95 + 60;
  const cam = [cx - d * 0.15, cy + d * 0.62, cz - d * 0.78];
  const id = name || "overview";
  const r = await c.tool("screen_capture", { capture_id: id, camera_position: cam, look_at_position: [cx, cy, cz] });
  const img = (r?.content ?? []).find((x) => x.type === "image");
  if (!img) throw new Error("no image returned");
  const dir = path.join(ROOT, "docs", "shots");
  fs.mkdirSync(dir, { recursive: true });
  fs.writeFileSync(path.join(dir, id + ".png"), Buffer.from(img.data, "base64"));
  console.log(`saved docs/shots/${id}.png — grid ${sx.toFixed(0)} x ${sz.toFixed(0)} studs`);
}

// ---- export: walk the model in Studio and emit a self-contained rebuild script ----
const DUMP = (name, from, to) => `local m = workspace.MODELKIT:FindFirstChild("${name}")
if not m then return "missing" end
local piv = m:GetPivot()
local list = {}
for _, d in ipairs(m:GetDescendants()) do if d:IsA("BasePart") then list[#list + 1] = d end end
table.sort(list, function(a, b) return a:GetFullName() < b:GetFullName() end)
if ${from} == 0 then return "COUNT " .. #list end
local function segName(inst)                      -- disambiguate same-named sibling groups, deterministically
  local n, idx = inst.Name, 1
  for _, s in ipairs(inst.Parent:GetChildren()) do
    if s == inst then break end
    if s.Name == n and not s:IsA("BasePart") then idx += 1 end
  end
  return idx > 1 and (n .. "#" .. idx) or n
end
local function relpath(inst)                      -- group path from the model root down to the part's parent
  local segs, cur = {}, inst
  while cur and cur ~= m do table.insert(segs, 1, segName(cur)); cur = cur.Parent end
  return table.concat(segs, "/")
end
local out = {}
for i = ${from}, math.min(${to}, #list) do
  local p = list[i]
  local rel = piv:ToObjectSpace(p.CFrame)
  local x, y, z, a, b2, c2, d2, e, f, g, h, k2 = rel:GetComponents()
  local shape = p:IsA("Part") and p.Shape.Name or ""
  local extra = {}
  for _, ch in ipairs(p:GetChildren()) do
    if ch:IsA("PointLight") then extra[#extra + 1] = string.format("light:%d,%d,%d,%.2f,%.2f", ch.Color.R * 255, ch.Color.G * 255, ch.Color.B * 255, ch.Range, ch.Brightness)
    elseif ch:IsA("Smoke") then extra[#extra + 1] = string.format("smoke:%.2f,%.2f,%.2f", ch.Size, ch.RiseVelocity, ch.Opacity) end
  end
  out[#out + 1] = string.format("%s\\t%s\\t%s\\t%s\\t%.4f,%.4f,%.4f\\t%.4f,%.4f,%.4f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f\\t%s\\t%d,%d,%d\\t%.3f\\t%s\\t%s",
    p.ClassName, p.Name, shape, relpath(p.Parent),
    p.Size.X, p.Size.Y, p.Size.Z, x, y, z, a, b2, c2, d2, e, f, g, h, k2,
    p.Material.Name, p.Color.R * 255, p.Color.G * 255, p.Color.B * 255, p.Transparency,
    p.CanCollide and "1" or "0", table.concat(extra, ";"))
end
return table.concat(out, "\\n")`;

const EXPORT_HEADER = (name, count) => `-- ${name} — exported from WOLD-Models on ${new Date().toISOString().slice(0, 10)} (${count} parts)
-- self-contained: no modelkit needed. Returns the Model, unparented.
--   local m = require(script.${name})()   -- or paste this file's body into a build step
-- local space: base on y = 0, centred on x/z, front = -Z.
return function()
\tlocal m = Instance.new("Model")
\tm.Name = "${name}"
\tlocal folders = {}
\tlocal function F(pathStr)
\t\tif pathStr == "" then return m end
\t\tif folders[pathStr] then return folders[pathStr] end
\t\tlocal head = pathStr:match("^(.*)/[^/]*$")
\t\tlocal f = Instance.new("Model")
\t\tf.Name = ((head and pathStr:sub(#head + 2) or pathStr):gsub("#%d+$", ""))
\t\tf.Parent = head and F(head) or m
\t\tfolders[pathStr] = f
\t\treturn f
\tend
\tlocal function P(cls, nm, shape, parent, sx, sy, sz, cf, mat, r, g, b, tr, cc, light, smoke)
\t\tlocal p = Instance.new(cls)
\t\tp.Name = nm; p.Size = Vector3.new(sx, sy, sz); p.CFrame = cf
\t\tp.Material = Enum.Material[mat]; p.Color = Color3.fromRGB(r, g, b)
\t\tp.Transparency = tr; p.CanCollide = cc; p.Anchored = true
\t\tif shape ~= "" and p:IsA("Part") then p.Shape = Enum.PartType[shape] end
\t\tp.TopSurface = Enum.SurfaceType.Smooth; p.BottomSurface = Enum.SurfaceType.Smooth
\t\tif light then local l = Instance.new("PointLight"); l.Color = Color3.fromRGB(light[1], light[2], light[3]); l.Range = light[4]; l.Brightness = light[5]; l.Parent = p end
\t\tif smoke then local s = Instance.new("Smoke"); s.Size = smoke[1]; s.RiseVelocity = smoke[2]; s.Opacity = smoke[3]; s.Parent = p end
\t\tp.Parent = F(parent)
\t\treturn p
\tend
`;

async function exportModel(c, name) {
  const head = c.text(await c.tool("execute_luau", lua(DUMP(name, 0, 0)))).trim();
  if (head.startsWith("missing")) throw new Error(`model "${name}" is not in workspace.MODELKIT — build it first`);
  const total = Number(head.replace(/[^0-9]/g, ""));
  if (!total) throw new Error("empty model: " + head);
  const rows = [];
  for (let i = 1; i <= total; i += 50) {
    const chunk = c.text(await c.tool("execute_luau", lua(DUMP(name, i, i + 49))));
    for (const line of chunk.split("\n")) if (line.includes("\t")) rows.push(line);
    process.stdout.write(`\rreading ${Math.min(i + 49, total)}/${total} parts`);
  }
  process.stdout.write("\n");
  const body = rows.map((line) => {
    const [cls, nm, shape, parent, size, cfs, mat, col, tr, cc, extra] = line.split("\t");
    const light = /light:([^;]*)/.exec(extra || "");
    const smoke = /smoke:([^;]*)/.exec(extra || "");
    const rgb = col.split(",").map((n) => Math.round(Number(n)));
    return `\tP("${cls}", "${nm}", "${shape}", "${parent}", ${size.split(",").join(", ")}, CFrame.new(${cfs}), "${mat}", ${rgb.join(", ")}, ${Number(tr)}, ${cc === "1"}, ${light ? `{${light[1]}}` : "nil"}, ${smoke ? `{${smoke[1]}}` : "nil"})`;
  }).join("\n");
  const out = path.join(ROOT, "export", name + ".lua");
  fs.mkdirSync(path.dirname(out), { recursive: true });
  const footer = `\n\tm.PrimaryPart = m:FindFirstChild("Root")\n\tm.WorldPivot = CFrame.new(0, 0, 0)\n\treturn m\nend\n`;
  fs.writeFileSync(out, EXPORT_HEADER(name, rows.length) + body + footer, "utf8");
  console.log(`wrote ${path.relative(ROOT, out)} (${rows.length} parts, ${(fs.statSync(out).size / 1024).toFixed(0)} KB)`);
}

async function main() {
  const c = await connect();
  try {
    if (cmd === "build") await build(c, rest[0]);
    else if (cmd === "shot") await shot(c, rest[0], rest[1]);
    else if (cmd === "overview") await overview(c, rest[0], rest[1]);
    else if (cmd === "export") await exportModel(c, rest[0]);
    else if (cmd === "select") {
      const r = c.text(await c.tool("execute_luau", lua(`local m = workspace.MODELKIT:FindFirstChild("${rest[0]}")
if not m then return "missing" end
game:GetService("Selection"):Set({ m })
return "selected " .. m.Name .. " — in Studio: right-click > Save to File... -> WOLD-Models/export/${rest[0]}.rbxm"`)));
      console.log(r);
    } else if (cmd === "list") {
      console.log(c.text(await c.tool("execute_luau", lua(`local r = workspace:FindFirstChild("MODELKIT")
if not r then return "no MODELKIT folder" end
local out = {}
for _, m in ipairs(r:GetChildren()) do
  if m:IsA("Model") and m:GetAttribute("Kit") then
    out[#out + 1] = string.format("%-22s slot %-3d %4d parts  %.0f x %.0f x %.0f", m.Name, m:GetAttribute("Slot") or -1, m:GetAttribute("Parts") or 0, m:GetAttribute("SizeX") or 0, m:GetAttribute("SizeY") or 0, m:GetAttribute("SizeZ") or 0)
  end
end
table.sort(out)
return #out > 0 and table.concat(out, "\\n") or "(no models built yet)"`))));
    } else if (cmd === "clear") {
      const n = rest[0];
      console.log(c.text(await c.tool("execute_luau", lua(n
        ? `local r = workspace:FindFirstChild("MODELKIT"); if not r then return "no MODELKIT" end
local m = r:FindFirstChild("${n}"); if m then m:Destroy() end
local p = r:FindFirstChild("Pads") and r.Pads:FindFirstChild("Pad_${n}"); if p then p:Destroy() end
return "cleared ${n}"`
        : `local r = workspace:FindFirstChild("MODELKIT"); if r then r:Destroy() end; return "cleared MODELKIT"`))));
    } else {
      console.log(read("tools/model.js").split("\n").slice(1, 10).map((l) => l.replace(/^\/\/ ?/, "")).join("\n"));
    }
  } finally { c.close(); }
  process.exit();
}
main().catch((e) => { console.error(e.message); process.exit(1); });
