# Player position: first spawn, respawn-on-death, save last position

**Status:** approved 2026-09-07, implemented same day.

## Scope

Sub-project 1 ("ข้อมูลผู้เล่น+วงจรชีวิต"), position-only slice. Not in scope: HP/stamina/mana persistence,
inventory, per-mode/channel-separated saves (Tanding's isolated data model is a later concern).

## Requirements (from the user, verbatim intent)

1. First-ever join lands the player at a real map point, not the lobby room.
2. Death/respawn returns the player to that same real map point (not wherever Roblox's own respawn picks).
3. Leaving the game (or losing connection) saves the player's last position; the next join restores it.

## Design

- **First spawn point:** `WOLD.TempSpawn.SpawnLocation` (`mapgen/temp_spawn.lua`, Brasshaven's future site, real
  terrain height). Already existed as the map's only real spawn point outside the lobby.
- **Save scope:** one position per player (UserId-keyed), no per-mode/channel split — confirmed with the user.
- **Save trigger:** `Players.PlayerRemoving` only. Covers both real disconnect and the "return to Lobby" menu
  teleport (both fire `PlayerRemoving`). No periodic autosave — confirmed with the user, added later if needed.
- **Store:** `WOLD_PlayerPosition_v1`, key `pos_<UserId>`, value `{x, y, z}` (position only, no orientation).

## Architecture correction found during design

The original `SpawnSelector.GetSpawnPosition` seam (from the channel-select/loading sub-project) was called
directly from `LoadingController.client.lua`, a `LocalScript`. `DataStoreService` is server-only — a client
can't query the position store directly. Fixed by splitting the concern:

- `SpawnSelector.lua` (ReplicatedStorage): pure logic only. `ResolvePosition(savedPosition | nil) -> Vector3`.
  Given a saved position, returns it; otherwise falls back to `WOLD.TempSpawn`, then a hardcoded safety net.
  No DataStore access — stays require-able (and testable) from either side, but only ever actually called
  server-side now.
- `PlayerPosition.server.lua` (new, ServerScriptService): the only file touching the position DataStore.
  - Answers `Remotes.GetSpawnPosition` (new `RemoteFunction`) — client invokes it, server loads the saved
    position and calls `SpawnSelector.ResolvePosition`.
  - Hooks `CharacterAdded` for every respawn after the first, repositioning the character server-side (Roblox's
    own respawn just grabs whatever `SpawnLocation` exists in workspace, same root cause as the earlier
    lobby-room bug — bypassing it entirely needs an explicit reposition).
  - Hooks `PlayerRemoving` to save the current `HumanoidRootPart.Position`.
  - Everything in this file except the RemoteFunction answer is gated to `not ServerConfig.IsLobby`: the lobby
    has its own dedicated `LobbySpawn` room, and saving a player's position while standing in it (y=1000+)
    would clobber a real saved map position with lobby coordinates.
- `Remotes.lua`: extended to also bootstrap `RemoteFunction`s (previously `RemoteEvent`-only), adding
  `GetSpawnPosition`.
- `LoadingController.client.lua`: `SpawnSelector.GetSpawnPosition(player)` → `Remotes.GetSpawnPosition:InvokeServer()`.
  First-spawn choreography (raycast-wait for terrain, loading-screen timing) is unchanged — `PlayerPosition`'s
  respawn hook explicitly skips a player's first `CharacterAdded` each session so it doesn't fight this.

## Verified

- `SpawnSelector.ResolvePosition(nil)` → `TempSpawn`'s real coordinates.
- `SpawnSelector.ResolvePosition(Vector3)` → returns it unchanged.
- `WOLD_PlayerPosition_v1` DataStore accepts the `{x,y,z}` schema and round-trips it correctly (tested directly
  in Studio Play, key removed after).
- Full end-to-end (real respawn-after-death repositioning, real save-on-leave) needs a real channel server —
  Studio blocks `TeleportService`/`ReserveServer` unconditionally (documented platform restriction, same as
  every previous channel-select test) — deferred to a real publish test alongside the existing Task 7 checklist.

## Bug found after first publish test (2026-09-07)

User reported: walked away from spawn, returned to lobby via the HUD menu, rejoined a channel — landed back at
the default spawn point instead of their last real position.

**Root cause:** `PlayerRemoving` was the only save trigger, and it does not reliably fire *before*
`TeleportService:Teleport()` (called client-side from the lobby-return button) actually removes the character —
documented, reported Roblox behavior, not a guess (see commit `a974c4c` for devforum links). The
`HumanoidRootPart` read inside the `PlayerRemoving` handler could already be gone, so the save silently no-opped.

**Fix:** the client no longer calls `TeleportService:Teleport()` directly. It fires a new
`RequestReturnToLobby` `RemoteEvent`; the server saves the position (character still fully exists at that
moment) and only then issues the teleport itself. `PlayerRemoving` remains as a backup for real
disconnects/crashes, which have no equivalent "about to leave" moment to hook into. General lesson: any
client-triggered leave-this-server action needs a server-side "save first, then act" step — `PlayerRemoving`
alone cannot be trusted as the sole save point for a teleport-driven exit.
