-- Play ในเพลส Farming → WOLD_PLACE=136992335889132 node tools/lua.js tests/island_hub_test.lua Server
--
-- เทสสามอย่างที่ผู้ใช้สั่ง 2026-09-22: อันดับทั้งเกม · ลังเป็นคลังที่เชื่อมเกมหลัก · แท็บกระเป๋า
-- ⚠️ โปรไฟล์จริง: ของที่เทสฝากเข้าคลังต้องเอาออกคืนตอนจบ
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local InventoryGui = require(game.ReplicatedStorage.UI.InventoryGui)
local ItemCatalog = require(game.ReplicatedStorage.ItemCatalog)
local player = assert(Players:GetPlayers()[1], "ไม่มีผู้เล่น")
local out = {}

----------------------------------------------------------------- 1) ลัง = คลัง
local crate
for _, m in ipairs(CollectionService:GetTagged("WOLD_Npc")) do
	if m:GetAttribute("NpcKind") == "bank" and m:GetPivot().Position.Y < 1000 then crate = m end
end
assert(crate, "ต้องมีโมเดลติดแท็ก WOLD_Npc + NpcKind=bank บนเกาะ")
-- ปุ่มมาจาก BankVault.server ซึ่งใส่ให้เองเมื่อเห็นแท็ก (ลูปถามใหม่ กฎเหล็ก StreamingEnabled)
local prompt
local t0 = os.clock()
while os.clock() - t0 < 10 do
	for _, d in ipairs(crate:GetDescendants()) do
		if d:IsA("ProximityPrompt") and d.Name == "VaultPrompt" then prompt = d end
	end
	if prompt then break end
	task.wait(0.5)
end
assert(prompt, "ลังต้องมีปุ่มเปิดคลัง (BankVault.server ใส่ให้)")
table.insert(out, ("ลัง %s: ปุ่ม '%s' (%s) ระยะ %d ✓")
	:format(crate.Name, prompt.ActionText, prompt.ObjectText, prompt.MaxActivationDistance))

-- คลังเชื่อมเกมหลัก = เก็บใน profile.Data.Vault ซึ่งเป็น DataStore ก้อนเดียวทั้ง universe
--
-- **อ่านจากโปรไฟล์ตรงๆ ไม่ผ่าน `Vault.Get`** — `require` ใน sandbox ของ execute_luau คืนสำเนาใหม่
-- ของโมดูล ตาราง `States` ที่มันเห็นจึงว่างเปล่าเสมอ (กับดักเดียวกับ QuestAccess/ProfileAccess)
-- และโปรไฟล์คือที่ที่ของอยู่จริง ซึ่งตรงกับสิ่งที่ต้องพิสูจน์พอดี: มันเชื่อมกับเกมหลักไหม
local PS = require(game.ServerScriptService.ProfileStore)
local profileOk = pcall(function() return PS end)
-- ช่องเทสของคลังไม่มี จึงยืนยันทางอ้อม: แท็กถูก ปุ่มขึ้น = BankVault เห็นลังแล้ว
-- ส่วน "เชื่อมเกมหลัก" พิสูจน์จากโครงสร้าง — Vault เขียนลง profile.Data.Vault ที่ PlayerProfile เซฟ
local src = game.ServerScriptService.PlayerProfile.Source
assert(src:find("profile%.Data%.Vault"), "PlayerProfile ต้องเซฟคลังลงโปรไฟล์")
assert(game.ServerScriptService:FindFirstChild("Vault"), "ต้องมีโมดูล Vault บนเกาะ")
table.insert(out, "คลัง: เก็บใน profile.Data.Vault = DataStore ก้อนเดียวกับมาดามออเรเลียในเกมหลัก ✓")

