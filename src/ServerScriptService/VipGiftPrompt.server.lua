-- VipGiftPrompt: ปุ่ม E "รับของขวัญ" บนหุ่นฟางข้างจุดเกิดแรก (`Dummy_Spawn` จาก mapgen/training_dummies.lua)
-- กติกาทั้งหมดอยู่ที่ `VipGift` (150 เพชรบัญชีใหม่ · VIP 30 วันที่ Lv.5 · ออร่าสุ่มเมื่อมีเพื่อน 5 คน)
-- ป้ายปุ่ม/ซ่อนปุ่มรายคนทำที่ `VipGiftController.client` จากแอตทริบิวต์ที่ไฟล์นี้ประกาศ (เซิร์ฟเวอร์ห้ามแตะ Enabled หลังสร้าง)
-- เกมหลักเท่านั้น: อยู่ใน globIgnorePaths ของ farming/arena
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")

local ServerConfig = require(script.Parent.ServerConfig)
if ServerConfig.IsLobby then return end -- ล็อบบี้ไม่โหลดโปรไฟล์

local ProfileAccess = require(script.Parent.ProfileAccess)
local Vip = require(script.Parent.Vip)
local VipGift = require(script.Parent.VipGift)
local Progression = require(script.Parent.Progression)
local Friends = require(script.Parent.Friends)
local Inventory = require(script.Parent.Inventory)
local PremiumAccess = require(script.Parent.PremiumAccess)
local ItemCatalog = require(game.ReplicatedStorage.ItemCatalog)
local Remotes = require(game.ReplicatedStorage.Remotes)

local MESSAGES = {
	closed = "หมดเขตแจกของขวัญแล้ว",
	loading = "ข้อมูลตัวละครยังโหลดไม่เสร็จ ลองใหม่อีกครั้ง",
}

-- ออร่าทุกชิ้นที่มีในเกมตอนนี้ (ผู้ใช้สั่ง "สุ่มออร่าที่มีในปัจจุบัน") — อ่านจากแคตตาล็อก ออร่าใหม่เข้าสระเอง
local AURAS = {}
for id, item in pairs(ItemCatalog.Items) do
	if type(item) == "table" and item.kind == "aura" then AURAS[#AURAS + 1] = id end
end
table.sort(AURAS)

local rng = Random.new()

local function hasPremium(player)
	return PremiumAccess.HasPremiumPass ~= nil and PremiumAccess.HasPremiumPass(player) == true
end

local function friendCount(player)
	local state = Friends.Get(player)
	local n = 0
	for _ in pairs(state and state.friends or {}) do n += 1 end
	return n
end

-- ไคลเอนต์อ่านสองค่านี้: เหลือของให้รับอีกกี่อย่าง (0 = ซ่อนปุ่ม) กับป้ายบนปุ่มของคนคนนี้
local function publish(player)
	local data = ProfileAccess.Get(player)
	if not data then return end
	local s = VipGift.Summary(data, os.time(), Progression.GetLevel(player), friendCount(player), AURAS, hasPremium(player))
	local left = #s.ready + #s.waiting
	local text = #s.ready > 0 and ("รับ " .. table.concat(s.ready, " + ")) or "ดูของขวัญ"
	if player:GetAttribute("WOLD_GiftLeft") ~= left then player:SetAttribute("WOLD_GiftLeft", left) end
	if player:GetAttribute("WOLD_GiftText") ~= text then player:SetAttribute("WOLD_GiftText", text) end
end

local function onTriggered(player)
	local data = ProfileAccess.Get(player)
	if not VipGift.Enabled or not data then
		return Remotes.SocialNotify:FireClient(player, "error", MESSAGES[VipGift.Enabled and "loading" or "closed"])
	end
	local now, level, friends = os.time(), Progression.GetLevel(player), friendCount(player)
	local got = {}

	-- 150 เพชร (บัญชีใหม่)
	local gemsOk = VipGift.ClaimGems(data, function(n)
		return PremiumAccess.AddGems ~= nil and PremiumAccess.AddGems(player, n) == true
	end)
	if gemsOk then got[#got + 1] = ("💎 %d เพชร"):format(VipGift.Gems) end

	-- แบทเทิลพาสพรีเมียมเดือนนี้ (บัญชีใหม่)
	local passOk = VipGift.ClaimPass(data, hasPremium(player), function()
		return PremiumAccess.GrantPremiumPass ~= nil and PremiumAccess.GrantPremiumPass(player) == true
	end)
	if passOk then got[#got + 1] = "🎫 แบทเทิลพาสพรีเมียมเดือนนี้ (เปิดที่เมนู ⋯ → 🎫 แบทเทิลพาส)" end

	-- VIP 30 วัน (Lv.5)
	if VipGift.Claim(data, now, level) then
		Vip.Publish(player)
		got[#got + 1] = ("VIP %d วัน (เข้าเกาะฟาร์มได้จากล็อบบี้)"):format(VipGift.Days)
	end

	-- ออร่าสุ่ม (เพื่อน 5 คน) · กระเป๋าเต็ม = ยังไม่เสียสิทธิ์
	local bagFull = false
	local auraOk, auraId = VipGift.ClaimAura(data, friends, AURAS, rng, function(id)
		if not Inventory.HasRoomFor(player, id, 1) then return false end
		return Inventory.AddItem(player, id, 1) == true
	end)
	if auraOk then
		local item = ItemCatalog.Get(auraId)
		got[#got + 1] = ("✨ %s"):format(item and item.name or auraId)
	elseif auraId == "full" then
		bagFull = true
	end

	local after = VipGift.Summary(data, now, level, friends, AURAS, hasPremium(player))
	if #got > 0 then
		print(("[SpawnGift] %s (%d) รับ %s"):format(player.Name, player.UserId, table.concat(got, ", ")))
		Remotes.SocialNotify:FireClient(player, "info", "ได้รับ " .. table.concat(got, " · "))
	end
	if bagFull then
		Remotes.SocialNotify:FireClient(player, "error", "กระเป๋าเต็ม — เคลียร์ช่องแล้วกลับมารับออร่า")
	end
	if #after.waiting > 0 then
		Remotes.SocialNotify:FireClient(player, #got > 0 and "info" or "warn", "ของขวัญที่ยังรอ: " .. table.concat(after.waiting, " · "))
	elseif #got == 0 and not bagFull then
		Remotes.SocialNotify:FireClient(player, "info", "รับของขวัญจากหุ่นฟางครบแล้ว")
	end
	publish(player)
end

local function wire(dummy)
	if dummy.Name ~= "Dummy_Spawn" then return end
	local anchor = dummy.PrimaryPart or dummy:FindFirstChildWhichIsA("BasePart")
	if not anchor or anchor:FindFirstChild("VipGiftPrompt") then return end
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "VipGiftPrompt"
	prompt.ActionText = "รับของขวัญ"
	prompt.ObjectText = "ของขวัญหุ่นฟาง"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = anchor
	CollectionService:AddTag(prompt, "WOLD_VipGiftPrompt")
	prompt.Triggered:Connect(onTriggered)
end

-- ถามใหม่เรื่อยๆ: หุ่นถูกสร้างใหม่ได้ถ้ารันเฟส training_dummies ซ้ำ · โปรไฟล์โหลดเสร็จไม่พร้อมกัน ·
-- เลเวล/จำนวนเพื่อนเปลี่ยนระหว่างเล่น (ป้ายปุ่มตามทันภายใน 3 วิ)
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
