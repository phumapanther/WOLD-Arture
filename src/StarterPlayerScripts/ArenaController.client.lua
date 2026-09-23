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
local UserInputService = game:GetService("UserInputService")

local ArenaConfig = require(game.ReplicatedStorage.ArenaConfig)
local ArenaHudGui = require(game.ReplicatedStorage.UI.ArenaHudGui)
local ArenaScoreboardGui = require(game.ReplicatedStorage.UI.ArenaScoreboardGui)
local ArenaShopGui = require(game.ReplicatedStorage.UI.ArenaShopGui)
local Remotes = require(game.ReplicatedStorage.Remotes)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local hud = ArenaHudGui.new()
local shop = ArenaShopGui.new()
local board = ArenaScoreboardGui.new()
hud.gui.Parent = playerGui
shop.gui.Parent = playerGui
board.gui.Parent = playerGui
hud:SetVisible(true)

local snapshot = nil
local bagSlots = {} -- ช่องกระเป๋าล่าสุดที่เซิร์ฟเวอร์ส่งมา — ใช้หาว่ายาที่ซื้อไว้อยู่ช่องไหน

--------------------------------------------------------------------------------
-- มุมมองบุคคลที่หนึ่ง (ผู้ใช้สั่ง: "โหมดนี้ตอนเล่นเป็นเฟิสเพอเซิ้นเท่านั้น")
--------------------------------------------------------------------------------
-- `CameraMode.LockFirstPerson` ล็อกทั้งมุมกล้องและเมาส์ — ซึ่งถูกต้องตอนสู้ แต่ทำให้กดปุ่มในหน้าร้าน
-- ไม่ได้ · `UserInputService.ModalEnabled` คือทางออกที่ Roblox เตรียมไว้: มันปลดเมาส์ออกจากการล็อก
-- ของกล้องโดยไม่ต้องสลับโหมดกล้องไปมา (การสลับโหมดทำให้ภาพกระตุกและซูมออกให้เห็นแมพ)
local function setFirstPerson(on)
	player.CameraMode = on and Enum.CameraMode.LockFirstPerson or Enum.CameraMode.Classic
end
setFirstPerson(true)
player.CharacterAdded:Connect(function()
	task.wait(0.2)
	setFirstPerson(not shop:IsVisible())
end)

--------------------------------------------------------------------------------
-- หน้าร้าน
--------------------------------------------------------------------------------
local function setShopOpen(open)
	shop:SetVisible(open)
	UserInputService.ModalEnabled = open
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

ContextActionService:BindAction("ArenaShop", function(_, state)
	if state ~= Enum.UserInputState.Begin then return end
	if not snapshot or snapshot.phase ~= "buy" then return end
	setShopOpen(not shop:IsVisible())
end, false, Enum.KeyCode.B)

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
-- กล้องของคนที่ยังไม่มีร่าง
--------------------------------------------------------------------------------
-- คนที่ตายแล้วยังมีศพให้กล้องเกาะ แต่คนที่ **เพิ่งเข้ามากลางรอบ** ไม่มีร่างเลย (เซิร์ฟเวอร์ปิด
-- `CharacterAutoLoads` เพราะมันเป็นคนตัดสินว่าใครเกิดเมื่อไหร่) — จอของเขาจะดำสนิทจนรอบใหม่เริ่ม
-- ⚠️ เซิร์ฟเวอร์ตั้งกล้องของไคลเอนต์อื่นไม่ได้ มุมมองระหว่างรอจึงต้องตั้งที่นี่
local function updateSpectator(snap)
	local camera = workspace.CurrentCamera
	if not camera then return end
	local hasBody = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if hasBody or not snap.centre then
		if camera.CameraType == Enum.CameraType.Scriptable then
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
	if snap.phase == "live" and not snap.alive then return "คุณตายแล้ว — รอรอบหน้า", Color3.fromRGB(210, 200, 190) end
	return nil, nil
end

Remotes.ArenaState.OnClientEvent:Connect(function(snap)
	if not snap then return end
	snapshot = snap
	hud:Render(snap)
	updateSpectator(snap)
	if snap.phase ~= lastPhase then onPhaseChanged(snap.phase) end
	if shop:IsVisible() then shop:Render(snap) end
	local text, colour = bannerFor(snap)
	hud:SetBanner(text, colour)
end)

--------------------------------------------------------------------------------
-- ตารางจบเกม
--------------------------------------------------------------------------------
Remotes.ArenaMatchEnd.OnClientEvent:Connect(function(result)
	setShopOpen(false)
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
