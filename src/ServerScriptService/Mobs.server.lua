-- Mobs.server.lua: the monsters that wander the world, chase people, and drop things when killed.
--
-- Spawners are found by TAG, like gathering nodes: anything tagged WOLD_Spawner with a MobKind attribute
-- keeps that many monsters alive within a radius, respawning them as they die. The user places spawners
-- (or a mapgen phase scatters them) and this file never needs to know where they are.
--
-- Monsters are built from parts here rather than loaded from a model, for the same reason WeaponPrefabs
-- builds weapons in code: a model that lives only in the place file is one accident away from being gone
-- with no way to rebuild it. When the user's own slime model arrives it can replace buildSlime alone.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")
local ServerConfig = require(game.ServerScriptService.ServerConfig)

if ServerConfig.IsLobby then return end

local GatherConfig = require(game.ReplicatedStorage.GatherConfig)
local ItemCatalog = require(game.ReplicatedStorage.ItemCatalog)
local Inventory = require(game.ServerScriptService.Inventory)
local Progression = require(game.ServerScriptService.Progression)
local Vitals = require(game.ServerScriptService.Vitals)
local MobAccess = require(game.ServerScriptService.MobAccess)
local EventState = require(game.ServerScriptService.EventState)
local MobMotion = require(game.ServerScriptService.MobMotion)
local Collection = require(game.ServerScriptService.Collection)
local QuestAccess = require(game.ServerScriptService.QuestAccess)

-- Filled in further down, once eventSpawners is in scope. Declared here because damage() is defined above
-- that point and has to be able to see the name.
local Mobs = {}
local Remotes = require(game.ReplicatedStorage.Remotes)
local BeastGait = require(game.ServerScriptService.BeastGait)

local SPAWNER_TAG = "WOLD_Spawner"
local MOB_TAG = "WOLD_Mob"

-- บอสประจำสปอว์เนอร์ ตัวใหญ่ 3 เท่า พลัง (เลือด/ดาเมจ) 5 เท่า ตามที่ผู้ใช้กำหนด
local SPAWNER_BOSS_SCALE = 3
local SPAWNER_BOSS_POWER = 5

-- [model] = { config, hp, spawner, home, nextAttackAt, target }
local Live = {}

local folder = Instance.new("Folder")
folder.Name = "WOLD_Mobs"
folder.Parent = workspace

--------------------------------------------------------------------------------
-- Building one
--------------------------------------------------------------------------------

-- A blob with eyes: two spheres and a wobble. Deliberately simple -- it is a placeholder for the user's
-- own model, and a complicated one would only be harder to throw away.
local function buildSlime(config)
	local model = Instance.new("Model")
	model.Name = "GreenSlime"

	local body = Instance.new("Part")
	body.Name = "Body"
	body.Shape = Enum.PartType.Ball
	body.Size = Vector3.new(3.4, 3.0, 3.4)
	body.Color = config.colour
	body.Material = Enum.Material.SmoothPlastic
	body.Transparency = 0.25
	body.TopSurface = Enum.SurfaceType.Smooth
	body.BottomSurface = Enum.SurfaceType.Smooth
	body.Parent = model
	model.PrimaryPart = body

	for _, side in ipairs({ -0.7, 0.7 }) do
		local eye = Instance.new("Part")
		eye.Name = "Eye"
		eye.Shape = Enum.PartType.Ball
		eye.Size = Vector3.new(0.5, 0.5, 0.5)
		eye.Color = Color3.fromRGB(20, 24, 28)
		eye.Material = Enum.Material.SmoothPlastic
		eye.CanCollide = false
		eye.Massless = true
		eye.CFrame = body.CFrame * CFrame.new(side, 0.5, -1.35)
		eye.Parent = model
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = body
		weld.Part1 = eye
		weld.Parent = body
	end

	-- A Humanoid so it can walk with MoveTo and be steered like anything else. HP is tracked in Live
	-- rather than on the Humanoid so nothing outside this file can quietly kill one.
	local humanoid = Instance.new("Humanoid")
	humanoid.MaxHealth = config.hp
	humanoid.Health = config.hp
	humanoid.WalkSpeed = config.walkSpeed
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.Parent = model

	-- Roblox wants a HumanoidRootPart to drive a Humanoid; the body doubles as one.
	body.Name = "HumanoidRootPart"

	local health = Instance.new("BillboardGui")
	health.Name = "Health"
	health.Size = UDim2.fromOffset(70, 8)
	health.StudsOffsetWorldSpace = Vector3.new(0, 2.6, 0)
	health.MaxDistance = 60
	health.Parent = body
	local back = Instance.new("Frame")
	back.Size = UDim2.fromScale(1, 1)
	back.BackgroundColor3 = Color3.fromRGB(28, 30, 36)
	back.BorderSizePixel = 0
	back.Parent = health
	local bar = Instance.new("Frame")
	bar.Name = "Bar"
	bar.Size = UDim2.fromScale(1, 1)
	bar.BackgroundColor3 = Color3.fromRGB(212, 84, 74)
	bar.BorderSizePixel = 0
	bar.Parent = back

	CollectionService:AddTag(model, MOB_TAG)
	return model
end

--------------------------------------------------------------------------------
-- Building one from the user's own model
--------------------------------------------------------------------------------

-- Where the hand-placed monster models live. The user arranged one of each in this folder; they are the
-- PROTOTYPES, not monsters -- each is cloned to make the real thing, and the original never moves or fights.
-- Every folder a monster prototype might live in, searched in order. V2 arrived as a second folder rather
-- than more models in the first, so the lookup takes a list: a third batch is one more string here.
-- New_moster: ชุดค้างคาว/หมูป่า/หมาป่า/วิญญาณ ผู้ใช้ย้ายโฟลเดอร์ทั้งก้อนเข้า ServerStorage แล้ว (2026-09-18)
-- ก่อนหน้านั้นมันอยู่ใน workspace และถูกหาเจอด้วย fallback — พอย้ายแล้วหาไม่เจอ มอนสี่ชนิดกลายเป็นสไลม์
local PROTOTYPE_FOLDERS = { "Model_moster", "Model_mosterV2", "New_moster" }

local function prototypeFor(config)
    if not config.model then return nil end

    -- ServerStorage FIRST. V1 moved the prototype folder out of the world: those display models carried the
    -- kit's own [E] prompts and name tags, so a player walking up to the spot where a rare slime spawns found
    -- a second, fake slime standing there offering a button that did nothing. They are still needed -- every
    -- monster is a clone of one -- so they moved rather than being deleted, and this looks in the new home
    -- first and the old one after, which means a place that has not run the phase yet still works.
    local serverStorage = game:GetService("ServerStorage")
    local root = workspace:FindFirstChild("WOLD")
    local found
    for _, folderName in ipairs(PROTOTYPE_FOLDERS) do
        local stored = serverStorage:FindFirstChild(folderName)
        found = stored and stored:FindFirstChild(config.model)
        if found then return found end
    end

    for _, folderName in ipairs(PROTOTYPE_FOLDERS) do
        local folderInstance = root and root:FindFirstChild(folderName, true)
        found = folderInstance and folderInstance:FindFirstChild(config.model)
        if found then break end
    end
    -- Searched by name across the whole world as a fallback, because the user is free to move the folder.
    if not found and root then found = root:FindFirstChild(config.model, true) end
    -- ...and across the whole Workspace, not just under WOLD.
    --
    -- โมเดลชุดใหม่ (Monster_Bat/Boar/Wolf/Wraith และสัตว์) ถูกวางไว้ใน `workspace.New_moster` ซึ่งอยู่
    -- นอก WOLD การค้นเฉพาะใต้ WOLD จึงหาไม่เจอและมอนไม่เกิดเลยโดยไม่มี error — เงียบสนิท
    --
    -- **ห้ามใช้ตัวที่ยังอยู่ใน Workspace เป็นต้นแบบโดยไม่ระวัง**: มันเป็นตัวที่ผู้เล่นเดินไปเจอได้จริง
    -- ถ้าถูกโคลนต่อไปเรื่อยๆ ก็ไม่เป็นไร แต่ตัวต้นแบบเองต้องไม่ถูกแท็กเป็นมอนที่ตีได้
    if not found then found = workspace:FindFirstChild(config.model, true) end
    -- และทั่ว ServerStorage ไม่ว่าจะโฟลเดอร์ชื่ออะไร — ผู้ใช้ย้ายโฟลเดอร์ต้นแบบได้ตามใจ
    if not found then found = serverStorage:FindFirstChild(config.model, true) end
    return found
end

-- A monster built by CLONING what the user modelled, rather than the placeholder ball.
--
-- Returns nil if the prototype is missing or unusable, and the caller falls back to buildSlime -- a missing
-- model should cost you the artwork, not the monster.
-- The R15 skeleton, as parent -> child pairs with the joint name Roblox expects between them.
--
-- The user's monsters are modelled as real R15 rigs -- all sixteen parts, correctly named and correctly
-- placed, RigType already R15 -- but held together with WeldConstraints. A weld is rigid: an animation can
-- ask a limb to move and nothing happens, which is why these monsters slid along the ground with their legs
-- locked straight. Motor6D is the joint an Animator can actually drive.
local R15_JOINTS = {
    { "LowerTorso", "HumanoidRootPart", "Root" },
    { "UpperTorso", "LowerTorso", "Waist" },
    { "Head", "UpperTorso", "Neck" },
    { "LeftUpperArm", "UpperTorso", "LeftShoulder" },
    { "LeftLowerArm", "LeftUpperArm", "LeftElbow" },
    { "LeftHand", "LeftLowerArm", "LeftWrist" },
    { "RightUpperArm", "UpperTorso", "RightShoulder" },
    { "RightLowerArm", "RightUpperArm", "RightElbow" },
    { "RightHand", "RightLowerArm", "RightWrist" },
    { "LeftUpperLeg", "LowerTorso", "LeftHip" },
    { "LeftLowerLeg", "LeftUpperLeg", "LeftKnee" },
    { "LeftFoot", "LeftLowerLeg", "LeftAnkle" },
    { "RightUpperLeg", "LowerTorso", "RightHip" },
    { "RightLowerLeg", "RightUpperLeg", "RightKnee" },
    { "RightFoot", "RightLowerLeg", "RightAnkle" },
}

