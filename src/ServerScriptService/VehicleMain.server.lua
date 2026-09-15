-- VehicleMain — จุดสตาร์ตของระบบพาหนะทั้งหมด
--
-- ยกมาจากโปรเจ็ค WOLD-Vehicle แล้วต่อเข้ากับระบบของเกมหลัก สิ่งที่ต่างจากต้นทางมีสามอย่าง:
--
--   1. **กุญแจเป็นไอเทมในกระเป๋า** ไม่ใช่ Tool ที่ระบบสร้างแจกเอง ต้นทางสร้าง Tool รูปกุญแจให้ทุกทะเบียนแล้ว
--      คอยเช็กว่าหายไปหรือยัง ที่นี่ ItemCatalog มี CarKey / BoatKey / AirshipKey อยู่แล้ว และ Inventory
--      รองรับ `meta` ต่อชิ้นอยู่แล้ว กุญแจจึงเป็นของจริงที่ยกให้เพื่อน แลก หรือทำหล่นได้ ด้วยระบบที่มีอยู่
--   2. **NPC คือบารอนเวน** ตัวที่ผู้ใช้วางไว้ในแมพ (แท็ก WOLD_Npc, NpcKind = "vehicle") ไม่ใช่หุ่นพาร์ทที่
--      ระบบปั้นขึ้นเอง ส่วนจุดเรียกสามจุด (รถ/เรือ/เรือเหาะ) ยังเป็นแท่นเรียกที่ระบบสร้าง
--   3. **มีค่าเบิก/ค่าฝาก** คิดตามระยะจากบารอนเวน ดู Config.Fee
local ServerConfig = require(game.ServerScriptService.ServerConfig)

if ServerConfig.IsLobby then return end

local Config = require(game.ReplicatedStorage.Vehicle.Config)
local Net = require(game.ReplicatedStorage.Vehicle.Net)
local Store = require(game.ServerScriptService.Vehicle.Store)
local VehicleService = require(game.ServerScriptService.Vehicle.Service)
local Stations = require(game.ServerScriptService.Vehicle.Stations)
local Inventory = require(game.ServerScriptService.Inventory)

local net = Net.get()

Store.start()
VehicleService.init(net.Signal)

-- ---------------------------------------------------------------- แผงโรงรถ
-- ราคาที่แสดงบนแผงคำนวณที่เซิร์ฟเวอร์เสมอ ไคลเอนต์ไม่เคยคิดเงินเอง และไม่มีตัวเลขอะไรให้โกหก
local function garagePayload(player, station)
  local retrieveFee, retrieveStuds = 0, 0
  if station then
    local spawnAt = station.resolvedSpawn or station.spawn
    retrieveFee, retrieveStuds = VehicleService.quote("retrieve", spawnAt)
  end

  return {
    ok = true,
    action = "Garage",
    station = station and { id = station.id, vtype = station.vtype, title = station.title, npc = station.npc } or nil,
    vtype = station and station.vtype or nil,
    display = station and Config.Types[station.vtype].display or nil,
    vehicles = VehicleService.list(player, station and station.vtype or nil),
    canRegister = Config.FreeRegister,
    -- ราคาบริการของ NPC ส่งไปให้แผงเขียนบอกบนปุ่ม ไม่ใช่ให้รู้ตอนโดนหักเงินไปแล้ว — กติกาเดียวกับค่าเบิก
    serviceRefuel = Config.Service.Refuel,
    serviceRepair = Config.Service.Repair,
    -- ค่าบริการของจุดนี้ ส่งลงไปให้แผงเขียนบอกก่อนกด ไม่ใช่ให้รู้ตอนโดนหักเงินไปแล้ว
    retrieveFee = retrieveFee,
    retrieveStuds = math.floor(retrieveStuds),
    -- เงินในกระเป๋าตอนนี้ ส่งไปด้วยเพื่อให้แผงเทียบกับค่าบริการได้เอง
    gold = (function()
      local state = Inventory.Get(player)
      return state and state.gold or 0
    end)(),
  }
end

local handlers = {}

function handlers.Garage(player, msg)
  local station = msg.stationId and Stations.get(msg.stationId) or nil
  return garagePayload(player, station)
end

-- จดทะเบียนกุญแจที่ถืออยู่ รับทะเบียนมาจากแถวที่กด ไม่ใช่ชนิดพาหนะ — ชนิดอ่านออกจากทะเบียนเองได้ และ
-- VehicleService ตรวจซ้ำว่ากุญแจดอกนั้นอยู่ในกระเป๋าจริงก่อนจะจดให้
function handlers.Register(player, msg)
  local station = msg.stationId and Stations.get(msg.stationId) or nil
  local plate, err = VehicleService.register(player, msg.plate, msg.name)
  if not plate then return { ok = false, err = err } end
  local payload = garagePayload(player, station)
  payload.toast = "📜 จดทะเบียน " .. plate .. " เรียบร้อย เป็นพาหนะของคุณแล้ว"
  return payload
end

