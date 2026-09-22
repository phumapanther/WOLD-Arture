-- IslandConfig: เลขทั้งหมดของเกาะฟาร์ม อ่านได้ทั้งสองฝั่ง — ตัวเลขทุกตัว Claude ตั้งไว้ก่อน (2026-09-22) ผู้ใช้ยังไม่ได้กำหนด
local IslandConfig = {}

IslandConfig.Cell = 4 -- ช่องละ 4 studs = วอกเซล Terrain ของ Roblox พอดี

-- ⚠️ สามค่านี้ต้องตรงกับ ORIGIN / R / OVAL ใน mapgen/80_sky_island.lua แก้ที่โน่นต้องแก้ที่นี่
IslandConfig.Center = Vector3.new(0, 800, 0)
IslandConfig.Radius = 220
IslandConfig.Oval = 0.90
IslandConfig.EdgeMargin = 24 -- ห่างขอบหน้าผาอย่างน้อยเท่านี้ (studs)

-- วงห้ามวาง อ่านตำแหน่งจริงตอนใช้: spawn = SpawnLocation · npc = ทุกโมเดลที่ติดแท็ก WOLD_Npc
IslandConfig.NoBuild = { spawn = 16, npc = 12 }

IslandConfig.MaxPlaced = 300 -- กันเซิร์ฟส่วนตัวหนัก
IslandConfig.MinCallGap = 0.2 -- วินาที ระหว่างคำขอวาง/เก็บของคนเดียวกัน

-- เข้าเกาะครั้งแรกได้ชุดนี้ใส่กระเป๋า (ไม่วางให้ ผู้เล่นวางเองตั้งแต่ชิ้นแรก) เมล็ด 5 = พืชรอบแรกฟรี
IslandConfig.StarterKit = {
	{ id = "House_StoneCottage", count = 1 },
	{ id = "FarmPlot", count = 9 },
	{ id = "Deco_Fence", count = 10 },
	{ id = "Seed", count = 5 },
}

IslandConfig.SeedItem = "Seed"
-- หยอดเมล็ดแล้วสุ่มพืชตามน้ำหนัก · seconds = เวลาจนสุก (นับจาก os.time จึงโตต่อตอนออฟไลน์) · ได้ min-max ชิ้น
IslandConfig.Crops = {
	{ item = "Wheat", weight = 50, seconds = 10 * 60, min = 3, max = 5 },
	{ item = "Vegetable", weight = 35, seconds = 15 * 60, min = 2, max = 4 },
	{ item = "Herb", weight = 15, seconds = 20 * 60, min = 2, max = 3 },
}
-- ระยะการโต: สัดส่วนเวลา → สเกลของโมเดลพืช (ระยะสุดท้าย = สุก)
IslandConfig.Stages = {
	{ at = 0, scale = 0.35 },
	{ at = 0.5, scale = 0.7 },
	{ at = 1, scale = 1 },
}

return IslandConfig
