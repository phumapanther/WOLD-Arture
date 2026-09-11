-- DeviceQualityController: turns the scene down in steps, following the player's own graphics slider.
--
-- The map is 187,000 parts, every one of them casting a shadow, with 1,203 lamps and 25,000 scattered trees
-- and rocks. A desktop absorbs that; a phone renders it at single-figure frame rates and gets hot doing it.
--
-- Rather than one all-or-nothing switch, the scene sheds load in tiers as the slider comes down, so a player
-- can buy back frames a step at a time instead of choosing between beautiful and unplayable:
--
--   level 9-10  everything on
--   level 6-8   shadows off            -- the single most expensive thing in the scene
--   level 3-5   + scenery and clutter hidden
--   level 1-2   + lamps off, draw distance halved
--
-- Phones are pinned to the bottom tier whatever their slider says.
--
-- Every change here is CLIENT-side -- transparency, collision on this client, light Enabled, fog. Nothing
-- reaches the server or another player, and nothing is destroyed: a player who slides the quality back up
-- gets the whole world back, which is why this file hides rather than deletes.
local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local GameSettings = UserSettings():GetService("UserGameSettings")

--------------------------------------------------------------------------------
-- Which tier the player is in
--------------------------------------------------------------------------------

-- The thresholds the user set, converted from their 0-100 wording to the 1-10 scale Roblox exposes:
-- 80% -> 8, 50% -> 5, 20% -> 2.
local SHADOWS_BELOW = 8
local SCENERY_BELOW = 5
local EVERYTHING_BELOW = 2

-- Phones and tablets ONLY, using the same test TouchActionController settled on: a touchscreen laptop and
-- Studio's device emulator both report TouchEnabled while still having a keyboard and mouse.
local function isTouchOnlyDevice()
	return UserInputService.TouchEnabled
		and not UserInputService.KeyboardEnabled
		and not UserInputService.MouseEnabled
end

-- The slider, as a number from 1 to 10.
--
-- Phones read it the same way desktops do rather than being pinned to the bottom. A phone that can afford
-- the scenery should be allowed to show it, and the player is the one who can tell.
--
-- Automatic means the player has not chosen and Roblox is deciding per-frame, so there is no number to read.
-- A desktop is given the benefit of the doubt and left at full; a phone is not, because a phone on Automatic
-- that renders this map at four frames a second has no way to tell anyone.
local function qualityLevel()
	local saved = GameSettings.SavedQualityLevel
	if saved == Enum.SavedQualitySetting.Automatic then
		return isTouchOnlyDevice() and 5 or 10
	end
	return saved.Value
end

--------------------------------------------------------------------------------
-- The things that can be turned down
--------------------------------------------------------------------------------

-- Remembered so the world can be handed back intact. A part's own values are captured the first time it is
-- hidden rather than assumed to be the defaults: some of this map is deliberately semi-transparent, and
-- restoring everything to 0 would make those solid.
local hiddenParts = {}
local disabledLights = {}

local function hidePart(part)
	if hiddenParts[part] then return end
	hiddenParts[part] = { collide = part.CanCollide }
	part.LocalTransparencyModifier = 1
	part.CanCollide = false
end

local function showPart(part)
	local saved = hiddenParts[part]
	if not saved then return end
	hiddenParts[part] = nil
	if part.Parent then
		part.LocalTransparencyModifier = 0
		part.CanCollide = saved.collide
	end
end

local function showEverything()
	for part in pairs(hiddenParts) do showPart(part) end
	for light in pairs(disabledLights) do
		if light.Parent then light.Enabled = true end
	end
	disabledLights = {}
end

--------------------------------------------------------------------------------
-- Scenery: trees, rocks and bushes nobody can harvest
--------------------------------------------------------------------------------

-- The test is whether the game USES the thing, not what it looks like: anything tagged WOLD_Node is a
-- resource someone can chop, mine or pick and is never touched however scenic it is. Measured over the whole
-- world: 20,294 harvestable nodes kept, 5,278 decorative models hidden.
local function isHarvestable(instance)
	local at = instance
	while at and at ~= Workspace do
		if CollectionService:HasTag(at, "WOLD_Node") then return true end
		at = at.Parent
	end
	return false
end

