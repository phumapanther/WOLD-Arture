-- LanguageRefreshController: เปลี่ยนภาษากลางเกม → ข้อความทุกอันที่ขึ้นจออยู่แล้วเปลี่ยนตามทันที (ผู้ใช้แจ้ง 2026-10-05:
-- กดเปลี่ยนภาษาแล้วเมนูหินเวท/แถบเควสยังเป็นภาษาเดิม) · ป้ายส่วนใหญ่ถูกสร้างครั้งเดียวด้วย L(...) จึงไม่รู้ว่าภาษาเปลี่ยน
-- วิธี: หาต้นฉบับไทยของข้อความที่ระบบแปลไว้ (Locale.SourceOf) แล้วแปลเป็นภาษาใหม่ (Locale.Translate) — ทุก GUI ไม่ต้องแก้ทีละไฟล์
-- ไม่แตะ TextBox.Text (ผู้เล่นพิมพ์เอง) · ข้อความที่ไม่รู้จัก (ชื่อคน ตัวเลข) คงเดิม
local Players = game:GetService("Players")
local Locale = require(game.ReplicatedStorage.Locale)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local current = Locale.Current()

local function retext(obj, prop, from, to)
	local text = obj[prop]
	if text == "" then return end
	-- ต้นฉบับไทย = ข้อความที่ระบบแปลเอง (SourceOf) หรือข้อความที่ขึ้นตอนเป็นภาษาไทย · คำอังกฤษเดิมในโค้ดไม่ถูกแตะ
	local thai = Locale.SourceOf(text) or (from == "th" and text)
	if not thai then return end
	local new = Locale.Translate(to, thai)
	if new ~= text then obj[prop] = new end
end

player:GetAttributeChangedSignal("WOLD_Lang"):Connect(function()
	local from, to = current, Locale.Current()
	if from == to then return end
	current = to
	-- ponytail: ไล่ทั้ง PlayerGui ทีเดียว พักทุก 300 ชิ้นกันเฟรมกระตุก · ป้ายในโลก (BillboardGui ใน workspace) ไม่ได้ไล่
	for i, obj in ipairs(playerGui:GetDescendants()) do
		if obj:IsA("TextLabel") or obj:IsA("TextButton") then
			retext(obj, "Text", from, to)
		elseif obj:IsA("TextBox") then
			retext(obj, "PlaceholderText", from, to)
		end
		if i % 300 == 0 then task.wait() end
	end
end)