-- Turns a welded R15 body into a jointed one, so Roblox's own walk, run and idle animations drive it.
--
-- Returns the set of parts that are now driven by a joint. The caller must NOT weld those to the root
-- afterwards: a part with both a Motor6D and a weld to the root is pinned by the weld and the animation
-- moves nothing, which is the same dead limb by a different route.
--
-- Does nothing to a model that is not an R15 rig -- the spiders already ship 29 Motor6Ds of their own, and
-- the slimes have no skeleton to find.
local function rigR15(model)
    local jointed = {}
    local humanoid = model:FindFirstChildOfClass("Humanoid")
    if not humanoid then return jointed end

    -- By name, but it MUST be a BasePart. Some of these models wrap a limb in a Model of the same name, and
    -- FindFirstChild would hand back the wrapper -- which Motor6D rejects outright ("Expected BasePart got
    -- Model"), taking the whole monster down with it.
    local function partNamed(name)
        for _, d in ipairs(model:GetDescendants()) do
            if d:IsA("BasePart") and d.Name == name then return d end
        end
        return nil
    end

    -- Resolved once, up front: every R15 part has to be there, and a partial rig animates half a body, which
    -- looks worse than a still one.
    local found = {}
    for _, joint in ipairs(R15_JOINTS) do
        found[joint[1]] = found[joint[1]] or partNamed(joint[1])
        found[joint[2]] = found[joint[2]] or partNamed(joint[2])
        if not found[joint[1]] or not found[joint[2]] then
            return jointed
        end
    end

    for _, joint in ipairs(R15_JOINTS) do
        local part, parent, name = found[joint[1]], found[joint[2]], joint[3]
        if part:FindFirstChildWhichIsA("Motor6D") then
            jointed[part] = true
        else
            -- The welds holding this part rigid have to go, wherever they were parented.
            for _, d in ipairs(model:GetDescendants()) do
                if (d:IsA("WeldConstraint") or d:IsA("Weld")) and (d.Part1 == part or d.Part0 == part) then
                    d:Destroy()
                end
            end
            -- C0/C1 from where the parts already are, so the rig keeps the pose the artist built rather than
            -- snapping to Roblox's default proportions.
            local motor = Instance.new("Motor6D")
            motor.Name = name
            motor.Part0 = parent
            motor.Part1 = part
            motor.C0 = parent.CFrame:ToObjectSpace(part.CFrame)
            motor.C1 = CFrame.new()
            motor.Parent = parent
            jointed[part] = true
        end
    end

    humanoid.RigType = Enum.HumanoidRigType.R15
    return jointed
end

-- Animations for a rigged monster. Reusing what already exists rather than authoring new sequences:
-- Roblox's stock R15 walk is a walk, and the game's own sword slash is a swing, and a monster that walks and
-- swings is the whole of what the user asked for.
--
-- `walk` is looped and played whenever it is moving; `attack` is one-shot and fired from the AI loop at the
-- moment the blow lands, so the animation and the damage are the same event.
--------------------------------------------------------------------------------
-- โผล่จากพื้น · หลบ · เลขดาเมจ
--------------------------------------------------------------------------------

-- ระยะเวลาที่มอนใช้ดันตัวขึ้นจากใต้ดิน ระหว่างนี้มันไม่เดิน ไม่ตี และ **ตีไม่เข้า**
local EMERGE_SECONDS = 1.6
-- ฝังลึกแค่ไหนก่อนโผล่ **คิดจากความสูงของตัวมอน ไม่ใช่ค่าตายตัว**
--
-- ค่าตายตัวใช้ไม่ได้: แมงมุมสูง 10.8 studs ถ้าฝังลงไปแค่ 7 ยอดตัวจะยังโผล่พ้นดินอยู่ 4.8 studs
-- กลายเป็นแมงมุมลอยอยู่เหนือพื้นแทนที่จะฝังอยู่ — วัดแล้วก่อนเขียน
--
-- ความสูงเต็มตัว + 2 = จมทั้งตัวพอดีและเหลือระยะเผื่ออีกนิด
local function emergeDepthFor(height)
	return height + 2
end

-- การหลบ: สุ่มตอนโดนตี ถ้าติดก็กระโดดถอยแล้วอมตะชั่วครู่
--
-- **ค่าพวกนี้อยู่ที่นี่ ไม่ได้อยู่ใน GatherConfig** เพราะเป็นพฤติกรรมร่วมของมอนทุกตัว ส่วนตัวเลขที่ต่างกัน
-- รายชนิด (โอกาสหลบ) อ่านจาก config ของมันเอง — ดู dodgeChance ข้างล่าง
local DODGE_BACK_STUDS = 6.5    -- ถอยไกลแค่ไหน (prompt ขอ 5-8)
local DODGE_INVULN = 0.35       -- อมตะกี่วินาทีหลังหลบ
local DODGE_FREEZE = 0.45       -- ยืนนิ่งกี่วินาทีก่อนกลับไปสู้ (prompt ขอ 0.3-0.6)
local DODGE_COOLDOWN = 2.5      -- กันหลบรัวจนตีไม่โดนเลย

local MOB_WALK = "rbxassetid://913402848"   -- Roblox stock R15 walk
local MOB_ATTACK = "rbxassetid://138133285610075" -- Sword_Slash, the game's own

-- Loads the two tracks onto a rigged monster. Returns nil for anything with no Animator to hang them on.
local function loadMobTracks(model, config)
    local humanoid = model:FindFirstChildOfClass("Humanoid")
    if not humanoid then return nil end
    local animator = humanoid:FindFirstChildOfClass("Animator")
    if not animator then
        animator = Instance.new("Animator")
        animator.Parent = humanoid
    end

    local function load(id, looped, priority)
        if not id or id == "" then return nil end
        local anim = Instance.new("Animation")
        anim.AnimationId = id
        local ok, track = pcall(function() return animator:LoadAnimation(anim) end)
        if not ok then return nil end
        track.Looped = looped
        track.Priority = priority
        return track
    end

    -- **ขาหลายขาขยับเอง ไม่ใช้อนิเมชันเดิน**
    --
    -- MOB_WALK คืออนิเมชันเดิน R15 มาตรฐานของ Roblox ซึ่งขยับข้อต่อชื่อ LeftUpperLeg/RightUpperLeg
    -- แมงมุมไม่มีข้อต่อชื่อนั้น (มันมี HipL1-4 / HipR1-4 / KneeL1-4 / KneeR1-4) อนิเมชันจึงเล่นแล้ว
    -- **ไม่โดนอะไรเลย** แมงมุมเลยไถลไปตามพื้นโดยขาไม่ขยับ ซึ่งเป็นอาการที่ผู้ใช้เห็น
    --
    -- MobMotion.Attach คืน true ถ้ามันรู้จักขาของโมเดลนี้และรับไปขยับเอง กรณีนั้นไม่ต้องโหลด walk
    local proceduralLegs = MobMotion.Attach(model)

    return {
        walk = (not proceduralLegs)
            and load(config.walkAnimation or MOB_WALK, true, Enum.AnimationPriority.Movement) or nil,
        attack = load(config.attackAnimation or MOB_ATTACK, false, Enum.AnimationPriority.Action),
    }
end

local function buildFromModel(config)
    local prototype = prototypeFor(config)
    if not prototype or not prototype:IsA("Model") then return nil end

    local model = prototype:Clone()
    model.Name = config.model

    -- A monster has to be driveable, and a display model is not. It needs a part the Humanoid can steer
    -- from, and that part has to be called HumanoidRootPart -- the kit names its pivot handle "Root", which
    -- Roblox does not recognise.
    local rootPart = model:FindFirstChild("HumanoidRootPart")
    if not rootPart then
        local candidate = model.PrimaryPart or model:FindFirstChild("Root")
            or model:FindFirstChildWhichIsA("BasePart", true)
        if not candidate then model:Destroy(); return nil end
        candidate.Name = "HumanoidRootPart"
        rootPart = candidate
    end
    model.PrimaryPart = rootPart

    -- The kit's pivot handle is a transparent 1x1 marker that does not collide, which is exactly wrong for
    -- the part a Humanoid stands on: without collision it sinks through the floor.
    rootPart.Transparency = 1
    rootPart.CanCollide = true
    rootPart.Anchored = false

    -- ...and a 1x1 cube is still wrong even once it collides, in two ways that look like different bugs.
    --
    -- A Humanoid holds its HumanoidRootPart HipHeight studs off the floor and balances the whole assembly on
    -- that one colliding part. The kit's handle sits half a stud from the BOTTOM of the model, so with a
    -- default HipHeight the body hangs in the air (measured: root 0.50 above the model's underside, on a
    -- body 4.7-6.2 tall), and a 5-stud slime balanced on a 1-stud peg tips and re-corrects every frame --
    -- which reads as constant shaking.
    --
    -- So the root is grown to the body's own footprint and told exactly how high to stand. The spider's
    -- model already ships a real 3.5x2.2x4.0 root and its own HipHeight, and is left alone.
    -- Only a MARKER gets replaced. A model that ships a real root -- the spider's is 3.5x2.2x4.0 with its
    -- own HipHeight -- is left exactly as its author built it. Measured against a fixed size rather than a
    -- fraction of the body, because the spider's own root is small next to its 19-stud leg span and a
    -- proportional test throws it away too.
    local modelCF, modelSize = model:GetBoundingBox()
    local isMarker = rootPart.Size.X <= 1.5 and rootPart.Size.Y <= 1.5 and rootPart.Size.Z <= 1.5
    if isMarker then
        -- Footprint of the body, and short: a tall root would make the monster stand on its own chin.
        rootPart.Size = Vector3.new(modelSize.X * 0.8, math.max(1, modelSize.Y * 0.5), modelSize.Z * 0.8)
        -- Re-centre it in the body. Welds are made below, after this, so nothing is dragged out of place.
        rootPart.CFrame = CFrame.new(modelCF.Position)
        -- The Humanoid holds the root's CENTRE this far off the floor. The body is centred on the root, so
        -- to rest the body's underside on the ground the centre has to sit half the BODY's height up --
        -- half the ROOT's height leaves it buried (measured: the body's underside ended up 1.2-1.6 studs
        -- below the floor). A little extra keeps it from scraping on uneven terrain.
        rootPart:SetAttribute("WOLD_HipHeight", modelSize.Y * 0.5 + 0.2)
    end

    -- Joint the skeleton FIRST, so the welding below knows which limbs must be left free to move.
    local jointed = rigR15(model)

    -- ชิ้นที่มีข้อต่อของตัวเองอยู่แล้ว เก็บเป็นตารางรอบเดียวก่อนลูป
    --
    -- ถามทั้ง Part0 และ Part1 เพราะแมงมุมเก็บข้อต่อเข่าไว้ที่ชิ้นบนของขา ไม่ใช่ที่ชิ้นล่าง
    local ownJointed = {}
    for _, j in ipairs(model:GetDescendants()) do
        if j:IsA("Motor6D") then
            if j.Part0 then ownJointed[j.Part0] = true end
            if j.Part1 then ownJointed[j.Part1] = true end
        end
    end

    -- Everything else rides along rather than fighting the physics: an anchored limb would pin the monster
    -- in place, and a colliding one would trip it over its own body.
    for _, d in ipairs(model:GetDescendants()) do
        if d:IsA("BasePart") and d ~= rootPart then
            d.Anchored = false
            d.CanCollide = false
            d.Massless = true
            -- A limb the rig drives must NOT also be welded to the root: the weld wins and the animation
            -- moves nothing. Decoration -- hair, a bandana, a sword -- still welds, because nothing animates
            -- it and loose parts would be left behind as the monster walks.
            -- **ชิ้นที่มีข้อต่อของตัวเองอยู่แล้วก็ห้ามเชื่อมเหมือนกัน**
            --
            -- `jointed` มีเฉพาะชิ้นที่ rigR15 เพิ่งสร้างข้อต่อให้ ซึ่งเป็นชื่อแบบ R15 เท่านั้น แมงมุมใช้ชื่อ
            -- ของมันเอง (LegL1Upper ฯลฯ) rigR15 จึงคืนตารางเปล่า และขาทั้งแปดถูกเชื่อมติดลำตัว
            -- **เชื่อมแล้วขาขยับไม่ได้เลย** ไม่ว่าจะขยับด้วยอนิเมชันหรือด้วยการเขียน C0 ตรงๆ ก็ตาม
            -- ซึ่งคือเหตุผลจริงที่ขาแมงมุมไม่ขยับ — คอมเมนต์ข้างบนเตือนเรื่องนี้ไว้แล้วแต่เช็คไม่ครบ
            if not jointed[d] and not ownJointed[d] and not d:FindFirstChildWhichIsA("WeldConstraint") then
                local weld = Instance.new("WeldConstraint")
                weld.Part0 = rootPart
                weld.Part1 = d
                weld.Parent = rootPart
            end
        end
        -- A prompt or a name tag belongs to the display model, not to something you are meant to fight.
        if d:IsA("ProximityPrompt") or (d:IsA("BillboardGui") and d.Name == "NameTag") then
            d:Destroy()
        end
    end

    local humanoid = model:FindFirstChildOfClass("Humanoid")
    if not humanoid then
        humanoid = Instance.new("Humanoid")
        humanoid.Parent = model
    end
    humanoid.MaxHealth = config.hp
    humanoid.Health = config.hp
    humanoid.WalkSpeed = config.walkSpeed
    humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
    -- Stand it at the height the root above was sized for.
    --
    -- **โมเดลที่มาพร้อม root ของตัวเองก็ต้องวัดให้ใหม่เหมือนกัน** ของเดิมปล่อยให้ใช้ HipHeight ที่ติดมา
    -- ซึ่งถูกเฉพาะตอนที่คนทำโมเดลตั้งมาถูก — ค้างคาวกับวิญญาณตั้งมาไม่ตรงกับรูปร่างจริง (วิญญาณเป็นผี
    -- ลอยไม่มีขาแต่ HipHeight = 2.0 ขณะที่ root อยู่สูงจากก้นตัว 4.95) ผลคือเอนจิ้นยกมันขึ้นไม่พอ
    -- แล้วครึ่งล่างจมดิน ซึ่งเป็นอาการที่ผู้ใช้เจอกับสองตัวนี้
    --
    -- ระยะที่ถูกคือ "root อยู่สูงจากก้นตัวเท่าไหร่" เพราะ HipHeight คือระยะจากพื้นถึงจุดกึ่งกลาง root
    -- วัดจากโมเดลจริงจึงถูกเสมอ ไม่ว่าใครจะตั้งอะไรมา
    --
    -- **ปิด AutomaticScalingEnabled ก่อน** ไม่งั้นตอนโมเดลถูกวางลงโลก เอนจิ้นจะคำนวณ HipHeight ใหม่จาก
    -- โครงกระดูกเอง — กับโครง R15 ที่เราเชื่อมข้อต่อให้ใหม่ มันคำนวณได้ 0 (วัดแล้ว: โจร/โกเลม/หุ่นไขลาน
    -- ทุกตัว hip=0 สถานะ Freefall ค้าง ตัวจมดินครึ่งตัว) ค่าที่ตั้งไว้ตรงนี้จึงไม่เคยถูกใช้เลย
    humanoid.AutomaticScalingEnabled = false
    local wanted = rootPart:GetAttribute("WOLD_HipHeight")
    if not wanted then
        -- HipHeight ของ R15 คือระยะจาก **ก้น** root ถึงพื้น (ไม่ใช่จุดกึ่งกลาง) และวัดถึงก้นของชิ้นที่มอง
        -- เห็น — ก้อน Root ล่องหน 1x1 ของชุดคิทอยู่ต่ำกว่าเท้าอีกครึ่งสตัด นับมันแล้วตัวจะลอย
        local bottom = math.huge
        for _, d in ipairs(model:GetDescendants()) do
            if d:IsA("BasePart") and d.Transparency < 0.9 then
                bottom = math.min(bottom, d.Position.Y - d.Size.Y * 0.5)
            end
        end
        if bottom == math.huge then
            local bodyCF, bodySize = model:GetBoundingBox()
            bottom = bodyCF.Position.Y - bodySize.Y * 0.5
        end
        -- เผื่อ 0.2 กันขูดพื้นบนภูมิประเทศขรุขระ เหมือนที่ทางสร้าง root เองใช้
        wanted = math.max(0.5, (rootPart.Position.Y - rootPart.Size.Y * 0.5) - bottom + 0.2)
    end
    humanoid.HipHeight = wanted

    -- โครง R15 ที่มีเกราะ/แผ่นครอบ (Plate_<ชิ้น>) ซ่อนชิ้นข้างในไว้ — โกเลมหินใส่แผ่นหินครอบทุกชิ้นแต่หัว
    -- คนข้างในยังโผล่หน้าออกมา ("กระดูกข้างในสำหรับทำให้มอนขยับ" ตามที่ผู้ใช้เรียก) มอนที่ไม่มีแผ่นครอบ
    -- เช่นโจร ตัวโครงคือตัวมันเอง ไม่แตะ
    for _, d in ipairs(model:GetDescendants()) do
        if d:IsA("BasePart") and model:FindFirstChild("Plate_" .. d.Name) then
            d.Transparency = 1
            for _, face in ipairs(d:GetChildren()) do
                if face:IsA("Decal") then face.Transparency = 1 end
            end
        end
    end

    -- The same health bar the placeholder carries, so every monster reads the same way in a fight.
    local health = Instance.new("BillboardGui")
    health.Name = "Health"
    health.Size = UDim2.fromOffset(70, 8)
    local _, size = model:GetBoundingBox()
    health.StudsOffsetWorldSpace = Vector3.new(0, size.Y * 0.6 + 1.5, 0)
    health.MaxDistance = 60
    health.Parent = rootPart
    local back = Instance.new("Frame")
    back.Size = UDim2.fromScale(1, 1)
    back.BackgroundColor3 = Color3.fromRGB(28, 30, 36)
    back.BorderSizePixel = 0
    back.Parent = health
    local bar = Instance.new("Frame")
    bar.Name = "Bar"
    bar.Size = UDim2.fromScale(1, 1)
    bar.BackgroundColor3 = Color3.fromRGB(212, 84, 74)
    bar.BorderSizePixel = 0
    bar.Parent = back

    CollectionService:AddTag(model, MOB_TAG)
    return model
