-- WeaponVisualsAccess: a hand-off from PlayerCombat to the file that holds the weapon model.
--
-- The same idea as RescueAccess and ProfileAccess. Two weapons -- the spellbook and the staff -- sit at the
-- chest while their attack pose is up and in the hand the rest of the time, so WeaponVisuals has to know
-- when a swing happens. CombatStateChanged is fired BY the server at clients and cannot be listened to on
-- the server, and having WeaponVisuals require PlayerCombat (or the reverse) would tie two unrelated files
-- together for one call.
--
-- Empty until WeaponVisuals has published itself, so callers must cope with nil -- in the lobby it never is.
local WeaponVisualsAccess = {}

-- OnAttack(player) -- called once per swing. Safe to call for any weapon; it does nothing for the ones that
-- do not move.
WeaponVisualsAccess.OnAttack = nil

-- OnAim(player, aiming) -- การ์ดขึ้น/ลง · สไนย้ายจากมือไปอกตลอดที่ส่องสโคป (อาวุธอื่นไม่สนใจ)
WeaponVisualsAccess.OnAim = nil

-- BuildModel(weaponId, meta) -> model, shapeId -- โมเดลอาวุธ (สกินครบ) ที่ยังไม่ได้วาง · อาวุธตกพื้นในสนามใช้
WeaponVisualsAccess.BuildModel = nil

return WeaponVisualsAccess
