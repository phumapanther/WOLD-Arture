-- node tools/lua.js tests/arena_teams_test.lua Edit
-- คิว PVP (QA 2026-09-26): 3 ปาร์ตี้สองคนเคยทำคิวค้างถาวร · กติกาผู้ใช้: "ค้นหาก่อนเจอกันก่อน ตี้ที่กดช้าหาต่อไป"
local function fresh(module)
	local copy = module:Clone()
	copy.Name = module.Name .. "_t" .. math.random(1, 1e9)
	copy.Parent = module.Parent
	local ok, result = pcall(require, copy)
	copy:Destroy()
	assert(ok, result)
	return result
end

local ArenaTeams = fresh(game.ServerScriptService.Lobby.ArenaTeams)
local out, fails = {}, 0
local function check(ok, text)
	out[#out + 1] = (ok and "ok   " or "FAIL ") .. text
	if not ok then fails += 1 end
end

-- ปาร์ตี้ปลอม: สมาชิกเป็นแค่ชื่อ · ลำดับในรายการ = ลำดับที่กดเล่น
local function party(name, size)
	local members = {}
	for i = 1, size do members[i] = name .. i end
	return { name = name, members = members }
end
local function names(list)
	local t = {}
	for _, e in ipairs(list) do t[#t + 1] = e.name end
	return table.concat(t, ",")
end

-- 1) บั๊กเดิม: สามคู่ → สองคู่แรกได้ไป (A/B) คู่ที่สามรอต่อ ไม่ค้างทั้งคิว
local chosen, teams = ArenaTeams.Assign({ party("p1", 2), party("p2", 2), party("p3", 2) }, 3)
check(names(chosen) == "p1,p2", "สามคู่: สองคู่แรกได้ไป คู่ที่สามรอ (" .. names(chosen) .. ")")
check(#teams.A == 2 and #teams.B == 2, "ทีมละ 2 (เติมบอททีมละ 1 เมื่อครบเวลา)")

-- 2) คู่ที่สามค้างอยู่ แล้วคนเดี่ยวสองคนมา → ครบ 6 ได้ (คู่ที่ถูกข้ามรอบก่อน ยังได้ไปก่อนคนมาทีหลังในรอบถัดไป)
chosen, teams = ArenaTeams.Assign({ party("p3", 2), party("s1", 1), party("s2", 1), party("s3", 1), party("s4", 1) }, 3)
check(#teams.A + #teams.B == 6 and chosen[1].name == "p3", "คู่ที่รอ + คนเดี่ยว = ครบหกคน คู่ที่รอได้ไปก่อน")

-- 3) เจอก่อนได้ไปก่อน: คนมาก่อนอยู่ฝั่ง A เสมอ แล้วสลับฝั่ง
chosen, teams = ArenaTeams.Assign({ party("a", 1), party("b", 1), party("c", 1) }, 3)
check(teams.A[1] == "a1" and teams.B[1] == "b1" and teams.A[2] == "c1", "สลับฝั่ง A, B, A ตามลำดับที่มา")

-- 4) ปาร์ตี้ไม่ถูกหั่นข้ามทีม: สามคนเต็มทีม สองคู่ถัดมา = ลงได้คู่เดียว อีกคู่รอ
chosen, teams = ArenaTeams.Assign({ party("t", 3), party("d1", 2), party("d2", 2) }, 3)
check(names(chosen) == "t,d1" and #teams.A == 3 and #teams.B == 2, "ปาร์ตี้สามคนเต็มฝั่งหนึ่ง คู่แรกได้ไป คู่สองรอ")
local seen, dup = {}, false
for _, side in ipairs({ "A", "B" }) do
	for _, member in ipairs(teams[side]) do
		if seen[member] then dup = true end
		seen[member] = true
	end
end
check(not dup, "ไม่มีใครถูกนับสองทีม")

-- 5) คิวว่าง / ปาร์ตี้ใหญ่เกินทีม = ไม่ได้ไป ไม่พัง
chosen = ArenaTeams.Assign({}, 3)
check(#chosen == 0, "คิวว่าง = ไม่มีใครได้ไป")
chosen = ArenaTeams.Assign({ party("big", 4), party("s", 1) }, 3)
check(names(chosen) == "s", "ปาร์ตี้เกินทีมถูกข้าม คนถัดไปยังได้ไป")

out[#out + 1] = fails == 0 and ("ผ่านทั้งหมด %d ข้อ"):format(#out) or ("ตก %d ข้อ"):format(fails)
return table.concat(out, "\n")
