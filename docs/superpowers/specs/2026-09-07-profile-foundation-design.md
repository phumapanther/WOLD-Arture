# Player profile foundation (ProfileStore), replacing the hand-rolled position save

**Status:** approved 2026-09-07, phase 1 of 3 (movement states and vitals/death are phases 2 and 3, separate specs).

## Why

`PlayerPosition.server.lua` (see `2026-09-07-player-position-design.md`) hand-rolled save-on-leave using
`PlayerRemoving` + `BindToClose`, and hit two real bugs during testing (`PlayerRemoving` not reliably firing
before a client-initiated teleport; the last-player-leaving case racing server shutdown) plus one unfixable
race (fast quit-and-rejoin reading the DataStore before the old server's save even starts). A periodic-autosave
mitigation was tried and reverted (didn't help in practice, added write volume for nothing).

The user asked to switch to `ProfileStore` (MadStudio's actively-maintained successor to the widely-used
`ProfileService`) now, ahead of building movement states and the vitals/death system, because those systems
need real shared, concurrently-touched player data (stamina drain affecting HP affecting hunger) — exactly the
case `ProfileStore`'s session-locking and batch-save design solves, and exactly the case that made adopting it
earlier (when there was only one field, position) premature per YAGNI.

## Scope (phase 1 only)

- Vendor `ProfileStore.luau` into the project as a real dependency.
- Define the profile schema/template with room for what's coming, but only actually *use* the `Position` field
  this phase — `Vitals` exists in the template so phases 2/3 don't need another `Reconcile`-requiring schema
  bump, but nothing reads/writes it yet.
- Replace `PlayerPosition.server.lua`'s hand-rolled DataStore access with a session-locked profile per player.
- Preserve every existing behavior from the position spec: first spawn at `WOLD.TempSpawn`, respawn-after-death
  to the same resolved position, lobby-server code stays fully untouched (no profile session started there).

Not in scope: anything `Vitals` actually does (phases 2/3), inventory, per-mode/channel profile separation.

## Design

### Dependency

`temp_refs/profilestore-madstudio/ProfileStore.luau` → `src/ServerScriptService/ProfileStore.lua` (server-only;
`ProfileStore`'s own docs confirm it's meant to be required from `ServerScriptService` and must never yield on
require — matches its own test file's assertion). Not exposed to `ReplicatedStorage`; nothing client-side needs
it directly.

### Schema

```lua
local ProfileTemplate = {
    Position = nil,  -- {x, y, z} | nil (nil = never saved yet, same meaning as today's DataStore miss)
    Vitals = { HP = 100, Stamina = 100, Hunger = 100 },  -- unused this phase; exists so phase 2/3 don't Reconcile again
}
```

`Profile:Reconcile()` fills in missing keys against this template on load — the mechanism that makes adding
`Vitals`-consuming code later safe without a migration step (existing profiles from before that field existed
just get it filled in).

### `PlayerProfile.server.lua` (replaces `PlayerPosition.server.lua`)

- One `ProfileStore.New("WOLD_PlayerProfile_v1", ProfileTemplate)`.
- `Players.PlayerAdded`: `ProfileStore:StartSessionAsync("Player_" .. userId)` — session-locked, so a second
  server trying to load the same profile waits/steals per `ProfileStore`'s own conflict resolution, not
  something this project needs to hand-roll.
  - If the session fails to start (returns `nil`) — the documented `ProfileStore` failure case — kick the
    player with a clear message rather than let them play with an unsaved session. This mirrors the reference
    pattern the user linked, and is a case genuinely worth failing loudly on (a session that can't lock has no
    safe way to persist anything).
  - `profile:AddUserId(player.UserId)`, `profile:Reconcile()`.
  - Keep the profile in a `Profiles[player] = profile` table for the rest of this file to use.
  - `profile:ListenToRelease(...)` → if the session gets released from under us (another server stole it), kick
    the player — same reasoning as above.
- `Remotes.GetSpawnPosition.OnServerInvoke`: read `Profiles[player].Data.Position`, call
  `SpawnSelector.ResolvePosition` exactly as today (that module is untouched — still pure logic, still doesn't
  know about `ProfileStore` or any store).
- Respawn-after-death repositioning: unchanged logic (skip first `CharacterAdded`, reposition every one after),
  just reads `Profiles[player].Data.Position` instead of a direct `GetAsync`.
- Position writes: assign into `profile.Data.Position = {x,y,z}` at three points — (1) in-game "return to
  lobby" button via `RequestReturnToLobby`, (2) `PlayerRemoving`, (3) a periodic in-memory update every ~5-10s
  while playing. `ProfileStore` guarantees whatever is in `Data` is saved as long as `profile:IsActive()`, and
  its own `AUTO_SAVE_PERIOD` (300s, only actually hits the real DataStore, not every in-memory write) already
  batches these — so (3) costs nothing extra in DataStore requests, unlike the reverted periodic-autosave
  attempt on the old hand-rolled store, which called `SetAsync` directly every tick.
- `Players.PlayerRemoving`: `profile:EndSession()` — `ProfileStore` handles the actual final save internally
  (its own `OnLastSave`/shutdown handling covers the exact cases `BindToClose` was hand-rolled for).
- Everything above is still gated to `not ServerConfig.IsLobby`, same reasoning as before: the lobby's own
  `LobbySpawn` room must never read or write map position data.

### What this fixes structurally (not just patches)

- The "last player leaving races server shutdown" bug: `ProfileStore` already handles `game:BindToClose()`
  internally (it's a maintained library solving exactly this).
- The "fast quit-and-rejoin reads stale data" race: `ProfileStore`'s session lock means a *second* server
  trying to start a session for the same profile while the first server's session is still active will wait
  or go through defined conflict resolution — the new server can no longer silently read a stale/missing value
  out from under a save that hasn't happened yet, the way a bare `GetAsync` could.

### What doesn't change

- `SpawnSelector.lua`: untouched. Still pure `ResolvePosition(savedPosition | nil) -> Vector3`.
- `Remotes.lua`: untouched (already has `GetSpawnPosition` and `RequestReturnToLobby`).
- `LoadingController.client.lua`, `HudController.client.lua`: untouched — same remotes, same call shapes.
- `mapgen/temp_spawn.lua`, `BuildLobbyRoom.server.lua`: untouched.

## Migration note

Existing saved positions live in the old `WOLD_PlayerPosition_v1` DataStore under `pos_<UserId>` keys. The new
profile store (`WOLD_PlayerProfile_v1`, key `Player_<UserId>`) starts empty for everyone — a one-time loss of
whatever was saved under the old scheme. Acceptable: this is pre-launch, hobby-scale testing data, not real
players' progress. No migration script planned.

## Testing

Same platform limits as every previous sub-project: `ProfileStore:StartSessionAsync` needs a real published
server to test session-lock behavior meaningfully (two real servers racing for one profile) — Studio can
exercise single-server load/save/reconcile logic, but not real cross-server conflict resolution. Verify what
Studio allows (profile loads, `Reconcile` fills the template, position save/load round-trips), defer the rest
to a real publish test like every remote/teleport-dependent piece before it.
