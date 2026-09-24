-- ArenaController: ทุกอย่างที่ผู้เล่นเห็นและกดในสนาม PVP — แถบสกอร์ หน้าร้าน ตารางจบเกม
-- มุมมองบุคคลที่หนึ่ง และปุ่ม F ที่กลายเป็น "ใช้ยา"
--
-- ⚠️ **ไม่มีตรรกะของเกมอยู่ที่นี่เลย** เซิร์ฟเวอร์เป็นคนบอกว่าเฟสไหน ซิลเวอร์เท่าไหร่ ซื้อได้หรือยัง
-- ไฟล์นี้วาดตามที่ได้รับ และส่งสิ่งที่ผู้เล่น *ขอ* กลับไป (`RequestArenaBuy`) — ไม่ใช่สิ่งที่ผู้เล่นทำ
while workspace:GetAttribute("IsLobby") == nil do
	task.wait(0.2)
end
if workspace:GetAttribute("ArenaMode") ~= true then return end

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")

local ArenaConfig = require(game.ReplicatedStorage.ArenaConfig)
local ArenaHudGui = require(game.ReplicatedStorage.UI.ArenaHudGui)
local ArenaMapGui = require(game.ReplicatedStorage.UI.ArenaMapGui)
local ArenaScoreboardGui = require(game.ReplicatedStorage.UI.ArenaScoreboardGui)
local ArenaShopGui = require(game.ReplicatedStorage.UI.ArenaShopGui)
local Remotes = require(game.ReplicatedStorage.Remotes)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local hud = ArenaHudGui.new()
local shop = ArenaShopGui.new()
local board = ArenaScoreboardGui.new()
local tabBoard = ArenaScoreboardGui.new() -- ตาราง Tab ระหว่างเล่น หน้าตาเดียวกับตารางจบเกม
tabBoard:SetLive(true)
local map = ArenaMapGui.new()
hud.gui.Parent = playerGui
shop.gui.Parent = playerGui
board.gui.Parent = playerGui
tabBoard.gui.Parent = playerGui
map.gui.Parent = playerGui
hud:SetVisible(true)

local snapshot = nil
local bagSlots = {} -- ช่องกระเป๋าล่าสุดที่เซิร์ฟเวอร์ส่งมา — ใช้หาว่ายาที่ซื้อไว้อยู่ช่องไหน

--------------------------------------------------------------------------------
-- มุมมองบุคคลที่หนึ่ง (ผู้ใช้สั่ง: "โหมดนี้ตอนเล่นเป็นเฟิสเพอเซิ้นเท่านั้น")
--------------------------------------------------------------------------------
-- `CameraMode.LockFirstPerson` ล็อกทั้งมุมกล้องและเมาส์ — ซึ่งถูกต้องตอนสู้ แต่ทำให้กดปุ่มในหน้าร้าน
-- ไม่ได้ · `UserInputService.ModalEnabled` คือทางออกที่ Roblox เตรียมไว้: มันปลดเมาส์ออกจากการล็อก
-- ของกล้องโดยไม่ต้องสลับโหมดกล้องไปมา (การสลับโหมดทำให้ภาพกระตุกและซูมออกให้เห็นแมพ)
local spectating = false -- ตายแล้วกำลังดูเพื่อน — ต้องเป็นมุมบุคคลที่สามถึงจะเห็นตัวเพื่อน

local function setFirstPerson(on)
	player.CameraMode = (on and not spectating) and Enum.CameraMode.LockFirstPerson or Enum.CameraMode.Classic
end
setFirstPerson(true)
player.CharacterAdded:Connect(function()
	task.wait(0.2)
	setFirstPerson(not shop:IsVisible())
end)

