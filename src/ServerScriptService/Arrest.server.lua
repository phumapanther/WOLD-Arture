-- Arrest.server.lua: a guard or noble taking someone into custody.
--
-- Shaped like the trade, but one-sided: only the guard chooses, and only the prisoner gives. They are held
-- in place in front of the guard with their hands behind their back until they are released, the fine is
-- paid, or the hold runs out.
--
-- The prisoner gets no say -- that is what an arrest is -- so everything that protects them is a limit on
-- the guard instead: four confiscation slots rather than the whole bag, a fine that cannot exceed what they
-- carry, and a hold that expires on its own so a guard who wanders off cannot leave someone locked forever.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ServerConfig = require(game.ServerScriptService.ServerConfig)
local Classes = require(game.ServerScriptService.Classes)
local Inventory = require(game.ServerScriptService.Inventory)
local Vitals = require(game.ServerScriptService.Vitals)
local ClassActionConfig = require(game.ReplicatedStorage.ClassActionConfig)
local ItemCatalog = require(game.ReplicatedStorage.ItemCatalog)
local Remotes = require(game.ReplicatedStorage.Remotes)
local Jail = require(game.ServerScriptService.Jail)

if ServerConfig.IsLobby then return end

local Arrests = {} -- [guard] = session
local Held = {} -- [prisoner] = session, so one prisoner cannot be arrested twice

--------------------------------------------------------------------------------

local function rootOf(player)
	local character = player and player.Character
	return character and character:FindFirstChild("HumanoidRootPart")
end

local function withinRange(a, b)
	local ra, rb = rootOf(a), rootOf(b)
	if not ra or not rb then return false end
	return (ra.Position - rb.Position).Magnitude <= ClassActionConfig.Range * 1.5
end

local function mayArrest(guard, target)
	if not guard or not target or guard == target then return false end
	if not guard.Parent or not target.Parent then return false end
	if Vitals.IsDowned(guard) or Vitals.IsDowned(target) then return false end
	if Arrests[guard] or Held[target] then return false end
	if not withinRange(guard, target) then return false end
	return ClassActionConfig.Grants(Classes.Get(guard, "basic"), "arrest")
		or ClassActionConfig.Grants(Classes.Get(guard, "advanced"), "arrest")
end

--------------------------------------------------------------------------------
-- Holding the prisoner
--------------------------------------------------------------------------------

-- Pinned in front of the guard and unable to walk. The same pieces the carry uses, for the same reasons:
-- PlatformStand stops their own controls fighting the position, and the prisoner keeps their own Animator
-- so the bound-hands pose can play on them.
local function bind(session)
	local prisoner, guard = session.prisoner, session.guard
	local pRoot = rootOf(prisoner)
	local gRoot = rootOf(guard)
	if not pRoot or not gRoot then return false end

	local humanoid = prisoner.Character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.PlatformStand = true
		humanoid.WalkSpeed = 0
		humanoid.JumpPower = 0
	end
	-- Held by the server rather than welded: a weld to a walking guard drags the prisoner through walls,
	-- and the position is re-set each frame below anyway.
	pRoot.Anchored = true
	prisoner:SetAttribute("WOLD_Arrested", true)
	return true
end

local function unbind(session)
	local prisoner = session.prisoner
	prisoner:SetAttribute("WOLD_Arrested", nil)
	local character = prisoner.Character
	if not character then return end
	local root = character:FindFirstChild("HumanoidRootPart")
	if root then root.Anchored = false end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.PlatformStand = false
		humanoid.JumpPower = 50
		-- PlayerMovement owns WalkSpeed; putting back the ordinary value is enough, its state machine
		-- corrects it on the next intent change.
		humanoid.WalkSpeed = 8
	end
end

-- Kept standing just in front of the guard, facing them. Re-set every frame rather than welded so the
-- prisoner follows a guard who walks off without being dragged through the world.
local function keepInPlace(session)
	local gRoot = rootOf(session.guard)
	local pRoot = rootOf(session.prisoner)
	if not gRoot or not pRoot then return false end
	local ahead = gRoot.Position + gRoot.CFrame.LookVector * 3.5
	pRoot.CFrame = CFrame.lookAt(Vector3.new(ahead.X, pRoot.Position.Y, ahead.Z), gRoot.Position)
	return true
end

--------------------------------------------------------------------------------
-- Telling both sides
--------------------------------------------------------------------------------

