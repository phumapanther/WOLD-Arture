-- ArmorVisuals.server.lua: ใส่เกราะแล้วเห็นเกราะบนตัวจริง
--
-- โมเดลเกราะสามชุดอยู่ใน `workspace.Model_Item` แต่ละชุดประกอบด้วยชิ้นส่วนที่ **ตั้งชื่อตามข้อต่อ R15**
-- (`Armor_UpperTorso`, `Armor_LeftHand`, ...) จึงสวมได้ด้วยการจับคู่ชื่อตรงๆ ไม่ต้องวัดตำแหน่งเอง
--
-- ชิ้นที่ไม่ตรงกับชื่อ R15 (`Armor_Seams`, `Armor_Pouch`, `Armor_Plume`, `Armor_SteamPlant`,
-- `Armor_Scabbard`, `Armor_Livery`) เป็นของตกแต่ง เชื่อมไว้กับลำตัวแทน — จะได้ติดตัวไปด้วยแทนที่จะถูกทิ้ง
--
-- **เชื่อมด้วย WeldConstraint ไม่ใช่ Motor6D**: เกราะไม่ต้องขยับข้อต่อของตัวเอง มันแค่ต้องติดไปกับ
-- ชิ้นส่วนที่มันสวมอยู่ ซึ่งขยับตามอนิเมชันอยู่แล้ว Motor6D จะทำให้ Animator พยายามขับมันด้วย
local Players = game:GetService("Players")

local ServerConfig = require(game.ServerScriptService.ServerConfig)
if ServerConfig.IsLobby then return end

local Inventory = require(game.ServerScriptService.Inventory)

--------------------------------------------------------------------------------
-- ชุดเกราะ
--------------------------------------------------------------------------------

-- ไอเทมในกระเป๋า -> ชื่อโมเดลชุดเกราะ
local KITS = {
	LeatherArmor = "Armor_LeatherKit",
	ChainmailArmor = "Armor_ChainKit",
	PlateArmor = "Armor_PlateKit",
}

local FOLDER_NAME = "WOLD_ArmorOn" -- ชื่อโฟลเดอร์ที่ห้อยอยู่ในตัวละคร

-- ชิ้นตกแต่งที่ไม่ตรงกับข้อต่อ R15 ไปเกาะกับอะไร
local DECOR_HOST = "UpperTorso"

--------------------------------------------------------------------------------
-- หาโมเดลต้นแบบ
--------------------------------------------------------------------------------

-- **ลูปถามใหม่ ไม่ใช่เก็บ reference ตอนบูต** เพลสนี้เปิด StreamingEnabled โฟลเดอร์กับโมเดลมาถึงคนละรอบ
-- การเก็บไว้ตอนเริ่มอาจได้ nil แล้วเงียบไปตลอดทั้งรอบ
local function kitModel(kitName)
	local folder = workspace:FindFirstChild("Model_Item")
	if not folder then return nil end
	local kit = folder:FindFirstChild(kitName)
	if kit and kit:IsA("Model") then return kit end
	return nil
end

--------------------------------------------------------------------------------
-- สวม / ถอด
--------------------------------------------------------------------------------

local function stripArmor(character)
	if not character then return end
	local worn = character:FindFirstChild(FOLDER_NAME)
	if worn then worn:Destroy() end
end

