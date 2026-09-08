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
local TeleportService = game:GetService("TeleportService")
local ServerConfig = require(game.ServerScriptService.ServerConfig)
local ProfileStore = require(game.ServerScriptService.ProfileStore)
local ProfileAccess = require(game.ServerScriptService.ProfileAccess)
local Remotes = require(game.ReplicatedStorage.Remotes)
local SpawnSelector = require(game.ReplicatedStorage.SpawnSelector)

local ProfileTemplate = {
	Position = nil, -- {x, y, z} | nil (nil = never saved yet)
	Vitals = { HP = 100, Stamina = 100, Hunger = 100 }, -- unused this phase; here so later phases don't Reconcile again
	Progression = { Level = 1, Exp = 0 }, -- EXP/level survive a rejoin; dying is what resets them, not leaving
}

local Store = ProfileStore.New("WOLD_PlayerProfile_v1", ProfileTemplate)
local Profiles = {} -- [player] = Profile, only ever populated in channel servers
local EndingOurselves = {} -- [player] = true while PlayerRemoving is ending this session on purpose

local function profileKey(userId)
	return "Player_" .. userId
end

local function resolvedSpawnPosition(profile)
	local saved = profile.Data.Position
	local savedVector = saved and Vector3.new(saved.x, saved.y, saved.z)
	return SpawnSelector.ResolvePosition(savedVector)
end

local function savePosition(player)
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

local function saveAll(player)
	savePosition(player)
	saveProgression(player)
end

Remotes.GetSpawnPosition.OnServerInvoke = function(player)
	local profile = Profiles[player]
	if not profile then return SpawnSelector.ResolvePosition(nil) end -- lobby, or profile failed to load
	return resolvedSpawnPosition(profile)
end

if not ServerConfig.IsLobby then
	Players.PlayerAdded:Connect(function(player)
		local profile = Store:StartSessionAsync(profileKey(player.UserId))
		if not profile then
			player:Kick("ไม่สามารถโหลดข้อมูลผู้เล่นได้ กรุณาเข้าเกมใหม่อีกครั้ง")
			return
		end
		profile:AddUserId(player.UserId)
		profile:Reconcile()
		profile.OnSessionEnd:Connect(function()
			Profiles[player] = nil
			if EndingOurselves[player] then return end -- our own PlayerRemoving handler ended this, not a steal
			if player:IsDescendantOf(Players) then
				player:Kick("เซสชันข้อมูลของคุณถูกเปิดจากที่อื่น")
			end
		end)
		if not player:IsDescendantOf(Players) then
			profile:EndSession()
			return
		end
		Profiles[player] = profile
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

	-- Primary explicit save path: the client asks to return to the lobby, server saves THEN teleports.
	Remotes.RequestReturnToLobby.OnServerEvent:Connect(function(player)
		saveAll(player)
		local ok, err = pcall(function()
			TeleportService:Teleport(game.PlaceId, player)
		end)
		if not ok then warn("[PlayerProfile] return-to-lobby teleport failed for", player.UserId, err) end
	end)

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
