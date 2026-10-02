"""render-map.py: วาดรูปแผนที่โลก v2 จาก assets/map/samples.txt.gz (tools/build-map-image.js)

    PYTHONUTF8=1 /c/Users/watch/hacker/pyembed/python.exe tools/render-map.py

ได้ assets/map/world.png (2048) + world_<แถว>_<คอลัมน์>.png (2x2 แผ่น แผ่นละ 1024 — Roblox ย่อรูปเกิน 1024 เอง)
แถวบนของรูป = ขอบ -Z ของโลก · คอลัมน์ซ้าย = ขอบ -X (ตรงกับ MapGui ที่วาง (n+1)/2 * size)
ขั้น: สีวัสดุ → ไล่สีตามความสูง → เงาภูเขา (แสงจากตะวันตกเฉียงเหนือ) → น้ำตื้น-ลึก + ขอบฝั่ง → ลายต้นไม้ในป่า →
เส้นชั้นความสูงทุก 100 สตัด → อาคาร (สีหลังคาจริง + เงาตกขวาล่าง + ขอบ)
"""
import gzip
import os

import numpy as np
from PIL import Image, ImageFilter

ROOT = os.path.join(os.path.dirname(__file__), "..")
SRC = os.path.join(ROOT, "assets", "map", "samples.txt.gz")
OUT = os.path.join(ROOT, "assets", "map")
SIZE = 2048

# รหัสวัสดุต้องตรงกับ MAT ใน tools/sample-map.lua · สีโทนแผนที่ RPG (ไม่ใช่สีจริงของเทอร์เรน)
MATERIALS = {
    0: (40, 90, 130),     # Water (ทาใหม่ตามความลึก)
    1: (124, 154, 84),    # Grass
    2: (74, 110, 60),     # LeafyGrass = ป่า
    3: (134, 126, 114),   # Rock
    4: (236, 240, 246),   # Snow
    5: (216, 198, 150),   # Sand
    6: (84, 78, 82),      # Basalt
    7: (146, 124, 86),    # Ground
    8: (116, 96, 68),     # Mud
    9: (186, 178, 158),   # Limestone
    10: (108, 110, 114),  # Slate
    11: (154, 144, 126),  # Cobblestone
    12: (164, 160, 150),  # Pavement
    13: (154, 96, 74),    # Brick
    14: (198, 226, 240),  # Ice
    15: (124, 154, 84),   # อื่นๆ = หญ้า
}
SHALLOW = np.array((108, 178, 196), np.float32)
DEEP = np.array((38, 62, 92), np.float32)  # = MapConfig.SeaColor ขอบรูปจะกลืนกับพื้นหลังแผนที่
DEEP_AT = 70.0  # สตัด
B64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
LOOKUP = np.zeros(256, np.int64)
for i, ch in enumerate(B64):
    LOOKUP[ord(ch)] = i


def decode(chars, width):
    v = LOOKUP[np.frombuffer(chars.encode("ascii"), np.uint8)].reshape(-1, width)
    out = np.zeros(v.shape[0], np.int64)
    for i in range(width):
        out = out * 64 + v[:, i]
    return out


def load():
    with gzip.open(SRC, "rt", encoding="ascii") as f:
        lines = f.read().split("\n")
    n = int(lines[0].split()[1])
    rows = lines[1:1 + n]
    mat = np.zeros((n, n), np.int64)
    height = np.zeros((n, n), np.float32)
    depth = np.zeros((n, n), np.float32)
    roof = np.zeros((n, n, 3), np.float32)
    above = np.full((n, n), -1.0, np.float32)
    for gz, row in enumerate(rows):
        cells, _, extra = row.partition("|")
        v = decode(cells, 4)
        mat[gz] = v >> 20
        height[gz] = ((v >> 8) & 4095) - 64
        depth[gz] = v & 255
        if extra:
            e = decode(extra, 6)
            gx = e >> 24
            data = e & 0xFFFFFF
            color = data >> 12
            roof[gz, gx, 0] = ((color >> 8) & 15) * 17
            roof[gz, gx, 1] = ((color >> 4) & 15) * 17
            roof[gz, gx, 2] = (color & 15) * 17
            above[gz, gx] = (data >> 4) & 255
    return n, mat, height, depth, roof, above


def up(a, n, smooth):
    """กริด n → SIZE · smooth = bilinear (ความสูง/ความลึก) ไม่งั้นช่องใกล้สุด"""
    if smooth:
        return np.asarray(Image.fromarray(a.astype(np.float32), "F").resize((SIZE, SIZE), Image.BILINEAR))
    k = SIZE // n
    return np.repeat(np.repeat(a, k, 0), k, 1)


def shift(a, dy, dx, fill):
    out = np.full_like(a, fill)
    h, w = a.shape[:2]
    ys, yd = (slice(0, h - dy), slice(dy, h)) if dy >= 0 else (slice(-dy, h), slice(0, h + dy))
    xs, xd = (slice(0, w - dx), slice(dx, w)) if dx >= 0 else (slice(-dx, w), slice(0, w + dx))
    out[yd, xd] = a[ys, xs]
    return out


def blur(rgb, radius):
    img = Image.fromarray(np.clip(rgb, 0, 255).astype(np.uint8), "RGB").filter(ImageFilter.GaussianBlur(radius))
    return np.asarray(img).astype(np.float32)


