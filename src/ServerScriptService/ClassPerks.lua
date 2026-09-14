-- ClassPerks: the one standing benefit each class carries, in one place.
--
-- Every perk here is a passive -- it is true for as long as the class is held, and no player action turns it
-- on. That is what separates these from ClassActions, which is the menu of things a class can DO.
--
-- They live together rather than as seven conditions scattered through seven systems, because otherwise the
-- answer to "what does a Rogue actually get?" is a grep. The systems still own their own arithmetic; they
-- just ask here whether this player is an exception.
--
-- Classes is safe to require from anywhere on the server: it pulls in only ClassConfig and ProfileAccess,
-- so it cannot close a cycle back through combat, vitals or progression.
local ClassConfig = require(game.ReplicatedStorage.ClassConfig)
local Classes = require(script.Parent.Classes)

local ClassPerks = {}

-- The table itself lives in ClassConfig, which both sides can see: the class card shows a player what a
-- class gives before they pick it, and this file decides what that actually does. One copy, so the promise
-- and the behaviour cannot drift apart.
ClassPerks.Perks = ClassConfig.Perks

-- Which class grants which perk, built once from the table above so the two can never disagree.
local GrantedBy = {}
for classId, perk in pairs(ClassPerks.Perks) do
	if perk then GrantedBy[perk.id] = classId end
end

-- Does this player have the named perk?
--
-- Asked by id rather than by class so a system says what it wants rather than who it is checking for -- a
-- reader of PlayerCombat should not have to know that "Rogue" is the one with the damage.
function ClassPerks.Has(player, perkId)
	local classId = GrantedBy[perkId]
	if not classId then return false end
	return Classes.Has(player, classId)
end

-- Perk-shaped helpers, so the calling code reads as arithmetic rather than as a class check.

-- Experience earned, after the adventurer's doubling.
function ClassPerks.ExpFor(player, amount)
	return ClassPerks.Has(player, "doubleExp") and amount * 2 or amount
end

-- How many of a gathered item to hand over, after the merchant's doubling.
function ClassPerks.HarvestFor(player, count)
	return ClassPerks.Has(player, "doubleHarvest") and count * 2 or count
end

-- Damage dealt, after the rogue's doubling. Takes the ATTACKER, not the victim.
function ClassPerks.DamageFor(attacker, amount)
	if not attacker then return amount end
	return ClassPerks.Has(attacker, "doubleDamage") and amount * 2 or amount
end

-- The perk table for a class, for the card that tells a player what they chose.
function ClassPerks.Of(classId)
	return classId and ClassPerks.Perks[classId] or nil
end

return ClassPerks
