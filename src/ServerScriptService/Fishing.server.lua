-- Fishing.server.lua: cast a line into any water and let it fish itself.
--
-- Equip the rod, stand near water, click once. The swing animation plays, the line goes out, and from then
-- on a catch lands every twenty to thirty seconds until the worms run out or the player walks away. A card
-- over their head says they are fishing, so it reads to everyone else as an activity rather than idling.
--
-- Everything that matters is decided here. The client asks to cast and is told whether it worked; it never
-- says what was caught, how long it took, or how many worms are left.
local Players = game:GetService("Players")
local Debris = game:GetService("Debris")
local ServerConfig = require(game.ServerScriptService.ServerConfig)

if ServerConfig.IsLobby then return end

local FishingConfig = require(game.ReplicatedStorage.FishingConfig)
local Collection = require(game.ServerScriptService.Collection)
local ItemCatalog = require(game.ReplicatedStorage.ItemCatalog)
local Inventory = require(game.ServerScriptService.Inventory)
local Vitals = require(game.ServerScriptService.Vitals)
local FishingAccess = require(game.ServerScriptService.FishingAccess)
local Remotes = require(game.ReplicatedStorage.Remotes)
local PlayerJoin = require(game.ServerScriptService.PlayerJoin)

-- [player] = { anchor = Vector3 where they cast from, thread }
local Sessions = {}

--------------------------------------------------------------------------------
-- Is there water in front of them?
--------------------------------------------------------------------------------

-- Looks ahead of the player and down. Terrain water is the only thing that counts -- a Part painted blue
-- is scenery, and letting it fish would make every decorative pond in a model a fishing spot.
--
-- IgnoreWater must be FALSE or the ray passes straight through the thing being looked for, which is the
-- single easiest way to get this wrong.
local function waterAhead(character)
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then return false end

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character }
	params.IgnoreWater = false

	-- Several points along the look direction rather than one: a single ray at a fixed distance misses
	-- water the player is standing right at the edge of, and misses it again if they are a little far back.
	local forward = root.CFrame.LookVector
	for _, distance in ipairs({ 4, 8, 12, FishingConfig.CastDistance }) do
		local origin = root.Position + forward * distance + Vector3.new(0, 3, 0)
		local hit = workspace:Raycast(origin, Vector3.new(0, -FishingConfig.CastDepth, 0), params)
		if hit and hit.Material == Enum.Material.Water then
			return true, hit.Position
		end
	end
	return false
end

--------------------------------------------------------------------------------
-- The card over their head
--------------------------------------------------------------------------------

-- A fish icon on a billboard, so everyone nearby can see who is fishing. Built on the server because it is
-- for other people to see as much as for the player themselves.
local function showCard(player, on)
	local character = player.Character
	local head = character and character:FindFirstChild("Head")
	if not head then return end

	local existing = head:FindFirstChild("FishingCard")
	if not on then
		if existing then existing:Destroy() end
		return
	end
	if existing then return end

	local gui = Instance.new("BillboardGui")
	gui.Name = "FishingCard"
	gui.Size = UDim2.fromOffset(46, 46)
	gui.StudsOffsetWorldSpace = Vector3.new(0, 2.6, 0)
	gui.MaxDistance = 90
	gui.AlwaysOnTop = false
	gui.Parent = head

	local back = Instance.new("Frame")
	back.Size = UDim2.fromScale(1, 1)
	back.BackgroundColor3 = Color3.fromRGB(26, 28, 34)
	back.BackgroundTransparency = 0.25
	back.BorderSizePixel = 0
	back.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = back
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(244, 197, 66)
	stroke.Transparency = 0.4
	stroke.Parent = back

	local icon = Instance.new("ImageLabel")
	icon.Size = UDim2.fromScale(0.72, 0.72)
	icon.Position = UDim2.fromScale(0.14, 0.14)
	icon.BackgroundTransparency = 1
	icon.Image = ItemCatalog.Get("Fish").icon
	icon.Parent = back
end

