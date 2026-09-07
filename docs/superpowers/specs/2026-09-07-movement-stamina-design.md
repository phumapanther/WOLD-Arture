# Movement states: walk / normal / run, tied to stamina

**Status:** approved and implemented 2026-09-07. Sub-project 2 (เคลื่อนไหว/อนิเมชัน), stamina-driven speed
slice only — animations themselves are a later pass. Every transition below was verified in Studio Play by
firing the intent remotes directly (real keypresses can't be simulated from the MCP context) and reading the
resulting `WalkSpeed`/stamina.

**Deviation found in testing:** `StaminaUpdate` must only be broadcast in channel servers and is capped at
10 sends/s per player. Firing it in the lobby — where `HudController` correctly never connects a listener —
filled Roblox's unhandled-remote queue and logged escalating "invocation queue exhausted" warnings. The
Architecture section's "Runs in every server" still holds for the speed logic; only the HUD broadcast is gated.

## Speeds

- Walk = 4
- Normal = 8 (today's flat `PlayerSpeed.server.lua` value — this system replaces that file)
- Run = 16

## Stamina

- 0-100. Drains at 20/s while running (empties in ~5s from full). Regenerates at 100/3 ≈ 33.3/s (fills in ~3s
  from empty). Regeneration is not gated on being idle — running is allowed again the instant stamina is above 0,
  even mid-regen.

## State machine (server-authoritative)

States: `Normal`, `Walk`, `Run`, `ForcedWalk`.

Input (client → server, intent only, not the resulting speed):
- `sprintIntent: bool` — true while the player is holding Shift AND has nonzero `MoveDirection` (WASD held).
  False the instant either Shift releases or movement stops.
- `walkToggle` — fired once when the player taps Shift (press+release within some short window) while
  `Humanoid.MoveDirection == Vector3.zero` (standing still). Not a held state — a one-shot request.

Transitions:
1. **Start:** `Normal`.
2. **`Normal` → `Run`:** `sprintIntent` becomes true (and stamina > 0). `WalkSpeed = 16`, stamina drains at 20/s.
3. **`Run` → `Normal`:** `sprintIntent` becomes false (Shift or WASD released) — immediate, no lingering run speed.
4. **`Run` → `ForcedWalk`:** stamina reaches 0 while running. `WalkSpeed = 4` for a fixed 2s, ignoring
   `sprintIntent` entirely during that window (confirmed: if the player keeps holding Shift+WASD through the
   whole 2s, they stay walking until the 2s elapses, THEN automatically go back to running — no need to
   release and re-press). Stamina begins regenerating immediately (doesn't wait for the 2s to end).
5. **`ForcedWalk` → `Run` or `Normal`:** after 2s, re-evaluate `sprintIntent` as of that moment — if still true,
   go straight to `Run` (stamina is already regenerating, doesn't need to be full); if false, go to `Normal`.
6. **`Normal`/idle → `Walk`:** `walkToggle` received while `MoveDirection == Vector3.zero`. `WalkSpeed = 4`,
   persists (not tied to holding anything).
7. **`Walk` → `Run`:** `sprintIntent` becomes true (same as transition 2, from a different starting state).
8. **`Run` → `Normal`** (not back to `Walk`) when `sprintIntent` releases, regardless of which state was active
   before the `Run` — confirmed: tapping Shift to walk, then holding Shift+WASD to run and releasing, returns
   to `Normal`, not back to `Walk`. `Walk` is effectively cancelled the instant a `Run` starts from it.
9. **`ForcedWalk` never triggers from `Walk`** — stamina only drains while actually in `Run`, and `Walk`'s
   speed never comes from stamina, so there's no case where walking-from-toggle depletes stamina.

Not modeled yet (explicitly out of scope this pass): swimming stamina drain, HP loss from any source, hunger.
Those are their own upcoming systems (drowning ties into this stamina value later, but isn't wired up now).

## Architecture

### Client: `MovementController.client.lua` (new, StarterPlayerScripts)

Sends intent only — never sets `WalkSpeed` itself (that would let a modified client simply set it to anything).

- `UserInputService.InputBegan`/`InputEnded` for `Enum.KeyCode.LeftShift`/`RightShift` → track `shiftHeld`.
- `Humanoid.Running:Connect(function(speed) movingKey = speed > 0 end)` (or poll `MoveDirection` — `Running`
  is the simpler, already-debounced signal Roblox provides) to track whether the character is actually moving.
- `sprintIntent = shiftHeld and moving`. Fire `Remotes.SetSprintIntent:FireServer(sprintIntent)` only on change
  (not every frame) to keep remote traffic low.
- Walk-toggle: on Shift press, if not currently moving, start a short timer (e.g. 0.3s); if Shift releases
  before the timer and the player still hasn't moved, fire `Remotes.ToggleWalk:FireServer()`. This distinguishes
  a tap (walk-toggle) from the start of a hold-to-sprint gesture without needing the player to already be
  sprinting to tell them apart.

### Server: `PlayerMovement.server.lua` (new, replaces `PlayerSpeed.server.lua`)

- Per-player state table: `{ state, stamina, forcedWalkUntil }`.
- `Remotes.SetSprintIntent.OnServerEvent` updates `sprintIntent` per player; `Remotes.ToggleWalk.OnServerEvent`
  applies transition 6 (only honored if `Humanoid.MoveDirection == Vector3.zero` — server re-checks, doesn't
  trust the client's own idle detection).
- One `RunService.Heartbeat` loop (or `task.spawn` + `task.wait` tick, whichever matches the existing project's
  style better — `HudController`/`PlayerSpeed` don't have a precedent for this, so a plain heartbeat-driven
  loop is simplest) per player (or one global loop iterating all players — simpler, one connection instead of
  N) that:
  - Advances `stamina` (drain in `Run`, regen otherwise) each tick, clamped [0, 100].
  - Applies transitions 4/5 (the 2s `ForcedWalk` timer) via `os.clock()` comparison, not a separate
    `task.wait(2)` per player (keeps the whole system driven by one loop, avoids N stray timer threads).
  - Sets `Humanoid.WalkSpeed` whenever `state` changes (not every tick — cheap check, avoid redundant writes).
  - Sends `Remotes.StaminaUpdate:FireClient(player, stamina/100)` only when the fraction changes enough to
    matter (e.g. rounds to a different percent) — throttles remote traffic, matches the HUD bar's own
    granularity (it's a thin bar; sub-percent updates aren't visible anyway).
- Runs in every server (not gated to channel-only) — movement should feel consistent even if a player is
  technically standing in the lobby, and this file has no DataStore/position concerns that need the
  `ServerConfig.IsLobby` guard the way `PlayerProfile.server.lua` does.

### `Remotes.lua`

Add `RemoteEvent`s: `SetSprintIntent`, `ToggleWalk`, `StaminaUpdate`.

### HUD wiring

`HudController.client.lua`: replace the current `gui:SetStaminaFraction(1)` (static full) with
`Remotes.StaminaUpdate.OnClientEvent:Connect(function(fraction) gui:SetStaminaFraction(fraction) end)`.

## Testing

Fully testable in Studio Play — no TeleportService/channel-server dependency, unlike every previous sub-project
this session. Verify: WalkSpeed changes on state transitions, stamina drains/regens at the specified rates,
the 2s forced-walk lock holds even while still holding Shift+WASD, walk-toggle only fires while idle, and
running-from-walk returns to Normal (not Walk) on release.

## Analog sticks — gamepad and mobile touch ("option B", added 2026-09-07)

Chosen by the user over a dedicated on-screen sprint button: **push the stick to the edge = sprint, light push =
walk, no extra buttons, no walk-toggle on sticks.** After a stamina-out forced walk, a stick still at the edge
auto-resumes Run exactly like a held Shift on keyboard (confirmed: same rule on every platform, accepting that a
player who pins the stick will cycle Run ~3.3s / ForcedWalk 2s).

- "Walk" needs no code: the engine scales speed by stick deflection natively (verified in Play — `Humanoid:Move`
  at 0.5 magnitude moves at exactly half `WalkSpeed`), and `DynamicThumbstick` emits
  `magnitude = deflection / radiusOfMaxSpeed` clamped to `[0, 1]`, so a full push is exactly `1.0`.
- Sprint decision (client, `MovementController`): deflection `>= 0.9` sustained `0.25s` → sprint intent on;
  `< 0.7` → off (hysteresis against edge jitter; the sustain window ignores a quick flick to the edge that's just
  starting a move). All three are constants at the top of the file — tune after real-device testing.
- Server unchanged: it still only receives `SetSprintIntent`. The client ORs the keyboard rule
  (`Shift held AND moving`) with the analog rule.
- **Gamepad deflection is read directly** from `UserInputService.InputChanged` (`KeyCode.Thumbstick1`,
  `Position.X/Y`) — exact, official, no PlayerModule involvement.
- **Touch deflection has no engine API.** Findings from the investigation: `Humanoid.MoveDirection` is always a
  unit vector; the modern `PlayerModule` lives at `StarterPlayer.PlayerModule`, is driven from the CoreScript
  VM, and no longer exposes `GetControls()`/`GetMoveVector()` (its `ControlModule` has an `inputMoveVector`
  field written only by that VM's update loop). `require`-ing that `ControlModule` from a client script builds a
  separate, never-updated copy, and a probe that did so recorded zero movement during real keypresses while an
  identical probe without it recorded full-speed movement — treated as "never do this." Chosen fallback:
  **infer deflection as `horizontal speed / WalkSpeed`** (ponytail: ~10 lines, exact on flat ground, reads low
  uphill/in water and can read high while airborne). Only evaluated when the last input type is Touch, so it
  can never trigger on keyboard (WASD would otherwise read as a constant full push). Upgrade paths if the slope
  error is noticeable in practice: read the thumbstick's own GUI (`ThumbstickEnd` offset from `ThumbstickStart`
  under `PlayerGui.TouchGui`), or fork the whole `PlayerModule` into `StarterPlayerScripts` so its
  `ControlModule` runs in the client VM and `inputMoveVector` becomes readable.
- Not tested by Claude: the user is testing gamepad and mobile themselves (real thumbstick input can't be
  produced from the MCP context).
