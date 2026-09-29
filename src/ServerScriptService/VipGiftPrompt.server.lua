-- VipGiftPrompt: ปุ่ม E "คุยกับออฟาเรียน" บนหุ่นฟางข้างจุดเกิดแรก (`Dummy_Spawn`) + ป้ายชื่อเหนือหัว (2026-09-29)
-- ของขวัญทั้งหมดมาเป็นเควสสีฟ้าของ "ออฟาเรียน เทพหุ่นฟาง" — กติกา `VipGift` · บทพูด/ให้ของ `Story.server` (TalkOforian)
-- ชื่อไฟล์เดิมคงไว้ (อยู่ใน denylist ของ farming/arena อยู่แล้ว) · เกมหลักเท่านั้น · ปุ่มโชว์ตลอด (ไม่มีเควส = บทพูดทักทาย)
local CollectionService = game:GetService("CollectionService")

local ServerConfig = require(script.Parent.ServerConfig)
if ServerConfig.IsLobby then return end

local StoryAccess = require(script.Parent.StoryAccess)
local StoryConfig = require(game.ReplicatedStorage.StoryConfig)
local Remotes = require(game.ReplicatedStorage.Remotes)

local NAME = StoryConfig.Npcs.Oforian.name
local COLOR = StoryConfig.Npcs.Oforian.color

local function wire(dummy)
	if dummy.Name ~= "Dummy_Spawn" then return end
	local anchor = dummy.PrimaryPart or dummy:FindFirstChildWhichIsA("BasePart")
	if not anchor or anchor:FindFirstChild("VipGiftPrompt") then return end
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "VipGiftPrompt"
	prompt.ActionText = "คุยกับออฟาเรียน"
	prompt.ObjectText = NAME
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = anchor
	prompt.Triggered:Connect(function(player)
		if StoryAccess.TalkOforian then
			StoryAccess.TalkOforian(player)
		else
			Remotes.SocialNotify:FireClient(player, "warn", "ออฟาเรียนยังไม่ตื่น ลองใหม่อีกครั้ง")
		end
	end)
	-- ป้ายชื่อเหนือหัว (สตัด: เล็กลงตามระยะ) · ❗ ของเควสฟ้าวาดฝั่งไคลเอนต์ (StoryController)
	local cf, size = dummy:GetBoundingBox()
	local tag = Instance.new("BillboardGui")
	tag.Name = "OforianTag"
	tag.Size = UDim2.fromScale(7, 1.1)
	tag.StudsOffsetWorldSpace = Vector3.new(0, (cf.Position.Y + size.Y / 2) - anchor.Position.Y + 0.9, 0)
	tag.MaxDistance = 90
	tag.LightInfluence = 0
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.TextColor3 = COLOR
	label.TextStrokeTransparency = 0.4
	label.Text = NAME
	label.Parent = tag
	tag.Parent = anchor
end

-- ถามใหม่เรื่อยๆ (หุ่นถูกสร้างใหม่ได้ถ้ารันเฟส training_dummies ซ้ำ)
task.spawn(function()
	while true do
		for _, dummy in ipairs(CollectionService:GetTagged("WOLD_Dummy")) do
			wire(dummy)
		end
		task.wait(3)
	end
end)
