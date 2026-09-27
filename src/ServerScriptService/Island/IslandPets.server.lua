-- IslandPets.server.lua: สัตว์เลี้ยงบนเกาะ — เดินเล่นเอง ลูบหัวได้ อุ้มย้ายที่ได้ โตตามการลูบ และให้บัพกับทั้งฟาร์ม
--
-- **ต่างจากสัตว์ในคอกโดยสิ้นเชิง** สัตว์ในคอกเป็นกล่องนิ่งที่กด E เก็บผลผลิต (`IslandZones`)
-- ส่วนสัตว์เลี้ยงเป็น rig จริงที่เดินเล่นทั่วเกาะ ให้ **บัพ** กับทั้งฟาร์ม และอยู่ถาวร
--
-- ## เฟส 2d (ผู้ใช้อนุมัติ 2026-09-27)
-- 24 ชนิด (`IslandConfig.PetSpecies`) · เกิดมาตัวเล็ก 30% โตตาม **จำนวนครั้งที่ลูบ** (`entry.pats` ในโปรไฟล์ ·
-- ติดไปกับไอเทมเป็น `meta.pats` ตอนเก็บคืนกระเป๋า) · ลูบได้ตัวละครั้งต่อ 30 นาที · ทุกครั้งได้ EXP + วัตถุดิบ 1-5 ชิ้น
-- (`PetRules`) · หมา/แมวรุ่นก่อนเฟส 2d นับเป็นโตเต็มวัย
--
-- ท่าเดินสามแบบตาม `spec.motion`:
--   beast    — `BeastGait` (สี่ขา แมงมุม ค้างคาว) ขับข้อต่อที่มีแอตทริบิวต์ Phase
--   humanoid — R15 + ท่าเดิน/ยืนมาตรฐานของ Roblox เล่นจาก Animator ฝั่งเซิร์ฟ (replicate ปกติ)
--   slime    — ลูกบอลเดินด้วย MoveTo แล้วกระโดดเป็นจังหวะ = ดุ๊กดิ๊ก
--
-- ## กฎเหล็กที่ต้องระวัง
--
-- ⚠️ `BeastGait` **โมดูล** (`ServerScriptService.BeastGait`) ไม่ใช่ **สคริปต์** ที่ติดมากับโมเดล —
-- สคริปต์ในโมเดลเขียน `Motor6D.Transform` ซึ่ง**ไม่ replicate** (ใน Studio เห็นขยับ ในเกมจริงยืนแข็ง)
-- โมดูลปิดสคริปต์นั้นให้แล้วทำแบบเดียวกันลง `C0` · เรียก `Attach` เสมอ อย่าปล่อยให้สคริปต์ทำเอง
-- ⚠️ **ย่อ/ขยายด้วย `ScaleTo` รอบจุดบนพื้นใต้ตัวสัตว์** ไม่ใช่รอบ Root (Root ตรึงอยู่ที่จุดวาง สัตว์เดินไปไกลแล้ว
-- = ScaleTo รอบ Root จะดึงตัวสัตว์วาร์ปเข้าหาจุดวาง) — ย้าย Root ไปใต้ตัวชั่วคราวแล้วคืนที่เดิม
-- ⚠️ **ห้ามติดแท็ก `WOLD_Mob`** ระบบต่อสู้ตีทุกอย่างที่มีแท็กนี้
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local ServerConfig = require(game.ServerScriptService.ServerConfig)
if not ServerConfig.IsFarm then return end

local IslandConfig = require(game.ReplicatedStorage.IslandConfig)
local ItemCatalog = require(game.ReplicatedStorage.ItemCatalog)
local PetRules = require(game.ReplicatedStorage.PetRules)
local IslandAccess = require(game.ServerScriptService.Island.IslandAccess)
local BeastGait = require(game.ServerScriptService.BeastGait)
local Inventory = require(game.ServerScriptService.Inventory)
local Remotes = require(game.ReplicatedStorage.Remotes)
local Progression = require(game.ServerScriptService.Progression)

local WANDER_RADIUS = 60 -- เดินเล่นไกลจากจุดที่วางได้เท่านี้ (ทั่วฟาร์ม ไม่ใช่ยืนกับที่)
local CARRY_RANGE = 12
-- ท่ามาตรฐาน R15 ของ Roblox (ตัวเดียวกับที่ Mobs ใช้เดิน) · ยืน = ท่าหายใจ ไม่ใช่รูปปั้น
local ANIM_WALK = "rbxassetid://913402848"
local ANIM_IDLE = "rbxassetid://507766388"
local MOVING_SPEED = 0.6

local Live = {} -- [model] = { uid, id, spec, carriedBy, fullScale, fullSize, walker, tracks, hopAt }
local rng = Random.new()

-- **ประกาศไว้ก่อนใช้** ปุ่มถูกผูกใน `setup` ซึ่งอยู่เหนือนิยามจริงของสองตัวนี้ — local ที่ประกาศทีหลัง
-- จะเป็น nil ตอน closure จับได้ (กับดัก "ใช้ก่อนประกาศ" ที่โปรเจ็คนี้เจอมาห้าครั้ง)
local pat, toggleCarry

--------------------------------------------------------------------------------
-- ข้อมูลของตัวสัตว์
--------------------------------------------------------------------------------

local function isPet(model)
	local id = model:GetAttribute("ItemId")
	return id and IslandConfig.Pets[id] == true
end

