# ponytail: top-down preview map of Arture from world-layout.json -> map-arture-v1.png
import json, math, numpy as np
from PIL import Image, ImageDraw, ImageFont

L = json.load(open("world-layout.json", encoding="utf-8"))
W, EXT = 1400, 1.5                      # image px, map covers [-EXT, EXT] normalized
HALF = L["half_size_studs"]
rng = np.random.default_rng(7)

def px(p): return ((p[0] + EXT) / (2 * EXT) * W, (p[1] + EXT) / (2 * EXT) * W)
def sig(a): return 1 / (1 + np.exp(-np.clip(a, -30, 30)))
def noise(res):
    small = (rng.random((res, res)) * 255).astype(np.uint8)
    return np.asarray(Image.fromarray(small).resize((W, W), Image.BICUBIC), np.float32) / 255
def fbm(): return sum(w * noise(o) for o, w in ((6, .5), (12, .25), (24, .125), (48, .0625))) / .9375

xs = np.linspace(-EXT, EXT, W, dtype=np.float32)
X, Z = np.meshgrid(xs, xs)
r = np.hypot(X, Z); ang = np.degrees(np.arctan2(Z, X))
n1, n2, n3 = fbm(), fbm(), fbm()
bay = L["bay"]
rc = L["coast_radius"] + L["coast_noise"] * (2 * n1 - 1) - bay["depth"] * np.exp(-(ang - bay["angle_deg"]) ** 2 / (2 * bay["sigma_deg"] ** 2))
land = np.clip((rc - r) / 0.05, 0, 1)
g = lambda c, s: np.exp(-((X - c[0]) ** 2 + (Z - c[1]) ** 2) / (2 * s * s))
plains = 20 + 40 * n2
fm = sig((L["forest"]["x_max"] - X) / 0.08) * sig((L["forest"]["z_abs_max"] - np.abs(Z)) / 0.08) * (0.55 + 0.45 * n3)
mb = sig((L["mountain_band_z"] - Z) / 0.06)
pk = L["peaks"]; PH = L["peak_height_studs"]; SNOW = L["snow_line_studs"]
ridge = np.exp(-(Z + 0.60) ** 2 / (2 * 0.07 ** 2)) * sig((0.45 - np.abs(X)) / 0.05)
cl = L["cliffs"]
cliffs = sig((r - cl["r_min"]) / 0.05) * np.exp(-(np.abs(ang) - cl["center_deg"]) ** 2 / (2 * cl["sigma_deg"] ** 2)) * 110
H_land = (plains + fm * 30 + mb * (250 + 330 * n3) + g(pk["main_NE"], .10) * (PH["main_NE"] - 450) + g(pk["second_NW"], .10) * (PH["second_NW"] - 450)
          + ridge * 380 + g(L["crown_hill"], .07) * 200 + cliffs)
sea = -40 - 40 * np.clip((r - 0.85) / 0.6, 0, 1)
H = land * H_land + (1 - land) * sea
for name, isl in L["isles"].items():
    d_ = np.hypot(X - isl["pos"][0], Z - isl["pos"][1])
    m = np.clip((isl["r"] * (0.85 + 0.3 * n1) - d_) / 0.015, 0, 1)
    H = m * (15 + 90 * np.exp(-d_ ** 2 / (2 * (isl["r"] * .5) ** 2))) + (1 - m) * H

def lerp(a, b, t):
    t = np.clip(t, 0, 1)[..., None]
    return np.array(a, np.float32) * (1 - t) + np.array(b, np.float32) * t
rgb = lerp((10, 40, 85), (55, 135, 185), (H + 80) / 80)
def paint(mask, col):
    global rgb
    rgb = np.where(mask[..., None], col, rgb)
