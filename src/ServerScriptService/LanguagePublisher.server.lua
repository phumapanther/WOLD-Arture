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
