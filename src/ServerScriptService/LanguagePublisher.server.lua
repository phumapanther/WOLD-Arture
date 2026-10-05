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
	-- ตั้งแอตทริบิวต์ครั้งเดียว **หลังอ่านที่เก็บ** — ไคลเอนต์รอค่านี้ (≤2 วิ ใน Locale) ก่อนสร้างป้าย
	-- ถ้าตั้งค่าเดาก่อน ป้ายที่สร้างตอนบูต (จอโหลด HUD) จะติดภาษาไอดีทุกครั้งที่เข้า ทั้งที่เลือกภาษาอื่นไว้
	local guess = Locale.FromLocaleId(player.LocaleId)
	local got, saved = false, nil
	if store then got, saved = pcall(function() return store:GetAsync(keyOf(player)) end) end
	-- ระหว่างรอ ผู้เล่นอาจกดเลือกภาษาเองแล้ว → ค่าที่เพิ่งกดชนะ
	if player.Parent and player:GetAttribute("WOLD_Lang") == nil then
		player:SetAttribute("WOLD_Lang", (got and Locale.Valid(saved)) and saved or guess)
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
