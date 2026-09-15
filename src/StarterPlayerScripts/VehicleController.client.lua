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
      Text = "ยังไม่มีทะเบียนของชนิดนี้เลย — ต้องได้กุญแจมาก่อน แล้วกุญแจจะมาโผล่ที่นี่ให้กดจดทะเบียน",
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
      Text = v.unregistered
        and string.format("%s · 🔑 กุญแจในกระเป๋า ยังไม่ได้จดทะเบียน", spec.display or v.vtype)
        or string.format("%s · %s%s%s%s", spec.display or v.vtype,
          v.out and "อยู่ในโลก" or "จอดในโรงเก็บ",
          v.locked and " · 🔒 ล็อกอยู่" or "",
          v.fuel and string.format(" · 🔥 %d%%", v.fuel) or "",
          v.durability and ((v.durability <= 0 and " · ⚙️ พังแล้ว")
            or string.format(" · ⚙️ %d%%", v.durability)) or ""),
    })

    local actions = make("Frame", {
      Parent = row, BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0.5),
      Position = UDim2.new(1, -12, 0.5, 0), Size = UDim2.fromOffset(360, 32),
    }, { make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6),
      HorizontalAlignment = Enum.HorizontalAlignment.Right, VerticalAlignment = Enum.VerticalAlignment.Center }) })

    if v.unregistered then
      -- การจดคือสิ่งเดียวที่ทำได้กับกุญแจที่ยังไม่มีรถผูกอยู่ — เบิก/ล็อก/เปิดท้ายไม่มีอะไรให้ทำทั้งนั้น
      -- และเป็นเหตุผลที่ปุ่มนี้ย้ายมาอยู่บนแถว: เดิมอยู่ท้ายแผงเป็น "จดทะเบียนรถไอน้ำ" ลอยๆ ที่กดแล้วเสก
      -- รถใหม่ทั้งคัน ตอนนี้การจดผูกกับกุญแจดอกใดดอกหนึ่งเสมอ
      --
      -- แถวว่างเปล่าเมื่อ canRegister ปิด: ไม่ใส่ปุ่มอื่นแทน เพราะไม่มีปุ่มไหนที่จะทำงานได้จริง
      if data.canRegister then
        local reg = button("📜 จดทะเบียน", actions, PALETTE.ink, 130)
        reg.MouseButton1Click:Connect(function()
          local r = request({ action = "Register", plate = v.plate, stationId = currentStation and currentStation.id })
          if r and r.vehicles then renderGarage(r) end
        end)
      end
    -- บารอนเวนทำสี่อย่าง: เบิก · ฝากคืน · เติมถ่าน · ซ่อม — และไม่ทำอย่างอื่นเลย ตามที่ผู้ใช้กำหนด
    --
    -- ล็อก/ปลดล็อกกับเปิดท้ายถูกเอาออกจากที่นี่ ไม่ได้หายไปไหน: ทั้งสองมีปุ่ม E ของตัวเองอยู่ที่ตัวพาหนะ
    -- อยู่แล้ว (`wireLockPrompt` / `wireTrunk` ใน Service) และเป็นสิ่งที่ทำกับรถที่อยู่ตรงหน้า ไม่ใช่สิ่งที่
    -- สั่งจากโรงรถอีกฟากเมือง
    --
    -- เติมถ่านกับซ่อมขึ้นเฉพาะตอน **ฝากแล้ว** เพราะเป็นเงื่อนไขของบริการเอง เซิร์ฟเวอร์ปฏิเสธคันที่ยังอยู่
    -- ในโลกอยู่แล้ว การซ่อนปุ่มจึงเป็นการพูดกติกาเดิมให้ตรงกัน ไม่ใช่กติกาที่สอง
    elseif v.out then
      local stow = button("ฝากคืน", actions, PALETTE.ink, 90)
      stow.MouseButton1Click:Connect(function()
        local r = request({ action = "Stow", plate = v.plate, stationId = currentStation and currentStation.id })
        if r and r.vehicles then renderGarage(r) end
      end)
    else
      local fee = data.retrieveFee or 0
      local call = button(fee > 0 and ("เบิก · " .. fee) or "เบิกออกมา", actions, PALETTE.ink, 128)
      call.MouseButton1Click:Connect(function()
        local r = request({ action = "Summon", plate = v.plate, stationId = currentStation and currentStation.id })
        if r and r.vehicles then renderGarage(r) end
      end)

      if v.fuel and v.fuel < 100 and data.serviceRefuel then
        local refuel = button("เติมถ่าน · " .. data.serviceRefuel, actions,
          v.fuel < 40 and PALETTE.warn or PALETTE.row, 138)
        refuel.MouseButton1Click:Connect(function()
          local r = request({ action = "ServiceRefuel", plate = v.plate, stationId = currentStation and currentStation.id })
          if r and r.vehicles then renderGarage(r) end
        end)
      end
      if v.durability and v.durability < 100 and data.serviceRepair then
        local fix = button("ซ่อม · " .. data.serviceRepair, actions,
          v.durability <= 0 and PALETTE.warn or PALETTE.row, 120)
        fix.MouseButton1Click:Connect(function()
          local r = request({ action = "ServiceRepair", plate = v.plate, stationId = currentStation and currentStation.id })
          if r and r.vehicles then renderGarage(r) end
        end)
      end
    end
  end

  local footer = make("Frame", {
    Parent = body, BackgroundTransparency = 1, AnchorPoint = Vector2.new(0, 1),
    Position = UDim2.new(0, 0, 1, 0), Size = UDim2.new(1, 0, 0, 34),
  }, { make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8),
    VerticalAlignment = Enum.VerticalAlignment.Center }) })

  -- ไม่มีปุ่ม "จดทะเบียน<ชนิด>" ท้ายแผงอีกแล้ว การจดเริ่มจากกุญแจที่ถืออยู่เสมอ ปุ่มจึงอยู่บนแถวของกุญแจ
  -- ดอกนั้น ถ้าไม่มีกุญแจในกระเป๋าก็ไม่มีอะไรให้จด ซึ่งเป็นข้อความที่ตัวแผงว่างเปล่าบอกได้เองอยู่แล้ว
  make("TextLabel", {
    Parent = footer, BackgroundTransparency = 1, Font = Enum.Font.Gotham, TextSize = 12,
    TextColor3 = PALETTE.soft, TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.new(0, 420, 1, 0),
    Text = "ต้องมีกุญแจในกระเป๋าก่อนถึงจดทะเบียนได้ · ยกกุญแจให้เพื่อนได้ · ค่าฝากคิดตามระยะจากบารอนเวน",
  })

  panel.Visible = true
