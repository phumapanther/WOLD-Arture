-- node tools/lua.js tests/island_node_caps_test.lua Edit
-- เพดานของสุ่มบนผืนดิน (ผู้ใช้สั่ง 2026-10-01 ลดครึ่ง): รวม 75 · แร่ (รวมหิน) 25 · พุ่ม 25 · ต้นไม้ 25
-- กลุ่มเต็ม = สุ่มจากกลุ่มที่ยังว่าง · ของที่เกินอยู่แล้วไม่ลบ แค่หยุดเกิด
local function fresh(module)
	local copy = module:Clone()
	copy.Name = module.Name .. "_t" .. math.random(1, 1e9)
	copy.Parent = module.Parent
	local ok, result = pcall(require, copy)
	copy:Destroy()
	assert(ok, result)
	return result
end

local C = fresh(game.ReplicatedStorage.IslandConfig)
local NS = C.NodeSpawn
local out, fails = {}, 0
local function check(ok, text)
	out[#out + 1] = (ok and "ok   " or "FAIL ") .. text
	if not ok then fails += 1 end
end

check(NS.max == 75, "เพดานรวม 75")
check(NS.groupMax.ore == 25 and NS.groupMax.bush == 25 and NS.groupMax.tree == 25, "แร่/พุ่ม/ต้นไม้ อย่างละ 25")

-- ทุกชนิดที่สุ่มได้ต้องอยู่ในกลุ่มใดกลุ่มหนึ่ง (ชนิดใหม่ที่ลืมใส่กลุ่มจะไม่มีเพดาน)
local missing = {}
for kind in pairs(NS.weights) do
	if not NS.groupOf[kind] then table.insert(missing, kind) end
end
check(#missing == 0, "ทุกชนิดมีกลุ่ม " .. table.concat(missing, ","))
check(NS.groupOf.Rock == "ore" and NS.groupOf.Coal == "ore" and NS.groupOf.DiamondOre == "ore", "หิน/ถ่าน/แร่ = กลุ่มแร่")
check(NS.groupOf.Herb == "bush" and NS.groupOf.Tree == "tree", "สมุนไพร = พุ่ม · ต้นไม้ = ต้นไม้")

local function kinds(w)
	local t = {}
	for k in pairs(w) do t[k] = true end
	return t
end

local all = kinds(C.NodeWeightsOpen({}))
check(all.Tree and all.Herb and all.Rock and all.DiamondOre, "ยังไม่มีอะไร = สุ่มได้ทุกชนิด")

local noTree = kinds(C.NodeWeightsOpen({ tree = 25 }))
check(not noTree.Tree and noTree.Herb and noTree.Rock, "ต้นไม้ครบ 25 = ไม่สุ่มต้นไม้ แต่ยังได้พุ่ม/แร่")

local noOre = kinds(C.NodeWeightsOpen({ ore = 40 }))
check(not noOre.Rock and not noOre.Coal and not noOre.GoldOre and noOre.Tree and noOre.Herb,
	"แร่เกินอยู่แล้ว (40 จากเพดานเก่า) = ไม่สุ่มหิน/แร่ใดๆ")

check(next(C.NodeWeightsOpen({ ore = 25, bush = 25, tree = 25 })) == nil, "ครบทุกกลุ่ม = ไม่มีอะไรให้สุ่ม")

return (fails == 0 and "PASS\n" or ("FAIL x%d\n"):format(fails)) .. table.concat(out, "\n")
