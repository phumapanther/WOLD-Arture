-- IslandBuildController: โหมดวางของบนเกาะ — ghost โปร่งใสตามตัวชี้ snap ช่อง 4 studs · สี่เหลี่ยมใต้ ghost หนึ่งแผ่นต่อช่อง
-- เขียว/แดง · R หมุน · คลิก/ปุ่ม "วาง" ส่ง (slot, cx, cz, r) ให้เซิร์ฟเวอร์ ซึ่งเป็นคนตัดสินจริง (สีที่นี่เป็นแค่คำแนะนำ:
-- StreamingEnabled อาจทำให้ยังไม่เห็นบางชิ้น เซิร์ฟเวอร์จะปฏิเสธพร้อมเหตุผลเอง)
--
-- ทางเข้า = BindableEvent WOLD_StartPlacing ที่ไฟล์นี้เป็นคนสร้าง ปุ่มในกระเป๋าไปหยิบตอนกด (บทเรียน PremiumController:
-- คนเปิดหน้าต่างเป็นเจ้าของช่องทาง ไม่ใช่คนกดปุ่ม)
while workspace:GetAttribute("IsLobby") == nil do task.wait() end
if workspace:GetAttribute("IslandMode") ~= true then return end

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local IslandConfig = require(ReplicatedStorage.IslandConfig)
local IslandGrid = require(ReplicatedStorage.IslandGrid)
local ItemCatalog = require(ReplicatedStorage.ItemCatalog)
local Remotes = require(ReplicatedStorage.Remotes)
local IslandBuildGui = require(ReplicatedStorage.UI.IslandBuildGui)

local player = Players.LocalPlayer
local mouse = player:GetMouse() -- ใช้ได้ทั้งเมาส์และนิ้ว (UnitRay ตามจุดแตะล่าสุด)
local gui = IslandBuildGui.new(player:WaitForChild("PlayerGui"))

local GREEN = Color3.fromRGB(90, 220, 110)
local RED = Color3.fromRGB(230, 80, 80)
local REASON_TEXT = {
	edge = "ใกล้ขอบเกาะเกินไป", blocked = "ตรงนี้วางไม่ได้", occupied = "วางทับของอื่น",
	needsoil = "ต้องวางบนผืนดิน", onsoil = "ผืนดินไว้ปลูกผักเท่านั้น", steep = "พื้นชันเกินไป", badground = "ต้องเป็นพื้นหญ้า", obstructed = "มีของตั้งอยู่แล้ว", unreachable = "เดินเข้าไปไม่ได้",
}

local starter = Instance.new("BindableEvent")
starter.Name = "WOLD_StartPlacing"
starter.Parent = ReplicatedStorage

local session = nil -- { slotIndex, id, w, d, r, cx, cz, ok, reason, ghost, squares = {}, folder }
local occupied, occupiedDirty = {}, true

--------------------------------------------------------------------------------
-- ช่องที่ถูกใช้แล้ว อ่านจากแอตทริบิวต์ของโมเดลในโลก (ไม่มี state protocol เพิ่ม)
--------------------------------------------------------------------------------

local function placedFolder()
	local island = workspace:FindFirstChild("WOLD_Island")
	return island and island:FindFirstChild("Placed")
end

local function rebuildOccupied()
	occupied = {}
	local folder = placedFolder()
	if not folder then return end
	for _, model in ipairs(folder:GetChildren()) do
		local fp = model:GetAttribute("Footprint")
		local x, z, r = model:GetAttribute("CellX"), model:GetAttribute("CellZ"), model:GetAttribute("Rot")
		if typeof(fp) == "Vector2" and x and z and r then
			for _, key in ipairs(IslandGrid.cellsOf(x, z, fp.X, fp.Y, r)) do occupied[key] = true end
		end
	end
	occupiedDirty = false
end

-- โฟลเดอร์มาถึงเมื่อไหร่ไม่รู้ (StreamingEnabled) → ลูปถามใหม่จนเจอ แล้วค่อยผูก ChildAdded/Removed
task.spawn(function()
	local hooked = nil
	while true do
		local folder = placedFolder()
		if folder and folder ~= hooked then
			hooked = folder
			folder.ChildAdded:Connect(function() occupiedDirty = true end)
			folder.ChildRemoved:Connect(function() occupiedDirty = true end)
			occupiedDirty = true
		end
		task.wait(0.5)
	end
end)

local function noBuildZones()
	local zones = {}
	local spawnLoc = workspace:FindFirstChildWhichIsA("SpawnLocation", true)
	if spawnLoc then table.insert(zones, { x = spawnLoc.Position.X, z = spawnLoc.Position.Z, radius = IslandConfig.NoBuild.spawn }) end
	for _, npc in ipairs(CollectionService:GetTagged("WOLD_Npc")) do
		local p = npc:IsA("BasePart") and npc.Position or npc:GetPivot().Position
		table.insert(zones, { x = p.X, z = p.Z, radius = IslandConfig.NoBuild.npc })
	end
	return zones
end