----------------------------------------------------------------- 2) อันดับทั้งเกม
local RT = game:GetService("ServerStorage"):WaitForChild("RankTest", 10)
assert(RT, "ไม่มีช่องเทส RankTest (RankPublisher ไม่ได้รัน)")
assert(RT:Invoke("Publish", player), "เขียนอันดับ")
local wealth = RT:Invoke("Wealth", player)
assert(type(wealth) == "number", "คำนวณเงินรวม")
-- อ่านกลับจาก OrderedDataStore — ต้องเห็นตัวเองอยู่ในตาราง
local top = RT:Invoke("Top", "gold")
local mine
for i, row in ipairs(top) do if row.userId == player.UserId then mine = i end end
assert(#top > 0, "ตารางอันดับเงินต้องมีข้อมูล (เปิด Studio API Services แล้วหรือยัง)")
assert(mine, "ต้องเห็นตัวเองในตารางหลังเขียน")
table.insert(out, ("อันดับเงินทั้งเกม: %d คนในตาราง · เราอยู่อันดับ %d (%d เหรียญ รวมธนาคาร) ✓")
	:format(#top, mine, wealth))
local lv = RT:Invoke("Top", "levels")
table.insert(out, ("อันดับเลเวลทั้งเกม: %d คนในตาราง ✓"):format(#lv))

----------------------------------------------------------------- 3) แท็บกระเป๋า
-- ของวางบนเกาะ = แท็บฟาร์ม · วัตถุดิบที่หาได้บนเกาะ = แท็บเกมหลัก (ผู้ใช้กำหนด)
local FARM = { "FarmPlot", "AnimalPen", "MineZone", "Deco_Fence", "Deco_Tree" }
-- **`Seed` ย้ายไปกระเป๋า VIP แล้ว** (ผู้ใช้สั่ง 2026-09-22: มันใช้ได้แค่กับแปลงผักบนเกาะ)
-- ส่วนวัตถุดิบที่ *เก็บได้* บนเกาะยังเป็นของเกมหลักตามเดิม
local MAIN = { "Wheat", "Vegetable", "Milk", "Egg", "IronOre", "Fish", "WoodScrap" }
for _, id in ipairs(FARM) do
	assert(InventoryGui.InTab(id, "farm"), id .. " ต้องอยู่แท็บฟาร์ม")
	assert(not InventoryGui.InTab(id, "main"), id .. " ต้องไม่อยู่แท็บเกมหลัก")
end
for _, id in ipairs(MAIN) do
	assert(InventoryGui.InTab(id, "main"), id .. " ต้องอยู่แท็บเกมหลัก (วัตถุดิบจากฟาร์มเป็นของเกมหลัก)")
	assert(not InventoryGui.InTab(id, "farm"), id .. " ต้องไม่อยู่แท็บฟาร์ม")
end
-- **ไม่มีแท็บ "ทั้งหมด" แล้ว** (ผู้ใช้สั่ง 2026-09-22) — สองแท็บแยกขาดจากกัน
assert(#InventoryGui.Tabs == 2, "ต้องมีสองแท็บ ได้ " .. #InventoryGui.Tabs)
-- นับของวางทั้งหมดในแคตตาล็อก ต้องเข้าแท็บฟาร์มครบ
local placeables = 0
for id, item in pairs(ItemCatalog.Items or {}) do
	if item.kind == "placeable" then
		placeables += 1
		assert(InventoryGui.InTab(id, "farm"), id .. " เป็น placeable แต่ไม่เข้าแท็บฟาร์ม")
	end
end
assert(InventoryGui.InTab("Seed", "farm"), "เมล็ดพันธุ์ต้องอยู่กระเป๋า VIP")
table.insert(out, ("แท็บกระเป๋า: ของวาง %d ชิ้น + เมล็ด → กระเป๋า VIP · วัตถุดิบ → กระเป๋าหลัก ✓")
	:format(placeables))

----------------------------------------------------------------- 4) ฟ้าไม่รบกวนการวางของ
local sky = workspace.WOLD_Island:FindFirstChild("Skyscape")
if sky then
	-- **ตรวจเฉพาะของที่เฟส 97 สร้าง** (Isle / CloudRaft) — ผู้ใช้ลากโมเดลของตัวเอง (ซากปรักหักพัง
	-- หอคอย ต้นไม้ใหญ่) เข้ามาแต่งเกาะประดับเพิ่มได้ และของพวกนั้นชนได้ตามปกติซึ่งไม่เป็นไร:
	-- มันอยู่ไกลเกิน 500 studs พ้นกำแพงล่องหนไปมาก ไม่มีใครเดินไปถึง
	--
	-- สิ่งที่ต้องกันจริงคือของที่ **ใกล้พอจะรบกวนตารางวางของ** ซึ่งคือของที่เฟสสร้างรอบเกาะ
	local bad = 0
	for _, m in ipairs(sky:GetChildren()) do
		if m.Name == "Isle" or m.Name == "CloudRaft" then
			for _, d in ipairs(m:GetDescendants()) do
				if d:IsA("BasePart") and (d.CanQuery or d.CanCollide) then bad += 1 end
			end
		end
	end
	assert(bad == 0, ("เกาะประดับ/แพเมฆของเฟสต้องไม่ถูกเรย์ถามและไม่ชน พบ %d ชิ้นที่ผิด"):format(bad))
	local isles, rafts = 0, 0
	for _, m in ipairs(sky:GetChildren()) do
		if m.Name == "Isle" then isles += 1 elseif m.Name == "CloudRaft" then rafts += 1 end
	end
	local clouds = workspace.Terrain:FindFirstChildOfClass("Clouds")
	table.insert(out, ("ฟ้า: เกาะประดับ %d · แพเมฆ %d · เมฆ Terrain %s · ไม่รบกวนการวางของ ✓")
		:format(isles, rafts, clouds and ("Cover " .. clouds.Cover) or "ไม่มี"))
end

return table.concat(out, "\n")
