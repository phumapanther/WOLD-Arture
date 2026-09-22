-- Edit mode → WOLD_PLACE=136992335889132 node tools/lua.js tests/island_grid_test.lua
-- โคลนโมดูลก่อน require: require ใน Edit แคชข้ามคำสั่ง (บทเรียน CLAUDE.md) ตัวโคลนคอมไพล์ Source ปัจจุบันเสมอ
local RS = game.ReplicatedStorage
local src = RS:FindFirstChild("IslandGrid")
assert(src, "IslandGrid ไม่อยู่ใน ReplicatedStorage (Rojo ยังไม่ sync?)")
local clone = src:Clone(); clone.Name = "IslandGrid_Test"; clone.Parent = RS
local G = require(clone)
local C = require(RS.IslandConfig)
local function eq(a, b, msg) if a ~= b then error(("%s: got %s want %s"):format(msg, tostring(a), tostring(b))) end end

local cx, cz = G.cellOf(C.Center.X + 2, C.Center.Z + 2); eq(cx, 0, "cellOf x"); eq(cz, 0, "cellOf z")
local wx, wz = G.worldOf(0, 0); eq(wx, C.Center.X + 2, "worldOf x"); eq(wz, C.Center.Z + 2, "worldOf z")
cx, cz = G.cellOf(C.Center.X - 1, C.Center.Z - 5); eq(cx, -1, "neg x"); eq(cz, -2, "neg z")

local w, d = G.footprintOf(2, 1, 1); eq(w, 1, "rot1 w"); eq(d, 2, "rot1 d")
w, d = G.footprintOf(2, 1, 2); eq(w, 2, "rot2 w"); eq(d, 1, "rot2 d")

local cells = G.cellsOf(3, 4, 2, 1, 0); eq(#cells, 2, "cells n"); eq(cells[1], "3,4", "c1"); eq(cells[2], "4,4", "c2")
cells = G.cellsOf(3, 4, 2, 1, 1); eq(#cells, 2, "cells rot n"); eq(cells[2], "3,5", "c2 rot")

assert(G.inBounds(0, 0), "centre in bounds")
assert(not G.inBounds(60, 0), "x=242 studs out")
assert(not G.inBounds(0, 50), "z=202 studs out (oval)")

local occ = {}
local ok, why = G.canPlace(occ, {}, 10, 10, 2, 2, 0); assert(ok, "empty ok")
ok, why = G.canPlace(occ, {}, 58, 0, 2, 2, 0); eq(ok, false, "edge fails"); eq(why, "edge", "edge reason")
ok, why = G.canPlace(occ, { { x = C.Center.X + 2, z = C.Center.Z + 2, radius = 16 } }, 0, 0, 1, 1, 0); eq(why, "blocked", "blocked reason")
occ["11,11"] = 7
ok, why = G.canPlace(occ, {}, 10, 10, 2, 2, 0); eq(why, "occupied", "occupied reason")
ok = G.canPlace(occ, {}, 12, 12, 2, 2, 0); assert(ok, "beside ok")

local p = G.pivotFor(0, 0, 2, 2, 0, 800)
eq(p.Position.X, C.Center.X + 4, "pivot x"); eq(p.Position.Z, C.Center.Z + 4, "pivot z"); eq(p.Position.Y, 800, "pivot y")
local p1 = G.pivotFor(0, 0, 2, 1, 1, 800) -- หมุนแล้วกิน 1x2 กึ่งกลางอยู่ที่ (+2, +4)
eq(p1.Position.X, C.Center.X + 2, "pivot rot x"); eq(p1.Position.Z, C.Center.Z + 4, "pivot rot z")

local ax, az = G.anchorFor(C.Center.X + 4, C.Center.Z + 4, 2, 2, 0); eq(ax, 0, "anchor x"); eq(az, 0, "anchor z")
ax, az = G.anchorFor(C.Center.X + 2, C.Center.Z + 2, 1, 1, 0); eq(ax, 0, "anchor1 x"); eq(az, 0, "anchor1 z")
ax, az = G.anchorFor(C.Center.X + 4.1, C.Center.Z + 2, 1, 1, 0); eq(ax, 1, "anchor next cell")

clone:Destroy()
return "IslandGrid: all checks passed"
