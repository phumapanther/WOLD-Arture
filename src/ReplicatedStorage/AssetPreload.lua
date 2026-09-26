-- AssetPreload: รวม asset id ของเกม (รูปไอเทม เสียง อนิเมชัน) จากตารางคอนฟิก ให้จอโหลดดึงมาไว้ก่อนเข้าเล่น
--
-- ผู้ใช้สั่ง 2026-09-26: "อันไหนโหลดทีเดียวตอนเข้าเชิฟแล้วไม่แลคได้ก็ทำเลย ... อาจจะเข้าเชิฟช้าลงแต่เล่นลื่นขึ้น"
-- ของเดิมไม่มีอะไรโหลดล่วงหน้าเลย (ขั้น preload ของ LoadingController เป็นรายการว่าง) = เสียงดาบ/ท่าต่อสู้/รูปไอเทม
-- ถูกดาวน์โหลดครั้งแรกตอนใช้กลางเกม มือถือกระตุกตรงนั้นพอดี
--
-- **เดินตารางหาเอง ไม่ใช่รายชื่อที่พิมพ์ไว้** — เพิ่มเสียง/ไอคอนใหม่ในคอนฟิกไหนก็ถูกโหลดล่วงหน้าเองโดยไม่ต้องมาแก้ที่นี่
-- ยกเว้นเพลง (`SKIP_KEYS`): ไฟล์ยาว เล่นต่อเนื่องอยู่แล้ว โหลดล่วงหน้ามีแต่กินแรมมือถือ
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AssetPreload = {}

local SOURCES = {
	"ItemCatalog", "CombatConfig", "SoundscapeConfig", "GatherConfig", "EmoteConfig", "QuestConfig",
	"ActionConfig", "VitalsConfig", "EventConfig", "FarmConfig", "FishingConfig", "PremiumConfig", "ArenaConfig",
}
local SKIP_KEYS = { LobbyMusic = true, WorldMusic = true, Music = true }

local function moduleAt(path)
	local node = ReplicatedStorage
	for part in path:gmatch("[^%.]+") do
		node = node and node:FindFirstChild(part)
	end
	return node
end

-- คืนรายการ "rbxassetid://<เลข>" ไม่ซ้ำ · คอนฟิกที่หาไม่เจอ/require ไม่ผ่านถูกข้ามเงียบๆ (โหลดล่วงหน้าเป็นของแถม ห้ามทำเกมพัง)
function AssetPreload.Collect()
	local seen, list, visited = {}, {}, {}
	local function walk(value, depth)
		if depth > 10 then return end
		if type(value) == "string" then
			local id = value:match("^rbxassetid://(%d+)$")
			if id and not seen[id] then
				seen[id] = true
				table.insert(list, "rbxassetid://" .. id)
			end
		elseif type(value) == "table" and not visited[value] then
			visited[value] = true
			for key, child in pairs(value) do
				if not SKIP_KEYS[key] then walk(child, depth + 1) end
			end
		end
	end
	for _, name in ipairs(SOURCES) do
		local module = moduleAt(name)
		if module and module:IsA("ModuleScript") then
			local ok, config = pcall(require, module)
			if ok then walk(config, 0) end
		end
	end
	local vehicle = moduleAt("Vehicle.Config")
	if vehicle then
		local ok, config = pcall(require, vehicle)
		if ok then walk(config, 0) end
	end
	return list
end

return AssetPreload