-- Swaps the card's icon to whatever was just caught and puts its name under it, then goes back to the
-- plain fish after a moment. Shown over the head rather than only in a toast so the people around you can
-- see you landed something -- which is most of the point of fishing where others can see.
--
-- `kg` colours the card through the tier ladder, so how big a catch was is something the people around you
-- read at a glance from across the bank rather than something only the angler is told.
local function showCatch(player, itemId, kg)
	local character = player.Character
	local head = character and character:FindFirstChild("Head")
	local card = head and head:FindFirstChild("FishingCard")
	if not card then return end
	local back = card:FindFirstChildWhichIsA("Frame")
	local icon = back and back:FindFirstChildWhichIsA("ImageLabel")
	if not icon then return end

	local item = ItemCatalog.Get(itemId)
	if not item then return end

	icon.Image = item.icon
	card.Size = UDim2.fromOffset(74, 74)

	local tier = kg and FishingConfig.TierFor(kg) or nil
	-- The stroke as well as the text, because the outline is the part that reads from a distance: at ninety
	-- studs the label is a smudge but the glowing edge of the card is still plainly purple.
	local stroke = back:FindFirstChildWhichIsA("UIStroke")
	if stroke and tier then
		stroke.Color = tier.color
		-- A heavy catch glows rather than merely being tinted. The plain tier keeps the card's usual
		-- half-faded edge so an ordinary fish does not announce itself.
		stroke.Transparency = (tier.from > 0) and 0 or 0.4
		stroke.Thickness = (tier.from > 0) and 2 or 1
	end

	local name = back:FindFirstChild("CatchName")
	if not name then
		name = Instance.new("TextLabel")
		name.Name = "CatchName"
		name.AnchorPoint = Vector2.new(0.5, 0)
		name.Position = UDim2.new(0.5, 0, 1, 2)
		-- Tall enough for two lines and wrapping on, because the heavy tiers add a word under the name.
		name.Size = UDim2.fromOffset(130, 34)
		name.BackgroundTransparency = 1
		name.Font = Enum.Font.GothamBold
		name.TextSize = 13
		name.TextColor3 = Color3.fromRGB(255, 226, 170)
		name.TextWrapped = true
		name.TextYAlignment = Enum.TextYAlignment.Top
		name.TextStrokeTransparency = 0.4
		name.Parent = back
	end
	-- The kilograms go on the card itself. A tier that has a word for itself ("ตำนาน") says it too, because
	-- a number alone does not tell a new player that 44 kg was remarkable.
	if kg then
		name.Text = (tier.name ~= "")
			and ("%s %.1f กก.\n%s"):format(item.name, kg, tier.name)
			or ("%s %.1f กก."):format(item.name, kg)
		name.TextColor3 = tier.color
	else
		name.Text = item.name
	end

	task.delay(3, function()
		if not card.Parent then return end
		icon.Image = ItemCatalog.Get("Fish").icon
		card.Size = UDim2.fromOffset(46, 46)
		if name.Parent then name.Text = "" end
		-- Put the edge back to the fishing card's resting look, or the colour of one lucky catch would stay
		-- on the card for the rest of the session.
		if stroke and stroke.Parent then
			stroke.Color = Color3.fromRGB(244, 197, 66)
			stroke.Transparency = 0.4
			stroke.Thickness = 1
		end
	end)
end

-- The rod twitches as something takes the line. Cosmetic, and short: a nudge, not a performance.
local function twitchRod(player)
	local character = player.Character
	local held = character and character:FindFirstChild("EquippedWeapon")
	local root = held and held.PrimaryPart
	if not root then return end
	local motor = character:FindFirstChild("RightHand")
	motor = motor and motor:FindFirstChild("WeaponGrip")
	if not motor then return end

	-- Nudged through the joint rather than by moving the model: the model is welded to the joint, so
	-- moving it directly would be undone on the next frame.
	local base = motor.C0
	task.spawn(function()
		for _, angle in ipairs({ 14, -8, 5, 0 }) do
			if not motor.Parent then return end
			motor.C0 = base * CFrame.Angles(math.rad(angle), 0, 0)
			task.wait(0.08)
		end
		if motor.Parent then motor.C0 = base end
	end)
end

--------------------------------------------------------------------------------
-- The catch
--------------------------------------------------------------------------------

-- One weighted roll. Nine lines, which is why no library is involved.
--
-- **ตารางขึ้นกับว่าตกที่ไหน** ปลาประจำถิ่นถูกต่อท้ายตารางปกติเมื่ออยู่ในเขตหมู่บ้าน จึงแข่งกับปลาธรรมดา
-- โดยตรง — นอกเขตได้ปลาธรรมดาเหมือนเดิมทุกประการ ซึ่งเป็นเหตุผลที่ต้องเดินทางไปตกที่อื่น
--
-- คืนทั้งชนิดปลาและเขต เพื่อให้ผู้เรียกบอกผู้เล่นได้ว่านี่คือปลาประจำถิ่น
local function rollLoot(position)
	local loot, zone = FishingConfig.Loot, nil
	if position then
		loot, zone = FishingConfig.LootAt(position)
	end

	local total = 0
	for _, entry in ipairs(loot) do total += entry.weight end
	local roll = math.random() * total
	local running = 0
	for _, entry in ipairs(loot) do
		running += entry.weight
		if roll <= running then return entry.item, zone end
	end
	return loot[1].item, zone
