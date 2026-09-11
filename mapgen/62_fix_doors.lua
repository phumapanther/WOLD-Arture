-- 62_fix_doors: move every existing double door's hinges from the middle to the outer edges.
--
-- modelkit/interior2.lua has been fixed, but the doors already standing in the world were built by the old
-- code and carry its numbers. Rebuilding the buildings to pick up the fix would throw away the user's own
-- arrangement, so the doors are corrected WHERE THEY STAND instead.
--
-- The old code derived each leaf's hinge from the sign of its swing, which put both hinges on the inner
-- edges where the leaves meet. Measured on a real door: hinges at local x = +0.05 and -0.05 -- dead centre
-- of an opening whose jambs are at +/-7.8 -- so the leaves swung through the doorway and met in the middle
-- of it. Hinging at the middle is precisely what butterfly wings look like.
--
-- Every moving piece of a leaf (the plank, its two bands, its handle) stores HingeX as an offset from ITS
-- OWN centre, so they all have to be rewritten together against the same new hinge, or the handle will
-- swing around a different point from the plank it is screwed to.
--
-- Run with:  node tools/run-luau.js mapgen/62_fix_doors.lua

return L.runPhase("FixDoors", function(folder)
	folder:SetAttribute("EditsOnly", true)

	local fixed, singles, alreadyOk = 0, 0, 0

	for _, door in ipairs(workspace:GetDescendants()) do
		if door:IsA("Model") and (door.Name == "AutoDoor" or door.Name == "CellDoor") then
			-- The leaves, and everything welded to each of them, grouped by which leaf they belong to. A
			-- part belongs to the leaf whose centre it shares, which is how the original code built them.
			local leaves = {}
			for _, p in ipairs(door:GetDescendants()) do
				if p:IsA("BasePart") and p.Name == "Leaf" then
					table.insert(leaves, p)
				end
			end

			if #leaves < 2 then
				-- A single door hinges on one side and was never wrong.
				singles += 1
			else
				local pivot = door:GetPivot()

				-- Sorted by position across the opening, so "left" and "right" mean what they look like.
				table.sort(leaves, function(a, b)
					return pivot:PointToObjectSpace(a.Position).X < pivot:PointToObjectSpace(b.Position).X
				end)

				local leftLeaf, rightLeaf = leaves[1], leaves[2]
				local leftX = pivot:PointToObjectSpace(leftLeaf.Position).X
				local rightX = pivot:PointToObjectSpace(rightLeaf.Position).X

				-- The outer edge of each leaf, in the door's own frame: where the hinge belongs.
				local leftHinge = leftX - leftLeaf.Size.X / 2
				local rightHinge = rightX + rightLeaf.Size.X / 2

				-- Already fixed? The hinges would be out at the edges rather than near the middle.
				if math.abs(leftHinge - (pivot:PointToObjectSpace(leftLeaf.Position).X + (leftLeaf:GetAttribute("HingeX") or 0))) < 0.2 then
					alreadyOk += 1
				else
					-- Both leaves swing OUT through the opening. The signs are opposite because the hinges
					-- are on opposite edges: the two mirror-flips cancel, and both free edges travel the
					-- same way. Checked numerically before this was written -- with matching signs the
					-- leaves become a revolving door instead.
					for _, pair in ipairs({ { leftLeaf, leftHinge, 95 }, { rightLeaf, rightHinge, -95 } }) do
						local leaf, hingeLocalX, swing = pair[1], pair[2], pair[3]
						local leafCentreX = pivot:PointToObjectSpace(leaf.Position).X

						for _, part in ipairs(door:GetDescendants()) do
							if part:IsA("BasePart") and part:GetAttribute("SwingDeg") then
								local px = pivot:PointToObjectSpace(part.Position).X
								-- Which leaf is this piece part of? The one whose half of the opening it
								-- sits in. Bands share their leaf's centre exactly; a handle is offset
								-- toward the free edge but never crosses into the other leaf.
								local mine = (leafCentreX < 0) and (px < 0) or (leafCentreX > 0) and (px > 0)
								if mine then
									part:SetAttribute("HingeX", hingeLocalX - px)
									part:SetAttribute("HingeZ", 0)
									part:SetAttribute("SwingDeg", swing)
								end
							end
						end
					end
					fixed += 1
				end
			end
		end
	end

	print(("[WOLD] FixDoors: %d double doors re-hinged, %d single doors left alone, %d already correct")
		:format(fixed, singles, alreadyOk))
end)
