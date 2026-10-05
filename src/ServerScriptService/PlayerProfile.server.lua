-- PlayerProfile.server.lua: the only file that touches player profiles. Replaces PlayerPosition.server.lua's
-- hand-rolled DataStore access (see docs/superpowers/specs/2026-09-07-player-position-design.md for the two
-- real bugs and one unfixable race that motivated this) with ProfileStore (src/ServerScriptService/ProfileStore.lua,
-- vendored from temp_refs/profilestore-madstudio) — a maintained, session-locked DataStore wrapper. See
-- docs/superpowers/specs/2026-09-07-profile-foundation-design.md for the full design.
--
-- Position is the only field this phase actually reads/writes. Vitals exists in the template so the next
-- systems (movement/stamina, HP/hunger/drowning) don't need another schema-migrating Reconcile bump.
--
-- Everything here except the RemoteFunction answer is gated to not ServerConfig.IsLobby: the lobby has its own
-- dedicated LobbySpawn room and must never start a profile session or read/write map position data.
local Players = game:GetService("Players")
local ServerConfig = require(game.ServerScriptService.ServerConfig)
local ProfileStore = require(game.ServerScriptService.ProfileStore)
local ProfileAccess = require(game.ServerScriptService.ProfileAccess)
local Remotes = require(game.ReplicatedStorage.Remotes)
local SpawnSelector = require(game.ReplicatedStorage.SpawnSelector)
local PlayerJoin = require(game.ServerScriptService.PlayerJoin)
local Vip = require(game.ServerScriptService.Vip)
local Mail = require(game.ServerScriptService.Mail)
local Achievements = require(game.ServerScriptService.Achievements)
local Locale = require(game.ReplicatedStorage.Locale)

-- ข้อความเตะขึ้นที่จอของ Roblox เอง ไคลเอนต์แปลให้ไม่ได้ → แปลตามภาษาของคนนั้นที่นี่ (ไทย = ข้อความเดิม)
local function kick(player, thai)
	local lang = player:GetAttribute("WOLD_Lang")
	if not Locale.Valid(lang) then lang = Locale.FromLocaleId(player.LocaleId) end
	player:Kick(Locale.T(lang, thai))
end