local function wearArmor(player, itemId)
	local character = player.Character
	if not character then return end
	stripArmor(character)

	local kitName = KITS[itemId]
	if not kitName then return end
	local kit = kitModel(kitName)
	if not kit then
		warn(("[ArmorVisuals] ไม่เจอโมเดล %s ใน workspace.Model_Item"):format(kitName))
		return
	end

	local kitRoot = kit:FindFirstChild("Root")
	if not kitRoot then
		warn(("[ArmorVisuals] %s ไม่มีชิ้น Root จึงวัดตำแหน่งไม่ได้"):format(kitName))
		return
	end

	local folder = Instance.new("Folder")
	folder.Name = FOLDER_NAME
	folder.Parent = character

	-- ตัวละครสูงเท่าไหร่เทียบกับชุดเกราะ
	--
	-- **ต้องย่อ/ขยายตามตัวจริง** ตัวละครโตขึ้นทุก 10 เลเวล (ProgressionConfig.ScaleForLevel) เกราะขนาด
	-- คงที่จะลอยห่างตัวหรือจมเข้าไปในตัวสำหรับคนที่ไม่ได้เลเวล 1 พอดี
	local _, charSize = character:GetBoundingBox()
	local _, kitSize = kit:GetBoundingBox()
	local scale = (kitSize.Y > 0) and (charSize.Y / kitSize.Y) or 1

	local decorHost = character:FindFirstChild(DECOR_HOST)
	local attached = 0

	for _, piece in ipairs(kit:GetChildren()) do
		if piece:IsA("Model") and piece.Name:sub(1, 6) == "Armor_" then
			local limbName = piece.Name:sub(7) -- ตัด "Armor_" ออก
			local host = character:FindFirstChild(limbName)
			local isDecor = false
			if not host then
				host = decorHost
				isDecor = true
			end

			if host and host:IsA("BasePart") then
				local clone = piece:Clone()
				if scale ~= 1 then
					local ok = pcall(function() clone:ScaleTo(scale) end)
					if not ok then scale = 1 end
				end

				-- ตำแหน่งเทียบกับข้อต่อที่มันสวม
				--
				-- ของตกแต่งใช้ระยะเทียบ Root ของชุด (มันไม่มีข้อต่อของตัวเอง) ส่วนชิ้นปกติวางทับข้อต่อ
				-- ตรงๆ เพราะโมเดลถูกปั้นมาตามสัดส่วน R15 อยู่แล้ว
				local pieceCF = piece:GetPivot()
				local offset
				if isDecor then
					local rel = pieceCF.Position - kitRoot.Position
					local kitTorso = kit:FindFirstChild("Armor_" .. DECOR_HOST)
					local torsoRel = kitTorso and (kitTorso:GetPivot().Position - kitRoot.Position) or Vector3.zero
					offset = CFrame.new((rel - torsoRel) * scale)
				else
					offset = CFrame.new()
				end

				clone:PivotTo(host.CFrame * offset)
				for _, d in ipairs(clone:GetDescendants()) do
					if d:IsA("BasePart") then
						d.Anchored = false
						d.CanCollide = false
						d.CanQuery = false
						d.CanTouch = false
						d.Massless = true
						local weld = Instance.new("WeldConstraint")
						weld.Part0 = host
						weld.Part1 = d
						weld.Parent = d
					end
				end
				clone.Parent = folder
				attached += 1
			end
		end
	end

	if attached == 0 then
		folder:Destroy()
	end
end

--------------------------------------------------------------------------------
-- ตามการใส่เกราะ
--------------------------------------------------------------------------------

-- **ไม่ได้ฟัง EquipmentChanged** เพราะมันเป็น remote ขาออก (server -> client) ฝั่งเซิร์ฟเวอร์ฟังไม่ได้
-- ลูปข้างล่างเป็นตัวจับการเปลี่ยนแปลงแทน ซึ่งทนกว่าอยู่แล้ว: มันตามทั้งการเปลี่ยนเกราะและการเกิดใหม่
-- ด้วยกลไกเดียวกัน

-- ลูปถามใหม่ทุกครึ่งวินาที
--
-- **กฎเหล็กของโปรเจ็คนี้** เกราะต้องมาหลังตัวละครประกอบเสร็จ และ EquipmentChanged อาจถูกยิงก่อนที่
-- ตัวละครจะมีแขนขาครบ การผูกครั้งเดียวจะแพ้จังหวะกับบางคน และเป็นคนละคนทุกรอบ
--
-- ตัวเทียบคือ "ใส่อะไรอยู่" เทียบกับ "วาดอะไรไว้" ถ้าตรงกันก็ไม่ทำอะไร จึงไม่ได้สร้างเกราะใหม่ทุกครึ่งวิ
local Drawn = {} -- [player] = itemId ที่วาดไว้แล้ว

task.spawn(function()
	while true do
		task.wait(0.5)
		for _, player in ipairs(Players:GetPlayers()) do
			local character = player.Character
			if character and character:FindFirstChild("HumanoidRootPart") then
				local _, entry = Inventory.EquippedArmor(player)
				local wanted = entry and entry.id or nil
				local shown = Drawn[player]
				-- ตัวละครใหม่ = โฟลเดอร์หายไปด้วย ต้องวาดใหม่แม้ไอเทมไม่เปลี่ยน
				local present = character:FindFirstChild(FOLDER_NAME) ~= nil
				if wanted ~= shown or (wanted and not present) then
					if wanted then wearArmor(player, wanted) else stripArmor(character) end
					Drawn[player] = wanted
				end
			end
		end
	end
end)

Players.PlayerRemoving:Connect(function(player)
	Drawn[player] = nil
end)
