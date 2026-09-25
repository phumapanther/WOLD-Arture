-- WeaponVisuals.server.lua: puts the equipped weapon in the character's hand.
--
-- Driven entirely by the inventory: whatever is in the weapon slot is what appears, and it is rebuilt on
-- respawn and on every equipment change. Nothing here decides anything — it only mirrors state.
--
-- Motor6D rather than a WeldConstraint, per the reference: a Motor6D is a real joint, so the weapon moves
-- with the hand under animation instead of being frozen relative to it.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerConfig = require(game.ServerScriptService.ServerConfig)
local Inventory = require(game.ServerScriptService.Inventory)
local ItemCatalog = require(game.ReplicatedStorage.ItemCatalog)
local WeaponVisualsAccess = require(game.ServerScriptService.WeaponVisualsAccess)
local PlayerJoin = require(game.ServerScriptService.PlayerJoin)

if ServerConfig.IsLobby then return end

-- **ห้ามเก็บ reference ของโฟลเดอร์ไว้ตอนบูต — ต้องถามใหม่ทุกครั้ง**
--
-- `WeaponPrefabs.server.lua` **ลบโฟลเดอร์เดิมทิ้งแล้วสร้างใหม่** ทุกครั้งที่เซิร์ฟเวอร์เริ่ม ถ้าเพลสมีโฟลเดอร์
-- ค้างอยู่ (เช่นมีคนรันตัวสร้างใน Edit mode ไว้) `WaitForChild` จะคืนของเก่าให้ทันที แล้วพอตัวสร้างจริง
-- ทำงาน ของเก่าก็ถูก Destroy ทิ้ง — ตัวแปรที่เก็บไว้ชี้ไปที่ instance ที่ตายแล้วตลอดทั้งรอบ
-- ผลคือ `FindFirstChild` คืน nil ทุกครั้ง อาวุธไม่โผล่ในมือเลยสักชิ้น **และไม่มี error ให้เห็นด้วย**
-- เพราะโค้ดแค่ return เงียบๆ (อาการที่เจอจริง: ท่าโจมตีเล่นปกติแต่มือว่างเปล่า)
--
-- ตรงกับกฎเหล็กของโปรเจ็คเรื่อง StreamingEnabled: ลูปถามใหม่ ไม่ใช่จำไว้ตอนเริ่ม
local function prefabFolder()
	return ReplicatedStorage:FindFirstChild("WOLD_Weapons")
end

