-- VaultController: opens Madam Aurelia's counter when the server sends a snapshot, and reports taps back.
--
-- Thin, like ShopController. The server pushes a whole picture after every action -- accepted or refused --
-- so this never patches the window and never works out what a move would do.
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")

while workspace:GetAttribute("IsLobby") == nil do
	task.wait()
end
if workspace:GetAttribute("IsLobby") then return end

local VaultGui = require(game.ReplicatedStorage.UI.VaultGui)
local UiSound = require(game.ReplicatedStorage.UI.UiSound)
local Remotes = require(game.ReplicatedStorage.Remotes)

local gui = VaultGui.new()

-- Coins, on money actually moving. Played when the SERVER answers rather than on the tap, so a refused
-- transfer stays silent instead of sounding like it worked.
local pendingCoin = false

gui:On("deposit", function(amount)
	pendingCoin = true
	Remotes.RequestVaultAction:FireServer("deposit", nil, amount)
end)

gui:On("withdraw", function(amount)
	pendingCoin = true
	Remotes.RequestVaultAction:FireServer("withdraw", nil, amount)
end)

-- `count` nil means the whole stack; the server clamps whatever it is told to what the slot holds.
gui:On("store", function(slot, count)
	Remotes.RequestVaultAction:FireServer("store", slot, count)
end)

gui:On("take", function(slot, count)
	Remotes.RequestVaultAction:FireServer("take", slot, count)
end)

Remotes.VaultOpen.OnClientEvent:Connect(function(snapshot)
	gui:Show(snapshot)
	if pendingCoin then
		pendingCoin = false
		UiSound.Play("Coin")
	end
end)

-- Walking away closes the counter. Presentation only -- the server re-checks the distance on every action,
-- which is the part that has to be trusted.
task.spawn(function()
	while true do
		task.wait(0.5)
		if gui:IsOpen() then
			local character = Players.LocalPlayer.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			if not root then
				gui:Hide()
			else
				local near = false
				for _, npc in ipairs(CollectionService:GetTagged("WOLD_Npc")) do
					if npc:GetAttribute("NpcKind") == "bank" then
						local position = npc:IsA("BasePart") and npc.Position or npc:GetPivot().Position
						if (position - root.Position).Magnitude <= 16 then
							near = true
							break
						end
					end
				end
				if not near then gui:Hide() end
			end
		end
	end
end)