def main():
    n, mat, height, depth, roof, above = load()
    k = SIZE // n
    studs_per_px = 16000.0 / SIZE

    m = up(mat, n, False)
    water = m == 0
    land = ~water
    h = up(np.where(mat == 0, 0, height), n, True)
    d = up(depth, n, True)

    # 1. สีวัสดุ (ทาแล้วเบลอนิด ขอบวัสดุจะได้ไม่เป็นขั้นบันได)
    palette = np.array([MATERIALS[i] for i in range(16)], np.float32)
    rgb = blur(palette[m], 1.2)

    # 2. ไล่สีตามความสูง: ที่สูงสว่างขึ้นนิด (มองออกว่าเป็นที่ราบสูง)
    rgb *= (0.94 + 0.14 * np.clip(h / 1600.0, 0, 1))[..., None]

    # 3. เงาภูเขา แสงจากตะวันตกเฉียงเหนือ สูง 40° · ขยายแนวดิ่ง 2 เท่า ให้เนินเตี้ยยังมีมิติ
    gy, gx = np.gradient(h * 2.0, studs_per_px)
    slope = np.arctan(np.hypot(gx, gy))
    aspect = np.arctan2(-gx, gy)
    az, alt = np.radians(315.0), np.radians(40.0)
    shade = np.sin(alt) * np.cos(slope) + np.cos(alt) * np.sin(slope) * np.cos(az - aspect)
    flat = np.sin(alt)
    rgb *= np.clip(1.0 + (shade - flat) * 0.9, 0.45, 1.35)[..., None]

    # 4. ลายต้นไม้ในป่า: พุ่มเล็กๆ สุ่มแบบคงที่ เงาเยื้องขวาล่าง ยอดสว่าง
    rng = np.random.default_rng(7)
    forest = up(mat == 2, n, False)
    crown = (rng.random((SIZE, SIZE)) < 0.10) & forest
    crown = crown | (shift(crown, 0, 1, False) & forest)
    tree_shadow = shift(crown, 1, 1, False) & forest & ~crown
    rgb[tree_shadow] *= 0.72
    rgb[crown] *= 1.10

    # 5. เส้นชั้นความสูงจางๆ ทุก 100 สตัด (บนบกเท่านั้น)
    level = np.floor(h / 100.0)
    contour = ((level != shift(level, 0, 1, 0)) | (level != shift(level, 1, 0, 0))) & land & (h > 30)
    rgb[contour] *= 0.86

    # 6. น้ำ: ตื้น → ลึก แล้วคลื่นฟองริมฝั่ง + เส้นขอบฝั่งเข้มบนบก
    t = np.clip(d / DEEP_AT, 0, 1)[..., None] ** 0.6
    sea = SHALLOW * (1 - t) + DEEP * t
    rgb[water] = sea[water]
    near_land = np.zeros_like(water)
    near_water = np.zeros_like(water)
    for dy, dx in ((0, 1), (0, -1), (1, 0), (-1, 0), (1, 1), (-1, -1), (1, -1), (-1, 1)):
        near_land |= shift(land, dy, dx, False)
        near_water |= shift(water, dy, dx, False)
    foam = water & near_land
    rgb[foam] = rgb[foam] * 0.45 + np.array((214, 232, 236), np.float32) * 0.55
    shore = land & near_water
    rgb[shore] *= 0.55

    # 7. อาคาร: สีหลังคาจริง · เงาตกขวาล่าง ยาวตามความสูง · ขอบเข้มรอบกลุ่มอาคาร
    built_cell = above >= 0
    built = up(built_cell, n, False)
    tall = up(np.where(built_cell, above, -1), n, False)
    shadow = np.zeros_like(built)
    for s in range(1, 7):
        shadow |= shift(built & (tall >= s * 6), s, s, False)
    shadow &= ~built
    rgb[shadow] *= 0.58
    roofs = up(roof, n, False).astype(np.float32)
    # หลังคาสีมืด/อ่อนเกินจะกลืนกับพื้น: ดันเข้าหาช่วงกลาง ไม่เปลี่ยนเฉดสี
    lum = roofs.mean(axis=2, keepdims=True)
    roofs = roofs + (np.clip(lum, 70, 215) - lum)
    rgb[built] = roofs[built]
    edge = np.zeros_like(built)
    for dy, dx in ((0, 1), (0, -1), (1, 0), (-1, 0)):
        edge |= shift(built, dy, dx, False)
    edge &= ~built & ~shadow
    rgb[edge] *= 0.6
    rgb[built & ~shift(built, -1, 0, False)] *= 0.82  # ขอบล่างของหลังคาเข้มลง อ่านเป็นก้อนสามมิติ

    out = Image.fromarray(np.clip(rgb, 0, 255).astype(np.uint8), "RGB")
    os.makedirs(OUT, exist_ok=True)
    out.save(os.path.join(OUT, "world.png"), optimize=True)
    half = SIZE // 2
    for r in range(2):
        for c in range(2):
            out.crop((c * half, r * half, (c + 1) * half, (r + 1) * half)).save(
                os.path.join(OUT, f"world_{r}_{c}.png"), optimize=True)
    print(f"{n}x{n} -> {SIZE}px · land {land.mean() * 100:.1f}% · built cells {int(built_cell.sum())} · k={k}")


if __name__ == "__main__":
    main()
