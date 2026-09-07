-- Remotes.lua: idempotent RemoteEvent/RemoteFunction bootstrap. The server creates them; the client waits for them.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local EVENTS = { "JoinChannel", "ChannelList", "JoinFailed", "RequestReturnToLobby" }
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
