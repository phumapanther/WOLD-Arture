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

	-- วงอนุภาคลอยขึ้นรอบตัว + จุดประกายรอบเท้า สองตัวให้อ่านออกว่าเป็น "รัศมี" ไม่ใช่ควัน
	local ring = Instance.new("ParticleEmitter")
	ring.Name = "Ring"
	ring.Color = ColorSequence.new(colour)
	ring.LightEmission = 0.8
	ring.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 0) })
	ring.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) })
	ring.Lifetime = NumberRange.new(1.2, 1.8)
	ring.Rate = 28
	ring.Speed = NumberRange.new(1.5, 2.5)
	ring.SpreadAngle = Vector2.new(360, 360)
	ring.Shape = Enum.ParticleEmitterShape.Cylinder
	ring.ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface
	ring.EmissionDirection = Enum.NormalId.Top
	ring.Parent = core

	local glow = Instance.new("PointLight")
	glow.Color = colour
	glow.Brightness = 0.8
	glow.Range = 9
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
	-- วงอนุภาคทรงกระบอกกว้าง 4 สตัดที่ระดับเอว ปรับขนาด core ให้เป็นวงที่ Cylinder ปล่อยจากผิว
	if model.Name == "AuraRing" then core.Size = Vector3.new(4, 0.2, 4) end
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
