-- read-only: proves the modelkit chain and the model files load in this place, and lists what
-- builders are available for 55_town_buildings to place. Creates nothing.
local names = {}
for name in pairs(K.builders) do names[#names + 1] = name end
table.sort(names)
local root = workspace:FindFirstChild("WOLD")
if root then
  root:SetAttribute("Status", "done")
  root:SetAttribute("Progress", "probe_models done: " .. #names .. " builders")
end
return ("builders (%d): %s"):format(#names, table.concat(names, ", "))
