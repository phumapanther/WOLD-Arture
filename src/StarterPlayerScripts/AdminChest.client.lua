-- AdminChest.client.lua: the chest itself, standing near the spawn -- and standing there for admins only.
--
-- Built here rather than on the server because that is the only way "only admins can see it" is true. One
-- model in the workspace is one model for everybody; a model each client builds for itself is seen by
-- exactly that client. Nothing is given away by drawing it -- every item comes from AdminChest.server.lua,
-- which asks the roster on every request -- so the worst a non-admin could do by forging the attribute is
-- draw themselves a box that hands out nothing.
local Players = game:GetService("Players")

while workspace:GetAttribute("IsLobby") == nil do
	task.wait()
end
if workspace:GetAttribute("IsLobby") then return end

local AdminChestGui = require(game.ReplicatedStorage.UI.AdminChestGui)
local Remotes = require(game.ReplicatedStorage.Remotes)

local player = Players.LocalPlayer
local chest = nil

--------------------------------------------------------------------------------
-- Where it stands
--------------------------------------------------------------------------------

-- Beside the spawn, on whatever ground is actually there. Raycast rather than a fixed Y: the terrain moves
-- between builds, and a chest at a remembered height ends up buried or hovering.
local function spawnPosition()
	local spawnLocation = workspace:FindFirstChildWhichIsA("SpawnLocation", true)
	local base = spawnLocation and spawnLocation.Position or Vector3.new(0, 100, 0)

	-- Well clear of the gazebo, which is 26 studs across: 10 studs puts the chest inside it among the
	-- columns. 30 stands it out on the open plaza where it can be seen and walked up to.
	local beside = base + Vector3.new(30, 0, 0)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { player.Character or workspace }
	-- Starts well ABOVE the ground and travels down through it: terrain counts as a hit, and a ray starting
	-- at pad height buried the old chest three studs.
	local hit = workspace:Raycast(beside + Vector3.new(0, 400, 0), Vector3.new(0, -1200, 0), params)
	-- Lifted clear of the terrain, not laid flush on it: Roblox grass decoration stands about 3 studs proud
	-- of the surface, and a chest whose base sits exactly at the hit is buried to the lid in it.
	return Vector3.new(beside.X, (hit and hit.Position.Y or base.Y) + 1.5, beside.Z)
end

local function buildChest(position)
	local model = Instance.new("Model")
	model.Name = "WOLD_AdminChest"

	local function part(name, size, offset, colour, material)
		local p = Instance.new("Part")
		p.Name = name
		p.Size = size
		p.CFrame = CFrame.new(position + offset)
		p.Color = colour
		p.Material = material or Enum.Material.Wood
		p.Anchored = true
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.Parent = model
		return p
	end

	local body = part("Body", Vector3.new(4, 2.4, 2.6), Vector3.new(0, 1.2, 0), Color3.fromRGB(70, 58, 92))
	model.PrimaryPart = body

	-- A rounded lid, so it reads as a chest rather than a crate.
	local lid = part("Lid", Vector3.new(4.1, 1.2, 2.7), Vector3.new(0, 2.7, 0), Color3.fromRGB(86, 72, 112))
	lid.Shape = Enum.PartType.Cylinder
	lid.Orientation = Vector3.new(0, 90, 90)

	part("Band", Vector3.new(4.2, 0.3, 2.8), Vector3.new(0, 1.9, 0), Color3.fromRGB(196, 160, 96),
		Enum.Material.Metal)

	local sign = Instance.new("BillboardGui")
	sign.Size = UDim2.fromOffset(200, 40)
	sign.StudsOffsetWorldSpace = Vector3.new(0, 3.6, 0)
	sign.MaxDistance = 60
	sign.Parent = body
	local text = Instance.new("TextLabel")
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundTransparency = 1
	text.Font = Enum.Font.GothamBold
	text.TextSize = 14
	text.TextColor3 = Color3.fromRGB(214, 186, 255)
	text.TextStrokeTransparency = 0.4
	text.Text = "หีบแอดมิน"
	text.Parent = sign

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "OpenPrompt"
	prompt.ActionText = "เปิดหีบ"
	prompt.ObjectText = "หีบแอดมิน"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.MaxActivationDistance = 10
	-- A tap, not a hold. The old chest held for six tenths of a second because a press spent the day's
	-- claim; there is nothing to spend now, so making the admin wait buys nothing.
	prompt.HoldDuration = 0
	prompt.RequiresLineOfSight = false
	prompt.Parent = body

	-- Parented to the camera, not the workspace: nothing a client puts in the workspace replicates, but the
	-- camera is the conventional home for client-only scenery and it is cleared on a place change by itself.
	model.Parent = workspace.CurrentCamera
	return model, prompt
end

--------------------------------------------------------------------------------

local gui = AdminChestGui.new()
gui:On("take", function(itemId, count)
	Remotes.RequestAdminItem:FireServer(itemId, count)
end)
gui:On("gold", function(amount)
	Remotes.RequestAdminGold:FireServer(amount)
end)

local function show()
	if chest then return end
	-- Waits for somewhere to put it. FirstTown replaces the temporary pad with its own spawn, so looking for
	-- a SpawnLocation rather than for a name survives that swap.
	for _ = 1, 40 do
		if workspace:FindFirstChildWhichIsA("SpawnLocation", true) then break end
		task.wait(0.25)
	end
	local model, prompt = buildChest(spawnPosition())
	chest = model
	prompt.Triggered:Connect(function()
		gui:Show()
	end)
end

local function hide()
	if not chest then return end
	chest:Destroy()
	chest = nil
	gui:Hide()
end

-- Built when the attribute says so, and taken away again if it is ever revoked mid-session -- /unadmin
-- should not leave a chest standing in front of someone who can no longer use it.
local function refresh()
	if player:GetAttribute("WOLD_Admin") == true then
		task.spawn(show)
	else
		hide()
	end
end

player:GetAttributeChangedSignal("WOLD_Admin"):Connect(refresh)
refresh()