--------------------------------------------------------------------------------
-- หน้าร้าน
--------------------------------------------------------------------------------
-- ร้านเปิด = **ล็อกมุมกล้องไว้ + ปล่อยเมาส์** (ผู้ใช้สั่ง 2026-09-24: "ร้านเปิดต้องเลื่อนเมาส์ได้")
-- ModalEnabled อย่างเดียวไม่พอในมุมบุคคลที่หนึ่ง: สคริปต์กล้องของ Roblox ล็อกเมาส์ไว้กลางจอทุกเฟรม
-- จึงต้องหยุดกล้อง (Scriptable) และเขียน MouseBehavior ทับหลังกล้องทุกเฟรม (ดู ArenaViewmodel ข้างล่าง)
local function setShopOpen(open)
	shop:SetVisible(open)
	UserInputService.ModalEnabled = open
	local camera = workspace.CurrentCamera
	if camera and not spectating then
		camera.CameraType = open and Enum.CameraType.Scriptable or Enum.CameraType.Custom
	end
	-- ปิดร้าน = กลับมุมบุคคลที่หนึ่ง (เดิมกลับเฉพาะตอนเกิดใหม่ ปิดร้านช่วงเตรียมตัวแล้วค้างมุมบุคคลที่สาม)
	setFirstPerson(not open)
	if snapshot then shop:Render(snapshot) end
end

shop:OnClose(function() setShopOpen(false) end)
shop:OnBuy(function(id)
	Remotes.RequestArenaBuy:FireServer(id)
end)

-- **เปิดเองตอนเริ่มช่วงซื้อของ ปิดเองตอนหมดเวลา** — ร้านที่ต้องกดเปิดเองคือร้านที่คนลืมเปิดแล้ว
-- ออกไปสู้มือเปล่า · ระหว่างนั้นกด B ปิด/เปิดซ้ำได้ตามใจ
local lastPhase = nil
local function onPhaseChanged(phase)
	if phase == "buy" then
		setShopOpen(true)
	elseif lastPhase == "buy" then
		setShopOpen(false)
	end
	lastPhase = phase
end

-- B = เปิด/ปิดร้าน · เปิดได้ช่วงเตรียมตัว หรือระหว่างสู้ตอนยืนอยู่ในฐานตัวเอง (`snapshot.canShop` จากเซิร์ฟ)
ContextActionService:BindAction("ArenaShop", function(_, state)
	if state ~= Enum.UserInputState.Begin then return end
	if not snapshot or not (snapshot.canShop or shop:IsVisible()) then return end
	setShopOpen(not shop:IsVisible())
end, true, Enum.KeyCode.B)
ContextActionService:SetTitle("ArenaShop", "ร้าน")

--------------------------------------------------------------------------------
-- มุมบุคคลที่หนึ่ง: เห็นแขน มือ และอาวุธของตัวเอง (ผู้ใช้สั่ง 2026-09-24)
--------------------------------------------------------------------------------
-- สคริปต์กล้องของ Roblox ตั้ง LocalTransparencyModifier = 1 ให้ทุกชิ้นของตัวละครทุกเฟรมตอนซูมสุด
-- → เขียนกลับเป็น 0 ให้แขน/มือ และทุกชิ้นของโมเดลอาวุธ (Model ลูกของตัวละครที่ไม่ใช่ Accessory)
-- **หลังกล้องทุกเฟรม** (priority Camera+1) ไม่งั้นกล้องเขียนทับ · หัว ลำตัว ผม หมวก ยังซ่อนอยู่ ไม่บังจอ
local ARM = { LeftUpperArm = true, LeftLowerArm = true, LeftHand = true,
	RightUpperArm = true, RightLowerArm = true, RightHand = true }
RunService:BindToRenderStep("ArenaViewmodel", Enum.RenderPriority.Camera.Value + 1, function()
	if shop:IsVisible() or board.gui.Enabled then
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
		UserInputService.MouseIconEnabled = true
	end
	local character = player.Character
	if not character or player.CameraMode ~= Enum.CameraMode.LockFirstPerson then return end
	for _, part in ipairs(character:GetDescendants()) do
		if part:IsA("BasePart") and (ARM[part.Name]
			or (part:FindFirstAncestorWhichIsA("Model") ~= character and not part:FindFirstAncestorWhichIsA("Accessory"))) then
			part.LocalTransparencyModifier = 0
		end
	end
end)

