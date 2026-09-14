-- WeaponPrefabs.server.lua: builds the held weapon models into ReplicatedStorage.WOLD_Weapons at startup.
--
-- These used to be Creator Store models turned into prefabs by a one-off script that was never committed --
-- and which destroyed its own source models on the way out. When the folder disappeared from the place there
-- was no way to rebuild it, and every weapon silently vanished from players' hands (holdWeapon finds no
-- prefab and returns quietly). Building them from parts in code means the place file holds nothing the
-- project cannot recreate on its own.
--
-- Each model is one welded rigid body with a PrimaryPart, laid out along its LOCAL +Y with the grip end at
-- +Y, because that is the convention WeaponVisuals' GRIP offsets were measured against.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FOLDER_NAME = "WOLD_Weapons"

-- Colours picked to read at a glance in a crowd rather than to be realistic.
local STEEL = Color3.fromRGB(198, 202, 212)
local DARK_STEEL = Color3.fromRGB(120, 126, 138)
local WOOD = Color3.fromRGB(122, 84, 52)
local DARK_WOOD = Color3.fromRGB(84, 58, 38)
local LEATHER = Color3.fromRGB(72, 52, 40)
local GOLD = Color3.fromRGB(198, 158, 78)
local GEM = Color3.fromRGB(96, 226, 158)
local PAGES = Color3.fromRGB(232, 224, 198)

local function part(name, size, cf, color, material)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	-- A held weapon must never collide with its owner or be shoved by physics.
	p.Anchored = false
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	return p
end

-- Welds every part to the primary one and returns the finished model.
local function assemble(name, primary, others)
	local model = Instance.new("Model")
	model.Name = name
	primary.Parent = model
	model.PrimaryPart = primary
	for _, p in ipairs(others) do
		p.Parent = model
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = primary
		weld.Part1 = p
		weld.Parent = primary
	end
	return model
end

--------------------------------------------------------------------------------
-- The four weapons
--------------------------------------------------------------------------------

local Builders = {}

-- Sword: blade at the origin, hilt at +Y. WeaponVisuals flips it 180 so the point stands up, and offsets by
-- 2.0 studs to put the HANDLE in the palm -- both measured against exactly this layout, so it must not move.
function Builders.Sword()
	local blade = part("Blade", Vector3.new(0.22, 3.0, 0.5), CFrame.new(0, 0, 0), STEEL, Enum.Material.Metal)
	local others = {
		part("Tip", Vector3.new(0.22, 0.5, 0.5), CFrame.new(0, -1.65, 0), STEEL, Enum.Material.Metal),
		part("Guard", Vector3.new(0.24, 0.18, 1.3), CFrame.new(0, 1.55, 0), GOLD, Enum.Material.Metal),
		part("Handle", Vector3.new(0.26, 0.9, 0.26), CFrame.new(0, 2.0, 0), LEATHER),
		part("Pommel", Vector3.new(0.36, 0.32, 0.36), CFrame.new(0, 2.5, 0), GOLD, Enum.Material.Metal),
	}
	return assemble("Sword", blade, others)
end

-- Greatsword: built from parts like every other weapon here.
--
-- The id the user supplied (131042286719658) is a DECAL, not a Model -- it is the inventory icon, and there
-- is no 3D greatsword on the account to load. So the weapon in the hand is built to the sword's layout at
-- half again the size: blade at the origin, hilt at +Y, which is what WeaponVisuals' grip maths expects.
--
-- If a real model is uploaded later, this is the one function to replace.
function Builders.Greatsword()
	local blade = part("Blade", Vector3.new(0.34, 4.4, 0.8), CFrame.new(0, 0, 0), STEEL, Enum.Material.Metal)
	local others = {
		part("Tip", Vector3.new(0.34, 0.7, 0.8), CFrame.new(0, -2.4, 0), STEEL, Enum.Material.Metal),
		part("Guard", Vector3.new(0.36, 0.26, 2.0), CFrame.new(0, 2.3, 0), GOLD, Enum.Material.Metal),
		part("Handle", Vector3.new(0.34, 1.4, 0.34), CFrame.new(0, 3.0, 0), LEATHER),
		part("Pommel", Vector3.new(0.5, 0.44, 0.5), CFrame.new(0, 3.8, 0), GOLD, Enum.Material.Metal),
	}
	return assemble("Greatsword", blade, others)
