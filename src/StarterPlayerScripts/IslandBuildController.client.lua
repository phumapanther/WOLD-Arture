-- IslandBuildController: โหมดจัดเกาะมุมสูง (ผู้ใช้สั่ง 2026-09-25) — ทุกการวาง/ย้าย/หมุน/เก็บของบนเกาะผ่านที่นี่
--
-- เข้า: F4 · กระเป๋า → "ใช้ · จัดเกาะ" บนของวางได้ · มือถือ: ปุ่ม 🏗️ ขวาบนข้างปุ่มแนะนำการเล่น — ออก: ทางเดิม · ปุ่มออก
-- ปุ่ม F "เก็บเข้ากระเป๋า" บนของที่วางไว้ **โชว์เฉพาะตอนอยู่ในโหมดนี้** (ผู้ใช้สั่ง 2026-09-25) ไฟล์นี้เป็นเจ้าของ Enabled
-- กล้องล็อกมุมสูงตามตัวละคร (เดินได้ปกติ = เลื่อนมุมมอง) · ล้อเมาส์ซูม
--   แถบล่าง  แตะของ → ghost ตามตัวชี้ → คลิก (มือถือ: ปุ่ม "วาง") วาง
--   ของบนเกาะ แตะ = เลือก (ย้าย/หมุน/เก็บ) · กดค้างแล้วลาก = ย้ายเลย ปล่อยตรงไหนวางตรงนั้น
--
-- ghost: snap ช่อง 4 studs · สี่เหลี่ยมใต้ ghost หนึ่งแผ่นต่อช่อง เขียว/แดง — สีเป็นแค่คำแนะนำ เซิร์ฟเวอร์ตัดสินจริง
-- (StreamingEnabled อาจทำให้ยังไม่เห็นบางชิ้น เซิร์ฟเวอร์จะปฏิเสธพร้อมเหตุผลเอง)
--
-- ช่องทางที่ไฟล์นี้เป็นเจ้าของ (ReplicatedStorage): WOLD_StartPlacing(slot, id) · WOLD_ToggleBuildMode()
-- ปุ่มในกระเป๋า/เมนูหยิบตอนกด (บทเรียน PremiumController: คนเปิดหน้าต่างเป็นเจ้าของช่องทาง)
while workspace:GetAttribute("IsLobby") == nil do task.wait() end
if workspace:GetAttribute("IslandMode") ~= true then return end

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local IslandConfig = require(ReplicatedStorage.IslandConfig)
local IslandGrid = require(ReplicatedStorage.IslandGrid)
local ItemCatalog = require(ReplicatedStorage.ItemCatalog)
local QuestConfig = require(ReplicatedStorage.QuestConfig)
local Responsive = require(ReplicatedStorage.UI.Responsive)
local ProximityPromptService = game:GetService("ProximityPromptService")
local Remotes = require(ReplicatedStorage.Remotes)
local IslandBuildGui = require(ReplicatedStorage.UI.IslandBuildGui)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local gui = IslandBuildGui.new(playerGui)

local GREEN = Color3.fromRGB(90, 220, 110)
local RED = Color3.fromRGB(230, 80, 80)
local REASON_TEXT = {
	edge = "ใกล้ขอบเกาะเกินไป", blocked = "ตรงนี้วางไม่ได้", occupied = "วางทับของอื่น",
	needsoil = "ต้องวางบนผืนดิน", onsoil = "ผืนดินไว้ปลูกผักเท่านั้น", steep = "พื้นชันเกินไป", badground = "ต้องเป็นพื้นหญ้า", obstructed = "มีของตั้งอยู่แล้ว", unreachable = "เดินเข้าไปไม่ได้",
}
local CAMERA_OFFSET = Vector3.new(0, 62, 40) -- มุมก้ม ~57° · ระยะคูณด้วย zoom
local ZOOM_MIN, ZOOM_MAX = 0.55, 1.8
local DRAG_PIXELS = 10 -- ลากเกินนี้ = ย้าย ไม่ใช่แตะเลือก

