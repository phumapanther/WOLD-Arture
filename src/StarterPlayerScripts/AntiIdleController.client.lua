-- AntiIdleController: keeps Roblox from disconnecting a player for standing still.
--
-- Roblox ships an idle timer of its own: about twenty minutes with no input at all and the player is
-- dropped, whatever the game thinks about it. For most games that is sensible. For a roleplay game it is
-- wrong -- sitting still IS the activity. Somebody sitting cross-legged in the tavern listening to two other
-- people talk is playing, and the server was throwing them out for it.
--
-- HOW IT IS SWITCHED OFF
--
-- The timer cannot be configured, but it can be answered. Player.Idled fires when Roblox has decided a
-- player has gone quiet -- shortly BEFORE the disconnect, not after -- and any real input resets it.
-- VirtualUser supplies that input on the player's behalf, and the clock starts again.
--
-- Note this is the standard way to do it and a great many published games use it, but Roblox documents
-- VirtualUser as being meant for automated testing rather than for this. Nothing here fakes gameplay: the
-- click is a right-button press at the origin, which does nothing in this game -- it exists only to be
-- noticed by the idle timer.
--
-- Client-side because the idle timer is: the server never sees the input that would have reset it.
local Players = game:GetService("Players")
local VirtualUser = game:GetService("VirtualUser")

local player = Players.LocalPlayer

player.Idled:Connect(function()
	-- CaptureController first, or the click has no controller to come from and is ignored.
	VirtualUser:CaptureController()
	-- Button TWO: the right mouse button. Button one would be a real click on whatever is under the cursor,
	-- which at twenty minutes of standing in a town square could be a shop prompt or another player.
	VirtualUser:ClickButton2(Vector2.new())
end)
