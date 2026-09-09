-- ClassActionConfig: what each class can do to another player standing next to them.
--
-- Every entry becomes a ProximityPrompt on nearby players, shown only to someone whose class grants it. The
-- server re-checks the class on every request, so the prompt is a convenience rather than the permission.
--
-- Prompts appear on players who are NOT downed. Reviving and carrying a downed player is a separate system
-- (PlayerRescue) with its own prompts, and the two never show at once.
local ClassActionConfig = {}

-- How close you must be. Matches the rescue range so all the prompts in the game appear at the same distance.
ClassActionConfig.Range = 8

-- Keys. E and F belong to the rescue prompts, which only appear on downed players -- these only appear on
-- players who are up, so the two sets can never be on screen together and the keys can be reused.
--
-- `hold` is how long the key must be held. A hold is for anything the target should have a chance to notice
-- happening to them, or that ought to cost the actor a moment of standing still.
ClassActionConfig.Actions = {
	{
		id = "give",
		label = "ให้เงิน",
		key = Enum.KeyCode.E,
		hold = 0, -- opens a box to type an amount; the deliberation is in the typing
		classes = { "Adventurer", "Merchant" },
	},
	{
		id = "beg",
		label = "ขอเงิน",
		key = Enum.KeyCode.E,
		hold = 0,
		classes = { "Beggar" },
	},
	{
		id = "rob",
		label = "ปล้น",
		key = Enum.KeyCode.R,
		-- A hold, so the victim sees the ring filling before anything is taken and has the three seconds
		-- the countdown promises rather than being robbed between frames.
		hold = 1,
		classes = { "Rogue", "Beggar" },
	},
	{
		id = "carry",
		label = "อุ้ม",
		key = Enum.KeyCode.F,
		hold = 2, -- shorter than the rescue carry: this one also needs the target to agree
		classes = { "Adventurer", "Rogue" },
	},
	{
		id = "trade",
		label = "เทรด",
		key = Enum.KeyCode.T,
		hold = 0, -- opens a request; the deliberation is in the window that follows
		classes = { "Merchant", "Chef" },
	},
	{
		id = "arrest",
		label = "จับกุม",
		key = Enum.KeyCode.R,
		hold = 3,
		classes = { "Guard", "Noble" },
	},
	{
		id = "heal",
		label = "ฮีล",
		key = Enum.KeyCode.E,
		hold = 0, -- opens a choice of small or large
		classes = { "Priest" },
	},
	{
		id = "repair",
		label = "ซ่อมของ",
		key = Enum.KeyCode.E,
		hold = 3, -- the work itself takes three seconds; the hold IS the work
		classes = { "Architect" },
	},
}

--------------------------------------------------------------------------------
-- Numbers
--------------------------------------------------------------------------------

-- Robbery. The victim gets a countdown and a button; beating it costs the thief nothing but the attempt,
-- and marks them red for everyone to see.
ClassActionConfig.Rob = {
	countdownSeconds = 3,
	cooldownSeconds = 60, -- per thief, so a failed robbery cannot be retried immediately
}

-- Begging: an animation and nothing else. Whether to give is the other player's business, which is what
-- makes it roleplay rather than a mechanic.
ClassActionConfig.Beg = {
	cooldownSeconds = 10,
}

-- The priest's two heals. Charged to the PATIENT, not the priest -- a healer who had to pay to heal would
-- simply not heal anyone.
ClassActionConfig.Heal = {
	small = { fraction = 0.25, cost = 500, label = "ฮีลเล็ก 25%" },
	large = { fraction = 1.00, cost = 2000, label = "ฮีลใหญ่ 100%" },
	-- A revived player wakes at full health rather than the usual fraction when a priest does it.
	reviveFraction = 1.0,
	-- And the CPR itself is quicker in trained hands.
	reviveSeconds = 2.5,
}

