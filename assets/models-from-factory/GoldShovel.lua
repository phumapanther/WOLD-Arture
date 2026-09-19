-- GoldShovel — exported from WOLD-Models on 2026-09-18 (20 parts)
-- self-contained: no modelkit needed. Returns the Model, unparented.
--   local m = require(script.GoldShovel)()   -- or paste this file's body into a build step
-- local space: base on y = 0, centred on x/z, front = -Z.
return function()
	local m = Instance.new("Model")
	m.Name = "GoldShovel"
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
	P("Part", "Blade", "Block", "", 0.8600, 0.9400, 0.1100, CFrame.new(0.0000,0.9200,0.0605,1.000000,0.000000,0.000000,0.000000,1.000000,0.000000,0.000000,0.000000,1.000000), "Metal", 240, 214, 138, 0, true, nil, nil, nil)
	P("WedgePart", "BladeTipL", "", "", 0.1100, 0.4300, 0.5000, CFrame.new(-0.2150,0.2000,0.0605,-0.000000,-1.000000,-0.000000,0.000000,-0.000000,1.000000,-1.000000,0.000000,0.000000), "Metal", 240, 214, 138, 0, true, nil, nil, nil)
	P("WedgePart", "BladeTipR", "", "", 0.1100, 0.4300, 0.5000, CFrame.new(0.2150,0.2000,0.0605,0.000000,1.000000,-0.000000,0.000000,0.000000,1.000000,1.000000,-0.000000,0.000000), "Metal", 240, 214, 138, 0, true, nil, nil, nil)
	P("Part", "DArm", "Block", "", 0.1000, 0.5000, 0.1100, CFrame.new(0.1400,4.5400,0.0000,0.961262,-0.275637,0.000000,0.275637,0.961262,0.000000,0.000000,0.000000,1.000000), "Metal", 240, 214, 138, 0, true, nil, nil, nil)
	P("Part", "DArm", "Block", "", 0.1000, 0.5000, 0.1100, CFrame.new(-0.1400,4.5400,0.0000,0.961262,0.275637,0.000000,-0.275637,0.961262,0.000000,0.000000,0.000000,1.000000), "Metal", 240, 214, 138, 0, true, nil, nil, nil)
	P("Part", "DGem", "Ball", "", 0.1500, 0.1500, 0.1500, CFrame.new(0.0000,4.8000,0.0000,1.000000,0.000000,0.000000,0.000000,1.000000,0.000000,0.000000,0.000000,1.000000), "Neon", 86, 172, 232, 0, true, nil, nil, nil)
	P("Part", "DTop", "Block", "", 0.4400, 0.1100, 0.1200, CFrame.new(0.0000,4.8000,0.0000,1.000000,0.000000,0.000000,0.000000,1.000000,0.000000,0.000000,0.000000,1.000000), "Metal", 240, 214, 138, 0, true, nil, nil, nil)
	P("Part", "Gem", "Ball", "", 0.1800, 0.1800, 0.1800, CFrame.new(0.0000,1.1400,0.1406,1.000000,0.000000,0.000000,0.000000,1.000000,0.000000,0.000000,0.000000,1.000000), "Neon", 246, 146, 24, 0, true, nil, nil, nil)
	P("Part", "Grip", "Cylinder", "", 0.7200, 0.2000, 0.2000, CFrame.new(0.0000,4.0600,0.0000,-0.000000,-1.000000,0.000000,1.000000,-0.000000,0.000000,0.000000,0.000000,1.000000), "Fabric", 72, 50, 36, 0, true, nil, nil, nil)
	P("Part", "GripBand", "Cylinder", "", 0.0700, 0.2400, 0.2400, CFrame.new(0.0000,4.0600,0.0000,-0.000000,-1.000000,0.000000,1.000000,-0.000000,0.000000,0.000000,0.000000,1.000000), "Metal", 240, 214, 138, 0, true, nil, nil, nil)
	P("Part", "GripBand", "Cylinder", "", 0.0700, 0.2400, 0.2400, CFrame.new(0.0000,3.8200,0.0000,-0.000000,-1.000000,0.000000,1.000000,-0.000000,0.000000,0.000000,0.000000,1.000000), "Metal", 240, 214, 138, 0, true, nil, nil, nil)
	P("Part", "GripBand", "Cylinder", "", 0.0700, 0.2400, 0.2400, CFrame.new(0.0000,4.3000,0.0000,-0.000000,-1.000000,0.000000,1.000000,-0.000000,0.000000,0.000000,0.000000,1.000000), "Metal", 240, 214, 138, 0, true, nil, nil, nil)
	P("Part", "Haft", "Cylinder", "", 3.0000, 0.1700, 0.1700, CFrame.new(0.0000,2.2000,0.0000,-0.000000,-1.000000,0.000000,1.000000,-0.000000,0.000000,0.000000,0.000000,1.000000), "Wood", 92, 62, 40, 0, true, nil, nil, nil)
	P("Part", "Root", "Block", "", 1.0000, 1.0000, 1.0000, CFrame.new(0.0000,0.0000,0.0000,1.000000,0.000000,0.000000,0.000000,1.000000,0.000000,0.000000,0.000000,1.000000), "Plastic", 163, 162, 165, 1, false, nil, nil, nil)
	P("Part", "Scroll1", "Block", "", 0.4400, 0.0600, 0.0200, CFrame.new(0.0000,0.9800,0.1309,1.000000,0.000000,0.000000,0.000000,1.000000,0.000000,0.000000,0.000000,1.000000), "Metal", 148, 110, 44, 0, true, nil, nil, nil)
	P("Part", "Scroll2", "Block", "", 0.0600, 0.3400, 0.0200, CFrame.new(-0.2200,0.7800,0.1309,1.000000,0.000000,0.000000,0.000000,1.000000,0.000000,0.000000,0.000000,1.000000), "Metal", 148, 110, 44, 0, true, nil, nil, nil)
	P("Part", "Scroll3", "Block", "", 0.0600, 0.3400, 0.0200, CFrame.new(0.2200,0.7800,0.1309,1.000000,0.000000,0.000000,0.000000,1.000000,0.000000,0.000000,0.000000,1.000000), "Metal", 148, 110, 44, 0, true, nil, nil, nil)
	P("Part", "Shoulder", "Block", "", 0.5200, 0.2200, 0.1300, CFrame.new(0.0000,1.3600,0.0605,1.000000,0.000000,0.000000,0.000000,1.000000,0.000000,0.000000,0.000000,1.000000), "Metal", 198, 158, 78, 0, true, nil, nil, nil)
	P("Part", "Socket", "Cylinder", "", 0.4600, 0.2500, 0.2500, CFrame.new(0.0000,1.5400,0.0000,-0.000000,-1.000000,0.000000,1.000000,-0.000000,0.000000,0.000000,0.000000,1.000000), "Metal", 198, 158, 78, 0, true, nil, nil, nil)
	P("Part", "Wing", "Block", "", 0.1600, 0.5200, 0.1800, CFrame.new(0.0000,1.2800,-0.0391,1.000000,0.000000,0.000000,0.000000,1.000000,0.000000,0.000000,0.000000,1.000000), "Metal", 198, 158, 78, 0, true, nil, nil, nil)
	m.PrimaryPart = m:FindFirstChild("Root")
	m.WorldPivot = CFrame.new(0, 0, 0)
	return m
end
