-- Vehicle/Store — ทะเบียนและกุญแจที่ต้องอยู่ข้ามเซสชัน
--
-- ในโปรเจ็คต้นทาง (WOLD-Vehicle) ไฟล์นี้คุย DataStore เองทั้งไฟล์ และเขียนคอมเมนต์ไว้ว่า
-- "ตั้งใจให้ผิวหน้าแคบมาก เพราะเกมหลักจะเปลี่ยนไปใช้ ProfileService แล้วแก้แค่ไฟล์นี้ไฟล์เดียว"
-- ตอนนี้คือตอนนั้น: ข้างในเปลี่ยนเป็น ProfileStore ของเกมทั้งหมดแล้ว ส่วนผิวหน้า (load/get/hasKey/...)
-- ยังเหมือนเดิมเป๊ะ VehicleService กับ VehicleMain จึงไม่ต้องแก้ตามเลย
--
-- โครงข้อมูลของผู้เล่นหนึ่งคน เก็บใน profile.Data.Vehicles:
--   Vehicles = { ["CAR-1234"] = { Type = "Car", Name = "...", Trunk = {...}, Locked = false, Fuel = 80 } }
--
-- **กุญแจไม่ได้อยู่ในตารางนี้แล้ว** ต่างจากโปรเจ็คต้นทางที่เก็บเป็น `Keys = { ["CAR-1234"] = true }`
-- ในเกมหลักกุญแจคือ *ไอเทมจริงในกระเป๋า* (CarKey / BoatKey / AirshipKey ใน ItemCatalog) ที่พก `meta.plate`
-- เป็นทะเบียนของคันนั้น เหตุผลคือโจทย์ข้อ "ยกกุญแจให้เพื่อนได้": ไอเทมส่งต่อ/แลก/ทำหล่นได้ด้วยระบบที่เกม
-- มีอยู่แล้ว ส่วนแถวในตารางข้อมูลทำไม่ได้สักอย่าง
--
-- **ของในกระเป๋าผู้เล่นไม่ได้อยู่ที่นี่แล้ว** — เกมหลักมี Inventory ของตัวเอง ท้ายพาหนะจึงย้ายของเข้าออก
-- ผ่าน Inventory ตรงๆ (ดู VehicleService.moveItem)
local Players = game:GetService("Players")
local ProfileAccess = require(game.ServerScriptService.ProfileAccess)
local ItemCatalog = require(game.ReplicatedStorage.ItemCatalog)
local Inventory = require(game.ServerScriptService.Inventory)
-- Config ไม่ require อะไรเลย จึงดึงมาตรงนี้ได้โดยไม่เกิดวงวน (ใช้แปลง prefix ของทะเบียนเป็นชนิดพาหนะ)
local Config = require(game.ReplicatedStorage.Vehicle.Config)

local Store = {}
local CACHE = {}                        -- userId -> profile-ish { Data = ..., UserId = ... }

local function blank()
  return { Vehicles = {} }
end

local function scrub(data)              -- กันข้อมูลเก่า/พังไม่ให้ทำระบบล้มทั้งเซิร์ฟ
  if type(data) ~= "table" then return blank() end
  data.Vehicles = type(data.Vehicles) == "table" and data.Vehicles or {}
  -- โปรไฟล์เก่าจากโปรเจ็คต้นทางอาจมี Keys ติดมา ทิ้งได้เลย กุญแจอยู่ในกระเป๋าแล้ว
  data.Keys = nil
  for plate, rec in pairs(data.Vehicles) do
    if type(rec) ~= "table" or type(rec.Type) ~= "string" then
      data.Vehicles[plate] = nil
    else
      rec.Trunk = type(rec.Trunk) == "table" and rec.Trunk or {}
      rec.Locked = rec.Locked == true
    end
  end
  return data
end

