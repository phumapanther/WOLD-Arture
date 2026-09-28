local RS, SG = game:GetService("ReplicatedStorage"), game:GetService("StarterGui")
local removed = {}
for _, pair in ipairs({ { RS, "UI_QA" }, { SG, "QA_Host" }, { SG, "QA_Out" }, { SG, "QA_Probe" } }) do
	for _, c in ipairs(pair[1]:GetChildren()) do
		if c.Name == pair[2] then c:Destroy(); removed[#removed + 1] = pair[2] end
	end
end
_G.QA, _G.QA_PLAYER, _G.QA_PARENT, _G.QA_RES = nil, nil, nil, nil
local left = {}
for _, c in ipairs(RS:GetChildren()) do if c.Name:find("QA") then left[#left + 1] = c:GetFullName() end end
for _, c in ipairs(SG:GetChildren()) do if c.Name:find("QA") then left[#left + 1] = c:GetFullName() end end
return "removed: " .. table.concat(removed, ",") .. " | left: " .. (#left == 0 and "none" or table.concat(left, ","))
