-- Skin_Bow_Vine — exported from WOLD-Models on 2026-09-18 (25 parts)
-- self-contained: no modelkit needed. Returns the Model, unparented.
--   local m = require(script.Skin_Bow_Vine)()   -- or paste this file's body into a build step
-- local space: base on y = 0, centred on x/z, front = -Z.
return function()
	local m = Instance.new("Model")
	m.Name = "Skin_Bow_Vine"
	local folders = {}
	local function F(pathStr)
		if pathStr == "" then return m end
		if folders[pathStr] then return folders[pathStr] end
		local head = pathStr:match("^(.*)/[^/]*$")
		local f = Instance.new("Model")
		f.Name = ((head and pathStr:sub(#head + 2) or pathStr):gsub("#%d+$", ""))
		f.Parent = head and F(head) or m
		folders[pathStr] = f
		return f
	end
	local function P(cls, nm, shape, parent, sx, sy, sz, cf, mat, r, g, b, tr, cc, light, smoke, fit)
		local p = Instance.new(cls)
		p.Name = nm; p.Size = Vector3.new(sx, sy, sz); p.CFrame = cf
		p.Material = Enum.Material[mat]; p.Color = Color3.fromRGB(r, g, b)
		p.Transparency = tr; p.CanCollide = cc; p.Anchored = true
		if shape ~= "" and p:IsA("Part") then p.Shape = Enum.PartType[shape] end
		p.TopSurface = Enum.SurfaceType.Smooth; p.BottomSurface = Enum.SurfaceType.Smooth
		if light then local l = Instance.new("PointLight"); l.Color = Color3.fromRGB(light[1], light[2], light[3]); l.Range = light[4]; l.Brightness = light[5]; l.Parent = p end
		if smoke then local s = Instance.new("Smoke"); s.Size = smoke[1]; s.RiseVelocity = smoke[2]; s.Opacity = smoke[3]; s.Parent = p end
		if fit then                                   -- armour keeps its fit tags, so ArmorFit still works
			p:SetAttribute("FitLimb", fit[1])
			p:SetAttribute("FitSize", Vector3.new(fit[2], fit[3], fit[4]))
			p:SetAttribute("FitPos", Vector3.new(fit[5], fit[6], fit[7]))
			p:SetAttribute("FitCF", CFrame.new(0, 0, 0, fit[8], fit[9], fit[10], fit[11], fit[12], fit[13], fit[14], fit[15], fit[16]))
		end
		p.Parent = F(parent)
		return p
	end
	P("Part", "Grip", "Cylinder", "", 0.6200, 0.3700, 0.3700, CFrame.new(0.0000,2.6000,0.0000,-0.000000,-1.000000,0.000000,1.000000,-0.000000,0.000000,0.000000,0.000000,1.000000), "Fabric", 64, 48, 34, 0, true, nil, nil, nil)
	P("Part", "GripVine", "Cylinder", "", 0.0700, 0.4000, 0.4000, CFrame.new(0.0000,2.3800,0.0000,-0.000000,-1.000000,0.000000,1.000000,-0.000000,0.000000,0.000000,0.000000,1.000000), "Grass", 86, 138, 58, 0, true, nil, nil, nil)
	P("Part", "GripVine", "Cylinder", "", 0.0700, 0.4000, 0.4000, CFrame.new(0.0000,2.8200,0.0000,-0.000000,-1.000000,0.000000,1.000000,-0.000000,0.000000,0.000000,0.000000,1.000000), "Grass", 86, 138, 58, 0, true, nil, nil, nil)
	P("Part", "HeartGem", "Ball", "", 0.1800, 0.1800, 0.1800, CFrame.new(0.0000,2.6000,-0.1406,1.000000,0.000000,0.000000,0.000000,1.000000,0.000000,0.000000,0.000000,1.000000), "Neon", 150, 226, 110, 0, true, nil, nil, nil)
	P("Part", "LowerCoil0", "Cylinder", "", 0.1000, 0.3100, 0.3100, CFrame.new(0.0000,1.9000,0.1191,-0.000000,-1.000000,0.000000,0.406737,-0.000000,-0.913545,0.913545,-0.000000,0.406737), "Grass", 86, 138, 58, 0, true, nil, nil, nil)
	P("Part", "LowerCoil1", "Cylinder", "", 0.1000, 0.3100, 0.3100, CFrame.new(0.0000,1.4667,0.2324,-0.000000,-1.000000,0.000000,0.406737,-0.000000,-0.913545,0.913545,-0.000000,0.406737), "Grass", 86, 138, 58, 0, true, nil, nil, nil)
	P("Part", "LowerCoil2", "Cylinder", "", 0.1000, 0.3100, 0.3100, CFrame.new(0.0000,1.0333,0.3457,-0.000000,-1.000000,0.000000,0.406737,-0.000000,-0.913545,0.913545,-0.000000,0.406737), "Grass", 86, 138, 58, 0, true, nil, nil, nil)
	P("Part", "LowerCoil3", "Cylinder", "", 0.1000, 0.3100, 0.3100, CFrame.new(0.0000,0.6000,0.4609,-0.000000,-1.000000,0.000000,0.406737,-0.000000,-0.913545,0.913545,-0.000000,0.406737), "Grass", 86, 138, 58, 0, true, nil, nil, nil)
	P("Part", "LowerLeaf0", "Block", "", 0.0400, 0.3400, 0.2000, CFrame.new(-0.0200,1.6500,0.0605,0.913545,0.000000,0.406737,0.139112,0.939693,-0.312451,-0.382207,0.342020,0.858452), "Grass", 112, 176, 72, 0, true, nil, nil, nil)
	P("Part", "LowerLeaf1", "Block", "", 0.0400, 0.3400, 0.2000, CFrame.new(-0.0200,1.1500,0.2109,0.913545,0.000000,0.406737,0.287606,0.707107,-0.645974,-0.287606,0.707107,0.645974), "Grass", 112, 176, 72, 0, true, nil, nil, nil)
	P("Part", "LowerLeaf2", "Block", "", 0.0400, 0.3400, 0.2000, CFrame.new(-0.0200,0.6500,0.3594,0.913545,0.000000,0.406737,0.382207,0.342020,-0.858452,-0.139112,0.939693,0.312451), "Grass", 112, 176, 72, 0, true, nil, nil, nil)
	P("Part", "LowerLimb", "Cylinder", "", 1.5000, 0.2400, 0.2400, CFrame.new(0.0000,1.3500,0.1992,-0.000000,-1.000000,0.000000,0.970296,-0.000000,0.241922,-0.241922,0.000000,0.970296), "Wood", 104, 80, 52, 0, true, nil, nil, nil)
	P("Part", "LowerTip", "Cylinder", "", 0.5000, 0.1700, 0.1700, CFrame.new(0.0000,0.5500,0.5000,-0.000000,-1.000000,0.000000,0.882948,-0.000000,0.469472,-0.469472,0.000000,0.882948), "Wood", 78, 58, 38, 0, true, nil, nil, nil)
	P("Part", "Riser", "Cylinder", "", 1.2000, 0.3200, 0.3200, CFrame.new(0.0000,2.6000,0.0000,-0.000000,-1.000000,0.000000,1.000000,-0.000000,0.000000,0.000000,0.000000,1.000000), "Wood", 78, 58, 38, 0, true, nil, nil, nil)
	P("Part", "Root", "Block", "", 1.0000, 1.0000, 1.0000, CFrame.new(0.0000,0.0000,0.0000,1.000000,0.000000,0.000000,0.000000,1.000000,0.000000,0.000000,0.000000,1.000000), "Plastic", 163, 162, 165, 1, false, nil, nil, nil)
	P("Part", "String", "Block", "", 0.0400, 4.3000, 0.0400, CFrame.new(0.0000,2.6000,0.6191,1.000000,0.000000,0.000000,0.000000,1.000000,0.000000,0.000000,0.000000,1.000000), "SmoothPlastic", 232, 224, 198, 0, true, nil, nil, nil)
	P("Part", "UpperCoil0", "Cylinder", "", 0.1000, 0.3100, 0.3100, CFrame.new(0.0000,3.3000,0.1191,-0.000000,-1.000000,0.000000,-0.069756,0.000000,-0.997564,0.997564,-0.000000,-0.069756), "Grass", 86, 138, 58, 0, true, nil, nil, nil)
	P("Part", "UpperCoil1", "Cylinder", "", 0.1000, 0.3100, 0.3100, CFrame.new(0.0000,3.7333,0.2324,-0.000000,-1.000000,0.000000,-0.069756,0.000000,-0.997564,0.997564,-0.000000,-0.069756), "Grass", 86, 138, 58, 0, true, nil, nil, nil)
	P("Part", "UpperCoil2", "Cylinder", "", 0.1000, 0.3100, 0.3100, CFrame.new(0.0000,4.1667,0.3457,-0.000000,-1.000000,0.000000,-0.069756,0.000000,-0.997564,0.997564,-0.000000,-0.069756), "Grass", 86, 138, 58, 0, true, nil, nil, nil)
	P("Part", "UpperCoil3", "Cylinder", "", 0.1000, 0.3100, 0.3100, CFrame.new(0.0000,4.6000,0.4609,-0.000000,-1.000000,0.000000,-0.069756,0.000000,-0.997564,0.997564,-0.000000,-0.069756), "Grass", 86, 138, 58, 0, true, nil, nil, nil)
	P("Part", "UpperLeaf0", "Block", "", 0.0400, 0.3400, 0.2000, CFrame.new(0.0200,3.5500,0.0605,0.913545,0.000000,0.406737,0.139112,0.939693,-0.312451,-0.382207,0.342020,0.858452), "Grass", 112, 176, 72, 0, true, nil, nil, nil)
	P("Part", "UpperLeaf1", "Block", "", 0.0400, 0.3400, 0.2000, CFrame.new(0.0200,4.0500,0.2109,0.913545,0.000000,0.406737,0.287606,0.707107,-0.645974,-0.287606,0.707107,0.645974), "Grass", 112, 176, 72, 0, true, nil, nil, nil)
	P("Part", "UpperLeaf2", "Block", "", 0.0400, 0.3400, 0.2000, CFrame.new(0.0200,4.5500,0.3594,0.913545,0.000000,0.406737,0.382207,0.342020,-0.858452,-0.139112,0.939693,0.312451), "Grass", 112, 176, 72, 0, true, nil, nil, nil)
	P("Part", "UpperLimb", "Cylinder", "", 1.5000, 0.2400, 0.2400, CFrame.new(0.0000,3.8500,0.1992,-0.000000,-1.000000,0.000000,0.970296,-0.000000,-0.241922,0.241922,-0.000000,0.970296), "Wood", 104, 80, 52, 0, true, nil, nil, nil)
	P("Part", "UpperTip", "Cylinder", "", 0.5000, 0.1700, 0.1700, CFrame.new(0.0000,4.6500,0.5000,-0.000000,-1.000000,0.000000,0.882948,-0.000000,-0.469472,0.469472,-0.000000,0.882948), "Wood", 78, 58, 38, 0, true, nil, nil, nil)
	m.PrimaryPart = m:FindFirstChild("Root")
	m.WorldPivot = CFrame.new(0, 0, 0)
	return m
end
