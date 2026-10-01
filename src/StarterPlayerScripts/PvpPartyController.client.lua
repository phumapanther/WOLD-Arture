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
-- แร็งก์ของเรา (เฟส 3 · LobbyRank.server) — จำไว้วาดใส่หน้าจอตัวใหม่ตอนมือถือหมุนจอ
local lastRank = nil
Remotes.PvpRankInfo.OnClientEvent:Connect(function(info)
	lastRank = info
	if gui then gui:SetRankInfo(info) end
end)

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

local UiSound = require(ReplicatedStorage.UI.UiSound)
-- ล็อบบี้ไม่มีจอโหลด: โหลดเสียงของหน้านี้ไว้ก่อน ไม่งั้นกดหาห้องครั้งแรกเงียบ/ช้า
task.spawn(UiSound.Preload, { "PvpSearch", "PvpFound", "LobbyReturn", "ToastInfo", "ToastError" })

-- คนกด = "ตึก" ทันทีที่กด ไม่รอเซิร์ฟตอบ (ผู้ใช้สั่ง 2026-10-01) · เพื่อนในตี้ได้ยินตอนภาพ "กำลังหา" มาถึง
local pressedAt = -math.huge

local function draw(snap)
	-- เสียงตามสถานะที่เปลี่ยน (ผู้ใช้สั่ง 2026-10-01): เริ่มหาห้อง · เจอห้องแล้ว (กำลังย้ายเข้าสนาม)
	-- เทียบกับภาพก่อนหน้า — ภาพเดิมที่วาดซ้ำตอนมือถือหมุนจอไม่มีอะไรเปลี่ยน จึงไม่ดังซ้ำ
	local prev = lastSnapshot
	if prev then
		if snap.launching and not prev.launching then
			UiSound.Play("PvpFound")
		elseif snap.searching and not prev.searching and os.clock() - pressedAt > 2 then
			UiSound.Play("PvpSearch")
		end
	end
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
				-- แตะตราแร็งก์: ตอนนี้แร็งก์ล็อก (PvpRankConfig.Enabled) ตอบในเครื่องเลย ไม่ต้องถามเซิร์ฟ
				if action == "ranklocked" then
					local toast = game.ReplicatedStorage:FindFirstChild("WOLD_Toast")
					if toast then toast:Fire(require(game.ReplicatedStorage.PvpRankConfig).LockedText) end
					return
				end
				if action == "play" or action == "solo" then
					pressedAt = os.clock()
					UiSound.Play("PvpSearch")
				end
				Remotes.RequestPvpParty:FireServer(action, arg)
			end)
			if lastSnapshot then draw(lastSnapshot) end
			if lastFriends then gui:RenderFriends(lastFriends) end
			if lastRank then gui:SetRankInfo(lastRank) end
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

-- กลับจากสนาม = เสียง + ข้อความ "กลับสู่ล็อบบี้แล้ว" (ผู้ใช้สั่ง 2026-10-01) · TeleportData มาจาก ArenaMatch.sendPartyHome
task.spawn(function()
	local ok, data = pcall(function() return game:GetService("TeleportService"):GetLocalPlayerTeleportData() end)
	local back = ok and type(data) == "table" and type(data.arenaReturn) == "table" and data.arenaReturn
	if not back then return end
	if not game:IsLoaded() then game.Loaded:Wait() end
	UiSound.Play("LobbyReturn")
	local text = back.again and "กลับสู่ล็อบบี้แล้ว — กำลังหาห้องต่อพร้อมตี้" or "กลับสู่ล็อบบี้แล้ว"
	for _ = 1, 20 do
		local toast = ReplicatedStorage:FindFirstChild("WOLD_Toast")
		if toast then return toast:Fire(text, false, true) end -- silent: เสียงของตัวเองดังไปแล้ว
		task.wait(0.5)
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
