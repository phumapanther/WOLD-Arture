-- CommandCatalog: every slash command, in one list, so the help text and the console's autocomplete cannot
-- disagree with each other.
--
-- This is a LIST OF NAMES, not a permission table. Whether a command actually runs is decided on the server
-- by AdminCommands.server.lua, which checks the UserId allow-list and the player's class on every line. A
-- client that reads a command out of here learns only that the word exists -- typing it still gets the same
-- silence a non-admin has always got.
--
-- Shared because the console needs it: before this, the only description of the commands was a block of
-- hand-written Thai inside /admin's reply, which the client could not read and which drifted from the real
-- command table every time one was added.
local CommandCatalog = {}

-- scope: "admin" (the allow-list), "noble" (the Noble class), "class" (any advanced class).
-- args is shown after the name in the suggestion list; desc is the one-line explanation.
CommandCatalog.Commands = {
	{ name = "give", args = "<ไอเทม> [จำนวน] [คน]", desc = "เสกของ", scope = "admin" },
	{ name = "gold", args = "<จำนวน> [คน]", desc = "เสกตัง (ติดลบ = ลด)", scope = "admin" },
	{ name = "gems", args = "<จำนวน> [คน]", desc = "เสกเพชร (ติดลบ = ลด)", scope = "admin" },
	{ name = "passxp", args = "<จำนวน> [คน]", desc = "เติม XP แบทเทิลพาส", scope = "admin" },
	{ name = "town", args = "[claim|free <เมือง>]", desc = "ดู/แก้เจ้าของเมือง", scope = "admin" },
	{ name = "vip", args = "<วัน> [คน]", desc = "ให้/ต่อ VIP (ติดลบ = ตัด)", scope = "admin" },
	{ name = "boss", args = "[ระยะ]", desc = "เสกบอสฟอร์จวอร์เดน", scope = "admin" },
	{ name = "worldboss", args = "[off|rank]", desc = "บอสโลก: เริ่ม/จบ/ดูตารางดาเมจ", scope = "admin" },
	{ name = "tpto", args = "<คน>", desc = "วาปไปหา", scope = "admin" },
	{ name = "bring", args = "<คน>", desc = "ดึงมาหา", scope = "admin" },
	{ name = "goto", args = "<x> <y> <z>", desc = "วาปไปพิกัด", scope = "admin" },
	{ name = "role", args = "<อาชีพ> [คน]", desc = "ตั้งอาชีพ", scope = "admin" },
	{ name = "unrole", args = "[คน]", desc = "ถอดอาชีพ", scope = "admin" },
	{ name = "kill", args = "[คน]", desc = "ฆ่า", scope = "admin" },
	{ name = "heal", args = "[คน]", desc = "ฟื้นฟูเต็ม", scope = "admin" },
	{ name = "level", args = "<n> [คน]", desc = "ตั้งเลเวล", scope = "admin" },
	{ name = "god", args = "[คน]", desc = "อมตะ เปิด/ปิด", scope = "admin" },
	{ name = "fly", args = "[ความเร็ว]", desc = "บิน", scope = "admin" },
	{ name = "land", args = "", desc = "ลงพื้น", scope = "admin" },
	{ name = "time", args = "<เช้า|กลางคืน|ชั่วโมง|auto>", desc = "ตั้งเวลาของโลก หรือปล่อยให้เดินเอง", scope = "admin" },
	{ name = "anim", args = "[ท่า] [คน]", desc = "สั่งเล่นท่าทาง (ไม่ใส่ชื่อท่า = ดูรายชื่อ)", scope = "admin" },
	{ name = "event", args = "<ชื่ออีเวนต์>", desc = "สั่งอีเวนต์", scope = "admin" },
	{ name = "blackout", args = "", desc = "ไฟดับทั้งเมือง", scope = "admin" },
	{ name = "slime", args = "", desc = "สไลม์กลายพันธุ์", scope = "admin" },
	{ name = "mob", args = "[จำนวน]", desc = "เสกมอนสุ่มรอบตัว ไล่ล่าคุณไม่เลิก", scope = "admin" },
	{ name = "fw", args = "[จำนวน] [ระยะ] [สูง] | at <x> <z> [สูง]", desc = "ยิงพลุรอบตัว หรือระบุพิกัดด้วย at", scope = "admin" },
	{ name = "chest", args = "[ไม้|เหล็ก|เงิน|ทอง]", desc = "วางหีบสมบัติข้างตัว (ไม่ใส่ = สุ่มระดับ)", scope = "admin" },
	{ name = "weather", args = "<ชนิด|auto>", desc = "ตั้งสภาพอากาศ หรือปล่อยให้สุ่มเอง", scope = "admin" },
	{ name = "veh", args = "<คำสั่งย่อย>", desc = "ระบบพาหนะ", scope = "admin" },
	{ name = "items", args = "", desc = "รายชื่อไอเทม", scope = "admin" },
	{ name = "announce", args = "<ข้อความ>", desc = "ประกาศ", scope = "admin" },
	{ name = "admin", args = "", desc = "คำสั่งทั้งหมด", scope = "admin" },
	{ name = "setadmin", args = "<คน>", desc = "ตั้งเป็นแอดมิน (เฉพาะเจ้าของเกม)", scope = "admin" },
	{ name = "unadmin", args = "<คน>", desc = "ถอนแอดมิน (เฉพาะเจ้าของเกม)", scope = "admin" },
	{ name = "admins", args = "", desc = "ดูรายชื่อแอดมิน", scope = "admin" },

	-- A noble has no commands of its OWN any more. The seven it may run are admin commands it is allowed to
	-- reach (NOBLE_MAY_RUN in AdminCommands), and all seven are already listed above under the admin scope --
	-- listing them twice would put them in the console's suggestions twice.

	{ name = "help", args = "", desc = "คำสั่งที่อาชีพของคุณใช้ได้", scope = "class" },
}

-- Every command whose name starts with `prefix`, in the order above. The prefix comes in without its slash.
--
-- An exact name is kept in the list rather than short-circuiting to it: "/land" is also the start of nothing
-- else, but "/a" is the start of three commands and a player typing it wants to see all three.
function CommandCatalog.Matching(prefix, scopes)
	local lower = (prefix or ""):lower()
	local out = {}
	for _, entry in ipairs(CommandCatalog.Commands) do
		if (not scopes or scopes[entry.scope]) and entry.name:sub(1, #lower):lower() == lower then
			table.insert(out, entry)
		end
	end
	return out
end

-- The /admin reply, built from the list above so it can never fall behind it.
function CommandCatalog.HelpLines(scope)
	local out = {}
	for _, entry in ipairs(CommandCatalog.Commands) do
		if entry.scope == scope then
			table.insert(out, ("/%s %s%s- %s"):format(entry.name, entry.args,
				entry.args == "" and "" or " ", entry.desc))
		end
	end
	return out
end

return CommandCatalog
