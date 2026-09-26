-- Responsive: shared viewport scaling for the GUI builders. Every screen is laid out at fixed pixel sizes
-- tuned for a ~1280px-wide viewport; a UIScale on each top-level group lets the whole thing shrink together
-- on smaller screens (phones especially) while keeping every internal ratio exactly as designed.
--
-- Extracted from HudGui once ChannelSelectGui needed it too: without a scale its fixed-width mode tabs
-- overflowed the right edge on a phone (measured 985px of content on a 909px viewport).
local Responsive = {}

Responsive.BaselineWidth = 1280
Responsive.MinScale = 0.5 -- below this, text stops being readable; better to clip than to shrink further

-- Attaches a UIScale to `parent` that tracks the viewport width, and keeps tracking it across camera swaps.
-- `minScale` overrides the default floor for screens that can afford to shrink further.
function Responsive.Scale(parent, minScale)
	local scale = Instance.new("UIScale")
	scale.Parent = parent
	local floor = minScale or Responsive.MinScale
	local camera = workspace.CurrentCamera

	local function update()
		local width = camera and camera.ViewportSize.X or Responsive.BaselineWidth
		scale.Scale = math.clamp(width / Responsive.BaselineWidth, floor, 1)
	end

	update()
	if camera then camera:GetPropertyChangedSignal("ViewportSize"):Connect(update) end
	workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
		camera = workspace.CurrentCamera
		update()
		if camera then camera:GetPropertyChangedSignal("ViewportSize"):Connect(update) end
	end)
	return scale
end

-- True when the viewport is phone-shaped. Used to pick between layouts rather than only scaling one down —
-- a landscape phone is short, so vertical space is the scarce axis, not horizontal.
function Responsive.IsSmallScreen()
	local camera = workspace.CurrentCamera
	if not camera then return false end
	return camera.ViewportSize.X < 900 or camera.ViewportSize.Y < 500
end

-- มือถือ/แท็บเล็ตล้วน: จอสัมผัสและไม่มีคีย์บอร์ด — ใช้เลือกคำบอกปุ่ม ("กด B" → "แตะ 🛒") ไม่ใช่เลือกเลย์เอาต์
-- จอสัมผัสที่มีคีย์บอร์ด (โน้ตบุ๊กจอสัมผัส) กดคีย์ได้ จึงนับเป็นคอม (QA 2026-09-26)
function Responsive.IsTouchOnly()
	local UserInputService = game:GetService("UserInputService")
	return UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
end

-- เพดานย่อของกลุ่มปุ่มมุมขวาบน (⋯ เมนู · ! สอนเล่น · 🏗️ จัดเกาะ) — สามกลุ่มต้องใช้ค่าเดียวกัน ไม่งั้นเลื่อนคนละทาง
-- มือถือไม่ย่อเลย: ที่ 0.55 ปุ่ม 44 px เหลือ ~26 px เล็กกว่านิ้ว (QA 2026-09-26)
function Responsive.CornerMinScale()
	return Responsive.IsTouchOnly() and 1 or 0.55
end

-- Taller than it is wide: a phone held upright. Worth its own branch because the scarce axis flips — there is
-- plenty of height for stacked rows but almost no width, so anything laid out as a horizontal strip has to be
-- re-arranged rather than merely scaled.
function Responsive.IsPortrait()
	local camera = workspace.CurrentCamera
	if not camera then return false end
	return camera.ViewportSize.Y > camera.ViewportSize.X
end

-- Runs `callback` now and again whenever the viewport changes shape (rotation, window resize), so a layout
-- that branches on IsPortrait/IsSmallScreen can rebuild itself instead of being frozen at whatever the screen
-- was when the GUI was first constructed.
function Responsive.OnViewportChanged(callback)
	local camera = workspace.CurrentCamera
	local last = camera and camera.ViewportSize or Vector2.zero

	local function check()
		local now = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize
		if not now then return end
		-- Only fire on a real shape change; ViewportSize also ticks during window drags.
		if math.abs(now.X - last.X) < 1 and math.abs(now.Y - last.Y) < 1 then return end
		last = now
		callback(now)
	end

	if camera then camera:GetPropertyChangedSignal("ViewportSize"):Connect(check) end
	workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
		camera = workspace.CurrentCamera
		if camera then camera:GetPropertyChangedSignal("ViewportSize"):Connect(check) end
		check()
	end)
end

-- The dark glass used by the lobby's channel panel. Shared so other surfaces (the touch action buttons) can
-- match it exactly rather than each guessing at "dark and see-through" and drifting apart.
Responsive.GlassColor = Color3.fromRGB(10, 10, 14)
Responsive.GlassTransparency = 0.45

return Responsive
