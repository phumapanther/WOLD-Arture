-- 111_story_cargo_truck: รถคาร์โก้สำหรับคัทซีน "เกาะลอยฟ้าแห่งความฝัน" (เพลสหลัก · 2026-09-29)
-- รัน: node tools/run-luau.js mapgen/111_story_cargo_truck.lua --no-lib --furniture
-- โมเดลคัดลอกจาก Car_Cargo บนเกาะ (assets/models-from-main/cargo_truck.lua) → ReplicatedStorage.WOLD_Cutscene.CargoTruck
-- ไคลเอนต์โคลนไปเล่นเองคนเดียว · ชนไม่ได้ · ReplicatedStorage มี $ignoreUnknownInstances Rojo จึงไม่ลบ
local RS = game:GetService("ReplicatedStorage")
local build = _G.WOLD_MAIN_MODELS and _G.WOLD_MAIN_MODELS.cargo_truck
if not build then error("ต้องรันด้วย --furniture") end
local folder = RS:FindFirstChild("WOLD_Cutscene")
if not folder then
	folder = Instance.new("Folder")
	folder.Name = "WOLD_Cutscene"
	folder.Parent = RS
end
local old = folder:FindFirstChild("CargoTruck")
if old then old:Destroy() end
local truck = build()
truck.Name = "CargoTruck"
local n = 0
for _, p in ipairs(truck:GetDescendants()) do
	if p:IsA("BasePart") then
		p.CanCollide, p.CanQuery, p.CanTouch = false, false, false
		n += 1
	end
end
truck.Parent = folder
local _, size = truck:GetBoundingBox()
return ("CargoTruck %d ชิ้น · กว้าง %.1f สูง %.1f ยาว %.1f"):format(n, size.X, size.Y, size.Z)