end

-- Bow: the riser is the body, the limbs curve away from it, and the string runs between the tips.
function Builders.Bow()
	local riser = part("Riser", Vector3.new(0.3, 1.2, 0.34), CFrame.new(0, 0, 0), DARK_WOOD)
	local others = {
		part("UpperLimb", Vector3.new(0.24, 1.5, 0.28),
			CFrame.new(0, 1.25, 0.2) * CFrame.Angles(math.rad(14), 0, 0), WOOD),
		part("LowerLimb", Vector3.new(0.24, 1.5, 0.28),
			CFrame.new(0, -1.25, 0.2) * CFrame.Angles(math.rad(-14), 0, 0), WOOD),
		part("UpperTip", Vector3.new(0.18, 0.5, 0.2),
			CFrame.new(0, 2.05, 0.5) * CFrame.Angles(math.rad(28), 0, 0), DARK_WOOD),
		part("LowerTip", Vector3.new(0.18, 0.5, 0.2),
			CFrame.new(0, -2.05, 0.5) * CFrame.Angles(math.rad(-28), 0, 0), DARK_WOOD),
		part("String", Vector3.new(0.05, 4.3, 0.05), CFrame.new(0, 0, 0.62), PAGES),
		part("Grip", Vector3.new(0.34, 0.6, 0.38), CFrame.new(0, 0, 0), LEATHER),
	}
	return assemble("Bow", riser, others)
end

-- Staff: a long shaft with a gem cradled at the top. Held against the torso, so it reads at full length.
function Builders.Staff()
	local shaft = part("Shaft", Vector3.new(0.2, 4.0, 0.2), CFrame.new(0, 0, 0), WOOD)
	local gem = part("Gem", Vector3.new(0.62, 0.62, 0.62), CFrame.new(0, 2.25, 0), GEM, Enum.Material.Neon)
	gem.Shape = Enum.PartType.Ball
	local light = Instance.new("PointLight")
	light.Color = GEM
	light.Range = 10
	light.Brightness = 1.4
	light.Parent = gem
	local others = {
		gem,
		part("Claw", Vector3.new(0.34, 0.5, 0.34), CFrame.new(0, 1.9, 0), DARK_WOOD),
		part("Binding", Vector3.new(0.26, 0.4, 0.26), CFrame.new(0, 1.3, 0), LEATHER),
		part("Ferrule", Vector3.new(0.24, 0.3, 0.24), CFrame.new(0, -2.0, 0), DARK_STEEL, Enum.Material.Metal),
	}
	return assemble("Staff", shaft, others)
end

-- Spellbook: a closed tome. It floats at the chest rather than being gripped, so it is small and flat.
function Builders.Spellbook()
	local cover = part("Cover", Vector3.new(1.3, 0.22, 1.6), CFrame.new(0, 0, 0), Color3.fromRGB(96, 48, 40))
	local others = {
		part("Pages", Vector3.new(1.16, 0.2, 1.46), CFrame.new(0, 0.06, 0.04), PAGES),
		part("Spine", Vector3.new(0.24, 0.26, 1.62), CFrame.new(-0.6, 0, 0), Color3.fromRGB(72, 34, 28)),
		part("Clasp", Vector3.new(0.16, 0.3, 0.3), CFrame.new(0.6, 0, 0), GOLD, Enum.Material.Metal),
		part("Rune", Vector3.new(0.4, 0.06, 0.4), CFrame.new(0.1, 0.14, 0), GEM, Enum.Material.Neon),
	}
	return assemble("Spellbook", cover, others)
end

--------------------------------------------------------------------------------
-- The three tools
--------------------------------------------------------------------------------

