-- StoryController: ฝั่งไคลเอนต์ของเนื้อเรื่อง "ผู้มากับแสงวิบวับ" (เพลสหลักเท่านั้น) — วาด/เล่นตามที่ Story.server สั่ง
--
-- · จอโหลดจบ (`WOLD_Loaded`) → ส่ง "ready" → เซิร์ฟตอบภาพความคืบหน้า (+ คัทซีนถ้าเป็นคนใหม่)
-- · คัทซีน: กล้อง Scriptable ตามช็อตใน `StoryConfig.Cutscene` · ซ่อน UI อื่นผ่าน PhotoMode · ท่านอน→ลุกของตัวเอง
--   (Root.Transform ฝั่งเครื่องนี้ ทรงเดียวกับท่าคลาน) · รูนในวงเวทสว่างทีละวง · ไลราเดินเข้าเฟรม — ทุกอย่างเป็นภาพในเครื่องนี้
--   ข้าม/จบ = คืนทุกอย่างแล้วส่ง "cutscene_done" (เซิร์ฟปลดตรึงตัว)
-- · ❗ เหนือหัว NPC ตอนมีเรื่องคุย (❔ = ยังทำขั้นนี้ไม่เสร็จ) · วง ❗ บนพื้นของจุดหมายขั้น reach
-- ลูปถามแท็กใหม่ทุกครึ่งวิ (กฎเหล็ก StreamingEnabled — NPC/หมุดโผล่มาทีหลังได้)
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

while workspace:GetAttribute("IsLobby") == nil do task.wait(0.2) end
if workspace:GetAttribute("IsLobby") then return end
if workspace:GetAttribute("ArenaMode") == true or workspace:GetAttribute("IslandMode") == true then return end

