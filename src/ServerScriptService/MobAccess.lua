-- MobAccess: the hand-off between the combat system (which knows how a hit was made) and the monster
-- system (which knows what a monster is).
--
-- Exists for the same reason ProfileAccess and RescueAccess do: PlayerCombat must be able to damage a
-- monster without requiring Mobs.server, and Mobs.server must be free to require the combat config. One
-- of them has to be the shallow one, and it is this.
local MobAccess = {}

-- Set by Mobs.server at startup. Takes (model, damage, attacker) and returns true if the model really was
-- a live monster, so the caller knows whether to play a hit sound. Left nil in the lobby, where no
-- monsters run -- every caller must check before calling.
MobAccess.Damage = nil

-- Set by Mobs.server at startup. Takes (model, seconds) and holds that monster still -- the greatsword's
-- rider. Separate from Damage because a stun is not a hit: the same swing does both, and either can land
-- without the other. Left nil in the lobby, so every caller must check.
MobAccess.Stun = nil

-- Set by Mobs.server at startup. Takes (victim, distance, count) and conjures that many monsters in a ring
-- around them, each picked at random from every kind in the game. They have no spawner, never respawn, and
-- chase that one player and no other. Left nil in the lobby, so every caller must check.
MobAccess.SpawnHunters = nil

-- Set by Mobs.server at startup. Takes (victim, distance, { scale, power, title, kind }) and conjures ONE
-- hunter built to those numbers -- a named boss, which is what a TikTok subscriber buys. Returns the model
-- and the kind's display name, or nil. Left nil in the lobby, so every caller must check.
MobAccess.SpawnBoss = nil

--------------------------------------------------------------------------------
-- อีเวนต์ที่มีมอนเป็นตัวเอก (บอสโลก)
--------------------------------------------------------------------------------

-- ตั้งโดย `WorldBoss.server` · Mobs.server เรียกทุกครั้งที่มอนซึ่งเกิดจากหมุดที่มี `EventOnly`
-- โดนตี — (eventId, ผู้ตี, ดาเมจที่เข้าจริง) ทิศทางเดียว: ระบบมอนรายงาน ระบบอีเวนต์เก็บยอดเอง
--
-- **ยอดสะสมต้องอยู่ฝั่งอีเวนต์ ไม่ใช่ฝั่งมอน** เพราะบอสโลกไม่จำเป็นต้องตาย พอหมดเวลาโมเดลถูกลบทิ้ง
-- พร้อมสถานะของมัน ถ้าเก็บยอดไว้ในตัวมอน รางวัลของรอบที่บอสรอดจะหายไปทั้งรอบ
MobAccess.OnEventDamage = nil

-- ตั้งโดย `WorldBoss.server` · เรียกตอนมอนของอีเวนต์ตายพอดี — (eventId, คนฟันไม้สุดท้าย)
-- แยกจาก OnEventDamage เพราะ "คนทำดาเมจเยอะสุด" กับ "คนฟันไม้สุดท้าย" เป็นรางวัลคนละใบ
MobAccess.OnEventKill = nil

-- ตั้งโดย Mobs.server · เปิด/ปิดหมุดที่ติด `EventOnly = <id>` และนับว่ามอนของอีเวนต์นั้นยังอยู่กี่ตัว
-- มีไว้ให้ระบบอีเวนต์ที่ **ไม่ใช่** Mobs.server เป็นเจ้าของ (บอสโลก) สั่งมอนได้โดยไม่ต้องแตะตาราง `Live`
MobAccess.StartEventSpawners = nil
MobAccess.StopEventSpawners = nil
MobAccess.EventMobsAlive = nil

return MobAccess
