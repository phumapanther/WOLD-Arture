-- VehicleService — หัวใจของระบบ: ทะเบียน กุญแจ การเรียก/ฝาก ล็อก และท้ายพาหนะ
--
-- กติกาที่โจทย์กำหนด (อ่านซ้ำก่อนแก้ตรรกะข้างล่าง):
--   * ทุกคนขับได้และเปิดดูของได้ "ตราบใดที่ยังไม่ถูกล็อก"  → พาหนะเกิดมาแบบ **ปลดล็อก**
--   * คนที่ถือกุญแจของทะเบียนนั้นเท่านั้น ที่สั่งล็อก/ปลดล็อก และเรียกพาหนะออกมาได้
--   * ถูกล็อกแล้ว: คนไม่มีกุญแจนั่งไม่ได้ (ทั้งเบาะคนขับและเบาะซ้อน) และเปิดท้ายไม่ได้
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(game.ReplicatedStorage.Vehicle.Config)
local Models = require(game.ServerScriptService.Vehicle.Models)
local Chassis = require(game.ServerScriptService.Vehicle.Chassis)
local Drive = require(game.ServerScriptService.Vehicle.Drive)
local Store = require(game.ServerScriptService.Vehicle.Store)
local ItemCatalog = require(game.ReplicatedStorage.ItemCatalog)
local Inventory = require(game.ServerScriptService.Inventory)
local Classes = require(game.ServerScriptService.Classes)
local CollectionService = game:GetService("CollectionService")

local VehicleService = {}
VehicleService.Active = {}                  -- plate -> record ของคันที่อยู่ในโลกตอนนี้
VehicleService.Drivers = {}                 -- userId -> record ของคันที่คนนั้นกำลังขับ
local Signal                                 -- RemoteEvent ใช้เด้งข้อความหาไคลเอนต์ (ตั้งค่าจาก init)

local PREFIX_TO_TYPE = {}
for vtype, spec in pairs(Config.Types) do PREFIX_TO_TYPE[spec.prefix] = vtype end

local function notify(player, text, kind)
  if Signal and player then Signal:FireClient(player, { action = "Toast", text = text, kind = kind or "info" }) end
end

local function folder()
  local f = workspace:FindFirstChild(Config.Folder)
  if not f then
    f = Instance.new("Folder")
    f.Name = Config.Folder
    f.Parent = workspace
  end
  return f
end

function VehicleService.typeOfPlate(plate)
  return PREFIX_TO_TYPE[tostring(plate):sub(1, 3)]
end

-- ---------------------------------------------------------------- ทะเบียน + กุญแจ
local function freshPlate(vtype)
  local spec = Config.Types[vtype]
  for _ = 1, 50 do
    local plate = string.format("%s-%04d", spec.prefix, math.random(1000, 9999))
    if not VehicleService.Active[plate] then return plate end
  end
  return string.format("%s-%d", spec.prefix, os.time() % 100000)
end

-- ---------------------------------------------------------------- สองขั้นตอน: ได้กุญแจ แล้วค่อยจด
--
-- เดิมเป็นก้าวเดียว — กดปุ่มที่บารอนเวนแล้วได้ทั้งทะเบียนและกุญแจพร้อมกัน ผู้ใช้สั่งให้แยก: **ต้องมีไอเทม
-- กุญแจที่มีทะเบียนติดมาอยู่ในกระเป๋าก่อน ถึงจะกดจดทะเบียนได้** กุญแจจึงกลายเป็นของที่ต้องหามาให้ได้ ไม่ใช่
-- ผลพลอยได้ของการกดปุ่ม
--
-- ตอนนี้ที่ผลิตกุญแจมีสองทาง (ผู้ใช้เลือกไว้ว่ายังไม่ผูกเศรษฐกิจ): หีบทดสอบ และคำสั่งแอดมิน `/veh key`
-- วันที่บารอนเวนขายกุญแจหรือช่างตีเหล็กคราฟได้ ก็เรียก issueKey ตัวนี้เพิ่มอีกที่ ไม่ต้องแก้ตรรกะการจด

-- ทะเบียนนี้มีเจ้าของแล้วหรือยัง ในสายตาของผู้เล่นคนนี้
--
-- ถามสามทางเพราะเกมไม่มีทะเบียนกลางของทั้งเซิร์ฟเวอร์ และแต่ละทางครอบคลุมคนละกรณีที่อีกสองทางตอบไม่ได้:
--   * อยู่ในตารางพาหนะของตัวเอง — เจ้าของตัวจริง และครอบคลุมกุญแจเก่าที่ออกมาก่อนจะมีธงนี้ด้วย
--   * ธงบนกุญแจในกระเป๋า       — กุญแจที่ยืมมา ไม่ว่าเจ้าของจะออนไลน์อยู่หรือไม่
--   * เจ้าของที่ออนไลน์อยู่      — กุญแจเก่าที่ยืมมา ซึ่งยังไม่มีธงติด
function VehicleService.isRegistered(player, plate)
  local profile = Store.get(player)
  if profile and profile.Data.Vehicles[plate] then return true end
  if Store.isRegisteredKey(player, plate) then return true end
  return (Store.ownerOf(plate)) ~= nil
end

-- ทำกุญแจดอกใหม่: ได้ทะเบียนสดๆ ติดกุญแจมาด้วย แต่ **ยังไม่ใช่พาหนะของใคร** จนกว่าจะเอาไปจด
function VehicleService.issueKey(player, vtype)
  local spec = Config.Types[vtype]
  if not spec then return nil, "ไม่รู้จักพาหนะชนิดนี้" end

  local plate = freshPlate(vtype)
  local ok, err = Store.giveKey(player, plate)
  if not ok then return nil, err or "แจกกุญแจไม่สำเร็จ" end
  return plate
end

-- จดทะเบียนพาหนะจากกุญแจที่ถืออยู่ รับ **ทะเบียน** ไม่ใช่ชนิด: ชนิดอ่านออกจากทะเบียนได้อยู่แล้ว และการรับ
-- ชนิดมาจะเปิดช่องให้ไคลเอนต์ขอจดอะไรก็ได้ที่ไม่ตรงกับกุญแจในมือ
function VehicleService.register(player, plate, name)
  if not Config.FreeRegister then return nil, "ยังเปิดให้จดทะเบียนไม่ได้" end
  local profile = Store.get(player)
  if not profile then return nil, "ข้อมูลผู้เล่นยังโหลดไม่เสร็จ" end

  plate = tostring(plate or ""):upper()
  local vtype = VehicleService.typeOfPlate(plate)
  local spec = vtype and Config.Types[vtype]
  if not spec then return nil, "ทะเบียนนี้อ่านไม่ออก" end

  -- ต้องถือกุญแจของทะเบียนนี้จริงๆ ตรวจจากกระเป๋าฝั่งเซิร์ฟเวอร์ ไม่ใช่เชื่อทะเบียนที่ไคลเอนต์ส่งมา
  if not Store.hasKey(player, plate) then
    return nil, "ต้องมีกุญแจของทะเบียนนี้อยู่ในกระเป๋าก่อน"
  end
  -- ของตัวเองอยู่แล้วถามก่อน เพื่อให้ได้ข้อความที่ตรงกว่าคำว่า "จดไปแล้ว" ลอยๆ
  if profile.Data.Vehicles[plate] then return nil, "ทะเบียนนี้เป็นของคุณอยู่แล้ว" end
  -- ทะเบียนหนึ่งจดได้ครั้งเดียวตลอดกาล และธงติดอยู่กับตัวกุญแจ ไม่ใช่กับคน — ยกกุญแจที่จดแล้วให้เพื่อน
  -- เพื่อนก็ยังจดไม่ได้ ซึ่งเป็นสิ่งที่ต้องการ: กุญแจที่ยืมมาไว้ขับ ไม่ใช่ไว้ยึดรถ
  if VehicleService.isRegistered(player, plate) then
    return nil, "กุญแจดอกนี้จดทะเบียนไปแล้ว"
  end

  local owned = 0
  for _, rec in pairs(profile.Data.Vehicles) do
    if rec.Type == vtype then owned += 1 end
  end
  if owned >= Config.MaxVehiclesPerType then
    return nil, string.format("มี%sครบ %d คันแล้ว", spec.display, Config.MaxVehiclesPerType)
  end

  profile.Data.Vehicles[plate] = {
    Type = vtype,
    Name = name or spec.display,
    Trunk = {},
    Locked = false,
    Born = os.time(),
  }
  -- ธงลงบนกุญแจหลังแถวทะเบียนเกิดแล้ว: ถ้าสลับกันแล้วมีอะไรพลาดกลางทาง จะเหลือกุญแจที่ถูกปิดตายทั้งที่ไม่มี
  -- รถผูกอยู่ = กุญแจตายสนิท ส่วนลำดับนี้อย่างมากได้รถที่จดซ้ำได้อีกครั้ง ซึ่งกันไว้ด้วยแถวข้างบนแล้ว
  Store.markRegistered(player, plate)
  Store.dirty(player)
  return plate
