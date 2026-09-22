-- 91_island_setup.lua: ของตายตัวบนเกาะ = NPC ร้าน (บาร์นาบี) ตัวเดียว ห่างจุดเกิด 22 studs หันหน้าเข้าหาจุดเกิด
--
--     WOLD_PLACE=136992335889132 node tools/run-luau.js mapgen/91_island_setup.lua --kit --models --no-lib
--
-- รันซ้ำได้: ลบ WOLD_Island.Fixed เดิมทิ้งแล้วสร้างใหม่ (ไม่แตะ WOLD_Island.Placed ซึ่งเป็นของผู้เล่น)
local CollectionService = game:GetService("CollectionService")

local function status(msg, done)
	local f = workspace:FindFirstChild("WOLD")
	if not f then f = Instance.new("Folder"); f.Name = "WOLD"; f.Parent = workspace end
	f:SetAttribute("Progress", msg)
	f:SetAttribute("Status", done and "done" or "running")
	print("[IslandSetup] " .. msg)
end

local island = workspace:FindFirstChild("WOLD_Island")
if not island then island = Instance.new("Folder"); island.Name = "WOLD_Island"; island.Parent = workspace end
local fixed = island:FindFirstChild("Fixed")
if fixed then fixed:Destroy() end
fixed = Instance.new("Folder"); fixed.Name = "Fixed"; fixed.Parent = island

local function groundAt(x, z)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { workspace.Terrain }
	local hit = workspace:Raycast(Vector3.new(x, 900, z), Vector3.new(0, -300, 0), params)
	return hit and hit.Position.Y
end

local spawnLoc = workspace:FindFirstChildWhichIsA("SpawnLocation", true)
local sx, sz = spawnLoc and spawnLoc.Position.X or 0, spawnLoc and spawnLoc.Position.Z or 0
local nx, nz = sx, sz - 22
local ground = groundAt(nx, nz) or 817
-- โมเดลหันหน้า -Z · NPC อยู่ทางเหนือของจุดเกิด จึงหมุน 180° ให้หันมาทาง +Z (หาจุดเกิด)
local npc = K.place("Merchant_Barnaby", fixed, CFrame.new(nx, ground, nz) * K.yaw(math.pi))
assert(npc, "ไม่มี builder Merchant_Barnaby (ลืม --models?)")
for _, p in ipairs(npc:GetDescendants()) do
	if p:IsA("ProximityPrompt") then p:Destroy() end -- ปุ่มตกแต่งของ kit; Shop.server ใส่ปุ่มจริงเองตอนเห็นแท็ก
end
npc:SetAttribute("NpcKind", "shop")
npc:SetAttribute("NpcName", "บาร์นาบี")
CollectionService:AddTag(npc, "WOLD_Npc")

status(("done: บาร์นาบีที่ (%.0f, %.1f, %.0f)"):format(nx, ground, nz), true)