end

local function baitCount(player)
	local state = Inventory.Get(player)
	if not state then return 0 end
	local n = 0
	for _, slot in pairs(state.slots) do
		if slot.id == FishingConfig.BaitItem then n += (slot.count or 1) end
	end
	return n
end

-- Spends one worm. Returns false if there were none, which ends the session.
local function spendBait(player)
	local state = Inventory.Get(player)
	if not state then return false end
	for index, slot in pairs(state.slots) do
		if slot.id == FishingConfig.BaitItem then
			Inventory.RemoveFromSlot(player, index, FishingConfig.BaitPerCatch)
			return true
		end
	end
	return false
end

--------------------------------------------------------------------------------
-- Sessions
--------------------------------------------------------------------------------

local function stop(player, reason)
	local session = Sessions[player]
	if not session then return end
	Sessions[player] = nil
	showCard(player, false)
	player:SetAttribute("WOLD_Fishing", nil)
	if reason then
		Remotes.SocialNotify:FireClient(player, "info", reason)
	end
end

local function holdingRod(player)
	local _, slot = Inventory.EquippedWeapon(player)
	local item = slot and ItemCatalog.Get(slot.id)
	return item ~= nil and item.fishing == true
end

local function startFishing(player)
	if Sessions[player] then return false end
	local character = player.Character
	if not character or Vitals.IsDowned(player) then return false end
	if not holdingRod(player) then return false end

	local found = waterAhead(character)
	if not found then
		Remotes.SocialNotify:FireClient(player, "error", "ตรงนี้ไม่มีน้ำ")
		return false
	end
	if baitCount(player) <= 0 then
		Remotes.SocialNotify:FireClient(player, "error", "ไม่มีหนอนเป็นเหยื่อ")
		return false
	end

	local root = character:FindFirstChild("HumanoidRootPart")
	local anchor = root and root.Position

	-- The cast: heard by everyone nearby, because it happens in the world.
	if root and FishingConfig.CastSound ~= "" then
		local sound = Instance.new("Sound")
		sound.SoundId = FishingConfig.CastSound
		sound.Volume = FishingConfig.CastSoundVolume
		sound.RollOffMaxDistance = FishingConfig.CastSoundDistance
		sound.Parent = root
		sound:Play()
		Debris:AddItem(sound, 4)
	end

	showCard(player, true)
	player:SetAttribute("WOLD_Fishing", true)
	Remotes.SocialNotify:FireClient(player, "info", "เริ่มตกปลา")

	local session = { anchor = anchor }
	Sessions[player] = session

	session.thread = task.spawn(function()
		while Sessions[player] == session do
			local wait = math.random(FishingConfig.MinSeconds, FishingConfig.MaxSeconds)
			-- Waited in slices so the checks below run during the wait, not only after it: a player who
			-- walks away should stop fishing then, not twenty seconds later.
			-- A fifth of a second, not a whole one: walking is meant to cancel fishing IMMEDIATELY, and a
			-- one-second sweep let the player take several steps before the line came in.
			local elapsed = 0
			while elapsed < wait do
				if Sessions[player] ~= session then return end
				task.wait(0.2)
				elapsed += 0.2

				local char = player.Character
				local root2 = char and char:FindFirstChild("HumanoidRootPart")
				if not root2 or Vitals.IsDowned(player) then
					return stop(player, "หยุดตกปลา")
				end
				if not holdingRod(player) then
					return stop(player, "เก็บคันเบ็ดแล้ว หยุดตกปลา")
				end
				if session.anchor and (root2.Position - session.anchor).Magnitude
					> FishingConfig.LeashDistance then
					return stop(player, "เดินออกจากน้ำ หยุดตกปลา")
				end
				-- Any deliberate movement reels in. Read from the humanoid rather than from a client flag:
				-- MoveDirection is non-zero only while the player is actually asking to move, so being
				-- shoved or standing on something moving does not count.
				local hum = char:FindFirstChildOfClass("Humanoid")
				if hum and hum.MoveDirection.Magnitude > 0.1 then
					return stop(player, "เดิน หยุดตกปลา")
				end
			end

			-- Bait first: no worm, no catch, and the session ends rather than fishing for free.
			if not spendBait(player) then
				return stop(player, "หนอนหมด หยุดตกปลา")
			end

			local caught, zone = rollLoot(session.anchor)
			local item = ItemCatalog.Get(caught)

			-- ปลาประจำถิ่นไหม — ใช้บอกผู้เล่นและใช้ตัดสินว่าจะประกาศให้ทั้งเซิร์ฟเวอร์รู้ไหม
			local isLocal = false
			if zone then
				for _, entry in ipairs(zone.fish) do
					if entry.item == caught then isLocal = true break end
				end
			end

			-- The bite: the rod jerks and the cast sound plays again, so a catch is something you SEE and
			-- hear rather than only a line of text.
			twitchRod(player)
			local char = player.Character
			local root = char and char:FindFirstChild("HumanoidRootPart")
			if root and FishingConfig.CastSound ~= "" then
				local sound = Instance.new("Sound")
				sound.SoundId = FishingConfig.CastSound
				sound.Volume = FishingConfig.CastSoundVolume
				sound.RollOffMaxDistance = FishingConfig.CastSoundDistance
				sound.Parent = root
				sound:Play()
				Debris:AddItem(sound, 4)
			end

			-- Rolled HERE, on the server, for the same reason the catch itself is: the client is told what it
			-- got and never asked. A weight decided client-side would be a fifty-kilo legendary every cast.
			local kg = FishingConfig.RollKg(caught)
			local tier = FishingConfig.TierFor(kg)

			-- Only a TROPHY carries its weight into the bag.
			--
			-- The kilograms ride in the slot's `meta`, which is the only per-item store the bag has -- the
			-- same shape a vehicle key's plate uses -- and a slot carrying meta never merges into a stack.
			-- Recording every catch therefore meant a fishing trip filling ninety-nine slots where it used
			-- to fill one, which turns bag space into the thing that ends a session.
			--
			-- So the common fish stack as they always did and are simply fish, while anything from the blue
			-- tier up keeps its weight, its colour and its own slot. The size still shows on the card either
			-- way, so nothing is hidden -- it just is not hoarded.
			-- ปลาประจำถิ่นเก็บน้ำหนักเสมอ ไม่ต้องรอให้ตัวใหญ่
			--
			-- มันสแตคไม่ได้อยู่แล้ว (stackSize = 1) การไม่เก็บน้ำหนักจึงไม่ประหยัดช่องอะไรเลย มีแต่เสีย
			-- ข้อมูลไปเปล่าๆ — และสมุดสะสมต้องใช้น้ำหนักตัวที่หนักที่สุดของแต่ละชนิด
			local meta = (isLocal or FishingConfig.IsBig(kg)) and { kg = kg } or nil
			if Inventory.AddItem(player, caught, 1, nil, meta) then
				showCatch(player, caught, kg)
				Collection.RecordFish(player, caught, kg)
				Remotes.SocialNotify:FireClient(player, "info",
					("ตกได้ %s %.1f กก.%s%s"):format(item and item.name or caught, kg,
						tier.name ~= "" and (" (%s)"):format(tier.name) or "",
						isLocal and (" — ปลาประจำถิ่น%s"):format(zone.name) or ""))
			else
				Remotes.SocialNotify:FireClient(player, "error", "กระเป๋าเต็ม ปลาหลุดไป")
			end
		end
	end)

	return true
end

--------------------------------------------------------------------------------
-- Hooks for the rest of the game
--------------------------------------------------------------------------------

-- Called by PlayerCombat when a click lands. Returns true if the swing was a cast, so the combat system
-- knows not to also resolve it as an attack -- otherwise every cast would swing a fishing rod at whatever
-- happened to be standing in front of the player.
FishingAccess.TryCast = function(player)
	if not holdingRod(player) then return false end
	-- Clicking again while fishing reels in, which is the obvious thing for a second click to do.
	if Sessions[player] then
		stop(player, "เก็บสายแล้ว")
		return true
	end
	startFishing(player)
	-- True either way: the swing belonged to the rod, whether or not the water was there.
	return true
end

FishingAccess.IsFishing = function(player)
	return Sessions[player] ~= nil
end

FishingAccess.Stop = function(player)
	stop(player)
end

Players.PlayerRemoving:Connect(function(player)
	Sessions[player] = nil
end)

PlayerJoin.Each(function(player)
	player.CharacterRemoving:Connect(function()
		stop(player)
	end)
end)
