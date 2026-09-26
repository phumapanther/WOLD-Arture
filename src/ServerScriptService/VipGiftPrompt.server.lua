-- VipGiftPrompt: ปุ่ม E "รับ VIP 30 วัน" บนหุ่นฟางข้างจุดเกิดแรก (`Dummy_Spawn` จาก mapgen/training_dummies.lua)
-- กติกาทั้งหมดอยู่ที่ `VipGift` · ซ่อนปุ่มรายคนที่ `VipGiftController.client` (เซิร์ฟเวอร์ห้ามแตะ Enabled หลังสร้าง)
-- เกมหลักเท่านั้น: อยู่ใน globIgnorePaths ของ farming/arena
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")

local ServerConfig = require(script.Parent.ServerConfig)
if ServerConfig.IsLobby then return end -- ล็อบบี้ไม่โหลดโปรไฟล์

local ProfileAccess = require(script.Parent.ProfileAccess)
local Vip = require(script.Parent.Vip)
local VipGift = require(script.Parent.VipGift)
local Remotes = require(game.ReplicatedStorage.Remotes)

local MESSAGES = {
	closed = "หมดเขตแจก VIP แล้ว",
	loading = "ข้อมูลตัวละครยังโหลดไม่เสร็จ ลองใหม่อีกครั้ง",
	claimed = "บัญชีนี้รับ VIP จากหุ่นฟางไปแล้ว (รับได้บัญชีละครั้ง)",
	active = "มี VIP อยู่แล้ว — กลับมารับได้หลัง VIP หมดอายุ",
}

-- ไคลเอนต์อ่านธงนี้คู่กับ `VipUntil` (Vip.Publish) เพื่อซ่อนปุ่ม
local function publish(player)
	local data = ProfileAccess.Get(player)
	if data then player:SetAttribute("WOLD_VipGiftClaimed", data.VipGiftClaimed == true) end
end

local function onTriggered(player)
	local ok, reason = VipGift.Claim(ProfileAccess.Get(player), os.time())
	if ok then
		Vip.Publish(player)
		publish(player)
		print(("[VipGift] %s (%d) รับ VIP %d วัน"):format(player.Name, player.UserId, VipGift.Days))
		Remotes.SocialNotify:FireClient(player, "info",
			("ได้รับ VIP %d วัน! เข้าเกาะฟาร์มได้จากล็อบบี้"):format(VipGift.Days))
	else
		Remotes.SocialNotify:FireClient(player, "error", MESSAGES[reason] or "รับไม่ได้")
	end
end

local function wire(dummy)
	if dummy.Name ~= "Dummy_Spawn" then return end
	local anchor = dummy.PrimaryPart or dummy:FindFirstChildWhichIsA("BasePart")
	if not anchor or anchor:FindFirstChild("VipGiftPrompt") then return end
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "VipGiftPrompt"
	prompt.ActionText = ("รับ VIP %d วัน"):format(VipGift.Days)
	prompt.ObjectText = "ของขวัญผู้มาใหม่"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = anchor
	CollectionService:AddTag(prompt, "WOLD_VipGiftPrompt")
	prompt.Triggered:Connect(onTriggered)
end

-- ถามใหม่เรื่อยๆ: หุ่นถูกสร้างใหม่ได้ถ้ารันเฟส training_dummies ซ้ำ · โปรไฟล์โหลดเสร็จไม่พร้อมกัน
task.spawn(function()
	while true do
		for _, dummy in ipairs(CollectionService:GetTagged("WOLD_Dummy")) do
			wire(dummy)
		end
		for _, player in ipairs(Players:GetPlayers()) do
			publish(player)
		end
		task.wait(3)
	end
end)
