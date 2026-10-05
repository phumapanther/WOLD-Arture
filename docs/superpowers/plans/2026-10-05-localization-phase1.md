# ระบบหลายภาษา เฟส 1 — แผนลงมือ

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** ผู้เล่นเห็นส่วนที่ใช้บ่อยของเกม (ไอเทม HUD กระเป๋า ร้าน คราฟ ข้อความเด้ง ล็อบบี้ จอโหลด) เป็นไทย/อังกฤษ/จีนตัวย่อ/ญี่ปุ่น ตามภาษาไอดี Roblox และเลือกเองได้ในหินเวท

**Architecture:** โมดูล `Locale` (ข้อมูลล้วน ใช้ทั้งสองฝั่ง) แปลโดยใช้ประโยคไทยเป็นกุญแจ ตารางคำแปลอยู่ `LocaleData/{en,zh,ja}.lua` ·
ภาษาของแต่ละคนอยู่ DataStore `WOLD_Lang_v1` → แอตทริบิวต์ `WOLD_Lang` บนตัว Player (`LanguagePublisher.server`) ·
ข้อความที่เซิร์ฟเวอร์ส่งเป็นไทยสำเร็จรูป ไคลเอนต์แปลตอนแสดงด้วย `Locale.Translate` (จับคู่แม่แบบ `%s/%d/%.1f` ย้อนกลับ) —
เซิร์ฟเวอร์ไม่ต้องแก้ทุกจุดที่ส่งข้อความ และเสียงข้อความเด้งที่ดูคำไทย (`REWARD_WORDS`) ยังทำงาน

**Tech Stack:** Luau (Roblox) · Rojo 3 เพลส (ดันด้วย `tools/verify.js`) · เทส offline `tools/offline-test.js` · ตัวตรวจคำแปล Node `tools/locale-check.js`

**Spec:** `docs/superpowers/specs/2026-10-03-localization-design.md`

## Global Constraints
- ภาษา: `th` (ต้นฉบับ) · `en` · `zh` (จีนตัวย่อ) · `ja` · ภาษาไอดีอื่น → `en`
- ข้อความที่ไม่มีคำแปล = ไทยเดิม ห้าม error
- ตัวคั่นรูปแบบในคำแปลต้องครบและเรียงเท่าต้นฉบับ
- ไม่แปล: ชื่อผู้เล่น ชื่อแคลน ข้อความที่ผู้เล่นพิมพ์ คำสั่งแอดมิน
- ห้ามใช้สัญลักษณ์ตัวอักษรที่ฟอนต์ Roblox วาดเป็นกล่อง (✦ ▲ ✚) ในคำแปล
- โฟลเดอร์ที่มี `init.lua` ใช้ไม่ได้กับ offline-test → `Locale.lua` + โฟลเดอร์ `LocaleData` แยก
- ตัวแปลเกมต้องใช้คำเดียวกันทั้งเกม: ชื่อเมือง/NPC/ไอเทมแปลครั้งเดียวในตาราง แล้วใช้ซ้ำ (Brasshaven, Saltmere, …)

## Review Focus
1. ข้อความเซิร์ฟเวอร์ที่มีชื่อไอเทมอยู่ข้างใน ("ซื้อ ขวาน x2") — `Translate` ต้องแปลทั้งแม่แบบและชื่อไอเทมที่จับได้ (Task 1)
2. แม่แบบสองอันที่จับคู่สตริงเดียวกันได้ — เลือกตัวที่ยาวกว่า (เจาะจงกว่า) (Task 1)
3. ผู้เล่นที่เปลี่ยนภาษาแล้วออกเกมทันที — ต้องจำได้ตอนเข้าใหม่ (Task 2 เขียน DataStore ก่อนตั้งแอตทริบิวต์)
4. DataStore ล่ม/Studio ไม่เปิดสิทธิ์ — ต้องตกไปใช้ภาษาไอดี ไม่ค้าง (Task 2)
5. ข้อความไทยที่ต่อด้วย `..` ในไฟล์เฟสนี้ — ต้องเปลี่ยนเป็น format ไม่งั้นแปลไม่ได้ (ทุกงานแปล · `locale-check` รายงาน)

---

### Task 1: โมดูล `Locale` + เทส

**Files:**
- Create: `src/ReplicatedStorage/Locale.lua`
- Create: `src/ReplicatedStorage/LocaleData/en.lua`, `zh.lua`, `ja.lua` (เริ่มด้วยคำในเทส)
- Test: `tests/locale_test.lua`

