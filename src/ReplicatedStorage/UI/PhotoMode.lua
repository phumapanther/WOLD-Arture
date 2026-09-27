-- PhotoMode: ซ่อน UI ทั้งหมดไว้ถ่ายรูป (ผู้ใช้สั่ง 2026-09-25) — สวิตช์อยู่ในหน้าตั้งค่าของหินเวท (P)
--
-- ซ่อน: ScreenGui ทุกตัวของเกม · UI ของ Roblox (แชท รายชื่อ กระเป๋า) · ปุ่ม E/F ทุกปุ่ม รวมปุ่มอาชีพที่ขึ้นข้างตัวคนอื่น
-- เว้น: ปุ่มควบคุมมือถือ — จอยของ Roblox (`TouchGui`) กับปุ่มแอ็กชันของเกม (`TouchActionGui`)
-- ออก: สวิตช์เดิม · คีย์ P · ปุ่มหินเวทบนมือถือ (SocialController ถามตัวนี้ก่อนเปิดหน้าต่าง)
-- ไม่เซฟ: เข้าเกมใหม่แล้วจอว่างเปล่าคือสิ่งที่อธิบายไม่ได้
local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")
local ProximityPromptService = game:GetService("ProximityPromptService")

-- WOLD_LobbyStone = ปุ่มหินเวทในล็อบบี้ (SocialController) ทางออกของมือถือตอนอยู่ล็อบบี้
local KEEP = { TouchGui = true, TouchActionGui = true, WOLD_LobbyStone = true, WOLD_Story = true } -- WOLD_Story = คัทซีนเนื้อเรื่องใช้โหมดนี้ซ่อน UI อื่น

local PhotoMode = {}
local on = false
local hidden = {} -- [ScreenGui] = true · คืนเฉพาะตัวที่เราปิดเอง ตัวที่ปิดอยู่แล้วต้องปิดต่อ
local core = {} -- [CoreGuiType] = เปิดอยู่ไหมก่อนเข้าโหมด

local function sweep(playerGui)
	for _, child in ipairs(playerGui:GetChildren()) do
		if child:IsA("ScreenGui") and child.Enabled and not KEEP[child.Name] then
			hidden[child] = true
			child.Enabled = false
		end
	end
end

function PhotoMode.IsOn()
	return on
end

function PhotoMode.Set(want)
	want = want == true
	if want == on then return end
	on = want
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	if on then
		for _, kind in ipairs(Enum.CoreGuiType:GetEnumItems()) do
			if kind ~= Enum.CoreGuiType.All then
				local ok, was = pcall(StarterGui.GetCoreGuiEnabled, StarterGui, kind)
				if ok then core[kind] = was end
			end
		end
		pcall(StarterGui.SetCoreGuiEnabled, StarterGui, Enum.CoreGuiType.All, false)
		ProximityPromptService.Enabled = false -- ฝั่งไคลเอนต์ = ปิดเฉพาะจอเรา
		-- ลูป ไม่ใช่ครั้งเดียว: ระบบอื่นเปิดหน้าต่างของมันเองได้ตลอด (HUD ป้ายอีเวนต์ แถบประกาศ)
		-- ponytail: หน้าต่างชั่วคราวที่จบระหว่างโหมด (มินิเกม) จะถูกคืนค้างไว้ ปิดเองได้ · แยกรายหน้าต่างถ้าเจอจริง
		task.spawn(function()
			while on do
				sweep(playerGui)
				task.wait(0.25)
			end
		end)
	else
		for gui in pairs(hidden) do
			if gui.Parent then gui.Enabled = true end
		end
		hidden = {}
		for kind, was in pairs(core) do
			pcall(StarterGui.SetCoreGuiEnabled, StarterGui, kind, was)
		end
		core = {}
		ProximityPromptService.Enabled = true
	end
end

return PhotoMode
