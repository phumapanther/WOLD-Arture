-- Skin_Spellbook_Blood — exported from WOLD-Models on 2026-09-18 (20 parts)
-- self-contained: no modelkit needed. Returns the Model, unparented.
--   local m = require(script.Skin_Spellbook_Blood)()   -- or paste this file's body into a build step
-- local space: base on y = 0, centred on x/z, front = -Z.
return function()
	local m = Instance.new("Model")
	m.Name = "Skin_Spellbook_Blood"
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
	P("Part", "Clasp", "Block", "", 0.1800, 0.3400, 0.3000, CFrame.new(0.6200,0.4700,0.0000,1.000000,0.000000,0.000000,0.000000,1.000000,0.000000,0.000000,0.000000,1.000000), "Metal", 240, 214, 138, 0, true, nil, nil, nil)
	P("Part", "Corner", "Block", "", 0.2200, 0.0500, 0.2000, CFrame.new(-0.5600,0.6200,-0.7207,1.000000,0.000000,0.000000,0.000000,1.000000,0.000000,0.000000,0.000000,1.000000), "Metal", 240, 214, 138, 0, true, nil, nil, nil)
	P("Part", "Corner", "Block", "", 0.2200, 0.0500, 0.2000, CFrame.new(0.5600,0.6200,-0.7207,1.000000,0.000000,0.000000,0.000000,1.000000,0.000000,0.000000,0.000000,1.000000), "Metal", 240, 214, 138, 0, true, nil, nil, nil)
	P("Part", "Corner", "Block", "", 0.2200, 0.0500, 0.2000, CFrame.new(-0.5600,0.6200,0.7207,1.000000,0.000000,0.000000,0.000000,1.000000,0.000000,0.000000,0.000000,1.000000), "Metal", 240, 214, 138, 0, true, nil, nil, nil)
	P("Part", "Corner", "Block", "", 0.2200, 0.0500, 0.2000, CFrame.new(0.5600,0.6200,0.7207,1.000000,0.000000,0.000000,0.000000,1.000000,0.000000,0.000000,0.000000,1.000000), "Metal", 240, 214, 138, 0, true, nil, nil, nil)
	P("Part", "CoverBack", "Block", "", 1.3000, 0.1300, 1.6000, CFrame.new(0.0000,0.3600,0.0000,1.000000,0.000000,0.000000,0.000000,1.000000,0.000000,0.000000,0.000000,1.000000), "Leather", 132, 30, 36, 0, true, nil, nil, nil)
	P("Part", "CoverTop", "Block", "", 1.3000, 0.1300, 1.6000, CFrame.new(0.0000,0.5700,0.0000,1.000000,0.000000,0.000000,0.000000,1.000000,0.000000,0.000000,0.000000,1.000000), "Leather", 132, 30, 36, 0, true, nil, nil, nil)
	P("Part", "Eye", "Ball", "", 0.2600, 0.2600, 0.2600, CFrame.new(0.0000,0.6600,0.0000,1.000000,0.000000,0.000000,0.000000,1.000000,0.000000,0.000000,0.000000,1.000000), "Neon", 240, 60, 60, 0, true, nil, nil, nil)
	P("Part", "GemA", "Ball", "", 0.1500, 0.1500, 0.1500, CFrame.new(0.0000,0.6500,-0.4395,1.000000,0.000000,0.000000,0.000000,1.000000,0.000000,0.000000,0.000000,1.000000), "Neon", 240, 60, 60, 0, true, nil, nil, nil)
	P("Part", "GemB", "Ball", "", 0.1500, 0.1500, 0.1500, CFrame.new(0.0000,0.6500,0.4395,1.000000,0.000000,0.000000,0.000000,1.000000,0.000000,0.000000,0.000000,1.000000), "Neon", 240, 60, 60, 0, true, nil, nil, nil)
	P("Part", "Inlay1", "Block", "", 0.6000, 0.0400, 0.0600, CFrame.new(0.0000,0.6300,0.0000,1.000000,0.000000,0.000000,0.000000,1.000000,0.000000,0.000000,0.000000,1.000000), "Metal", 198, 158, 78, 0, true, nil, nil, nil)
	P("Part", "Inlay2", "Block", "", 0.0600, 0.0400, 0.8000, CFrame.new(0.0000,0.6300,0.0000,1.000000,0.000000,0.000000,0.000000,1.000000,0.000000,0.000000,0.000000,1.000000), "Metal", 198, 158, 78, 0, true, nil, nil, nil)
	P("Part", "Pages", "Block", "", 1.1800, 0.1600, 1.4800, CFrame.new(0.0200,0.4700,0.0195,1.000000,0.000000,0.000000,0.000000,1.000000,0.000000,0.000000,0.000000,1.000000), "SmoothPlastic", 232, 224, 198, 0, true, nil, nil, nil)
	P("Part", "Ribbon", "Block", "", 0.1000, 0.0400, 0.3400, CFrame.new(0.3000,0.3400,0.6992,1.000000,0.000000,0.000000,0.000000,1.000000,0.000000,0.000000,0.000000,1.000000), "Fabric", 196, 54, 58, 0, true, nil, nil, nil)
	P("Part", "Root", "Block", "", 1.0000, 1.0000, 1.0000, CFrame.new(0.0000,0.0000,0.0000,1.000000,0.000000,0.000000,0.000000,1.000000,0.000000,0.000000,0.000000,1.000000), "Plastic", 163, 162, 165, 1, false, nil, nil, nil)
	P("Part", "Spine", "Block", "", 0.2600, 0.4200, 1.6200, CFrame.new(-0.6200,0.4700,0.0000,1.000000,0.000000,0.000000,0.000000,1.000000,0.000000,0.000000,0.000000,1.000000), "Leather", 86, 20, 26, 0, true, nil, nil, nil)
	P("Part", "SpineBand", "Block", "", 0.2700, 0.4500, 0.1100, CFrame.new(-0.6300,0.4700,0.5000,1.000000,0.000000,0.000000,0.000000,1.000000,0.000000,0.000000,0.000000,1.000000), "Metal", 198, 158, 78, 0, true, nil, nil, nil)
	P("Part", "SpineBand", "Block", "", 0.2700, 0.4500, 0.1100, CFrame.new(-0.6300,0.4700,0.0000,1.000000,0.000000,0.000000,0.000000,1.000000,0.000000,0.000000,0.000000,1.000000), "Metal", 198, 158, 78, 0, true, nil, nil, nil)
	P("Part", "SpineBand", "Block", "", 0.2700, 0.4500, 0.1100, CFrame.new(-0.6300,0.4700,-0.5000,1.000000,0.000000,0.000000,0.000000,1.000000,0.000000,0.000000,0.000000,1.000000), "Metal", 198, 158, 78, 0, true, nil, nil, nil)
	P("Part", "Strap", "Block", "", 0.3000, 0.0500, 0.1800, CFrame.new(0.5000,0.6200,0.0000,1.000000,0.000000,0.000000,0.000000,1.000000,0.000000,0.000000,0.000000,1.000000), "Leather", 86, 20, 26, 0, true, nil, nil, nil)
	m.PrimaryPart = m:FindFirstChild("Root")
	m.WorldPivot = CFrame.new(0, 0, 0)
	return m
end
