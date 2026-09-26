-- Clans.server.lua: แคลน — สร้าง เข้า บริจาค แจกจ่าย และคลังของแคลน
--
-- **เงินแคลนคือเหรียญซิลเวอร์ ไม่ใช่เงินในเกม** ตามที่ผู้ใช้กำหนด ซิลเวอร์เป็นไอเทมที่ต้องหามา
-- (จากโจร จากเควส จากภาษี) จึงเป็นทรัพยากรที่แคลนแย่งกันสะสมได้จริง ต่างจากเงินซึ่งทุกคนมีอยู่แล้ว
--
-- ตอนแจกจ่ายถึงจะแปลงเป็นเงินในเกม เรท 1:1 ตามที่กำหนด
local Players = game:GetService("Players")

local ServerConfig = require(game.ServerScriptService.ServerConfig)
if ServerConfig.IsLobby then return end

local ClanConfig = require(game.ReplicatedStorage.ClanConfig)
local ClanStore = require(game.ServerScriptService.ClanStore)
local ClanAccess = require(game.ServerScriptService.ClanAccess)
local Inventory = require(game.ServerScriptService.Inventory)
local ItemCatalog = require(game.ReplicatedStorage.ItemCatalog)
local ProfileAccess = require(game.ServerScriptService.ProfileAccess)
local PlayerJoin = require(game.ServerScriptService.PlayerJoin)
local Remotes = require(game.ReplicatedStorage.Remotes)
local Announce = require(game.ServerScriptService.Announce)

local SILVER = "Silver"

--------------------------------------------------------------------------------
-- ใครอยู่แคลนไหน
--------------------------------------------------------------------------------

-- เก็บ clanId ไว้ในโปรไฟล์ของผู้เล่น ไม่ต้องไล่อ่านทุกแคลนเพื่อหาว่าเขาอยู่ไหน
local function clanIdOf(player)
	local data = ProfileAccess.Get(player)
	return data and data.ClanId or nil
end

local function setClanId(player, clanId)
	local data = ProfileAccess.Get(player)
	if data then data.ClanId = clanId end
end

local function clanOf(player, fresh)
	local id = clanIdOf(player)
	if not id then return nil end
	local clan = ClanStore.Get(id, fresh)
	-- ถูกเตะออกจากแคลนตอนอยู่คนละเซิร์ฟเวอร์: โปรไฟล์ยังจำ id เดิมอยู่ แต่ตัวแคลนไม่มีชื่อเราแล้ว
	if clan and not ClanStore.RoleOf(clan, player.UserId) then
		setClanId(player, nil)
		return nil
	end
	-- แคลนถูกยุบไปแล้ว (หายจากดัชนี ไม่ใช่แค่อ่านไม่ได้ชั่วคราว) ก็ล้าง id ทิ้ง
	if not clan and ClanStore.Index(true)[id] == nil then
		setClanId(player, nil)
		return nil
	end
	return clan
end

--------------------------------------------------------------------------------
-- ซิลเวอร์ในกระเป๋า
--------------------------------------------------------------------------------

local function silverHeld(player)
	local state = Inventory.Get(player)
	if not state then return 0 end
	local n = 0
	for _, slot in pairs(state.slots) do
		if slot.id == SILVER then n += (slot.count or 1) end
	end
	return n
end

local function takeSilver(player, amount)
	return Inventory.RemoveById(player, SILVER, amount)
end

--------------------------------------------------------------------------------
-- ภาพที่ส่งให้ไคลเอนต์
--------------------------------------------------------------------------------

local function memberRows(clan)
	local rows = {}
	for userIdStr, role in pairs(clan.members or {}) do
		local userId = tonumber(userIdStr)
		rows[#rows + 1] = {
			userId = userId,
			name = (clan.names and clan.names[userIdStr]) or ("ผู้เล่น " .. userIdStr),
			role = role,
			roleName = ClanConfig.RoleName(role),
			rank = ClanConfig.RankOf(role),
			online = userId and Players:GetPlayerByUserId(userId) ~= nil or false,
		}
	end
	-- หัวแคลนอยู่บนสุดเสมอ ชื่อเป็นตัวตัดสินเมื่อตำแหน่งเท่ากัน ลำดับจึงคงที่
	table.sort(rows, function(a, b)
		if a.rank ~= b.rank then return a.rank < b.rank end
		return a.name < b.name
	end)
	return rows
end

