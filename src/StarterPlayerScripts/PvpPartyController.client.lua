-- PvpPartyController: ต่อหน้าปาร์ตี้ของแท็บ PVP เข้ากับเซิร์ฟเวอร์ (ผู้ใช้ส่งภาพร่างมา 2026-09-23)
--
-- ทำงานเฉพาะในล็อบบี้ · หน้าจออยู่ใน `ChannelSelectGui` ซึ่ง `ChannelSelectController` เป็นคนสร้าง
--
-- ⚠️ **หน้าต่างสร้างช่องทางเอง ฝั่งนี้ไปหยิบตอนใช้** — กฎเดิมของโปรเจ็ค (บทเรียนปุ่มร้านพรีเมียม
-- ที่ `WaitForChild` หมดเวลาแล้วเงียบสนิท) · รอแบบลูปถามใหม่ ไม่ใช่ผูกครั้งเดียวแล้วหวังว่าทัน
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

while workspace:GetAttribute("IsLobby") == nil do task.wait(0.2) end
if workspace:GetAttribute("IsLobby") ~= true then return end

local Remotes = require(ReplicatedStorage.Remotes)
local player = Players.LocalPlayer

-- หน้าปาร์ตี้ตัวปัจจุบัน — **ไม่ใช่ตัวแรกที่เจอ** (บั๊กมือถือ 2026-09-26: สามช่องเป็น + ทั้งหมด กดเล่นไม่ได้)
-- `ChannelSelectController` สร้างหน้าจอล็อบบี้ใหม่ทั้งชุดทุกครั้งที่จอพลิกแนวตั้ง↔แนวนอน (มันบังคับ LandscapeSensor
-- โทรศัพท์ที่เปิดมาแนวตั้งจึงโดนสร้างใหม่อย่างน้อยหนึ่งรอบเสมอ) → `_G.WOLD_PvpPartyGui` เป็นตัวใหม่ ของเดิมจับตัวแรกไว้
-- ครั้งเดียว: วาดลงตัวที่ถูกลบไปแล้ว และปุ่มของตัวใหม่ไม่มีใครฟัง · คอมไม่เคยหมุนจอ เทสใน Studio จึงผ่าน
local gui = nil
local lastSnapshot = nil
local lastFriends = nil

--------------------------------------------------------------------------------
-- รูปอวตาร: ขอทีละคน แล้วแคชไว้ (ยิงซ้ำทุกวินาทีตอนค้นหาห้องคือการรีเควสต์ทิ้ง)
--------------------------------------------------------------------------------
local avatarCache = {}

local function avatarFor(userId)
	if avatarCache[userId] ~= nil then return avatarCache[userId] end
	avatarCache[userId] = false -- กันขอซ้ำระหว่างรอ
	task.spawn(function()
		local ok, content = pcall(function()
			return Players:GetUserThumbnailAsync(userId, Enum.ThumbnailType.AvatarThumbnail, Enum.ThumbnailSize.Size420x420)
		end)
		avatarCache[userId] = ok and content or false
	end)
	return false
end

local function draw(snap)
	lastSnapshot = snap
	if not gui then return end -- ยังไม่มีหน้าจอ: เก็บไว้ ลูปข้างล่างวาดให้ทันทีที่หน้าจอมา
	gui:Render(snap)
	for i, member in ipairs(snap.members or {}) do
		local content = avatarFor(member.userId)
		if content then gui:SetSlotAvatar(i, content) end
	end
end

-- ลูปเดียวทำสองอย่าง: (1) หน้าจอเปลี่ยนตัว → ผูกปุ่มกับตัวใหม่แล้ววาดภาพล่าสุดลงไป
-- (2) รูปอวตารที่มาถึงทีหลังต้องได้วาด · ถามใหม่ทุกรอบ ไม่ผูกครั้งเดียว (กฎเหล็กเดิมของโปรเจ็ค)
task.spawn(function()
	local warned = false
	local started = os.clock()
	while true do
		local current = _G.WOLD_PvpPartyGui
		if current and current ~= gui then
			gui = current
			gui:OnAction(function(action, arg)
				Remotes.RequestPvpParty:FireServer(action, arg)
			end)
			if lastSnapshot then draw(lastSnapshot) end
			if lastFriends then gui:RenderFriends(lastFriends) end
		elseif not current and not warned and os.clock() - started > 30 then
			warned = true
			warn("[PvpParty] หาหน้าปาร์ตี้ไม่เจอ — แท็บ PVP จะไม่ตอบสนอง")
		end
		if gui and lastSnapshot then
			for i, member in ipairs(lastSnapshot.members or {}) do
				local content = avatarCache[member.userId]
				if content then gui:SetSlotAvatar(i, content) end
			end
		end
		task.wait(0.25)
	end
end)

--------------------------------------------------------------------------------
Remotes.PvpPartyUpdate.OnClientEvent:Connect(function(data)
	if not data then return end
	-- ข้อความสองชนิดมาทางเดียวกัน: ภาพปาร์ตี้ กับรายชื่อเพื่อนที่เพิ่งขอ
	if data.friends then
		lastFriends = data.friends
		if gui then gui:RenderFriends(data.friends) end
	else
		draw(data)
	end
end)

-- ขอภาพแรกทันที · ถ้าเข้ามาก่อนเซิร์ฟเวอร์พร้อม ลูปข้างล่างจะถามซ้ำให้เอง
task.spawn(function()
	for _ = 1, 10 do
		if lastSnapshot then return end
		Remotes.RequestPvpParty:FireServer("refresh")
		task.wait(1)
	end
end)