**Interfaces:**
- Produces: `Locale.Languages` `{ {id="th",label="ไทย"}, {id="en",label="English"}, {id="zh",label="简体中文"}, {id="ja",label="日本語"} }` ·
  `Locale.FromLocaleId(id) -> lang` · `Locale.T(lang, thai, ...) -> string` · `Locale.Translate(lang, text) -> string` ·
  `Locale.Current() -> lang` (ไคลเอนต์: แอตทริบิวต์ `WOLD_Lang` ของ LocalPlayer ถ้าไม่มี = `FromLocaleId(LocalPlayer.LocaleId)` · เซิร์ฟ = "th") ·
  `Locale.L(thai, ...) = Locale.T(Locale.Current(), thai, ...)` · `Locale.Valid(lang) -> bool`

- [ ] **Step 1: เขียนเทสที่ล้ม** `tests/locale_test.lua`

```lua
-- node tools/offline-test.js tests/locale_test.lua
local L = require(game.ReplicatedStorage.Locale)
local out, fails = {}, 0
local function check(ok, text) out[#out + 1] = (ok and "ok   " or "FAIL ") .. text if not ok then fails += 1 end end

check(L.FromLocaleId("th-th") == "th", "th-th → th")
check(L.FromLocaleId("en-us") == "en", "en-us → en")
check(L.FromLocaleId("zh-cn") == "zh" and L.FromLocaleId("zh-tw") == "zh", "zh-* → zh")
check(L.FromLocaleId("ja-jp") == "ja", "ja-jp → ja")
check(L.FromLocaleId("ko-kr") == "en" and L.FromLocaleId("") == "en" and L.FromLocaleId(nil) == "en", "อื่น/ว่าง → en")
check(L.Valid("ja") and not L.Valid("fr"), "Valid")

check(L.T("en", "กระเป๋าเต็ม") == "Bag is full", "แปลตรงตัว")
check(L.T("th", "กระเป๋าเต็ม") == "กระเป๋าเต็ม", "ไทยไม่แปล")
check(L.T("en", "ไม่มีในตาราง") == "ไม่มีในตาราง", "ไม่มีคำแปล = ไทย")
check(L.T("en", "ตกได้ %s %.1f กก.", "ปลา", 3.25) == "Caught Fish 3.2 kg", "format + แปลอาร์กิวเมนต์ชื่อ")
check(L.T("en", "ตกได้ %s %.1f กก.") == "Caught %s %.1f kg", "ไม่ส่งอาร์กิวเมนต์ = ไม่ format")
local ok = pcall(L.T, "en", "ตกได้ %s %.1f กก.", "ปลา") -- อาร์กิวเมนต์ไม่ครบ
check(ok, "format พังไม่ error")

-- ย้อนแม่แบบ: เซิร์ฟส่งไทยสำเร็จรูปมา
check(L.Translate("en", "ตกได้ ปลา 3.2 กก.") == "Caught Fish 3.2 kg", "Translate จับแม่แบบ + แปลชื่อที่จับได้")
check(L.Translate("en", "กระเป๋าเต็ม") == "Bag is full", "Translate ตรงตัว")
check(L.Translate("en", "ข้อความแปลก ๆ") == "ข้อความแปลก ๆ", "Translate ไม่เจอ = เดิม")
check(L.Translate("th", "ตกได้ ปลา 3.2 กก.") == "ตกได้ ปลา 3.2 กก.", "Translate ไทย = เดิม")
check(L.Translate("en", "ซื้อ ปลา x2 แล้ว") == "Bought Fish x2", "แม่แบบยาวกว่าชนะ (ไม่ไปจับ 'ซื้อ %s')")

return (fails == 0 and "PASS\n" or ("FAIL x%d\n"):format(fails)) .. table.concat(out, "\n")
```

- [ ] **Step 2: รันให้เห็นล้ม** — `node tools/offline-test.js tests/locale_test.lua` · Expected: `ERROR` (ไม่มีโมดูล `Locale`)

- [ ] **Step 3: เขียน `LocaleData/en.lua`** (zh/ja ใส่คำเดียวกันแปลเป็นภาษานั้น)

```lua
-- ประโยคไทยต้นฉบับ → อังกฤษ · ตัวคั่น %… ต้องครบและเรียงเท่าต้นฉบับ (tools/locale-check.js ตรวจ)
return {
	["กระเป๋าเต็ม"] = "Bag is full",
	["ตกได้ %s %.1f กก."] = "Caught %s %.1f kg",
	["ซื้อ %s"] = "Bought %s",
	["ซื้อ %s x%d แล้ว"] = "Bought %s x%d",
	["ปลา"] = "Fish",
}
```

