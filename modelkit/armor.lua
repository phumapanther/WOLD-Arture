-- armor — wearable armour that takes its size from the body it is put on.
--
-- Every number in a piece table is a MULTIPLE OF THAT LIMB'S OWN Size, never a stud count.
-- A cuirass is "1.12 of the torso wide, 0.98 of it tall, 1.32 of it deep", so one table dresses
-- a slim scout, a stock knight and a broad brute with no second version of the set. R15 barely
-- lets you stretch a rig (HeightScale clamps near 1.05) but WidthScale / BodyType / Proportion
-- move every limb Size around, and a monster built by wrapping plates moves them a lot more —
-- which is exactly the case this file exists for.
--
-- Each finished part also carries FitLimb / FitSize / FitPos / FitCF attributes recording where
-- it sits IN LIMB UNITS, so the ArmorFit module (R.armorFitter) can drop a built set onto any
-- character at run time and re-derive every plate from THAT character's limbs. Build once, fits
-- everyone — the game never ships one hauberk per body type.
--
-- loaded after rig.lua through RIG_FILES, so K and R are both already in scope.

local AMAT = Enum.Material
local ARGB = Color3.fromRGB
local function AV(x, y, z) return Vector3.new(x, y, z) end

-- how far the limb reaches along one of the PART's own axes. For the quarter turns armour
-- actually uses (an upright cylinder is a cylinder rolled onto its side) this is exact; for an
-- odd angle it blends, which is the sane answer. Without it a rolled cylinder would scale its
-- height by the limb's width, and a bracer would stretch the wrong way on a broader body.
local function AEXT(axis, s)
  return math.abs(axis.X) * s.X + math.abs(axis.Y) * s.Y + math.abs(axis.Z) * s.Z
end

-- ------------------------------------------------------------------ fit tagging
-- record a part's place on its limb in limb units. Anything welded through R.armorAttach gets
-- this, so hand-built extras (a boiler, a rivet seam) refit exactly like the table-driven plates.
function R.fitTag(part, limb)
  local rel = limb.CFrame:Inverse() * part.CFrame
  local ls = limb.Size
  part:SetAttribute("FitLimb", limb.Name)
  part:SetAttribute("FitSize", AV(
    part.Size.X / AEXT(rel.RightVector, ls),
    part.Size.Y / AEXT(rel.UpVector, ls),
    part.Size.Z / AEXT(rel.LookVector, ls)))
  part:SetAttribute("FitPos", AV(rel.Position.X / ls.X, rel.Position.Y / ls.Y, rel.Position.Z / ls.Z))
  part:SetAttribute("FitCF", rel - rel.Position)      -- rotation only; the offset lives in FitPos
  return part
end

-- R.attach plus the fit tags, under a holder name every armour piece shares so R.armorKit can
-- lift the finished set off the mannequin it was fitted on.
function R.armorAttach(m, limbName, fn, holderName)
  local limb = R.limb(m, limbName)
  if not limb then return nil end
  local holder = R.attach(m, limbName, fn, "Armor_" .. (holderName or limbName))
  for _, p in ipairs(holder:GetDescendants()) do
    if p:IsA("BasePart") then R.fitTag(p, limb) end
  end
  return holder
end

-- ------------------------------------------------------------------ shapes
-- size arrives in studs here; cyl / cylx / cylz say which of the LIMB's axes the barrel runs along
local function APART(g, cf, size, shape, mat, color, name)
  local o = { name = name, cancollide = false, massless = true }
  if shape == "ball" then
    return K.part(g, K.SHAPE.Ball, cf, size, mat, color, o)
  elseif shape == "cyl" then
    return K.cyl(g, cf, size.X / 2, size.Y, mat, color, o)
  elseif shape == "cylx" then
    return K.cylX(g, cf, size.Y / 2, size.X, mat, color, o)
  elseif shape == "cylz" then
    return K.cylX(g, cf * K.yaw(math.pi / 2), size.Y / 2, size.Z, mat, color, o)
  elseif shape == "wedge" then
    return K.wedge(g, cf, size, mat, color, { name = name, cancollide = false })
  end
  return K.box(g, cf, size, mat, color, o)
end

-- ------------------------------------------------------------------ the sets
-- tone keys index the set's palette, so recolouring a whole suit is one table, not sixty call
-- sites. MAT.Metal renders about a fifth darker than the colour handed to it (catalog note from
-- the chest set), so every metal colour below is mixed brighter than the look it aims at.
R.ARMOR = {}

