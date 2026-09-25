-- node tools/lua.js tests/charm_sources_test.lua Edit
-- เครื่องรางคุ้มครอง (2026-09-25): บอสโลกอันดับ 1-5 ได้แน่นอน · แบทเทิลพาสแจก (ฟรีขั้น 17 · พรีเมียมขั้น 14, 24)
local function fresh(module)
	local copy = module:Clone()
	copy.Name = module.Name .. "_t" .. math.random(1, 1e9)
	copy.Parent = module.Parent
	local ok, result = pcall(require, copy)
	copy:Destroy()
	assert(ok, result)
	return result
end
local RS = game.ReplicatedStorage
local EventConfig, PremiumConfig = fresh(RS.EventConfig), fresh(RS.PremiumConfig)
local out, fails = {}, 0
local function check(ok, text)
	out[#out + 1] = (ok and "ok   " or "FAIL ") .. text
	if not ok then fails += 1 end
end
local WB = EventConfig.WorldBoss
check(WB.CharmTopRanks == 5 and WB.CharmItem == "GuardianCharm", "บอสโลกอันดับ 1-5 ได้เครื่องราง")
local function isCharm(r) return r and r.item == "GuardianCharm" and r.count == 1 end
check(isCharm(PremiumConfig.Pass.Free[17]), "พาสฟรีขั้น 17 = เครื่องราง")
check(isCharm(PremiumConfig.Pass.Premium[14]) and isCharm(PremiumConfig.Pass.Premium[24]), "พาสพรีเมียมขั้น 14, 24 = เครื่องราง")
return (fails == 0 and "PASS\n" or ("FAIL x%d\n"):format(fails)) .. table.concat(out, "\n")