-- The architect's repair: everything worn and everything in the bag, back to full.
ClassActionConfig.Repair = {
	cost = 2500,
	seconds = 3,
}

-- Trading. Both sides put things up, both must agree, and either can walk away.
ClassActionConfig.Trade = {
	askSeconds = 20, -- how long the invitation stands before it is treated as a refusal
	offerSlots = 8, -- how many items one side can put up at once
	range = 12, -- a little further than the other actions: a trade takes a while and people shuffle
}

-- What a guard or noble may take. Four slots is enough to strip someone's weapon and armour without it
-- becoming a way to empty a bag.
ClassActionConfig.Arrest = {
	confiscateSlots = 4,
	maxFine = 1000000, -- a blast radius, the same reason the bank transfer has one
	-- How long an arrested player stays held. Not indefinite: a guard who wanders off must not leave someone
	-- locked in place forever.
	holdSeconds = 120,
}

--------------------------------------------------------------------------------
-- The F2 command menu
--------------------------------------------------------------------------------

-- Commands an advanced class can issue about itself, rather than to a particular person standing next to
-- them. F2 opens the list; only the classes with commands see anything.
--
-- Deliberately a LIST rather than a set of hardcoded abilities: the point of the menu is that more commands
-- get added to it over time, and adding one should be an entry here plus a branch on the server -- not a new
-- key, a new prompt, and a new window each time.
--
-- `id` is what the server is told; `label` is what the player reads; `announce` marks a command that speaks
-- to the whole server, which is the shape most of these will take.
ClassActionConfig.Commands = {
	Guard = {
		{ id = "guard_patrol", label = "ประกาศ: ออกตรวจการณ์", announce = true },
		{ id = "guard_alert", label = "ประกาศ: แจ้งเหตุร้าย", announce = true },
	},
	Noble = {
		{ id = "noble_decree", label = "ประกาศ: ออกประกาศิต", announce = true },
	},
	Priest = {
		{ id = "priest_blessing", label = "ประกาศ: ให้พร", announce = true },
		{ id = "priest_service", label = "ประกาศ: เปิดพิธี", announce = true },
	},
	Architect = {
		{ id = "architect_open", label = "ประกาศ: เปิดร้านซ่อม", announce = true },
	},
	Chef = {
		{ id = "chef_open", label = "ประกาศ: เปิดร้านอาหาร", announce = true },
	},
}

-- How often one player may issue a command. Announcements reach everyone, so the limit is the whole point:
-- without it the menu is a way to shout at the server on a loop.
ClassActionConfig.CommandCooldown = 30

function ClassActionConfig.CommandsFor(classId)
	return (classId and ClassActionConfig.Commands[classId]) or {}
end

-- Whether `classId` may issue `commandId`. The server permission check, matching Grants above.
function ClassActionConfig.MayCommand(classId, commandId)
	for _, command in ipairs(ClassActionConfig.CommandsFor(classId)) do
		if command.id == commandId then return command end
	end
	return nil
end

--------------------------------------------------------------------------------

-- Every action a class grants, in config order so the prompts stack the same way every time.
function ClassActionConfig.ForClass(classId)
	local list = {}
	if not classId then return list end
	for _, action in ipairs(ClassActionConfig.Actions) do
		for _, allowed in ipairs(action.classes) do
			if allowed == classId then
				table.insert(list, action)
				break
			end
		end
	end
	return list
end

-- Whether `classId` grants `actionId`. The server's permission check.
function ClassActionConfig.Grants(classId, actionId)
	if not classId then return false end
	for _, action in ipairs(ClassActionConfig.Actions) do
		if action.id == actionId then
			for _, allowed in ipairs(action.classes) do
				if allowed == classId then return true end
			end
			return false
		end
	end
	return false
end

function ClassActionConfig.Get(actionId)
	for _, action in ipairs(ClassActionConfig.Actions) do
		if action.id == actionId then return action end
	end
	return nil
end

return ClassActionConfig
