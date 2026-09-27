-- TrapWeapon.server: อาวุธกับดัก (เฟส 3 · ผู้ใช้อนุมัติร่าง 2026-09-27) — เขวี้ยง/วาง · ติดพื้น · ทำงาน · หมดอายุ
--
-- ไคลเอนต์ (`TrapController`) ส่งแค่ความตั้งใจ: "throw" + ทิศกล้อง + แรง 0..1 หรือ "place" · เซิร์ฟเวอร์คิดวิถีเอง
-- ด้วยสูตรเดียวกับเส้นเล็ง (`TrapConfig.Velocity/Simulate`) จากตัวละครจริง ไม่เชื่อพิกัดจากไคลเอนต์
-- ตัวเลขทั้งหมด `TrapConfig` · กระสุนหัก 1 ต่อครั้ง (`TrapConfig.SelectedAmmo`)
--
-- กติกา: ติดค้างได้ 3 อันต่อคน (อันที่ 4 = อันเก่าสุดหาย) · 60 วิไม่มีใครมาโดน = หาย · เพื่อนร่วมตี้/ร่วมทีมไม่โดน
-- (เจ้าของก็ไม่โดน) · วิถีผ่านใกล้ตัวใคร = ทำงานทันที · มอนไม่มีสถานะช้า/ล้ม → สตัน `mobStun` วิ
-- สนาม: `ArenaAccess.TrapsAllowed()` = false (ช่วงซื้อของ/จบรอบ) → เขวี้ยงไม่ได้ + กับดักที่ค้างถูกเก็บหมด
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ServerConfig = require(script.Parent.ServerConfig)
if ServerConfig.IsLobby then return end

local TrapConfig = require(ReplicatedStorage.TrapConfig)
local CombatConfig = require(ReplicatedStorage.CombatConfig)
local ItemCatalog = require(ReplicatedStorage.ItemCatalog)
local ProgressionConfig = require(ReplicatedStorage.ProgressionConfig)
local ClassConfig = require(ReplicatedStorage.ClassConfig)
local Remotes = require(ReplicatedStorage.Remotes)
local Inventory = require(script.Parent.Inventory)
local Vitals = require(script.Parent.Vitals)
local StatusEffects = require(script.Parent.StatusEffects)
local Consuming = require(script.Parent.Consuming)
local Party = require(script.Parent.Party)
local MobAccess = require(script.Parent.MobAccess)
local ArenaAccess = require(script.Parent.ArenaAccess)
local Progression = require(script.Parent.Progression)
local Classes = require(script.Parent.Classes)

local TAG = "WOLD_Trap"
local folder = workspace:FindFirstChild("WOLD_Traps") or Instance.new("Folder")
folder.Name = "WOLD_Traps"
folder.Parent = workspace

local Traps = {} -- [model] = { owner, ammo, armedAt, expiresAt }
local ByOwner = {} -- [player] = { model, ... } เรียงเก่า → ใหม่
local LastUse = {} -- [player] = os.clock()

local function allowed()
	return not ArenaAccess.TrapsAllowed or ArenaAccess.TrapsAllowed()
end

local function notify(player, text, kind)
	Remotes.SocialNotify:FireClient(player, kind or "warn", text)
end

-- ของในมือเป็นกับดักไหม → entry, ammoDef, จำนวน
local function heldTrap(player)
	local _, entry = Inventory.EquippedWeapon(player)
	if not (entry and TrapConfig.IsTrap(entry.id)) then return nil end
	local state = Inventory.Get(player)
	local ammo, count = TrapConfig.SelectedAmmo(entry.id, entry.meta, state and state.slots)
	return entry, ammo, count
end

