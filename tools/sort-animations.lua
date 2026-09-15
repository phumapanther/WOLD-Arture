-- tools/sort-animations.lua — แยกท่าที่ยังไม่ได้อัปออกจากท่าที่อัปแล้ว
--
--   node tools/lua.js tools/sort-animations.lua Edit
--
-- ท่าที่ยังไม่มี id ในคอนฟิกจะถูกย้ายเข้า ServerStorage.WOLD_Animations.New_Animations
-- ท่าที่มี id แล้วจะถูกย้ายกลับออกมาไว้ชั้นนอก
--
-- ตัดสินจาก **คอนฟิก** ไม่ใช่จากรายชื่อที่เขียนไว้ในนี้ เพราะคำถามที่ต้องตอบคือ "ท่านี้อัปแล้วหรือยัง" ซึ่ง
-- คำตอบมีอยู่ที่เดียวคือช่อง anim ในคอนฟิกนั้นว่างหรือเปล่า รันซ้ำได้เรื่อยๆ หลังอัปแต่ละตัว แล้วมันจะย้าย
-- ตัวที่เพิ่งอัปออกมาให้เอง
local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local folder = ServerStorage:FindFirstChild("WOLD_Animations")
if not folder then return "ไม่พบ ServerStorage.WOLD_Animations" end

local pending = folder:FindFirstChild("New_Animations")
if not pending then
	pending = Instance.new("Folder")
	pending.Name = "New_Animations"
	pending.Parent = folder
end

-- อ่านคอนฟิกจากสำเนาสด: require ใน Edit mode คืนของที่แคชไว้ข้ามการเรียกคนละครั้ง
local function fresh(name)
	local src = ReplicatedStorage:FindFirstChild(name)
	if not src then return nil end
	local clone = src:Clone()
	clone.Name = name .. "_SortProbe_" .. tostring(os.clock()):gsub("%.", "")
	clone.Parent = ReplicatedStorage
	local ok, mod = pcall(require, clone)
	clone:Destroy()
	return ok and mod or nil
end

local EmoteConfig = fresh("EmoteConfig")
local VitalsConfig = fresh("VitalsConfig")

-- ชื่อ sequence -> id ในคอนฟิก: ตัดคำนำหน้า Emote_ / Conv_ แล้วทำเป็นตัวเล็ก
-- (Emote_CrossLegged -> crosslegged, Conv_FloorFaint -> floorfaint)
local function emoteIdFor(name)
	local bare = name:match("^Emote_(.+)$") or name:match("^Conv_(.+)$")
	return bare and bare:lower() or nil
end

local uploaded = {}   -- [emote id] = true ถ้ามี id แล้ว
if EmoteConfig then
	for _, e in ipairs(EmoteConfig.Emotes) do
		uploaded[e.id] = e.anim ~= ""
	end
end

-- ท่าที่ชื่อกับ id เดากันไม่ได้ตรงๆ ต้องบอกไว้ที่นี่
--
-- สองแบบ: ท่าที่ไม่ได้อยู่ในระบบท่าทางเลย (Dizzy_Loop มีคอนฟิกของตัวเอง) กับ **ท่าที่ชื่อชนกัน** —
-- Conv_Bow กับ Emote_Bow ตัดคำนำหน้าแล้วได้ "bow" เหมือนกันทั้งคู่ พอ id ของ bow ถูกเติม ตัวแยกก็คิดว่า
-- ทั้งสองตัวอัปแล้ว ทั้งที่อัปไปตัวเดียว การเดาจากชื่อจึงไม่พอ ต้องระบุ
local special = {
	Dizzy_Loop = VitalsConfig and VitalsConfig.DizzyAnimation ~= "" or false,
}

-- ท่าที่ id ในคอนฟิกไม่ตรงกับชื่อที่ตัดคำนำหน้าแล้ว
local renamed = {
	-- ท่าแปลงที่อัปคู่กับตัวปั้นเอง จึงมีแถวของตัวเองในคอนฟิก ชื่อกับ id เลยไม่ตรงกันตรงๆ
	Conv_Scared = "scared2",
	Conv_Bow = "bow2",
	Conv_Crouch = "squat2",
}

local function isUploaded(name)
	if special[name] ~= nil then return special[name] end
	local id = renamed[name] or emoteIdFor(name)
	if id == nil then
		-- ไม่ใช่ท่าที่เจนจาก animgen รอบนี้ (ดาบ ธนู กลิ้ง สไลด์ ฯลฯ) อัปไปหมดแล้วตั้งแต่ก่อนหน้า
		return true
	end
	-- ชื่อที่ไม่มีแถวในคอนฟิกเลย (เช่น Conv_Crouch ที่เอาไว้เทียบ) ถือว่ายังไม่ได้อัป
	if uploaded[id] == nil then return false end
	return uploaded[id]
end

local moved, promoted = {}, {}
local function sweep(from, wantUploaded)
	for _, seq in ipairs(from:GetChildren()) do
		if seq:IsA("KeyframeSequence") then
			local up = isUploaded(seq.Name)
			if up ~= wantUploaded then
				seq.Parent = wantUploaded and pending or folder
				table.insert(wantUploaded and moved or promoted, seq.Name)
			end
		end
	end
end
sweep(folder, true)      -- ชั้นนอกควรมีแต่ท่าที่อัปแล้ว
sweep(pending, false)    -- New_Animations ควรมีแต่ท่าที่ยังไม่อัป

local stillIn, outside = {}, {}
for _, s in ipairs(pending:GetChildren()) do table.insert(stillIn, s.Name) end
for _, s in ipairs(folder:GetChildren()) do
	if s:IsA("KeyframeSequence") then table.insert(outside, s.Name) end
end
table.sort(stillIn) table.sort(outside)

return table.concat({
	("ย้ายเข้า New_Animations: %s"):format(#moved > 0 and table.concat(moved, ", ") or "-"),
	("ย้ายออกมา (อัปแล้ว): %s"):format(#promoted > 0 and table.concat(promoted, ", ") or "-"),
	"",
	("ยังไม่ได้อัป %d ท่า:"):format(#stillIn),
	"  " .. table.concat(stillIn, ", "),
	"",
	("อัปแล้ว %d ท่า:"):format(#outside),
	"  " .. table.concat(outside, ", "),
}, "\n")
