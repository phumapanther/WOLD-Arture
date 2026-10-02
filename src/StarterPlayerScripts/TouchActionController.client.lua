-- TouchActionController: shows the touch action buttons (attack, and the roll/slide button) on touch devices
-- and wires the attack button to the same RequestAttack path the mouse uses. Presentation + intent only, like
-- every other controller here — the server decides what an attack actually does.
--
-- The roll/slide button routes through ActionController's BindableEvent, so touch and keyboard share one
-- code path; the server decides whether the press becomes a roll or a slide.
local FORCE_SHOW_IN_STUDIO_FOR_TESTING = false -- ponytail: flip to preview the buttons on a desktop Play session

while workspace:GetAttribute("IsLobby") == nil do
	task.wait()
end
if workspace:GetAttribute("IsLobby") then return end -- lobby has no gameplay controls

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TouchActionGui = require(game.ReplicatedStorage.UI.TouchActionGui)
local Remotes = require(game.ReplicatedStorage.Remotes)
local AimAccess = require(game.ReplicatedStorage.UI.AimAccess)
local CombatConfig = require(game.ReplicatedStorage.CombatConfig)

-- Phones and tablets ONLY. TouchEnabled alone is not enough: a touchscreen laptop, a 2-in-1, and Studio's
-- device emulator all report it true while still having a keyboard and mouse, and those players use Ctrl and
-- left-click. A real phone or tablet has touch and NO keyboard, so require that combination.
local function isTouchOnlyDevice()
	return UserInputService.TouchEnabled
		and not UserInputService.KeyboardEnabled
		and not UserInputService.MouseEnabled
end

if not isTouchOnlyDevice() and not FORCE_SHOW_IN_STUDIO_FOR_TESTING then return end

local player = Players.LocalPlayer
-- ล็อกแนวนอนในเกมหลัก/เกาะ/สนาม เหมือนที่ล็อบบี้ทำ (ChannelSelectController) — HUD ทุกชิ้นวางไว้สำหรับจอกว้าง
-- แนวตั้งทำให้ปุ่มขวาล่างทับจอยและหลอดสถานะ · Sensor = พลิกซ้าย/ขวาได้ (QA 2026-09-26)
player:WaitForChild("PlayerGui").ScreenOrientation = Enum.ScreenOrientation.LandscapeSensor
local gui = TouchActionGui.new()
gui.gui.Parent = player:WaitForChild("PlayerGui")

-- กับดัก (เฟส 3): ปุ่มโจมตีกดค้าง = เล็ง ปล่อย = เขวี้ยง แตะ = วาง — ส่งต่อให้ TrapController ทางช่องทาง
-- `WOLD_TrapInput` (ReplicatedStorage · TrapController เป็นเจ้าของ) ไม่ส่งคำขอตี
local function holdingTrap()
	local held = CombatConfig.Weapons[player:GetAttribute("WOLD_Weapon") or ""]
	return held ~= nil and held.trap == true
end

gui:OnAttack(function()
	if holdingTrap() then return end
	-- The same aim point the mouse sends: on touch the camera IS the aim, so a phone player shoots where
	-- they are looking rather than where their character happens to be facing.
	local aim = AimAccess.Fire or AimAccess.Point
	Remotes.RequestAttack:FireServer(aim and aim() or nil)
end)

gui:OnAttackHold(function(phase)
	if not holdingTrap() then return end
	local channel = game.ReplicatedStorage:FindFirstChild("WOLD_TrapInput")
	if channel then channel:Fire(phase) end
end)

-- The roll/slide button drives the same path as the Ctrl key, through ActionController's BindableEvent, so
-- the two input routes cannot drift apart. It resolves to a slide while sprinting and a roll otherwise.
gui:OnRoll(function()
	-- ช่องทางอยู่ใน ReplicatedStorage ไม่ใช่ PlayerGui (PlayerGui ถูกล้างทุกครั้งที่ตัวละครเกิด) QA 2026-09-26
	local bindable = game.ReplicatedStorage:FindFirstChild("WOLD_RequestAction")
	if bindable then bindable:Fire() end
end)

-- ปุ่มวิ่ง 🏃 กดค้าง (2026-10-02) → แอตทริบิวต์ท้องถิ่นบนตัวเอง MovementController อ่านทุกเฟรมแล้วส่งเจตนาวิ่ง (ทางเดียวกับ Shift)
-- แอตทริบิวต์ที่ไคลเอนต์ตั้งบนตัวเองไม่ส่งถึงเซิร์ฟ — เซิร์ฟยังตัดสินสตามินา/ความเร็วเองเหมือนเดิม
gui:OnSprintHold(function(held)
	player:SetAttribute("WOLD_SprintButton", held)
end)
-- ตายกลางการกด: InputEnded ยังมา แต่กันไว้ไม่ให้วิ่งค้างข้ามร่าง
player.CharacterAdded:Connect(function() player:SetAttribute("WOLD_SprintButton", false) end)

-- The weapon skill is bound to Q on desktop, which touch cannot press either. Fires the same remote the
-- keyboard path does, so the server sees one kind of request and the cooldown, the cost and the refusal
-- messages are all whatever they already were.
gui:OnSkill(function()
	Remotes.RequestSkill:FireServer()
end)

