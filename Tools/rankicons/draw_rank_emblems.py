#!/usr/bin/env python3
"""Draws the four rank-track emblems for the Bastion HUD.

Output: LuaUI/Images/rml/rank_<track>.png, 128x128, premultiplied alpha
(the engine's RmlUi draws images as premultiplied; see draw_ability_icons.py).

Each emblem is drawn in two colors on transparency: the ember accent
(#ff9b21) for the "key" element and the HUD text color (#c2ccd6) for the
rest, the same two the mockup used. Everything is drawn 8x and downscaled.

Run from anywhere: python3 Tools/rankicons/draw_rank_emblems.py
"""

import math
import os

from PIL import Image, ImageDraw

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
SIZE = 128
BIG = SIZE * 8  # drawn at 1024 and downscaled
EMBER = (0xFF, 0x9B, 0x21)
STEEL = (0xC2, 0xCC, 0xD6)

# the mockup's SVG viewBox was 96 wide; scale its coordinates up
S = BIG / 96.0


def pt(x, y):
    return (x * S, y * S)


def poly(d, points, **kw):
    d.polygon([pt(x, y) for x, y in points], **kw)


def stroke_poly(d, points, width, closed=True):
    pts = [pt(x, y) for x, y in points]
    if closed:
        pts.append(pts[0])
    d.line(pts, fill=255, width=int(width * S), joint="curve")
    # round the joins, which PIL's joint="curve" does not fully do
    r = width * S / 2
    for x, y in pts:
        d.ellipse([x - r, y - r, x + r, y + r], fill=255)


def ring(d, cx, cy, r, width):
    o, i = r + width / 2, r - width / 2
    d.ellipse([pt(cx - o, cy - o), pt(cx + o, cy + o)], fill=255)
    d.ellipse([pt(cx - i, cy - i), pt(cx + i, cy + i)], fill=0)


def layer():
    mask = Image.new("L", (BIG, BIG), 0)
    return mask, ImageDraw.Draw(mask)


# Each function returns (ember_mask, steel_mask)

def combat():
    ember, de = layer()
    steel, ds = layer()
    poly(de, [(18, 70), (76, 20), (26, 78)], fill=255)
    stroke_poly(ds, [(78, 70), (20, 20), (70, 78)], 4)
    # the square boss where the blades cross, cut out of both then outlined
    ds.rectangle([pt(40.5, 41.5), pt(55.5, 56.5)], fill=255)
    hole = Image.new("L", (BIG, BIG), 0)
    ImageDraw.Draw(hole).rectangle([pt(43.5, 44.5), pt(52.5, 53.5)], fill=255)
    ember.paste(0, mask=steel)
    steel.paste(0, mask=hole)
    ember.paste(0, mask=hole)
    return ember, steel


def economy():
    ember, de = layer()
    steel, ds = layer()
    stroke_poly(ds, [(10, 48), (29, 15), (67, 15), (86, 48), (67, 81), (29, 81)], 4)
    ds.rectangle([pt(30, 56), pt(39, 68)], fill=255)
    ds.rectangle([pt(43.5, 46), pt(52.5, 68)], fill=255)
    de.rectangle([pt(57, 32), pt(66, 68)], fill=255)
    return ember, steel


def industry():
    ember, de = layer()
    steel, ds = layer()
    # the cog: a thick ring with 12 gaps cut out of it
    ring(ds, 48, 48, 36, 10)
    cut = Image.new("L", (BIG, BIG), 0)
    dc = ImageDraw.Draw(cut)
    step = 2 * math.pi / 12
    half = step * 0.29  # the gap between two teeth, as an angle
    for k in range(12):
        a = (k + 0.5) * step
        wedge = []
        for ang in (a - half, a + half):
            wedge.append((48 + 30 * math.cos(ang), 48 + 30 * math.sin(ang)))
        for ang in (a + half, a - half):
            wedge.append((48 + 44 * math.cos(ang), 48 + 44 * math.sin(ang)))
        poly(dc, wedge, fill=255)
    steel.paste(0, mask=cut)
    ring(ds, 48, 48, 28, 5)
    poly(de, [(38, 30), (58, 30), (48, 66)], fill=255)
    return ember, steel


def territory():
    ember, de = layer()
    steel, ds = layer()
    poly(de, [(48, 16), (60, 23), (60, 37), (48, 44), (36, 37), (36, 23)], fill=255)
    stroke_poly(ds, [(31, 44), (43, 51), (43, 65), (31, 72), (19, 65), (19, 51)], 4)
    stroke_poly(ds, [(65, 44), (77, 51), (77, 65), (65, 72), (53, 65), (53, 51)], 4)
    return ember, steel


def weapons():
    """A shell: the shard pointing up, flanked by two angled steel lines."""
    ember, de = layer()
    steel, ds = layer()
    poly(de, [(48, 12), (60, 44), (60, 78), (36, 78), (36, 44)], fill=255)
    ds.line([pt(24, 76), pt(24, 46), pt(38, 22)], fill=255, width=int(4 * S), joint="curve")
    ds.line([pt(72, 76), pt(72, 46), pt(58, 22)], fill=255, width=int(4 * S), joint="curve")
    # a dark groove splits the shell head from its body
    hole = Image.new("L", (BIG, BIG), 0)
    ImageDraw.Draw(hole).rectangle([pt(36, 50), pt(60, 54)], fill=255)
    ember.paste(0, mask=hole)
    return ember, steel


