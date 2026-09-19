-- Skin_Pistol_Brass — exported from WOLD-Models on 2026-09-18 (20 parts)
-- self-contained: no modelkit needed. Returns the Model, unparented.
--   local m = require(script.Skin_Pistol_Brass)()   -- or paste this file's body into a build step
-- local space: base on y = 0, centred on x/z, front = -Z.
return function()
	local m = Instance.new("Model")
	m.Name = "Skin_Pistol_Brass"
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
	P("Part", "Barrel", "Cylinder", "", 1.9000, 0.2100, 0.2100, CFrame.new(0.0000,1.4000,0.0000,-0.000000,-1.000000,0.000000,1.000000,-0.000000,0.000000,0.000000,0.000000,1.000000), "Metal", 206, 160, 66, 0, true, nil, nil, nil)
	P("Part", "BarrelBand", "Cylinder", "", 0.0900, 0.2500, 0.2500, CFrame.new(0.0000,0.8500,0.0000,-0.000000,-1.000000,0.000000,1.000000,-0.000000,0.000000,0.000000,0.000000,1.000000), "Metal", 206, 160, 66, 0, true, nil, nil, nil)
	P("Part", "BarrelBand", "Cylinder", "", 0.0900, 0.2500, 0.2500, CFrame.new(0.0000,1.5500,0.0000,-0.000000,-1.000000,0.000000,1.000000,-0.000000,0.000000,0.000000,0.000000,1.000000), "Metal", 206, 160, 66, 0, true, nil, nil, nil)
	P("Part", "ButtCap", "Block", "", 0.2900, 0.1600, 0.3600, CFrame.new(0.0000,3.8800,-0.3594,1.000000,0.000000,0.000000,0.000000,1.000000,0.000000,0.000000,0.000000,1.000000), "Metal", 206, 160, 66, 0, true, nil, nil, nil)
	P("Part", "Frizzen", "Block", "", 0.0600, 0.1600, 0.1600, CFrame.new(0.1000,2.4200,-0.2793,1.000000,0.000000,0.000000,0.000000,1.000000,0.000000,0.000000,0.000000,1.000000), "Metal", 206, 160, 66, 0, true, nil, nil, nil)
	P("Part", "FrontSight", "Block", "", 0.0500, 0.1000, 0.0700, CFrame.new(0.0000,0.6200,0.1309,1.000000,0.000000,0.000000,0.000000,1.000000,0.000000,0.000000,0.000000,1.000000), "Metal", 206, 160, 66, 0, true, nil, nil, nil)
	P("Part", "Grip", "Block", "", 0.2500, 0.9600, 0.3400, CFrame.new(0.0000,3.4000,-0.2207,1.000000,0.000000,0.000000,0.000000,0.951057,-0.309017,0.000000,0.309017,0.951057), "Wood", 116, 76, 46, 0, true, nil, nil, nil)
	P("Part", "GripMedal", "Ball", "", 0.1300, 0.1300, 0.1300, CFrame.new(0.0000,3.4200,-0.3809,1.000000,0.000000,0.000000,0.000000,1.000000,0.000000,0.000000,0.000000,1.000000), "Metal", 206, 160, 66, 0, true, nil, nil, nil)
	P("Part", "GuardBow", "Block", "", 0.0700, 0.4000, 0.0700, CFrame.new(0.0000,3.0200,-0.4199,1.000000,0.000000,0.000000,0.000000,1.000000,0.000000,0.000000,0.000000,1.000000), "Metal", 206, 160, 66, 0, true, nil, nil, nil)
	P("Part", "GuardFront", "Block", "", 0.0700, 0.0700, 0.2800, CFrame.new(0.0000,2.8200,-0.3008,1.000000,0.000000,0.000000,0.000000,1.000000,0.000000,0.000000,0.000000,1.000000), "Metal", 206, 160, 66, 0, true, nil, nil, nil)
	P("Part", "GuardRear", "Block", "", 0.0700, 0.0800, 0.2000, CFrame.new(0.0000,3.2200,-0.3594,1.000000,0.000000,0.000000,0.000000,1.000000,0.000000,0.000000,0.000000,1.000000), "Metal", 206, 160, 66, 0, true, nil, nil, nil)
	P("Part", "Hammer", "Block", "", 0.0700, 0.3400, 0.1400, CFrame.new(0.1000,2.5600,-0.2598,1.000000,0.000000,0.000000,0.000000,0.913545,-0.406737,0.000000,0.406737,0.913545), "Metal", 176, 182, 194, 0, true, nil, nil, nil)
	P("Part", "Lockplate", "Block", "", 0.0500, 0.4600, 0.2800, CFrame.new(0.1200,2.2800,-0.1406,1.000000,0.000000,0.000000,0.000000,1.000000,0.000000,0.000000,0.000000,1.000000), "Metal", 176, 182, 194, 0, true, nil, nil, nil)
	P("Part", "Muzzle", "Cylinder", "", 0.2000, 0.2700, 0.2700, CFrame.new(0.0000,0.4400,0.0000,-0.000000,-1.000000,0.000000,1.000000,-0.000000,0.000000,0.000000,0.000000,1.000000), "Metal", 176, 182, 194, 0, true, nil, nil, nil)
	P("Part", "Ramrod", "Cylinder", "", 1.2000, 0.0700, 0.0700, CFrame.new(0.0000,1.1000,0.1602,-0.000000,-1.000000,0.000000,1.000000,-0.000000,0.000000,0.000000,0.000000,1.000000), "Wood", 116, 76, 46, 0, true, nil, nil, nil)
	P("Part", "Root", "Block", "", 1.0000, 1.0000, 1.0000, CFrame.new(0.0000,0.0000,0.0000,1.000000,0.000000,0.000000,0.000000,1.000000,0.000000,0.000000,0.000000,1.000000), "Plastic", 163, 162, 165, 1, false, nil, nil, nil)
	P("Part", "SidePlate", "Block", "", 0.0500, 0.4200, 0.2600, CFrame.new(-0.1200,2.2800,-0.1406,1.000000,0.000000,0.000000,0.000000,1.000000,0.000000,0.000000,0.000000,1.000000), "Metal", 206, 160, 66, 0, true, nil, nil, nil)
	P("Part", "Stock", "Block", "", 0.2100, 0.8600, 0.3000, CFrame.new(0.0000,2.3200,-0.0801,1.000000,0.000000,0.000000,0.000000,1.000000,0.000000,0.000000,0.000000,1.000000), "Wood", 116, 76, 46, 0, true, nil, nil, nil)
	P("Part", "Tang", "Block", "", 0.1800, 0.4400, 0.2200, CFrame.new(0.0000,2.8600,-0.1309,1.000000,0.000000,0.000000,0.000000,1.000000,0.000000,0.000000,0.000000,1.000000), "Wood", 116, 76, 46, 0, true, nil, nil, nil)
	P("Part", "Trigger", "Block", "", 0.0600, 0.2400, 0.0900, CFrame.new(0.0000,2.9400,-0.2598,1.000000,0.000000,0.000000,0.000000,0.961262,-0.275637,0.000000,0.275637,0.961262), "Metal", 176, 182, 194, 0, true, nil, nil, nil)
	m.PrimaryPart = m:FindFirstChild("Root")
	m.WorldPivot = CFrame.new(0, 0, 0)
	return m
end
