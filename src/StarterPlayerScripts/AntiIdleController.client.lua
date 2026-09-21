-- AntiIdleController: keeps Roblox from disconnecting a player for standing still (error 278).
--
-- Roblox ships an idle timer of its own: twenty minutes with no input at all and the player is dropped,
-- whatever the game thinks about it. For most games that is sensible. For a roleplay game it is wrong --
-- sitting still IS the activity. Somebody sitting cross-legged in the tavern listening to two other people
-- talk is playing, and the server was throwing them out for it.
--
--------------------------------------------------------------------------------
-- ⚠️ สิ่งที่วัดได้จริงในเกมจริง (2026-09-21) — อ่านก่อนแก้อะไรในไฟล์นี้
--------------------------------------------------------------------------------
--
-- ผู้ใช้เปิด F9 ในเพลสหลักแล้วเจอ:
--
--   [AntiIdle] ทำงานแล้ว ... (เพลส 88774255487951)          ← ไฟล์อยู่ในบิลด์แล้ว
--   [AntiIdle] ปลอมอินพุตไม่สำเร็จ (Idled):
--       The current thread cannot call 'CaptureController' (lacking capability LocalUser)
--
-- **VirtualUser ทุกเมธอดเป็น LocalUserSecurity** (ตรวจกับ API reference แล้ว ทั้ง 13 ตัว รวม
-- `Button2Down`/`SetKeyDown`/`MoveMouse` — ไม่มีตัวไหนเป็นทางอ้อม) เธรดที่ไม่มี capability `LocalUser`
-- จึงเรียกไม่ได้สักตัว
--
-- **ข้อที่ยังไม่รู้ และไฟล์นี้ถูกเขียนขึ้นเพื่อตอบมัน:** ข้อความบอกว่า "**เธรดปัจจุบัน**เรียกไม่ได้" ไม่ใช่
-- "สคริปต์นี้เรียกไม่ได้" — และครั้งที่พังคือครั้งที่เรียกจาก **callback ของ `Player.Idled`** ซึ่งเป็นเธรดที่
-- เอนจินปลุกขึ้นมา ไม่ใช่เธรดของสคริปต์เอง เป็นไปได้ว่า capability หายไปเฉพาะเธรดนั้น
--
-- ไฟล์นี้จึง **ไม่เรียก VirtualUser จาก callback อีกแล้ว** ทุกการเรียกเกิดบนเธรดที่ `task.spawn` ออกมาจาก
-- ตัวสคริปต์ตอนบูตเธรดเดียว · `Idled` เหลือหน้าที่แค่ยกธงให้ลูปนั้นมาเก็บ
--
-- ถ้ารอบหน้ายังเจอ `ปลอมอินพุตไม่สำเร็จ (heartbeat)` = ทั้งสคริปต์ไม่มี capability นี้ ไม่ใช่แค่เธรด
-- **แปลว่าทางนี้ตายแล้ว ไม่มีทางอื่นในเอนจิน** เหลือแต่ป้ายเตือนข้างล่างซึ่งทำงานอยู่แล้ว
--------------------------------------------------------------------------------
--
-- คลิกขวา ไม่ใช่คลิกซ้าย: คลิกซ้ายคือการกดของจริงลงบนอะไรก็ตามที่อยู่ใต้เมาส์ ซึ่งตอนยืนอยู่กลางจัตุรัส
-- อาจเป็นปุ่มร้านค้าหรือผู้เล่นคนอื่น · ตรวจแล้วว่าเกมนี้ไม่ได้ผูกอะไรไว้กับปุ่มขวาเลย
--
-- Client-side because the idle timer is: the server never sees the input that would have reset it.
--
-- ⚠️ ไฟล์นี้คุ้มครองเฉพาะเพลสที่มันอยู่ เพลส `WOLD Farming` (เกาะลอยฟ้า) ยังไม่มีสคริปต์ไคลเอนต์เลย
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local VirtualUser = game:GetService("VirtualUser")

local player = Players.LocalPlayer

local KICK_AFTER = 1200 -- เพดานของ Roblox (วินาที) ไม่ใช่ของเรา ปรับไม่ได้
local NUDGE_AFTER = 120 -- เงียบเท่านี้แล้วปลอมอินพุตหนึ่งครั้ง — พลาดติดกันเก้ารอบก็ยังไม่ถึงเพดาน
local CHECK_EVERY = 5
local WARN_BEFORE = 300 -- เหลือเวลาเท่านี้ก่อนถูกเตะ ถึงจะขึ้นป้าย (เฉพาะตอนปลอมไม่ได้)
local LOG_FIRST = 3     -- พิมพ์การปลอมกี่ครั้งแรก แล้วเงียบ — สามบรรทัดพอพิสูจน์ ส่วนทุก 2 นาทีคือขยะ