paint((H >= 0) & (H < 8), np.array((214, 196, 140), np.float32))
paint((H >= 8) & (H < 100), lerp((120, 170, 75), (85, 135, 60), (H - 8) / 92))
paint((H >= 8) & (H < 100) & (fm > 0.45) & (land > 0.5), lerp((85, 135, 60), (38, 88, 45), fm * 1.4))
paint((H >= 100) & (H < 250), lerp((85, 135, 60), (125, 115, 98), (H - 100) / 150))
paint((H >= 250) & (H < SNOW), lerp((110, 100, 90), (150, 145, 140), (H - 250) / (SNOW - 250)))
paint(H >= SNOW, np.array((238, 242, 246), np.float32))
paint((cliffs > 60) & (land > 0.5) & (H > 0) & (H < 250), np.array((72, 66, 66), np.float32))
gy, gx = np.gradient(H)
shade = np.clip(1 + (-gx - gy) * 0.006, 0.55, 1.35)
shade = np.where(H > 0, shade, 1)
img = Image.fromarray(np.clip(rgb * shade[..., None], 0, 255).astype(np.uint8))
d = ImageDraw.Draw(img)
def F(s, b=False): return ImageFont.truetype("C:/Windows/Fonts/tahoma%s.ttf" % ("bd" if b else ""), s)

# grid every 4000 studs + island frame ±8000
for v in np.arange(-1.5, 1.51, 0.5):
    p = px((v, v))[0]
    d.line([(p, 0), (p, W)], fill=(200, 210, 220), width=1)
    d.line([(0, p), (W, p)], fill=(200, 210, 220), width=1)
    d.text((p + 3, W - 18), f"{int(v * HALF):+d}", font=F(12), fill=(30, 30, 30))
    d.text((4, p + 2), f"{int(v * HALF):+d}", font=F(12), fill=(30, 30, 30))
a, b = px((-1, -1)), px((1, 1))
d.rectangle([a, b], outline=(255, 230, 120), width=2)
d.text((a[0] + 6, a[1] + 4), "กรอบเกาะหลัก 16,000 x 16,000 studs", font=F(13), fill=(255, 230, 120), stroke_width=2, stroke_fill=(20, 20, 20))

def poly(pts, col, w, dash=None):
    P = [px(p) for p in pts]
    if not dash:
        d.line(P, fill=col, width=w, joint="curve"); return
    on, off = dash
    for (x0, y0), (x1, y1) in zip(P, P[1:]):
        Ln = math.hypot(x1 - x0, y1 - y0); t = 0
        while t < Ln:
            t2 = min(t + on, Ln)
            d.line([(x0 + (x1 - x0) * t / Ln, y0 + (y1 - y0) * t / Ln), (x0 + (x1 - x0) * t2 / Ln, y0 + (y1 - y0) * t2 / Ln)], fill=col, width=w)
            t += on + off
pos = lambda n: L["places"][n]["pos"]
for road in L["roads"]: poly([pos(n) for n in road], (170, 140, 95), 3, dash=(9, 6))
poly([pos(n) for n in L["railway"]], (45, 40, 40), 4)
poly([pos(n) for n in L["railway"]], (230, 230, 230), 2, dash=(6, 6))
poly(L["river_tributary"], (70, 150, 210), 3)
poly(L["river_main"], (60, 140, 205), 5)

def label(p, txt, size=15, dy=10, bold=False, col=(25, 25, 25)):
    x, y = px(p)
    d.text((x, y + dy), txt, font=F(size, bold), fill=col, anchor="mt", stroke_width=3, stroke_fill=(255, 255, 255))
for name, pl in L["places"].items():
    x, y = px(pl["pos"]); t = pl["type"]
    if t == "capital":
        d.regular_polygon((x, y, 11), 4, rotation=45, fill=(200, 60, 40), outline=(40, 20, 10))
        label(pl["pos"], name, 18, 13, True); label(pl["pos"], pl["th"], 12, 34)
    elif t == "castle":
        d.regular_polygon((x, y, 10), 3, fill=(90, 90, 100), outline=(20, 20, 20))
        label(pl["pos"], name, 15, 11, True); label(pl["pos"], pl["th"], 12, 29)
    elif t == "spire":
        d.regular_polygon((x, y, 10), 5, fill=(170, 90, 220), outline=(40, 10, 60))
        label(pl["pos"], name, 15, 11, True); label(pl["pos"], pl["th"], 12, 29)
    else:
        d.ellipse([x - 7, y - 7, x + 7, y + 7], fill=(250, 245, 230), outline=(40, 30, 20), width=2)
        label(pl["pos"], name, 15, 9, True); label(pl["pos"], pl["th"], 12, 27)