-- How each weapon sits in the hand. Tuned per weapon because the prefabs have different origins: a sword is
-- held mid-blade, a bow across the grip, a book flat on the palm.
-- These prefabs run along their own Y axis, but the HILT is at +Y and the blade at the origin (measured on
-- the sword: Handle +2.00, Pommel +2.50, Blade 0.00). So leaving the rotation alone hangs the sword point
-- DOWN; it has to be flipped 180 degrees for the blade to stand up, then leaned forward.
local BLADE_UP = CFrame.Angles(math.rad(180), 0, 0)
-- Named because four things use it: the sword and the three tools, which are all built to the same layout.
local SWORD_GRIP = CFrame.new(0, -0.3, 0) * BLADE_UP * CFrame.Angles(math.rad(-90), 0, 0) * CFrame.new(0, -2.0, 0)
local GRIP = {
	-- Gripped in the right hand, by the HANDLE. The joint drives the PrimaryPart, which is the Blade, and the
	-- Handle sits 2.0 studs along the blade's local +Y — so the offset has to pull the model back by that much
	-- or the palm ends up holding the blade (measured: handle 3.2 studs from the hand, blade only 1.2).
	-- BLADE_UP flips the model so the point stands up, and the lean is negative because it is applied after
	-- that flip, which reverses it.
	-- Leaned forward from -20 to -90: the blade was standing bolt upright. The lean is applied BEFORE the
	-- handle offset below, so the grip stays put in the palm and only the blade swings down and forward.
	Sword = SWORD_GRIP,
	-- โล่: จุดยึดคือ `RightLowerArm` ไม่ใช่ฝ่ามือ (ดู `ANCHOR_ALWAYS`)
	--
	-- **อยู่ข้างแขนด้านนอก ไม่ใช่หน้าแขน** (ผู้ใช้สั่งรอบสอง 2026-09-20) — หน้าโล่ของโมเดลคือ -Z
	-- การ yaw -90° ทำให้ -Z ไปชี้ +X = ด้านนอกของแขนขวา ส่วนความกว้างของใบไปวางตามแนวหน้า-หลัง
	-- ซึ่งคือทรงของโล่ที่รัดแขนจริง เวลามองจากด้านข้างจะเห็นเต็มใบ
	-- ผู้ใช้ปรับจากภาพในเกมรอบสอง (2026-09-20): เลื่อนลงให้เลยมือ และถอยออกจากแขนให้เห็นช่องว่าง
	-- 0.15 = กลางแผ่นอยู่แถวข้อมือ ตัวใบจึงคลุมท่อนแขนล่างและปลายเลยมือลงไป · 0.75 = ห่างจากแขน
	-- พอให้เห็นว่าเป็นของที่รัดอยู่ ไม่ใช่แผ่นที่ทาบติดเนื้อแขน
	Shield = CFrame.new(0.75, 0.15, 0) * CFrame.Angles(0, math.rad(-90), 0),
	-- The greatsword is built to the sword's layout (blade at the origin, grip along +Y), so it takes the
	-- sword's offset -- pushed a little further out because the hilt sits further up a longer weapon.
	Greatsword = SWORD_GRIP * CFrame.new(0, -1.0, 0),
	-- The three tools are built on the sword's layout on purpose -- working end at the origin, grip 2.0 studs
	-- out along +Y -- so they take the sword's offset unchanged. Sharing the value rather than copying the
	-- number three times means a future correction to the sword's grip fixes all four together.
	Axe = SWORD_GRIP,
	Pickaxe = SWORD_GRIP,
	Shovel = SWORD_GRIP,
	-- The rod is built to the same layout, so it takes the same grip. Held in two hands like the sword,
	-- which is what the user asked for -- the two-handed look comes from Sword_Idle, not from the offset.
	FishingRod = SWORD_GRIP,
	-- ตะหลิวสร้างตามแบบเดียวกัน (ใบพายอยู่ที่จุดกำเนิด ด้ามยื่นไป +Y 2.0) จึงใช้ค่าเดียวกันได้
	Spatula = SWORD_GRIP,
	-- The pistol needs its OWN grip, not the sword's.
	--
	-- SWORD_GRIP stands its model bolt upright, which is right for a blade and wrong for a gun: measured
	-- the barrel pointing straight up (vertical component 1.00) while the character faced forward. A gun
	-- has to lie along the aim.
	--
	-- The model is built muzzle-at-origin with the grip 2.0 studs out along +Y, so the whole thing is
	-- rotated to lay that axis FORWARD rather than upward, then pulled back by the same 2.0 to put the
	-- stock in the palm instead of the muzzle.
	-- No rotation at all, which is the surprising part. The hand's own axes already lay the model's +Y
	-- backward along the body's facing, so leaving the orientation alone points the barrel FORWARD and
	-- level -- measured 0.34, 0.04, -0.94 against a body facing 0, 0, -1, versus 1.00 straight up under
	-- SWORD_GRIP. All that remains is pulling the model back 2.0 studs so the palm holds the stock rather
	-- than the muzzle.
	Pistol = CFrame.new(0, -0.2, 0) * CFrame.new(0, -2.0, 0),
	-- สไน: **ติดกลางอกตลอด ปากกระบอกชี้ไปหน้า** (ผู้ใช้สั่ง "ถือเหมือนคฑา ปืนอยู่กลางอกแต่ชี้ไปด้านหน้าแบบปืน")
	-- จุดยึดคือ UpperTorso (ดู ANCHOR_ALWAYS) · หมุนให้แกน +Y ของโมเดล (ไปทางพานท้าย) ชี้ไปหลัง (+Z ลำตัว)
	-- และ +Z ของโมเดล (กล้องเล็ง) ชี้ขึ้น · ปากกระบอกห่างหน้าอก 3.7 สตัด = ด้ามจับอยู่หน้าอกพอดี
	-- ปรับเลขนี้ได้อย่างเดียวถ้าในเกมดูไม่ตรง ไม่ต้องแตะโมเดล
	Sniper = CFrame.fromMatrix(Vector3.new(0, 0.1, -3.7), Vector3.new(-1, 0, 0), Vector3.new(0, 0, 1), Vector3.new(0, 1, 0)),
	-- The bow's belly has to face out to the RIGHT while it is held in the right hand, so the limbs curve away
	-- from the character rather than into it. The 180 is on ROLL, not yaw: the bow lies in a plane, so yawing
	-- it only spins that plane about the arm while rolling it turns the belly over.
	Bow = CFrame.new(0, -0.2, 0.3) * CFrame.Angles(math.rad(-90), 0, math.rad(180)),
	-- The staff is a single part with no separate hilt, so it has no wrong end to flip: leaving it upright
	-- puts its ornamented head at the top, which is the way a staff is carried.
	Staff = CFrame.new(0, 0.9, -1.6) * CFrame.Angles(math.rad(-20), 0, 0),
	-- The spellbook is not gripped: it floats in front of the chest between the open hands, so it hangs off
	-- the torso instead. Attached to the hand it sat off to one side (measured x=2.5 instead of centred).
	Spellbook = CFrame.new(0, 0.4, -2) * CFrame.Angles(math.rad(-70), 0, 0),
}
-- Which body part each weapon joints to WHILE FIGHTING. Anything not listed here is held in the hand.
--
-- These two are the exception because their attack poses put them in front of the chest rather than in a
-- fist: the spellbook floats open between both hands, and the staff is brought across the body. Jointed to
-- the hand they went where the hand went, which is off to one side (measured: spellbook at x=2.5 instead of
-- centred).
local ATTACH_TO = {
	Spellbook = "UpperTorso",
	Staff = "UpperTorso",
}

