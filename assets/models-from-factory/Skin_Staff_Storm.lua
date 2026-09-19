-- Skin_Staff_Storm — exported from WOLD-Models on 2026-09-18 (25 parts)
-- self-contained: no modelkit needed. Returns the Model, unparented.
--   local m = require(script.Skin_Staff_Storm)()   -- or paste this file's body into a build step
-- local space: base on y = 0, centred on x/z, front = -Z.
return function()
	local m = Instance.new("Model")
	m.Name = "Skin_Staff_Storm"
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
	P("Part", "Binding", "Cylinder", "", 0.4200, 0.2600, 0.2600, CFrame.new(0.0000,3.7000,0.0000,-0.000000,-1.000000,0.000000,1.000000,-0.000000,0.000000,0.000000,0.000000,1.000000), "Fabric", 72, 50, 36, 0, true, nil, nil, nil)
	P("Part", "Bolt1", "Block", "", 0.0900, 0.4400, 0.0900, CFrame.new(0.5200,4.9000,0.0000,0.898794,-0.438371,0.000000,0.438371,0.898794,0.000000,0.000000,0.000000,1.000000), "Neon", 96, 200, 255, 0, true, nil, nil, nil)
	P("Part", "Bolt1", "Block", "", 0.0900, 0.4400, 0.0900, CFrame.new(-0.5200,4.9000,0.0000,0.898794,0.438371,0.000000,-0.438371,0.898794,0.000000,0.000000,0.000000,1.000000), "Neon", 96, 200, 255, 0, true, nil, nil, nil)
	P("Part", "Bolt2", "Block", "", 0.0900, 0.4000, 0.0900, CFrame.new(-0.7000,4.5600,0.0000,0.848048,-0.529919,0.000000,0.529919,0.848048,0.000000,0.000000,0.000000,1.000000), "Neon", 96, 200, 255, 0, true, nil, nil, nil)
	P("Part", "Bolt2", "Block", "", 0.0900, 0.4000, 0.0900, CFrame.new(0.7000,4.5600,0.0000,0.848048,0.529919,0.000000,-0.529919,0.848048,0.000000,0.000000,0.000000,1.000000), "Neon", 96, 200, 255, 0, true, nil, nil, nil)
	P("Part", "Bolt3", "Block", "", 0.0900, 0.4000, 0.0900, CFrame.new(0.0000,5.0000,0.5195,1.000000,0.000000,0.000000,0.000000,0.898794,-0.438371,0.000000,0.438371,0.898794), "Neon", 96, 200, 255, 0, true, nil, nil, nil)
	P("Part", "Bolt3", "Block", "", 0.0900, 0.4000, 0.0900, CFrame.new(0.0000,5.0000,-0.5195,1.000000,0.000000,0.000000,0.000000,0.898794,0.438371,0.000000,-0.438371,0.898794), "Neon", 96, 200, 255, 0, true, nil, nil, nil)
	P("Part", "Claw0", "Block", "", 0.0800, 0.5400, 0.0900, CFrame.new(0.0000,4.3400,0.1602,1.000000,0.000000,0.000000,0.000000,0.961262,0.275637,0.000000,-0.275637,0.961262), "Slate", 66, 64, 70, 0, true, nil, nil, nil)
	P("Part", "Claw120", "Block", "", 0.0800, 0.5400, 0.0900, CFrame.new(0.1386,4.3400,-0.0801,-0.500000,-0.238709,0.832477,0.000000,0.961262,0.275637,-0.866025,0.137819,-0.480631), "Slate", 66, 64, 70, 0, true, nil, nil, nil)
	P("Part", "Claw240", "Block", "", 0.0800, 0.5400, 0.0900, CFrame.new(-0.1386,4.3400,-0.0801,-0.500000,0.238709,-0.832477,0.000000,0.961262,0.275637,0.866025,0.137819,-0.480631), "Slate", 66, 64, 70, 0, true, nil, nil, nil)
	P("Part", "Cloud1", "Ball", "", 0.5600, 0.5600, 0.5600, CFrame.new(0.0000,5.2600,0.0000,1.000000,0.000000,0.000000,0.000000,1.000000,0.000000,0.000000,0.000000,1.000000), "SmoothPlastic", 226, 232, 242, 0, true, nil, nil, nil)
	P("Part", "Cloud2", "Ball", "", 0.4200, 0.4200, 0.4200, CFrame.new(0.2600,5.1800,0.1602,1.000000,0.000000,0.000000,0.000000,1.000000,0.000000,0.000000,0.000000,1.000000), "SmoothPlastic", 226, 232, 242, 0, true, nil, nil, nil)
	P("Part", "Cloud3", "Ball", "", 0.3800, 0.3800, 0.3800, CFrame.new(-0.2400,5.1600,-0.1406,1.000000,0.000000,0.000000,0.000000,1.000000,0.000000,0.000000,0.000000,1.000000), "SmoothPlastic", 226, 232, 242, 0, true, nil, nil, nil)
	P("Part", "Crystal", "Block", "", 0.3400, 0.5600, 0.3400, CFrame.new(0.0000,4.7400,0.0000,0.707107,0.000000,0.707107,0.000000,1.000000,0.000000,-0.707107,0.000000,0.707107), "Neon", 70, 170, 245, 0, true, {96,200,255,10.00,1.80}, nil, nil)
	P("Part", "Ferrule", "Cylinder", "", 0.3200, 0.2400, 0.2400, CFrame.new(0.0000,0.4000,0.0000,-0.000000,-1.000000,0.000000,1.000000,-0.000000,0.000000,0.000000,0.000000,1.000000), "Metal", 130, 134, 142, 0, true, nil, nil, nil)
	P("Part", "Root", "Block", "", 1.0000, 1.0000, 1.0000, CFrame.new(0.0000,0.0000,0.0000,1.000000,0.000000,0.000000,0.000000,1.000000,0.000000,0.000000,0.000000,1.000000), "Plastic", 163, 162, 165, 1, false, nil, nil, nil)
	P("Part", "Shaft", "Cylinder", "", 4.0000, 0.2000, 0.2000, CFrame.new(0.0000,2.4000,0.0000,-0.000000,-1.000000,0.000000,1.000000,-0.000000,0.000000,0.000000,0.000000,1.000000), "Slate", 104, 100, 106, 0, true, nil, nil, nil)
	P("Part", "Twist0", "Block", "", 0.2400, 0.1000, 0.0900, CFrame.new(0.0000,0.7000,0.0000,1.000000,0.000000,0.000000,0.000000,0.913545,-0.406737,0.000000,0.406737,0.913545), "Slate", 66, 64, 70, 0, true, nil, nil, nil)
	P("Part", "Twist1", "Block", "", 0.2400, 0.1000, 0.0900, CFrame.new(0.0000,1.1400,0.0000,0.766044,0.261445,0.587216,0.000000,0.913545,-0.406737,-0.642788,0.311578,0.699816), "Slate", 66, 64, 70, 0, true, nil, nil, nil)
	P("Part", "Twist2", "Block", "", 0.2400, 0.1000, 0.0900, CFrame.new(0.0000,1.5800,0.0000,0.173648,0.400557,0.899667,0.000000,0.913545,-0.406737,-0.984808,0.070629,0.158636), "Slate", 66, 64, 70, 0, true, nil, nil, nil)
	P("Part", "Twist3", "Block", "", 0.2400, 0.1000, 0.0900, CFrame.new(0.0000,2.0200,0.0000,-0.500000,0.352244,0.791154,0.000000,0.913545,-0.406737,-0.866025,-0.203368,-0.456773), "Slate", 66, 64, 70, 0, true, nil, nil, nil)
	P("Part", "Twist4", "Block", "", 0.2400, 0.1000, 0.0900, CFrame.new(0.0000,2.4600,0.0000,-0.939693,0.139112,0.312451,0.000000,0.913545,-0.406737,-0.342020,-0.382207,-0.858452), "Slate", 66, 64, 70, 0, true, nil, nil, nil)
	P("Part", "Twist5", "Block", "", 0.2400, 0.1000, 0.0900, CFrame.new(0.0000,2.9000,0.0000,-0.939693,-0.139112,-0.312451,0.000000,0.913545,-0.406737,0.342020,-0.382207,-0.858452), "Slate", 66, 64, 70, 0, true, nil, nil, nil)
	P("Part", "Twist6", "Block", "", 0.2400, 0.1000, 0.0900, CFrame.new(0.0000,3.3400,0.0000,-0.500000,-0.352244,-0.791154,0.000000,0.913545,-0.406737,0.866025,-0.203368,-0.456773), "Slate", 66, 64, 70, 0, true, nil, nil, nil)
	P("Part", "Twist7", "Block", "", 0.2400, 0.1000, 0.0900, CFrame.new(0.0000,3.7800,0.0000,0.173648,-0.400557,-0.899667,0.000000,0.913545,-0.406737,0.984808,0.070629,0.158635), "Slate", 66, 64, 70, 0, true, nil, nil, nil)
	m.PrimaryPart = m:FindFirstChild("Root")
	m.WorldPivot = CFrame.new(0, 0, 0)
	return m
end