--------------------------------------------------------------------------------
-- ปุ่ม F = ใช้ยาที่ซื้อไว้
--------------------------------------------------------------------------------
-- ใช้ทาง `RequestUseItem` เดิมของเกมหลักทั้งดุ้น ท่ากินและผลของยาจึงเหมือนกันเป๊ะโดยไม่ต้องเขียนใหม่
-- (เอกสารออกแบบเตือนไว้ว่าในเกมหลัก F คือฟาร์มออโต้ — สคริปต์นั้นถูกปิดในสนามแล้ว)
Remotes.InventoryUpdate.OnClientEvent:Connect(function(data)
	bagSlots = (data and data.slots) or {}
end)

ContextActionService:BindAction("ArenaUsePotion", function(_, state)
	if state ~= Enum.UserInputState.Begin then return end
	local want = snapshot and snapshot.loadout and snapshot.loadout.use
	if not want then return end
	for index, slot in pairs(bagSlots) do
		if type(slot) == "table" and slot.id == want then
			Remotes.RequestUseItem:FireServer(tonumber(index))
			return
		end
	end
end, false, Enum.KeyCode.F)

--------------------------------------------------------------------------------
-- ตายแล้วดูเพื่อนที่ยังรอด + สลับคนดูได้ (ผู้ใช้สั่ง 2026-09-24)
--------------------------------------------------------------------------------
local specName = nil -- ดูใครอยู่ (จำเป็นชื่อ ไม่ใช่ลำดับ — รายชื่อหดเมื่อเพื่อนตาย ลำดับจะเลื่อนไปคนอื่น)

-- หา "ร่าง" ของสมาชิกในรายชื่อ: คน = ตัวละครของ Player · บอท = โมเดลที่เซิร์ฟส่งมาเลย
local function bodyOf(member)
	if member.userId then
		local other = Players:GetPlayerByUserId(member.userId)
		return other and other.Character
	end
	return member.model
end

local function aliveTeammates(snap)
	local list = {}
	for _, member in ipairs(snap.roster or {}) do
		if member.side == snap.mySide and member.alive and not member.me then
			local body = bodyOf(member)
			local humanoid = body and body:FindFirstChildOfClass("Humanoid")
			if humanoid and humanoid.Health > 0 then
				table.insert(list, { name = member.name, humanoid = humanoid })
			end
		end
	end
	return list
end

local updateSpectator -- ประกาศข้างล่าง

