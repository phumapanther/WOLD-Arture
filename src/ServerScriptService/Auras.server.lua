-- Auras.server.lua: เอฟเฟกต์ออร่าลอยรอบตัวละคร (ของจากกาชา)
--
-- ออร่าเป็นไอเทมในกระเป๋า กด "ใช้" = เปิด/ปิด (ไม่ถูกใช้หมด) ออร่าที่เปิดอยู่จำไว้ในโปรไฟล์ (Aura) จึงติด
-- ข้ามการตาย/ออกเกม ถ้าไอเทมหายจากกระเป๋า (ให้เพื่อน/ทิ้ง) ออร่าดับเองในลูปข้างล่าง
--
-- รูปร่างเอฟเฟกต์: มีโมเดลชื่อเดียวกับไอเทมใน `ReplicatedStorage.WOLD_Effects` ก็เอาโมเดลนั้น (ผู้ใช้วางเอง
-- ในอนาคต) ไม่มีก็สร้างวงอนุภาคสี `colour` จากแคตตาล็อกให้ — ทุกออร่าจึงมีหน้าตาตั้งแต่วันแรกโดยไม่ต้องรอโมเดล
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ServerConfig = require(game.ServerScriptService.ServerConfig)
if ServerConfig.IsLobby then return end

local ItemCatalog = require(game.ReplicatedStorage.ItemCatalog)
local Remotes = require(game.ReplicatedStorage.Remotes)
local ProfileAccess = require(game.ServerScriptService.ProfileAccess)
local AuraAccess = require(game.ServerScriptService.AuraAccess)
local Inventory = require(game.ServerScriptService.Inventory)

local FOLDER_NAME = "WOLD_Aura"

local function hasAuraItem(player, id)
	local state = Inventory.Get(player)
	if not state then return false end
	for _, slot in pairs(state.slots) do
		if slot.id == id then return true end
	end
	return false
end

--------------------------------------------------------------------------------
-- วาด
--------------------------------------------------------------------------------

local function strip(character)
	local old = character and character:FindFirstChild(FOLDER_NAME)
	if old then old:Destroy() end
end

local function buildProcedural(colour)
	local model = Instance.new("Model")
	model.Name = "AuraRing"
	local core = Instance.new("Part")
	core.Name = "Core"
	core.Size = Vector3.new(0.2, 0.2, 0.2)
	core.Transparency = 1
	core.CanCollide = false
	core.CanQuery = false
	core.Massless = true
	core.Parent = model
	model.PrimaryPart = core

	-- **ฟุ้ง สว่าง และอ่านออกว่าเป็นรัศมี** (ผู้ใช้สั่งแก้ 2026-09-18) ทำด้วยอนุภาคสามชั้นทับกัน ไม่ใช่ชั้นเดียว
	-- ที่เร่ง Rate ขึ้นเฉยๆ — ชั้นเดียวยิ่งถี่ยิ่งกลายเป็นเสาควันทึบ สามชั้นคนละหน้าที่จึงยังโปร่งอยู่:
	--
	--   Haze  หมอกนุ่มเม็ดใหญ่ ลอยช้า โปร่งมาก = ตัว "ฟุ้ง"
	--   Ring  ลำแสงเม็ดเล็กพุ่งขึ้นจากวงที่เอว   = ตัว "ชัด" ที่บอกว่ามันเป็นวง
	--   Motes ประกายกะพริบลอยขึ้นช้าๆ            = ตัว "สว่าง" ที่ตาจับได้ก่อนเพื่อน
	--
	-- ทุกชั้นใช้ `LightEmission = 1` และสีเดียวกัน กลางคืนจึงเรืองแสงจริง ไม่ใช่แค่สีจางบนพื้นมืด
	local function emitter(name, parent)
		local p = Instance.new("ParticleEmitter")
		p.Name = name
		p.Color = ColorSequence.new(colour)
		p.LightEmission = 1
		p.LightInfluence = 0 -- ไม่ให้แสงในฉากมากดสีให้หม่นตอนกลางคืน
		p.Shape = Enum.ParticleEmitterShape.Cylinder
		p.ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface
		p.EmissionDirection = Enum.NormalId.Top
		p.SpreadAngle = Vector2.new(18, 18)
		p.Parent = parent
		return p
	end

	local haze = emitter("Haze", core)
	haze.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1.1),
		NumberSequenceKeypoint.new(0.4, 2.2),
		NumberSequenceKeypoint.new(1, 2.8),
	})
	haze.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.25, 0.72), -- โปร่งมาก ความฟุ้งมาจากจำนวนเม็ดที่ซ้อนกัน ไม่ใช่ความทึบของเม็ดเดียว
		NumberSequenceKeypoint.new(1, 1),
	})
	haze.Lifetime = NumberRange.new(2.2, 3.2)
	haze.Rate = 26
	haze.Speed = NumberRange.new(0.8, 1.6)
	haze.RotSpeed = NumberRange.new(-24, 24)
	haze.SpreadAngle = Vector2.new(40, 40)

	local ring = emitter("Ring", core)
	ring.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.55),
		NumberSequenceKeypoint.new(0.7, 0.32),
		NumberSequenceKeypoint.new(1, 0),
	})
	ring.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.08),
		NumberSequenceKeypoint.new(0.8, 0.4),
		NumberSequenceKeypoint.new(1, 1),
	})
	ring.Lifetime = NumberRange.new(1.3, 2.0)
	ring.Rate = 70
	ring.Speed = NumberRange.new(2.6, 4.2)

	local motes = emitter("Motes", core)
	motes.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.22),
		NumberSequenceKeypoint.new(1, 0.05),
	})
	motes.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(1, 1),
	})
	motes.Lifetime = NumberRange.new(2.0, 3.4)
	motes.Rate = 22
	motes.Speed = NumberRange.new(0.6, 1.8)
	motes.SpreadAngle = Vector2.new(60, 60)
	motes.RotSpeed = NumberRange.new(-90, 90)

	-- ไฟจริงด้วย ไม่ใช่แค่อนุภาคเรืองแสง ยืนในที่ร่มแล้วต้องเห็นพื้นรอบตัวติดสีออร่า
	local glow = Instance.new("PointLight")
	glow.Color = colour
	glow.Brightness = 3.2 -- เดิม 0.8 มองแทบไม่ออกกลางวัน
	glow.Range = 16
	glow.Shadows = false
	glow.Parent = core
	return model