local lastInput = os.clock()
local idledFlag = false
local fakeWorks = nil -- nil = ยังไม่เคยลอง · true/false = ผลครั้งล่าสุด
local nudges = 0
local warnedPath = {} -- เตือนทางละครั้ง ไม่ใช่ครั้งเดียวรวมทุกทาง ไม่งั้นทางที่สองจะเงียบหาย

--------------------------------------------------------------------------------
-- ป้ายเตือน: ตาข่ายรองรับสำหรับวันที่ปลอมอินพุตไม่ได้
--
-- ไม่ได้ช่วยคนที่ลุกไปทำอย่างอื่นจริงๆ แต่ช่วย **คนที่นั่งอ่านแชทอยู่** ซึ่งคือเคสที่ไฟล์นี้ถูกเขียนขึ้นมา
-- เพื่อเขาตั้งแต่แรก — เขาเห็นจอ แค่ไม่ได้แตะอะไร กดปุ่มเดียวก็รอด
--------------------------------------------------------------------------------
local warnGui, warnLabel

local function ensureWarnGui()
	if warnGui then return end
	warnGui = Instance.new("ScreenGui")
	warnGui.Name = "AntiIdleWarning"
	warnGui.ResetOnSpawn = false
	warnGui.IgnoreGuiInset = true
	warnGui.DisplayOrder = 900
	warnGui.Enabled = false
	warnGui.Parent = player:WaitForChild("PlayerGui")

	local frame = Instance.new("Frame")
	frame.AnchorPoint = Vector2.new(0.5, 0)
	frame.Position = UDim2.new(0.5, 0, 0.06, 0)
	frame.Size = UDim2.new(0.5, 0, 0, 56)
	frame.BackgroundColor3 = Color3.fromRGB(28, 22, 16)
	frame.BackgroundTransparency = 0.15
	frame.BorderSizePixel = 0
	frame.Parent = warnGui
	Instance.new("UICorner").Parent = frame
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(214, 164, 72)
	stroke.Thickness = 2
	stroke.Parent = frame

	warnLabel = Instance.new("TextLabel")
	warnLabel.Size = UDim2.new(1, -24, 1, 0)
	warnLabel.Position = UDim2.new(0, 12, 0, 0)
	warnLabel.BackgroundTransparency = 1
	warnLabel.Font = Enum.Font.GothamMedium
	warnLabel.TextScaled = true
	warnLabel.TextColor3 = Color3.fromRGB(246, 226, 186)
	warnLabel.Text = ""
	warnLabel.Parent = frame
end

local function showWarning(secondsLeft)
	ensureWarnGui()
	warnLabel.Text = ("ขยับเมาส์หรือกดปุ่มอะไรก็ได้ — อีก %d นาทีระบบของ Roblox จะตัดการเชื่อมต่อเพราะอยู่นิ่ง")
		:format(math.max(1, math.ceil(secondsLeft / 60)))
	warnGui.Enabled = true
end

local function hideWarning()
	if warnGui then warnGui.Enabled = false end
end

--------------------------------------------------------------------------------

-- **เรียกจากเธรดของลูปเท่านั้น** อย่าเรียกจาก callback ของ event ดูเหตุผลที่หัวไฟล์
local function nudge(reason)
	local quietFor = os.clock() - lastInput -- วัดก่อนรีเซ็ต ไม่งั้นได้ศูนย์ทุกครั้ง

	-- pcall เพราะ VirtualUser เป็น LocalUserSecurity ทั้งบริการ — ถ้าเรียกไม่ได้ ลูปต้องไม่ตายไปด้วย
	local ok, err = pcall(function()
		-- CaptureController first, or the click has no controller to come from and is ignored.
		VirtualUser:CaptureController()
		VirtualUser:ClickButton2(Vector2.new())
	end)

	fakeWorks = ok
	if ok then
		lastInput = os.clock()
		hideWarning()
		nudges += 1
		if nudges <= LOG_FIRST then
			print(("[AntiIdle] ปลอมอินพุตครั้งที่ %d (%s) — เงียบมา %d วินาที")
				:format(nudges, reason, math.floor(quietFor)))
		end
	elseif not warnedPath[reason] then
		warnedPath[reason] = true
		warn(("[AntiIdle] ปลอมอินพุตไม่สำเร็จ (%s): %s"):format(reason, tostring(err)))
	end
