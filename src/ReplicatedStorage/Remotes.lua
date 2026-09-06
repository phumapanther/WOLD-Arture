-- Remotes.lua: idempotent RemoteEvent bootstrap. The server creates them; the client waits for them.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local NAMES = { "JoinChannel", "ChannelList", "JoinFailed" }

local folder = ReplicatedStorage:FindFirstChild("Remotes")
if RunService:IsServer() then
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "Remotes"
		folder.Parent = ReplicatedStorage
	end
	for _, name in ipairs(NAMES) do
		if not folder:FindFirstChild(name) then
			local event = Instance.new("RemoteEvent")
			event.Name = name
			event.Parent = folder
		end
	end
else
	folder = folder or ReplicatedStorage:WaitForChild("Remotes")
end

local Remotes = {}
for _, name in ipairs(NAMES) do
	Remotes[name] = folder:WaitForChild(name)
end
return Remotes