-- What the guard sees: the prisoner's whole bag and gold, plus what has been marked for confiscation and
-- the fine typed so far.
local function describe(session)
	local state = Inventory.Get(session.prisoner)
	local bag = {}
	for index, slot in pairs((state and state.slots) or {}) do
		local item = ItemCatalog.Get(slot.id)
		table.insert(bag, {
			slot = index,
			id = slot.id,
			name = item and item.name or slot.id,
			icon = item and item.icon or "",
			count = slot.count or 1,
		})
	end
	return {
		bag = bag,
		gold = (state and state.gold) or 0,
		taking = session.taking,
		fine = session.fine,
	}
end

local function publish(session)
	local payload = describe(session)
	payload.role = "guard"
	Remotes.ArrestStateChanged:FireClient(session.guard, "update", session.prisoner, payload)
	-- The prisoner sees the same thing: being able to watch what is being taken is the only power they have.
	local theirs = describe(session)
	theirs.role = "prisoner"
	Remotes.ArrestStateChanged:FireClient(session.prisoner, "update", session.guard, theirs)
end

local function closeSession(session, reason)
	if session.closed then return end
	session.closed = true
	Arrests[session.guard] = nil
	Held[session.prisoner] = nil
	unbind(session)
	for _, player in ipairs({ session.guard, session.prisoner }) do
		if player.Parent then
			local other = (player == session.guard) and session.prisoner or session.guard
			Remotes.ArrestStateChanged:FireClient(player, "closed", other, reason)
		end
	end
end

--------------------------------------------------------------------------------
-- Taking
--------------------------------------------------------------------------------

-- The whole take, replaced each time rather than added to one item at a time: the client says what it wants
-- to be taking, and the server decides whether that is possible. One request shape, one place to validate.
Remotes.RequestArrestTake.OnServerEvent:Connect(function(guard, slots, fine)
	local session = Arrests[guard]
	if not session or session.closed then return end
	if type(slots) ~= "table" then return end

	local state = Inventory.Get(session.prisoner)
	if not state then return end

	local clean, seen = {}, {}
	for _, index in ipairs(slots) do
		-- ของขอบทอง (เฟส 2b) ยึดไม่ได้: การยึดคือการย้ายของไปที่ทหาร ซึ่งของขอบทองออกจากมือเจ้าของไม่ได้
		if type(index) == "number" and state.slots[index] and not seen[index]
			and not ItemCatalog.IsGoldBorder(state.slots[index].meta) then
			seen[index] = true
			table.insert(clean, index)
			if #clean >= ClassActionConfig.Arrest.confiscateSlots then break end
		end
	end

	fine = math.floor(tonumber(fine) or 0)
	-- Cannot fine more than they are carrying: a debt they cannot pay would just be a number that never
	-- resolves, and taking them below zero is not something the gold system allows anyway.
	fine = math.clamp(fine, 0, math.min(state.gold, ClassActionConfig.Arrest.maxFine))

	session.taking = clean
	session.fine = fine
	publish(session)
end)

