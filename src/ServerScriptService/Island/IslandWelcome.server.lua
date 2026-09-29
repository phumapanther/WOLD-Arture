-- IslandWelcome.server: ป้ายต้อนรับครั้งแรกบนเกาะ (เควส "เกาะลอยฟ้าแห่งความฝัน" · 2026-09-29)
-- ธง `Story.skyWelcome` ตั้งตอนกด "รับพร" (Story.server เกมหลัก) · ผูกกับธง ไม่ใช่กับการวาป — เข้าจากล็อบบี้ก็ได้ป้ายเหมือนกัน
-- เจ้าของเกาะเท่านั้น (ไปเกาะเพื่อนก่อน = ธงรอไว้เกาะตัวเอง) · Story.server ไม่รันบนเกาะ ช่อง RequestStory จึงว่างให้ใช้
local Players = game:GetService("Players")
local ServerConfig = require(script.Parent.Parent.ServerConfig)
if not ServerConfig.IsFarm then return end

local ProfileAccess = require(script.Parent.Parent.ProfileAccess)
local IslandAccess = require(script.Parent.IslandAccess)
local Remotes = require(game.ReplicatedStorage.Remotes)

local Done = {}

Remotes.RequestStory.OnServerEvent:Connect(function(player, action)
	if action ~= "island_ready" or Done[player] then return end
	local data = ProfileAccess.Get(player)
	if not data then return end -- ไคลเอนต์ส่งซ้ำอีกรอบ
	if IslandAccess.IsOwner and not IslandAccess.IsOwner(player) then return end
	Done[player] = true
	local story = data.Story
	if type(story) == "table" and story.skyWelcome == true then
		story.skyWelcome = nil
		Remotes.StoryPlay:FireClient(player, "welcome")
	end
end)

Players.PlayerRemoving:Connect(function(player)
	Done[player] = nil
end)