R.ARMOR.leather = {
  name = "Leather",
  pal = {
    base  = { ARGB(126, 84, 52),  AMAT.Leather },
    dark  = { ARGB(62, 40, 26),   AMAT.Leather },
    strap = { ARGB(40, 26, 18),   AMAT.Leather },
    trim  = { ARGB(224, 176, 78), AMAT.Metal },
    cloth = { ARGB(126, 114, 88), AMAT.Fabric },
  },
  pieces = {
    -- a hunter's cap, not a helmet: a dome recedes behind the brow, so the face stays readable
    -- the brow band has to clear the eyes: anything below y = 0.30 of the head sits on the face
    { limb = "Head", name = "CapCrown", shape = "ball", s = AV(1.06, 0.44, 1.08), p = AV(0, 0.44, 0.02), tone = "base" },
    { limb = "Head", name = "CapBand",  shape = "box",  s = AV(1.14, 0.11, 1.14), p = AV(0, 0.34, 0.02), tone = "strap" },
    { limb = "Head", name = "CapNape",  shape = "box",  s = AV(1.04, 0.46, 0.28), p = AV(0, -0.04, 0.46), tone = "base" },

    { limb = "UpperTorso", name = "Jerkin",      shape = "box",  s = AV(1.10, 0.90, 1.28), p = AV(0, -0.03, 0),    tone = "base" },
    { limb = "UpperTorso", name = "JerkinYoke",  shape = "box",  s = AV(1.15, 0.26, 1.34), p = AV(0, 0.34, 0),     tone = "dark" },
    -- a placket and two shoulder seams: one brown box the size of a torso is a crate, not a coat
    { limb = "UpperTorso", name = "Placket",     shape = "box",  s = AV(0.17, 0.86, 0.10), p = AV(0, -0.04, -0.68), tone = "dark" },
    { limb = "UpperTorso", name = "Seam",        shape = "box",  s = AV(0.26, 0.10, 1.38), p = AV(0.42, 0.46, 0), twin = true, tone = "strap" },
    { limb = "UpperTorso", name = "Collar",      shape = "box",  s = AV(0.62, 0.17, 1.42), p = AV(0, 0.50, 0.02),  tone = "dark" },
    { limb = "UpperTorso", name = "Baldric",     shape = "box",  s = AV(1.26, 0.11, 1.36), p = AV(0, 0.02, 0), r = AV(0, 0, -30), tone = "strap" },
    { limb = "UpperTorso", name = "BaldricBoss", shape = "cylz", s = AV(0.07, 0.19, 0.12), p = AV(-0.22, 0.13, -0.69), tone = "trim" },

    { limb = "LowerTorso", name = "Belt",       shape = "box", s = AV(1.12, 0.95, 1.34), p = AV(0, 0.05, 0),      tone = "strap" },
    { limb = "LowerTorso", name = "Buckle",     shape = "box", s = AV(0.16, 1.05, 0.11), p = AV(0, 0.05, -0.70),  tone = "trim" },
    { limb = "LowerTorso", name = "Tasset",     shape = "box", s = AV(0.44, 2.30, 0.26), p = AV(0.30, -1.20, -0.48), r = AV(-5, 0, 0), twin = true, tone = "dark" },
    { limb = "LowerTorso", name = "TassetBack", shape = "box", s = AV(0.44, 2.10, 0.26), p = AV(0.30, -1.10, 0.48), twin = true, tone = "dark" },

    -- a near-round ball on the shoulder is a boxing glove. Flatten it and put a strap lame under
    { limb = "UpperArm", name = "Pauldron",  shape = "ball", s = AV(1.34, 0.66, 1.38), p = AV(0.12, 0.44, 0), mirror = true, tone = "base" },
    { limb = "UpperArm", name = "PauldronLame", shape = "box", s = AV(1.28, 0.20, 1.32), p = AV(0.14, 0.20, 0), r = AV(0, 0, -14), mirror = true, tone = "dark" },
    { limb = "UpperArm", name = "ArmStrap",  shape = "box",  s = AV(1.22, 0.16, 1.22), p = AV(0, -0.12, 0),   mirror = true, tone = "strap" },
    { limb = "LowerArm", name = "Bracer",    shape = "box",  s = AV(1.26, 0.74, 1.26), p = AV(0, -0.08, 0),   mirror = true, tone = "dark" },
    { limb = "LowerArm", name = "BracerLip", shape = "box",  s = AV(1.30, 0.10, 1.30), p = AV(0, 0.28, 0),    mirror = true, tone = "trim" },
    { limb = "Hand",     name = "Glove",     shape = "box",  s = AV(1.20, 1.10, 1.20), p = AV(0, -0.05, 0),   mirror = true, tone = "dark" },

    { limb = "UpperLeg", name = "ThighGuard", shape = "box", s = AV(1.18, 0.66, 1.20), p = AV(0, 0.08, -0.06), mirror = true, tone = "base" },
    { limb = "UpperLeg", name = "ThighStrap", shape = "box", s = AV(1.24, 0.13, 1.24), p = AV(0, -0.26, 0),    mirror = true, tone = "strap" },
    { limb = "LowerLeg", name = "BootShaft",  shape = "box", s = AV(1.24, 0.80, 1.24), p = AV(0, -0.10, 0),    mirror = true, tone = "base" },
    { limb = "LowerLeg", name = "BootCuff",   shape = "box", s = AV(1.30, 0.16, 1.30), p = AV(0, 0.30, 0),     mirror = true, tone = "dark" },
    { limb = "Foot",     name = "Boot",       shape = "box", s = AV(1.24, 1.10, 1.28), p = AV(0, 0.05, -0.02), mirror = true, tone = "dark" },
  },
  extra = function(m, o, P)
    -- the details that say "stitched by hand": rivet seams, a hip pouch, a bedroll on the back
    R.armorAttach(m, "UpperTorso", function(g, T, L)
      local s = L.Size
      for _, sx in ipairs({ -1, 1 }) do
        K.rivets(g, (T * CFrame.new(sx * s.X * 0.44, s.Y * 0.38, -s.Z * 0.66)).Position,
                    (T * CFrame.new(sx * s.X * 0.44, -s.Y * 0.40, -s.Z * 0.66)).Position,
                    5, s.X * 0.030, P.trim[1])
      end
      if o.pack ~= false then
        local roll = K.cylX(g, T * CFrame.new(0, s.Y * 0.30, s.Z * 0.78), s.Z * 0.20, s.X * 0.86,
          AMAT.Fabric, P.cloth[1], { name = "Bedroll", cancollide = false })
        for _, sx in ipairs({ -1, 1 }) do
          K.box(g, roll.CFrame * CFrame.new(sx * s.X * 0.28, 0, 0), AV(s.X * 0.06, s.Z * 0.46, s.Z * 0.46),
            AMAT.Leather, P.strap[1], { name = "RollStrap", cancollide = false })
        end
      end
    end, "Seams")

    R.armorAttach(m, "LowerTorso", function(g, B, L)
      local s = L.Size
      local pouch = K.box(g, B * CFrame.new(-s.X * 0.33, -s.Y * 0.62, -s.Z * 0.46),
        AV(s.X * 0.20, s.Y * 1.35, s.Z * 0.26), AMAT.Leather, P.dark[1], { name = "Pouch", cancollide = false })
      K.box(g, pouch.CFrame * CFrame.new(0, s.Y * 0.62, -s.Z * 0.03),
        AV(s.X * 0.22, s.Y * 0.32, s.Z * 0.30), AMAT.Leather, P.strap[1], { name = "PouchFlap", cancollide = false })
      K.ball(g, pouch.CFrame * CFrame.new(0, s.Y * 0.38, -s.Z * 0.16), s.X * 0.05, AMAT.Metal, P.trim[1], { name = "PouchStud", cancollide = false })
      -- rope coil on the other hip: a disc facing forward, with a darker eye so it is not a plate
      local coil = K.cylX(g, B * CFrame.new(s.X * 0.35, -s.Y * 0.70, -s.Z * 0.30) * K.yaw(math.pi / 2),
        s.X * 0.11, s.Z * 0.20, AMAT.Fabric, ARGB(178, 154, 112), { name = "RopeCoil", cancollide = false })
      K.cylX(g, coil.CFrame * CFrame.new(0, 0, 0), s.X * 0.04, s.Z * 0.24, AMAT.Fabric, ARGB(122, 104, 74), { name = "RopeEye", cancollide = false })
    end, "Pouch")
  end,
}

