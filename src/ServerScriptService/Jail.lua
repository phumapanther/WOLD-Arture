-- Jail: การคุมขัง — ใครติดคุกอยู่ ถึงเมื่อไหร่ และลูกกรงกันใครไว้
--
-- แยกออกมาจาก `Arrest.server.lua` เพราะเป็นคนละอายุ การจับกุมจบใน 2 นาทีและต้องมีทหารยามยืนอยู่ตรงนั้น
-- ส่วนการคุมขังอยู่ได้ถึง 30 นาที ข้ามการตาย ข้ามการออกจากเกม และไม่มีใครต้องเฝ้า
--
-- **โทษเดินตามเวลาจริง ไม่ใช่เวลาที่อยู่ในเกม** เก็บเป็น `os.time()` ที่จะพ้นโทษ ไม่ใช่ "เหลืออีกกี่วินาที"
-- เพราะค่าที่นับถอยหลังจะหยุดเดินตอนออกจากเกม ซึ่งแปลว่าออกเกมคือวิธีหนีคุกที่ง่ายที่สุด — ผู้ใช้เลือกแล้ว
-- ว่าเวลาต้องเดินต่อ
local Players = game:GetService("Players")
local PhysicsService = game:GetService("PhysicsService")

local ProfileAccess = require(game.ServerScriptService.ProfileAccess)

local Jail = {}

-- ชื่อกลุ่มการชน: นักโทษอยู่กลุ่มหนึ่ง ลูกกรงอีกกลุ่มหนึ่ง แล้วสั่งให้สองกลุ่มนี้ชนกัน
--
-- **ทำแบบนี้แทนการตั้ง CanCollide บนลูกกรง** เพราะ CanCollide เป็นของชิ้นส่วน ไม่ใช่ของคู่ที่ชนกัน
-- ถ้าเปิดไว้ก็กันทุกคนรวมทั้งทหารยาม ถ้าปิดก็ไม่กันใครเลย ผู้ใช้เลือกว่าคนอื่นต้องเดินผ่านได้ตามปกติ
local GROUP_PRISONER = "WOLD_Prisoner"
local GROUP_BARS = "WOLD_PrisonBars"

-- [player] = { until_ = เวลาที่พ้นโทษ (os.time), gui = ป้ายนับถอยหลัง }
local Live = {}

-- ชิ้นส่วนลูกกรงที่ตั้งกลุ่มไปแล้ว กันไม่ให้ไล่ซ้ำ
local barred = {}

--------------------------------------------------------------------------------
-- กลุ่มการชน
--------------------------------------------------------------------------------

local ready = false

local function ensureGroups()
	if ready then return true end
	local ok = pcall(function()
		-- RegisterCollisionGroup โยน error ถ้ามีอยู่แล้ว ซึ่งเกิดได้จริงตอนเซิร์ฟเวอร์รีสตาร์ตแบบ soft
		pcall(PhysicsService.RegisterCollisionGroup, PhysicsService, GROUP_PRISONER)
		pcall(PhysicsService.RegisterCollisionGroup, PhysicsService, GROUP_BARS)
		-- ลูกกรงกันเฉพาะนักโทษ ไม่กันคนกลุ่ม Default
		PhysicsService:CollisionGroupSetCollidable(GROUP_BARS, "Default", false)
		PhysicsService:CollisionGroupSetCollidable(GROUP_BARS, GROUP_PRISONER, true)
		-- นักโทษยังชนพื้น/กำแพง/คนอื่นได้ตามปกติ
		PhysicsService:CollisionGroupSetCollidable(GROUP_PRISONER, "Default", true)
		PhysicsService:CollisionGroupSetCollidable(GROUP_PRISONER, GROUP_PRISONER, true)
	end)
	ready = ok
	return ok
end

--------------------------------------------------------------------------------
-- หาลูกกรงกับห้องขังในแมพ
--------------------------------------------------------------------------------

