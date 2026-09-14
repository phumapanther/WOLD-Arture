-- 64_ore_nodes.lua: turns the ore models the user placed by hand into gathering nodes.
--
-- The user drops Ore_Iron / Ore_Crystal / Ore_Coal models into the world wherever they want mining to
-- happen. This phase finds them by NAME and tags them, which is all the gathering system needs: it works
-- entirely off the WOLD_Node tag plus a NodeKind attribute naming an entry in GatherConfig.Nodes.
--
-- Safe to re-run. Tagging something already tagged is a no-op, so the user can place more ore and run this
-- again without touching what is already there -- and nothing here creates or destroys a single model, so
-- there is no phase folder to lose.
local CollectionService = game:GetService("CollectionService")

-- Model name in the world -> NodeKind in GatherConfig. Everything else about the node -- what it drops, how
-- long it takes, that it needs a pickaxe -- lives in the config, not here.
local ORE_KINDS = {
	Ore_Iron = "IronOre",
	Ore_Crystal = "Crystal",
	Ore_Coal = "Coal",
}

local counts, total, already = {}, 0, 0

for _, descendant in ipairs(workspace:GetDescendants()) do
	local kind = ORE_KINDS[descendant.Name]
	-- Models and parts both: the user may have placed a single rock part or a whole model, and either is a
	-- perfectly good thing to swing a pickaxe at.
	if kind and (descendant:IsA("Model") or descendant:IsA("BasePart")) then
		if CollectionService:HasTag(descendant, "WOLD_Node") then
			already += 1
		else
			total += 1
		end
		descendant:SetAttribute("NodeKind", kind)
		CollectionService:AddTag(descendant, "WOLD_Node")
		counts[descendant.Name] = (counts[descendant.Name] or 0) + 1
	end
end

local parts = {}
for name, n in pairs(counts) do
	parts[#parts + 1] = ("%s=%d"):format(name, n)
end
table.sort(parts)

print(("[OreNodes] tagged %d new (%d already tagged): %s")
	:format(total, already, #parts > 0 and table.concat(parts, " ") or "ไม่เจอโมเดลแร่เลย"))
