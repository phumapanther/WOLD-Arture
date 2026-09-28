-- QA UI harness step 2: read _G.QA (built by ui_build.lua) and report overlaps / offscreen / small taps / small text
local QA = _G.QA
local objs = QA.objs or {}
local cfg = QA.cfg
local W, H = cfg.w, cfg.h
local TOPBAR = 58
local lines = {}
local function add(s) lines[#lines + 1] = s end

-- which ScreenGuis are always-on HUD in the main game (conditional ones included: party bar, event banner, story tracker)
local HUD = {
	["HudGui::HudGui"] = true, ["TutorialGui::TutorialGui"] = "TopRight", ["TouchActionGui::TouchActionGui"] = cfg.touch,
	["PartyGui::PartyGui"] = true, ["EventBannerGui::EventBannerGui"] = true, ["BoardFeedGui::BoardFeedGui"] = true,
}
local LOBBY = { ["ChannelSelectGui::ChannelSelectGui"] = true, ["LobbyButton::QA_LobbyStone"] = true }
local SKIP = { ["LoadingGui::LoadingGui"] = true, ["ScopeGui::WOLD_Scope"] = true,
	["KillBannerGui::WOLD_KillBanner"] = true }
HUD["StoryGui::WOLD_Story"] = "tracker"
if cfg.arena then
	HUD = { ["HudGui::HudGui"] = true, ["TutorialGui::TutorialGui"] = "TopRight", ["TouchActionGui::TouchActionGui"] = cfg.touch,
		["ArenaHudGui::ArenaHudGui"] = true }
end

local function rect(o)
	local p, s = o.AbsolutePosition, o.AbsoluteSize
	return { x = p.X, y = p.Y, w = s.X, h = s.Y }
end
local function inter(a, b)
	local x1, y1 = math.max(a.x, b.x), math.max(a.y, b.y)
	local x2, y2 = math.min(a.x + a.w, b.x + b.w), math.min(a.y + a.h, b.y + b.h)
	if x2 <= x1 or y2 <= y1 then return nil end
	return { x = x1, y = y1, w = x2 - x1, h = y2 - y1 }
end
local function fullscreen(r) return r.w >= W * 0.9 and r.h >= H * 0.9 end
local function cut(s, n) local ok, i = pcall(utf8.offset, s, n + 1) if ok and i then return s:sub(1, i - 1) end return s end
local function fmt(r) return ("(%d,%d %dx%d)"):format(r.x, r.y, r.w, r.h) end

local function hasContent(o)
	if o.BackgroundTransparency < 0.95 then return true end
	if (o:IsA("TextLabel") or o:IsA("TextButton") or o:IsA("TextBox")) and o.Text ~= "" and o.TextTransparency < 1 then return true end
	if (o:IsA("ImageLabel") or o:IsA("ImageButton")) and o.Image ~= "" and o.ImageTransparency < 1 then return true end
	return false
end

-- walk an emulation frame: returns list of { o, r (clipped), path, depth, top, interactive, text }
local function collect(g)
	local items = {}
	local function walk(o, clip, depth, top, path, scale)
		if not o:IsA("GuiObject") then return end
		if not o.Visible then return end
		local r = rect(o)
		local shown = clip and inter(r, clip) or r
		if not shown then return end
		local uis = o:FindFirstChildWhichIsA("UIScale")
		local s = scale * (uis and uis.Scale or 1)
		local item = { o = o, r = shown, full = r, path = path, depth = depth, top = top,
			interactive = (o:IsA("GuiButton") or o:IsA("TextBox")) and o.Active ~= false and o.Interactable ~= false,
			content = hasContent(o), scroll = clip ~= nil and clip.scroll, scale = s }
		items[#items + 1] = item
		local nextClip = clip
		if o.ClipsDescendants or o:IsA("ScrollingFrame") then
			nextClip = inter(r, clip or r) or r
			nextClip.scroll = (clip and clip.scroll) or o:IsA("ScrollingFrame")
		end
		for _, c in ipairs(o:GetChildren()) do
			walk(c, nextClip, depth + 1, top, path .. "/" .. c.Name, s)
		end
	end
	local base = g.emu:FindFirstChildWhichIsA("UIScale")
	for _, c in ipairs(g.emu:GetChildren()) do
		walk(c, nil, 1, c.Name, c.Name, base and base.Scale or 1)
	end
	return items
end

local screen = { x = 0, y = 0, w = W, h = H }
local zones = { { name = "ปุ่ม Roblox มุมซ้ายบน", r = { x = 0, y = 0, w = 200, h = TOPBAR } } }
if cfg.touch then
	local small = math.min(W, H) <= 500
	local js = small and 70 or 120
	zones[#zones + 1] = { name = "ปุ่มกระโดด", r = { x = W - 193 - js, y = H - 30 - js, w = js, h = js } }
	zones[#zones + 1] = { name = "จอยตอนพัก", r = small and { x = 15, y = H - 110, w = 100, h = 100 } or { x = 50, y = H - 215, w = 140, h = 135 } }
end

local all = {}
for _, g in ipairs(QA.guis) do
	local key = g.emu.Name
	if not SKIP[key] then
		all[#all + 1] = { g = g, key = key, items = collect(g) }
	end
end

add(("== %s %dx%d touch=%s"):format(cfg.name, W, H, tostring(cfg.touch)))

-- 1) HUD groups and their content bbox
local hudGroups = {}
for _, e in ipairs(all) do
	local sel = HUD[e.key] or (LOBBY[e.key] and true)
	local ctx = LOBBY[e.key] and "lobby" or "game"
	if sel then
		local groups = {}
		for _, it in ipairs(e.items) do
			local seg2 = it.path:match("^([^/]+/[^/]+)") or it.path
			local isTracker = sel == "tracker" and objs.StoryGui and objs.StoryGui.tracker and (it.o == objs.StoryGui.tracker or it.o:IsDescendantOf(objs.StoryGui.tracker))
			if it.content and it.top ~= "Blackout" and not fullscreen(it.full) and (sel == true or it.top == sel or isTracker) then
				local gk = e.key .. "|" .. (e.key == "HudGui::HudGui" and seg2 or (isTracker and "Tracker" or it.top))
				groups[gk] = groups[gk] or { key = gk, sg = e.key, order = e.g.order, leaves = {}, ctx = ctx }
				table.insert(groups[gk].leaves, it)
			end
		end
		for _, grp in pairs(groups) do
			local x1, y1, x2, y2 = math.huge, math.huge, -math.huge, -math.huge
			for _, it in ipairs(grp.leaves) do
				x1 = math.min(x1, it.r.x); y1 = math.min(y1, it.r.y)
				x2 = math.max(x2, it.r.x + it.r.w); y2 = math.max(y2, it.r.y + it.r.h)
			end
			grp.bbox = { x = x1, y = y1, w = x2 - x1, h = y2 - y1 }
			hudGroups[#hudGroups + 1] = grp
		end
	end
end
local s1 = math.clamp(W / 1280, 0.6, 1)
local SYN = {
	{ "Toast(ข้อความเด้ง)", 14, cfg.touch and { x = W / 2 - 160, y = 118, w = 320, h = 56 } or { x = W - 336, y = H - 176, w = 320, h = 56 } },
	{ "Announce(แถบประกาศข้ามเซิร์ฟ)", 14, { x = W / 2 - 0.31 * W, y = 78, w = 0.62 * W, h = 30 } },
	{ "GatherStatus(แถบฟาร์มออโต้)", 12, { x = W / 2 - 150, y = 74, w = 300, h = 30 }, true },
	{ "AntiIdle(เตือนอยู่นิ่ง)", 900, { x = W / 4, y = 0.06 * H, w = W / 2, h = 56 } },
	{ "DebugCoords(พิกัด/เวอร์ชัน)", 999, { x = W - 204, y = H - 18, w = 200, h = 14 } },
	{ "Ammo(กระสุนเกมหลัก)", 5, { x = W / 2 - 75, y = H - 207, w = 150, h = 35 } },
	{ "LevelUp(แบนเนอร์เลเวล)", 30, { x = W / 2 - 230 * s1, y = 0.3 * H - 60 * s1, w = 460 * s1, h = 120 * s1 } },
	{ "FarmChip(ป้ายเลเวลฟาร์ม·เกาะ)", 6, { x = 62, y = 10, w = 214, h = 34 } },
	{ "PetDrop(ปุ่มวางสัตว์·เกาะ)", 30, { x = W / 2 - 85, y = H - 200, w = 170, h = 40 }, true },
}
if cfg.arena then
	SYN = {
		{ "Toast(ข้อความเด้ง)", 14, SYN[1][3] },
		{ "DebugCoords(พิกัด/เวอร์ชัน)", 999, SYN[5][3] },
		{ "ArenaAmmo(กระสุนสนาม)", 5, { x = 16, y = H - 185, w = 150, h = 35 } },
	}
end
if cfg.touch then
	if not cfg.arena then SYN[#SYN + 1] = { "BuildToggle(ปุ่ม🏗️·เกาะ)", 41, { x = W - 140, y = 7, w = 38, h = 38 }, true }
	end
	SYN[#SYN + 1] = { "Unscope(ปุ่มเลิกส่องสไน·สนาม)", 23, { x = W - 80, y = 0.32 * H - 28, w = 56, h = 56 }, true }
end
for _, s in ipairs(SYN) do
	local leaf = { r = s[3], full = s[3], path = s[1], interactive = s[4] == true, content = true }
	hudGroups[#hudGroups + 1] = { key = "script:" .. s[1], sg = "script", order = s[2], leaves = { leaf }, bbox = s[3],
		ctx = s[1]:find("Toast") and "both" or "game" }
end
table.sort(hudGroups, function(a, b) return a.key < b.key end)
add("-- HUD")
for _, grp in ipairs(hudGroups) do add(("  %s DO%d %s"):format(grp.key, grp.order, fmt(grp.bbox))) end

-- 2) HUD vs HUD (leaf level, different groups)
add("-- HUD ทับ HUD")
for i = 1, #hudGroups do
	for j = i + 1, #hudGroups do
		local A, B = hudGroups[i], hudGroups[j]
		local sameCtx = A.ctx == B.ctx or A.ctx == "both" or B.ctx == "both"
		if sameCtx and inter(A.bbox, B.bbox) then
			local best, ex = 0, nil
			for _, a in ipairs(A.leaves) do
				for _, b in ipairs(B.leaves) do
					local r = inter(a.r, b.r)
					if r and r.w * r.h > best and not a.path:find(b.path, 1, true) then
						best = r.w * r.h
						ex = ("%s × %s %s"):format(a.path, b.path, fmt(r))
					end
				end
			end
			if best >= 20 then add(("  %s <> %s : %s"):format(A.key, B.key, ex)) end
		end
	end
end

-- 3) HUD vs Roblox zones
add("-- HUD ทับของระบบ Roblox")
for _, grp in ipairs(hudGroups) do
	for _, z in ipairs(zones) do
		local best, ex = 0, nil
		for _, it in ipairs(grp.leaves) do
			local r = inter(it.r, z.r)
			if r and r.w * r.h > best then best = r.w * r.h; ex = it.path .. (it.interactive and "[ปุ่ม]" or "") .. " " .. fmt(r) end
		end
		if best >= 20 then add(("  %s × %s : %s"):format(grp.key, z.name, ex)) end
	end
end

-- 4) every sg: offscreen content, interactive under Roblox top-left, small taps, small text
add("-- ต่อหน้าต่าง")
for _, e in ipairs(all) do
	local off, offEx, offWorst = 0, nil, 0
	local tb, tbEx = 0, nil
	local tap, tapEx, tapMin = 0, nil, math.huge
	local txt, txtEx, txtMin = 0, nil, math.huge
	for _, it in ipairs(e.items) do
		local o = it.o
		if it.content and not it.scroll and it.full.w >= 6 and it.full.h >= 6 then
			local over = math.max(-it.full.x, -it.full.y, it.full.x + it.full.w - W, it.full.y + it.full.h - H)
			if over > 3 then
				off += 1
				if over > offWorst then offWorst = over; offEx = it.path .. " " .. fmt(it.full) end
			end
		end
		if it.interactive and not fullscreen(it.full) and inter(it.r, zones[1].r) then
			tb += 1; tbEx = tbEx or (it.path .. " " .. fmt(it.r))
		end
		if cfg.touch and it.interactive and it.r.w > 0 then
			local m = math.min(it.full.w, it.full.h)
			if m < 32 then
				tap += 1
				if m < tapMin then tapMin = m; tapEx = it.path .. " " .. fmt(it.full) end
			end
		end
		if (o:IsA("TextLabel") or o:IsA("TextButton") or o:IsA("TextBox")) and o.Text ~= "" and o.TextTransparency < 1 and not o.TextScaled then
			local eff = o.TextSize * it.scale
			if eff < 11 then
				txt += 1
				if eff < txtMin then txtMin = eff; txtEx = it.path .. " \"" .. cut(o.Text, 12) .. "\"" end
			end
		end
	end
	local parts = {}
	if off > 0 then parts[#parts + 1] = ("หลุดจอ %d ชิ้น (มากสุด %dpx: %s)"):format(off, offWorst, offEx) end
	if tb > 0 then parts[#parts + 1] = ("ปุ่มใต้ปุ่ม Roblox %d (%s)"):format(tb, tbEx) end
	if tap > 0 then parts[#parts + 1] = ("ปุ่มเล็ก<32px %d (เล็กสุด %d: %s)"):format(tap, tapMin, tapEx) end
	if txt > 0 then parts[#parts + 1] = ("ตัวอักษร<11px %d (เล็กสุด %.1f: %s)"):format(txt, txtMin, txtEx) end
	if #parts > 0 then add(("  [%s DO%d] %s"):format(e.key, e.g.order, table.concat(parts, " | "))) end
end

-- 5) panels covered by persistent HUD drawn on top (DisplayOrder >= panel) — grouped per HUD piece
local PERSIST = { ["EventBannerGui::EventBannerGui|Banners"] = true, ["StoryGui::WOLD_Story|Tracker"] = true,
	["TutorialGui::TutorialGui|TopRight"] = true, ["script:BuildToggle(ปุ่ม🏗️·เกาะ)"] = true,
	["script:DebugCoords(พิกัด/เวอร์ชัน)"] = true, ["PartyGui::PartyGui|Panel"] = true, ["script:Toast(ข้อความเด้ง)"] = true }
add("-- หน้าต่างโดน HUD ที่ค้างจอ (ลำดับสูงกว่า) ทับ")
for _, grp in ipairs(hudGroups) do
	if PERSIST[grp.key] then
		local hits = {}
		for _, e in ipairs(all) do
			if not HUD[e.key] and not LOBBY[e.key] and grp.order >= e.g.order then
				local bestBtn, bestAny, exBtn = 0, 0, nil
				for _, it in ipairs(e.items) do
					if it.content and not fullscreen(it.full) then
						for _, h in ipairs(grp.leaves) do
							local r = inter(it.r, h.r)
							if r then
								local area = r.w * r.h
								if area > bestAny then bestAny = area end
								if it.interactive and area > bestBtn then bestBtn = area; exBtn = it.path .. " " .. fmt(r) end
							end
						end
					end
				end
				if bestBtn >= 20 then hits[#hits + 1] = e.key:match("^[^:]+") .. "[ปุ่ม " .. exBtn .. "]"
				elseif bestAny >= 60 then hits[#hits + 1] = e.key:match("^[^:]+") end
			end
		end
		if #hits > 0 then add(("  %s DO%d ทับ %d หน้าต่าง: %s"):format(grp.key, grp.order, #hits, table.concat(hits, " · "))) end
	end
end
return table.concat(lines, string.char(10))
