-- Vehicle/Net — ช่องทางคุยกันระหว่างไคลเอนต์กับเซิร์ฟเวอร์ ทุกอย่างผ่านสองตัวนี้เท่านั้น
--   Request (RemoteFunction) : ไคลเอนต์ขอให้ทำอะไรสักอย่าง แล้วรอคำตอบ { ok = bool, err = string, ... }
--   Signal  (RemoteEvent)    : เซิร์ฟเวอร์เด้งข้อความ/สถานะให้ไคลเอนต์ และไคลเอนต์ส่งอินพุตต่อเนื่อง (คันบังคับเรือเหาะ)
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = {}
local FOLDER = "VehicleNet"

local function ensure(class, name, parent)
  local found = parent:FindFirstChild(name)
  if found then return found end
  local inst = Instance.new(class)
  inst.Name = name
  inst.Parent = parent
  return inst
end

function Net.get()
  if RunService:IsServer() then
    local folder = ensure("Folder", FOLDER, ReplicatedStorage)
    return {
      Request = ensure("RemoteFunction", "Request", folder),
      Signal = ensure("RemoteEvent", "Signal", folder),
    }
  end
  local folder = ReplicatedStorage:WaitForChild(FOLDER, 30)
  assert(folder, "VehicleNet หาย — เซิร์ฟเวอร์ยังไม่ได้ติดตั้งระบบพาหนะ") -- locale: skip (assert)
  return {
    Request = folder:WaitForChild("Request", 30),
    Signal = folder:WaitForChild("Signal", 30),
  }
end

return Net