end

-- รายการที่แผง "โรงรถ" ของผู้เล่นแสดง: คันที่เป็นเจ้าของ + คันที่ถือกุญแจของคนอื่น
-- ทะเบียนที่ "ไม่มีกุญแจแล้ว" จะถูกลบทิ้ง — เสียกุญแจ = เสียรถ ตามที่ผู้ใช้สั่ง
--
-- ทำไมต้องนับคลังสินค้าด้วย: กุญแจเอาไปเก็บในคลังของมาดามออเรเลียได้ ถ้านับแค่กระเป๋า คนที่เก็บกุญแจไว้ใน
-- คลังอย่างปลอดภัยจะโดนลบรถทิ้ง ซึ่งตรงข้ามกับสิ่งที่กติกานี้ต้องการ "เสีย" จึงแปลว่า **ไม่มีอยู่ทั้งใน
-- กระเป๋าและในคลัง**
--
-- คันที่ถูกเรียกออกมาอยู่ในโลกจะถูกเก็บกลับก่อน ไม่งั้นจะเหลือรถวิ่งอยู่โดยไม่มีทะเบียนเป็นเจ้าของ
--
-- ไม่ได้ทำเป็น hook ตอนของหายจากกระเป๋า เพราะของ "ออกจากกระเป๋า" มีทั้งแบบหายจริงและแบบย้ายที่ (เข้าคลัง
-- เข้าท้ายรถ เทรด) แยกสองอย่างนั้นจากจุดนั้นไม่ได้ การกวาดตอนเปิดโรงรถถามคำถามที่ตอบได้แน่นอนกว่า คือ
-- "ตอนนี้กุญแจดอกนี้ยังมีอยู่ไหม"
local function heldPlates(player)
  local plates = Store.keyPlates(player)
  local ok, Vault = pcall(function() return require(game.ServerScriptService.Vault) end)
  local vault = ok and Vault and Vault.Get(player)
  if vault and vault.slots then
    for _, slot in pairs(vault.slots) do
      local item = slot and ItemCatalog.Get(slot.id)
      if item and item.kind == "key" and slot.meta and type(slot.meta.plate) == "string" then
        plates[slot.meta.plate] = true
      end
    end
  end
  return plates
end