-- `PrisonCage` ซ้อนตัวเองอยู่ (ตัวนอก 1 + ตัวใน 5) เหมือน DistillSet/Reactor ที่ CLAUDE.md เตือนไว้
-- แต่ที่นี่ไม่ต้องเลือกตัวนอกสุด: เราต้องการ **ทุกชิ้นส่วน** ไม่ว่าจะอยู่ชั้นไหน การไล่ descendants จาก
-- ตัวไหนก็ได้จึงให้คำตอบเดียวกัน
local function markBars()
	if not ensureGroups() then return 0 end
	local n = 0
	for _, d in ipairs(workspace:GetDescendants()) do
		if d.Name == "PrisonCage" and (d:IsA("Model") or d:IsA("BasePart")) then
			local parts = d:IsA("BasePart") and { d } or d:GetDescendants()
			for _, part in ipairs(parts) do
				if part:IsA("BasePart") and not barred[part] then
					barred[part] = true
					-- ต้องชนได้ ไม่งั้นกลุ่มการชนก็ไม่มีความหมาย
					part.CanCollide = true
					pcall(function() part.CollisionGroup = GROUP_BARS end)
					n += 1
				end
			end
		end
	end
	return n
end

-- จุดที่ส่งนักโทษไป: กลางพื้นฟางใน ContainmentArea
--
-- หาเอาเองจากแมพจริงแทนที่จะฝังพิกัดไว้ เพราะห้องขังย้ายได้ และพิกัดที่ฝังไว้จะกลายเป็นคำโกหกเงียบๆ
-- ที่ส่งคนไปโผล่กลางอากาศ — กฎเดียวกับที่จุดเรียกพาหนะใช้
function Jail.CellSpot()
	local area
	for _, d in ipairs(workspace:GetDescendants()) do
		if d.Name == "ContainmentArea" then area = d break end
	end
	if not area then return nil end

	-- สุ่มพื้นฟางสักแผ่น เพื่อให้นักโทษหลายคนไม่ไปยืนซ้อนกันที่จุดเดียว
	local floors = {}
	for _, p in ipairs(area:IsA("BasePart") and { area } or area:GetDescendants()) do
		if p:IsA("BasePart") then table.insert(floors, p) end
	end
	if #floors == 0 then return nil end

	local pick = floors[math.random(#floors)]
	-- ยืนบนพื้น ไม่ใช่จมอยู่ในมัน
	return CFrame.new(pick.Position + Vector3.new(0, pick.Size.Y / 2 + 3.5, 0))
end

--------------------------------------------------------------------------------
-- ป้ายนับถอยหลังเหนือหัว
--------------------------------------------------------------------------------

local function clock(seconds)
	seconds = math.max(0, math.floor(seconds))
	return ("%d:%02d"):format(math.floor(seconds / 60), seconds % 60)
end

local function showTimer(player)
	local character = player.Character
	local head = character and character:FindFirstChild("Head")
	if not head then return nil end
	local existing = head:FindFirstChild("JailTimer")
	if existing then return existing end

	local gui = Instance.new("BillboardGui")
	gui.Name = "JailTimer"
	gui.Size = UDim2.fromOffset(110, 34)
	gui.StudsOffsetWorldSpace = Vector3.new(0, 2.6, 0)
	gui.MaxDistance = 80
	gui.AlwaysOnTop = true
	gui.Parent = head

	local label = Instance.new("TextLabel")
	label.Name = "Text"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(255, 190, 90)
	label.TextStrokeTransparency = 0.4
	label.Text = "⛓ --:--"
	label.Parent = gui
	return gui
end

local function hideTimer(player)
	local character = player and player.Character
	local head = character and character:FindFirstChild("Head")
	local gui = head and head:FindFirstChild("JailTimer")
	if gui then gui:Destroy() end
end

--------------------------------------------------------------------------------
-- ใส่/ถอดสถานะนักโทษบนตัวละคร
--------------------------------------------------------------------------------

-- ตัวละครทั้งตัวเข้ากลุ่มนักโทษ ทุกชิ้น — ถ้าเหลือชิ้นไหนไว้ ชิ้นนั้นจะเดินทะลุลูกกรงแล้วลากทั้งตัวตามไป
local function setPrisonerParts(character, on)
	if not character then return end
	local group = on and GROUP_PRISONER or "Default"
	for _, part in ipairs(character:GetDescendants()) do
		if part:IsA("BasePart") then
			pcall(function() part.CollisionGroup = group end)
		end
	end
end

local function applyTo(player)
	local entry = Live[player]
	if not entry then return end
	setPrisonerParts(player.Character, true)
	showTimer(player)
end

--------------------------------------------------------------------------------
-- คำสั่งหลัก
--------------------------------------------------------------------------------

-- ส่งเข้าคุกเป็นเวลา `seconds` วินาที
function Jail.Commit(player, seconds)
	if not player or not player.Parent then return false, "ไม่มีผู้เล่นคนนี้" end
	seconds = tonumber(seconds)
	if not seconds or seconds <= 0 then return false, "เวลาไม่ถูกต้อง" end

	markBars()
	local spot = Jail.CellSpot()
	if not spot then return false, "ไม่เจอห้องขังในแมพ" end

	-- โทษที่ยาวกว่าไม่ถูกโทษที่สั้นกว่าลบทิ้ง กฎเดียวกับหัวแดง
	local until_ = os.time() + seconds
	local existing = Live[player]
	if existing and existing.until_ > until_ then until_ = existing.until_ end

	Live[player] = { until_ = until_ }
	player:SetAttribute("WOLD_Jailed", true)

	-- เซฟทันที ไม่รอ autosave — ถ้าเซิร์ฟเวอร์ล่มระหว่างนี้ โทษต้องไม่หายไป
	local data = ProfileAccess.Get(player)
	if data then data.JailUntil = until_ end

	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root then root.CFrame = spot end
	applyTo(player)
	return true
end

function Jail.Release(player)
	if not Live[player] then return false end
	Live[player] = nil
	player:SetAttribute("WOLD_Jailed", nil)
	local data = ProfileAccess.Get(player)
	if data then data.JailUntil = nil end
	setPrisonerParts(player.Character, false)
	hideTimer(player)
	return true
end

function Jail.IsJailed(player)
	local entry = Live[player]
	return entry ~= nil and entry.until_ > os.time()
end

function Jail.SecondsLeft(player)
	local entry = Live[player]
	if not entry then return 0 end
	return math.max(0, entry.until_ - os.time())
end

--------------------------------------------------------------------------------
-- วงจรชีวิต
--------------------------------------------------------------------------------

-- ตายแล้วเกิดใหม่ = กลับเข้าคุก ไม่ใช่หลุดออกมา ตัวละครใหม่ไม่มีทั้งกลุ่มการชนและป้าย ต้องใส่ให้ใหม่ทุกครั้ง
local function watch(player)
	player.CharacterAdded:Connect(function(character)
		if not Live[player] then return end
		-- รอให้ชิ้นส่วนมาครบก่อน ไม่งั้นจะตั้งกลุ่มให้ตัวละครที่ยังประกอบไม่เสร็จ
		character:WaitForChild("HumanoidRootPart", 10)
		task.wait(0.2)
		if not Live[player] then return end
		local spot = Jail.CellSpot()
		local root = character:FindFirstChild("HumanoidRootPart")
		if spot and root then root.CFrame = spot end
		applyTo(player)
	end)
end

-- โทษที่ค้างมาจากเซสชันก่อน
function Jail.Restore(player)
	local data = ProfileAccess.Get(player)
	local until_ = data and data.JailUntil
	if not until_ or until_ <= os.time() then
		if data then data.JailUntil = nil end
		return false
	end
	markBars()
	Live[player] = { until_ = until_ }
	player:SetAttribute("WOLD_Jailed", true)
	local spot = Jail.CellSpot()
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if spot and root then root.CFrame = spot end
	applyTo(player)
	return true
end

-- เข้าเกมมา: รอโปรไฟล์ แล้วดูว่ามีโทษค้างอยู่ไหม
--
-- **Jail เป็นฝ่ายถามโปรไฟล์เอง ไม่ใช่ให้ PlayerProfile มาเรียก** ถ้า PlayerProfile ต้อง require Jail
-- มันจะกลายเป็นวงจร (Jail require ProfileAccess ซึ่งเป็นของคู่กับ PlayerProfile) — รูปแบบเดียวกับที่
-- ระบบอื่นทั้งหมดในเกมใช้กับ ProfileAccess.Wait
local function onJoin(player)
	watch(player)
	task.spawn(function()
		-- รอโปรไฟล์แบบไม่มีเส้นตาย เหตุผลเดียวกับที่ ProfileAccess.Wait อธิบายไว้: เส้นตายที่หมดก่อน
		-- ข้อมูลมาถึง แปลว่านักโทษเดินออกจากคุกได้เพราะ DataStore ช้า
		for _ = 1, 120 do
			if not player.Parent then return end
			if ProfileAccess.Get(player) then break end
			task.wait(0.5)
		end
		if not player.Parent then return end
		-- ตัวละครอาจยังมาไม่ถึง Restore จะวางกลุ่มการชนให้เท่าที่มี ส่วนลูปนาฬิกาเก็บที่เหลือ
		Jail.Restore(player)
	end)
end

Players.PlayerAdded:Connect(onJoin)
for _, player in ipairs(Players:GetPlayers()) do onJoin(player) end

Players.PlayerRemoving:Connect(function(player)
	-- ไม่เรียก Release: การออกจากเกมไม่ใช่การพ้นโทษ แค่ลบของที่อยู่ในหน่วยความจำ ส่วน JailUntil ใน
	-- profile ยังอยู่และจะถูกอ่านกลับตอนเข้ามาใหม่
	Live[player] = nil
end)

--------------------------------------------------------------------------------
-- นาฬิกา
--------------------------------------------------------------------------------

-- ทุกครึ่งวินาที: อัปเดตป้าย และปล่อยคนที่ครบกำหนด
--
-- **ลูปที่ถามใหม่เรื่อยๆ ไม่ใช่การนัดเวลาไว้ล่วงหน้า** กฎเดียวกับทั้งโปรเจ็ค: ป้ายแขวนอยู่กับหัวที่
-- StreamingEnabled ส่งมาคนละรอบ ถ้าผูกครั้งเดียวตอนเริ่มจะแพ้จังหวะกับบางคน และเป็นคนละคนทุกรอบ
task.spawn(function()
	while true do
		task.wait(0.5)
		local now = os.time()
		for player, entry in pairs(Live) do
			if not player.Parent then
				Live[player] = nil
			elseif entry.until_ <= now then
				Jail.Release(player)
			else
				-- สร้างป้ายใหม่ถ้ายังไม่มี (หัวเพิ่งมาถึง หรือเพิ่งเกิดใหม่)
				local gui = showTimer(player)
				local label = gui and gui:FindFirstChild("Text")
				if label then
					label.Text = "⛓ " .. clock(entry.until_ - now)
				end
				-- ตัวละครที่เพิ่งประกอบเสร็จอาจยังไม่ได้เข้ากลุ่ม ตั้งซ้ำไม่มีผลเสีย
				local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
				if root and root.CollisionGroup ~= GROUP_PRISONER then
					setPrisonerParts(player.Character, true)
				end
			end
		end
	end
end)

-- ลูกกรงมาถึงคนละรอบกับสคริปต์เหมือนกัน ถามใหม่เรื่อยๆ จนกว่าจะเจอ แล้วค่อยถามห่างลง
task.spawn(function()
	for _ = 1, 40 do
		if markBars() > 0 then break end
		task.wait(0.5)
	end
end)

return Jail
