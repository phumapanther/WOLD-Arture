#!/usr/bin/env bash
# usage: bash tools/offline-check.sh [file.lua ...]    (ไม่ใส่ไฟล์ = ทุกไฟล์ .lua ที่แก้/เพิ่มใน git)
#
# ตรวจโดยไม่ต้องเปิด Studio (ใช้ได้ตอน MCP หลุด) ด้วย Luau CLI แบบ portable ที่ ~/tools/luau (luau-lang/luau release)
#  1. คอมไพล์ผ่านไหม (syntax)
#  2. **ตัวแปรที่ใช้ก่อนประกาศ / สะกดผิด** = "Unknown global" ที่ไม่ใช่ของ Roblox — บั๊กที่เกมนี้เจอมาแล้วหกครั้ง
# ไม่แทน tools/syntax.js กับเทสใน Edit: มันไม่รู้จัก API ของ Roblox และไม่รันโค้ด
LUAU="$HOME/tools/luau"
KNOWN='game|workspace|script|Instance|Vector3|Vector2|CFrame|Color3|ColorSequence|ColorSequenceKeypoint|NumberSequence|NumberSequenceKeypoint|NumberRange|Enum|task|UDim2|UDim|TweenInfo|RaycastParams|Ray|Region3|Region3int16|Vector3int16|OverlapParams|typeof|tick|time|wait|delay|spawn|warn|require|os|math|string|table|utf8|bit32|coroutine|debug|buffer|DateTime|Random|BrickColor|PhysicalProperties|Font|Rect|PathWaypoint|Faces|Axes|SharedTable|elapsedTime|settings|plugin|shared|_G|print|pairs|ipairs|next|select|tostring|tonumber|type|pcall|xpcall|error|assert|setmetatable|getmetatable|rawget|rawset|rawequal|rawlen|unpack|newproxy|gcinfo|loadstring|DockWidgetPluginGuiInfo|CatalogSearchParams|FloatCurveKey|RotationCurveKey|Path2DControlPoint|Content|version|UserSettings|stats|printidentity|ypcall'
if [ $# -eq 0 ]; then
	set -- $( (git status --short | awk '{print $2}'; git ls-files --others --exclude-standard) | grep '\.lua$' | sort -u)
fi
bad=0
for f in "$@"; do
	[ -f "$f" ] || continue
	if ! out=$("$LUAU/luau-compile.exe" --null "$f" 2>&1) || echo "$out" | grep -qi "error"; then
		echo "SYNTAX $f"; echo "$out" | head -5; bad=1
	fi
	globals=$("$LUAU/luau-analyze.exe" --formatter=plain "$f" 2>&1 | grep "Unknown global" | grep -Ev "Unknown global '($KNOWN)'")
	if [ -n "$globals" ]; then echo "GLOBAL $f"; echo "$globals" | head -10; bad=1; fi
done
[ $bad -eq 0 ] && echo "OK ($# files)"
exit $bad