local function clanDetail(clan, viewer)
	if not clan then return nil end
	local towns = {}
	for townId in pairs(clan.towns or {}) do towns[#towns + 1] = townId end
	table.sort(towns)
	return {
		id = clan.id,
		name = clan.name,
		blurb = clan.blurb or "",
		image = clan.image or "",
		silver = clan.silver or 0,
		towns = towns,
		members = memberRows(clan),
		memberCount = ClanStore.MemberCount(clan),
		maxMembers = ClanConfig.MaxMembers,
		myRole = viewer and ClanStore.RoleOf(clan, viewer.UserId) or nil,
		-- คนที่ขอเข้า รอหัวแคลน/รองหัวอนุมัติ
		applicants = (function()
			local rows = {}
			for userId, name in pairs(clan.applicants or {}) do
				rows[#rows + 1] = { userId = tonumber(userId), name = name }
			end
			table.sort(rows, function(a, b) return a.name < b.name end)
			return rows
		end)(),
		vaultSlots = ClanConfig.VaultSlots,
		-- นับเฉพาะช่องที่มีของ — ตาราง vault ที่ส่งไปมี false เต็มทุกช่อง นับ # จะได้ 81/81 เสมอ
		vaultUsed = (function()
			local n = 0
			for _, entry in pairs(clan.vault or {}) do if entry then n += 1 end end
			return n
		end)(),
		-- ของในคลัง ส่งชื่อกับไอคอนมาด้วยเลย ไคลเอนต์จะได้ไม่ต้องเปิดแคตตาล็อกเอง
		vaultCols = ClanConfig.VaultCols,
		vaultRows = ClanConfig.VaultRows,
		-- ของในคลัง ส่งครบทุกช่อง ช่องว่างเป็น false
		--
		-- ส่ง false แทน nil เพราะ nil ในตารางทำให้ช่องหายไปตอนข้ามสายไป ไคลเอนต์จะไม่รู้ว่าช่องไหนว่าง
		-- ช่องไหนไม่มีอยู่ — ตารางจะกลายเป็นรายการที่สั้นลงเรื่อยๆ แทนที่จะเป็นตารางคงที่
		vault = (function()
			local rows = {}
			local stored = clan.vault or {}
			for i = 1, ClanConfig.VaultSlots do
				local entry = stored[i]
				if entry then
					local item = ItemCatalog.Get(entry.id)
					rows[i] = {
						index = i, id = entry.id, count = entry.count or 1,
						name = ItemCatalog.DisplayName(entry.id, entry.meta) or entry.id,
						icon = item and item.icon or "",
					}
				else
					rows[i] = false
				end
			end
			return rows
		end)(),
	}
end

-- รายชื่อแคลนทั้งหมด เรียงตามยอดซิลเวอร์ ซึ่งเป็นอันดับที่ผู้ใช้กำหนด
local function clanList()
	local index = ClanStore.Index()
	local rows = {}
	for clanId in pairs(index) do
		local clan = ClanStore.Get(clanId)
		if clan then
			local towns = 0
			for _ in pairs(clan.towns or {}) do towns += 1 end
			rows[#rows + 1] = {
				id = clan.id,
				name = clan.name,
				blurb = clan.blurb or "",
				image = clan.image or "",
				silver = clan.silver or 0,
				members = ClanStore.MemberCount(clan),
				towns = towns,
			}
		end
	end
	table.sort(rows, function(a, b)
		if a.silver ~= b.silver then return a.silver > b.silver end
		return a.name < b.name
	end)
	return rows
end

local function applyIdOf(player)
	local data = ProfileAccess.Get(player)
	return data and data.ClanApply or nil
end

local function setApplyId(player, clanId)
	local data = ProfileAccess.Get(player)
	if data then data.ClanApply = clanId end
end

-- **ประกาศแคลนของแต่ละคนไว้บนตัว Player** — แอตทริบิวต์บน Player ไปถึงไคลเอนต์ทุกเครื่อง
-- ซึ่งเป็นสิ่งเดียวที่ทำให้ "ปุ่มนี้โชว์เฉพาะคนของแคลนที่ยึดเมืองอยู่" เป็นไปได้: ProximityPrompt มี
-- `Enabled` ตัวเดียวสำหรับทุกคน การซ่อนรายคนจึงต้องให้ไคลเอนต์ปิดของตัวเอง และมันต้องรู้ว่าตัวเองอยู่แคลนไหน
--
-- อ่านจากโปรไฟล์ในหน่วยความจำ ไม่แตะ DataStore — เซิร์ฟเวอร์ยังตรวจสิทธิ์จริงทุกครั้งที่มีคนกดอยู่ดี
-- แอตทริบิวต์นี้ตัดสินแค่ว่า "ปุ่มควรโผล่ไหม" ไม่ใช่ "ทำได้ไหม"
local function publishClanId(player)
	-- **`""` = ไม่ได้อยู่แคลนไหน · nil = ไฟล์นี้ยังไม่ได้พูด** ความต่างนี้สำคัญกว่าที่เห็น: ฝั่งไคลเอนต์
	-- แปล nil ว่า "ยังไม่รู้ อย่าเพิ่งซ่อนปุ่มอะไร" ถ้าใช้ nil แทนคนไม่มีแคลน วันที่ไฟล์นี้พังหรือโหลดช้า
	-- ทุกคนจะกลายเป็น "คนไม่มีแคลน" แล้วปุ่มทั้งหมดที่อนุสาวรีย์จะหายไปเงียบๆ โดยไม่มี error ให้เห็น
	player:SetAttribute("ClanId", clanIdOf(player) or "")
end

local function push(player)
	-- อ่านสดทุกครั้งที่วาดหน้า: คำขอเข้าแคลนมาจากคนละเซิร์ฟเวอร์ได้ ถ้าใช้แคชหัวแคลนจะไม่เห็นคำขอเลย
	-- จนกว่าตัวเองจะไปแก้อะไรในแคลน — หนึ่ง GetAsync ต่อการเปิดหน้า รับได้
	local clan = clanOf(player, true)
	Remotes.ClanUpdate:FireClient(player, {
		list = clanList(),
		mine = clanDetail(clan, player),
		-- แคลนที่ยื่นขอไว้ (ถ้ามี) ปุ่มสมัครจะได้เปลี่ยนเป็น "รออนุมัติ"
		applying = (not clan) and applyIdOf(player) or nil,
		silverHeld = silverHeld(player),
		createCost = ClanConfig.CreateCostSilver,
	})
end

--------------------------------------------------------------------------------
-- การกระทำ
--------------------------------------------------------------------------------

local function create(player, name, blurb)
	if clanIdOf(player) then
		return Remotes.SocialNotify:FireClient(player, "warn", "คุณอยู่ในแคลนอยู่แล้ว")
	end
	local cost = ClanConfig.CreateCostSilver
	if silverHeld(player) < cost then
		return Remotes.SocialNotify:FireClient(player, "error",
			("ต้องใช้เหรียญซิลเวอร์ %d เหรียญ"):format(cost))
	end

	-- **ชื่อ/คำอธิบายแคลนผ่านตัวกรองของ Roblox ก่อน** (QA 2026-09-26) — มันโผล่ในรายชื่อแคลน บนแหวน และบน
	-- ป้ายยึดเมืองให้ทุกคนเห็น · ชื่อที่ตัวกรองต้องแก้ = ใช้ไม่ได้ (ชื่อที่มี #### เป็นชื่อถาวรที่ไม่มีใครอยากได้)
	-- · คำอธิบายรับฉบับที่กรองแล้ว · กรองไม่สำเร็จ (บริการล่ม) = ยังไม่สร้าง
	if type(name) ~= "string" then return end
	name = name:gsub("^%s+", ""):gsub("%s+$", "")
	local shownName = Announce.Filter(name, player.UserId)
	if not shownName then
		return Remotes.SocialNotify:FireClient(player, "error", "กรองข้อความไม่สำเร็จ ลองใหม่อีกครั้ง")
	end
	if shownName ~= name then
		return Remotes.SocialNotify:FireClient(player, "error", "ชื่อแคลนนี้ใช้ไม่ได้ ลองชื่ออื่น")
	end
	blurb = type(blurb) == "string" and Announce.Trim(blurb, ClanConfig.BlurbMaxLength) or ""
	if blurb ~= "" then
		blurb = Announce.Filter(blurb, player.UserId)
		if not blurb then
			return Remotes.SocialNotify:FireClient(player, "error", "กรองข้อความไม่สำเร็จ ลองใหม่อีกครั้ง")
		end
	end

	local clan, err = ClanStore.Create(name, blurb, player.UserId, player.DisplayName)
	if not clan then
		return Remotes.SocialNotify:FireClient(player, "error", err or "สร้างแคลนไม่สำเร็จ")
	end

	-- **หักเงินหลังสร้างสำเร็จ** ถ้าหักก่อนแล้วชื่อซ้ำ ผู้เล่นจะเสียซิลเวอร์ฟรี
	takeSilver(player, cost)
	setClanId(player, clan.id)
	ClanAccess.GiveRing(player)
	Remotes.SocialNotify:FireClient(player, "info", ("สร้างแคลน %s แล้ว"):format(clan.name))
	push(player)
end

-- **สมัครแล้วต้องรออนุมัติ** ผู้ใช้กำหนด — การกดสมัครแค่ใส่ชื่อลงรายชื่อผู้ขอของแคลนนั้น หัวแคลนหรือรองหัว
-- ต้องกดรับถึงจะเป็นสมาชิก คนหนึ่งยื่นได้ทีละแคลน (ยื่นใหม่ = ถอนอันเก่า)
--
-- ผู้ขอกับคนอนุมัติมักไม่ได้ออนไลน์พร้อมกัน จึงจำ id แคลนที่ยื่นไว้ในโปรไฟล์ของผู้ขอ (ClanApply) แล้วตอนเข้าเกม
-- ครั้งถัดไปมาดูว่าชื่อตัวเองไปอยู่ในสมาชิกหรือยัง (อนุมัติแล้ว) หรือหายจากรายชื่อผู้ขอ (ถูกปฏิเสธ)
local function withdraw(player, clanId)
	if not clanId then return end
	ClanStore.Update(clanId, function(c)
		if not c or not c.applicants then return nil end
		c.applicants[tostring(player.UserId)] = nil
		return c
	end)
	setApplyId(player, nil)
end

local function join(player, clanId)
	if clanIdOf(player) then
		return Remotes.SocialNotify:FireClient(player, "warn", "คุณอยู่ในแคลนอยู่แล้ว")
	end
	local previous = applyIdOf(player)
	if previous == clanId then
		return Remotes.SocialNotify:FireClient(player, "info", "ยื่นขอเข้าแคลนนี้ไว้แล้ว รอหัวแคลนอนุมัติ")
	end
	if previous then withdraw(player, previous) end

	local full = false
	local result = ClanStore.Update(clanId, function(clan)
		if not clan then return nil end
		if ClanStore.MemberCount(clan) >= ClanConfig.MaxMembers then
			full = true
			return nil
		end
		clan.applicants = clan.applicants or {}
		clan.applicants[tostring(player.UserId)] = player.DisplayName
		return clan
	end)

	if full then
		return Remotes.SocialNotify:FireClient(player, "warn", "แคลนนี้เต็มแล้ว")
	end
	if not result then
		return Remotes.SocialNotify:FireClient(player, "error", "ส่งคำขอไม่สำเร็จ")
	end

	setApplyId(player, clanId)
	Remotes.SocialNotify:FireClient(player, "info",
		("ส่งคำขอเข้าแคลน %s แล้ว รอหัวแคลนอนุมัติ"):format(result.name))
	-- บอกหัวแคลน/รองหัวที่ออนไลน์อยู่
	for _, p in ipairs(Players:GetPlayers()) do
		local role = ClanStore.RoleOf(result, p.UserId)
		if role == "leader" or role == "officer" then
			Remotes.SocialNotify:FireClient(p, "info", ("%s ขอเข้าแคลน — เปิดหน้าแคลนเพื่ออนุมัติ"):format(player.DisplayName))
			push(p)
		end
	end
	push(player)
end

local function cancelApply(player)
	local clanId = applyIdOf(player)
	if not clanId then return end
	withdraw(player, clanId)
	Remotes.SocialNotify:FireClient(player, "info", "ถอนคำขอแล้ว")
	push(player)
end

local function canApprove(clan, player)
	local role = ClanStore.RoleOf(clan, player.UserId)
	return role == "leader" or role == "officer"
end

local function approve(player, targetUserId)
	local clan = clanOf(player)
	if not clan then return end
	if not canApprove(clan, player) then
		return Remotes.SocialNotify:FireClient(player, "warn", "เฉพาะหัวแคลนหรือรองหัวเท่านั้น")
	end
	local key = tostring(targetUserId)
	local full, name = false, nil
	local result = ClanStore.Update(clan.id, function(c)
		if not c or not c.applicants or not c.applicants[key] then return nil end
		if ClanStore.MemberCount(c) >= ClanConfig.MaxMembers then
			full = true
			return nil
		end
		name = c.applicants[key]
		c.applicants[key] = nil
		c.members = c.members or {}
		c.names = c.names or {}
		c.members[key] = "member"
		c.names[key] = name
		return c
	end)
	if full then
		return Remotes.SocialNotify:FireClient(player, "warn", ("แคลนเต็มแล้ว (%d คน)"):format(ClanConfig.MaxMembers))
	end
	if not result then
		return Remotes.SocialNotify:FireClient(player, "error", "อนุมัติไม่สำเร็จ")
	end

	-- ผู้ขอออนไลน์อยู่ก็เข้าแคลนทันที ไม่อยู่ก็เจอตอนเข้าเกม (reconcile ข้างล่าง)
	local target = Players:GetPlayerByUserId(tonumber(targetUserId) or 0)
	if target then
		if clanIdOf(target) then
			-- ไปอยู่แคลนอื่นแล้วระหว่างรอ ถอดชื่อออกจากเราอีกที
			ClanStore.Update(clan.id, function(c)
				if not c then return nil end
				c.members[key] = nil
				c.names[key] = nil
				return c
			end)
			return Remotes.SocialNotify:FireClient(player, "warn", "คนนั้นอยู่แคลนอื่นแล้ว")
		end
		setClanId(target, clan.id)
		setApplyId(target, nil)
		ClanAccess.GiveRing(target)
		Remotes.SocialNotify:FireClient(target, "info", ("ได้รับอนุมัติเข้าแคลน %s แล้ว"):format(result.name))
		push(target)
	end
	Remotes.SocialNotify:FireClient(player, "info", ("รับ %s เข้าแคลนแล้ว"):format(name or key))
	push(player)
end

local function reject(player, targetUserId)
	local clan = clanOf(player)
	if not clan then return end
	if not canApprove(clan, player) then
		return Remotes.SocialNotify:FireClient(player, "warn", "เฉพาะหัวแคลนหรือรองหัวเท่านั้น")
	end
	local key = tostring(targetUserId)
	local name
	ClanStore.Update(clan.id, function(c)
		if not c or not c.applicants or not c.applicants[key] then return nil end
		name = c.applicants[key]
		c.applicants[key] = nil
		return c
	end)
	local target = Players:GetPlayerByUserId(tonumber(targetUserId) or 0)
	if target and applyIdOf(target) == clan.id then
		setApplyId(target, nil)
		Remotes.SocialNotify:FireClient(target, "warn", ("แคลน %s ปฏิเสธคำขอ"):format(clan.name))
		push(target)
	end
	Remotes.SocialNotify:FireClient(player, "info", ("ปฏิเสธ %s แล้ว"):format(name or key))
	push(player)
end

-- ยุบแคลน: หัวแคลนเท่านั้น ลบออกจาก DataStore/ดัชนี ปล่อยเมืองที่ยึด สมาชิกออนไลน์หลุดทันที ออฟไลน์หลุดตอนเข้าเกม
-- (clanOf เห็นว่าแคลนหายจากดัชนีแล้วล้าง ClanId ให้)
local function disband(player)
	local clan = clanOf(player, true)
	if not clan then return end
	if ClanStore.RoleOf(clan, player.UserId) ~= "leader" then
		return Remotes.SocialNotify:FireClient(player, "warn", "เฉพาะหัวแคลนเท่านั้น")
	end
	local name = clan.name
	if not ClanStore.Delete(clan.id) then
		return Remotes.SocialNotify:FireClient(player, "error", "ยุบแคลนไม่สำเร็จ")
	end
	ClanStore.UpdateTowns(function(t)
		for id, o in pairs(t) do if o.clanId == clan.id then t[id] = nil end end
		return t
	end)
	for _, p in ipairs(Players:GetPlayers()) do
		if clanIdOf(p) == clan.id then
			setClanId(p, nil)
			setApplyId(p, nil)
			Remotes.SocialNotify:FireClient(p, "warn", ("แคลน %s ถูกยุบแล้ว"):format(name))
			push(p)
		end
	end
end

local function leave(player)
	local clan = clanOf(player)
	if not clan then return end
	if ClanStore.RoleOf(clan, player.UserId) == "leader" and ClanStore.MemberCount(clan) > 1 then
		return Remotes.SocialNotify:FireClient(player, "warn",
			"หัวแคลนออกไม่ได้ ต้องยกตำแหน่งให้คนอื่นก่อน")
	end
	ClanStore.Update(clan.id, function(c)
		if not c then return nil end
		c.members[tostring(player.UserId)] = nil
		c.names[tostring(player.UserId)] = nil
		return c
	end)
	setClanId(player, nil)
	Remotes.SocialNotify:FireClient(player, "info", "ออกจากแคลนแล้ว")
	push(player)
end

local function donate(player, amount)
	local clan = clanOf(player)
	if not clan then return end
	amount = math.max(1, math.floor(tonumber(amount) or 0))
	if silverHeld(player) < amount then
		return Remotes.SocialNotify:FireClient(player, "error", "เหรียญซิลเวอร์ไม่พอ")
	end

	-- **เอาออกจากกระเป๋าก่อน แล้วค่อยบวกเข้าคลัง** ถ้าบวกก่อนแล้วเอาออกไม่สำเร็จ แคลนจะได้เงินฟรี
	if not takeSilver(player, amount) then
		return Remotes.SocialNotify:FireClient(player, "error", "เหรียญซิลเวอร์ไม่พอ")
	end

	local result = ClanStore.Update(clan.id, function(c)
		if not c then return nil end
		c.silver = (c.silver or 0) + amount
		return c
	end)

	if not result then
		-- คืนเงินถ้าเขียนไม่สำเร็จ ไม่งั้นซิลเวอร์หายไปเฉยๆ
		Inventory.AddItem(player, SILVER, amount)
		return Remotes.SocialNotify:FireClient(player, "error", "บริจาคไม่สำเร็จ คืนเหรียญแล้ว")
	end

	Remotes.SocialNotify:FireClient(player, "info",
		("บริจาค %d ซิลเวอร์ (คลังมี %d)"):format(amount, result.silver))
	push(player)
end

-- แจกจ่ายเงินให้สมาชิก แปลงซิลเวอร์เป็นเงินในเกม 1:1
--
-- `target` = userId คนเดียว หรือ nil = แจกทุกคนเท่าๆ กัน
local function distribute(player, amount, target)
	local clan = clanOf(player)
	if not clan then return end
	if ClanStore.RoleOf(clan, player.UserId) ~= "leader" then
		return Remotes.SocialNotify:FireClient(player, "warn", "เฉพาะหัวแคลนเท่านั้น")
	end

	amount = math.max(1, math.floor(tonumber(amount) or 0))

	-- หาคนรับ
	local receivers = {}
	if target then
		local p = Players:GetPlayerByUserId(tonumber(target) or 0)
		if not p or not ClanStore.RoleOf(clan, p.UserId) then
			return Remotes.SocialNotify:FireClient(player, "warn", "คนนั้นไม่อยู่ในเซิร์ฟเวอร์นี้")
		end
		receivers[1] = p
	else
		for _, p in ipairs(Players:GetPlayers()) do
			if ClanStore.RoleOf(clan, p.UserId) then receivers[#receivers + 1] = p end
		end
	end
	if #receivers == 0 then
		return Remotes.SocialNotify:FireClient(player, "warn", "ไม่มีสมาชิกออนไลน์")
	end

	-- แจกทุกคน = หารเท่าๆ กัน ส่วนที่หารไม่ลงตัวไม่ถูกหักออกจากคลัง
	local each = target and amount or math.floor(amount / #receivers)
	if each < 1 then
		return Remotes.SocialNotify:FireClient(player, "warn", "จำนวนน้อยเกินกว่าจะหารได้")
	end
	local total = each * #receivers

	local result = ClanStore.Update(clan.id, function(c)
		if not c then return nil end
		if (c.silver or 0) < total then return nil end
		c.silver -= total
		return c
	end)
	if not result then
		return Remotes.SocialNotify:FireClient(player, "error", "เงินในคลังไม่พอ")
	end

	local gold = each * ClanConfig.SilverToGold
	for _, p in ipairs(receivers) do
		Inventory.AddGold(p, gold)
		Remotes.SocialNotify:FireClient(p, "info", ("ได้รับจากแคลน %d เหรียญ"):format(gold))
	end
	Remotes.SocialNotify:FireClient(player, "info",
		("แจกจ่าย %d ซิลเวอร์ ให้ %d คน (เหลือ %d)"):format(total, #receivers, result.silver))
	push(player)
end

local function setRole(player, targetUserId, role)
	local clan = clanOf(player)
	if not clan then return end
	if ClanStore.RoleOf(clan, player.UserId) ~= "leader" then
		return Remotes.SocialNotify:FireClient(player, "warn", "เฉพาะหัวแคลนเท่านั้น")
	end
	if not ClanConfig.RoleName(role) or ClanConfig.RankOf(role) == 99 then return end

	ClanStore.Update(clan.id, function(c)
		if not c or not c.members[tostring(targetUserId)] then return nil end
		-- ยกตำแหน่งหัวแคลนให้คนอื่น = ตัวเองลงเป็นรองหัว ไม่งั้นจะมีหัวแคลนสองคน
		if role == "leader" then
			c.members[tostring(player.UserId)] = "officer"
			c.leader = tonumber(targetUserId)
		end
		c.members[tostring(targetUserId)] = role
		return c
	end)
	push(player)
end

--------------------------------------------------------------------------------
-- คลังของแคลน
--------------------------------------------------------------------------------

local function vaultPut(player, bagIndex, count)
	local clan = clanOf(player)
	if not clan then return end
	local state = Inventory.Get(player)
	local slot = state and state.slots[bagIndex]
	if not slot then return end
	if not ItemCatalog.IsStorable(slot.id) then
		return Remotes.SocialNotify:FireClient(player, "warn", "ของชิ้นนี้ฝากคลังไม่ได้")
	end
	count = math.clamp(math.floor(tonumber(count) or 1), 1, slot.count or 1)

	local stored = { id = slot.id, count = count, durability = slot.durability, meta = slot.meta }
	local full = false
	local result = ClanStore.Update(clan.id, function(c)
		if not c then return nil end
		c.vault = c.vault or {}
		-- **หาช่องว่างแรก ไม่ใช่ต่อท้าย** คลังเป็นตาราง 9x9 ที่ของอยู่กับที่ ไม่ใช่รายการที่เลื่อนได้
		local free
		for i = 1, ClanConfig.VaultSlots do
			if c.vault[i] == nil then free = i break end
		end
		if not free then full = true return nil end
		c.vault[free] = stored
		return c
	end)
	if full then
		return Remotes.SocialNotify:FireClient(player, "warn", "คลังแคลนเต็ม")
	end
	if not result then return end
	Inventory.RemoveFromSlot(player, bagIndex, count)
	push(player)
end

local function vaultTake(player, index)
	local clan = clanOf(player)
	if not clan then return end
	-- ใครหยิบของออกจากคลังได้: หัวแคลนกับรองหัว
	local rank = ClanConfig.RankOf(ClanStore.RoleOf(clan, player.UserId) or "member")
	if rank > 2 then
		return Remotes.SocialNotify:FireClient(player, "warn", "เฉพาะหัวแคลนและรองหัวเท่านั้น")
	end

	local taken = nil
	local result = ClanStore.Update(clan.id, function(c)
		if not c or not c.vault or not c.vault[index] then return nil end
		taken = c.vault[index]
		-- **เคลียร์ช่อง ไม่ใช่ table.remove** การลบออกจะเลื่อนของทุกชิ้นที่อยู่หลังมันขึ้นมาหนึ่งช่อง
		-- ของในตารางจะกระโดดที่ทุกครั้งที่มีคนหยิบ ซึ่งเป็นสิ่งที่คลังแบบตารางต้องไม่ทำ
		c.vault[index] = nil
		return c
	end)
	if not result or not taken then return end

	if not Inventory.AddItem(player, taken.id, taken.count, taken.durability, taken.meta) then
		-- ใส่กลับคลัง ไม่งั้นของหายไปเฉยๆ
		ClanStore.Update(clan.id, function(c)
			-- คืนที่ช่องเดิม ไม่ใช่ต่อท้าย
			if c then c.vault[index] = taken end
			return c
		end)
		return Remotes.SocialNotify:FireClient(player, "error", "กระเป๋าเต็ม")
	end
	push(player)
end

--------------------------------------------------------------------------------
-- เผยแพร่ให้ระบบอื่น
--------------------------------------------------------------------------------

-- ลูปเดียวที่ดูความจริงตอนนี้ ด้วยเหตุผลเดียวกับ BoundItems: การเข้า/ออกแคลนเกิดจากหลายทาง
-- (หัวแคลนอนุมัติจากเซิร์ฟอื่น · โดนเตะ · แคลนถูกยุบ) ผูกกับเหตุการณ์ไหนก็พลาดทางที่เหลือ
task.spawn(function()
	while true do
		for _, player in ipairs(Players:GetPlayers()) do
			publishClanId(player)
		end
		task.wait(3)
	end
end)

ClanAccess.ClanOf = function(player) return clanOf(player) end
ClanAccess.ClanIdOf = clanIdOf

-- ภาษีเข้าคลัง เรียกโดย NPC ประจำเมือง (รอบถัดไป)
ClanAccess.AddSilver = function(clanId, amount)
	if not clanId or not amount or amount <= 0 then return end
	ClanStore.Update(clanId, function(c)
		if not c then return nil end
		c.silver = (c.silver or 0) + amount
		return c
	end)
end

-- แหวนแคลน: วางโครงไว้ก่อนตามที่ผู้ใช้สั่ง ยังไม่มีไอเทมจริง
-- แหวนแคลน: BoundItems.server เป็นคนเติม/ลบจริง (ทุก 3 วิ ตามสถานะแคลน) ที่นี่แค่ให้ทันทีเพื่อไม่ต้องรอ
ClanAccess.GiveRing = function(player)
	local clan = clanOf(player)
	if clan and ItemCatalog.Exists("ClanRing") then
		local state = Inventory.Get(player)
		for _, slot in pairs(state and state.slots or {}) do
			if slot.id == "ClanRing" then return end
		end
		Inventory.AddItem(player, "ClanRing", 1, nil, { clan = clan.name })
	end
end

--------------------------------------------------------------------------------
-- ปุ่มที่ NPC กิลด์
--------------------------------------------------------------------------------

local CollectionService = game:GetService("CollectionService")
local NPC_TAG = "WOLD_Npc"
local RANGE = 12

local wired = {}

local function register(npc)
	if npc:GetAttribute("NpcKind") ~= "guild" then return end
	if wired[npc] then return end

	-- **HumanoidRootPart ก่อน ไม่ใช่ PrimaryPart** ด้วยเหตุผลเดียวกับที่ร้านค้าเขียนไว้: PrimaryPart ของ
	-- โมเดลชุดคิทเป็นหมุด 1x1 ที่เท้า ปุ่มจะไปอยู่ระดับพื้นข้างรองเท้าแทนที่จะอยู่ระดับตัว
	local anchor = npc:IsA("BasePart") and npc
		or (npc:IsA("Model") and (npc:FindFirstChild("HumanoidRootPart") or npc:FindFirstChild("UpperTorso")
			or npc.PrimaryPart or npc:FindFirstChildWhichIsA("BasePart", true)))
	if not anchor then return end
	if anchor:FindFirstChild("GuildPrompt") then return end
	wired[npc] = true

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "GuildPrompt"
	prompt.ActionText = "สมาคมแคลน"
	prompt.ObjectText = npc:GetAttribute("NpcName") or "เอลิน่า"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.MaxActivationDistance = RANGE
	prompt.RequiresLineOfSight = false
	prompt.HoldDuration = 0
	prompt.Parent = anchor

	prompt.Triggered:Connect(function(player)
		push(player)
	end)
end

-- ลูปถามใหม่ กฎเหล็กของโปรเจ็ค: NPC มาถึงคนละรอบกับสคริปต์ภายใต้ StreamingEnabled
task.spawn(function()
	while true do
		for _, npc in ipairs(CollectionService:GetTagged(NPC_TAG)) do
			register(npc)
		end
		task.wait(0.5)
	end
end)

CollectionService:GetInstanceAddedSignal(NPC_TAG):Connect(register)

--------------------------------------------------------------------------------
-- คำขอจากไคลเอนต์
--------------------------------------------------------------------------------

Remotes.RequestClanAction.OnServerEvent:Connect(function(player, action, a, b)
	if action == "refresh" then push(player)
	elseif action == "create" then create(player, a, b)
	elseif action == "join" then join(player, a)
	elseif action == "cancelapply" then cancelApply(player)
	elseif action == "approve" then approve(player, a)
	elseif action == "reject" then reject(player, a)
	elseif action == "leave" then leave(player)
	elseif action == "disband" then disband(player)
	elseif action == "donate" then donate(player, a)
	elseif action == "distribute" then distribute(player, a, b)
	elseif action == "setrole" then setRole(player, a, b)
	elseif action == "vaultput" then vaultPut(player, a, b)
	elseif action == "vaulttake" then vaultTake(player, a)
	end
end)

-- **อยู่ท้ายไฟล์** เพราะเรียก ClanAccess.GiveRing ซึ่งถูกนิยามข้างบนนี้ — ผู้เล่นที่อยู่แล้วตอนสคริปต์เริ่ม
-- จะถูกส่งเข้าฟังก์ชันนี้ทันที ถ้าวางไว้กลางไฟล์ GiveRing ยังเป็น nil
-- ตอนเข้าเกม: คำขอที่ยื่นไว้ถูกตัดสินไปแล้วระหว่างออฟไลน์ไหม
PlayerJoin.Each(function(player)
	local data = ProfileAccess.Wait(player)
	if not data or not data.ClanApply or data.ClanId then
		if data and data.ClanId then data.ClanApply = nil end
		return
	end
	local clan = ClanStore.Get(data.ClanApply, true)
	if not clan then
		data.ClanApply = nil
		return
	end
	if ClanStore.RoleOf(clan, player.UserId) then
		data.ClanId = clan.id
		data.ClanApply = nil
		ClanAccess.GiveRing(player)
		Remotes.SocialNotify:FireClient(player, "info", ("ได้รับอนุมัติเข้าแคลน %s แล้ว"):format(clan.name))
	elseif not (clan.applicants and clan.applicants[tostring(player.UserId)]) then
		data.ClanApply = nil
		Remotes.SocialNotify:FireClient(player, "warn", ("แคลน %s ปฏิเสธคำขอ"):format(clan.name))
	end
end)
