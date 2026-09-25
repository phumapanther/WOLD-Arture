-- ArenaDrops: อาวุธที่ตกพื้นในสนาม PVP (ผู้ใช้สั่ง 2026-09-25) — คนตายอาวุธตก ใครก็หยิบได้ก่อนรอบจบ
--
-- ไฟล์นี้แค่วางโมเดล + ปุ่มหยิบ แล้วถามคนที่ผูกไว้ (`Bind`) ว่าหยิบได้ไหม — กติกาของแมตช์ (ใครหยิบได้
-- ช่วงไหน สลับอาวุธยังไง) อยู่ที่ ArenaMatch ซึ่งเป็นเจ้าของกระเป๋า/ของติดตัวของทุกคน
local TweenService = game:GetService("TweenService")
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
	-- **ร่วงลงพื้น** (ผู้ใช้สั่ง 2026-09-25): เริ่มที่ระดับอกของคนตาย ตั้งเฉียงๆ แล้วตกลงไปนอนราบกับพื้น
	-- เด้งนิดหนึ่ง · ใช้ Tween ไม่ใช่ฟิสิกส์จริง — ของที่ปล่อยให้ฟิสิกส์ตกเองกระเด็นได้/ทะลุพื้นได้
	-- และกองศพสามศพที่ทับกันจะผลักอาวุธกระจาย ส่วน Tween จบที่พื้นเสมอ
	-- นอนราบ: ตัวอาวุธยาวไปตามแกน Y ของโมเดล → หมุน 90° รอบ X · หันสุ่มให้กองไม่ดูเป็นแถว
	local ground = groundBelow(position)
	local heading = CFrame.Angles(0, math.random() * math.pi * 2, 0)
	local rest = CFrame.new(ground + Vector3.new(0, 0.35, 0)) * heading * CFrame.Angles(math.rad(90), 0, 0)
	local startY = math.max(position.Y, ground.Y + 1.5)
	model:PivotTo(CFrame.new(ground.X, startY, ground.Z) * heading * CFrame.Angles(math.rad(25), 0, math.rad(15)))
	local fall = Instance.new("CFrameValue")
	fall.Value = model:GetPivot()
	fall.Changed:Connect(function(cf)
		if model.Parent then model:PivotTo(cf) end
	end)
	local seconds = math.clamp((startY - ground.Y) * 0.12, 0.35, 0.8)
	local tween = TweenService:Create(fall, TweenInfo.new(seconds, Enum.EasingStyle.Bounce, Enum.EasingDirection.Out),
		{ Value = rest })
	tween.Completed:Once(function() fall:Destroy() end)
	task.defer(function() tween:Play() end) -- หลัง model.Parent ถูกตั้ง (ท้ายฟังก์ชัน)

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
