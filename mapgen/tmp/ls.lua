local sps = game.StarterPlayer.StarterPlayerScripts
local c = sps:FindFirstChild("VehicleRepairController")
if not c then return "ยังไม่มี VehicleRepairController" end
return ("VehicleRepairController เข้าแล้ว: %s %d bytes | หาปุ่มถูกชื่อ=%s | ลูป 0.5 วิ=%s"):format(
  c.ClassName, #c.Source,
  tostring(c.Source:find("VehicleRepairPrompt", 1, true) ~= nil),
  tostring(c.Source:find("task.wait(0.5)", 1, true) ~= nil))
