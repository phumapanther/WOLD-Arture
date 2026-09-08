# Reviving and carrying a downed player

**Status:** approved 2026-09-08 (every number below confirmed with the user), not yet implemented. Sub-project 3b.

Takes the hook `2026-09-07-vitals-downed-design.md` deliberately left open: `Vitals.Recover(player, hpFraction)`
already ends the downed state without respawning, and nothing in the vitals system needs to change for this.

## Scope

In scope: CPR revive, piggyback carry, putting someone down, the prompts that start both, the animations, and
every way either can be interrupted (carrier dies, target's countdown expires, someone leaves the server).

Out of scope: roll and slide (sub-project 4), medical items or bandages, reviving NPCs, dragging by the ankles.

## Numbers (all confirmed with the user)

| Thing | Value |
|---|---|
| CPR hold to complete a revive | 8 seconds |
| HP the revived player comes back with | 30% |
| Downed countdown while being carried or revived | **keeps running, always** |
| What the carrier can do while carrying | everything they normally can |
| Stamina cost of sprinting while carrying | 2x the normal drain |
| Prompt activation distance | 7 studs |

The countdown never pauses (confirmed): an 8-second CPR that gets interrupted leaves the target no better off,
and a carrier has to actually reach safety rather than parking a body somewhere to stop the clock. It is the
simplest rule and the one with no exploit.

## Interaction: two ProximityPrompts on the downed character

Roblox's `ProximityPrompt` was chosen over a hand-built UI (confirmed) because it already supplies the hold
ring, the release-to-cancel behaviour, and keyboard, gamepad and touch input — none of which have to be added
to `TouchActionGui`, which is where the roll/slide button already lives. The default look can be replaced later
with a custom prompt GUI without touching any of the logic here.

Both prompts are parented to the downed character's `HumanoidRootPart`, created when the player goes down and
destroyed on every exit from the downed state:

| Prompt | ActionText | Key | HoldDuration |
|---|---|---|---|
| `RevivePrompt` | ปั๊มหัวใจ | E | 8 (the full CPR) |
| `CarryPrompt` | อุ้ม / วางลง | F | 0.4 (long enough that a stray tap can't fire it) |

`RequiresLineOfSight = false` — a body on the ground fails the engine's line-of-sight check from standing
eye height often enough to be maddening.

The downed player sees their own prompts too, since a prompt cannot be hidden from one player server-side. The
server simply rejects a trigger whose sender is the target, and the client hides them through
`ProximityPromptService.PromptShown` when `prompt.Parent` belongs to the local player's own character.

`Vitals` gains a `DownedChanged` BindableEvent fired inside `EnterDowned` and `clearDowned`, so the revive
system learns about state changes instead of polling `Vitals.IsDowned` every frame. That is the only edit this
spec makes to existing vitals code.

## CPR revive

`ProximityPrompt.Triggered` only fires after the whole 8-second hold, and
`PromptButtonHoldBegan`/`PromptButtonHoldEnded` bracket the attempt — that is the entire state machine, with no
custom timer.

On hold began (server, after validating that the target is still downed and not being carried, that the reviver
is alive, not downed and not carrying, and that no one else is already reviving this target):

- The reviver's `WalkSpeed` goes to 0 and their character is CFramed to a fixed offset beside the target,
  **facing them**. Without that snap the kneeling pose floats next to a body it is not touching.
- `CPR_Loop` plays on the reviver. Its `Beat` KeyframeMarker fires the compression sound and pulses the heart
  icon on the HUD, so audio and UI land on the press instead of on a guessed interval.

On `Triggered`: `Vitals.Recover(target, 0.3)`, both prompts destroyed by the resulting `DownedChanged`.

On hold ended without a trigger: everything above is undone and the target keeps its countdown.

**Cancelling from the server** (the reviver takes damage, gets downed, or the target is picked up mid-CPR) has
no direct API — a hold is driven by the client that owns it. Setting `prompt.Enabled = false` for a frame and
back cancels it, and that is what the implementation should do rather than trying to reach into the client.

Only one reviver per target at a time. A second player's hold is rejected on `PromptButtonHoldBegan`.

## Carry (piggyback)

Triggering `CarryPrompt` attaches the target to the carrier's back. Four things have to happen together, and
each one looks like a bug on its own if it is missed:

1. **`Motor6D`** — `Part0 = carrier.UpperTorso`, `Part1 = carried.HumanoidRootPart`,
   `C0 = CFrame.new(0, 0.15, 1.55) * CFrame.Angles(math.rad(-8), 0, 0)` (tune against the built pose).
   A `Motor6D` and not a `WeldConstraint`: only a Motor6D leaves the carried player's own `Animator` free to
   play `Carry_Held` on top of the joint.
2. **`PlatformStand = true`** on the carried humanoid, or it fights the joint every frame.
3. **A collision group** so the two characters do not collide with each other. Register it once at startup via
   `PhysicsService`; without it the two capsules shove each other apart and the carry jitters or launches.
4. **`SetNetworkOwner(carrier)` on every BasePart of the carried character.** Two clients simulating the same
   welded assembly is the single most common reason carry systems in Roblox look broken.

**The crawl tilt has to stop while carried.** `DownedController` fakes the prone crawl by writing
`LowerTorso.Root.Transform` on `RunService.Stepped`, which runs *after* the animator and would therefore
overwrite `Carry_Held` entirely, leaving a rigid prone plank floating on the carrier's back. While carried, that
writer pauses and `HipHeight` returns to 2. It resumes on put-down.

**What the carrier can do:** everything, unchanged (confirmed) — walk, sprint, jump, punch bare-handed. The only
penalty is that sprinting drains stamina at 2x, which needs a multiplier hook where `Vitals` ticks sprint
drain, not a second copy of the drain rule.

**Open point — roll and slide while carrying.** The user's answer was "ทำได้เหมือนเดิมทุกอย่างเลย", so this
spec allows them. Neither exists yet (sub-project 4), and a passenger welded to a tumbling carrier will look
wrong. Revisit when the moves land: either forbid them while carrying, or drop the passenger on the first frame
of a roll.

### Putting down

The same `CarryPrompt` switches its `ActionText` to "วางลง" while the carry is active, and the server honours
that trigger **only from the carrier** — otherwise any passer-by could unload someone else's rescue. The
carried player lands on the ground behind the carrier, facing the same way, with the joint, collision group,
network ownership, `PlatformStand` and crawl tilt all restored.

`RevivePrompt` is disabled while a player is being carried: CPR needs the body on the ground, and the kneeling
pose has nothing to line up with while the target is on someone's back. Put them down first.

### Everything that ends a carry

Drop immediately, restoring the same four things, when any of these happens: the carrier dies, goes downed,
leaves the server, or their character is removed; the carried player's countdown expires, they respawn, or they
leave; or the carried player is somehow recovered by other means.

## Animations

All three sequences already exist in `ServerStorage.WOLD_Animations`, built by `animgen/revive.lua`. They are
not published yet. Once each is right-clicked → **Save to Roblox** (on the account that owns the place, or the
`Animation` fails to load), the ids go in `VitalsConfig` alongside `CrawlAnimation`, which already owns the
downed lifecycle's assets:

| Constant | Sequence | Played on |
|---|---|---|
| `ReviveAnimation` | `CPR_Loop` | the reviver, looped for the length of the hold |
| `CarryHolderAnimation` | `Carry_Holder` | the carrier, looped (arms and torso only, so the walk still drives the legs) |
| `CarryHeldAnimation` | `Carry_Held` | the carried player, looped |

Every id is safe to leave as `""` — the system works, it just will not look right — the same rule
`CombatConfig` follows.

## Architecture

Mirrors `PlayerCombat.server.lua`: one server script owning the state, clients doing presentation only.

- **`src/ServerScriptService/PlayerRevive.server.lua`** (new): builds and tears down the prompts off
  `Vitals.DownedChanged`, validates every trigger, owns the "who is reviving whom" and "who is carrying whom"
  tables, builds and destroys the Motor6D, and handles all of the teardown cases above.
- **`Vitals.lua`**: gains the `DownedChanged` BindableEvent and a stamina-drain multiplier the carry can set.
  Nothing else changes; `Vitals.Recover` is called exactly as it was designed to be.
- **`Remotes`**: add `ReviveStateChanged` (server → all clients: `who`, `event`, `target`), shaped exactly like
  `CombatStateChanged` so animation playback for other players works the same way it already does for punches.
- **`src/StarterPlayerScripts/ReviveController.client.lua`** (new): plays the three animations off
  `ReviveStateChanged`, hides the local player's own prompts, and pulses the HUD heart on the `Beat` marker.
- **`DownedController.client.lua`**: pauses its `Stepped` tilt writer while the local player is being carried.

## Testing

Two players are required, so this is a Studio 2-player local test rather than the single-player Play sessions
the earlier systems used. `VirtualInputManager` is blocked here (established in sub-project 2), so a
ProximityPrompt hold cannot be driven from a test script — call the server's own trigger handler directly, the
same way movement transitions were tested by firing remotes instead of pressing keys.

Worth testing specifically, because each has a distinct failure that only shows up with a second player:
carrier disconnects mid-carry; target's countdown expires mid-carry; two players hold CPR on the same target;
CPR started on a target who is picked up during the hold; carrier jumps and sprints with a passenger; put-down
placement on a slope.