-- โปรไฟล์ของเกมอาจยังโหลดไม่เสร็จตอนผู้เล่นเข้ามา (ProfileStore ต้องจับล็อกเซสชันก่อน) จึงรอแบบเดียวกับ
-- ที่ PlayerSocial และ BankVault รอ: 4 วินาที แล้วยอมเริ่มด้วยข้อมูลว่าง
--
-- เริ่มด้วยข้อมูลว่างปลอดภัยกว่าการเดา เพราะตารางที่ "ว่าง" จะไม่ถูกเขียนทับลงโปรไฟล์จริง —
-- VehicleService เขียนกลับเฉพาะตอนมีการเปลี่ยนแปลงจริงเท่านั้น
function Store.load(player)
  if CACHE[player.UserId] then return CACHE[player.UserId] end

  -- รอโปรไฟล์แบบไม่มีเส้นตาย (ProfileAccess.Wait) — เดิมรอ 4 วินาทีแล้วไปต่อ ซึ่งวันที่ DataStore ช้า
  -- จะได้โรงรถว่างแล้วถูกเซฟทับของจริง
  local data = ProfileAccess.Wait(player)
  local saved = data and data.Vehicles

  local profile = { Data = scrub(saved), UserId = player.UserId }
  CACHE[player.UserId] = profile

  -- ผูกเข้ากับโปรไฟล์จริงเลย: ตารางเดียวกัน ไม่ใช่สำเนา เขียนที่นี่ = โปรไฟล์เปลี่ยนตาม
  -- (ProfileStore เขียนลง DataStore ตามรอบของมันเอง ส่วน ProfileAccess.Flush ใช้เร่งตอนของสำคัญเปลี่ยน)
  if data then data.Vehicles = profile.Data end
  return profile
end

function Store.get(player)
  return CACHE[player.UserId]
end

-- ของสำคัญพอที่จะไม่ยอมรอรอบเซฟถัดไป: ทะเบียนที่เพิ่งจด กุญแจที่เพิ่งได้ ของในท้ายที่เพิ่งย้าย
function Store.dirty(player)
  if CACHE[player.UserId] and ProfileAccess.Flush then ProfileAccess.Flush(player) end
end

-- เหลือไว้ให้ผิวหน้าเหมือนเดิม แต่ไม่ต้องทำอะไรแล้ว: ProfileStore เป็นคนเซฟและปลดล็อกเซสชันเอง
function Store.save(player, release)
  if release then CACHE[player.UserId] = nil end
end

-- ---------------------------------------------------------------- กุญแจ (เป็นไอเทมในกระเป๋า)

-- ไอเทมกุญแจของพาหนะแต่ละชนิด อ่านจาก ItemCatalog เองแทนที่จะพิมพ์รายชื่อไว้ที่นี่ ItemCatalog ประกาศไว้แล้วว่า
-- ไอเทมไหนเป็น `kind = "key"` ของ `vehicle` อะไร เพิ่มพาหนะชนิดใหม่จึงเพิ่มที่เดียว
local KEY_ITEM = {}
for id, item in pairs(ItemCatalog.Items) do
  if item.kind == "key" and item.vehicle then
    -- vehicle ในแคตตาล็อกเป็นตัวเล็ก ("car") ส่วนชนิดพาหนะใน Config เป็นตัวใหญ่ ("Car")
    KEY_ITEM[item.vehicle:lower()] = id
  end
end

-- prefix ของทะเบียน (CAR / SEA / AIR) -> ชนิดพาหนะ อ่านจาก Config ชุดเดียวกับที่ VehicleService ใช้ จึงไม่มี
-- ทางที่สองฝั่งจะแปลทะเบียนไม่ตรงกัน
local PREFIX_TO_TYPE = {}
for vtype, spec in pairs(Config.Types) do PREFIX_TO_TYPE[spec.prefix] = vtype end

function Store.keyItemFor(vtype)
  return KEY_ITEM[tostring(vtype):lower()]
end

-- ทุกทะเบียนที่ผู้เล่นถือกุญแจอยู่ตอนนี้ อ่านจากกระเป๋าสดๆ ไม่ได้จำไว้ที่ไหน — ยกกุญแจให้เพื่อนแล้วสิทธิ์
-- ย้ายตามทันทีโดยไม่ต้องมีใครไปลบแถวไหน
function Store.keyPlates(player)
  local out = {}
  local state = Inventory.Get(player)
  if not state then return out end
  for _, slot in pairs(state.slots) do
    local item = slot and ItemCatalog.Get(slot.id)
    if item and item.kind == "key" and slot.meta and type(slot.meta.plate) == "string" then
      out[slot.meta.plate] = true
    end
  end
  return out
end

function Store.hasKey(player, plate)
  return Store.keyPlates(player)[plate] == true
end

