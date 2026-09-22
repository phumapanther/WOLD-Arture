-- 95_island_water_level.lua — ปรับผิวน้ำบนเกาะให้เรียบเป็นระนาบเดียว
--
--     WOLD_PLACE=136992335889132 node tools/run-luau.js mapgen/95_island_water_level.lua --no-lib
--
-- **แตะเฉพาะ voxel ที่เป็นน้ำอยู่แล้ว ไม่ขุดดิน ไม่เติมดิน** บ่อที่ผู้ใช้ขุดไว้เองยังเป็นรูปเดิมทุกประการ
-- เฟสนี้เปลี่ยนแค่ "น้ำเต็มถึงระดับไหน" — ดินกับหินไม่ถูกเขียนทับแม้แต่ voxel เดียว
--
-- ⚠️ **อย่าเผลอใช้ FillBlock/FillCylinder กับบ่อนี้** สองตัวนั้นเขียนทับทุกอย่างในกรอบ รวมถึงหินที่ผู้ใช้
-- แต่งไว้ก้นบ่อ (บทเรียน 2026-09-22: FillCylinder ที่หมุนผิดแกนเจาะเกาะทะลุถึงชั้นหินมาแล้ว)
-- ตัวที่ปลอดภัยคือ ReadVoxels/WriteVoxels ซึ่งอ่านของเดิมมาก่อนแล้วเขียนกลับเฉพาะช่องที่ตั้งใจ
--
-- ## ทำไมผิวน้ำถึงไม่เรียบตั้งแต่แรก
--
-- วัดก่อนแก้: ผิวน้ำอยู่ **ห้าระดับ** ตั้งแต่ y=798 ถึง 814 (ห่างกัน 16 studs) และ **249 จาก 444**
-- voxel ผิวมี occupancy ไม่เต็ม (เฉลี่ย 0.71) — ซึ่งคือสิ่งที่ทำให้มันดูหยักเป็นคลื่นแทนที่จะเป็นแผ่นเรียบ
-- เครื่องมือ Terrain ในสตูดิโอวาดน้ำตามรูปพู่กัน ไม่ได้ปรับระดับให้เอง
--
-- ## ระดับที่เลือก
--
-- y = 808 มาจากการวัดขอบบ่อจริง 152 จุด (ไม่ใช่เลขที่ตั้งเอง):
--   · ดินรอบบ่อต่ำสุด 804.7 · เปอร์เซ็นไทล์ที่ 10 อยู่ที่ 810.9
--   · ตั้งที่ 808 → ดินรอบบ่อจมน้ำ **1 จาก 152 จุด** · ตั้งที่ 810 → จม 7 จุด
-- สูงกว่านี้เริ่มกินชายฝั่ง ต่ำกว่านี้บ่อจะตื้นลงโดยไม่จำเป็น
local T = workspace.Terrain

local LEVEL = 808 -- ระดับผิวน้ำเป้าหมาย
local RES = 4 -- ขนาด voxel ของ Terrain
local BOUNDS = { x0 = -180, x1 = 40, z0 = -200, z1 = 100, y0 = 772, y1 = 836 }
local CHUNK = 64 -- อ่าน/เขียนทีละก้อน กัน Region3 ใหญ่เกิน

assert(game.PlaceId == 136992335889132 or game.PlaceId == 0, "เฟสนี้สำหรับเพลสเกาะเท่านั้น")

local function status(msg, done)
	local f = workspace:FindFirstChild("WOLD")
	if not f then f = Instance.new("Folder"); f.Name = "WOLD"; f.Parent = workspace end
	f:SetAttribute("Progress", msg)
	f:SetAttribute("Status", done and "done" or "running")
	print("[IslandWater] " .. msg)
end

-- **โหมดล้างน้ำทิ้ง** ตั้งแอตทริบิวต์ `IslandWaterErase = true` บน workspace แล้วรันซ้ำ
-- (เผื่อผู้ใช้อยากรื้อแล้วขุดใหม่เอง — ไม่ต้องมาแก้ไฟล์)
local ERASE = workspace:GetAttribute("IslandWaterErase") == true

local air = Enum.Material.Air
local water = Enum.Material.Water

local changed, kept, drained, filled = 0, 0, 0, 0

for bx = BOUNDS.x0, BOUNDS.x1 - 1, CHUNK do
	for bz = BOUNDS.z0, BOUNDS.z1 - 1, CHUNK do
		local x1 = math.min(bx + CHUNK, BOUNDS.x1)
		local z1 = math.min(bz + CHUNK, BOUNDS.z1)
		local region = Region3.new(
			Vector3.new(bx, BOUNDS.y0, bz),
			Vector3.new(x1, BOUNDS.y1, z1)
		):ExpandToGrid(RES)
		local mats, occs = T:ReadVoxels(region, RES)
		local sx, sy, sz = mats.Size.X, mats.Size.Y, mats.Size.Z
		local touched = false

		for i = 1, sx do
			for k = 1, sz do
				-- คอลัมน์นี้เป็นส่วนหนึ่งของบ่อไหม — ดูว่ามีน้ำอยู่แล้วหรือเปล่า
				-- **ตัดสินจากคอลัมน์ ไม่ใช่จาก voxel เดี่ยว** ไม่งั้นช่องอากาศเหนือผิวน้ำเดิมจะไม่มีใครเติม
				local hasWater = false
				for j = 1, sy do
					if mats[i][j][k] == water then hasWater = true break end
				end

				if hasWater then
					for j = 1, sy do
						local y = region.CFrame.Position.Y - region.Size.Y / 2 + (j - 0.5) * RES
						local m = mats[i][j][k]
						if ERASE then
							if m == water then mats[i][j][k], occs[i][j][k] = air, 0; drained += 1; touched = true end
						elseif y <= LEVEL then
							-- ใต้ระดับผิว: เป็นน้ำเต็มช่อง **ยกเว้นช่องที่เป็นดิน/หินอยู่แล้ว**
							-- (ก้อนหินที่ผู้ใช้วางไว้ก้นบ่อต้องไม่กลายเป็นน้ำ)
							if m == air or m == water then
								if m ~= water or occs[i][j][k] < 1 then
									mats[i][j][k], occs[i][j][k] = water, 1
									if m ~= water then filled += 1 end
									changed += 1
									touched = true
								else
									kept += 1
								end
							else
								kept += 1
							end
						else
							-- เหนือระดับผิว: ไม่ควรมีน้ำค้างอยู่
							if m == water then
								mats[i][j][k], occs[i][j][k] = air, 0
								drained += 1
								changed += 1
								touched = true
							end
						end
					end
				end
			end
		end

		if touched then T:WriteVoxels(region, RES, mats, occs) end
	end
end

if ERASE then
	status(("done: ล้างน้ำออก %d voxel (ตั้ง IslandWaterErase = false แล้วรันใหม่เพื่อเติมกลับ)"):format(drained), true)
else
	status(("done: ผิวน้ำเรียบที่ y=%d · แก้ %d voxel (เติม %d · ระบายออก %d · ของเดิมคงไว้ %d)")
		:format(LEVEL, changed, filled, drained, kept), true)
end
