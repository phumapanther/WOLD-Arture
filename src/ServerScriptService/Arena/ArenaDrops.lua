-- ArenaDrops: อาวุธที่ตกพื้นในสนาม PVP (ผู้ใช้สั่ง 2026-09-25) — คนตายอาวุธตก ใครก็หยิบได้ก่อนรอบจบ
--
-- ไฟล์นี้แค่วางโมเดล + ปุ่มหยิบ แล้วถามคนที่ผูกไว้ (`Bind`) ว่าหยิบได้ไหม — กติกาของแมตช์ (ใครหยิบได้
-- ช่วงไหน สลับอาวุธยังไง) อยู่ที่ ArenaMatch ซึ่งเป็นเจ้าของกระเป๋า/ของติดตัวของทุกคน
local ItemCatalog = require(game.ReplicatedStorage.ItemCatalog)
local WeaponVisualsAccess = require(game.ServerScriptService.WeaponVisualsAccess)

local ArenaDrops = {}

local FOLDER_NAME = "WOLD_ArenaDrops"
local onPickup = nil -- function(player, drop) -> true ถ้าหยิบสำเร็จ

local function folder()
	local f = workspace:FindFirstChild(FOLDER_NAME)
	if not f then
		f = Instance.new("Folder")
		f.Name = FOLDER_NAME
		f.Parent = workspace
	end
	return f
end

-- พื้นใต้จุดที่ตาย (มองข้ามตัวละคร/บอท/อาวุธที่ตกอยู่ก่อน) · ไม่เจอพื้นก็วางที่จุดนั้นเลย
local function groundBelow(position)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.RespectCanCollide = true
	params.FilterDescendantsInstances = { folder() }
	local hit = workspace:Raycast(position + Vector3.new(0, 3, 0), Vector3.new(0, -40, 0), params)
	return hit and hit.Position or position
end

function ArenaDrops.Bind(fn)
	onPickup = fn
end

-- วางอาวุธ `id` (พร้อม meta/สกิน และกระสุนที่เหลือ) ลงพื้นแถว `position`
function ArenaDrops.Drop(position, id, meta, ammo)
	local model = WeaponVisualsAccess.BuildModel and WeaponVisualsAccess.BuildModel(id, meta)
	if not model then return end
	model.Name = "Drop_" .. id
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			-- ไม่ชน ไม่ขวางกระสุน (สไนยิงทะลุ) — มันคือของบนพื้น ไม่ใช่กำแพง
			d.Anchored, d.CanCollide, d.CanQuery, d.CanTouch = true, false, false, false
		end
	end
	-- นอนราบกับพื้น: ตัวอาวุธยาวไปตามแกน Y ของโมเดล → หมุน 90° รอบ X · หันสุ่มให้กองไม่ดูเป็นแถว
	local ground = groundBelow(position)
	model:PivotTo(CFrame.new(ground + Vector3.new(0, 0.35, 0))
		* CFrame.Angles(0, math.random() * math.pi * 2, 0) * CFrame.Angles(math.rad(90), 0, 0))

	local glow = Instance.new("Highlight")
	glow.FillTransparency = 1
	glow.OutlineColor = Color3.fromRGB(255, 214, 110)
	glow.Parent = model

	local item = ItemCatalog.Get(id)
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "หยิบ"
	prompt.ObjectText = ItemCatalog.DisplayName and ItemCatalog.DisplayName(id, meta) or (item and item.name) or id
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0.3
	prompt.MaxActivationDistance = 8
	prompt.RequiresLineOfSight = false
	prompt.Parent = model.PrimaryPart

	local drop = { id = id, meta = meta, ammo = ammo, position = ground, model = model }
	prompt.Triggered:Connect(function(player)
		-- สองคนกดพร้อมกัน: คนแรกจองไว้ก่อน คนที่สองเห็นว่าจองแล้วก็จบ (ไม่งั้นได้อาวุธซ้ำสองชิ้น)
		if drop.taken or not model.Parent then return end
		drop.taken = true
		if onPickup and onPickup(player, drop) then
			model:Destroy()
		else
			drop.taken = false
		end
	end)
	model.Parent = folder()
end

-- เก็บอาวุธที่ตกทั้งสนาม (รอบจบ)
function ArenaDrops.Clear()
	local f = workspace:FindFirstChild(FOLDER_NAME)
	if f then f:ClearAllChildren() end
end

return ArenaDrops
