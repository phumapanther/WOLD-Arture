-- ClassActionController: the prompts your class puts on the players around you.
--
-- Which prompts exist depends on your own class, so they are rebuilt when it changes. They appear only on
-- players who are UP -- a downed player belongs to the rescue prompts, and the two sets never show at once,
-- which is why they can share the E and F keys.
--
-- Nothing here is trusted: the server re-checks the class, the distance and the money on every request. A
-- prompt that should not be there would simply be refused.
local Players = game:GetService("Players")
local ClassActionConfig = require(game.ReplicatedStorage.ClassActionConfig)
local ClassActionGui = require(game.ReplicatedStorage.UI.ClassActionGui)
local Remotes = require(game.ReplicatedStorage.Remotes)
local UiSound = require(game.ReplicatedStorage.UI.UiSound)

while workspace:GetAttribute("IsLobby") == nil do
	task.wait()
end
if workspace:GetAttribute("IsLobby") then return end

local player = Players.LocalPlayer
local gui = ClassActionGui.new()

local prompts = {} -- [target] = { ProximityPrompt, ... }

-- **ปุ่มที่ติดคูลดาวน์ต้องซ่อนเสมอ** (ผู้ใช้สั่ง 2026-09-25) · ขอเงินมีคูลดาวน์ของคนขอ (ClassActionConfig.Beg)
-- ใช้ได้กับทุกเป้าหมาย จึงซ่อนที่นี่ฝั่งไคลเอนต์ นับจากตอนกดเอง (+0.5 วิเผื่อเวลาที่คำขอวิ่งไปถึงเซิร์ฟเวอร์)
local COOLDOWN = { beg = ClassActionConfig.Beg.cooldownSeconds }
local coolUntil = {} -- [actionId] = os.clock ที่ปุ่มกลับมา

local function applyCooldowns()
	for _, held in pairs(prompts) do
		for _, prompt in ipairs(held) do
			local readyAt = coolUntil[prompt:GetAttribute("ActionId")]
			if readyAt and prompt.Parent then prompt.Enabled = os.clock() >= readyAt end
		end
	end
end

--------------------------------------------------------------------------------

local function clearPrompts(target)
	local held = prompts[target]
	if not held then return end
	prompts[target] = nil
	for _, prompt in ipairs(held) do
		if prompt.Parent then prompt:Destroy() end
	end
end

local function myActions()
	local list = {}
	for _, tier in ipairs({ "WOLD_ClassBasic", "WOLD_ClassAdvanced", "WOLD_ClassElite" }) do
		for _, action in ipairs(ClassActionConfig.ForClass(player:GetAttribute(tier))) do
			-- Two classes can grant the same action (Rogue and Beggar both rob); one prompt is enough.
			local seen = false
			for _, existing in ipairs(list) do
				if existing.id == action.id then seen = true break end
			end
			if not seen then table.insert(list, action) end
		end
	end
	return list
end

local function buildPrompts(target)
	clearPrompts(target)
	if target == player then return end
	local character = target.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then return end
	-- Downed players belong to the rescue prompts. Checked from the attribute the server keeps in step,
	-- rather than guessed at.
	if target:GetAttribute("WOLD_Downed") then return end
	-- Nothing at all is offered on or by a passenger.
	--
	-- Being carried is NOT being downed -- a consented carry lifts someone perfectly healthy -- so the test
	-- above lets a passenger straight through, and these prompts went on appearing over the head of someone
	-- riding on a back. The server already refuses every one of them; this is what stops the button being
	-- drawn in the first place.
	--
	-- Both directions: no prompts ON someone being carried, and none AT ALL for a player who is being
	-- carried themselves, whoever they belong to.
	if target:GetAttribute("WOLD_BeingCarried") then return end
	if player:GetAttribute("WOLD_BeingCarried") then return end

	local actions = myActions()
	if #actions == 0 then return end

	local held = {}
	for order, action in ipairs(actions) do
		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = action.label
		prompt.ObjectText = target.DisplayName
		prompt.KeyboardKeyCode = action.key
		prompt.MaxActivationDistance = ClassActionConfig.Range
		prompt.RequiresLineOfSight = false
		prompt.HoldDuration = action.hold or 0
		prompt.UIOffset = Vector2.new(0, (order - 1) * 44)
		prompt:SetAttribute("ActionId", action.id)
		local readyAt = coolUntil[action.id]
		if readyAt and os.clock() < readyAt then prompt.Enabled = false end
		prompt.Parent = root

		prompt.Triggered:Connect(function()
			-- Two of these need a number or a choice before anything is sent; the rest go straight off.
			if action.id == "give" then
				gui:AskAmount(target, function(amount)
					Remotes.RequestClassAction:FireServer("give", target, amount)
				end)
			elseif action.id == "heal" then
				gui:AskHealSize(target, function(size)
					Remotes.RequestClassAction:FireServer("heal", target, size)
				end)
			else
				Remotes.RequestClassAction:FireServer(action.id, target)
			end
			local wait = COOLDOWN[action.id]
			if wait then
				coolUntil[action.id] = os.clock() + wait + 0.5
				applyCooldowns()
				task.delay(wait + 0.6, applyCooldowns)
			end
		end)
		table.insert(held, prompt)
	end
	prompts[target] = held
