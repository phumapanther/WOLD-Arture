-- ProfileAccess: a tiny hand-off between PlayerProfile (which owns the DataStore session) and the systems
-- that need to read or contribute to the saved data.
--
-- It exists to keep those systems from requiring each other in a cycle: PlayerProfile must be able to save
-- Progression's level without depending on a channel-only module, and Progression must be able to read the
-- saved level without depending on the profile lifecycle.
local Players = game:GetService("Players")

local ProfileAccess = {}

local Data = {} -- [player] = profile.Data, only while the session is live

function ProfileAccess.Set(player, data)
	Data[player] = data
end

function ProfileAccess.Get(player)
	return Data[player]
end

-- Blocks until this player's profile has arrived, and answers with it. nil means it never will, because the
-- player has left.
--
-- Every system that restores something -- bag, level, classes, bank, warehouse, garage -- used to poll Get on
-- its own for a fixed four seconds and then carry on with nil. Two things are wrong with a deadline here.
-- The player is not gone when it expires, so they get a STARTER kit and level 1; and the profile usually
-- arrives a moment later, at which point the autosave writes that starter kit over the bag they actually
-- had. A slow DataStore day does not just fail to restore -- it destroys.
--
-- There is no deadline that is safe, so there is no deadline. The wait is bounded by the only thing that can
-- truly end it: PlayerProfile kicks a player whose session will not start, and leaving ends this loop. A wait
-- long enough to notice says so once, so a hang is visible in the log rather than silent.
function ProfileAccess.Wait(player)
	local started = os.clock()
	local grumbled = false
	while Data[player] == nil and player:IsDescendantOf(Players) do
		if not grumbled and os.clock() - started > 10 then
			grumbled = true
			warn(("[ProfileAccess] still waiting for %s's profile after 10s"):format(player.Name))
		end
		task.wait(0.1)
	end
	return Data[player]
end

-- Set by Progression at startup: PlayerProfile calls this when saving. nil in the lobby, where no progression
-- system runs and there is nothing to save.
ProfileAccess.SerializeProgression = nil
ProfileAccess.SerializeInventory = nil
ProfileAccess.SerializeRole = nil
ProfileAccess.SerializeSocial = nil
ProfileAccess.SerializeVault = nil

-- Set by PlayerProfile: copies a player's current level and bag into their profile immediately, rather than
-- waiting for the next autosave tick. Call it after anything worth keeping.
ProfileAccess.Flush = nil

-- PeekAsync(userId) -> ตารางข้อมูลโปรไฟล์ (อ่านอย่างเดียว) หรือ nil
--
-- **ใช้ในล็อบบี้** ซึ่งไม่ได้เปิดเซสชันโปรไฟล์ของใครเลย (ProfileStore ล็อกเซสชันไว้กับเซิร์ฟช่อง) แต่ต้อง
-- รู้บางอย่างของคนที่ยืนอยู่ตรงนั้น เช่น "เป็น VIP ไหม" เพื่อวาดแถวโหมดฟาร์มมิ่ง — อ่านผ่านทางนี้เท่านั้น
-- **ห้ามเปิดเซสชันในล็อบบี้** ไม่งั้นจะไปแย่งล็อกกับเซิร์ฟที่เขากำลังเล่นอยู่ แล้วเขาจะโดนเตะออกจากเกม
ProfileAccess.PeekAsync = nil

-- MessageAsync(userId, message) -> true ถ้าฝากสำเร็จ
--
-- ฝากข้อความไว้กับโปรไฟล์ของ **คนที่ไม่ได้อยู่ในเซิร์ฟนี้** (หรือไม่ได้ออนไลน์เลย) ProfileStore เขียนลง
-- เรคอร์ดของเขาใน DataStore แล้วส่งให้ตอนเขาเปิดเซสชันครั้งถัดไป — เป็นทางเดียวที่แตะข้อมูลคนอื่นได้
-- โดยไม่ไปแย่งล็อกเซสชัน (ซึ่งจะเตะเขาออกจากเกม) · ผู้รับอยู่ใน `PlayerProfile.server.lua`
ProfileAccess.MessageAsync = nil

return ProfileAccess