local StoryConfig = require(ReplicatedStorage.StoryConfig)
local Remotes = require(ReplicatedStorage.Remotes)
local StoryGui = require(ReplicatedStorage.UI.StoryGui)
local PhotoMode = require(ReplicatedStorage.UI.PhotoMode)
local UiSound = require(ReplicatedStorage.UI.UiSound)
local TeleportService = game:GetService("TeleportService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local gui = StoryGui.new(playerGui)
local state = nil
local inCutscene = false

local RUNE_COLOR = Color3.fromRGB(126, 214, 232)
local WALK_ANIM = "rbxassetid://507777826" -- ท่าเดิน R15 มาตรฐาน (ไลราเดินเข้าเฟรม)

--------------------------------------------------------------------------------
-- ความคืบหน้า + ป้าย
--------------------------------------------------------------------------------
local function npcModel(npcId)
	for _, m in ipairs(CollectionService:GetTagged("WOLD_StoryNpc")) do
		if m:GetAttribute("StoryNpc") == npcId then return m end
	end
	return nil
end

local function billboard(adornee, name, text, offsetY)
	local b = adornee:FindFirstChild(name)
	if not b then
		b = Instance.new("BillboardGui")
		b.Name = name
		b.Size = UDim2.fromScale(2.4, 2.4) -- สตัด: เล็กลงตามระยะเหมือนของในโลก
		b.StudsOffsetWorldSpace = Vector3.new(0, offsetY or 2.6, 0)
		b.LightInfluence = 0
		b.MaxDistance = 140
		b.AlwaysOnTop = false
		local l = Instance.new("TextLabel")
		l.Name = "Mark"
		l.Size = UDim2.fromScale(1, 1)
		l.BackgroundTransparency = 1
		l.TextScaled = true
		l.Parent = b
		b.Parent = adornee
	end
	b.Mark.Text = text
	return b
end

-- วงจุดหมายบนพื้น (ของเครื่องนี้)
local ring = Instance.new("Part")
ring.Name = "StoryTargetRing"
ring.Shape = Enum.PartType.Cylinder
ring.Material = Enum.Material.Neon
ring.Color = Color3.fromRGB(255, 214, 110)
ring.Transparency = 0.55
ring.Anchored, ring.CanCollide, ring.CanQuery, ring.CanTouch, ring.CastShadow = true, false, false, false, false
local ringAnchor = Instance.new("Part")
ringAnchor.Name = "StoryTargetMark"
ringAnchor.Size = Vector3.new(0.2, 0.2, 0.2)
ringAnchor.Transparency = 1
ringAnchor.Anchored, ringAnchor.CanCollide, ringAnchor.CanQuery, ringAnchor.CanTouch = true, false, false, false

local function refreshMarks()
	-- ❗ / ❔ เหนือ NPC ของบทนี้
	for _, m in ipairs(CollectionService:GetTagged("WOLD_StoryNpc")) do
		local head = m:FindFirstChild("Head")
		if head then
			local mine = state and not state.done and state.npc == m:GetAttribute("StoryNpc")
			local b = billboard(head, "StoryMark", (mine and state.ready) and "❗" or "❔", 2.6)
			b.Enabled = mine == true and not inCutscene
		end
	end
	-- จุดหมายขั้น reach
	if state and state.kind == "reach" and state.target and not inCutscene then
		local r = state.radius or 9
		ring.Size = Vector3.new(0.2, r * 2, r * 2)
		ring.CFrame = CFrame.new(state.target + Vector3.new(0, 0.15, 0)) * CFrame.Angles(0, 0, math.rad(90))
		ring.Parent = workspace
		ringAnchor.Position = state.target + Vector3.new(0, 4, 0)
		ringAnchor.Parent = workspace
		billboard(ringAnchor, "StoryMark", "❗", 0).MaxDistance = 400
		ring.Transparency = 0.45 + 0.2 * math.sin(os.clock() * 3)
	else
		ring.Parent = nil
		ringAnchor.Parent = nil
	end
	-- ❗ เหนือออฟาเรียน (หุ่นฟางข้างจุดเกิด) ตอนมีเควสฟ้าพร้อมรับ
	local sideReady = false
	for _, row in ipairs(state and state.rows or {}) do
		if row.color == "side" and row.state == "active" then sideReady = true break end
	end
	for _, d in ipairs(CollectionService:GetTagged("WOLD_Dummy")) do
		if d.Name == "Dummy_Spawn" then
			local anchor = d:FindFirstChild("Head") or d.PrimaryPart
			if anchor then
				local cf, size = d:GetBoundingBox()
				local b = billboard(anchor, "OforianMark", "❗", (cf.Position.Y + size.Y / 2) - anchor.Position.Y + 2.4)
				b.Enabled = sideReady and not inCutscene
			end
		end
	end
end

task.spawn(function()
	while true do
		pcall(refreshMarks)
		task.wait(0.1)
	end
end)

local function localToast(text, silent)
	local channel = ReplicatedStorage:FindFirstChild("WOLD_Toast")
	if channel then channel:Fire(text, false, silent) end
end

Remotes.StoryState.OnClientEvent:Connect(function(s)
	local previous = state
	state = s
	-- ความคืบหน้าไม่เงียบ (QA 2026-09-28): ขึ้นขั้นใหม่ = เสียง + ข้อความเป้าหมายใหม่ · ล่ามอนได้เพิ่ม = บอกจำนวน
	if previous and s and not s.done and previous.chapter == s.chapter then
		if (s.step or 0) > (previous.step or 0) then
			UiSound.Play("StoryStep")
			localToast(("📜 %s"):format(s.goal or ""), true)
		elseif s.kind == "hunt" and (s.got or 0) > (previous.got or 0) then
			localToast(("📜 %s %d/%d"):format(s.goal or "", s.got or 0, s.need or 0))
		end
	end
end)

--------------------------------------------------------------------------------
-- คัทซีน
--------------------------------------------------------------------------------
local function runes()
	local out = {}
	for _, circle in ipairs(CollectionService:GetTagged("WOLD_MagicCircle")) do
		for _, d in ipairs(circle:GetDescendants()) do
			if d:IsA("BasePart") and d.Name:match("^Rune") then out[#out + 1] = d end
		end
	end
	table.sort(out, function(a, b) return (tonumber(a:GetAttribute("Ring")) or 0) < (tonumber(b:GetAttribute("Ring")) or 0) end)
	return out
end

local function steam(count)
	for _, circle in ipairs(CollectionService:GetTagged("WOLD_MagicCircle")) do
		for _, d in ipairs(circle:GetDescendants()) do
			if d:IsA("ParticleEmitter") and d.Name == "Steam" then d:Emit(count) end
		end
	end
end

local function tweenCamera(camera, from, to, seconds)
	camera.CFrame = from
	local tween = TweenService:Create(camera, TweenInfo.new(seconds, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), { CFrame = to })
	tween:Play()
	return tween
end

local function runCutscene(info)
	local camera = workspace.CurrentCamera
	local center = info and info.center
	if not (camera and center) then
		Remotes.RequestStory:FireServer("cutscene_done")
		return
	end
	inCutscene = true
	pcall(function() player:RequestStreamAroundAsync(center, 6) end)

	-- ซ่อนทุกอย่าง (ปุ่มมือถือของเกมด้วย — PhotoMode เว้นไว้ให้)
	PhotoMode.Set(true)
	local touch = playerGui:FindFirstChild("TouchActionGui")
	local touchWas = touch and touch.Enabled
	if touch then touch.Enabled = false end
	gui:SetCinema(true)
	local cameraType = camera.CameraType
	camera.CameraType = Enum.CameraType.Scriptable

	local skipped = false
	local skipConn = gui.skipButton.Activated:Connect(function() skipped = true end)

	-- ท่านอนหงาย → ลุก (k 1 = นอน · 0 = ยืน)
	local k = 1
	local character = player.Character
	local lower = character and character:FindFirstChild("LowerTorso")
	local rootJoint = lower and lower:FindFirstChild("Root")
	local poseConn = RunService.Stepped:Connect(function()
		if rootJoint and rootJoint.Parent then
			rootJoint.Transform = CFrame.new(0, -2.6 * k, 0) * CFrame.Angles(math.rad(90 * k), 0, 0)
		end
	end)
	local hrp = character and character:FindFirstChild("HumanoidRootPart")
	local sparkles
	if hrp then
		sparkles = Instance.new("ParticleEmitter")
		sparkles.Name = "StorySparkles"
		sparkles.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		sparkles.Color = ColorSequence.new(RUNE_COLOR, Color3.fromRGB(255, 236, 170))
		sparkles.LightEmission = 1
		sparkles.LightInfluence = 0
		sparkles.Size = NumberSequence.new(0.35, 0)
		sparkles.Lifetime = NumberRange.new(1.2, 2)
		sparkles.Speed = NumberRange.new(0.5, 1.5)
		sparkles.SpreadAngle = Vector2.new(180, 180)
		sparkles.Rate = 0
		sparkles.Parent = hrp
	end

	-- รูน: หรี่ไว้ก่อน แล้วสว่างทีละวงตอนกล้องลง
	local runeParts = runes()
	local saved = {}
	for _, r in ipairs(runeParts) do
		saved[r] = { r.Transparency, r.Color, r.Material }
		r.Transparency = 0.85
	end

	-- ไลรา: ย้ายออกไปก่อน (เฉพาะเครื่องนี้) แล้วเดินเข้าเฟรมตอนถึงช็อตของเธอ
	local lyra = npcModel("Lyra")
	local lyraPivot = lyra and lyra:GetPivot()

	local function wait(seconds)
		local t0 = os.clock()
		while os.clock() - t0 < seconds and not skipped do RunService.RenderStepped:Wait() end
	end

	-- เสียงของคัทซีน (QA 2026-09-28) — เก็บไว้ค่อยๆ ปิดตอนข้าม/จบ
	local playing = {}
	local function sfx(name)
		local sound = UiSound.Play(name)
		if sound then playing[#playing + 1] = sound end
	end

	local shots = {
		black = function(beat)
			gui:Black(true, 0)
			gui:Motes(true)
			sfx("Memory")
			camera.CFrame = CFrame.lookAt(center + Vector3.new(-80, 50, 80), center)
		end,
		rooftops = function(beat)
			gui:Motes(false)
			gui:Black(false, 0.8)
			tweenCamera(camera, CFrame.lookAt(center + Vector3.new(-80, 50, 80), center),
				CFrame.lookAt(center + Vector3.new(-40, 34, 40), center), beat.seconds)
			steam(12)
			sfx("CutRumble")
		end,
		descend = function(beat)
			tweenCamera(camera, CFrame.lookAt(center + Vector3.new(-26, 22, 26), center),
				CFrame.lookAt(center + Vector3.new(-12, 8, 12), center), beat.seconds)
			for i, r in ipairs(runeParts) do
				task.delay((i / math.max(#runeParts, 1)) * beat.seconds * 0.85, function()
					if saved[r] then
						r.Material = Enum.Material.Neon
						r.Color = RUNE_COLOR
						r.Transparency = 0
					end
				end)
			end
			steam(20)
			sfx("CutMagic")
		end,
		flash = function(beat)
			gui:Flash(beat.seconds)
			sfx("CutFlash")
		end,
		wake = function(beat)
			local body = hrp and hrp.Position or center
			tweenCamera(camera, CFrame.lookAt(body + Vector3.new(7, 5, 9), body),
				CFrame.lookAt(body + Vector3.new(5, 4, 7), body + Vector3.new(0, 1, 0)), beat.seconds)
			if sparkles then sparkles.Rate = 40 end
			sfx("GachaRare")
			task.delay(1.5, function()
				local t0 = os.clock()
				while k > 0 and inCutscene do
					k = math.max(0, 1 - (os.clock() - t0) / 2.5)
					RunService.Stepped:Wait()
				end
			end)
		end,
		lyra = function(beat)
			k = 0
			if lyra and lyraPivot and hrp then
				local toPlayer = (hrp.Position - lyraPivot.Position) * Vector3.new(1, 0, 1)
				local from = lyraPivot * CFrame.new(0, 0, 12) -- ถอยไปด้านหลังเธอ 12 สตัด
				local humanoid = lyra:FindFirstChildOfClass("Humanoid")
				local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
				local track
				if animator then
					local anim = Instance.new("Animation")
					anim.AnimationId = WALK_ANIM
					local ok, t = pcall(animator.LoadAnimation, animator, anim)
					if ok then track = t track:Play() end
				end
				local t0 = os.clock()
				task.spawn(function()
					while inCutscene and os.clock() - t0 < 1.6 do
						lyra:PivotTo(from:Lerp(lyraPivot, (os.clock() - t0) / 1.6))
						RunService.RenderStepped:Wait()
					end
					if inCutscene then lyra:PivotTo(lyraPivot) end
					if track then track:Stop(0.3) end
				end)
				local eye = hrp.Position + Vector3.new(0, 3.2, 0) - toPlayer.Unit * 5 + toPlayer.Unit:Cross(Vector3.yAxis) * 2
				tweenCamera(camera, CFrame.lookAt(eye, lyraPivot.Position + Vector3.new(0, 2, 0)),
					CFrame.lookAt(eye + toPlayer.Unit * 1.5, lyraPivot.Position + Vector3.new(0, 2, 0)), beat.seconds)
			end
		end,
		lyraClose = function(beat)
			local head = lyra and lyra:FindFirstChild("Head")
			if head then
				local look = head.CFrame.LookVector
				tweenCamera(camera, CFrame.lookAt(head.Position + look * 7 + Vector3.new(0, 0.6, 0), head.Position),
					CFrame.lookAt(head.Position + look * 5.5 + Vector3.new(0, 0.4, 0), head.Position), beat.seconds)
			end
		end,
		title = function(beat)
			tweenCamera(camera, CFrame.lookAt(center + Vector3.new(0, 14, 26), center),
				CFrame.lookAt(center + Vector3.new(0, 24, 34), center), beat.seconds)
			gui:TitleCard(beat.title, beat.subtitle)
			sfx("CutTitle")
		end,
	}

	for _, beat in ipairs(StoryConfig.Cutscene) do
		if skipped then break end
		gui:Caption(beat.text, beat.who)
		local fn = shots[beat.shot]
		if fn then pcall(fn, beat) end
		wait(beat.seconds or 3)
	end

	-- คืนทุกอย่าง · เสียงที่ยังเล่นค่อยๆ เบาลง (ข้ามกลางคัน = ไม่ตัดกึก)
	for _, sound in ipairs(playing) do
		if sound.Parent then
			TweenService:Create(sound, TweenInfo.new(0.6), { Volume = 0 }):Play()
			game:GetService("Debris"):AddItem(sound, 0.7)
		end
	end
	inCutscene = false
	skipConn:Disconnect()
	poseConn:Disconnect()
	if rootJoint and rootJoint.Parent then rootJoint.Transform = CFrame.new() end
	if sparkles then
		sparkles.Rate = 0
		game:GetService("Debris"):AddItem(sparkles, 3)
	end
	for r, props in pairs(saved) do
		if r.Parent then r.Transparency, r.Color, r.Material = props[1], props[2], props[3] end
	end
	if lyra and lyraPivot then lyra:PivotTo(lyraPivot) end
	camera.CameraType = cameraType == Enum.CameraType.Scriptable and Enum.CameraType.Custom or cameraType
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if humanoid then camera.CameraSubject = humanoid end
	gui:SetCinema(false)
	PhotoMode.Set(false)
	if touch and touchWas ~= nil then touch.Enabled = touchWas end
	Remotes.RequestStory:FireServer("cutscene_done")
end

-- คัทซีนรถคาร์โก้ (StoryConfig.SkyCutscene) → จอขาวค้าง → ให้เซิร์ฟวาป · ภาพทั้งหมดเป็นของเครื่องนี้
local function whiteVeil()
	local g = Instance.new("ScreenGui")
	g.Name = "WOLD_SkyVeil"
	g.IgnoreGuiInset = true
	g.DisplayOrder = 1000
	g.ResetOnSpawn = false
	local f = Instance.new("Frame")
	f.Size = UDim2.fromScale(1, 1)
	f.BackgroundColor3 = Color3.new(1, 1, 1)
	f.BorderSizePixel = 0
	f.Parent = g
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.AnchorPoint = Vector2.new(0.5, 0.5)
	t.Position = UDim2.fromScale(0.5, 0.5)
	t.Size = UDim2.fromScale(0.8, 0.12)
	t.Font = Enum.Font.GothamBlack
	t.TextScaled = true
	t.TextColor3 = Color3.fromRGB(170, 130, 60)
	t.Text = StoryConfig.SkyTitle
	t.Parent = f
	return g
end

local skyRestore = nil -- คืนหน้าจอตอนวาปไม่สำเร็จ
local function runSkyCutscene(info)
	local camera = workspace.CurrentCamera
	local character = player.Character
	local hrp = character and character:FindFirstChild("HumanoidRootPart")
	if not (camera and hrp) then
		Remotes.RequestStory:FireServer("sky_warp")
		return
	end
	inCutscene = true
	local at = (info and info.at) or hrp.Position
	PhotoMode.Set(true)
	local touch = playerGui:FindFirstChild("TouchActionGui")
	local touchWas = touch and touch.Enabled
	if touch then touch.Enabled = false end
	gui:SetCinema(true)
	local cameraType = camera.CameraType
	camera.CameraType = Enum.CameraType.Scriptable
	local skipped = false
	local skipConn = gui.skipButton.Activated:Connect(function() skipped = true end)
	local playing = {}
	local function sfx(name)
		local sound = UiSound.Play(name)
		if sound then playing[#playing + 1] = sound end
	end
	local function wait(seconds)
		local t0 = os.clock()
		while os.clock() - t0 < seconds and not skipped do RunService.RenderStepped:Wait() end
	end

	-- รถ: ข้างตัวผู้เล่น 10 สตัด บนพื้นจริง หันไปทางเดียวกับผู้เล่น
	local look = hrp.CFrame.LookVector * Vector3.new(1, 0, 1)
	look = look.Magnitude > 0.1 and look.Unit or Vector3.new(0, 0, -1)
	local right = look:Cross(Vector3.yAxis)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character }
	local spot = hrp.Position + right * 10
	local hit = workspace:Raycast(spot + Vector3.new(0, 30, 0), Vector3.new(0, -80, 0), params)
	local ground = hit and hit.Position or (spot - Vector3.new(0, 3, 0))
	local truckCf = CFrame.lookAt(ground, ground + look)
	local folder = ReplicatedStorage:FindFirstChild("WOLD_Cutscene")
	local proto = folder and folder:FindFirstChild("CargoTruck")
	local truck = proto and proto:Clone()
	local fades = {}
	if truck then
		for _, p in ipairs(truck:GetDescendants()) do
			if p:IsA("BasePart") then
				fades[p] = p.Transparency
				p.Transparency = 1
			end
		end
		truck:PivotTo(truckCf)
		truck.Parent = workspace
	end

	-- แสงทองของออฟาเรียน
	local glow = Instance.new("Part")
	glow.Anchored, glow.CanCollide, glow.CanQuery, glow.CanTouch = true, false, false, false
	glow.Transparency = 1
	glow.Size = Vector3.new(1, 1, 1)
	glow.Position = at + Vector3.new(0, 3, 0)
	glow.Parent = workspace
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 214, 120)
	light.Range = 18
	light.Brightness = 0
	light.Parent = glow
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	emitter.Color = ColorSequence.new(Color3.fromRGB(255, 214, 120))
	emitter.LightEmission = 1
	emitter.LightInfluence = 0
	emitter.Size = NumberSequence.new(0.5, 0)
	emitter.Lifetime = NumberRange.new(1, 1.8)
	emitter.Speed = NumberRange.new(1, 3)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Rate = 0
	emitter.Parent = glow

	local function hideSelf(on)
		for _, d in ipairs(character:GetDescendants()) do
			if d:IsA("BasePart") or d:IsA("Decal") then d.LocalTransparencyModifier = on and 1 or 0 end
		end
	end

	-- รถลอยขึ้น + กล้องตาม (ใช้ทั้งฉาก rise และ clouds)
	local follow = nil -- "rise" | "clouds" | nil
	local riseStart = nil
	local followConn = RunService.RenderStepped:Connect(function()
		if not (truck and riseStart) then return end
		local k = os.clock() - riseStart
		truck:PivotTo(truckCf + Vector3.new(0, k * k * 6, 0))
		local pos = truck:GetPivot().Position
		if follow == "rise" then
			camera.CFrame = CFrame.lookAt(pos + look * 34 + right * 26 + Vector3.new(0, -6, 0), pos + Vector3.new(0, 4, 0))
		elseif follow == "clouds" then
			camera.CFrame = CFrame.lookAt(pos + Vector3.new(24, 70, 24), pos)
		end
	end)

	local c = ground + Vector3.new(0, 3, 0)
	local shots = {
		glow = function(beat)
			TweenService:Create(light, TweenInfo.new(1.5), { Brightness = 4 }):Play()
			emitter.Rate = 30
			sfx("CutMagic")
			tweenCamera(camera, CFrame.lookAt(at + right * 6 + look * 8 + Vector3.new(0, 4, 0), at + Vector3.new(0, 3, 0)),
				CFrame.lookAt(at + right * 10 + look * 14 + Vector3.new(0, 7, 0), at + Vector3.new(0, 3, 0)), beat.seconds)
		end,
		truck = function(beat)
			gui:Flash(0.5)
			sfx("CutFlash")
			sfx("CutRumble")
			for p, t in pairs(fades) do TweenService:Create(p, TweenInfo.new(2), { Transparency = t }):Play() end
			tweenCamera(camera, CFrame.lookAt(c + look * 22 + right * 14 + Vector3.new(0, 6, 0), c),
				CFrame.lookAt(c + look * 16 + right * 10 + Vector3.new(0, 4, 0), c), beat.seconds)
		end,
		board = function()
			gui:Black(true, 0.5)
			task.delay(0.8, function()
				hideSelf(true)
				if not skipped then gui:Black(false, 0.6) end
			end)
		end,
		rise = function()
			sfx("CutRumble")
			riseStart = os.clock()
			follow = "rise"
		end,
		clouds = function()
			follow = "clouds"
		end,
		flash = function(beat)
			gui:Flash(beat.seconds)
			sfx("CutFlash")
		end,
		title = function(beat)
			follow = nil
			gui:White(true)
			gui:TitleCard(beat.title, beat.subtitle)
			sfx("CutTitle")
		end,
	}

	for _, beat in ipairs(StoryConfig.SkyCutscene) do
		if skipped then break end
		gui:Caption(beat.text, beat.who)
		local fn = shots[beat.shot]
		if fn then pcall(fn, beat) end
		wait(beat.seconds or 3)
	end

	-- จบ/ข้าม: จอขาวค้าง (ต่อเนื่องไปถึงเกาะด้วย SetTeleportGui) แล้วให้เซิร์ฟวาป
	for _, sound in ipairs(playing) do
		if sound.Parent then
			TweenService:Create(sound, TweenInfo.new(0.6), { Volume = 0 }):Play()
			game:GetService("Debris"):AddItem(sound, 0.7)
		end
	end
	gui:White(true)
	local veil = whiteVeil()
	pcall(function() TeleportService:SetTeleportGui(veil) end)
	veil.Parent = playerGui
	followConn:Disconnect()
	skyRestore = function()
		inCutscene = false
		skipConn:Disconnect()
		hideSelf(false)
		if truck then truck:Destroy() end
		glow:Destroy()
		veil:Destroy()
		camera.CameraType = cameraType == Enum.CameraType.Scriptable and Enum.CameraType.Custom or cameraType
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid then camera.CameraSubject = humanoid end
		gui:White(false)
		gui:SetCinema(false)
		PhotoMode.Set(false)
		if touch and touchWas ~= nil then touch.Enabled = touchWas end
	end
	Remotes.RequestStory:FireServer("sky_warp")
end

--------------------------------------------------------------------------------
-- คำสั่งจากเซิร์ฟ
--------------------------------------------------------------------------------
local function afterTalking(fn)
	task.spawn(function()
		while gui:IsTalking() or inCutscene do task.wait(0.2) end
		fn()
	end)
end

Remotes.StoryPlay.OnClientEvent:Connect(function(kind, arg)
	if kind == "dialogue" then
		local lines = StoryConfig.Dialogues[arg]
		if lines then afterTalking(function() gui:Say(lines) end) end
	elseif kind == "cutscene" then
		task.spawn(runCutscene, arg)
	elseif kind == "memory" then
		local beats = StoryConfig.Memories[arg]
		if not beats then return end
		afterTalking(function()
			UiSound.Play("Memory")
			local blur = Instance.new("BlurEffect")
			blur.Size = 16
			blur.Parent = workspace.CurrentCamera
			gui:Memory(beats, function() blur:Destroy() end)
		end)
	elseif kind == "complete" and type(arg) == "table" then
		afterTalking(function()
			UiSound.Play("FarmLevelUp")
			local lines = {}
			if arg.exp then lines[#lines + 1] = ("+%d EXP"):format(arg.exp) end
			if arg.gold then
				local digits = tostring(math.floor(arg.gold))
				local grouped = digits:reverse():gsub("(%d%d%d)", "%1,"):reverse()
				lines[#lines + 1] = ("+%s เหรียญ"):format((grouped:gsub("^,", "")))
			end
			local body = table.concat(lines, " · ")
			if arg.title then body ..= ("\nได้ฉายา \"%s\" — เลือกใช้ได้ในสมุดสะสม"):format(arg.title) end
			if arg.gift then body ..= "\n🎁 ออฟาเรียน เทพหุ่นฟางมีของขวัญการเดินทางให้ — ไปพบที่ข้างจุดเกิด" end
			gui:Banner(("📜 จบบท: %s"):format(arg.name or ""), body, 7)
		end)
	elseif kind == "newQuest" then
		UiSound.Play("StoryStep")
		localToast(("📜 เควสใหม่: %s — แตะที่แถบเควสเพื่อนำทาง"):format(tostring(arg)), true)
	elseif kind == "gift" and type(arg) == "table" then
		afterTalking(function()
			UiSound.Play("ToastReward")
			gui:Banner(arg.title or "🎁", arg.body or "", 7)
		end)
	elseif kind == "skyOffer" then
		afterTalking(function()
			gui:Choice("รับพรจากออฟาเรียน แล้วเดินทางไปเกาะลอยฟ้าแห่งความฝัน?", "รับพร", "ไว้ก่อน", function(yes)
				if yes then Remotes.RequestStory:FireServer("sky_accept") end
			end)
		end)
	elseif kind == "skyCutscene" then
		task.spawn(runSkyCutscene, arg)
	elseif kind == "skyFailed" then
		if skyRestore then
			skyRestore()
			skyRestore = nil
		end
		localToast(tostring(arg))
	end
end)

-- Space/Enter = ไปต่อ (ตอนมีกล่องคุยเปิดอยู่)
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed or not gui:IsTalking() then return end
	if input.KeyCode == Enum.KeyCode.Space or input.KeyCode == Enum.KeyCode.Return then gui:Next() end
end)

-- จอโหลดจบแล้วค่อยบอกเซิร์ฟ (คัทซีนต้องไม่เล่นใต้จอโหลด)
-- **ส่งซ้ำทุก 3 วิจนกว่าเซิร์ฟตอบ** (QA 2026-09-28): โปรไฟล์ยังโหลดไม่เสร็จ เซิร์ฟเงียบ — ส่งครั้งเดียวคนใหม่จะพลาดคัทซีน
task.spawn(function()
	while player:GetAttribute("WOLD_Loaded") ~= true do task.wait(0.25) end
	task.wait(0.5)
	for _ = 1, 20 do
		if state ~= nil then break end
		Remotes.RequestStory:FireServer("ready")
		task.wait(3)
	end
end)
