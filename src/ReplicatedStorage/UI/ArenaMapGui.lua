-- ArenaMapGui: แผนที่สนาม PVP กด M (ผู้ใช้สั่ง 2026-09-24)
--
-- วาดจากชิ้นส่วนของแมพจริงใน workspace มองจากด้านบน — ไม่มีรูปแผนที่ให้ใครต้องวาดมือแล้วลืมอัปเดต
-- แมพเปลี่ยนเมื่อไหร่ แผนที่เปลี่ยนตามเอง
--
-- ponytail: วาดเป็นกล่องแนวแกน (AABB) ของแต่ละชิ้น ไม่หมุนตาม — กำแพงเฉียงจะดูอ้วนขึ้น ถ้าวันหนึ่ง
-- แมพมีกำแพงเฉียงเยอะจนอ่านยาก ค่อยหมุน Frame ตาม yaw ของชิ้น
--
-- จุดบนแผนที่: เรา (ขาวมีขีดบอกทิศ) + เพื่อนร่วมทีมที่ยังยืนอยู่ · **ไม่โชว์ศัตรู** (แผนที่ที่บอกตำแหน่ง
-- ศัตรูคือ wallhack ที่ทุกคนได้ฟรี)
local ArenaConfig = require(script.Parent.Parent.ArenaConfig)

local ArenaMapGui = {}
ArenaMapGui.__index = ArenaMapGui

local LOW = Color3.fromRGB(46, 46, 52)
local HIGH = Color3.fromRGB(206, 200, 188)

function ArenaMapGui.new()
	local self = setmetatable({ dots = {} }, ArenaMapGui)

	local gui = Instance.new("ScreenGui")
	gui.Name = "ArenaMapGui"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 20
	gui.Enabled = false
	self.gui = gui

	local panel = Instance.new("Frame")
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.fromScale(0.72, 0.72)
	panel.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
	panel.BackgroundTransparency = 0.15
	panel.BorderSizePixel = 0
	panel.Parent = gui
	local aspect = Instance.new("UIAspectRatioConstraint")
	aspect.Parent = panel
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 12)
	c.Parent = panel
	self.panel, self.aspect = panel, aspect

	local canvas = Instance.new("Frame")
	canvas.AnchorPoint = Vector2.new(0.5, 0.5)
	canvas.Position = UDim2.fromScale(0.5, 0.5)
	canvas.Size = UDim2.fromScale(0.92, 0.92)
	canvas.BackgroundTransparency = 1
	canvas.ClipsDescendants = true
	canvas.Parent = panel
	self.canvas = canvas

	local title = Instance.new("TextLabel")
	title.Position = UDim2.fromOffset(12, 6)
	title.Size = UDim2.new(1, -24, 0, 24)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBold
	title.TextSize = 18
	title.TextColor3 = Color3.fromRGB(238, 234, 226)
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.ZIndex = 5
	title.Text = "แผนที่ (M)"
	title.Parent = panel
	self.title = title

	return self
end

function ArenaMapGui:SetVisible(on)
	self.gui.Enabled = on and true or false
end

function ArenaMapGui:IsVisible()
	return self.gui.Enabled
end