- [ ] **Step 4: เขียน `Locale.lua`**

```lua
-- Locale: แปลข้อความเกมโดยใช้ประโยคไทยต้นฉบับเป็นกุญแจ (ผู้ใช้สั่ง 2026-10-03 · สเปก 2026-10-03-localization-design)
-- ตาราง `LocaleData/<lang>` · ไม่มีคำแปล = ไทยเดิม · ใช้ทั้งเซิร์ฟ/ไคลเอนต์ (Current() ฝั่งเซิร์ฟ = th)
local Locale = {}

Locale.Languages = {
	{ id = "th", label = "ไทย" }, { id = "en", label = "English" },
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
			local p = thai:gsub("[%^%$%(%)%.%[%]%*%+%-%?]", "%%%0") -- ตัวพิเศษของรูปแบบ Lua
			p = p:gsub("%%%%%%%.?%d*[sdf]", function(spec)
				return spec:sub(-1) == "s" and "(.-)" or "([%-%d%.,]+)"
			end)
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
			local result = template:gsub("%%%.?%d*[sdf]", function()
				i += 1
				local v = caps[i]
				return v and (t[v] or v) or ""
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

return Locale
```

- [ ] **Step 5: รันให้ผ่าน** — `node tools/offline-test.js tests/locale_test.lua` · Expected: `PASS`
  (ถ้าตัวจำลองไม่มี `table.pack`/`RunService:IsClient` ให้ดูที่ prelude ก่อน — `Current()` ไม่ถูกเรียกในเทสนี้)

- [ ] **Step 6: Commit** — `git add src/ReplicatedStorage/Locale.lua src/ReplicatedStorage/LocaleData tests/locale_test.lua && git commit -m "Locale core: Thai-keyed tables, format, reverse template match"`

### Task 2: ภาษาของผู้เล่น (`LanguagePublisher.server`)

**Files:**
- Create: `src/ServerScriptService/LanguagePublisher.server.lua`
- Modify: `src/ReplicatedStorage/Remotes.lua` (เพิ่ม `"SetLanguage"` ในรายการ EVENTS)

**Interfaces:**
- Consumes: `Locale.Valid`, `Locale.FromLocaleId`
- Produces: แอตทริบิวต์ `WOLD_Lang` บนตัว Player (ทุกเพลสรวมล็อบบี้/สนาม) · `Remotes.SetLanguage:FireServer(lang)`

- [ ] **Step 1: เขียนสคริปต์**

```lua
-- LanguagePublisher: ภาษาของแต่ละคน (สเปก 2026-10-03) · DataStore แยก เพราะล็อบบี้/สนามเปิดเซสชันโปรไฟล์ไม่ได้
-- ไม่เคยเลือก = ภาษาไอดี Roblox ทุกครั้งที่เข้า (ไม่จดลงที่เก็บ) · เลือกเอง = จดถาวร
local DataStoreService = game:GetService("DataStoreService")
local Locale = require(game.ReplicatedStorage.Locale)
local Remotes = require(game.ReplicatedStorage.Remotes)
local PlayerJoin = require(game.ServerScriptService.PlayerJoin)

local ok, store = pcall(function() return DataStoreService:GetDataStore("WOLD_Lang_v1") end)
if not ok then store = nil end
local function keyOf(player) return "u_" .. player.UserId end

PlayerJoin.Each(function(player)
	local guess = Locale.FromLocaleId(player.LocaleId)
	player:SetAttribute("WOLD_Lang", guess) -- ทันที ไม่รอ DataStore
	if not store then return end
	local got, saved = pcall(function() return store:GetAsync(keyOf(player)) end)
	-- ระหว่างรอ ผู้เล่นอาจกดเลือกภาษาเองแล้ว → ค่าที่เพิ่งกดชนะ ไม่ถูกค่าเก่าในที่เก็บทับ
	if got and Locale.Valid(saved) and player.Parent and player:GetAttribute("WOLD_Lang") == guess then
		player:SetAttribute("WOLD_Lang", saved)
	end
end)

local pending = {} -- เขียน DataStore ครั้งเดียวต่อช่วง 2 วิ ด้วยค่าล่าสุด (กดรัวไม่เปลืองโควตา · ค่าที่กดสุดท้ายถูกจดเสมอ)
Remotes.SetLanguage.OnServerEvent:Connect(function(player, lang)
	if not Locale.Valid(lang) then return end
	player:SetAttribute("WOLD_Lang", lang)
	if not store or pending[player] then return end
	pending[player] = true
	task.delay(2, function()
		pending[player] = nil
		local latest = player:GetAttribute("WOLD_Lang")
		pcall(function() store:SetAsync(keyOf(player), latest) end)
	end)
end)
game:GetService("Players").PlayerRemoving:Connect(function(player) pending[player] = nil end)
```

