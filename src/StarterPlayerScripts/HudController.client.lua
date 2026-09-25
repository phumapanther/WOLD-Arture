-- HudController: only runs in channel servers (not the lobby, which has its own ChannelSelectController screen).
-- It's always true in Studio Play (Play is always the lobby), so this never shows locally unless you flip the flag.
local FORCE_SHOW_IN_STUDIO_FOR_TESTING = false -- ponytail: flip to true to preview this screen in Play; flip back before publishing

while workspace:GetAttribute("IsLobby") == nil do
	task.wait()
end
if workspace:GetAttribute("IsLobby") and not FORCE_SHOW_IN_STUDIO_FOR_TESTING then return end

local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")
local HudGui = require(game.ReplicatedStorage.UI.HudGui)
local Remotes = require(game.ReplicatedStorage.Remotes)

-- Same as the lobby: no chat/playerlist UI built for this yet.
pcall(function() StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Chat, false) end)
pcall(function() StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false) end)

local player = Players.LocalPlayer
local HudAccess = require(game.ReplicatedStorage.UI.HudAccess)
local gui = HudGui.new()
gui.gui.Parent = player:WaitForChild("PlayerGui")
-- Published so the bag can find the hotbar to drop onto, without either screen requiring the other.
HudAccess.Set(gui)
gui:Show()
if workspace:GetAttribute("ArenaMode") == true then gui:SetArenaMode() end

-- HP, hunger, stamina and armor are all real now, driven by Vitals.lua on the server. Mana is still static
-- (no mana system exists yet).
gui:SetBarFraction("hp", 1)
gui:SetBarFraction("hunger", 1)
gui:SetStaminaFraction(1)
gui:SetArmorFraction(1) -- everyone starts in the bare starter armor, which reads full until it is chipped away
gui:SetManaPips(3) -- real value arrives with the first VitalsUpdate below

-- EXP bar: level and progress toward the next one.
gui:SetExp(1, 0)
Remotes.ProgressionUpdate.OnClientEvent:Connect(function(p)
	local fraction = 0
	if p.expForNext and p.expForNext > 0 and p.expForNext ~= math.huge then
		fraction = p.exp / p.expForNext
	elseif p.expForNext == math.huge then
		fraction = 1 -- level capped: show the bar full rather than empty
	end
	gui:SetExp(p.level, fraction)
end)

Remotes.VitalsUpdate.OnClientEvent:Connect(function(vitals)
	gui:SetBarFraction("hp", vitals.hp)
	gui:SetBarFraction("hunger", vitals.hunger)
	gui:SetStaminaFraction(vitals.stamina)
	gui:SetArmorFraction(vitals.armor)
	gui:SetArmorPoints(vitals.armorPoints)
	gui:SetManaPips(vitals.mana or 0)
	gui:SetBuffs(vitals.buffs)
end)

-- Hotbar: the first six consumables in the bag, so a potion is one key away without opening it. Keys 1-6 and
-- tapping a slot both use the item; the server re-validates the slot either way.
local ItemCatalog = require(game.ReplicatedStorage.ItemCatalog)
local InventoryConfig = require(game.ReplicatedStorage.InventoryConfig)
local UserInputService = game:GetService("UserInputService")

-- The bar shows what the player put there, not the first six consumables the bag happened to hold. The
-- server owns the assignment (it is saved with the profile) and sends it with every inventory update.
local function refreshHotbar(inventory)
	local entries = {}
	for i = 1, InventoryConfig.HotbarSlots do
		local id = inventory.hotbar and inventory.hotbar[i]
		if id then
			local item = ItemCatalog.Get(id)
			if item then
				-- How many of it are actually carried. Zero is not empty: the slot keeps the assignment and
				-- shows dimmed, so drinking your last potion does not lose the arrangement.
				local count = 0
				for _, slot in pairs(inventory.slots or {}) do
					if slot and slot.id == id then count += slot.count or 1 end
				end
				entries[i] = { id = id, count = count, icon = item.icon, name = item.name }
			end
		end
	end
	gui:SetHotbar(entries)
end

-- The server decides what pressing a slot means -- eat it or wear it -- since only it knows what is really
-- in the bag at that moment.
local function useHotbar(index)
	Remotes.RequestUseHotbar:FireServer(index)
end

gui:OnHotbarUsed(useHotbar)

Remotes.InventoryUpdate.OnClientEvent:Connect(refreshHotbar)

local NUMBER_KEYS = {
	[Enum.KeyCode.One] = 1, [Enum.KeyCode.Two] = 2, [Enum.KeyCode.Three] = 3,
	[Enum.KeyCode.Four] = 4, [Enum.KeyCode.Five] = 5, [Enum.KeyCode.Six] = 6,
}
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	if workspace:GetAttribute("ArenaMode") == true then return end -- สนามไม่มีช่องของใช้ 1-6
	local index = NUMBER_KEYS[input.KeyCode]
	if index then useHotbar(index) end
end)

-- ปุ่มร้านพรีเมียม/กาชา/แบทเทิลพาส ในเมนูสามจุด (ผู้ใช้กำหนดตำแหน่ง) เปิดหน้ารวมที่แท็บนั้น
--
-- **หยิบช่องทางตอนกด ไม่ใช่ตอนบูต** เจ้าของช่องทางคือ `PremiumController` (มันเป็นเจ้าของหน้าต่าง)
-- ทรงเดียวกับปุ่มกระเป๋า/หินสื่อสารบนจอสัมผัส — ไม่มีสองสคริปต์ต้องมาถึงพร้อมกัน จึงไม่มีจังหวะให้แพ้
-- ถ้าหน้าจอพรีเมียมยังไม่พร้อมจริงๆ ให้ดังออกมาเป็น warn ไม่ใช่เงียบ (ของเดิมเงียบจนหาไม่เจอว่าพังตรงไหน)
local function openPremium(tab)
	local bindable = player:FindFirstChild("PlayerGui")
	bindable = bindable and bindable:FindFirstChild("WOLD_OpenPremium")
	if bindable then
		bindable:Fire(tab)
	else
		warn("[Hud] ยังไม่มี WOLD_OpenPremium ใน PlayerGui — PremiumController ยังไม่พร้อมหรือหยุดกลางทาง")
	end
end
gui:AddMenuItem("💎 ร้านค้าพรีเมียม", Color3.fromRGB(70, 100, 150), function() openPremium("shop") end)
gui:AddMenuItem("🎰 กาชา", Color3.fromRGB(120, 70, 150), function() openPremium("gacha") end)
gui:AddMenuItem("🎫 แบทเทิลพาส", Color3.fromRGB(150, 110, 40), function() openPremium("pass") end)

gui:OnLobbyRequested(function()
	-- Server-authoritative: it saves the player's position THEN teleports, because PlayerRemoving does not
	-- reliably fire before a client-initiated Teleport actually removes the character (documented Roblox
	-- behavior) — calling TeleportService directly from here lost the save. See PlayerPosition.server.lua.
	Remotes.RequestReturnToLobby:FireServer()
end)
