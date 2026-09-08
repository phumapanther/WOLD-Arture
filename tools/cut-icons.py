# Cuts an item-icon sheet into one transparent PNG per icon.
#
# The sheet is not a strict grid -- the armor stand is far taller than a key, and the columns are unevenly
# spaced -- so the icons are found by their own alpha instead: label every connected island of non-transparent
# pixels, drop specks, then sort the survivors into visual rows. That way a re-drawn sheet with different
# spacing still cuts correctly.
import sys, json
from pathlib import Path
import numpy as np
from PIL import Image

ALPHA_MIN = 12      # below this a pixel counts as background
MIN_AREA  = 900     # islands smaller than this are anti-aliasing specks, not icons
PAD       = 8       # transparent breathing room kept around each cut
ROW_TOL   = 0.35    # two icons are on the same row if their vertical centres are within this * row height

def islands(alpha):
    """Connected components of the alpha mask, via iterative flood fill (no scipy needed)."""
    h, w = alpha.shape
    mask = alpha > ALPHA_MIN
    seen = np.zeros((h, w), dtype=bool)
    boxes = []
    for y in range(h):
        for x in range(w):
            if not mask[y, x] or seen[y, x]:
                continue
            # Flood fill this island, tracking its bounding box.
            stack = [(y, x)]
            seen[y, x] = True
            x0 = x1 = x
            y0 = y1 = y
            area = 0
            while stack:
                cy, cx = stack.pop()
                area += 1
                if cx < x0: x0 = cx
                if cx > x1: x1 = cx
                if cy < y0: y0 = cy
                if cy > y1: y1 = cy
                for dy in (-1, 0, 1):
                    for dx in (-1, 0, 1):
                        ny, nx = cy + dy, cx + dx
                        if 0 <= ny < h and 0 <= nx < w and mask[ny, nx] and not seen[ny, nx]:
                            seen[ny, nx] = True
                            stack.append((ny, nx))
            if area >= MIN_AREA:
                boxes.append([x0, y0, x1, y1, area])
    return boxes

def split_touching(mask, cell):
    """Split a column run that holds more than one icon.

    Most icons are separated by an empty column and never reach here. The exception on this sheet is the bow
    and the staff: they lean toward each other, so no empty column divides them and their bounding boxes
    overlap. Each is still ONE connected component, so splitting on components -- and masking each crop to
    the component it owns -- separates them exactly, with no pixels of the neighbour left behind.
    """
    x0, y0, x1, y1, area = cell
    sub = mask[y0:y1 + 1, x0:x1 + 1]
    comps = components(sub)

    # Only components big enough to be an icon in their own right count as separate icons.
    icons = [c for c in comps if c[4] >= MIN_AREA * 3]
    if len(icons) < 2:
        return [cell]

    # ...and they must actually stand side by side, or this is one drawing made of several parts.
    icons.sort(key=lambda c: c[0])
    width = x1 - x0 + 1
    spread = (icons[-1][0] + icons[-1][2]) / 2 - (icons[0][0] + icons[0][2]) / 2
    if spread < width * 0.25:
        return [cell]

    masks = [c[5] for c in icons]

    # Small leftovers (anti-aliasing crumbs) join whichever icon's pixels they sit nearest.
    for c in comps:
        if any(c[0] == ic[0] and c[1] == ic[1] and c[4] == ic[4] for ic in icons):
            continue
        piece = c[5]
        cy, cx = np.argwhere(piece).mean(axis=0)
        best = min(range(len(icons)), key=lambda i: min(
            (abs(cy - py) + abs(cx - px)) for py, px in [np.argwhere(masks[i]).mean(axis=0)]))
        masks[best] |= piece

    out = []
    for own in masks:
        ys, xs = np.where(own)
        out.append([x0 + int(xs.min()), y0 + int(ys.min()),
                    x0 + int(xs.max()), y0 + int(ys.max()),
                    int(own.sum()), (x0, y0, own)])
    return out


def components(sub):
    """Connected components of a small mask.

    Each entry is [x0, y0, x1, y1, area, pixels] where `pixels` is the component's own boolean mask. The
    mask is returned here rather than re-found later from the bounding box: two leaning icons have
    overlapping boxes, so a box-based flood fill starts on whichever component happens to come first and
    returns the same shape twice.
    """
    h, w = sub.shape
    seen = np.zeros((h, w), dtype=bool)
    out = []
    for y in range(h):
        for x in range(w):
            if not sub[y, x] or seen[y, x]:
                continue
            own = np.zeros((h, w), dtype=bool)
            stack = [(y, x)]
            seen[y, x] = True
            own[y, x] = True
            x0 = x1 = x; y0 = y1 = y; area = 0
            while stack:
                cy, cx = stack.pop()
                area += 1
                if cx < x0: x0 = cx
                if cx > x1: x1 = cx
                if cy < y0: y0 = cy
                if cy > y1: y1 = cy
                for dy in (-1, 0, 1):
                    for dx in (-1, 0, 1):
                        ny, nx = cy + dy, cx + dx
                        if 0 <= ny < h and 0 <= nx < w and sub[ny, nx] and not seen[ny, nx]:
                            seen[ny, nx] = True
                            own[ny, nx] = True
                            stack.append((ny, nx))
            out.append([x0, y0, x1, y1, area, own])
    return out


