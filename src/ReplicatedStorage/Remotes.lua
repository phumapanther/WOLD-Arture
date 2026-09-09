-- Remotes.lua: idempotent RemoteEvent/RemoteFunction bootstrap. The server creates them; the client waits for them.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local EVENTS = {
	"JoinChannel", "ChannelList", "JoinFailed", "RequestReturnToLobby", "RequestChannelRefresh",
	"SetSprintIntent", "ToggleWalk", -- movement (client intent in; stamina goes out via VitalsUpdate)
	"RequestAttack", "CombatStateChanged", -- combat (click intent in, guard/attack playback out)
	"VitalsUpdate", "DownedStateChanged", "RequestRespawn", -- vitals (hp/hunger/stamina/armor out, downed UI, respawn in)
	"RequestRoll", "RequestSlide", "MoveStateChanged", -- roll/slide (client intent in, animation playback out)
	"RequestRevive", "RequestCarry", "RequestDrop", "CarryStateChanged", -- reviving and carrying a downed player
	"ProgressionUpdate", "LevelUp", -- exp/level out, plus a one-shot for the level-up effect
	-- Inventory: contents out, player intents in (move/equip/use/sort), equipment broadcast so everyone can
	-- see what each other is holding.
	"InventoryUpdate", "EquipmentChanged",
	"RequestEquip", "RequestUnequip", "RequestUseItem", "RequestDropItem", "RequestAutoSort",
	"RequestInventoryRefresh",
	-- Eating and drinking take time; every client needs to know so it can play the animation and hold the
	-- item to the mouth.
	"ConsumeStateChanged", -- client asks for a resend: the join broadcast can land before it connects
	"RequestSkill", "SkillUsed", -- the weapon's Q skill: intent in, playback out
	"StatusChanged", -- knockdown / slow, so every client can render them
	-- Admin console: the command text in, the reply out. AdminCommand is guarded by a UserId allow-list on
	-- the SERVER, so a non-admin firing it is refused exactly as if they had never found it.
	"AdminCommand", "AdminMessage",
	-- Flight is driven on the CLIENT because the character physics belongs to it; the server only says
	-- whether an admin may fly, which is the part that has to be trusted.
	"AdminFly",
	-- Social (the speaking stone): the client asks and the server answers. Every inbound one is validated
	-- server-side -- amounts, names and lengths are never trusted as sent.
	"RequestSocialData", "SocialUpdate", "SocialNotify",
	"RequestGuildPost", "GuildPostAdded", -- the board, plus a push for the floating feed
	"RequestFriendAction", "RequestPigeonMessage", "PigeonMessage",
	"RequestBankAction",
	"RequestShowCard", "CardStateChanged", -- profile card raised over a player, seen by everyone nearby
	"RequestCall", "CallStateChanged", -- telepathy: ring, answer, decline, hang up (UI only, no audio yet)
}
local FUNCTIONS = { "GetSpawnPosition" } -- DataStore-backed lookups can only run server-side; the client must ask

local folder = ReplicatedStorage:FindFirstChild("Remotes")
if RunService:IsServer() then
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "Remotes"
		folder.Parent = ReplicatedStorage
	end
	for _, name in ipairs(EVENTS) do
		if not folder:FindFirstChild(name) then
			local event = Instance.new("RemoteEvent")
			event.Name = name
			event.Parent = folder
		end
	end
	for _, name in ipairs(FUNCTIONS) do
		if not folder:FindFirstChild(name) then
			local fn = Instance.new("RemoteFunction")
			fn.Name = name
			fn.Parent = folder
		end
	end
else
	folder = folder or ReplicatedStorage:WaitForChild("Remotes")
end

local Remotes = {}
for _, name in ipairs(EVENTS) do
	Remotes[name] = folder:WaitForChild(name)
end
for _, name in ipairs(FUNCTIONS) do
	Remotes[name] = folder:WaitForChild(name)
end
return Remotes