-- All three follow the sword's convention exactly: the working end sits at the origin and the grip runs out
-- to +Y, with the hand meeting the shaft 2.0 studs along it. That is not a coincidence to be tidied away --
-- WeaponVisuals reuses the sword's GRIP offset for these, and it was measured against precisely this layout.
-- Move the handle and the tool ends up held by its blade.

-- Axe: a wedge head on one side of the haft, with a small back-spike to balance it visually.
function Builders.Axe()
	local haft = part("Haft", Vector3.new(0.16, 3.0, 0.16), CFrame.new(0, 0, 0), WOOD)
	local others = {
		part("Head", Vector3.new(0.2, 0.85, 0.9), CFrame.new(0, -1.1, 0.42), STEEL, Enum.Material.Metal),
		part("Edge", Vector3.new(0.1, 1.05, 0.24), CFrame.new(0, -1.1, 0.92), STEEL, Enum.Material.Metal),
		part("Spike", Vector3.new(0.16, 0.4, 0.34), CFrame.new(0, -1.1, -0.22), DARK_STEEL, Enum.Material.Metal),
		part("Collar", Vector3.new(0.22, 0.26, 0.22), CFrame.new(0, -0.6, 0), DARK_STEEL, Enum.Material.Metal),
		part("Grip", Vector3.new(0.2, 0.9, 0.2), CFrame.new(0, 2.0, 0), LEATHER),
		part("Butt", Vector3.new(0.24, 0.2, 0.24), CFrame.new(0, 2.5, 0), DARK_STEEL, Enum.Material.Metal),
	}
	return assemble("Axe", haft, others)
end

-- Pickaxe: a head crossing the haft, pointed one way and chisel-flat the other.
function Builders.Pickaxe()
	local haft = part("Haft", Vector3.new(0.16, 3.0, 0.16), CFrame.new(0, 0, 0), WOOD)
	local others = {
		part("Head", Vector3.new(0.18, 0.3, 2.0), CFrame.new(0, -1.15, 0), DARK_STEEL, Enum.Material.Metal),
		part("Point", Vector3.new(0.14, 0.2, 0.5), CFrame.new(0, -1.15, 1.15), STEEL, Enum.Material.Metal),
		part("Chisel", Vector3.new(0.16, 0.42, 0.4), CFrame.new(0, -1.15, -1.1), STEEL, Enum.Material.Metal),
		part("Collar", Vector3.new(0.22, 0.3, 0.22), CFrame.new(0, -0.75, 0), DARK_STEEL, Enum.Material.Metal),
		part("Grip", Vector3.new(0.2, 0.9, 0.2), CFrame.new(0, 2.0, 0), LEATHER),
		part("Butt", Vector3.new(0.24, 0.2, 0.24), CFrame.new(0, 2.5, 0), DARK_STEEL, Enum.Material.Metal),
	}
	return assemble("Pickaxe", haft, others)
end

-- Shovel: a dished blade at the bottom, a T-handle at the top so it reads as a shovel and not a paddle.
function Builders.Shovel()
	local haft = part("Haft", Vector3.new(0.16, 3.0, 0.16), CFrame.new(0, 0, 0), WOOD)
	local others = {
		part("Blade", Vector3.new(0.9, 1.0, 0.12), CFrame.new(0, -1.35, 0.06), STEEL, Enum.Material.Metal),
		part("Lip", Vector3.new(0.9, 0.16, 0.24), CFrame.new(0, -1.8, 0.14), STEEL, Enum.Material.Metal),
		part("Wing", Vector3.new(0.18, 0.5, 0.2), CFrame.new(0, -0.95, -0.04), DARK_STEEL, Enum.Material.Metal),
		part("Socket", Vector3.new(0.22, 0.4, 0.22), CFrame.new(0, -0.7, 0), DARK_STEEL, Enum.Material.Metal),
		part("Grip", Vector3.new(0.2, 0.7, 0.2), CFrame.new(0, 1.9, 0), LEATHER),
		part("Crossbar", Vector3.new(0.7, 0.18, 0.18), CFrame.new(0, 2.4, 0), DARK_WOOD),
	}
	return assemble("Shovel", haft, others)
end

--------------------------------------------------------------------------------
-- The pistol
--------------------------------------------------------------------------------

