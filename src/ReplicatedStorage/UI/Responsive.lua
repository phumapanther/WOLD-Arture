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

return Responsive
