-- PromptStackController: เจ้าของ UIOffset ของทุกปุ่ม E/F (ProximityPrompt) ที่โชว์บนจอเครื่องนี้ — ทุกเพลส
--
-- ปุ่มหลายระบบแขวนบนโมเดลเดียวกันแล้วซ้อนทับกัน (ผู้ใช้แจ้ง 2026-09-26 ทั้งโหมดฟาร์มและโหมดหลัก) · ปุ่มที่โชว์อยู่
-- และแขวนห่างกันไม่เกิน `PromptStack.GroupStuds` ถูกเรียงเป็นกองบนลงล่าง (E ก่อน) ดู UI/PromptStack
-- ⚠️ **ห้ามตั้ง UIOffset เองที่อื่นอีก** ไม่ว่าฝั่งเซิร์ฟหรือไคลเอนต์ — ไฟล์นี้เขียนทับทุก 0.3 วิ สองเจ้าของจะแย่งกันกระพริบ
-- UIOffset ที่ไคลเอนต์เขียนไม่ replicate จึงไม่กวนเครื่องอื่น
local ProximityPromptService = game:GetService("ProximityPromptService")
local PromptStack = require(game.ReplicatedStorage.UI.PromptStack)
local Locale = require(game.ReplicatedStorage.Locale)

-- ป้ายปุ่ม E/F ตั้งจากเซิร์ฟ = ภาษาเดียวกันทุกคน → แปลในเครื่องนี้ตอนโชว์ (ค่าที่ไคลเอนต์เขียนไม่ replicate ·
-- เซิร์ฟเขียนทับเมื่อไหร่ ลูปข้างล่างแปลซ้ำเอง · Show ของข้อความที่แปลแล้ว = เดิม) — ระบบหลายภาษา 2026-10-05
-- ข้อความปุ่มอาจถูกแปลเป็นภาษาก่อนหน้าไปแล้ว → ย้อนเป็นไทยก่อนแปลใหม่ (เปลี่ยนภาษากลางเกม/กลับเป็นไทยได้)
local function toThai(text)
	return Locale.SourceOf(text) or text -- ข้อความที่ไม่เคยถูกแปล (ไทยจากเซิร์ฟ/อังกฤษเดิม) = ตัวมันเอง
end

local function translatePrompt(prompt)
	local action, object = Locale.Show(toThai(prompt.ActionText)), Locale.Show(toThai(prompt.ObjectText))
	if prompt.ActionText ~= action then prompt.ActionText = action end
	if prompt.ObjectText ~= object then prompt.ObjectText = object end
end

local shown = {} -- [ProximityPrompt] = true ที่กำลังโชว์บนจอเครื่องนี้
-- ระยะเลื่อนเดิมของปุ่ม (จดตอนเห็นครั้งแรก ก่อนเราเขียนอะไร) — ปุ่มที่อยู่เดี่ยวๆ กลับไปใช้ค่าเดิม
-- ปุ่มที่ผู้ใช้วางมือใน Studio แล้วตั้งเลื่อนไว้เองจึงไม่ถูกลบ · เรียงใหม่เฉพาะตอนมีปุ่มซ้อนกันจริง
local original = setmetatable({}, { __mode = "k" })

local function anchorPos(prompt)
	local parent = prompt.Parent
	if not parent then return nil end
	if parent:IsA("BasePart") then return parent.Position end
	if parent:IsA("Attachment") then return parent.WorldPosition end
	if parent:IsA("Model") then return parent:GetPivot().Position end
	return nil
end

local function relayout()
	local entries = {}
	for prompt in pairs(shown) do
		local pos = anchorPos(prompt)
		if pos then
			table.insert(entries, {
				key = prompt, pos = pos, order = prompt.KeyboardKeyCode.Value,
				name = prompt.Name .. "|" .. prompt.ActionText,
			})
		else
			shown[prompt] = nil -- ถูกลบไปแล้ว
		end
	end
	local offsets, sizes = PromptStack.Layout(entries)
	for prompt, offset in pairs(offsets) do
		if sizes[prompt] <= 1 then offset = original[prompt] or offset end
		if prompt.UIOffset ~= offset then prompt.UIOffset = offset end
	end
end

ProximityPromptService.PromptShown:Connect(function(prompt)
	if original[prompt] == nil then original[prompt] = prompt.UIOffset end
	translatePrompt(prompt)
	shown[prompt] = true
	relayout()
end)
ProximityPromptService.PromptHidden:Connect(function(prompt)
	shown[prompt] = nil
	relayout()
end)

-- ของที่ขยับได้ (ผู้เล่น สัตว์ รถ) เข้า-ออกกองเองได้ และเซิร์ฟเวอร์อาจเขียนค่าเก่ามาทับ → ถามใหม่ทุก 0.3 วิ เฉพาะตอนมีปุ่มโชว์
task.spawn(function()
	while true do
		task.wait(0.3)
		if next(shown) then
			relayout()
			for prompt in pairs(shown) do translatePrompt(prompt) end
		end
	end
end)
