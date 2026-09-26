-- ActionController: turns Ctrl into a roll or slide request and plays the resulting animations. Intent only —
-- the server decides whether the action happens, spends the stamina, and moves the character.
--
--   Ctrl while moving        -> roll in the WASD direction
--   Ctrl while sprinting     -> slide (W + Shift + Ctrl, as the user described it)
--
-- "Sprinting" is the server's own answer, published by PlayerMovement as the player attribute WOLD_Sprinting —
-- the same flag the touch button reads. (It used to be guessed from WalkSpeed >= 12, which a heavy bag or a
-- slow effect could pull under the line while still running.)
while workspace:GetAttribute("IsLobby") == nil do
	task.wait()
end
if workspace:GetAttribute("IsLobby") then return end

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ActionConfig = require(game.ReplicatedStorage.ActionConfig)
local Remotes = require(game.ReplicatedStorage.Remotes)

local player = Players.LocalPlayer
local tracks = {} -- rebuilt per character; the Animator is recreated with it

local function loadTracks(character)
	tracks = {}
	local humanoid = character:WaitForChild("Humanoid")
	local animator = humanoid:WaitForChild("Animator")

	local function load(id, priority, looped)
		if not id or id == "" then return nil end -- unpublished: the action still works, just silently
		local anim = Instance.new("Animation")
		anim.AnimationId = id
		local ok, track = pcall(function() return animator:LoadAnimation(anim) end)
		if not ok then
			warn("[Action] failed to load animation", id, track)
			return nil
		end
		track.Priority = priority
		track.Looped = looped or false
		return track
	end

	tracks.roll = load(ActionConfig.Roll.animation, Enum.AnimationPriority.Action3)
	tracks.slideEnter = load(ActionConfig.Slide.enterAnimation, Enum.AnimationPriority.Action3)
	tracks.slideHold = load(ActionConfig.Slide.holdAnimation, Enum.AnimationPriority.Action3, true)
end

local function onCharacterAdded(character)
	loadTracks(character)
end
player.CharacterAdded:Connect(onCharacterAdded)
if player.Character then onCharacterAdded(player.Character) end

-- Exposed so the touch button can trigger the same path as the key.
local function requestAction()
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end

	if player:GetAttribute("WOLD_Sprinting") then -- ตั้งโดย PlayerMovement ฝั่งเซิร์ฟ
		Remotes.RequestSlide:FireServer()
	else
		-- Roll goes where the player is steering; the server re-checks and flattens this.
		local direction = humanoid.MoveDirection
		if direction.Magnitude < 0.1 then return end -- standing still: nothing to roll into
		Remotes.RequestRoll:FireServer(direction)
	end
end
-- The touch button fires the same path as the Ctrl key. A BindableEvent rather than a global: it is the
-- supported way for two LocalScripts to talk, and it cannot be clobbered by load order.
-- ⚠️ ช่องทางอยู่ใน ReplicatedStorage (สร้างฝั่งไคลเอนต์ = มีแค่เครื่องนี้) **ห้ามไว้ใน PlayerGui** — ตัวละครเกิดทีไร
-- Roblox ล้าง PlayerGui ทุกอย่างยกเว้น ScreenGui ที่ ResetOnSpawn=false ช่องทางหายเงียบๆ ปุ่มมือถือตายทั้งแถบ
-- (สนาม PVP เกิดตัวละครหลังสคริปต์เริ่มและทุกรอบ = ตายตั้งแต่ต้น · เกมหลักตายหลังตายครั้งแรก) QA 2026-09-26
local bindable = Instance.new("BindableEvent")
bindable.Name = "WOLD_RequestAction"
bindable.Parent = game.ReplicatedStorage
bindable.Event:Connect(requestAction)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	if input.KeyCode == Enum.KeyCode.LeftControl or input.KeyCode == Enum.KeyCode.RightControl then
		requestAction()
	end
end)

-- Playback for everyone, driven by the server so all clients see the same thing.
--
-- `sliding` guards the delayed hold: under lag "slide" and "slide_end" can arrive in the same burst, and the
-- old version stopped a hold that had not started yet, then started it 0.2 s later -- looped, with nothing
-- left to stop it. That is the frozen slide pose the user photographed.
local sliding = false
Remotes.MoveStateChanged.OnClientEvent:Connect(function(who, event)
	if who ~= player then return end -- other players animate through their own replicated tracks
	if event == "roll" then
		if tracks.roll then tracks.roll:Play(0.05) end
	elseif event == "slide" then
		sliding = true
		if tracks.slideEnter then tracks.slideEnter:Play(0.05) end
		if tracks.slideHold then
			-- Hold takes over as the entry finishes, so the pose is continuous rather than snapping back.
			task.delay(0.2, function()
				if sliding and tracks.slideHold then tracks.slideHold:Play(0.1) end
			end)
		end
	elseif event == "roll_end" then
		if tracks.roll then tracks.roll:Stop(0.15) end
	elseif event == "slide_end" then
		sliding = false
		if tracks.slideEnter then tracks.slideEnter:Stop(0.15) end
		if tracks.slideHold then tracks.slideHold:Stop(0.2) end
	end
end)

-- A new character is never mid-slide; the flag must not carry a stale "true" into its fresh tracks.
player.CharacterAdded:Connect(function() sliding = false end)
