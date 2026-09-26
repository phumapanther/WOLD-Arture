-- Navigation: computes a walkable path to a waypoint and draws it on the ground.
--
-- Client-side by design. The path is a hint to the player, not a fact about the world -- nothing about it
-- needs the server's authority, and computing it locally keeps every player's route their own without a
-- round trip on every step.
--
-- Uses PathfindingService directly rather than a module: the whole of what a module like SimplePath adds
-- is agent movement (making an NPC walk the path), and here the player does the walking. What is left is
-- CreatePath, ComputeAsync, GetWaypoints -- three calls, wrapped once.
local PathfindingService = game:GetService("PathfindingService")
local Players = game:GetService("Players")
local NavigationConfig = require(script.Parent.NavigationConfig)

local Navigation = {}
Navigation.__index = Navigation

function Navigation.new()
	local self = setmetatable({}, Navigation)
	self.destination = nil -- Vector3 | nil
	self.label = nil
	self.markers = nil -- Folder holding the trail, or nil
	self.lastComputeAt = 0
	self.lastComputeFrom = nil
	self.onChanged = nil
	return self
end

--------------------------------------------------------------------------------
-- Drawing
--------------------------------------------------------------------------------

local function clearFolder(self)
	if self.markers then
		self.markers:Destroy()
		self.markers = nil
	end
end

local function marker(parent, position, size, color, transparency)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Material = Enum.Material.Neon
	p.Color = color
	p.Size = size
	p.Position = position
	p.Parent = parent
	return p
end

