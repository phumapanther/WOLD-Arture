-- node tools/lua.js tests/quest_images_test.lua Edit
-- รูปบนใบประกาศบอร์ดเควสต้องโหลดได้จริงทุกรูป — decal ที่ถูก archive ทำให้รูปโหลดไม่ขึ้นเงียบๆ
-- (เจอจริง 2026-09-29: แมงมุมยักษ์ 132951908475043 จาก decal 122241010306288 ที่ถูก archive)
local AssetService = game:GetService("AssetService")

local function fresh(module)
	local copy = module:Clone()
	copy.Name = module.Name .. "_t" .. math.random(1, 1e9)
	copy.Parent = module.Parent
	local ok, result = pcall(require, copy)
	copy:Destroy()
	assert(ok, result)
	return result
end

local Q = fresh(game.ReplicatedStorage.QuestConfig)
local out, fails = {}, 0
local function check(ok, text)
	out[#out + 1] = (ok and "ok   " or "FAIL ") .. text
	if not ok then fails += 1 end
end

local function loads(image)
	local ok, img = pcall(function()
		return AssetService:CreateEditableImageAsync(Content.fromUri(image))
	end)
	if ok then img:Destroy() end
	return ok, not ok and tostring(img) or nil
end

local ok, err = loads(Q.NoticeImage)
check(ok, "ใบประกาศเปล่า " .. Q.NoticeImage .. (err and (" — " .. err) or ""))
for mob, image in pairs(Q.MobImages) do
	ok, err = loads(image)
	check(ok, mob .. " " .. image .. (err and (" — " .. err) or ""))
end
return (fails == 0 and "PASS\n" or ("FAIL x%d\n"):format(fails)) .. table.concat(out, "\n")
