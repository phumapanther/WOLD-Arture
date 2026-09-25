-- Edit mode → WOLD_PLACE=136992335889132 node tools/lua.js tests/island_move_test.lua Edit
-- โหมดจัดเกาะ: ย้าย/หมุนของที่วางแล้ว ต้องไม่ชนตัวเอง (IslandGrid.canPlace ... ignore, reach)
local RS = game.ReplicatedStorage
local clone = RS.IslandGrid:Clone(); clone.Name = "IslandGrid_MoveTest"; clone.Parent = RS
local ok0, G = pcall(require, clone)
clone:Destroy()
assert(ok0, G)
local C = require(RS.IslandConfig)
local out, fails = {}, 0
local function check(ok, text)
	out[#out + 1] = (ok and "ok   " or "FAIL ") .. text
	if not ok then fails += 1 end
end

-- หาช่อง 2x2 ที่วางได้จริงบนเกาะนี้ (ผังเกาะแก้มือได้ ห้ามฝังพิกัด)
local cx, cz
for x = -20, 20, 3 do
	for z = -20, 20, 3 do
		if not cx and G.canPlace({}, {}, x, z, 2, 2, 0) then cx, cz = x, z end
	end
end
assert(cx, "หาช่องว่าง 2x2 บนเกาะไม่เจอ")

-- จำลอง "ของที่วางแล้ว" ทับสองช่องนั้น: กล่องทึบชนได้ สูงพอบังทางเดิน
local y = G.surfaceAt(cx, cz)
local wx, wz = G.centreOf(cx, cz, 2, 2, 0)
local model = Instance.new("Model")
model.Name = "MoveTestBlock"
local block = Instance.new("Part")
block.Anchored, block.CanCollide = true, true
block.Size = Vector3.new(C.Cell * 2 - 0.4, 8, C.Cell * 2 - 0.4)
block.CFrame = CFrame.new(wx, y + 4, wz)
block.Parent = model
model.PrimaryPart = block
model.Parent = workspace

local okA, whyA = G.canPlace({}, {}, cx, cz, 2, 2, 0)
check(not okA, "ไม่ ignore: ตัวเองขวางช่องตัวเอง (" .. tostring(whyA) .. ")")
check(G.obstructed(cx, cz, model) == false, "obstructed ignore ได้ แม้ไม่มี IslandGhost (ตารางไม่มีรู)")
local reach = G.reachSet(model)
check(reach == nil or reach[G.key(cx, cz)] == true, "reachSet(ignore) เดินถึงช่องใต้ตัวเอง")
local okB, whyB = G.canPlace({}, {}, cx, cz, 2, 2, 1, nil, model, reach)
check(okB, "หมุนอยู่กับที่ได้เมื่อ ignore ตัวเอง (" .. tostring(whyB) .. ")")
local okC = G.canPlace({}, {}, cx, cz, 2, 2, 0, nil, model)
check(okC, "ignore อย่างเดียว (ไม่ส่ง reach) ก็คิดให้เอง")

model:Destroy()
return (fails == 0 and "PASS\n" or ("FAIL x%d\n"):format(fails)) .. table.concat(out, "\n")
