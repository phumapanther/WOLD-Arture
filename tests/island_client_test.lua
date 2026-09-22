-- Play ในเพลส Farming → WOLD_PLACE=136992335889132 node tools/lua.js tests/island_client_test.lua Client
local RS = game.ReplicatedStorage
local starter = RS:FindFirstChild("WOLD_StartPlacing")
assert(starter, "IslandBuildController ไม่ได้รัน (IslandMode ไม่ใช่ true?)")
starter:Fire(1, "Deco_Fence")
task.wait(0.3)
local folder = assert(workspace:FindFirstChild("IslandGhost"), "ไม่มี ghost")
local squares = 0
for _, c in ipairs(folder:GetChildren()) do if c:IsA("Part") then squares += 1 end end
assert(folder:FindFirstChild("Ghost"), "ไม่มีโมเดล ghost")
assert(squares == 1, "รั้ว 1x1 ต้องมี 1 ช่อง ได้ " .. squares)
starter:Fire(1, "FarmPlot")
task.wait(0.3)
folder = assert(workspace:FindFirstChild("IslandGhost"), "ghost แปลง")
squares = 0
for _, c in ipairs(folder:GetChildren()) do if c:IsA("Part") then squares += 1 end end
assert(squares == 4, "แปลง 2x2 ต้องมี 4 ช่อง ได้ " .. squares)
local gui = game.Players.LocalPlayer.PlayerGui:FindFirstChild("IslandBuildGui")
assert(gui and gui.Enabled, "แถบไม่ขึ้น")
starter:Fire(nil)
task.wait(0.2)
assert(not workspace:FindFirstChild("IslandGhost"), "ยกเลิกแล้ว ghost ต้องหาย")
assert(not gui.Enabled, "ยกเลิกแล้วแถบต้องซ่อน")
return "client ok"
