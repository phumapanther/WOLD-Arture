-- AimController: the crosshair, and where a ranged weapon is actually pointed.
--
-- Only appears while a projectile weapon is held. A sword needs no crosshair -- it hits what is in front of
-- the character -- and drawing one for it would suggest an aim that does nothing.
--
-- The aim point is worked out here and sent with the attack, because only the client knows where its own
-- camera is looking. The server still decides everything else: whether the shot is legal, what it hits, and
-- what that costs. A lie about the aim point can only ever miss differently -- it cannot fire faster, spend
-- less mana, or hit someone out of range.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local ItemCatalog = require(game.ReplicatedStorage.ItemCatalog)
local CombatConfig = require(game.ReplicatedStorage.CombatConfig)
local Remotes = require(game.ReplicatedStorage.Remotes)

while workspace:GetAttribute("IsLobby") == nil do
	task.wait()
end
if workspace:GetAttribute("IsLobby") then return end

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

-- How far the aim ray reaches before giving up and aiming at empty air.
local AIM_DISTANCE = 500

--------------------------------------------------------------------------------
-- The crosshair
--------------------------------------------------------------------------------

local gui = Instance.new("ScreenGui")
gui.Name = "WOLD_Crosshair"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 5 -- under every panel: this is world furniture, not interface
gui.Enabled = false
gui.Parent = player:WaitForChild("PlayerGui")

-- Drawn from four ticks around a centre dot rather than an uploaded image, for the same reason the touch
-- buttons are: nothing to upload, nothing to go missing.
local function tick(size, position, anchor)
	local f = Instance.new("Frame")
	f.Size = size
	f.Position = position
	f.AnchorPoint = anchor
	f.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	f.BackgroundTransparency = 0.25
	f.BorderSizePixel = 0
	f.Parent = gui
	local s = Instance.new("UIStroke")
	s.Color = Color3.fromRGB(0, 0, 0)
	s.Transparency = 0.55
	s.Thickness = 1
	s.Parent = f
	return f
end

local GAP, LEN, THICK = 8, 7, 2
tick(UDim2.fromOffset(THICK, THICK), UDim2.fromScale(0.5, 0.5), Vector2.new(0.5, 0.5)) -- centre dot
tick(UDim2.fromOffset(THICK, LEN), UDim2.new(0.5, 0, 0.5, -GAP), Vector2.new(0.5, 1)) -- up
tick(UDim2.fromOffset(THICK, LEN), UDim2.new(0.5, 0, 0.5, GAP), Vector2.new(0.5, 0)) -- down
tick(UDim2.fromOffset(LEN, THICK), UDim2.new(0.5, -GAP, 0.5, 0), Vector2.new(1, 0.5)) -- left
tick(UDim2.fromOffset(LEN, THICK), UDim2.new(0.5, GAP, 0.5, 0), Vector2.new(0, 0.5)) -- right

--------------------------------------------------------------------------------
-- The charge bar
--------------------------------------------------------------------------------

-- แถบโหลดของทุกท่าที่ต้องรอก่อนออกแรง (ผู้ใช้สั่ง 2026-09-25 — เดิมมีแค่อาวุธระยะไกล)
-- อยู่ใน ScreenGui ของมันเองที่เปิดตลอด เพราะดาบใหญ่ไม่มีเป้าเล็ง แถบที่ฝากไว้กับเป้าเล็งจึงไม่เคยขึ้น
-- เซิร์ฟเวอร์เป็นคนตัดสินว่าท่าไหนมีแถบ (ส่งวินาทีมาเฉพาะท่าที่รอ >= CombatConfig.ChargeBarMinSeconds)
local BAR_W, BAR_H, BAR_DROP = 70, 5, 34
local BAR_POS = UDim2.new(0.5, 0, 0.5, BAR_DROP)
local BAR_POS_SCOPED = UDim2.new(0.5, 0, 0.95, 0) -- ใต้วงสโคป

local barGui = Instance.new("ScreenGui")
barGui.Name = "WOLD_ChargeBar"
barGui.ResetOnSpawn = false
barGui.IgnoreGuiInset = true
barGui.DisplayOrder = 7 -- เหนือจอสโคป
barGui.Parent = player:WaitForChild("PlayerGui")

local barBack = Instance.new("Frame")
barBack.Name = "ChargeBack"
barBack.AnchorPoint = Vector2.new(0.5, 0)
barBack.Position = BAR_POS
barBack.Size = UDim2.fromOffset(BAR_W, BAR_H)
barBack.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
barBack.BackgroundTransparency = 0.35
barBack.BorderSizePixel = 0
barBack.Visible = false
barBack.Parent = barGui