local ProfileTemplate = {
	Position = nil, -- {x, y, z} | nil (nil = never saved yet)
	Vitals = { HP = 100, Stamina = 100, Hunger = 100 }, -- unused this phase; here so later phases don't Reconcile again
	Progression = { Level = 1, Exp = 0 }, -- EXP/level survive a rejoin; dying is what resets them, not leaving
	Inventory = nil, -- {Slots, Equipped, Gold} | nil (nil = never saved, so hand out the starter kit)
	-- Classes: {Basic, Advanced} | nil. Named "Role" still because that is the key already written into
	-- every saved profile; Classes.Add also accepts the bare role id those older profiles hold.
	Role = nil,
	-- Friend list, banked gold, and the profile fields the player will be able to set later. The three
	-- display fields exist now so adding the editor later needs no migration.
	Social = nil, -- {Friends, Pending, Bank, Birthday, Gender, AvatarImage} | nil
	-- The warehouse behind Madam Aurelia's counter. {Slots} | nil (nil = never used one). Kept out of
	-- Inventory rather than folded into it because the whole point of the vault is that it is NOT the bag:
	-- it does not travel, does not weigh anything, and survives what the bag does not.
	Vault = nil,
	-- Vehicle registrations. {Vehicles = {[plate] = {...}}} | nil. Written straight into Data by
	-- Vehicle/Store, which binds to the same table rather than keeping a copy -- so unlike the fields above
	-- there is no serializer for it and nothing for saveAll to do. The KEYS are not here: a vehicle key is a
	-- real item in the bag (ItemCatalog CarKey/BoatKey/AirshipKey, with the plate in the slot's meta), so it
	-- saves with the inventory and can be handed to somebody else.
	Vehicles = nil,
	-- ของบนเกาะฟาร์ม {starter, placed = {{uid,id,x,z,r,crop?,at?}}, nextUid} | nil — Island/IslandBuild เขียนตรง
	-- เข้าตารางเหมือน Vehicles (ไม่มี serializer) ดู docs/superpowers/specs/2026-09-21-island-placement-design.md
	-- When the old daily chest was last opened. The chest it belonged to is gone -- it became the admin chest,
	-- which has no cooldown to remember -- but the field stays: every saved profile already has it, and
	-- removing a key from the template is how a Reconcile starts rewriting profiles for no reason.
	-- สมุดสะสม: ปลาที่เคยตกได้ และมอนที่เคยฆ่า
	--
	-- { Fish = { [itemId] = { n, best } }, Mobs = { [ชนิด] = จำนวน } } | nil = ยังไม่เคยเก็บอะไร
	-- Collection.lua เป็นคนเขียนลงตรงนี้ และ saveAll เซฟไปพร้อมทุกอย่าง ไม่ต้องมี serializer ของตัวเอง
	-- งานเควสที่รับไว้ ยังไม่ส่ง | nil = ไม่มีงานค้าง
	-- แคลนที่สังกัดอยู่ | nil = ยังไม่มีแคลน
	--
	-- เก็บแค่ id ตัวแคลนอยู่ใน DataStore ของมันเอง (ClanStore) เพราะแคลนเป็นของทั้งเกม ไม่ใช่ของคนเดียว
	ClanId = nil,
	-- แคลนที่ยื่นขอเข้าไว้ รอหัวแคลนอนุมัติ (id) ตอนเข้าเกม Clans.server จะไปดูว่าอนุมัติหรือยัง
	ClanApply = nil,
	-- เพชร (สกุลเงินพรีเมียม) ตอนนี้ได้จาก /gems เท่านั้น วันหน้าซื้อด้วยโรบัค
	Gems = 0,
	-- VIP หมดอายุเมื่อไหร่ (os.time) · 0 = ไม่เคยซื้อ (ผู้ใช้กำหนด 2026-09-20: ขายด้วยเพชรในหน้าร้านแคช)
	--
	-- เก็บเป็น "เวลาหมดอายุ" ไม่ใช่ธง true/false เพราะต่ออายุคือการบวกเวลาเพิ่ม และเวลาที่เหลือคือสิ่งที่
	-- คนจ่ายเงินอยากเห็น · เป็น os.time (เวลาจริง) ไม่ใช่ os.clock เพราะต้องเดินต่อตอนออกเกมด้วย
	VipUntil = 0,
	-- ออร่าที่เปิดอยู่ (item id) | nil = ปิด
	Aura = nil,
	-- ใส่ชุดแคลนอยู่ไหม (กดจากแหวนแคลน) | nil = ไม่ได้ใส่ — ออกจากแคลนแล้วถอดเองโดย ClanOutfit.server
	ClanOutfit = nil,
	-- แบทเทิลพาส { season, xp, premium, claimedFree = {[tier]=true}, claimedPremium = {[tier]=true} } | nil
	BattlePass = nil,
	Quests = nil,
	-- เควสที่ส่งไปแล้ววันนี้ { day = เลขวันจาก QuestConfig.DayNumber, keys = { ["เมือง|ชนิด|ของ"] = true } }
	-- | nil = ยังไม่เคยส่งอะไร — Quests.server ล้างทั้งก้อนเองเมื่อเลขวันเปลี่ยน (กันรับงานเดิมซ้ำในวันเดียว)
	QuestsDone = nil,
	Collection = nil,
	-- แต้มกิจกรรม สะสมข้ามเซสชัน ใช้จัดอันดับในหินสื่อสาร
	EventPoints = 0,
	-- เวลาที่พ้นโทษคุมขัง (os.time) | nil = ไม่ได้ติดคุก
	--
	-- เก็บเป็นเวลาที่พ้น ไม่ใช่ "เหลืออีกกี่วินาที" เพราะค่าที่นับถอยหลังจะหยุดเดินตอนออกจากเกม ซึ่งแปลว่า
	-- ออกเกมคือวิธีหนีคุก โทษต้องเดินตามเวลาจริงต่อไปแม้ไม่ได้เล่น
	JailUntil = nil,
	TestChestAt = 0,
	-- true = ได้ของเปิดตัว (เครื่องมือสามอย่าง คันเบ็ด ขนมปัง ล้อเดียว) ไปแล้ว — ครั้งเดียวต่อบัญชี ดู PlayerInventory
	StarterKit = nil,
	-- true = รับ VIP ฟรีจากหุ่นฟางจุดเกิดไปแล้ว — บัญชีละครั้ง ดู VipGift
	VipGiftClaimed = nil,
	-- ของขวัญหุ่นฟางอีกสองอย่าง (2026-09-27) ดู VipGift: true = บัญชีใหม่มีสิทธิ์รับ 150 เพชร · true = รับเพชรแล้ว ·
	-- id ออร่าที่ได้จากการมีเพื่อน 5 คน (มีค่า = รับแล้ว)
	NewbieGems = nil,
	NewbieGemsClaimed = nil,
	FriendAuraClaimed = nil,
	-- One-off test grant. Recorded in the profile so it happens once per player, ever, rather than on every
	-- rejoin. Bumping the number re-runs it for everyone; leave it alone to stop granting.
	TestGrant = 0,
	-- Which garage wipe this profile has already had. See GARAGE_RESET below.
	GarageReset = 0,
	-- กล่องจดหมายในหินเวท { {id, at, from, fromName, subject, body, items, gold, exp, claimed, read}, ... }
	-- | nil = ยังไม่เคยได้เมล · Mail.lua เขียนตรงเข้าตาราง (ไม่มี serializer เหมือน Vehicles)
	Mail = nil,
}

--------------------------------------------------------------------------------
-- One-off garage wipe
--------------------------------------------------------------------------------

-- Emptying every player's garage, at the user's instruction.
--
-- "Every player" cannot be done in one pass: a DataStore has no way to list its keys, so there is no such
-- thing as reaching profiles that are not loaded. What there is instead is a version number in each profile,
-- checked on the way in -- so the wipe happens once per player, the next time each of them joins, and never
-- again. Same shape as TestGrant above. **Raise this number to wipe everyone's garage again.**
local GARAGE_RESET = 1

local VehicleConfig = require(game.ReplicatedStorage.Vehicle.Config)
local KNOWN_PREFIX = {}
for _, spec in pairs(VehicleConfig.Types) do KNOWN_PREFIX[spec.prefix] = true end

local function wipeGarage(data)
	if (tonumber(data.GarageReset) or 0) >= GARAGE_RESET then return false end
	data.GarageReset = GARAGE_RESET

	-- The registrations themselves. Every vehicle, its trunk and its lock state.
	data.Vehicles = nil

	-- The keys are items in the bag, so they survive the line above and have to be dealt with here.
	--
	-- A key whose plate this game can still read is KEPT: its vehicle is gone, so under the two-step rule it
	-- reads as unregistered again and the player simply registers it once more. Its `registered` flag has to
	-- come off for that to be true -- a flag left set would say "this plate has an owner" about a plate that
	-- now has none, which is worse than either state on its own: the garage would offer to summon a vehicle
	-- that no longer exists in anybody's records.
	--
	-- A key whose plate is NOT readable is thrown away. Those are the ones the old test chest invented for
	-- itself before the vehicle system minted plates ("คข 8660") -- nothing in the game can summon, register
	-- or even name them, and they do nothing but take up slots.
	local slots = data.Inventory and data.Inventory.Slots
	if type(slots) == "table" then
		for index, slot in pairs(slots) do
			local meta = type(slot) == "table" and slot.meta or nil
			local plate = type(meta) == "table" and meta.plate or nil
			if type(plate) == "string" then
				if KNOWN_PREFIX[plate:sub(1, 3)] then
					meta.registered = nil
				else
					slots[index] = nil
				end
			end
		end
	end
	return true
end

local Store = ProfileStore.New("WOLD_PlayerProfile_v1", ProfileTemplate)
local Profiles = {} -- [player] = Profile, only ever populated in channel servers
local EndingOurselves = {} -- [player] = true while PlayerRemoving is ending this session on purpose

local function profileKey(userId)
	return "Player_" .. userId
end

local function resolvedSpawnPosition(profile)
	-- บนเกาะ พิกัดที่เซฟไว้เป็นของเมืองหลัก ซึ่งบนเกาะคือกลางอากาศ → ใช้ SpawnLocation ของเกาะเสมอ
	if ServerConfig.IsFarm then return SpawnSelector.ResolvePosition(nil) end
	local saved = profile.Data.Position
	local savedVector = saved and Vector3.new(saved.x, saved.y, saved.z)
	return SpawnSelector.ResolvePosition(savedVector)
end

local function savePosition(player)
	-- พิกัดเกมหลักในโปรไฟล์ต้องรอดข้ามการไปเกาะ ไม่งั้นกลับเมืองแล้วโผล่ที่ (0, 817, 0) ของเกาะ
	if ServerConfig.IsFarm then return end
	local profile = Profiles[player]
	local character = player.Character
	local hrp = character and character:FindFirstChild("HumanoidRootPart")
	if not profile or not hrp then return end
	local p = hrp.Position
	profile.Data.Position = { x = p.X, y = p.Y, z = p.Z }
end

-- Level and EXP ride along on the same save points as position. Progression publishes a serializer through
-- ProfileAccess rather than being required here, so this file keeps working in the lobby where Progression
-- never starts.
local function saveProgression(player)
	local profile = Profiles[player]
	local serialize = ProfileAccess.SerializeProgression
	if not profile or not serialize then return end
	local data = serialize(player)
	if data then profile.Data.Progression = data end
end

local function saveInventory(player)
	local profile = Profiles[player]
	local serialize = ProfileAccess.SerializeInventory
	if not profile or not serialize then return end
	local data = serialize(player)
	if data then profile.Data.Inventory = data end
end

local function saveRole(player)
	local profile = Profiles[player]
	local serialize = ProfileAccess.SerializeRole
	if not profile or not serialize then return end
	local data = serialize(player)
	-- Guarded like the others. Nil now means only one thing -- the player is no longer loaded in Classes --
	-- and writing that through wipes the class AND the offered-at levels that stop the card reappearing.
	-- Both PlayerClasses and this file answer PlayerRemoving, in an order Roblox does not define, so the
	-- unguarded version lost the whole Role on roughly every other logout.
	if data then profile.Data.Role = data end
end

local function saveSocial(player)
	local profile = Profiles[player]
	local serialize = ProfileAccess.SerializeSocial
	if not profile or not serialize then return end
	local data = serialize(player)
	if data then
		-- Merge rather than replace: the display fields (birthday, gender, picture) are not owned by the
		-- social modules, so a save must not wipe them.
		local existing = profile.Data.Social or {}
		for key, value in pairs(data) do existing[key] = value end
		profile.Data.Social = existing
	end
end

local function saveVault(player)
	local profile = Profiles[player]
	local serialize = ProfileAccess.SerializeVault
	if not profile or not serialize then return end
	local data = serialize(player)
	-- Guarded like Role's: nil means "not loaded here", and writing it through would empty a warehouse that
	-- is merely not in memory yet.
	if data then profile.Data.Vault = data end
end

local function saveAll(player)
	savePosition(player)
	saveProgression(player)
	saveInventory(player)
	saveRole(player)
	saveSocial(player)
	saveVault(player)
end

-- Published so the systems that OWN the data can flush it the moment it changes. ProfileStore only writes to
-- the DataStore on its own schedule, so calling this often is cheap — it just keeps the in-memory profile
-- current, which is what PlayerRemoving and BindToClose then persist. Without it, everything earned since the
-- last 7-second tick was lost by anyone who left in between.
-- อ่านโปรไฟล์ของ userId แบบไม่แตะเซสชัน — ใช้ในล็อบบี้ที่ไม่มีโปรไฟล์ของใครโหลดอยู่เลย
--
-- ถ้าคนนั้นมีโปรไฟล์เปิดอยู่ในเซิร์ฟนี้ ตอบจากในหน่วยความจำทันที (ไม่ยิง DataStore ซ้ำ)
-- ไม่งั้นค่อย `Store:GetAsync` ซึ่งเป็นการอ่านอย่างเดียว **ไม่ล็อกเซสชัน** จึงไม่ไปเตะคนที่กำลังเล่นอยู่
ProfileAccess.PeekAsync = function(userId)
	userId = tonumber(userId)
	if not userId then return nil end
	for player, profile in pairs(Profiles) do
		if player.UserId == userId then return profile.Data end
	end
	local ok, view = pcall(function() return Store:GetAsync(profileKey(userId)) end)
	if not ok or not view then return nil end
	return view.Data
end

ProfileAccess.MessageAsync = function(userId, message)
	userId = tonumber(userId)
	if not userId or type(message) ~= "table" then return false end
	local ok, sent = pcall(function() return Store:MessageAsync(profileKey(userId), message) end)
	return ok and sent == true
end

ProfileAccess.Flush = function(player)
	if Profiles[player] then saveAll(player) end
end

Remotes.GetSpawnPosition.OnServerInvoke = function(player)
	local profile = Profiles[player]
	if not profile then return SpawnSelector.ResolvePosition(nil) end -- lobby, or profile failed to load
	return resolvedSpawnPosition(profile)
end

if not ServerConfig.IsLobby then
	-- Through PlayerJoin rather than PlayerAdded directly: a reserved server is created because somebody is
	-- being teleported into it, and ServerConfig blocks on a DataStore call above -- so the player this server
	-- exists for can land before this line runs. PlayerAdded would never mention them, and they would play a
	-- whole session with no profile: default spawn, starter bag, level 1, nothing saved.
	PlayerJoin.Each(function(player)
		local profile = Store:StartSessionAsync(profileKey(player.UserId))
		if not profile then
			kick(player, "ไม่สามารถโหลดข้อมูลผู้เล่นได้ กรุณาเข้าเกมใหม่อีกครั้ง")
			return
		end
		profile:AddUserId(player.UserId)
		profile:Reconcile()

		-- ข้อความที่ฝากไว้ตอนเขาไม่ได้อยู่ในเซิร์ฟไหนเลย (การแจก VIP ผ่าน `/givevip` และเมลจาก Mail.lua)
		-- ProfileStore เก็บไว้ในเรคอร์ดของเขาเองและส่งให้ตรงนี้ **ต้องเรียก `processed()` เสมอ**
		-- ไม่งั้นข้อความค้างอยู่ในคิว แล้วถูกส่งซ้ำทุกครั้งที่เขาเข้าเกม = แจกซ้ำไม่รู้จบ
		--
		-- ผูกก่อน `ProfileAccess.Set` ได้ เพราะมันเขียนลง `profile.Data` ซึ่งเป็นตารางเดียวกับที่ Set
		-- จะส่งต่อไปอยู่แล้ว · ส่วนการประกาศ/แจ้งเตือนรอถึงหลังจากนั้นด้วย `task.defer`
		profile:MessageHandler(function(message, processed)
			-- เมล: Mail เป็นคนตัดสินว่าจะ processed เลยหรือรอคิว (กล่องเต็ม) — ห้าม processed แทนมันตรงนี้
			if type(message) == "table" and message.kind == "mail" then
				Mail.Deliver(player, profile.Data, message, processed)
				return
			end
			-- สถิติความสำเร็จจากสนาม PVP / บอสโลก (ตัดซ้ำด้วย id ใน Achievements)
			if type(message) == "table" and message.kind == "stats" then
				Achievements.AddStatsData(profile.Data, message)
				processed()
				return
			end
			local until_ = nil
			if type(message) == "table" and message.kind == "vip" then
				until_ = Vip.GrantData(profile.Data, message.days, message.onlyIfNone)
			end
			processed()
			if not until_ then return end
			local days = math.floor((until_ - os.time()) / 86400 + 0.5)
			print(("[VIP] %s ได้รับ VIP ที่ฝากไว้ (เหลือ %d วัน)"):format(player.Name, days))
			task.defer(function()
				if not player:IsDescendantOf(Players) then return end
				Vip.Publish(player)
				Remotes.PremiumUpdate:FireClient(player, { vipLeft = math.max(0, until_ - os.time()) })
				Remotes.SocialNotify:FireClient(player, "info",
					("ได้รับ VIP %d วัน — เปิดโหมดฟาร์มมิ่งได้แล้ว"):format(days))
			end)
		end)
		profile.OnSessionEnd:Connect(function()
			Profiles[player] = nil
			if EndingOurselves[player] then return end -- our own PlayerRemoving handler ended this, not a steal
			if player:IsDescendantOf(Players) then
				kick(player, "เซสชันข้อมูลของคุณถูกเปิดจากที่อื่น")
			end
		end)
		if not player:IsDescendantOf(Players) then
			profile:EndSession()
			return
		end
		Profiles[player] = profile

		-- Before the data is handed out. Vehicle/Store binds itself to profile.Data.Vehicles the moment it
		-- can see it, and PlayerInventory reads Inventory.Slots from the same place -- so the wipe has to be
		-- finished before either of them looks.
		if wipeGarage(profile.Data) then
			print(("[Garage] wiped %s's garage (reset %d)"):format(player.Name, GARAGE_RESET))
		end

		ProfileAccess.Set(player, profile.Data)

		-- Respawns after death go to the SPAWN POINT, not the saved position: dying at the bottom of a ravine
		-- or in deep water would otherwise drop the player straight back into what killed them. The saved
		-- position is for rejoining the server, which is the first CharacterAdded — and that one is
		-- choreographed by LoadingController.client.lua, so nothing here needs to move the character at all.
		-- (Vitals.lua handles the death/downed side; this file only decides where a fresh join lands, through
		-- the GetSpawnPosition RemoteFunction above.)
	end)

	-- Periodic in-memory position update: cheap (ProfileStore only actually writes to the DataStore on its own
	-- AUTO_SAVE_PERIOD, not on every Data mutation), and reduces how much movement a fast quit-and-rejoin race
	-- can lose (see the position spec's "third finding" — a hand-rolled version of this on the raw DataStore
	-- was tried and reverted because it didn't help; this one costs nothing extra to leave in).
	task.spawn(function()
		while true do
			task.wait(7)
			for _, player in ipairs(Players:GetPlayers()) do
				saveAll(player)
			end
		end
	end)

	-- The explicit "I am leaving" save used to live here, next to the teleport it has to come before. Both
	-- moved to LobbyTravel.server.lua when the trip grew a bar and a way to be cancelled; it calls
	-- ProfileAccess.Flush, which is saveAll under its published name, so the ordering guarantee is unchanged.

	Players.PlayerRemoving:Connect(function(player)
		saveAll(player)
		ProfileAccess.Set(player, nil)
		local profile = Profiles[player]
		Profiles[player] = nil
		if profile then
			EndingOurselves[player] = true
			profile:EndSession()
		end
	end)
end
