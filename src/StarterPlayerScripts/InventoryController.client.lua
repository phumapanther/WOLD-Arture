-- InventoryController: opens the bag on I (or the touch button), renders what the server sends, and turns
-- clicks into requests. Every decision belongs to the server — this only asks.
--
-- Clicking a slot does the obvious thing for what is in it: weapons and armor equip, consumables are used,
-- junk does nothing. That avoids a context menu, which would be painful on a phone.
while workspace:GetAttribute("IsLobby") == nil do
	task.wait()
end
if workspace:GetAttribute("IsLobby") then return end
-- ⚠️ **กระเป๋าใช้ไม่ได้ในสนาม PVP** (ผู้ใช้สั่ง) — ของที่ซื้อในสนามถูกสวมให้เลยจากหน้าร้าน
-- และปุ่ม B ในสนามเป็นของ "หน้าร้าน" ไม่ใช่ของกระเป๋า (`ArenaController`)
if workspace:GetAttribute("ArenaMode") == true then return end

local Players = game:GetService("Players")
local ContextActionService = game:GetService("ContextActionService")
local UserInputService = game:GetService("UserInputService")
local InventoryGui = require(game.ReplicatedStorage.UI.InventoryGui)
local ItemCatalog = require(game.ReplicatedStorage.ItemCatalog)
local TrapConfig = require(game.ReplicatedStorage.TrapConfig)

-- How close someone must be to be offered in the "give" list. Arm's length, matching the class actions --
-- handing something over should mean walking to them.
local GIVE_RANGE = 8
local Remotes = require(game.ReplicatedStorage.Remotes)
local HudAccess = require(game.ReplicatedStorage.UI.HudAccess)
local InventoryConfig = require(game.ReplicatedStorage.InventoryConfig)

local player = Players.LocalPlayer
local gui = InventoryGui.new()
gui.gui.Parent = player:WaitForChild("PlayerGui")

local latest = { slots = {}, equipped = {}, gold = 0, weight = 0, maxWeight = 1 }
local addSkinEntries -- นิยามข้างล่าง ใกล้เมนูไอเทม

Remotes.InventoryUpdate.OnClientEvent:Connect(function(data)
	latest = data
	-- เงินในกระเป๋าเป็นแอตทริบิวต์ท้องถิ่น (ไม่ replicate) ให้ช่องกรอกเงินที่อื่นใช้เป็นเพดาน เช่น ให้เงินผู้เล่น (2026-10-02)
	player:SetAttribute("WOLD_GoldHeld", data and data.gold or 0)
	-- Only redraw while open: the panel is hidden most of the time and this fires on every pickup.
	if gui:IsOpen() then gui:Render(latest) end
end)

-- Ask for the contents rather than relying on having caught the one broadcast the server sends on join.
-- This script waits for the IsLobby attribute before it connects, and on a slow-loading client (a phone,
-- measured) that wait outlasts the server send -- so the bag stayed empty forever, since later updates only
-- arrive when something CHANGES. Retried a few times because the profile may still be loading server-side.
task.spawn(function()
	for _ = 1, 10 do
		if latest.slots and next(latest.slots) ~= nil then return end
		Remotes.RequestInventoryRefresh:FireServer()
		task.wait(1)
	end
end)

local function toggle()
	if gui:IsOpen() then
		gui:Hide()
	else
		gui:Render(latest)
		gui:GuardAgainstOpeningTap()
		gui:Show()
	end
end

-- Exposed to the touch controller the same way the roll button reaches ActionController: a BindableEvent
-- rather than a global, so load order cannot break it.
-- ⚠️ ช่องทางอยู่ใน ReplicatedStorage (สร้างฝั่งไคลเอนต์ = มีแค่เครื่องนี้) **ห้ามไว้ใน PlayerGui** — ตัวละครเกิดทีไร
-- Roblox ล้าง PlayerGui ทุกอย่างยกเว้น ScreenGui ที่ ResetOnSpawn=false ช่องทางหายเงียบๆ ปุ่มมือถือตายทั้งแถบ
-- (สนาม PVP เกิดตัวละครหลังสคริปต์เริ่มและทุกรอบ = ตายตั้งแต่ต้น · เกมหลักตายหลังตายครั้งแรก) QA 2026-09-26
local bindable = Instance.new("BindableEvent")
bindable.Name = "WOLD_ToggleInventory"
bindable.Parent = game.ReplicatedStorage
bindable.Event:Connect(toggle)