-- ช่องกระเป๋าที่กุญแจของทะเบียนนี้อยู่ คืน index กับตัวช่องเอง — ใช้ทั้งตอนอ่าน meta และตอนทิ้งกุญแจ
local function findKeySlot(player, plate)
  local state = Inventory.Get(player)
  if not state then return nil, nil end
  for index, slot in pairs(state.slots) do
    local item = slot and ItemCatalog.Get(slot.id)
    if item and item.kind == "key" and slot.meta and slot.meta.plate == plate then
      return index, slot
    end
  end
  return nil, nil
end

-- ---------------------------------------------------------------- กุญแจ "จดทะเบียนแล้ว" หรือยัง
--
-- ธงอยู่บน **ตัวกุญแจ** ไม่ใช่ในตารางกลาง เพราะเกมไม่มีทะเบียนกลางของทั้งเซิร์ฟเวอร์ — `Store.ownerOf` หา
-- ได้เฉพาะคนที่ออนไลน์อยู่ ถ้าใช้ตัวนั้นตัดสิน คนที่ยืมกุญแจของเพื่อนที่ออฟไลน์ไปจะจดทะเบียนทับได้ทันที
-- และกลายเป็นเจ้าของรถของเพื่อน
--
-- ธงบนไอเทมเดินทางไปกับไอเทม: ยกกุญแจที่จดแล้วให้ใคร คนนั้นก็ยังจดไม่ได้ ซึ่งเป็นกติกาที่ถูกต้องอยู่แล้ว
-- (กุญแจที่ยืมมาไว้ขับ ไม่ใช่ไว้ยึด)
function Store.isRegisteredKey(player, plate)
  local _, slot = findKeySlot(player, plate)
  return slot ~= nil and slot.meta.registered == true
end

function Store.markRegistered(player, plate)
  local _, slot = findKeySlot(player, plate)
  if not slot then return false end
  slot.meta.registered = true
  -- ช่องถูกแก้ตรงๆ ไม่ได้ผ่าน AddItem/RemoveFromSlot จึงต้องบอกไคลเอนต์เอง (Serialize ส่ง state.slots
  -- ตัวเดียวกันนี้ลงโปรไฟล์อยู่แล้ว ธงจึงเซฟตามไปเองโดยไม่ต้องทำอะไรเพิ่ม)
  Inventory.Send(player)
  return true
end

-- คืน false เมื่อกระเป๋าเต็ม ซึ่งผู้เรียกต้องเช็ก: การจดทะเบียนที่แจกกุญแจไม่สำเร็จ = ทะเบียนที่ไม่มีใครเปิดได้
function Store.giveKey(player, plate)
  local prefix = tostring(plate):sub(1, 3)
  local vtype = PREFIX_TO_TYPE[prefix]
  local itemId = vtype and Store.keyItemFor(vtype)
  if not itemId then return false, "ไม่รู้จักชนิดของทะเบียน " .. prefix end
  -- meta คือสิ่งที่ทำให้กุญแจสองดอกไม่กองรวมกัน (Inventory.AddItem ปฏิเสธการรวมกองของทุกอย่างที่มี meta)
  if not Inventory.AddItem(player, itemId, 1, nil, { plate = plate }) then
    return false, "กระเป๋าเต็ม ใส่กุญแจไม่ได้"
  end
  return true
end

-- ทิ้งกุญแจของทะเบียนนี้จากกระเป๋า (ใช้ตอนทดสอบ และตอนคืนทะเบียนในอนาคต)
function Store.takeKey(player, plate)
  local index, slot = findKeySlot(player, plate)
  if not index then return false end
  Inventory.RemoveFromSlot(player, index, slot.count or 1)
  return true
end

function Store.vehicle(player, plate)
  local p = CACHE[player.UserId]
  return p and p.Data.Vehicles[plate] or nil
end

-- เจ้าของทะเบียนนี้ที่กำลังออนไลน์ (ใช้ตอนคนถือกุญแจฝากพาหนะของเพื่อน)
function Store.ownerOf(plate)
  for userId, profile in pairs(CACHE) do
    if profile.Data.Vehicles[plate] then
      return Players:GetPlayerByUserId(userId), profile.Data.Vehicles[plate]
    end
  end
  return nil, nil
end

function Store.start()
  for _, player in ipairs(Players:GetPlayers()) do task.spawn(Store.load, player) end
  Players.PlayerAdded:Connect(function(player) task.spawn(Store.load, player) end)
  Players.PlayerRemoving:Connect(function(player) CACHE[player.UserId] = nil end)
end

return Store