R.ARMOR.chain = {
  name = "Chain",
  pal = {
    mail     = { ARGB(112, 122, 138), AMAT.Pebble },
    mailDark = { ARGB(68, 74, 86),    AMAT.Pebble },
    base     = { ARGB(112, 122, 138), AMAT.Pebble },
    iron     = { ARGB(96, 100, 112),  AMAT.Metal },
    strap    = { ARGB(60, 40, 28),    AMAT.Leather },
    trim     = { ARGB(224, 176, 78),  AMAT.Metal },
    cloth    = { ARGB(158, 60, 52),   AMAT.Fabric },
    clothDark = { ARGB(104, 38, 34),  AMAT.Fabric },
  },
  pieces = {
    -- a coif is four slabs around the skull, never one box: the face has to stay out of it
    { limb = "Head", name = "CoifTop",  shape = "ball", s = AV(1.16, 0.70, 1.16), p = AV(0, 0.32, 0.04),  tone = "mail" },
    { limb = "Head", name = "CoifBack", shape = "box",  s = AV(1.10, 1.05, 0.26), p = AV(0, -0.06, 0.50), tone = "mail" },
    { limb = "Head", name = "CoifSide", shape = "box",  s = AV(0.17, 1.00, 1.02), p = AV(0.50, -0.06, 0.04), twin = true, tone = "mail" },
    { limb = "Head", name = "CoifChin", shape = "box",  s = AV(0.68, 0.22, 0.92), p = AV(0, -0.46, 0.06),  tone = "mail" },
    { limb = "Head", name = "CoifBrow", shape = "box",  s = AV(1.14, 0.13, 1.14), p = AV(0, 0.30, 0.03),   tone = "mailDark" },
    -- nasal helm over the top. A bar down the nose is the one detail that dates a helmet to 1100
    { limb = "Head", name = "HelmDome",  shape = "ball", s = AV(1.24, 0.74, 1.24), p = AV(0, 0.44, 0.03),  tone = "iron" },
    { limb = "Head", name = "HelmRim",   shape = "box",  s = AV(1.27, 0.12, 1.27), p = AV(0, 0.28, 0.03),  tone = "trim" },
    { limb = "Head", name = "HelmNasal", shape = "box",  s = AV(0.14, 0.56, 0.16), p = AV(0, 0.06, -0.60), tone = "iron" },

    { limb = "UpperTorso", name = "Hauberk",      shape = "box", s = AV(1.10, 1.00, 1.26), p = AV(0, 0, 0),      tone = "mail" },
    -- Pebble carries the rings; three thicker rows carry the courses. Six thin ones read as noise
    { limb = "UpperTorso", name = "MailRow",      shape = "box", s = AV(1.13, 0.09, 1.30), p = AV(0, 0.28, 0),   tone = "mailDark" },
    { limb = "UpperTorso", name = "MailRow2",     shape = "box", s = AV(1.13, 0.09, 1.30), p = AV(0, 0.02, 0),   tone = "mailDark" },
    { limb = "UpperTorso", name = "MailRow3",     shape = "box", s = AV(1.13, 0.09, 1.30), p = AV(0, -0.26, 0),  tone = "mailDark" },
    { limb = "UpperTorso", name = "MailCollar",   shape = "box", s = AV(0.72, 0.20, 1.40), p = AV(0, 0.49, 0),   tone = "mail" },
    { limb = "UpperTorso", name = "SurcoatFront", shape = "box", s = AV(0.66, 1.00, 0.09), p = AV(0, -0.03, -0.68), tone = "cloth" },
    { limb = "UpperTorso", name = "SurcoatBack",  shape = "box", s = AV(0.66, 1.00, 0.09), p = AV(0, -0.03, 0.68),  tone = "cloth" },
    -- a flat red plank reads as a sign hung on a wall; the darker selvedge down each edge is what
    -- makes it read as cloth draped over the mail
    { limb = "UpperTorso", name = "SurcoatEdge",  shape = "box", s = AV(0.06, 1.00, 0.11), p = AV(0.33, -0.03, -0.68), twin = true, tone = "clothDark" },

    { limb = "LowerTorso", name = "HauberkSkirt",  shape = "box", s = AV(1.08, 3.30, 1.24), p = AV(0, -1.05, 0),  tone = "mail" },
    { limb = "LowerTorso", name = "SkirtHem",      shape = "box", s = AV(1.11, 0.30, 1.27), p = AV(0, -2.55, 0),  tone = "mailDark" },
    { limb = "LowerTorso", name = "SurcoatSkirtF", shape = "box", s = AV(0.64, 3.00, 0.09), p = AV(0, -1.05, -0.66), tone = "cloth" },
    { limb = "LowerTorso", name = "SurcoatSkirtB", shape = "box", s = AV(0.64, 3.00, 0.09), p = AV(0, -1.05, 0.66),  tone = "cloth" },
    { limb = "LowerTorso", name = "SurcoatSkirtE", shape = "box", s = AV(0.06, 3.00, 0.11), p = AV(0.32, -1.05, -0.66), twin = true, tone = "clothDark" },
    { limb = "LowerTorso", name = "SkirtRow",      shape = "box", s = AV(1.10, 0.22, 1.27), p = AV(0, -1.80, 0),     tone = "mailDark" },
    { limb = "LowerTorso", name = "Belt",          shape = "box", s = AV(1.14, 1.10, 1.30), p = AV(0, -0.30, 0),  tone = "strap" },
    { limb = "LowerTorso", name = "BeltBuckle",    shape = "box", s = AV(0.18, 1.20, 0.11), p = AV(0, -0.30, -0.68), tone = "trim" },

    { limb = "UpperArm", name = "Sleeve",    shape = "box",  s = AV(1.22, 1.02, 1.22), p = AV(0, 0, 0),        mirror = true, tone = "mail" },
    { limb = "UpperArm", name = "Shoulder",  shape = "ball", s = AV(1.42, 0.82, 1.40), p = AV(0.10, 0.34, 0),  mirror = true, tone = "mail" },
    { limb = "UpperArm", name = "SleeveRow", shape = "box",  s = AV(1.25, 0.07, 1.25), p = AV(0, -0.22, 0),    mirror = true, tone = "mailDark" },
    { limb = "LowerArm", name = "Sleeve",    shape = "box",  s = AV(1.18, 1.00, 1.18), p = AV(0, 0, 0),        mirror = true, tone = "mail" },
    { limb = "LowerArm", name = "Vambrace",  shape = "box",  s = AV(1.24, 0.34, 1.24), p = AV(0, -0.24, 0),    mirror = true, tone = "strap" },
    { limb = "Hand",     name = "Mitten",    shape = "box",  s = AV(1.24, 1.20, 1.24), p = AV(0, -0.05, 0),    mirror = true, tone = "mail" },

    { limb = "UpperLeg", name = "Chausse",      shape = "box", s = AV(1.14, 0.98, 1.14), p = AV(0, 0, 0),        mirror = true, tone = "mail" },
    { limb = "LowerLeg", name = "ChausseLower", shape = "box", s = AV(1.12, 0.98, 1.12), p = AV(0, 0, 0),        mirror = true, tone = "mail" },
    { limb = "LowerLeg", name = "Garter",       shape = "box", s = AV(1.18, 0.12, 1.18), p = AV(0, 0.30, 0),     mirror = true, tone = "strap" },
    { limb = "Foot",     name = "MailShoe",     shape = "box", s = AV(1.22, 1.10, 1.28), p = AV(0, 0.05, -0.02), mirror = true, tone = "mail" },
  },
  extra = function(m, o, P)
    R.armorAttach(m, "UpperTorso", function(g, T, L)
      local s = L.Size
      -- livery on the surcoat. A cross reads at any distance; a coat of arms does not
      local live = o.livery or ARGB(240, 226, 190)
      K.box(g, T * CFrame.new(0, s.Y * 0.02, -s.Z * 0.74), AV(s.X * 0.11, s.Y * 0.56, s.Z * 0.05), AMAT.Fabric, live, { name = "Livery", cancollide = false })
      K.box(g, T * CFrame.new(0, s.Y * 0.18, -s.Z * 0.74), AV(s.X * 0.34, s.Y * 0.11, s.Z * 0.05), AMAT.Fabric, live, { name = "Livery", cancollide = false })
      -- one visible row of rings along the collar sells the mail on every other slab
      K.rivets(g, (T * CFrame.new(-s.X * 0.30, s.Y * 0.44, -s.Z * 0.62)).Position,
                  (T * CFrame.new(s.X * 0.30, s.Y * 0.44, -s.Z * 0.62)).Position, 9, s.X * 0.024, P.mailDark[1])
    end, "Livery")

    R.armorAttach(m, "LowerTorso", function(g, B, L)
      local s = L.Size
      -- scabbard on the left hip, tipped back so it clears the leg
      local sc = K.box(g, B * CFrame.new(-s.X * 0.42, -s.Y * 1.7, s.Z * 0.24) * K.pitch(math.rad(16)) * K.roll(math.rad(10)),
        AV(s.X * 0.13, s.Y * 3.4, s.Z * 0.22), AMAT.Leather, P.strap[1], { name = "Scabbard", cancollide = false })
      K.box(g, sc.CFrame * CFrame.new(0, s.Y * 1.5, 0), AV(s.X * 0.16, s.Y * 0.4, s.Z * 0.26), AMAT.Metal, P.trim[1], { name = "Locket", cancollide = false })
      K.box(g, sc.CFrame * CFrame.new(0, -s.Y * 1.6, 0), AV(s.X * 0.15, s.Y * 0.35, s.Z * 0.25), AMAT.Metal, P.trim[1], { name = "Chape", cancollide = false })
    end, "Scabbard")
  end,
}

