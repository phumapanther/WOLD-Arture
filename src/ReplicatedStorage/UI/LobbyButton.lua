-- LobbyButton: ปุ่มกลมมุมขวาล่างของล็อบบี้ — หินเวท (🔮) กับคอนโซลแอดมิน (🛠️)
--
-- ผู้ใช้สั่ง 2026-09-26: "ปุ่มแอดมิน/หินเวทใหญ่ บังจอ · ทำให้เหมือนในเกมหลัก · ย้ายไปขวาล่าง ไม่ทับปุ่มกระโดด"
-- → ปุ่มกระจกวงกลม 45px ชุดเดียวกับปุ่มมือถือในเกม (TouchActionGui.Circle) เรียงเป็นแถวทางซ้ายของปุ่มกระโดด
--
-- ตำแหน่งคิดจากปุ่มกระโดดของ Roblox ซึ่งอยู่มุมขวาล่างคงที่: จอเล็ก 70px ที่ x -95..-25 · y -90..-20
-- จอใหญ่ (แท็บเล็ต) 120px ที่ x -170..-50 · y -210..-90 — แถวนี้ (y -65..-20, ขวาสุด -105) จึงไม่ทับทั้งสองขนาด
-- และอยู่ในแถบล่างที่ ChannelSelectGui เว้นว่างไว้ (bottomMargin) ไม่ทับปุ่ม JOIN · เครื่องไม่มีจอสัมผัส (ไม่มีปุ่ม
-- กระโดด) ชิดขวา 16px
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TouchActionGui = require(script.Parent.TouchActionGui)

local LobbyButton = {}

local SIZE, GAP = 45, 8

-- name = ชื่อ ScreenGui (PhotoMode ดูจากชื่อ) · slot = ลำดับจากขวา (1 = ติดปุ่มกระโดด) · iconName/emoji อย่างใดอย่างหนึ่ง
-- shouldShow() ถูกถามทุก 0.25 วิ (สิทธิ์แอดมินได้/ถูกถอนกลางเซสชันได้) · ซ่อนเองตอนจอดำหลังกด JOIN
function LobbyButton.new(name, slot, iconName, emoji, shouldShow, onTap)
	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")

	local holder = Instance.new("ScreenGui")
	holder.Name = name
	holder.ResetOnSpawn = false
	holder.IgnoreGuiInset = true
	holder.DisplayOrder = 25
	holder.Enabled = false

	local button, icon = TouchActionGui.Circle(holder, SIZE, iconName)
	button.Name = name .. "Button"
	button.AnchorPoint = Vector2.new(1, 1)
	local right = UserInputService.TouchEnabled and 105 or 16
	button.Position = UDim2.new(1, -(right + (slot - 1) * (SIZE + GAP)), 1, -20)
	if emoji then
		local glyph = Instance.new("TextLabel")
		glyph.Size = UDim2.fromScale(1, 1)
		glyph.BackgroundTransparency = 1
		glyph.TextScaled = true
		glyph.Text = emoji
		glyph.Parent = icon
	end
	button.Activated:Connect(onTap)
	holder.Parent = playerGui

	task.spawn(function()
		while holder.Parent do
			local lobbyGui = playerGui:FindFirstChild("ChannelSelectGui")
			local blackout = lobbyGui and lobbyGui:FindFirstChild("Blackout", true)
			holder.Enabled = shouldShow() and not (blackout and blackout.Visible)
			task.wait(0.25)
		end
	end)
	return holder
end

return LobbyButton
