-- EventState.lua: what the world is currently doing, and where the pieces of an event meet.
--
-- Three jobs, all of them about keeping the event system from turning into a knot of mutual requires:
--
--   1. THE ANSWER. `IsBlackout()` is asked by every NPC prompt in the game. The shopkeeper must not have to
--      require the event scheduler to find out whether the lights are on.
--   2. THE BOARD. `Active` is the live set of events, written by WorldEvents and read by anything that cares.
--   3. THE SOCKET. An event's *effects* live with the system that owns them -- the transformers own the
--      blackout, the monsters own the slimes -- so each registers a pair of handlers here and the scheduler
--      calls them without knowing what they do.
--
-- Same reasoning as ProfileAccess: somebody has to be the shallow module in the middle, and it is this one.
local EventState = {}

-- [eventId] = { startedAt, endsAt | nil, detail | nil, hp | nil }. Written only by WorldEvents.
EventState.Active = {}

-- [eventId] = { start = function() end, stop = function() end }. Registered by whichever system implements
-- the event. A missing entry is not an error -- it means that event has no world effects yet, and the
-- announcement still runs.
EventState.Hooks = {}

-- Set by WorldEvents: call it after changing anything a player can see, and the new picture goes out.
EventState.Publish = nil

function EventState.Register(id, handlers)
	EventState.Hooks[id] = handlers
end

function EventState.IsActive(id)
	return EventState.Active[id] ~= nil
end

-- The one rule that reaches outside the event system: while the city's engines are down, an NPC will not
-- talk to you. Asked by every NPC prompt, so the answer lives in one place.
function EventState.IsBlackout()
	return EventState.Active.blackout ~= nil
end

-- What to say instead. Exactly the user's wording, kept here so every refusal is worded identically wherever
-- it comes from.
EventState.BlackoutRefusal = "ไฟดับอยากรุณาไปซ่อมไฟก่อน"

-- True when the player may open an NPC's menu at all. Returns the reason as a second value, so a caller can
-- pass it straight to the notification it was going to send anyway.
function EventState.NpcAvailable()
	if EventState.IsBlackout() then return false, EventState.BlackoutRefusal end
	return true
end

-- The line on the right-hand side of the banner, for an event with no clock. The blackout uses it to count
-- machines still broken; anything with an `endsAt` shows a countdown instead and never calls this.
function EventState.SetDetail(id, detail)
	local entry = EventState.Active[id]
	if not entry then return end
	if entry.detail == detail then return end -- nothing to say, so nothing to send
	entry.detail = detail
	if EventState.Publish then EventState.Publish() end
end

-- หลอดเลือดใต้ป้ายประกาศ (ผู้ใช้สั่ง 2026-09-21 สำหรับบอสโลก) — `nil` = ไม่มีหลอด
--
-- อยู่ใน EventState ไม่ใช่ใน WorldBoss เพราะป้ายประกาศเป็นของระบบอีเวนต์ ไม่ใช่ของบอส · วันไหนมี
-- อีเวนต์อื่นที่มีเป้าหมายเป็นเลือดก้อนหนึ่ง (เรือโจรสลัด ประตูเมือง) มันก็เรียกฟังก์ชันเดียวกันนี้
--
-- **เงียบเมื่อค่าไม่เปลี่ยน** เหมือน `SetDetail` — ตัวเรียกโพลทุกครึ่งวินาทีได้โดยไม่ต้องคิดเอง
-- และช่วงที่ไม่มีใครตีบอสก็ไม่มีแพ็กเก็ตวิ่งเลยสักอัน
function EventState.SetHealth(id, current, maximum)
	local entry = EventState.Active[id]
	if not entry then return end

	local hp = nil
	-- `maximum = 0` คือ "ยังไม่มีตัวอยู่ในโลก" (อีเวนต์เริ่มแล้วแต่บอสยังไม่โผล่) ไม่ใช่ "เลือดหมด"
	-- สองอย่างนี้ต้องต่างกัน ไม่งั้นหลอดจะขึ้นเป็นศูนย์ค้างอยู่สองวินาทีแรกของทุกรอบ
	if maximum and maximum > 0 then
		hp = { current = math.max(0, math.floor(current or 0)), maximum = math.floor(maximum) }
	end

	local old = entry.hp
	if (old == nil) == (hp == nil)
		and (hp == nil or (old.current == hp.current and old.maximum == hp.maximum)) then
		return
	end

	entry.hp = hp
	if EventState.Publish then EventState.Publish() end
end

return EventState
