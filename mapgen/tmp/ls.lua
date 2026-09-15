local out = {}
local ic = game.ReplicatedStorage.ItemCatalog.Source
out[#out+1] = "ชื่อหีบไม้กลับมา=" .. tostring(ic:find('name = "หีบไม้"', 1, true) ~= nil)
out[#out+1] = "เครื่องราง icon=" .. tostring(ic:find("107664753644079", 1, true) ~= nil)
local cc = game.ReplicatedStorage.CombatConfig.Source
out[#out+1] = "สมุดเวทมึน 1 วิ=" .. tostring(cc:find('effect = "dizzy", effectSeconds = 1', 1, true) ~= nil)
out[#out+1] = "คฑาสโลว์ 90%=" .. tostring(cc:find("effectFactor = 0.1", 1, true) ~= nil)
local ac = game.ServerScriptService.AdminCommands.Source
out[#out+1] = "/fw=" .. tostring(ac:find("Commands.fw = function", 1, true) ~= nil)
out[#out+1] = "Fireworks module=" .. tostring(game.ServerScriptService:FindFirstChild("Fireworks") ~= nil)
local pp = game.ServerScriptService.PlayerProgression.Source
out[#out+1] = "เครื่องรางกันตาย=" .. tostring(pp:find("spendCharm", 1, true) ~= nil)
return table.concat(out, "\n")
