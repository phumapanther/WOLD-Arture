-- ExportController (เฟส 2c): รถส่งออกบนเกาะ ฝั่งไคลเอนต์
--
--   · หน้าต่าง (UI/ExportGui) — เปิดเมื่อเซิร์ฟส่ง ExportOpen ที่ `open = true` (กด E ท้ายรถ) · เดินห่างเกิน = ปิดเอง
--   · ป้ายลอยเหนือรถ + ควันปล่องตอนกำลังส่ง — ทุกคนบนเกาะเห็น (อ่านแอตทริบิวต์ ShipStart/ShipEnd บนตัวรถ)
--
-- หารถจากแท็ก `WOLD_ExportTruck` ในลูปถามใหม่ทุกครึ่งวิ (กฎเหล็ก StreamingEnabled — รถอาจมาถึงทีหลังสคริปต์)
while workspace:GetAttribute("IsLobby") == nil do task.wait() end
if workspace:GetAttribute("IslandMode") ~= true then return end

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local Remotes = require(ReplicatedStorage.Remotes)
local ExportGui = require(ReplicatedStorage.UI.ExportGui)
local UiSound = require(ReplicatedStorage.UI.UiSound)
local L = require(ReplicatedStorage.Locale).L

local player = Players.LocalPlayer
local gui = ExportGui.new()
local WALK_AWAY = 34 -- สตัดจากกลางรถ (ด่านเซิร์ฟ 26 + เผื่อ) เกินนี้ปิดหน้าต่างเอง

gui:OnShip(function(slot) Remotes.RequestExport:FireServer("ship", slot) end)
gui:OnReroll(function(slot) Remotes.RequestExport:FireServer("reroll", slot) end)
gui:OnClose(function() Remotes.RequestExport:FireServer("close") end)
gui:OnInstant(function() Remotes.RequestExport:FireServer("instant") end) -- 💎 รถกลับทันที (เซิร์ฟคิดราคาเอง)

local lastShip = nil -- สล็อตที่กำลังส่งในภาพก่อนหน้า (ไว้ตัดสินเสียงหวูด/เหรียญ)
Remotes.ExportOpen.OnClientEvent:Connect(function(snap)
	if type(snap) ~= "table" then return end
	local wasOpen = gui:IsOpen()
	gui:Show(snap)
	if not gui:IsOpen() then return end
	local now = snap.ship and snap.ship.slot or nil
	if wasOpen and now and lastShip == nil then UiSound.Play("ExportShip") end
	if wasOpen and lastShip ~= nil and now == nil then UiSound.Play("Coin") end
	lastShip = now
end)

player.CharacterRemoving:Connect(function() gui:Hide() end)

--------------------------------------------------------------------------------
-- ป้ายเหนือรถ + ควัน
--------------------------------------------------------------------------------

local Board = {} -- [truck] = { gui, title, status, fill, track, smoke }

