# Vitals: HP, hunger, drowning, fall damage, and the downed state

**Status:** approved 2026-09-07, not yet implemented. Sub-project 3.

Builds directly on the movement/stamina system (`2026-09-07-movement-stamina-design.md`) and the profile
foundation (`2026-09-07-profile-foundation-design.md` — the `Vitals` field reserved there is finally used).

## Scope

In scope: HP as a real value, hunger drain, swim stamina drain, drowning, fall damage + void death, the downed
(crawling) state with its countdown UI, and respawn.

**Not in scope, deliberately split out:** reviving and carrying a downed player ("โดนชุบ / โดนอุ้ม"). Those are
player-to-player interactions needing their own design (proximity prompt, hold duration, carry attachment,
what happens if the carrier dies). This spec leaves a clean hook for them; they get their own spec next.

Also out of scope (later sub-projects): roll/slide, attacking, mobile buttons for those.

## Numbers (all confirmed with the user)

| Thing | Value |
|---|---|
| Hunger: full → empty | 30 minutes |
| HP: full → downed, from starvation (hunger at 0) | 2 minutes |
| HP: full → dead, from drowning | 10 seconds |
| Stamina drain while swimming (moving only) | 5/s (~20s from full) |
| Downed countdown | 10 minutes |
| Respawn invulnerability | 10 seconds, character blinks |
| Fall damage | scaled by fall height; a high enough fall kills outright |
| Void (fell out of the map) | instant death, no fall-damage curve |

## Armor

Armor is a **one-time pool that never refills** (confirmed 2026-09-07, overriding this spec's earlier claim
that respawn restores it):

- 0-100, stored in `profile.Data.Vitals.Armor`, saved across sessions like HP and hunger.
- While armor > 0, incoming **combat** damage is split: half to armor, half to HP. Armor absorbs only as much
  as it has left, and the remainder falls through to HP in full.
- Once at 0 it stays at 0 forever — respawn does **not** restore it, and no other vitals rule touches it.
- Only combat damage is reduced. Starvation, drowning, and fall damage go straight to HP: armor doesn't help
  you stop being hungry.
- There is no way to gain armor yet. Players start at 0 (no armor system exists to grant any), so this code
  path is dormant until armor items arrive with a later sub-project — it is implemented now because the damage
  split has to live in `applyDamage` from the start rather than be retrofitted through every damage source.

## HP model

- 0-100, stored in `profile.Data.Vitals.HP`, saved across sessions (confirmed) — as is hunger. Stamina and mana
  are *not* saved (they refill on join, being second-to-second values).
- HP reaching 0 does **not** kill: it triggers the downed state (below). Only drowning, fall damage, and the
  void kill outright.
- Damage sources this pass: starvation, drowning, falling. (Combat damage arrives with sub-project 5; it will
  route through the same `applyDamage` path.)

## Hunger

- Drains continuously while in a channel server, 100 → 0 over 30 minutes (≈0.0556/s).
- At 0, HP drains at the rate that takes full HP → 0 in 2 minutes (≈0.833/s), which puts the player into the
  downed state.
- No food exists yet, so nothing refills hunger mid-session — the HUD bar simply reflects it, and respawn resets
  it to full. Eating arrives with the gathering sub-project.

## Swimming and drowning

- Stamina drains 5/s **only while actually swimming (moving in water)**. Floating still neither drains nor
  regenerates (confirmed) — so a player can rest at the surface indefinitely but must surface to recover.
