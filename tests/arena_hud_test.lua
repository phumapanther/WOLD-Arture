-- node tools/lua.js tests/arena_hud_test.lua Edit
-- เฟส 1 (ผู้ใช้สั่ง 2026-09-26): แถบคะแนนเล็กลง · ไม่มีกล่องเงินซ้าย · ไม่มีข้อความกลางจอ · ร้านมีบรรทัดสถานะ
-- เก็บโคลนไว้จนจบเทส: ArenaHudGui require พี่น้อง (Responsive) ตอน new() ถูกเรียก ไม่ใช่ตอนโหลด
local clones = {}
local function fresh(module)
	local copy = module:Clone()
	copy.Name = module.Name .. "_t" .. math.random(1, 1e9)
	copy.Parent = module.Parent
	clones[#clones + 1] = copy
	local ok, result = pcall(require, copy)
	assert(ok, result)
	return result
end

local ArenaHudGui = fresh(game.ReplicatedStorage.UI.ArenaHudGui)
local out, fails = {}, 0
local function check(ok, text)
	out[#out + 1] = (ok and "ok   " or "FAIL ") .. text
	if not ok then fails += 1 end
end

local hud = ArenaHudGui.new()
local gui = hud.gui
local bar = gui:FindFirstChild("ScoreBar")
check(bar ~= nil and bar.Size.X.Offset <= 280 and bar.Size.Y.Offset <= 44, "แถบคะแนนเล็กลง (≤280x44)")
check(gui:FindFirstChild("Silver", true) == nil, "ไม่มีกล่องซิลเวอร์ซ้าย")
check(gui:FindFirstChild("Banner", true) == nil, "ไม่มีป้ายกลางจอ")
check(gui:FindFirstChild("ShopHint", true) == nil, "ไม่มีข้อความชวนเปิดร้าน")
check(hud.SetBanner == nil and hud.SetShopHint == nil, "ไม่มีทางวาดข้อความกลางจออีก")
local ok, err = pcall(function()
	hud:Render({ phase = "live", round = 2, secondsLeft = 75, wins = { A = 1, B = 0 }, silver = 1200,
		mapName = "ปราสาท", alive = true, mySide = "A", teams = { A = {}, B = {} } })
end)
check(ok, "Render ทำงานได้โดยไม่มีกล่องเงิน " .. tostring(err or ""))
gui:Destroy()

local ArenaShopGui = fresh(game.ReplicatedStorage.UI.ArenaShopGui)
local okShop, shop = pcall(ArenaShopGui.new)
check(okShop and type(shop) == "table" and type(shop.Flash) == "function", "ร้านมี Flash สำหรับข้อความจากเซิร์ฟเวอร์")
if okShop and type(shop) == "table" and shop.Flash then
	shop:Flash("ซิลเวอร์ไม่พอ", "warn")
	local status = shop.gui:FindFirstChild("Status", true)
	check(status ~= nil and status.Text == "ซิลเวอร์ไม่พอ" and status.Visible, "Flash ขึ้นในบรรทัดสถานะของร้าน")
end
if okShop and type(shop) == "table" and shop.gui then shop.gui:Destroy() end

for _, c in ipairs(clones) do c:Destroy() end
return ("%s\n%d fail(s)"):format(table.concat(out, "\n"), fails)