local function eachSceneryPart(instance, fn)
	for _, part in ipairs(instance:GetDescendants()) do
		if part:IsA("BasePart") then fn(part) end
	end
	if instance:IsA("BasePart") then fn(instance) end
end

local function applyScenery(hide)
	for _, tag in ipairs({ "Tree", "Rock", "Bush" }) do
		for _, instance in ipairs(CollectionService:GetTagged(tag)) do
			if not isHarvestable(instance) then
				eachSceneryPart(instance, hide and hidePart or showPart)
			end
		end
	end
end

--------------------------------------------------------------------------------
-- Clutter: the small ornament inside buildings
--------------------------------------------------------------------------------

-- SMALL AND walk-through, not walk-through alone. Seventy percent of the map does not collide, including the
-- roof joists and balusters that hold a building up visually, so hiding everything a player can pass through
-- would take the roofs off the houses. Volume 2 is where a mug and a candlestick fall and a floorboard does
-- not.
local CLUTTER_MAX_VOLUME = 2

local function isClutter(part)
	if part.CanCollide then return false end
	if part.Transparency > 0.9 then return false end
	if part.Size.X * part.Size.Y * part.Size.Z > CLUTTER_MAX_VOLUME then return false end
	-- A part carrying a sign, a light, a prompt, a sound or an effect is doing a job rather than decorating.
	for _, child in ipairs(part:GetChildren()) do
		if child:IsA("Light") or child:IsA("GuiBase3d") or child:IsA("ProximityPrompt")
			or child:IsA("ParticleEmitter") or child:IsA("Sound") then
			return false
		end
	end
	return true
end

local function applyClutter(hide)
	if not hide then return end
	-- Nothing to do when showing: showEverything restores every hidden part at once, and re-testing isClutter
	-- afterwards would fail anyway, since a hidden part has already had its CanCollide taken away.
	for _, part in ipairs(Workspace:GetDescendants()) do
		if part:IsA("BasePart") and isClutter(part) then hidePart(part) end
	end
end

--------------------------------------------------------------------------------
-- Lamps
--------------------------------------------------------------------------------

-- Each of the 1,203 house lights is resolved every frame against everything near it, and that cost does not
-- go away when shadows are off. Lighting's own sun and sky are a different thing and are what stops the map
-- going pitch black, so even the bottom tier keeps those.
local function applyLamps(off)
	if not off then return end
	for _, instance in ipairs(Workspace:GetDescendants()) do
		if instance:IsA("PointLight") or instance:IsA("SpotLight") or instance:IsA("SurfaceLight") then
			if instance.Enabled then
				disabledLights[instance] = true
				instance.Enabled = false
			end
		end
	end
end

--------------------------------------------------------------------------------
-- Post-processing and water
--------------------------------------------------------------------------------

-- Sun rays, bloom and atmosphere are full-screen passes: they cost the same whether the scene in front of
-- them is a castle or an empty field, which makes them some of the best value to switch off on a device that
-- is struggling. Depth of field is already off in this place and is left alone either way.
--
-- Water reflection is the other one. A reflective surface renders the world a second time to put it in the
-- water, and this map has a sea and two lakes.
local EFFECT_NAMES = { "SunRays", "Bloom", "Atmosphere" }

local disabledEffects = {}
local waterWas = nil

local function applyEffects(off)
	if off then
		for _, name in ipairs(EFFECT_NAMES) do
			local effect = Lighting:FindFirstChild(name)
			-- Atmosphere has no Enabled property, so it is removed from Lighting and parented back later
			-- rather than switched -- pcall because which of these exist is the place's business, not this
			-- file's.
			if effect then
				pcall(function()
					if effect.Enabled ~= nil then
						if effect.Enabled then
							disabledEffects[effect] = "enabled"
							effect.Enabled = false
						end
					end
				end)
				if disabledEffects[effect] == nil and effect:IsA("Atmosphere") then
					disabledEffects[effect] = Lighting
					effect.Parent = nil
				end
			end
		end
		if waterWas == nil then
			waterWas = {
				reflectance = Workspace.Terrain.WaterReflectance,
				wave = Workspace.Terrain.WaterWaveSize,
			}
			Workspace.Terrain.WaterReflectance = 0
			Workspace.Terrain.WaterWaveSize = 0
		end
	else
		for effect, how in pairs(disabledEffects) do
			if how == "enabled" then
				pcall(function() effect.Enabled = true end)
			else
				effect.Parent = how
			end
		end
		disabledEffects = {}
		if waterWas then
			Workspace.Terrain.WaterReflectance = waterWas.reflectance
			Workspace.Terrain.WaterWaveSize = waterWas.wave
			waterWas = nil
		end
	end
