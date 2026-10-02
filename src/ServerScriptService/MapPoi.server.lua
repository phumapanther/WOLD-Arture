-- MapPoi: หมุดบนแผนที่ v2 (2026-10-02) — สแกนของจริงในแมพแล้วส่งให้ไคลเอนต์ตอนเปิดแผนที่ (เพลสหลักเท่านั้น)
-- ฝั่งเซิร์ฟเพราะ StreamingEnabled: ไคลเอนต์มองไม่เห็น NPC/สปอว์เนอร์/บอร์ดที่อยู่ไกล (บทเรียน QuestNav)
-- ย้ายของในสตูดิโอ = หมุดตามหลังรีสตาร์ท ไม่มีพิกัดฝังที่นี่ · กติกาหมวด/อีโมจิ/รวมกลุ่ม = MapPoiRules.Build
-- สแกนตอนบูต + ทุก 120 วิ: สถานีพาหนะหาฝั่งจริงตอนบูต (Stations.build) อาจเสร็จหลังสแกนแรก
local CollectionService = game:GetService("CollectionService")
local ServerConfig = require(script.Parent.ServerConfig)
if ServerConfig.IsLobby or ServerConfig.IsFarm or ServerConfig.IsArena then return end

local Remotes = require(game.ReplicatedStorage.Remotes)
local MapPoiRules = require(game.ReplicatedStorage.MapPoiRules)
local GatherConfig = require(game.ReplicatedStorage.GatherConfig)
local QuestConfig = require(game.ReplicatedStorage.QuestConfig)
local StoryConfig = require(game.ReplicatedStorage.StoryConfig)
local FishingConfig = require(game.ReplicatedStorage.FishingConfig)
local ItemCatalog = require(game.ReplicatedStorage.ItemCatalog)
local QuestNav = require(script.Parent.QuestNav)
local Stations = require(script.Parent.Vehicle.Stations)

local RESCAN_SECONDS = 120
local MAIN_ZONES = { IslandPond = false } -- เขตตกปลาที่ไม่ได้อยู่ในเกมหลัก

local function at(inst)
	local p = inst:IsA("Model") and inst:GetPivot().Position or inst:IsA("BasePart") and inst.Position or nil
	return p and { x = p.X, y = p.Y, z = p.Z }
end
local function with(t, extra)
	for k, v in pairs(extra) do t[k] = v end
	return t
end

local boardNames = {}
for _, b in ipairs(QuestConfig.Boards) do boardNames[b.id] = b.name end
boardNames[QuestConfig.MainBoardId] = "สมาคม"

local shores = {} -- ริมน้ำของเขตตกปลา ไม่ขยับ หาครั้งเดียว
local function fishing()
	local out = {}
	for _, zone in ipairs(FishingConfig.Zones) do
		if MAIN_ZONES[zone.id] ~= false then
			if shores[zone.id] == nil then shores[zone.id] = QuestNav.Shore(zone.centre) or false end
			local p = shores[zone.id]
			local fish = zone.fish and zone.fish[1] and ItemCatalog.Get(zone.fish[1].item)
			if p then out[#out + 1] = { id = zone.id, name = zone.name, fish = fish and fish.name, x = p.X, y = p.Y, z = p.Z } end
		end
	end
	return out
end

local function collect()
	local src = { npcs = {}, story = {}, spawners = {}, ores = {}, boards = {}, stations = {}, fishing = fishing() }
	for _, n in ipairs(CollectionService:GetTagged("WOLD_Npc")) do
		local p = at(n)
		if p then src.npcs[#src.npcs + 1] = with(p, { kind = n:GetAttribute("NpcKind"), name = n:GetAttribute("NpcName") or n.Name }) end
	end
	for _, n in ipairs(CollectionService:GetTagged("WOLD_StoryNpc")) do
		local id, p = n:GetAttribute("StoryNpc"), at(n)
		local info = id and StoryConfig.Npcs[id]
		if p and info then src.story[#src.story + 1] = with(p, { id = id, name = info.name }) end
	end
	local dummy = QuestNav.Dummy()
	src.oforian = dummy and { x = dummy.X, y = dummy.Y, z = dummy.Z }
	for _, s in ipairs(CollectionService:GetTagged("WOLD_Spawner")) do
		local kind, p = s:GetAttribute("MobKind"), at(s)
		local mob = kind and GatherConfig.Mobs[kind]
		if p and mob then src.spawners[#src.spawners + 1] = with(p, { kind = kind, name = mob.name, event = s:GetAttribute("EventOnly") }) end
	end
	local wold = workspace:FindFirstChild("WOLD")
	local mineral = wold and wold:FindFirstChild("Mineral")
	for _, d in ipairs(mineral and mineral:GetDescendants() or {}) do
		local kind = d:GetAttribute("NodeKind")
		local p = kind and CollectionService:HasTag(d, "WOLD_Node") and at(d)
		if p then src.ores[#src.ores + 1] = with(p, { kind = kind }) end
	end
	for _, b in ipairs(CollectionService:GetTagged("WOLD_QuestBoard")) do
		local name, p = boardNames[b:GetAttribute("BoardId")], at(b)
		if p and name then src.boards[#src.boards + 1] = with(p, { id = b:GetAttribute("BoardId"), name = name }) end
	end
	for id, station in pairs(Stations.List) do
		local p = station.resolvedPos
		if p then src.stations[#src.stations + 1] = { id = id, vtype = station.vtype, title = station.title, x = p.X, y = p.Y, z = p.Z } end
	end
	table.sort(src.stations, function(a, b) return a.id < b.id end) -- pairs ไม่มีลำดับ: id หมุดคงที่ระหว่างสแกน
	return MapPoiRules.Build(src)
end

local pins = {}
task.spawn(function()
	task.wait(5)
	while true do
		local ok, result = pcall(collect)
		if ok then pins = result else warn("[MapPoi] สแกนหมุดไม่สำเร็จ: " .. tostring(result)) end
		task.wait(next(Stations.List) == nil and 15 or RESCAN_SECONDS) -- สถานียังไม่สร้าง = ถามใหม่เร็วๆ
	end
end)

local lastAsk = {}
Remotes.RequestMapPois.OnServerEvent:Connect(function(player)
	local now = os.clock()
	if lastAsk[player] and now - lastAsk[player] < 2 then return end
	lastAsk[player] = now
	Remotes.MapPois:FireClient(player, pins)
end)
game:GetService("Players").PlayerRemoving:Connect(function(player) lastAsk[player] = nil end)
