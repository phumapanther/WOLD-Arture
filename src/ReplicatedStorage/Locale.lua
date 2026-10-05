-- Locale: แปลข้อความเกมโดยใช้ประโยคไทยต้นฉบับเป็นกุญแจ (ผู้ใช้สั่ง 2026-10-03 · สเปก 2026-10-03-localization-design)
-- ตาราง `LocaleData/<lang>` · ไม่มีคำแปล = ไทยเดิม · ใช้ทั้งเซิร์ฟ/ไคลเอนต์ (Current() ฝั่งเซิร์ฟ = th)
local Locale = {}

Locale.Languages = {
	{ id = "th", label = "ไทย" }, { id = "en", label = "English" }, -- locale: skip (ชื่อภาษาเขียนด้วยภาษาของมันเอง)
	{ id = "zh", label = "简体中文" }, { id = "ja", label = "日本語" },
}

local tables = {}
local function tableOf(lang)
	if lang == "th" then return nil end
	if tables[lang] == nil then
		-- แต่ละภาษาแบ่งหลายโมดูล <lang>_<n> (Source ของ Roblox เกิน 200,000 ไบต์ไม่ได้) → รวมทุกส่วน
		local merged, found = {}, false
		local folder = script.Parent:FindFirstChild("LocaleData")
		for _, mod in ipairs(folder and folder:GetChildren() or {}) do
			if mod:IsA("ModuleScript") and (mod.Name == lang or mod.Name:match("^" .. lang .. "_%d+$")) then
				for k, v in pairs(require(mod)) do merged[k] = v end
				found = true
			end
		end
		tables[lang] = found and merged or false
	end
	return tables[lang] or nil
end

function Locale.Valid(lang)
	for _, l in ipairs(Locale.Languages) do if l.id == lang then return true end end
	return false
end

function Locale.FromLocaleId(id)
	local prefix = type(id) == "string" and id:lower():sub(1, 2) or ""
	if prefix == "th" or prefix == "zh" or prefix == "ja" or prefix == "en" then return prefix end
	return "en"
end

local function lookup(lang, thai)
	local t = tableOf(lang)
	return t and t[thai] or thai
end

-- อาร์กิวเมนต์ที่เป็นสตริงแปลด้วย (ชื่อไอเทม/ชื่อเมือง) · format พัง = คืนแม่แบบที่แปลแล้วไม่ format
function Locale.T(lang, thai, ...)
	local template = lookup(lang, thai)
	if select("#", ...) == 0 then return template end
	local args = table.pack(...)
	for i = 1, args.n do
		if type(args[i]) == "string" then args[i] = lookup(lang, args[i]) end
	end
	local ok, text = pcall(string.format, template, table.unpack(args, 1, args.n))
	return ok and text or template
end

