-- node tools/lua.js tests/prompt_stack_test.lua Edit
-- ปุ่ม E/F ซ้อนกันบนโมเดลเดียวกัน (ผู้ใช้แจ้ง 2026-09-26) — PromptStack คิดระยะเลื่อนของทุกปุ่มที่โชว์อยู่
local function fresh(module)
	local copy = module:Clone()
	copy.Name = module.Name .. "_t" .. math.random(1, 1e9)
	copy.Parent = module.Parent
	local ok, result = pcall(require, copy)
	copy:Destroy()
	assert(ok, result)
	return result
end

local PromptStack = fresh(game.ReplicatedStorage.UI.PromptStack)
local out, fails = {}, 0
local function check(ok, text)
	out[#out + 1] = (ok and "ok   " or "FAIL ") .. text
	if not ok then fails += 1 end
end
local E, F, R = Enum.KeyCode.E.Value, Enum.KeyCode.F.Value, Enum.KeyCode.R.Value
local S = PromptStack.Spacing

local r = PromptStack.Layout({ { key = "a", pos = Vector3.new(0, 0, 0), order = E, name = "Gather" } })
check(r.a == Vector2.zero, "ปุ่มเดียวไม่เลื่อน")

r = PromptStack.Layout({
	{ key = "f", pos = Vector3.new(0, 0, 0), order = F, name = "Auto" },
	{ key = "e", pos = Vector3.new(1, 0.5, 0), order = E, name = "Gather" },
})
check(r.e == Vector2.new(0, -S / 2) and r.f == Vector2.new(0, S / 2), "สองปุ่มจุดเดียวกัน: E บน F ล่าง กึ่งกลางที่เดิม")

r = PromptStack.Layout({
	{ key = "a", pos = Vector3.new(0, 0, 0), order = E, name = "A" },
	{ key = "b", pos = Vector3.new(20, 0, 0), order = F, name = "B" },
})
check(r.a == Vector2.zero and r.b == Vector2.zero, "ห่างกันเกินระยะกอง = ต่างคนต่างอยู่ ไม่เลื่อน")

r = PromptStack.Layout({
	{ key = "c", pos = Vector3.new(0, 0, 0), order = R, name = "C" },
	{ key = "a", pos = Vector3.new(0, 0, 0), order = E, name = "A" },
	{ key = "b", pos = Vector3.new(0, 0, 0), order = F, name = "B" },
})
check(r.a == Vector2.new(0, -S) and r.b == Vector2.zero and r.c == Vector2.new(0, S), "สามปุ่มเรียง E F R ห่างเท่ากัน")
check((r.b - r.a).Y >= 72, "ระยะห่างไม่น้อยกว่าความสูงปุ่ม (~72 px)")

r = PromptStack.Layout({
	{ key = "x", pos = Vector3.new(0, 0, 0), order = E, name = "Zeta" },
	{ key = "y", pos = Vector3.new(0, 0, 0), order = E, name = "Alpha" },
})
check(r.y.Y < r.x.Y, "ปุ่มเดียวกันสองอันเรียงตามชื่อ คงที่ทุกครั้ง")

check(next((PromptStack.Layout({}))) == nil, "ไม่มีปุ่ม = ไม่มีผล")

local offs, sizes = PromptStack.Layout({
	{ key = "solo", pos = Vector3.new(50, 0, 0), order = E, name = "S" },
	{ key = "p1", pos = Vector3.new(0, 0, 0), order = E, name = "P1" },
	{ key = "p2", pos = Vector3.new(0, 0, 0), order = F, name = "P2" },
})
check(sizes.solo == 1 and sizes.p1 == 2 and sizes.p2 == 2, "บอกขนาดกองของแต่ละปุ่ม (เดี่ยว = 1 ใช้ค่าเลื่อนเดิมของปุ่มได้)")

table.insert(out, fails == 0 and ("ผ่านทั้งหมด %d ข้อ"):format(#out) or ("ตก %d ข้อ"):format(fails))
return table.concat(out, "\n")
