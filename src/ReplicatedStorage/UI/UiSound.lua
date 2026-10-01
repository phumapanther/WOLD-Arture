-- UiSound: one-shot interface sounds.
--
-- A click, a notification, a ringtone. These are not positional -- they are things happening TO the player,
-- not in the world -- so they play from SoundService rather than from a part, at a flat volume with no
-- distance falloff.
--
-- Client-only. Calling this on the server would play nothing and cost a wasted instance.
local SoundService = game:GetService("SoundService")
local Debris = game:GetService("Debris")
local SoundscapeConfig = require(script.Parent.Parent.SoundscapeConfig)

local UiSound = {}

local Config = SoundscapeConfig.Interface
local TweenService = game:GetService("TweenService")

-- คลิปยาวถูกตัดตาม `Config.MaxSeconds` (ค่อยๆ เบาลงก่อนหยุด ไม่ใช่ตัดกึก) · QA 2026-09-28
local function limit(sound, name)
	local max = Config.MaxSeconds and Config.MaxSeconds[name]
	if type(max) ~= "number" then return end
	task.delay(math.max(0, max - 0.3), function()
		if sound.Parent then
			TweenService:Create(sound, TweenInfo.new(0.3), { Volume = 0 }):Play()
			Debris:AddItem(sound, 0.35)
		end
	end)
end

-- The level this one plays at: its own, if it has been given one, and the interface's common level otherwise.
-- Config.Volumes is itself a member of Config, so it would answer a Play("Volumes") -- harmlessly, since a
-- table is not a string id and Play bails on that.
local function volumeFor(name)
	local overrides = Config.Volumes
	local own = overrides and overrides[name]
	return type(own) == "number" and own or Config.Volume
end

-- Plays `name` from SoundscapeConfig.Interface once. An unknown or unset name is silently ignored, so a
-- caller naming a sound that does not exist yet is harmless rather than an error.
function UiSound.Play(name)
	local id = Config[name]
	if type(id) ~= "string" or id == "" then return end

	local sound = Instance.new("Sound")
	sound.SoundId = id
	sound.Volume = volumeFor(name)
	sound.Parent = SoundService
	sound:Play()
	-- ⚠️ เสียงที่ยังไม่เคยโหลด Play() แล้วเงียบ (เหตุผลเดียวกับ Loop ข้างล่าง) — ในเกมจอโหลดโหลดไว้ให้หมด
	-- แต่ล็อบบี้ไม่มีจอโหลด เสียงกดหาห้องจึงเงียบ (ผู้ใช้แจ้ง 2026-10-01) · มาช้าเกิน 3 วิ = ไม่เล่นแล้ว (เลยจังหวะ)
	if not sound.IsLoaded then
		local asked = os.clock()
		sound.Loaded:Once(function()
			if sound.Parent and not sound.IsPlaying and os.clock() - asked < 3 then sound:Play() end
		end)
	end
	-- Cleaned up after a generous margin rather than on Ended: a sound that never loads never fires Ended,
	-- and would sit in SoundService forever.
	Debris:AddItem(sound, 10)
	limit(sound, name)
	return sound
end

-- โหลดเสียงไว้ก่อนใช้ (ที่ที่ไม่มีจอโหลด เช่นล็อบบี้) · ชื่อจาก `SoundscapeConfig.Interface` · เรียกใน task.spawn
function UiSound.Preload(names)
	local sounds = {}
	for _, name in ipairs(names) do
		local id = Config[name]
		if type(id) == "string" and id ~= "" then
			local s = Instance.new("Sound")
			s.SoundId = id
			sounds[#sounds + 1] = s
		end
	end
	pcall(function() game:GetService("ContentProvider"):PreloadAsync(sounds) end)
end

-- เสียงในโลก: ได้ยินตามระยะ (กับดัก · แสงเลเวลขึ้นของคนอื่น) · `where` = Vector3 หรือ BasePart · ฝั่งไคลเอนต์
-- `volumeScale` คูณเสียงปกติ (ของคนอื่นเบากว่าของตัวเอง) · `maxDistance` ค่าเริ่มต้น 80 สตัด
function UiSound.PlayAt(name, where, volumeScale, maxDistance)
	local id = Config[name]
	if type(id) ~= "string" or id == "" or not where then return end
	local holder
	if typeof(where) == "Vector3" then
		holder = Instance.new("Part")
		holder.Anchored, holder.CanCollide, holder.CanQuery, holder.CanTouch = true, false, false, false
		holder.Transparency = 1
		holder.Size = Vector3.new(0.2, 0.2, 0.2)
		holder.Position = where
		holder.Parent = workspace
		Debris:AddItem(holder, 10)
	end
	local sound = Instance.new("Sound")
	sound.SoundId = id
	sound.Volume = volumeFor(name) * (volumeScale or 1) * 2 -- เสียงในโลกเบาลงตามระยะ ตั้งต้นดังกว่าเสียงหน้าจอ
	sound.RollOffMode = Enum.RollOffMode.InverseTapered
	sound.RollOffMinDistance = 8
	sound.RollOffMaxDistance = maxDistance or 80
	sound.Parent = holder or where
	sound:Play()
	Debris:AddItem(sound, 10)
	limit(sound, name)
	return sound
end

-- A looping sound that has to be stopped by hand, for the ringtone: it rings until the call is answered or
-- given up on, which this module cannot know. The caller keeps the returned Sound and destroys it.
function UiSound.Loop(name)
	local id = Config[name]
	if type(id) ~= "string" or id == "" then return nil end

	local sound = Instance.new("Sound")
	sound.SoundId = id
	sound.Volume = volumeFor(name)
	sound.Looped = true
	sound.Parent = SoundService
	sound:Play()

	-- Play() on a sound Roblox has not finished fetching does nothing, and there is no second attempt: the
	-- asset arrives a moment later and sits there silent. A one-shot can live with that, since it is over
	-- before anyone notices; a loop cannot, because the whole point is that it runs for a while.
	--
	-- So a loop that was not ready is started again when it becomes ready. Loaded already, this never fires.
	if not sound.IsLoaded then
		sound.Loaded:Once(function()
			-- Unless whoever asked for it has already stopped it -- a craft that finished during the fetch
			-- must not leave a loop running behind it.
			if sound.Parent and not sound.IsPlaying then
				sound:Play()
			end
		end)
	end

	return sound
end

return UiSound
