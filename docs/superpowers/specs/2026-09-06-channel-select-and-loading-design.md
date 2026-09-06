# Channel Select + Loading Screen — Design Spec

Sub-project 6 of the gameplay-systems roadmap (see `docs/design/04-gameplay-hooks.md` for the full ordered list: 1 Player Data & Life Cycle, 2 Movement & Animation, 3 Combat, 4 Downed & Revive, 5 Resource Gathering, 6 **this spec**). The user chose to build this one first even though it has no gameplay dependency, since it is fully independent of the other five.

Approved 2026-09-06 through three design sections in chat. Reference mockups (described, not stored as files): (1) a channel-list screen with mode tabs "Stories Mode / Roleplay Mode / Tanding Mode", rows "เชิฟ 1..4" each showing a grid of player avatar circles, an "X/30" count, and a green JOIN or red FULL button; (2) a teal loading screen with a circular logo placeholder, "Loading..." text, and a segmented pill progress bar.

## 1. Purpose and scope

Let a player, immediately after Roblox places them in a server, pick which live "channel" (population shard) of the Roleplay world to actually play in, without the 16,000-stud map ever streaming in until they commit — then show a loading screen while the real world catches up.

**In scope:** the public lobby experience, the channel registry/routing backend, the loading screen and its extensible step list.
**Out of scope (future sub-projects):** actual player-data persistence (sub-project 1 will plug into the loading screen's step list and into per-mode save-key selection), the in-game HUD from the third reference mockup (health/stamina/hunger/armor bars, equipment slots — that is sub-project 1/3 territory), Stories Mode and Tanding Mode gameplay differences (no farmable resources; both are UI-visible but disabled tabs for now).

## 2. Architecture

**Single Roblox place.** Whatever server Roblox's normal matchmaking puts a fresh player into is **the lobby** — `game.PrivateServerId == ""` identifies it at startup. Every "channel" the player can choose is a **Reserved Server** (`TeleportService:ReserveServer`), created once ever per (mode, channel) slot and reused forever after. A channel server is identified by `game.PrivateServerId ~= ""`.

**Self-identification without relying on join order.** A channel server looks itself up in the registry DataStore by its own `game.PrivateServerId` the moment it starts — it does not wait on the first player's `TeleportData`, which would be fragile if that player disconnects before the lookup happens.

**Live population without hammering DataStore.** Each channel server publishes its own headcount + player-id list on a `MessagingService` topic every 12 seconds, and immediately whenever the lobby broadcasts a "please report" ping (sent when a player first opens the channel-select screen, so the numbers are fresh rather than waiting for the next 12-second tick). The lobby keeps an in-memory table built from these messages; DataStore is only touched to look up or create a channel's access code, never for headcounts.

**Modes baked into the schema, only one wired up.** The registry key includes the mode name so Stories/Tanding slots can be added later without a data migration. Player-data save keys (sub-project 1's concern) will be `Player_<UserId>` for Roleplay and Stories (shared progress) and `Player_<UserId>_Tanding` for Tanding (isolated progress) — `ServerConfig.Mode` is what a future data-loading script reads to pick the key; this spec only guarantees that value is correct and available by the time any other system needs it.

## 3. Data model

**DataStore `WOLD_ChannelRegistry_v1`**, two key shapes in the same store:

| Key | Value (JSON) | Written by | Read by |
|---|---|---|---|
| `slot_<mode>_<channel>` | `{ accessCode, privateServerId, createdAt }` | Lobby, once, the first time that channel is ever picked | Lobby, every time a player picks that channel |
| `code_<privateServerId>` | `{ mode, channel }` | Lobby, at the same moment as the row above (written together, best-effort — see failure handling) | The channel server itself, once, at startup |

`accessCode` is what `TeleportService:TeleportToPrivateServer` needs; `privateServerId` is what a server sees as `game.PrivateServerId` once inside — these are different values returned as two separate results from `TeleportService:ReserveServer`, both must be stored.

**MessagingService topic `ChannelHeartbeat_Roleplay`** (one topic per mode, only this one exists for now): channel servers publish `{ channel: number, count: number, playerIds: {number}, ts: number }` every 12s and immediately on request.

**MessagingService topic `ChannelPing_Roleplay`**: the lobby publishes an empty ping when a player opens the channel-select screen and the lobby's cached data for that mode is older than 5 seconds; every channel server for that mode responds on the heartbeat topic within about a second.

**Fixed channel count:** 5 slots per mode (`Roleplay` = slots 1-5 active now; `Stories`/`Tanding` slots reserved in the schema, not created). **Population cap:** 30 players per channel (from the reference mockup).

## 4. Server-side components

| File | Responsibility |
|---|---|
| `ServerScriptService/ServerConfig.lua` | ModuleScript. Exposes `ServerConfig.IsLobby: boolean`, `ServerConfig.Mode: string?`, `ServerConfig.Channel: number?`. Populated once, synchronously, before any other script needs it (see startup order below). |
| `ServerScriptService/Lobby/ChannelRegistry.lua` | ModuleScript wrapping the DataStore + MessagingService calls: `GetOrCreateChannel(mode, channel) -> accessCode`, `IdentifySelf() -> mode, channel` (reverse lookup by `game.PrivateServerId`), `PublishHeartbeat(mode, channel, count, playerIds)`, `SubscribeToHeartbeats(mode, callback)`, `RequestFreshData(mode)`. |
| `ServerScriptService/Lobby/LobbyServer.server.lua` | Runs only when `ServerConfig.IsLobby`. Subscribes to heartbeats, answers the client's `JoinChannel` remote by resolving/creating the access code and calling `TeleportToPrivateServer`, handles teleport failures (see §6). |
| `ServerScriptService/Lobby/ChannelServer.server.lua` | Runs only when not the lobby. Calls `IdentifySelf()` to fill `ServerConfig`, starts the 12s heartbeat loop, answers `ChannelPing`. |

**Startup order:** a single bootstrap at the top of `ServerConfig.lua` runs `ChannelRegistry.IdentifySelf()` synchronously (a single DataStore `GetAsync` call, a few hundred ms) before returning the module, so any script that `require`s `ServerConfig` gets a fully-populated table — no race between scripts that need to know the mode.

## 5. Client-side components and flow

| File | Responsibility |
|---|---|
| `ReplicatedStorage/Remotes/` | `JoinChannel` (RemoteEvent, client→server, `{mode, channel}`), `ChannelList` (RemoteEvent, server→client, pushes the current table whenever it changes or a ping response arrives). |
| `StarterGui/ChannelSelectGui/` | The screen from mockup 1: mode tabs, channel rows, avatar circles, JOIN/FULL buttons, per-row "connecting…" and error states. |
| `StarterGui/LoadingGui/` | The screen from mockup 2: logo, "Loading...", segmented progress bar. |
| `StarterPlayerScripts/ChannelSelectController.client.lua` | Shows `ChannelSelectGui` on spawn if `ServerConfig` (replicated via an Attribute on `game.Workspace` or a small RemoteFunction, since ModuleScripts don't cross the client/server boundary) says this is the lobby. Fetches thumbnails (queued, cached in a table keyed by UserId, one `Players:GetUserThumbnailAsync` in flight at a time to stay under Roblox's request rate). Fires `JoinChannel` on click. |
| `StarterPlayerScripts/LoadingController.client.lua` | Runs on every spawn that is **not** the lobby. Drives the weighted step list, animates the progress bar, reveals the world (removes the `LoadingGui` overlay) when all steps finish. |

**Lobby scene:** a small hand-placed 3D room (a handful of Parts, themed to match the rest of the game — not generated by `mapgen/`), with its own `SpawnLocation`, built directly under `src/ServerScriptService`'s sibling `Workspace`-facing counterpart... concretely: since Rojo only syncs scripts by default in this project, the lobby room's Parts will be built by a small one-off script (`Lobby/BuildLobbyRoom.server.lua`, run once, idempotent like the map generator's phases — checks for an existing `Workspace.LobbyRoom` and skips if present) rather than hand-placed in Studio, so it survives a fresh place file and stays in git.

## 6. Failure handling

- `ReserveServer` or the DataStore write fails while creating a new channel slot: the row shows an error state ("สร้างช่องไม่สำเร็จ") with a retry button; nothing is teleported.
- `TeleportToPrivateServer` fails (expired code, Roblox-side error): retry once automatically; on a second failure, show the same error state.
- A channel server's `IdentifySelf()` finds no registry entry for its `PrivateServerId` (should be unreachable in normal operation, but DataStore writes are best-effort across two keys): treat it as a fatal misconfiguration, `warn` loudly, and fall back to `Mode = "Roleplay"`, `Channel = 0` so the server is still playable rather than stuck.
- Heartbeat publish fails (MessagingService throttled): skip that tick silently, try again in 12s; the lobby simply shows slightly stale numbers, never blocks on it.

## 7. Loading screen step list

An ordered array so sub-project 1 (and later systems) can append a step without touching the controller:

```
{ name, weight, run: () -> Promise/yields-until-done }
1. "character"  weight 1  -- wait for LocalPlayer.Character and HumanoidRootPart
2. "preload"    weight 2  -- ContentProvider:PreloadAsync on a static asset-id list (empty for now, real list arrives with sub-project 2's animations)
3. "streaming"  weight 3  -- move the character to the correct spawn point (see §8) and poll until the ground beneath it is streamed in (bounded retry loop, ~10s timeout, proceeds anyway after timeout rather than hanging forever)
4. "playerdata" weight 1  -- stub that returns immediately; sub-project 1 replaces this with "wait for the profile to finish loading"
```

Progress bar fill = cumulative completed weight / total weight. A minimum 1-second display time is enforced even if everything finishes instantly, so the screen never just flashes.

## 8. Spawn point selection (interface only, not full logic)

The loading screen's "streaming" step needs a target position. For now, since sub-project 1 (save/restore last position) does not exist yet, every arrival uses the `SpawnLocation` tagged `SpawnKind="First"` at Brasshaven's harbor (already placed by `mapgen/30_capital.lua`... not yet generated — see open item below). The step function is written against a small seam, `SpawnSelector.GetSpawnPosition(player) -> Vector3`, so sub-project 1 can replace its body (check for a saved last position first) without touching the loading controller.

## 9. Open items / explicitly deferred

- **Brasshaven (map phase 5) has not been generated yet** — the plan currently stops after phase 3 (caves). The "First" `SpawnLocation` this spec depends on for spawn selection does not exist in the world yet. Until phase 5 runs, `SpawnSelector.GetSpawnPosition` falls back to `workspace:FindFirstChild("SpawnLocation")` on the temporary spawn point left by whichever mapgen phase last ran (matches current dev practice), so this sub-project can be built and tested in isolation before the map is finished.
- Real avatar thumbnails for the row's circle grid: capped display (mockup shows up to 30 circles across 2 rows; if a channel is near-empty most circles show an empty/placeholder ring).
- Stories Mode / Tanding Mode tabs are visible, non-interactive, labeled "เร็วๆ นี้" — no registry slots are created for them.
- Testing Reserved Servers and MessagingService end-to-end requires a real publish to Roblox; Studio Play/Play-Here cannot fully simulate cross-server teleport. The user will do this verification pass after implementation (confirmed in chat).
