# Combat sounds

Synthesised by `tools/make-sounds.py` (numpy + stdlib `wave`), converted by `tools/wav-to-mp3.py`
(PyAV — this machine has no ffmpeg binary and installers are blocked).

Regenerate both with:

    PYTHONUTF8=1 <python> tools/make-sounds.py
    PYTHONUTF8=1 <python> tools/wav-to-mp3.py assets/sounds assets/sounds

## Uploading

Upload the `.mp3` files at <https://create.roblox.com/dashboard/creations> → Audio, **signed in as the
account that owns the place** (same rule as the animations — assets uploaded by another account will not
load). Then paste each id into `CombatConfig.Sounds`:

| file | goes in | plays |
|---|---|---|
| `sword_swing.mp3` | `Sounds.Sword.cast` | at the attacker, on the swing |
| `sword_hit.mp3` | `Sounds.Sword.hit` | at whoever it lands on |
| `bow_shoot.mp3` | `Sounds.Bow.cast` | at the archer, as the arrow leaves |
| `bow_hit.mp3` | `Sounds.Bow.hit` | at whoever the arrow hits |
| `laser_shoot.mp3` | `Sounds.Staff.cast` | at the caster |
| `laser_hit.mp3` | `Sounds.Staff.hit` | where the beam lands |
| `spell_shoot.mp3` | `Sounds.Spellbook.cast` | at the caster |
| `spell_hit.mp3` | `Sounds.Spellbook.hit` | where the orb lands |

An empty id is safe: that half stays silent, and an unset `hit` falls back to `VitalsConfig.HitSoundId`
(the punch sound) so combat never lands in silence.

The `.wav` files are the uncompressed renders, kept so the sounds can be re-tuned without re-synthesising
from scratch. Only the `.mp3` files need uploading.