R.ARMOR.plate = {
  name = "Plate",
  pal = {
    plate = { ARGB(132, 140, 152), AMAT.Metal },
    base  = { ARGB(132, 140, 152), AMAT.Metal },
    dark  = { ARGB(80, 86, 96),    AMAT.Metal },
    trim  = { ARGB(228, 180, 82),  AMAT.Metal },
    slit  = { ARGB(16, 16, 18),    AMAT.SmoothPlastic },
    strap = { ARGB(52, 34, 24),    AMAT.Leather },
    cloth = { ARGB(70, 104, 152),  AMAT.Fabric },
    glow  = { ARGB(255, 146, 54),  AMAT.Neon },
  },
  pieces = {
    -- closed helm: skull, face plate, cheeks, back. The slit is the only opening
    -- a dome on its own is a helmet-shaped balloon; the jaw box under it is what gives it a head
    { limb = "Head", name = "HelmSkull",  shape = "ball", s = AV(1.20, 0.80, 1.18), p = AV(0, 0.28, 0.05),  tone = "plate" },
    { limb = "Head", name = "HelmJaw",    shape = "box",  s = AV(1.10, 0.66, 1.08), p = AV(0, -0.04, 0.04), tone = "plate" },
    { limb = "Head", name = "HelmFace",   shape = "box",  s = AV(1.02, 0.66, 0.30), p = AV(0, -0.06, -0.50), tone = "plate" },
    { limb = "Head", name = "HelmBack",   shape = "box",  s = AV(1.04, 0.80, 0.30), p = AV(0, -0.06, 0.52),  tone = "plate" },
    { limb = "Head", name = "VisorSlit",  shape = "box",  s = AV(0.92, 0.15, 0.16), p = AV(0, 0.10, -0.68),  tone = "slit" },
    { limb = "Head", name = "VisorVent",  shape = "box",  s = AV(0.34, 0.09, 0.14), p = AV(0, -0.24, -0.68), tone = "slit" },
    { limb = "Head", name = "VisorRidge", shape = "box",  s = AV(0.12, 0.66, 0.24), p = AV(0, -0.08, -0.64), r = AV(0, 45, 0), tone = "plate" },
    { limb = "Head", name = "BrowTrim",   shape = "box",  s = AV(1.08, 0.10, 1.16), p = AV(0, 0.22, 0.02),   tone = "trim" },
    { limb = "Head", name = "ChinTrim",   shape = "box",  s = AV(1.06, 0.09, 1.10), p = AV(0, -0.38, 0.03),  tone = "trim" },
    { limb = "Head", name = "HelmCrest",  shape = "box",  s = AV(0.13, 0.22, 1.08), p = AV(0, 0.62, 0.05),   tone = "trim" },

    { limb = "UpperTorso", name = "Breastplate", shape = "box", s = AV(1.12, 0.98, 1.32), p = AV(0, -0.01, 0),   tone = "plate" },
    { limb = "UpperTorso", name = "Keel",        shape = "box", s = AV(0.12, 0.94, 0.24), p = AV(0, -0.02, -0.68), r = AV(0, 45, 0), tone = "plate" },
    { limb = "UpperTorso", name = "Gorget",      shape = "box", s = AV(0.82, 0.22, 1.44), p = AV(0, 0.48, 0),    tone = "dark" },
    { limb = "UpperTorso", name = "GorgetTrim",  shape = "box", s = AV(0.86, 0.08, 1.48), p = AV(0, 0.37, 0),    tone = "trim" },
    { limb = "UpperTorso", name = "ChestTrim",   shape = "box", s = AV(1.15, 0.09, 1.36), p = AV(0, 0.30, 0),    tone = "trim" },
    { limb = "UpperTorso", name = "WaistTrim",   shape = "box", s = AV(1.15, 0.09, 1.36), p = AV(0, -0.44, 0),   tone = "trim" },

    -- fauld: three lames, each a touch wider and lower than the one above it
    { limb = "LowerTorso", name = "Fauld1",    shape = "box", s = AV(1.08, 0.95, 1.30), p = AV(0, -0.30, 0), tone = "plate" },
    { limb = "LowerTorso", name = "Fauld2",    shape = "box", s = AV(1.11, 0.95, 1.33), p = AV(0, -1.15, 0), tone = "plate" },
    { limb = "LowerTorso", name = "Fauld3",    shape = "box", s = AV(1.14, 0.95, 1.36), p = AV(0, -2.00, 0), tone = "dark" },
    { limb = "LowerTorso", name = "FauldTrim", shape = "box", s = AV(1.17, 0.20, 1.39), p = AV(0, -2.52, 0), tone = "trim" },

    -- ONE big dome is a chrome egg that swallows the whole arm. Three shallow lames stepping
    -- outward and down read as a pauldron, and leave the rerebrace underneath visible
    { limb = "UpperArm", name = "PauldronCap",   shape = "ball", s = AV(1.26, 0.52, 1.34), p = AV(0.08, 0.56, 0), mirror = true, tone = "plate" },
    { limb = "UpperArm", name = "Pauldron",      shape = "box",  s = AV(1.38, 0.30, 1.42), p = AV(0.12, 0.46, 0), r = AV(0, 0, -10), mirror = true, tone = "plate" },
    { limb = "UpperArm", name = "PauldronLame",  shape = "box",  s = AV(1.44, 0.26, 1.42), p = AV(0.16, 0.28, 0), r = AV(0, 0, -17), mirror = true, tone = "dark" },
    { limb = "UpperArm", name = "PauldronLame2", shape = "box",  s = AV(1.48, 0.24, 1.40), p = AV(0.20, 0.10, 0), r = AV(0, 0, -24), mirror = true, tone = "plate" },
    { limb = "UpperArm", name = "PauldronSpike", shape = "box",  s = AV(0.26, 0.40, 0.26), p = AV(0.34, 0.72, 0), r = AV(0, 45, 18), mirror = true, tone = "trim" },
    { limb = "UpperArm", name = "Rerebrace",     shape = "box",  s = AV(1.24, 0.52, 1.24), p = AV(0, -0.32, 0),   mirror = true, tone = "plate" },
    { limb = "LowerArm", name = "Couter",        shape = "ball", s = AV(1.44, 0.62, 1.44), p = AV(0, 0.34, 0),    mirror = true, tone = "dark" },
    { limb = "LowerArm", name = "Vambrace",      shape = "box",  s = AV(1.28, 0.84, 1.28), p = AV(0, -0.10, 0),   mirror = true, tone = "plate" },
    { limb = "LowerArm", name = "VambraceTrim",  shape = "box",  s = AV(1.32, 0.09, 1.32), p = AV(0, -0.50, 0),   mirror = true, tone = "trim" },
    { limb = "Hand",     name = "Gauntlet",      shape = "box",  s = AV(1.26, 1.30, 1.26), p = AV(0, -0.05, 0),   mirror = true, tone = "dark" },
    { limb = "Hand",     name = "Knuckles",      shape = "box",  s = AV(1.20, 0.62, 0.34), p = AV(0, 0.22, -0.56), mirror = true, tone = "trim" },

    { limb = "UpperLeg", name = "Cuisse",     shape = "box",  s = AV(1.14, 0.90, 1.18), p = AV(0, -0.02, 0),    mirror = true, tone = "plate" },
    { limb = "UpperLeg", name = "Tasset",     shape = "box",  s = AV(1.06, 0.54, 0.30), p = AV(0, 0.30, -0.62), r = AV(6, 0, 0), mirror = true, tone = "dark" },
    { limb = "LowerLeg", name = "Poleyn",     shape = "ball", s = AV(1.32, 0.60, 1.38), p = AV(0, 0.36, -0.10), mirror = true, tone = "dark" },
    { limb = "LowerLeg", name = "Greave",     shape = "box",  s = AV(1.14, 0.84, 1.18), p = AV(0, -0.08, 0),    mirror = true, tone = "plate" },
    { limb = "LowerLeg", name = "GreaveTrim", shape = "box",  s = AV(1.18, 0.09, 1.22), p = AV(0, -0.46, 0),    mirror = true, tone = "trim" },
    { limb = "Foot",     name = "Sabaton",    shape = "box",  s = AV(1.20, 1.15, 1.26), p = AV(0, 0.05, -0.04), mirror = true, tone = "plate" },
    -- K.wedge stands its face at +Z and slopes down toward -Z, so the point aims forward unturned
    { limb = "Foot",     name = "SabatonToe", shape = "wedge", s = AV(1.28, 0.62, 0.62), p = AV(0, -0.24, -0.98), mirror = true, tone = "plate" },
  },
  extra = function(m, o, P)
    R.armorAttach(m, "UpperTorso", function(g, T, L)
      local s = L.Size
      for _, sx in ipairs({ -1, 1 }) do              -- rivet seams down both sides of the breastplate
        K.rivets(g, (T * CFrame.new(sx * s.X * 0.50, s.Y * 0.26, -s.Z * 0.60)).Position,
                    (T * CFrame.new(sx * s.X * 0.50, -s.Y * 0.40, -s.Z * 0.60)).Position,
                    4, s.X * 0.030, P.trim[1])
      end
      if o.core ~= false then                        -- the steam heart, and where players aim
        -- a big Neon disc burns out to a flat sticker; a small one inside a dark housing glows
        K.cylX(g, T * CFrame.new(0, s.Y * 0.05, -s.Z * 0.74) * K.yaw(math.pi / 2),
          s.X * 0.13, s.Z * 0.14, AMAT.Metal, P.dark[1], { name = "CoreHousing", cancollide = false })
        local core = K.cylX(g, T * CFrame.new(0, s.Y * 0.05, -s.Z * 0.80) * K.yaw(math.pi / 2),
          s.X * 0.07, s.Z * 0.06, AMAT.Neon, P.glow[1], { name = "Core", cancollide = false })
        K.rivetRing(g, T * CFrame.new(0, s.Y * 0.05, -s.Z * 0.74), s.X * 0.17, 8, s.X * 0.026, P.trim[1])
        local l = Instance.new("PointLight")
        l.Color = P.glow[1]; l.Range = 12; l.Brightness = 1.6; l.Parent = core
      end
      if o.boiler ~= false then                      -- steam plant on the back, piped to both shoulders
        local tank = K.cyl(g, T * CFrame.new(0, -s.Y * 0.02, s.Z * 0.92), s.X * 0.26, s.Y * 0.80,
          AMAT.Metal, P.dark[1], { name = "Boiler", cancollide = false })
        K.band(g, tank.CFrame * CFrame.new(0, s.Y * 0.22, 0), s.X * 0.275, s.Y * 0.07, P.trim[1])
        K.band(g, tank.CFrame * CFrame.new(0, -s.Y * 0.22, 0), s.X * 0.275, s.Y * 0.07, P.trim[1])
        for _, sx in ipairs({ -1, 1 }) do
          K.pipe(g, {
            (T * CFrame.new(sx * s.X * 0.13, s.Y * 0.30, s.Z * 0.92)).Position,
            (T * CFrame.new(sx * s.X * 0.34, s.Y * 0.46, s.Z * 0.72)).Position,
            (T * CFrame.new(sx * s.X * 0.48, s.Y * 0.46, s.Z * 0.14)).Position,
          }, s.X * 0.055, P.trim[1], { name = "ShoulderPipe" })
          local stack = K.cyl(g, T * CFrame.new(sx * s.X * 0.17, s.Y * 0.52, s.Z * 0.92), s.X * 0.07, s.Y * 0.34,
            AMAT.Metal, P.dark[1], { name = "Stack", cancollide = false })
          if o.steam then
            local e = Instance.new("ParticleEmitter")
            e.Name = "SteamEmitter"
            e.Color = ColorSequence.new(ARGB(226, 232, 240))
            e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1.1) })
            e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.45), NumberSequenceKeypoint.new(1, 1) })
            e.Lifetime = NumberRange.new(0.8, 1.6); e.Rate = 9
            e.Speed = NumberRange.new(1.4, 2.6); e.SpreadAngle = Vector2.new(14, 14)
            e.EmissionDirection = Enum.NormalId.Top; e.Parent = stack
          end
        end
      end
    end, "SteamPlant")

    if o.plume ~= false and R.limb(m, "Head") then
      R.armorAttach(m, "Head", function(g, H, L)
        local s = L.Size
        local col = o.plume or P.cloth[1]
        for i = 0, 4 do                              -- a fan of slabs, shortest at the back
          local t = i / 4
          K.box(g, H * CFrame.new(0, s.Y * (0.86 - t * 0.14), s.Z * (-0.02 + t * 0.44)) * K.pitch(math.rad(-16 + t * 34)),
            AV(s.X * 0.10, s.Y * (0.42 - t * 0.10), s.Z * 0.22), AMAT.Fabric, col, { name = "Plume", cancollide = false })
        end
      end, "Plume")
    end
  end,
}

