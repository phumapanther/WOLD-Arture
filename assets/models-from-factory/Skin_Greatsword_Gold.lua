-- Skin_Greatsword_Gold — exported from WOLD-Models on 2026-09-18 (29 parts)
-- self-contained: no modelkit needed. Returns the Model, unparented.
--   local m = require(script.Skin_Greatsword_Gold)()   -- or paste this file's body into a build step
-- local space: base on y = 0, centred on x/z, front = -Z.
return function()
	local m = Instance.new("Model")
	m.Name = "Skin_Greatsword_Gold"
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
	P("Part", "Blade", "Block", "", 0.3000, 4.4000, 0.8200, CFrame.new(0.0000,2.9000,0.0000,1.000000,0.000000,0.000000,0.000000,1.000000,0.000000,0.000000,0.000000,1.000000), "Metal", 240, 214, 138, 0, true, nil, nil, nil)
	P("Part", "Edge", "Block", "", 0.1300, 4.0000, 0.0600, CFrame.new(0.0000,3.0000,0.3906,1.000000,0.000000,0.000000,0.000000,1.000000,0.000000,0.000000,0.000000,1.000000), "Metal", 148, 110, 44, 0, true, nil, nil, nil)
	P("Part", "Edge", "Block", "", 0.1300, 4.0000, 0.0600, CFrame.new(0.0000,3.0000,-0.3906,1.000000,0.000000,0.000000,0.000000,1.000000,0.000000,0.000000,0.000000,1.000000), "Metal", 148, 110, 44, 0, true, nil, nil, nil)
	P("Part", "Fuller", "Block", "", 0.3300, 3.7000, 0.2800, CFrame.new(0.0000,3.0000,0.0000,1.000000,0.000000,0.000000,0.000000,1.000000,0.000000,0.000000,0.000000,1.000000), "Metal", 198, 158, 78, 0, true, nil, nil, nil)
	P("Part", "Gem1L", "Ball", "", 0.2200, 0.2200, 0.2200, CFrame.new(-0.1600,4.6000,0.0000,1.000000,0.000000,0.000000,0.000000,1.000000,0.000000,0.000000,0.000000,1.000000), "Neon", 22, 154, 84, 0, true, nil, nil, nil)
	P("Part", "Gem1R", "Ball", "", 0.2200, 0.2200, 0.2200, CFrame.new(0.1600,4.6000,0.0000,1.000000,0.000000,0.000000,0.000000,1.000000,0.000000,0.000000,0.000000,1.000000), "Neon", 22, 154, 84, 0, true, nil, nil, nil)
	P("Part", "Gem2L", "Ball", "", 0.2200, 0.2200, 0.2200, CFrame.new(-0.1600,3.6000,0.0000,1.000000,0.000000,0.000000,0.000000,1.000000,0.000000,0.000000,0.000000,1.000000), "Neon", 112, 48, 196, 0, true, nil, nil, nil)
	P("Part", "Gem2R", "Ball", "", 0.2200, 0.2200, 0.2200, CFrame.new(0.1600,3.6000,0.0000,1.000000,0.000000,0.000000,0.000000,1.000000,0.000000,0.000000,0.000000,1.000000), "Neon", 112, 48, 196, 0, true, nil, nil, nil)
	P("Part", "Gem3L", "Ball", "", 0.2200, 0.2200, 0.2200, CFrame.new(-0.1600,2.6000,0.0000,1.000000,0.000000,0.000000,0.000000,1.000000,0.000000,0.000000,0.000000,1.000000), "Neon", 196, 38, 34, 0, true, nil, nil, nil)
	P("Part", "Gem3R", "Ball", "", 0.2200, 0.2200, 0.2200, CFrame.new(0.1600,2.6000,0.0000,1.000000,0.000000,0.000000,0.000000,1.000000,0.000000,0.000000,0.000000,1.000000), "Neon", 196, 38, 34, 0, true, nil, nil, nil)
	P("Part", "Gem4L", "Ball", "", 0.2200, 0.2200, 0.2200, CFrame.new(-0.1600,1.6000,0.0000,1.000000,0.000000,0.000000,0.000000,1.000000,0.000000,0.000000,0.000000,1.000000), "Neon", 40, 118, 208, 0, true, nil, nil, nil)
	P("Part", "Gem4R", "Ball", "", 0.2200, 0.2200, 0.2200, CFrame.new(0.1600,1.6000,0.0000,1.000000,0.000000,0.000000,0.000000,1.000000,0.000000,0.000000,0.000000,1.000000), "Neon", 40, 118, 208, 0, true, nil, nil, nil)
	P("Part", "Guard", "Block", "", 0.3600, 0.3000, 2.0000, CFrame.new(0.0000,5.2000,0.0000,1.000000,0.000000,0.000000,0.000000,1.000000,0.000000,0.000000,0.000000,1.000000), "Metal", 198, 158, 78, 0, true, nil, nil, nil)
	P("Part", "GuardGemL", "Ball", "", 0.2400, 0.2400, 0.2400, CFrame.new(-0.1900,5.2000,-0.7793,1.000000,0.000000,0.000000,0.000000,1.000000,0.000000,0.000000,0.000000,1.000000), "Neon", 86, 172, 232, 0, true, nil, nil, nil)
	P("Part", "GuardGemL", "Ball", "", 0.2400, 0.2400, 0.2400, CFrame.new(-0.1900,5.2000,0.7793,1.000000,0.000000,0.000000,0.000000,1.000000,0.000000,0.000000,0.000000,1.000000), "Neon", 86, 172, 232, 0, true, nil, nil, nil)
	P("Part", "GuardGemR", "Ball", "", 0.2400, 0.2400, 0.2400, CFrame.new(0.1900,5.2000,-0.7793,1.000000,0.000000,0.000000,0.000000,1.000000,0.000000,0.000000,0.000000,1.000000), "Neon", 86, 172, 232, 0, true, nil, nil, nil)
	P("Part", "GuardGemR", "Ball", "", 0.2400, 0.2400, 0.2400, CFrame.new(0.1900,5.2000,0.7793,1.000000,0.000000,0.000000,0.000000,1.000000,0.000000,0.000000,0.000000,1.000000), "Neon", 86, 172, 232, 0, true, nil, nil, nil)
	P("Part", "GuardLeaf", "Block", "", 0.3000, 0.4400, 0.3400, CFrame.new(0.0000,5.0400,0.7793,1.000000,0.000000,0.000000,0.000000,0.866025,-0.500000,0.000000,0.500000,0.866025), "Metal", 240, 214, 138, 0, true, nil, nil, nil)
	P("Part", "GuardLeaf", "Block", "", 0.3000, 0.4400, 0.3400, CFrame.new(0.0000,5.0400,-0.7793,1.000000,0.000000,0.000000,0.000000,0.866025,0.500000,0.000000,-0.500000,0.866025), "Metal", 240, 214, 138, 0, true, nil, nil, nil)
	P("Part", "Handle", "Cylinder", "", 1.4000, 0.3400, 0.3400, CFrame.new(0.0000,5.9000,0.0000,-0.000000,-1.000000,0.000000,1.000000,-0.000000,0.000000,0.000000,0.000000,1.000000), "Fabric", 128, 40, 44, 0, true, nil, nil, nil)
	P("Part", "Pommel", "Ball", "", 0.5000, 0.5000, 0.5000, CFrame.new(0.0000,6.7200,0.0000,1.000000,0.000000,0.000000,0.000000,1.000000,0.000000,0.000000,0.000000,1.000000), "Metal", 240, 214, 138, 0, true, nil, nil, nil)
	P("Part", "PommelGem", "Ball", "", 0.2200, 0.2200, 0.2200, CFrame.new(0.0000,6.9200,0.0000,1.000000,0.000000,0.000000,0.000000,1.000000,0.000000,0.000000,0.000000,1.000000), "Neon", 240, 82, 72, 0, true, nil, nil, nil)
	P("Part", "Root", "Block", "", 1.0000, 1.0000, 1.0000, CFrame.new(0.0000,0.0000,0.0000,1.000000,0.000000,0.000000,0.000000,1.000000,0.000000,0.000000,0.000000,1.000000), "Plastic", 163, 162, 165, 1, false, nil, nil, nil)
	P("WedgePart", "TipL", "", "", 0.3000, 0.4100, 0.7200, CFrame.new(0.0000,0.3400,-0.2051,1.000000,-0.000000,0.000000,0.000000,-0.000000,1.000000,0.000000,-1.000000,-0.000000), "Metal", 240, 214, 138, 0, true, nil, nil, nil)
	P("WedgePart", "TipR", "", "", 0.3000, 0.4100, 0.7200, CFrame.new(0.0000,0.3400,0.2051,-1.000000,0.000000,0.000000,0.000000,0.000000,1.000000,0.000000,1.000000,-0.000000), "Metal", 240, 214, 138, 0, true, nil, nil, nil)
	P("Part", "Wrap1", "Cylinder", "", 0.0700, 0.3800, 0.3800, CFrame.new(0.0000,5.3750,0.0000,-0.000000,-1.000000,0.000000,1.000000,-0.000000,0.000000,0.000000,0.000000,1.000000), "Metal", 240, 214, 138, 0, true, nil, nil, nil)
	P("Part", "Wrap2", "Cylinder", "", 0.0700, 0.3800, 0.3800, CFrame.new(0.0000,5.7250,0.0000,-0.000000,-1.000000,0.000000,1.000000,-0.000000,0.000000,0.000000,0.000000,1.000000), "Metal", 240, 214, 138, 0, true, nil, nil, nil)
	P("Part", "Wrap3", "Cylinder", "", 0.0700, 0.3800, 0.3800, CFrame.new(0.0000,6.0750,0.0000,-0.000000,-1.000000,0.000000,1.000000,-0.000000,0.000000,0.000000,0.000000,1.000000), "Metal", 240, 214, 138, 0, true, nil, nil, nil)
	P("Part", "Wrap4", "Cylinder", "", 0.0700, 0.3800, 0.3800, CFrame.new(0.0000,6.4250,0.0000,-0.000000,-1.000000,0.000000,1.000000,-0.000000,0.000000,0.000000,0.000000,1.000000), "Metal", 240, 214, 138, 0, true, nil, nil, nil)
	m.PrimaryPart = m:FindFirstChild("Root")
	m.WorldPivot = CFrame.new(0, 0, 0)
	return m
end
