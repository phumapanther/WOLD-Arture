-- PlayerEmotes.server.lua: the one part of an emote the client may not decide for itself.
--
-- The animation is entirely the client's: it plays on its own character's Animator and Roblox replicates it
-- to everyone else with no help. What comes through here is the HOLD -- sitting cross-legged or lying down
-- means not walking, and WalkSpeed is written every tick by PlayerMovement from the server's own state, so a
-- client setting it to zero would be overwritten inside the frame.
--
-- Nothing here trusts the client beyond "I am posing" / "I am not". Both are states the player is allowed to
-- put themselves in at will -- standing still is not a privilege -- and everything that outranks a pose
-- (being knocked down, dizzy, rooted for a minigame) is decided in StatusEffects above it.
local Players = game:GetService("Players")
local ServerConfig = require(game.ServerScriptService.ServerConfig)

if ServerConfig.IsLobby then return end

local StatusEffects = require(game.ServerScriptService.StatusEffects)
local Vitals = require(game.ServerScriptService.Vitals)
local Remotes = require(game.ReplicatedStorage.Remotes)
local PlayerJoin = require(game.ServerScriptService.PlayerJoin)

Remotes.RequestEmotePose.OnServerEvent:Connect(function(player, posing)
	-- Anything but a literal true is a request to stand up. A client sending nonsense therefore releases the
	-- player rather than trapping them, which is the safe direction for a state that stops you moving.
	local wants = posing == true

	-- Not while you are on the floor: the crawl owns the body then, and a pose lock on top of it would stop
	-- the crawl dead -- the same rule dizziness and knockdowns already follow.
	if wants and Vitals.IsDowned(player) then return end

	StatusEffects.SetPosing(player, wants)
end)

-- A new character is a standing character. The state table survives a respawn, so without this a player who
-- died mid-pose would come back rooted with nothing on screen to explain why.
PlayerJoin.Each(function(player)
	player.CharacterAdded:Connect(function()
		StatusEffects.SetPosing(player, false)
	end)
end)