local function clock(seconds)
	seconds = math.max(0, math.floor(seconds))
	return ("%d:%02d"):format(seconds // 60, seconds % 60)
end

-- ชิ้นที่สูงที่สุดของปล่อง (ควันออกยอด) · ไม่มีปล่อง = หลังคาห้องคนขับ
local function stackTop(truck)
	local stack = truck:FindFirstChild("Smokestack")
	local best
	if stack then
		for _, d in ipairs(stack:GetDescendants()) do
			if d:IsA("BasePart") and (not best or d.Position.Y > best.Position.Y) then best = d end
		end
		if stack:IsA("BasePart") then best = best or stack end
	end
	return best
end

local function buildBoard(truck)
	local anchor = truck:FindFirstChild("CabRoof") or truck.PrimaryPart or truck:FindFirstChildWhichIsA("BasePart", true)
	if not anchor then return nil end
	local board = Instance.new("BillboardGui")
	board.Name = "WOLD_ExportBoard"
	board.Adornee = anchor
	-- ⚠️ ขนาดเป็นสตัด (fromScale) ไม่ใช่พิกเซล — บทเรียนป้ายอีโมจิ: ของไกลเล็กลงเอง ไม่รกจอ ไม่ต้องตัดระยะแคบ
	board.Size = UDim2.fromScale(10, 2.6)
	board.StudsOffsetWorldSpace = Vector3.new(0, 4.2, 0)
	board.MaxDistance = 160
	board.LightInfluence = 0
	board.ResetOnSpawn = false
	board.Parent = anchor

	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundColor3 = Color3.fromRGB(22, 22, 28)
	frame.BackgroundTransparency = 0.25
	frame.BorderSizePixel = 0
	frame.Parent = board
	local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0.25, 0); c.Parent = frame
	local s = Instance.new("UIStroke"); s.Color = Color3.fromRGB(244, 197, 66); s.Transparency = 0.4; s.Thickness = 1.5; s.Parent = frame

	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Size = UDim2.fromScale(1, 0.46)
	title.Font = Enum.Font.GothamBold
	title.TextScaled = true
	title.TextColor3 = Color3.fromRGB(244, 197, 66)
	title.Text = L("🚚 รถส่งออก")
	title.Parent = frame
	local pad = Instance.new("UIPadding"); pad.PaddingTop = UDim.new(0.08, 0); pad.Parent = title

	local track = Instance.new("Frame")
	track.AnchorPoint = Vector2.new(0.5, 1)
	track.Position = UDim2.fromScale(0.5, 0.9)
	track.Size = UDim2.fromScale(0.9, 0.4)
	track.BackgroundColor3 = Color3.fromRGB(40, 42, 50)
	track.BorderSizePixel = 0
	track.Parent = frame
	local tc = Instance.new("UICorner"); tc.CornerRadius = UDim.new(0.5, 0); tc.Parent = track
	local fill = Instance.new("Frame")
	fill.Size = UDim2.fromScale(0, 1)
	fill.BackgroundColor3 = Color3.fromRGB(96, 150, 100)
	fill.BorderSizePixel = 0
	fill.Parent = track
	local fc = Instance.new("UICorner"); fc.CornerRadius = UDim.new(0.5, 0); fc.Parent = fill
	local status = Instance.new("TextLabel")
	status.BackgroundTransparency = 1
	status.Size = UDim2.fromScale(1, 1)
	status.Font = Enum.Font.GothamBold
	status.TextScaled = true
	status.TextColor3 = Color3.fromRGB(236, 236, 240)
	status.ZIndex = 2
	status.Parent = track
	local sp = Instance.new("UIPadding"); sp.PaddingTop = UDim.new(0.12, 0); sp.PaddingBottom = UDim.new(0.12, 0); sp.Parent = status

	-- ควันปล่อง (เครื่องนี้สร้างเอง ทุกคนสร้างของตัวเอง = ทุกคนเห็น)
	local smoke
	local top = stackTop(truck)
	if top then
		smoke = Instance.new("ParticleEmitter")
		smoke.Name = "WOLD_ExportSmoke"
		smoke.Texture = "rbxasset://textures/particles/smoke_main.dds"
		smoke.Color = ColorSequence.new(Color3.fromRGB(210, 210, 210), Color3.fromRGB(150, 150, 155))
		smoke.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 1) })
		smoke.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.8), NumberSequenceKeypoint.new(1, 3.2) })
		smoke.Lifetime = NumberRange.new(2, 3)
		smoke.Speed = NumberRange.new(3, 5)
		smoke.SpreadAngle = Vector2.new(12, 12)
		smoke.Acceleration = Vector3.new(0.6, 1.2, 0)
		smoke.EmissionDirection = Enum.NormalId.Top
		smoke.Rate = 7
		smoke.Enabled = false
		smoke.Parent = top
	end
	return { gui = board, fill = fill, status = status, smoke = smoke }
end

local function drawBoard(truck, entry)
	local startAt, endAt = truck:GetAttribute("ShipStart"), truck:GetAttribute("ShipEnd")
	local shipping = type(endAt) == "number" and type(startAt) == "number"
	if shipping then
		local left = math.max(0, endAt - workspace:GetServerTimeNow())
		entry.fill.Size = UDim2.fromScale(math.clamp(1 - left / math.max(1, endAt - startAt), 0, 1), 1)
		entry.status.Text = left > 0 and L("กำลังส่ง · กลับใน %s", clock(left)) or L("กำลังกลับเข้าฟาร์ม…")
	else
		entry.fill.Size = UDim2.fromScale(0, 1)
		entry.status.Text = L("ว่าง · กด E ท้ายรถเพื่อส่งของ")
	end
	if entry.smoke then entry.smoke.Enabled = shipping end
end

task.spawn(function()
	while true do
		for truck, entry in pairs(Board) do
			if not truck.Parent or not entry.gui.Parent then
				if entry.smoke then entry.smoke:Destroy() end
				entry.gui:Destroy()
				Board[truck] = nil
			end
		end
		for _, truck in ipairs(CollectionService:GetTagged("WOLD_ExportTruck")) do
			if truck:IsA("Model") then
				local entry = Board[truck] or buildBoard(truck)
				if entry then
					Board[truck] = entry
					drawBoard(truck, entry)
				end
			end
		end
		-- เดินห่างรถ = ปิดหน้าต่าง (เซิร์ฟปฏิเสธคำสั่งจากไกลอยู่แล้ว หน้าต่างที่ค้างจะกดอะไรก็ไม่ได้)
		if gui:IsOpen() then
			local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
			local near = false
			for truck in pairs(Board) do
				if root and (truck:GetPivot().Position - root.Position).Magnitude <= WALK_AWAY then near = true end
			end
			if not near then gui:Hide() end
		end
		task.wait(0.5)
	end
end)
