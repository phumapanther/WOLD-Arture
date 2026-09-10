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
local UiSound = require(game.ReplicatedStorage.UI.UiSound)
local Remotes = require(game.ReplicatedStorage.Remotes)

local gui = ShopGui.new()

-- Coins, on money actually changing hands. Played when the SERVER confirms rather than on the tap, so a
-- refused purchase -- not enough gold, full bag, walked away -- stays silent instead of lying about it.
local pendingCoin = false

gui:OnBuy(function(index, amount)
	pendingCoin = true
	-- amount nil means one; the server clamps whatever it is told to what the purse can afford.
	Remotes.RequestShopAction:FireServer("buy", index, amount)
end)

gui:OnSell(function(slot, amount)
	pendingCoin = true
	-- amount nil means the whole stack; the server clamps whatever it is told to what the slot holds.
	Remotes.RequestShopAction:FireServer("sell", slot, amount)
end)

gui:OnSellAll(function()
	pendingCoin = true
	Remotes.RequestShopAction:FireServer("sellall")
end)

-- Sent both when the prompt is used and after every purchase, so the window redraws itself from the
-- server's own figures rather than guessing what changed.
Remotes.ShopOpen.OnClientEvent:Connect(function(snapshot)
	gui:Show(snapshot)
	-- A snapshot arriving with a trade outstanding IS the confirmation: the server only re-sends one after
	-- a buy or sell it accepted. A refusal comes back as a SocialNotify and no snapshot at all.
	if pendingCoin then
		pendingCoin = false
		UiSound.Play("Coin")
	end
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