-- ของที่ **ไม่ได้ถืออยู่ในมือเลย** ไม่ว่าจะกำลังตีอยู่หรือไม่ — ตอนนี้มีโล่ชิ้นเดียว
--
-- ผู้ใช้กำหนด 2026-09-20: "ตำแหน่งที่ถืออาวุธจะอยู่ที่แขนขวา แบบโล่ติดแขน ติดตรงหน้าแขน ไม่ใช่ฝั่งมือ"
-- แยกจาก `ATTACH_TO` ข้างบนเพราะอันนั้นเป็นของที่ย้ายที่ **เฉพาะตอนตี** แล้วกลับมาอยู่ในมือตอนเดิน
-- ส่วนโล่รัดอยู่กับแขนตลอดเวลา ไม่มีจังหวะไหนที่มันควรไปอยู่ในฝ่ามือ
local ANCHOR_ALWAYS = {
	Shield = "RightLowerArm",
	Sniper = "UpperTorso", -- สไนติดกลางอกตลอด (ผู้ใช้สั่ง 2026-09-25)
}

-- ...but that is only right while the attack pose is up.
--
-- Out of combat there is no pose holding the arms in place, so a book hanging in front of a chest that is
-- walking normally looks like it is stuck to the character rather than carried by them. Carried in the right
-- hand it reads as something a person is holding.
--
-- So both of these move: hand while idle, chest while fighting. The grip differs too, because a thing held
-- at arm's length needs a different offset from one floating at the sternum.
local CARRY_GRIP = {
	-- Tucked against the palm with its spine down, the way a book is carried rather than read.
	Spellbook = CFrame.new(0, -0.6, 0) * CFrame.Angles(math.rad(-90), 0, math.rad(90)),
	-- Upright in the fist, ornamented head up, the way a walking staff is carried.
	--
	-- The offset pulls the model DOWN its own length so the hand meets the shaft rather than the tip. At 1.6
	-- the staff floated clear of the fist; 0.6 puts the grip in the palm. Small numbers here because the
	-- staff's origin already sits near its middle, unlike the sword's, which hangs from the hilt at +2.
	Staff = CFrame.new(0, -0.6, 0) * CFrame.Angles(math.rad(-90), 0, 0),
}
-- โล่รัดท่อนแขนขวา — วัดจากผังของโมเดล (`Builders.Shield`): หน้าโล่หันไป -Z กลางแผ่นอยู่ที่จุดกำเนิด
--
-- ท่อนแขนล่างของ R15 หันแกนเหมือนตัวละคร (แกน Y ลงตามแขน · -Z คือด้านหน้าตัว) ค่านี้จึงเป็นการเลื่อนล้วน
-- ไม่ต้องหมุน: ออกด้านนอกตัวเล็กน้อย · ยกขึ้นให้ใบโล่คลุมตั้งแต่ข้อศอกลงมา (ตัวโล่ห้อยลงจากจุดกำเนิด
-- ราว 2 สตัด) · ดันไปข้างหน้าแขนพอให้ไม่จมเข้าไปในเนื้อแขน
local DEFAULT_GRIP = CFrame.new(0, -1, 0) * CFrame.Angles(math.rad(-90), 0, 0)