end

-- ---------------------------------------------------------------- แผงท้ายพาหนะ
-- ช่องเป็น **กริด** ไม่ใช่รายการยาว ผู้ใช้สั่งให้ "แบ่งช่องแบ่งกริดให้สวยงาม" และมันอ่านง่ายกว่าจริง: ท้าย
-- เรือเหาะมี 24 ช่อง ซึ่งเป็นรายการที่ต้องเลื่อนสี่หน้าจอ แต่เป็นกริดแค่หกแถว
--
-- หนึ่งช่อง = หนึ่งชนิดของ ไอคอนใหญ่ตรงกลาง จำนวนมุมขวาล่าง ชื่อใต้ภาพ กดที่ช่องย้ายทีละชิ้น กดปุ่มมุมขวาบน
-- ย้ายทั้งกอง — สองจังหวะที่ต่างกันชัดโดยไม่ต้องมีปุ่ม < << สองอันข้างกันเหมือนเดิม
local TILE = 74

local function itemTiles(parent, source, toTrunk, onChange)
  for _, c in ipairs(parent:GetChildren()) do
    if not c:IsA("UIGridLayout") then c:Destroy() end
  end
  local empty = true
  for id, count in pairs(source) do
    empty = false
    local item = ItemCatalog.Get(id)
    local tile = make("TextButton", {
      Parent = parent, BackgroundColor3 = PALETTE.row, AutoButtonColor = true, Text = "",
      Size = UDim2.fromOffset(TILE, TILE),
    }, { corner(8), stroke(PALETTE.brassDim, 1) })

    make("ImageLabel", {
      Parent = tile, BackgroundTransparency = 1, Image = (item and item.icon) or "",
      ScaleType = Enum.ScaleType.Fit,
      AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 6), Size = UDim2.fromOffset(34, 34),
    })
    make("TextLabel", {
      Parent = tile, BackgroundTransparency = 1, Font = Enum.Font.Gotham, TextSize = 11,
      TextColor3 = PALETTE.text, TextTruncate = Enum.TextTruncate.AtEnd,
      AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -4), Size = UDim2.new(1, -6, 0, 14),
      Text = (item and item.name) or id,
    })
    -- จำนวน วางทับมุมล่างซ้ายของไอคอน แบบเดียวกับช่องในกระเป๋า
    make("TextLabel", {
      Parent = tile, BackgroundTransparency = 1, Font = Enum.Font.GothamBold, TextSize = 12,
      TextColor3 = PALETTE.brass, TextXAlignment = Enum.TextXAlignment.Right,
      AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -6, 0, 30), Size = UDim2.fromOffset(30, 14),
      Text = count > 1 and ("x" .. count) or "",
    })

    tile.MouseButton1Click:Connect(function() onChange(id, 1, toTrunk) end)

    -- ทั้งกอง: ปุ่มเล็กมุมขวาบนของช่อง ทิศของลูกศรบอกว่าของจะไปทางไหน
    if count > 1 then
      local all = make("TextButton", {
        Parent = tile, BackgroundColor3 = PALETTE.ink, AutoButtonColor = true,
        Font = Enum.Font.GothamBold, TextSize = 11, TextColor3 = PALETTE.brass,
        AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -4, 0, 4), Size = UDim2.fromOffset(20, 16),
        Text = toTrunk and "≫" or "≪",
      }, { corner(4) })
      all.MouseButton1Click:Connect(function() onChange(id, count, toTrunk) end)
    end
  end
  if empty then
    make("TextLabel", {
      Parent = parent, BackgroundTransparency = 1, Size = UDim2.fromOffset(TILE * 2, 40),
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

  -- แถบล่างกันไว้ให้ปุ่มเติมถ่าน กริดจึงสั้นลงเท่านั้น
  local FOOTER = 40

  local function column(x, w, heading)
    local holder = make("Frame", {
      Parent = body, BackgroundTransparency = 1,
      Position = UDim2.new(x, 0, 0, 0), Size = UDim2.new(w, -6, 1, -FOOTER),
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
    }, { make("UIGridLayout", {
      CellSize = UDim2.fromOffset(TILE, TILE), CellPadding = UDim2.fromOffset(6, 6),
      SortOrder = Enum.SortOrder.Name,
      -- ช่องต่อแถวปล่อยให้ความกว้างเป็นตัวกำหนด: แผงหดบนจอมือถือแล้วกริดพับเองโดยไม่ต้องคำนวณ
      HorizontalAlignment = Enum.HorizontalAlignment.Left,
    }) })
  end

  local bagList = column(0, 0.5, "🎒 กระเป๋าของคุณ")
  local trunkList = column(0.5, 0.5, "📦 ท้ายพาหนะ")

  local function move(id, count, toTrunk)
    local r = request({ action = "Move", plate = data.plate, item = id, count = count, toTrunk = toTrunk })
    if r and r.ok then renderTrunk(r) end
  end
  itemTiles(bagList, data.bag, true, move)
  itemTiles(trunkList, data.trunk, false, move)

  ------------------------------------------------------------------------------
  -- เติมถ่านที่ตัวรถ
  ------------------------------------------------------------------------------
  -- ผู้ใช้: "การเติมถ่านทำให้มาเติมที่ตัวรถได้ โดยเปิดท้ายรถ แล้วมีปุ่มให้กดเติมด้านล่างขวา"
  --
  -- อยู่ที่นี่เพราะถ่านอยู่ในกระเป๋า และแผงนี้คือที่ที่ของย้ายระหว่างกระเป๋ากับรถอยู่แล้ว การเติมคือการ
  -- โยนถ่านเข้าเตา ซึ่งเป็นการย้ายของอีกแบบหนึ่งพอดี ต่างจากการเติมที่บารอนเวนที่จ่ายเป็นเงินแล้วจบ
  local footer = make("Frame", {
    Parent = body, BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 1),
    Position = UDim2.new(1, 0, 1, 0), Size = UDim2.new(1, 0, 0, FOOTER - 6),
  })
  make("TextLabel", {
    Parent = footer, BackgroundTransparency = 1, Font = Enum.Font.Gotham, TextSize = 12,
    TextColor3 = PALETTE.soft, TextXAlignment = Enum.TextXAlignment.Left,
    Position = UDim2.new(0, 0, 0, 0), Size = UDim2.new(1, -190, 1, 0), TextWrapped = true,
    Text = data.fuel and string.format("🔥 ถ่านในเตา %d%%  ·  เติมเต็มถังใช้ถ่าน %d ก้อน",
      data.fuel, data.coalPerFullTank or 100) or "",
  })
  local refuel = make("TextButton", {
    Parent = footer, BackgroundColor3 = (data.fuel and data.fuel < 40) and PALETTE.warn or PALETTE.ink,
    AutoButtonColor = true, Font = Enum.Font.GothamBold, TextSize = 14, TextColor3 = PALETTE.brass,
    AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0), Size = UDim2.fromOffset(180, 30),
    Text = "🔥 เติมถ่านจากกระเป๋า",
  }, { corner(6), stroke(PALETTE.brassDim, 1) })
  refuel.MouseButton1Click:Connect(function()
    local r = request({ action = "Refuel", plate = data.plate })
    -- request เด้ง toast ของ err ให้แล้ว ตรงนี้แค่ไม่วาดใหม่ถ้าไม่มีอะไรเปลี่ยน
    if not r or r.err then return end
    -- เติมแล้วเปิดแผงท้ายรถใหม่ ไม่ใช่แผงโรงรถ: คนกดยังยืนอยู่ที่ท้ายรถ และเพิ่งเสียถ่านไปจากกระเป๋า
    -- ซึ่งเป็นตัวเลขที่เปลี่ยนบนหน้าจอนี้พอดี
    local again = request({ action = "Trunk", plate = data.plate })
    if again and again.ok then renderTrunk(again) end
  end)

  panel.Visible = true