end

-- The monster for a config: the user's model where there is one, the placeholder ball otherwise.
local function buildMonster(config)
    return buildFromModel(config) or buildSlime(config)
end

--------------------------------------------------------------------------------
-- Living and dying
--------------------------------------------------------------------------------

local function setHealthBar(model, fraction)
	local root = model.PrimaryPart
	local gui = root and root:FindFirstChild("Health")
	local back = gui and gui:FindFirstChildWhichIsA("Frame")
	local bar = back and back:FindFirstChild("Bar")
	if bar then bar.Size = UDim2.fromScale(math.clamp(fraction, 0, 1), 1) end
end

-- `loot` carries the two multipliers a boss gets: `amount` doubles how many come out, `chance` doubles the
-- odds a rare roll succeeds. Both default to 1, which is every ordinary monster.
--
-- Doubling the ODDS rather than rolling twice is deliberate: two rolls at 5% is not 10%, and the user asked
-- for the rate to double. A doubled chance is also clamped below, because a 60% drop doubled is not 120%.
-- What a boss may leave behind on top of its own kind's drops. Held here rather than in each monster's
-- config because a boss IS one of those monsters -- it shares their table -- so the extra has to hang off
-- the boss flag, not off the kind.
--
-- `noScale` keeps the boss's own x2 multipliers off this one entry: the doubling exists to make a boss's
-- ORDINARY loot worth the fight, and applying it here would mean 50% odds and two charms per kill. One charm
-- is one death survived, and handing out two at once is a different item.
local BOSS_EXTRA = { item = "GuardianCharm", min = 1, max = 1, chance = 0.25, noScale = true }