-- เปิดกระเป๋าได้ทั้ง I และ B ตามที่ผู้ใช้สั่ง
--
-- ผูกผ่าน ContextActionService ไม่ใช่ UserInputService เพราะ **I กับ O เป็นปุ่มซูมกล้องในตัวของ Roblox**
-- กด I เฉยๆ จะเปิดกระเป๋าพร้อมซูมกล้องเข้าไปด้วย การ Sink กินปุ่มก่อนกล้องจะเห็น และล้อเมาส์ยังซูมได้ปกติ
--
-- B ไม่ชนกับอะไรของ Roblox จึงเป็นทางสำรองที่ใช้ได้แน่นอนถ้า I ถูกอย่างอื่นแย่งไป (ปลั๊กอิน Studio บางตัว
-- จับ I ไว้ตอนกด Play ซึ่งเป็นอาการที่ผู้ใช้เจอ)
ContextActionService:BindAction("WOLD_ToggleInventory", function(_, inputState)
	if inputState == Enum.UserInputState.Begin then
		toggle()
	end
	return Enum.ContextActionResult.Sink
end, false, Enum.KeyCode.I, Enum.KeyCode.B)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	if input.KeyCode == Enum.KeyCode.Escape and gui:IsOpen() then
		gui:Hide()
	end
end)

gui:OnCloseRequested(function()
	gui:Hide()
end)

gui:OnSortRequested(function(tab)
	Remotes.RequestAutoSort:FireServer(tab)
end)

-- Everyone standing close enough to hand something to. Sorted by distance so the nearest person -- almost
-- always the one meant -- is first in the list.
local function nearbyPlayers()
	local myRoot = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not myRoot then return {} end
	local found = {}
	for _, other in ipairs(Players:GetPlayers()) do
		local root = other ~= player and other.Character
			and other.Character:FindFirstChild("HumanoidRootPart")
		if root then
			local distance = (root.Position - myRoot.Position).Magnitude
			if distance <= GIVE_RANGE then
				table.insert(found, { player = other, distance = distance })
			end
		end
	end
	table.sort(found, function(a, b) return a.distance < b.distance end)
	return found
end