-- แถวของสัตว์ตัวนี้ในโปรไฟล์เกาะ (nil = เจ้าของไม่อยู่ โปรไฟล์ปิดแล้ว)
local function entryOf(model)
	local data = IslandAccess.Data and IslandAccess.Data()
	local uid = model:GetAttribute("Uid")
	if not data or not uid then return nil end
	for _, entry in ipairs(data.placed or {}) do
		if entry.uid == uid then return entry end
	end
	return nil
end

-- ชื่อที่พูดถึงตัวสัตว์ ("ไก่ (สัตว์เลี้ยง)" ในร้าน → "ไก่" ตอนคุยกับมัน)
local function nameOf(id)
	local item = ItemCatalog.Get(id)
	local name = item and item.name or id
	return (name:gsub(" %(สัตว์เลี้ยง%)", ""))
end

-- จำนวนครั้งที่ลูบ (ตัวเลขที่แก้แล้ว) · โปรไฟล์ก่อน แอตทริบิวต์เป็นทางสำรองตอนเจ้าของไม่อยู่
local function patsOf(model)
	local id = model:GetAttribute("ItemId")
	local entry = entryOf(model)
	local raw = entry and entry.pats
	if not entry then raw = model:GetAttribute("Pats") end
	return IslandConfig.PetPats(id, raw)
end

local function growthText(model)
	local id = model:GetAttribute("ItemId")
	local g = IslandConfig.PetGrowth01(id, patsOf(model))
	if g >= 1 then return "โตเต็มวัย" end
	return ("โต %d%%"):format(math.floor(g * 100))
end

-- ลูบได้หรือยัง · เวลาเป็น os.time (ข้ามการรีสตาร์ทได้) อ่านจากโปรไฟล์ก่อน แอตทริบิวต์เป็นทางสำรองตอนเจ้าของไม่อยู่
local function patReady(model)
	local entry = entryOf(model)
	local last = (entry and entry.pat) or model:GetAttribute("PatAt") or 0
	return os.time() - last >= IslandConfig.PetPatSeconds
end

--------------------------------------------------------------------------------
-- ขนาดตัว
--------------------------------------------------------------------------------

-- กล่องของตัวสัตว์ (ไม่รวม Root) — ใช้เมื่อต้นแบบไม่มี FullSize (หมา/แมวก่อนรันเฟส 103)
local function bodySize(model)
	local lo, hi = Vector3.new(math.huge, math.huge, math.huge), Vector3.new(-math.huge, -math.huge, -math.huge)
	for _, p in ipairs(model:GetDescendants()) do
		if p:IsA("BasePart") and p.Name ~= "Root" then
			lo = lo:Min(p.Position - p.Size / 2)
			hi = hi:Max(p.Position + p.Size / 2)
		end
	end
	if lo.X == math.huge then return Vector3.new(2, 2, 2) end
	return hi - lo
end

-- ขนาดตอนนี้เป็นสัดส่วนของตัวเต็มวัย
local function sizeFraction(model)
	return IslandConfig.PetSizeFraction(model:GetAttribute("ItemId"), patsOf(model))
end

-- ความเร็ว/แรงกระโดดตามขนาด (ตัวเล็กเดินต้วมเตี้ยม) — beast ใช้ค่าในโมเดลตามเดิม BeastGait ปรับจังหวะก้าวเอง
local function tuneHumanoid(model, state)
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if not humanoid or state.spec.motion == "beast" then return end
	local g = IslandConfig.PetGrowth01(state.id, patsOf(model))
	humanoid.WalkSpeed = 3 + 4 * g
	if state.spec.motion == "slime" then
		humanoid.UseJumpPower = true
		humanoid.JumpPower = 16 + 12 * g
	end
end

-- ย่อ/ขยายให้ตรงกับจำนวนครั้งที่ลูบ · `atPlacement` = ยังยืนอยู่ที่จุดวาง (Root อยู่ใต้ตัวพอดี ใช้เป็นจุดหมุนได้เลย)
local function applySize(model, state, atPlacement)
	local target = state.fullScale * sizeFraction(model)
	if math.abs(model:GetScale() - target) < 0.002 then
		tuneHumanoid(model, state)
		return
	end
	local root = model:FindFirstChild("Root")
	local hrp = model:FindFirstChild("HumanoidRootPart")
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if not root or not hrp or not humanoid then return end
	local beast = state.spec.motion == "beast"
	if beast then BeastGait.Detach(model) end
	local rootCf, rootSize = root.CFrame, root.Size
	if not atPlacement then
		-- จุดหมุน = พื้นใต้ตัว ไม่ใช่จุดที่วางไว้ตอนแรก (ดูหัวไฟล์) · Root anchored และไม่ได้เชื่อมกับตัวสัตว์
		-- ย้ายมันเฉยๆ จึงไม่ลากตัวสัตว์ไปด้วย
		local ground = hrp.Position - Vector3.new(0, hrp.Size.Y / 2 + humanoid.HipHeight, 0)
		root.CFrame = CFrame.new(ground)
	end
	model:ScaleTo(target)
	root.Size = rootSize
	root.CFrame = rootCf
	if beast and not state.carriedBy then BeastGait.Attach(model, { wander = true }) end
	tuneHumanoid(model, state)
end

--------------------------------------------------------------------------------
-- เดินเล่น
--------------------------------------------------------------------------------

