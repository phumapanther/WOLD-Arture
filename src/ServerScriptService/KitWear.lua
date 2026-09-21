-- KitWear: สวม "ชุดคิท" (โมเดลชิ้นส่วนใน `Model_Item`) ลงบนตัวละคร R15
--
-- ยกออกมาจาก `ArmorVisuals.server.lua` ตอนที่ชุดแคลนต้องการกลไกเดียวกันเป๊ะ — สองระบบที่สวมชุดคนละชุดแต่
-- เชื่อมชิ้นส่วนแบบเดียวกัน ถ้าลอกโค้ดกันไว้คนละไฟล์ วันที่ต้องแก้เรื่องสเกลหรือของตกแต่ง จะแก้ที่เดียวแล้ว
-- อีกที่เงียบๆ ผิดต่อไป
--
-- โมเดลชุดประกอบด้วยชิ้นส่วนที่ **ตั้งชื่อตามข้อต่อ R15** (`Armor_UpperTorso`, `Armor_LeftHand`, ...) จึงสวมได้
-- ด้วยการจับคู่ชื่อตรงๆ ไม่ต้องวัดตำแหน่งเอง ชิ้นที่ไม่ตรงกับชื่อ R15 (`Armor_Seams`, `Armor_Plume`, ...)
-- เป็นของตกแต่ง เชื่อมไว้กับลำตัวแทน
--
-- **เชื่อมด้วย WeldConstraint ไม่ใช่ Motor6D**: ชุดไม่ต้องขยับข้อต่อของตัวเอง มันแค่ต้องติดไปกับชิ้นส่วนที่มัน
-- สวมอยู่ ซึ่งขยับตามอนิเมชันอยู่แล้ว Motor6D จะทำให้ Animator พยายามขับมันด้วย
local KitWear = {}

local DECOR_HOST = "UpperTorso" -- ชิ้นตกแต่งที่ไม่ตรงกับข้อต่อ R15 ไปเกาะกับอะไร

-- **หมวก/เกราะหัวใหญ่กว่าชิ้นอื่น** (ผู้ใช้สั่ง 2026-09-21)
--
-- ชิ้นที่สวมหัวถูกปั้นมาพอดีกับ "หัว R15 เปล่าๆ" แต่ตัวละครจริงมีผมของ Roblox (Accessory) โผล่พ้นหัว
-- ขึ้นไปเสมอ และชุดแฟชั่นบางชุดก็มีผมติดมากับสกิน หมวกขนาดพอดีหัวจึงครอบไม่มิดทุกครั้ง ผมทะลุออกข้าง
--
-- ขยายรอบ **จุดกึ่งกลางหัว** ไม่ใช่ยกขึ้น: ชิ้นถูก `PivotTo` ไปที่ CFrame ของพาร์ท Head พอดี การ
-- `ScaleTo` จึงโตออกทุกทิศเท่าๆ กันรอบจุดนั้น — บนพอจะกลืนผม ข้างพอจะกลืนหู
--
-- **ตัวเลขเดียวคุมทั้งเกม** ทั้งเกราะสามชุด ชุดแฟชั่นจากกาชา และชุดแคลน ล้วนผ่าน KitWear.Wear ตัวนี้
-- อยากให้ใหญ่กว่านี้อีกแก้บรรทัดเดียว (1.0 = กลับไปเท่าชิ้นอื่น · 2.0 = เท่าตัว)
--
-- ที่มาของ 1.5: หัว R15 กว้าง 1.20 studs ส่วนชิ้นสวมหัวในคิททั้งห้าชุดกว้าง 1.3-1.7 คือแค่ "พอดีหัว"
-- คูณ 1.5 ได้ราว 2.0-2.5 ซึ่งพอจะกลืนทรงผมของ Roblox ที่ยื่นพ้นหัวขึ้นไปราวหนึ่ง stud
local HEAD_SCALE = 1.5
local HEAD_LIMB = "Head"

-- **ลูปถามใหม่ ไม่ใช่เก็บ reference ตอนบูต** เพลสนี้เปิด StreamingEnabled โฟลเดอร์กับโมเดลมาถึงคนละรอบ
-- การเก็บไว้ตอนเริ่มอาจได้ nil แล้วเงียบไปตลอดทั้งรอบ
--
-- **หาใน `ServerStorage.Model_Item` ก่อน `workspace.Model_Item`** ต้นแบบชุดไม่ได้เป็นของในโลก มันมีไว้ให้
-- โคลนอย่างเดียว อยู่ใน workspace เมื่อไหร่ผู้เล่นก็เห็นมันยืนอยู่ตรงนั้น (ชุดแฟชั่นสามชุดเคยอยู่ที่พิกัด
-- 0,0,0 ซึ่งผิวดินอยู่ y=56 จึงโผล่ "ใต้โลก") — ฝั่ง workspace ยังหาอยู่เพื่อให้ชุดที่ผู้ใช้วางเองในแมพใช้ได้
local ServerStorage = game:GetService("ServerStorage")

function KitWear.Model(kitName)
	for _, parent in ipairs({ ServerStorage, workspace }) do
		local folder = parent:FindFirstChild("Model_Item")
		local kit = folder and folder:FindFirstChild(kitName)
		if kit and kit:IsA("Model") then return kit end
	end
	return nil
end

function KitWear.Strip(character, folderName)
	if not character then return end
	local worn = character:FindFirstChild(folderName)
	if worn then worn:Destroy() end
end

-- คืน true ถ้าสวมได้จริง (มีชิ้นส่วนเกาะอย่างน้อยหนึ่งชิ้น)
function KitWear.Wear(character, kitName, tint, folderName)
	if not character or not kitName then return false end
	KitWear.Strip(character, folderName)

	local kit = KitWear.Model(kitName)
	if not kit then
		warn(("[KitWear] ไม่เจอโมเดล %s ใน ServerStorage.Model_Item หรือ workspace.Model_Item"):format(kitName))
		return false
	end
	local kitRoot = kit:FindFirstChild("Root")
	if not kitRoot then
		warn(("[KitWear] %s ไม่มีชิ้น Root จึงวัดตำแหน่งไม่ได้"):format(kitName))
		return false
	end

	local folder = Instance.new("Folder")
	folder.Name = folderName
	folder.Parent = character

	-- ตัวละครสูงเท่าไหร่เทียบกับชุด
	--
	-- **ต้องย่อ/ขยายตามตัวจริง** ตัวละครโตขึ้นทุก 10 เลเวล (ProgressionConfig.ScaleForLevel) ชุดขนาดคงที่
	-- จะลอยห่างตัวหรือจมเข้าไปในตัวสำหรับคนที่ไม่ได้เลเวล 1 พอดี
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
				-- หัวได้ตัวคูณเพิ่มจาก `scale` ของทั้งชุด ไม่ใช่แทนที่ — ชุดยังต้องย่อ/ขยายตามตัวละคร
				-- ที่โตขึ้นทุก 10 เลเวลเหมือนเดิม หมวกแค่โตกว่าชิ้นอื่นในชุดเดียวกัน
				local pieceScale = scale
				if not isDecor and limbName == HEAD_LIMB then pieceScale = scale * HEAD_SCALE end
				if pieceScale ~= 1 then
					local ok = pcall(function() clone:ScaleTo(pieceScale) end)
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
				if tint then
					for _, d in ipairs(clone:GetDescendants()) do
						if d:IsA("BasePart") then d.Color = tint end
					end
				end
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
		return false
	end
	return true
end

return KitWear
