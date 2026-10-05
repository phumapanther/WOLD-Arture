-- ServerConfig.lua: require this once; it does the (blocking, ~100-300ms) self-identification DataStore call up front
-- so every other server script sees a fully-populated table with no race.
local ChannelRegistry = require(script.Parent.Lobby.ChannelRegistry)

-- ponytail: Studio Play is ALWAYS the lobby (PrivateServerId is empty there), so every channel-only system —
-- vitals, the downed state, the HUD — is switched off and can't be tested without publishing. Flip this to
-- pretend Play is a channel server. Flip it back before publishing, or the real lobby will run gameplay.
local FORCE_CHANNEL_IN_STUDIO_FOR_TESTING = true

local ServerConfig = {}

-- **เพลสปลายทางของโหมดฟาร์มมิ่ง** (เกาะลอยฟ้า) — อยู่ใน universe เดียวกับเกมหลัก ข้อมูลผู้เล่นจึงใช้ร่วมกัน
-- ตั้งชื่อ "WOLD Farming" บนเว็บ · 0 = ยังไม่มีเพลส (ล็อบบี้จะขึ้นแถวโหมดนี้เป็น "ยังไม่เปิด" แทน)
ServerConfig.FarmingPlaceId = 136992335889132

-- **เพลสหลัก = ล็อบบี้** (เซิร์ฟสาธารณะของเพลสนี้คือหน้าเลือกช่อง)
--
-- ⚠️ จำเป็นเพราะ **`game.PlaceId` ไม่ใช่ทางกลับล็อบบี้อีกแล้ว** — บนเกาะมันคือเลขของเกาะเอง
-- `LobbyTravel` เคยเทเลพอร์ตไป `game.PlaceId` ซึ่งถูกตอนที่มีเพลสเดียว แต่บนเกาะ
-- **มันส่งกลับมาที่เกาะเดิม** (ผู้ใช้แจ้ง 2026-09-22: กดกลับล็อบบี้แล้วยังอยู่เซิร์ฟฟาร์ม)
ServerConfig.MainPlaceId = 88774255487951

-- **เพลสสนาม PVP** (universe เดียวกับเกมหลัก ข้อมูลจึงเป็นก้อนเดียวกันโดยไม่ต้องทำสะพานอะไรเลย)
-- ตั้งชื่อ "WOLD Arena" บนเว็บ · 0 = ยังไม่มีเพลส (แท็บ PVP จะบอกตรงๆ ว่าสนามยังไม่เปิด แทนที่จะหมุนค้าง)
--
-- ⚠️ เซิร์ฟของเพลสนี้ **มีสองแบบ**: เซิร์ฟที่ถูกจองไว้ให้แมตช์หนึ่งแมตช์ (มีบันทึกใน `ArenaRegistry`)
-- กับเซิร์ฟสาธารณะที่คนกดเข้ามาเองจากหน้าเกม ซึ่งไม่มีแมตช์อยู่เลย — `Arena/ArenaMatch` แยกสองอย่างนี้
ServerConfig.ArenaPlaceId = 134798670267276

local FarmRegistry = require(script.Parent.Lobby.FarmRegistry)
local ArenaRegistry = require(script.Parent.Lobby.ArenaRegistry)

-- เพลสเกาะฟาร์มรู้ตัวจาก PlaceId ไม่ใช่จาก PrivateServerId: Studio Play ในเพลสนี้จึงเป็นเกาะเสมอโดยไม่ต้องพึ่ง
-- FORCE flag และเซิร์ฟสาธารณะของเพลสนี้ (ถ้ามีใครหลงเข้ามา) ก็ไม่กลายเป็นล็อบบี้
ServerConfig.IsFarm = game.PlaceId == ServerConfig.FarmingPlaceId