end

--------------------------------------------------------------------------------
-- Applying a tier
--------------------------------------------------------------------------------

-- Fog doubles as the draw limit: pulled in, the renderer stops drawing the far side of the map and the
-- horizon fades rather than pops. Captured once so it can be handed back.
local fullFogEnd = Lighting.FogEnd
local fullFogStart = Lighting.FogStart

local applied = nil

local function apply()
	local level = qualityLevel()

	local wantShadows = level > SHADOWS_BELOW
	local wantScenery = level > SCENERY_BELOW
	local wantLamps = level > EVERYTHING_BELOW

	-- The floor a phone gets that a desktop does not.
	--
	-- At the bottom of the slider a phone gives up the full-screen effects and the water reflection as well,
	-- which a desktop at the same setting keeps. They are the cheapest things to lose and among the most
	-- expensive to draw, and somebody who has dragged the slider to the bottom on a phone has already said
	-- what they want: frames, not sun rays.
	local wantEffects = wantLamps or not isTouchOnlyDevice()

	-- Nothing to do if the tier has not actually changed; the slider fires this on every nudge.
	local signature = ("%s|%s|%s|%s"):format(tostring(wantShadows), tostring(wantScenery),
		tostring(wantLamps), tostring(wantEffects))
	if signature == applied then return end
	applied = signature

	-- Everything comes back first, then the current tier is re-applied. Restoring and re-hiding is a few
	-- thousand property writes on a change the player made by hand, and it is far easier to be sure of than
	-- working out the difference between two tiers.
	showEverything()

	Lighting.GlobalShadows = wantShadows

	pcall(function()
		Workspace.Terrain.Decoration = wantScenery
	end)
	applyScenery(not wantScenery)
	applyClutter(not wantScenery)

	applyLamps(not wantLamps)
	applyEffects(not wantEffects)
	Lighting.FogEnd = wantLamps and fullFogEnd or math.min(fullFogEnd, 12000)
	Lighting.FogStart = wantLamps and fullFogStart or math.min(fullFogStart, 6000)

	print(("[Quality] level %d%s: shadows=%s scenery=%s lamps=%s effects=%s"):format(
		level, isTouchOnlyDevice() and " (touch)" or "", tostring(wantShadows), tostring(wantScenery),
		tostring(wantLamps), tostring(wantEffects)))
end

-- Re-applied whenever the player moves the slider, so the effect is immediate rather than needing a rejoin.
GameSettings:GetPropertyChangedSignal("SavedQualityLevel"):Connect(apply)

-- Anything that streams in later gets whatever the current tier says, so walking into a fresh village does
-- not bring back the scenery and lamps the tier had already turned off.
--
-- This is also what makes the setting apply to models added to the game in FUTURE: a new tree is hidden by
-- the same rule the existing ones are -- provided it carries the same tag. An untagged tree is invisible to
-- this file, exactly as it is to the gathering system.
local function catchUp(instance)
	if applied == nil then return end
	local level = qualityLevel()
	if instance:IsA("PointLight") or instance:IsA("SpotLight") or instance:IsA("SurfaceLight") then
		if level <= EVERYTHING_BELOW then
			disabledLights[instance] = true
			instance.Enabled = false
		end
		return
	end
	if level > SCENERY_BELOW then return end
	if instance:IsA("BasePart") and isClutter(instance) then hidePart(instance) end
end

Workspace.DescendantAdded:Connect(catchUp)

for _, tag in ipairs({ "Tree", "Rock", "Bush" }) do
	CollectionService:GetInstanceAddedSignal(tag):Connect(function(instance)
		if qualityLevel() > SCENERY_BELOW then return end
		if isHarvestable(instance) then return end
		eachSceneryPart(instance, hidePart)
	end)
end

-- Deferred, because the world streams in: running immediately would only catch whatever had arrived by the
-- time this script ran.
task.defer(apply)
