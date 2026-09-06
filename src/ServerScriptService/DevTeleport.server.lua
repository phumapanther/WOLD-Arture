-- DevTeleport (development only, remove before release): chat "/tp <name>" teleports you to any Zone_* / RespawnPoint / SpawnLocation
-- under workspace.WOLD, matched case-insensitively by prefix. "/tp list" prints the names. Example: /tp stonemark, /tp crystal, /tp sea, /tp brass
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")

local function targets()
	local out = {}
	local root = workspace:FindFirstChild("WOLD")
	if not root then return out end
	for _, z in ipairs(CollectionService:GetTagged("Zone")) do
		if z:IsDescendantOf(root) then out[#out + 1] = { name = z:GetAttribute("ZoneName") or z.Name, pos = z.Position - Vector3.new(0, z.Size.X / 2, 0) } end   -- zone is a vertical cylinder rolled 90°: X = height
	end
	for _, p in ipairs(CollectionService:GetTagged("RespawnPoint")) do
		if p:IsDescendantOf(root) then out[#out + 1] = { name = "spawn " .. (p:GetAttribute("Place") or p.Name), pos = p.Position } end
	end
	for _, d in ipairs(root:GetDescendants()) do
		if d:IsA("SpawnLocation") then out[#out + 1] = { name = d.Name, pos = d.Position } end
	end
	return out
end

local function groundY(x, z, fallback)
	local ray = workspace:Raycast(Vector3.new(x, 4000, z), Vector3.new(0, -8000, 0))
	return ray and ray.Position.Y or fallback
end

Players.PlayerAdded:Connect(function(player)
	player.Chatted:Connect(function(msg)
		local arg = msg:match("^/tp%s+(.+)$")
		if not arg then return end
		arg = arg:lower()
		local list = targets()
		if arg == "list" then
			local names = {}
			for _, t in ipairs(list) do names[#names + 1] = t.name end
			print("[DevTeleport] targets: " .. table.concat(names, ", "))
			return
		end
		for _, t in ipairs(list) do
			if t.name:lower():sub(1, #arg) == arg or t.name:lower():find(arg, 1, true) then
				local char = player.Character
				local hrp = char and char:FindFirstChild("HumanoidRootPart")
				if hrp then
					local y = groundY(t.pos.X, t.pos.Z, t.pos.Y) + 5
					hrp.CFrame = CFrame.new(t.pos.X, y, t.pos.Z)
					print(("[DevTeleport] %s -> %s"):format(player.Name, t.name))
				end
				return
			end
		end
		print("[DevTeleport] no target matches '" .. arg .. "' (try /tp list)")
	end)
end)