end

-- อินพุตจริงทุกชนิดรีเซ็ตนาฬิกาของเรา — `InputChanged` ครอบเมาส์ขยับกับจอยแพดด้วย
local function sawInput()
	lastInput = os.clock()
	hideWarning()
end
UserInputService.InputBegan:Connect(sawInput)
UserInputService.InputChanged:Connect(sawInput)

-- ชั้นที่ 1: สัญญาณจาก Roblox เอง — **ยกธงอย่างเดียว ไม่เรียก VirtualUser ตรงนี้**
player.Idled:Connect(function() idledFlag = true end)

-- ชั้นที่ 2: ลูปที่ถามใหม่เรื่อยๆ และเป็นเธรดเดียวที่ได้แตะ VirtualUser
task.spawn(function()
	while true do
		task.wait(CHECK_EVERY)
		local quiet = os.clock() - lastInput
		local wanted = idledFlag and "Idled" or (quiet >= NUDGE_AFTER and "heartbeat" or nil)
		idledFlag = false

		if wanted then nudge(wanted) end

		-- ปลอมไม่ได้ = เตือนด้วยตา · เวลาที่เหลือคิดจากนาฬิกาของเราเอง ซึ่งเริ่มนับพร้อมกับของ Roblox
		if fakeWorks == false then
			local left = KICK_AFTER - (os.clock() - lastInput)
			if left <= WARN_BEFORE then showWarning(left) else hideWarning() end
		end
	end
end)

--------------------------------------------------------------------------------
-- ตัวแยกโรค: VirtualUser ตัวเดียวที่โดน หรือ capability `LocalUser` หายไปทั้งยวง
--
-- `game:GetEngineFeature` เป็นอีก API ที่ต้องใช้ capability เดียวกัน และ **ไม่เกี่ยวกับ VirtualUser เลย**
-- ถ้ามันพังด้วย = เธรดนี้ไม่มี `LocalUser` เลยสักนิด ซึ่งเป็นอาการเดียวกับบั๊กที่ Roblox เคยแก้ไปเมื่อ
-- 2026-04 (devforum: "lacking capability LocalUser" กับ GetEngineFeature) → เป็นเรื่องฝั่งแพลตฟอร์ม
-- ถ้ามันผ่าน = `LocalUser` มีอยู่ แต่ VirtualUser ถูกปิดแยกต่างหาก → เป็นเรื่องนโยบายของ Roblox
--
-- พิมพ์ครั้งเดียวตอนบูต เอาไว้แปะรายงานบั๊กและเอาไว้ดูว่าวันไหน Roblox แก้ให้แล้ว
--------------------------------------------------------------------------------
do
	local RunService = game:GetService("RunService")

	-- คืน "ผ่าน" / "ไม่มีสิทธิ์" / "พังด้วยเหตุอื่น" — **ต้องแยกสามทาง ไม่ใช่สองทาง** ชื่อฟีเจอร์ที่ไม่มีอยู่จริง
	-- ก็ error เหมือนกัน ถ้านับรวมเป็น "ไม่ผ่าน" จะอ่านผลผิดทั้งหมด
	local function tryCall(fn)
		local ok, err = pcall(fn)
		if ok then return "ผ่าน" end
		err = tostring(err)
		if err:find("lacking capability", 1, true) then return "ไม่มีสิทธิ์" end
		return "พังด้วยเหตุอื่น (" .. err:sub(1, 60) .. ")"
	end

	local clientVersion = "?"
	pcall(function() clientVersion = version() end)

	print(("[AntiIdle] ตรวจสิทธิ์: GetEngineFeature=%s · VirtualUser.MoveMouse=%s · Studio=%s · ไคลเอนต์ %s")
		:format(
			tryCall(function() return game:GetEngineFeature("AnimatorLuau") end),
			tryCall(function() return VirtualUser:MoveMouse(Vector2.new()) end),
			tostring(RunService:IsStudio()), clientVersion))
end

print(("[AntiIdle] ทำงานแล้ว — ปลอมอินพุตทุก %d วินาทีที่ไม่มีการกดจริง (เพลส %d)")
	:format(NUDGE_AFTER, game.PlaceId))
