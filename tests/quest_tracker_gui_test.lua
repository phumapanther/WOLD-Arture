-- node tools/lua.js tests/quest_tracker_gui_test.lua Edit
-- แถบเควสรวม (2026-09-29): แถวตามลำดับ · สีตามชนิด · ล็อก = 🔒 · ย่อ/ขยาย · ไม่มีเควส = ซ่อน · อยู่ใต้หน้าต่าง
local RS = game.ReplicatedStorage
local temp = Instance.new("Folder")
temp.Name = "QuestTrackerTest_" .. math.random(1, 1e9)
temp.Parent = RS
RS.QuestLogRules:Clone().Parent = temp
local ui = Instance.new("Folder")
ui.Name = "UI"
ui.Parent = temp
for _, name in ipairs({ "QuestTrackerGui", "Responsive" }) do RS.UI[name]:Clone().Parent = ui end

local out, fails = {}, 0
local function check(ok, text)
	out[#out + 1] = (ok and "ok   " or "FAIL ") .. text
	if not ok then fails += 1 end
end

local ok, err = pcall(function()
	local Rules = require(temp.QuestLogRules)
	local Gui = require(ui.QuestTrackerGui)
	local g = Gui.new(temp)
	check(g.gui.DisplayOrder == 4, "อยู่ใต้หน้าต่างทุกบาน (DisplayOrder 4)")
	g:SetCollapsed(false)
	local rows = Rules.Merge({
		Rules.LockedRow({ id = "saltmere", name = "เส้นทางสู่ซอลต์เมียร์", goal = "หาคำแนะนำ" }),
		Rules.SideRow({ id = "sky", state = "active" }, { title = "เกาะลอยฟ้าแห่งความฝัน", goal = "ไปพบออฟาเรียน" }),
	}, { Rules.BoardRow("B|hunt|x", "สไลม์เขียว", "ล่า 5", 2, 5) })
	g:SetRows(rows, "side:sky")
	check(#g.buttons == 3, "สามแถว")
	check(g.buttons[1].Title.Text:find("🔒", 1, true) == 1 and g.buttons[1].Title.TextColor3 == Rules.Colors.main, "แถวล็อกทอง + 🔒")
	check(g.buttons[2].Title.Text:find("🧭", 1, true) == 1 and g.buttons[2].Title.TextColor3 == Rules.Colors.side, "แถวที่นำทางอยู่มี 🧭 · สีฟ้า")
	check(g.buttons[3]:FindFirstChild("Progress") ~= nil and g.buttons[3].Progress.Text == "2/5", "งานบอร์ดมีตัวนับ")
	check(g.holder.Visible and g.list.Visible, "ขยายอยู่ = เห็นรายการ")
	g:SetCollapsed(true)
	check(not g.list.Visible and g.header.Text:find("(3)", 1, true) ~= nil, "ย่อ = เหลือหัว (บอกจำนวน)")
	g:SetRows({}, nil)
	check(not g.holder.Visible, "ไม่มีเควส = ซ่อนทั้งแถบ")
	g.gui:Destroy()
end)
check(ok, "รันจบ " .. tostring(err or ""))
temp:Destroy()
return (fails == 0 and "PASS\n" or ("FAIL x%d\n"):format(fails)) .. table.concat(out, "\n")
