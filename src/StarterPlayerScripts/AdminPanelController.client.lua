-- AdminPanelController: F3 opens the admin roster.
--
-- The key is bound for everyone, because the client cannot be told who the admins are without telling every
-- client who the admins are. Pressing it simply asks the server for the panel data; a non-admin is answered
-- with silence and never sees a window. That is the same shape the slash commands use.
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local Remotes = require(game.ReplicatedStorage.Remotes)
local AdminPanelGui = require(game.ReplicatedStorage.UI.AdminPanelGui)

local gui = AdminPanelGui.new()

gui:On("action", function(action, userId, value)
	Remotes.RequestAdminAction:FireServer(action, userId, value)
end)

-- The server answers a request only for an admin, so the window opens when the data arrives rather than when
-- the key is pressed. A non-admin pressing F3 gets nothing at all -- not a locked panel, not an error.
Remotes.AdminPanelData.OnClientEvent:Connect(function(data)
	gui:Render(data)
	-- Refreshes arrive whenever anything changes, including while the panel is closed. Only the first one
	-- after a keypress should open it.
	if gui.pendingOpen then
		gui.pendingOpen = false
		gui:Show()
	end
end)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	if input.KeyCode ~= Enum.KeyCode.F3 then return end
	if gui:IsOpen() then
		gui:Hide()
	else
		gui.pendingOpen = true
		Remotes.RequestAdminPanel:FireServer()
	end
end)
