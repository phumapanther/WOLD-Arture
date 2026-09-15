// build-map-terrain.js: rebuilds src/ReplicatedStorage/MapTerrain.lua by sampling the real terrain.
//
//   node tools/build-map-terrain.js [cells-per-side]   (default 360)
//
// Studio must be open on the place, in EDIT mode. Takes a couple of minutes at 360.
//
// Why a driver rather than one Luau call: execute_luau truncates its answer at 100KB, and a 360-cell grid is
// roughly half a megabyte. tools/sample-terrain.lua therefore returns one band of rows per call and this
// stitches them together. The bands are sized by cells, not by rows, so raising N does not quietly start
// overrunning the limit again.
const fs = require("fs");
const path = require("path");
const connect = require("./mcp-client");

const N = Number(process.argv[2] || 360);
if (!Number.isInteger(N) || N < 16 || N > 1200) {
  console.error("cells-per-side must be a whole number between 16 and 1200");
  process.exit(1);
}

// A cell is at most six bytes on the wire ("g1234," for a 1234-stud peak), so 12,000 cells is ~72KB against
// the 100KB ceiling. The headroom is the point: a band that overruns loses rows SILENTLY, and the only sign
// would be a strip of the map missing its ground.
const CELLS_PER_BAND = 12000;
const ROWS_PER_BAND = Math.max(1, Math.floor(CELLS_PER_BAND / N));

const template = fs.readFileSync(path.join(__dirname, "sample-terrain.lua"), "utf8");
const NOT_READY = /No Roblox Studio instances|Unable to reach Roblox Studio|Target is not reachable/;

(async () => {
  const c = await connect();
  const rows = [];
  let land = 0, water = 0, miss = 0;

  for (let from = 1; from <= N; from += ROWS_PER_BAND) {
    const to = Math.min(N, from + ROWS_PER_BAND - 1);
    const code = template
      .replace(/^local N = \d+ *-- __N__$/m, `local N = ${N}`)
      .replace(/^local FROM = \d+ *-- __FROM__$/m, `local FROM = ${from}`)
      .replace(/^local TO = \d+ *-- __TO__$/m, `local TO = ${to}`);

    let text = "";
    for (let attempt = 1; attempt <= 10; attempt++) {
      text = c.text(await c.tool("execute_luau", { datamodel_type: "Edit", code }));
      if (!NOT_READY.test(text)) break;
      await new Promise((r) => setTimeout(r, 4000));
    }

    const header = text.split("\n")[0];
    const m = header.match(/^BAND (\d+) (\d+) (\d+) land=(\d+) water=(\d+) miss=(\d+)$/);
    if (!m) {
      console.error(`rows ${from}-${to} came back wrong:\n${text.slice(0, 400)}`);
      process.exit(1);
    }
    land += Number(m[4]); water += Number(m[5]); miss += Number(m[6]);

    const band = text.slice(text.indexOf("\n") + 1).split(";");
    if (band.length !== to - from + 1) {
      // The exact failure the bands exist to prevent, caught rather than written into the map.
      console.error(`rows ${from}-${to}: expected ${to - from + 1} rows, got ${band.length} -- band too big?`);
      process.exit(1);
    }
    for (const row of band) rows.push(row);
    process.stdout.write(`rows ${from}-${to} of ${N}\n`);
  }

  // Split each cell into its material letter and its height.
  const heights = [];
  const materials = [];
  for (const row of rows) {
    const h = [], mat = [];
    for (const cell of row.split(",")) {
      if (cell === "w0") { h.push("-1"); mat.push("w"); }
      else { mat.push(cell[0]); h.push(cell.slice(1)); }
    }
    heights.push(`\t{${h.join(",")}},`);
    materials.push(`\t"${mat.join("")}",`);
  }

  const out = `-- MapTerrain: height AND ground material, sampled from the real terrain.
--
-- GENERATED FILE -- do not hand-edit. Rebuild with:  node tools/build-map-terrain.js [cells-per-side]
-- Sampled by raycasting a ${N}x${N} grid over the whole 16000-stud world, hitting TERRAIN ONLY.
--
-- Why material and not just height: colouring by height alone disagreed with what players see. It
-- painted 19% of the island as rock and snow where the generator had made most of that slope grass,
-- because the generator decides using slope and forest cover as well as height. Reading its choice
-- gives what the world actually looks like.
--
-- Material codes: g grass, f forest, r rock, s snow, d sand, b basalt, w water.
local MapTerrain = {}

MapTerrain.Size = ${N} -- cells per side
MapTerrain.HalfSize = 8000 -- studs from centre to edge, matching MapConfig
MapTerrain.Water = -1
MapTerrain.StudsPerCell = 16000 / ${N}

-- Row 1 is the -Z edge; column 1 is the -X edge.
MapTerrain.Heights = {
${heights.join("\n")}
}

-- One string per row, one letter per cell, in the same order as the heights above. Strings rather than
-- tables of strings: ${N * N} separate one-character Lua strings is a table the parser is slow to read and
-- the engine is slow to hold, and every reader wants a single character anyway.
MapTerrain.Materials = {
${materials.join("\n")}
}

-- Height at a world position, or MapTerrain.Water.
function MapTerrain.At(x, z)
\tlocal step = (MapTerrain.HalfSize * 2) / MapTerrain.Size
\tlocal gx = math.clamp(math.floor((x + MapTerrain.HalfSize) / step) + 1, 1, MapTerrain.Size)
\tlocal gz = math.clamp(math.floor((z + MapTerrain.HalfSize) / step) + 1, 1, MapTerrain.Size)
\tlocal row = MapTerrain.Heights[gz]
\treturn row and row[gx] or MapTerrain.Water
end

-- The material letter for a cell, by grid index.
function MapTerrain.MaterialAt(gx, gz)
\tlocal row = MapTerrain.Materials[gz]
\treturn row and row:sub(gx, gx) or "w"
end

return MapTerrain
`;

  const target = path.join(__dirname, "..", "src", "ReplicatedStorage", "MapTerrain.lua");
  fs.writeFileSync(target, out);
  console.log(`\n${N}x${N}: land=${land} water=${water} miss=${miss}`);
  console.log(`wrote ${target} (${(out.length / 1024).toFixed(0)} KB)`);
  c.close();
  process.exit();
})().catch((e) => {
  console.error(e.message);
  process.exit(1);
});
