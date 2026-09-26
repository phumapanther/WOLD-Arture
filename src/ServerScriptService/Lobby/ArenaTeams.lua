-- ArenaTeams: จัดปาร์ตี้ในคิว PVP ลงสองทีม — ตรรกะล้วน แยกจาก ArenaQueue ให้เทสได้ใน Edit (tests/arena_teams_test.lua)
--
-- **เจอก่อน ได้ไปก่อน · เรียงตามลำดับที่เข้าคิว แล้วสลับฝั่ง** (ผู้ใช้กำหนด 2026-09-24 / 2026-09-26)
-- ปาร์ตี้ที่รอนานที่สุด = "ฝั่งเรา" (A) คนถัดมาไปฝั่งตรงข้าม (B) แล้วสลับไปเรื่อยๆ · ปาร์ตี้ไม่ถูกหั่นข้ามทีม:
-- ฝั่งที่ถึงคิวใส่ไม่พอ ลองอีกฝั่ง · **ใส่ไม่ลงทั้งสองฝั่ง = ข้ามไป รอแมตช์หน้าต่อ** (ไม่ขวางคนข้างหลัง)
--
-- ⚠️ ของเดิมหยิบตามจำนวนคนรวมก่อน (2+2+2 = 6) แล้วค่อยจัดทีม ซึ่งจัดไม่ลง → ส่งไม่ได้ → รอบหน้าหยิบชุดเดิม
-- ไม่เคยถึงทางเติมบอท = **คิวค้างถาวร** ทุกคนข้างหลังค้างด้วย (QA 2026-09-26) · ตอนนี้หยิบกับจัดทีมคือการตัดสินเดียวกัน
local ArenaTeams = {}

-- entries = { { members = {…} }, … } เรียงจากรอนานสุด · คืน (ก้อนที่ได้ไป ตามลำดับเดิม, { A = {…}, B = {…} })
function ArenaTeams.Assign(entries, teamSize)
	local teams = { A = {}, B = {} }
	local chosen = {}
	local nextSide = "A"
	for _, entry in ipairs(entries) do
		local n = #entry.members
		local other = (nextSide == "A") and "B" or "A"
		local target = (#teams[nextSide] + n <= teamSize) and nextSide
			or ((#teams[other] + n <= teamSize) and other or nil)
		if target then
			for _, member in ipairs(entry.members) do table.insert(teams[target], member) end
			table.insert(chosen, entry)
			nextSide = (target == "A") and "B" or "A"
		end
	end
	return chosen, teams
end

return ArenaTeams
