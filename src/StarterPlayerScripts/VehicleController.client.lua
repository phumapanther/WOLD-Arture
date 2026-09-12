-- VehicleController — หน้าจอฝั่งผู้เล่น: แผงโรงรถ (เบิก/ฝาก/ล็อก), แผงท้ายพาหนะ, แถบสถานะตอนขับ
-- ไม่มีตรรกะสิทธิ์อยู่ในนี้เลย ทุกปุ่มคือการ "ขอ" ไปที่เซิร์ฟเวอร์แล้ววาดผลลัพธ์ที่ตอบกลับมา
--
-- ยกมาจาก VehicleClient ของโปรเจ็ค WOLD-Vehicle ต่างจากต้นทางแค่สองจุด: ข้ามการทำงานในล็อบบี้ (ที่นั่น
-- ไม่มีระบบพาหนะให้คุย) และแถวของในท้ายพาหนะอ่านชื่อ/ไอคอนจาก ItemCatalog ของเกมแทนตารางไอเทมทดสอบ
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

-- ล็อบบี้ไม่มีระบบพาหนะ และ Net.get() ฝั่งไคลเอนต์จะยืนรอโฟลเดอร์ที่ไม่มีวันมาจนหมดเวลาแล้ว assert ทิ้ง
while workspace:GetAttribute("IsLobby") == nil do
  task.wait()
end
if workspace:GetAttribute("IsLobby") then return end

local Config = require(game.ReplicatedStorage.Vehicle.Config)
local Net = require(game.ReplicatedStorage.Vehicle.Net)
local ItemCatalog = require(game.ReplicatedStorage.ItemCatalog)
local net = Net.get()

local player = Players.LocalPlayer
local PALETTE = {
  ink = Color3.fromRGB(22, 19, 16),
  panel = Color3.fromRGB(38, 32, 27),
  row = Color3.fromRGB(50, 42, 34),
  brass = Color3.fromRGB(206, 164, 86),
  brassDim = Color3.fromRGB(138, 108, 52),
  text = Color3.fromRGB(238, 226, 204),
  soft = Color3.fromRGB(176, 160, 136),
  good = Color3.fromRGB(126, 196, 142),
  warn = Color3.fromRGB(224, 146, 110),
}

local function make(class, props, children)
  local inst = Instance.new(class)
  for k, v in pairs(props) do
    if k ~= "Parent" then inst[k] = v end
  end
  for _, child in ipairs(children or {}) do child.Parent = inst end
  if props.Parent then inst.Parent = props.Parent end
  return inst
end

local function corner(r) return make("UICorner", { CornerRadius = UDim.new(0, r or 8) }) end
local function stroke(color, t) return make("UIStroke", { Color = color or PALETTE.brassDim, Thickness = t or 1.5 }) end
local function pad(n) return make("UIPadding", {
  PaddingTop = UDim.new(0, n), PaddingBottom = UDim.new(0, n),
  PaddingLeft = UDim.new(0, n), PaddingRight = UDim.new(0, n) }) end

local gui = make("ScreenGui", {
  Name = "VehicleUI", ResetOnSpawn = false, IgnoreGuiInset = true,
  ZIndexBehavior = Enum.ZIndexBehavior.Sibling, Parent = player:WaitForChild("PlayerGui"),
})

-- ---------------------------------------------------------------- ข้อความเด้ง
local toastHolder = make("Frame", {
  Name = "Toasts", Parent = gui, BackgroundTransparency = 1,
  AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 16),
  Size = UDim2.new(0, 520, 0, 200),
}, { make("UIListLayout", { Padding = UDim.new(0, 6), HorizontalAlignment = Enum.HorizontalAlignment.Center,
  SortOrder = Enum.SortOrder.LayoutOrder }) })

local function toast(text, kind)
  local color = kind == "warn" and PALETTE.warn or (kind == "ok" and PALETTE.good or PALETTE.text)
  local label = make("TextLabel", {
    Parent = toastHolder, BackgroundColor3 = PALETTE.ink, BackgroundTransparency = 0.1,
    Size = UDim2.new(1, 0, 0, 34), Font = Enum.Font.GothamMedium, TextSize = 16,
    TextColor3 = color, Text = text, AutomaticSize = Enum.AutomaticSize.Y,
  }, { corner(6), stroke(PALETTE.brassDim, 1), pad(6) })
  task.delay(3.2, function()
    TweenService:Create(label, TweenInfo.new(0.4), { BackgroundTransparency = 1, TextTransparency = 1 }):Play()
    task.wait(0.45)
    label:Destroy()
  end)
