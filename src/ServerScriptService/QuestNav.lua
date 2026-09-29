-- QuestNav: หา "จุดที่ใกล้ที่สุด" ให้แถบเควส (ฝั่งเซิร์ฟ — StreamingEnabled ทำให้ไคลเอนต์มองไม่เห็นสปอว์เนอร์/จุดเก็บที่อยู่ไกล)
-- กติกา "ของนี้มาจากไหน" อยู่ QuestNavRules (เทสได้) · ไฟล์นี้แค่เดินแท็กหาตำแหน่ง · ใช้ตอนจิ้มแถวเท่านั้น (ไม่ใช่ทุกเฟรม)
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local Remotes = require(game.ReplicatedStorage.Remotes)
local ItemCatalog = require(game.ReplicatedStorage.ItemCatalog)
local QuestNavRules = require(game.ReplicatedStorage.QuestNavRules)
local MapTerrain = require(game.ReplicatedStorage.MapTerrain)

local QuestNav = {}

local function positionOf(inst)
	if inst:IsA("Model") then return inst:GetPivot().Position end
	if inst:IsA("BasePart") then return inst.Position end
	return nil
end

local function nearest(list, from, accept)
	local best, bestDistance
	for _, inst in ipairs(list) do
		if not accept or accept(inst) then
			local p = positionOf(inst)
			if p then
				local d = (p - from).Magnitude
				if not bestDistance or d < bestDistance then best, bestDistance = p, d end
			end
		end
	end
	return best
end

local function setOf(list)
	local s = {}
	for _, v in ipairs(list) do s[v] = true end
	return s
end

-- สปอว์เนอร์ของมอนชนิดนั้น (ข้ามสปอว์เนอร์อีเวนต์ — ว่างเปล่านอกอีเวนต์)
function QuestNav.Spawner(kinds, from)
	local want = setOf(kinds)
	return nearest(CollectionService:GetTagged("WOLD_Spawner"), from, function(s)
		return want[s:GetAttribute("MobKind")] == true and not s:GetAttribute("EventOnly")
	end)
end

-- จุดเก็บที่ยังไม่ถูกเก็บก่อน · ไม่มีเลยค่อยเอาที่ติดคูลดาวน์
function QuestNav.Node(kinds, from)
	local want = setOf(kinds)
	local nodes = CollectionService:GetTagged("WOLD_Node")
	return nearest(nodes, from, function(n) return want[n:GetAttribute("NodeKind")] == true and not n:GetAttribute("Spent") end)
		or nearest(nodes, from, function(n) return want[n:GetAttribute("NodeKind")] == true end)
end

function QuestNav.ForItem(item, from)
	local kinds = QuestNavRules.NodeKindsFor(item)
	local at = #kinds > 0 and QuestNav.Node(kinds, from) or nil
	if at then return at end
	local mobs = QuestNavRules.MobKindsFor(item)
	return #mobs > 0 and QuestNav.Spawner(mobs, from) or nil
end

-- ริมน้ำของเขตตกปลาที่ใกล้สุด — กลางเขตเป็นน้ำ และ Navigation ปฏิเสธจุดหมายที่แผนที่ (MapTerrain) บอกว่าเป็นน้ำ
-- เรย์เคารพ CanCollide: กล่องเขตหมู่บ้าน `Zone_*` สูง 200 สตัดกับพุ่มใบไม้ชนเรย์ได้ แต่ไม่ใช่พื้นให้ยืน (บทเรียน Stations.groundAt)
function QuestNav.Shore(centre)
	local params = RaycastParams.new()
	params.IgnoreWater = false
	params.RespectCanCollide = true
	params.FilterType = Enum.RaycastFilterType.Exclude
	local characters = {}
	for _, p in ipairs(Players:GetPlayers()) do
		if p.Character then characters[#characters + 1] = p.Character end
	end
	params.FilterDescendantsInstances = characters
	return QuestNavRules.PickShore(centre, function(x, z)
		local hit = workspace:Raycast(Vector3.new(x, 2000, z), Vector3.new(0, -4000, 0), params)
		return hit and hit.Material ~= Enum.Material.Water and hit.Position or nil
	end, function(x, z)
		return MapTerrain.At(x, z) == MapTerrain.Water
	end)
end

function QuestNav.FishZone(item, from)
	local best, bestDistance
	for _, c in ipairs(QuestNavRules.FishZones(item)) do
		local d = (Vector2.new(from.X, from.Z) - c).Magnitude
		if not bestDistance or d < bestDistance then best, bestDistance = c, d end
	end
	return best and QuestNav.Shore(best) or nil
end

-- บอร์ดของเมืองนั้น · ไม่มี (บนเกาะ = บอร์ดรวม) → บอร์ดที่ใกล้สุด
function QuestNav.Board(boardId, from)
	local boards = CollectionService:GetTagged("WOLD_QuestBoard")
	return nearest(boards, from, function(b) return b:GetAttribute("BoardId") == boardId end) or nearest(boards, from)
end

-- หุ่นฟางข้างจุดเกิดแรก = ออฟาเรียน
function QuestNav.Dummy()
	for _, d in ipairs(CollectionService:GetTagged("WOLD_Dummy")) do
		if d.Name == "Dummy_Spawn" then return positionOf(d) end
	end
	return nil
end

function QuestNav.ItemName(id)
	local item = ItemCatalog.Get(id)
	return item and item.name or tostring(id)
end

-- ส่งเป้าให้ไคลเอนต์ปักหมุด · หาไม่เจอ = บอก (ไม่เงียบ)
function QuestNav.Send(player, position, label)
	if position then
		Remotes.QuestNav:FireClient(player, position, label or "")
	else
		Remotes.SocialNotify:FireClient(player, "warn", ("ไม่มีจุด%s ในแมพนี้"):format(label and (" " .. label) or ""))
	end
end

return QuestNav