-- Who is currently mid-attack, so the two chest-mounted weapons know which way round they should be.
-- Cleared by a timer rather than by an "attack ended" event, because there is no such event: an attack is
-- a moment, and the pose that follows it lets go on its own.
local Fighting = {}

-- Matches STANCE_SECONDS in CombatController, which is how long the attack pose lingers on the client. If
-- the two disagree the weapon snaps back to the hand while the arms are still posed, or hangs at the chest
-- after they have relaxed.
local STANCE_SECONDS = 1.5

-- Where a given weapon should be jointed. The hand by default; the chest for the spellbook and staff, but
-- only while their attack pose is actually up.
local function anchorPartFor(character, weaponId, fighting)
	local always = ANCHOR_ALWAYS[weaponId]
	if always then
		local part = character:FindFirstChild(always)
		-- ไม่เจอชิ้นที่ต้องการ (โครง R6 หรือร่างยังประกอบไม่เสร็จ) ก็ตกไปใช้มือตามเดิม ดีกว่าไม่โผล่เลย
		if part then return part end
	end
	local wanted = fighting and ATTACH_TO[weaponId] or nil
	if wanted then
		local part = character:FindFirstChild(wanted)
		if part then return part end
	end
	return character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm")
end

-- And the offset that goes with wherever it ended up.
local function gripFor(weaponId, fighting)
	if not fighting and CARRY_GRIP[weaponId] then return CARRY_GRIP[weaponId] end
	return GRIP[weaponId] or DEFAULT_GRIP
end

local function clearHeldWeapon(character)
	local existing = character:FindFirstChild("EquippedWeapon")
	if existing then existing:Destroy() end
	-- The joint can live on the hand or the torso, so clear both rather than assuming.
	for _, name in ipairs({ "RightHand", "Right Arm", "UpperTorso", "RightLowerArm" }) do
		local part = character:FindFirstChild(name)
		local grip = part and part:FindFirstChild("WeaponGrip")
		if grip then grip:Destroy() end
	end
end

-- ย้อมทุกชิ้นของโมเดลถือ (เครื่องมือทอง / สกินที่ไม่มีโมเดลของตัวเอง)
local function tintModel(model, colour, material)
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			if colour then d.Color = colour end
			if material then d.Material = material end
		end
	end
end