local barStroke = Instance.new("UIStroke")
barStroke.Color = Color3.fromRGB(0, 0, 0)
barStroke.Transparency = 0.5
barStroke.Thickness = 1
barStroke.Parent = barBack

local barFill = Instance.new("Frame")
barFill.Name = "ChargeFill"
barFill.Size = UDim2.fromScale(0, 1)
barFill.BackgroundColor3 = Color3.fromRGB(255, 226, 170)
barFill.BorderSizePixel = 0
barFill.Parent = barBack

-- Which shot the bar is currently drawing. Bumped on every start, so a second shot fired before the first
-- bar finished takes the bar over rather than both writing to it at once.
local chargeToken = 0

local function showCharge(seconds)
	if not seconds or seconds <= 0 then return end
	chargeToken += 1
	local mine = chargeToken

	barFill.Size = UDim2.fromScale(0, 1)
	barBack.Visible = true

	local started = os.clock()
	local connection
	connection = RunService.RenderStepped:Connect(function()
		-- A newer shot owns the bar now, or the aim has been put away mid-draw.
		if chargeToken ~= mine then
			connection:Disconnect()
			if chargeToken == mine then barBack.Visible = false end
			return
		end
		local progress = (os.clock() - started) / seconds
		if progress >= 1 then
			connection:Disconnect()
			barFill.Size = UDim2.fromScale(1, 1)
			-- Held for a beat at full so the shot is seen to complete rather than the bar just vanishing.
			task.delay(0.12, function()
				if chargeToken == mine then barBack.Visible = false end
			end)
			return
		end
		barFill.Size = UDim2.fromScale(progress, 1)
	end)
end


--------------------------------------------------------------------------------
-- Where the weapon is pointed
--------------------------------------------------------------------------------

-- The world point under the middle of the screen. A ray from the camera through the screen centre, out to
-- whatever it hits first -- or a point far away along it, so aiming at open sky still gives a direction.
--
-- The character is excluded, or the ray would stop on the shooter's own back in third person.
local function aimPoint()
	local viewport = camera.ViewportSize
	local ray = camera:ViewportPointToRay(viewport.X / 2, viewport.Y / 2)

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local filter = {}
	if player.Character then table.insert(filter, player.Character) end
	params.FilterDescendantsInstances = filter
	params.IgnoreWater = true

	local result = workspace:Raycast(ray.Origin, ray.Direction * AIM_DISTANCE, params)
	return result and result.Position or (ray.Origin + ray.Direction * AIM_DISTANCE)
end

-- Published so the combat controller can send it with an attack without duplicating any of this.
local AimAccess = require(game.ReplicatedStorage.UI.AimAccess)
AimAccess.Point = aimPoint

--------------------------------------------------------------------------------
-- Showing it only for the weapons that use it
--------------------------------------------------------------------------------

local function usesAim(itemId)
	local item = itemId and ItemCatalog.Get(itemId)
	if not item or item.kind ~= "weapon" then return false end
	local weapon = CombatConfig.Weapons[itemId]
	if not weapon then return false end
	-- A weapon aims if any of its attacks throws something.
	for _, attack in ipairs(weapon.attacks or {}) do
		if attack.projectile then return true end
	end
	return false
end

-- ประกาศไว้ก่อน: บล็อกสโคปท้ายไฟล์เป็นคนกำหนดค่า แต่ refresh/DownedStateChanged ต้องเรียกถึง
local currentWeaponId = nil
local savedFov = nil
local closeScope

local function refresh(equipped)
	local weapon = equipped and equipped.weapon
	local id = weapon and weapon.id
	gui.Enabled = usesAim(id) and savedFov == nil -- ระหว่างส่องสโคป เป้าเล็งปกติหลบให้
	-- InventoryUpdate มาทุกครั้งที่อาวุธสึก (ทุกคลิก) — ซ่อนแถบเฉพาะตอน "เปลี่ยนอาวุธ" จริง
	-- ไม่งั้นแถบดาบใหญ่หายทันทีที่เริ่มเหวี่ยง
	if equipped ~= nil and id ~= currentWeaponId then
		chargeToken += 1
		barBack.Visible = false
		if savedFov and closeScope then closeScope() end
	end
	if equipped ~= nil then currentWeaponId = id end
end