def armor():
    """A plate: a square frame with a smaller ember plate set into it."""
    ember, de = layer()
    steel, ds = layer()
    stroke_poly(ds, [(16, 14), (80, 14), (80, 66), (48, 84), (16, 66)], 4)
    poly(de, [(32, 28), (64, 28), (64, 58), (48, 68), (32, 58)], fill=255)
    return ember, steel


def comeback():
    """A rising arrow out of a dip: the line falls, then climbs in ember."""
    ember, de = layer()
    steel, ds = layer()
    ds.line([pt(14, 30), pt(34, 62)], fill=255, width=int(5 * S))
    de.line([pt(34, 62), pt(70, 26)], fill=255, width=int(5 * S))
    poly(de, [(58, 20), (80, 16), (76, 38)], fill=255)
    stroke_poly(ds, [(10, 80), (86, 80)], 3, closed=False)
    return ember, steel


def firstblood():
    """A single drop over a thin ring."""
    ember, de = layer()
    steel, ds = layer()
    ring(ds, 48, 52, 30, 4)
    poly(de, [(48, 22), (62, 46), (62, 54), (48, 70), (34, 54), (34, 46)], fill=255)
    de.ellipse([pt(34, 44), pt(62, 70)], fill=255)
    return ember, steel


def efficient():
    """A ratio: a big ember block over a small steel one, split by a slash."""
    ember, de = layer()
    steel, ds = layer()
    ds.line([pt(30, 84), pt(66, 12)], fill=255, width=int(5 * S))
    poly(de, [(14, 16), (44, 16), (44, 46), (14, 46)], fill=255)
    ds.rectangle([pt(58, 58), pt(78, 78)], fill=255)
    return ember, steel


def juggernaut():
    """A skull-sized target: a big ember hex with a steel reticle over it."""
    ember, de = layer()
    steel, ds = layer()
    poly(de, [(48, 10), (80, 29), (80, 67), (48, 86), (16, 67), (16, 29)], fill=255)
    ring(ds, 48, 48, 20, 4)
    for a, b in (((48, 22), (48, 34)), ((48, 62), (48, 74)), ((22, 48), (34, 48)), ((62, 48), (74, 48))):
        ds.line([pt(*a), pt(*b)], fill=255, width=int(4 * S))
    return ember, steel


EMBLEMS = {
    "comeback": comeback,
    "firstblood": firstblood,
    "efficient": efficient,
    "juggernaut": juggernaut,
    "weapons": weapons,
    "armor": armor,
    "combat": combat,
    "economy": economy,
    "industry": industry,
    "territory": territory,
}


def premultiplied(ember_mask, steel_mask):
    """Composes the two single-color layers into one premultiplied RGBA image."""
    ember_mask = ember_mask.resize((SIZE, SIZE), Image.LANCZOS)
    steel_mask = steel_mask.resize((SIZE, SIZE), Image.LANCZOS)
    out = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    px = out.load()
    pe, ps = ember_mask.load(), steel_mask.load()
    for y in range(SIZE):
        for x in range(SIZE):
            ae, as_ = pe[x, y] / 255.0, ps[x, y] / 255.0
            # steel drawn over ember
            a = as_ + ae * (1 - as_)
            r = STEEL[0] * as_ + EMBER[0] * ae * (1 - as_)
            g = STEEL[1] * as_ + EMBER[1] * ae * (1 - as_)
            b = STEEL[2] * as_ + EMBER[2] * ae * (1 - as_)
            # r, g, b are already multiplied by alpha here
            px[x, y] = (int(r + 0.5), int(g + 0.5), int(b + 0.5), int(a * 255 + 0.5))
    return out


def chevron(color, path):
    """A small upward chevron, the rank tally under a badge (24x14)."""
    w, h, k = 24, 14, 8
    mask = Image.new("L", (w * k, h * k), 0)
    d = ImageDraw.Draw(mask)
    d.line([(2 * k, 12 * k), (12 * k, 2 * k), (22 * k, 12 * k)], fill=255, width=int(2.5 * k), joint="curve")
    mask = mask.resize((w, h), Image.LANCZOS)
    channels = [mask.point(lambda a, c=c: a * c // 255) for c in color]
    Image.merge("RGBA", channels + [mask]).save(path, optimize=True)
    print("drew", os.path.relpath(path, ROOT))


def main():
    out_dir = os.path.join(ROOT, "LuaUI", "Images", "rml")
    for name, draw in EMBLEMS.items():
        ember_mask, steel_mask = draw()
        icon = premultiplied(ember_mask, steel_mask)
        path = os.path.join(out_dir, "rank_" + name + ".png")
        icon.save(path, optimize=True)
        print("drew", os.path.relpath(path, ROOT))
    chevron(STEEL, os.path.join(out_dir, "rank_chevron.png"))
    chevron(EMBER, os.path.join(out_dir, "rank_chevron_ember.png"))


if __name__ == "__main__":
    main()
