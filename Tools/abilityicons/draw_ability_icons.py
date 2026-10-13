#!/usr/bin/env python3
"""Draw the ability icons in LuaUI/Images/abilities/.

The icons are drawn by this script in one style: a light, single-color symbol
on a transparent background (128x128), meant to sit on a dark tile. To change
an icon, edit its function below and run:

    python3 Tools/abilityicons/draw_ability_icons.py

Needs Python 3 with Pillow. File names match the `icon` fields of the
ABILITIES table in LuaUI/Widgets/gui_rml_abilities.lua.
"""
import math
import os

from PIL import Image, ImageDraw

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
SIZE = 128                  # size of the finished icon
S = 1024                    # icons are drawn on a 1024x1024 sheet and scaled down
COLOR = (240, 244, 248)     # the HUD's heading color (#f0f4f8)
C = S // 2


def sheet():
    image = Image.new("L", (S, S), 0)
    return image, ImageDraw.Draw(image)


def disc(d, x, y, r, fill=255):
    d.ellipse((x - r, y - r, x + r, y + r), fill=fill)


def ring(d, x, y, r, w):
    """A circle outline whose outer edge is at radius r."""
    disc(d, x, y, r)
    disc(d, x, y, r - w, 0)


def seg(d, a, b, w, fill=255):
    """A line with round ends."""
    d.line([a, b], fill=fill, width=w)
    disc(d, a[0], a[1], w / 2, fill)
    disc(d, b[0], b[1], w / 2, fill)


def polar(r, degrees, cx=C, cy=C):
    """A point at a distance and an angle (clockwise from 3 o'clock)."""
    return (cx + r * math.cos(math.radians(degrees)), cy + r * math.sin(math.radians(degrees)))


def chevron(d, cx, cy, half_width, rise, w, fill=255):
    """An upward chevron whose point is at (cx, cy)."""
    seg(d, (cx - half_width, cy + rise), (cx, cy), w, fill)
    seg(d, (cx + half_width, cy + rise), (cx, cy), w, fill)


def scanner_sweep():
    """Scanner Sweep: a scope, its beam partway round, and something found."""
    image, d = sheet()
    ring(d, C, C, 410, 58)
    ring(d, C, C, 236, 46)
    # the beam: a wedge from the center, with a gap between it and the rings
    d.pieslice((C - 330, C - 330, C + 330, C + 330), -90, -28, fill=0)
    d.pieslice((C - 300, C - 300, C + 300, C + 300), -84, -34, fill=255)
    disc(d, C, C, 72, 0)
    disc(d, C, C, 44)
    # the contact, in the quarter the beam has just left
    disc(d, *polar(300, 148), 70, 0)
    disc(d, *polar(300, 148), 46)
    return image


def weapons_upgrade():
    """Weapons Upgrade: a gunsight."""
    image, d = sheet()
    ring(d, C, C, 340, 80)
    for angle in (0, 90, 180, 270):
        # each tick crosses the ring, with a gap cut around it
        seg(d, polar(190, angle), polar(440, angle), 136, 0)
        seg(d, polar(205, angle), polar(420, angle), 76)
    disc(d, C, C, 70)
    return image


def shield_outline(scale):
    """The points of a shield, scaled about its middle."""
    points = [(-300, -340), (300, -340), (300, 20)]
    # the lower edge curves in to a point
    for step in range(1, 12):
        t = step / 12
        points.append((300 * (1 - t) ** 0.55, 20 + 370 * t))
    points.append((0, 390))
    for step in range(11, 0, -1):
        t = step / 12
        points.append((-300 * (1 - t) ** 0.55, 20 + 370 * t))
    points.append((-300, 20))
    return [(C + x * scale, C - 10 + y * scale) for x, y in points]


def armor_upgrade():
    """Armor Upgrade: a shield, with plating stacked inside it."""
    image, d = sheet()
    d.polygon(shield_outline(1.0), fill=255)
    d.polygon(shield_outline(0.80), fill=0)
    chevron(d, C, 360, 130, 110, 56)
    chevron(d, C, 520, 130, 110, 56)
    return image


def production_boost():
    """Production Boost: a gear with a bolt of power through it."""
    image, d = sheet()
    teeth = 8
    for i in range(teeth):
        angle = i * 360 / teeth
        half = 15                  # half the width of a tooth, in degrees
        d.polygon([polar(280, angle - half - 4), polar(420, angle - half + 3),
                   polar(420, angle + half - 3), polar(280, angle + half + 4)], fill=255)
    disc(d, C, C, 320)
    # the bolt is cut out of the gear, with a margin so it reads at small sizes
    bolt = [(560, 250), (392, 548), (498, 548), (452, 782), (640, 468), (530, 468), (590, 250)]
    d.polygon(bolt, fill=0)
    return image


ICONS = {
    "scanner_sweep": scanner_sweep,
    "weapons_upgrade": weapons_upgrade,
    "armor_upgrade": armor_upgrade,
    "production_boost": production_boost,
}


def main():
    for name, draw in ICONS.items():
        mask = draw().resize((SIZE, SIZE), Image.LANCZOS)
        # The engine's RmlUi draws images as premultiplied alpha: a pixel's
        # color is added to the screen as it is, whatever its alpha. So the
        # color is multiplied by the alpha here, which leaves the transparent
        # parts black. (With full color there, the whole tile turns white.)
        channels = [mask.point(lambda a, c=c: a * c // 255) for c in COLOR]
        icon = Image.merge("RGBA", channels + [mask])
        path = os.path.join(ROOT, "LuaUI", "Images", "abilities", name + ".png")
        icon.save(path, optimize=True)
        print("drew", os.path.relpath(path, ROOT))


if __name__ == "__main__":
    main()
