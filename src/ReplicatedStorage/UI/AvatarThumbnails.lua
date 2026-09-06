-- AvatarThumbnails: queued, cached, gently-paced avatar headshot fetching so a 30-player channel row
-- doesn't fire 30 simultaneous thumbnail requests.
local Players = game:GetService("Players")

local AvatarThumbnails = {}
local cache = {} -- [userId] = content (string) | false (failed)
local queue = {}
local queueSet = {}
local processing = false
local onLoaded = nil

local function processQueue()
	if processing then return end
	processing = true
	task.spawn(function()
		while #queue > 0 do
			local userId = table.remove(queue, 1)
			queueSet[userId] = nil
			local ok, content = pcall(function()
				return Players:GetUserThumbnailAsync(userId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size48x48)
			end)
			cache[userId] = ok and content or false
			if onLoaded then onLoaded(userId, cache[userId]) end
			task.wait(0.05)
		end
		processing = false
	end)
end

function AvatarThumbnails.Get(userId, callback)
	if cache[userId] ~= nil then
		callback(cache[userId])
		return
	end
	callback(nil)
	if not queueSet[userId] then
		queueSet[userId] = true
		table.insert(queue, userId)
	end
	processQueue()
end

function AvatarThumbnails.OnAnyLoaded(fn)
	onLoaded = fn
end

return AvatarThumbnails