local starter = Instance.new("BindableEvent")
starter.Name = "WOLD_StartPlacing"
starter.Parent = ReplicatedStorage
local toggler = Instance.new("BindableEvent")
toggler.Name = "WOLD_ToggleBuildMode"
toggler.Parent = ReplicatedStorage

local buildMode = false
local zoom = 1
local session = nil -- ghost: { kind = "new"|"move", slotIndex, id, uid, model, w, d, r, cx, cz, ok, reason, ghost, squares, folder, reach }
local selected = nil -- { model, highlight }
local press = nil -- { model, at = Vector2 } กดค้างบนของอยู่ (ยังไม่รู้ว่าจะแตะหรือลาก)
local pointer = nil -- Vector2 ตำแหน่งตัวชี้ล่าสุด (พิกัดจอ ไม่รวมแถบบน = InputObject.Position)
-- นิ้วที่เป็น "ตัวชี้" = นิ้วที่เริ่มแตะบนโลก (ไม่ใช่บนจอย/ปุ่ม) · นิ้วอื่นขยับไม่มีผล — เดิมทุกนิ้วเลื่อน ghost
-- รวมนิ้วที่คุมจอยเดิน ของที่จะวางจึงวิ่งตามจอย (QA 2026-09-26)
local pointerTouch = nil
local KEY_R = not IslandBuildGui.TouchOnly -- ป้ายปุ่มบอกคีย์ลัดเฉพาะเครื่องที่มีคีย์บอร์ด
local occupied, occupiedDirty = {}, true
local latestSlots = {}
local hiddenHud = nil

--------------------------------------------------------------------------------
-- ช่องที่ถูกใช้แล้ว อ่านจากแอตทริบิวต์ของโมเดลในโลก (ไม่มี state protocol เพิ่ม)
--------------------------------------------------------------------------------

local function placedFolder()
	local island = workspace:FindFirstChild("WOLD_Island")
	return island and island:FindFirstChild("Placed")
end

local occupiedVersion = 0 -- ขยับทุกครั้งที่ผังช่องถูกยึดถูกสร้างใหม่ — ตัวบอกว่าผลตรวจช่องที่แคชไว้หมดอายุ
local function rebuildOccupied()
	occupiedVersion += 1
	occupied = {}
	local folder = placedFolder()
	if not folder then return end
	for _, model in ipairs(folder:GetChildren()) do
		local fp = model:GetAttribute("Footprint")
		local x, z, r = model:GetAttribute("CellX"), model:GetAttribute("CellZ"), model:GetAttribute("Rot")
		if typeof(fp) == "Vector2" and x and z and r then
			for _, key in ipairs(IslandGrid.cellsOf(x, z, fp.X, fp.Y, r)) do occupied[key] = model end
		end
	end
	occupiedDirty = false
end

-- โฟลเดอร์มาถึงเมื่อไหร่ไม่รู้ (StreamingEnabled) → ลูปถามใหม่จนเจอ แล้วค่อยผูก ChildAdded/Removed
-- แอตทริบิวต์ CellX/Rot เปลี่ยนตอนย้าย ไม่มีสัญญาณ Child* → ลูปนี้ทำให้สกปรกเองทุกครึ่งวิระหว่างอยู่ในโหมด
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
		if buildMode then occupiedDirty = true end
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
-- ตัวชี้ → เรย์
--------------------------------------------------------------------------------

local function pointerRay()
	local camera = workspace.CurrentCamera
	if pointer then return camera:ScreenPointToRay(pointer.X, pointer.Y) end
	local at = UserInputService:GetMouseLocation() -- พิกัด viewport (รวมแถบบน) ต่างจาก InputObject.Position
	return camera:ViewportPointToRay(at.X, at.Y)
end

-- ของที่วางแล้วใต้ตัวชี้ (ไต่ขึ้นหาลูกตรงของ Placed = ตัวโมเดลที่มี Uid)
local function placedUnderPointer()
	local folder = placedFolder()
	if not folder then return nil end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { folder }
	local ray = pointerRay()
	local hit = workspace:Raycast(ray.Origin, ray.Direction * 800, params)
	local node = hit and hit.Instance
	while node and node.Parent ~= folder do node = node.Parent end
	return node