-- Carrying out the sentence: what the guard marked is taken, the fine is paid, and both are told what
-- happened. Shared by the plain "confirm" and by "confirm and jail" so the two can never drift apart --
-- jailing someone must not quietly take a different amount than releasing them would have.
--
-- Returns the settlement, or nil if it could not be carried out (the session is closed in that case).
local function settle(guard, session)
	if not withinRange(guard, session.prisoner) then
		closeSession(session, "อยู่ไกลเกินไป")
		return nil
	end

	local state = Inventory.Get(session.prisoner)
	if not state then
		closeSession(session, "ทำรายการไม่ได้")
		return nil
	end

	-- Re-read at the moment it happens, not when it was marked: the prisoner is held, but a stack can still
	-- change under a long arrest.
	local taking = {}
	for _, index in ipairs(session.taking) do
		local slot = state.slots[index]
		if slot and not ItemCatalog.IsGoldBorder(slot.meta) then
			table.insert(taking, { index = index, id = slot.id, count = slot.count or 1,
				durability = slot.durability, meta = slot.meta })
		end
	end
	local fine = math.min(session.fine, state.gold)

	for _, entry in ipairs(taking) do
		Inventory.RemoveFromSlot(session.prisoner, entry.index, entry.count)
	end
	if fine > 0 then
		Inventory.AddGold(session.prisoner, -fine)
		Inventory.AddGold(guard, fine)
	end
	for _, entry in ipairs(taking) do
		Inventory.AddItem(guard, entry.id, entry.count, entry.durability, entry.meta)
	end

	return { items = #taking, fine = fine }
end

Remotes.RequestArrestConfirm.OnServerEvent:Connect(function(guard)
	local session = Arrests[guard]
	if not session or session.closed then return end

	local result = settle(guard, session)
	if not result then return end

	Remotes.ArrestStateChanged:FireClient(guard, "completed", session.prisoner, result)
	Remotes.ArrestStateChanged:FireClient(session.prisoner, "completed", guard, result)
	closeSession(session, nil)
end)

-- ยึดของ ปรับเงิน แล้วส่งเข้าคุกตามระยะเวลาที่ทหารยามเลือก
--
-- **เวลาที่รับมาเป็น id ไม่ใช่จำนวนวินาที** ไคลเอนต์ส่งมาแค่ว่ากดปุ่มไหน แล้วเซิร์ฟเวอร์เปิดตารางเอง
-- ถ้ารับวินาทีมาตรงๆ ใครก็ส่งมาเท่าไหร่ก็ได้ และไม่มีด่านไหนที่รู้ว่าเท่าไหร่ถึงจะมากเกินไป
Remotes.RequestArrestJail.OnServerEvent:Connect(function(guard, termId)
	local session = Arrests[guard]
	if not session or session.closed then return end

	local seconds
	for _, term in ipairs(ClassActionConfig.Arrest.jailTerms) do
		if term.id == termId then seconds = term.seconds break end
	end
	if not seconds then return end

	local prisoner = session.prisoner
	local result = settle(guard, session)
	if not result then return end

	-- **ปลดการจับกุมก่อนส่งเข้าคุก** การจับกุมยึดตัวไว้ด้วย Anchored และตำแหน่งที่เขียนใหม่ทุกเฟรม ถ้ายัง
	-- ไม่ปลด การเทเลพอร์ตจะถูกเขียนทับกลับมาที่หน้าทหารยามทันทีในเฟรมถัดไป
	closeSession(session, nil)

	local ok, why = Jail.Commit(prisoner, seconds)
	result.jailed = ok and seconds or nil

	Remotes.ArrestStateChanged:FireClient(guard, "completed", prisoner,
		ok and result or { items = result.items, fine = result.fine, failed = why })
	if prisoner.Parent then
		Remotes.ArrestStateChanged:FireClient(prisoner, "completed", guard, result)
	end
end)

Remotes.RequestArrestRelease.OnServerEvent:Connect(function(player)
	-- Either party's remote, but only the guard can actually let go. A prisoner firing this is refused,
	-- which is the point of being arrested.
	local session = Arrests[player]
	if session then closeSession(session, "ปล่อยตัวแล้ว") end
end)

--------------------------------------------------------------------------------
-- Starting one
--------------------------------------------------------------------------------

local function begin(guard, target)
	if not mayArrest(guard, target) then return false, "จับกุมไม่ได้ตอนนี้" end

	local session = {
		guard = guard,
		prisoner = target,
		taking = {},
		fine = 0,
		closed = false,
		endsAt = os.clock() + ClassActionConfig.Arrest.holdSeconds,
	}
	if not bind(session) then return false, "จับกุมไม่ได้ตอนนี้" end

	Arrests[guard] = session
	Held[target] = session
	-- The role is stated rather than inferred: a client working out "am I the guard" from an attribute would
	-- get it wrong for the frame before that attribute replicates.
	Remotes.ArrestStateChanged:FireClient(guard, "opened", target, { role = "guard" })
	Remotes.ArrestStateChanged:FireClient(target, "opened", guard, { role = "prisoner" })
	publish(session)
	return true
end

local ArrestAccess = require(game.ServerScriptService.ArrestAccess)
ArrestAccess.Begin = begin

--------------------------------------------------------------------------------
-- Upkeep
--------------------------------------------------------------------------------

RunService.Heartbeat:Connect(function()
	local now = os.clock()
	for guard, session in pairs(Arrests) do
		if session.closed then
			-- already gone
		elseif now >= session.endsAt then
			closeSession(session, "หมดเวลาควบคุมตัว")
		elseif not session.prisoner.Parent or not session.guard.Parent then
			closeSession(session, "อีกฝ่ายออกจากเกม")
		elseif Vitals.IsDowned(session.prisoner) or Vitals.IsDowned(session.guard) then
			-- A guard who goes down cannot hold anyone, and a prisoner who goes down needs to be able to
			-- crawl and bleed out like anyone else.
			closeSession(session, "ล้มลง")
		elseif not keepInPlace(session) then
			closeSession(session, "ตัวละครหายไป")
		end
	end
end)

Players.PlayerRemoving:Connect(function(player)
	local asGuard = Arrests[player]
	if asGuard then closeSession(asGuard, "อีกฝ่ายออกจากเกม") end
	local asPrisoner = Held[player]
	if asPrisoner then closeSession(asPrisoner, "อีกฝ่ายออกจากเกม") end
end)