end

-- ---------------------------------------------------------------- โครงแผง
local panel = make("Frame", {
  Name = "Panel", Parent = gui, Visible = false, BackgroundColor3 = PALETTE.panel,
  AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
  Size = UDim2.fromOffset(720, 470),
}, { corner(12), stroke(PALETTE.brass, 2) })

local scaler = make("UIScale", { Parent = panel })
local function fitPanel()
  local vp = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1280, 720)
  scaler.Scale = math.clamp(math.min(vp.X / 780, vp.Y / 540), 0.55, 1.1)
end
fitPanel()
if workspace.CurrentCamera then
  workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(fitPanel)
end

local header = make("Frame", {
  Parent = panel, BackgroundColor3 = PALETTE.ink, Size = UDim2.new(1, 0, 0, 58),
}, { corner(12) })
make("Frame", { Parent = header, BackgroundColor3 = PALETTE.ink, BorderSizePixel = 0,
  Position = UDim2.new(0, 0, 1, -12), Size = UDim2.new(1, 0, 0, 12) })

local title = make("TextLabel", {
  Parent = header, BackgroundTransparency = 1, Font = Enum.Font.Garamond, TextSize = 28,
  TextColor3 = PALETTE.brass, TextXAlignment = Enum.TextXAlignment.Left,
  Position = UDim2.new(0, 18, 0, 6), Size = UDim2.new(1, -80, 0, 30), Text = "โรงรถ",
})
local subtitle = make("TextLabel", {
  Parent = header, BackgroundTransparency = 1, Font = Enum.Font.Gotham, TextSize = 14,
  TextColor3 = PALETTE.soft, TextXAlignment = Enum.TextXAlignment.Left,
  Position = UDim2.new(0, 19, 0, 33), Size = UDim2.new(1, -80, 0, 18), Text = "",
})
local closeBtn = make("TextButton", {
  Parent = header, BackgroundColor3 = PALETTE.row, Text = "X", Font = Enum.Font.GothamBold,
  TextSize = 18, TextColor3 = PALETTE.text, AnchorPoint = Vector2.new(1, 0.5),
  Position = UDim2.new(1, -14, 0.5, 0), Size = UDim2.fromOffset(34, 34),
}, { corner(8), stroke(PALETTE.brassDim, 1) })

local body = make("Frame", {
  Parent = panel, BackgroundTransparency = 1,
  Position = UDim2.new(0, 0, 0, 58), Size = UDim2.new(1, 0, 1, -58),
}, { pad(14) })

local function clearBody()
  for _, c in ipairs(body:GetChildren()) do
    if not c:IsA("UIPadding") then c:Destroy() end
  end
end

local function closePanel()
  panel.Visible = false
end
closeBtn.MouseButton1Click:Connect(closePanel)

local function button(text, parent, color, width)
  return make("TextButton", {
    Parent = parent, BackgroundColor3 = color or PALETTE.row, Text = text,
    Font = Enum.Font.GothamMedium, TextSize = 14, TextColor3 = PALETTE.text,
    Size = UDim2.fromOffset(width or 86, 30), AutoButtonColor = true,
  }, { corner(6), stroke(PALETTE.brassDim, 1) })
end

local function request(msg)
  local ok, result = pcall(function() return net.Request:InvokeServer(msg) end)
  if not ok then
    toast("ติดต่อเซิร์ฟเวอร์ไม่ได้", "warn")
    return nil
  end
  if type(result) ~= "table" then return nil end
  if result.err then toast(result.err, "warn") end
  if result.toast then toast(result.toast, "ok") end
  return result
end

-- ---------------------------------------------------------------- แผงโรงรถ
local currentStation = nil
local renderTrunk                                 -- ประกาศไว้ก่อน แผงโรงรถมีปุ่มเปิดท้ายที่เรียกถึงมัน

