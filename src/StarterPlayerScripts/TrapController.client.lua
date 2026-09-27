-- TrapController: ฝั่งไคลเอนต์ของอาวุธกับดัก (เฟส 3) — ส่งแค่ความตั้งใจ เซิร์ฟเวอร์ (`TrapWeapon.server`) คิดวิถีเอง
--
-- ถือกับดักอยู่: **กดค้างคลิกซ้าย/ปุ่มโจมตี = เล็ง** (เส้นโค้งจุดๆ + วงตก สีตามกระสุน ยิ่งค้างนานยิ่งไกล)
-- **ปล่อย = เขวี้ยง** · **แตะสั้นกว่า `TrapConfig.TapSeconds` = วางหน้าเท้า** · มือถือส่งกด/ปล่อยมาทาง `WOLD_TrapInput`
-- (TouchActionController) · เส้นเล็งใช้สูตรเดียวกับเซิร์ฟ (`TrapConfig.Velocity/Simulate`) จุดตกจึงตรงกัน
--
-- ภาพที่ทุกเครื่องวาดเอง: ไฟกับดักกะพริบ (แท็ก `WOLD_Trap`) · กับดักลอยตามวิถีตอนถูกเขวี้ยง · ระเบิด/คลื่นตอนทำงาน
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")

while workspace:GetAttribute("IsLobby") == nil do task.wait() end
if workspace:GetAttribute("IsLobby") then return end

local TrapConfig = require(ReplicatedStorage.TrapConfig)
local Remotes = require(ReplicatedStorage.Remotes)

local player = Players.LocalPlayer

-- ช่องทางกด/ปล่อยจากปุ่มมือถือ — อยู่ใน ReplicatedStorage (PlayerGui ถูกล้างทุกครั้งที่เกิดใหม่) ตัวนี้เป็นเจ้าของ
local channel = ReplicatedStorage:FindFirstChild("WOLD_TrapInput")
if not channel then
	channel = Instance.new("BindableEvent")
	channel.Name = "WOLD_TrapInput"
	channel.Parent = ReplicatedStorage
end

local latest = nil -- ภาพกระเป๋าล่าสุด (หาว่ากระสุนที่เลือกคือสีอะไร)
Remotes.InventoryUpdate.OnClientEvent:Connect(function(inventory) latest = inventory end)
Remotes.RequestInventoryRefresh:FireServer() -- ภาพแรกอาจมาก่อนสคริปต์นี้เริ่ม

local function heldTrapId()
	local id = player:GetAttribute("WOLD_Weapon")
	return TrapConfig.IsTrap(id) and id or nil
end

local function selectedAmmo()
	local id = heldTrapId()
	if not id then return nil end
	local weapon = latest and latest.equipped and latest.equipped.weapon
	local meta = weapon and weapon.id == id and weapon.meta or nil
	return (TrapConfig.SelectedAmmo(id, meta, latest and latest.slots))
end

--------------------------------------------------------------------------------
-- เส้นเล็ง
--------------------------------------------------------------------------------
local previewFolder = Instance.new("Folder")
previewFolder.Name = "WOLD_TrapAim"
previewFolder.Parent = workspace

local DOTS = 28
local dots = {}
for i = 1, DOTS do
	local dot = Instance.new("Part")
	dot.Name = "Dot"
	dot.Shape = Enum.PartType.Ball
	dot.Size = Vector3.new(0.28, 0.28, 0.28)
	dot.Material = Enum.Material.Neon
	dot.Anchored, dot.CanCollide, dot.CanQuery, dot.CanTouch, dot.CastShadow = true, false, false, false, false
	dot.Transparency = 1
	dot.Parent = previewFolder
	dots[i] = dot
end
local ring = Instance.new("Part")
ring.Name = "Landing"
ring.Shape = Enum.PartType.Cylinder
ring.Size = Vector3.new(0.12, TrapConfig.EffectRadius * 2, TrapConfig.EffectRadius * 2)
ring.Material = Enum.Material.Neon
ring.Anchored, ring.CanCollide, ring.CanQuery, ring.CanTouch, ring.CastShadow = true, false, false, false, false
ring.Transparency = 1
ring.Parent = previewFolder

