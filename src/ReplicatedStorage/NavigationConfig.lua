-- NavigationConfig: the numbers behind waypoints and the trail that leads to them.
local NavigationConfig = {}

-- How the path is computed. These go straight to PathfindingService:CreatePath, and describe the character
-- rather than the world: a path is only walkable if it assumes the right body.
NavigationConfig.AgentParams = {
	AgentRadius = 2.5,
	AgentHeight = 5,
	AgentCanJump = true,
	AgentCanClimb = false,
	-- Water is passable but slow, and the world has a river through the middle of it; without this the
	-- path refuses to cross and reports failure on perfectly reachable places.
	Costs = {
		Water = 20,
		Sand = 1,
		Grass = 1,
		LeafyGrass = 1.2,
		Rock = 1.5,
		Snow = 3,
	},
}

-- The trail. Markers rather than a Beam: a beam between two points cuts through hills, while a marker per
-- waypoint sits on the ground and shows the actual route.
NavigationConfig.MarkerSpacing = 1 -- draw every Nth waypoint; 1 is every one
NavigationConfig.MarkerSize = Vector3.new(1.6, 0.12, 1.6)
NavigationConfig.MarkerColor = Color3.fromRGB(126, 214, 232)
NavigationConfig.MarkerHeight = 0.6 -- studs above the waypoint, so it lies on the ground not in it
NavigationConfig.MaxMarkers = 220 -- a very long path would otherwise fill the world with parts

-- How close counts as arrived.
NavigationConfig.ArriveDistance = 12

-- Paths go stale as the player moves; recompute occasionally rather than every frame.
NavigationConfig.RecomputeSeconds = 4
NavigationConfig.RecomputeDistance = 60 -- ...or sooner if they have moved this far since the last one

-- How far a single path may reach. Roblox only builds its navmesh over streamed-in terrain, so anything
-- past the streaming radius reports NoPath however the agent is configured (measured on this world: 1000
-- studs succeeds, 1200 fails, at every setting). A far destination is therefore walked in legs: each path
-- aims at a point this far along the straight line toward it, and the next leg is computed on arrival.
NavigationConfig.MaxLegStuds = 900

-- A destination further than this is refused outright rather than walked in a hundred legs.
NavigationConfig.MaxPathStuds = 14000

-- The floating marker over the destination, so it is findable without the map open.
NavigationConfig.PinHeight = 8
NavigationConfig.PinColor = Color3.fromRGB(226, 96, 84)

return NavigationConfig