- Detected via `Humanoid:GetState() == Enum.HumanoidStateType.Swimming` plus `MoveDirection.Magnitude > 0`.
- When stamina hits 0 while in water: drowning starts, HP drains at 10/s (full → 0 in 10s), and reaching 0 this
  way is an **instant death**, not a downed state (confirmed — you can't crawl underwater).
- Leaving the water stops drowning immediately; HP does not self-heal (no regeneration system yet).

## Fall damage and the void

Both behaviors, per the user's "ทั้งสองอย่าง":

- **Fall damage:** track the peak Y while the humanoid is `Freefall`; on landing, compare against the landing Y.
  Below a safe threshold (~12 studs, roughly a two-storey drop) do nothing; above it, damage scales with the
  extra distance, and a large enough fall exceeds 100 and kills outright.
- **Void:** if `HumanoidRootPart.Position.Y` drops below a floor constant (well under the sea bed), kill
  instantly without the fall-damage curve.
- Both are ignored while the respawn invulnerability window is active.

## Downed state (the big piece)

Entered when HP reaches 0 **on land** from starvation or fall damage that didn't outright kill.

- Character switches to a crawl: `WalkSpeed` set to a crawl speed, jumping disabled, crawl animation played.
  The player can still crawl around — this is not a ragdoll.
- **All other vitals freeze** (confirmed): hunger stops draining, stamina stops draining and regenerating. The
  only thing running is the countdown.
- **Fully invulnerable** (confirmed): further damage from any source — other players, more falls — does nothing.
  There is no finishing blow; the countdown is the only exit.
- Screen goes **nearly black with the surroundings faintly visible** (confirmed): a `ColorCorrectionEffect`
  dropping brightness/saturation hard, plus a vignette, so the player can still see enough to crawl.
- A large countdown sits in the centre of the screen, ticking down each second from 10:00.
- Below it, a **"เกิดใหม่ทันที"** button skips the wait.
- **Falling into water while downed = instant respawn** (confirmed), skipping the rest of the countdown.
- Movement input still works (crawling), but sprint/walk-toggle intent is ignored while downed.

### Crawl animation — reuse the stock swim animation on land

Decided 2026-09-07 (user: "ท่าล้มลงไปคลาน ใช้ท่าเดียวกันกับว่ายน้ำก็ได้แต่เป็นใช้บนบก จะได้ประหยัดเวลา").
A hand-built crawl was started and abandoned in favour of this; no custom animation is needed.

Roblox's default swim animation (`rbxassetid://913384386`, plus `913389285` for the idle) is exactly the
face-down paddling motion the crawl needs. Two facts found by measurement:

1. **The swim animation only moves the arms.** Played on land it leaves the body fully upright
   (`uprightDot=1.00`) — Roblox tilts the body prone through the *swimming humanoid state*, not the animation.
   Forcing `HumanoidStateType.Swimming` on land doesn't work either: the engine snaps straight back to Running.
2. **The tilt must be cosmetic only.** Physically rotating the character (via `AlignOrientation` on the root
   part) does look prone, but it stops the player moving almost entirely — travel fell from 2.88 studs to 0.01,
   because the humanoid's mover can't drive a rig whose orientation is pinned. `Root.C0` is read-only, so that
   route is closed too.

The approach that works: leave the humanoid upright so walking behaves normally, and pitch only the **visible**
body by writing `LowerTorso.Root.Transform` on `RunService.Stepped` (after the animator has run each frame, or
the animation overwrites it), with `HipHeight` lowered so the body rests near the floor. Measured prone:
`uprightDot=0.05`, `headAboveFoot=0.20`, and still travels 2.18 studs — and it restores cleanly on stand-up.

### Revive/carry hook (for the next spec)

The downed state exposes, server-side, "is this player downed" and a single entry point to end it early. The
revive and carry systems will call that entry point rather than reimplementing recovery — nothing else in this
spec needs to change when they land.

## Respawn

- Always at the main spawn point (`WOLD.TempSpawn`, later Brasshaven) — **never** at the saved last position
  (confirmed; the position system's 7-second autosave would otherwise drop the player right back where they
  died).
- On respawn: HP, hunger, stamina, and mana reset to full. **Armor does not** — see the Armor section; it is a
  one-time pool that stays wherever it was.
- 10 seconds of invulnerability, with the character blinking (transparency pulse) so it's visible to everyone.
  All damage sources are suppressed during it.

## Architecture

Follows the same shape as the movement system: **the server owns every value**, the client only renders.

- **`PlayerVitals.server.lua`** (new): one Heartbeat loop over all players, ticking hunger, swim stamina,
  drowning, fall damage, starvation, and the downed countdown. Owns the state table and all transitions. Reads
  and writes `profile.Data.Vitals` through `PlayerProfile`.
- **Stamina ownership moves here** from `PlayerMovement.server.lua`, since two systems now change it (sprinting
  and swimming) and drowning depends on it. `PlayerMovement` keeps the walk/run state machine and asks
  `PlayerVitals` for the stamina value instead of holding its own — one owner per value, no double-draining.
- **`Remotes`**: add `VitalsUpdate` (server → client, the whole vitals table, throttled like `StaminaUpdate` and
  likewise only in channel servers), `DownedStateChanged` (server → client, entering/leaving downed + the
  deadline), and `RequestRespawn` (client → server, the instant-respawn button; server re-verifies the player is
  actually downed).
- **`HudController`/`HudGui`**: HP, hunger, and armor bars start reflecting the real values instead of static
  full. Stamina already does.
- **`DownedGui`** (new UI module, matching the existing `HudGui`/`LoadingGui` pattern): the darkening effect,
  centre countdown, and respawn button. Built by a controller that listens for `DownedStateChanged`.
- **Animations:** crawl (and later roll/slide/punch) need Animation IDs owned by this account — none exist yet.
  Every animation slot is a clearly-marked constant that is safe to leave empty: the system works without them,
  it just won't look right. Fill them in from the Animation Editor later.

## Testing

Fully testable in Studio Play, like the movement system — no TeleportService dependency. The tick rates make
real-time verification slow (30 minutes for hunger), so the loop will be driven by a tunable time-scale
constant that testing can raise, rather than by `task.wait` calls scattered per system.
