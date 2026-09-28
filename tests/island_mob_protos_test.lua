-- node tools/lua.js tests/island_mob_protos_test.lua Edit                                (เพลสหลัก = ต้นฉบับ)
-- WOLD_PLACE=136992335889132 node tools/lua.js tests/island_mob_protos_test.lua Edit   (เพลสเกาะ)
-- มอนบุกเกาะ (2026-09-28): ทุกชนิดใน IslandConfig.NightRaid มีต้นแบบให้ Mobs (ไม่งั้นได้ลูกบอลสไลม์เขียวทุกตัว)
-- พิมพ์จำนวนชิ้น/ขนาดไว้เทียบสองเพลส
local ServerStorage = game:GetService("ServerStorage")
local function fresh(module)
	local copy = module:Clone()
	copy.Name = module.Name .. "_t" .. math.random(1, 1e9)
	copy.Parent = module.Parent
	local ok, result = pcall(require, copy)
	copy:Destroy()
	assert(ok, result)
	return result
end
local GatherConfig = fresh(game.ReplicatedStorage.GatherConfig)
local R = fresh(game.ReplicatedStorage.IslandConfig).NightRaid

local kinds = {}
for _, tier in ipairs(R.pools) do for _, k in ipairs(tier.kinds) do kinds[#kinds + 1] = k end end
for _, k in ipairs(R.specials) do kinds[#kinds + 1] = k end
kinds[#kinds + 1] = R.boss.kind

local out, fails = {}, 0
for _, kind in ipairs(kinds) do
	local model = GatherConfig.Mobs[kind].model
	if model then -- สไลม์เขียวไม่มีโมเดล (Mobs.buildSlime ปั้นเอง)
		local found
		for _, name in ipairs({ "Model_moster", "Model_mosterV2", "New_moster" }) do
			local f = ServerStorage:FindFirstChild(name)
			found = found or (f and f:FindFirstChild(model))
		end
		if found then
			local parts = 0
			for _, p in ipairs(found:GetDescendants()) do if p:IsA("BasePart") then parts += 1 end end
			local _, size = found:GetBoundingBox()
			out[#out + 1] = ("ok   %-24s %3d ชิ้น %5.1f x %5.1f x %5.1f"):format(model, parts, size.X, size.Y, size.Z)
		else
			fails += 1
			out[#out + 1] = "FAIL ไม่มีต้นแบบ " .. model
		end
	end
end
return (fails == 0 and "PASS\n" or ("FAIL x%d\n"):format(fails)) .. table.concat(out, "\n")
