-- QA UI harness step 1: clone ReplicatedStorage.UI → UI_QA, patch sources for an emulated device, construct every
-- GUI module, move each ScreenGui's content into a W×H emulation frame. Results kept in _G.QA for step 2.
-- _G.QA_CFG = { name, w, h, touch, keyboard } must be set by the caller (prepended line).
local RS = game:GetService("ReplicatedStorage")
local SG = game:GetService("StarterGui")
local cfg = _G.QA_CFG
local TOPBAR = 58

for _, n in ipairs({ "UI_QA" }) do local o = RS:FindFirstChild(n) if o then o:Destroy() end end
for _, n in ipairs({ "QA_Host", "QA_Out" }) do local o = SG:FindFirstChild(n) if o then o:Destroy() end end

local function patch(src)
	src = src:gsub("game%.Players%.LocalPlayer", "_G.QA_PLAYER")
	src = src:gsub("Players%.LocalPlayer", "_G.QA_PLAYER")
	src = src:gsub("[%w_]+%.TouchEnabled", "_G.QA_TOUCH")
	src = src:gsub("[%w_]+%.KeyboardEnabled", "_G.QA_KEYBOARD")
	src = src:gsub("[%w_]+:IsRunning%(%)", "true")
	src = src:gsub("[%w_%.]+%.ViewportSize", "_G.QA_VIEWPORT")
	src = src:gsub("%.UI%.", ".UI_QA.")
	src = src:gsub("WaitForChild%(\"UI\"%)", "WaitForChild(\"UI_QA\")")
	return src
end

local clone = RS.UI:Clone()
clone.Name = "UI_QA"
for _, m in ipairs(clone:GetDescendants()) do
	if m:IsA("ModuleScript") then m.Source = patch(m.Source) end
end
clone.Parent = RS

local out = Instance.new("Folder")
out.Name = "QA_Out"
out.Parent = SG

local function sig()
	return { Connect = function() return { Disconnect = function() end } end, Wait = function() end, Once = function() end }
end
_G.QA_PARENT = out
_G.QA_TOUCH = cfg.touch
_G.QA_KEYBOARD = cfg.keyboard
_G.QA_VIEWPORT = Vector2.new(cfg.w, cfg.h)
_G.QA_PLAYER = setmetatable({ Name = "QA", DisplayName = "QA", UserId = 1 }, { __index = function(_, k)
	if k == "WaitForChild" or k == "FindFirstChild" or k == "FindFirstChildOfClass" or k == "FindFirstChildWhichIsA" then
		return function(_, n) if n == "PlayerGui" then return out end return nil end
	end
	if k == "GetAttribute" then return function() return nil end end
	if k == "SetAttribute" then return function() end end
	if k == "GetAttributeChangedSignal" or k == "GetPropertyChangedSignal" then return function() return sig() end end
	if k == "CharacterAdded" or k == "CharacterRemoving" or k == "AttributeChanged" or k == "Changed" then return sig() end
	if k == "GetMouse" then return function() return { X = 0, Y = 0 } end end
	if k == "IsA" then return function() return false end end
	return nil
end })

local function withTimeout(fn, seconds)
	local done, res, err = false, nil, nil
	local th = task.spawn(function()
		local ok, r = pcall(fn)
		done = true
		if ok then res = r else err = r end
	end)
	local t0 = os.clock()
	while not done and os.clock() - t0 < seconds do task.wait(0.03) end
	if not done then pcall(task.cancel, th) return nil, "TIMEOUT" end
	return res, err
end

local ARGS = {
	DiscordGui = { "https://discord.gg/x" },
	LobbyButton = { "QA_LobbyStone", 1, nil, "🔮", function() return true end, function() end },
	StoryGui = { out },
	IslandBuildGui = { out },
}
local SKIP = { PvpPartyGui = true } -- built by ChannelSelectGui itself

