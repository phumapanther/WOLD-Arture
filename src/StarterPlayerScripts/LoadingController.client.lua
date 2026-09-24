-- LoadingController: runs the weighted loading-step list and reveals the world when done.
-- game.PrivateServerId cannot be read from the client at all ("PrivateServerId cannot be checked on the client")
-- — ServerConfig.lua replicates IsLobby via a Workspace Attribute instead. It's always true in Studio Play
-- (Play is always the lobby), so this never shows locally unless you flip the flag below.
local FORCE_SHOW_IN_STUDIO_FOR_TESTING = false -- ponytail: flip to true to preview this screen in Play; flip back before publishing

while workspace:GetAttribute("IsLobby") == nil do
	task.wait()
end
if workspace:GetAttribute("IsLobby") and not FORCE_SHOW_IN_STUDIO_FOR_TESTING then return end
-- สนาม PVP ไม่ใช้จอโหลดนี้ (ผู้ใช้แจ้ง 2026-09-24: "เกมเริ่มแล้วแต่จอมีแต่รูปโหลดค้าง 43%")
-- ขั้น streaming ถาม `GetSpawnPosition` ซึ่งไม่มีใครตอบในสนาม (ArenaMatch วางจุดเกิดเอง) → InvokeServer
-- รอตลอดไป · และคนที่มาสายกลางรอบไม่มีร่าง ขั้น character ก็รอตลอดไปเหมือนกัน
if workspace:GetAttribute("ArenaMode") == true then return end

local Players = game:GetService("Players")
local ContentProvider = game:GetService("ContentProvider")
local LoadingGui = require(game.ReplicatedStorage.UI.LoadingGui)
local Remotes = require(game.ReplicatedStorage.Remotes)

local player = Players.LocalPlayer
local gui = LoadingGui.new()
gui.gui.Parent = player:WaitForChild("PlayerGui")
gui:Show()

local STEPS = {
	{
		name = "character",
		weight = 1,
		run = function()
			if not player.Character then
				player.CharacterAdded:Wait()
			end
			player.Character:WaitForChild("HumanoidRootPart")
		end,
	},
	{
		name = "preload",
		weight = 2,
		run = function()
			local assets = {} -- later sub-projects append animation/model asset ids here; empty list preloads instantly
			if #assets > 0 then
				ContentProvider:PreloadAsync(assets)
			end
		end,
	},
	{
		name = "streaming",
		weight = 3,
		run = function()
			local hrp = player.Character:WaitForChild("HumanoidRootPart")
			local target = Remotes.GetSpawnPosition:InvokeServer()
			hrp.CFrame = CFrame.new(target)
			local deadline = os.clock() + 10
			while os.clock() < deadline do
				local ray = workspace:Raycast(target + Vector3.new(0, 200, 0), Vector3.new(0, -400, 0))
				if ray then break end
				task.wait(0.25)
			end
		end,
	},
	{
		name = "playerdata",
		weight = 1,
		run = function() end, -- stub; sub-project 1 replaces this with "wait for the profile to load"
	},
}

local totalWeight = 0
for _, step in ipairs(STEPS) do
	totalWeight += step.weight
end

local startTime = os.clock()
local done = 0
for _, step in ipairs(STEPS) do
	local ok, err = pcall(step.run)
	if not ok then
		warn("[Loading] step failed:", step.name, err)
	end
	done += step.weight
	gui:SetProgress(done / totalWeight)
end

local elapsed = os.clock() - startTime
if elapsed < 1 then
	task.wait(1 - elapsed)
end
gui:Destroy()
