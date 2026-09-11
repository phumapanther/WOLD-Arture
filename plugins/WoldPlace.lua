-- WoldPlace: keyboard shortcuts for placing WOLD Arture's models by hand.
--
-- Studio's own arrow-key nudge moves in WORLD axes by a fixed stud, which is the wrong tool for dropping a
-- house onto a plot: you want to slide it along the ground, spin it, and have it sit ON the ground without
-- hunting for the height. That is what this does.
--
-- Drop this file in plugins/ (already a junction to Studio's plugin folder) and Studio loads it on restart.
-- Everything happens through ChangeHistoryService, so every shortcut is one Ctrl+Z.
--
-- The shortcuts are deliberately NOT bound through PluginActions with default keybinds, because Studio
-- reserves most useful keys. They are read directly from UserInputService and only act while the plugin's
-- toolbar button is toggled on -- so normal Studio typing is never swallowed.

local ChangeHistoryService = game:GetService("ChangeHistoryService")
local CollectionService = game:GetService("CollectionService")
local Selection = game:GetService("Selection")
local UserInputService = game:GetService("UserInputService")

--------------------------------------------------------------------------------
-- Settings
--------------------------------------------------------------------------------

local STEP = 4 -- studs per nudge; Shift makes it 1, Alt makes it 16
local FINE_STEP = 1
local COARSE_STEP = 16
local TURN = math.rad(15) -- degrees per rotate; Shift makes it 5, Alt makes it 90
local FINE_TURN = math.rad(5)
local COARSE_TURN = math.rad(90)

-- What Tab cycles through when tagging. Each entry is the tag plus the attributes that go with it, matching
-- the vocabulary the game's own systems read (GatherConfig.Nodes, GatherConfig.Mobs, NpcKind).
local TAG_PRESETS = {
	{ label = "ต้นไม้ (เก็บไม้)", tag = "WOLD_Node", attrs = { NodeKind = "Tree" } },
	{ label = "ก้อนหิน (ทุบหิน)", tag = "WOLD_Node", attrs = { NodeKind = "Rock" } },
	{ label = "แร่เหล็ก", tag = "WOLD_Node", attrs = { NodeKind = "IronOre" } },
	{ label = "คริสตัล", tag = "WOLD_Node", attrs = { NodeKind = "Crystal" } },
	{ label = "สมุนไพร", tag = "WOLD_Node", attrs = { NodeKind = "Herb" } },
	{ label = "จุดเกิดสไลม์", tag = "WOLD_Spawner", attrs = { MobKind = "GreenSlime", Count = 3, Radius = 55 } },
	{ label = "NPC ร้านค้า", tag = "WOLD_Npc", attrs = { NpcKind = "shop", NpcName = "เฒ่าแก่" } },
}
local presetIndex = 1

--------------------------------------------------------------------------------
-- Toolbar
--------------------------------------------------------------------------------

local toolbar = plugin:CreateToolbar("WOLD")
local toggleButton = toolbar:CreateButton(
	"WOLD Place",
	"เปิด/ปิดคีย์ลัดจัดวางโมเดล",
	"rbxasset://textures/ui/GuiImagePlaceholder.png")
toggleButton.ClickableWhenViewportHidden = true

local active = false

-- A small panel that stays on screen while the shortcuts are live, so the keys are discoverable rather than
-- something to remember. It also shows which tag preset Tab is currently on.
local widget = plugin:CreateDockWidgetPluginGui(
	"WoldPlaceHelp",
	DockWidgetPluginGuiInfo.new(Enum.InitialDockState.Float, false, false, 300, 330, 260, 260))
widget.Title = "WOLD Place"

local text = Instance.new("TextLabel")
text.Size = UDim2.fromScale(1, 1)
text.BackgroundColor3 = Color3.fromRGB(30, 32, 38)
text.BorderSizePixel = 0
text.Font = Enum.Font.Code
text.TextSize = 13
text.TextColor3 = Color3.fromRGB(226, 226, 232)
text.TextXAlignment = Enum.TextXAlignment.Left
text.TextYAlignment = Enum.TextYAlignment.Top
text.Text = ""
text.Parent = widget

-- Declared up here because refreshHelp below prints it, and a local declared further down the file would be
-- a different (global, always nil) name to everything above it.
local destination = nil

local function refreshHelp()
	text.Text = table.concat({
		active and "  ●  เปิดอยู่" or "  ○  ปิดอยู่ (กดปุ่ม WOLD Place)",
		"",
		"  ลูกศร      เลื่อนตามมุมกล้อง",
		"  PgUp/PgDn  ขึ้น / ลง",
		"  Q / E      หมุนซ้าย / ขวา",
		"  G          วางลงพื้น",
		"  R          หมุนสุ่ม",
		"  T          ขนาดสุ่ม (±15%)",
		"  Ctrl+D     คัดลอกวางข้างๆ",
		"  Ctrl+F     ตั้งโฟลเดอร์ปลายทาง",
		"  Ctrl+B     ย้ายของที่เลือกเข้าโฟลเดอร์",
		"  Shift+V    ก็อปไปวางตรงปลายเมาส์",
		"  Tab        เปลี่ยนชนิดแท็ก",
		"  Enter      ติดแท็กที่เลือก",
		"",
		"  Shift = ละเอียด   Alt = หยาบ",
		"",
		"  ปลายทางตอนนี้:",
		"    " .. (destination and destination.Parent and destination.Name or "ไม่ได้ตั้ง (วางตามต้นฉบับ)"),
		"",
		"  แท็กตอนนี้:",
		"    " .. TAG_PRESETS[presetIndex].label,
	}, "\n")
end

toggleButton.Click:Connect(function()
	active = not active
	toggleButton:SetActive(active)
	widget.Enabled = active
	refreshHelp()
end)

--------------------------------------------------------------------------------
-- Helpers
--------------------------------------------------------------------------------

-- Every shortcut works on whatever is selected, and on Models as readily as Parts -- which is why nothing
-- here touches CFrame directly. PivotTo moves a Model and a Part alike.
local function selected()
	local out = {}
	for _, inst in ipairs(Selection:Get()) do
		if inst:IsA("Model") or inst:IsA("BasePart") then
			table.insert(out, inst)
		end
	end
	return out
end

local function stepSize()
	if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then return FINE_STEP end
	if UserInputService:IsKeyDown(Enum.KeyCode.LeftAlt) then return COARSE_STEP end
	return STEP
end

local function turnSize()
	if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then return FINE_TURN end
	if UserInputService:IsKeyDown(Enum.KeyCode.LeftAlt) then return COARSE_TURN end
	return TURN
end

-- One undo entry per action, named so the history reads sensibly.
local function withUndo(name, fn)
	local recording = ChangeHistoryService:TryBeginRecording(name)
	local ok, err = pcall(fn)
	if recording then
		ChangeHistoryService:FinishRecording(recording,
			ok and Enum.FinishRecordingOperation.Commit or Enum.FinishRecordingOperation.Cancel)
	end
	if not ok then warn("[WoldPlace] " .. name .. ": " .. tostring(err)) end
end

-- The camera's flat forward and right. Arrow keys move things the way they LOOK on screen; moving along
-- world X and Z means the arrows do something different depending on where you are standing, which is the
-- single most annoying thing about the built-in nudge.
local function cameraAxes()
	local camera = workspace.CurrentCamera
	if not camera then return Vector3.new(0, 0, -1), Vector3.new(1, 0, 0) end
	local look = camera.CFrame.LookVector
	local flat = Vector3.new(look.X, 0, look.Z)
	if flat.Magnitude < 0.01 then flat = Vector3.new(0, 0, -1) end
	flat = flat.Unit
	local right = Vector3.new(-flat.Z, 0, flat.X)
	return flat, right
end

local function move(offset)
	local items = selected()
	if #items == 0 then return end
	withUndo("WOLD move", function()
		for _, inst in ipairs(items) do
			inst:PivotTo(inst:GetPivot() + offset)
		end
	end)
end

local function rotate(radians)
	local items = selected()
	if #items == 0 then return end
	withUndo("WOLD rotate", function()
		for _, inst in ipairs(items) do
			-- Spun about the object's OWN centre, not the world origin: rotating a house should turn it in
			-- place rather than swing it across the map.
			local pivot = inst:GetPivot()
			inst:PivotTo(CFrame.new(pivot.Position) * CFrame.Angles(0, radians, 0)
				* (pivot - pivot.Position))
		end
	end)
end

-- The visible extents of a thing, whatever it is. Model:GetBoundingBox() is the measurement that matches
-- what the eye sees -- a MeshPart's mesh does not fill its own box, and measuring part by part put models
-- visibly in the air while reporting them as planted.
local function extents(inst)
	if inst:IsA("Model") then
		return inst:GetBoundingBox()
	end
	return inst.CFrame, inst.Size
end

-- Drop onto whatever is underneath, ignoring the thing being dropped. Sinks it slightly so it reads as
-- planted rather than balanced: Roblox terrain grass stands about 3 studs proud of the surface, so anything
-- laid exactly flush is swallowed by it, and anything laid on top of the grass hovers.
local SINK = 0.4

local function dropToGround()
	local items = selected()
	if #items == 0 then return end
	withUndo("WOLD drop to ground", function()
		for _, inst in ipairs(items) do
			local box, size = extents(inst)
			local base = box.Position.Y - size.Y / 2

			local params = RaycastParams.new()
			params.FilterType = Enum.RaycastFilterType.Exclude
			params.FilterDescendantsInstances = { inst }
			local hit = workspace:Raycast(
				Vector3.new(box.Position.X, base + 200, box.Position.Z),
				Vector3.new(0, -800, 0), params)
			if hit then
				local wanted = hit.Position.Y - SINK
				inst:PivotTo(inst:GetPivot() + Vector3.new(0, wanted - base, 0))
			end
		end
	end)
end

local function randomYaw()
	local items = selected()
	if #items == 0 then return end
	withUndo("WOLD random rotation", function()
		for _, inst in ipairs(items) do
			local pivot = inst:GetPivot()
			inst:PivotTo(CFrame.new(pivot.Position)
				* CFrame.Angles(0, math.random() * math.pi * 2, 0)
				* (pivot - pivot.Position))
		end
	end)
end

local function randomScale()
	local items = selected()
	if #items == 0 then return end
	withUndo("WOLD random scale", function()
		for _, inst in ipairs(items) do
			-- Only Models can be scaled as a unit; a lone Part is left alone rather than stretched, which
			-- would distort it against its neighbours.
			if inst:IsA("Model") then
				inst:ScaleTo(inst:GetScale() * (0.85 + math.random() * 0.3))
			end
		end
	end)
end

--------------------------------------------------------------------------------
-- The destination folder
--------------------------------------------------------------------------------

-- Where new copies go.
--
-- Studio's own Ctrl+V pastes into Workspace, never into the folder you are working in, so an afternoon of
-- copying buildings leaves them scattered at the top of the tree and they have to be dragged back in one at
-- a time. Pinning a folder here means every copy lands where it belongs.
--
-- Held as a reference rather than a path, so renaming the folder does not break it. Cleared automatically
-- if the folder is deleted.

local function destinationName()
	if destination and destination.Parent then return destination:GetFullName() end
	destination = nil
	return nil
end

-- Pin whatever is selected. A Folder is used as-is; anything else pins the folder it sits in, so you can
-- click a building already in the right place instead of hunting for the folder itself.
local function pinDestination()
	local items = Selection:Get()
	if #items == 0 then
		destination = nil
		print("[WoldPlace] ยกเลิกโฟลเดอร์ปลายทาง — วางตามต้นฉบับเหมือนเดิม")
		refreshHelp()
		return
	end
	local first = items[1]
	destination = first:IsA("Folder") and first or first.Parent
	print(("[WoldPlace] โฟลเดอร์ปลายทาง = %s"):format(destination:GetFullName()))
	refreshHelp()
end

-- Move the selection into the destination, for things that have already escaped -- a Ctrl+V that landed in
-- Workspace, or a model dragged out by accident. World position is preserved: reparenting alone would keep
-- the pivot, but only if the new parent has no offset of its own, and a Model's pivot is cheap to restore
-- exactly.
local function collectIntoDestination()
	if not destinationName() then
		print("[WoldPlace] ยังไม่ได้ตั้งโฟลเดอร์ปลายทาง (Ctrl+F)")
		return
	end
	local items = Selection:Get()
	if #items == 0 then return end
	local moved = 0
	withUndo("WOLD collect", function()
		for _, inst in ipairs(items) do
			if inst ~= destination and not destination:IsDescendantOf(inst) and inst.Parent ~= destination then
				local pivot = inst:IsA("Model") and inst:GetPivot() or nil
				inst.Parent = destination
				if pivot then inst:PivotTo(pivot) end
				moved += 1
			end
		end
	end)
	print(("[WoldPlace] ย้าย %d ชิ้นเข้า %s"):format(moved, destination.Name))
end

-- Duplicate beside the original rather than exactly on top of it, so the copy is visible and immediately
-- draggable instead of hidden inside what it was copied from.
local function duplicate()
	local items = selected()
	if #items == 0 then return end
	local copies = {}
	withUndo("WOLD duplicate", function()
		local _, right = cameraAxes()
		for _, inst in ipairs(items) do
			local _, size = extents(inst)
			local copy = inst:Clone()
			-- The pinned folder wins; without one the copy stays beside its original, as before.
			copy.Parent = destinationName() and destination or inst.Parent
			copy:PivotTo(inst:GetPivot() + right * (math.max(size.X, size.Z) + 4))
			table.insert(copies, copy)
		end
	end)
	if #copies > 0 then Selection:Set(copies) end
end

-- Copy the selection to wherever the mouse is pointing, into the pinned folder.
--
-- This is the "take one from the parts yard and put it over there" move: Ctrl+D drops a copy beside the
-- original, which is right for filling a row of houses and useless for fetching a building from a store
-- across the map.
--
-- The ray is cast from the CAMERA through the cursor rather than straight down from it, because a cursor is
-- a direction on screen, not a place in the world -- it only becomes a point when it hits something.
local function duplicateToMouse()
	local items = selected()
	if #items == 0 then return end

	local mouse = plugin:GetMouse()
	local ray = workspace.CurrentCamera:ViewportPointToRay(mouse.X, mouse.Y)

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	-- The originals are excluded so that pointing AT the thing being copied still finds the ground behind
	-- it rather than landing the copy on its own roof.
	params.FilterDescendantsInstances = items
	local hit = workspace:Raycast(ray.Origin, ray.Direction * 6000, params)
	if not hit then
		print("[WoldPlace] เล็งไม่โดนพื้น — เลื่อนเมาส์ไปตรงพื้นดินแล้วลองใหม่")
		return
	end

	local copies = {}
	withUndo("WOLD duplicate to mouse", function()
		-- Several selected items keep their arrangement relative to each other: the group is moved as a
		-- whole, rather than every piece being stacked on the same spot.
		local anchorPivot = items[1]:GetPivot()
		for _, inst in ipairs(items) do
			local copy = inst:Clone()
			copy.Parent = destinationName() and destination or inst.Parent
			local offset = inst:GetPivot().Position - anchorPivot.Position
			copy:PivotTo(inst:GetPivot() - inst:GetPivot().Position + hit.Position + offset)

			-- Then sit it ON the ground, the same way G does, so it does not land half-buried or hovering.
			local box, size = extents(copy)
			local base = box.Position.Y - size.Y / 2
			local down = RaycastParams.new()
			down.FilterType = Enum.RaycastFilterType.Exclude
			down.FilterDescendantsInstances = { copy }
			local floor = workspace:Raycast(
				Vector3.new(box.Position.X, base + 200, box.Position.Z),
				Vector3.new(0, -800, 0), down)
			if floor then
				copy:PivotTo(copy:GetPivot() + Vector3.new(0, (floor.Position.Y - SINK) - base, 0))
			end
			table.insert(copies, copy)
		end
	end)
	if #copies > 0 then
		Selection:Set(copies)
		print(("[WoldPlace] วาง %d ชิ้นที่ปลายเมาส์%s"):format(#copies,
			destinationName() and (" ใน " .. destination.Name) or ""))
	end
end

local function applyTag()
	local items = selected()
	if #items == 0 then return end
	local preset = TAG_PRESETS[presetIndex]
	withUndo("WOLD tag " .. preset.label, function()
		for _, inst in ipairs(items) do
			CollectionService:AddTag(inst, preset.tag)
			for key, value in pairs(preset.attrs) do
				inst:SetAttribute(key, value)
			end
		end
	end)
	print(("[WoldPlace] ติด %s ให้ %d ชิ้น"):format(preset.label, #items))
end

--------------------------------------------------------------------------------
-- Keys
--------------------------------------------------------------------------------

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	-- Only while the plugin is switched on, and never while something else is reading the keyboard --
	-- otherwise typing a script name in the Explorer would start nudging models around.
	if not active or gameProcessed then return end
	if input.UserInputType ~= Enum.UserInputType.Keyboard then return end

	local key = input.KeyCode
	local step = stepSize()
	local forward, right = cameraAxes()

	if key == Enum.KeyCode.Up then
		move(forward * step)
	elseif key == Enum.KeyCode.Down then
		move(-forward * step)
	elseif key == Enum.KeyCode.Left then
		move(-right * step)
	elseif key == Enum.KeyCode.Right then
		move(right * step)
	elseif key == Enum.KeyCode.PageUp then
		move(Vector3.new(0, step, 0))
	elseif key == Enum.KeyCode.PageDown then
		move(Vector3.new(0, -step, 0))
	elseif key == Enum.KeyCode.Q then
		rotate(turnSize())
	elseif key == Enum.KeyCode.E then
		rotate(-turnSize())
	elseif key == Enum.KeyCode.G then
		dropToGround()
	elseif key == Enum.KeyCode.R then
		randomYaw()
	elseif key == Enum.KeyCode.T then
		randomScale()
	elseif key == Enum.KeyCode.D and UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
		duplicate()
	elseif key == Enum.KeyCode.F and UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
		pinDestination()
	elseif key == Enum.KeyCode.B and UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
		collectIntoDestination()
	elseif key == Enum.KeyCode.V and UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then
		duplicateToMouse()
	elseif key == Enum.KeyCode.Tab then
		presetIndex = presetIndex % #TAG_PRESETS + 1
		refreshHelp()
	elseif key == Enum.KeyCode.Return then
		applyTag()
	end
end)

refreshHelp()
print("[WoldPlace] พร้อมใช้งาน — กดปุ่ม WOLD Place บนแถบเครื่องมือ")