end

-- ---------------------------------------------------------------- แถบสถานะตอนขับ
-- สามชั้น อ่านจากบนลงล่างตามลำดับที่คนขับต้องการจริง:
--
--   ชื่อคัน + ทะเบียน  ซ้าย   |   ความเร็ว ตัวใหญ่  ขวา
--   เกจถ่าน            ซ้าย   |   เกจความคงทน       ขวา
--   ปุ่มที่กดได้                                     เต็มความกว้าง
--
-- ของเดิมเป็นสองบรรทัดกับเกจเส้นเดียวไม่มีป้ายว่าเกจอะไร ตอนนี้มีสองเกจแล้ว การไม่บอกว่าอันไหนคืออันไหน
-- จะกลายเป็นปริศนา — เกจแต่ละอันจึงมีไอคอน ชื่อ และตัวเลขเป็นเปอร์เซ็นต์ของตัวเอง
local hud = make("Frame", {
  Name = "DriveHUD", Parent = gui, Visible = false, BackgroundColor3 = PALETTE.ink,
  BackgroundTransparency = 0.08, AnchorPoint = Vector2.new(0.5, 1),
  Position = UDim2.new(0.5, 0, 1, -18), Size = UDim2.fromOffset(468, 118),
}, { corner(12), stroke(PALETTE.brass, 2), pad(12) })

