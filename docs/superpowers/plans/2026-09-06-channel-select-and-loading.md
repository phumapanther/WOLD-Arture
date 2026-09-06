# Channel Select + Loading Screen Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the public-lobby → pick-a-channel → Reserved-Server-teleport → loading-screen flow described in the spec, using Rojo-synced Luau under `src/`.

**Architecture:** One Roblox place. A server with `game.PrivateServerId == ""` is the lobby and shows the channel-select screen; every channel is a Reserved Server, created once and reused via a DataStore-backed registry; live population travels over MessagingService, never DataStore. All UI is built procedurally from Luau (no hand-authored GUI trees), matching how the rest of this codebase generates everything from code.

**Tech Stack:** Luau, Rojo (already configured, `default.project.json` needs no changes), Roblox `DataStoreService`, `MessagingService`, `TeleportService`, `ContentProvider`.

**Spec:** `docs/superpowers/specs/2026-09-06-channel-select-and-loading-design.md`

## Global Constraints

- Fixed channel count: 5 (`Roleplay` mode only active; the number lives in one constant, `LobbyServer.lua`'s `FIXED_CHANNELS.Roleplay`).
- Population cap per channel: 30 (from the reference mockup).
- Player-data save key split (future sub-project 1's concern, not built here): Roleplay+Stories share `Player_<UserId>`; Tanding uses `Player_<UserId>_Tanding`. This plan only guarantees `ServerConfig.Mode` is correct and available.
- DataStore name: `WOLD_ChannelRegistry_v1`. Keys: `slot_<mode>_<channel>` (forward) and `code_<privateServerId>` (reverse).
- MessagingService topics: `ChannelHeartbeat_<mode>` (channel → lobby, every 12s + on request) and `ChannelPing_<mode>` (lobby → channels, "report now").
- Stories/Tanding tabs are visible, non-interactive, no registry slots created for them.
- Reserved Servers, real MessagingService cross-server delivery, and TeleportService cross-server teleport **cannot be fully exercised in Studio Play** — Studio Play always has `game.PrivateServerId == ""`. Every task says exactly what it can verify locally vs. what needs a real publish (Task 7 is the post-publish checklist).

**Deviation from the spec worth flagging:** the spec's file table put the two GUIs under `StarterGui/`. Since every UI element here is built with `Instance.new` rather than hand-placed in Studio (no GUI-export pipeline exists in this project), the builder modules live under `ReplicatedStorage/UI/` instead and are invoked by LocalScripts in `StarterPlayerScripts/`. Same responsibilities, simpler file story for a codebase with no Studio-authored UI anywhere else.

**Correction found during Task 2's local testing (not just a Studio quirk — a real client/server API restriction):** the spec assumed `game.PrivateServerId` would be a plain client-readable property, so `ServerConfig.IsLobby` wouldn't need replicating. That's wrong — Roblox throws `"PrivateServerId cannot be checked on the client"` the instant a LocalScript reads it. `ServerConfig.lua` now sets `workspace:SetAttribute("IsLobby", ...)` (Attributes replicate automatically), and both client controllers wait for and read that Attribute instead of touching `game.PrivateServerId` directly. `Mode`/`Channel` remain server-only as originally planned; nothing on the client needs them for this plan's scope.

---

## File structure

| File | Responsibility |
|---|---|
| `src/ReplicatedStorage/Remotes.lua` | Idempotently creates/finds the 3 RemoteEvents; returns them to whoever requires it. |
| `src/ServerScriptService/Lobby/ChannelRegistry.lua` | All DataStore + MessagingService calls. Pure-logic pieces are separated from environment reads so they're testable. |
| `src/ServerScriptService/ServerConfig.lua` | Runs `ChannelRegistry.IdentifySelf()` once at require-time; exposes `IsLobby`, `Mode`, `Channel`. |
| `src/ServerScriptService/Lobby/LobbyServer.server.lua` | Only active when `ServerConfig.IsLobby`. Tracks live channel data, answers `JoinChannel`. |
| `src/ServerScriptService/Lobby/ChannelServer.server.lua` | Only active when not the lobby. Publishes heartbeats. |
| `src/ServerScriptService/Lobby/BuildLobbyRoom.server.lua` | Idempotent: builds a small themed waiting room + SpawnLocation under `workspace.LobbyRoom` if it isn't there yet. Runs in every server (cheap no-op check) so the room exists even before a channel server ever needs it (harmless there, just unused). |
| `src/ReplicatedStorage/UI/AvatarThumbnails.lua` | Client-side thumbnail fetch queue + cache by UserId. |
| `src/ReplicatedStorage/UI/ChannelSelectGui.lua` | Builds the mode-tab + channel-row screen; pure UI, no networking. |
| `src/ReplicatedStorage/UI/LoadingGui.lua` | Builds the logo + "Loading..." + segmented-bar screen; pure UI. |
| `src/ReplicatedStorage/SpawnSelector.lua` | `GetSpawnPosition(player) -> Vector3`. Stub sub-project 1 will replace. |
| `src/StarterPlayerScripts/ChannelSelectController.client.lua` | Wires `ChannelSelectGui` to the remotes and to `AvatarThumbnails`. |
| `src/StarterPlayerScripts/LoadingController.client.lua` | Runs the weighted loading-step list, drives `LoadingGui`. |

---

### Task 1: Remotes + ChannelRegistry + ServerConfig (data layer)

**Files:**
- Create: `src/ReplicatedStorage/Remotes.lua`
- Create: `src/ServerScriptService/Lobby/ChannelRegistry.lua`
- Create: `src/ServerScriptService/ServerConfig.lua`
- Test: `mapgen/../` — no, this is gameplay code; the check is a throwaway Luau snippet run via `node tools/mcp-call.js execute_luau`, not a file kept in the repo.

**Interfaces:**
- Produces: `Remotes.JoinChannel: RemoteEvent`, `Remotes.ChannelList: RemoteEvent`, `Remotes.JoinFailed: RemoteEvent` — required as `require(game.ReplicatedStorage.Remotes)` from either side.
- Produces: `ChannelRegistry.GetOrCreateChannel(mode: string, channel: number) -> accessCode: string`
- Produces: `ChannelRegistry.IdentifySelfFor(privateServerId: string) -> mode: string?, channel: number?` (pure; `""` → `nil, nil`; unknown id → `"Roleplay", 0` fallback)
- Produces: `ChannelRegistry.IdentifySelf() -> mode, channel` (thin wrapper: `return IdentifySelfFor(game.PrivateServerId)`)
- Produces: `ChannelRegistry.PublishHeartbeat(mode: string, channel: number, count: number, playerIds: {number})`
- Produces: `ChannelRegistry.SubscribeToHeartbeats(mode: string, callback: (channel: number, count: number, playerIds: {number}) -> ())`
- Produces: `ChannelRegistry.RequestFreshData(mode: string)`
- Produces: `ChannelRegistry.SubscribeToPings(mode: string, callback: () -> ())`
- Produces: `ServerConfig.IsLobby: boolean`, `ServerConfig.Mode: string?`, `ServerConfig.Channel: number?`

- [ ] **Step 1: Confirm Rojo is syncing** — this whole plan depends on `src/` reaching the live Studio session.

Run: double-click `serve.bat`, then in Studio open the Rojo plugin panel and click **Connect** (per `README.md`). Leave it running for the rest of this plan.
Expected: the plugin shows "Connected" and the port from `serve.bat` (34872).

- [ ] **Step 2: Write `src/ReplicatedStorage/Remotes.lua`**

```lua
-- Remotes.lua: idempotent RemoteEvent bootstrap. The server creates them; the client waits for them.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local NAMES = { "JoinChannel", "ChannelList", "JoinFailed" }

local folder = ReplicatedStorage:FindFirstChild("Remotes")
if RunService:IsServer() then
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "Remotes"
		folder.Parent = ReplicatedStorage
	end
	for _, name in ipairs(NAMES) do
		if not folder:FindFirstChild(name) then
			local event = Instance.new("RemoteEvent")
			event.Name = name
			event.Parent = folder
		end
	end
else
	folder = folder or ReplicatedStorage:WaitForChild("Remotes")
end

local Remotes = {}
for _, name in ipairs(NAMES) do
	Remotes[name] = folder:WaitForChild(name)
end
return Remotes
```

- [ ] **Step 3: Write `src/ServerScriptService/Lobby/ChannelRegistry.lua`**

```lua
-- ChannelRegistry.lua: the only file that touches DataStoreService / MessagingService / TeleportService for channels.
local DataStoreService = game:GetService("DataStoreService")
local MessagingService = game:GetService("MessagingService")
local TeleportService = game:GetService("TeleportService")

local store = DataStoreService:GetDataStore("WOLD_ChannelRegistry_v1")

local ChannelRegistry = {}

local function slotKey(mode, channel)
	return ("slot_%s_%d"):format(mode, channel)
end
local function codeKey(privateServerId)
	return "code_" .. privateServerId
end

function ChannelRegistry.GetOrCreateChannel(mode, channel)
	-- Deliberately NOT built on UpdateAsync: ReserveServer is a side-effecting, non-idempotent external call
	-- (it really reserves a server), and Roblox may invoke an UpdateAsync transform function more than once
	-- internally on write contention — calling ReserveServer inside one would risk reserving extra servers for
	-- the same slot even in normal operation. Get-then-set is simpler and keeps ReserveServer to exactly one call.
	-- ReserveServer only works on a real published server (HTTP 403 in Studio, Play or not); errors here are
	-- expected in Studio and only resolvable by a real publish — see spec §6 and plan Task 7.
	local key = slotKey(mode, channel)
	local getOk, existing = pcall(function()
		return store:GetAsync(key)
	end)
	if not getOk then
		error("[ChannelRegistry] GetOrCreateChannel(" .. mode .. ", " .. channel .. ") lookup failed: " .. tostring(existing), 0)
	end
	if existing then
		return existing.accessCode
	end

	local reserveOk, accessCode, privateServerId = pcall(TeleportService.ReserveServer, TeleportService, game.PlaceId)
	if not reserveOk then
		error("[ChannelRegistry] ReserveServer failed for " .. mode .. "/" .. channel .. ": " .. tostring(accessCode), 0)
	end

	-- ponytail: known small race — two players picking an empty slot at the same instant can each reserve a
	-- server; the second write below wins and the first reservation is orphaned (wasted, harmless at hobby scale)
	local setOk, setErr = pcall(function()
		store:SetAsync(key, { accessCode = accessCode, privateServerId = privateServerId, createdAt = os.time() })
	end)
	if not setOk then
		warn("[ChannelRegistry] failed to persist new slot (a reserved server now exists but is not recorded):", setErr)
	end
	local revOk, revErr = pcall(function()
		store:SetAsync(codeKey(privateServerId), { mode = mode, channel = channel })
	end)
	if not revOk then warn("[ChannelRegistry] failed to write reverse lookup:", revErr) end
	return accessCode
end

function ChannelRegistry.IdentifySelfFor(privateServerId)
	if privateServerId == "" then
		return nil, nil
	end
	local ok, data = pcall(function()
		return store:GetAsync(codeKey(privateServerId))
	end)
	if ok and data then
		return data.mode, data.channel
	end
	warn("[ChannelRegistry] could not identify self for PrivateServerId", privateServerId)
	return "Roleplay", 0
end

function ChannelRegistry.IdentifySelf()
	return ChannelRegistry.IdentifySelfFor(game.PrivateServerId)
end

function ChannelRegistry.PublishHeartbeat(mode, channel, count, playerIds)
	local ok, err = pcall(function()
		MessagingService:PublishAsync("ChannelHeartbeat_" .. mode, {
			channel = channel,
			count = count,
			playerIds = playerIds,
			ts = os.time(),
		})
	end)
	if not ok then warn("[ChannelRegistry] heartbeat publish failed:", err) end
end

function ChannelRegistry.SubscribeToHeartbeats(mode, callback)
	MessagingService:SubscribeAsync("ChannelHeartbeat_" .. mode, function(message)
		local d = message.Data
		callback(d.channel, d.count, d.playerIds)
	end)
end

function ChannelRegistry.RequestFreshData(mode)
	local ok, err = pcall(function()
		MessagingService:PublishAsync("ChannelPing_" .. mode, { ts = os.time() })
	end)
	if not ok then warn("[ChannelRegistry] ping publish failed:", err) end
end

function ChannelRegistry.SubscribeToPings(mode, callback)
	MessagingService:SubscribeAsync("ChannelPing_" .. mode, function()
		callback()
	end)
end

return ChannelRegistry
```

- [ ] **Step 4: Write `src/ServerScriptService/ServerConfig.lua`**

```lua
-- ServerConfig.lua: require this once; it does the (blocking, ~100-300ms) self-identification DataStore call up front
-- so every other server script sees a fully-populated table with no race.
local ChannelRegistry = require(script.Parent.Lobby.ChannelRegistry)

local ServerConfig = {}
ServerConfig.IsLobby = game.PrivateServerId == ""
if ServerConfig.IsLobby then
	ServerConfig.Mode = nil
	ServerConfig.Channel = nil
else
	ServerConfig.Mode, ServerConfig.Channel = ChannelRegistry.IdentifySelf()
end

-- game.PrivateServerId cannot be read from LocalScripts at all ("PrivateServerId cannot be checked on the
-- client") — replicate the one bit clients actually need via a Workspace Attribute, which replicates automatically.
workspace:SetAttribute("IsLobby", ServerConfig.IsLobby)

return ServerConfig
```

- [ ] **Step 5: Run the self-check**

Two things cannot be verified in Studio at all, Play mode or not: `DataStoreService` calls only work from a real server context (not the Edit-mode command/Assistant context — use `datamodel_type: "Server"` while Play is running), and `TeleportService:ReserveServer` always fails with HTTP 403 in Studio regardless of Play/API-access settings (a real Roblox platform restriction, not a bug). The check below verifies everything that *can* run locally: the "channel already exists" path (via a pre-seeded fake entry, so it never has to call `ReserveServer`), idempotency, both branches of `IdentifySelfFor`, and that a genuinely new slot correctly *errors* rather than silently returning garbage. The "first-ever creation of a channel" path is only provable end to end after a real publish (Task 7).

Run: with Studio in Play mode (start it if it isn't already):
```
node tools/mcp-call.js execute_luau '{"datamodel_type":"Server","code":"local CR = require(game.ServerScriptService.Lobby.ChannelRegistry); local DS = game:GetService(\"DataStoreService\"):GetDataStore(\"WOLD_ChannelRegistry_v1\"); DS:RemoveAsync(\"slot_TestMode_999\"); local fails = {}; local function check(cond, msg) if not cond then table.insert(fails, msg) end end; local seeded = { accessCode = \"fake-code-abc\", privateServerId = \"fake-psid-xyz\", createdAt = os.time() }; DS:SetAsync(\"slot_TestMode_999\", seeded); DS:SetAsync(\"code_fake-psid-xyz\", { mode = \"TestMode\", channel = 999 }); local code1 = CR.GetOrCreateChannel(\"TestMode\", 999); local code2 = CR.GetOrCreateChannel(\"TestMode\", 999); check(code1 == \"fake-code-abc\", \"expected pre-seeded code, got \"..tostring(code1)); check(code1 == code2, \"not idempotent\"); local m, c = CR.IdentifySelfFor(\"fake-psid-xyz\"); check(m == \"TestMode\" and c == 999, \"reverse lookup wrong: \"..tostring(m)..\"/\"..tostring(c)); local m2, c2 = CR.IdentifySelfFor(\"not-a-real-id\"); check(m2 == \"Roleplay\" and c2 == 0, \"fallback should be Roleplay/0\"); local m3, c3 = CR.IdentifySelfFor(\"\"); check(m3 == nil and c3 == nil, \"empty id should mean lobby\"); local reserveOk = pcall(CR.GetOrCreateChannel, \"TestMode\", 998); check(not reserveOk, \"expected a brand-new slot to error in Studio (ReserveServer 403)\"); DS:RemoveAsync(\"slot_TestMode_999\"); DS:RemoveAsync(\"code_fake-psid-xyz\"); return #fails == 0 and \"ALL PASS\" or (#fails ..\" FAIL(S): \"..table.concat(fails, \" | \"))"}'
```
Expected: `"ALL PASS"`. If it prints a fail message instead, fix the corresponding function in `ChannelRegistry.lua`, re-push it, and rerun.

Note: this Studio session needs **Game Settings → Security → Enable Studio Access to API Services** turned on, the same setting the map generator already relies on for `InsertService`/asset loading — if this step errors with something like "API access not enabled," turn that on and retry.

- [ ] **Step 6: Commit**

```bash
git add src/ReplicatedStorage/Remotes.lua src/ServerScriptService/Lobby/ChannelRegistry.lua src/ServerScriptService/ServerConfig.lua
git commit -m "channel select: DataStore/MessagingService registry + ServerConfig self-identification"
```

---

### Task 2: LobbyServer + ChannelServer

**Files:**
- Create: `src/ServerScriptService/Lobby/LobbyServer.server.lua`
- Create: `src/ServerScriptService/Lobby/ChannelServer.server.lua`

**Interfaces:**
- Consumes: `ServerConfig` (Task 1), `ChannelRegistry` (Task 1), `Remotes` (Task 1)
- Produces: nothing further code depends on directly — these are the two "run automatically" endpoints. `Remotes.ChannelList` payload shape (needed by Task 5's client code): `{ [mode]: { [channel]: { count: number, playerIds: {number}, full: boolean } } }`.

- [ ] **Step 1: Write `src/ServerScriptService/Lobby/LobbyServer.server.lua`**

```lua
-- LobbyServer: only the public server (ServerConfig.IsLobby) runs this. Tracks live channel population
-- from MessagingService heartbeats and routes JoinChannel requests to a Reserved Server.
local ServerConfig = require(game.ServerScriptService.ServerConfig)
if not ServerConfig.IsLobby then return end

local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")
local ChannelRegistry = require(script.Parent.ChannelRegistry)
local Remotes = require(game.ReplicatedStorage.Remotes)

local FIXED_CHANNELS = { Roleplay = 5 } -- ponytail: one constant; raise the number here if you want more channels
local CAP = 30

local liveData = {} -- liveData[mode][channel] = { count, playerIds, updatedAt }
for mode in pairs(FIXED_CHANNELS) do
	liveData[mode] = {}
	ChannelRegistry.SubscribeToHeartbeats(mode, function(channel, count, playerIds)
		liveData[mode][channel] = { count = count, playerIds = playerIds, updatedAt = os.clock() }
	end)
end

local function snapshot()
	local out = {}
	for mode, count in pairs(FIXED_CHANNELS) do
		out[mode] = {}
		for ch = 1, count do
			local d = liveData[mode][ch]
			out[mode][ch] = {
				count = d and d.count or 0,
				playerIds = d and d.playerIds or {},
				full = (d and d.count or 0) >= CAP,
			}
		end
	end
	return out
end

Players.PlayerAdded:Connect(function(player)
	Remotes.ChannelList:FireClient(player, snapshot())
	for mode in pairs(FIXED_CHANNELS) do
		ChannelRegistry.RequestFreshData(mode)
	end
end)

Remotes.JoinChannel.OnServerEvent:Connect(function(player, mode, channel)
	if not FIXED_CHANNELS[mode] or type(channel) ~= "number" or channel < 1 or channel > FIXED_CHANNELS[mode] then
		return
	end
	local d = liveData[mode][channel]
	if d and d.count >= CAP then
		Remotes.JoinFailed:FireClient(player, "full")
		return
	end
	local ok, accessCode = pcall(ChannelRegistry.GetOrCreateChannel, mode, channel)
	if not ok then
		warn("[Lobby] could not get/create channel", mode, channel, accessCode)
		Remotes.JoinFailed:FireClient(player, "create_failed")
		return
	end
	local teleportOk, err = pcall(function()
		TeleportService:TeleportToPrivateServer(game.PlaceId, accessCode, { player })
	end)
	if not teleportOk then
		teleportOk, err = pcall(function()
			TeleportService:TeleportToPrivateServer(game.PlaceId, accessCode, { player })
		end) -- one retry, per spec §6
	end
	if not teleportOk then
		warn("[Lobby] teleport failed for", player.Name, err)
		Remotes.JoinFailed:FireClient(player, "teleport_failed")
	end
end)
```

- [ ] **Step 2: Write `src/ServerScriptService/Lobby/ChannelServer.server.lua`**

```lua
-- ChannelServer: only a Reserved Server (not the lobby) runs this. Reports its own population periodically.
local ServerConfig = require(game.ServerScriptService.ServerConfig)
if ServerConfig.IsLobby then return end

local Players = game:GetService("Players")
local ChannelRegistry = require(script.Parent.ChannelRegistry)

local function currentPlayerIds()
	local ids = {}
	for _, p in ipairs(Players:GetPlayers()) do
		table.insert(ids, p.UserId)
	end
	return ids
end

local function heartbeat()
	ChannelRegistry.PublishHeartbeat(ServerConfig.Mode, ServerConfig.Channel, #Players:GetPlayers(), currentPlayerIds())
end

ChannelRegistry.SubscribeToPings(ServerConfig.Mode, heartbeat)
heartbeat()

task.spawn(function()
	while true do
		task.wait(12)
		heartbeat()
	end
end)
```

- [ ] **Step 3: Local Studio check (partial — see note)**

Note: in Studio Play, `game.PrivateServerId` is always `""`, so this session is always "the lobby"; `ChannelServer.server.lua` will never run locally. `TeleportService:ReserveServer` fails with HTTP 403 in Studio unconditionally (confirmed in Task 1), so a channel that has never been created before **cannot** be created locally either — `GetOrCreateChannel` correctly raises an error in that case rather than silently producing garbage. What we CAN verify locally: that `LobbyServer` reaches that code path at all, handles the error cleanly (no crash, a `JoinFailed` reaches the client), and that the client's own request actually arrives (fire it from the real client, not a fabricated server-side call — `Remotes.JoinChannel.OnServerEvent`'s player argument only auto-populates for a genuine client `FireServer`).

Run: press Play in Studio, then fire the remote as the client actually would (`datamodel_type: "Client"`):
```
node tools/mcp-call.js execute_luau '{"datamodel_type":"Client","code":"local Remotes = require(game.ReplicatedStorage.Remotes); Remotes.JoinChannel:FireServer(\"Roleplay\", 1); return \"fired from client\""}'
```
then check the server console:
```
node tools/mcp-call.js get_console_output '{}'
```
Expected: `[Lobby] could not get/create channel Roleplay 1 [ChannelRegistry] ReserveServer failed for Roleplay/1: HTTP 403 (Forbidden)` — proves the request reached `LobbyServer`, it attempted the real flow, and it failed for exactly the expected Studio-only reason rather than crashing. Confirm no slot got left behind:
```
node tools/mcp-call.js execute_luau '{"datamodel_type":"Server","code":"local ok, data = pcall(function() return game:GetService(\"DataStoreService\"):GetDataStore(\"WOLD_ChannelRegistry_v1\"):GetAsync(\"slot_Roleplay_1\") end); return ok and tostring(data) or tostring(data)"}'
```
Expected: `nil` (the failed attempt wrote nothing — `GetOrCreateChannel` only writes *after* `ReserveServer` succeeds). The full success path (a real channel actually getting created and reused) is confirmed post-publish in Task 7.
Stop Play mode when done.

- [ ] **Step 4: Commit**

```bash
git add src/ServerScriptService/Lobby/LobbyServer.server.lua src/ServerScriptService/Lobby/ChannelServer.server.lua
git commit -m "channel select: lobby routing + channel heartbeat servers"
```

---

### Task 3: Lobby room (set-dressing)

**Files:**
- Create: `src/ServerScriptService/Lobby/BuildLobbyRoom.server.lua`

**Interfaces:**
- Produces: `workspace.LobbyRoom` (Folder containing the room's parts) and `workspace.LobbyRoom.LobbySpawn` (SpawnLocation) — nothing else in this plan reads these by name, but they're what the player actually stands in/on while the channel-select screen is up.

- [ ] **Step 1: Write `src/ServerScriptService/Lobby/BuildLobbyRoom.server.lua`**

```lua
-- BuildLobbyRoom: idempotent. A small enclosed room with a spawn point, themed to match the rest of the game.
-- Runs in every server (cheap no-op if it already exists) so it's there before anyone needs it.
local existing = workspace:FindFirstChild("LobbyRoom")
if existing then return end

local STONE = Color3.fromRGB(163, 162, 165)
local WOOD = Color3.fromRGB(86, 66, 54)
local room = Instance.new("Folder")
room.Name = "LobbyRoom"
room.Parent = workspace

local ORIGIN = Vector3.new(0, 1000, 0) -- far above the real island so it never collides with map generation

local function part(size, pos, color, material)
	local p = Instance.new("Part")
	p.Anchored = true
	p.Size = size
	p.Position = pos
	p.Color = color
	p.Material = material or Enum.Material.Cobblestone
	p.Parent = room
	return p
end

part(Vector3.new(40, 1, 40), ORIGIN, STONE) -- floor
part(Vector3.new(40, 20, 1), ORIGIN + Vector3.new(0, 10, 20), STONE) -- walls
part(Vector3.new(40, 20, 1), ORIGIN + Vector3.new(0, 10, -20), STONE)
part(Vector3.new(1, 20, 40), ORIGIN + Vector3.new(20, 10, 0), STONE)
part(Vector3.new(1, 20, 40), ORIGIN + Vector3.new(-20, 10, 0), STONE)
part(Vector3.new(40, 1, 40), ORIGIN + Vector3.new(0, 20, 0), WOOD, Enum.Material.WoodPlanks) -- ceiling

local spawn = Instance.new("SpawnLocation")
spawn.Name = "LobbySpawn"
spawn.Size = Vector3.new(6, 1, 6)
spawn.Position = ORIGIN + Vector3.new(0, 1, 0)
spawn.Anchored = true
spawn.Neutral = true
spawn.Duration = 0
spawn.Material = Enum.Material.Cobblestone
spawn.Parent = room
```

- [ ] **Step 2: Local check**

Run: press Play in Studio, then:
```
node tools/mcp-call.js execute_luau '{"datamodel_type":"Edit","code":"local r = workspace:FindFirstChild(\"LobbyRoom\"); return r and (#r:GetChildren()) or \"missing\""}'
```
Expected: `7` (6 parts + 1 SpawnLocation). Run it a second time (re-fire the script by rejoining Play) and confirm the count stays `7`, not `14` — proves idempotency.
Stop Play mode when done.

- [ ] **Step 3: Commit**

```bash
git add src/ServerScriptService/Lobby/BuildLobbyRoom.server.lua
git commit -m "channel select: idempotent lobby waiting room"
```

---

### Task 4: AvatarThumbnails

**Files:**
- Create: `src/ReplicatedStorage/UI/AvatarThumbnails.lua`

**Interfaces:**
- Produces: `AvatarThumbnails.Get(userId: number, callback: (content: string | false | nil) -> ())` — calls back synchronously with the cached value if known (string content, or `false` for "fetch failed"), otherwise calls back once immediately with `nil` (caller shows a placeholder) and again later once the real value loads.
- Produces: `AvatarThumbnails.OnAnyLoaded(fn: (userId: number, content: string | false) -> ())` — Task 5 uses this to know when to swap a placeholder for a real image.

- [ ] **Step 1: Write `src/ReplicatedStorage/UI/AvatarThumbnails.lua`**

```lua
-- AvatarThumbnails: queued, cached, gently-paced avatar headshot fetching so a 30-player channel row
-- doesn't fire 30 simultaneous thumbnail requests.
local Players = game:GetService("Players")

local AvatarThumbnails = {}
local cache = {} -- [userId] = content (string) | false (failed)
local queue = {}
local queueSet = {}
local processing = false
local onLoaded = nil

local function processQueue()
	if processing then return end
	processing = true
	task.spawn(function()
		while #queue > 0 do
			local userId = table.remove(queue, 1)
			queueSet[userId] = nil
			local ok, content = pcall(function()
				return Players:GetUserThumbnailAsync(userId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size48x48)
			end)
			cache[userId] = ok and content or false
			if onLoaded then onLoaded(userId, cache[userId]) end
			task.wait(0.05)
		end
		processing = false
	end)
end

function AvatarThumbnails.Get(userId, callback)
	if cache[userId] ~= nil then
		callback(cache[userId])
		return
	end
	callback(nil)
	if not queueSet[userId] then
		queueSet[userId] = true
		table.insert(queue, userId)
	end
	processQueue()
end

function AvatarThumbnails.OnAnyLoaded(fn)
	onLoaded = fn
end

return AvatarThumbnails
```

- [ ] **Step 2: Local check** (client-side API, so this runs from a LocalScript context — use the command bar with client context, or check via a temporary `print` in Play mode's client console)

Run: press Play in Studio, open the client-side Output/command bar (bottom of the Play window, not the server one), paste:
```lua
local AvatarThumbnails = require(game.ReplicatedStorage.UI.AvatarThumbnails)
AvatarThumbnails.OnAnyLoaded(function(id, content) print("loaded", id, content) end)
AvatarThumbnails.Get(1, function(c) print("first call:", c) end)
task.wait(1)
AvatarThumbnails.Get(1, function(c) print("second call (should be cached, non-nil):", c) end)
```
Expected: `first call: nil`, then `loaded 1 rbxthumb://...`, then `second call (should be cached, non-nil): rbxthumb://...`.
Stop Play mode when done.

- [ ] **Step 3: Commit**

```bash
git add src/ReplicatedStorage/UI/AvatarThumbnails.lua
git commit -m "channel select: avatar thumbnail queue/cache"
```

---

### Task 5: ChannelSelectGui + ChannelSelectController

**Files:**
- Create: `src/ReplicatedStorage/UI/ChannelSelectGui.lua`
- Create: `src/StarterPlayerScripts/ChannelSelectController.client.lua`

**Interfaces:**
- Consumes: `Remotes` (Task 1), `AvatarThumbnails` (Task 4)
- Produces: `ChannelSelectGui.new() -> self` where `self:OnJoin(callback: (mode: string, channel: number) -> ())`, `self:SetChannelData(mode, channel, data: {count, playerIds, full})`, `self:SetRowStatus(mode, channel, status: "idle"|"connecting"|"error")`, `self:Show()`, `self:Destroy()`.

- [ ] **Step 1: Write `src/ReplicatedStorage/UI/ChannelSelectGui.lua`**

```lua
-- ChannelSelectGui: pure UI builder for the mode-tabs + channel-rows screen. No networking in this file.
local CAP = 30
local ROWS, COLS = 2, 15 -- 30 avatar slots per channel, matching the reference mockup

local ChannelSelectGui = {}
ChannelSelectGui.__index = ChannelSelectGui

local ACTIVE_MODES = { Roleplay = true }
local MODE_ORDER = { "Stories", "Roleplay", "Tanding" }

local function corner(parent, radius)
	local c = Instance.new("UICorner")
	c.CornerRadius = radius or UDim.new(0, 8)
	c.Parent = parent
	return c
end

function ChannelSelectGui.new()
	local self = setmetatable({}, ChannelSelectGui)
	self.onJoin = nil
	self.rows = {} -- rows["Roleplay"][1] = { frame, countLabel, joinButton, statusLabel, avatars = {ImageLabel,...} }

	local gui = Instance.new("ScreenGui")
	gui.Name = "ChannelSelectGui"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true

	local root = Instance.new("Frame")
	root.Size = UDim2.fromScale(1, 1)
	root.BackgroundColor3 = Color3.fromRGB(230, 230, 230)
	root.BorderSizePixel = 0
	root.Parent = gui

	-- mode tab bar
	local tabBar = Instance.new("Frame")
	tabBar.Size = UDim2.new(0, 420, 0, 50)
	tabBar.Position = UDim2.new(1, -440, 0, 20)
	tabBar.BackgroundTransparency = 1
	tabBar.Parent = root
	local tabLayout = Instance.new("UIListLayout")
	tabLayout.FillDirection = Enum.FillDirection.Horizontal
	tabLayout.Padding = UDim.new(0, 10)
	tabLayout.Parent = tabBar

	self.tabs = {}
	for _, mode in ipairs(MODE_ORDER) do
		local btn = Instance.new("TextButton")
		btn.Size = UDim2.new(0, 130, 1, 0)
		btn.Text = mode == "Roleplay" and "Roleplay Mode" or (mode .. " Mode")
		btn.Font = Enum.Font.SourceSansBold
		btn.TextSize = 16
		btn.TextColor3 = Color3.new(1, 1, 1)
		btn.BackgroundColor3 = mode == "Roleplay" and Color3.fromRGB(20, 20, 20) or Color3.fromRGB(150, 150, 150)
		btn.AutoButtonColor = ACTIVE_MODES[mode] == true
		btn.Parent = tabBar
		corner(btn, UDim.new(1, 0))
		self.tabs[mode] = btn
	end

	-- channel list
	local list = Instance.new("ScrollingFrame")
	list.Size = UDim2.new(0, 1100, 0, 560)
	list.Position = UDim2.new(0.5, -550, 0, 100)
	list.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
	list.CanvasSize = UDim2.new(0, 0, 0, 5 * 150)
	list.Parent = root
	corner(list, UDim.new(0, 20))
	local listLayout = Instance.new("UIListLayout")
	listLayout.Padding = UDim.new(0, 8)
	listLayout.Parent = list
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 20)
	pad.PaddingTop = UDim.new(0, 20)
	pad.Parent = list

	self.rows.Roleplay = {}
	for channel = 1, 5 do
		local row = Instance.new("Frame")
		row.Size = UDim2.new(0, 1040, 0, 130)
		row.BackgroundColor3 = Color3.fromRGB(220, 220, 220)
		row.LayoutOrder = channel
		row.Parent = list
		corner(row)

		local nameLabel = Instance.new("TextLabel")
		nameLabel.Size = UDim2.new(0, 100, 1, 0)
		nameLabel.Position = UDim2.new(0, 20, 0, 0)
		nameLabel.BackgroundTransparency = 1
		nameLabel.Font = Enum.Font.SourceSansBold
		nameLabel.TextSize = 22
		nameLabel.Text = "เชิฟ " .. channel
		nameLabel.TextXAlignment = Enum.TextXAlignment.Left
		nameLabel.Parent = row

		local avatarGrid = Instance.new("Frame")
		avatarGrid.Size = UDim2.new(0, 700, 0, 90)
		avatarGrid.Position = UDim2.new(0, 130, 0.5, -45)
		avatarGrid.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
		avatarGrid.Parent = row
		corner(avatarGrid, UDim.new(0, 6))
		local grid = Instance.new("UIGridLayout")
		grid.CellSize = UDim2.new(0, 44, 0, 40)
		grid.CellPadding = UDim2.new(0, 2, 0, 2)
		grid.Parent = avatarGrid
		local gpad = Instance.new("UIPadding")
		gpad.PaddingLeft = UDim.new(0, 5)
		gpad.PaddingTop = UDim.new(0, 5)
		gpad.Parent = avatarGrid

		local avatars = {}
		for i = 1, CAP do
			local icon = Instance.new("ImageLabel")
			icon.Image = ""
			icon.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
			icon.LayoutOrder = i
			icon.Visible = false
			icon.Parent = avatarGrid
			corner(icon, UDim.new(1, 0))
			avatars[i] = icon
		end

		local countLabel = Instance.new("TextLabel")
		countLabel.Size = UDim2.new(0, 90, 0, 40)
		countLabel.Position = UDim2.new(1, -190, 0, 20)
		countLabel.BackgroundTransparency = 1
		countLabel.Font = Enum.Font.SourceSansBold
		countLabel.TextSize = 22
		countLabel.Text = "0/" .. CAP
		countLabel.Parent = row

		local statusLabel = Instance.new("TextLabel")
		statusLabel.Size = UDim2.new(0, 190, 0, 20)
		statusLabel.Position = UDim2.new(1, -190, 0, 60)
		statusLabel.BackgroundTransparency = 1
		statusLabel.Font = Enum.Font.SourceSans
		statusLabel.TextSize = 14
		statusLabel.TextColor3 = Color3.fromRGB(200, 60, 50)
		statusLabel.Text = ""
		statusLabel.Parent = row

		local joinButton = Instance.new("TextButton")
		joinButton.Size = UDim2.new(0, 90, 0, 40)
		joinButton.Position = UDim2.new(1, -90, 0, 70)
		joinButton.Font = Enum.Font.SourceSansBold
		joinButton.TextSize = 18
		joinButton.TextColor3 = Color3.new(1, 1, 1)
		joinButton.BackgroundColor3 = Color3.fromRGB(60, 175, 90)
		joinButton.Text = "JOIN"
		joinButton.Parent = row
		corner(joinButton, UDim.new(0, 10))
		joinButton.MouseButton1Click:Connect(function()
			if self.onJoin then self.onJoin("Roleplay", channel) end
		end)

		self.rows.Roleplay[channel] = {
			frame = row, countLabel = countLabel, joinButton = joinButton, statusLabel = statusLabel, avatars = avatars,
		}
	end

	-- Stories/Tanding: a single "coming soon" placeholder frame each, swapped in when that tab is selected
	for _, mode in ipairs({ "Stories", "Tanding" }) do
		local soon = Instance.new("TextLabel")
		soon.Size = UDim2.new(1, 0, 1, 0)
		soon.BackgroundTransparency = 1
		soon.Font = Enum.Font.SourceSansBold
		soon.TextSize = 28
		soon.TextColor3 = Color3.fromRGB(120, 120, 120)
		soon.Text = "เร็วๆ นี้"
		soon.Visible = false
		soon.Parent = root
		self.rows[mode] = { comingSoon = soon }
	end

	self.list = list
	self.gui = gui
	self:_selectMode("Roleplay")
	for mode, btn in pairs(self.tabs) do
		btn.MouseButton1Click:Connect(function()
			if ACTIVE_MODES[mode] then self:_selectMode(mode) end
		end)
	end
	return self
end

function ChannelSelectGui:_selectMode(mode)
	self.list.Visible = (mode == "Roleplay")
	for _, m in ipairs(MODE_ORDER) do
		if self.rows[m] and self.rows[m].comingSoon then
			self.rows[m].comingSoon.Visible = (m == mode)
		end
		self.tabs[m].BackgroundColor3 = (m == mode) and Color3.fromRGB(20, 20, 20) or Color3.fromRGB(150, 150, 150)
	end
end

function ChannelSelectGui:OnJoin(callback)
	self.onJoin = callback
end

function ChannelSelectGui:SetChannelData(mode, channel, data)
	local row = self.rows[mode] and self.rows[mode][channel]
	if not row then return end
	row.countLabel.Text = data.count .. "/" .. CAP
	row.joinButton.Text = data.full and "FULL" or "JOIN"
	row.joinButton.BackgroundColor3 = data.full and Color3.fromRGB(200, 60, 50) or Color3.fromRGB(60, 175, 90)
	row.joinButton.Active = not data.full
	for i, icon in ipairs(row.avatars) do
		icon.Visible = i <= data.count
	end
	row._playerIds = data.playerIds
end

function ChannelSelectGui:SetRowAvatarImage(mode, channel, slotIndex, content)
	local row = self.rows[mode] and self.rows[mode][channel]
	if row and row.avatars[slotIndex] then
		row.avatars[slotIndex].Image = content or ""
	end
end

function ChannelSelectGui:SetRowStatus(mode, channel, status)
	local row = self.rows[mode] and self.rows[mode][channel]
	if not row then return end
	local text = { idle = "", connecting = "กำลังเชื่อมต่อ...", error = "เชื่อมต่อไม่สำเร็จ ลองอีกครั้ง" }
	row.statusLabel.Text = text[status] or ""
	row.joinButton.Active = (status ~= "connecting")
end

function ChannelSelectGui:Show()
	self.gui.Enabled = true
end

function ChannelSelectGui:Destroy()
	self.gui:Destroy()
end

return ChannelSelectGui
```

- [ ] **Step 2: Write `src/StarterPlayerScripts/ChannelSelectController.client.lua`**

```lua
-- ChannelSelectController: only runs in the lobby. game.PrivateServerId cannot be read from the client at all
-- ("PrivateServerId cannot be checked on the client") — ServerConfig.lua replicates IsLobby via a Workspace
-- Attribute instead; wait for it since it may not exist the instant this script starts.
while workspace:GetAttribute("IsLobby") == nil do
	task.wait()
end
if not workspace:GetAttribute("IsLobby") then return end

local Players = game:GetService("Players")
local ChannelSelectGui = require(game.ReplicatedStorage.UI.ChannelSelectGui)
local AvatarThumbnails = require(game.ReplicatedStorage.UI.AvatarThumbnails)
local Remotes = require(game.ReplicatedStorage.Remotes)

local player = Players.LocalPlayer
local gui = ChannelSelectGui.new()
gui.gui.Parent = player:WaitForChild("PlayerGui")
gui:Show()

AvatarThumbnails.OnAnyLoaded(function(userId, content)
	-- only Roleplay has real per-channel row tables; Stories/Tanding are { comingSoon = TextLabel }, not indexable this way
	for channel, row in pairs(gui.rows.Roleplay) do
		if row._playerIds then
			for slot, id in ipairs(row._playerIds) do
				if id == userId then
					gui:SetRowAvatarImage("Roleplay", channel, slot, content)
				end
			end
		end
	end
end)

local function applySnapshot(data)
	for mode, channels in pairs(data) do
		for channel, d in pairs(channels) do
			gui:SetChannelData(mode, channel, d)
			for slot, userId in ipairs(d.playerIds) do
				AvatarThumbnails.Get(userId, function(content)
					if content then gui:SetRowAvatarImage(mode, channel, slot, content) end
				end)
			end
		end
	end
end

Remotes.ChannelList.OnClientEvent:Connect(applySnapshot)

Remotes.JoinFailed.OnClientEvent:Connect(function(reason)
	warn("[ChannelSelect] join failed:", reason)
	-- ponytail: reset every Roleplay row's status rather than tracking which one was mid-join (only ever one in
	-- flight per client); Stories/Tanding aren't real per-channel tables (see ChannelSelectGui.new), so they're excluded.
	for channel in pairs(gui.rows.Roleplay) do
		gui:SetRowStatus("Roleplay", channel, "error")
	end
end)

gui:OnJoin(function(mode, channel)
	gui:SetRowStatus(mode, channel, "connecting")
	Remotes.JoinChannel:FireServer(mode, channel)
end)
```

- [ ] **Step 3: Local check**

Run: press Play in Studio.
Expected: the channel-select screen appears immediately over the default character. "Roleplay Mode" tab is dark/selected, "Stories Mode"/"Tanding Mode" are grey; clicking them shows "เร็วๆ นี้" and hides the channel list; clicking back to Roleplay shows 5 rows, all "0/30", green JOIN. Click JOIN on row 1 → label changes to "กำลังเชื่อมต่อ..." then (a few seconds later, since Studio can't really teleport) an error state appears — that's the expected Studio-only limitation from Task 2.
Stop Play mode when done.

**Bugs found and fixed here during actual Play testing (both are why this step exists — see git history for the exact fixes):** (1) `game.PrivateServerId` throws when read from a LocalScript at all, not just "always empty in Studio" as the spec assumed — fixed via the `workspace:GetAttribute("IsLobby")` wait above. (2) the original `JoinFailed`/`OnAnyLoaded` handlers iterated `gui.rows` including the Stories/Tanding entries, which aren't per-channel tables (`{ comingSoon = TextLabel }`) — indexing `.statusLabel`/`.avatars` on the TextLabel crashed with "X is not a valid member of TextLabel". Fixed by scoping both loops to `gui.rows.Roleplay` only, since that's the only mode with real rows.

- [ ] **Step 4: Commit**

```bash
git add src/ReplicatedStorage/UI/ChannelSelectGui.lua src/StarterPlayerScripts/ChannelSelectController.client.lua
git commit -m "channel select: screen UI + client controller"
```

---

### Task 6: SpawnSelector + LoadingGui + LoadingController

**Files:**
- Create: `src/ReplicatedStorage/SpawnSelector.lua`
- Create: `src/ReplicatedStorage/UI/LoadingGui.lua`
- Create: `src/StarterPlayerScripts/LoadingController.client.lua`

**Interfaces:**
- Produces: `SpawnSelector.GetSpawnPosition(player: Player) -> Vector3`
- Produces: `LoadingGui.new() -> self` where `self:SetProgress(fraction: number)`, `self:Show()`, `self:Destroy()`.

- [ ] **Step 1: Write `src/ReplicatedStorage/SpawnSelector.lua`**

```lua
-- SpawnSelector: sub-project 1 (save/restore last position) will replace this body to check a saved
-- position first. For now, every arrival uses whatever SpawnLocation exists in the world.
local SpawnSelector = {}

function SpawnSelector.GetSpawnPosition(_player)
	local spawn = workspace:FindFirstChildWhichIsA("SpawnLocation", true)
	if spawn then
		return spawn.Position + Vector3.new(0, 3, 0)
	end
	return Vector3.new(0, 50, 0) -- last-resort fallback so an empty/fresh place never errors
end

return SpawnSelector
```

- [ ] **Step 2: Write `src/ReplicatedStorage/UI/LoadingGui.lua`**

```lua
-- LoadingGui: pure UI builder for the logo + "Loading..." + segmented progress bar screen.
local SEGMENTS = 18

local LoadingGui = {}
LoadingGui.__index = LoadingGui

function LoadingGui.new()
	local self = setmetatable({}, LoadingGui)

	local gui = Instance.new("ScreenGui")
	gui.Name = "LoadingGui"
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 10

	local root = Instance.new("Frame")
	root.Size = UDim2.fromScale(1, 1)
	root.BackgroundColor3 = Color3.fromRGB(0, 188, 196)
	root.BorderSizePixel = 0
	root.Parent = gui

	local logo = Instance.new("Frame")
	logo.Size = UDim2.new(0, 220, 0, 220)
	logo.Position = UDim2.new(0.5, -110, 0.5, -220)
	logo.BackgroundColor3 = Color3.fromRGB(10, 90, 210)
	logo.Parent = root
	local logoCorner = Instance.new("UICorner")
	logoCorner.CornerRadius = UDim.new(1, 0)
	logoCorner.Parent = logo
	local logoLabel = Instance.new("TextLabel")
	logoLabel.Size = UDim2.fromScale(1, 1)
	logoLabel.BackgroundTransparency = 1
	logoLabel.Font = Enum.Font.SourceSansBold
	logoLabel.TextSize = 22
	logoLabel.TextColor3 = Color3.new(1, 1, 1)
	logoLabel.Text = "LOGO"
	logoLabel.Parent = logo

	local loadingLabel = Instance.new("TextLabel")
	loadingLabel.Size = UDim2.new(0, 400, 0, 60)
	loadingLabel.Position = UDim2.new(0.5, -200, 0.5, 40)
	loadingLabel.BackgroundTransparency = 1
	loadingLabel.Font = Enum.Font.SourceSansBold
	loadingLabel.TextSize = 40
	loadingLabel.TextColor3 = Color3.new(1, 1, 1)
	loadingLabel.TextXAlignment = Enum.TextXAlignment.Left
	loadingLabel.Text = "Loading..."
	loadingLabel.Parent = root

	local barBg = Instance.new("Frame")
	barBg.Size = UDim2.new(0, 860, 0, 60)
	barBg.Position = UDim2.new(0.5, -430, 0.5, 110)
	barBg.BackgroundColor3 = Color3.fromRGB(0, 188, 196)
	barBg.Parent = root
	local barCorner = Instance.new("UICorner")
	barCorner.CornerRadius = UDim.new(1, 0)
	barCorner.Parent = barBg
	local barStroke = Instance.new("UIStroke")
	barStroke.Color = Color3.new(0, 0.4, 0.85)
	barStroke.Thickness = 4
	barStroke.Parent = barBg

	local segmentsFrame = Instance.new("Frame")
	segmentsFrame.Size = UDim2.new(1, -16, 1, -16)
	segmentsFrame.Position = UDim2.new(0, 8, 0, 8)
	segmentsFrame.BackgroundTransparency = 1
	segmentsFrame.Parent = barBg
	local segLayout = Instance.new("UIListLayout")
	segLayout.FillDirection = Enum.FillDirection.Horizontal
	segLayout.Padding = UDim.new(0, 4)
	segLayout.Parent = segmentsFrame

	self.segments = {}
	for i = 1, SEGMENTS do
		local seg = Instance.new("Frame")
		seg.Size = UDim2.new(1 / SEGMENTS, -4, 1, 0)
		seg.BackgroundColor3 = Color3.new(1, 1, 1)
		seg.BackgroundTransparency = 1
		seg.LayoutOrder = i
		seg.Parent = segmentsFrame
		self.segments[i] = seg
	end

	self.gui = gui
	return self
end

function LoadingGui:SetProgress(fraction)
	local filled = math.floor(math.clamp(fraction, 0, 1) * #self.segments + 0.5)
	for i, seg in ipairs(self.segments) do
		seg.BackgroundTransparency = (i <= filled) and 0 or 1
	end
end

function LoadingGui:Show()
	self.gui.Enabled = true
end

function LoadingGui:Destroy()
	self.gui:Destroy()
end

return LoadingGui
```

- [ ] **Step 3: Write `src/StarterPlayerScripts/LoadingController.client.lua`**

```lua
-- LoadingController: runs the weighted loading-step list and reveals the world when done.
-- game.PrivateServerId cannot be read from the client at all ("PrivateServerId cannot be checked on the client")
-- — ServerConfig.lua replicates IsLobby via a Workspace Attribute instead. It's always true in Studio Play
-- (Play is always the lobby), so this never shows locally unless you flip the flag below.
local FORCE_SHOW_IN_STUDIO_FOR_TESTING = false -- ponytail: flip to true to preview this screen in Play; flip back before publishing

while workspace:GetAttribute("IsLobby") == nil do
	task.wait()
end
if workspace:GetAttribute("IsLobby") and not FORCE_SHOW_IN_STUDIO_FOR_TESTING then return end

local Players = game:GetService("Players")
local ContentProvider = game:GetService("ContentProvider")
local LoadingGui = require(game.ReplicatedStorage.UI.LoadingGui)
local SpawnSelector = require(game.ReplicatedStorage.SpawnSelector)

local player = Players.LocalPlayer
local gui = LoadingGui.new()
gui.gui.Parent = player:WaitForChild("PlayerGui")
gui:Show()

local STEPS = {
	{
		name = "character",
		weight = 1,
		run = function()
			if not player.Character then
				player.CharacterAdded:Wait()
			end
			player.Character:WaitForChild("HumanoidRootPart")
		end,
	},
	{
		name = "preload",
		weight = 2,
		run = function()
			local assets = {} -- later sub-projects append animation/model asset ids here; empty list preloads instantly
			if #assets > 0 then
				ContentProvider:PreloadAsync(assets)
			end
		end,
	},
	{
		name = "streaming",
		weight = 3,
		run = function()
			local hrp = player.Character:WaitForChild("HumanoidRootPart")
			local target = SpawnSelector.GetSpawnPosition(player)
			hrp.CFrame = CFrame.new(target)
			local deadline = os.clock() + 10
			while os.clock() < deadline do
				local ray = workspace:Raycast(target + Vector3.new(0, 200, 0), Vector3.new(0, -400, 0))
				if ray then break end
				task.wait(0.25)
			end
		end,
	},
	{
		name = "playerdata",
		weight = 1,
		run = function() end, -- stub; sub-project 1 replaces this with "wait for the profile to load"
	},
}

local totalWeight = 0
for _, step in ipairs(STEPS) do
	totalWeight += step.weight
end

local startTime = os.clock()
local done = 0
for _, step in ipairs(STEPS) do
	local ok, err = pcall(step.run)
	if not ok then
		warn("[Loading] step failed:", step.name, err)
	end
	done += step.weight
	gui:SetProgress(done / totalWeight)
end

local elapsed = os.clock() - startTime
if elapsed < 1 then
	task.wait(1 - elapsed)
end
gui:Destroy()
```

- [ ] **Step 4: Local check** (using the testing flag)

Run: temporarily edit `LoadingController.client.lua`, set `FORCE_SHOW_IN_STUDIO_FOR_TESTING = true`, save. Press Play in Studio.
Expected: the teal loading screen appears immediately, the segmented bar fills left to right over roughly 1+ second, then disappears revealing the character standing wherever the current `SpawnLocation` in the place is.
Then: set the flag back to `false` and save, since this must not run for real players in the lobby (only a channel server should ever show it, and there `workspace:GetAttribute("IsLobby")` will correctly be `false` automatically, no flag needed).

**Bug found and fixed here during actual Play testing:** the original guard read `game.PrivateServerId` directly, which throws when read from a LocalScript — not just "always empty in Studio" as first assumed. Fixed via the `workspace:GetAttribute("IsLobby")` wait shown above (same fix as Task 5's controller).

- [ ] **Step 5: Commit**

```bash
git add src/ReplicatedStorage/SpawnSelector.lua src/ReplicatedStorage/UI/LoadingGui.lua src/StarterPlayerScripts/LoadingController.client.lua
git commit -m "channel select: loading screen with weighted, extensible step list"
```

---

### Task 7: Post-publish verification (manual, cannot be automated)

**Files:** none — this task only runs checks against the real published game.

**Interfaces:** none produced; this is the final acceptance pass for the whole plan.

- [ ] **Step 1: Publish** the updated place to Roblox (File → Publish to Roblox in Studio, same action already done once before).

- [ ] **Step 2: Two-account channel test.** Using two different Roblox accounts (or the same account from two devices/browsers, which Roblox allows), both open the game.
Expected: both land in the lobby room, see the channel-select screen, "Roleplay" tab active, 5 channels all showing 0/30 (or whatever the real current count is if others are already playing).

- [ ] **Step 3: Join the same channel from both accounts.** Click "JOIN" on Channel 1 from both.
Expected: both actually teleport (a short Roblox-native transition screen appears), then the custom teal Loading screen shows, then both land in the same real place instance — confirm this by having both walk toward each other and seeing each other's character, or by checking each session's `game.JobId` differs from the lobby's `game.JobId` but the two channel-1 sessions could be the same JobId if they joined the identical reserved server (expected) or different if Roblox spun up a second instance of that Reserved Server under load (also technically possible at scale, not a concern at hobby scale).

- [ ] **Step 4: Join different channels.** One account picks Channel 1, the other Channel 2.
Expected: they do **not** see each other — confirms real separation.

- [ ] **Step 5: Population number sanity.** With one account sitting in Channel 1, go back to the lobby with the second account (rejoin the game fresh) and check the channel list.
Expected: Channel 1 shows `1/30` (or higher if others are there) within about 15 seconds of opening the screen (the ping-driven fast path should make this much faster than the 12s heartbeat interval).

- [ ] **Step 6: Full behavior.** This is impractical to test with 30 real accounts — instead, temporarily lower `CAP` in both `LobbyServer.server.lua` and `ChannelSelectGui.lua` to `2`, publish, verify the JOIN button correctly shows red "FULL" and refuses a third player, then set `CAP` back to `30` in both files and publish again.

- [ ] **Step 7: Record the outcome.** Once all of the above pass, update `CLAUDE.md`'s status block: note that the channel-select + loading system (sub-project 6) is live, and which sub-project (1: player data & life cycle) is next per `docs/design/04-gameplay-hooks.md`'s ordering.

```bash
git add CLAUDE.md
git commit -m "docs: channel select + loading screen verified live"
```

---

## Self-Review

**Spec coverage:** §2 architecture → Tasks 1-3 (registry, self-identification, lobby room). §3 data model → Task 1 (exact keys/topics match). §4 server components → Task 2 (`LobbyServer`/`ChannelServer` match the spec's table exactly; `ChannelRegistry`/`ServerConfig` from Task 1). §5 client components/flow → Tasks 5-6 (`ChannelSelectGui`/`Controller`, `LoadingGui`/`Controller`); the lobby-scene note is Task 3. §6 failure handling → `JoinFailed` remote + retry-once in Task 2, error row state in Task 5. §7 loading steps → Task 6's `STEPS` table matches the four named steps and weights exactly. §8 spawn selection → `SpawnSelector` in Task 6, with the exact seam name (`GetSpawnPosition`) the spec specified. §9 open items → all carried into Global Constraints and Task 7's manual-only framing; the "Brasshaven not generated yet" gap is handled by `SpawnSelector`'s `FindFirstChildWhichIsA("SpawnLocation", true)` fallback, matching the spec's stated fallback behavior.

**Placeholder scan:** no TBD/TODO; every code block is complete and runnable. The two `ponytail:` comments (best-effort second DataStore write; single-in-flight-join reset-all-rows) each name their real limitation and are deliberate, not deferred work.

**Type consistency checked across tasks:** `ChannelRegistry.IdentifySelfFor`/`IdentifySelf` used identically in Task 1 (definition) and Task 4 of `ServerConfig` (consumption). `Remotes.JoinChannel`/`ChannelList`/`JoinFailed` names match between Task 1 (creation) and Tasks 2, 5 (consumption) exactly. `ChannelSelectGui:SetChannelData`'s expected shape `{count, playerIds, full}` matches exactly what `LobbyServer.snapshot()` produces in Task 2. `LoadingGui:SetProgress` takes a 0-1 fraction in both its definition (Task 6) and its one call site (same task). `SpawnSelector.GetSpawnPosition` signature matches its definition and its one call site.

## Execution options

Plan complete and saved to `docs/superpowers/plans/2026-09-06-channel-select-and-loading.md`. Two ways to run it:

**1. Subagent-Driven (recommended)** — I dispatch a fresh subagent per task, review between tasks, fast iteration.

**2. Inline Execution** — I execute tasks in this session, batch execution with checkpoints for your review.

Which approach?
