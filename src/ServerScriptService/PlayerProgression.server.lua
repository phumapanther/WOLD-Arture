-- PlayerProgression.server.lua: wires Progression into the game's lifecycle, and binds it to Vitals.
--
-- The two modules depend on each other (a level-up refills the bars; the bars' maximums depend on level), so
-- neither requires the other — this file injects each into the other once, at startup, before any player joins.
local Players = game:GetService("Players")
local ServerConfig = require(game.ServerScriptService.ServerConfig)
local Progression = require(game.ServerScriptService.Progression)
local Classes = require(game.ServerScriptService.Classes)
local Vitals = require(game.ServerScriptService.Vitals)
local ProfileAccess = require(game.ServerScriptService.ProfileAccess)
local PlayerJoin = require(game.ServerScriptService.PlayerJoin)

if ServerConfig.IsLobby then return end

Progression.BindVitals(Vitals)
Vitals.BindProgression(Progression)
-- PlayerProfile calls this when it saves; publishing it here keeps the profile system free of any dependency
-- on progression.
ProfileAccess.SerializeProgression = Progression.Serialize

local Inventory = require(game.ServerScriptService.Inventory)
local Remotes = require(game.ReplicatedStorage.Remotes)

-- The item that buys one death. Named here rather than read from a config table because there is exactly one
-- of them and this is the only code that cares.
local CHARM_ITEM = "GuardianCharm"

-- Spends one charm if the player is carrying one. Returns true when the death was paid for, which the caller
-- reads as "skip both resets".
--
-- Removing it FIRST and only then reporting success means a failed removal cannot hand out a free life: if
-- the slot has gone between finding it and taking it, nothing is spent and nothing is saved.
local function spendCharm(player)
	local index = Inventory.FindSlotById(player, CHARM_ITEM)
	if not index then return false end
	-- **หัวแดง = เครื่องรางไม่ทำงาน** (ผู้ใช้สั่ง 2026-09-25) — ไม่แตกด้วย (ของยังอยู่ ใช้ได้ตอนหัวไม่แดง)
	if Classes.IsMarked(player) then
		Remotes.SocialNotify:FireClient(player, "warn",
			"หัวแดงอยู่ — เครื่องรางคุ้มครองไม่ทำงาน เลเวลและอาชีพรีเซ็ต")
		return false
	end
	if not Inventory.RemoveFromSlot(player, index, 1) then return false end

	Remotes.SocialNotify:FireClient(player, "info",
		"เครื่องรางคุ้มครองแตก — เลเวลและอาชีพของคุณปลอดภัย")
	return true
end

PlayerJoin.Each(function(player)
	-- Wait for the profile session, so a returning player is restored at their saved level rather than flashing
	-- level 1. No deadline: giving up early started them at level 1, and the autosave then wrote THAT down as
	-- their level. See ProfileAccess.Wait.
	local data = ProfileAccess.Wait(player)
	local saved = data and data.Progression
	Progression.Add(player, saved)

	-- Shared by CharacterAdded and by a character that already exists when this runs. Missing the second case
	-- left the very first character with no death hook at all, so the first death never cost a level.
	local function setUpCharacter(character)
		local humanoid = character:WaitForChild("Humanoid")

		-- Every death resets the level, whatever killed the player. Hooked to Humanoid.Died rather than to
		-- Vitals.Kill because a player can die by paths that never call it — drowning, the void, falling, or
		-- being killed by another player — and each of those must cost the level too.
		humanoid.Died:Connect(function()
			-- ตายบนเกาะฟาร์มมิ่งไม่เสียอะไร (ผู้ใช้สั่ง 2026-09-28 · มอนบุกกลางคืน) — ไม่ลดเลเวล ไม่ถอดอาชีพ
			-- ไม่ใช้เครื่องราง · ทุกทางที่ตาย (มอน จมน้ำ ตก) และทุกคนในเซิร์ฟ (เจ้าของ + แขก)
			if ServerConfig.IsFarm then return end

			-- The charm is spent BEFORE either reset runs, and spending it cancels both. Checked here rather
			-- than inside ResetOnDeath so the two systems stay ignorant of inventory -- and so there is one
			-- place that decides what a death costs, which is the whole reason both resets live on this hook.
			if spendCharm(player) then return end

			Progression.ResetOnDeath(player)
			-- The class goes with the level, and for the same reason: the card is offered at "level 5 with no
			-- basic class", so a player who kept theirs through a death would never be asked again. Hooked
			-- here rather than in a second Died listener of its own -- one death, one place that decides what
			-- a death costs.
			Classes.ResetOnDeath(player)
		end)

		-- Scale and tag have to be re-applied every respawn: the character is rebuilt from scratch.
		Progression.Refresh(player, character)
	end

	player.CharacterAdded:Connect(setUpCharacter)
	if player.Character then
		task.spawn(setUpCharacter, player.Character)
	end
end)

Players.PlayerRemoving:Connect(function(player)
	Progression.Remove(player)
end)
