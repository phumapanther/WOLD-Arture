-- GoldAxe — exported from WOLD-Models on 2026-09-18 (18 parts)
-- self-contained: no modelkit needed. Returns the Model, unparented.
--   local m = require(script.GoldAxe)()   -- or paste this file's body into a build step
-- local space: base on y = 0, centred on x/z, front = -Z.
return function()
	local m = Instance.new("Model")
	m.Name = "GoldAxe"
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
	P("Part", "Bit", "Block", "", 0.1500, 0.8000, 0.9000, CFrame.new(0.0000,1.1000,0.5996,1.000000,0.000000,0.000000,0.000000,1.000000,0.000000,0.000000,0.000000,1.000000), "Metal", 198, 158, 78, 0, true, nil, nil, nil)
	P("Part", "Collar", "Cylinder", "", 0.2800, 0.2500, 0.2500, CFrame.new(0.0000,1.5800,0.0000,-0.000000,-1.000000,0.000000,1.000000,-0.000000,0.000000,0.000000,0.000000,1.000000), "Metal", 240, 214, 138, 0, true, nil, nil, nil)
	P("Part", "Edge", "Block", "", 0.0600, 1.4400, 0.1000, CFrame.new(0.0000,1.1000,1.0801,1.000000,0.000000,0.000000,0.000000,1.000000,0.000000,0.000000,0.000000,1.000000), "Metal", 240, 214, 138, 0, true, nil, nil, nil)
	P("Part", "Engrave", "Block", "", 0.0200, 0.5600, 0.2000, CFrame.new(0.0800,1.1000,0.6992,1.000000,0.000000,0.000000,0.000000,1.000000,0.000000,0.000000,0.000000,1.000000), "Metal", 148, 110, 44, 0, true, nil, nil, nil)
	P("Part", "Eye", "Block", "", 0.2000, 0.7000, 0.2600, CFrame.new(0.0000,1.1000,0.1797,1.000000,0.000000,0.000000,0.000000,1.000000,0.000000,0.000000,0.000000,1.000000), "Metal", 198, 158, 78, 0, true, nil, nil, nil)
	P("WedgePart", "FlareBottom", "", "", 0.1300, 0.3400, 0.9000, CFrame.new(0.0000,0.5300,0.5996,-1.000000,0.000000,0.000000,-0.000000,-1.000000,0.000000,0.000000,0.000000,1.000000), "Metal", 240, 214, 138, 0, true, nil, nil, nil)
	P("WedgePart", "FlareTop", "", "", 0.1300, 0.3400, 0.9000, CFrame.new(0.0000,1.6700,0.5996,1.000000,0.000000,0.000000,0.000000,1.000000,0.000000,0.000000,0.000000,1.000000), "Metal", 240, 214, 138, 0, true, nil, nil, nil)
	P("Part", "GemL", "Ball", "", 0.1600, 0.1600, 0.1600, CFrame.new(-0.0800,1.1000,0.4199,1.000000,0.000000,0.000000,0.000000,1.000000,0.000000,0.000000,0.000000,1.000000), "Neon", 246, 146, 24, 0, true, nil, nil, nil)
	P("Part", "GemR", "Ball", "", 0.1600, 0.1600, 0.1600, CFrame.new(0.0800,1.1000,0.4199,1.000000,0.000000,0.000000,0.000000,1.000000,0.000000,0.000000,0.000000,1.000000), "Neon", 246, 146, 24, 0, true, nil, nil, nil)
	P("Part", "Grip", "Cylinder", "", 0.9000, 0.2000, 0.2000, CFrame.new(0.0000,4.2000,0.0000,-0.000000,-1.000000,0.000000,1.000000,-0.000000,0.000000,0.000000,0.000000,1.000000), "Fabric", 72, 50, 36, 0, true, nil, nil, nil)
	P("Part", "GripBand", "Cylinder", "", 0.0700, 0.2400, 0.2400, CFrame.new(0.0000,4.5000,0.0000,-0.000000,-1.000000,0.000000,1.000000,-0.000000,0.000000,0.000000,0.000000,1.000000), "Metal", 240, 214, 138, 0, true, nil, nil, nil)
	P("Part", "GripBand", "Cylinder", "", 0.0700, 0.2400, 0.2400, CFrame.new(0.0000,4.2000,0.0000,-0.000000,-1.000000,0.000000,1.000000,-0.000000,0.000000,0.000000,0.000000,1.000000), "Metal", 240, 214, 138, 0, true, nil, nil, nil)
	P("Part", "GripBand", "Cylinder", "", 0.0700, 0.2400, 0.2400, CFrame.new(0.0000,3.9000,0.0000,-0.000000,-1.000000,0.000000,1.000000,-0.000000,0.000000,0.000000,0.000000,1.000000), "Metal", 240, 214, 138, 0, true, nil, nil, nil)
	P("Part", "Haft", "Cylinder", "", 3.0000, 0.1700, 0.1700, CFrame.new(0.0000,2.2000,0.0000,-0.000000,-1.000000,0.000000,1.000000,-0.000000,0.000000,0.000000,0.000000,1.000000), "Wood", 92, 62, 40, 0, true, nil, nil, nil)
	P("Part", "HaftSwell", "Cylinder", "", 0.9000, 0.2100, 0.2100, CFrame.new(0.0000,3.4500,0.0000,-0.000000,-1.000000,0.000000,1.000000,-0.000000,0.000000,0.000000,0.000000,1.000000), "Wood", 92, 62, 40, 0, true, nil, nil, nil)
	P("Part", "Poll", "Block", "", 0.1600, 0.4400, 0.3000, CFrame.new(0.0000,1.1000,-0.1797,1.000000,0.000000,0.000000,0.000000,1.000000,0.000000,0.000000,0.000000,1.000000), "Metal", 198, 158, 78, 0, true, nil, nil, nil)
	P("Part", "Pommel", "Cylinder", "", 0.1800, 0.2600, 0.2600, CFrame.new(0.0000,4.7200,0.0000,-0.000000,-1.000000,0.000000,1.000000,-0.000000,0.000000,0.000000,0.000000,1.000000), "Metal", 240, 214, 138, 0, true, nil, nil, nil)
	P("Part", "Root", "Block", "", 1.0000, 1.0000, 1.0000, CFrame.new(0.0000,0.0000,0.0000,1.000000,0.000000,0.000000,0.000000,1.000000,0.000000,0.000000,0.000000,1.000000), "Plastic", 163, 162, 165, 1, false, nil, nil, nil)
	m.PrimaryPart = m:FindFirstChild("Root")
	m.WorldPivot = CFrame.new(0, 0, 0)
	return m
end