local function drop(model, config, killer, loot)
	if not killer or not killer.Parent then return end
	local amountScale = (loot and loot.amount) or 1
	local chanceScale = (loot and loot.chance) or 1

	-- A boss rolls for the charm as well. Built as a copy of the kind's list rather than by writing into it:
	-- `config.drops` is the shared table every monster of that kind reads, and appending to it would give the
	-- charm to the ordinary ones too, permanently.
	local drops = config.drops or {}
	if loot and loot.boss then
		local extended = table.clone(drops)
		table.insert(extended, BOSS_EXTRA)
		drops = extended
	end

	for _, entry in ipairs(drops) do
		-- `chance` is optional: without one a drop is certain, which is what every material drop is. With
		-- one it is rolled per kill, which is what makes a weapon worth hunting for rather than a reward
		-- for showing up.
		local entryChance = entry.noScale and 1 or chanceScale
		local entryAmount = entry.noScale and 1 or amountScale
		local odds = entry.chance and math.min(1, entry.chance * entryChance) or nil
		if not odds or math.random() < odds then
			-- `oneOf` picks a single item from a list, so a rare roll gives ONE weapon rather than all of
			-- them at once. `item` names a specific thing; the two are alternatives.
			local id = entry.item
			if entry.oneOf and #entry.oneOf > 0 then
				id = entry.oneOf[math.random(1, #entry.oneOf)]
			end
			local count = math.random(entry.min or 1, entry.max or 1) * entryAmount
			if Inventory.AddItem(killer, id, count) then
				local item = ItemCatalog.Get(id)
				local name = item and item.name or id
				-- A rare drop says so. ToastController only distinguishes "error" from everything else, so
				-- the difference has to live in the words rather than in the colour.
				Remotes.SocialNotify:FireClient(killer, "info", odds
					and ("หายาก! ได้ %s x%d"):format(name, count)
					or ("ได้ %s x%d"):format(name, count))
			else
				Remotes.SocialNotify:FireClient(killer, "error", "กระเป๋าเต็ม ของหล่นหาย")
			end
		end
	end
	if config.xp and config.xp > 0 then
		Progression.AwardExp(killer, config.xp)
	end
	-- ลงสมุดสะสม บันทึกตามชนิด ไม่ใช่ตามตัว — สมุดตอบว่า "ฆ่าอะไรไปกี่ตัว"
	Collection.RecordMob(killer, config.name or kind)
	-- นับให้เควสล่าด้วย ถ้ามีคนรับงานล่ามอนชนิดนี้ไว้
	if QuestAccess.RecordKill then QuestAccess.RecordKill(killer, config.name or kind) end
end

local function despawn(model)
	local state = Live[model]
	Live[model] = nil
	-- หยุดลูปขยับขา ไม่งั้นมันจะค้างอยู่จนกว่าโมเดลจะถูกลบ ซึ่งช้ากว่าตรงนี้หลายวินาที
	MobMotion.Detach(model)
	-- บอสตาย = ปลดธง ตัวถัดไปที่เกิดจากจุดนี้จะขึ้นเป็นบอสแทน
	if state and state.bossOf then
		state.bossOf:SetAttribute("HasBoss", nil)
	end

	if state and state.spawner then
		local alive = state.spawner:GetAttribute("Alive") or 0
		local left = math.max(0, alive - 1)
		state.spawner:SetAttribute("Alive", left)

		-- ตัวสุดท้ายของสปอว์เนอร์แบบ Trigger ตายแล้ว: ล็อกไว้จนกว่าคนจะเดินออกจากพื้นที่
		--
		-- ตามที่ผู้ใช้ขอ — ถ้าไม่มีด่านนี้ คนที่ยืนเฝ้าจุดเกิดจะได้มอนไม่รู้จบโดยไม่ต้องขยับเลย
		if left == 0 and state.spawner:GetAttribute("TriggerRadius") then
			state.spawner:SetAttribute("AwaitExit", true)
		end
		-- The respawn clock starts HERE, at the death, rather than at the next spawn: "back in thirty
		-- minutes" has to mean thirty minutes after it died, which is the only moment a player can see.
		local seconds = state.config and state.config.respawnSeconds or 0
		if seconds > 0 then
			state.spawner:SetAttribute("ReadyAt", os.clock() + seconds)
		end
	end
	if model.Parent then model:Destroy() end
end

-- Played at the monster, so a fight sounds like it is happening where it is rather than in the attacker's
-- ear. One helper for both the hit and the death, since they differ only in which id and how loud.
local function playAt(model, soundId, volume)
	local root = model.PrimaryPart
	if not root or not soundId then return end
	local sound = Instance.new("Sound")
	sound.SoundId = soundId
	sound.Volume = volume
	sound.RollOffMaxDistance = GatherConfig.MobSoundDistance
	sound.PlaybackSpeed = 1 + (math.random() - 0.5) * 0.1
	sound.Parent = root
	sound:Play()
	Debris:AddItem(sound, 4)
end

-- Public through MobAccess so PlayerCombat can call it without requiring this file.
-- เลขดาเมจลอยขึ้นเหนือหัวแล้วจางไป
--
-- สร้างฝั่งเซิร์ฟเวอร์เพราะมันต้องเห็นกันทุกคน ไม่ใช่เฉพาะคนตี — การรุมบอสควรเห็นเลขของคนอื่นด้วย
-- อายุสั้นและ Debris เก็บให้ จึงไม่ต้องมีใครตามลบ
local function showDamageNumber(model, amount, dodged)
	local root = model.PrimaryPart or model:FindFirstChild("HumanoidRootPart")
	if not root then return end

	local _, size = model:GetBoundingBox()
	local holder = Instance.new("Part")
	holder.Anchored = true
	holder.CanCollide = false
	holder.CanQuery = false
	holder.CanTouch = false
	holder.Transparency = 1
	holder.Size = Vector3.new(0.2, 0.2, 0.2)
	-- สุ่มออกข้างเล็กน้อย เลขหลายตัวจากการรุมจะได้ไม่ทับกันสนิท
	holder.Position = root.Position + Vector3.new(
		math.random(-12, 12) / 10, size.Y * 0.5 + 1, math.random(-12, 12) / 10)
	holder.Parent = workspace

	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(90, 34)
	gui.AlwaysOnTop = true
	gui.MaxDistance = 90
	gui.Parent = holder

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.TextStrokeTransparency = 0.3
	if dodged then
		label.Text = "หลบ!"
		label.TextColor3 = Color3.fromRGB(150, 210, 255)
	else
		label.Text = tostring(math.max(1, math.floor(amount + 0.5)))
		label.TextColor3 = Color3.fromRGB(255, 214, 92)
	end
	label.Parent = gui

	-- ลอยขึ้นและจาง ใช้ TweenService แทนลูปต่อเฟรม: เป็นค่าสองค่าวิ่งทางเดียว เอนจิ้นทำให้ได้อยู่แล้ว
	TweenService:Create(holder, TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Position = holder.Position + Vector3.new(0, 3.2, 0),
	}):Play()
	TweenService:Create(label, TweenInfo.new(0.9), {
		TextTransparency = 1, TextStrokeTransparency = 1,
	}):Play()
	Debris:AddItem(holder, 1)
end

-- พยายามหลบหนึ่งครั้ง คืน true ถ้าหลบสำเร็จ (แปลว่าดาเมจครั้งนี้ไม่เข้า)
--
-- **อ่านโอกาสจาก config รายชนิด** มอนที่ไม่ได้ตั้ง dodgeChance ไว้ก็ไม่หลบเลย ซึ่งทำให้ของเดิมทุกตัว
-- ทำงานเหมือนเดิมเป๊ะจนกว่าจะมีใครไปใส่ค่าให้
local function tryDodge(state, model)
	local chance = state.config.dodgeChance
	if not chance or chance <= 0 then return false end

	local now = os.clock()
	if state.dodgeReadyAt and now < state.dodgeReadyAt then return false end
	-- กำลังโผล่จากพื้นอยู่ หลบไม่ได้ (และตีไม่เข้าอยู่แล้ว)
	if state.emergingUntil and now < state.emergingUntil then return false end
	if math.random() > chance then return false end

	local root = model.PrimaryPart
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid then return false end

	state.dodgeReadyAt = now + DODGE_COOLDOWN
	state.invulnUntil = now + DODGE_INVULN
	-- ยืนนิ่งหลังหลบ ใช้ตัวเดียวกับที่ระบบมึนใช้ ลูป AI จึงหยุดให้เองโดยไม่ต้องเพิ่มด่านใหม่
	state.stunnedUntil = now + DODGE_FREEZE

	-- ถอยไปทางตรงข้ามกับคนตี ถ้าไม่รู้ว่าใครตีก็ถอยหลังตัวเอง
	local away = -root.CFrame.LookVector
	local target = state.target
	local targetRoot = target and target.Character and target.Character:FindFirstChild("HumanoidRootPart")
	if targetRoot then
		local delta = (root.Position - targetRoot.Position) * Vector3.new(1, 0, 1)
		if delta.Magnitude > 0.1 then away = delta.Unit end
	end

	-- กระโดดถอย: ดันด้วยความเร็ว ไม่ใช่ย้ายตำแหน่ง — การย้ายตำแหน่งทะลุกำแพงได้ ส่วนแรงไม่ทะลุ
	root.AssemblyLinearVelocity = away * (DODGE_BACK_STUDS * 2.2) + Vector3.new(0, 18, 0)
	return true
end

local function damage(model, amount, attacker)
	local state = Live[model]
	if not state then return false end

	local now = os.clock()

	-- กำลังโผล่ขึ้นจากพื้น: ตียังไม่เข้า ตามที่ prompt กำหนด ("ยังไม่รับ Damage")
	if state.emergingUntil and now < state.emergingUntil then return false end

	-- ช่วงอมตะสั้นๆ หลังหลบสำเร็จ
	if state.invulnUntil and now < state.invulnUntil then return false end

	-- ลองหลบก่อนคิดดาเมจ ถ้าหลบติด เลือดไม่ลดเลย
	if attacker and attacker.Character then state.target = attacker end
	if tryDodge(state, model) then
		showDamageNumber(model, 0, true)
		return false
	end

	state.hp -= amount
	showDamageNumber(model, amount, false)
	playAt(model, state.config.hitSound, GatherConfig.MobHitVolume)

	-- สะดุ้งและเด้งถอย ไม่ให้ยืนนิ่งเป็นเป้า
	--
	-- น้ำหนักอ่านจากตัวคูณตอนกลางคืน/บอส บอสที่ถูกคูณตัวใหญ่จึงสะเทือนน้อยกว่าสไลม์ธรรมดา
	local attackerRoot = attacker and attacker.Character
		and attacker.Character:FindFirstChild("HumanoidRootPart")
	MobMotion.Flinch(model, attackerRoot and attackerRoot.Position or nil, amount,
		state.damageScale or 1)
	setHealthBar(model, state.hp / (state.maxHp or state.config.hp))
	-- Being hit makes it care about whoever hit it, even from outside its notice range: a monster that
	-- ignored an archer shooting it from a hill would look broken.
	if attacker and attacker.Character then
		state.target = attacker
	end

	if state.hp <= 0 then
		-- The death sound has to outlive the model, so it plays from a bare part left behind rather than
		-- from the monster that is about to be destroyed underneath it.
		local root = model.PrimaryPart
		if root and state.config.dieSound then
			local marker = Instance.new("Part")
			marker.Anchored = true
			marker.CanCollide = false
			marker.CanQuery = false
			marker.Transparency = 1
			marker.Size = Vector3.new(1, 1, 1)
			marker.Position = root.Position
			marker.Parent = workspace
			local sound = Instance.new("Sound")
			sound.SoundId = state.config.dieSound
			sound.Volume = GatherConfig.MobDieVolume
			sound.RollOffMaxDistance = GatherConfig.MobSoundDistance
			sound.Parent = marker
			sound:Play()
			Debris:AddItem(marker, 5)
		end
		drop(model, state.config, attacker, state.loot)
		local spawner = state.spawner
		despawn(model)
		-- Told AFTER despawn, so whoever is counting sees the world as it is now rather than one monster
		-- ahead of itself. Set further down, once eventSpawners exists.
		if spawner and Mobs.OnEventMobKilled then
			task.defer(Mobs.OnEventMobKilled, spawner)
		end
	end
	return true
end

MobAccess.Damage = damage

-- Held still by the greatsword. Stored as a deadline rather than a timer so overlapping hits simply extend
-- it, and so the AI loop -- which already runs four times a second -- is the only thing that has to know
-- about it. A stunned monster stops where it is: it does not walk, chase or swing.
local function stun(model, seconds)
	local state = Live[model]
	if not state or not seconds or seconds <= 0 then return false end
	local until_ = os.clock() + seconds
	if not state.stunnedUntil or until_ > state.stunnedUntil then
		state.stunnedUntil = until_
	end
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local root = model.PrimaryPart
	-- Stop the walk it is already in the middle of; MoveTo keeps steering on its own otherwise.
	if humanoid and root then humanoid:MoveTo(root.Position) end
	return true
end

MobAccess.Stun = stun

--------------------------------------------------------------------------------
-- Spawning
--------------------------------------------------------------------------------

-- พื้นแห้งตรงจุดนั้น หรือ nil ถ้าเป็นน้ำ/ไม่มีพื้น
--
-- **ไม่เกิดในน้ำ** (ผู้ใช้กำหนด) ราย์ชนผิวน้ำก็ตอบมาเหมือนพื้น จึงต้องดูวัสดุ · **กัน Zone_* ออก**
-- กล่องโซนหมู่บ้านลอยอยู่เหนือพื้นราวร้อยสตัดและตอบราย์ด้วย มอนที่เกิดบนนั้นจะร่วงลงมา
-- หรือค้างกลางอากาศ — บทเรียนเดียวกับฝูงสัตว์และบอร์ดเควส
--
-- **ยิงจากเหนือสปอว์เนอร์ ไม่ใช่จาก y=500 ตายตัว** ยอดเขาแอสตราเวลอยู่ที่ y≈1200 ราย์ที่เริ่มจาก 500 จึง
-- เริ่มอยู่ในเนื้อหินและไม่ชนอะไรเลย — วิญญาณบนนั้นไม่เคยเกิดสักตัวโดยไม่มี error
local function groundAt(x, z, fromY)
	local ignore = { folder }
	local top = (fromY or 300) + 200
	for _ = 1, 8 do
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = ignore
		params.IgnoreWater = false
		local hit = workspace:Raycast(Vector3.new(x, top, z), Vector3.new(0, -(top + 700), 0), params)
		if not hit then return nil end
		if hit.Material == Enum.Material.Water then return nil end
		if not hit.Instance.Name:match("^Zone_") then return hit.Position.Y end
		ignore[#ignore + 1] = hit.Instance
	end
	return nil
end

-- มีน้ำอยู่ตรงจุดนี้ไหม (มองลงจากเหนือหัว) ใช้เช็คก้าวถัดไปก่อนเดิน
local function waterAt(position)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { folder }
	params.IgnoreWater = false
	local hit = workspace:Raycast(position + Vector3.new(0, 6, 0), Vector3.new(0, -30, 0), params)
	return hit ~= nil and hit.Material == Enum.Material.Water
end

-- ต่ำกว่านี้คือหลุดโลก (ก้นทะเลลึกอยู่ที่ -80) ส่งกลับบ้าน
local WORLD_FLOOR_Y = -150

-- After dark everything in the world hits twice as hard and takes twice as much killing.
--
-- Stamped onto each monster when it SPAWNS rather than read live, for two reasons: a monster must not
-- double its health bar halfway through a fight because the sun went down, and `config` is the shared table
-- every monster of that kind points at -- scaling it in place would buff the species, permanently, every
-- time night fell.
local NIGHT_MULTIPLIER = 2

local function nightScale()
	return workspace:GetAttribute("WOLD_IsNight") and NIGHT_MULTIPLIER or 1
end

-- ดันมอนขึ้นมาจากใต้พื้น พร้อมฝุ่นและเศษดิน
--
-- ตัวมอนถูก **ตรึงไว้** (Anchored) ตลอดช่วงที่ขึ้น เพราะถ้าปล่อยให้ฟิสิกส์ทำงาน มันจะถูกพื้นดันออกด้วย
-- แรงมหาศาลแล้วกระเด็นไปไกล ซึ่งเป็นอาการเดียวกับที่เคยเจอตอนวางมอนจมดิน (ดูคอมเมนต์เรื่อง "มอนไหล")
local function startEmerge(model, state, restY)
	if not state then return end
	local root = model.PrimaryPart
	if not root then return end

	local now = os.clock()
	state.emergingUntil = now + EMERGE_SECONDS
	-- ลูป AI ใช้ตัวนี้หยุดมันอยู่แล้ว จึงไม่ต้องเพิ่มด่านใหม่ในลูป
	state.stunnedUntil = now + EMERGE_SECONDS

	-- ตรึงทุกชิ้นไว้ และ **ปิดการชนด้วย** ระหว่างที่ยังอยู่ในดิน
	--
	-- ตรึงไว้อย่างเดียวไม่พอ: ตัวมอนจมอยู่ในพื้นจริงๆ ถ้ายังชนได้ ผู้เล่นที่เดินผ่านจะชนก้อนอะไรไม่รู้
	-- ที่มองไม่เห็นใต้ดิน และกระสุน/การฟันก็จะไปโดนมันทั้งที่ยังโผล่ไม่ขึ้นมา
	--
	-- จำค่าเดิมไว้คืนทีละชิ้น ไม่ได้เปิดคืนหมดทุกชิ้น — buildFromModel ตั้งใจให้แขนขาเป็น CanCollide=false
	-- อยู่แล้ว (ไม่งั้นมอนสะดุดขาตัวเอง) การเปิดคืนหมดจะทำลายค่านั้น
	local wasCollide = {}
	for _, part in ipairs(model:GetDescendants()) do
		if part:IsA("BasePart") then
			wasCollide[part] = part.CanCollide
			part.Anchored = true
			part.CanCollide = false
		end
	end

	-- ฝุ่นที่ปากหลุม อยู่กับที่ ไม่ได้ขึ้นตามตัวมอน
	local _, size = model:GetBoundingBox()
	local dust = Instance.new("Part")
	dust.Anchored = true
	dust.CanCollide = false
	dust.CanQuery = false
	dust.CanTouch = false
	dust.Transparency = 1
	dust.Size = Vector3.new(1, 1, 1)
	dust.Position = Vector3.new(root.Position.X, restY - size.Y * 0.5, root.Position.Z)
	dust.Parent = workspace

	local p = Instance.new("ParticleEmitter")
	p.Texture = "rbxasset://textures/particles/smoke_main.dds"
	p.Color = ColorSequence.new(Color3.fromRGB(122, 98, 74))
	p.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, math.max(2, size.X * 1.2)),
		NumberSequenceKeypoint.new(1, 0),
	})
	p.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.25),
		NumberSequenceKeypoint.new(1, 1),
	})
	p.Lifetime = NumberRange.new(0.6, 1.1)
	p.Speed = NumberRange.new(4, 9)
	p.SpreadAngle = Vector2.new(60, 60)
	p.Acceleration = Vector3.new(0, -12, 0)
	p.Rate = 0
	p.Parent = dust
	p:Emit(40)
	Debris:AddItem(dust, 3)

	-- **ขยับทั้งโมเดลด้วย PivotTo ไม่ใช่ tween ที่ PrimaryPart** ตอนทุกชิ้นถูก Anchored ไว้ การเลื่อน
	-- ชิ้นเดียวจะทิ้งชิ้นที่เหลือไว้ที่เดิม ตัวมอนจะขาดออกจากกันกลางอากาศ
	local startCF = model:GetPivot()
	local goalCF = CFrame.new(startCF.Position.X, restY, startCF.Position.Z) * (startCF - startCF.Position)

	task.spawn(function()
		local t0 = os.clock()
		local bailed = false
		while os.clock() - t0 < EMERGE_SECONDS do
			if not model.Parent or not Live[model] then bailed = true break end
			local a = (os.clock() - t0) / EMERGE_SECONDS
			-- ease-out แบบ cubic: เร็วตอนต้นแล้วค่อยๆ ช้าลงจนหยุดพอดีที่ผิวดิน
			local eased = 1 - (1 - a) ^ 3
			model:PivotTo(startCF:Lerp(goalCF, eased))
			task.wait()
		end
		-- คืนสภาพให้ฟิสิกส์ **ไม่ว่าจะจบด้วยทางไหน**
		--
		-- ประกาศเป็นฟังก์ชันแล้วเรียกทุกทางออก เพราะถ้ามอนถูกฆ่าระหว่างกำลังโผล่ (แอดมินสั่ง หรือระเบิด
		-- โดนโดยไม่ผ่าน damage()) ลูปจะออกก่อนถึงบรรทัดคืนค่า แล้วเหลือซากที่ถูกตรึงไว้ตลอดกาล
		local function release()
			for part, collide in pairs(wasCollide) do
				if part.Parent then
					part.Anchored = false
					part.CanCollide = collide
					part.AssemblyLinearVelocity = Vector3.zero
					part.AssemblyAngularVelocity = Vector3.zero
				end
			end
		end

		if bailed or not model.Parent or not Live[model] then
			release()
			return
		end
		model:PivotTo(goalCF)
		release()
	end)
