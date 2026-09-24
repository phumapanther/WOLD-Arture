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

-- หน้าต่างถูกสร้างโดย `ChannelSelectController` ซึ่งอาจยังไม่เสร็จตอนสคริปต์นี้เริ่ม
local gui
local t0 = os.clock()
while os.clock() - t0 < 30 do
	gui = _G.WOLD_PvpPartyGui
	if gui then break end
	task.wait(0.25)
end
if not gui then
	warn("[PvpParty] หาหน้าปาร์ตี้ไม่เจอ — แท็บ PVP จะไม่ตอบสนอง")
	return
end

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

local lastSnapshot = nil

local function draw(snap)
	lastSnapshot = snap
	gui:Render(snap)
	for i, member in ipairs(snap.members or {}) do
		local content = avatarFor(member.userId)
		if content then gui:SetSlotAvatar(i, content) end
	end
end

-- รูปที่มาถึงทีหลังต้องได้วาด — ลูปเบาๆ ที่ไล่เติมรูปให้ช่องที่ยังว่าง
task.spawn(function()
	while true do
		task.wait(0.5)
		if lastSnapshot then
			for i, member in ipairs(lastSnapshot.members or {}) do
				local content = avatarCache[member.userId]
				if content then gui:SetSlotAvatar(i, content) end
			end
		end
	end
end)

--------------------------------------------------------------------------------
Remotes.PvpPartyUpdate.OnClientEvent:Connect(function(data)
	if not data then return end
	-- ข้อความสองชนิดมาทางเดียวกัน: ภาพปาร์ตี้ กับรายชื่อเพื่อนที่เพิ่งขอ
	if data.friends then
		gui:RenderFriends(data.friends)
	else
		draw(data)
	end
end)

gui:OnAction(function(action, arg)
	Remotes.RequestPvpParty:FireServer(action, arg)
end)

-- ขอภาพแรกทันที · ถ้าเข้ามาก่อนเซิร์ฟเวอร์พร้อม ลูปข้างล่างจะถามซ้ำให้เอง
task.spawn(function()
	for _ = 1, 10 do
		if lastSnapshot then return end
		Remotes.RequestPvpParty:FireServer("refresh")
		task.wait(1)
	end
end)
