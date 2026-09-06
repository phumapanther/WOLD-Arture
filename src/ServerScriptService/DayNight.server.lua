-- DayNight: one full in-game day every 30 real minutes (15 min daylight 06:00-18:00, 15 min night).
-- Lighting.ClockTime drives the sun and moon; the default Sky provides moon and stars.
local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")

local DAY_LENGTH_SECONDS = 30 * 60           -- ponytail: tune here; 24 game hours per this many real seconds
local START_TIME = 8                          -- game starts in the morning

Lighting.ClockTime = START_TIME
RunService.Heartbeat:Connect(function(dt)
	Lighting.ClockTime = (Lighting.ClockTime + dt * 24 / DAY_LENGTH_SECONDS) % 24
end)