end

local function spawnOne(spawner, kind, config)
	local radius = spawner:GetAttribute("Radius") or 60
	local origin = spawner:IsA("BasePart") and spawner.Position or spawner:GetPivot().Position

	-- A few attempts at a spot with ground under it, then give up for this tick rather than dropping a
	-- monster into the sea or inside a rock.
	for _ = 1, 8 do
		local angle = math.random() * math.pi * 2
		local distance = math.sqrt(math.random()) * radius -- sqrt keeps them evenly spread, not clumped at the middle
		local x = origin.X + math.cos(angle) * distance
		local z = origin.Z + math.sin(angle) * distance
		local y = groundAt(x, z, origin.Y)
		if y then
			local model = buildMonster(config)

			-- ตัวนี้เป็นบอสประจำจุดไหม
			--
			-- เป็นบอสเมื่อสปอว์เนอร์นี้ยังไม่มีบอสอยู่ — ตัวแรกที่เกิดหลังบอสตายจะรับตำแหน่งแทน (ธงถูกล้าง
			-- ใน despawn) จึงมีบอสหนึ่งตัวเสมอโดยไม่ต้องนับอะไรเพิ่ม
			--
			-- **หนึ่งตัวต่อสปอว์เนอร์ ไม่ใช่สุ่มทุกตัวที่เกิด** ถ้าสุ่มรายตัว ฝูงละ 8 จะมีบอสหลายตัวและ
			-- จำนวนไม่คงที่ทุกรอบ สปอว์เนอร์ที่ไม่ต้องการบอสตั้ง NoBoss ได้
			local isBoss = not spawner:GetAttribute("HasBoss") and not spawner:GetAttribute("NoBoss")
			if isBoss then
				-- ใหญ่ก่อนวัด ไม่งั้นจะยกตัวด้วยขนาดเดิมแล้วเข่าจมดิน
				model:ScaleTo(SPAWNER_BOSS_SCALE)
			end

			-- **ยกขึ้นตามขนาดตัวจริง ไม่ใช่ +2 ตายตัว** — โกเลมกับแมงมุมสูงกว่านั้นมาก การวางที่ +2 ทำให้
			-- ครึ่งล่างของตัวจมอยู่ในพื้น เอนจิ้นก็ดันมันออกมาด้วยแรงมหาศาล ตัวเลยพุ่งไถลไปไกล ซึ่งตรงกับ
			-- อาการที่ผู้ใช้เจอ ("มอนเกิดแล้วบางตัวก็ไหลไปไกลมาก")
			--
			-- ครึ่งความสูง + 1 คือ "ก้นตัวลอยเหนือพื้น 1 สตัด" แล้วปล่อยให้ตกลงมาเองซึ่งไม่มีการดันออก
			local _, mobSize = model:GetBoundingBox()
			local restY = y + mobSize.Y * 0.5 + 1

			-- สปอว์เนอร์ที่ติด Emerge ไว้ จะให้มอนดันตัวขึ้นมาจากใต้ดินแทนที่จะโผล่มาเฉยๆ
			--
			-- **เป็นทางเลือก ไม่ใช่ค่าเริ่มต้น** สปอว์เนอร์เดิมทุกตัวในแมพไม่มีแอตทริบิวต์นี้ จึงทำงานเหมือนเดิมทุกประการ
			local emerge = spawner:GetAttribute("Emerge") == true
			if emerge then
				model:PivotTo(CFrame.new(x, restY - emergeDepthFor(mobSize.Y), z))
			else
				model:PivotTo(CFrame.new(x, restY, z))
			end
			model.Parent = folder
			-- ความเร็วที่ติดมาจากตอนประกอบร่าง/ย้ายตำแหน่ง ต้องล้างทิ้ง ไม่งั้นมันจะพุ่งต่อจากจุดเกิด
			for _, part in ipairs(model:GetDescendants()) do
				if part:IsA("BasePart") then
					part.AssemblyLinearVelocity = Vector3.zero
					part.AssemblyAngularVelocity = Vector3.zero
				end
			end
			-- มอนชุดคิทสัตว์ (หมูป่า หมาป่า ค้างคาว) ขาขยับผ่าน C0 ที่ส่งถึงไคลเอนต์ **หลัง ScaleTo** เพราะ
			-- ท่าเดินจำ C0 ตอนพักไว้ ถ้าจำก่อนขยายบอส ขาจะถูกดึงกลับไปขนาดเดิม
			BeastGait.Attach(model)
			local scale = nightScale() * (isBoss and SPAWNER_BOSS_POWER or 1)
			local maxHp = config.hp * scale
			-- buildMonster already sized the Humanoid from the unscaled config; correct it here so the bar
			-- and the real pool agree.
			local humanoid = model:FindFirstChildOfClass("Humanoid")
			if humanoid and scale ~= 1 then
				humanoid.MaxHealth = maxHp
				humanoid.Health = maxHp
			end
			if isBoss then
				if humanoid then
					humanoid.DisplayName = ("จ่าฝูง%s"):format(config.name or kind)
				end
				spawner:SetAttribute("HasBoss", true)
			end
			Live[model] = {
				config = config,
				hp = maxHp,
				maxHp = maxHp,
				damageScale = scale,
				-- จำว่าตัวนี้คือบอสของสปอว์เนอร์ไหน เพื่อคืนตำแหน่งให้ตัวถัดไปตอนมันตาย
				bossOf = isBoss and spawner or nil,
				-- ดรอปแบบบอส: ออกสองเท่าและโอกาสของหายากสองเท่า เหมือนบอสของ TikTok
				loot = isBoss and { amount = 2, chance = 2, boss = true } or nil,
				-- Walk and swing. nil for a slime or anything else with no rig to drive.
				tracks = loadMobTracks(model, config),
				spawner = spawner,
				home = Vector3.new(x, y, z),
				nextAttackAt = 0,
				target = nil,
			}
			if emerge then
				startEmerge(model, Live[model], restY)
			end

			spawner:SetAttribute("Alive", (spawner:GetAttribute("Alive") or 0) + 1)
			-- How many this spawner has put into the world since the event started. "Alive" alone cannot end
			-- an event: it is zero both before the first one walks out and after the last one dies, and those
			-- two have to be told apart.
			spawner:SetAttribute("Spawned", (spawner:GetAttribute("Spawned") or 0) + 1)
			return true
		end
	end
	return false
