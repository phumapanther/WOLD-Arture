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

--------------------------------------------------------------------------------
-- Scenery a phone does not have to draw
--------------------------------------------------------------------------------

-- Trees, rocks and bushes that cannot be harvested are pure decoration, and there are 11,759 parts of them
-- -- most of it in Elderwood, which is exactly where a phone struggles most.
--
-- The test is whether the game USES the thing, not what it looks like: anything tagged WOLD_Node is a
-- resource someone can chop, mine or pick, and is never touched however scenic it is. What is left over is
-- tagged Tree/Rock/Bush for the sake of the world generator and does nothing else.
--
-- Hidden, not destroyed, and made walk-through with it.
--
-- Hiding alone would be worse than leaving them: an invisible tree you bump into is a bug, not a saving. So
-- collision goes as well, and on a phone these stop existing as far as the player is concerned.
--
-- Both properties are client-side. LocalTransparencyModifier is the display-only channel, and CanCollide set
-- on the client governs that client's own physics, so neither reaches the server or anybody else. Destroying
-- them instead would leave this client disagreeing with the server about what is in the world.
local CollectionService = game:GetService("CollectionService")

local function isHarvestable(instance)
	-- Walk up as well as check the instance itself: the tag can sit on the model while the parts hang below.
	local at = instance
	while at and at ~= Workspace do
		if CollectionService:HasTag(at, "WOLD_Node") then return true end
		at = at.Parent
	end
	return false
end

local function hideScenery()
	local hidden, kept = 0, 0
	for _, tag in ipairs({ "Tree", "Rock", "Bush" }) do
		for _, instance in ipairs(CollectionService:GetTagged(tag)) do
			if isHarvestable(instance) then
				kept += 1
			else
				hidden += 1
				for _, part in ipairs(instance:GetDescendants()) do
					if part:IsA("BasePart") then
						-- LocalTransparencyModifier rather than Transparency: it is the client-only channel,
						-- so a later server update to Transparency does not fight it.
						part.LocalTransparencyModifier = 1
						part.CanCollide = false
					end
				end
				if instance:IsA("BasePart") then
					instance.LocalTransparencyModifier = 1
					instance.CanCollide = false
				end
			end
		end
	end
	print(("[Quality] phone: hid %d scenery models, kept %d harvestable"):format(hidden, kept))
end

-- Deferred, because the world streams in: running immediately would only catch whatever had arrived by the
-- time this script ran, and the tags arrive with the models.
task.defer(hideScenery)

-- Anything that streams in later gets the same treatment, so walking into a fresh chunk does not bring the
-- scenery back with it.
for _, tag in ipairs({ "Tree", "Rock", "Bush" }) do
	CollectionService:GetInstanceAddedSignal(tag):Connect(function(instance)
		if isHarvestable(instance) then return end
		for _, part in ipairs(instance:GetDescendants()) do
			if part:IsA("BasePart") then
				part.LocalTransparencyModifier = 1
				part.CanCollide = false
			end
		end
		if instance:IsA("BasePart") then
			instance.LocalTransparencyModifier = 1
			instance.CanCollide = false
		end
	end)
end

-- Let Roblox pick the rest. Automatic already scales texture and effect quality to the device, and overriding
-- it with a fixed low number would also punish a new flagship phone that could have handled more.