-- humanoid/slime: สุ่มจุดรอบบ้านแล้ว MoveTo · token ต่อรอบ — หยุด/เริ่มใหม่ (อุ้มแล้ววาง) = รอบเก่าจบเอง
local function startWalker(model, state)
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local hrp = model:FindFirstChild("HumanoidRootPart")
	if not humanoid or not hrp then return end
	local token = {}
	state.walker = token
	local home = hrp.Position
	task.spawn(function()
		while model.Parent and state.walker == token do
			task.wait(rng:NextInteger(4, 9))
			if state.walker ~= token or not model.Parent then break end
			local a, r = rng:NextNumber() * math.pi * 2, math.sqrt(rng:NextNumber()) * WANDER_RADIUS
			humanoid:MoveTo(home + Vector3.new(math.cos(a) * r, 0, math.sin(a) * r))
			-- MoveTo หมดเวลาเองใน 8 วิถ้าไปไม่ถึง (ติดกำแพง) Finished ยิงเสมอ ไม่ค้าง
			humanoid.MoveToFinished:Wait()
		end
	end)
end

local function startMotion(model, state)
	if state.carriedBy then return end
	if state.spec.motion == "beast" then
		BeastGait.Attach(model, { wander = true })
	else
		startWalker(model, state)
	end
end

local function stopMotion(model, state)
	if state.spec.motion == "beast" then
		BeastGait.Detach(model)
	else
		state.walker = nil
		local humanoid = model:FindFirstChildOfClass("Humanoid")
		local hrp = model:FindFirstChild("HumanoidRootPart")
		if humanoid and hrp then humanoid:MoveTo(hrp.Position) end
	end
end