end

local function itemName(id)
	local item = ItemCatalog.Get(id or "")
	return item and item.name or tostring(id)
end

--------------------------------------------------------------------------------
-- แถบของ + HUD
--------------------------------------------------------------------------------

local function refreshItems()
	local items = {}
	for index, slot in pairs(latestSlots) do
		local item = slot and ItemCatalog.Get(slot.id)
		if item and item.kind == "placeable" then
			table.insert(items, { slot = index, id = slot.id, name = item.name, icon = item.icon, count = slot.count or 1 })
		end
	end
	table.sort(items, function(a, b) return a.slot < b.slot end)
	gui:SetItems(items)
end

Remotes.InventoryUpdate.OnClientEvent:Connect(function(data)
	latestSlots = type(data) == "table" and type(data.slots) == "table" and data.slots or {}
	if buildMode then refreshItems() end
end)

-- HUD (หลอดเลือด ช่องของใช้ 6 ช่อง) อยู่ตรงแถบล่างพอดี → ซ่อนระหว่างจัดเกาะ คืนตอนออก
local function setHud(visible)
	local hud = playerGui:FindFirstChild("HudGui")
	if not visible then
		if hud and hud.Enabled then hiddenHud = hud; hud.Enabled = false end
	elseif hiddenHud then
		if hiddenHud.Parent then hiddenHud.Enabled = true end
		hiddenHud = nil
	end
end

--------------------------------------------------------------------------------
-- เลือก / ghost
--------------------------------------------------------------------------------

local function stopSession()
	if not session then return end
	if session.folder then session.folder:Destroy() end
	if session.model then
		for _, d in ipairs(session.model:GetDescendants()) do
			if d:IsA("BasePart") then d.LocalTransparencyModifier = 0 end
		end
	end
	session = nil
end

local refreshPanel -- นิยามข้างล่าง (ปุ่มของแผงเรียกกลับมาที่ฟังก์ชันที่ประกาศทีหลัง)

local function deselect()
	if selected and selected.highlight then selected.highlight:Destroy() end
	selected = nil
end

local function selectModel(model)
	deselect()
	if not model then return end
	local highlight = Instance.new("Highlight")
	highlight.FillColor = Color3.fromRGB(255, 210, 110)
	highlight.FillTransparency = 0.8
	highlight.OutlineColor = Color3.fromRGB(255, 210, 110)
	highlight.Parent = model
	selected = { model = model, highlight = highlight }
end

