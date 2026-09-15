-- The OLD behaviour: "take all" fired ChestClose to the client but never cleared Viewing.
local Viewing, Live = {}, {}
local P = "PLAYER"
local function openChest(model)
  local st = Live[model]
  if st.viewer and st.viewer ~= P then return "คนอื่นเปิดอยู่" end
  if Viewing[P] and Viewing[P] ~= model then return "ติดค้าง เปิดไม่ได้ <- บั๊ก" end
  st.viewer = P; Viewing[P] = model
  return "เปิดได้"
end
local out = {}
Live["c1"] = { loot = {{id="Stone"}}, viewer = nil }
out[#out+1] = "หีบ1: " .. openChest("c1")
-- old take-all: empties the loot, tells the client, and stops. Viewing[P] still = c1
Live["c1"].loot = {}
Live["c2"] = { loot = {{id="Coal"}}, viewer = nil }
out[#out+1] = "หีบ2 (โค้ดเดิม): " .. openChest("c2")
return table.concat(out, "\n")
