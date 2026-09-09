-- InventoryController: opens the bag on I (or the touch button), renders what the server sends, and turns
-- clicks into requests. Every decision belongs to the server — this only asks.
--
-- Clicking a slot does the obvious thing for what is in it: weapons and armor equip, consumables are used,
-- junk does nothing. That avoids a context menu, which would be painful on a phone.
while workspace:GetAttribute("IsLobby") == nil do
	task.wait()
end
if workspace:GetAttribute("IsLobby") then return end

local Players = game:GetService("Players")
local ContextActionService = game:GetService("ContextActionService")
local UserInputService = game:GetService("UserInputService")
local InventoryGui = require(game.ReplicatedStorage.UI.InventoryGui)
local ItemCatalog = require(game.ReplicatedStorage.ItemCatalog)

-- How close someone must be to be offered in the "give" list. Arm's length, matching the class actions --
-- handing something over should mean walking to them.
local GIVE_RANGE = 8
local Remotes = require(game.ReplicatedStorage.Remotes)
local HudAccess = require(game.ReplicatedStorage.UI.HudAccess)

local player = Players.LocalPlayer
local gui = InventoryGui.new()
gui.gui.Parent = player:WaitForChild("PlayerGui")

local latest = { slots = {}, equipped = {}, gold = 0, weight = 0, maxWeight = 1 }

Remotes.InventoryUpdate.OnClientEvent:Connect(function(data)
	latest = data
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
local bindable = Instance.new("BindableEvent")
bindable.Name = "WOLD_ToggleInventory"
bindable.Parent = player:WaitForChild("PlayerGui")
bindable.Event:Connect(toggle)

-- I is bound through ContextActionService rather than watched through UserInputService, because I and O are
-- Roblox's built-in camera zoom keys: pressing I opened the bag AND zoomed the camera in. Sinking the action
-- consumes the key before the camera sees it, and leaves zooming on the mouse wheel untouched.
ContextActionService:BindAction("WOLD_ToggleInventory", function(_, inputState)
	if inputState == Enum.UserInputState.Begin then
		toggle()
	end
	return Enum.ContextActionResult.Sink
end, false, Enum.KeyCode.I)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	if input.KeyCode == Enum.KeyCode.Escape and gui:IsOpen() then
		gui:Hide()
	end
end)

gui:OnCloseRequested(function()
	gui:Hide()
end)

gui:OnSortRequested(function()
	Remotes.RequestAutoSort:FireServer()
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

	local entries = {}

	-- "Use" only for things that can be used. Junk has no use, so it gets no button rather than a button
	-- that does nothing.
	if item.kind == "weapon" or item.kind == "armor" then
		table.insert(entries, { label = "สวมใส่", onClick = function()
			Remotes.RequestEquip:FireServer(index)
		end })
	elseif item.kind == "consumable" then
		table.insert(entries, { label = "ใช้", onClick = function()
			Remotes.RequestUseItem:FireServer(index)
		end })
	end

	table.insert(entries, { label = "ให้", onClick = function()
		local nearby = nearbyPlayers()
		if #nearby == 0 then
			gui:ShowItemMenu(button, { { label = "ไม่มีใครอยู่ใกล้", onClick = function() end } })
			return
		end
		-- A second menu of names, in the same place, so it reads as one flow rather than a new window.
		local people = {}
		for _, entry in ipairs(nearby) do
			local other = entry.player
			table.insert(people, {
				label = other.DisplayName ~= "" and other.DisplayName or other.Name,
				onClick = function()
					Remotes.RequestGiveItem:FireServer(index, other)
				end,
			})
		end
		gui:ShowItemMenu(button, people)
	end })

	table.insert(entries, {
		label = "ทิ้ง",
		color = Color3.fromRGB(214, 84, 74), -- red: it is the one choice that destroys the item
		onClick = function()
			Remotes.RequestDropItem:FireServer(index)
		end,
	})

	gui:ShowItemMenu(button, entries)
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

gui:OnEquipSlotClicked(function(kind)
	if latest.equipped and latest.equipped[kind] then
		Remotes.RequestUnequip:FireServer(kind)
	end
end)