--------------------------------------------------------------------------------
-- กระสุนที่เหลือ (ผู้ใช้สั่ง 2026-09-25): รูปกระสุนเรียงกลางล่างจอ ตอนถืออาวุธที่กินกระสุน (ปืนเล็ก)
--------------------------------------------------------------------------------
-- นับจากกระเป๋าจริงทุกครั้งที่กระเป๋าเปลี่ยน (ยิงหนึ่งนัด = หักหนึ่งชิ้น = InventoryUpdate มาเอง)
-- วาดรูปทีละนัดได้ถึง MAX_ICONS · เกินนั้น (เกมหลักพกได้เป็นร้อย) เหลือเลขบอกจำนวน
local MAX_ICONS = 12
local ammoGui = Instance.new("ScreenGui")
ammoGui.Name = "WOLD_Ammo"
ammoGui.ResetOnSpawn = false
ammoGui.IgnoreGuiInset = true
ammoGui.DisplayOrder = 5
ammoGui.Enabled = false
ammoGui.Parent = player:WaitForChild("PlayerGui")

-- สนาม PVP: มุมซ้ายล่าง ต่อท้ายกล่องซิลเวอร์ของ ArenaHudGui (x 16..206 · ก้น 1,-150) — กลางล่างจอที่ -172px
-- บนมือถือแนวนอน (สูง ~390px) คือกลางจอพอดี ทับเป้าเล็งทั้งแถว (ผู้ใช้แจ้ง 2026-09-25) · เกมหลักอยู่ที่เดิม
local ARENA = workspace:GetAttribute("ArenaMode") == true
local ammoRow = Instance.new("Frame")
ammoRow.AnchorPoint = ARENA and Vector2.new(0, 1) or Vector2.new(0.5, 1)
ammoRow.Position = ARENA and UDim2.new(0, 216, 1, -150)
	or UDim2.new(0.5, 0, 1, -172) -- เหนือแถวบัพ/หลอด EXP ของ HUD (สูงสุด ~1,-114)
ammoRow.AutomaticSize = Enum.AutomaticSize.XY
ammoRow.BackgroundTransparency = 1
ammoRow.Parent = ammoGui
local ammoLayout = Instance.new("UIListLayout")
ammoLayout.FillDirection = Enum.FillDirection.Horizontal
ammoLayout.HorizontalAlignment = ARENA and Enum.HorizontalAlignment.Left or Enum.HorizontalAlignment.Center
ammoLayout.VerticalAlignment = Enum.VerticalAlignment.Bottom
ammoLayout.SortOrder = Enum.SortOrder.LayoutOrder
ammoLayout.Padding = UDim.new(0, 4)
ammoLayout.Parent = ammoRow

-- กระสุนหนึ่งนัด: ปลอกทองเหลือง + หัวทองแดงมน (Frame ล้วน ไม่มีรูปให้อัปโหลด)
local ammoIcons = {}
for i = 1, MAX_ICONS do
	local case = Instance.new("Frame")
	case.LayoutOrder = i
	case.Size = UDim2.fromOffset(9, 26)
	case.BackgroundColor3 = Color3.fromRGB(214, 172, 82)
	case.BorderSizePixel = 0
	case.Parent = ammoRow
	local caseRound = Instance.new("UICorner")
	caseRound.CornerRadius = UDim.new(0, 2)
	caseRound.Parent = case
	local caseStroke = Instance.new("UIStroke")
	caseStroke.Color = Color3.fromRGB(40, 28, 12)
	caseStroke.Thickness = 1
	caseStroke.Parent = case
	local head = Instance.new("Frame")
	head.AnchorPoint = Vector2.new(0.5, 1)
	head.Position = UDim2.fromScale(0.5, 0)
	head.Size = UDim2.fromOffset(9, 9)
	head.BackgroundColor3 = Color3.fromRGB(190, 112, 62)
	head.BorderSizePixel = 0
	head.Parent = case
	local headRound = Instance.new("UICorner")
	headRound.CornerRadius = UDim.new(1, 0)
	headRound.Parent = head
	ammoIcons[i] = case
end

local ammoText = Instance.new("TextLabel")
ammoText.LayoutOrder = MAX_ICONS + 1
ammoText.AutomaticSize = Enum.AutomaticSize.X
ammoText.Size = UDim2.fromOffset(0, 26)
ammoText.BackgroundTransparency = 1
ammoText.Font = Enum.Font.GothamBold
ammoText.TextSize = 20
ammoText.TextColor3 = Color3.fromRGB(245, 240, 225)
ammoText.TextStrokeTransparency = 0.4
ammoText.Parent = ammoRow

