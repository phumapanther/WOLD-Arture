local ok, res = pcall(function() return game:GetService("InsertService"):LoadAsset(116009846089971) end)
if not ok then return "ล้มเหลว: " .. tostring(res):sub(1,80) end
for _, d in ipairs(res:GetDescendants()) do
  if d:IsA("Decal") or d:IsA("Texture") then local t = d.Texture; res:Destroy(); return "ภาพจริง = " .. t end
end
res:Destroy(); return "ไม่เจอ"
