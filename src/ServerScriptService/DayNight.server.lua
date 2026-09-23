-- DayNight.server.lua: the world clock. Advances Lighting.ClockTime, which is what actually moves Roblox's
-- sun and moon across the sky, and drives the lighting through the keyframes in DayNightConfig so dawn and
-- dusk look like dawn and dusk rather than noon with the sun in a different place.
--
-- The clock is owned by the SERVER and replicated as a Workspace attribute, so every player sees the same
-- time of day. Lighting properties are set on the server too: they replicate to every client, which keeps a
-- single source of truth instead of each client running its own cycle and drifting apart.
local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")
local ServerConfig = require(game.ServerScriptService.ServerConfig)
-- **ล็อบบี้ไม่มีวงจรกลางวัน-กลางคืน** (2026-09-23) — มันเป็นห้องปิดลอยอยู่ที่ y=1000 ที่ผู้เล่นแวะ
-- ไม่กี่วินาที การปล่อยให้มันมืดสนิทตอนตีสองไม่ได้ให้บรรยากาศอะไร แค่ทำให้เมนูอ่านยาก
-- · `BuildLobbyRoom` ตั้งแสงคงที่ไว้แทน (ตั้งที่นั่นได้เพราะไม่มีใครมาเขียนทับแล้ว)
if ServerConfig.IsLobby then return end
local DayNightConfig = require(game.ReplicatedStorage.DayNightConfig)
local DayNightAccess = require(game.ServerScriptService.DayNightAccess)
local WeatherConfig = require(game.ReplicatedStorage.WeatherConfig)

Lighting.ClockTime = DayNightConfig.StartTime
-- Replicated so client code (and any later clock UI) can read the time without recomputing it.
workspace:SetAttribute("WOLD_ClockTime", Lighting.ClockTime)
workspace:SetAttribute("WOLD_IsNight", DayNightConfig.IsNight(Lighting.ClockTime))

-- Reused rather than found every frame.
local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")

-- The sun and moon rise and set on their own from ClockTime; GeographicLatitude tilts the arc they travel.
-- Measured: latitude 20 puts the noon sun at y=1.00, i.e. straight overhead, which leaves shadows pointing
-- nowhere. Roblox's own default keeps it slightly off vertical (y=0.95) so midday still casts a direction.
Lighting.GeographicLatitude = 41.7
Lighting.GlobalShadows = true

local HOURS_PER_SECOND = 24 / DayNightConfig.DayLengthSeconds

-- Applying every frame is wasteful and the change is invisible at that rate; a quarter second is smooth
-- enough for a 20-minute day and costs a fraction as much replication.
local APPLY_INTERVAL = 0.25
local sinceApply = 0

-- Set by Weather.server: returns (kindId, blend) for the sky right now, or nil while no weather runs. A
-- function rather than a require, so DayNight keeps no dependency on the weather system and works exactly
-- as before in a place that has none.
local weatherSource = nil
function DayNightAccess.SetWeatherSource(fn)
	weatherSource = fn
end

local function apply(clockTime)
	local s = DayNightConfig.Sample(clockTime)
	-- Weather sits ON TOP of the clock's own sample, every time, because this function rewrites Lighting
	-- four times a second -- anything that set the fog outside of here would be erased within a tick.
	if weatherSource then
		local kindId, blend = weatherSource()
		if kindId then
			WeatherConfig.Apply(s, kindId, blend)
		end
	end
	Lighting.Brightness = s.brightness
	Lighting.Ambient = s.ambient
	Lighting.OutdoorAmbient = s.outdoorAmbient
	Lighting.ColorShift_Top = s.colorShift
	Lighting.FogColor = s.fogColor
	-- **บนเกาะลอยฟ้าหมอกต้องไกลกว่ามาก** ค่าในคอนฟิก (900-4,000 studs) ตั้งไว้สำหรับแมพหลักซึ่งมี
	-- ภูเขาและป่าบังอยู่แล้ว · เกาะลอยกลางอากาศไม่มีอะไรบัง และเกาะประดับอยู่ที่ 760-1,900 studs
	-- คูณ 4 ได้ 3,600-16,000: เห็นเกาะประดับครบทุกวง แต่ยังเหลือหมอกบางๆ ให้วงนอกจางหายไปในฟ้า
	Lighting.FogEnd = ServerConfig.IsFarm and s.fogEnd * 4 or s.fogEnd
	if atmosphere then
		-- ⚠️ **`Atmosphere.Density` คือตัวที่วาดพื้นสีเทาใต้เส้นขอบฟ้า** (ผู้ใช้แจ้ง 2026-09-22)
		--
		-- เอนจินวาดหมอกพื้นดินให้ครึ่งล่างของท้องฟ้าเสมอ ซึ่งถูกต้องตอนยืนบนแผ่นดิน — แต่บนเกาะลอยฟ้า
		-- ครึ่งล่างคือ *ท้องฟ้า* ไม่ใช่พื้น มันจึงกลายเป็นผนังเทาทึบบังเกาะประดับทั้งหมด
		--
		-- **พิสูจน์แล้วว่าไม่ใช่หมอกและไม่ใช่ skybox**: ปิด FogEnd เป็น 100,000 แล้วยังเทาเหมือนเดิม ·
		-- เปลี่ยน skybox ทั้งใบแล้วแถบเทายังอยู่ที่ความสูงเดิมเป๊ะ · เอา Atmosphere ออก = หายทันที
		--
		-- 0.05 ไม่ใช่ 0 — เหลือไว้นิดหน่อยให้ระยะไกลยังมีมิติ ไม่ใช่ฉากแบนๆ
		atmosphere.Density = ServerConfig.IsFarm and 0.05 or s.atmosphereDensity
		atmosphere.Haze = ServerConfig.IsFarm and 0 or s.atmosphereHaze
		atmosphere.Color = s.atmosphereColor
	end

	workspace:SetAttribute("WOLD_ClockTime", clockTime)
	workspace:SetAttribute("WOLD_IsNight", DayNightConfig.IsNight(clockTime))
end

apply(Lighting.ClockTime)

-- An hour the clock has been pinned to, or nil while it runs normally. An admin setting the world to
-- "morning" means morning STAYS -- not that it starts at dawn and is dusk twenty minutes later -- so holding
-- has to stop the advance rather than just set the hour once.
local heldAt = nil

DayNightAccess.Hold = function(hour)
	heldAt = hour and (hour % 24) or nil
	if heldAt then
		Lighting.ClockTime = heldAt
		apply(heldAt)
	end
	return heldAt or Lighting.ClockTime
end

DayNightAccess.HeldAt = function()
	return heldAt
end

RunService.Heartbeat:Connect(function(dt)
	-- Still applied while held, not merely left alone: something else may have moved Lighting, and a held sky
	-- that quietly drifts back is worse than one that never held.
	if heldAt then
		sinceApply += dt
		if sinceApply >= APPLY_INTERVAL then
			sinceApply = 0
			Lighting.ClockTime = heldAt
			apply(heldAt)
		end
		return
	end

	Lighting.ClockTime = (Lighting.ClockTime + dt * HOURS_PER_SECOND) % 24

	sinceApply += dt
	if sinceApply >= APPLY_INTERVAL then
		sinceApply = 0
		apply(Lighting.ClockTime)
	end
end)