-- วางอาวุธลงมือของ "ร่าง" ใดก็ได้ — ผู้เล่นเรียกผ่าน holdWeapon · บอทสนาม PVP เรียกผ่าน
-- `WeaponVisualsAccess.HoldOn` (2026-09-24) ได้โมเดล สกิน และท่าจับชุดเดียวกับคนเป๊ะ
local function holdOn(character, weaponId, meta, fighting)
	if not character then return end
	clearHeldWeapon(character)
	local PREFABS = prefabFolder()
	if not weaponId or not PREFABS then return end

	local item = ItemCatalog.Get(weaponId)
	-- เครื่องมือทองใช้โมเดลถือ (และท่าจับ) ของตัวธรรมดา แล้วย้อมเป็นทอง
	local shapeId = item and item.prefab or weaponId
	local anchor = anchorPartFor(character, shapeId, fighting)
	if not anchor then return end

	-- สกินที่ติดตั้งไว้: มีโมเดลของตัวเองใน WOLD_Skins ก็ใช้ ไม่มีก็ย้อมโมเดลเดิม
	local skin = meta and meta.skin and ItemCatalog.Get(meta.skin) or nil
	local skinFolder = ReplicatedStorage:FindFirstChild("WOLD_Skins")
	-- ลำดับการหาโมเดลถือ: สกินที่ติดตั้งไว้ → โมเดลเฉพาะของไอเทมนั้นเอง → รูปทรงมาตรฐานของอาวุธชนิดนั้น
	--
	-- ชั้นกลางคือ **เครื่องมือทอง**: มันมีโมเดลของตัวเองใน `WOLD_Skins` (ชื่อ = id ของไอเทม) แต่ยังใช้
	-- `prefab` เดิมเป็นตัวบอกท่าจับอยู่ จึงต้องหาโดยใช้ `weaponId` ไม่ใช่ `shapeId`
	--
	-- **ห้ามเอาไปไว้ใน `WOLD_Weapons`** โฟลเดอร์นั้นถูกลบทิ้งแล้วสร้างใหม่ทุกครั้งที่เซิร์ฟเวอร์บูต
	-- (`WeaponPrefabs.server.lua`) ของที่วางมือไว้ในเพลสจะหายหมด — `WOLD_Skins` ไม่ถูกแตะ
	local own = skinFolder and skinFolder:FindFirstChild(weaponId)
	local prefab = (skin and skinFolder and skinFolder:FindFirstChild(skin.model or meta.skin))
		or own
		or PREFABS:FindFirstChild(shapeId)
	if not prefab then return end

	local model = prefab:Clone()
	model.Name = "EquippedWeapon"
	local root = model.PrimaryPart
	if not root then
		model:Destroy()
		return
	end
	-- ย้อมสีเฉพาะตอนที่ยืมรูปทรงมาตรฐานมาใช้ — โมเดลที่ปั้นมาเพื่อของชิ้นนั้นโดยเฉพาะมีสีของมันเองแล้ว
	-- ถ้าย้อมทับจะกลายเป็นก้อนสีเดียวทั้งชิ้น ลายและวัสดุที่ออกแบบไว้หายหมด
	local borrowed = prefab.Parent == PREFABS
	if skin then
		if borrowed then tintModel(model, skin.tint, skin.material) end
	elseif item and item.tint and borrowed then
		tintModel(model, item.tint, item.material or Enum.Material.Metal)
	end
	weaponId = shapeId

	-- **ของที่ถืออยู่ต้องไม่ anchored ไม่ชน และไม่มีมวล** (แก้ 2026-09-22: ผู้ใช้แจ้ง "ดาบปักอยู่เฉยๆ
	-- ถอนดาบแล้วถึงขยับได้")
	--
	-- ชิ้นที่ **anchored แล้วถูก Motor6D เชื่อมกับมือ** จะตรึงตัวละครทั้งตัวไว้กับที่ — anchored แปลว่า
	-- "ฟิสิกส์ห้ามขยับชิ้นนี้" และข้อต่อก็ส่งข้อห้ามนั้นย้อนขึ้นไปทั้งร่าง · ปลดอาวุธออกเมื่อไหร่ก็เดินได้
	-- ทันที ซึ่งตรงกับอาการที่เจอเป๊ะ
	--
	-- `CanCollide` ทำให้ดาบไปเกยพื้น/กำแพง · `Massless` กันไม่ให้น้ำหนักอาวุธ 20-30 ชิ้นไปถ่วงการเดิน
	--
	-- **ทำตรงนี้ ไม่ใช่ที่ต้นแบบ** ต้นแบบถูก anchored ถูกแล้ว (มันนอนรออยู่เฉยๆ ไม่ควรร่วง) —
	-- ที่ผิดคือการเอาของที่ anchored ไปแขวนกับตัวคน ตรงนี้จึงเป็นที่เดียวที่รู้ว่ากำลังจะถูกถือ
	-- และครอบคลุมโมเดลทุกชิ้นที่จะเพิ่มมาในอนาคตโดยไม่ต้องไปไล่แก้ทีละอัน
	--
	-- ⚠️ **ห้ามแตะ `CanQuery`** ระบบอื่นยิงเรย์หาอาวุธในมืออยู่ (เช็คระยะฟัน/เล็ง) ปิดแล้วมันหาไม่เจอ
	-- — แก้เท่าที่อาการต้องการเท่านั้น: anchored คือตัวที่ตรึง ที่เหลือคือกันเกยพื้นและกันถ่วงน้ำหนัก
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Anchored = false
			d.CanCollide = false
			d.Massless = true
		end
	end

	-- Parent first, then joint: a Motor6D whose parts are not both in the workspace does nothing.
	model.Parent = character

	local motor = Instance.new("Motor6D")
	motor.Name = "WeaponGrip"
	motor.Part0 = anchor
	motor.Part1 = root
	motor.C0 = gripFor(weaponId, fighting)
	motor.Parent = anchor
end

local function holdWeapon(player, weaponId, meta)
	holdOn(player.Character, weaponId, meta, Fighting[player] == true)
end

WeaponVisualsAccess.HoldOn = function(character, weaponId, meta)
	holdOn(character, weaponId, meta, false)
end

local function refresh(player)
	local item, entry = Inventory.EquippedWeapon(player)
	holdWeapon(player, (item and entry) and entry.id or nil, entry and entry.meta or nil)
end

-- Inventory calls this whenever the weapon slot changes, so the hand updates the instant it happens rather
-- than on a poll.
Inventory.OnWeaponChanged = refresh

PlayerJoin.Each(function(player)
	player.CharacterAdded:Connect(function(character)
		-- The rig is rebuilt on respawn, so the weapon has to be re-attached.
		character:WaitForChild("RightHand", 10)
		task.wait(0.2)
		refresh(player)
	end)
end)

-- A player whose weapon was ALREADY equipped when they joined never triggers OnWeaponChanged, and their
-- character can finish loading before PlayerInventory has read the saved bag. Re-check for a short while
-- after each join so a restored weapon still ends up in hand.
local function refreshUntilArmed(player)
	task.spawn(function()
		for _ = 1, 20 do
			task.wait(0.5)
			if not player.Parent then return end
			local item, entry = Inventory.EquippedWeapon(player)
			local character = player.Character
			if character then
				local wanted = (item and entry) and entry.id or nil
				local held = character:FindFirstChild("EquippedWeapon")
				-- Only act when the hand disagrees with the inventory. Crucially this does NOT stop on
				-- "nothing equipped": at this point the profile may simply not have loaded yet, and giving up
				-- there is what left a restored weapon out of the player's hand.
				if wanted and not held then
					refresh(player)
					return
				elseif wanted and held then
					return -- already correct
				end
			end
		end
	end)
end

Players.PlayerAdded:Connect(refreshUntilArmed)
for _, player in ipairs(Players:GetPlayers()) do
	refreshUntilArmed(player)
	if player.Character then task.spawn(refresh, player) end
end

--------------------------------------------------------------------------------
-- Moving the chest-mounted weapons between the hand and the chest
--------------------------------------------------------------------------------

-- Only the spellbook and the staff care, so only an attack with one of those rebuilds anything. Every other
-- weapon is in the hand either way, and re-jointing it on every swing would be work for nothing.
local function movesWhileFighting(player)
	local item, entry = Inventory.EquippedWeapon(player)
	local id = (item and entry) and entry.id or nil
	return id ~= nil and ATTACH_TO[id] ~= nil
end

-- Bumped on every attack so a second swing during the countdown extends the pose rather than the first
-- swing's timer dropping the weapon back to the hand while the arms are still raised.
local stanceToken = {}

-- CombatStateChanged is fired BY the server at clients, so it cannot be listened to here. WeaponVisuals is
-- told directly instead, through a function PlayerCombat calls -- the same hand-off pattern the rest of the
-- server uses rather than a second copy of the combat state.
local function onAttack(player)
	if not movesWhileFighting(player) then return end

	local wasFighting = Fighting[player] == true
	Fighting[player] = true
	-- Only rebuild when it actually moves. A chain of swings should not re-joint the weapon on every one.
	if not wasFighting then refresh(player) end

	stanceToken[player] = (stanceToken[player] or 0) + 1
	local mine = stanceToken[player]
	task.delay(STANCE_SECONDS, function()
		if stanceToken[player] ~= mine then return end
		Fighting[player] = nil
		if player.Parent then refresh(player) end
	end)
end

WeaponVisualsAccess.OnAttack = onAttack

Players.PlayerRemoving:Connect(function(player)
	Fighting[player] = nil
	stanceToken[player] = nil
end)
