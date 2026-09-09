-- ArrestController: the client half of an arrest.
--
-- Opens the confiscation window for the guard and a read-only copy for the prisoner, and draws the bound
-- pose on anyone currently under arrest.
--
-- The pose is written to the joints each frame after the animator, the same approach the crawl and the
-- eating pose use: an animation playing underneath would otherwise win.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ArrestGui = require(game.ReplicatedStorage.UI.ArrestGui)
local UiSound = require(game.ReplicatedStorage.UI.UiSound)
local Remotes = require(game.ReplicatedStorage.Remotes)

while workspace:GetAttribute("IsLobby") == nil do
	task.wait()
end
if workspace:GetAttribute("IsLobby") then return end

local player = Players.LocalPlayer
local gui = ArrestGui.new()

--------------------------------------------------------------------------------
-- The bound pose
--------------------------------------------------------------------------------

-- Both arms pulled back and in, wrists together behind the back. Drawn for everyone who is arrested, not
-- just the local player, so a guard can see who they are holding.
local poses = {} -- [player] = RunService connection

local function stopPose(target)
	local conn = poses[target]
	if not conn then return end
	poses[target] = nil
	conn:Disconnect()
end

local function startPose(target)
	stopPose(target)
	local character = target.Character
	if not character then return end
	local leftJoint = character:FindFirstChild("LeftUpperArm")
	local rightJoint = character:FindFirstChild("RightUpperArm")
	local leftShoulder = leftJoint and leftJoint:FindFirstChild("LeftShoulder")
	local rightShoulder = rightJoint and rightJoint:FindFirstChild("RightShoulder")
	if not leftShoulder or not rightShoulder then return end

	local leftLower = character:FindFirstChild("LeftLowerArm")
	local rightLower = character:FindFirstChild("RightLowerArm")
	local leftElbow = leftLower and leftLower:FindFirstChild("LeftElbow")
	local rightElbow = rightLower and rightLower:FindFirstChild("RightElbow")

	poses[target] = RunService.Stepped:Connect(function()
		-- NEGATIVE X swings an R15 arm BEHIND the back, which is the opposite of the eating pose and
		-- exactly what is wanted here. The Z roll brings the wrists together at the spine.
		leftShoulder.Transform = CFrame.Angles(math.rad(-32), 0, math.rad(-20))
		rightShoulder.Transform = CFrame.Angles(math.rad(-32), 0, math.rad(20))
		-- Elbows folded so the forearms cross rather than sticking straight out behind.
		if leftElbow then leftElbow.Transform = CFrame.Angles(math.rad(48), math.rad(28), 0) end
		if rightElbow then rightElbow.Transform = CFrame.Angles(math.rad(48), math.rad(-28), 0) end
	end)
end

local function refreshPose(target)
	if target:GetAttribute("WOLD_Arrested") then
		startPose(target)
	else
		stopPose(target)
	end
end

local function watch(target)
	target:GetAttributeChangedSignal("WOLD_Arrested"):Connect(function()
		refreshPose(target)
	end)
	target.CharacterAdded:Connect(function(character)
		character:WaitForChild("HumanoidRootPart", 10)
		refreshPose(target)
	end)
	refreshPose(target)
end

for _, other in ipairs(Players:GetPlayers()) do watch(other) end
Players.PlayerAdded:Connect(watch)
Players.PlayerRemoving:Connect(stopPose)

--------------------------------------------------------------------------------
-- The window
--------------------------------------------------------------------------------

gui:On("take", function(slots, fine)
	Remotes.RequestArrestTake:FireServer(slots, fine)
end)

gui:On("confirm", function()
	Remotes.RequestArrestConfirm:FireServer()
end)

gui:On("release", function()
	Remotes.RequestArrestRelease:FireServer()
end)

Remotes.ArrestStateChanged.OnClientEvent:Connect(function(event, other, payload)
	local asGuard = payload and payload.role == "guard"
	if event == "opened" then
		gui:Open(other, asGuard)
	elseif event == "update" then
		if not gui:IsOpen() then gui:Open(other, asGuard) end
		gui:Render(payload)
	elseif event == "completed" then
		if payload and (payload.fine or 0) > 0 then UiSound.Play("Coin") end
		gui:Close()
	elseif event == "closed" then
		gui:Close()
	end
end)
