-- DeviceQualityController: makes the world cheaper to draw on a phone.
--
-- The map is 187,000 parts and every one of them casts a shadow, which is the single most expensive thing in
-- the scene -- shadow cost scales with how many casters are in view, not with how big they are, so a hillside
-- of pebbles costs more than the castle. A desktop absorbs that; a phone renders it at single-figure frame
-- rates and gets hot doing it.
--
-- So the phone gets a cheaper version of the same world rather than a different world: same geometry, same
-- layout, fewer of the effects that cost the most per frame.
--
-- Everything here is CLIENT-side. Shadows, quality level and fog are rendering properties, so turning them
-- down for one player changes nothing for anybody else.
local Lighting = game:GetService("Lighting")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

-- Phones and tablets ONLY, using the same test TouchActionController settled on: a touchscreen laptop and
-- Studio's device emulator both report TouchEnabled while still having a keyboard and mouse, and those
-- machines can afford the full scene.
local function isTouchOnlyDevice()
	return UserInputService.TouchEnabled
		and not UserInputService.KeyboardEnabled
		and not UserInputService.MouseEnabled
end

if not isTouchOnlyDevice() then return end

-- Shadows off. This is the big one, and the reason this file exists: 187,198 casters is not a number a phone
-- can light. Everything is still lit, just not shadowed -- the scene reads slightly flatter and runs several
-- times faster.
Lighting.GlobalShadows = false

-- Grass and other terrain decoration is drawn per-blade over the whole visible ground. It is the second
-- biggest per-frame cost after shadows and the easiest thing to lose: nobody looks at a phone screen and
-- misses individual blades of grass.
pcall(function()
	Workspace.Terrain.Decoration = false
end)

-- Pull the far plane in to HALF what the desktop sees.
--
-- Fog is not decoration here: it is what lets the renderer stop drawing the far side of the map. FogEnd was
-- 24,000, which is far enough that nothing was ever culled by it. Cut to 12,000 for phones, the distance
-- halves, and the horizon fades rather than pops -- which is what makes a draw limit look deliberate instead
-- of broken.
Lighting.FogEnd = math.min(Lighting.FogEnd, 12000)
Lighting.FogStart = math.min(Lighting.FogStart, 6000)

-- Let Roblox pick the rest. Automatic already scales texture and effect quality to the device, and overriding
-- it with a fixed low number would also punish a new flagship phone that could have handled more.
