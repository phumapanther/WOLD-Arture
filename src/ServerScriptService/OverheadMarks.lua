-- OverheadMarks: อีโมจิสถานะเหนือหัว (💫 มึน · 💤 หลับ · 💦 เหนื่อย/โดนสโลว์ · 🐌 ของหนัก · 🔧 ของใกล้พัง)
--
-- สร้างฝั่งเซิร์ฟเวอร์ ทุกคนแถวนั้นเห็น (สถานะที่คนอื่นต้องรู้) · **หลายสถานะพร้อมกัน = ขึ้นทุกอันเรียงข้างกัน**
-- (ผู้ใช้สั่ง 2026-09-29 · เดิมทุกป้ายอยู่จุดเดียวกันจึงทับกันเหลือให้เห็นอันเดียว) · ไม่มี require อะไร จึงเทสใน Edit ได้
-- (tests/overhead_marks_test.lua) · StatusEffects เป็นเจ้าของ "เหตุผล" ของแต่ละป้าย ไฟล์นี้เป็นเจ้าของ "การวาด"
local OverheadMarks = {}

-- ลำดับซ้าย → ขวา · ป้ายใหม่ต้องเติมชื่อที่นี่ ไม่งั้นมันไม่ถูกจัดแถว (ซ้อนทับกลางหัว)
OverheadMarks.Order = { "DizzyMark", "AsleepMark", "TiredMark", "SlowedMark", "HeavyMark", "WornMark" }
local RANK = {}
for i, name in ipairs(OverheadMarks.Order) do RANK[name] = i end

-- ระยะห่างระหว่างป้าย เป็นสัดส่วนความกว้างป้าย (60 px × 0.6 = 36 px)
local SPACING = 0.6

-- เลื่อนป้ายทุกอันบนหัวให้เรียงข้างกัน กึ่งกลางอยู่ที่เดิม (SizeOffset = เลื่อนบนจอเป็นเท่าของขนาดป้าย)
function OverheadMarks.Arrange(head)
	local marks = {}
	for _, child in ipairs(head:GetChildren()) do
		if child:IsA("BillboardGui") and RANK[child.Name] then marks[#marks + 1] = child end
	end
	table.sort(marks, function(a, b) return RANK[a.Name] < RANK[b.Name] end)
	for i, gui in ipairs(marks) do
		gui.SizeOffset = Vector2.new((i - (#marks + 1) / 2) * SPACING, 0)
	end
end

-- เปิด/ปิดป้ายหนึ่งอัน · เรียกซ้ำได้ (เปิดอยู่แล้ว = ไม่สร้างซ้อน)
function OverheadMarks.Set(head, name, emoji, colour, on)
	if not head then return end
	local existing = head:FindFirstChild(name)
	if not on then
		if existing then
			existing:Destroy()
			OverheadMarks.Arrange(head)
		end
		return
	end
	if existing then return end

	local gui = Instance.new("BillboardGui")
	gui.Name = name
	gui.Size = UDim2.fromOffset(60, 30)
	gui.StudsOffsetWorldSpace = Vector3.new(0, 1.8, 0)
	gui.MaxDistance = 60
	gui.AlwaysOnTop = true
	gui.Parent = head

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.TextColor3 = colour
	label.Text = emoji
	label.Parent = gui

	OverheadMarks.Arrange(head)
end

return OverheadMarks
