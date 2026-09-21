-- AntiIdleController: keeps Roblox from disconnecting a player for standing still (error 278).
--
-- Roblox ships an idle timer of its own: about twenty minutes with no input at all and the player is
-- dropped, whatever the game thinks about it. For most games that is sensible. For a roleplay game it is
-- wrong -- sitting still IS the activity. Somebody sitting cross-legged in the tavern listening to two other
-- people talk is playing, and the server was throwing them out for it.
--
-- HOW IT IS SWITCHED OFF
--
-- The timer cannot be configured, but it can be answered: any real input resets it, and VirtualUser can
-- supply that input on the player's behalf.
--
-- **สองชั้น ไม่ใช่ชั้นเดียว** (2026-09-21 — ผู้ใช้โดนเตะจริงทั้งที่ไฟล์นี้มีอยู่แล้ว)
--
--   ชั้นที่ 1  `Player.Idled` — สัญญาณตรงจาก Roblox ว่ากำลังจะเตะ ของเดิมมีแค่ชั้นนี้
--   ชั้นที่ 2  นาฬิกาของเราเอง — ไม่มีอินพุตจริงเกิน `NUDGE_AFTER` วินาที ก็ปลอมให้เลย ไม่ต้องรอใครบอก
--
-- ที่ต้องมีชั้นที่สองเพราะ **ชั้นแรกพึ่งสัญญาณที่เราไม่ได้เป็นคนยิง** ถ้ามันไม่มา หรือมาช้ากว่าที่เซิร์ฟเวอร์
-- ตัดสินใจ ก็ไม่มีอะไรมาปลุกอีกเลย — เป็นรูปแบบเดียวกับกฎเหล็กเรื่อง StreamingEnabled ในคู่มือนี้:
-- **ลูปที่ถามใหม่เรื่อยๆ ไม่มีจังหวะให้แพ้** ส่วนตัวที่ผูกกับเหตุการณ์ครั้งเดียวมีเสมอ
--
-- สองนาทีคือเลขที่เลือกให้ "ถี่พอจะไม่มีวันไปถึง 20 นาที แม้พลาดไปติดๆ กันหลายรอบ" โดยไม่ได้ยิงถี่จนเปลือง
--
-- คลิกขวา ไม่ใช่คลิกซ้าย: คลิกซ้ายคือการกดของจริงลงบนอะไรก็ตามที่อยู่ใต้เมาส์ ซึ่งตอนยืนอยู่กลางจัตุรัส
-- อาจเป็นปุ่มร้านค้าหรือผู้เล่นคนอื่น · ตรวจแล้วว่าเกมนี้ **ไม่ได้ผูกอะไรไว้กับปุ่มขวาเลย** (ไม่มี
-- `MouseButton2` ในสคริปต์ไคลเอนต์สักไฟล์) มันจึงเป็นอินพุตที่ไม่ทำอะไรนอกจากถูกนาฬิกาของ Roblox มองเห็น
--
-- หมายเหตุ: นี่เป็นวิธีมาตรฐานที่เกมที่เผยแพร่แล้วจำนวนมากใช้กัน แต่ Roblox เขียนคู่มือ VirtualUser ไว้
-- สำหรับการทดสอบอัตโนมัติ ไม่ใช่เรื่องนี้ — ที่นี่ไม่มีการปลอมการเล่นเกม มีแต่คลิกที่ไม่ทำอะไรเลย
--
-- Client-side because the idle timer is: the server never sees the input that would have reset it.
--
-- ⚠️ **ไฟล์นี้คุ้มครองเฉพาะเพลสที่มันอยู่** เพลส `WOLD Farming` (เกาะลอยฟ้า 136992335889132) ยังไม่มี
-- สคริปต์ฝั่งไคลเอนต์เลยสักไฟล์ ใครไปยืนนิ่งบนเกาะก็ยังโดนเตะอยู่ดี — ต้องก๊อบไฟล์นี้เข้าไปด้วย
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local VirtualUser = game:GetService("VirtualUser")

local player = Players.LocalPlayer

-- ไม่มีอินพุตจริงนานเท่านี้ (วินาที) = ปลอมให้หนึ่งครั้ง · เพดานของ Roblox คือ 1200 วินาที
local NUDGE_AFTER = 120
local CHECK_EVERY = 15

local lastInput = os.clock()
local warned = false

local function nudge(reason)
	-- pcall เพราะ VirtualUser เป็นบริการที่ปฏิเสธได้ตามบริบทที่เรียก — ถ้าวันหนึ่ง Roblox ปิดทางนี้
	-- ลูปต้องไม่ตายไปเงียบๆ พร้อมกัน ต้องมีเสียงให้เห็นใน F9 หนึ่งครั้ง
	local ok, err = pcall(function()
		-- CaptureController first, or the click has no controller to come from and is ignored.
		VirtualUser:CaptureController()
		VirtualUser:ClickButton2(Vector2.new())
	end)
	if ok then
		lastInput = os.clock()
	elseif not warned then
		warned = true
		warn(("[AntiIdle] ปลอมอินพุตไม่สำเร็จ (%s): %s — ผู้เล่นจะโดนเตะที่ 20 นาทีตามเดิม"):format(reason, tostring(err)))
	end
end

-- ชั้นที่ 1: สัญญาณจาก Roblox เอง
player.Idled:Connect(function() nudge("Idled") end)

-- อินพุตจริงทุกชนิดรีเซ็ตนาฬิกาของเรา — รวม `InputChanged` ซึ่งครอบเมาส์ขยับกับจอยแพด
UserInputService.InputBegan:Connect(function() lastInput = os.clock() end)
UserInputService.InputChanged:Connect(function() lastInput = os.clock() end)

-- ชั้นที่ 2: ลูปที่ถามใหม่เรื่อยๆ
task.spawn(function()
	while true do
		task.wait(CHECK_EVERY)
		if os.clock() - lastInput >= NUDGE_AFTER then
			nudge("heartbeat")
		end
	end
end)

print(("[AntiIdle] ทำงานแล้ว — ปลอมอินพุตทุก %d วินาทีที่ไม่มีการกดจริง (เพลส %d)")
	:format(NUDGE_AFTER, game.PlaceId))