end

local function rebuildAll()
	for _, other in ipairs(Players:GetPlayers()) do
		buildPrompts(other)
	end
end

--------------------------------------------------------------------------------
-- Keeping them in step
--------------------------------------------------------------------------------

local function watch(target)
	if target == player then return end
	target.CharacterAdded:Connect(function(character)
		character:WaitForChild("HumanoidRootPart", 10)
		buildPrompts(target)
	end)
	-- Going down takes the prompts away; getting up brings them back.
	target:GetAttributeChangedSignal("WOLD_Downed"):Connect(function()
		buildPrompts(target)
	end)
	-- Being picked up and put down does the same.
	target:GetAttributeChangedSignal("WOLD_BeingCarried"):Connect(function()
		buildPrompts(target)
	end)
	buildPrompts(target)
end

-- When WE are picked up or put down, every prompt we can see has to be re-decided at once: the per-target
-- listeners above only fire for the player they watch, and none of them watches us.
player:GetAttributeChangedSignal("WOLD_BeingCarried"):Connect(rebuildAll)

for _, other in ipairs(Players:GetPlayers()) do watch(other) end
Players.PlayerAdded:Connect(watch)
Players.PlayerRemoving:Connect(clearPrompts)

-- Our own class changing changes every prompt in the world.
for _, tier in ipairs({ "WOLD_ClassBasic", "WOLD_ClassAdvanced", "WOLD_ClassElite" }) do
	player:GetAttributeChangedSignal(tier):Connect(rebuildAll)
end

--------------------------------------------------------------------------------
-- Being on the receiving end
--------------------------------------------------------------------------------

Remotes.ClassActionPrompt.OnClientEvent:Connect(function(actionId, fromPlayer, seconds, question)
	-- ฮีล/ซ่อมที่เราต้องจ่ายเงิน — เซิร์ฟเวอร์เขียนคำถามมาให้ (ราคาอยู่ในนั้น) · QA 2026-09-26
	if actionId == "service" then
		gui:AskConsent(fromPlayer, seconds, tostring(question or "มีคนขอให้บริการ"),
			function(accepted)
				Remotes.RespondClassAction:FireServer("service", accepted)
			end)
	elseif actionId == "rob" then
		gui:ShowRobDefence(fromPlayer, seconds, function()
			Remotes.RespondClassAction:FireServer("rob", false)
		end)
	elseif actionId == "carry" then
		gui:AskConsent(fromPlayer, seconds,
			("%s ขออุ้มคุณ"):format(fromPlayer and fromPlayer.DisplayName or "ใครบางคน"),
			function(accepted)
				Remotes.RespondClassAction:FireServer("carry", accepted)
			end)
	elseif actionId == "trade" then
		gui:AskConsent(fromPlayer, seconds,
			("%s ขอเทรดกับคุณ"):format(fromPlayer and fromPlayer.DisplayName or "ใครบางคน"),
			function(accepted)
				Remotes.RespondClassAction:FireServer("trade", accepted)
			end)
	end
end)

-- The noise a successful action makes. Only on success: a refused give should not sound like coins
-- changing hands. Both parties get the result event, so both hear it, which is right for money -- a
-- transfer happens between two people rather than to one.
local SOUND_FOR = {
	give = "Coin",
	rob = "Coin",
	repair = "Repair",
}

Remotes.ClassActionResult.OnClientEvent:Connect(function(actionId, ok, message, other, extra)
	gui:Notify(ok, message, other)
	if ok then
		local sound = SOUND_FOR[actionId]
		if sound then UiSound.Play(sound) end
	end
end)
