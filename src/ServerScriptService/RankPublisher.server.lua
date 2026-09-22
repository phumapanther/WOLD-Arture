-- RankPublisher.server.lua: ส่งเลเวลกับเงินของคนในเซิร์ฟเวอร์นี้ขึ้นตารางอันดับของทั้งเกม
--
-- **แยกจาก `Leaderboards.server` โดยตั้งใจ** ไฟล์นั้นเป็นเจ้าของ "การแสดงผล" และถูกกันออกจากเพลสเกาะ
-- (`farming.project.json`) เพราะตารางแบบในเซิร์ฟไม่มีความหมายบนเกาะส่วนตัว — แต่ **การเขียน** ต้องเกิด
-- ทุกที่ที่คนเล่นอยู่ ไม่งั้นเวลาที่ใช้บนเกาะจะไม่เคยถูกนับ แล้วคนที่เล่นฟาร์มอย่างเดียวจะไม่มีชื่อในตารางเลย
--
-- เขียนเป็นรอบ ไม่ใช่ทุกครั้งที่ค่าขยับ: OrderedDataStore มีโควตาเขียน และเงินขยับทุกครั้งที่ขายของชิ้นเดียว
-- `GlobalRanks.Write` เงียบเองเมื่อค่าไม่เปลี่ยนจากรอบก่อน รอบที่ไม่มีใครทำอะไรจึงไม่ยิง DataStore เลย
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local ServerConfig = require(game.ServerScriptService.ServerConfig)
-- ล็อบบี้ไม่เปิดเซสชันโปรไฟล์ (จะไปแย่งล็อกกับเซิร์ฟที่เขากำลังเล่น) จึงไม่มีค่าอะไรให้เขียน
if ServerConfig.IsLobby then return end

local Progression = require(game.ServerScriptService.Progression)
local Inventory = require(game.ServerScriptService.Inventory)
local Bank = require(game.ServerScriptService.Bank)
local GlobalRanks = require(game.ServerScriptService.GlobalRanks)

local EVERY_SECONDS = 120

-- เงิน = ติดตัว + ในธนาคาร · เหมือนที่ตารางเดิมคิด
--
-- **ต้องรวมสองอย่าง** ไม่งั้น "คนรวยที่สุด" จะกลายเป็นคนที่พกเงินสดเยอะที่สุด ซึ่งคนละเรื่องกับรวย
-- และจะสอนให้คนไม่ฝากเงินเพื่อไต่อันดับ ทั้งที่เกมออกแบบให้ฝากเงินปลอดภัยกว่า
local function wealthOf(player)
	local state = Inventory.Get(player)
	local carried = state and state.gold or 0
	local ok, banked = pcall(Bank.Get, player)
	return carried + (ok and banked or 0)
end

local function publish(player)
	if not player.Parent then return end
	-- โปรไฟล์ยังไม่โหลด = ยังไม่รู้ค่าจริง · เขียนตอนนี้จะทับของจริงด้วยศูนย์
	local state = Inventory.Get(player)
	if not state then return end

	pcall(function()
		GlobalRanks.Write(player.UserId, "levels", Progression.GetLevel(player) or 0)
		GlobalRanks.Write(player.UserId, "gold", wealthOf(player))
	end)
end

Players.PlayerRemoving:Connect(function(player)
	-- เขียนครั้งสุดท้ายตอนออก ค่าที่ได้มาในรอบสุดท้ายจึงไม่หาย
	publish(player)
	GlobalRanks.Forget(player.UserId)
end)

task.spawn(function()
	while true do
		task.wait(EVERY_SECONDS)
		for _, player in ipairs(Players:GetPlayers()) do
			publish(player)
			task.wait() -- กระจายภาระ ไม่ยิง DataStore พร้อมกันทั้งเซิร์ฟ
		end
	end
end)

-- ช่องเทสใน Studio (ทรงเดียวกับ IslandTest / QuestTest — sandbox ของ execute_luau require ได้สำเนาว่าง)
if RunService:IsStudio() then
	local bf = Instance.new("BindableFunction")
	bf.Name = "RankTest"
	bf.OnInvoke = function(op, ...)
		if op == "Publish" then publish(...) return true end
		if op == "Wealth" then return wealthOf(...) end
		if op == "Top" then GlobalRanks.ClearCache() return GlobalRanks.Top(...) end
		error("RankTest: ไม่มี op " .. tostring(op))
	end
	bf.Parent = game:GetService("ServerStorage")
end