-- สกินที่มีในกระเป๋าซึ่งใส่กับชิ้นนี้ได้ (ผู้ใช้กำหนด: สกินแยกตามอาวุธ ชุดแฟชั่นใส่เกราะไหนก็ได้)
local function skinsFor(entry)
	local item = ItemCatalog.Get(entry.id)
	if not item then return {} end
	local out = {}
	-- ⚠️ ช่องว่างมาเป็น `false` ไม่ใช่ช่องที่หายไป (`Inventory.Send` เติมรูให้ครบก่อนส่ง เพราะ sparse array
	-- ข้าม RemoteEvent ไม่ได้) — `slot.id` บน false คือ error ที่กินทั้งเมนู ไม่ใช่แค่รายการสกิน
	for index, slot in pairs(latest.slots or {}) do
		local skin = slot and ItemCatalog.Get(slot.id)
		if skin and ((item.kind == "weapon" and skin.kind == "skin" and skin.skinFor == entry.id)
			or (item.kind == "armor" and skin.kind == "fashion")) then
			out[#out + 1] = { index = tonumber(index), name = skin.name }
		end
	end
	table.sort(out, function(a, b) return a.index < b.index end)
	return out
end

-- ปุ่ม "ติดตั้งสกิน" (เปิดรายการสกินที่ใส่ได้) และ "ถอดสกิน" บนอาวุธ/เกราะ target = "bag:<i>" | "equipped:<kind>"
addSkinEntries = function(entries, anchorButton, title, target, entry)
	-- กับดัก (เฟส 3): เลือกกระสุนที่จะใช้ (`meta.ammo`) · กับดักสนามกระสุนติดมาแล้ว ไม่มีให้เลือก
	local trap = TrapConfig.Traps[entry.id]
	if trap and not trap.fixedAmmo then
		local current = TrapConfig.SelectedAmmo(entry.id, entry.meta, latest.slots)
		table.insert(entries, { label = ("กระสุน: %s (เปลี่ยน)"):format(current and current.name or "ยังไม่มี"), onClick = function()
			local picks = {}
			for _, ammo in ipairs(TrapConfig.Ammo) do
				local _, count = TrapConfig.SelectedAmmo(entry.id, { ammo = ammo.id }, latest.slots)
				table.insert(picks, { label = ("%s (%d)"):format(ammo.name, count), onClick = function()
					Remotes.RequestTrapAmmo:FireServer(target, ammo.id)
				end })
			end
			gui:ShowItemMenu(anchorButton, picks, "เลือกกระสุนกับดัก")
		end })
	end
	local options = skinsFor(entry)
	if #options > 0 then
		table.insert(entries, { label = ("ติดตั้งสกิน (%d)"):format(#options), onClick = function()
			local picks = {}
			for _, o in ipairs(options) do
				table.insert(picks, { label = o.name, onClick = function()
					Remotes.RequestSkin:FireServer("install", target, o.index)
				end })
			end
			gui:ShowItemMenu(anchorButton, picks, "เลือกสกิน")
		end })
	end
	if entry.meta and entry.meta.skin then
		table.insert(entries, { label = "ถอดสกิน", onClick = function()
			Remotes.RequestSkin:FireServer("remove", target)
		end })
	end
end

-- Tapping an item opens a small menu beside it rather than acting at once. Using, giving and dropping are
-- three very different outcomes -- one of them destroys the item -- and a single tap that picked one of them
-- for you was the wrong shape.
gui:OnSlotClicked(function(index)
	local slot = latest.slots and latest.slots[index]
	if not slot then return end
	local item = ItemCatalog.Get(slot.id)
	if not item then return end

	local button = gui:SlotButton(index)
	if not button then return end

	-- Shown at the top of the menu. The catalog name rather than the id, because that is what the player
	-- sees on the icon, and the count so "ทิ้ง" on a stack says how much is about to go.
	local title = ItemCatalog.DisplayName(slot.id, slot.meta)
	if (slot.count or 1) > 1 then
		title = ("%s x%d"):format(title, slot.count)
	end

	local entries = {}

	-- "Use" only for things that can be used. Junk has no use, so it gets no button rather than a button
	-- that does nothing.
	if item.use and item.use.stat == "clanoutfit" then
		-- แหวนแคลน: กดได้อย่างเดียวคือใส่/ถอดชุด อยู่ก่อนด่านอื่นเพราะแหวนเป็น token ไม่ใช่ consumable
		table.insert(entries, { label = "ใส่/ถอดชุดแคลน", onClick = function()
			Remotes.RequestUseItem:FireServer(index)
		end })
	elseif item.kind == "weapon" or item.kind == "armor" then
		table.insert(entries, { label = "สวมใส่", onClick = function()
			Remotes.RequestEquip:FireServer(index)
		end })
		addSkinEntries(entries, button, title, "bag:" .. index, slot)
	elseif item.kind == "consumable" then
		table.insert(entries, { label = "ใช้", onClick = function()
			Remotes.RequestUseItem:FireServer(index)
		end })
		-- 🍽️ กินอัตโนมัติเมื่ออาหารเหลือ 10% (ผู้ใช้สั่ง 2026-10-02) · ทีละอย่าง · เฉพาะของที่เติมหลอดอาหาร · ชิ้นขอบทองไม่ถูกกิน
		if ItemCatalog.FillsHunger(slot.id) and not ItemCatalog.IsGoldBorder(slot.meta) then
			local chosen = latest.autoEat == slot.id
			table.insert(entries, { label = chosen and "ยกเลิกกินอัตโนมัติ" or "🍽️ กินอัตโนมัติ", onClick = function()
				Remotes.RequestSetAutoEat:FireServer(not chosen and slot.id or nil)
			end })
		end
	elseif item.kind == "aura" then
		-- ออร่า: ใช้ = เปิด/ปิด ไม่ถูกใช้หมด
		table.insert(entries, { label = "เปิด/ปิดออร่า", onClick = function()
			Remotes.RequestUseItem:FireServer(index)
		end })
	elseif item.kind == "skin" or item.kind == "fashion" then
		-- ทางลัด: ติดกับชิ้นที่สวมอยู่ ถ้าตรงชนิด
		local key = item.kind == "skin" and "weapon" or "armor"
		local worn = latest.equipped and latest.equipped[key]
		if worn and (item.kind == "fashion" or item.skinFor == worn.id) then
			table.insert(entries, { label = "ติดตั้งกับที่สวมอยู่", onClick = function()
				Remotes.RequestSkin:FireServer("install", "equipped:" .. key, index)
			end })
		else
			local base = item.kind == "skin" and ItemCatalog.Get(item.skinFor or "") or nil
			local hint = item.kind == "skin" and ("ใช้กับ: " .. (base and base.name or tostring(item.skinFor)))
				or "ใช้กับเกราะที่สวมอยู่"
			table.insert(entries, { label = hint, onClick = function() end })
		end
	elseif item.kind == "placeable" then
		-- ของวางบนเกาะ: "ใช้" = เข้าโหมดจัดเกาะมุมสูงแล้วหยิบชิ้นนี้ขึ้นมาเลย (IslandBuildController เป็นเจ้าของช่องทาง
		-- หยิบตอนกด ไม่รอไว้ล่วงหน้า) · ผู้ใช้สั่ง 2026-09-25 "เปิดกระเป๋าและกด ใช้ หรือ กด F4"
		if workspace:GetAttribute("IslandMode") == true then
			table.insert(entries, { label = "ใช้ · จัดเกาะ", onClick = function()
				local opener = game.ReplicatedStorage:FindFirstChild("WOLD_StartPlacing")
				if not opener then warn("[Inventory] ไม่พบ WOLD_StartPlacing (IslandBuildController ไม่ได้รัน?)") return end
				gui:Hide()
				opener:Fire(index, slot.id)
			end })
		else
			table.insert(entries, { label = "วางได้บนเกาะฟาร์มเท่านั้น", onClick = function() end })
		end
	end

	-- ใส่ช่องลัด 1-6 จากเมนู — ทางเดียวที่ใช้ได้แน่บนมือถือ (การลากจากกระเป๋าไปแถบล่าง นิ้วบังช่องปลายทาง)
	-- เงื่อนไขเดียวกับการลาก: ของขยะไม่มีอะไรให้กด (QA 2026-09-26)
	if item.kind ~= "junk" then
		table.insert(entries, { label = "ใส่ช่องลัด", onClick = function()
			local picks = {}
			for n = 1, InventoryConfig.HotbarSlots do
				table.insert(picks, { label = ("ช่อง %d"):format(n), onClick = function()
					Remotes.RequestSetHotbar:FireServer(n, slot.id)
				end })
			end
			gui:ShowItemMenu(button, picks, "ใส่ช่องลัดช่องไหน")
		end })
	end

	-- ไม่มีปุ่ม "ให้" สำหรับของประจำตำแหน่ง (ตะหลิวเชฟ แหวนแคลน) ด้วยเหตุผลเดียวกับปุ่มทิ้งของกุญแจรถ
	-- ข้างล่าง: เซิร์ฟเวอร์ปฏิเสธอยู่แล้ว แต่ปุ่มที่กดแล้วได้คำว่า "ไม่ได้" แย่กว่าปุ่มที่ไม่มี
	if not ItemCatalog.IsBound(slot.id) and not ItemCatalog.IsGoldBorder(slot.meta) then
		table.insert(entries, { label = "ให้", onClick = function()
			local nearby = nearbyPlayers()
			if #nearby == 0 then
				gui:ShowItemMenu(button, { { label = "ไม่มีใครอยู่ใกล้", onClick = function() end } }, title)
				return
			end
			-- A second menu of names, in the same place, so it reads as one flow rather than a new window.
			local people = {}
			for _, entry in ipairs(nearby) do
				local other = entry.player
				table.insert(people, {
					label = other.DisplayName ~= "" and other.DisplayName or other.Name,
					onClick = function()
						-- ของกองเดียวถามจำนวนก่อน ของชิ้นเดียวส่งเลย ไม่ต้องให้กดยืนยันเลข 1
						local have = slot.count or 1
						if have <= 1 then
							Remotes.RequestGiveItem:FireServer(index, other, 1)
							return
						end
						gui:ShowCountPrompt(button, ("ให้ %s กี่ชิ้น"):format(title), have, function(count)
							Remotes.RequestGiveItem:FireServer(index, other, count)
						end)
					end,
				})
			end
			gui:ShowItemMenu(button, people, ("ให้ใคร: %s"):format(title))
		end })
	end

	-- No "throw away" for a vehicle key. The server refuses it anyway, but offering a red button that says no
	-- is worse than not offering it: the player has to press it to find out, and the thing they were trying
	-- to do is one they should never have been invited to attempt.
	if ItemCatalog.IsDroppable(slot.id, slot.meta) then
		table.insert(entries, {
			label = "ทิ้ง",
			color = Color3.fromRGB(214, 84, 74), -- red: it is the one choice that destroys the item
			onClick = function()
				Remotes.RequestDropItem:FireServer(index)
			end,
		})
	end

	gui:ShowItemMenu(button, entries, title)
end)

--------------------------------------------------------------------------------
-- Dragging an item from the bag onto a hotbar slot
--------------------------------------------------------------------------------

-- A press on a bag slot might be a tap (use it) or the start of a drag (assign it). They are told apart by
-- distance: a press that never moves far is a tap, and OnSlotClicked handles it as before. Only once the
-- pointer has travelled past this does it become a drag, so an ordinary tap is never stolen.
local DRAG_THRESHOLD = 12 -- pixels

local drag = nil -- { index, id, startedAt, moved, connections }

local function endDrag(dropPosition)
	if not drag then return end
	local current = drag
	drag = nil

	for _, c in ipairs(current.connections) do c:Disconnect() end
	gui:EndDragGhost()

	local hud = HudAccess.Get()
	if hud then hud:HighlightSlot(nil) end
	-- A drag that never moved was a tap; the slot's own Activated has already dealt with it.
	if not current.moved or not hud or not dropPosition then return end

	local slotIndex = hud:SlotAt(dropPosition)
	if slotIndex then
		Remotes.RequestSetHotbar:FireServer(slotIndex, current.id)
	end
end

gui:OnDragStarted(function(index, input)
	local slot = latest.slots and latest.slots[index]
	if not slot then return end
	-- Junk cannot be assigned: there is nothing pressing a slot would do with it.
	local item = ItemCatalog.Get(slot.id)
	if not item or item.kind == "junk" then return end

	endDrag(nil) -- never two at once
	local startPosition = Vector2.new(input.Position.X, input.Position.Y)
	drag = { index = index, id = slot.id, moved = false, connections = {} }

	local moveConn = UserInputService.InputChanged:Connect(function(moved)
		if not drag then return end
		if moved.UserInputType ~= Enum.UserInputType.MouseMovement
			and moved.UserInputType ~= Enum.UserInputType.Touch then
			return
		end
		local position = Vector2.new(moved.Position.X, moved.Position.Y)
		if not drag.moved and (position - startPosition).Magnitude >= DRAG_THRESHOLD then
			drag.moved = true
			gui:BeginDragGhost(item.icon, item.name)
		end
		if drag.moved then
			gui:MoveDragGhost(position)
			local hud = HudAccess.Get()
			if hud then hud:HighlightSlot(hud:SlotAt(position)) end
		end
	end)

	local endConn
	endConn = UserInputService.InputEnded:Connect(function(ended)
		if not drag then return end
		if ended.UserInputType ~= Enum.UserInputType.MouseButton1
			and ended.UserInputType ~= Enum.UserInputType.Touch then
			return
		end
		endDrag(Vector2.new(ended.Position.X, ended.Position.Y))
	end)

	drag.connections = { moveConn, endConn }
end)

-- ช่องสวม: เมนู ถอด / ติดตั้งสกิน / ถอดสกิน (เดิมกดแล้วถอดทันที — ตอนนี้มีสกินให้เลือกจึงต้องเป็นเมนู)
gui:OnEquipSlotClicked(function(kind)
	local worn = latest.equipped and latest.equipped[kind]
	if not worn then return end
	local anchor = gui:EquipSlotButton(kind)
	if not anchor then
		Remotes.RequestUnequip:FireServer(kind)
		return
	end
	local title = ItemCatalog.DisplayName(worn.id, worn.meta)
	local entries = {
		{ label = "ถอด", onClick = function() Remotes.RequestUnequip:FireServer(kind) end },
	}
	addSkinEntries(entries, anchor, title, "equipped:" .. kind, worn)
	gui:ShowItemMenu(anchor, entries, title)
end)
