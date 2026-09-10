-- TestChestController: draws each player's own countdown to the next daily chest.
--
-- The chest's BillboardGui is built on the server and is therefore ONE object shared by everybody -- writing
-- a timer into it would show one player's countdown to the whole server. This runs on the client and writes
-- only into that client's view, so every player sees their own.
--
-- The claim time arrives as the WOLD_ChestReadyAt attribute on the local player, set by TestChest.server.
-- Attributes replicate on their own and are already correct for a client that joins late, so there is no
-- remote to wait on and nothing to re-request after a respawn.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

while workspace:GetAttribute("IsLobby") == nil do
	task.wait()
end
if workspace:GetAttribute("IsLobby") then return end

local player = Players.LocalPlayer

local READY_TEXT = "เปิดหีบ"

-- Coarse on purpose: a chest on a 24-hour cooldown does not need a seconds display until the last minute,
-- and rewriting the prompt every second all day would be noise.
local function remainingText(seconds)
	if seconds <= 0 then return READY_TEXT end
	local hours = seconds // 3600
	local minutes = (seconds % 3600) // 60
	if hours > 0 then
		return ("เปิดได้อีก %d ชม. %d นาที"):format(hours, minutes)
	end
	if minutes > 0 then
		return ("เปิดได้อีก %d นาที"):format(minutes)
	end
	return ("เปิดได้อีก %d วินาที"):format(seconds)
end

-- The chest is built after the server has found the ground, so it may not exist yet when this starts.
local function findPrompt()
	local chest = workspace:FindFirstChild("WOLD_TestChest")
	if not chest then return nil end
	return chest:FindFirstChildWhichIsA("ProximityPrompt", true)
end

task.spawn(function()
	local prompt
	local lastText

	while true do
		if not prompt or not prompt.Parent then
			prompt = findPrompt()
			lastText = nil -- a rebuilt chest starts with the server's default text
		end

		if prompt then
			local readyAt = player:GetAttribute("WOLD_ChestReadyAt") or 0
			local left = math.max(0, math.floor(readyAt - os.time()))
			local text = remainingText(left)
			-- Only written when it actually changes: assigning ActionText every tick would fight the
			-- prompt's own UI for no visible gain.
			if text ~= lastText then
				prompt.ActionText = text
				lastText = text
			end
		end

		-- Once a second is finer than a day-long timer needs, and it costs nothing.
		task.wait(1)
	end
end)
