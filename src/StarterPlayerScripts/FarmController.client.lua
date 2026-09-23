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
-- ในสนาม PVP ไม่มีฟาร์ม · เอกสารออกแบบเตือนไว้ตรงๆ ว่าปุ่ม F ของฟาร์มออโต้จะถูกลากมาด้วยโดยไม่ตั้งใจ
if workspace:GetAttribute("ArenaMode") == true then return end

local TAG = "WOLD_Farm"
local SHOW_DISTANCE = 60

local Labels = {} -- [node] = BillboardGui

local function anchorOf(node)
	if node:IsA("BasePart") then return node end
	-- Whatever is there RIGHT NOW. Nothing waits any more: the loop below asks again in half a second, so a
	-- part that has not replicated yet costs one tick rather than the whole session.
	return node:FindFirstChild("FarmAnchor") or node.PrimaryPart
		or node:FindFirstChildWhichIsA("BasePart", true)
end

-- Built the first time there is actually a countdown to draw, not up front.
--
-- Attaching in advance was the bug. The label hangs off the invisible FarmAnchor the SERVER plants at the
-- model's base, and with StreamingEnabled the tag, the model's parts and that anchor reach a client in
-- separate batches -- seconds apart on a phone. Every version of "attach once, early" loses that race on
-- some nodes, and the node it loses on is different every run, which is exactly how the bug behaved: the
-- countdown missing from *some* spots, never the same ones.
--
-- Nothing is scheduled, waited for or remembered here. The tick loop re-asks twice a second forever, so a
-- node whose anchor arrives late gets its label the moment the anchor exists, and one that streams out and
-- back in gets a new one. Eighteen nodes is nothing to walk every half second.
local function labelFor(node)
	local existing = Labels[node]
	if existing and existing.Parent then return existing end

	local anchor = anchorOf(node)
	if not anchor then return nil end

	local gui = Instance.new("BillboardGui")
	gui.Name = "FarmCooldown"
	gui.Size = UDim2.fromOffset(120, 28)
	gui.StudsOffsetWorldSpace = Vector3.new(0, 4.5, 0)
	gui.MaxDistance = SHOW_DISTANCE
	gui.AlwaysOnTop = true
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
	return gui
end

-- Twice a second is enough for a clock counting whole seconds, and it keeps a field of nodes off the frame
-- budget entirely.
task.spawn(function()
	while true do
		task.wait(0.5)
		local now = workspace:GetServerTimeNow()

		-- Nodes that have been destroyed or streamed away take their label with them.
		for node, gui in pairs(Labels) do
			if not node.Parent then
				Labels[node] = nil
				if gui.Parent then gui:Destroy() end
			end
		end

		for _, node in ipairs(CollectionService:GetTagged(TAG)) do
			local readyAt = node:GetAttribute("FarmReadyAt")
			local left = type(readyAt) == "number" and (readyAt - now) or 0
			if left > 0 then
				local gui = labelFor(node)
				if gui then
					gui.Enabled = true
					local label = gui:FindFirstChildWhichIsA("TextLabel")
					if label then
						label.Text = ("รออีก %d:%02d"):format(math.floor(left / 60), math.floor(left % 60))
					end
				end
			else
				local gui = Labels[node]
				if gui then gui.Enabled = false end
			end
		end
	end
end)