-- ท่ามาตรฐานของ R15 โหลดครั้งเดียวต่อตัว
local function tracksOf(model, state)
	if state.tracks then return state.tracks end
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local animator = humanoid and (humanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator", humanoid))
	if not animator then return nil end
	local function load(id, priority)
		local anim = Instance.new("Animation")
		anim.AnimationId = id
		local ok, track = pcall(function() return animator:LoadAnimation(anim) end)
		if not ok then return nil end
		track.Priority = priority
		track.Looped = true
		return track
	end
	state.tracks = { walk = load(ANIM_WALK, Enum.AnimationPriority.Movement), idle = load(ANIM_IDLE, Enum.AnimationPriority.Idle) }
	return state.tracks
end

local function animate(model, state)
	if state.spec.motion == "beast" then return end -- BeastGait ขับเองทุกเฟรม
	local hrp = model:FindFirstChild("HumanoidRootPart")
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if not hrp or not humanoid then return end
	local vel = hrp.AssemblyLinearVelocity
	local speed = Vector3.new(vel.X, 0, vel.Z).Magnitude
	local moving = speed > MOVING_SPEED and not state.carriedBy
	if state.spec.motion == "humanoid" then
		local tracks = tracksOf(model, state)
		if not tracks then return end
		local walk, idle = tracks.walk, tracks.idle
		if moving then
			if idle and idle.IsPlaying then idle:Stop(0.2) end
			if walk then
				if not walk.IsPlaying then walk:Play(0.2) end
				-- ขาสั้นก้าวถี่: ท่าเดินมาตรฐานออกแบบมาที่ ~6 สตัด/วิ สำหรับตัวสูงเท่าคน
				walk:AdjustSpeed(math.clamp(speed / (6 * sizeFraction(model)), 0.4, 2.2))
			end
		else
			if walk and walk.IsPlaying then walk:Stop(0.25) end
			if idle and not idle.IsPlaying then idle:Play(0.3) end
		end
	elseif state.spec.motion == "slime" and moving then
		-- กระโดดเป็นจังหวะตอนเดิน = สไลม์ดุ๊กดิ๊ก (ยืนนิ่งไม่กระโดด)
		local now = os.clock()
		if now >= (state.hopAt or 0) and humanoid.FloorMaterial ~= Enum.Material.Air then
			humanoid.Jump = true
			state.hopAt = now + rng:NextNumber() * 0.4 + 0.7
		end
	end
end

--------------------------------------------------------------------------------
-- ป้ายชื่อ + ความโต เหนือหัว (เฟส 2d)
--------------------------------------------------------------------------------

-- ป้ายเดียวของทุกตัว (แทนป้ายชื่อของ kit ที่หมา/แมวเคยพกมา) · สร้างฝั่งเซิร์ฟ = ทุกคนบนเกาะเห็นเหมือนกัน
-- **ขนาดเป็นสตัด** (Scale ของ BillboardGui) ป้ายเล็กลงตามระยะเหมือนของในโลก · อยู่ใต้ป้าย ❤️ ของ IslandBadgeController
-- (❤️ อยู่เหนือยอดหัว 1.2-3.8 สตัด · ป้ายนี้ 0.2-1.0) · ลอยตามความสูงจริงที่โตขึ้น
local TAG_DISTANCE = 22
local function updateTag(model, state)
	local hrp = model:FindFirstChild("HumanoidRootPart")
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if not hrp or not humanoid then return end
	local tag = hrp:FindFirstChild("PetTag")
	if not tag then
		tag = Instance.new("BillboardGui")
		tag.Name = "PetTag"
		tag.Size = UDim2.fromScale(6, 0.8)
		tag.LightInfluence = 0
		tag.MaxDistance = TAG_DISTANCE
		tag.Parent = hrp
		local label = Instance.new("TextLabel")
		label.Name = "Text"
		label.BackgroundTransparency = 1
		label.Size = UDim2.fromScale(1, 1)
		label.Font = Enum.Font.GothamBold
		label.TextScaled = true
		label.RichText = true
		label.TextColor3 = Color3.fromRGB(245, 240, 225)
		label.TextStrokeTransparency = 0.35
		label.TextStrokeColor3 = Color3.fromRGB(30, 26, 20)
		label.Parent = tag
	end
	local g = IslandConfig.PetGrowth01(state.id, patsOf(model))
	local grown = g >= 1
	local text = grown and ("%s  <font color=\"#FFD45C\">✨ โตเต็มวัย</font>"):format(nameOf(state.id))
		or ("%s  <font color=\"#9BE08A\">โต %d%%</font>"):format(nameOf(state.id), math.floor(g * 100))
	local label = tag:FindFirstChild("Text")
	if label and label.Text ~= text then label.Text = text end
	-- ยอดหัว = พื้นใต้ตัว + ความสูงตอนนี้ (FullSize × สัดส่วนขนาด) · ปัดทีละ 0.1 กันเขียนค่าทุกวินาที
	local feet = hrp.Position.Y - (hrp.Size.Y / 2 + humanoid.HipHeight)
	local top = feet + state.fullSize.Y * sizeFraction(model)
	local lift = math.floor((top - hrp.Position.Y + 0.6) * 10 + 0.5) / 10
	if state.carriedBy then lift = math.floor((state.fullSize.Y * sizeFraction(model) * 0.5 + 0.6) * 10 + 0.5) / 10 end
	local offset = Vector3.new(0, lift, 0)
	if tag.StudsOffsetWorldSpace ~= offset then tag.StudsOffsetWorldSpace = offset end
end

--------------------------------------------------------------------------------
-- ปุ่ม
--------------------------------------------------------------------------------

-- **ปุ่มที่ใช้ไม่ได้ตอนนี้ต้องซ่อนเสมอ** (ผู้ใช้สั่ง): E ซ่อนตอนติดคูลดาวน์หรือถูกอุ้ม · F ซ่อนตอนถูกอุ้ม
-- ที่เดียวที่ตั้ง Enabled ของสองปุ่มนี้ — ลูป 1 วิเรียกซ้ำจึงเปิดกลับเองเมื่อคูลดาวน์หมด
local function refreshPrompts(model)
	local state = Live[model]
	local hrp = model:FindFirstChild("HumanoidRootPart")
	if not state or not hrp then return end
	local carried = state.carriedBy ~= nil
	local canPat = not carried and patReady(model)
	local petPrompt = hrp:FindFirstChild("PetPrompt")
	if petPrompt then
		petPrompt.Enabled = canPat
		-- ชื่อ + ความโต บนปุ่ม (เฟส 2d) — เห็นทุกครั้งที่เดินเข้าไปใกล้ ไม่ต้องเปิดหน้าต่างไหน
		local text = ("%s · %s"):format(nameOf(state.id), growthText(model))
		if petPrompt.ObjectText ~= text then petPrompt.ObjectText = text end
	end
	-- ประกาศให้ป้าย ❤️ ลอยเหนือหัว (IslandBadgeController อ่านแอตทริบิวต์ ไม่อ่าน Enabled ของปุ่ม)
	if model:GetAttribute("PatReady") ~= canPat then model:SetAttribute("PatReady", canPat) end
	local carryPrompt = hrp:FindFirstChild("CarryPrompt")
	if carryPrompt then carryPrompt.Enabled = not carried end
	updateTag(model, state)
end

local function setup(model)
	if Live[model] then return end
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local root = model:FindFirstChild("HumanoidRootPart")
	local id = model:GetAttribute("ItemId")
	local spec = id and IslandConfig.PetSpecies[id]
	if not humanoid or not root or not spec then return end

	local fullScale = model:GetAttribute("FullScale") or model:GetScale()
	local fullSize = model:GetAttribute("FullSize")
	if typeof(fullSize) ~= "Vector3" then fullSize = bodySize(model) end
	local state = { uid = model:GetAttribute("Uid"), id = id, spec = spec, fullScale = fullScale, fullSize = fullSize }
	Live[model] = state

	-- ป้ายชื่อของ kit ที่หมา/แมวรุ่นแรกพกมา — ใช้ป้าย PetTag ของไฟล์นี้แทน (เฟส 103 ถอดจากต้นแบบแล้ว ตรงนี้กันต้นแบบเก่า)
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BillboardGui") and d.Name == "NameTag" then d:Destroy() end
	end

	-- **ย่อให้ตรงขนาดก่อนปลด anchor** — ตอนนี้ยังยืนที่จุดวาง ตัวโคลนมาจากต้นแบบเต็มวัย
	model:SetAttribute("Pats", patsOf(model))
	applySize(model, state, true)

	-- **ปลด anchor ทุกชิ้น** IslandBuild ตรึงของที่วางไว้ทั้งหมด ซึ่งถูกสำหรับบ้านแต่ผิดสำหรับสัตว์
	-- ยกเว้น Root ล่องหนของระบบเกาะ ซึ่งไม่ใช่ส่วนหนึ่งของตัวสัตว์
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") and d.Name ~= "Root" then d.Anchored = false end
	end

	-- เดินเล่นรอบจุดที่วาง — `BeastGait` อ่าน WanderRadius จากตัวโมเดล
	model:SetAttribute("WanderRadius", WANDER_RADIUS)
	startMotion(model, state)

	-- ปุ่มลูบหัว (E) และอุ้ม (F) — แขวนที่ HumanoidRootPart เพราะปุ่มวัดระยะจากชิ้นที่มันเกาะ
	if not root:FindFirstChild("PetPrompt") then
		local petPrompt = Instance.new("ProximityPrompt")
		petPrompt.Name = "PetPrompt"
		petPrompt.ActionText = "ลูบหัว"
		petPrompt.ObjectText = nameOf(id)
		petPrompt.KeyboardKeyCode = Enum.KeyCode.E
		petPrompt.HoldDuration = 0
		petPrompt.MaxActivationDistance = 10
		petPrompt.RequiresLineOfSight = false
		petPrompt.Parent = root
		petPrompt.Triggered:Connect(function(player) pat(model, player) end)
	end

	-- **ปุ่มอุ้มต้องไม่ชนกับปุ่มเก็บของระบบเกาะ** ซึ่งก็ใช้ F เหมือนกัน
	-- `IslandBuild` แขวนปุ่มเก็บ (PickupPrompt) ไว้ที่ Root — ปุ่มอุ้มอยู่คนละชิ้นและใกล้กว่า
	-- คนที่อยากเก็บสัตว์คืนกระเป๋ายังถอยออกไปกดปุ่มเก็บได้ตามเดิม
	if not root:FindFirstChild("CarryPrompt") then
		local carry = Instance.new("ProximityPrompt")
		carry.Name = "CarryPrompt"
		carry.ActionText = "อุ้ม"
		carry.ObjectText = ""
		carry.KeyboardKeyCode = Enum.KeyCode.F
		carry.GamepadKeyCode = Enum.KeyCode.ButtonX
		carry.HoldDuration = 0
		carry.MaxActivationDistance = CARRY_RANGE
		carry.RequiresLineOfSight = false
		carry.Parent = root
		carry.Triggered:Connect(function(player)
			-- ลูบหัวสัตว์ของเพื่อนได้ แต่ **อุ้มไปวางที่อื่นไม่ได้** — นั่นคือการจัดของบนเกาะเขา
			if not IslandAccess.MayUseFixtures(player) then
				return Remotes.SocialNotify:FireClient(player, "warn", IslandAccess.FixtureDenied)
			end
			toggleCarry(model, player)
		end)
	end
	-- สองปุ่มแขวนชิ้นเดียวกัน: PromptStackController ฝั่งไคลเอนต์เรียงให้ (ลูบหัว E บน อุ้ม F ล่าง) ไม่ตั้ง UIOffset ที่นี่
	refreshPrompts(model)
end

--------------------------------------------------------------------------------
-- ลูบหัว
--------------------------------------------------------------------------------

-- "กระดูก ×3 · เหล็ก ×1"
local function describe(drops)
	local parts = {}
	for item, count in pairs(drops) do
		local it = ItemCatalog.Get(item)
		parts[#parts + 1] = ("%s ×%d"):format(it and it.name or item, count)
	end
	table.sort(parts)
	return table.concat(parts, " · ")
end

function pat(model, player)
	local state = Live[model]
	if not state or state.carriedBy then return end
	if not patReady(model) then return end -- ปุ่มถูกซ่อนอยู่แล้ว กันกดพร้อมกันสองคน
	-- ความโตต้องลงโปรไฟล์ — เจ้าของไม่อยู่ (โปรไฟล์ปิด) = ไม่นับ (แขกถูกพากลับล็อบบี้ในไม่กี่วินาทีอยู่แล้ว)
	local saved = entryOf(model)
	if not saved then return end

	-- ของที่ได้ทอยก่อน แล้ว **ถามที่ว่างก่อนนับครั้ง** — กระเป๋าเต็มแล้วลูบไป = เสียคูลดาวน์ 30 นาทีฟรีๆ
	local drops = PetRules.Roll(state.id, rng)
	for item, count in pairs(drops) do
		if not Inventory.HasRoomFor(player, item, count) then
			return Remotes.SocialNotify:FireClient(player, "error", "กระเป๋าเต็ม — เคลียร์ช่องก่อนแล้วค่อยลูบ (ของที่ได้จะหาย)")
		end
	end

	local now = os.time()
	model:SetAttribute("PatAt", now)
	saved.pat = now
	local need = IslandConfig.PetPatsToGrow(state.id)
	local before = patsOf(model)
	local after = before + 1
	saved.pats = after
	model:SetAttribute("Pats", after)
	refreshPrompts(model)

	-- หันมาหาคนลูบ แล้วกระโดดเบาๆ — ไม่มีอนิเมชันเฉพาะ ใช้สิ่งที่ Humanoid ทำได้อยู่แล้ว
	local root = model:FindFirstChild("HumanoidRootPart")
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if root and hrp then
		local look = Vector3.new(hrp.Position.X, root.Position.Y, hrp.Position.Z)
		root.CFrame = CFrame.lookAt(root.Position, look)
	end
	-- โตขึ้นหนึ่งขั้น (หลังหันหน้า — ScaleTo รอบพื้นใต้ตัวที่ตำแหน่งปัจจุบัน)
	if before < need then applySize(model, state, false) end
	updateTag(model, state)
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if humanoid then humanoid.Jump = true end

	Remotes.IslandPetHearts:FireAllClients(model)

	local xp = IslandConfig.PetPatExp
	if IslandAccess.FarmExpMultiplier then xp = math.floor(xp * IslandAccess.FarmExpMultiplier() + 0.5) end
	Progression.AwardExp(player, xp)

	local got, lost = {}, false
	for item, count in pairs(drops) do
		if Inventory.AddItem(player, item, count) then got[item] = count else lost = true end
	end

	local name = nameOf(state.id)
	local text = ("%s ดูมีความสุข (+%d EXP)"):format(name, xp)
	if next(got) then text ..= " · ได้ " .. describe(got) end
	if lost then text ..= " · กระเป๋าเต็ม ได้ของไม่ครบ" end
	if before < need then text ..= " · " .. growthText(model) end
	Remotes.SocialNotify:FireClient(player, "info", text)
	if before < need and after >= need then
		-- ครั้งที่ทำให้โตเต็มวัย: หัวใจอีกชุด + แจ้งแยกให้เห็นชัด
		task.delay(0.6, function()
			if model.Parent then Remotes.IslandPetHearts:FireAllClients(model) end
		end)
		Remotes.SocialNotify:FireClient(player, "info", ("🎉 %s โตเต็มวัยแล้ว!"):format(name))
	end
end

--------------------------------------------------------------------------------
-- อุ้ม / วาง
--------------------------------------------------------------------------------

-- อุ้มแล้วเดินไปวางที่ใหม่ได้ — **ไม่ผ่านระบบตารางของเกาะ** เพราะสัตว์ไม่ได้กินช่อง
-- (มันเดินไปเรื่อยอยู่แล้ว การจองช่องให้ของที่ขยับตลอดเวลาไม่มีความหมาย)
--
-- ⚠️ **อุ้ม = เชื่อม (Weld) ตัวสัตว์เข้ากับตัวคนอุ้ม** (แก้ 2026-09-25 ผู้ใช้แจ้ง "อุ้มแล้วกระตุกไปมา")
-- เดิมเซิร์ฟเวอร์เขียน CFrame ของสัตว์ทุกเฟรม แต่ตัวสัตว์ไม่ anchored ฟิสิกส์ยังทำงาน และ Roblox ยกความเป็น
-- เจ้าของฟิสิกส์ให้ผู้เล่นที่อยู่ใกล้ = สองฝั่งแย่งกันขยับ + ตำแหน่งคนอุ้มบนเซิร์ฟเวอร์ช้ากว่าบนจอเขา
-- เชื่อมแล้วสัตว์เป็นชิ้นส่วนเดียวกับตัวคนอุ้ม เครื่องของคนอุ้มขยับให้เองทั้งก้อน ลื่นเท่าตัวละคร
-- ระหว่างอุ้ม: ไร้มวล (ไม่ถ่วงคนอุ้ม) · ไม่ชน (ไม่ดันคนอุ้ม) · PlatformStand (ขาไม่พยายามเดิน)
-- **หัวหันออก** (ผู้ใช้สั่ง 2026-09-25) = หันทางเดียวกับคนอุ้ม · เดิมหมุน 180° หัวเลยหันเข้าหาอกคนอุ้ม
-- **ระยะห่างจากอกตามขนาดตัว** (เฟส 2d: สัตว์เลี้ยงโตได้ถึงขนาดคน) — หมาเต็มวัยได้ -2.2 เท่าค่าเดิมที่ผู้ใช้เห็นแล้ว
local function carryOffset(model, state)
	local length = math.max(state.fullSize.X, state.fullSize.Z) * sizeFraction(model)
	return CFrame.new(0, 0.5, -(0.6 + 0.35 * length))
end

local function setCarried(model, on)
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if humanoid then humanoid.PlatformStand = on end
	-- ระหว่างอุ้ม ปุ่ม E/F ลอยตามหน้าคนอุ้มตลอด (ผู้ใช้สั่ง 2026-09-25 ให้ซ่อน) → ปิดทั้งสองปุ่มสำหรับทุกคน
	-- คนอุ้มวางลงผ่านปุ่มบนจอของตัวเอง (IslandPetController ← แอตทริบิวต์ CarriedBy · Remotes.IslandPetDrop)
	-- (carriedBy ถูกตั้ง/ล้างก่อนเรียกตัวนี้เสมอ)
	refreshPrompts(model)
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") and d.Name ~= "Root" then
			if on then
				d:SetAttribute("PetCollide", d.CanCollide)
				d.CanCollide, d.Massless = false, true
			else
				local was = d:GetAttribute("PetCollide")
				if was ~= nil then d.CanCollide = was end
				d.Massless = false
				d:SetAttribute("PetCollide", nil)
			end
		end
	end
end

local function release(model, entry)
	local carrier = entry.carriedBy
	entry.carriedBy = nil
	-- เลิกเดินช้า/ท่าอุ้ม (PlayerMovement + IslandPetController อ่านแอตทริบิวต์นี้)
	if carrier and carrier.Parent then carrier:SetAttribute("WOLD_CarryingPet", nil) end
	model:SetAttribute("CarriedBy", nil)
	local root = model:FindFirstChild("HumanoidRootPart")
	local weld = root and root:FindFirstChild("PetCarryWeld")
	if weld then weld:Destroy() end
	setCarried(model, false)
end

function toggleCarry(model, player)
	local state = Live[model]
	if not state then return end
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if not hrp then return end

	if state.carriedBy == player then
		-- วางลง: ตรงหน้าคนอุ้ม ระดับพื้น
		release(model, state)
		local root = model:FindFirstChild("HumanoidRootPart")
		if root then
			local drop = hrp.CFrame * CFrame.new(0, 0, -4)
			root.CFrame = CFrame.new(drop.Position.X, hrp.Position.Y - 1.5, drop.Position.Z)
			-- เดินเล่นรอบจุดใหม่ ไม่ใช่เดินกลับไปที่เดิม
			model:SetAttribute("WanderHome", root.Position)
		end
		startMotion(model, state)
		Remotes.SocialNotify:FireClient(player, "info", "วางลงแล้ว")
		return
	end

	if state.carriedBy then
		return Remotes.SocialNotify:FireClient(player, "error", "มีคนอุ้มอยู่แล้ว")
	end
	if player:GetAttribute("WOLD_CarryingPet") then
		return Remotes.SocialNotify:FireClient(player, "error", "อุ้มได้ทีละตัว")
	end
	local root = model:FindFirstChild("HumanoidRootPart")
	if not root then return end
	state.carriedBy = player
	model:SetAttribute("CarriedBy", player.UserId)
	-- ตัวคนอุ้ม: เดินช้า (PlayerMovement) + ท่าอุ้ม (IslandPetController วาดให้ทุกเครื่อง) · ผู้ใช้สั่ง 2026-09-25
	player:SetAttribute("WOLD_CarryingPet", true)
	stopMotion(model, state)
	setCarried(model, true)
	local offset = carryOffset(model, state)
	root.CFrame = hrp.CFrame * offset
	local weld = Instance.new("Weld")
	weld.Name = "PetCarryWeld"
	weld.Part0, weld.Part1 = hrp, root
	weld.C0 = offset
	weld.Parent = root
	Remotes.SocialNotify:FireClient(player, "info", "อุ้มไว้แล้ว — กด F หรือปุ่ม วางลง บนจอ")
end

-- คนอุ้มตาย/ร่างใหม่/ออกเกม = ปล่อยสัตว์ลงตรงนั้น (Weld ไปกับร่างเก่า ต้องคืนสภาพสัตว์เอง)
-- ไม่เขียน CFrame ทุกเฟรมแล้ว — Weld ทำให้เอง (ดูหมายเหตุเหนือ setCarried) · ท่าเดิน/กระโดดของ humanoid/slime ที่นี่ด้วย
local animClock = 0
RunService.Heartbeat:Connect(function(dt)
	animClock += dt
	local doAnim = animClock >= 0.1
	if doAnim then animClock = 0 end
	for model, state in pairs(Live) do
		if not model.Parent then
			Live[model] = nil
		elseif state.carriedBy then
			local char = state.carriedBy.Character
			local hrp = char and char:FindFirstChild("HumanoidRootPart")
			local root = model:FindFirstChild("HumanoidRootPart")
			local weld = root and root:FindFirstChild("PetCarryWeld")
			if not (hrp and root and weld and weld.Part0 == hrp) then
				release(model, state)
				startMotion(model, state)
			elseif doAnim then
				animate(model, state)
			end
		elseif doAnim then
			animate(model, state)
		end
	end
end)

Remotes.IslandPetDrop.OnServerEvent:Connect(function(player)
	for model, state in pairs(Live) do
		if state.carriedBy == player then
			toggleCarry(model, player)
			return
		end
	end
end)

Players.PlayerRemoving:Connect(function(player)
	for model, state in pairs(Live) do
		if state.carriedBy == player then
			release(model, state)
			startMotion(model, state)
		end
	end
end)

--------------------------------------------------------------------------------
-- บัพให้ทั้งฟาร์ม
--------------------------------------------------------------------------------

-- มีสัตว์เลี้ยงอยู่บนเกาะไหม · **นับจากของที่วางอยู่จริง ไม่ใช่จากตารางที่จำไว้**
-- ผู้เล่นเก็บสัตว์คืนกระเป๋าได้ตลอด คำตอบจึงต้องมาจากโลกตอนนี้
local function petCount()
	local n = 0
	for model in pairs(Live) do
		if model.Parent then n += 1 end
	end
	return n
end

-- ของตกแต่งที่วางอยู่กี่ชิ้น — ยิ่งเยอะ EXP จากฟาร์มยิ่งเพิ่ม (ผู้ใช้สั่ง)
local function decorCount()
	local data = IslandAccess.Data and IslandAccess.Data()
	if not data then return 0 end
	local n = 0
	for _, entry in ipairs(data.placed or {}) do
		local item = ItemCatalog.Get(entry.id)
		-- นับเฉพาะของตกแต่ง: ไม่นับแปลงผัก คอก โซนแร่ บ้าน สัตว์เลี้ยง ซึ่งเป็นเครื่องมือ ไม่ใช่การตกแต่ง
		if item and item.kind == "placeable" and item.spot and not item.pet
			and entry.id:sub(1, 5) == "Deco_" then
			n += 1
		end
	end
	return n
end

-- ตัวคูณเวลาโตของพืช (< 1 = เร็วขึ้น) — `IslandPlots` เรียกตอนคำนวณว่าสุกหรือยัง
IslandAccess.GrowthMultiplier = function()
	if petCount() > 0 then return 1 - IslandConfig.PetGrowBonus end
	return 1
end

-- ตัวคูณ EXP จากการทำฟาร์ม (> 1 = ได้เพิ่ม) — สัตว์เลี้ยง + จำนวนของตกแต่ง
IslandAccess.FarmExpMultiplier = function()
	local bonus = 0
	if petCount() > 0 then bonus += IslandConfig.PetExpBonus end
	bonus += math.min(decorCount() * IslandConfig.DecorExpPerItem, IslandConfig.DecorExpCap)
	return 1 + bonus
end

--------------------------------------------------------------------------------
-- ลูปหาสัตว์ที่เพิ่งถูกวาง
--------------------------------------------------------------------------------

-- กฎเหล็กของโปรเจ็ค: ลูปถามใหม่ ไม่ใช่ผูก event ครั้งเดียว — ของถูกวางตอนไหนก็ได้
-- (ChildAdded ของโฟลเดอร์ที่เจอด้วย = ตั้งทันทีที่วาง ไม่เห็นตัวเต็มวัยแวบหนึ่งวินาทีก่อนหดเหลือ 30%
-- · ฝั่งเซิร์ฟไม่มี StreamingEnabled จังหวะจึงไม่แพ้ แต่ลูปยังเป็นตัวหลักเผื่อโฟลเดอร์ถูกสร้างใหม่)
local hooked = nil
local ownerTick = 0
task.spawn(function()
	while true do
		local island = workspace:FindFirstChild("WOLD_Island")
		local placed = island and island:FindFirstChild("Placed")
		if placed then
			if hooked ~= placed then
				hooked = placed
				placed.ChildAdded:Connect(function(model)
					if model:IsA("Model") and isPet(model) then setup(model) end
				end)
			end
			for _, model in ipairs(placed:GetChildren()) do
				if model:IsA("Model") and isPet(model) then setup(model) end
			end
		end
		ownerTick += 1
		for model, state in pairs(Live) do
			if model.Parent then
				refreshPrompts(model) -- คูลดาวน์ลูบหัวหมด = ปุ่ม E กลับมาเอง
				-- **เซิร์ฟเวอร์เป็นเจ้าของฟิสิกส์ของสัตว์เสมอ** (บทเรียนมอน: ปล่อยอัตโนมัติ = มือถือที่ใกล้สุดเป็นเจ้าของ
				-- แล้ว MoveTo ของเซิร์ฟไม่มีผล) · ถูกอุ้มอยู่ = เป็นก้อนเดียวกับตัวคนอุ้ม ห้ามแตะ
				if not state.carriedBy and ownerTick % 2 == 0 then
					local hrp = model:FindFirstChild("HumanoidRootPart")
					if hrp and not hrp.Anchored then pcall(function() hrp:SetNetworkOwner(nil) end) end
				end
			end
		end
		task.wait(1)
	end
end)

-- คำสั่งแอดมิน `/farm pets ready | <n>` (ผ่าน IslandFarm.FarmAdmin) — ลูบได้ทันทีทุกตัว / ตั้งจำนวนครั้งที่ลูบทุกตัวแล้วย่อขยายตาม
-- มีไว้ให้เทสในเกมจริง: คูลดาวน์ 30 นาทีต่อการลูบ ทำให้ดูการโตแบบปกติไม่ได้เลย
IslandAccess.PetAdmin = function(arg)
	local n = tonumber(arg)
	if arg ~= "ready" and not n then return "ใช้: /farm pets ready (ลูบได้ทันทีทุกตัว) | /farm pets <จำนวนครั้งที่ลูบ>" end
	local count = 0
	for model, state in pairs(Live) do
		local saved = entryOf(model)
		if model.Parent and saved then
			saved.pat = 0
			model:SetAttribute("PatAt", 0)
			if n then
				saved.pats = math.max(0, math.floor(n))
				model:SetAttribute("Pats", saved.pats)
				if not state.carriedBy then applySize(model, state, false) end
			end
			refreshPrompts(model)
			count += 1
		end
	end
	if n then return ("ตั้งการลูบของสัตว์เลี้ยง %d ตัวเป็น %d ครั้ง (ลูบได้ทันที)"):format(count, math.max(0, math.floor(n))) end
	return ("สัตว์เลี้ยง %d ตัวลูบได้ทันที"):format(count)
end

-- ช่องเทสใน Studio (ทรงเดียวกับ IslandTest)
if RunService:IsStudio() then
	local bf = Instance.new("BindableFunction")
	bf.Name = "PetTest"
	bf.OnInvoke = function(op, ...)
		if op == "Count" then return petCount() end
		if op == "Decor" then return decorCount() end
		if op == "Growth" then return IslandAccess.GrowthMultiplier() end
		if op == "Exp" then return IslandAccess.FarmExpMultiplier() end
		if op == "Pat" then pat(...) return true end
		if op == "Carry" then toggleCarry(...) return true end
		if op == "CarriedBy" then
			local model = ...
			local e = Live[model]
			return e and e.carriedBy or nil
		end
		if op == "Pats" then return patsOf(...) end
		if op == "SetPats" then
			local model, n = ...
			local saved = entryOf(model)
			if saved then saved.pats = n end
			model:SetAttribute("Pats", n)
			local state = Live[model]
			if state then applySize(model, state, false) end
			return model:GetScale()
		end
		if op == "ResetPat" then
			local model = ...
			local saved = entryOf(model)
			if saved then saved.pat = 0 end
			model:SetAttribute("PatAt", 0)
			return true
		end
		if op == "Scale" then
			local model = ...
			local state = Live[model]
			return model:GetScale(), state and state.fullScale
		end
		error("PetTest: ไม่มี op " .. tostring(op))
	end
	bf.Parent = game:GetService("ServerStorage")
end