--------------------------------------------------------------------------------
-- ghost
--------------------------------------------------------------------------------

local function stop()
	if not session then return end
	if session.folder then session.folder:Destroy() end
	session = nil
	gui:Hide()
end

local function start(slotIndex, id)
	stop()
	if slotIndex == nil then return end
	local protos = ReplicatedStorage:FindFirstChild("WOLD_Placeables")
	local proto = protos and protos:FindFirstChild(id)
	if not proto then warn("[IslandBuild] ไม่มีต้นแบบ " .. tostring(id)) return end
	local fp = proto:GetAttribute("Footprint")
	if typeof(fp) ~= "Vector2" then warn("[IslandBuild] ต้นแบบ " .. id .. " ไม่มี Footprint") return end

	local folder = Instance.new("Folder")
	folder.Name = "IslandGhost"
	folder.Parent = workspace

	local ghost = proto:Clone()
	ghost.Name = "Ghost"
	for _, d in ipairs(ghost:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Transparency = math.max(d.Transparency, 0.55)
			d.CanCollide, d.CanQuery, d.CanTouch = false, false, false
		elseif d:IsA("Script") or d:IsA("ProximityPrompt") or d:IsA("Light") then
			d:Destroy()
		end
	end
	ghost.Parent = folder

	local squares = {}
	for i = 1, fp.X * fp.Y do
		local sq = Instance.new("Part")
		sq.Anchored = true
		sq.CanCollide, sq.CanQuery, sq.CanTouch = false, false, false
		sq.Size = Vector3.new(IslandConfig.Cell - 0.2, 0.15, IslandConfig.Cell - 0.2)
		sq.Material = Enum.Material.Neon
		sq.Transparency = 0.45
		sq.Color = GREEN
		sq.Parent = folder
		squares[i] = sq
	end

	local item = ItemCatalog.Get(id)
	session = { slotIndex = slotIndex, id = id, w = fp.X, d = fp.Y, r = 0, ghost = ghost, squares = squares, folder = folder, ok = false }
	gui:Show(item and item.name or id)
	occupiedDirty = true
end

local function tryPlace()
	if not session then return end
	if not session.ok then
		gui:SetStatus(REASON_TEXT[session.reason] or "วางตรงนี้ไม่ได้", false)
		return
	end
	Remotes.IslandPlace:FireServer(session.slotIndex, session.cx, session.cz, session.r)
end

local function rotate()
	if session then session.r = (session.r + 1) % 4 end
end

-- ทุกเฟรม: ตัวชี้ → เรย์ลง Terrain → ช่อง → ตรวจ → วาง ghost + ระบายสี
RunService.RenderStepped:Connect(function()
	if not session then return end
	if occupiedDirty then rebuildOccupied() end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { workspace.Terrain }
	local ray = mouse.UnitRay
	local hit = workspace:Raycast(ray.Origin, ray.Direction * 600, params)
	if not hit then
		session.ok = false
		gui:SetStatus("ชี้ไปที่พื้นเกาะ", false)
		return
	end
	local cx, cz = IslandGrid.anchorFor(hit.Position.X, hit.Position.Z, session.w, session.d, session.r)
	local ok, reason = IslandGrid.canPlace(occupied, noBuildZones(), cx, cz, session.w, session.d, session.r, session.id)
	session.cx, session.cz, session.ok, session.reason = cx, cz, ok, reason
	session.ghost:PivotTo(IslandGrid.pivotFor(cx, cz, session.w, session.d, session.r, hit.Position.Y))

	local fw, fd = IslandGrid.footprintOf(session.w, session.d, session.r)
	local n = 0
	for i = 0, fw - 1 do
		for j = 0, fd - 1 do
			n += 1
			local sq = session.squares[n]
			local wx, wz = IslandGrid.worldOf(cx + i, cz + j)
			sq.CFrame = CFrame.new(wx, hit.Position.Y + 0.1, wz)
			sq.Color = ok and GREEN or RED
		end
	end
	gui:SetStatus(ok and "วางได้" or (REASON_TEXT[reason] or "วางไม่ได้"), ok)
end)

--------------------------------------------------------------------------------
-- อินพุต
--------------------------------------------------------------------------------

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if not session or gameProcessed then return end
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		tryPlace()
	elseif input.KeyCode == Enum.KeyCode.R then
		rotate()
	elseif input.KeyCode == Enum.KeyCode.Escape then
		stop()
	end
end)

gui.OnRotate = rotate
gui.OnPlace = tryPlace
gui.OnCancel = stop

-- เซิร์ฟเวอร์ตอบ (ok, remaining): วางสำเร็จและยังมีชิ้นเดิมเหลือ = อยู่ในโหมดต่อ (รั้ว 20 อัน) หมดแล้วออก
Remotes.IslandPlace.OnClientEvent:Connect(function(ok, remaining)
	occupiedDirty = true
	if ok and (remaining or 0) <= 0 then stop() end
end)

starter.Event:Connect(start)

player.CharacterRemoving:Connect(stop)