- [ ] **Step 2: เพิ่ม `"SetLanguage"` ใน `Remotes.lua`** ต่อท้ายบรรทัด `"RequestSetAutoEat"`
- [ ] **Step 3: ตรวจคอมไพล์** — `bash tools/offline-check.sh src/ServerScriptService/LanguagePublisher.server.lua src/ReplicatedStorage/Remotes.lua` · Expected: `OK (2 files)`
- [ ] **Step 4: ตรวจว่าไม่อยู่ใน denylist ของเพลสไหน** — `grep -n LanguagePublisher *.project.json` · Expected: ไม่มีบรรทัด (รันทุกเพลส)
- [ ] **Step 5: Commit**

### Task 3: ปุ่มเลือกภาษาในหน้าตั้งค่าหินเวท

**Files:**
- Modify: `src/ReplicatedStorage/UI/SocialGui.lua` (`buildSettings` · เพิ่มแถวภาษาก่อนสวิตช์)
- Modify: `src/StarterPlayerScripts/SocialController.client.lua` (callback `language` ยิง `Remotes.SetLanguage` ตรง — ไม่ผ่าน `ask()` เพราะล็อบบี้ต้องใช้ได้)

- [ ] **Step 1:** ใน `buildSettings` ก่อน `toggleRow(...)` แรก เพิ่ม:

```lua
	local Locale = require(script.Parent.Parent.Locale)
	local langHead = label(page, "ภาษา / Language", 12, TEXT_MUTED)
	langHead.Position = UDim2.new(0, 0, 0, y + 2)
	langHead.Size = UDim2.new(1, 0, 0, 18)
	y = y + 22
	local langButtons = {}
	local function paintLang()
		local current = Locale.Current()
		for id, b in pairs(langButtons) do
			b.BackgroundColor3 = id == current and OK_GREEN or STONE_DEEP
		end
	end
	for i, l in ipairs(Locale.Languages) do
		local b = Instance.new("TextButton")
		b.Position = UDim2.new((i - 1) / 4, 2, 0, y)
		b.Size = UDim2.new(0.25, -4, 0, 34)
		b.BorderSizePixel = 0
		b.Text = l.label
		b.TextColor3 = TEXT_LIGHT
		b.TextScaled = true
		b.Font = Enum.Font.GothamMedium
		b.Parent = page
		corner(b, UDim.new(0, 8))
		langButtons[l.id] = b
		b.Activated:Connect(function()
			if self.callbacks.language then self.callbacks.language(l.id) end
		end)
	end
	game:GetService("Players").LocalPlayer:GetAttributeChangedSignal("WOLD_Lang"):Connect(paintLang)
	paintLang()
	y = y + 40
	local note = label(page, Locale.L("บางส่วนจะเปลี่ยนเมื่อเข้าเกมใหม่"), 11, TEXT_MUTED)
	note.Position = UDim2.new(0, 0, 0, y)
	note.Size = UDim2.new(1, 0, 0, 16)
	y = y + 24
```
  (สีปุ่ม/ฟอนต์ ให้ใช้ค่าคงที่ที่ไฟล์ใช้อยู่แล้ว ถ้า `OK_GREEN`/`STONE_DEEP`/`label`/`corner` ไม่ใช่ชื่อจริง ให้ใช้ชื่อที่ไฟล์นิยาม)
- [ ] **Step 2:** ใน SocialController ใต้ `gui:On("settingsChanged", …)` เพิ่ม `gui:On("language", function(lang) Remotes.SetLanguage:FireServer(lang) end)`
  (ถ้า `gui:On` ไม่รองรับชื่อใหม่ ดู `SocialGui:On` แล้วใช้กลไกเดียวกับ `settingsChanged`)
- [ ] **Step 3: เทส Edit** — สร้าง `SocialGui.new()` ใน sandbox mirror (แบบ `craft_gui_fuel_test`) เปิดหน้า settings แล้วตรวจว่ามีปุ่ม 4 ปุ่มข้อความ `ไทย/English/简体中文/日本語` และกดปุ่ม English แล้ว callback ได้ `"en"` · `tests/social_language_test.lua` · Expected: PASS
- [ ] **Step 4:** ตรวจคอมไพล์ + Commit