end

local function draw(player, auraId)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then return end
	strip(character)
	local item = ItemCatalog.Get(auraId)
	if not item or item.kind ~= "aura" then return end

	local folder = Instance.new("Folder")
	folder.Name = FOLDER_NAME
	folder:SetAttribute("Aura", auraId)

	local effects = ReplicatedStorage:FindFirstChild("WOLD_Effects")
	local prefab = effects and effects:FindFirstChild(item.model or auraId)
	local model = prefab and prefab:Clone() or buildProcedural(item.colour or Color3.new(1, 1, 1))
	local core = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true)
	if not core then model:Destroy() folder:Destroy() return end
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Anchored = false
			d.CanCollide = false
			d.Massless = true
		end
	end
	-- วงอนุภาคทรงกระบอกที่ระดับเอว ปรับขนาด core ให้เป็นวงที่ Cylinder ปล่อยจากผิว (กว้างขึ้นเป็น 4.6 ให้หมอกไม่ทับหน้า)
	if model.Name == "AuraRing" then core.Size = Vector3.new(4.6, 0.2, 4.6) end
	model:PivotTo(root.CFrame * CFrame.new(0, -1.5, 0))
	model.Parent = folder
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = root
	weld.Part1 = core
	weld.Parent = core
	folder.Parent = character
end

--------------------------------------------------------------------------------
-- เปิด/ปิด
--------------------------------------------------------------------------------

AuraAccess.Toggle = function(player, auraId)
	local data = ProfileAccess.Get(player)
	if not data then return end
	if data.Aura == auraId then
		data.Aura = nil
		strip(player.Character)
		Remotes.SocialNotify:FireClient(player, "info", "ปิดออร่าแล้ว")
	else
		data.Aura = auraId
		draw(player, auraId)
		local item = ItemCatalog.Get(auraId)
		Remotes.SocialNotify:FireClient(player, "info", ("เปิด%s"):format(item and item.name or "ออร่า"))
	end
end

-- ลูปถามใหม่ (กฎเหล็ก StreamingEnabled): ตัวละครใหม่ไม่มีโฟลเดอร์ → วาดใหม่ · ไอเทมหายจากกระเป๋า → ดับ
task.spawn(function()
	while true do
		task.wait(1)
		for _, player in ipairs(Players:GetPlayers()) do
			local data = ProfileAccess.Get(player)
			local character = player.Character
			if data and character and character:FindFirstChild("HumanoidRootPart") then
				local wanted = data.Aura
				if wanted and not hasAuraItem(player, wanted) then
					data.Aura = nil
					wanted = nil
				end
				local folder = character:FindFirstChild(FOLDER_NAME)
				local shown = folder and folder:GetAttribute("Aura") or nil
				if wanted ~= shown then
					if wanted then draw(player, wanted) else strip(character) end
				end
			end
		end
	end
end)