for name, c in L["caves"].items():
    x, y = px(c)
    d.pieslice([x - 8, y - 8, x + 8, y + 8], 180, 360, fill=(30, 30, 30))
    label(c, "ถ้ำ " + name, 12, 4, col=(60, 30, 10))
for name, isl in L["isles"].items():
    label(isl["pos"], name, 13, int(isl["r"] / (2 * EXT) * W) + 2, True, col=(20, 40, 70))
rk = L["rocks"]; rr = np.random.default_rng(rk["seed"]); n = 0
while n < rk["count"]:
    rad, th = rr.uniform(rk["r_min"], rk["r_max"]), rr.uniform(0, 2 * math.pi)
    p = (rad * math.cos(th), rad * math.sin(th))
    if max(abs(p[0]), abs(p[1])) > EXT - 0.05: continue
    if any(math.hypot(p[0] - i["pos"][0], p[1] - i["pos"][1]) < i["r"] + 0.05 for i in L["isles"].values()): continue
    x, y = px(p)
    d.ellipse([x - 4, y - 3, x + 4, y + 3], fill=(120, 115, 110), outline=(60, 60, 60)); n += 1

# title, compass, scale, legend
d.text((18, 14), "ARTURE  แผนที่ตัวอย่าง v1", font=F(30, True), fill=(255, 255, 255), stroke_width=3, stroke_fill=(20, 30, 50))
d.text((18, 52), "มุมบน  เหนือ = บน (-Z)  ระดับน้ำ Y=0  ตัวเลขขอบ = studs  ทะเล Terrain ต่อถึง +-16,000 (นอกภาพ)", font=F(13), fill=(255, 255, 255), stroke_width=2, stroke_fill=(20, 30, 50))
cx, cy = W - 70, 80
d.polygon([(cx, cy - 40), (cx - 12, cy + 8), (cx + 12, cy + 8)], fill=(230, 60, 40), outline=(255, 255, 255))
d.text((cx, cy + 14), "N", font=F(22, True), fill=(255, 255, 255), anchor="mt", stroke_width=2, stroke_fill=(0, 0, 0))
sx, sy, sl = W - 260, W - 46, 2000 / HALF / (2 * EXT) * W
d.line([(sx, sy), (sx + sl, sy)], fill=(255, 255, 255), width=4)
d.text((sx + sl / 2, sy - 20), "2,000 studs", font=F(13, True), fill=(255, 255, 255), anchor="mt", stroke_width=2, stroke_fill=(0, 0, 0))
leg = [((30, 90, 150), "ทะเล (ลึก -> ตื้น)"), ((214, 196, 140), "หาดทราย 0-8"), ((100, 150, 65), "ทุ่งหญ้า 20-60"),
       ((38, 88, 45), "ป่าตะวันตก 30-90"), ((125, 115, 98), "เนิน / Crown Hill 100-250"), ((140, 135, 130), "เขาเหนือ 250-2,000"),
       ((238, 242, 246), "หิมะ > 1,200"), ((72, 66, 66), "หน้าผาตะวันตก"), ((60, 140, 205), "แม่น้ำ"), ((170, 140, 95), "ถนน (เส้นประ)"),
       ((45, 40, 40), "รถไฟ"), ((30, 30, 30), "ถ้ำ")]
lx, ly = 18, W - 22 - 22 * len(leg) - 10
d.rectangle([lx - 8, ly - 8, lx + 250, W - 14], fill=(255, 255, 255), outline=(60, 60, 60))
for i, (c, t) in enumerate(leg):
    y = ly + i * 22
    d.rectangle([lx, y, lx + 18, y + 14], fill=c, outline=(40, 40, 40))
    d.text((lx + 26, y - 1), t, font=F(13), fill=(20, 20, 20))
img.save("map-arture-v1.png")
print("saved map-arture-v1.png", img.size)
