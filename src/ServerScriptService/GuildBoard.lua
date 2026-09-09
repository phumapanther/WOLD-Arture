-- GuildBoard.lua: the notice board every player in this server shares.
--
-- Server memory only, never the DataStore: the board is scoped to one channel by design (a post in channel 1
-- is for channel 1), and it disappears when the server does. That was the user's choice, and it keeps the
-- board free of the write budget every persistent system has to share.
local SocialConfig = require(game.ReplicatedStorage.SocialConfig)
local Classes = require(script.Parent.Classes)

local GuildBoard = {}

local Posts = {} -- newest first
local LastPostAt = {} -- [player] = os.clock() of their last accepted post
local NextId = 1

-- Trims a player's text to something safe to show: no newlines (they would break the feed's one-line rows),
-- no runaway length, and nothing that is only whitespace.
local function clean(text)
	if typeof(text) ~= "string" then return nil end
	text = text:gsub("[\r\n\t]", " "):gsub("%s+", " "):gsub("^%s*(.-)%s*$", "%1")
	if text == "" then return nil end
	if #text > SocialConfig.BoardMaxLength then
		text = text:sub(1, SocialConfig.BoardMaxLength)
	end
	return text
end

-- Returns the new post, or nil plus a reason the caller can show the player.
function GuildBoard.Post(player, text)
	local body = clean(text)
	if not body then return nil, "ข้อความว่างเปล่า" end

	local last = LastPostAt[player]
	local now = os.clock()
	if last and now - last < SocialConfig.BoardCooldown then
		return nil, ("รออีก %.0f วินาที"):format(SocialConfig.BoardCooldown - (now - last))
	end
	LastPostAt[player] = now

	local post = {
		id = NextId,
		userId = player.UserId,
		name = player.DisplayName ~= "" and player.DisplayName or player.Name,
		-- Stamped onto the post rather than looked up when it is drawn: the board keeps posts after the
		-- writer has left, and a name with no colour would be a stranger among coloured ones.
		class = Classes.Primary(player),
		text = body,
		at = os.time(),
	}
	NextId += 1

	table.insert(Posts, 1, post)
	-- Trim from the end: the oldest post falls off once the board is full.
	while #Posts > SocialConfig.BoardMaxPosts do
		table.remove(Posts)
	end
	return post
end

-- The whole board, newest first. Returned as a copy so a caller cannot reorder or edit the live list.
function GuildBoard.All()
	local out = table.create(#Posts)
	for i, post in ipairs(Posts) do
		out[i] = post
	end
	return out
end

function GuildBoard.Remove(player)
	LastPostAt[player] = nil
end

return GuildBoard