local function drawAmmo(inventory)
	local weapon = inventory and inventory.equipped and inventory.equipped.weapon
	local spec = weapon and CombatConfig.Weapons[weapon.id]
	local ammoId = spec and spec.ammo
	ammoGui.Enabled = ammoId ~= nil
	if not ammoId then return end
	local count = 0
	for _, slot in pairs(inventory.slots or {}) do
		if slot and slot.id == ammoId then count += slot.count or 1 end
	end
	for i, icon in ipairs(ammoIcons) do icon.Visible = i <= count end
	ammoText.Text = count == 0 and "กระสุนหมด" or (" " .. count)
	ammoText.TextColor3 = count == 0 and Color3.fromRGB(235, 110, 100) or Color3.fromRGB(245, 240, 225)
end

Remotes.InventoryUpdate.OnClientEvent:Connect(function(inventory)
	refresh(inventory and inventory.equipped)
	drawAmmo(inventory)
end)

-- The bag may not have been sent yet when this starts.
Remotes.RequestInventoryRefresh:FireServer()

-- Hidden while dead or downed: there is nothing to aim.
Remotes.DownedStateChanged.OnClientEvent:Connect(function(isDowned)
	if isDowned then
		gui.Enabled = false
		chargeToken += 1
		barBack.Visible = false
		if savedFov and closeScope then closeScope() end
	end
end)

--------------------------------------------------------------------------------
-- สโคปสไน (ผู้ใช้สั่ง 2026-09-25 รอบสอง)
--------------------------------------------------------------------------------
-- คลิกแรก = เซิร์ฟเวอร์ยกการ์ด (guard_start) → เข้ามุมมองบุคคลที่หนึ่งก่อน แล้วค่อยขึ้นสโคปซูมไกล
-- คลิกสอง = ยิง (เซิร์ฟเวอร์ปลดการ์ดหลังยิง → guard_end → ออกจากสโคป) · คลิกขวา = เลิกส่อง
-- `savedFov ~= nil` แปลว่ากำลังส่องอยู่ (refresh/DownedStateChanged ข้างบนถามจากค่านี้)
local ScopeGui = require(game.ReplicatedStorage.UI.ScopeGui)
local scope = ScopeGui.new()
scope.gui.Parent = player:WaitForChild("PlayerGui")

-- **มือถือ**: การหมุนกล้องด้วยนิ้วไม่สนใจ MouseDeltaSensitivity (ลดความไวได้แค่เมาส์) ที่ FOV 12 นิ้วเลื่อนนิดเดียว
-- ภาพกระชากไปไกล ~6 เท่า · มือถือจึงซูมน้อยกว่า (30) = ความไวเหลือราว 2 เท่า ยังเล็งได้ (QA 2026-09-26)
local TOUCH_ONLY = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
local SCOPED_FOV = TOUCH_ONLY and 30 or 12 -- ซูมไกล (ปกติ 70)
local FIRST_PERSON_SECONDS = 0.2 -- อยู่ในมุมมองบุคคลที่หนึ่งเปล่าๆ แค่นี้ก่อนขึ้นสโคป
local ZOOM_SECONDS = 0.3
local SCOPED_SENSITIVITY = 0.35 -- ซูมไกลแล้วเมาส์ต้องช้าลง ไม่งั้นเล็งไม่ได้
local scopeToken = 0
local savedCameraMode, savedZoom, savedSensitivity, zoomTween = nil, nil, nil, nil

