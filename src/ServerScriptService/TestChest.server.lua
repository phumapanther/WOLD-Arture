-- TestChest.server.lua: a chest near the spawn that hands out one of everything, once a day.
--
-- This exists for testing, not as a designed reward: it is the fastest way to get a full kit in front of a
-- playtester without an admin command. Delete it, or set TestChestConfig.Enabled to false, before release.
--
-- Contents are DERIVED from the catalog rather than listed here, so a weapon added tomorrow is in the chest
-- tomorrow without anyone remembering to update a list.
local Players = game:GetService("Players")
local ServerConfig = require(game.ServerScriptService.ServerConfig)

if ServerConfig.IsLobby then return end

local ItemCatalog = require(game.ReplicatedStorage.ItemCatalog)
local Inventory = require(game.ServerScriptService.Inventory)
local ProfileAccess = require(game.ServerScriptService.ProfileAccess)
local Remotes = require(game.ReplicatedStorage.Remotes)

local COOLDOWN_SECONDS = 24 * 60 * 60 -- once a day, per player

-- Everything the chest gives: EVERY item in the catalog, which is what a test chest is for. Weapons and
-- armor come one at a time because they do not stack; anything that stacks arrives as a full stack.
--
-- Written as "every kind except the exceptions" rather than a list of wanted kinds, so an item kind invented
-- next month is in the chest the day it exists instead of being silently left out -- which is exactly how
-- the tools and the gathering materials went missing from it before.
local SKIP_KINDS = {
	-- A key without a plate opens nothing: keys are issued by the vehicle system with a registration in
	-- their meta, and a blank one from here would just be dead weight in the bag.
	key = true,
}

local function contents()
	local out = {}
	for id, item in pairs(ItemCatalog.Items) do
		if not SKIP_KINDS[item.kind] then
			local stack = ItemCatalog.StackSize(id)
			table.insert(out, { id = id, count = stack > 1 and stack or 1 })
		end
	end
	-- Sorted so the chest hands things out in a stable order rather than a random one each server.
	table.sort(out, function(a, b) return a.id < b.id end)
	return out
end

--------------------------------------------------------------------------------
-- The chest itself
--------------------------------------------------------------------------------

local function buildChest(position)
	local model = Instance.new("Model")
	model.Name = "WOLD_TestChest"

	local function part(name, size, offset, color, material)
		local p = Instance.new("Part")
		p.Name = name
		p.Size = size
		p.CFrame = CFrame.new(position + offset)
		p.Color = color
		p.Material = material or Enum.Material.Wood
		p.Anchored = true
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.Parent = model
		return p
	end

	local body = part("Body", Vector3.new(4, 2.4, 2.6), Vector3.new(0, 1.2, 0),
		Color3.fromRGB(96, 64, 38))
	model.PrimaryPart = body

	-- A rounded lid, so it reads as a chest rather than a crate.
	local lid = part("Lid", Vector3.new(4.1, 1.2, 2.7), Vector3.new(0, 2.7, 0),
		Color3.fromRGB(112, 76, 44))
	lid.Shape = Enum.PartType.Cylinder
	lid.Orientation = Vector3.new(0, 0, 90)
	lid.Size = Vector3.new(2.7, 4.1, 2.7)

	part("BandLeft", Vector3.new(0.4, 2.6, 2.8), Vector3.new(-1.2, 1.2, 0),
		Color3.fromRGB(78, 74, 70), Enum.Material.Metal)
	part("BandRight", Vector3.new(0.4, 2.6, 2.8), Vector3.new(1.2, 1.2, 0),
		Color3.fromRGB(78, 74, 70), Enum.Material.Metal)
	local lock = part("Lock", Vector3.new(0.5, 0.6, 0.4), Vector3.new(0, 2.1, 1.4),
		Color3.fromRGB(198, 158, 78), Enum.Material.Metal)
	lock.Material = Enum.Material.Metal

	-- A light so it is findable at night, which is when a tester is most likely to be looking for it.
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 210, 140)
	light.Range = 14
	light.Brightness = 1.2
	light.Parent = body

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "OpenPrompt"
	prompt.ActionText = "เปิดหีบ"
	prompt.ObjectText = "หีบทดสอบ"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.MaxActivationDistance = 10
	-- A short hold rather than a tap: opening a chest that hands out a full kit should take a deliberate
	-- moment, and it stops a stray E while walking past from burning the daily claim.
	prompt.HoldDuration = 0.6
	prompt.RequiresLineOfSight = false
	prompt.Parent = body

	local sign = Instance.new("BillboardGui")
	sign.Size = UDim2.fromOffset(180, 40)
	sign.StudsOffsetWorldSpace = Vector3.new(0, 3.6, 0)
	sign.MaxDistance = 60
	sign.Parent = body
	local text = Instance.new("TextLabel")
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundTransparency = 1
	text.Font = Enum.Font.GothamBold
	text.TextSize = 14
	text.TextColor3 = Color3.fromRGB(255, 226, 170)
	text.TextStrokeTransparency = 0.4
	text.Text = "หีบทดสอบ (วันละครั้ง)"
	text.Parent = sign

	model.Parent = workspace
	return model, prompt