local function canAct(player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then return false end
	if Vitals.IsDowned(player) or not StatusEffects.CanFight(player) then return false end
	if Consuming.IsConsuming(player) then return false end
	return true
end

-- พวกเดียวกัน = ไม่โดน (เจ้าของ · ตี้เดียวกัน · ทีมเดียวกันในสนาม) · `other` = Player หรือโมเดลบอท
local function friendly(owner, other)
	if other == owner then return true end
	if typeof(other) == "Instance" and other:IsA("Player") and Party.SameParty(owner, other) then return true end
	return ArenaAccess.Friendly ~= nil and ArenaAccess.Friendly(owner, other) == true
end

local function rootOf(model)
	return model and (model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart)
end

-- ทุกเป้าที่ยังยืนอยู่ในรัศมี (คน + มอน/บอท) ที่ไม่ใช่พวกเดียวกับเจ้าของ
local function targetsNear(owner, position, radius)
	local out = {}
	for _, other in ipairs(Players:GetPlayers()) do
		local root = rootOf(other.Character)
		if root and not friendly(owner, other) and (root.Position - position).Magnitude <= radius
			and not Vitals.IsDowned(other) then
			out[#out + 1] = { player = other, root = root }
		end
	end
	for _, mob in ipairs(CollectionService:GetTagged("WOLD_Mob")) do
		local root = rootOf(mob)
		local humanoid = mob:FindFirstChildOfClass("Humanoid")
		if root and mob:IsDescendantOf(workspace) and (not humanoid or humanoid.Health > 0)
			and not friendly(owner, mob) and (root.Position - position).Magnitude <= radius then
			out[#out + 1] = { mob = mob, root = root }
		end
	end
	return out
end

-- การฆ่าคนด้วยกับดักนับเหมือนการตี: สนามส่งให้ระบบแมตช์ · เกมหลักได้ EXP + หัวแดง (ทรงเดียวกับ PlayerCombat.awardKill)
local function awardKill(owner, victim)
	if ArenaAccess.OnKill then
		ArenaAccess.OnKill(owner, victim)
		return
	end
	local multiplier = ProgressionConfig.KillMultiplier(Progression.GetLevel(owner), Progression.GetLevel(victim))
	Progression.AwardExp(owner, math.floor(ProgressionConfig.ExpPerPlayerKill * multiplier + 0.5))
	Classes.Mark(owner, ClassConfig.MarkedSecondsKill)
end

local function applyTo(owner, ammo, target)
	if target.player then
		local victim = target.player
		if Vitals.IsInvulnerable(victim) then return end
		if ammo.kind == "slow" then
			StatusEffects.Slow(victim, ammo.seconds, ammo.factor)
		elseif ammo.kind == "stun" then
			StatusEffects.Stagger(victim, ammo.seconds)
		elseif ammo.kind == "knockdown" then
			StatusEffects.Knockdown(victim, ammo.seconds)
		elseif ammo.kind == "damage" then
			local wasDowned = Vitals.IsDowned(victim)
			local landed = Vitals.ApplyDamage(victim, ammo.damage, "combat")
			if landed and ArenaAccess.OnHit and owner.Parent then ArenaAccess.OnHit(owner, victim, ammo.damage) end
			if landed and owner.Parent and not wasDowned and Vitals.IsDowned(victim) then awardKill(owner, victim) end
		end
		Remotes.CombatHit:FireClient(victim)
	else
		local mob = target.mob
		if ammo.kind == "damage" then
			-- บอทสนามคิดดาเมจแบบคน (ทางเดียวกับอาวุธอื่น: ตัวเลขของคน) · มอนเกมหลักใช้ `mobDamage`
			local amount = ArenaAccess.OnHit and ammo.damage or ammo.mobDamage
			if MobAccess.Damage then MobAccess.Damage(mob, amount, owner.Parent and owner or nil) end
		elseif MobAccess.Stun then
			MobAccess.Stun(mob, ammo.mobStun or ammo.seconds or 1)
		end
	end
end

local function removeTrap(model)
	local info = Traps[model]
	Traps[model] = nil
	if info then
		local list = ByOwner[info.owner]
		if list then
			local i = table.find(list, model)
			if i then table.remove(list, i) end
		end
	end
	if model.Parent then model:Destroy() end
end

-- ทำงาน: ภาพ + ผลกับทุกคนในวง แล้วหาย
local function fire(owner, ammo, position)
	Remotes.TrapEvent:FireAllClients("burst", position, ammo.id)
	for _, target in ipairs(targetsNear(owner, position, TrapConfig.EffectRadius)) do
		applyTo(owner, ammo, target)
	end
end

local function buildModel(ammo)
	local weapons = ReplicatedStorage:FindFirstChild("WOLD_Weapons")
	local prefab = weapons and weapons:FindFirstChild("Trap")
	local model
	if prefab then
		model = prefab:Clone()
	else
		-- ต้นแบบหาย (WeaponPrefabs ล้ม) — กับดักยังต้องมีอะไรให้เห็น
		model = Instance.new("Model")
		local core = Instance.new("Part")
		core.Name = "Core"
		core.Shape = Enum.PartType.Cylinder
		core.Size = Vector3.new(0.35, 1.1, 1.1)
		core.CFrame = CFrame.Angles(0, 0, math.rad(90))
		core.Color = Color3.fromRGB(180, 140, 70)
		core.Material = Enum.Material.Metal
		core.Parent = model
		model.PrimaryPart = core
	end
	model.Name = "Trap"
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.CanQuery = false -- ไม่ขวางเรย์ของใคร (เล็ง เก็บเกี่ยว วางของ)
			d.CanTouch = false
		end
	end
	model:ScaleTo(TrapConfig.Scale)
	-- ไฟกะพริบ: ไคลเอนต์ทำให้กะพริบเอง (TrapController) เซิร์ฟตั้งสีไว้ให้
	local lamp = model:FindFirstChild("Lamp", true)
	if lamp and lamp:IsA("BasePart") then
		lamp.Color = ammo.color
		lamp.Material = Enum.Material.Neon
		local light = Instance.new("PointLight")
		light.Name = "TrapLight"
		light.Color = ammo.color
		light.Range = 10
		light.Brightness = 2
		light.Shadows = false
		light.Parent = lamp
	end
	return model
end

-- วางกับดักลงโลก ณ จุด/ผิวที่ตก
local function spawnTrap(owner, ammo, position, normal)
	local up = (normal and normal.Magnitude > 0.1) and normal.Unit or Vector3.yAxis
	local model = buildModel(ammo)
	-- หันด้านบนตามผิว (พื้น = ตั้งตรง · ผนัง = แปะข้างผนัง) · ยกขึ้นครึ่งความหนาให้ก้นแตะผิวพอดี
	local _, size = model:GetBoundingBox()
	local right = up:Cross(Vector3.zAxis)
	if right.Magnitude < 0.1 then right = up:Cross(Vector3.xAxis) end
	right = right.Unit
	local back = right:Cross(up).Unit
	local cf = CFrame.fromMatrix(position + up * (size.Y * 0.5 - 0.05), right, up, back)
	model:PivotTo(cf)
	model:SetAttribute("Owner", owner.UserId)
	model:SetAttribute("Ammo", ammo.id)
	model.Parent = folder
	CollectionService:AddTag(model, TAG)

	local now = os.clock()
	Traps[model] = { owner = owner, ammo = ammo, position = position, armedAt = now + TrapConfig.ArmSeconds,
		expiresAt = now + TrapConfig.LifeSeconds }
	local list = ByOwner[owner] or {}
	ByOwner[owner] = list
	list[#list + 1] = model
	-- อันที่ 4 = อันเก่าสุดหาย
	while #list > TrapConfig.MaxPerOwner do
		removeTrap(list[1])
	end
end

-- เรย์ของกับดัก: ไม่ชนคนเขวี้ยง ไม่ชนกับดักอื่น · เคารพ CanCollide (กล่องโซนล่องหนสูง 200 สตัดไม่ใช่พื้น)
local function rayParams(owner)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local exclude = { folder }
	if owner.Character then exclude[#exclude + 1] = owner.Character end
	params.FilterDescendantsInstances = exclude
	params.RespectCanCollide = true
	return params
end

-- ใช้กระสุนหนึ่งนัด · คืน ammoDef ถ้าใช้ได้
local function spend(player)
	local entry, ammo, count = heldTrap(player)
	if not entry then return nil end
	if not ammo or count <= 0 then
		notify(player, "ไม่มีกระสุนกับดัก — คราฟได้ที่ช่างตีเหล็ก หน้าไอเทมจิปาถะ")
		return nil
	end
	if not Inventory.RemoveById(player, ammo.id, 1) then return nil end
	Inventory.Send(player)
	return ammo
end

local function throw(player, look, power)
	local root = rootOf(player.Character)
	if not root then return end
	local ammo = spend(player)
	if not ammo then return end
	local origin = root.Position + Vector3.new(0, 1.5, 0) + Vector3.new(look.X, 0, look.Z).Unit * 1.2
	local velocity = TrapConfig.Velocity(look, power)
	-- วิถีผ่านใกล้ลำตัวใคร (ที่ไม่ใช่พวกเดียวกัน) = โดนตรงๆ
	local function probe(position)
		local hits = targetsNear(player, position, TrapConfig.DirectHitRadius)
		return hits[1]
	end
	local result = TrapConfig.Simulate(origin, velocity, rayParams(player), probe)
	local landing, normal = result.position, result.normal
	if result.fell then
		-- ไม่ชนอะไรในเวลาบิน (เขวี้ยงลงหน้าผา) — หาพื้นใต้จุดสุดท้าย · ไม่มีเลย = หายไป
		local down = workspace:Raycast(landing, Vector3.new(0, -400, 0), rayParams(player))
		if not down then
			Remotes.TrapEvent:FireAllClients("throw", player.UserId, origin, velocity, result.time, ammo.id)
			return
		end
		landing, normal = down.Position, down.Normal
	end
	Remotes.TrapEvent:FireAllClients("throw", player.UserId, origin, velocity, result.time, ammo.id)
	task.delay(result.time, function()
		if not allowed() then return end
		if result.direct then
			fire(player, ammo, landing)
		else
			spawnTrap(player, ammo, landing, normal)
		end
	end)
end

local function place(player)
	local root = rootOf(player.Character)
	if not root then return end
	local look = root.CFrame.LookVector
	local flat = Vector3.new(look.X, 0, look.Z)
	flat = flat.Magnitude > 1e-3 and flat.Unit or Vector3.new(0, 0, -1)
	local above = root.Position + flat * TrapConfig.PlaceAhead + Vector3.new(0, 2, 0)
	local down = workspace:Raycast(above, Vector3.new(0, -12, 0), rayParams(player))
	if not down then return notify(player, "วางตรงนี้ไม่ได้") end
	local ammo = spend(player)
	if not ammo then return end
	Remotes.TrapEvent:FireAllClients("place", player.UserId, down.Position, ammo.id)
	spawnTrap(player, ammo, down.Position, down.Normal)
end

Remotes.RequestTrap.OnServerEvent:Connect(function(player, action, look, power)
	if not canAct(player) then return end
	if not heldTrap(player) then return end
	if not allowed() then return notify(player, "ยังใช้กับดักไม่ได้ตอนนี้") end
	local now = os.clock()
	if now - (LastUse[player] or 0) < TrapConfig.Cooldown then return end
	LastUse[player] = now
	if action == "throw" then
		-- ทิศจากไคลเอนต์: ต้องเป็นเวกเตอร์จริง (ไม่ NaN/inf) แล้วใช้แค่ทิศ ความยาวไม่มีผล
		if typeof(look) ~= "Vector3" then return end
		local length = look.Magnitude
		if length ~= length or length < 0.5 or length > 1e4 then return end
		power = type(power) == "number" and power == power and math.clamp(power, 0, 1) or 0.5
		throw(player, look.Unit, power)
	elseif action == "place" then
		place(player)
	end
end)

-- เลือกกระสุน (`meta.ammo`) ของกับดักชิ้นที่ถือ/ในกระเป๋า · target = "equipped:weapon" | "bag:<i>"
Remotes.RequestTrapAmmo.OnServerEvent:Connect(function(player, target, ammoId)
	if type(ammoId) ~= "string" or not TrapConfig.AmmoById[ammoId] then return end
	local state = Inventory.Get(player)
	if not state then return end
	local entry
	target = tostring(target or "")
	if target == "equipped:weapon" then
		entry = state.equipped.weapon
	else
		local index = tonumber(target:match("^bag:(%d+)$") or "")
		entry = index and state.slots[index] or nil
	end
	if not (entry and TrapConfig.IsTrap(entry.id)) then return end
	if TrapConfig.Traps[entry.id].fixedAmmo then return end
	entry.meta = entry.meta or {}
	entry.meta.ammo = ammoId
	local ammo = TrapConfig.AmmoById[ammoId]
	notify(player, ("กับดักใช้กระสุน %s แล้ว"):format(ammo.name), "info")
	Inventory.Send(player)
end)

-- ลูปตรวจ: ทำงานเมื่อมีเป้าเข้าใกล้ · หมดอายุ · เจ้าของออกเกม · สนามปิดใช้กับดัก = เก็บทุกอัน
task.spawn(function()
	while true do
		task.wait(0.1)
		local ok = allowed()
		local now = os.clock()
		for model, info in pairs(Traps) do
			if not ok or not model.Parent or not info.owner.Parent or now >= info.expiresAt then
				removeTrap(model)
			elseif now >= info.armedAt then
				local pivot = model:GetPivot().Position
				if #targetsNear(info.owner, pivot, TrapConfig.TriggerRadius) > 0 then
					removeTrap(model)
					fire(info.owner, info.ammo, pivot)
				end
			end
		end
	end
end)

Players.PlayerRemoving:Connect(function(player)
	for _, model in ipairs(table.clone(ByOwner[player] or {})) do removeTrap(model) end
	ByOwner[player] = nil
	LastUse[player] = nil
end)

-- ชื่อที่ใช้กับ ItemCatalog กันพิมพ์ผิด: กับดักทุกชิ้นต้องมีในแคตตาล็อกและเป็นอาวุธ
for id in pairs(TrapConfig.Traps) do
	local item = ItemCatalog.Items[id]
	if not (item and item.kind == "weapon" and CombatConfig.Weapons[id] and CombatConfig.Weapons[id].trap) then
		warn("[Trap] กับดักไม่ครบในแคตตาล็อก/CombatConfig: " .. id)
	end
end
for _, ammo in ipairs(TrapConfig.Ammo) do
	if not ItemCatalog.Items[ammo.id] then warn("[Trap] กระสุนไม่มีในแคตตาล็อก: " .. ammo.id) end
end