local hudTitle = make("TextLabel", {
  Parent = hud, BackgroundTransparency = 1, Font = Enum.Font.Garamond, TextSize = 22,
  TextColor3 = PALETTE.brass, TextXAlignment = Enum.TextXAlignment.Left,
  TextTruncate = Enum.TextTruncate.AtEnd,
  Size = UDim2.new(1, -244, 0, 26), Text = "",
})

-- ไฟบูสต์ ติดอยู่ข้างชื่อคัน ที่เดียวกับที่ตาอยู่ตอนเร่ง
local hudBoost = make("TextLabel", {
  Parent = hud, BackgroundColor3 = PALETTE.warn, BackgroundTransparency = 0.1, Visible = false,
  Font = Enum.Font.GothamBold, TextSize = 12, TextColor3 = Color3.fromRGB(28, 22, 12),
  AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -116, 0, 3), Size = UDim2.fromOffset(62, 20),
  Text = "⚡ บูสต์",
}, { corner(5) })

-- ความเร็ว ตัวใหญ่สุดในแถบ พร้อมหน่วยตัวเล็กใต้เลข เพื่อให้เลขไม่ต้องแบกคำอธิบายไว้ในตัวเอง
local hudSpeed = make("TextLabel", {
  Parent = hud, BackgroundTransparency = 1, Font = Enum.Font.GothamBold, TextSize = 30,
  TextColor3 = PALETTE.text, TextXAlignment = Enum.TextXAlignment.Right,
  AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, -2), Size = UDim2.fromOffset(108, 32),
  Text = "0",
})
local hudUnit = make("TextLabel", {
  Parent = hud, BackgroundTransparency = 1, Font = Enum.Font.Gotham, TextSize = 11,
  TextColor3 = PALETTE.soft, TextXAlignment = Enum.TextXAlignment.Right,
  AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 30), Size = UDim2.fromOffset(108, 13),
  Text = "stud/s",
})