### Task 4: ตัวตรวจคำแปล `tools/locale-check.js`

**Files:**
- Create: `tools/locale-check.js`

ทำงาน:
1. อ่าน `LocaleData/{en,zh,ja}.lua` (แยกด้วย regex `\["((?:[^"\\]|\\.)*)"\]\s*=\s*"((?:[^"\\]|\\.)*)"`)
2. ทุกคู่: ตัวคั่น `%[-\d.]*[sdfq%]` ในคำแปลต้องเรียงเท่าต้นฉบับ → `MISMATCH <lang> <ไทย>`
3. รับรายชื่อไฟล์เป็นอาร์กิวเมนต์ (ไฟล์ของเฟส) — หา `L("…"` `Locale.L("…"` `Locale.T(lang, "…"` และสตริงไทยในฟิลด์ `name =`/`desc =`/`description =` ของ `ItemCatalog` → ไม่มีในตารางภาษาไหน → `MISSING <lang> <ไทย>`
4. สตริงไทยในไฟล์ที่ระบุซึ่ง **ไม่ได้** ถูกครอบ (ยังเป็นตัวอักษรไทยเปล่าที่จะขึ้นบนจอ) → `BARE <file>:<line>` (คอมเมนต์ไม่นับ · บรรทัด `print`/`warn` ไม่นับ)
5. ออกด้วยโค้ด 1 ถ้ามี MISMATCH/MISSING

- [ ] **Step 1:** เขียนสคริปต์ · **Step 2:** รัน `node tools/locale-check.js src/ReplicatedStorage/Locale.lua` · Expected: `OK 5 keys · 0 missing` · **Step 3:** ใส่คำแปลผิดตัวคั่นชั่วคราวใน en.lua → Expected: `MISMATCH` exit 1 · เอาคืน · **Step 4:** Commit

### Task 5: ชื่อ/คำอธิบายไอเทม

**Files:**
- Modify: `src/ReplicatedStorage/ItemCatalog.lua` (`DisplayName(id, meta, lang)` + `ItemCatalog.Description(id, lang)` ถ้ามีฟิลด์คำอธิบาย)
- Modify: `LocaleData/{en,zh,ja}.lua` (ชื่อไอเทมทุกชิ้น + คำอธิบาย ~232 สตริง)
- Test: เพิ่มใน `tests/locale_test.lua`

- [ ] **Step 1: เทสล้ม** — เพิ่ม `check(require(game.ReplicatedStorage.ItemCatalog).DisplayName("Axe", nil, "en") == "Axe", "ชื่อไอเทมแปล")` และ `DisplayName("Axe", {enhance=3}, "ja")` มี `+3`
- [ ] **Step 2:** ใน `DisplayName` แทน `local base = item and item.name or id` ด้วย
  `local base = item and Locale.T(lang or Locale.Current(), item.name) or id` (require `script.Parent.Locale`) · ชื่อสกินในวงเล็บแปลแบบเดียวกัน
- [ ] **Step 3:** แปลทุก `name`/คำอธิบายใน ItemCatalog ลงสามตาราง (เรียงตามลำดับในไฟล์ · คงคำเฉพาะของเกม: Brasshaven ฯลฯ)
- [ ] **Step 4:** `node tools/locale-check.js src/ReplicatedStorage/ItemCatalog.lua` · Expected: `0 missing` · `node tools/offline-test.js tests/locale_test.lua` · Expected: PASS
- [ ] **Step 5:** Commit

### Task 6: ข้อความเด้ง

**Files:**
- Modify: `src/StarterPlayerScripts/ToastController.client.lua`