local report = {}
local objs = {}
local owners = {} -- [ScreenGui] = module name
for _, m in ipairs(clone:GetChildren()) do
	if m:IsA("ModuleScript") and not SKIP[m.Name] then
		local before = {}
		for _, d in ipairs(out:GetDescendants()) do before[d] = true end
		local mod, err = withTimeout(function() return require(m) end, 2)
		if type(mod) == "table" and type(mod.new) == "function" then
			local args = ARGS[m.Name] or {}
			local obj, err2 = withTimeout(function() return mod.new(table.unpack(args)) end, 3)
			if err2 then report[#report + 1] = ("ERR %s.new: %s"):format(m.Name, tostring(err2):sub(1, 140)) end
			-- ScreenGuis the controller would parent itself: find them in the returned object
			local seen = {}
			local function adopt(v, depth)
				if typeof(v) == "Instance" then
					local sgui = v:IsA("ScreenGui") and v or v:FindFirstAncestorWhichIsA("ScreenGui")
					if sgui and not sgui:IsDescendantOf(out) then sgui.Parent = out end
				elseif type(v) == "table" and depth < 2 and not seen[v] then
					seen[v] = true
					for _, x in pairs(v) do adopt(x, depth + 1) end
				end
			end
			adopt(obj, 0)
			objs[m.Name] = obj
		elseif err then
			report[#report + 1] = ("ERR require %s: %s"):format(m.Name, tostring(err):sub(1, 140))
		end
		for _, d in ipairs(out:GetDescendants()) do
			if not before[d] and d:IsA("ScreenGui") and not owners[d] then owners[d] = m.Name end
		end
	end
end

-- emulation host
local host = Instance.new("ScreenGui")
host.Name = "QA_Host"
host.IgnoreGuiInset = true
host.Parent = SG

local guis = {}
for sg, owner in pairs(owners) do
	local emu = Instance.new("Frame")
	emu.Name = owner .. "::" .. sg.Name
	emu.BackgroundTransparency = 1
	if sg.IgnoreGuiInset then
		emu.Position = UDim2.fromOffset(0, 0)
		emu.Size = UDim2.fromOffset(cfg.w, cfg.h)
	else
		emu.Position = UDim2.fromOffset(0, TOPBAR)
		emu.Size = UDim2.fromOffset(cfg.w, cfg.h - TOPBAR)
	end
	emu.Parent = host
	local info = { sg = sg, owner = owner, name = sg.Name, order = sg.DisplayOrder, inset = sg.IgnoreGuiInset,
		enabled = sg.Enabled, emu = emu, tops = {} }
	local seenNames = {}
	for _, c in ipairs(sg:GetChildren()) do
		if c:IsA("GuiObject") then
			if seenNames[c.Name] then c.Name = c.Name .. "#" .. (#info.tops + 1) end
			seenNames[c.Name] = true
			info.tops[#info.tops + 1] = { name = c.Name, visible = c.Visible }
			c.Visible = true
		end
		c.Parent = emu
	end
	guis[#guis + 1] = info
end
table.sort(guis, function(a, b) return a.emu.Name < b.emu.Name end)
_G.QA = { cfg = cfg, guis = guis, report = report, objs = objs }
-- typical in-game state so conditional HUD pieces exist
local function try(label, fn) local ok, e = pcall(fn) if not ok then report[#report + 1] = "STATE " .. label .. ": " .. tostring(e):sub(1, 120) end end
try("hotbar", function()
	local e = {}
	for i = 1, 6 do e[i] = { id = "Bread", name = "ขนมปัง", icon = "rbxassetid://1", count = 3 } end
	objs.HudGui:SetHotbar(e)
end)
try("buffs", function() objs.HudGui:SetBuffs({ noHunger = 60, noStamina = 60, noHp = -1 }) end)
try("exp", function() objs.HudGui:SetExp(12, 0.5) end)
try("party", function() objs.PartyGui:SetMembers({ { name = "เพื่อนหนึ่ง", hp = 0.8, hunger = 0.6, userId = 2 }, { name = "เพื่อนสอง", hp = 0.5, hunger = 0.9, userId = 3 } }) end)
try("event", function() objs.EventBannerGui:Set({ worldboss = { title = "บอสโลกตื่นแล้ว", text = "ฟอร์จวอร์เดน", endsAt = os.time() + 1800, colour = Color3.new(1, 0.6, 0.2), hp = { current = 8000, maximum = 12000 } } }) end)
try("feed", function() objs.BoardFeedGui:Add({ id = 1, author = "QA", name = "QA", text = "ประกาศทดสอบบอร์ด", message = "ประกาศทดสอบบอร์ด" }) end)
if cfg.arena then
	try("arena", function()
		objs.HudGui:SetArenaMode()
		objs.TouchActionGui:SetArenaMode(function() end)
		objs.ArenaHudGui:SetDamageCards({ { name = "บอทหนึ่ง", damage = 45, hits = 2 }, { name = "บอทสอง", damage = 20, hits = 1 } })
	end)
end
for _, g in ipairs(guis) do g.order = g.sg.DisplayOrder end
try("story", function() objs.StoryGui:SetTracker({ chapter = "c1", name = "ความทรงจำแรก", step = 2, steps = 5, goal = "คุยกับไลรา" }) end)
task.wait(0.2)
report[#report + 1] = ("built %d screenguis"):format(#guis)
for _, g in ipairs(guis) do
	local tops = {}
	for _, t in ipairs(g.tops) do tops[#tops + 1] = t.name .. (t.visible and "" or "(hidden)") end
	report[#report + 1] = ("%s DO=%d inset=%s enabled=%s tops=%s"):format(g.emu.Name, g.order, tostring(g.inset),
		tostring(g.enabled), table.concat(tops, ","))
end
return table.concat(report, "\n")