-- A steampunk flintlock: brass barrel, wooden stock, a little boiler drum where a hammer would be. Built to
-- the same convention as the rest -- muzzle at the origin, grip out along +Y -- so it takes SWORD_GRIP.
function Builders.Pistol()
	local barrel = part("Barrel", Vector3.new(0.22, 1.9, 0.22), CFrame.new(0, 0, 0), GOLD, Enum.Material.Metal)
	local others = {
		part("Muzzle", Vector3.new(0.3, 0.24, 0.3), CFrame.new(0, -0.95, 0), DARK_STEEL, Enum.Material.Metal),
		part("Boiler", Vector3.new(0.42, 0.5, 0.42), CFrame.new(0, 0.75, -0.18), DARK_STEEL, Enum.Material.Metal),
		part("Valve", Vector3.new(0.16, 0.16, 0.3), CFrame.new(0.22, 0.75, -0.3), GOLD, Enum.Material.Metal),
		part("Hammer", Vector3.new(0.12, 0.34, 0.2), CFrame.new(0, 1.15, -0.22), DARK_STEEL, Enum.Material.Metal),
		part("Trigger", Vector3.new(0.08, 0.22, 0.1), CFrame.new(0, 1.5, -0.1), DARK_STEEL, Enum.Material.Metal),
		-- The stock, angled back the way a pistol grip is rather than straight down the barrel.
		part("Grip", Vector3.new(0.26, 0.95, 0.34),
			CFrame.new(0, 2.0, -0.22) * CFrame.Angles(math.rad(18), 0, 0), WOOD),
		part("Butt", Vector3.new(0.3, 0.18, 0.36), CFrame.new(0, 2.48, -0.36), DARK_WOOD),
	}
	return assemble("Pistol", barrel, others)
end

--------------------------------------------------------------------------------
-- The fishing rod
--------------------------------------------------------------------------------

-- Same convention as the sword and the tools: working end at the origin, grip 2.0 studs out along +Y, so
-- it takes the shared SWORD_GRIP unchanged. The "working end" here is the rod tip, which is why the pole
-- runs DOWN from the grip rather than up.
function Builders.FishingRod()
	local pole = part("Pole", Vector3.new(0.12, 3.2, 0.12), CFrame.new(0, 0, 0), WOOD)
	local others = {
		part("Tip", Vector3.new(0.08, 0.7, 0.08), CFrame.new(0, -1.85, 0), DARK_WOOD),
		-- The reel, sitting just above the hand.
		part("Reel", Vector3.new(0.5, 0.5, 0.28), CFrame.new(0, 1.5, 0.2), DARK_STEEL, Enum.Material.Metal),
		part("ReelHandle", Vector3.new(0.12, 0.12, 0.36), CFrame.new(0.28, 1.5, 0.34), GOLD, Enum.Material.Metal),
		part("Grip", Vector3.new(0.2, 0.9, 0.2), CFrame.new(0, 2.0, 0), LEATHER),
		part("Butt", Vector3.new(0.24, 0.2, 0.24), CFrame.new(0, 2.5, 0), DARK_WOOD),
		-- The line: a thin pale strand from the tip back to the reel, so it reads as a rod and not a stick.
		part("Line", Vector3.new(0.03, 3.1, 0.03), CFrame.new(0, -0.2, 0.12), PAGES),
	}
	return assemble("FishingRod", pole, others)
end

--------------------------------------------------------------------------------

-- Rebuilt on every server start rather than trusted to survive in the place file: that is exactly how the
-- originals were lost. Cheap enough (four models of five parts) that there is no reason to cache them.
local existing = ReplicatedStorage:FindFirstChild(FOLDER_NAME)
if existing then existing:Destroy() end

local folder = Instance.new("Folder")
folder.Name = FOLDER_NAME

for name, build in pairs(Builders) do
	local ok, model = pcall(build)
	if ok and model then
		model.Parent = folder
	else
		warn(("[WeaponPrefabs] failed to build %s: %s"):format(name, tostring(model)))
	end
end

folder.Parent = ReplicatedStorage