def bands(mask, axis):
    """Runs of non-empty rows (axis=1) or columns (axis=0) in the alpha mask."""
    counts = mask.sum(axis=axis)
    out, start, inside = [], 0, False
    for i, v in enumerate(counts):
        if v > 0 and not inside:
            start, inside = i, True
        elif v == 0 and inside:
            out.append((start, i - 1))
            inside = False
    if inside:
        out.append((start, len(counts) - 1))
    return out


def rows_of(boxes):
    """Group boxes into visual rows, then order each row left to right."""
    boxes = sorted(boxes, key=lambda b: (b[1] + b[3]) / 2)
    rows, cur = [], [boxes[0]]
    for b in boxes[1:]:
        cy_cur = sum((c[1] + c[3]) / 2 for c in cur) / len(cur)
        h_cur = max(c[3] - c[1] for c in cur)
        if abs((b[1] + b[3]) / 2 - cy_cur) <= h_cur * ROW_TOL + 40:
            cur.append(b)
        else:
            rows.append(sorted(cur, key=lambda c: c[0]))
            cur = [b]
    rows.append(sorted(cur, key=lambda c: c[0]))
    return rows

def main():
    src, outdir = Path(sys.argv[1]), Path(sys.argv[2])
    names = json.loads(Path(sys.argv[3]).read_text(encoding="utf-8")) if len(sys.argv) > 3 else None

    img = Image.open(src).convert("RGBA")
    mask = np.array(img)[:, :, 3] > ALPHA_MIN

    # Icons are separated by fully empty stripes: horizontal ones between rows, vertical ones between the
    # icons of a row. Cutting on those stripes needs no bounding boxes at all, which is what kept welding
    # the bow to the staff (their diagonal boxes overlap) or splitting a woodpile (its sticks do not touch).
    rows = []
    for y0, y1 in bands(mask, 1):
        if y1 - y0 < 20:
            continue  # a stray speck line, not a row of icons
        strip = mask[y0:y1 + 1]
        row = []
        for x0, x1 in bands(strip, 0):
            sub = strip[:, x0:x1 + 1]
            if sub.sum() < MIN_AREA:
                continue
            # Trim the icon's own top and bottom inside this column.
            ys = np.where(sub.any(axis=1))[0]
            row.append([x0, y0 + int(ys[0]), x1, y0 + int(ys[-1]), int(sub.sum())])
        # One column run can still hold two icons: on this sheet the bow and the staff lean toward each
        # other so their columns never fully separate (measured: no empty column between x=350 and x=755).
        # Split such a run on its own connected components when they are clearly side by side.
        row = [piece for cell in row for piece in split_touching(mask, cell)]
        if row:
            rows.append(row)

    outdir.mkdir(parents=True, exist_ok=True)
    flat, report = [], []
    for r, row in enumerate(rows):
        report.append(f"row {r+1}: {len(row)} icons")
        for b in row:
            flat.append(b)

    print(f"sheet {img.width}x{img.height} -> {len(flat)} icons in {len(rows)} rows")
    for line in report:
        print(" ", line)

    if names and len(names) != len(flat):
        print(f"!! names list has {len(names)} entries but {len(flat)} icons were found; writing numbered files")
        names = None

    for i, cell in enumerate(flat):
        x0, y0, x1, y1 = cell[0], cell[1], cell[2], cell[3]
        x0 = max(0, x0 - PAD); y0 = max(0, y0 - PAD)
        x1 = min(img.width - 1, x1 + PAD); y1 = min(img.height - 1, y1 + PAD)
        crop = img.crop((x0, y0, x1 + 1, y1 + 1))
        owned = cell[5] if len(cell) > 5 else None
        if owned:
            # Erase whatever belongs to the icon standing beside this one.
            # `own` covers the whole column run the icon was split out of, so take just the part that lands
            # inside this crop rather than assuming the two are the same size.
            ox, oy, own = owned
            keep = np.zeros((crop.height, crop.width), dtype=bool)
            oh, ow = own.shape
            sy0 = max(0, y0 - oy); sx0 = max(0, x0 - ox)
            sy1 = min(oh, y1 + 1 - oy); sx1 = min(ow, x1 + 1 - ox)
            if sy1 > sy0 and sx1 > sx0:
                piece = own[sy0:sy1, sx0:sx1]
                ty0 = max(0, oy - y0); tx0 = max(0, ox - x0)
                keep[ty0:ty0 + piece.shape[0], tx0:tx0 + piece.shape[1]] = piece
            px = np.array(crop)
            px[:, :, 3] = np.where(keep, px[:, :, 3], 0)
            crop = Image.fromarray(px)
        name = names[i] if names else f"icon_{i+1:02d}"
        crop.save(outdir / f"{name}.png")
        print(f"  {name}.png  {crop.width}x{crop.height}")

main()