end

--------------------------------------------------------------------------------
-- Placement
--------------------------------------------------------------------------------

-- Beside the spawn, on whatever ground is actually there. Raycasting rather than trusting a fixed Y is what
-- keeps it from floating or being buried when the terrain changes.
local function spawnPosition()
	local root = workspace:FindFirstChild("WOLD")
	local temp = root and root:FindFirstChild("TempSpawn")
	-- TempSpawn is a FOLDER, not a Model, so PrimaryPart is not even a valid member of it (it throws rather
	-- than returning nil). Find a part inside it instead, whatever shape the pad happens to be.
	local base
	if temp then
		if temp:IsA("BasePart") then
			base = temp.Position
		else
			local anyPart = temp:FindFirstChildWhichIsA("BasePart", true)
			base = anyPart and anyPart.Position
		end
	end
	if not base then
		local spawnLocation = workspace:FindFirstChildWhichIsA("SpawnLocation", true)
		base = spawnLocation and spawnLocation.Position or Vector3.new(0, 100, 0)
	end

	local beside = base + Vector3.new(10, 0, 0)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	-- Exclude any chest already standing here. On the first run there is none, and a stale lookup that
	-- returns nil filters nothing -- which is how a re-run measured the ground as its own lid (y=50.1).
	local existingChest = workspace:FindFirstChild("WOLD_TestChest")
	params.FilterDescendantsInstances = existingChest and { existingChest } or {}
	-- Terrain counts as a hit, so the ray has to start well ABOVE the ground and travel down through it.
	-- Starting from the pad height alone buried the chest 3 studs (measured: chest y=47.3, ground y=50.2).
	local hit = workspace:Raycast(beside + Vector3.new(0, 400, 0), Vector3.new(0, -1200, 0), params)
	-- The model is built around this point with the body 1.2 studs up and 2.4 tall, so sitting the origin
	-- ON the ground puts the chest on the ground rather than half inside it.
	local groundY = hit and hit.Position.Y or base.Y
	return Vector3.new(beside.X, groundY, beside.Z)
end

--------------------------------------------------------------------------------

task.spawn(function()
	-- The spawn pad is built by another script, so wait for it rather than racing it.
	for _ = 1, 40 do
		local root = workspace:FindFirstChild("WOLD")
		if root and root:FindFirstChild("TempSpawn") then break end
		task.wait(0.25)
	end

	local _, prompt = buildChest(spawnPosition())

	-- Each player's next-claim time, published as an attribute rather than pushed down a remote: attributes
	-- replicate on their own and are already correct for a client that joins later, which is exactly what a
	-- countdown needs. The BillboardGui above cannot show this -- it is one object shared by everyone, so it
	-- would show one player's timer to the whole server. The client draws its own from this.
	local function publishClaim(player)
		local data = ProfileAccess.Get(player)
		if not data then return end
		player:SetAttribute("WOLD_ChestReadyAt", (data.TestChestAt or 0) + COOLDOWN_SECONDS)
	end

	for _, player in ipairs(Players:GetPlayers()) do
		task.spawn(publishClaim, player)
	end
	Players.PlayerAdded:Connect(function(player)
		-- The profile arrives after the player does, so wait for it rather than publishing a zero.
		task.spawn(function()
			for _ = 1, 300 do
				if ProfileAccess.Get(player) then break end
				if not player.Parent then return end
				task.wait(0.1)
			end
			publishClaim(player)
		end)
	end)

	prompt.Triggered:Connect(function(player)
		local data = ProfileAccess.Get(player)
		if not data then
			Remotes.SocialNotify:FireClient(player, "error", "ยังโหลดข้อมูลไม่เสร็จ")
			return
		end

		-- os.time is the server's clock, and the claim is stored in the profile, so this survives a rejoin
		-- and cannot be reset by leaving. A player who waits out the day gets another.
		local last = data.TestChestAt or 0
		local now = os.time()
		local waited = now - last
		if waited < COOLDOWN_SECONDS then
			local left = COOLDOWN_SECONDS - waited
			Remotes.SocialNotify:FireClient(player, "error",
				("เปิดได้อีกครั้งใน %d ชั่วโมง %d นาที"):format(left // 3600, (left % 3600) // 60))
			return
		end

		local given, full = 0, false
		for _, entry in ipairs(contents()) do
			if Inventory.AddItem(player, entry.id, entry.count) then
				given += 1
			else
				full = true
			end
		end

		-- Only charge the daily claim if something was actually received; a full bag should not burn it.
		if given > 0 then
			data.TestChestAt = now
			if ProfileAccess.Flush then ProfileAccess.Flush(player) end
			publishClaim(player)
		end

		Remotes.SocialNotify:FireClient(player, given > 0 and "info" or "error",
			given == 0 and "กระเป๋าเต็ม เปิดหีบไม่ได้"
			or full and ("ได้รับของ %d อย่าง (กระเป๋าเต็มก่อนครบ)"):format(given)
			or ("ได้รับของครบ %d อย่าง"):format(given))
	end)
end)
