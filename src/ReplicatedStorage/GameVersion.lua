-- GameVersion: which build of WOLD Arture this is.
--
-- Exists because the game is about to be open to real players, and the first thing a bug report needs is
-- "which version were you on". A server prints it at boot and every screen carries it in the corner, so the
-- answer is on the screenshot rather than in someone's memory.
--
-- In ReplicatedStorage rather than ServerScriptService so the client can read it too -- the corner label is
-- drawn locally, and asking the server for a constant would be a remote call for a string that never changes.
local GameVersion = {}

-- Bump this, and nothing else, when cutting a release. The git tag (`rolplayV_1`) and this string are the
-- same fact recorded in two places; they have to be changed together.
GameVersion.Number = "1.0"
GameVersion.Name = "V1"
GameVersion.Released = "2026-09-12"

-- What went in, shortest form, for the changelog line a player might be shown later. Newest first.
GameVersion.Highlights = {
	"ธนาคารและคลังสินค้า · หน้าคราฟคนดวงซวย · ของสายผิดกฎหมาย 6 ชนิด",
	"ฟาร์มผิดกฎหมาย 3 จุด พร้อมมินิเกมกดตามจังหวะ",
	"อีเวนต์สไลม์กลายพันธุ์ และอีเวนต์เครื่องยนต์ไอน้ำขัดข้อง",
	"พาหนะไอน้ำ: รถ เรือ เรือเหาะ พร้อมกุญแจ ทะเบียน และท้ายพาหนะ",
}

function GameVersion.Label()
	return ("WOLD Arture %s"):format(GameVersion.Name)
end

return GameVersion
