// node tools/dump-model.js <placeId> "<Lua expression ของโมเดล>" <ชื่อไฟล์ใน assets/models-from-main> "<คำอธิบาย>"
// ดัมพ์ BasePart ทุกชิ้นเป็นแถวตัวเลขเทียบ "ก้นกลางกล่องครอบ" ของโมเดล (ทรงแถวเดียวกับ chests.lua)
// ทีละ 60 แถว เพราะ execute_luau ตัดผลลัพธ์ยาวทิ้งเงียบๆ
const { spawnSync } = require("child_process");
const fs = require("fs");
const path = require("path");
const [placeId, expr, outName, note] = process.argv.slice(2);
if (!placeId || !expr || !outName) {
  console.error('usage: node tools/dump-model.js <placeId> "<expr>" <outName> "<note>"');
  process.exit(1);
}
const root = path.join(__dirname, "..");
const tmp = path.join(root, "tests", "_dump_model_tmp.lua");
const CHUNK = 60;
function run(lua) {
  fs.writeFileSync(tmp, lua);
  const r = spawnSync(process.execPath, [path.join(root, "tools", "lua.js"), tmp, "Edit"],
    { env: { ...process.env, WOLD_PLACE: placeId }, encoding: "utf8", cwd: root });
  fs.unlinkSync(tmp);
  if (r.status !== 0) throw new Error(r.stderr || r.stdout);
  return r.stdout.trim();
}
const head = `local m = ${expr}
local cf, size = m:GetBoundingBox()
local base = CFrame.new(cf.Position - cf.UpVector * size.Y / 2) * cf.Rotation
local parts = {}
for _, d in ipairs(m:GetDescendants()) do if d:IsA("BasePart") then parts[#parts + 1] = d end end
`;
const total = Number(run(head + "return tostring(#parts)").split("\n").pop());
if (!total) throw new Error("ไม่พบชิ้นส่วน");
const rows = [];
for (let offset = 0; offset < total; offset += CHUNK) {
  const out = run(head + `
local SHAPES = { [Enum.PartType.Ball] = 0, [Enum.PartType.Block] = 1, [Enum.PartType.Cylinder] = 2 }
local function r(v) return math.floor(v * 1000 + 0.5) / 1000 end
local out = {}
for i = ${offset} + 1, math.min(#parts, ${offset + CHUNK}) do
	local p = parts[i]
	local shape = p:IsA("WedgePart") and 9 or p:IsA("CornerWedgePart") and 10 or (p:IsA("Part") and SHAPES[p.Shape]) or 1
	local c = { base:ToObjectSpace(p.CFrame):GetComponents() }
	for k = 1, 12 do c[k] = r(c[k]) end
	local col = math.floor(p.Color.R * 255 + 0.5) * 65536 + math.floor(p.Color.G * 255 + 0.5) * 256 + math.floor(p.Color.B * 255 + 0.5)
	out[#out + 1] = ("{%q,%d,%s,%s,%s,%s,%d,%q,%s,%s,%d},"):format(p.Name, shape, r(p.Size.X), r(p.Size.Y), r(p.Size.Z),
		table.concat(c, ","), col, p.Material.Name, r(p.Transparency), r(p.Reflectance), p.CanCollide and 1 or 0)
end
return table.concat(out, "\\n")`);
  rows.push(...out.split("\n").filter((l) => l.startsWith("{")));
  console.log(`rows ${rows.length}/${total}`);
}
if (rows.length !== total) throw new Error(`ได้ ${rows.length} แถว จาก ${total}`);
const file = `-- ${note || outName}
-- ดัมพ์ด้วย tools/dump-model.js จากเพลส ${placeId} · ${expr} · ${total} ชิ้น
-- แถว: { ชื่อ, รูปทรง, กว้าง,สูง,ลึก, CFrame 12 ตัวเทียบก้นกลางกล่องครอบ, สี(0xRRGGBB), วัสดุ, โปร่งแสง, สะท้อน, ชนได้ }
-- รูปทรง: 0 Ball · 1 Block · 2 Cylinder · 9 Wedge · 10 CornerWedge
local ROWS = {
${rows.join("\n")}
}

local SHAPES = { [0] = Enum.PartType.Ball, [1] = Enum.PartType.Block, [2] = Enum.PartType.Cylinder }

-- สร้างโมเดล: จุดหมุน (WorldPivot) = ก้นกลาง → PivotTo(จุดบนพื้น) วางพอดีพื้น · ทุกชิ้น anchored
return function()
	local model = Instance.new("Model")
	for _, row in ipairs(ROWS) do
		local shape = row[2]
		local part = Instance.new(shape == 9 and "WedgePart" or shape == 10 and "CornerWedgePart" or "Part")
		part.Name = row[1]
		if shape ~= 9 and shape ~= 10 and SHAPES[shape] then part.Shape = SHAPES[shape] end
		part.Size = Vector3.new(row[3], row[4], row[5])
		part.CFrame = CFrame.new(row[6], row[7], row[8], row[9], row[10], row[11], row[12], row[13], row[14], row[15], row[16], row[17])
		part.Color = Color3.fromRGB(bit32.band(bit32.rshift(row[18], 16), 255), bit32.band(bit32.rshift(row[18], 8), 255), bit32.band(row[18], 255))
		local ok = pcall(function() part.Material = Enum.Material[row[19]] end)
		if not ok then part.Material = Enum.Material.Plastic end
		part.Transparency = row[20]
		part.Reflectance = row[21]
		part.CanCollide = row[22] == 1
		part.Anchored = true
		part.Parent = model
	end
	model.WorldPivot = CFrame.new()
	return model
end
`;
fs.writeFileSync(path.join(root, "assets", "models-from-main", outName + ".lua"), file);
console.log(`เขียน assets/models-from-main/${outName}.lua (${total} ชิ้น)`);