function handlers.Summon(player, msg)
  local station = msg.stationId and Stations.get(msg.stationId) or nil
  if not station then
    -- เบิกจากบารอนเวน: ส่งไปลงลานจอดที่ตรงชนิด เรียกเรือขึ้นมาข้างตัว NPC กลางเมืองคือเรือที่แล่นไม่ได้
    -- และไม่บังคับว่าต้องยืนใกล้ลานจอด เพราะคนยืนอยู่ตรงหน้า NPC ไม่ใช่ตรงท่าเรือ
    -- **ลานจอดที่ใกล้ผู้เรียกที่สุด** ตามที่ผู้ใช้สั่ง วัดจากตัวผู้เล่น ไม่ใช่จากตัว NPC: วันที่มีโรงรถ
    -- หลายแห่งต่อชนิด คนยืนอยู่หน้าโรงรถไหนก็ควรได้รถออกมาที่โรงรถนั้น และเป็นจุดที่ค่าเบิกถูกที่สุดด้วย
    local char = player.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    local found = Stations.nearestForType(VehicleService.typeOfPlate(msg.plate), root and root.Position)
    if found then
      station = table.clone(found)
      station.requireNear = false
    end
  end
  local ok, result = VehicleService.summon(player, msg.plate, station)
  if not ok then return { ok = false, err = result } end
  local payload = garagePayload(player, station)
  local fee = type(result) == "table" and result.fee or 0
  payload.toast = fee > 0
    and string.format("🚂 เบิก %s ออกมาแล้ว ค่าบริการ %d เหรียญ", msg.plate, fee)
    or ("🚂 เบิก " .. msg.plate .. " ออกมาแล้ว")
  return payload
end

function handlers.Stow(player, msg)
  local ok, result = VehicleService.stow(msg.plate, player)
  if not ok then return { ok = false, err = result } end
  local station = msg.stationId and Stations.get(msg.stationId) or nil
  local payload = garagePayload(player, station)
  local fee = tonumber(result) or 0
  payload.toast = fee > 0
    and string.format("🏠 ฝาก %s เข้าโรงเก็บแล้ว ค่าบริการ %d เหรียญ", msg.plate, fee)
    or ("🏠 ฝาก " .. msg.plate .. " เข้าโรงเก็บแล้ว")
  return payload
end

function handlers.Lock(player, msg)
  local ok, err = VehicleService.setLock(player, msg.plate, msg.locked and true or false)
  if not ok then return { ok = false, err = err } end
  local station = msg.stationId and Stations.get(msg.stationId) or nil
  local payload = garagePayload(player, station)
  payload.toast = (msg.locked and "🔒 ล็อก " or "🔓 ปลดล็อก ") .. msg.plate .. " แล้ว"
  return payload
end

function handlers.Refuel(player, msg)
  local ok, result = VehicleService.refuel(player, msg.plate)
  if not ok then return { ok = false, err = result } end
  local station = msg.stationId and Stations.get(msg.stationId) or nil
  local payload = garagePayload(player, station)
  payload.toast = "🔥 " .. msg.plate .. " " .. tostring(result) .. " เรียบร้อย"
  return payload
end

-- บริการของบารอนเวน ทั้งคู่ต้องฝากรถไว้ก่อน และคิดเป็นเงิน ดูเหตุผลที่ Config.Service
function handlers.ServiceRefuel(player, msg)
  local ok, result = VehicleService.serviceRefuel(player, msg.plate)
  if not ok then return { ok = false, err = result } end
  local payload = garagePayload(player, msg.stationId and Stations.get(msg.stationId) or nil)
  payload.toast = ("🔥 เติมถ่านเต็มถังให้ %s แล้ว ค่าบริการ %d เหรียญ"):format(msg.plate, result)
  return payload
end

function handlers.ServiceRepair(player, msg)
  local ok, result = VehicleService.serviceRepair(player, msg.plate)
  if not ok then return { ok = false, err = result } end
  local payload = garagePayload(player, msg.stationId and Stations.get(msg.stationId) or nil)
  payload.toast = ("🔧 ซ่อม %s กลับมาเต็มแล้ว ค่าบริการ %d เหรียญ"):format(msg.plate, result)
  return payload
end

function handlers.Trunk(player, msg)
  local payload, err = VehicleService.trunkState(player, msg.plate)
  if not payload then return { ok = false, err = err } end
  payload.ok = true
  return payload
end

function handlers.Move(player, msg)
  local payload, err = VehicleService.moveItem(player, msg.plate, msg.item, msg.count, msg.toTrunk and true or false)
  if not payload then return { ok = false, err = err } end
  payload.ok = true
  return payload
end

net.Request.OnServerInvoke = function(player, msg)
  if type(msg) ~= "table" or type(msg.action) ~= "string" then return { ok = false, err = "คำสั่งไม่ถูกต้อง" } end
  local fn = handlers[msg.action]
  if not fn then return { ok = false, err = "ไม่รู้จักคำสั่ง " .. msg.action } end
  local ok, result = pcall(fn, player, msg)
  if not ok then
    warn("[VehicleMain] " .. msg.action .. " ล้ม: " .. tostring(result))
    return { ok = false, err = "ระบบขัดข้อง" }
  end
  return result
end

-- อินพุตต่อเนื่องที่เบาะไม่มีให้: ขึ้น/ลงของเรือเหาะ
net.Signal.OnServerEvent:Connect(function(player, msg)
  if type(msg) ~= "table" then return end
  if msg.action == "Lift" then
    VehicleService.setLift(player, tonumber(msg.value) or 0)
  elseif msg.action == "Aim" then
    VehicleService.setAim(player, tonumber(msg.value) or 0)
  elseif msg.action == "Boost" then
    VehicleService.setBoost(player, msg.value and true or false)
  elseif msg.action == "Horn" then
    VehicleService.horn(player)
  end
end)

-- ---------------------------------------------------------------- จุดเรียก + บารอนเวน
Stations.build(function(player, info)
  net.Signal:FireClient(player, garagePayload(player, info))
end)

print("[VehicleMain] ระบบพาหนะพร้อมใช้งาน v" .. Config.Version)
