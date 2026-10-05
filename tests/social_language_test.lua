-- node tools/lua.js tests/social_language_test.lua Edit   (เพลสไหนก็ได้)
-- หน้าตั้งค่าหินเวทมีปุ่มเลือกภาษาสี่ปุ่ม ป้ายเขียนด้วยภาษานั้นเอง (ระบบหลายภาษา เฟส 1 · 2026-10-05)
local mirror = Instance.new("Folder")
mirror.Name = "SocialLangMirror"
mirror.Sandboxed = true
mirror.Capabilities = SecurityCapabilities.new(Enum.SecurityCapability.Basic, Enum.SecurityCapability.CreateInstances,
	Enum.SecurityCapability.UI, Enum.SecurityCapability.RunServerScript, Enum.SecurityCapability.Input, Enum.SecurityCapability.LegacySound)
mirror.Parent = game.ServerStorage
game.ReplicatedStorage.UI:Clone().Parent = mirror
for _, m in ipairs(game.ReplicatedStorage:GetChildren()) do
	if (m:IsA("ModuleScript") and m.Name ~= "Remotes") or m.Name == "LocaleData" then m:Clone().Parent = mirror end
end

local out, fails = {}, 0
local function check(ok, text)
	out[#out + 1] = (ok and "ok   " or "FAIL ") .. text
	if not ok then fails += 1 end
end

local ok, err = pcall(function()
	local SocialGui = require(mirror.UI.SocialGui)
	local gui = SocialGui.new()
	local buttons = gui.languageButtons
	check(type(buttons) == "table", "มีตารางปุ่มภาษา")
	if type(buttons) ~= "table" then return end
	for id, label in pairs({ th = "ไทย", en = "English", zh = "简体中文", ja = "日本語" }) do
		check(buttons[id] and buttons[id].Text == label, "ปุ่ม " .. id .. " = " .. label)
		check(buttons[id] and buttons[id]:IsDescendantOf(gui.screens.settings), "ปุ่ม " .. id .. " อยู่ในหน้าตั้งค่า")
	end
	local picked
	gui:On("language", function(lang) picked = lang end)
	gui.pickLanguage("ja")
	check(picked == "ja", "เลือกภาษา → callback ได้ ja")
	gui.gui:Destroy()
end)
mirror:Destroy()
if not ok then out[#out + 1] = "ERROR " .. tostring(err) fails += 1 end
return (fails == 0 and "PASS\n" or ("FAIL x%d\n"):format(fails)) .. table.concat(out, "\n")
