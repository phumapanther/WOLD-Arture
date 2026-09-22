-- 94_island_questboard.lua — บอร์ดเควสบนเกาะ = บอร์ดรวมของสมาคม
--
--     WOLD_PLACE=136992335889132 node tools/run-luau.js mapgen/94_island_questboard.lua --no-lib
--
-- **ไม่สร้างโมเดล ไม่ย้ายโมเดล** ผู้ใช้วาง `Guild_QuestBoard` ไว้บนเกาะเองแล้ว เฟสนี้แค่ติดแท็กกับ
-- `BoardId` ให้ ตำแหน่งจึงเป็นของผู้ใช้ตลอด — ลากย้ายในสตูดิโอได้โดยไม่ต้องรันอะไรซ้ำ
--
-- **BoardId = MainGuild (บอร์ดรวม) ไม่ใช่บอร์ดเมืองใดเมืองหนึ่ง**
--
-- บอร์ดประจำเมืองสุ่มงานจากคลังของตัวเอง ซึ่งผูกกับสิ่งที่หาได้ในเมืองนั้น (บอร์ดเหมืองให้งานขุด
-- บอร์ดประมงให้งานตกปลา) เกาะไม่ใช่เมืองไหนเลย มันมีทั้งแปลงผัก บ่อปลา โซนแร่ และต้นไม้ปนกัน
-- การเลือกคลังเมืองใดเมืองหนึ่งจึงตัดงานอีกห้าเมืองทิ้งโดยไม่มีเหตุผล
--
-- บอร์ดรวมแสดง **งานชุดเดียวกับที่บอร์ดประจำเมืองแสดงอยู่ในวันนั้น** (ไม่มีคลังของตัวเอง) ผู้เล่นจึงเห็น
-- ใบเดียวกันทั้งในเกมหลักและบนเกาะ · และเพราะสิทธิ์ "รับแล้ว/ส่งแล้ววันนี้" เก็บอยู่ในโปรไฟล์ซึ่งเป็น
-- DataStore ก้อนเดียวกันทั้งจักรวาล งานที่รับจากเกมหลักจึงขึ้นว่ารับแล้วที่นี่ทันที โดยไม่ต้องเขียนอะไรเพิ่ม
local CollectionService = game:GetService("CollectionService")

local BOARD_TAG = "WOLD_QuestBoard"
local BOARD_ID = "MainGuild" -- ตรงกับ QuestConfig.MainBoardId
local NAMES = { "MainGuild_QuestBoard", "Guild_QuestBoard" }

assert(game.PlaceId == 136992335889132 or game.PlaceId == 0, "เฟสนี้สำหรับเพลสเกาะเท่านั้น")

local function status(msg, done)
	local f = workspace:FindFirstChild("WOLD")
	if not f then f = Instance.new("Folder"); f.Name = "WOLD"; f.Parent = workspace end
	f:SetAttribute("Progress", msg)
	f:SetAttribute("Status", done and "done" or "running")
	print("[IslandQuest] " .. msg)
end

local board
for _, name in ipairs(NAMES) do
	local m = workspace:FindFirstChild(name)
	if m and m:IsA("Model") then board = m break end
end

if not board then
	status("ไม่เจอโมเดลบอร์ด (" .. table.concat(NAMES, " / ") .. ") บนเกาะ", true)
	return
end

board:SetAttribute("BoardId", BOARD_ID)
if not CollectionService:HasTag(board, BOARD_TAG) then
	CollectionService:AddTag(board, BOARD_TAG)
end

local p = board:GetPivot().Position
status(("done: %s เป็นบอร์ดรวม ที่ (%.0f, %.0f, %.0f)"):format(board.Name, p.X, p.Y, p.Z), true)