-- Lays the trail out along the computed waypoints. Drawn locally, so it exists only for this player.
function Navigation:draw(waypoints)
	clearFolder(self)
	if not waypoints or #waypoints == 0 then return end

	local folder = Instance.new("Folder")
	folder.Name = "WOLD_NavTrail"
	folder.Parent = workspace.CurrentCamera -- under the camera: never replicated, never saved with the place
	self.markers = folder

	local step = math.max(1, NavigationConfig.MarkerSpacing)
	local drawn = 0
	for i = 1, #waypoints, step do
		if drawn >= NavigationConfig.MaxMarkers then break end
		local point = waypoints[i]
		local dot = marker(folder, point.Position + Vector3.new(0, NavigationConfig.MarkerHeight, 0),
			NavigationConfig.MarkerSize, NavigationConfig.MarkerColor, 0)
		-- Fade the far end of the trail, so the eye follows it outward rather than reading it as a fence.
		dot.Transparency = math.min(0.75, (i / #waypoints) * 0.7)
		-- A jump waypoint is worth calling out: the route is not walkable without it.
		if point.Action == Enum.PathWaypointAction.Jump then
			dot.Color = Color3.fromRGB(232, 190, 84)
			dot.Size = NavigationConfig.MarkerSize * 1.4
		end
		drawn += 1
	end

	-- The destination itself, tall enough to see over a hill.
	if self.destination then
		local pin = marker(folder, self.destination + Vector3.new(0, NavigationConfig.PinHeight / 2, 0),
			Vector3.new(0.6, NavigationConfig.PinHeight, 0.6), NavigationConfig.PinColor, 0)
		pin.Transparency = 0.25
		local light = Instance.new("PointLight")
		light.Color = NavigationConfig.PinColor
		light.Range = 24
		light.Brightness = 2
		light.Parent = pin
	end
end

--------------------------------------------------------------------------------
-- Pathfinding
--------------------------------------------------------------------------------

local function characterPosition()
	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return root and root.Position or nil
end

-- Recomputes the route from where the player is now. Returns false plus a reason when there is no path,
-- which the caller shows rather than leaving the player staring at nothing.
function Navigation:compute()
	if not self.destination then return false, "ยังไม่ได้ปักหมุด" end
	local from = characterPosition()
	if not from then return false, "ตัวละครยังไม่พร้อม" end

	if (self.destination - from).Magnitude > NavigationConfig.MaxPathStuds then
		return false, "จุดหมายอยู่ไกลเกินไป"
	end

	-- Refuse water outright. Walking the route in legs means the first leg succeeds even when the final
	-- destination is out at sea, so the destination itself has to be checked rather than trusting the path.
	local MapTerrain = require(script.Parent.MapTerrain)
	if MapTerrain.At(self.destination.X, self.destination.Z) == MapTerrain.Water then
		return false, "ไปถึงจุดนั้นไม่ได้ (อยู่ในน้ำ)"
	end

	-- Aim at a point within navmesh range rather than at the destination itself. Roblox only meshes terrain
	-- it has streamed in, so a far target reports NoPath no matter how the agent is configured; walking the
	-- route in legs is what makes cross-map navigation work at all.
	local toward = self.destination - from
	local target = self.destination
	if toward.Magnitude > NavigationConfig.MaxLegStuds then
		local step = from + toward.Unit * NavigationConfig.MaxLegStuds
		-- Put the leg s end on the ground, or the path aims at a point in mid-air.
		local hit = workspace:Raycast(Vector3.new(step.X, step.Y + 600, step.Z),
			Vector3.new(0, -2000, 0))
		target = hit and hit.Position or step
	end
	self.legTarget = target

	-- จดเวลา/จุดของ "ความพยายาม" ไม่ใช่แค่ของรอบที่สำเร็จ — เดิมหาไม่เจอแล้วไม่จด ลูปวินาทีละรอบจึงคำนวณ
	-- ComputeAsync ซ้ำทุกวินาทีตลอดที่ไปไม่ถึง (มือถือสตรีมแมพน้อยกว่า เจอ NoPath บ่อยกว่า) QA 2026-09-26
	self.lastComputeAt = os.clock()
	self.lastComputeFrom = from

	local path = PathfindingService:CreatePath(NavigationConfig.AgentParams)
	local ok, err = pcall(function()
		path:ComputeAsync(from, target)
	end)
	if not ok then
		return false, "คำนวณเส้นทางไม่สำเร็จ"
	end
	if path.Status ~= Enum.PathStatus.Success then
		-- A partial path is still worth drawing: it walks the player as far as the mesh reaches, which is
		-- usually to the edge of whatever is blocking them.
		if path.Status ~= Enum.PathStatus.ClosestNoPath then
			return false, "ไปถึงจุดนั้นไม่ได้"
		end
	end

	local waypoints = path:GetWaypoints()
	if #waypoints == 0 then return false, "ไม่พบเส้นทาง" end

	self:draw(waypoints)
	self.lastComputeAt = os.clock()
	self.lastComputeFrom = from
	return true, ("%d จุด"):format(#waypoints)
end

--------------------------------------------------------------------------------
-- Public
--------------------------------------------------------------------------------

function Navigation:SetDestination(position, label)
	self.destination = position
	self.label = label
	if not position then
		clearFolder(self)
		if self.onChanged then self.onChanged(nil) end
		return true
	end
	local ok, message = self:compute()
	if not ok then
		clearFolder(self)
		self.destination = nil
		self.label = nil
	end
	if self.onChanged then self.onChanged(self.destination and label or nil) end
	return ok, message
end

function Navigation:Clear()
	return self:SetDestination(nil)
end

function Navigation:HasDestination()
	return self.destination ~= nil
end

-- How far the player still has to go, in studs, or nil when there is no destination.
function Navigation:DistanceRemaining()
	if not self.destination then return nil end
	local from = characterPosition()
	if not from then return nil end
	return (self.destination - from).Magnitude
end

-- Called on a timer while a destination is set: recomputes when the path has gone stale, and clears itself
-- on arrival so the trail does not linger over the player's head.
function Navigation:Update()
	if not self.destination then return end
	local from = characterPosition()
	if not from then return end

	local distance = (self.destination - from).Magnitude
	if distance <= NavigationConfig.ArriveDistance then
		local label = self.label
		self:Clear()
		return "arrived", label
	end

	local moved = self.lastComputeFrom and (from - self.lastComputeFrom).Magnitude or math.huge
	-- Also recompute when the current leg is nearly finished, which is what carries a long route forward.
	local legLeft = self.legTarget and (self.legTarget - from).Magnitude or math.huge
	-- ตัวจับเวลาทำงานเฉพาะตอนกำลังเดิน: ยืนนิ่งเส้นทางไม่เปลี่ยน การคำนวณใหม่ + วาดเส้น ~220 ชิ้นใหม่ทุก 4 วิ
	-- คือภาระเปล่าๆ ของมือถือ
	if (os.clock() - self.lastComputeAt >= NavigationConfig.RecomputeSeconds and moved >= 4)
		or moved >= NavigationConfig.RecomputeDistance
		or legLeft <= NavigationConfig.ArriveDistance * 4 then
		self:compute()
	end
	return "travelling", distance
end

return Navigation
