-- GoldFishingRod — exported from WOLD-Models on 2026-09-18 (28 parts)
-- self-contained: no modelkit needed. Returns the Model, unparented.
--   local m = require(script.GoldFishingRod)()   -- or paste this file's body into a build step
-- local space: base on y = 0, centred on x/z, front = -Z.
return function()
	local m = Instance.new("Model")
	m.Name = "GoldFishingRod"
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
	P("Part", "ButtCap", "Cylinder", "", 0.1600, 0.2800, 0.2800, CFrame.new(0.0000,4.7400,0.0000,-0.000000,-1.000000,0.000000,1.000000,-0.000000,0.000000,0.000000,0.000000,1.000000), "Metal", 240, 214, 138, 0, true, nil, nil, nil)
	P("Part", "Ferrule", "Cylinder", "", 0.1300, 0.1500, 0.1500, CFrame.new(0.0000,2.2500,0.0000,-0.000000,-1.000000,0.000000,1.000000,-0.000000,0.000000,0.000000,0.000000,1.000000), "Metal", 198, 158, 78, 0, true, nil, nil, nil)
	P("Part", "Ferrule", "Cylinder", "", 0.1300, 0.1500, 0.1500, CFrame.new(0.0000,1.2500,0.0000,-0.000000,-1.000000,0.000000,1.000000,-0.000000,0.000000,0.000000,0.000000,1.000000), "Metal", 198, 158, 78, 0, true, nil, nil, nil)
	P("Part", "Ferrule", "Cylinder", "", 0.1300, 0.1500, 0.1500, CFrame.new(0.0000,3.2500,0.0000,-0.000000,-1.000000,0.000000,1.000000,-0.000000,0.000000,0.000000,0.000000,1.000000), "Metal", 198, 158, 78, 0, true, nil, nil, nil)
	P("Part", "FishMark", "Block", "", 0.0300, 0.0600, 0.1100, CFrame.new(0.1100,3.8039,0.1797,1.000000,0.000000,0.000000,0.000000,-0.500000,-0.866025,0.000000,0.866025,-0.500000), "Metal", 148, 110, 44, 0, true, nil, nil, nil)
	P("Part", "FishMark", "Block", "", 0.0300, 0.0600, 0.1100, CFrame.new(0.1100,3.7000,0.3594,1.000000,0.000000,0.000000,0.000000,1.000000,0.000000,0.000000,0.000000,1.000000), "Metal", 148, 110, 44, 0, true, nil, nil, nil)
	P("Part", "FishMark", "Block", "", 0.0300, 0.0600, 0.1100, CFrame.new(0.1100,3.5961,0.1797,1.000000,-0.000000,0.000000,0.000000,-0.500000,0.866025,0.000000,-0.866025,-0.500000), "Metal", 148, 110, 44, 0, true, nil, nil, nil)
	P("Part", "Guide", "Cylinder", "", 0.0350, 0.1500, 0.1500, CFrame.new(0.0000,1.6500,0.0898,-0.000000,-1.000000,0.000000,-0.000000,0.000000,-1.000000,1.000000,-0.000000,-0.000000), "Metal", 198, 158, 78, 0, true, nil, nil, nil)
	P("Part", "Guide", "Cylinder", "", 0.0350, 0.1500, 0.1500, CFrame.new(0.0000,2.6500,0.0898,-0.000000,-1.000000,0.000000,-0.000000,0.000000,-1.000000,1.000000,-0.000000,-0.000000), "Metal", 198, 158, 78, 0, true, nil, nil, nil)
	P("Part", "Guide", "Cylinder", "", 0.0350, 0.1500, 0.1500, CFrame.new(0.0000,0.7500,0.0898,-0.000000,-1.000000,0.000000,-0.000000,0.000000,-1.000000,1.000000,-0.000000,-0.000000), "Metal", 198, 158, 78, 0, true, nil, nil, nil)
	P("Part", "GuideFoot", "Block", "", 0.0300, 0.0300, 0.0900, CFrame.new(0.0000,1.6500,0.0449,1.000000,0.000000,0.000000,0.000000,1.000000,0.000000,0.000000,0.000000,1.000000), "Metal", 198, 158, 78, 0, true, nil, nil, nil)
	P("Part", "GuideFoot", "Block", "", 0.0300, 0.0300, 0.0900, CFrame.new(0.0000,2.6500,0.0449,1.000000,0.000000,0.000000,0.000000,1.000000,0.000000,0.000000,0.000000,1.000000), "Metal", 198, 158, 78, 0, true, nil, nil, nil)
	P("Part", "GuideFoot", "Block", "", 0.0300, 0.0300, 0.0900, CFrame.new(0.0000,0.7500,0.0449,1.000000,0.000000,0.000000,0.000000,1.000000,0.000000,0.000000,0.000000,1.000000), "Metal", 198, 158, 78, 0, true, nil, nil, nil)
	P("Part", "Handle", "Cylinder", "", 0.9200, 0.2300, 0.2300, CFrame.new(0.0000,4.2000,0.0000,-0.000000,-1.000000,0.000000,1.000000,-0.000000,0.000000,0.000000,0.000000,1.000000), "Wood", 152, 112, 70, 0, true, nil, nil, nil)
	P("Part", "HandleBandA", "Cylinder", "", 0.0900, 0.2600, 0.2600, CFrame.new(0.0000,3.7800,0.0000,-0.000000,-1.000000,0.000000,1.000000,-0.000000,0.000000,0.000000,0.000000,1.000000), "Metal", 198, 158, 78, 0, true, nil, nil, nil)
	P("Part", "HandleBandB", "Cylinder", "", 0.0900, 0.2600, 0.2600, CFrame.new(0.0000,4.6400,0.0000,-0.000000,-1.000000,0.000000,1.000000,-0.000000,0.000000,0.000000,0.000000,1.000000), "Metal", 198, 158, 78, 0, true, nil, nil, nil)
	P("Part", "HookBend", "Block", "", 0.0400, 0.0400, 0.1600, CFrame.new(0.0000,0.2700,0.2207,1.000000,0.000000,0.000000,0.000000,1.000000,0.000000,0.000000,0.000000,1.000000), "Metal", 240, 214, 138, 0, true, nil, nil, nil)
	P("Part", "HookPoint", "Block", "", 0.0400, 0.1800, 0.0400, CFrame.new(0.0000,0.3700,0.2891,1.000000,0.000000,0.000000,0.000000,1.000000,0.000000,0.000000,0.000000,1.000000), "Metal", 240, 214, 138, 0, true, nil, nil, nil)
	P("Part", "HookShank", "Block", "", 0.0400, 0.2600, 0.0400, CFrame.new(0.0000,0.4200,0.1602,1.000000,0.000000,0.000000,0.000000,1.000000,0.000000,0.000000,0.000000,1.000000), "Metal", 240, 214, 138, 0, true, nil, nil, nil)
	P("Part", "Line", "Block", "", 0.0220, 3.0000, 0.0220, CFrame.new(0.0000,2.0000,0.1309,1.000000,0.000000,0.000000,0.000000,1.000000,0.000000,0.000000,0.000000,1.000000), "SmoothPlastic", 232, 226, 200, 0, true, nil, nil, nil)
	P("Part", "Pole", "Cylinder", "", 3.2000, 0.1160, 0.1160, CFrame.new(0.0000,2.2000,0.0000,-0.000000,-1.000000,0.000000,1.000000,-0.000000,0.000000,0.000000,0.000000,1.000000), "Metal", 240, 214, 138, 0, true, nil, nil, nil)
	P("Part", "Reel", "Cylinder", "", 0.1400, 0.5400, 0.5400, CFrame.new(0.0000,3.7000,0.2402,1.000000,0.000000,0.000000,0.000000,1.000000,0.000000,0.000000,0.000000,1.000000), "Metal", 198, 158, 78, 0, true, nil, nil, nil)
	P("Part", "ReelArm", "Block", "", 0.2200, 0.0700, 0.0700, CFrame.new(0.2000,3.7000,0.3809,1.000000,0.000000,0.000000,0.000000,1.000000,0.000000,0.000000,0.000000,1.000000), "Metal", 240, 214, 138, 0, true, nil, nil, nil)
	P("Part", "ReelFace", "Cylinder", "", 0.1700, 0.4000, 0.4000, CFrame.new(0.0000,3.7000,0.2402,1.000000,0.000000,0.000000,0.000000,1.000000,0.000000,0.000000,0.000000,1.000000), "Metal", 240, 214, 138, 0, true, nil, nil, nil)
	P("Part", "ReelFoot", "Block", "", 0.1200, 0.1600, 0.1600, CFrame.new(0.0000,3.7000,0.1191,1.000000,0.000000,0.000000,0.000000,1.000000,0.000000,0.000000,0.000000,1.000000), "Metal", 198, 158, 78, 0, true, nil, nil, nil)
	P("Part", "ReelKnob", "Ball", "", 0.1300, 0.1300, 0.1300, CFrame.new(0.3000,3.7000,0.3809,1.000000,0.000000,0.000000,0.000000,1.000000,0.000000,0.000000,0.000000,1.000000), "Metal", 198, 158, 78, 0, true, nil, nil, nil)
	P("Part", "Root", "Block", "", 1.0000, 1.0000, 1.0000, CFrame.new(0.0000,0.0000,0.0000,1.000000,0.000000,0.000000,0.000000,1.000000,0.000000,0.000000,0.000000,1.000000), "Plastic", 163, 162, 165, 1, false, nil, nil, nil)
	P("Part", "Tip", "Cylinder", "", 0.7000, 0.0680, 0.0680, CFrame.new(0.0000,0.3500,0.0000,-0.000000,-1.000000,0.000000,1.000000,-0.000000,0.000000,0.000000,0.000000,1.000000), "Metal", 240, 214, 138, 0, true, nil, nil, nil)
	m.PrimaryPart = m:FindFirstChild("Root")
	m.WorldPivot = CFrame.new(0, 0, 0)
	return m
end