local function renderGarage(data)
  currentStation = data.station
  data.vehicles = data.vehicles or {}
  clearBody()
  title.Text = (data.station and data.station.title) or "โรงรถของฉัน"
  -- ค่าบริการมาจากเซิร์ฟเวอร์ (คิดตามระยะจากบารอนเวนถึงลานจอด) เขียนบอกไว้ตั้งแต่ก่อนกด ไม่ใช่ให้รู้ตอน
  -- เงินหายไปแล้ว
  local money = string.format("เงิน %d เหรียญ", data.gold or 0)
  if data.station then
    subtitle.Text = string.format("%s · ค่าเบิก %d เหรียญ (ห่างบารอนเวน %d studs) · %s",
      data.station.title or (data.display or ""), data.retrieveFee or 0, data.retrieveStuds or 0, money)
  else
    subtitle.Text = "พาหนะทั้งหมดที่คุณมีกุญแจ · " .. money
  end

  local list = make("ScrollingFrame", {
    Parent = body, BackgroundTransparency = 1, BorderSizePixel = 0,
    Size = UDim2.new(1, 0, 1, -46), CanvasSize = UDim2.new(),
    AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 5,
    ScrollBarImageColor3 = PALETTE.brassDim,
  }, { make("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }) })

  if #data.vehicles == 0 then
    make("TextLabel", {
      Parent = list, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 80),
      Font = Enum.Font.Gotham, TextSize = 15, TextColor3 = PALETTE.soft, TextWrapped = true,
      Text = "ยังไม่มีทะเบียนของชนิดนี้เลย — กดจดทะเบียนคันใหม่ด้านล่างเพื่อรับกุญแจ",
    })
  end

  for _, v in ipairs(data.vehicles) do
    local spec = Config.Types[v.vtype] or {}
    local row = make("Frame", {
      Parent = list, BackgroundColor3 = PALETTE.row, Size = UDim2.new(1, -6, 0, 62),
    }, { corner(8), stroke(PALETTE.brassDim, 1) })

    make("TextLabel", {
      Parent = row, BackgroundTransparency = 1, Font = Enum.Font.GothamBold, TextSize = 17,
      TextColor3 = PALETTE.brass, TextXAlignment = Enum.TextXAlignment.Left,
      Position = UDim2.new(0, 14, 0, 8), Size = UDim2.new(0, 240, 0, 20),
      Text = (spec.icon or "") .. " " .. v.plate,
    })
    make("TextLabel", {
      Parent = row, BackgroundTransparency = 1, Font = Enum.Font.Gotham, TextSize = 13,
      TextColor3 = PALETTE.soft, TextXAlignment = Enum.TextXAlignment.Left,
      Position = UDim2.new(0, 14, 0, 32), Size = UDim2.new(0, 320, 0, 18),
      Text = string.format("%s · %s%s%s", spec.display or v.vtype,
        v.out and "อยู่ในโลก" or "จอดในโรงเก็บ",
        v.locked and " · 🔒 ล็อกอยู่" or "",
        v.fuel and string.format(" · 🔥 %d%%", v.fuel) or ""),
    })

    local actions = make("Frame", {
      Parent = row, BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0.5),
      Position = UDim2.new(1, -12, 0.5, 0), Size = UDim2.fromOffset(360, 32),
    }, { make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6),
      HorizontalAlignment = Enum.HorizontalAlignment.Right, VerticalAlignment = Enum.VerticalAlignment.Center }) })

    if v.out then
      local stow = button("ฝากคืน", actions)
      stow.MouseButton1Click:Connect(function()
        local r = request({ action = "Stow", plate = v.plate, stationId = currentStation and currentStation.id })
        if r and r.vehicles then renderGarage(r) end
      end)
      local lock = button(v.locked and "ปลดล็อก" or "ล็อก", actions, v.locked and PALETTE.row or PALETTE.ink)
      lock.MouseButton1Click:Connect(function()
        local r = request({ action = "Lock", plate = v.plate, locked = not v.locked, stationId = currentStation and currentStation.id })
        if r and r.vehicles then renderGarage(r) end
      end)
      local fuel = button("เติมถ่าน", actions, (v.fuel and v.fuel < 40) and PALETTE.warn or PALETTE.row, 78)
      fuel.MouseButton1Click:Connect(function()
        local r = request({ action = "Refuel", plate = v.plate, stationId = currentStation and currentStation.id })
        if r and r.vehicles then renderGarage(r) end
      end)
      local trunk = button("เปิดท้าย", actions)
      trunk.MouseButton1Click:Connect(function()
        local r = request({ action = "Trunk", plate = v.plate })
        if r and r.ok then renderTrunk(r) end
      end)
    else
      local fee = data.retrieveFee or 0
      local call = button(fee > 0 and ("เบิก · " .. fee .. " เหรียญ") or "เบิกออกมา", actions, PALETTE.ink, 150)
      call.MouseButton1Click:Connect(function()
        local r = request({ action = "Summon", plate = v.plate, stationId = currentStation and currentStation.id })
        if r and r.vehicles then renderGarage(r) end
      end)
    end
  end

  local footer = make("Frame", {
    Parent = body, BackgroundTransparency = 1, AnchorPoint = Vector2.new(0, 1),
    Position = UDim2.new(0, 0, 1, 0), Size = UDim2.new(1, 0, 0, 34),
  }, { make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8),
    VerticalAlignment = Enum.VerticalAlignment.Center }) })

  if data.canRegister then
    -- ที่แท่นเรียกจดได้เฉพาะชนิดของจุดนั้น ส่วนที่บารอนเวน (ไม่มี station) จดได้ทุกชนิด — เขาคือโรงรถ
    local kinds = data.vtype and { data.vtype } or { "Car", "Boat", "Airship" }
    for _, vtype in ipairs(kinds) do
      local spec = Config.Types[vtype]
      if spec then
        local reg = button("📜 จดทะเบียน" .. spec.display, footer, PALETTE.ink, data.vtype and 250 or 150)
        reg.MouseButton1Click:Connect(function()
          local r = request({ action = "Register", vtype = vtype, stationId = currentStation and currentStation.id })
          if r and r.vehicles then renderGarage(r) end
        end)
      end
    end
  end
  make("TextLabel", {
    Parent = footer, BackgroundTransparency = 1, Font = Enum.Font.Gotham, TextSize = 12,
    TextColor3 = PALETTE.soft, TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.new(0, 340, 1, 0),
    Text = "กุญแจเป็นไอเทมในกระเป๋า · ยกให้เพื่อนได้ · ค่าฝากคิดตามระยะจากบารอนเวนถึงจุดที่จอด",
  })

  panel.Visible = true