-- เกจหนึ่งอัน: ไอคอน+ชื่อซ้าย เปอร์เซ็นต์ขวา รางเต็มความกว้างใต้ทั้งคู่
local function meter(x, w, label)
  local holder = make("Frame", {
    Parent = hud, BackgroundTransparency = 1,
    Position = UDim2.new(x, x > 0 and 6 or 0, 0, 46), Size = UDim2.new(w, -6, 0, 30),
  })
  local name = make("TextLabel", {
    Parent = holder, BackgroundTransparency = 1, Font = Enum.Font.Gotham, TextSize = 12,
    TextColor3 = PALETTE.soft, TextXAlignment = Enum.TextXAlignment.Left,
    Size = UDim2.new(1, -44, 0, 14), Text = label,
  })
  local readout = make("TextLabel", {
    Parent = holder, BackgroundTransparency = 1, Font = Enum.Font.GothamBold, TextSize = 12,
    TextColor3 = PALETTE.text, TextXAlignment = Enum.TextXAlignment.Right,
    AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 0), Size = UDim2.fromOffset(44, 14),
    Text = "",
  })
  local track = make("Frame", {
    Parent = holder, BackgroundColor3 = PALETTE.row, BorderSizePixel = 0,
    Position = UDim2.new(0, 0, 0, 18), Size = UDim2.new(1, 0, 0, 8),
  }, { corner(4) })
  local bar = make("Frame", {
    Parent = track, BackgroundColor3 = PALETTE.brass, BorderSizePixel = 0, Size = UDim2.new(1, 0, 1, 0),
  }, { corner(4) })
  return { name = name, readout = readout, bar = bar }
end

local fuelMeter = meter(0, 0.5, "🔥 ถ่านในเตา")
local wearMeter = meter(0.5, 0.5, "⚙️ ความคงทน")

local hudHint = make("TextLabel", {
  Parent = hud, BackgroundTransparency = 1, Font = Enum.Font.Gotham, TextSize = 11,
  TextColor3 = PALETTE.soft, TextXAlignment = Enum.TextXAlignment.Left,
  AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 0, 1, 0), Size = UDim2.new(1, 0, 0, 14),
  TextTruncate = Enum.TextTruncate.AtEnd, Text = "",
})

-- เขียนค่าลงเกจหนึ่งอัน สีเปลี่ยนตามความน่ากังวล ไม่ใช่ตามชนิดของเกจ — ทั้งสองอันจึงอ่านด้วยสายตาชุดเดียวกัน
local function setMeter(m, fraction, broken)
  fraction = math.clamp(fraction, 0, 1)
  m.bar.Size = UDim2.new(fraction, 0, 1, 0)
  m.bar.BackgroundColor3 = (fraction <= 0.001) and PALETTE.warn
    or (fraction < 0.2 and Color3.fromRGB(226, 168, 96) or PALETTE.brass)
  m.readout.Text = broken and "พังแล้ว" or (math.floor(fraction * 100 + 0.5) .. "%")
  m.readout.TextColor3 = (fraction < 0.2) and PALETTE.warn or PALETTE.text
end

