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
		local mod = script.Parent:FindFirstChild("LocaleData") and script.Parent.LocaleData:FindFirstChild(lang)
		tables[lang] = mod and require(mod) or false
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

-- แม่แบบไทย → รูปแบบ Lua ไว้จับข้อความที่เซิร์ฟประกอบมาแล้ว · เรียงยาวก่อน (เจาะจงกว่าชนะ)
local patterns = {}
local function patternsOf(lang)
	if patterns[lang] then return patterns[lang] end
	local list = {}
	for thai in pairs(tableOf(lang) or {}) do
		if thai:find("%%") then
			-- ตัดเป็นชิ้น: ตัวคั่น %… → ช่องจับ · ข้อความระหว่างนั้น escape ตัวพิเศษของรูปแบบ Lua
			local p, last = "", 1
			-- %% ในแม่แบบ = เครื่องหมาย % ตัวเดียวในข้อความจริง
			local function literal(piece)
				return (piece:gsub("%%%%", "%%"):gsub("[%^%$%(%)%%%.%[%]%*%+%-%?]", "%%%0"))
			end
			for s, spec, e in thai:gmatch("()(%%[%-%d%.]*[sdf%%])()") do
				if spec == "%%" then
					p ..= literal(thai:sub(last, e - 1))
				else
					p ..= literal(thai:sub(last, s - 1))
					p ..= spec:sub(-1) == "s" and "(.-)" or "([%-%d%.,]+)"
				end
				last = e
			end
			p ..= literal(thai:sub(last))
			list[#list + 1] = { thai = thai, pattern = "^" .. p .. "$" }
		end
	end
	table.sort(list, function(a, b) return #a.thai > #b.thai end)
	patterns[lang] = list
	return list
end

-- ข้อความไทยสำเร็จรูป (จากเซิร์ฟ) → ภาษา lang · ไม่เจอ = ข้อความเดิม
function Locale.Translate(lang, text)
	if lang == "th" or type(text) ~= "string" then return text end
	local t = tableOf(lang)
	if not t then return text end
	if t[text] then return t[text] end
	for _, entry in ipairs(patternsOf(lang)) do
		local caps = table.pack(text:match(entry.pattern))
		if caps[1] ~= nil then
			local template = t[entry.thai]
			local i = 0
			local result = template:gsub("%%[%-%d%.]*[sdf%%]", function(spec)
				if spec == "%%" then return "%" end
				i += 1
				local v = caps[i]
				if not v then return "" end
				if t[v] then return t[v] end
				-- ช่อง %s ที่เป็นข้อความซ้อนแม่แบบอีกชั้น ("ดาบ (ในบ้าน) x3") · สั้นกว่าเดิมเสมอ = ไม่วนไม่จบ
				if spec:sub(-1) == "s" and #v < #text then return Locale.Translate(lang, v) end
				return v
			end)
			return result
		end
	end
	return text
end

function Locale.Current()
	local RunService = game:GetService("RunService")
	if not RunService:IsClient() then return "th" end
	local player = game:GetService("Players").LocalPlayer
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
	local player = game:GetService("Players").LocalPlayer
	if player then Locale.AwaitChoice(player, 2) end
end

return Locale
