-- ScopeGui: จอสโคปสไน (ผู้ใช้ส่งภาพมา 2026-09-25) — วาดด้วย Frame ล้วน ไม่มีรูปให้อัปโหลด
--
-- รอบนอกวงเลนส์ถมด้วย UIStroke ความหนามหาศาลบนวงกลม: เส้นขอบวาดออกด้านนอก จึงถมทุกอย่างนอกวง
-- ในขณะที่ข้างในวงยังใส (มองเห็นโลกผ่านเลนส์) — ทำรูกลมบนแผ่นทึบด้วย Frame ตรงๆ ไม่ได้
--
-- **นอกวงเป็นสีมืดโปร่ง ไม่ใช่เบลอ** (ผู้ใช้ขอเบลอ 2026-09-25): Roblox เบลอได้แค่ทั้งจอ (BlurEffect)
-- ซึ่งจะเบลอในเลนส์ด้วยจนเล็งไม่ได้ และ UI ไม่มี backdrop blur — มืดโปร่ง + ขอบเลนส์มืดไล่ระดับคือที่ใกล้สุด
local ScopeGui = {}
ScopeGui.__index = ScopeGui

local SHADE = Color3.fromRGB(12, 12, 14)
local OUTSIDE_TRANSPARENCY = 0.4 -- นอกวงเห็นโลกจางๆ (0 = ทึบ · 1 = ใสหมด)
local TICK = Color3.fromRGB(150, 150, 150)

local function frame(parent, props)
	local f = Instance.new("Frame")
	f.BorderSizePixel = 0
	for k, v in pairs(props) do f[k] = v end
	f.Parent = parent
	return f
end

function ScopeGui.new()
	local self = setmetatable({}, ScopeGui)
	local gui = Instance.new("ScreenGui")
	gui.Name = "WOLD_Scope"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 6
	gui.Enabled = false
	self.gui = gui

	-- วงเลนส์: สี่เหลี่ยมจัตุรัส 86% ของความสูงจอ มุมโค้งเต็ม = วงกลม
	local lens = frame(gui, {
		Name = "Lens", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.86, 0.86), BackgroundTransparency = 1,
	})
	local aspect = Instance.new("UIAspectRatioConstraint")
	aspect.DominantAxis = Enum.DominantAxis.Height
	aspect.Parent = lens
	local round = Instance.new("UICorner")
	round.CornerRadius = UDim.new(1, 0)
	round.Parent = lens
	-- ชั้นแรกถมนอกวงทั้งจอ ชั้นถัดไปบางลงเรื่อยๆ ซ้อนทับกันที่ขอบเลนส์ = ขอบมืดไล่ระดับออกไป
	-- (หนึ่ง GuiObject มี UIStroke ได้เส้นเดียว จึงต้องเป็นวงซ้อนหลายวง)
	for _, band in ipairs({ { 3000, OUTSIDE_TRANSPARENCY }, { 70, 0.8 }, { 35, 0.72 }, { 14, 0.55 } }) do
		local ring = frame(lens, { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 })
		local ringRound = Instance.new("UICorner")
		ringRound.CornerRadius = UDim.new(1, 0)
		ringRound.Parent = ring
		local fill = Instance.new("UIStroke")
		fill.Color = SHADE
		fill.Thickness = band[1]
		fill.Transparency = band[2]
		fill.Parent = ring
	end

	-- ขอบดำของเลนส์: วงซ้อนข้างใน ขอบบาง
	local rim = frame(lens, { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 })
	local rimRound = Instance.new("UICorner")
	rimRound.CornerRadius = UDim.new(1, 0)
	rimRound.Parent = rim
	local rimStroke = Instance.new("UIStroke")
	rimStroke.Color = Color3.fromRGB(25, 25, 25)
	rimStroke.Thickness = 4
	rimStroke.Parent = rim

	-- กากบาทสี่ขีดจากขอบเข้าหากลาง เว้นช่องกลาง (สัดส่วนจากภาพ: ขีดยาว ~24% ของเส้นผ่านศูนย์กลาง)
	local LONG, THICK = 0.24, 0.035
	frame(lens, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0), Size = UDim2.fromScale(THICK, LONG), BackgroundColor3 = TICK })
	frame(lens, { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.fromScale(0.5, 1), Size = UDim2.fromScale(THICK, LONG), BackgroundColor3 = TICK })
	frame(lens, { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.fromScale(0, 0.5), Size = UDim2.fromScale(LONG, THICK), BackgroundColor3 = TICK })
	frame(lens, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.fromScale(1, 0.5), Size = UDim2.fromScale(LONG, THICK), BackgroundColor3 = TICK })
	-- + ตรงกลาง
	frame(lens, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.08, 0.012), BackgroundColor3 = TICK })
	frame(lens, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.012, 0.08), BackgroundColor3 = TICK })
	return self
end

function ScopeGui:Show() self.gui.Enabled = true end
function ScopeGui:Hide() self.gui.Enabled = false end

return ScopeGui