-- วาดแมพใหม่ถ้าเป็นคนละแมพกับที่วาดไว้ (หรือยังไม่เคยวาด)
function ArenaMapGui:Build(mapId, mapName)
	local folder = workspace:FindFirstChild(ArenaConfig.MapFolder)
	local model = folder and folder:FindFirstChild(mapId or "")
	if not model then return false end
	local parts = {}
	for _, p in ipairs(model:GetDescendants()) do
		if p:IsA("BasePart") and p.Transparency < 0.9 then table.insert(parts, p) end
	end
	-- ⚠️ StreamingEnabled: ชิ้นที่ยังไม่มาถึงไคลเอนต์จะหายจากแผนที่ — วาดใหม่ถ้าจำนวนชิ้นเปลี่ยน
	if self.builtFor == mapId and self.builtCount == #parts then return true end
	self.builtFor, self.builtCount = mapId, #parts
	self.title.Text = ("%s — แผนที่ (M)"):format(mapName or mapId)

	for _, child in ipairs(self.canvas:GetChildren()) do child:Destroy() end
	self.dots = {}

	-- กรอบของทั้งแมพ + ความสูงต่ำสุด/สูงสุด (ใช้ไล่สีว่าอะไรสูงกว่า)
	local minX, maxX, minZ, maxZ, lowTop, highTop = math.huge, -math.huge, math.huge, -math.huge, math.huge, -math.huge
	local boxes = {}
	for _, p in ipairs(parts) do
		local cf, s = p.CFrame, p.Size
		local r, u, l = cf.RightVector, cf.UpVector, cf.LookVector
		local hx = (math.abs(r.X) * s.X + math.abs(u.X) * s.Y + math.abs(l.X) * s.Z) / 2
		local hy = (math.abs(r.Y) * s.X + math.abs(u.Y) * s.Y + math.abs(l.Y) * s.Z) / 2
		local hz = (math.abs(r.Z) * s.X + math.abs(u.Z) * s.Y + math.abs(l.Z) * s.Z) / 2
		local pos = cf.Position
		local top = pos.Y + hy
		minX, maxX = math.min(minX, pos.X - hx), math.max(maxX, pos.X + hx)
		minZ, maxZ = math.min(minZ, pos.Z - hz), math.max(maxZ, pos.Z + hz)
		lowTop, highTop = math.min(lowTop, top), math.max(highTop, top)
		table.insert(boxes, { part = p, x0 = pos.X - hx, x1 = pos.X + hx, z0 = pos.Z - hz, z1 = pos.Z + hz, top = top })
	end
	if #boxes == 0 then return false end

	self.minX, self.minZ = minX, minZ
	self.w, self.d = math.max(1, maxX - minX), math.max(1, maxZ - minZ)
	self.aspect.AspectRatio = self.w / self.d
	-- เตี้ยวาดก่อน สูงทับทีหลัง — พื้นอยู่ล่างสุด กำแพงเห็นชัด
	table.sort(boxes, function(a, b) return a.top < b.top end)
	local range = math.max(1, highTop - lowTop)

	for i, b in ipairs(boxes) do
		local f = Instance.new("Frame")
		f.BorderSizePixel = 0
		f.Position = UDim2.fromScale((b.x0 - minX) / self.w, (b.z0 - minZ) / self.d)
		f.Size = UDim2.fromScale((b.x1 - b.x0) / self.w, (b.z1 - b.z0) / self.d)
		local spawnSide = b.part.Parent and b.part.Parent.Name:match("^Spawn(%u)$")
		if spawnSide and ArenaConfig.Teams[spawnSide] then
			f.BackgroundColor3 = ArenaConfig.Teams[spawnSide].colour
		else
			f.BackgroundColor3 = LOW:Lerp(HIGH, (b.top - lowTop) / range)
		end
		f.ZIndex = 1
		f.LayoutOrder = i
		f.Parent = self.canvas
	end
	return true
end

-- `marks` = { { pos = Vector3, look = Vector3?, colour = Color3, me = bool } }
function ArenaMapGui:SetMarks(marks)
	if not self.w then return end
	for i, mark in ipairs(marks) do
		local dot = self.dots[i]
		if not dot then
			dot = Instance.new("Frame")
			dot.AnchorPoint = Vector2.new(0.5, 0.5)
			dot.BorderSizePixel = 0
			dot.ZIndex = 4
			local round = Instance.new("UICorner")
			round.CornerRadius = UDim.new(1, 0)
			round.Parent = dot
			local stroke = Instance.new("UIStroke")
			stroke.Thickness = 2
			stroke.Color = Color3.fromRGB(10, 10, 12)
			stroke.Parent = dot
			-- ขีดบอกทิศที่หันอยู่ · ⚠️ Rotation หมุนรอบกึ่งกลางของ Frame เอง ไม่ใช่รอบ AnchorPoint —
			-- จึงหมุนกล่องใสที่ครอบจุดไว้ แล้วให้ขีดอยู่ครึ่งบนของกล่อง
			local nose = Instance.new("Frame")
			nose.Name = "Nose"
			nose.AnchorPoint = Vector2.new(0.5, 0.5)
			nose.Position = UDim2.fromScale(0.5, 0.5)
			nose.Size = UDim2.fromScale(2.8, 2.8)
			nose.BackgroundTransparency = 1
			nose.ZIndex = 3
			nose.Parent = dot
			local bar = Instance.new("Frame")
			bar.AnchorPoint = Vector2.new(0.5, 0)
			bar.Position = UDim2.fromScale(0.5, 0)
			bar.Size = UDim2.new(0, 3, 0.5, 0)
			bar.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
			bar.BorderSizePixel = 0
			bar.ZIndex = 3
			bar.Parent = nose
			dot.Parent = self.canvas
			self.dots[i] = dot
		end
		dot.Visible = true
		dot.Size = UDim2.fromOffset(mark.me and 16 or 12, mark.me and 16 or 12)
		dot.BackgroundColor3 = mark.colour
		dot.Position = UDim2.fromScale((mark.pos.X - self.minX) / self.w, (mark.pos.Z - self.minZ) / self.d)
		local nose = dot:FindFirstChild("Nose")
		nose.Visible = mark.look ~= nil
		if mark.look then
			-- หน้าจอ: ขึ้น = -Z ของโลก · Rotation หมุนตามเข็ม
			nose.Rotation = math.deg(math.atan2(mark.look.X, -mark.look.Z))
		end
	end
	for i = #marks + 1, #self.dots do self.dots[i].Visible = false end
end

return ArenaMapGui