function VehicleService.forgetKeyless(player)
  local profile = Store.get(player)
  if not profile then return 0 end
  local held = heldPlates(player)

  local gone = {}
  for plate in pairs(profile.Data.Vehicles) do
    if not held[plate] then table.insert(gone, plate) end
  end
  for _, plate in ipairs(gone) do
    if VehicleService.Active[plate] then VehicleService.stow(plate) end
    profile.Data.Vehicles[plate] = nil
  end
  if #gone > 0 then
    Store.dirty(player)
    print(("[Vehicle] %s เสียกุญแจ %d ดอก รถถูกลบจากโรงรถ: %s"):format(
      player.Name, #gone, table.concat(gone, ", ")))
  end
  return #gone
end

-- โอนกรรมสิทธิ์ตามกุญแจ: ยกกุญแจที่ **จดทะเบียนแล้ว** ให้ใคร คนนั้นได้รถคันนั้นเข้าโรงรถทันที
--
-- ก่อนหน้านี้กุญแจที่จดแล้วเป็นแค่ "กุญแจฝากไว้ให้ขับ" — ขับได้แต่ไม่ใช่รถของตัวเอง และแถวในโรงรถยังอยู่กับ
-- คนให้ ซึ่งแปลก: ของถูกยกให้ไปแล้วแต่ยังเป็นของคนเดิม ผู้ใช้สั่งให้กรรมสิทธิ์เดินตามกุญแจไป
--
-- ทำที่นี่ที่เดียวเพราะ "ให้ของ" มีทางเดียว (RequestGiveItem) ส่วนกุญแจที่ยังไม่จดไม่ต้องทำอะไร -- มันยังไม่ใช่
-- รถของใคร คนรับเอาไปจดเองได้อยู่แล้ว
function VehicleService.handOver(fromPlayer, toPlayer, plate)
  plate = tostring(plate or ""):upper()
  if plate == "" then return false end

  local giver = Store.get(fromPlayer)
  local record = giver and giver.Data.Vehicles[plate]
  if not record then return false end   -- ไม่ใช่รถของคนให้ ไม่มีอะไรจะโอน

  local taker = Store.get(toPlayer)
  if not taker then return false end

  -- คันที่ถูกเรียกออกมาอยู่ในโลกต้องเก็บกลับก่อน: เจ้าของเปลี่ยนแล้ว แต่ตัวรถยังจำเจ้าของเดิมไว้ในกล่องชน
  -- ของมันเอง (record.ownerId) เก็บแล้วเรียกใหม่จะได้เจ้าของถูกคน
  if VehicleService.Active[plate] then VehicleService.stow(plate) end

  taker.Data.Vehicles[plate] = record
  giver.Data.Vehicles[plate] = nil
  Store.dirty(fromPlayer)
  Store.dirty(toPlayer)
  print(("[Vehicle] %s ยกรถ %s ให้ %s"):format(fromPlayer.Name, plate, toPlayer.Name))
  return true
end

function VehicleService.list(player, vtype)
  local profile = Store.get(player)
  if not profile then return {} end
  -- กวาดก่อนวาด: แถวที่กุญแจหายไปแล้วต้องไม่โผล่มาให้กดตั้งแต่แรก
  VehicleService.forgetKeyless(player)
  local out = {}
  for plate, rec in pairs(profile.Data.Vehicles) do
    if not vtype or rec.Type == vtype then
      local active = VehicleService.Active[plate]
      local spec = Config.Types[rec.Type]
      out[#out + 1] = {
        plate = plate, vtype = rec.Type, name = rec.Name, owner = true,
        locked = rec.Locked == true, out = active ~= nil,
        key = Store.hasKey(player, plate),
        -- จดไปแล้วโดยนิยาม: แถวนี้มาจากตารางพาหนะของเจ้าตัว
        unregistered = false,
        -- ความคงทน อ่านจากคันที่อยู่ในโลกถ้ามี ไม่งั้นจากที่เซฟไว้ — สูตรเดียวกับเชื้อเพลิงบรรทัดล่าง
        durability = active and VehicleService.durabilityPercent(active)
          or (spec and spec.durability
            and math.floor((tonumber(rec.Durability) or spec.durability.max) / spec.durability.max * 100 + 0.5)) or 100,
        fuel = active and VehicleService.fuelPercent(active)
          or (spec and spec.fuel and math.floor((tonumber(rec.Fuel) or spec.fuel.max) / spec.fuel.max * 100 + 0.5)) or 100,
      }
    end
  end
  for plate in pairs(Store.keyPlates(player)) do
    if not profile.Data.Vehicles[plate] then
      local t = VehicleService.typeOfPlate(plate)
      -- A plate this system cannot read is a key to nothing -- it can never be summoned, locked or stowed.
      -- Listing it anyway gave the garage rows that did nothing when pressed, which read as the whole NPC
      -- being broken. Skipped rather than shown greyed out: there is no action that would ever work on it.
      if t and (not vtype or t == vtype) then
        local active = VehicleService.Active[plate]
        -- กุญแจที่ถืออยู่แต่ไม่ใช่รถของเรา มีสองแบบที่ต่างกันคนละเรื่อง และแผงต้องแยกให้ออก:
        --   ยังไม่ถูกจด  -> นี่คือรถที่รอเจ้าของ กดจดทะเบียนได้
        --   จดไปแล้ว     -> กุญแจของคนอื่นที่ฝากไว้ให้ขับ จดทับไม่ได้
        local unregistered = not VehicleService.isRegistered(player, plate)
        out[#out + 1] = {
          plate = plate, vtype = t, owner = false,
          name = unregistered and "ยังไม่จดทะเบียน" or "กุญแจฝาก",
          unregistered = unregistered,
          locked = active and active.model:GetAttribute("IsLocked") or false,
          out = active ~= nil, key = true,
          fuel = active and VehicleService.fuelPercent(active) or nil,
          durability = active and VehicleService.durabilityPercent(active) or nil,
        }
      end
    end
  end
  table.sort(out, function(a, b) return a.plate < b.plate end)
  return out
end

-- ---------------------------------------------------------------- สิทธิ์
function VehicleService.hasKey(player, plate)
  return Store.hasKey(player, plate)
end

-- ใครก็เข้าได้ ถ้ายังไม่ล็อก — ล็อกเมื่อไหร่เหลือแค่คนถือกุญแจ
function VehicleService.canAccess(player, record)
  if not record then return false end
  if record.model:GetAttribute("IsLocked") ~= true then return true end
  return VehicleService.hasKey(player, record.plate)
end

function VehicleService.setLock(player, plate, locked)
  local record = VehicleService.Active[plate]
  if not record then return false, "ไม่พบพาหนะทะเบียนนี้ในโลก" end
  if not VehicleService.hasKey(player, plate) then return false, "ต้องมีกุญแจถึงจะล็อกได้" end
  record.model:SetAttribute("IsLocked", locked and true or false)
  record.lastTouch = os.clock()

  local owner, data = Store.ownerOf(plate)
  if data then data.Locked = locked and true or false end
  if owner then Store.dirty(owner) end

  if locked then                                       -- ล็อกแล้วเด้งคนที่ไม่มีกุญแจลงจากรถ
    for _, seat in ipairs(record.seats) do
      local occ = seat.Occupant
      local sitter = occ and Players:GetPlayerFromCharacter(occ.Parent)
      if sitter and not VehicleService.hasKey(sitter, plate) then
        VehicleService.eject(sitter, occ, "เจ้าของล็อกพาหนะ")
      end
    end
  end
  return true
end

-- ใครเป็นคนจำลองฟิสิกส์ของคันนี้
--
-- รถ (Wheels) → ยกให้เครื่องคนขับ: สิ่งที่เซิร์ฟเวอร์ส่งไปคือ "ความเร็วเป้าหมายของล้อ" ซึ่งนิ่ง
-- ดีเลย์ไม่ทำให้เพี้ยน แถมพวงมาลัยตอบสนองทันมือ
--
-- เรือ/เรือเหาะ (Float/Hover) → **ต้องอยู่ที่เซิร์ฟเวอร์**: แรงลอยเป็นสปริงที่มีตัวหน่วงอิงความเร็วปัจจุบัน
-- ถ้าคนขับเป็นคนจำลอง เซิร์ฟเวอร์จะคำนวณตัวหน่วงจากข้อมูลที่ช้าไปราว 100ms แล้วส่งแรงกลับไปช้าอีกรอบ
-- ตัวหน่วงที่มาช้าครึ่งรอบคลื่นกลายเป็นตัว "เติมพลังงาน" — วัดได้จริงว่าเรือดีดขึ้นฟ้าถึง y=153
-- (ไม่มีคนนั่ง เซิร์ฟเวอร์เป็นเจ้าของอยู่แล้ว เรือจึงนิ่งสนิท ซึ่งเป็นเบาะแสที่ชี้ไปที่ต้นเหตุนี้)
function VehicleService.own(record, player)
  local wantServer = record.spec.serverOwned ~= false
  pcall(function()
    record.hull:SetNetworkOwner((not wantServer) and player or nil)
  end)
end

function VehicleService.eject(player, humanoid, reason)
  humanoid.Sit = false
  task.delay(0.1, function()
    local root = humanoid.Parent and humanoid.Parent:FindFirstChild("HumanoidRootPart")
    if root then root.CFrame = root.CFrame * CFrame.new(0, 2, 6) end
  end)
  notify(player, "🔒 " .. (reason or "พาหนะถูกล็อกอยู่"), "warn")
end

-- ---------------------------------------------------------------- สร้างตัวถัง
local function prompt(parent, action, object, distance)
  local p = Instance.new("ProximityPrompt")
  p.ActionText = action
  p.ObjectText = object
  p.HoldDuration = 0
  p.MaxActivationDistance = distance or 10
  p.RequiresLineOfSight = false
  p.Parent = parent
  return p
end

local function wireSeat(record, seat)
  local kind = seat:GetAttribute("SeatKind")
  local p = prompt(seat, kind == "driver" and "ขับ" or "นั่งซ้อน", record.display .. " " .. record.plate, 11)
  p.Triggered:Connect(function(player)
    local char = player.Character
    local humanoid = char and char:FindFirstChildOfClass("Humanoid")
    if not humanoid or humanoid.Health <= 0 then return end
    if not VehicleService.canAccess(player, record) then
      notify(player, "🔒 " .. record.plate .. " ถูกล็อกอยู่ ต้องมีกุญแจถึงจะขึ้นได้", "warn")
      return
    end
    if seat.Occupant then
      notify(player, "ที่นั่งนี้มีคนอยู่แล้ว", "warn")
      return
    end
    seat:Sit(humanoid)
    record.lastTouch = os.clock()
  end)

  seat:GetPropertyChangedSignal("Occupant"):Connect(function()
    local occ = seat.Occupant
    record.lastTouch = os.clock()
    if not occ then
      if seat == record.driveSeat then
        record.model:SetAttribute("Lift", 0)
        record.model:SetAttribute("Aim", 0)
        record.model:SetAttribute("Boost", false)
        record.aim = 0
        local was = record.driver
        record.driver = nil
        if was then
          VehicleService.Drivers[was.UserId] = nil
          if Signal then Signal:FireClient(was, { action = "Driving", plate = nil }) end
        end
        if record.hull:IsDescendantOf(workspace) then
          pcall(function() record.hull:SetNetworkOwner(nil) end)
        end
      end
      return
    end
    local sitter = Players:GetPlayerFromCharacter(occ.Parent)
    if sitter and not VehicleService.canAccess(sitter, record) then
      -- ปีนขึ้นมาเองทั้งที่ล็อกอยู่ (ไม่ได้ผ่านปุ่ม) — ด่านสุดท้ายที่กันไว้
      task.defer(VehicleService.eject, sitter, occ, "พาหนะคันนี้ถูกล็อกอยู่")
      return
    end
    if sitter and seat == record.driveSeat then
      record.driver = sitter
      VehicleService.Drivers[sitter.UserId] = record
      VehicleService.own(record, sitter)
      Signal:FireClient(sitter, {
        action = "Driving", plate = record.plate, vtype = record.vtype,
        display = record.display, mode = record.spec.drive,
        seats = #record.seats - 1,
      })
    end
  end)
end

local function wireTrunk(record, part)
  if not part then return end
  part.CanQuery = true
  local p = prompt(part, "เปิดท้าย", record.display .. " " .. record.plate, Config.TrunkRange)
  p.Triggered:Connect(function(player)
    local payload, err = VehicleService.trunkState(player, record.plate)
    if not payload then
      notify(player, "🔒 " .. tostring(err), "warn")
      return
    end
    Signal:FireClient(player, payload)
  end)
end

-- ช่างมาซ่อมถึงที่ ปุ่มขึ้นเฉพาะกับนักประดิษฐ์ และเฉพาะตอนคันนี้สึกจริง
--
-- ปุ่มโผล่/หายเองตาม Attribute "Durability" ที่ Drive อัปเดตอยู่แล้ว แทนที่จะให้กดแล้วค่อยบอกว่า "ยังไม่
-- สึก" — ปุ่มที่ตอบว่าไม่ได้เสมอคือปุ่มที่ไม่ควรมี ส่วนการเช็กคลาสต้องอยู่ตอนกด ไม่ใช่ตอนสร้าง เพราะปุ่ม
-- หนึ่งอันใช้ร่วมกันทุกคนที่เดินผ่าน
local function wireRepairPrompt(record)
  local dur = record.spec.durability
  if not dur then return end

  local p = prompt(record.hull, "ซ่อมพาหนะ", record.display .. " " .. record.plate, 12)
  -- ตั้งชื่อไว้ให้ไคลเอนต์หาเจอ: `VehicleRepairController` ซ่อนปุ่มนี้จากคนที่ไม่ใช่นักประดิษฐ์ ซึ่งทำได้
  -- เฉพาะฝั่งไคลเอนต์เท่านั้น (Enabled ฝั่งเซิร์ฟเวอร์เห็นเหมือนกันหมดทุกคน)
  p.Name = "VehicleRepairPrompt"
  p.Enabled = false
  p.Triggered:Connect(function(player)
    if not Classes.Has(player, Config.RepairClass) then
      return notify(player, "ต้องเป็นนักประดิษฐ์ถึงจะซ่อมพาหนะได้", "warn")
    end
    local ok, message = VehicleService.fieldRepair(player, record.plate)
    notify(player, (ok and "🔧 " or "") .. tostring(message), ok and "info" or "warn")
  end)

  local function refresh()
    p.Enabled = (record.durability or dur.max) < dur.max
  end
  record.model:GetAttributeChangedSignal("Durability"):Connect(refresh)
  refresh()
end

local function wireLockPrompt(record)
  local p = prompt(record.hull, "ล็อก / ปลดล็อก", record.display .. " " .. record.plate, 12)
  p.Triggered:Connect(function(player)
    if not VehicleService.hasKey(player, record.plate) then
      notify(player, "ไม่มีกุญแจของ " .. record.plate, "warn")
      return
    end
    local locked = record.model:GetAttribute("IsLocked") ~= true
    local ok, err = VehicleService.setLock(player, record.plate, locked)
    if ok then
      notify(player, (locked and "🔒 ล็อก " or "🔓 ปลดล็อก ") .. record.plate .. " แล้ว", "ok")
    else
      notify(player, tostring(err), "warn")
    end
  end)
end

-- สร้างพาหนะจริงเข้าโลก แล้วผูกทุกอย่าง (ฟิสิกส์ ปุ่ม ป้ายทะเบียน)
function VehicleService.build(vtype, cf, plate, ownerId, data)
  local spec = Config.Types[vtype]
  local model, parts = Models[vtype](spec)
  model.Name = string.format("%s_%s", model.Name, plate)

  local record = {
    plate = plate, vtype = vtype, spec = spec, display = spec.display,
    model = model, hull = model.PrimaryPart, seats = parts.seats,
    wheels = parts.wheels, spinners = parts.spinners, ownerId = ownerId, lastTouch = os.clock(),
  }
  record.driveSeat = parts.seats[1]

  model:SetAttribute("Plate", plate)
  model:SetAttribute("VehicleType", vtype)
  model:SetAttribute("OwnerUserId", ownerId)
  model:SetAttribute("IsLocked", data and data.Locked == true or false)
  model:SetAttribute("Lift", 0)
  model:SetAttribute("Boost", false)

  -- เชื้อเพลิง: ค่าจริงอยู่ใน record ส่วน Attribute "Fuel" เป็นเปอร์เซ็นต์ให้ไคลเอนต์วาดเกจ
  record.fuel = data and tonumber(data.Fuel) or (spec.fuel and spec.fuel.max) or 0
  if spec.fuel then record.fuel = math.clamp(record.fuel, 0, spec.fuel.max) end
  model:SetAttribute("Fuel", spec.fuel and math.floor(record.fuel / spec.fuel.max * 100 + 0.5) or 100)

  -- ความคงทน เก็บและเผยแพร่ด้วยกติกาเดียวกับเชื้อเพลิงเป๊ะ: ค่าจริงใน record, เปอร์เซ็นต์ใน Attribute,
  -- เซฟไปกับทะเบียน ตัวใหม่ที่ไม่เคยมีค่าเก็บไว้เกิดมาเต็มเสมอ
  local dur = spec.durability
  record.durability = data and tonumber(data.Durability) or (dur and dur.max) or 0
  if dur then record.durability = math.clamp(record.durability, 0, dur.max) end
  model:SetAttribute("Durability", dur and math.floor(record.durability / dur.max * 100 + 0.5) or 100)
  record.onEmpty = function(rec)
    if rec.driver then
      notify(rec.driver, "🔥 ไฟในเตาดับแล้ว — " .. rec.plate .. " ไปต่อไม่ได้ ต้องเติมถ่าน (เปิดท้ายรถแล้วกดเติม)", "warn")
    end
  end
  -- ตัวเลขความสึกคำนวณใน Drive ส่วนการเก็บ/เผยแพร่/แจ้งเตือนอยู่ที่นี่ ด้วยเหตุผลเดียวกับ onEmpty
  record.onWear = function(rec, amount) VehicleService.wear(rec, amount) end

  if spec.drive ~= "Wheels" then
    record.rig = Chassis.forceRig(record.hull)
  end

  -- โมเดลสร้างในพิกัดท้องถิ่นที่ "ฐาน = y 0" แต่ pivot ของ Model คือ PrimaryPart (กล่องชน)
  -- ที่ลอยอยู่กลางตัวถัง → ยก cf ขึ้นเท่าความสูงของกล่องชน ไม่งั้นล้อจะจมพื้นทุกครั้ง
  model:PivotTo(cf * CFrame.new(0, record.hull.Position.Y, 0))
  model.Parent = folder()

  for _, seat in ipairs(parts.seats) do wireSeat(record, seat) end
  wireTrunk(record, parts.trunkPart)
  wireLockPrompt(record)
  wireRepairPrompt(record)

  record.drive = Drive.new(record)
  pcall(function() record.hull:SetNetworkOwner(nil) end)
  VehicleService.Active[plate] = record
  return record
end

-- ---------------------------------------------------------------- ค่าเบิก / ค่าฝาก
--
-- โจทย์: "เบิกฝากรถได้ แต่เสียเงินค่าเบิก และถ้ารถอยู่ห่างจาก NPC มาก็เสียตังเบิกหรือฝากมากขึ้นด้วย"
-- ระยะที่คิดคือระยะจากบารอนเวนไปยังสิ่งที่กำลังทำ — ดู Config.Fee

-- ตำแหน่งของบารอนเวน หาจากแท็กแบบเดียวกับที่ร้านค้ากับช่างตีเหล็กหา NPC ของตัวเอง ผู้ใช้ลากตัว NPC ไปไหน
-- ค่าบริการก็ขยับตาม โดยไม่มีพิกัดชุดที่สองให้ลืมอัปเดต
function VehicleService.npcPosition()
  for _, npc in ipairs(CollectionService:GetTagged("WOLD_Npc")) do
    if npc:GetAttribute("NpcKind") == "vehicle" then
      return npc:IsA("BasePart") and npc.Position or npc:GetPivot().Position
    end
  end
  return nil
end

-- ค่าบริการของงานหนึ่งครั้ง คืนเป็น (จำนวนเงิน, ระยะ) เพื่อให้แผงบอกผู้เล่นได้ว่าทำไมถึงแพง
--
-- ไม่มีบารอนเวนในแมพ = ไม่มีใครเก็บเงิน ค่าบริการจึงเป็นศูนย์ ไม่ใช่ค่าพื้นฐาน: การคิดเงินโดยไม่มีคนรับเงิน
-- เป็นบั๊กที่ผู้เล่นมองไม่เห็นต้นเหตุ
function VehicleService.quote(kind, position)
  local npc = VehicleService.npcPosition()
  if not npc or not position then return 0, 0 end
  local studs = (position - npc).Magnitude
  return Config.feeFor(kind, studs), studs
end

local function charge(player, amount)
  if amount <= 0 then return true end
  local state = Inventory.Get(player)
  if not state then return false, "ข้อมูลผู้เล่นยังไม่พร้อม" end
  if (state.gold or 0) < amount then
    return false, string.format("เงินไม่พอ ต้องมี %d เหรียญ", amount)
  end
  Inventory.AddGold(player, -amount)
  return true
end

-- ---------------------------------------------------------------- เรียก / ฝาก
local function freeSpot(base)
  -- ลานจอดว่างไหม ถ้ามีคันอื่นอยู่ให้ขยับออกข้างทีละ 16 studs
  for _, dx in ipairs({ 0, 16, -16, 32, -32 }) do
    local cf = base * CFrame.new(dx, 0, 0)
    local hit = false
    for _, rec in pairs(VehicleService.Active) do
      if (rec.hull.Position - cf.Position).Magnitude < 16 then hit = true break end
    end
    if not hit then return cf end
  end
  return base * CFrame.new(0, 8, 0)
end

function VehicleService.summon(player, plate, station)
  local vtype = VehicleService.typeOfPlate(plate)
  if not vtype then return false, "ทะเบียนไม่ถูกต้อง" end
  if not VehicleService.hasKey(player, plate) then return false, "ต้องมีกุญแจของ " .. plate end
  -- กุญแจที่ยังไม่ได้จดทะเบียนเรียกรถออกมาไม่ได้ ถ้าไม่ด่านนี้ การจดทะเบียนก็ไม่มีความหมาย: หีบทดสอบแจก
  -- กุญแจมา แล้วขับได้เลยโดยไม่ต้องแวะหาบารอนเวนสักครั้ง (ตัว build ยอมรับ data = nil อยู่แล้ว จึงเงียบ)
  if not VehicleService.isRegistered(player, plate) then
    return false, "กุญแจดอกนี้ยังไม่ได้จดทะเบียน ไปจดที่บารอนเวนก่อน"
  end
  if VehicleService.Active[plate] then return false, plate .. " ถูกเรียกออกมาแล้ว" end
  if station and station.vtype ~= vtype then return false, "จุดนี้เรียกได้เฉพาะ" .. Config.Types[station.vtype].display end

  local char = player.Character
  local root = char and char:FindFirstChild("HumanoidRootPart")
  -- ต้องยืนใกล้แท่นเรียกถึงจะกดเรียกที่แท่นนั้นได้ — ยกเว้นตอนสั่งผ่านบารอนเวน ซึ่งผู้เล่นยืนอยู่ตรงหน้า NPC
  -- ไม่ใช่ตรงลานจอด (VehicleMain ตั้ง requireNear = false ให้เส้นทางนั้น)
  if station and station.requireNear ~= false and root
    and (root.Position - station.pos).Magnitude > Config.SummonRange * 2 then
    return false, "ต้องยืนใกล้จุดเรียกก่อน"
  end

  local owner, data = Store.ownerOf(plate)
  local base = station and CFrame.new(station.spawn) * CFrame.Angles(0, math.rad(station.spawnFace or 0), 0)
    or (root and root.CFrame * CFrame.new(0, 0, -20))
  if not base then return false, "หาจุดจอดไม่ได้" end

  -- ค่าเบิก คิดจากระยะระหว่างบารอนเวนกับลานจอดที่พาหนะจะโผล่ เก็บเงินก่อนสร้างตัวถัง: ถ้าเก็บทีหลังแล้วเงินไม่พอ
  -- จะเหลือพาหนะที่เกิดมาแล้วแต่ไม่ได้จ่าย ซึ่งเก็บกลับยากกว่าการปฏิเสธตั้งแต่แรก
  local fee = VehicleService.quote("retrieve", base.Position)
  local paid, reason = charge(player, fee)
  if not paid then return false, reason end

  -- สร้างตัวถังใน pcall แล้วคืนเงินถ้าล้ม: เงินถูกหักไปก่อนแล้ว (ต้องหักก่อน ไม่งั้นจะมีพาหนะที่เกิดมาแต่ไม่ได้
  -- จ่าย) จึงต้องมีทางกลับสำหรับกรณีที่การสร้างพัง
  local ok, record = pcall(VehicleService.build, vtype, freeSpot(base), plate,
    owner and owner.UserId or player.UserId, data)
  if not ok or not record then
    if fee > 0 then Inventory.AddGold(player, fee) end
    warn("[VehicleService] สร้าง " .. plate .. " ไม่สำเร็จ: " .. tostring(record))
    return false, "สร้างพาหนะไม่สำเร็จ คืนเงินให้แล้ว"
  end
  record.fee = fee
  record.summonedBy = player.UserId
  if data and data.Trunk then
    record.trunk = table.clone(data.Trunk)
  else
    record.trunk = {}
  end
  return true, record
end

-- ฝากคืนโรงรถ: เซฟของในท้ายกลับเข้าข้อมูลเจ้าของแล้วเก็บโมเดลออกจากโลก
function VehicleService.stow(plate, byPlayer)
  local record = VehicleService.Active[plate]
  if not record then return false, "คันนี้ไม่ได้อยู่ในโลก" end
  if byPlayer and not VehicleService.hasKey(byPlayer, plate) then
    return false, "ต้องมีกุญแจถึงจะฝากได้"
  end

  -- เช็กว่ามีคนนั่งอยู่ไหม **ก่อน** เก็บเงินเสมอ: ทางที่ยังปฏิเสธได้ต้องอยู่หน้าทางที่หักเงินไปแล้ว ไม่งั้น
  -- คนที่สั่งฝากตอนเพื่อนนั่งอยู่จะเสียค่าบริการให้กับงานที่ไม่ได้เกิดขึ้น
  local sitters = {}
  for _, seat in ipairs(record.seats) do
    local occ = seat.Occupant
    if occ then
      local sitter = Players:GetPlayerFromCharacter(occ.Parent)
      if sitter and byPlayer and sitter ~= byPlayer then
        return false, "ยังมีคนนั่งอยู่ในพาหนะ"
      end
      table.insert(sitters, occ)
    end
  end

  -- ค่าฝาก คิดจากระยะระหว่างบารอนเวนกับตัวพาหนะตรงที่มันจอดอยู่จริง ทิ้งเรือเหาะไว้ยอดเขาแล้วสั่งเก็บจากในเมือง
  -- ย่อมแพงกว่าบินกลับมาจอดเอง — คิดเฉพาะตอนคนสั่ง ส่วนการเก็บอัตโนมัติ (ไม่มีคนแตะนาน / เจ้าของออกจากเกม)
  -- ไม่มีใครต้องจ่าย
  local fee = 0
  if byPlayer then
    fee = VehicleService.quote("stow", record.hull.Position)
    local paid, reason = charge(byPlayer, fee)
    if not paid then return false, reason end
  end

  for _, occ in ipairs(sitters) do occ.Sit = false end
  VehicleService.saveTrunk(record)
  record.model:Destroy()
  VehicleService.Active[plate] = nil
  return true, fee
end

function VehicleService.saveTrunk(record)
  local owner, data = Store.ownerOf(record.plate)
  if data then
    data.Trunk = table.clone(record.trunk or {})
    data.Locked = record.model:GetAttribute("IsLocked") == true
    data.Fuel = record.fuel
    data.Durability = record.durability
    if owner then Store.dirty(owner) end
  end
end

-- ---------------------------------------------------------------- เติมเชื้อเพลิง
-- ใช้ถ่านหินในกระเป๋าก่อน ถ้าไม่มีและเปิด FreeFuel ไว้ก็เติมให้ฟรี (ช่วงทดสอบ)
function VehicleService.refuel(player, plate)
  local record = VehicleService.Active[plate]
  if not record then return false, "ต้องเรียกพาหนะออกมาก่อนถึงจะเติมได้" end
  if not VehicleService.canAccess(player, record) then return false, plate .. " ถูกล็อกอยู่" end
  local spec = record.spec.fuel
  if not spec then return false, "พาหนะนี้ไม่ใช้เชื้อเพลิง" end
  local missing = spec.max - record.fuel
  if missing < 1 then return false, "ถังเต็มอยู่แล้ว" end

  -- ถ่านหินมาจากกระเป๋าจริงของเกม ไม่ใช่ตารางไอเทมทดสอบของโปรเจ็คต้นทางแล้ว
  local perCoal = Config.fuelPerCoal(record.spec)
  local need = math.ceil(missing / perCoal)
  local used = 0
  if not Config.FreeFuel then
    used = VehicleService.takeFromBag(player, "Coal", need)
    if used <= 0 then return false, "ไม่มีถ่านหินในกระเป๋า" end
  end

  record.fuel = Config.FreeFuel and spec.max or math.min(spec.max, record.fuel + used * perCoal)
  record.lastTouch = os.clock()
  record.model:SetAttribute("Fuel", math.floor(record.fuel / spec.max * 100 + 0.5))
  VehicleService.saveTrunk(record)
  return true, used > 0 and ("เติมถ่าน " .. used .. " ชิ้น") or "เติมให้ฟรี"
end

function VehicleService.fuelPercent(record)
  local spec = record.spec.fuel
  if not spec then return 100 end
  return math.floor((record.fuel or 0) / spec.max * 100 + 0.5)
end

-- ---------------------------------------------------------------- ความคงทน
function VehicleService.durabilityPercent(record)
  local dur = record.spec.durability
  if not dur then return 100 end
  return math.floor((record.durability or 0) / dur.max * 100 + 0.5)
end

-- เรียกจากลูปขับทุกสเต็ป ดูคำอธิบายว่าอะไรทำให้สึกที่ Config.Durability
function VehicleService.wear(record, amount)
  local dur = record.spec.durability
  if not dur or amount <= 0 then return end
  local before = record.durability or dur.max
  if before <= 0 then return end

  record.durability = math.max(0, before - amount)
  local pct = math.floor(record.durability / dur.max * 100 + 0.5)
  if pct ~= record._pubDurability then
    record._pubDurability = pct
    record.model:SetAttribute("Durability", pct)
  end
  -- ถึงศูนย์แล้วเงียบไปเฉยๆ คือบั๊กที่คนขับหาไม่เจอ ต้องบอกให้รู้ว่าเกิดอะไรขึ้นและต้องทำอย่างไรต่อ
  if record.durability <= 0 and before > 0 then
    if record.driver then
      notify(record.driver, "⚙️ " .. record.plate .. " พังแล้ว ขับต่อไม่ได้ — ฝากคืนกับบารอนเวนแล้วกดซ่อม หรือให้นักประดิษฐ์ซ่อมให้ตรงนี้", "warn")
    end
    VehicleService.saveTrunk(record)
  end
end

function VehicleService.isBroken(record)
  local dur = record.spec.durability
  return dur ~= nil and (record.durability or dur.max) <= 0
end

-- ซ่อมกลับเต็ม คืน true ถ้ามีอะไรให้ซ่อมจริง
local function restore(record)
  local dur = record.spec.durability
  if not dur then return false end
  if (record.durability or 0) >= dur.max then return false end
  record.durability = dur.max
  record._pubDurability = 100
  record.model:SetAttribute("Durability", 100)
  return true
end

-- ช่างซ่อมถึงที่: นักประดิษฐ์เดินมาซ่อมพาหนะที่พังคาอยู่ตรงนั้น ทางเลือกที่สองของผู้ใช้ ("เรียกช่างมาซ่อม")
-- คู่กับการฝากคืนแล้วกดซ่อมที่ NPC
--
-- จ่ายด้วยเฟืองอะไหล่ ไม่ใช่เงิน: เงินเป็นทางของบารอนเวนอยู่แล้ว และของที่ต้องหามาเองคือสิ่งที่ทำให้การมี
-- ช่างอยู่ในเซิร์ฟเวอร์มีค่ากว่าการมีเงิน
function VehicleService.fieldRepair(player, plate)
  local record = VehicleService.Active[plate]
  if not record then return false, "ไม่พบพาหนะทะเบียนนี้ในโลก" end
  local dur = record.spec.durability
  if not dur then return false, "พาหนะนี้ไม่มีค่าความคงทน" end
  if (record.durability or 0) >= dur.max then return false, "คันนี้ยังไม่สึกหรอ" end

  local need = Config.RepairParts or 3
  local used = VehicleService.takeFromBag(player, "GearSpare", need)
  if used < need then
    -- คืนของที่หยิบไปแล้ว: ซ่อมไม่สำเร็จต้องไม่กินอะไหล่
    if used > 0 then Inventory.AddItem(player, "GearSpare", used) end
    return false, ("ต้องใช้เฟืองอะไหล่ %d ชิ้น"):format(need)
  end

  restore(record)
  record.lastTouch = os.clock()
  VehicleService.saveTrunk(record)
  return true, ("ซ่อม %s กลับมาเต็มแล้ว (ใช้เฟืองอะไหล่ %d)"):format(plate, need)
end

-- ---------------------------------------------------------------- บริการที่บารอนเวน
-- ทั้งสองอย่างต้อง **ฝากรถไว้ก่อน** ตามที่ผู้ใช้กำหนด ซึ่งอ่านเป็นกติกาเดียวกันทั้งคู่: บารอนเวนทำงานกับ
-- พาหนะที่อยู่ในโรงเก็บของเขา ไม่ใช่กับคันที่จอดอยู่อีกฟากของแมพ
--
-- "ฝากแล้ว" = ไม่มีอยู่ใน Active ซึ่งเป็นนิยามเดียวกับที่แผงโรงรถใช้วาดปุ่ม เบิก/ฝากคืน อยู่แล้ว
local function stowedRecord(player, plate)
  if VehicleService.Active[plate] then
    return nil, "ต้องฝากคืนก่อนถึงจะใช้บริการนี้ได้"
  end
  local profile = Store.get(player)
  local rec = profile and profile.Data.Vehicles[plate]
  if not rec then return nil, "ทะเบียนนี้ไม่ได้อยู่ในโรงรถของคุณ" end
  if not Store.hasKey(player, plate) then return nil, "ต้องมีกุญแจของ " .. plate end
  return rec, Config.Types[rec.Type]
end

function VehicleService.serviceRefuel(player, plate)
  local rec, spec = stowedRecord(player, plate)
  if not rec then return false, spec end
  local fuel = spec and spec.fuel
  if not fuel then return false, "พาหนะนี้ไม่ใช้เชื้อเพลิง" end
  if (tonumber(rec.Fuel) or fuel.max) >= fuel.max then return false, "ถังเต็มอยู่แล้ว" end

  local price = Config.Service.Refuel
  local paid, reason = charge(player, price)
  if not paid then return false, reason end

  rec.Fuel = fuel.max
  Store.dirty(player)
  return true, price
end

function VehicleService.serviceRepair(player, plate)
  local rec, spec = stowedRecord(player, plate)
  if not rec then return false, spec end
  local dur = spec and spec.durability
  if not dur then return false, "พาหนะนี้ไม่มีค่าความคงทน" end
  if (tonumber(rec.Durability) or dur.max) >= dur.max then return false, "คันนี้ยังไม่สึกหรอ" end

  local price = Config.Service.Repair
  local paid, reason = charge(player, price)
  if not paid then return false, reason end

  rec.Durability = dur.max
  Store.dirty(player)
  return true, price
end

-- ---------------------------------------------------------------- ท้ายพาหนะ
-- กระเป๋าของผู้เล่นในรูปแบบที่แผงท้ายพาหนะใช้: { [itemId] = จำนวนรวม }
--
-- รวมทุกช่องเข้าด้วยกัน เพราะแผงท้ายพาหนะพูดถึง "ของ" ไม่ใช่ "ช่อง" — หินสิบก้อนที่กระจายอยู่สามช่องก็คือ
-- หินสิบก้อน ส่วนของที่มี meta (กุญแจพาหนะ ปลาที่ชั่งน้ำหนักแล้ว) ถูกข้ามไป: มันเป็นของเฉพาะตัว ย้ายเข้าท้าย
-- แบบนับจำนวนไม่ได้โดยไม่ทำ meta หาย
local function bagOf(player)
  local out = {}
  local state = Inventory.Get(player)
  if not state then return out end
  for _, slot in pairs(state.slots) do
    if slot and not slot.meta then
      out[slot.id] = (out[slot.id] or 0) + (slot.count or 1)
    end
  end
  return out
end

-- เอาของออกจากกระเป๋าให้ครบ `count` ชิ้น เดินไล่ทีละช่อง คืนจำนวนที่เอาออกได้จริง (อาจน้อยกว่าที่ขอ)
-- เก็บรายชื่อช่องให้ครบก่อนค่อยลบ ด้วยเหตุผลเดียวกับที่ร้านค้าทำ: RemoveFromSlot ล้างช่องทิ้ง การเดินตาราง
-- ไปลบไปคือการอ่านสิ่งที่ตัวเองกำลังแก้
function VehicleService.takeFromBag(player, itemId, count)
  local state = Inventory.Get(player)
  if not state or count <= 0 then return 0 end

  local found = {}
  for index, slot in pairs(state.slots) do
    if slot and slot.id == itemId and not slot.meta then
      table.insert(found, { index = index, count = slot.count or 1 })
    end
  end

  local taken = 0
  for _, entry in ipairs(found) do
    if taken >= count then break end
    local take = math.min(entry.count, count - taken)
    Inventory.RemoveFromSlot(player, entry.index, take)
    taken += take
  end
  return taken
end

-- สิ่งที่แผงท้ายพาหนะวาดจาก ใช้ร่วมกันทั้งตอนเปิดและตอนย้ายของเสร็จ — เดิมเขียนแยกกันสองที่ และการเพิ่ม
-- ฟิลด์ใหม่ก็คือการลืมเติมอีกที่หนึ่ง (เกจถ่านบนแผงหายไปหลังย้ายของ เพราะเหตุผลนี้พอดี)
--
-- เกจถ่านอยู่ในนี้เพราะปุ่มเติมถ่านย้ายมาอยู่บนแผงนี้แล้ว ปุ่มที่ไม่บอกว่าตอนนี้เหลือเท่าไหร่คือปุ่มที่ต้อง
-- กดเพื่อจะรู้ว่าควรกดไหม
function VehicleService.trunkPayload(player, record)
  return {
    action = "Trunk", plate = record.plate, display = record.display,
    capacity = record.spec.trunk, trunk = record.trunk or {}, bag = bagOf(player),
    fuel = VehicleService.fuelPercent(record),
    durability = VehicleService.durabilityPercent(record),
    coalPerFullTank = Config.CoalPerFullTank,
  }
end

function VehicleService.trunkState(player, plate)
  local record = VehicleService.Active[plate]
  if not record then return nil, "ไม่พบพาหนะทะเบียนนี้" end
  if not VehicleService.canAccess(player, record) then
    return nil, plate .. " ถูกล็อกอยู่ ต้องมีกุญแจถึงจะเปิดท้ายได้"
  end
  local char = player.Character
  local root = char and char:FindFirstChild("HumanoidRootPart")
  if not root or (root.Position - record.hull.Position).Magnitude > Config.TrunkRange + 12 then
    return nil, "อยู่ไกลจากพาหนะเกินไป"
  end
  record.lastTouch = os.clock()
  return VehicleService.trunkPayload(player, record)
end

local function stackLimit(itemId)
  return ItemCatalog.StackSize(itemId)
end

function VehicleService.moveItem(player, plate, itemId, count, toTrunk)
  local record = VehicleService.Active[plate]
  if not record then return nil, "ไม่พบพาหนะทะเบียนนี้" end
  if not VehicleService.canAccess(player, record) then return nil, "ท้ายพาหนะถูกล็อกอยู่" end
  if not ItemCatalog.Exists(itemId) then return nil, "ไม่รู้จักของชิ้นนี้" end
  count = math.floor(tonumber(count) or 0)
  if count <= 0 then return nil, "จำนวนไม่ถูกต้อง" end

  if not Inventory.Get(player) then return nil, "ข้อมูลผู้เล่นยังไม่พร้อม" end
  record.trunk = record.trunk or {}

  if toTrunk then
    -- กุญแจใส่ท้ายพาหนะไม่ได้ ไม่ใช่แค่เพราะกติกา แต่เพราะท้ายพาหนะเก็บ **จำนวนของแต่ละชนิด** ไม่ได้เก็บช่อง
    -- (`record.trunk[itemId] = n`) จึงไม่มีที่ให้ meta ของช่องอยู่เลย กุญแจที่ใส่เข้าไปจะออกมาเป็นกุญแจที่
    -- ไม่มีทะเบียน ซึ่งคือปัญหา "คข 8660" ที่เคยทำให้โรงรถบารอนเวนพัง
    if not ItemCatalog.IsStorable(itemId) then
      return nil, "กุญแจเก็บในท้ายพาหนะไม่ได้ — ต้องพกติดตัวไว้"
    end

    -- ช่องท้ายพาหนะนับเป็น "ชนิดของ" ไม่ใช่ช่องกระเป๋า ของชนิดใหม่จึงกินหนึ่งช่อง ส่วนของชนิดเดิมไปกองรวม
    local slots = 0
    for _ in pairs(record.trunk) do slots += 1 end
    if not record.trunk[itemId] and slots >= record.spec.trunk then
      return nil, "ท้ายพาหนะเต็มแล้ว"
    end
    local room = stackLimit(itemId) - (record.trunk[itemId] or 0)
    count = math.min(count, room)
    if count <= 0 then return nil, "ของชิ้นนี้ในท้ายพาหนะเต็มกองแล้ว" end

    -- เอาออกจากกระเป๋าก่อน แล้วค่อยใส่ท้ายเท่าที่เอาออกได้จริง: ฝั่งที่ล้มเหลวได้ต้องไปก่อนเสมอ
    local taken = VehicleService.takeFromBag(player, itemId, count)
    if taken <= 0 then return nil, "ในกระเป๋าไม่มีของชิ้นนี้" end
    record.trunk[itemId] = (record.trunk[itemId] or 0) + taken
  else
    local have = record.trunk[itemId] or 0
    count = math.min(count, have)
    if count <= 0 then return nil, "ในท้ายพาหนะไม่มีของชิ้นนี้" end

    -- ใส่กระเป๋าทีละชิ้นก่อน แล้วค่อยหักออกจากท้ายเท่าที่ใส่ได้จริง ด้วยเหตุผลกลับกัน: ตอนนี้กระเป๋าคือฝั่ง
    -- ที่ล้มเหลวได้ (เต็ม) ส่วนกองในท้ายหักออกยังไงก็สำเร็จ
    -- AddItem เป็น "ทั้งหมดหรือไม่เอาเลย" (QA 2026-09-26 — ของเดิมทีละชิ้น: กระเป๋าเต็มแล้วของลงคลังแต่คืน false
    -- ท้ายรถไม่ถูกหัก = ปั๊มของ) · ขอทั้งก้อนแล้วลดทีละชิ้นจนพอดี
    local moved = 0
    for n = count, 1, -1 do
      if Inventory.AddItem(player, itemId, n) then
        moved = n
        break
      end
    end
    if moved <= 0 then return nil, "กระเป๋าเต็ม" end
    record.trunk[itemId] = have - moved
    if record.trunk[itemId] <= 0 then record.trunk[itemId] = nil end
  end

  record.lastTouch = os.clock()
  VehicleService.saveTrunk(record)
  return VehicleService.trunkPayload(player, record)
end

-- คันบังคับขึ้น/ลงของเรือเหาะ (-1..1) ส่งมาจากไคลเอนต์ของคนที่นั่งเบาะคนขับอยู่เท่านั้น
function VehicleService.setLift(player, value)
  local record = VehicleService.Drivers[player.UserId]
  if not record or record.spec.drive ~= "Hover" then return end
  if not record.driveSeat.Occupant then return end
  record.model:SetAttribute("Lift", math.clamp(value, -1, 1))
end

-- บูสต์: กด Shift ค้างตอนขับ ทรงเดียวกับ Lift เป๊ะ — Attribute บนโมเดล ที่ Drive อ่านทุกสเต็ป
--
-- เก็บเป็น Attribute ไม่ใช่ตัวแปรใน record ด้วยเหตุผลเดียวกับ Lift: ไคลเอนต์ทุกเครื่องเห็นด้วย ไฟบูสต์บน
-- HUD กับเสียงเครื่องจึงตามได้โดยไม่ต้องมี remote เพิ่ม
function VehicleService.setBoost(player, on)
  local record = VehicleService.Drivers[player.UserId]
  if not record then return end
  if not record.driveSeat.Occupant then return end
  record.model:SetAttribute("Boost", on and true or false)
end

-- หวูด/แตร: เซิร์ฟเวอร์แค่บอกทุกเครื่องว่า "คันนี้เพิ่งกดหวูด" ที่เหลือไคลเอนต์เล่นเสียงเอง
function VehicleService.horn(player)
  local record = VehicleService.Drivers[player.UserId]
  if not record or not record.driveSeat.Occupant then return end
  local now = os.clock()
  if now - (record.lastHorn or 0) < 1.2 then return end
  record.lastHorn = now
  record.lastTouch = now
  if Signal then Signal:FireAllClients({ action = "Horn", plate = record.plate }) end
end

-- มุมเล็งกล้องของคนขับ (-1 ก้มสุด .. 1 เงยสุด) ใช้กับเรือเหาะเท่านั้น
-- ปัดเป็นขั้นละ 1/32 เพื่อไม่ให้ Attribute วิ่งถี่เกินจำเป็น
function VehicleService.setAim(player, value)
  local record = VehicleService.Drivers[player.UserId]
  if not record or record.spec.drive ~= "Hover" then return end
  if not record.driveSeat.Occupant then return end
  local v = math.floor(math.clamp(value, -1, 1) * 32 + 0.5) / 32
  if v ~= record.aim then
    record.aim = v
    record.model:SetAttribute("Aim", v)
  end
end

-- ---------------------------------------------------------------- ลูปหลัก
function VehicleService.init(signal)
  Signal = signal
  RunService.Heartbeat:Connect(function(dt)
    for plate, record in pairs(VehicleService.Active) do
      -- ตกจากแมพแล้วโดน FallenPartsDestroyHeight เก็บ = กล่องชนหายไปทั้งที่โมเดลยังอยู่ ต้องเก็บกวาดเอง
      if record.model.Parent == nil or record.hull.Parent == nil or record.hull.Position.Y < -400 then
        VehicleService.saveTrunk(record)
        record.model:Destroy()
        VehicleService.Active[plate] = nil
        if record.driver then VehicleService.Drivers[record.driver.UserId] = nil end
      else
        local ok, err = pcall(record.drive.step, record.drive, math.min(dt, 0.1))
        if not ok then warn("[VehicleService] " .. plate .. " ขับไม่ได้: " .. tostring(err)) end
      end
    end
  end)

  -- Roblox ยกสิทธิ์จำลองฟิสิกส์ให้คนที่นั่งเบาะเองทุกครั้งที่มีคนขึ้น/ลง ต้องยึดคืนเป็นระยะ
  task.spawn(function()
    while task.wait(1) do
      for _, record in pairs(VehicleService.Active) do
        if record.spec.serverOwned ~= false and record.hull.Parent then
          local ok, owner = pcall(function() return record.hull:GetNetworkOwner() end)
          if ok and owner ~= nil then VehicleService.own(record, nil) end
        end
      end
    end
  end)

  task.spawn(function()
    while task.wait(20) do
      if Config.AutoDespawn > 0 then
        for plate, record in pairs(VehicleService.Active) do
          local busy = false
          for _, seat in ipairs(record.seats) do if seat.Occupant then busy = true break end end
          if busy then
            record.lastTouch = os.clock()
          elseif os.clock() - record.lastTouch > Config.AutoDespawn then
            VehicleService.stow(plate)
          end
        end
      end
    end
  end)

  Players.PlayerRemoving:Connect(function(player)
    for plate, record in pairs(VehicleService.Active) do
      if record.ownerId == player.UserId or record.summonedBy == player.UserId then
        VehicleService.saveTrunk(record)
        local busy = false
        for _, seat in ipairs(record.seats) do if seat.Occupant then busy = true break end end
        if not busy then VehicleService.stow(plate) end
      end
    end
  end)
end

return VehicleService