end

-- ---------------------------------------------------------------- แผงท้ายพาหนะ
local function itemRows(parent, source, plate, toTrunk, onChange)
  for _, c in ipairs(parent:GetChildren()) do
    if not c:IsA("UIListLayout") then c:Destroy() end
  end
  local empty = true
  for id, count in pairs(source) do
    empty = false
    -- ชื่อกับรูปมาจากแคตตาล็อกของเกม ไม่ใช่ตารางไอเทมทดสอบของโปรเจ็คต้นทาง — ไอคอนที่นี่เป็น rbxassetid
    -- (รูปจริง) ไม่ใช่อีโมจิ จึงต้องวาดเป็น ImageLabel ไม่ใช่ต่อเข้าไปในข้อความ
    local item = ItemCatalog.Get(id)
    local row = make("Frame", { Parent = parent, BackgroundColor3 = PALETTE.row, Size = UDim2.new(1, -6, 0, 38) },
      { corner(6), stroke(PALETTE.brassDim, 1) })
    make("ImageLabel", {
      Parent = row, BackgroundTransparency = 1, Image = (item and item.icon) or "",
      Position = UDim2.new(0, 8, 0.5, -11), Size = UDim2.new(0, 22, 0, 22),
    })
    make("TextLabel", {
      Parent = row, BackgroundTransparency = 1, Font = Enum.Font.Gotham, TextSize = 14,
      TextColor3 = PALETTE.text, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd,
      Position = UDim2.new(0, 36, 0, 0), Size = UDim2.new(1, -146, 1, 0),
      Text = string.format("%s  x%d", (item and item.name) or id, count),
    })
    local one = button(toTrunk and ">" or "<", row, PALETTE.ink, 32)
    one.AnchorPoint = Vector2.new(1, 0.5)
    one.Position = UDim2.new(1, -46, 0.5, 0)
    local all = button(toTrunk and ">>" or "<<", row, PALETTE.ink, 40)
    all.AnchorPoint = Vector2.new(1, 0.5)
    all.Position = UDim2.new(1, -6, 0.5, 0)
    one.MouseButton1Click:Connect(function() onChange(id, 1, toTrunk) end)
    all.MouseButton1Click:Connect(function() onChange(id, count, toTrunk) end)
  end
  if empty then
    make("TextLabel", {
      Parent = parent, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 40),
      Font = Enum.Font.Gotham, TextSize = 13, TextColor3 = PALETTE.soft, Text = "— ว่าง —",
    })
  end
end