local driving = nil          -- { plate, mode, model }
local lift = 0
local boosting = false
local warnedLow, warnedWear = false, false
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
    -- ปล่อยบูสต์เอง ไม่รอ InputEnded: การลุกจากเบาะไม่ได้ปล่อยปุ่ม Shift และเซิร์ฟเวอร์ก็ล้างธงของมันเอง
    -- อยู่แล้ว การค้าง true ไว้ฝั่งนี้จะทำให้การขึ้นรถคันถัดไปไม่ส่งค่าเริ่มต้นเพราะคิดว่าส่งไปแล้ว
    boosting = false
    lastAim = 0
    warnedWear = false
    return
  end
  driving = { plate = data.plate, mode = data.mode, model = findModel(data.plate) }
  hudTitle.Text = (data.display or "พาหนะ") .. "  " .. data.plate
  hudHint.Text = data.mode == "Hover"
    and "W/S เดินหน้า-ถอย · Shift บูสต์ · A/D เลี้ยว · เล็งกล้องไต่-ดิ่ง · R/F ขึ้น-ลง · H หวูด · L ล็อก · ซ้อน " .. (data.seats or 0)
    or "W/S เร่ง-ถอย · Shift บูสต์ · A/D เลี้ยว · H หวูด · L ล็อก · เบาะซ้อน " .. (data.seats or 0) .. " ที่"
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
  hudSpeed.Text = tostring(speed)
  -- ความสูงไปอยู่บรรทัดหน่วย ไม่ใช่ยัดเข้าไปในตัวเลขใหญ่: สองตัวเลขในช่องเดียวที่ฟอนต์ขนาด 30 คือช่องที่
  -- ล้นเสมอ และตัวไหนคือความเร็วก็เดาไม่ออก
  hudUnit.Text = driving.mode == "Hover"
    and ("stud/s · สูง " .. (model:GetAttribute("Altitude") or 0))
    or "stud/s"

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
  setMeter(fuelMeter, fuel)
  if fuel < 0.2 and not warnedLow then
    warnedLow = true
    toast("🔥 ถ่านใกล้หมด — เปิดท้ายรถแล้วกดเติมถ่าน", "warn")
  elseif fuel >= 0.25 then
    warnedLow = false
  end

  local wear = math.clamp((model:GetAttribute("Durability") or 100) / 100, 0, 1)
  setMeter(wearMeter, wear, wear <= 0.001)
  if wear < 0.25 and not warnedWear then
    warnedWear = true
    toast("⚙️ สภาพรถย่ำแย่ — ให้นักประดิษฐ์ซ่อม หรือฝากคืนกับบารอนเวนแล้วกดซ่อม", "warn")
  elseif wear >= 0.3 then
    warnedWear = false
  end

  -- ไฟบูสต์ตามค่าที่ **เซิร์ฟเวอร์** ตัดสิน ไม่ใช่ตามปุ่มที่กดค้างอยู่: ถ่านต่ำเกินหรือรถพังแล้วบูสต์ไม่ติด
  -- ไฟจึงต้องดับตามไปด้วย ไม่งั้นมันจะโกหกว่ากำลังเร่งอยู่
  hudBoost.Visible = model:GetAttribute("Boost") == true
end)

UserInputService.InputBegan:Connect(function(input, processed)
  if processed or not driving then return end
  if input.KeyCode == Enum.KeyCode.L then
    local model = driving.model or findModel(driving.plate)
    local locked = model and model:GetAttribute("IsLocked") ~= true
    request({ action = "Lock", plate = driving.plate, locked = locked })
  elseif input.KeyCode == Enum.KeyCode.H then
    net.Signal:FireServer({ action = "Horn" })
  elseif input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.RightShift then
    -- Shift เป็นปุ่มวิ่งตอนเดินเท้าด้วย แต่ตอนนั่งอยู่บนเบาะ ความเร็วเดินไม่มีความหมาย ปุ่มจึงว่างพอดี
    -- ส่งขอบขาขึ้น/ขาลงอย่างละครั้ง ไม่ใช่ทุกเฟรม — เซิร์ฟเวอร์ถือธงไว้เอง
    if not boosting then
      boosting = true
      net.Signal:FireServer({ action = "Boost", value = true })
    end
  elseif driving.mode == "Hover" then
    if input.KeyCode == Enum.KeyCode.R then lift = 1; net.Signal:FireServer({ action = "Lift", value = 1 })
    elseif input.KeyCode == Enum.KeyCode.F then lift = -1; net.Signal:FireServer({ action = "Lift", value = -1 }) end
  end
end)

UserInputService.InputEnded:Connect(function(input)
  if not driving then return end
  -- ปล่อย Shift ไม่เช็ก `processed`: การกดเริ่มอาจถูก UI กินไปแต่การปล่อยต้องผ่านเสมอ ไม่งั้นบูสต์ค้าง
  if input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.RightShift then
    if boosting then
      boosting = false
      net.Signal:FireServer({ action = "Boost", value = false })
    end
    return
  end
  if driving.mode ~= "Hover" then return end
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