-- แม่แบบ → รูปแบบ Lua ไว้จับข้อความที่ประกอบมาแล้ว · เรียงยาวก่อน (เจาะจงกว่าชนะ)
-- map = { แม่แบบต้นทาง = แม่แบบปลายทาง } ใช้ได้ทั้งไทย→ภาษาอื่น (Translate) และกลับ (ToThai)
local function buildPatterns(map)
	local list = {}
	for source in pairs(map) do
		if source:find("%%") then
			-- ตัดเป็นชิ้น: ตัวคั่น %… → ช่องจับ · ข้อความระหว่างนั้น escape ตัวพิเศษของรูปแบบ Lua
			local p, last = "", 1
			-- %% ในแม่แบบ = เครื่องหมาย % ตัวเดียวในข้อความจริง
			local function literal(piece)
				return (piece:gsub("%%%%", "%%"):gsub("[%^%$%(%)%%%.%[%]%*%+%-%?]", "%%%0"))
			end
			for st, spec, e in source:gmatch("()(%%[%-%d%.]*[sdf%%])()") do
				if spec == "%%" then
					p ..= literal(source:sub(last, e - 1))
				else
					p ..= literal(source:sub(last, st - 1))
					p ..= spec:sub(-1) == "s" and "(.-)" or "([%-%d%.,]+)"
				end
				last = e
			end
			p ..= literal(source:sub(last))
			list[#list + 1] = { source = source, pattern = "^" .. p .. "$" }
		end
	end
	table.sort(list, function(x, y) return #x.source > #y.source end)
	return list
end

-- ข้อความสำเร็จรูป → แม่แบบปลายทาง · ช่อง %s แปลซ้ำได้ (ชื่อไอเทม · "ดาบ (ในบ้าน) x3") · ไม่เจอ = ข้อความเดิม
local function convert(map, list, text)
	if map[text] then return map[text] end
	for _, entry in ipairs(list) do
		local caps = table.pack(text:match(entry.pattern))
		if caps[1] ~= nil then
			local i = 0
			return (map[entry.source]:gsub("%%[%-%d%.]*[sdf%%]", function(spec)
				if spec == "%%" then return "%" end
				i += 1
				local v = caps[i]
				if not v then return "" end
				if map[v] then return map[v] end
				-- สั้นกว่าเดิมเสมอ = ไม่วนไม่จบ
				if spec:sub(-1) == "s" and #v < #text then return convert(map, list, v) end
				return v
			end))
		end
	end
	return text
end

local patterns = {}
-- ข้อความไทยสำเร็จรูป (จากเซิร์ฟ) → ภาษา lang · ไม่เจอ = ข้อความเดิม
function Locale.Translate(lang, text)
	if lang == "th" or type(text) ~= "string" then return text end
	local t = tableOf(lang)
	if not t then return text end
	patterns[lang] = patterns[lang] or buildPatterns(t)
	return convert(t, patterns[lang], text)
end

-- กลับทาง: ข้อความภาษา lang ที่ขึ้นจออยู่แล้ว → ไทยต้นฉบับ (เปลี่ยนภาษากลางเกมแปลป้ายเดิมใหม่ได้ · ผู้ใช้แจ้ง 2026-10-05)
-- คำแปลซ้ำกันหลายกุญแจ = ได้กุญแจใดกุญแจหนึ่ง (ความหมายเดียวกันอยู่แล้ว) · ไม่รู้จัก/เป็นไทยอยู่แล้ว = เดิม
local reverse = {}
function Locale.ToThai(lang, text)
	if lang == "th" or type(text) ~= "string" then return text end
	if not reverse[lang] then
		local t = tableOf(lang)
		if not t then return text end
		local map = {}
		for thai, tr in pairs(t) do map[tr] = map[tr] or thai end
		reverse[lang] = { map = map, list = buildPatterns(map) }
	end
	return convert(reverse[lang].map, reverse[lang].list, text)
end

-- โฟลเดอร์ Sandboxed ของเทส Edit ได้ GetService("Players") = nil ทั้งที่ IsClient() เป็นจริง
local function localPlayer()
	local Players = game:GetService("Players")
	return Players and Players.LocalPlayer
end

function Locale.Current()
	local RunService = game:GetService("RunService")
	if not RunService:IsClient() then return "th" end
	local player = localPlayer()
	local lang = player and player:GetAttribute("WOLD_Lang")
	if Locale.Valid(lang) then return lang end
	return Locale.FromLocaleId(player and player.LocaleId)
end

function Locale.L(thai, ...) return Locale.T(Locale.Current(), thai, ...) end
function Locale.Show(text) return Locale.Translate(Locale.Current(), text) end

-- รอแอตทริบิวต์ WOLD_Lang (เซิร์ฟตั้งหลังอ่านที่เก็บ) ไม่เกิน timeout วิ · หมดเวลา = nil แล้ว Current ใช้ภาษาไอดี
function Locale.AwaitChoice(player, timeout)
	local started = os.clock()
	while player:GetAttribute("WOLD_Lang") == nil and os.clock() - started < timeout do task.wait(0.05) end
	return player:GetAttribute("WOLD_Lang")
end

-- ฝั่งไคลเอนต์: โมดูลแรกที่ require ตัวนี้ (จอโหลด HUD กระเป๋า) รอภาษาที่เลือกไว้ก่อนสร้างป้ายตอนบูต
if game:GetService("RunService"):IsClient() then
	local player = localPlayer()
	if player then Locale.AwaitChoice(player, 2) end
end

return Locale
