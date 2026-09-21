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

-- **ชิ้นสวมหัววัดจากหัวจริง ไม่ได้ย่อตามความสูงของทั้งชุด** (ผู้ใช้สั่ง 2026-09-21)
--
-- ⚠️ **ต้นเหตุที่หมวกเคยครอบหัวไม่มิด ไม่ใช่ว่าโมเดลปั้นมาเล็ก — มันถูกย่อทิ้ง** สเกลของทั้งชุดคือ
-- `charSize.Y / kitSize.Y` และคิททุกชุดถูกปั้นมาสูง 6.3-6.8 studs ขณะที่ตัวละคร R15 มาตรฐานสูงราว 5.0
-- สเกลจริงจึงเป็น **0.74-0.80 คือย่อลง** ชิ้นหมวกที่ปั้นไว้ 1.32 กว้าง เหลือ 0.97 ซึ่ง **เล็กกว่าหัว
-- R15 (1.20)** หมวกจึงจมอยู่ในหัวมาตลอด ไม่ใช่แค่ครอบไม่มิด
--
-- ตัวคูณคงที่แก้ไม่ตรงจุด เพราะตัวละครแต่ละคนสูงไม่เท่ากัน สเกลของชุดจึงต่างกันไปด้วย เลขที่พอดีกับ
-- อวตารสูง 5.0 จะกลายเป็นถังครอบหัวบนอวตารสูง 6.5
--
-- **วิธีที่ถูกคือวัดจากพาร์ท Head ของคนนั้นตรงๆ**: ย่อ/ขยายชิ้นหมวกให้ด้านที่แคบที่สุดในแนวนอน
-- (X หรือ Z อันไหนแคบกว่า) กว้างกว่าหัวตามสัดส่วนข้างล่าง — ผลคือหมวก "พอดีหัว ห่างออกมานิดหนึ่ง"
-- เท่ากันทุกชุดและทุกขนาดตัว โดยไม่ต้องแก้โมเดลสักชุด
--
-- ใช้ด้าน **แคบที่สุด** ไม่ใช่กว้างที่สุด เพราะหมวกหลายใบยาวไปทาง Z (บังตา/ท้ายทอย) การวัดจากด้านยาว
-- จะย่อทั้งใบจนด้านกว้างกลับไปเล็กกว่าหัวอีก · และ **ไม่ใช้แกน Y** เพราะหมวกหนังตั้งใจให้เตี้ยกว่าหัว
-- (มันเป็นแก๊ป ไม่ใช่หมวกเหล็ก) การบังคับความสูงจะทำให้มันกลายเป็นถัง
local HEAD_CLEARANCE = 1.15 -- หมวกกว้างกว่าหัว 15% = ห่างจากผิวหัวราว 0.09 studs ต่อข้าง
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
				-- ชิ้นสวมหัว **ไม่ใช้สเกลของทั้งชุด** มันวัดจากพาร์ท Head ของตัวละครคนนั้นแทน
				-- (ดูเหตุผลที่ HEAD_CLEARANCE) ชิ้นอื่นยังย่อ/ขยายตามชุดเหมือนเดิมทุกชิ้น
				local pieceScale = scale
				if not isDecor and limbName == HEAD_LIMB then
					local _, pieceSize = piece:GetBoundingBox()
					local narrow = math.min(pieceSize.X, pieceSize.Z)
					if narrow > 0 then
						pieceScale = (math.max(host.Size.X, host.Size.Z) * HEAD_CLEARANCE) / narrow
					end
				end
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