end

-- Conjures one monster that exists only to chase `victim`, with no spawner behind it.
--
-- Deliberately NOT spawnOne: that function belongs to a spawner -- it counts against its Alive attribute and
-- sets its respawn clock -- and a monster called up by an admin has neither. When this one dies it is simply
-- gone, which is what despawn already does for a state with no spawner.
local function spawnHunter(kind, config, victim, origin, distance, boss)
	-- Ringed around them rather than dropped on top: a monster spawned inside someone's body shoves them.
	for attempt = 1, 12 do
		local angle = math.random() * math.pi * 2
		-- Widen the ring a little on each retry, so a wall on one side does not mean no monster at all.
		local reach = distance + (attempt - 1) * 4
			local x = origin.X + math.cos(angle) * reach
			local z = origin.Z + math.sin(angle) * reach
		local y = groundAt(x, z, origin.Y)
		if y then
			local model = buildMonster(config)
			-- A boss is the same monster, made bigger and meaner. ScaleTo BEFORE the pivot, and lift it by
			-- the scale as well: a model scaled about its own pivot grows downward too, so a tripled
			-- monster placed at the usual two studs starts with its knees in the ground.
			local size = boss and boss.scale or 1
			if size ~= 1 then model:ScaleTo(size) end
			-- วัดหลัง ScaleTo จึงได้ขนาดจริงของบอส เหมือนทางเกิดปกติ: ยกครึ่งตัว + 1 แล้วปล่อยให้ตกเอง
			-- ดีกว่าเดาว่า 2 คูณสเกลพอ ซึ่งยังจมสำหรับตัวที่สูงอยู่แล้ว
			local _, mobSize = model:GetBoundingBox()
			model:PivotTo(CFrame.new(x, y + mobSize.Y * 0.5 + 1, z))
			model.Parent = folder
			BeastGait.Attach(model)
			for _, part in ipairs(model:GetDescendants()) do
				if part:IsA("BasePart") then
					part.AssemblyLinearVelocity = Vector3.zero
					part.AssemblyAngularVelocity = Vector3.zero
				end
			end

			local scale = nightScale() * (boss and boss.power or 1)
			local maxHp = config.hp * scale
			local humanoid = model:FindFirstChildOfClass("Humanoid")
			if humanoid and scale ~= 1 then
				humanoid.MaxHealth = maxHp
				humanoid.Health = maxHp
			end
			if boss and boss.title and humanoid then
				humanoid.DisplayName = boss.title
				model.Name = boss.modelName or model.Name
			end

			Live[model] = {
				config = config,
				hp = maxHp,
				maxHp = maxHp,
				damageScale = scale,
				-- A boss drops twice as much and rolls its rare drops at twice the odds, per the user. Stamped
				-- at spawn like damageScale, so what a monster is worth is decided when it appears rather than
				-- read off a table that may have changed by the time it dies.
				loot = boss and { amount = 2, chance = 2, boss = true } or nil,
				-- Walk and swing. nil for a slime or anything else with no rig to drive.
				tracks = loadMobTracks(model, config),
				-- No spawner: nothing counts it, and nothing brings it back.
				spawner = nil,
				home = Vector3.new(x, y, z),
				nextAttackAt = 0,
				target = victim,
				-- The whole point of it.
				hunt = victim,
			}
			return model
		end
	end
	return nil
