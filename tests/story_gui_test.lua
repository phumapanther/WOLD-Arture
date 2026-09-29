-- node tools/lua.js tests/story_gui_test.lua Edit
-- StoryGui (2026-09-29 รีวิวรอบท้าย): กล่อง "รับพร" มีได้ทีละอัน (กด E รัวเคยซ้อนหลายกล่องค้างทับคัทซีน) · ปิดได้ · จอขาวเปิด/ปิด
local ui = game.ReplicatedStorage.UI
local copy = ui.StoryGui:Clone()
copy.Name = "StoryGui_t" .. math.random(1, 1e9)
copy.Parent = ui
local folder = Instance.new("Folder")
folder.Parent = game.ReplicatedStorage
local out, fails = {}, 0
local function check(ok, text)
	out[#out + 1] = (ok and "ok   " or "FAIL ") .. text
	if not ok then fails += 1 end
end
local function choices(g)
	local n = 0
	for _, c in ipairs(g.gui:GetChildren()) do
		if c.Name == "Choice" then n += 1 end
	end
	return n
end
local ok, err = pcall(function()
	local StoryGui = require(copy)
	local g = StoryGui.new(folder)
	check(g.tracker == nil, "แผง tracker เดิมถูกถอดแล้ว (แถบเควสรวมแทน)")
	g:Choice("q1?", "yes", "no", function() end)
	g:Choice("q2?", "yes", "no", function() end)
	check(choices(g) == 1, "เรียกซ้ำ = กล่องเดียว (ได้ " .. choices(g) .. ")")
	g:CloseChoice()
	check(choices(g) == 0, "ปิดกล่องได้ (ก่อนคัทซีนเริ่ม)")
	g:White(true)
	check(g.flash.Visible and g.cinema.Visible, "จอขาวขึ้น")
	g:White(false)
	check(not g.flash.Visible, "จอขาวปิด")
end)
check(ok, "รันจบ " .. tostring(err or ""))
copy:Destroy()
folder:Destroy()
return (fails == 0 and "PASS\n" or ("FAIL x%d\n"):format(fails)) .. table.concat(out, "\n")