local function hidePreview()
	for _, dot in ipairs(dots) do dot.Transparency = 1 end
	ring.Transparency = 1
end

local function rayParams()
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local exclude = { previewFolder }
	local traps = workspace:FindFirstChild("WOLD_Traps")
	if traps then exclude[#exclude + 1] = traps end
	if player.Character then exclude[#exclude + 1] = player.Character end
	params.FilterDescendantsInstances = exclude
	params.RespectCanCollide = true
	return params
end

-- จุดออกของกับดัก — สูตรเดียวกับ TrapWeapon.server.throw
local function launchOrigin(root, look)
	local flat = Vector3.new(look.X, 0, look.Z)
	flat = flat.Magnitude > 1e-3 and flat.Unit or Vector3.new(0, 0, -1)
	return root.Position + Vector3.new(0, 1.5, 0) + flat * 1.2
end

local function drawPreview(power)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	local camera = workspace.CurrentCamera
	if not (root and camera) then return hidePreview() end
	local ammo = selectedAmmo()
	local color = ammo and ammo.color or Color3.fromRGB(255, 190, 90)
	local look = camera.CFrame.LookVector
	local result = TrapConfig.Simulate(launchOrigin(root, look), TrapConfig.Velocity(look, power), rayParams())
	local points = result.points
	for i, dot in ipairs(dots) do
		-- กระจายจุดตามความยาวเส้น (ไม่ใช่จุดละเฟรมของการจำลอง) จุดจึงห่างเท่ากันทั้งเส้น
		local index = math.clamp(math.floor((i / DOTS) * #points + 0.5), 1, #points)
		dot.Position = points[index]
		dot.Color = color
		dot.Transparency = 0.15 + 0.5 * (i / DOTS)
	end
	local up = result.normal or Vector3.yAxis
	ring.Color = color
	ring.Transparency = 0.65
	-- ทรงกระบอกของ Roblox วางแกนตาม X → หันแกน X ตามผิวที่ตก
	ring.CFrame = CFrame.lookAt(result.position + up * 0.08, result.position + up * 1.08) * CFrame.Angles(0, math.rad(90), 0)
end

--------------------------------------------------------------------------------
-- กด/ปล่อย
--------------------------------------------------------------------------------
local pressedAt = nil

local function press()
	if not heldTrapId() then return end
	pressedAt = os.clock()
end

local function powerNow()
	local held = os.clock() - pressedAt - TrapConfig.TapSeconds
	return math.clamp(held / TrapConfig.ChargeSeconds, 0, 1)
end

local function release()
	if not pressedAt then return end
	local heldFor = os.clock() - pressedAt
	local power = powerNow()
	pressedAt = nil
	hidePreview()
	if not heldTrapId() then return end
	if heldFor < TrapConfig.TapSeconds then
		Remotes.RequestTrap:FireServer("place")
	else
		local camera = workspace.CurrentCamera
		Remotes.RequestTrap:FireServer("throw", camera and camera.CFrame.LookVector or Vector3.new(0, 0, -1), power)
	end
end

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	if input.UserInputType == Enum.UserInputType.MouseButton1 then press() end
end)
UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then release() end
end)
channel.Event:Connect(function(phase)
	if phase == "down" then press() elseif phase == "up" then release() end
end)

RunService.RenderStepped:Connect(function()
	if not pressedAt then return end
	-- เปลี่ยนอาวุธกลางทาง = เลิกเล็ง
	if not heldTrapId() then
		pressedAt = nil
		return hidePreview()
	end
	if os.clock() - pressedAt < TrapConfig.TapSeconds then return end
	drawPreview(powerNow())
end)

--------------------------------------------------------------------------------
-- ไฟกะพริบบนกับดักที่ติดอยู่ (ทุกคนเห็น) — ถามแท็กใหม่ทุกเฟรม (StreamingEnabled: กับดักโผล่/หายตลอด)
--------------------------------------------------------------------------------
RunService.Heartbeat:Connect(function()
	local on = (os.clock() % 0.8) < 0.4
	for _, model in ipairs(CollectionService:GetTagged("WOLD_Trap")) do
		local lamp = model:FindFirstChild("Lamp", true)
		if lamp and lamp:IsA("BasePart") then
			lamp.Transparency = on and 0 or 0.6
			local light = lamp:FindFirstChild("TrapLight")
			if light then light.Enabled = on end
		end
	end
end)

--------------------------------------------------------------------------------
-- ภาพที่เซิร์ฟเวอร์สั่ง: เขวี้ยง (กับดักลอยตามวิถี) · ทำงาน (คลื่น/ระเบิด)
--------------------------------------------------------------------------------
local function flyingModel(ammo)
	local weapons = ReplicatedStorage:FindFirstChild("WOLD_Weapons")
	local prefab = weapons and weapons:FindFirstChild("Trap")
	local model
	if prefab then
		model = prefab:Clone()
	else
		model = Instance.new("Model")
		local p = Instance.new("Part")
		p.Size = Vector3.new(1, 0.4, 1)
		p.Parent = model
		model.PrimaryPart = p
	end
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Anchored, d.CanCollide, d.CanQuery, d.CanTouch = true, false, false, false
		end
	end
	model:ScaleTo(TrapConfig.Scale)
	local lamp = model:FindFirstChild("Lamp", true)
	if lamp and ammo then lamp.Color = ammo.color end
	model.Parent = previewFolder
	return model
end

local function animateThrow(origin, velocity, duration, ammo)
	local model = flyingModel(ammo)
	local started = os.clock()
	local connection
	connection = RunService.RenderStepped:Connect(function()
		local t = os.clock() - started
		if t >= duration or not model.Parent then
			connection:Disconnect()
			model:Destroy()
			return
		end
		model:PivotTo(CFrame.new(TrapConfig.PositionAt(origin, velocity, t)) * CFrame.Angles(t * 9, t * 5, 0))
	end)
end

local function burst(position, ammo)
	local color = ammo and ammo.color or Color3.fromRGB(255, 190, 90)
	if ammo and ammo.kind == "damage" then
		-- ระเบิดของ Roblox ที่ไม่ทำอะไรใคร (ของที่ไคลเอนต์สร้างไม่มีผลกับฟิสิกส์ของเซิร์ฟอยู่แล้ว) — ได้ภาพ+เสียงระเบิดฟรี
		local explosion = Instance.new("Explosion")
		explosion.Position = position
		explosion.BlastRadius = TrapConfig.EffectRadius
		explosion.BlastPressure = 0
		explosion.DestroyJointRadiusPercent = 0
		explosion.ExplosionType = Enum.ExplosionType.NoCraters
		explosion.Parent = workspace
	end
	local wave = Instance.new("Part")
	wave.Shape = Enum.PartType.Ball
	wave.Size = Vector3.new(1, 1, 1)
	wave.Position = position
	wave.Color = color
	wave.Material = Enum.Material.Neon
	wave.Transparency = 0.3
	wave.Anchored, wave.CanCollide, wave.CanQuery, wave.CanTouch, wave.CastShadow = true, false, false, false, false
	wave.Parent = previewFolder
	local d = TrapConfig.EffectRadius * 2
	TweenService:Create(wave, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Size = Vector3.new(d, d, d), Transparency = 1 }):Play()
	Debris:AddItem(wave, 0.5)
end

Remotes.TrapEvent.OnClientEvent:Connect(function(kind, a, b, c, d, e)
	if kind == "throw" then
		-- a = userId · b = จุดออก · c = ความเร็ว · d = เวลาบิน · e = กระสุน
		if typeof(b) == "Vector3" and typeof(c) == "Vector3" and type(d) == "number" then
			animateThrow(b, c, math.min(d, TrapConfig.MaxFlight), TrapConfig.AmmoById[e])
		end
	elseif kind == "burst" then
		-- a = จุด · b = กระสุน
		if typeof(a) == "Vector3" then burst(a, TrapConfig.AmmoById[b]) end
	end
end)
