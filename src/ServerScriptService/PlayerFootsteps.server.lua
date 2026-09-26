-- PlayerFootsteps.server.lua: relays one player's footsteps to everyone else.
--
-- Each client times its own steps -- it knows its material and speed on the frame it needs them, with no
-- replication lag -- and reports them here. This forwards them so people can hear each other walking.
--
-- Deliberately not authoritative: a footstep is cosmetic, and validating "were you really going fast enough
-- to take a step there" would cost more than the lie is worth. What IS enforced is the rate, because an
-- unthrottled client could otherwise fire this hundreds of times a second and make every other client build
-- sound instances until it stuttered.
local Players = game:GetService("Players")
local ServerConfig = require(game.ServerScriptService.ServerConfig)
local SoundscapeConfig = require(game.ReplicatedStorage.SoundscapeConfig)
local Remotes = require(game.ReplicatedStorage.Remotes)

if ServerConfig.IsLobby then return end

-- Comfortably above a sprinting player's real step rate (one per 0.28s) with room for latency jitter, and
-- far below what it would take to cause trouble.
local MIN_STEP_INTERVAL = 0.15

local lastStep = {} -- [player] = os.clock() of the last accepted step

Remotes.Footstep.OnServerEvent:Connect(function(player, group)
	-- Only the group names the config actually defines: anything else would be a client inventing a key,
	-- and every listener would look it up and find nothing.
	if type(group) ~= "string" or not SoundscapeConfig.Footsteps[group] then return end

	local now = os.clock()
	if now - (lastStep[player] or 0) < MIN_STEP_INTERVAL then return end
	lastStep[player] = now

	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then return end

	-- Everyone except the author, who already played it locally the moment it happened -- and only those
	-- close enough to hear it. เดิมส่งถึงทุกคนในเซิร์ฟ แต่ได้ยินแค่ 45 สตัด: 30 คนวิ่งพร้อมกัน = มือถือทุกเครื่อง
	-- รับรีโมต + สร้าง Sound 100+ ครั้งต่อวินาทีเพื่อเสียงที่ไม่มีใครได้ยิน (QA 2026-09-26) · เผื่อระยะ 1.5 เท่า
	-- เพราะตำแหน่งฝั่งเซิร์ฟตามหลังจริงนิดหน่อย
	local reach = SoundscapeConfig.FootstepDistance * 1.5
	local here = root.Position
	for _, other in ipairs(Players:GetPlayers()) do
		if other ~= player then
			local otherCharacter = other.Character
			local otherRoot = otherCharacter and otherCharacter:FindFirstChild("HumanoidRootPart")
			if otherRoot and (otherRoot.Position - here).Magnitude <= reach then
				Remotes.Footstep:FireClient(other, player, group)
			end
		end
	end
end)

Players.PlayerRemoving:Connect(function(player)
	lastStep[player] = nil
end)
