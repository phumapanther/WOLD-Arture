-- LobbyRank.server: แร็งก์ PVP ในล็อบบี้ (เฟส 3 · roadmap) — ฉลองเลื่อนขั้น + ข้อมูลแร็งก์ให้หน้าปาร์ตี้ PVP
--
-- กลับจากแมตช์ถึงล็อบบี้ → **อ่านซ้ำเป็นรอบ** (เซิร์ฟสนามอาจเขียนแต้มเสร็จหลังคนถึงล็อบบี้แล้ว — กฎเหล็กลูปถามใหม่):
-- 4 วิ/ครั้งใน 60 วิแรก แล้ว 30 วิ/ครั้ง · ขั้นตอนนี้ > ขั้นที่ฉลองแล้ว = ยิงฉลอง (เห็นคนเดียว) → ไคลเอนต์ตอบ "เห็นแล้ว"
-- → จด `seen` · ตกขั้น (แพ้ต่ำกว่าเส้น/จบซีซันลด 2 ขั้น) ไม่มีเอฟเฟกต์ แค่บรรทัดเล็กในหน้าปาร์ตี้ (`last`)
local Players = game:GetService("Players")

local ServerConfig = require(game.ServerScriptService.ServerConfig)
if not ServerConfig.IsLobby then return end

local PvpRankStore = require(game.ServerScriptService.PvpRankStore)
local PvpRankConfig = require(game.ReplicatedStorage.PvpRankConfig)
local Remotes = require(game.ReplicatedStorage.Remotes)

local Pending = {} -- [player] = ขั้นที่กำลังฉลอง (รอไคลเอนต์ตอบ)
local LastInfo = {} -- [player] = คีย์ของข้อมูลที่ส่งไปล่าสุด (ส่งเฉพาะตอนเปลี่ยน)

local function check(player)
	local r = PvpRankStore.Read(player.UserId)
	if not r or not player.Parent then return end
	local tier = PvpRankConfig.TierIndex(r.p)
	local season = PvpRankConfig.Season(os.time())
	local info = {
		played = r.played == true, tier = tier, points = r.p, next = PvpRankConfig.NextMin(r.p),
		season = season, endsAt = PvpRankConfig.SeasonEnds(season), last = r.last,
	}
	local key = ("%s:%d:%d:%s"):format(tostring(info.played), tier, r.p, tostring(r.last and r.last.at))
	if LastInfo[player] ~= key then
		LastInfo[player] = key
		Remotes.PvpRankInfo:FireClient(player, info)
	end
	if r.played and tier > (r.seen or 1) and Pending[player] == nil then
		Pending[player] = tier
		Remotes.PvpRankUp:FireClient(player, { from = r.seen or 1, to = tier, points = r.p })
	end
end

Players.PlayerAdded:Connect(function(player)
	local started = os.clock()
	task.spawn(function()
		while player.Parent do
			pcall(check, player)
			task.wait(os.clock() - started < 60 and 4 or 30)
		end
	end)
end)

Remotes.PvpRankSeen.OnServerEvent:Connect(function(player)
	local tier = Pending[player]
	if not tier then return end
	Pending[player] = nil
	task.spawn(PvpRankStore.MarkSeen, player.UserId, tier)
end)

Players.PlayerRemoving:Connect(function(player)
	Pending[player] = nil
	LastInfo[player] = nil
end)
