-- WOLD_PLACE=136992335889132 node tools/lua.js tests/export_gui_instant_test.lua Edit   (เพลสไหนก็ได้)
-- 💎 รถกลับทันที (ผู้ใช้สั่ง 2026-10-02): ปุ่มอยู่ในการ์ดที่กำลังส่ง ข้างแถบเวลา · ราคา CraftConfig.InstantGems ตามเวลาที่เหลือ
-- (1 เพชร / 5 นาที) · ไม่มีงานส่ง = ไม่มีปุ่ม
local mirror = Instance.new("Folder")
mirror.Name = "ExportInstantMirror"
mirror.Sandboxed = true
mirror.Capabilities = SecurityCapabilities.new(Enum.SecurityCapability.Basic, Enum.SecurityCapability.CreateInstances,
	Enum.SecurityCapability.UI, Enum.SecurityCapability.RunServerScript, Enum.SecurityCapability.Input)
mirror.Parent = game.ServerStorage
game.ReplicatedStorage.UI:Clone().Parent = mirror
for _, m in ipairs(game.ReplicatedStorage:GetChildren()) do
	if m:IsA("ModuleScript") and m.Name ~= "Remotes" then m:Clone().Parent = mirror end
end

local out, fails = {}, 0
local function check(ok, text)
	out[#out + 1] = (ok and "ok   " or "FAIL ") .. text
	if not ok then fails += 1 end
end

local gui
local ok, err = pcall(function()
	local ExportGui = require(mirror.UI.ExportGui)
	gui = ExportGui.new()
	local now = workspace:GetServerTimeNow()
	local function order(slot, shipping)
		return { slot = slot, coins = 600, exp = 120, gems = "💎 1-2", ready = true, shipping = shipping,
			lines = { { item = "Bread", qty = 2, have = 4, name = "ขนมปัง", icon = "" } } }
	end
	local function snap(left)
		return { open = true, level = 4, into = 10, need = 100, gemsToday = 0, gemsDayCap = 5, rerollLeft = 1,
			shipSeconds = 1080, now = now,
			ship = left and { slot = 2, startAt = now - 60, endAt = now + left } or nil,
			orders = { order(1), order(2, left ~= nil), order(3) } }
	end

	gui:Show(snap(1020)) -- เหลือ 17 นาที = 4 เพชร
	local card = gui.cards[2]
	check(card and card.instant and card.instant.Visible and card.instant.Text:find("4", 1, true),
		"เหลือ 17 นาที = 💎 4: " .. tostring(card and card.instant and card.instant.Text))
	check(not (gui.cards[1].instant or gui.cards[3].instant), "ใบที่ไม่ได้ส่ง = ไม่มีปุ่ม 💎")
	gui:Show(snap(200))
	check(gui.cards[2].instant and gui.cards[2].instant.Text:find("1", 1, true),
		"เหลือ 3 นาทีกว่า = 💎 1: " .. tostring(gui.cards[2].instant and gui.cards[2].instant.Text))
	gui:Show(snap(nil))
	local any = false
	for _, c in pairs(gui.cards) do if c.instant then any = true end end
	check(not any, "รถว่าง = ไม่มีปุ่ม 💎")
end)
if gui and gui.gui then gui.gui:Destroy() end
mirror:Destroy()
if not ok then fails += 1 out[#out + 1] = "ERROR " .. tostring(err) end
return ("%s — %d fail\n%s"):format(fails == 0 and "PASS" or "FAIL", fails, table.concat(out, "\n"))