local function makeGhost(source, footprint)
	local folder = Instance.new("Folder")
	folder.Name = "IslandGhost"
	folder.Parent = workspace
	local ghost = source:Clone()
	ghost.Name = "Ghost"
	for _, d in ipairs(ghost:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Transparency = math.max(d.Transparency, 0.55)
			d.CanCollide, d.CanQuery, d.CanTouch = false, false, false
			d.Anchored = true
		elseif d:IsA("LuaSourceContainer") or d:IsA("ProximityPrompt") or d:IsA("Light") or d:IsA("Highlight")
			or d:IsA("BillboardGui") or d:IsA("ParticleEmitter") then
			d:Destroy()
		end
	end
	ghost.Parent = folder
	local squares = {}
	for i = 1, footprint.X * footprint.Y do
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
	return folder, ghost, squares
end

-- หยิบของจากกระเป๋าขึ้นมาวาง
local function startNew(slotIndex, id)
	stopSession()
	deselect()
	local protos = ReplicatedStorage:FindFirstChild("WOLD_Placeables")
	local proto = protos and protos:FindFirstChild(id)
	if not proto then warn("[IslandBuild] ไม่มีต้นแบบ " .. tostring(id)) return end
	local fp = proto:GetAttribute("Footprint")
	if typeof(fp) ~= "Vector2" then warn("[IslandBuild] ต้นแบบ " .. id .. " ไม่มี Footprint") return end
	local folder, ghost, squares = makeGhost(proto, fp)
	session = { kind = "new", slotIndex = slotIndex, id = id, w = fp.X, d = fp.Y, r = 0, ghost = ghost, squares = squares, folder = folder, ok = false,
		-- ผังเดินถึงคิดครั้งเดียวตอนหยิบ (เดิมปล่อยให้ canPlace คิดเองทุก 10 วิกลางลูปเรนเดอร์ = มือถือค้างเป็นจังหวะ)
		reach = IslandGrid.reachSet(nil) }
	occupiedDirty = true
	refreshPanel()
end

-- ยกของที่วางแล้วขึ้นมาย้าย (ตัวจริงจางลง ghost ตามตัวชี้)
local function startMove(model)
	stopSession()
	local fp = model:GetAttribute("Footprint")
	if typeof(fp) ~= "Vector2" then return end
	local folder, ghost, squares = makeGhost(model, fp)
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then d.LocalTransparencyModifier = 0.7 end
	end
	session = {
		kind = "move", uid = model:GetAttribute("Uid"), id = model:GetAttribute("ItemId"), model = model,
		w = fp.X, d = fp.Y, r = model:GetAttribute("Rot") or 0, ghost = ghost, squares = squares, folder = folder, ok = false,
		-- ผังเดินถึงแบบ "ของชิ้นนี้ไม่อยู่" คิดครั้งเดียวต่อการย้าย ไม่ใช่ทุกเฟรม (~30 ms)
		reach = IslandGrid.reachSet(model),
	}
	selectModel(model)
	occupiedDirty = true
	refreshPanel()
end

local function confirm()
	if not session then return end
	if not session.ok then
		gui:SetStatus(REASON_TEXT[session.reason] or "วางตรงนี้ไม่ได้", false)
		return
	end
	if session.kind == "new" then
		Remotes.IslandPlace:FireServer(session.slotIndex, session.cx, session.cz, session.r)
	else
		Remotes.IslandMove:FireServer(session.uid, session.cx, session.cz, session.r)
		stopSession()
		refreshPanel()
	end
end

local function rotate()
	if session then
		session.r = (session.r + 1) % 4
	elseif selected and selected.model.Parent then
		local m = selected.model
		Remotes.IslandMove:FireServer(m:GetAttribute("Uid"), m:GetAttribute("CellX"), m:GetAttribute("CellZ"),
			((m:GetAttribute("Rot") or 0) + 1) % 4)
	end
end

local function pickup()
	if selected and selected.model.Parent then
		Remotes.IslandPickup:FireServer(selected.model:GetAttribute("Uid"))
	end
	deselect()
	refreshPanel()
end

local function cancel()
	if session then
		stopSession()
	else
		deselect()
	end
	refreshPanel()
end

function refreshPanel()
	if session then
		gui:SetActions((session.kind == "move" and "ย้าย: " or "วาง: ") .. itemName(session.id), {
			{ label = KEY_R and "หมุน (R)" or "หมุน", color = "rotate", fn = rotate },
			{ label = "วาง", color = "place", fn = confirm },
			{ label = KEY_R and "ยกเลิก (Esc)" or "ยกเลิก", color = "cancel", fn = cancel },
		})
	elseif selected then
		gui:SetActions(itemName(selected.model:GetAttribute("ItemId")), {
			{ label = "ย้าย", color = "move", fn = function() if selected then startMove(selected.model) end end },
			{ label = KEY_R and "หมุน (R)" or "หมุน", color = "rotate", fn = rotate },
			{ label = "เก็บ", color = "pickup", fn = pickup },
			{ label = KEY_R and "ยกเลิก (Esc)" or "ยกเลิก", color = "cancel", fn = cancel },
		})
	else
		gui:SetActions(nil, nil)
	end
end

--------------------------------------------------------------------------------
-- เข้า / ออกโหมด
--------------------------------------------------------------------------------

local function exitMode()
	if not buildMode then return end
	buildMode = false
	stopSession()
	deselect()
	press = nil
	RunService:UnbindFromRenderStep("WOLD_BuildCamera")
	local camera = workspace.CurrentCamera
	camera.CameraType = Enum.CameraType.Custom
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if humanoid then camera.CameraSubject = humanoid end
	gui:Hide()
	setHud(true)
end

local function enterMode()
	if buildMode then return end
	buildMode = true
	zoom = 1
	local camera = workspace.CurrentCamera
	camera.CameraType = Enum.CameraType.Scriptable
	-- กล้องหลังระบบกล้องของ Roblox ทุกเฟรม: ตามตัวละคร มุมเดิม (เดิน = เลื่อนมุมมอง)
	RunService:BindToRenderStep("WOLD_BuildCamera", Enum.RenderPriority.Camera.Value + 1, function()
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if not root then return end
		local focus = root.Position
		camera.CFrame = CFrame.lookAt(focus + CAMERA_OFFSET * zoom, focus)
	end)
	setHud(false)
	Remotes.RequestInventoryRefresh:FireServer() -- ของในกระเป๋าอาจมาถึงก่อนสคริปต์นี้ผูกฟัง
	refreshItems()
	refreshPanel()
	gui:Show()
	occupiedDirty = true
end

local function toggleMode()
	if buildMode then exitMode() else enterMode() end
end

gui.OnExit = exitMode
gui.OnZoom = function(delta) zoom = math.clamp(zoom + delta, ZOOM_MIN, ZOOM_MAX) end
gui.OnPick = function(slotIndex, id) startNew(slotIndex, id) end

--------------------------------------------------------------------------------
-- ปุ่ม F "เก็บเข้ากระเป๋า" — โชว์เฉพาะในโหมดจัดเกาะ
--------------------------------------------------------------------------------

-- เก็บคืนได้ไหม (ฝั่งที่ดูได้จากโลก): ของที่เก็บเกี่ยวไปแล้ววันนี้ย้ายเข้ากระเป๋าไม่ได้ถึงพรุ่งนี้ = ซ่อน
-- (กติกา "ปุ่มที่ติดคูลดาวน์ต้องซ่อนเสมอ") · เหตุผลอื่น (แปลงยังปลูกอยู่ คอกมีสัตว์) เซิร์ฟเวอร์ปฏิเสธพร้อมข้อความ
local function pickupWanted(model)
	return buildMode and model:GetAttribute("HarvestedDay") ~= QuestConfig.DayNumber()
end

local function pickupPromptOf(model)
	local root = model.PrimaryPart
	return root and root:FindFirstChild("PickupPrompt")
end

local function refreshPickupPrompts()
	local folder = placedFolder()
	if not folder then return end
	for _, model in ipairs(folder:GetChildren()) do
		local prompt = pickupPromptOf(model)
		if prompt then
			local want = pickupWanted(model)
			if prompt.Enabled ~= want then prompt.Enabled = want end
		end
	end
end

-- ลูปถามใหม่ (กฎเหล็ก StreamingEnabled: ของบนเกาะถูกวาง/สตรีมมาถึงตอนไหนก็ได้)
task.spawn(function()
	while true do
		refreshPickupPrompts()
		task.wait(0.25)
	end
end)
-- ปุ่มที่เพิ่งสตรีมมาถึงแล้วโผล่ก่อนรอบลูป — ดับทันที ไม่ให้กระพริบ
ProximityPromptService.PromptShown:Connect(function(prompt)
	if prompt.Name ~= "PickupPrompt" then return end
	local model = prompt.Parent and prompt.Parent.Parent
	if model and not pickupWanted(model) then prompt.Enabled = false end
end)

--------------------------------------------------------------------------------
-- ปุ่มเปิด/ปิดโหมดของมือถือ — ขวาบน ซ้ายมือของปุ่มแนะนำการเล่น (!)
--------------------------------------------------------------------------------

-- กล่อง 220x140 ชิดขวาบน ย่อด้วยสเกลเดียวกับ HUD/ปุ่มแนะนำการเล่น (บทเรียน: ปุ่มที่ตรึงพิกเซลเองจะเดินคนละทาง
-- กับกลุ่มที่ย่อด้วย UIScale แล้วซ้อนกันทุกครั้งที่จอเปลี่ยนขนาด) · ปุ่ม ! อยู่ที่ x -56 กว้าง 38 → ปุ่มนี้ -102
if UserInputService.TouchEnabled then
	local toggleGui = Instance.new("ScreenGui")
	toggleGui.Name = "WOLD_BuildToggle"
	toggleGui.ResetOnSpawn = false
	toggleGui.IgnoreGuiInset = true
	toggleGui.DisplayOrder = 41 -- เหนือหน้าจอจัดเกาะ (40) จะได้กดออกได้เสมอ
	toggleGui.Parent = playerGui

	local group = Instance.new("Frame")
	group.AnchorPoint = Vector2.new(1, 0)
	group.Position = UDim2.new(1, 0, 0, 0)
	group.Size = UDim2.fromOffset(220, 140)
	group.BackgroundTransparency = 1
	group.Parent = toggleGui
	Responsive.Scale(group, Responsive.CornerMinScale())

	local button = Instance.new("TextButton")
	button.Name = "BuildModeButton"
	button.AnchorPoint = Vector2.new(1, 0)
	button.Position = UDim2.new(1, -102, 0, 7)
	button.Size = UDim2.fromOffset(38, 38)
	button.BackgroundColor3 = Color3.fromRGB(40, 38, 46)
	button.BackgroundTransparency = 0.35
	button.BorderSizePixel = 0
	button.TextSize = 20
	button.Text = "🏗️"
	button.AutoButtonColor = false
	button.Parent = group
	local round = Instance.new("UICorner")
	round.CornerRadius = UDim.new(1, 0)
	round.Parent = button
	local rim = Instance.new("UIStroke")
	rim.Color = Color3.fromRGB(196, 150, 60)
	rim.Thickness = 2
	rim.Transparency = 0.2
	rim.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	rim.Parent = button
	button.Activated:Connect(function() toggleMode() end)
	-- สีขอบบอกสถานะ: ทอง = ปิดอยู่ · เขียว = กำลังจัดเกาะ (แตะอีกครั้งเพื่อออก)
	task.spawn(function()
		while true do
			rim.Color = buildMode and Color3.fromRGB(111, 224, 122) or Color3.fromRGB(196, 150, 60)
			task.wait(0.25)
		end
	end)
end

--------------------------------------------------------------------------------
-- ghost ทุกเฟรม: ตัวชี้ → เรย์ลง Terrain → ช่อง → ตรวจ → วาง ghost + ระบายสี
--------------------------------------------------------------------------------

RunService.RenderStepped:Connect(function()
	if not session then return end
	if occupiedDirty then rebuildOccupied() end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { workspace.Terrain }
	local ray = pointerRay()
	local hit = workspace:Raycast(ray.Origin, ray.Direction * 800, params)
	if not hit then
		session.ok = false
		gui:SetStatus("ชี้ไปที่พื้นเกาะ", false)
		return
	end
	local cx, cz = IslandGrid.anchorFor(hit.Position.X, hit.Position.Z, session.w, session.d, session.r)
	local occ = occupied
	if session.kind == "move" then
		-- ช่องของตัวเองไม่นับว่าถูกยึด (ทรงเดียวกับฝั่งเซิร์ฟเวอร์)
		occ = {}
		for key, owner in pairs(occupied) do
			if owner ~= session.model then occ[key] = owner end
		end
	end
	-- ตรวจช่องเฉพาะตอนช่อง/ทิศเปลี่ยน หรือผังช่องถูกยึดเพิ่งสร้างใหม่ (ทุก ~0.5 วิ) — เดิมตรวจทุกเฟรม: ช่องละเรย์ 2 เส้น
	-- + ค้นชิ้นในกล่อง ของ 3x3 = 18 เรย์ 9 กล่องต่อเฟรม มือถือหน่วงตลอดที่ถือของ (QA 2026-09-26) · ghost ยังตามนิ้วทุกเฟรม
	local checkKey = ("%d,%d,%d,%d"):format(cx, cz, session.r, occupiedVersion)
	local ok, reason = session.ok, session.reason
	if checkKey ~= session.checkKey then
		session.checkKey = checkKey
		ok, reason = IslandGrid.canPlace(occ, noBuildZones(), cx, cz, session.w, session.d, session.r, session.id,
			session.model, session.reach)
	end
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

local function isPress(input)
	return input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch
end

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if not buildMode or gameProcessed then return end
	if isPress(input) then
		if input.UserInputType == Enum.UserInputType.Touch then pointerTouch = input end
		pointer = Vector2.new(input.Position.X, input.Position.Y)
		if session then
			-- เมาส์คลิก = วางเลย · นิ้วแตะ = แค่ย้าย ghost มาตรงนั้น (ยืนยันด้วยปุ่ม "วาง" จะได้ไม่วางพลาด)
			if input.UserInputType == Enum.UserInputType.MouseButton1 then confirm() end
			return
		end
		local model = placedUnderPointer()
		if model then
			press = { model = model, at = pointer }
		else
			deselect()
			refreshPanel()
		end
	elseif input.KeyCode == Enum.KeyCode.R then
		rotate()
	elseif input.KeyCode == Enum.KeyCode.Escape then
		cancel()
	end
end)

UserInputService.InputChanged:Connect(function(input)
	if not buildMode then return end
	if input.UserInputType == Enum.UserInputType.MouseMovement
		or (input.UserInputType == Enum.UserInputType.Touch and input == pointerTouch) then
		pointer = Vector2.new(input.Position.X, input.Position.Y)
		if press and (pointer - press.at).Magnitude > DRAG_PIXELS then
			local model = press.model
			press = nil
			if model.Parent then
				startMove(model)
				session.dragging = true
			end
		end
	elseif input.UserInputType == Enum.UserInputType.MouseWheel then
		zoom = math.clamp(zoom - input.Position.Z * 0.1, ZOOM_MIN, ZOOM_MAX)
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if not buildMode or not isPress(input) then return end
	if input.UserInputType == Enum.UserInputType.Touch then
		if input ~= pointerTouch then return end -- นิ้วจอย/นิ้วบนปุ่มปล่อย ไม่ใช่การวาง
		pointerTouch = nil
	end
	if session and session.dragging then
		confirm() -- ลากแล้วปล่อย = วางตรงนั้น (วางไม่ได้ = ghost ค้างให้เลื่อนต่อ/ยกเลิก)
		if session then session.dragging = false end
	elseif press then
		local model = press.model
		press = nil
		if model.Parent then selectModel(model) end
		refreshPanel()
	end
end)

ContextActionService:BindAction("WOLD_IslandBuildMode", function(_, inputState)
	if inputState == Enum.UserInputState.Begin then toggleMode() end
	return Enum.ContextActionResult.Sink
end, false, Enum.KeyCode.F4)

-- เซิร์ฟเวอร์ตอบ (ok, remaining): วางสำเร็จและยังมีชิ้นเดิมเหลือ = วางต่อ (รั้ว 20 อัน) หมดแล้วเลิกถือ
Remotes.IslandPlace.OnClientEvent:Connect(function(ok, remaining)
	occupiedDirty = true
	if ok and (remaining or 0) <= 0 and session and session.kind == "new" then
		stopSession()
		refreshPanel()
	elseif ok and session and session.kind == "new" then
		-- วางต่อ (รั้ว 20 อัน): ของที่เพิ่งวางอาจปิดทางเดิน คิดผังเดินถึงใหม่ตรงนี้ ไม่ใช่ในลูปเรนเดอร์
		session.reach = IslandGrid.reachSet(nil)
		session.checkKey = nil
	end
end)
Remotes.IslandMove.OnClientEvent:Connect(function()
	occupiedDirty = true
end)

-- ของที่เลือกไว้หายไป (เก็บคืน/ถูกลบ) → ปล่อยการเลือก
task.spawn(function()
	while true do
		if selected and not selected.model.Parent then
			deselect()
			refreshPanel()
		end
		task.wait(0.5)
	end
end)

-- เข้าจากกระเป๋า: เข้าโหมดแล้วหยิบชิ้นนั้นขึ้นมาเลย
starter.Event:Connect(function(slotIndex, id)
	enterMode()
	if slotIndex then startNew(slotIndex, id) end
end)
toggler.Event:Connect(toggleMode)

player.CharacterRemoving:Connect(exitMode)