-- เพลสสนามรู้ตัวจาก PlaceId เหมือนเกาะ — Studio Play ในเพลสนั้นจึงเป็นสนามเสมอโดยไม่ต้องพึ่ง FORCE flag
-- (ArenaPlaceId = 0 แปลว่ายังไม่มีเพลส `game.PlaceId` ไม่มีทางเป็น 0 เงื่อนไขนี้จึงเป็นเท็จเสมอ)
ServerConfig.IsArena = ServerConfig.ArenaPlaceId ~= 0 and game.PlaceId == ServerConfig.ArenaPlaceId

ServerConfig.IsLobby = game.PrivateServerId == "" and not ServerConfig.IsFarm and not ServerConfig.IsArena
if FORCE_CHANNEL_IN_STUDIO_FOR_TESTING and game:GetService("RunService"):IsStudio() then
	ServerConfig.IsLobby = false
end
if ServerConfig.IsArena then
	ServerConfig.Mode = "PVP"
	-- nil = เซิร์ฟสาธารณะของเพลสสนาม (ไม่ได้มาจากล็อบบี้) → `Arena/ArenaServer` จะเด้งทุกคนกลับล็อบบี้
	ServerConfig.ArenaMatch = ArenaRegistry.MatchOfServer(game.PrivateServerId)
	ServerConfig.Channel = 0
elseif ServerConfig.IsFarm then
	ServerConfig.Mode = "Farming"
	-- nil ใน Studio (ไม่มี Reserved Server) → IslandBuild ให้คนแรกที่เข้าเป็นเจ้าของ · nil ในเซิร์ฟจริง = ไม่ได้มาจากล็อบบี้
	ServerConfig.FarmOwnerId = FarmRegistry.OwnerOfServer(game.PrivateServerId)
	ServerConfig.Channel = ServerConfig.FarmOwnerId or 0
elseif ServerConfig.IsLobby then
	ServerConfig.Mode = nil
	ServerConfig.Channel = nil
elseif FORCE_CHANNEL_IN_STUDIO_FOR_TESTING and game:GetService("RunService"):IsStudio() then
	-- There is no reserved server behind this fake channel, so skip the registry lookup it would fail.
	ServerConfig.Mode, ServerConfig.Channel = "Studio", 0
else
	ServerConfig.Mode, ServerConfig.Channel = ChannelRegistry.IdentifySelf()
end

-- ไคลเอนต์อ่านสองบิตนี้จาก Workspace (PrivateServerId/PlaceId ฝั่งไคลเอนต์เชื่อไม่ได้) — IslandMode ต้องมาก่อน IsLobby
-- เพราะทุก LocalScript รอ IsLobby แล้วอ่าน IslandMode ทันที ถ้ากลับลำดับจะได้ nil ชั่วขณะ
workspace:SetAttribute("IslandMode", ServerConfig.IsFarm)
-- ArenaMode ต้องมาก่อน IsLobby ด้วยเหตุผลเดียวกับ IslandMode: ทุก LocalScript รอ IsLobby แล้วอ่านตัวอื่นทันที
workspace:SetAttribute("ArenaMode", ServerConfig.IsArena)
workspace:SetAttribute("IsLobby", ServerConfig.IsLobby)

-- Printed once, from the module every server script requires before anything else, so the first line in a
-- server's log says which build is running and which half of the game it is. Worth its own line now that
-- there are real players: a bug report that begins "it happened in the lobby on V1" is a different bug from
-- the same words about a channel server.
local GameVersion = require(game.ReplicatedStorage.GameVersion)
ServerConfig.Version = GameVersion.Number
print(("[WOLD] %s (%s) -- %s"):format(GameVersion.Label(), GameVersion.Number,
	ServerConfig.IsLobby and "ล็อบบี้" -- locale: skip (log เซิร์ฟ)
		or ServerConfig.IsArena and ("สนาม PVP " .. (ServerConfig.ArenaMatch and "(แมตช์)" or "(เซิร์ฟสาธารณะ)")) -- locale: skip (log เซิร์ฟ)
		or ("ช่อง " .. tostring(ServerConfig.Channel)))) -- locale: skip (log เซิร์ฟ)

return ServerConfig