-- ------------------------------------------------------------------ dressing a rig
-- opts: helm=false strips the head pieces · bulk widens every plate (a monster wants 0.1 - 0.2)
--       colors={base=,trim=,...} overrides palette entries · wear=0..1 tints each plate slightly
--       skip={LowerTorso=true} / only={"UpperTorso"} choose which limbs get dressed
--       fitter=false leaves out the ArmorFit module · per set: steam, plume, livery, core, boiler, pack
function R.armor(m, kind, o)
  o = o or {}
  local set = R.ARMOR[kind]
  assert(set, "no armour set named " .. tostring(kind))

  local P = {}                                       -- private copy: overrides must not leak sets
  for k, v in pairs(set.pal) do P[k] = { v[1], v[2] } end
  P.base = P.base or P.plate or P.mail
  for k, c in pairs(o.colors or {}) do if P[k] then P[k][1] = c end end

  local only = nil
  if o.only then only = {}; for _, n in ipairs(o.only) do only[n] = true end end
  local rng = Random.new(o.seed or 7)
  local bulk = 1 + (o.bulk or 0)

  local byLimb, order = {}, {}
  local function file(limbName, q)
    if o.skip and o.skip[limbName] then return end
    if only and not only[limbName] then return end
    if not R.limb(m, limbName) then return end
    if not byLimb[limbName] then byLimb[limbName] = {}; order[#order + 1] = limbName end
    table.insert(byLimb[limbName], q)
  end

  for _, sp in ipairs(set.pieces) do
    if not (o.helm == false and sp.limb == "Head") then
      local ry, rz = sp.r and sp.r.Y or 0, sp.r and sp.r.Z or 0
      if sp.mirror then                              -- authored for the right side; the X offset
        for _, sx in ipairs({ -1, 1 }) do            -- and the Y/Z spins flip for the left
          file((sx < 0 and "Left" or "Right") .. sp.limb, { sp = sp, px = sp.p.X * sx, ry = ry * sx, rz = rz * sx })
        end
      elseif sp.twin then                            -- two of them on the SAME limb
        for _, sx in ipairs({ -1, 1 }) do
          file(sp.limb, { sp = sp, px = sp.p.X * sx, ry = ry * sx, rz = rz * sx })
        end
      else
        file(sp.limb, { sp = sp, px = sp.p.X, ry = ry, rz = rz })
      end
    end
  end

  local holders = {}
  for _, limbName in ipairs(order) do
    holders[#holders + 1] = R.armorAttach(m, limbName, function(g, L, limb)
      local ls = limb.Size
      for _, q in ipairs(byLimb[limbName]) do
        local sp = q.sp
        local size = AV(ls.X * sp.s.X * bulk, ls.Y * sp.s.Y, ls.Z * sp.s.Z * bulk)
        local cf = L * CFrame.new(ls.X * q.px, ls.Y * sp.p.Y, ls.Z * sp.p.Z)
        if sp.r then cf = cf * CFrame.Angles(math.rad(sp.r.X), math.rad(q.ry), math.rad(q.rz)) end
        local t = P[sp.tone] or P.base
        local col = t[1]
        if o.wear and o.wear > 0 then col = K.stint(rng, col, o.wear * 0.3) end
        APART(g, cf, size, sp.shape, t[2], col, sp.name)
      end
    end, limbName)
  end

  if set.extra then set.extra(m, o, P) end
  K.attrs(m, { ArmorSet = set.name })
  if o.fitter ~= false then R.armorFitter(m) end
  return holders
end

-- ------------------------------------------------------------------ run-time fitter
-- The same text goes two places: a copy dropped inside every armour model (so an .rbxm is
-- self-contained) and `export/ArmorFit.lua` for the game repo, where a module belongs. It reads
-- the fit attributes back off the parts, so it never needs to know which set it is looking at.
R.ARMORFIT_SOURCE = [==[
-- ArmorFit — put a suit of armour on any R15 character, sized from THAT character's own limbs.
--
--   local ArmorFit = require(ReplicatedStorage.Shared.ArmorFit)
--   local worn = ArmorFit.fit(ServerStorage.Armor_PlateKit, character)
--   worn:Destroy()                         -- and that takes it off again
--
-- Every source part records where it sits on its limb IN LIMB UNITS (FitLimb / FitSize / FitPos /
-- FitCF), so one suit built on a stock knight comes out right on a child, a brute or a golem —
-- the game never needs a second model per body type. The source may sit in ServerStorage;
-- nothing here needs it in the workspace.
local ArmorFit = {}

local function extent(axis, s)
	return math.abs(axis.X) * s.X + math.abs(axis.Y) * s.Y + math.abs(axis.Z) * s.Z
end

-- opts: parent (default the character), name, transparency, tint (Color3) + amount (0..1)
function ArmorFit.fit(source, character, opts)
	opts = opts or {}
	local worn = Instance.new("Model")
	worn.Name = opts.name or (source.Name .. "_Worn")

	for _, src in ipairs(source:GetDescendants()) do
		local limbName = src:IsA("BasePart") and src:GetAttribute("FitLimb")
		local limb = limbName and character:FindFirstChild(limbName)
		if limb then
			local p = src:Clone()
			for _, ch in ipairs(p:GetChildren()) do                 -- the source's own welds still
				if ch:IsA("WeldConstraint") or ch:IsA("Weld") then     -- point at its mannequin
					ch:Destroy()
				end
			end
			local ls = limb.Size
			local rot = src:GetAttribute("FitCF") or CFrame.new()
			local fs = src:GetAttribute("FitSize")
			local fp = src:GetAttribute("FitPos")
			p.Size = Vector3.new(
				extent(rot.RightVector, ls) * fs.X,
				extent(rot.UpVector, ls) * fs.Y,
				extent(rot.LookVector, ls) * fs.Z)
			p.CFrame = limb.CFrame * CFrame.new(ls.X * fp.X, ls.Y * fp.Y, ls.Z * fp.Z) * rot
			p.Anchored = false
			p.CanCollide = false
			p.Massless = true
			if opts.transparency then p.Transparency = opts.transparency end
			if opts.tint then p.Color = p.Color:Lerp(opts.tint, opts.amount or 0.5) end
			p.Parent = worn

			local w = Instance.new("WeldConstraint")
			w.Name = "WeldTo_" .. limbName
			w.Part0, w.Part1 = p, limb
			w.Parent = p
		end
	end

	worn.Parent = opts.parent or character
	return worn
end

-- convenience for the copy that lives INSIDE an armour model
function ArmorFit.wear(character, opts)
	return ArmorFit.fit(script.Parent, character, opts)
end

return ArmorFit
]==]

function R.armorFitter(m)
  local old = m:FindFirstChild("ArmorFit"); if old then old:Destroy() end
  local s = Instance.new("ModuleScript")
  s.Name = "ArmorFit"
  s.Source = R.ARMORFIT_SOURCE
  s.Parent = m
  return s
end

-- ------------------------------------------------------------------ the bare suit
-- Build the set on a throwaway mannequin, then take the mannequin away: what is left is the
-- wearable asset itself — an empty suit standing in the air, plus the fitter that puts it on.
function R.armorKit(m, kind, o)
  o = o or {}
  local body = Instance.new("Model")
  body.Name = "_Mannequin"
  body.Parent = m
  R.new(body, { baseY = o.baseY or 0, height = o.height, width = o.width, face = false })
  R.armor(body, kind, o)

  for _, c in ipairs(body:GetChildren()) do
    if (c:IsA("Model") and c.Name:sub(1, 6) == "Armor_") or c:IsA("ModuleScript") then
      for _, p in ipairs(c:GetDescendants()) do
        if p:IsA("BasePart") then
          p.Anchored = true                          -- nothing holds it up once the body is gone
          for _, w in ipairs(p:GetChildren()) do
            if w:IsA("WeldConstraint") then w:Destroy() end
          end
        end
      end
      c.Parent = m
    end
  end
  body:Destroy()
  K.attrs(m, { ArmorSet = R.ARMOR[kind].name, Wearable = true })
  return m
end