end

-- Published for the admin command. Takes (victim, distance, count) and returns how many actually landed,
-- picking a random kind from EVERY monster in the game -- both batches, since GatherConfig.Mobs holds them
-- all in one table.
MobAccess.SpawnHunters = function(victim, distance, count)
	local character = victim and victim.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then return 0, {} end

	local kinds = {}
	for kind in pairs(GatherConfig.Mobs) do kinds[#kinds + 1] = kind end
	-- Sorted before picking so the choice is reproducible from the seed rather than from hash order.
	table.sort(kinds)
	if #kinds == 0 then return 0, {} end

	local spawned, names = 0, {}
	for _ = 1, math.max(1, count or 1) do
		local kind = kinds[math.random(#kinds)]
		local config = GatherConfig.Mobs[kind]
		if config and spawnHunter(kind, config, victim, root.Position, distance or 15) then
			spawned += 1
			names[#names + 1] = config.name or kind
		end
	end
	return spawned, names
end

-- One hunter, but a named boss: bigger, tougher, and carrying somebody's name over its head.
--
-- Published for the TikTok link, where a subscriber buys one. Kept here rather than done to the model from
-- outside because everything that makes a monster dangerous lives in Live[model] -- hp, maxHp and the
-- damage multiplier -- and that table is private to this file. Reaching in from another script to triple a
-- health bar would leave the damage alone and make the boss a punching bag.
--
-- opts: { scale, power, title, kind }. Returns the model and the kind's display name, or nil.
MobAccess.SpawnBoss = function(victim, distance, opts)
	opts = opts or {}
	local character = victim and victim.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then return nil end

	local kinds = {}
	for kind in pairs(GatherConfig.Mobs) do kinds[#kinds + 1] = kind end
	table.sort(kinds)
	if #kinds == 0 then return nil end

	local kind = opts.kind or kinds[math.random(#kinds)]
	local config = GatherConfig.Mobs[kind]
	if not config then return nil end

	local model = spawnHunter(kind, config, victim, root.Position, distance or 20, {
		scale = math.clamp(tonumber(opts.scale) or 1, 1, 6),
		power = math.clamp(tonumber(opts.power) or 1, 1, 20),
		title = opts.title,
		modelName = opts.modelName,
	})
	if not model then return nil end
	return model, config.name or kind
end

-- มีใครยืนอยู่ในระยะนี้ไหม
--
-- **เขียนเองแทนการใช้ nearestPlayer** เพราะ nearestPlayer ถูกนิยามทีหลัง serviceSpawner ในไฟล์นี้
-- และ local ใน Lua เป็น nil จนกว่าบรรทัดที่ประกาศจะรัน การเรียกจากตรงนี้จะได้ nil เสมอ
-- (กับดักเดียวกับที่ CombatConfig.PlayWeaponHitSound เขียนเตือนไว้ และที่จักรยานเพิ่งเจอมา)
--
-- ต่างจาก nearestPlayer ตรงที่ตอบแค่ว่ามีหรือไม่มี ไม่ต้องหาว่าใครใกล้สุด จึงหยุดทันทีที่เจอคนแรก
local function anyPlayerWithin(origin, radius)
	for _, player in ipairs(Players:GetPlayers()) do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		-- คนที่ล้มอยู่ไม่นับ กฎเดียวกับ nearestPlayer: มอนไม่ควรถูกปลุกโดยคนที่ลุกไม่ขึ้น
		if root and humanoid and humanoid.Health > 0 and not player:GetAttribute("WOLD_Downed") then
			if (root.Position - origin).Magnitude <= radius then return true end
		end
	end
	return false
end

local function serviceSpawner(spawner)
	local kind = spawner:GetAttribute("MobKind")
	local config = kind and GatherConfig.Mobs[kind]
	if not config then
		warn(("[Mobs] %s is tagged %s but MobKind (%s) is unknown")
			:format(spawner:GetFullName(), SPAWNER_TAG, tostring(kind)))
		return
	end

	-- A spawner that belongs to an event stands empty between events. Before V1 the three named slimes were
	-- permanently in the world and came back half an hour after dying, which made them a PLACE you visited;
	-- as an event they are a THING THAT HAPPENS, and the difference is entirely this check.
	local eventId = spawner:GetAttribute("EventOnly")
	if eventId and not EventState.IsActive(eventId) then return end

	local wanted = spawner:GetAttribute("Count") or 5
	local alive = spawner:GetAttribute("Alive") or 0

	-- สปอว์เนอร์ที่มี TriggerRadius จะรอจนมีคนเดินเข้ามาใกล้ก่อนถึงจะปล่อยมอน
	--
	-- **เป็นทางเลือก** ไม่มีแอตทริบิวต์นี้ = เกิดตลอดเวลาเหมือนเดิม สปอว์เนอร์เดิมทุกตัวจึงไม่เปลี่ยนพฤติกรรม
	--
	-- มีสองสถานะ ไม่ใช่ห้าอย่างที่ prompt เสนอ: "กำลังทำงานอยู่" กับ "รอให้คนออกไปก่อน" สถานะที่เหลือ
	-- (Spawning / Cooldown) ระบบเดิมมีของมันอยู่แล้วในรูป Alive กับ ReadyAt การเพิ่มอีกชุดจะเป็นสองแหล่ง
	-- ความจริงที่ต้องคอยให้ตรงกัน
	local triggerRadius = spawner:GetAttribute("TriggerRadius")
	if triggerRadius and triggerRadius > 0 then
		local origin = spawner:IsA("BasePart") and spawner.Position or spawner:GetPivot().Position
		local somebodyNear = anyPlayerWithin(origin, triggerRadius)

		-- รอบที่แล้วถูกเคลียร์หมดแล้ว และยังไม่มีใครออกจากพื้นที่เลย
		--
		-- ตามที่ prompt ขอ: คนต้องเดินออกไปก่อนแล้วกลับเข้ามาใหม่ ไม่งั้นการยืนแช่ในพื้นที่จะเรียกมอน
		-- ออกมาไม่รู้จบ
		if spawner:GetAttribute("AwaitExit") then
			if somebodyNear then return end
			spawner:SetAttribute("AwaitExit", nil)
			return
		end

		if not somebodyNear then return end
	end

	if alive >= wanted then return end

	-- respawnSeconds was declared in the config from the start and never actually read, so every monster
	-- came back on the next two-second service tick no matter what its config said. That is survivable for
	-- a green slime worth one lump of goo; for a named slime with a weapon in its drop table it would mean
	-- standing in one spot and emptying the table.
	--
	-- The clock lives on the SPAWNER as an attribute rather than in a local, so it survives this file being
	-- reloaded and can be read from outside when something wants to show a timer.
	local readyAt = spawner:GetAttribute("ReadyAt")
	if readyAt and os.clock() < readyAt then return end

	spawnOne(spawner, kind, config)
end

--------------------------------------------------------------------------------
-- The AI, one loop for every monster
--------------------------------------------------------------------------------

local function nearestPlayer(position, within)
	local best, bestDistance
	for _, player in ipairs(Players:GetPlayers()) do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		-- The dead and the downed are not targets: a monster chewing on someone who is already crawling
		-- makes them impossible to rescue.
		if root and humanoid and humanoid.Health > 0 and not player:GetAttribute("WOLD_Downed") then
			local d = (root.Position - position).Magnitude
			if d <= within and (not bestDistance or d < bestDistance) then
				best, bestDistance = player, d
			end
		end
	end
	return best, bestDistance
end

local accumulator = 0
RunService.Heartbeat:Connect(function(dt)
	accumulator += dt
	-- Four times a second is plenty for a walking blob, and keeps a field of fifty slimes off the frame
	-- budget. MoveTo keeps steering between ticks on its own.
	if accumulator < 0.25 then return end
	accumulator = 0

	for model, state in pairs(Live) do
		local root = model.PrimaryPart
		local humanoid = model:FindFirstChildOfClass("Humanoid")
		if not root or not humanoid or not model.Parent then
			Live[model] = nil
		else
			local position = root.Position
			local config = state.config

			-- หลุดโลก หรือลงไปอยู่ในน้ำแล้ว: ส่งกลับบ้านทันที (ผู้ใช้กำหนด ไม่ให้มอนอยู่ในน้ำ/ตกโลก)
			-- ตัวที่ถูกเสกล่าไม่มีบ้าน ให้กลับไปที่เดิมของมันเอง
			if position.Y < WORLD_FLOOR_Y or humanoid:GetState() == Enum.HumanoidStateType.Swimming then
				local back = state.home or state.lastDry or position
				model:PivotTo(CFrame.new(back + Vector3.new(0, 3, 0)))
				for _, part in ipairs(model:GetDescendants()) do
					if part:IsA("BasePart") then
						part.AssemblyLinearVelocity = Vector3.zero
						part.AssemblyAngularVelocity = Vector3.zero
					end
				end
				state.target = nil
				continue
			end
			state.lastDry = position

			-- ก้าวถัดไปเป็นน้ำ: หยุดและเลิกไล่ ไม่เดินลงไป
			local moveDir = humanoid.MoveDirection
			if moveDir.Magnitude > 0.1 and waterAt(position + moveDir.Unit * 5) then
				humanoid:MoveTo(position)
				state.target = nil
				state.blockedUntil = os.clock() + 2
				continue
			end
			if state.blockedUntil and os.clock() < state.blockedUntil then
				continue
			end

			-- Legs follow the body. Read off the real velocity rather than from each place that calls MoveTo,
			-- so chasing, walking home and drifting around the field all animate without three copies of
			-- this -- and so a monster stopped by a wall stops moving its legs too.
			--
			-- Started, never re-Played: Play on a running track restarts it from frame one every tick, which
			-- reads as a permanent twitch.
			if state.tracks and state.tracks.walk then
				local moving = root.AssemblyLinearVelocity * Vector3.new(1, 0, 1)
				if moving.Magnitude > 0.6 then
					if not state.tracks.walk.IsPlaying then state.tracks.walk:Play(0.2) end
				elseif state.tracks.walk.IsPlaying then
					state.tracks.walk:Stop(0.2)
				end
			end

			-- Stunned: nothing else this tick. Checked before the leash and the chase so a monster caught
			-- mid-walk stands still rather than finishing its step.
			if state.stunnedUntil and os.clock() < state.stunnedUntil then
				humanoid:MoveTo(position)
				continue
			end

			-- A HUNTED monster has no home and no leash: it was conjured to chase one person and it does not stop.
			-- Checked before the leash so it never walks back, and before the retarget so it never picks
			-- someone closer -- "ตามไม่เลิก" means this one player and no other.
			local hunted = state.hunt
			local huntRoot = hunted and hunted.Character
				and hunted.Character:FindFirstChild("HumanoidRootPart")

			-- Once they are down, stop. Vitals already refuses the damage, but a monster standing over a
			-- crawling player still blocks the rescue -- which is exactly why nearestPlayer skips the downed,
			-- and a hunter must not be the exception that undoes it. It waits where it is and resumes when
			-- they are back up.
			if hunted and huntRoot and hunted:GetAttribute("WOLD_Downed") then
				humanoid:MoveTo(position)
				continue
			end

			if hunted and not huntRoot then
				-- Their character is gone for the moment (dead, respawning, streamed out). Stand still and
				-- wait rather than falling back to ordinary behaviour, which would re-home a monster that
				-- has no home.
				humanoid:MoveTo(position)
				continue
			end

			-- Too far from home: stop chasing and walk back, so a chase cannot drag monsters into town.
			if not hunted and (position - state.home).Magnitude > config.leashRange then
				state.target = nil
				humanoid:MoveTo(state.home)
			else
				local target = state.target
				local targetRoot = target and target.Character
					and target.Character:FindFirstChild("HumanoidRootPart")

				if hunted then
					-- One target, forever. No aggro range to enter and no leash to escape.
					state.target, targetRoot = hunted, huntRoot
				elseif not targetRoot or (targetRoot.Position - position).Magnitude > config.leashRange then
					-- Lost them (left, died, went down, or outran the leash): look for someone else.
					state.target = nearestPlayer(position, config.aggroRange)
					targetRoot = state.target and state.target.Character
						and state.target.Character:FindFirstChild("HumanoidRootPart")
				end

				if targetRoot then
					local distance = (targetRoot.Position - position).Magnitude
					if distance <= config.attackRange then
						local now = os.clock()
						if now >= state.nextAttackAt then
							state.nextAttackAt = now + config.attackCooldown
							-- Swing where the blow happens, so the animation and the damage are one event
							-- rather than two things that usually coincide.
							if state.tracks and state.tracks.attack then
								state.tracks.attack:Play(0.1)
							end
							-- Through Vitals, the one door every kind of damage goes through: armor,
							-- invulnerability and the downed state are all decided there.
							local hurt = Vitals.ApplyDamage(state.target, config.damage * (state.damageScale or 1), "combat")
							-- And it should be HEARD -- but only by the person it happened to, and only when it
							-- cost them something. Built here on the server, the Sound went into the world and
							-- replicated, so everyone within sixty studs heard every bite taken out of everyone
							-- else and a field with a few slimes in it sounded like a battlefield. Now the one
							-- player it happened to is told, and their own client makes the noise
							-- (HurtSoundController), where it goes no further.
							--
							-- ApplyDamage answering false is what silences a monster standing over somebody who
							-- is already crawling: it keeps biting a body with no blood left, and that should be
							-- as quiet as it is harmless.
							--
							-- Player-on-player blows are deliberately NOT routed this way: PlayerCombat still
							-- plays those into the world, because a fight is worth overhearing.
							if hurt then Remotes.HurtSound:FireClient(state.target) end
						end
					else
						humanoid:MoveTo(targetRoot.Position)
						-- The wet slap of something large moving. Only a mob that declares a hop sound makes
						-- one, and only while it is actually going somewhere: a slime sitting in a field
						-- should be silent.
						if config.hopSound then
							local hopNow = os.clock()
							if hopNow >= (state.nextHopAt or 0) then
								state.nextHopAt = hopNow + (config.hopInterval or 1)
								playAt(model, config.hopSound, config.hopVolume or 0.3)
								-- A slime does not walk, it hops -- so it leaves the ground on the same beat
								-- the sound plays on, rather than sliding along while something boings.
								-- Only from the floor: asking mid-air does nothing and would desync the two.
								if humanoid.FloorMaterial ~= Enum.Material.Air then
									humanoid.JumpPower = config.hopPower or 28
									humanoid.UseJumpPower = true
									humanoid.Jump = true
								end
							end
						end
					end
				else
					-- Nobody about: drift slowly around home so the field is not a still life.
					if math.random() < 0.06 then
						local angle = math.random() * math.pi * 2
						humanoid:MoveTo(state.home + Vector3.new(
							math.cos(angle) * 12, 0, math.sin(angle) * 12))
					end
				end
			end
		end
	end
end)

--------------------------------------------------------------------------------
-- Keeping the spawners stocked
--------------------------------------------------------------------------------

task.spawn(function()
	while true do
		for _, spawner in ipairs(CollectionService:GetTagged(SPAWNER_TAG)) do
			serviceSpawner(spawner)
		end
		-- One monster per spawner per tick, which fills an empty field over a few seconds rather than
		-- materialising a crowd all at once.
		task.wait(2)
	end
end)

CollectionService:GetInstanceRemovedSignal(SPAWNER_TAG):Connect(function(spawner)
	for model, state in pairs(Live) do
		if state.spawner == spawner then despawn(model) end
	end
end)

--------------------------------------------------------------------------------
-- The mutant slime event
--------------------------------------------------------------------------------

-- Which spawners belong to an event, and what to do to them when it starts and stops. The event system knows
-- nothing about monsters; it calls these and this file does the rest.
local function eventSpawners(id)
	local out = {}
	for _, spawner in ipairs(CollectionService:GetTagged(SPAWNER_TAG)) do
		if spawner:GetAttribute("EventOnly") == id then table.insert(out, spawner) end
	end
	return out
end

-- The event ends when the last one dies, not only when the half hour runs out.
--
-- Counted from the SPAWNERS rather than from a tally of kills: a spawner knows how many it is meant to be
-- holding up and how many are alive, so this stays right if a slime is despawned by anything other than a
-- player -- the leash, a server restock, an admin clearing the field.
--
-- Only fires for a spawner that belongs to an event; an ordinary monster dying reaches this and leaves.
function Mobs.OnEventMobKilled(spawner)
	local eventId = spawner:GetAttribute("EventOnly")
	if not eventId or not EventState.IsActive(eventId) then return end

	for _, other in ipairs(eventSpawners(eventId)) do
		-- Still one standing, or one still due to walk out on the next stocking tick.
		if (other:GetAttribute("Alive") or 0) > 0 then return end
		-- A spawner that has not finished putting its share into the world yet. Without this the event would
		-- end the instant the first one was killed, before the other two had spawned.
		if (other:GetAttribute("Spawned") or 0) < (other:GetAttribute("Count") or 1) then return end
	end

	if EventState.Stop then EventState.Stop(eventId) end
end

EventState.Register("slime", {
	start = function()
		for _, spawner in ipairs(eventSpawners("slime")) do
			-- The respawn clock is cleared rather than waited out. It was set by whatever killed the last one,
			-- possibly during the previous event, and an announcement that produced nothing for twenty-nine
			-- minutes would be a lie.
			spawner:SetAttribute("ReadyAt", nil)
			spawner:SetAttribute("Alive", 0)
			spawner:SetAttribute("Spawned", 0)
		end
		-- Nothing else to do: the stocking loop runs every two seconds and its EventOnly check now passes, so
		-- the three of them walk into the world on the next tick.
	end,

	stop = function()
		-- Gone when the half hour is up, killed or not. A mutant left standing after the event would be a
		-- free weapon roll for whoever wandered past afterwards.
		for _, spawner in ipairs(eventSpawners("slime")) do
			for model, state in pairs(Live) do
				if state.spawner == spawner then despawn(model) end
			end
			spawner:SetAttribute("ReadyAt", nil)
			spawner:SetAttribute("Alive", 0)
			spawner:SetAttribute("Spawned", 0)
		end
	end,
})
