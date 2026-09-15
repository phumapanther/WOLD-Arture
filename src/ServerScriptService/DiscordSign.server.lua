-- DiscordSign.server.lua: the [E] on the town sign that hands out the Discord invite.
--
-- Found by the TEXT on the board rather than by its path, so the sign can be moved, renamed or rebuilt by a
-- mapgen phase without this breaking. The sign is a hand-placed thing in a folder a phase owns; naming a
-- path here would tie a game system to a map layout that is expected to change.
local Players = game:GetService("Players")

local ServerConfig = require(game.ServerScriptService.ServerConfig)
if ServerConfig.IsLobby then return end

local SocialConfig = require(game.ReplicatedStorage.SocialConfig)
local Remotes = require(game.ReplicatedStorage.Remotes)

-- The words on the board that mark it as the town sign.
local SIGN_TEXT = "BRASSHAVEN"

local function boardsNamed(text)
	local found = {}
	for _, d in ipairs(workspace:GetDescendants()) do
		if (d:IsA("TextLabel") or d:IsA("TextBox")) and tostring(d.Text):upper():find(text, 1, true) then
			-- The prompt has to hang off a BasePart. A SurfaceGui is drawn ON one, so walk out to it.
			local gui = d:FindFirstAncestorWhichIsA("SurfaceGui")
			local part = gui and (gui.Adornee or gui.Parent)
			if part and part:IsA("BasePart") then
				found[#found + 1] = part
			end
		end
	end
	return found
end

local function wire(part)
	if part:FindFirstChild("DiscordPrompt") then return false end

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "DiscordPrompt"
	prompt.ActionText = SocialConfig.DiscordPrompt
	prompt.ObjectText = SocialConfig.DiscordObject
	prompt.MaxActivationDistance = 14
	-- The board faces outward from a post, and a player reading it stands in front rather than in line of
	-- sight of its centre.
	prompt.RequiresLineOfSight = false
	prompt.Parent = part

	prompt.Triggered:Connect(function(player)
		Remotes.ShowDiscord:FireClient(player)
	end)
	return true
end

local wired = 0
for _, part in ipairs(boardsNamed(SIGN_TEXT)) do
	if wire(part) then wired += 1 end
end

if wired == 0 then
	-- Loud rather than silent: a sign nobody can press looks exactly like a sign nobody has walked up to
	-- yet, and the difference would only be found by a player.
	warn(("[Discord] ไม่เจอป้ายที่มีข้อความ %q ในแมพ — ปุ่มดิสคอร์ดจะไม่ขึ้น"):format(SIGN_TEXT))
else
	print(("[Discord] ติดปุ่มบนป้ายเมือง %d จุด"):format(wired))
end
