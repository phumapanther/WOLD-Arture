-- ShopController: opens the shop window when the server sends a price list, and sends taps back.
--
-- Thin on purpose. The server pushes a whole snapshot every time anything changes, so this never patches
-- the window or works out what a thing costs -- it draws what it was handed and reports which row was hit.
local Players = game:GetService("Players")

while workspace:GetAttribute("IsLobby") == nil do
	task.wait()
end
if workspace:GetAttribute("IsLobby") then return end

local ShopGui = require(game.ReplicatedStorage.UI.ShopGui)
local Remotes = require(game.ReplicatedStorage.Remotes)

local gui = ShopGui.new()

gui:OnBuy(function(index)
	Remotes.RequestShopAction:FireServer("buy", index)
end)

gui:OnSell(function(slot)
	Remotes.RequestShopAction:FireServer("sell", slot)
end)

-- Sent both when the prompt is used and after every purchase, so the window redraws itself from the
-- server's own figures rather than guessing what changed.
Remotes.ShopOpen.OnClientEvent:Connect(function(snapshot)
	gui:Show(snapshot)
end)

-- Walking away closes the counter. Checked here rather than on the server because it is a matter of
-- presentation -- the server re-checks the distance on every buy and sell regardless, which is the part
-- that has to be trusted.
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
				for _, npc in ipairs(game:GetService("CollectionService"):GetTagged("WOLD_Npc")) do
					if npc:GetAttribute("NpcKind") == "shop" then
						local position = npc:IsA("BasePart") and npc.Position or npc:GetPivot().Position
						if (position - root.Position).Magnitude <= 16 then near = true break end
					end
				end
				if not near then gui:Hide() end
			end
		end
	end
end)