renderTrunk = function(data)
  clearBody()
  local used = 0
  for _ in pairs(data.trunk) do used += 1 end
  title.Text = "ท้าย" .. (data.display or "พาหนะ") .. " " .. data.plate
  subtitle.Text = string.format("ช่องเก็บของ %d/%d ช่อง", used, data.capacity)

  local function column(x, w, heading)
    local holder = make("Frame", {
      Parent = body, BackgroundTransparency = 1,
      Position = UDim2.new(x, 0, 0, 0), Size = UDim2.new(w, -6, 1, 0),
    })
    make("TextLabel", {
      Parent = holder, BackgroundTransparency = 1, Font = Enum.Font.GothamBold, TextSize = 14,
      TextColor3 = PALETTE.brass, TextXAlignment = Enum.TextXAlignment.Left,
      Size = UDim2.new(1, 0, 0, 24), Text = heading,
    })
    return make("ScrollingFrame", {
      Parent = holder, BackgroundTransparency = 1, BorderSizePixel = 0,
      Position = UDim2.new(0, 0, 0, 26), Size = UDim2.new(1, 0, 1, -26),
      CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
      ScrollBarThickness = 5, ScrollBarImageColor3 = PALETTE.brassDim,
    }, { make("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.Name }) })
  end

  local bagList = column(0, 0.5, "🎒 กระเป๋าของคุณ")
  local trunkList = column(0.5, 0.5, "📦 ท้ายพาหนะ")

  local function refresh(payload)
    itemRows(bagList, payload.bag, payload.plate, true, function(id, count, toTrunk)
      local r = request({ action = "Move", plate = payload.plate, item = id, count = count, toTrunk = toTrunk })
      if r and r.ok then renderTrunk(r) end
    end)
    itemRows(trunkList, payload.trunk, payload.plate, false, function(id, count, toTrunk)
      local r = request({ action = "Move", plate = payload.plate, item = id, count = count, toTrunk = toTrunk })
      if r and r.ok then renderTrunk(r) end
    end)
  end
  refresh(data)
  panel.Visible = true
end

-- ---------------------------------------------------------------- แถบสถานะตอนขับ
local hud = make("Frame", {
  Name = "DriveHUD", Parent = gui, Visible = false, BackgroundColor3 = PALETTE.ink,
  BackgroundTransparency = 0.15, AnchorPoint = Vector2.new(0.5, 1),
  Position = UDim2.new(0.5, 0, 1, -18), Size = UDim2.fromOffset(440, 84),
}, { corner(10), stroke(PALETTE.brass, 2), pad(10) })

local hudTitle = make("TextLabel", {
  Parent = hud, BackgroundTransparency = 1, Font = Enum.Font.Garamond, TextSize = 22,
  TextColor3 = PALETTE.brass, TextXAlignment = Enum.TextXAlignment.Left,
  Size = UDim2.new(1, -180, 0, 24), Text = "",
})
local hudHint = make("TextLabel", {
  Parent = hud, BackgroundTransparency = 1, Font = Enum.Font.Gotham, TextSize = 13,
  TextColor3 = PALETTE.soft, TextXAlignment = Enum.TextXAlignment.Left,
  Position = UDim2.new(0, 0, 0, 28), Size = UDim2.new(1, 0, 0, 28), TextWrapped = true, Text = "",
})
local hudSpeed = make("TextLabel", {
  Parent = hud, BackgroundTransparency = 1, Font = Enum.Font.GothamBold, TextSize = 24,
  TextColor3 = PALETTE.text, TextXAlignment = Enum.TextXAlignment.Right,
  AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 0), Size = UDim2.fromOffset(176, 26), Text = "",
})

-- เกจพลังงานใต้แถบสถานะ
local fuelTrack = make("Frame", {
  Parent = hud, BackgroundColor3 = PALETTE.row, BorderSizePixel = 0,
  AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 0, 1, 0), Size = UDim2.new(1, 0, 0, 7),
}, { corner(4) })
local fuelBar = make("Frame", {
  Parent = fuelTrack, BackgroundColor3 = PALETTE.brass, BorderSizePixel = 0, Size = UDim2.new(1, 0, 1, 0),
}, { corner(4) })

local driving = nil          -- { plate, mode, model }
local lift = 0
local warnedLow = false
local lastAim, lastAimSent = 0, 0

local function findModel(plate)
  local folder = workspace:FindFirstChild(Config.Folder)
  if not folder then return nil end
  for _, m in ipairs(folder:GetChildren()) do
    if m:GetAttribute("Plate") == plate then return m end
  end
  return nil
end

local function setDriving(data)
  if not data or not data.plate then
    driving = nil
    hud.Visible = false
    lift = 0
    lastAim = 0
    return
  end
  driving = { plate = data.plate, mode = data.mode, model = findModel(data.plate) }
  hudTitle.Text = (data.display or "พาหนะ") .. "  " .. data.plate
  hudHint.Text = data.mode == "Hover"
    and "W/S เดินหน้า-ถอย · A/D เลี้ยว · เล็งกล้องขึ้น/ลงเพื่อไต่-ดิ่ง · R/F ขึ้น-ลงตรงๆ · H หวูด · L ล็อก · ซ้อน " .. (data.seats or 0) .. " ที่"
    or "W/S เร่ง-ถอย · A/D เลี้ยว · H หวูด · L ล็อก · เบาะซ้อน " .. (data.seats or 0) .. " ที่"
  hud.Visible = true
end

RunService.RenderStepped:Connect(function()
  if not driving then return end
  local model = driving.model
  if not model or not model.Parent then
    driving.model = findModel(driving.plate)
    model = driving.model
  end
  if not model then return end
  local speed = model:GetAttribute("Speed") or 0
  if driving.mode == "Hover" then
    hudSpeed.Text = string.format("%d  สูง %d", speed, model:GetAttribute("Altitude") or 0)
  else
    hudSpeed.Text = tostring(speed)
  end

  -- ส่งมุมเล็งกล้องให้เซิร์ฟเวอร์ เฉพาะตอนขยับจริงและไม่เกิน ~12 ครั้ง/วินาที
  if driving.mode == "Hover" then
    local cam = workspace.CurrentCamera
    local aim = cam and math.clamp(cam.CFrame.LookVector.Y, -1, 1) or 0
    local now = os.clock()
    if math.abs(aim - lastAim) > 0.035 and now - lastAimSent > 0.08 then
      lastAim, lastAimSent = aim, now
      net.Signal:FireServer({ action = "Aim", value = aim })
    end
  end

  local fuel = math.clamp((model:GetAttribute("Fuel") or 100) / 100, 0, 1)
  fuelBar.Size = UDim2.new(fuel, 0, 1, 0)
  fuelBar.BackgroundColor3 = fuel <= 0.001 and PALETTE.warn
    or (fuel < 0.2 and Color3.fromRGB(226, 168, 96) or PALETTE.brass)
  if fuel < 0.2 and not warnedLow then
    warnedLow = true
    toast("🔥 ถ่านใกล้หมด — แวะเติมที่ NPC", "warn")
  elseif fuel >= 0.25 then
    warnedLow = false
  end
end)

UserInputService.InputBegan:Connect(function(input, processed)
  if processed or not driving then return end
  if input.KeyCode == Enum.KeyCode.L then
    local model = driving.model or findModel(driving.plate)
    local locked = model and model:GetAttribute("IsLocked") ~= true
    request({ action = "Lock", plate = driving.plate, locked = locked })
  elseif input.KeyCode == Enum.KeyCode.H then
    net.Signal:FireServer({ action = "Horn" })
  elseif driving.mode == "Hover" then
    if input.KeyCode == Enum.KeyCode.R then lift = 1; net.Signal:FireServer({ action = "Lift", value = 1 })
    elseif input.KeyCode == Enum.KeyCode.F then lift = -1; net.Signal:FireServer({ action = "Lift", value = -1 }) end
  end
end)

UserInputService.InputEnded:Connect(function(input)
  if not driving or driving.mode ~= "Hover" then return end
  if (input.KeyCode == Enum.KeyCode.R and lift > 0) or (input.KeyCode == Enum.KeyCode.F and lift < 0) then
    lift = 0
    net.Signal:FireServer({ action = "Lift", value = 0 })
  end
end)

-- ---------------------------------------------------------------- ข้อความจากเซิร์ฟเวอร์
net.Signal.OnClientEvent:Connect(function(msg)
  if type(msg) ~= "table" then return end
  if msg.action == "Toast" then
    toast(msg.text, msg.kind)
  elseif msg.action == "Garage" then
    renderGarage(msg)
  elseif msg.action == "Trunk" then
    renderTrunk(msg)
  elseif msg.action == "Driving" then
    setDriving(msg)
  end
end)