-- ปุ่ม "×" ออกจากสโคปบนมือถือ — ของเดิมออกได้แค่คลิกขวา มือถือต้องยิง (เสียมานา) หรือรอ 20 วิ (QA 2026-09-26)
-- อยู่ขวากลางจอ เหนือกลุ่มปุ่มโจมตี ไม่ทับปุ่มไหน · DisplayOrder เหนือสโคป (6) และเหนือปุ่มสนาม (21)
local unscopeGui = Instance.new("ScreenGui")
unscopeGui.Name = "WOLD_Unscope"
unscopeGui.ResetOnSpawn = false
unscopeGui.IgnoreGuiInset = true
unscopeGui.DisplayOrder = 23
unscopeGui.Enabled = false
unscopeGui.Parent = player:WaitForChild("PlayerGui")
local unscopeButton = Instance.new("TextButton")
unscopeButton.AnchorPoint = Vector2.new(1, 0.5)
unscopeButton.Position = UDim2.new(1, -24, 0.32, 0)
unscopeButton.Size = UDim2.fromOffset(56, 56)
unscopeButton.BackgroundColor3 = Color3.fromRGB(20, 20, 24)
unscopeButton.BackgroundTransparency = 0.25
unscopeButton.Font = Enum.Font.GothamBold
unscopeButton.TextSize = 30
unscopeButton.TextColor3 = Color3.fromRGB(240, 240, 245)
unscopeButton.Text = "×" -- × (เครื่องหมายคูณ ฟอนต์วาดได้ ต่างจาก ✕)
unscopeButton.Parent = unscopeGui
local unscopeCorner = Instance.new("UICorner")
unscopeCorner.CornerRadius = UDim.new(1, 0)
unscopeCorner.Parent = unscopeButton
unscopeButton.Activated:Connect(function()
	if savedFov then Remotes.RequestUnscope:FireServer() end
end)

closeScope = function()
	scopeToken += 1
	scope:Hide()
	unscopeGui.Enabled = false
	barBack.Position = BAR_POS
	if zoomTween then zoomTween:Cancel(); zoomTween = nil end
	if savedFov then
		camera.FieldOfView = savedFov
		savedFov = nil
	end
	if savedSensitivity then
		UserInputService.MouseDeltaSensitivity = savedSensitivity
		savedSensitivity = nil
	end
	if savedCameraMode then
		player.CameraMode = savedCameraMode
		-- ออกจาก LockFirstPerson แล้วกล้องค้างชิดหัว — ดันระยะกลับไปเท่าก่อนส่อง (ในสนามล็อกบุคคลที่หนึ่ง
		-- อยู่แล้ว savedCameraMode เป็น LockFirstPerson จึงไม่ต้องดัน)
		if savedCameraMode ~= Enum.CameraMode.LockFirstPerson and savedZoom then
			local minZoom = player.CameraMinZoomDistance
			player.CameraMinZoomDistance = math.clamp(savedZoom, minZoom, player.CameraMaxZoomDistance)
			task.defer(function() player.CameraMinZoomDistance = minZoom end)
		end
		savedCameraMode, savedZoom = nil, nil
	end
	-- เป้าเล็งกลับมาตามอาวุธที่ถืออยู่
	gui.Enabled = currentWeaponId ~= nil and usesAim(currentWeaponId)
end

local function openScope()
	scopeToken += 1
	local mine = scopeToken
	if not savedFov then
		savedFov = camera.FieldOfView
		savedCameraMode = player.CameraMode
		savedZoom = (camera.CFrame.Position - camera.Focus.Position).Magnitude
	end
	gui.Enabled = false -- เป้าเล็งปกติหลบให้กากบาทของสโคป
	player.CameraMode = Enum.CameraMode.LockFirstPerson
	task.delay(FIRST_PERSON_SECONDS, function()
		if scopeToken ~= mine then return end
		scope:Show()
		unscopeGui.Enabled = TOUCH_ONLY
		barBack.Position = BAR_POS_SCOPED
		savedSensitivity = savedSensitivity or UserInputService.MouseDeltaSensitivity
		UserInputService.MouseDeltaSensitivity = savedSensitivity * SCOPED_SENSITIVITY
		zoomTween = TweenService:Create(camera, TweenInfo.new(ZOOM_SECONDS, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ FieldOfView = SCOPED_FOV })
		zoomTween:Play()
	end)
end

-- ตายระหว่างส่อง: ร่างใหม่ต้องไม่ติดกล้องซูมค้าง
player.CharacterAdded:Connect(function()
	if savedFov then closeScope() end
end)

-- แถบโหลด (ทุกท่าที่เซิร์ฟเวอร์ส่งวินาทีมา) + สโคปตามการ์ดของอาวุธที่มี `scope`
Remotes.CombatStateChanged.OnClientEvent:Connect(function(who, event, _chainIndex, windup)
	if who ~= player then return end
	if event == "attack" then
		showCharge(windup)
	elseif event == "guard_start" then
		local spec = currentWeaponId and CombatConfig.Weapons[currentWeaponId]
		if spec and spec.scope then openScope() end
	elseif event == "guard_end" then
		if savedFov then closeScope() end
	end
end)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	if input.UserInputType == Enum.UserInputType.MouseButton2 and savedFov then
		Remotes.RequestUnscope:FireServer()
	end
end)
