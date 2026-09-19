-- GoldPickaxe — exported from WOLD-Models on 2026-09-18 (23 parts)
-- self-contained: no modelkit needed. Returns the Model, unparented.
--   local m = require(script.GoldPickaxe)()   -- or paste this file's body into a build step
-- local space: base on y = 0, centred on x/z, front = -Z.
return function()
	local m = Instance.new("Model")
	m.Name = "GoldPickaxe"
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
	P("Part", "Collar", "Cylinder", "", 0.3400, 0.2700, 0.2700, CFrame.new(0.0000,1.4200,0.0000,-0.000000,-1.000000,0.000000,1.000000,-0.000000,0.000000,0.000000,0.000000,1.000000), "Metal", 240, 214, 138, 0, true, nil, nil, nil)
	P("Part", "Crown", "Block", "", 0.2400, 0.4600, 0.4600, CFrame.new(0.0000,1.0500,0.0000,1.000000,0.000000,0.000000,0.000000,1.000000,0.000000,0.000000,0.000000,1.000000), "Metal", 198, 158, 78, 0, true, nil, nil, nil)
	P("Part", "CrownBand", "Block", "", 0.2800, 0.2400, 0.5200, CFrame.new(0.0000,1.0500,0.0000,1.000000,0.000000,0.000000,0.000000,1.000000,0.000000,0.000000,0.000000,1.000000), "Metal", 240, 214, 138, 0, true, nil, nil, nil)
	P("Part", "EngraveL", "Block", "", 0.0200, 0.1000, 0.3000, CFrame.new(0.0800,1.0800,-0.6191,1.000000,0.000000,0.000000,0.000000,0.970296,-0.241922,0.000000,0.241922,0.970296), "Metal", 148, 110, 44, 0, true, nil, nil, nil)
	P("Part", "EngraveR", "Block", "", 0.0200, 0.1000, 0.3000, CFrame.new(0.0800,1.0800,0.6191,1.000000,0.000000,0.000000,0.000000,0.970296,0.241922,0.000000,-0.241922,0.970296), "Metal", 148, 110, 44, 0, true, nil, nil, nil)
	P("Part", "GemL", "Ball", "", 0.2200, 0.2200, 0.2200, CFrame.new(-0.1300,1.0500,0.0000,1.000000,0.000000,0.000000,0.000000,1.000000,0.000000,0.000000,0.000000,1.000000), "Neon", 24, 170, 104, 0, true, nil, nil, nil)
	P("Part", "GemR", "Ball", "", 0.2200, 0.2200, 0.2200, CFrame.new(0.1300,1.0500,0.0000,1.000000,0.000000,0.000000,0.000000,1.000000,0.000000,0.000000,0.000000,1.000000), "Neon", 24, 170, 104, 0, true, nil, nil, nil)
	P("Part", "Grip", "Cylinder", "", 0.9000, 0.2000, 0.2000, CFrame.new(0.0000,4.2000,0.0000,-0.000000,-1.000000,0.000000,1.000000,-0.000000,0.000000,0.000000,0.000000,1.000000), "Fabric", 72, 50, 36, 0, true, nil, nil, nil)
	P("Part", "GripBand", "Cylinder", "", 0.0700, 0.2400, 0.2400, CFrame.new(0.0000,3.9000,0.0000,-0.000000,-1.000000,0.000000,1.000000,-0.000000,0.000000,0.000000,0.000000,1.000000), "Metal", 240, 214, 138, 0, true, nil, nil, nil)
	P("Part", "GripBand", "Cylinder", "", 0.0700, 0.2400, 0.2400, CFrame.new(0.0000,4.5000,0.0000,-0.000000,-1.000000,0.000000,1.000000,-0.000000,0.000000,0.000000,0.000000,1.000000), "Metal", 240, 214, 138, 0, true, nil, nil, nil)
	P("Part", "GripBand", "Cylinder", "", 0.0700, 0.2400, 0.2400, CFrame.new(0.0000,4.2000,0.0000,-0.000000,-1.000000,0.000000,1.000000,-0.000000,0.000000,0.000000,0.000000,1.000000), "Metal", 240, 214, 138, 0, true, nil, nil, nil)
	P("Part", "Haft", "Cylinder", "", 3.0000, 0.1700, 0.1700, CFrame.new(0.0000,2.2000,0.0000,-0.000000,-1.000000,0.000000,1.000000,-0.000000,0.000000,0.000000,0.000000,1.000000), "Wood", 92, 62, 40, 0, true, nil, nil, nil)
	P("Part", "HaftSwell", "Cylinder", "", 0.9000, 0.2100, 0.2100, CFrame.new(0.0000,3.4500,0.0000,-0.000000,-1.000000,0.000000,1.000000,-0.000000,0.000000,0.000000,0.000000,1.000000), "Wood", 92, 62, 40, 0, true, nil, nil, nil)
	P("Part", "Horn1L", "Block", "", 0.1700, 0.2600, 0.5200, CFrame.new(0.0000,1.0200,-0.3398,1.000000,0.000000,0.000000,0.000000,0.990268,-0.139173,0.000000,0.139173,0.990268), "Metal", 198, 158, 78, 0, true, nil, nil, nil)
	P("Part", "Horn1R", "Block", "", 0.1700, 0.2600, 0.5200, CFrame.new(0.0000,1.0200,0.3398,1.000000,0.000000,0.000000,0.000000,0.990268,0.139173,0.000000,-0.139173,0.990268), "Metal", 198, 158, 78, 0, true, nil, nil, nil)
	P("Part", "Horn2L", "Block", "", 0.1500, 0.2200, 0.5200, CFrame.new(0.0000,1.1000,-0.8008,1.000000,0.000000,0.000000,0.000000,0.927184,-0.374607,0.000000,0.374607,0.927184), "Metal", 240, 214, 138, 0, true, nil, nil, nil)
	P("Part", "Horn2R", "Block", "", 0.1500, 0.2200, 0.5200, CFrame.new(0.0000,1.1000,0.8008,1.000000,0.000000,0.000000,0.000000,0.927184,0.374607,0.000000,-0.374607,0.927184), "Metal", 240, 214, 138, 0, true, nil, nil, nil)
	P("Part", "Horn3L", "Block", "", 0.1200, 0.1700, 0.4200, CFrame.new(0.0000,1.2800,-1.1602,1.000000,0.000000,0.000000,0.000000,0.788011,-0.615662,0.000000,0.615662,0.788011), "Metal", 240, 214, 138, 0, true, nil, nil, nil)
	P("Part", "Horn3R", "Block", "", 0.1200, 0.1700, 0.4200, CFrame.new(0.0000,1.2800,1.1602,1.000000,0.000000,0.000000,0.000000,0.788011,0.615662,0.000000,-0.615662,0.788011), "Metal", 240, 214, 138, 0, true, nil, nil, nil)
	P("Part", "PointL", "Block", "", 0.0700, 0.1100, 0.2400, CFrame.new(0.0000,1.4600,-1.3809,1.000000,0.000000,0.000000,0.000000,0.694658,-0.719340,0.000000,0.719340,0.694658), "Metal", 240, 214, 138, 0, true, nil, nil, nil)
	P("Part", "PointR", "Block", "", 0.0700, 0.1100, 0.2400, CFrame.new(0.0000,1.4600,1.3809,1.000000,0.000000,0.000000,0.000000,0.694658,0.719340,0.000000,-0.719340,0.694658), "Metal", 240, 214, 138, 0, true, nil, nil, nil)
	P("Part", "Pommel", "Cylinder", "", 0.1800, 0.2600, 0.2600, CFrame.new(0.0000,4.7200,0.0000,-0.000000,-1.000000,0.000000,1.000000,-0.000000,0.000000,0.000000,0.000000,1.000000), "Metal", 240, 214, 138, 0, true, nil, nil, nil)
	P("Part", "Root", "Block", "", 1.0000, 1.0000, 1.0000, CFrame.new(0.0000,0.0000,0.0000,1.000000,0.000000,0.000000,0.000000,1.000000,0.000000,0.000000,0.000000,1.000000), "Plastic", 163, 162, 165, 1, false, nil, nil, nil)
	m.PrimaryPart = m:FindFirstChild("Root")
	m.WorldPivot = CFrame.new(0, 0, 0)
	return m
end
