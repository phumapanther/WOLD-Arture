-- node tools/lua.js tests/starter_kit_test.lua Edit
-- ของเปิดตัวผู้เล่นใหม่ (ผู้ใช้สั่งเช็คทุกเงื่อนไข 2026-09-26): ได้ครั้งเดียวต่อบัญชี และไม่มีอาวุธ/เกราะต่อสู้
local function fresh(module)
	local copy = module:Clone()
	copy.Name = module.Name .. "_t" .. math.random(1, 1e9)
	copy.Parent = module.Parent
	local ok, result = pcall(require, copy)
	copy:Destroy()
	assert(ok, result)
	return result
end

local StarterKit = fresh(game.ServerScriptService.StarterKit)
local ItemCatalog = fresh(game.ReplicatedStorage.ItemCatalog)
local out, fails = {}, 0
local function check(ok, text)
	out[#out + 1] = (ok and "ok   " or "FAIL ") .. text
	if not ok then fails += 1 end
end

-- โปรไฟล์ใหม่เอี่ยม: ทุกช่องเป็น nil ตามแม่แบบของ PlayerProfile
check(StarterKit.ShouldGive({}, nil) == true, "บัญชีใหม่เอี่ยม = ได้ของเปิดตัว")
check(StarterKit.ShouldGive(nil, nil) == false, "โหลดโปรไฟล์ไม่สำเร็จ = ไม่แจก (จดไม่ได้ว่าแจกแล้ว)")
check(StarterKit.ShouldGive({ StarterKit = true }, nil) == false, "ได้ไปแล้ว (ธง) = ไม่แจกซ้ำ แม้พิกัดยังไม่เคยเซฟ")
check(StarterKit.ShouldGive({}, {}) == false, "มีกระเป๋าที่เซฟไว้ (แม้ว่างเปล่า) = คนเก่า")
check(StarterKit.ShouldGive({ Position = { x = 0, y = 0, z = 0 } }, nil) == false, "บัญชีเก่าก่อนมีธง มีพิกัด = คนเก่า")

-- เข้าเกาะเป็นที่แรก: เกาะไม่เซฟพิกัด — รอบแรกได้ แล้วธงกันรอบถัดไป (เดิมได้ทุกครั้งที่เข้าเกาะ)
local islandFirst = {}
check(StarterKit.ShouldGive(islandFirst, nil) == true, "เข้าเกาะเป็นที่แรก ครั้งแรก = ได้")
islandFirst.StarterKit = true
check(StarterKit.ShouldGive(islandFirst, nil) == false, "เข้าเกาะครั้งที่สอง (ยังไม่มีพิกัดเมือง) = ไม่ได้ซ้ำ")

-- เนื้อในชุด: มีเครื่องมือครบสามอย่าง และไม่มีของต่อสู้เลย (อาวุธที่ไม่ใช่เครื่องมือ/คันเบ็ด หรือเกราะ)
local have, combat = {}, {}
for _, entry in ipairs(StarterKit.Items) do
	local item = ItemCatalog.Get(entry.id)
	check(item ~= nil, "ของในชุดมีอยู่จริงในแคตตาล็อก: " .. entry.id)
	have[entry.id] = true
	if item and (item.kind == "armor" or (item.kind == "weapon" and not item.gathers and entry.id ~= "FishingRod")) then
		table.insert(combat, entry.id)
	end
end
check(have.Axe and have.Shovel and have.Pickaxe and have.FishingRod, "มีขวาน พลั่ว อีเต้อ คันเบ็ด ครบ")
check(#combat == 0, "ไม่มีอาวุธ/เกราะต่อสู้ในชุด" .. (#combat > 0 and (": " .. table.concat(combat, ",")) or ""))

table.insert(out, fails == 0 and ("ผ่านทั้งหมด %d ข้อ"):format(#out) or ("ตก %d ข้อ"):format(fails))
return table.concat(out, "\n")