local function stepSpectate(dir)
	if not spectating or not snapshot then return end
	local mates = aliveTeammates(snapshot)
	if #mates < 2 then return end
	local at = 1
	for i, m in ipairs(mates) do if m.name == specName then at = i end end
	specName = mates[((at - 1 + dir) % #mates) + 1].name
	updateSpectator(snapshot)
end
hud:OnSpectateStep(stepSpectate)

ContextActionService:BindAction("ArenaSpectate", function(_, state, input)
	if state ~= Enum.UserInputState.Begin or not spectating then return Enum.ContextActionResult.Pass end
	local back = input.KeyCode == Enum.KeyCode.Q or input.KeyCode == Enum.KeyCode.Left
	stepSpectate(back and -1 or 1)
	return Enum.ContextActionResult.Sink
end, false, Enum.KeyCode.Q, Enum.KeyCode.E, Enum.KeyCode.Left, Enum.KeyCode.Right)

--------------------------------------------------------------------------------
-- กล้องของคนที่ยังไม่มีร่าง
--------------------------------------------------------------------------------
-- คนที่ตายแล้วยังมีศพให้กล้องเกาะ แต่คนที่ **เพิ่งเข้ามากลางรอบ** ไม่มีร่างเลย (เซิร์ฟเวอร์ปิด
-- `CharacterAutoLoads` เพราะมันเป็นคนตัดสินว่าใครเกิดเมื่อไหร่) — จอของเขาจะดำสนิทจนรอบใหม่เริ่ม
-- ⚠️ เซิร์ฟเวอร์ตั้งกล้องของไคลเอนต์อื่นไม่ได้ มุมมองระหว่างรอจึงต้องตั้งที่นี่
function updateSpectator(snap)
	local camera = workspace.CurrentCamera
	if not camera then return end

	-- ตายแล้ว (หรือมาสาย) ระหว่างรอบ → กล้องเกาะเพื่อนที่ยังยืนอยู่ + การ์ดดาเมจขวาจอ
	local dead = not snap.alive and (snap.phase == "live" or snap.phase == "roundEnd")
	local mates = dead and aliveTeammates(snap) or {}
	local wasSpectating = spectating
	spectating = #mates > 0
	hud:SetDamageCards(dead and snap.dealt or nil)
	if spectating then
		local target = mates[1]
		for _, m in ipairs(mates) do if m.name == specName then target = m end end
		specName = target.name
		camera.CameraType = Enum.CameraType.Custom
		if camera.CameraSubject ~= target.humanoid then camera.CameraSubject = target.humanoid end
		if not wasSpectating then setFirstPerson(false) end
		hud:SetSpectating(target.name, #mates)
		return
	end
	hud:SetSpectating(nil)
	if wasSpectating then setFirstPerson(not shop:IsVisible()) end

	local ownHumanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if ownHumanoid and camera.CameraSubject ~= ownHumanoid then camera.CameraSubject = ownHumanoid end

	local hasBody = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if hasBody or not snap.centre then
		if camera.CameraType == Enum.CameraType.Scriptable and not shop:IsVisible() then -- ร้านเปิดอยู่ = ล็อกกล้องไว้โดยตั้งใจ
			camera.CameraType = Enum.CameraType.Custom
		end
		return
	end
	camera.CameraType = Enum.CameraType.Scriptable
	camera.CFrame = CFrame.lookAt(snap.centre + Vector3.new(0, 120, 150), snap.centre)
end

--------------------------------------------------------------------------------
-- ภาพจากเซิร์ฟเวอร์
--------------------------------------------------------------------------------
local function bannerFor(snap)
	if snap.phase == "roundEnd" and snap.lastWinner then
		if snap.lastWinner == "draw" then return "รอบนี้เสมอ", nil end
		local team = ArenaConfig.Teams[snap.lastWinner]
		local mine = snap.lastWinner == snap.mySide
		return ("%s ชนะรอบ %d"):format(team.name, snap.round),
			mine and Color3.fromRGB(96, 220, 140) or Color3.fromRGB(230, 120, 112)
	end
	if snap.phase == "buy" then return "เตรียมตัว — ซื้อของได้เลย (B)", Color3.fromRGB(226, 184, 78) end
	if snap.phase == "live" and not snap.alive and not spectating then
		return "คุณตายแล้ว — รอรอบหน้า", Color3.fromRGB(210, 200, 190)
	end
	return nil, nil
end

Remotes.ArenaState.OnClientEvent:Connect(function(snap)
	if not snap then return end
	snapshot = snap
	hud:Render(snap)
	updateSpectator(snap)
	if snap.phase ~= lastPhase then onPhaseChanged(snap.phase) end
	-- เดินออกจากฐานระหว่างสู้ = ร้านปิดเอง
	if shop:IsVisible() and not snap.canShop then setShopOpen(false) end
	if shop:IsVisible() then shop:Render(snap) end
	hud:SetShopHint(snap.phase == "live" and snap.canShop and not shop:IsVisible())
	local text, colour = bannerFor(snap)
	hud:SetBanner(text, colour)
	if tabBoard.gui.Enabled then tabBoard:RenderLive(snap) end
end)

--------------------------------------------------------------------------------
-- Tab = ตารางสถิติ KDA/อันดับ/ดาเมจ (กดค้าง) · M = แผนที่สนาม (ผู้ใช้สั่ง 2026-09-24)
--------------------------------------------------------------------------------
-- รายชื่อผู้เล่นของ Roblox ก็ผูกกับ Tab — ปิดทิ้งในสนาม ไม่งั้นขึ้นซ้อนกันสองตาราง
task.spawn(function()
	for _ = 1, 20 do
		if pcall(StarterGui.SetCoreGuiEnabled, StarterGui, Enum.CoreGuiType.PlayerList, false) then return end
		task.wait(0.5)
	end
end)

ContextActionService:BindAction("ArenaTab", function(_, state)
	if state == Enum.UserInputState.Begin and snapshot and not board.gui.Enabled then
		tabBoard:RenderLive(snapshot)
		tabBoard:SetVisible(true)
	elseif state == Enum.UserInputState.End or state == Enum.UserInputState.Cancel then
		tabBoard:SetVisible(false)
	end
	return Enum.ContextActionResult.Sink
end, true, Enum.KeyCode.Tab)
ContextActionService:SetTitle("ArenaTab", "สถิติ")

local mapLoop = nil
local function setMap(open)
	if open and not (snapshot and map:Build(snapshot.mapId, snapshot.mapName)) then open = false end
	map:SetVisible(open)
	if mapLoop then mapLoop:Disconnect() mapLoop = nil end
	if not open then return end
	mapLoop = RunService.RenderStepped:Connect(function()
		local marks = {}
		for _, member in ipairs(snapshot.roster or {}) do
			-- เฉพาะฝั่งเรา: แผนที่ที่บอกตำแหน่งศัตรูคือ wallhack ฟรี
			if member.side == snapshot.mySide and member.alive then
				local body = member.me and player.Character or bodyOf(member)
				local root = body and body:FindFirstChild("HumanoidRootPart")
				if root then
					table.insert(marks, {
						pos = root.Position,
						look = member.me and root.CFrame.LookVector or nil,
						colour = member.me and Color3.fromRGB(255, 255, 255) or ArenaConfig.Teams[member.side].colour,
						me = member.me,
					})
				end
			end
		end
		map:SetMarks(marks)
	end)
end

ContextActionService:BindAction("ArenaMap", function(_, state)
	if state == Enum.UserInputState.Begin and not board.gui.Enabled then setMap(not map:IsVisible()) end
	return Enum.ContextActionResult.Sink
end, true, Enum.KeyCode.M)
ContextActionService:SetTitle("ArenaMap", "แผนที่")

--------------------------------------------------------------------------------
-- ตารางจบเกม
--------------------------------------------------------------------------------
Remotes.ArenaMatchEnd.OnClientEvent:Connect(function(result)
	setShopOpen(false)
	setMap(false)
	tabBoard:SetVisible(false)
	hud:SetSpectating(nil)
	hud:SetDamageCards(nil)
	-- ปลดล็อกกล้องตอนจบ: หน้าตารางต้องกดปุ่มได้ และไม่มีอะไรให้เล็งอีกแล้ว
	setFirstPerson(false)
	UserInputService.ModalEnabled = true
	board:Render(result)
	board:SetVisible(true)
	hud:SetBanner(nil)
end)

board:OnBack(function()
	Remotes.RequestReturnToLobby:FireServer()
	board.backButton.Text = "กำลังกลับ…"
end)

--------------------------------------------------------------------------------
-- ข้อความสั้นๆ จากเซิร์ฟเวอร์ (ซื้อไม่ผ่าน เงินไม่พอ ฯลฯ)
--------------------------------------------------------------------------------
Remotes.ArenaNotice.OnClientEvent:Connect(function(kind, text)
	-- ยืมป้ายกลางจอของ HUD: ข้อความในสนามต้องอ่านได้โดยไม่ละสายตา และมันหายเองในสองวินาที
	hud:SetBanner(text, kind == "warn" and Color3.fromRGB(230, 120, 112) or Color3.fromRGB(226, 184, 78))
	task.delay(2, function()
		if snapshot then
			local again, colour = bannerFor(snapshot)
			hud:SetBanner(again, colour)
		end
	end)
end)