- [ ] **Step 1:** ใน `toast(message, isError)` ก่อน `line.Text = …` เพิ่ม `message = Locale.Show(message)` (require Locale) — **`soundFor` ยังรับข้อความไทยเดิม** (เรียกก่อนแปลอยู่แล้วที่บรรทัด 136/144 ตรวจว่าคงเดิม)
- [ ] **Step 2:** แปลแม่แบบข้อความที่ส่งจากไฟล์เฟสนี้: `Shop.server` `Crafting.server` `PlayerInventory.server` `Inventory.lua` `LobbyParty.server` `LobbyServer.server` — ข้อความที่ประกอบด้วย `..` เปลี่ยนเป็น `("…%s…"):format(...)` ก่อน แล้วใส่แม่แบบลงตาราง
- [ ] **Step 3:** `node tools/locale-check.js <หกไฟล์ข้างบน>` · Expected: 0 missing · BARE ที่เหลือเป็นข้อความที่ส่งเข้า SocialNotify ได้ (ถือว่าแปลผ่าน Translate) ให้ทำรายการไว้ในตัวสคริปต์ด้วยแฟล็ก `--server` (ไม่รายงาน BARE สำหรับไฟล์ฝั่งเซิร์ฟ แต่รายงาน MISSING ของทุกสตริงไทย)
- [ ] **Step 4:** เพิ่มเทส `Translate` กับข้อความจริงสามอันจาก Shop/Crafting ใน `locale_test` · PASS · Commit

### Task 7: HUD + กระเป๋า

**Files:** `UI/HudGui.lua` `HudController.client.lua` `UI/InventoryGui.lua` `InventoryController.client.lua` + ตาราง

- [ ] **Step 1:** ครอบทุกสตริงไทยที่ขึ้นจอด้วย `Locale.L(...)` (`..` → format) · ป้ายที่ตั้งตอนบูตยอมรับว่าเปลี่ยนหลังเข้าใหม่
- [ ] **Step 2:** แปลลงตาราง · `node tools/locale-check.js <สี่ไฟล์>` · Expected: 0 missing · 0 BARE
- [ ] **Step 3:** `bash tools/offline-check.sh <สี่ไฟล์>` · Expected OK · Commit

### Task 8: ร้าน + คราฟ

**Files:** `UI/ShopGui.lua` `UI/CraftGui.lua` `CraftController.client.lua` `CraftConfig.lua` (ชื่อแท็บ/ชื่อสถานี — แปลที่จุดแสดงใน CraftGui ไม่ใช่แก้คอนฟิก) + ตาราง

- [ ] **Step 1:** ครอบ + แปล · ข้อความที่มาจาก snapshot ของเซิร์ฟ (เหตุผลล็อก ป้ายสถานะ) ใช้ `Locale.Show(text)` ตอนแสดง
- [ ] **Step 2:** locale-check 0 missing/0 BARE · offline-check OK · รันเทส Edit เดิม `shop_gui_test` `craft_gui_busy_test` `craft_gui_fuel_test` `export_gui_instant_test` · Expected: PASS ทั้งหมด (ภาษาเครื่อง Studio = th → ข้อความเดิม)
- [ ] **Step 3:** Commit

### Task 9: ล็อบบี้ + จอโหลด

**Files:** `UI/ChannelSelectGui.lua` `ChannelSelectController.client.lua` `UI/PvpPartyGui.lua` `PvpPartyController.client.lua` `UI/LoadingGui.lua` + ตาราง

- [ ] **Step 1:** ครอบ + แปล (LoadingGui มี `..` 4 จุด → format)
- [ ] **Step 2:** ⚠️ หน้าจอล็อบบี้ถูกสร้างใหม่ทั้งชุดเมื่อจอพลิก — เปลี่ยนภาษาในล็อบบี้ให้ผลทันทีด้วยการสร้างใหม่แบบเดียวกัน: ใน ChannelSelectController ฟัง `WOLD_Lang` เปลี่ยน → เรียกทางเดียวกับตอนจอพลิก
- [ ] **Step 3:** locale-check 0/0 · offline-check · Commit

### Task 10: ดันขึ้นเพลส + บันทึก

- [ ] **Step 1:** `node tools/offline-test.js tests/locale_test.lua tests/island_fishing_test.lua tests/craft_fuel_test.lua` · Expected: PASS ทั้งหมด
- [ ] **Step 2:** `node tools/locale-check.js` กับทุกไฟล์ของเฟส · Expected exit 0
- [ ] **Step 3:** `node tools/verify.js default.project.json --push` แล้ว farming/arena · แล้วรันซ้ำไม่มี `--push` · Expected: `mismatches 0` ทั้งสาม
- [ ] **Step 4:** เพิ่มหัวข้อใน CLAUDE.md: กฎ "ข้อความใหม่ที่ขึ้นจอต้องผ่าน `Locale.L` (ไคลเอนต์) · ข้อความเซิร์ฟส่งไทยได้ ไคลเอนต์แปลด้วย `Locale.Show` แต่ต้องมีแม่แบบในตาราง · เพิ่มคำแปลแล้วรัน `tools/locale-check.js`"
- [ ] **Step 5:** Commit
