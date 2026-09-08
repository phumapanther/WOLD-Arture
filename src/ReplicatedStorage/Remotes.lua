-- Remotes.lua: idempotent RemoteEvent/RemoteFunction bootstrap. The server creates them; the client waits for them.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local EVENTS = {
	"JoinChannel", "ChannelList", "JoinFailed", "RequestReturnToLobby", "RequestChannelRefresh",
	"SetSprintIntent", "ToggleWalk", -- movement (client intent in; stamina goes out via VitalsUpdate)
	"RequestAttack", "CombatStateChanged", -- combat (click intent in, guard/attack playback out)
	"VitalsUpdate", "DownedStateChanged", "RequestRespawn", -- vitals (hp/hunger/stamina/armor out, downed UI, respawn in)
	"RequestRoll", "RequestSlide", "MoveStateChanged", -- roll/slide (client intent in, animation playback out)
	"RequestRevive", "RequestCarry", "RequestDrop", "CarryStateChanged", -- reviving and carrying a downed player
	"ProgressionUpdate", "LevelUp", -- exp/level out, plus a one-shot for the level-up effect
}
local FUNCTIONS = { "GetSpawnPosition" } -- DataStore-backed lookups can only run server-side; the client must ask

local folder = ReplicatedStorage:FindFirstChild("Remotes")
if RunService:IsServer() then
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "Remotes"
		folder.Parent = ReplicatedStorage
	end
	for _, name in ipairs(EVENTS) do
		if not folder:FindFirstChild(name) then
			local event = Instance.new("RemoteEvent")
			event.Name = name
			event.Parent = folder
		end
	end
	for _, name in ipairs(FUNCTIONS) do
		if not folder:FindFirstChild(name) then
			local fn = Instance.new("RemoteFunction")
			fn.Name = name
			fn.Parent = folder
		end
	end
else
	folder = folder or ReplicatedStorage:WaitForChild("Remotes")
end

local Remotes = {}
for _, name in ipairs(EVENTS) do
	Remotes[name] = folder:WaitForChild(name)
end
for _, name in ipairs(FUNCTIONS) do
	Remotes[name] = folder:WaitForChild(name)
end
return Remotes
