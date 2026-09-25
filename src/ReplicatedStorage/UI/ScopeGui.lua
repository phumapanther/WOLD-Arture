-- ScopeGui: จอสโคปสไน (ผู้ใช้ส่งภาพมา 2026-09-25) — วาดด้วย Frame ล้วน ไม่มีรูปให้อัปโหลด
--
-- รอบนอกวงเลนส์ทึบด้วย UIStroke ความหนามหาศาลบนวงกลม: เส้นขอบวาดออกด้านนอก จึงถมทุกอย่างนอกวง
-- ในขณะที่ข้างในวงยังใส (มองเห็นโลกผ่านเลนส์) — ทำรูกลมบนแผ่นทึบด้วย Frame ตรงๆ ไม่ได้
local ScopeGui = {}
ScopeGui.__index = ScopeGui

local GREY = Color3.fromRGB(190, 190, 190)
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
	local fill = Instance.new("UIStroke")
	fill.Color = GREY
	fill.Thickness = 3000 -- ถมนอกวงทั้งจอ
	fill.Parent = lens

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
