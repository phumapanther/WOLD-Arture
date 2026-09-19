-- Skin_Sword_Frost — exported from WOLD-Models on 2026-09-18 (18 parts)
-- self-contained: no modelkit needed. Returns the Model, unparented.
--   local m = require(script.Skin_Sword_Frost)()   -- or paste this file's body into a build step
-- local space: base on y = 0, centred on x/z, front = -Z.
return function()
	local m = Instance.new("Model")
	m.Name = "Skin_Sword_Frost"
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
	P("Part", "Blade", "Block", "", 0.1900, 3.0000, 0.4600, CFrame.new(0.0000,2.2000,0.0000,1.000000,0.000000,0.000000,0.000000,1.000000,0.000000,0.000000,0.000000,1.000000), "Ice", 150, 214, 250, 0.05, true, nil, nil, nil)
	P("Part", "Core", "Block", "", 0.2300, 2.4000, 0.1400, CFrame.new(0.0000,2.3000,0.0000,1.000000,0.000000,0.000000,0.000000,1.000000,0.000000,0.000000,0.000000,1.000000), "Glass", 46, 116, 184, 0, true, nil, nil, nil)
	P("Part", "Flake0", "Block", "", 0.1600, 0.1700, 1.4200, CFrame.new(0.0000,3.7200,0.0000,1.000000,0.000000,0.000000,0.000000,1.000000,0.000000,0.000000,0.000000,1.000000), "Ice", 150, 214, 250, 0, true, nil, nil, nil)
	P("Part", "Flake120", "Block", "", 0.1600, 0.1700, 1.4200, CFrame.new(0.0000,3.7200,0.0000,1.000000,0.000000,0.000000,0.000000,-0.500000,-0.866025,0.000000,0.866025,-0.500000), "Ice", 150, 214, 250, 0, true, nil, nil, nil)
	P("Part", "Flake60", "Block", "", 0.1600, 0.1700, 1.4200, CFrame.new(0.0000,3.7200,0.0000,1.000000,0.000000,0.000000,0.000000,0.500000,-0.866025,0.000000,0.866025,0.500000), "Ice", 150, 214, 250, 0, true, nil, nil, nil)
	P("Part", "FlakeHub", "Ball", "", 0.3400, 0.3400, 0.3400, CFrame.new(0.0000,3.7200,0.0000,1.000000,0.000000,0.000000,0.000000,1.000000,0.000000,0.000000,0.000000,1.000000), "Glass", 46, 116, 184, 0, true, nil, nil, nil)
	P("Part", "Handle", "Cylinder", "", 0.9000, 0.2600, 0.2600, CFrame.new(0.0000,4.2000,0.0000,-0.000000,-1.000000,0.000000,1.000000,-0.000000,0.000000,0.000000,0.000000,1.000000), "Ice", 28, 62, 104, 0, true, nil, nil, nil)
	P("Part", "Jag0", "Block", "", 0.1400, 0.4000, 0.2200, CFrame.new(0.0000,3.2500,0.2793,1.000000,0.000000,0.000000,0.000000,0.866025,-0.500000,0.000000,0.500000,0.866025), "Ice", 150, 214, 250, 0.08, true, nil, nil, nil)
	P("Part", "Jag1", "Block", "", 0.1400, 0.4000, 0.2200, CFrame.new(0.0000,2.6300,-0.2793,1.000000,0.000000,0.000000,0.000000,0.866025,0.500000,0.000000,-0.500000,0.866025), "Ice", 150, 214, 250, 0.08, true, nil, nil, nil)
	P("Part", "Jag2", "Block", "", 0.1400, 0.4000, 0.2200, CFrame.new(0.0000,2.0100,0.2793,1.000000,0.000000,0.000000,0.000000,0.866025,-0.500000,0.000000,0.500000,0.866025), "Ice", 150, 214, 250, 0.08, true, nil, nil, nil)
	P("Part", "Jag3", "Block", "", 0.1400, 0.4000, 0.2200, CFrame.new(0.0000,1.3900,-0.2793,1.000000,0.000000,0.000000,0.000000,0.866025,0.500000,0.000000,-0.500000,0.866025), "Ice", 150, 214, 250, 0.08, true, nil, nil, nil)
	P("Part", "Pommel", "Ball", "", 0.3200, 0.3200, 0.3200, CFrame.new(0.0000,4.7200,0.0000,1.000000,0.000000,0.000000,0.000000,1.000000,0.000000,0.000000,0.000000,1.000000), "Glass", 46, 116, 184, 0, true, nil, nil, nil)
	P("Part", "Root", "Block", "", 1.0000, 1.0000, 1.0000, CFrame.new(0.0000,0.0000,0.0000,1.000000,0.000000,0.000000,0.000000,1.000000,0.000000,0.000000,0.000000,1.000000), "Plastic", 163, 162, 165, 1, false, nil, nil, nil)
	P("WedgePart", "TipL", "", "", 0.1900, 0.2300, 0.5200, CFrame.new(0.0000,0.4400,-0.1152,1.000000,-0.000000,0.000000,0.000000,-0.000000,1.000000,0.000000,-1.000000,-0.000000), "Ice", 150, 214, 250, 0, true, nil, nil, nil)
	P("WedgePart", "TipR", "", "", 0.1900, 0.2300, 0.5200, CFrame.new(0.0000,0.4400,0.1152,-1.000000,0.000000,0.000000,0.000000,0.000000,1.000000,0.000000,1.000000,-0.000000), "Ice", 150, 214, 250, 0, true, nil, nil, nil)
	P("Part", "Wrap1", "Cylinder", "", 0.0700, 0.3000, 0.3000, CFrame.new(0.0000,3.9000,0.0000,-0.000000,-1.000000,0.000000,1.000000,-0.000000,0.000000,0.000000,0.000000,1.000000), "Metal", 150, 214, 250, 0, true, nil, nil, nil)
	P("Part", "Wrap2", "Cylinder", "", 0.0700, 0.3000, 0.3000, CFrame.new(0.0000,4.2000,0.0000,-0.000000,-1.000000,0.000000,1.000000,-0.000000,0.000000,0.000000,0.000000,1.000000), "Metal", 150, 214, 250, 0, true, nil, nil, nil)
	P("Part", "Wrap3", "Cylinder", "", 0.0700, 0.3000, 0.3000, CFrame.new(0.0000,4.5000,0.0000,-0.000000,-1.000000,0.000000,1.000000,-0.000000,0.000000,0.000000,0.000000,1.000000), "Metal", 150, 214, 250, 0, true, nil, nil, nil)
	m.PrimaryPart = m:FindFirstChild("Root")
	m.WorldPivot = CFrame.new(0, 0, 0)
	return m
end
