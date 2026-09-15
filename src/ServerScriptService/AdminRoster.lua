-- AdminRoster: who is an admin, and the one place that answers it.
--
-- This file exists because the answer stopped being a constant. It used to be a table of UserIds written in
-- two places by hand -- once in AdminCommands and once again in the console that draws the box -- and the
-- user asked for a command that grants admin in-game, which neither of those could survive.
--
-- ROOT vs GRANTED, and why the difference is kept
--
-- Roots are the accounts written below, in the source, and nothing in the game can add to that list or take
-- from it. Everyone else is granted at runtime and stored in a DataStore, and **only a root may grant or
-- revoke**. The original file refused to have a grant command at all, with a reason worth keeping: "an admin
-- command that hands out admin is how one leaked account becomes everyone's problem". Requiring a root to
-- do the granting keeps that from cascading -- a stolen granted account can hand out items and teleport
-- people, which is bad, but it cannot mint more of itself.
--
-- Say so if you want granted admins to be able to grant in turn; it is one line.
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")

local AdminRoster = {}

-- Written in source, permanent, and the only accounts that may hand out admin.
local ROOTS = {
	[4871683651] = true, -- phumapanther (owner)
	[7899449166] = true, -- phumapanter
}

local STORE_NAME = "WOLD_Admins_v1"
local KEY = "roster"

local Granted = {}   -- [userId] = true, loaded from the store and kept in step with it
local loaded = false

local store
local ok = pcall(function() store = DataStoreService:GetDataStore(STORE_NAME) end)
if not ok then store = nil end

-- Read once at start-up. A failure here is not fatal and must not be: the roots are in source, so a
-- DataStore outage costs the granted admins their powers for that server and nothing else.
local function load()
	if loaded then return end
	loaded = true
	if not store then return end
	local success, saved = pcall(function() return store:GetAsync(KEY) end)
	if success and type(saved) == "table" then
		for id in pairs(saved) do
			local n = tonumber(id)
			if n then Granted[n] = true end
		end
	elseif not success then
		warn("[AdminRoster] could not read the roster:", saved)
	end
end

local function save()
	if not store then return false, "DataStore ใช้ไม่ได้" end
	-- Keys are written as STRINGS. A DataStore round-trips a table with number keys as a JSON object, which
	-- comes back with string keys anyway -- writing them as strings from the start means what goes in is
	-- what comes out, instead of a table that quietly changes shape on the way home.
	local out = {}
	for id in pairs(Granted) do out[tostring(id)] = true end
	local success, err = pcall(function() store:SetAsync(KEY, out) end)
	if not success then
		warn("[AdminRoster] could not write the roster:", err)
		return false, "บันทึกไม่สำเร็จ"
	end
	return true
end

load()

function AdminRoster.IsRoot(player)
	return ROOTS[player.UserId] == true
end

function AdminRoster.IsAdmin(player)
	return ROOTS[player.UserId] == true or Granted[player.UserId] == true
end

-- Replicated as an Attribute so the client can see it. The console and the admin chest both need to know
-- whether to draw themselves, and a hardcoded copy of the list on the client was how the two lists drifted
-- apart in the first place.
--
-- This grants NOTHING. Every command is re-checked on the server against the table above, so a client that
-- forges the attribute has only lied to its own interface.
local function publish(player)
	player:SetAttribute("WOLD_Admin", AdminRoster.IsAdmin(player) or nil)
end

AdminRoster.Publish = publish

-- Adds someone, and writes it down. Returns ok, message.
function AdminRoster.Grant(userId)
	if ROOTS[userId] then return false, "คนนี้เป็นแอดมินถาวรอยู่แล้ว" end
	if Granted[userId] then return false, "เป็นแอดมินอยู่แล้ว" end
	Granted[userId] = true
	local wrote, err = save()
	if not wrote then
		Granted[userId] = nil
		return false, err
	end
	local player = Players:GetPlayerByUserId(userId)
	if player then publish(player) end
	return true
end

function AdminRoster.Revoke(userId)
	if ROOTS[userId] then return false, "ถอนแอดมินถาวรไม่ได้" end
	if not Granted[userId] then return false, "คนนี้ไม่ใช่แอดมิน" end
	Granted[userId] = nil
	local wrote, err = save()
	if not wrote then
		Granted[userId] = true
		return false, err
	end
	local player = Players:GetPlayerByUserId(userId)
	if player then publish(player) end
	return true
end

-- Everyone on the list, for /admins. Roots are marked, because "can this person take my admin away" is the
-- question that list is usually being read to answer.
function AdminRoster.List()
	local out = {}
	for id in pairs(ROOTS) do table.insert(out, { userId = id, root = true }) end
	for id in pairs(Granted) do table.insert(out, { userId = id, root = false }) end
	table.sort(out, function(a, b)
		if a.root ~= b.root then return a.root end
		return a.userId < b.userId
	end)
	return out
end

return AdminRoster
