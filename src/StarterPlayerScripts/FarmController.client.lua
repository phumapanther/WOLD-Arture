-- FarmController: the countdown that hangs over a worked-out still, pipe or crate.
--
-- Drawn on the client from one number the server publishes (`FarmReadyAt`, in server time), rather than by
-- the server pushing a new string every second. Ten nodes ticking down would otherwise be ten property
-- replications a second forever, for a label most players are not looking at.
--
-- GetServerTimeNow is what makes that safe: it is the same clock on every machine in the server, so a
-- deadline written by the server means the same instant here.
local CollectionService = game:GetService("CollectionService")

while workspace:GetAttribute("IsLobby") == nil do
	task.wait()
end
if workspace:GetAttribute("IsLobby") then return end

local TAG = "WOLD_Farm"
local SHOW_DISTANCE = 60

local Labels = {} -- [node] = TextLabel

local function anchorOf(node)
	if node:IsA("BasePart") then return node end
	return node:FindFirstChild("FarmAnchor") or node.PrimaryPart
		or node:FindFirstChildWhichIsA("BasePart", true)
end

local function attach(node)
	if Labels[node] then return end
	local anchor = anchorOf(node)
	if not anchor then return end

	local gui = Instance.new("BillboardGui")
	gui.Name = "FarmCooldown"
	gui.Size = UDim2.fromOffset(120, 28)
	gui.StudsOffsetWorldSpace = Vector3.new(0, 4.5, 0)
	gui.MaxDistance = SHOW_DISTANCE
	gui.AlwaysOnTop = true
	gui.Enabled = false
	gui.Parent = anchor

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundColor3 = Color3.fromRGB(20, 22, 28)
	label.BackgroundTransparency = 0.25
	label.BorderSizePixel = 0
	label.Font = Enum.Font.GothamBold
	label.TextSize = 14
	label.TextColor3 = Color3.fromRGB(226, 96, 84)
	label.Text = ""
	label.Parent = gui

	local round = Instance.new("UICorner")
	round.CornerRadius = UDim.new(0, 6)
	round.Parent = label

	Labels[node] = gui
end

for _, node in ipairs(CollectionService:GetTagged(TAG)) do
	attach(node)
end
CollectionService:GetInstanceAddedSignal(TAG):Connect(attach)
CollectionService:GetInstanceRemovedSignal(TAG):Connect(function(node)
	local gui = Labels[node]
	Labels[node] = nil
	if gui then gui:Destroy() end
end)

-- Twice a second is enough for a clock counting whole seconds, and it keeps a field of nodes off the frame
-- budget entirely.
task.spawn(function()
	while true do
		task.wait(0.5)
		local now = workspace:GetServerTimeNow()
		for node, gui in pairs(Labels) do
			if not node.Parent or not gui.Parent then
				Labels[node] = nil
				if gui.Parent then gui:Destroy() end
			else
				local readyAt = node:GetAttribute("FarmReadyAt")
				local left = type(readyAt) == "number" and (readyAt - now) or 0
				if left > 0 then
					gui.Enabled = true
					local label = gui:FindFirstChildWhichIsA("TextLabel")
					if label then
						label.Text = ("รออีก %d:%02d"):format(math.floor(left / 60), math.floor(left % 60))
					end
				else
					gui.Enabled = false
				end
			end
		end
	end
end)