-- ปุ่มสกิลขึ้นเฉพาะตอนของในมือมีสกิล อ่านจากภาพกระเป๋าที่เซิร์ฟเวอร์ส่งมาทุกครั้งที่ของเปลี่ยน
-- เริ่มแบบโชว์ไว้: ภาพกระเป๋าชุดแรกอาจมาก่อนสคริปต์นี้ต่อสาย ถ้าเริ่มแบบซ่อน ปุ่มจะหายจนกว่ากระเป๋าจะเปลี่ยน
local ItemCatalog = require(game.ReplicatedStorage.ItemCatalog)
Remotes.InventoryUpdate.OnClientEvent:Connect(function(inventory)
	local held = type(inventory) == "table" and inventory.equipped and inventory.equipped.weapon
	local item = held and ItemCatalog.Get(held.id)
	gui:SetSkillAvailable(item and item.skill ~= nil)
end)

-- Dropping a carried player is bound to F on desktop, which touch cannot press. This button drives the same
-- remote. Carry state comes straight from the server event, so it matches RescueController without either
-- script having to reach into the other.
gui:OnDrop(function()
	Remotes.RequestDrop:FireServer()
end)

Remotes.CarryStateChanged.OnClientEvent:Connect(function(actor, event, target)
	-- คนที่ยอมให้อุ้ม (ยังยืนได้) ก็ได้ปุ่มวางไว้ขอลงเอง (QA 2026-09-26) · คนล้มถูกอุ้มไม่ได้ปุ่ม เซิร์ฟเวอร์ไม่รับอยู่ดี
	if actor ~= player and target ~= player then return end
	if event == "carry_start" and actor ~= player and player:GetAttribute("WOLD_Downed") then return end
	if event == "carry_start" then
		gui:SetCarrying(true)
	elseif event == "carry_end" then
		gui:SetCarrying(false)
	end
end)

-- The bag button drives InventoryController's BindableEvent, so touch and the I key share one path.
gui:OnBag(function()
	local toggle = game.ReplicatedStorage:FindFirstChild("WOLD_ToggleInventory")
	if toggle then toggle:Fire() end
end)

-- Same again for the speaking stone: touch and the P key share SocialController's BindableEvent.
gui:OnSocial(function()
	local toggle = game.ReplicatedStorage:FindFirstChild("WOLD_ToggleSocial")
	if toggle then toggle:Fire() end
end)

-- สนาม PVP (ผู้ใช้สั่ง 2026-09-25): กระเป๋ากับหินเวทใช้ไม่ได้ในสนาม → ร้าน (B) · สถิติ (Tab) · แผนที่ (M) · ยา (F)
-- ArenaController เป็นเจ้าของทุกหน้าต่างพวกนั้นและเป็นคนสร้างช่องทาง `WOLD_ArenaAction` — หยิบตอนกด ไม่ผูกล่วงหน้า
if workspace:GetAttribute("ArenaMode") == true then
	gui:SetArenaMode(function(action)
		local channel = game.ReplicatedStorage:FindFirstChild("WOLD_ArenaAction")
		if channel then channel:Fire(action) else warn("[Touch] ไม่เจอ WOLD_ArenaAction (ArenaController)") end
	end)
	-- ปุ่มการ์ดซ่อนตอนถือสไน (สไนใช้การ์ดเป็นสโคป) · อ่านอาวุธในมือจากแอตทริบิวต์ WOLD_Weapon (Inventory.Send ตั้ง)
	task.spawn(function()
		local CombatConfig = require(game.ReplicatedStorage.CombatConfig)
		local me = game:GetService("Players").LocalPlayer
		while true do
			local id = me:GetAttribute("WOLD_Weapon")
			local spec = type(id) == "string" and CombatConfig.Weapons[id]
			gui:SetBlockVisible(not (spec and spec.scope))
			task.wait(0.3)
		end
	end)
end

gui:Show()
gui:AnchorJumpButton()

-- A tablet can gain a keyboard mid-session (a docked iPad, a Surface folded around), which turns it into a
-- device that should be using Ctrl and left-click instead. Follow that rather than deciding once at startup.
local function refreshVisibility()
	if isTouchOnlyDevice() then
		gui:Show()
		gui:AnchorJumpButton()
	else
		gui:Hide()
	end
end
UserInputService:GetPropertyChangedSignal("KeyboardEnabled"):Connect(refreshVisibility)
UserInputService:GetPropertyChangedSignal("MouseEnabled"):Connect(refreshVisibility)
UserInputService:GetPropertyChangedSignal("TouchEnabled"):Connect(refreshVisibility)

-- Roblox rebuilds its touch controls with the character, so the jump button has to be re-positioned each time.
player.CharacterAdded:Connect(function()
	gui:AnchorJumpButton()
end)

-- Swap ROLL -> SLIDE while sprinting: the server's own flag (PlayerMovement), the same one it slides by.
local sprinting = false
local driving = false
RunService.Heartbeat:Connect(function()
	-- ตอนขับ ปุ่มขับของ VehicleController (บูสต์/หวูด/ขึ้น-ลง) ขึ้นแทนที่กลุ่มนี้ ตำแหน่งเดียวกัน (QA 2026-09-26)
	-- ⚠️ เขียนเฉพาะตอนสถานะขับเปลี่ยน — เขียนทุกเฟรมจะทับการซ่อนกลุ่มนี้ของร้านสนาม (ArenaController.setShopOpen)
	local nowDriving = player:GetAttribute("WOLD_Driving") == true
	if nowDriving ~= driving then
		driving = nowDriving
		gui.cluster.Visible = not driving
	end
	local now = player:GetAttribute("WOLD_Sprinting") == true
	if now ~= sprinting then
		sprinting = now
		gui:SetSprinting(sprinting)
	end
end)
