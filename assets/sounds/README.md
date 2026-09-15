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

## Vehicle sounds

The steam machinery, synthesised by the same script. These are what the vehicles will sound like once they
are uploaded -- until then `Vehicle/Config.lua` plays Roblox's own stock sounds pitched down, which is why a
car already makes a noise today.

`engine_drone` and `engine_wash` are **looped** by `VehicleSoundController`, so they are rendered as a whole
number of cycles and written with no fade at either end. Do not "clean them up" by trimming the ends: the
silence a fade leaves is a hole you would hear twice a second.

| file | goes in (`Vehicle/Config.lua` -> `Config.Sound.types`) | plays |
|---|---|---|
| `engine_drone.mp3` | `Car/Boat/Airship .drone.id` | the boiler, always, pitch rising with throttle |
| `engine_wash.mp3` | `Boat/Airship .wash.id` | water and wind, louder with speed |
| `engine_chug_a.mp3` | `.pulse.ids[1]` (all three) | one piston stroke |
| `engine_chug_b.mp3` | `.pulse.ids[2]` (all three) | the off-beat stroke, so it is not a metronome |
| `engine_vent.mp3` | `.vent.id` (all three) | steam let go when the throttle drops at speed |
| `horn_car.mp3` | `Car.horn.id` | H |
| `horn_boat.mp3` | `Boat.horn.id` | H |
| `horn_airship.mp3` | `Airship.horn.id` | H |

**Set the pitches back to about 1 when you paste the ids in.** The values in there now (0.2-0.6) exist to
drag Roblox's stock sounds down far enough to pass as machinery; these files are already machinery, and
leaving the pitch where it is would bury them.


## ⚠️ เสียงดังใน Studio แต่เงียบในเกมจริง (เจอ 2026-09-15 กับเสียงพาหนะ)

**ไม่ใช่บั๊กในโค้ด** ตั้งแต่ปี 2022 Roblox ทำให้เสียงที่อัปใหม่เป็น **ส่วนตัว (private) โดยปริยาย** —
Studio เล่นได้เพราะคุณล็อกอินเป็นเจ้าของไฟล์อยู่ แต่เซิร์ฟเวอร์ของเกมจริงเป็นคนละตัวตน จึงถูกปฏิเสธและเงียบสนิท
ไม่มี error ไม่มีอะไรบอก

หลักฐานที่ยืนยันว่าเป็นเรื่องนี้: `hit_wood` / `hit_rock` (อัป 10 ก.ย.) ดังในเกมจริงปกติ ส่วน `engine_drone` /
`horn_car` (อัป 15 ก.ย.) เงียบ ทั้งที่เป็นบัญชีเดียวกัน เกมเดียวกัน และโค้ดเส้นทางเดียวกัน

**วิธีแก้ ทำทีละไฟล์:**
Creator Dashboard → Creations → เลือกเกม → **Configure Experience** → Audio
(หรือ create.roblox.com → Development Items → Audio → คลิกไฟล์ → Permissions)
แล้วเพิ่มเกมนี้เข้าไปในรายการที่ได้รับอนุญาต

ทางลัดที่ได้ผลเหมือนกัน: ใน Studio เปิด **Asset Manager → Audio** แล้วลากไฟล์เข้า place โดยตรง
Roblox จะผูกสิทธิ์ให้เองตอนอัปผ่านช่องทางนั้น
