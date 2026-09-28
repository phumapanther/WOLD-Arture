#!/usr/bin/env bash
# วัด UI ทุกหน้าต่างบนจอจำลองหลายขนาด หาที่ทับกัน/หลุดจอ/โดนปุ่ม Roblox บัง/ปุ่มเล็ก/ตัวอักษรเล็ก (QA 2026-09-28)
# ใช้: bash tools/ui-audit/run.sh [ชื่อจอ ...]   ผลอยู่ที่ tools/ui-audit/out/<จอ>.txt · รันใน Edit ของเพลสหลัก ไม่ต้องกด Play
# ทำงานโดยโคลน ReplicatedStorage.UI → UI_QA แก้ Source ให้เชื่อว่าเป็นมือถือ/คอมขนาดนั้น สร้างทุกหน้าต่าง แล้ววัด
# **ลบของทดสอบทิ้งเองตอนจบเสมอ** (cleanup.lua) — ถ้ารันค้างกลางทาง ให้รัน cleanup.lua เองก่อน publish
# UI ที่สร้างในสคริปต์ฝั่งผู้เล่น (ข้อความเด้ง แถบประกาศ กระสุน ฯลฯ) อยู่ในตาราง SYN ของ analyze.lua — ย้ายตำแหน่งในโค้ดแล้วต้องแก้ตามที่นั่น
set -u
cd "$(dirname "$0")/../.."
D=tools/ui-audit
mkdir -p $D/out
declare -A CFG=(
  [phone844]='{ name = "phone844", w = 844, h = 390, touch = true, keyboard = false }'
  [phone667]='{ name = "phoneSE667", w = 667, h = 375, touch = true, keyboard = false }'
  [phone800]='{ name = "android800", w = 800, h = 360, touch = true, keyboard = false }'
  [phone932]='{ name = "phoneMax932", w = 932, h = 430, touch = true, keyboard = false }'
  [tab1024]='{ name = "iPad1024", w = 1024, h = 768, touch = true, keyboard = false }'
  [tab1180]='{ name = "iPadAir1180", w = 1180, h = 820, touch = true, keyboard = false }'
  [pc1920]='{ name = "pc1920", w = 1920, h = 1080, touch = false, keyboard = true }'
  [pc1366]='{ name = "pc1366", w = 1366, h = 768, touch = false, keyboard = true }'
  [pc1280]='{ name = "pc1280", w = 1280, h = 720, touch = false, keyboard = true }'
  [arena844]='{ name = "arena844", w = 844, h = 390, touch = true, keyboard = false, arena = true }'
  [arena1366]='{ name = "arena1366", w = 1366, h = 768, touch = false, keyboard = true, arena = true }'
)
NAMES=("$@"); [ ${#NAMES[@]} -eq 0 ] && NAMES=("${!CFG[@]}")
for n in "${NAMES[@]}"; do
  { echo "_G.QA_CFG = ${CFG[$n]}"; echo "local built = (function()"; cat $D/build.lua; echo "end)()";
    echo "local res = (function()"; cat $D/analyze.lua; echo "end)()"; echo 'return res'; } > $D/out/run_$n.lua
  WOLD_PLACE=88774255487951 timeout 170 node tools/lua.js $D/out/run_$n.lua Edit 2>/dev/null > $D/out/$n.txt
  echo "$n: $(wc -l < $D/out/$n.txt) บรรทัด"
done
WOLD_PLACE=88774255487951 timeout 60 node tools/lua.js $D/cleanup.lua Edit 2>/dev/null
