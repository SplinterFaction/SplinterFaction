#!/usr/bin/env python3
"""Draws SplinterFaction's mouse cursors from scratch.

    python3 Tools/cursors/make_cursors.py [--previews DIR] [--no-write] [--only STYLE]

Writes Anims/cursor<name>_<n>.png and Anims/cursor<name>.txt (the engine's
cursor animation spec), which is where the engine looks for the game's
cursors. Every Anims/cursor* file is replaced, so this script is the only
source of them; nothing is copied from older cursor art.

The game's set is "forboding": the motifs of the old Forboding Angel set (red
blades closing on a sight, lights walking a beat, crates, two halves welded,
the green dart, the red W), redrawn as vectors at 6x the final size, in the
colours of the order lines, 36 frames at 30 a second. Each cursor is one
function, h_<name> (a few fall back on a b_<name> glyph), and style_forboding
gives the drawing its gradient, bevel, outline and glow.

The file also holds the other looks tried along the way (STYLES, and the older
c_ / fx_ / b_ drawings). They are not written unless asked for with --only,
which puts them in Anims/<style>/; --previews DIR writes an animated GIF.
"""
import argparse, math, os, sys
import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont, ImageChops

SS = 6                      # supersampling
FRAMES = 24                 # frames per loop
FRAME_TIME = 0.04           # seconds per frame
HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.normpath(os.path.join(HERE, "..", ".."))
OUT = os.path.join(REPO, "Anims")

WHITE = (240, 244, 248)
DARK = (11, 14, 18)
ORANGE = (255, 155, 33)

TAU = math.tau


def lerp(a, b, t):
    return a + (b - a) * t


def mix(c1, c2, t):
    return tuple(int(round(lerp(a, b, t))) for a, b in zip(c1, c2))


def pulse(t, power=1.0):
    """0..1..0 over one loop, smooth."""
    return (0.5 - 0.5 * math.cos(TAU * t)) ** power


def saw(t):
    return t % 1.0


def ease_out(x):
    return 1 - (1 - x) ** 3


class G:
    """One frame: draws in unit coordinates (0,0 centre, +-1 the usable edge, y down)."""

    def __init__(self, size, scale=1):
        self.size = size
        self.px = size * scale * SS
        self.scale = scale
        self.r = self.px / 2 * 0.90
        self.c = self.px / 2
        self.layers = []          # (image, glow strength)
        self.t = 0.0
        self.wscale = 1.0         # every line this much wider (a style may ask for chunkier shapes)
        self.fx = True            # draw the flash layer
        self.style = None
        self.rot = 0.0            # everything drawn is turned by this (turns, clockwise) about the centre
        self.zoom = 1.0           # ... and scaled by this, about the centre
        self.new_layer()

    def new_layer(self, glow=1.0):
        self.img = Image.new("RGBA", (self.px, self.px), (0, 0, 0, 0))
        self.d = ImageDraw.Draw(self.img)
        self.layers.append((self.img, glow))

    # -- coordinates
    def P(self, x, y):
        if self.rot:
            ca, sa = math.cos(TAU * self.rot), math.sin(TAU * self.rot)
            x, y = x * ca - y * sa, x * sa + y * ca
        return (self.c + x * self.r * self.zoom, self.c + y * self.r * self.zoom)

    def W(self, w):
        return max(1, int(round(w * self.r * self.wscale * self.zoom)))

    @staticmethod
    def col(color, alpha=1.0):
        return (color[0], color[1], color[2], int(round(255 * max(0.0, min(1.0, alpha)))))

    # -- primitives
    def line(self, pts, w, color, alpha=1.0, closed=False):
        pts = [self.P(*p) for p in pts]
        if closed:
            pts = pts + [pts[0]]
        wpx = self.W(w)
        self.d.line(pts, fill=self.col(color, alpha), width=wpx, joint="curve")
        rr = wpx / 2
        for x, y in (pts if not closed else pts[:-1]):       # round caps and joins
            self.d.ellipse((x - rr, y - rr, x + rr, y + rr), fill=self.col(color, alpha))

    def poly(self, pts, color, alpha=1.0):
        self.d.polygon([self.P(*p) for p in pts], fill=self.col(color, alpha))

    def erase(self, pts):
        """Cuts a hole in what this layer holds so far."""
        self.d.polygon([self.P(*p) for p in pts], fill=(0, 0, 0, 0))

    def erase_dot(self, x, y, r):
        cx, cy = self.P(x, y)
        rr = r * self.r * self.zoom
        self.d.ellipse((cx - rr, cy - rr, cx + rr, cy + rr), fill=(0, 0, 0, 0))

    def band(self, r0, r1, a0, a1, color, alpha=1.0, cx=0.0, cy=0.0):
        """A solid piece of a ring between radii r0 and r1, from angle a0 to a1 (turns), square ended."""
        n = max(3, int(abs(a1 - a0) * 96))
        outer, inner = [], []
        for i in range(n + 1):
            a = TAU * lerp(a0, a1, i / n)
            outer.append((cx + r1 * math.sin(a), cy - r1 * math.cos(a)))
            inner.append((cx + r0 * math.sin(a), cy - r0 * math.cos(a)))
        self.poly(outer + inner[::-1], color, alpha)

    def bar(self, p0, p1, w, color, alpha=1.0):
        """A solid straight bar of width w, square ended."""
        dx, dy = p1[0] - p0[0], p1[1] - p0[1]
        n = math.hypot(dx, dy) or 1.0
        nx, ny = -dy / n * w / 2, dx / n * w / 2
        self.poly([(p0[0] + nx, p0[1] + ny), (p1[0] + nx, p1[1] + ny), (p1[0] - nx, p1[1] - ny), (p0[0] - nx, p0[1] - ny)], color, alpha)

    def dot(self, x, y, r, color, alpha=1.0):
        cx, cy = self.P(x, y)
        rr = r * self.r * self.zoom
        self.d.ellipse((cx - rr, cy - rr, cx + rr, cy + rr), fill=self.col(color, alpha))

    def arc(self, r, a0, a1, w, color, alpha=1.0, cx=0.0, cy=0.0):
        """Arc from angle a0 to a1 (turns, 0 = up, clockwise)."""
        n = max(4, int(abs(a1 - a0) * 96))
        pts = []
        for i in range(n + 1):
            a = TAU * lerp(a0, a1, i / n)
            pts.append((cx + r * math.sin(a), cy - r * math.cos(a)))
        self.line(pts, w, color, alpha)

    def ring(self, r, w, color, alpha=1.0, cx=0.0, cy=0.0):
        self.arc(r, 0, 1, w, color, alpha, cx, cy)

    def segments(self, r, n, fill, rot, w, color, alpha=1.0):
        """n arcs around a ring, each `fill` of its share, turned by rot (turns)."""
        for i in range(n):
            a0 = rot + i / n + (1 - fill) / (2 * n)
            self.arc(r, a0, a0 + fill / n, w, color, alpha)

    def chevron(self, x, y, ang, size, w, color, alpha=1.0, spread=0.62):
        """A V pointing along ang (turns, 0 = up)."""
        a = TAU * ang
        dx, dy = math.sin(a), -math.cos(a)
        nx, ny = -dy, dx
        tip = (x + dx * size * 0.5, y + dy * size * 0.5)
        l = (x - dx * size * 0.5 + nx * size * spread, y - dy * size * 0.5 + ny * size * spread)
        r_ = (x - dx * size * 0.5 - nx * size * spread, y - dy * size * 0.5 - ny * size * spread)
        self.line([l, tip, r_], w, color, alpha)

    def arrowhead(self, x, y, ang, size, color, alpha=1.0):
        a = TAU * ang
        dx, dy = math.sin(a), -math.cos(a)
        nx, ny = -dy, dx
        self.poly([(x + dx * size, y + dy * size),
                   (x - dx * size * 0.6 + nx * size * 0.8, y - dy * size * 0.6 + ny * size * 0.8),
                   (x - dx * size * 0.6 - nx * size * 0.8, y - dy * size * 0.6 - ny * size * 0.8)], color, alpha)

    def brackets(self, half, length, w, color, alpha=1.0, rot=0.0):
        """Four corner brackets of a square of half-size `half`."""
        for sx, sy in ((-1, -1), (1, -1), (1, 1), (-1, 1)):
            pts = [(sx * half, sy * (half - length)), (sx * half, sy * half), (sx * (half - length), sy * half)]
            if rot:
                ca, sa = math.cos(TAU * rot), math.sin(TAU * rot)
                pts = [(x * ca - y * sa, x * sa + y * ca) for x, y in pts]
            self.line(pts, w, color, alpha)

    # -- finishing: dark rim, glow, core
    def render(self):
        out = Image.new("RGBA", (self.px, self.px), (0, 0, 0, 0))
        total = Image.new("L", (self.px, self.px), 0)
        for img, _ in self.layers:
            total = ImageChops.lighter(total, img.getchannel("A"))
        # dark rim: the shapes grown a little, in near-black
        rim = total.filter(ImageFilter.GaussianBlur(SS * self.scale * 0.9)).point(lambda v: min(255, int(v * 3.2)))
        dark = Image.new("RGBA", (self.px, self.px), DARK + (0,))
        dark.putalpha(rim.point(lambda v: int(v * 0.82)))
        out = Image.alpha_composite(out, dark)
        for img, glow in self.layers:
            if glow > 0:
                g = img.filter(ImageFilter.GaussianBlur(SS * self.scale * 1.7))
                g.putalpha(g.getchannel("A").point(lambda v, k=glow: min(255, int(v * 1.25 * k))))
                out = Image.alpha_composite(out, g)
            if glow >= 1.9:      # the flash layer: a wide bloom as well
                g = img.filter(ImageFilter.GaussianBlur(SS * self.scale * 3.4))
                g.putalpha(g.getchannel("A").point(lambda v: min(255, int(v * 2.2))))
                out = Image.alpha_composite(out, g)
        for img, _ in self.layers:
            out = Image.alpha_composite(out, img)
        final = self.size * self.scale
        return out.resize((final, final), Image.LANCZOS)


# ----------------------------------------------------------------------------
# the cursors: fn(g, t) draws frame t (0..1) of one loop
# ----------------------------------------------------------------------------

def c_normal(g, t):
    """The pointer: a faceted arrowhead, an orange spine, and a glint running down its edge."""
    # in pixel-ish coordinates of a 32 box, tip at the top left; mapped to unit space
    def U(x, y):
        return ((x - 16) / 14.4, (y - 16) / 14.4)
    body = [U(2.5, 2.5), U(2.5, 24.0), U(8.6, 18.6), U(13.2, 28.6), U(17.4, 26.6), U(12.8, 17.0), U(21.0, 16.6)]
    g.poly(body, (150, 172, 200) if g.style == "bastion" else (20, 26, 34))     # Bastion: brushed steel
    g.line(body, 0.10, WHITE, closed=True)
    # inner facet
    g.new_layer(glow=1.3)
    g.line([U(5.3, 8.0), U(5.3, 18.2)], 0.075, ORANGE)
    g.line([U(5.3, 8.0), U(13.6, 15.0)], 0.075, ORANGE, 0.55)
    # glint down the long edge, tip to heel
    k = saw(t)
    y0 = lerp(2.5, 26.0, k)
    a = math.sin(math.pi * k) ** 0.6
    g.line([U(2.5, max(2.5, y0 - 5.5)), U(2.5, min(24.0, y0))], 0.13, (255, 236, 200), a)
    g.dot(*U(2.5, 2.5), 0.11 + 0.07 * pulse(t), ORANGE, 0.55 + 0.45 * pulse(t))


def c_move(g, t, color=(110, 232, 132)):
    """Four chevrons falling inward onto a point."""
    for i in range(4):
        for j in range(2):
            k = saw(t + j * 0.5)
            dist = lerp(0.92, 0.34, ease_out(k))
            alpha = math.sin(math.pi * k) ** 0.7
            a = i / 4
            g.chevron(dist * math.sin(TAU * a), -dist * math.cos(TAU * a), a + 0.5, 0.26, 0.11, color, alpha)
    g.new_layer(glow=1.4)
    g.dot(0, 0, 0.10 + 0.04 * pulse(t * 2), WHITE)
    g.ring(0.22, 0.05, color, 0.8)


def reticle(g, t, color, spin=1.0, ticks=True):
    g.segments(0.80, 4, 0.62, spin * t / 4, 0.10, color)
    g.segments(0.56, 4, 0.30, -spin * t / 4 + 0.125, 0.07, color, 0.75)
    if ticks:
        k = pulse(t * 2)
        inner = lerp(0.16, 0.26, k)
        for a in range(4):
            dx, dy = math.sin(TAU * a / 4), -math.cos(TAU * a / 4)
            g.line([(dx * inner, dy * inner), (dx * 0.44, dy * 0.44)], 0.085, color)


def c_attack(g, t, color=(255, 72, 60)):
    """A reticle whose rings counter-rotate and whose crosshair snaps in twice a loop."""
    reticle(g, t, color)
    g.new_layer(glow=1.5)
    g.dot(0, 0, 0.075, WHITE)


def c_areaattack(g, t, color=(255, 72, 60)):
    """The attack reticle inside a dashed circle that breathes outward."""
    g.segments(lerp(0.84, 0.92, pulse(t)), 12, 0.5, t / 12, 0.07, color, 0.9)
    g.segments(0.52, 4, 0.6, -t / 4, 0.09, color)
    for a in range(4):
        dx, dy = math.sin(TAU * (a / 4 + 0.125)), -math.cos(TAU * (a / 4 + 0.125))
        g.line([(dx * 0.14, dy * 0.14), (dx * 0.34, dy * 0.34)], 0.08, color)
    g.new_layer(glow=1.5)
    g.dot(0, 0, 0.07, WHITE)


def c_setattack(g, t, color=ORANGE):
    """Set Target: lock brackets closing on a diamond, the same orange as its order line."""
    k = pulse(t * 2)
    g.brackets(lerp(0.86, 0.70, k), 0.30, 0.10, color)
    g.segments(0.50, 2, 0.55, t / 2, 0.07, color, 0.8)
    g.new_layer(glow=1.5)
    s = 0.17
    g.line([(0, -s), (s, 0), (0, s), (-s, 0)], 0.085, WHITE, closed=True)


def c_fight(g, t, color=(132, 140, 255)):
    """Attack-move: crossed blades inside a turning ring, with a spark where they meet."""
    g.segments(0.84, 3, 0.70, t / 3, 0.09, color)
    for sx in (-1, 1):
        g.line([(sx * 0.50, 0.50), (-sx * 0.46, -0.46)], 0.11, color)               # blade
        g.line([(sx * 0.26, 0.52), (sx * 0.52, 0.26)], 0.09, color)                 # guard
        g.arrowhead(-sx * 0.50, -0.50, -sx * 0.125, 0.15, color)
    g.new_layer(glow=1.6)
    g.dot(0, 0, 0.06 + 0.07 * pulse(t * 2), WHITE, 0.6 + 0.4 * pulse(t * 2))


def c_patrol(g, t, color=(84, 156, 255)):
    """Two arrows chasing each other round a loop."""
    for i in range(2):
        a0 = t + i * 0.5
        g.arc(0.66, a0, a0 + 0.36, 0.11, color)
        a = TAU * (a0 + 0.36)
        g.arrowhead(0.66 * math.sin(a), -0.66 * math.cos(a), a0 + 0.36 + 0.27, 0.21, color)
    g.new_layer(glow=1.3)
    g.dot(0, 0, 0.09, WHITE, 0.6 + 0.4 * pulse(t * 2))
    g.ring(0.26, 0.05, color, 0.7)


def c_defend(g, t, color=(96, 176, 255)):
    """Guard: a shield with a band of light sweeping up it, inside a slow ring."""
    g.segments(0.90, 6, 0.55, t / 6, 0.07, color, 0.85)
    shield = [(-0.44, -0.46), (0.0, -0.60), (0.44, -0.46), (0.44, 0.04), (0.0, 0.62), (-0.44, 0.04)]
    g.poly(shield, color, 0.22)
    g.line(shield, 0.10, color, closed=True)
    g.new_layer(glow=1.4)
    y = lerp(0.50, -0.50, saw(t))
    half = 0.40 * max(0.05, 1 - abs(y - 0.02) / 0.62) if y > 0.04 else 0.40
    g.line([(-half, y), (half, y)], 0.07, WHITE, math.sin(math.pi * saw(t)) ** 0.5)
    g.line([(0, -0.28), (0, 0.24)], 0.08, WHITE, 0.9)
    g.line([(-0.22, -0.06), (0.22, -0.06)], 0.08, WHITE, 0.9)


def gear(g, cx, cy, r, teeth, rot, w, color, alpha=1.0):
    pts = []
    for i in range(teeth * 4):
        a = TAU * (rot + i / (teeth * 4))
        rr = r if (i % 4) in (0, 1) else r * 0.74
        pts.append((cx + rr * math.sin(a), cy - rr * math.cos(a)))
    g.line(pts, w, color, alpha, closed=True)


def c_repair(g, t, color=(72, 232, 232)):
    """Build / repair: a turning cog and a pulsing plus."""
    gear(g, 0, 0, 0.84, 8, t / 8, 0.10, color)
    g.ring(0.42, 0.06, color, 0.7)
    g.new_layer(glow=1.5)
    s = 0.22 + 0.04 * pulse(t * 2)
    g.line([(-s, 0), (s, 0)], 0.11, WHITE)
    g.line([(0, -s), (0, s)], 0.11, WHITE)


def c_reclamate(g, t, color=(255, 92, 230)):
    """Reclaim: three arrows spiralling in to a core that swells as they arrive."""
    for i in range(3):
        a0 = -t / 3 + i / 3
        g.arc(0.70, a0, a0 + 0.22, 0.11, color)
        a = TAU * a0
        g.arrowhead(0.70 * math.sin(a), -0.70 * math.cos(a), a0 - 0.27, 0.22, color)
    for i in range(3):
        k = saw(t + i / 3)
        a = TAU * (i / 3 + 0.16)
        d = lerp(0.52, 0.10, k)
        g.dot(d * math.sin(a), -d * math.cos(a), 0.05, color, 1 - k * 0.3)
    g.new_layer(glow=1.5)
    g.dot(0, 0, 0.10 + 0.05 * pulse(t * 3), WHITE)


def c_revive(g, t, color=(110, 190, 255)):
    """Resurrect: chevrons rising through a ring, a wave spreading from the base."""
    g.segments(0.86, 2, 0.72, 0.25, 0.08, color, 0.85)
    for j in range(3):
        k = saw(t + j / 3)
        y = lerp(0.52, -0.56, k)
        g.chevron(0, y, 0, 0.30, 0.11, color if j else WHITE, math.sin(math.pi * k) ** 0.6)
    g.new_layer(glow=1.4)
    k = saw(t * 2)
    g.arc(lerp(0.15, 0.60, k), 0.30, 0.70, 0.06, WHITE, (1 - k) * 0.9, cy=0.66)


def c_capture(g, t, color=(255, 232, 84)):
    """Capture: a flag flying, brackets pulsing shut around it."""
    k = pulse(t * 2)
    g.brackets(lerp(0.90, 0.76, k), 0.26, 0.09, color)
    g.line([(-0.30, -0.50), (-0.30, 0.52)], 0.10, color)
    pts_top, pts_bot = [], []
    for i in range(9):
        x = -0.30 + 0.70 * i / 8
        wave = 0.07 * math.sin(TAU * (i / 8 * 1.2 - t)) * (i / 8)
        pts_top.append((x, -0.48 + wave))
        pts_bot.append((x, -0.04 + wave))
    g.poly(pts_top + pts_bot[::-1], color, 0.85)
    g.new_layer(glow=1.4)
    g.dot(-0.30, 0.52, 0.08, WHITE)


def tray(g, color, y=0.58):
    g.line([(-0.56, y - 0.26), (-0.56, y), (0.56, y), (0.56, y - 0.26)], 0.10, color)


def c_pickup(g, t, color=(72, 232, 232)):
    """Load: chevrons lifting out of a cradle."""
    tray(g, color)
    for j in range(2):
        k = saw(t + j * 0.5)
        g.chevron(0, lerp(0.30, -0.66, k), 0, 0.34, 0.12, color, math.sin(math.pi * k) ** 0.6)
    g.new_layer(glow=1.4)
    g.segments(0.92, 4, 0.35, t / 4, 0.06, WHITE, 0.7)


def c_unload(g, t, color=(255, 222, 72)):
    """Unload: chevrons dropping into a cradle."""
    tray(g, color)
    for j in range(2):
        k = saw(t + j * 0.5)
        g.chevron(0, lerp(-0.72, 0.24, k), 0.5, 0.34, 0.12, color, math.sin(math.pi * k) ** 0.6)
    g.new_layer(glow=1.4)
    g.segments(0.92, 4, 0.35, -t / 4, 0.06, WHITE, 0.7)


def c_dgun(g, t, color=(255, 190, 56)):
    """Manual fire: a bolt that flickers, in a ring that discharges."""
    k = saw(t * 2)
    g.ring(lerp(0.50, 0.92, k), 0.07, color, (1 - k))
    g.segments(0.88, 8, 0.4, t / 8, 0.06, color, 0.6)
    bolt = [(0.16, -0.70), (-0.30, 0.06), (0.02, 0.06), (-0.16, 0.70), (0.34, -0.14), (0.02, -0.14)]
    g.new_layer(glow=1.8)
    flick = 0.75 + 0.25 * math.sin(TAU * t * 4)
    g.poly(bolt, mix(color, WHITE, 0.55 * flick))
    g.line(bolt, 0.05, WHITE, flick, closed=True)


def c_wait(g, t, color=(196, 208, 222)):
    """Wait: a dial, a hand sweeping round it, a trail fading behind."""
    for i in range(12):
        a = TAU * i / 12
        r0 = 0.74 if i % 3 else 0.66
        g.line([(r0 * math.sin(a), -r0 * math.cos(a)), (0.88 * math.sin(a), -0.88 * math.cos(a))], 0.07, color, 1 if i % 3 == 0 else 0.6)
    for j in range(6):
        a = TAU * (t - j * 0.02)
        g.line([(0, 0), (0.56 * math.sin(a), -0.56 * math.cos(a))], 0.09, ORANGE, (1 - j / 6) * (0.35 if j else 0))
    g.new_layer(glow=1.5)
    a = TAU * t
    g.line([(0, 0), (0.58 * math.sin(a), -0.58 * math.cos(a))], 0.10, ORANGE)
    g.dot(0, 0, 0.10, WHITE)


def c_selfd(g, t):
    """Self-destruct: a hazard triangle flashing between red and yellow."""
    k = pulse(t * 2)
    color = mix((255, 60, 48), (255, 224, 64), k)
    tri = [(0, -0.80), (0.82, 0.62), (-0.82, 0.62)]
    g.poly(tri, color, 0.20 + 0.25 * k)
    g.line(tri, 0.12, color, closed=True)
    g.new_layer(glow=1.6)
    g.line([(0, -0.34), (0, 0.16)], 0.13, WHITE)
    g.dot(0, 0.40, 0.085, WHITE)


def c_jump(g, t, color=(140, 255, 204)):
    """Jump: a spark flying an arc from a launch mark to a landing ring."""
    def arc_pt(k):
        return (lerp(-0.62, 0.58, k), 0.50 - 1.12 * math.sin(math.pi * k))
    for i in range(12):                                   # the arc, as dashes
        if i % 2 == 0:
            g.line([arc_pt(i / 12), arc_pt((i + 1) / 12)], 0.07, color, 0.6)
    g.line([(-0.86, 0.60), (-0.40, 0.60)], 0.09, color)   # launch mark
    k2 = saw(t * 2)
    g.ring(0.20, 0.07, color, 0.9, cx=0.58, cy=0.50)      # landing ring and its ripple
    g.ring(lerp(0.20, 0.42, k2), 0.05, color, 1 - k2, cx=0.58, cy=0.50)
    g.new_layer(glow=1.7)
    k = saw(t)
    for j in range(4):                                    # the spark and its tail
        kk = k - j * 0.045
        if kk > 0:
            g.dot(*arc_pt(kk), 0.11 - j * 0.02, WHITE if j == 0 else color, 1 - j * 0.22)


def c_bomb(g, t, color=(255, 116, 52)):
    """Bomb: a drop zone with a marker falling into it and a ring bursting out."""
    g.segments(0.86, 4, 0.5, 0.125 + t / 4, 0.09, color)
    k = saw(t)
    fall = min(1.0, k / 0.55)
    if k < 0.55:
        y = lerp(-0.86, 0.0, fall ** 2)
        g.poly([(0, y + 0.20), (-0.15, y - 0.12), (0.15, y - 0.12)], WHITE)
        g.line([(-0.15, y - 0.20), (0.15, y - 0.20)], 0.07, WHITE)
    else:
        b = (k - 0.55) / 0.45
        g.ring(lerp(0.10, 0.70, ease_out(b)), 0.10 * (1 - b) + 0.03, mix(WHITE, color, b), 1 - b)
    g.new_layer(glow=1.5)
    g.line([(-0.20, 0), (0.20, 0)], 0.07, color)
    g.line([(0, -0.20), (0, 0.20)], 0.07, color)


def c_purchase(g, t, color=(190, 124, 255)):
    """Purchase: a research hexagon with light running round its rim."""
    hexa = [(0.80 * math.sin(TAU * i / 6), -0.80 * math.cos(TAU * i / 6)) for i in range(6)]
    g.poly(hexa, color, 0.16)
    g.line(hexa, 0.09, color, closed=True)
    inner = [(0.42 * math.sin(TAU * (i / 6 + t / 6)), -0.42 * math.cos(TAU * (i / 6 + t / 6))) for i in range(6)]
    g.line(inner, 0.06, color, 0.7, closed=True)
    g.new_layer(glow=1.7)
    for j in range(2):
        a = (t + j * 0.5) * 6
        i = int(a) % 6
        f = a - int(a)
        x = lerp(hexa[i][0], hexa[(i + 1) % 6][0], f)
        y = lerp(hexa[i][1], hexa[(i + 1) % 6][1], f)
        g.dot(x, y, 0.10, WHITE)
    s = 0.17 + 0.03 * pulse(t * 2)
    g.line([(-s, 0), (s, 0)], 0.09, WHITE)
    g.line([(0, -s), (0, s)], 0.09, WHITE)


def c_areamex(g, t, color=(169, 201, 234)):
    """Area mex: an extractor's three arms turning inside a sweep of the area."""
    g.segments(0.90, 16, 0.5, 0, 0.06, color, 0.55)
    g.arc(0.90, t, t + 0.22, 0.09, WHITE, 0.95)
    for i in range(3):
        a = TAU * (i / 3 - t / 3)
        g.line([(0.16 * math.sin(a), -0.16 * math.cos(a)), (0.56 * math.sin(a), -0.56 * math.cos(a))], 0.12, color)
        g.dot(0.60 * math.sin(a), -0.60 * math.cos(a), 0.10, color)
    g.new_layer(glow=1.5)
    g.dot(0, 0, 0.13 + 0.03 * pulse(t * 2), WHITE)


def c_restore(g, t, color=(96, 232, 120)):
    """Restore: ground levelling out under a pair of arrows."""
    amp = 0.22 * (0.5 + 0.5 * math.cos(TAU * t))
    pts = [(lerp(-0.84, 0.84, i / 16), 0.30 + amp * math.sin(TAU * i / 16 * 1.5)) for i in range(17)]
    g.line(pts, 0.10, color)
    g.line([(-0.84, 0.62), (0.84, 0.62)], 0.06, color, 0.5)
    g.new_layer(glow=1.4)
    k = pulse(t)
    g.chevron(-0.36, lerp(-0.50, -0.30, k), 0.5, 0.26, 0.10, WHITE)
    g.chevron(0.36, lerp(-0.30, -0.50, k), 0.0, 0.26, 0.10, WHITE)



# ----------------------------------------------------------------------------
# the flash layer: fx(g, t) is drawn over a cursor, white-hot, with a wide bloom
# ----------------------------------------------------------------------------

# How much sparkle: 1 is everything the fx functions ask for. Below that the
# twinkles are smaller and fainter, and there are fewer comets, rays and embers.
SPARKLE = 0.5

RED, GREEN, BLUE, CYAN = (255, 72, 60), (110, 232, 132), (84, 156, 255), (72, 232, 232)
HOT = (255, 246, 226)


def star(g, x, y, size, alpha=1.0, color=HOT, rot=0.0):
    """A four-point twinkle."""
    size *= 0.55 + 0.45 * SPARKLE
    alpha *= 0.50 + 0.50 * SPARKLE
    if alpha <= 0.02 or size <= 0.01:
        return
    pts = []
    for i in range(8):
        a = TAU * (rot + i / 8)
        r = size if i % 2 == 0 else size * 0.20
        pts.append((x + r * math.sin(a), y - r * math.cos(a)))
    g.poly(pts, color, alpha)
    g.dot(x, y, size * 0.26, WHITE, alpha)


def ping(g, t, color, r0, r1, times=1, w=0.07, phase=0.0, cx=0.0, cy=0.0, peak=1.0):
    """A ring running from r0 to r1 and fading, `times` a loop."""
    k = saw(t * times + phase)
    g.ring(lerp(r0, r1, ease_out(k)), w * (1 - 0.6 * k), mix(HOT, color, k), (1 - k) ** 1.3 * peak, cx, cy)


def comets(g, t, r, n, color, turns=1, tail=0.16, size=0.085):
    """n white-hot sparks round a ring, each with a tail in the cursor's colour."""
    steps = 7
    n = max(1, int(round(n * SPARKLE)))
    for i in range(n):
        head = t * turns + i / n
        d = -1 if turns >= 0 else 1
        for j in range(steps, 0, -1):
            a0 = head + d * tail * j / steps
            a1 = head + d * tail * (j - 1) / steps
            g.arc(r, a0, a1, size * (1.1 - 0.7 * j / steps), mix(HOT, color, j / steps), 1 - j / (steps + 1))
        a = TAU * head
        g.dot(r * math.sin(a), -r * math.cos(a), size * 0.75, HOT)


def burst(g, t, n, r0, r1, color, times=1, phase=0.0, cx=0.0, cy=0.0, rot=0.0, w=0.06, length=0.16):
    """n rays flying out from r0 to r1 and fading, `times` a loop."""
    k = saw(t * times + phase)
    d = lerp(r0, r1, ease_out(k))
    n = max(3, int(round(n * (0.4 + 0.6 * SPARKLE))))
    for i in range(n):
        a = TAU * (rot + i / n)
        dx, dy = math.sin(a), -math.cos(a)
        g.line([(cx + dx * d, cy + dy * d), (cx + dx * (d + length * (1 - k)), cy + dy * (d + length * (1 - k)))],
               w, mix(HOT, color, k), (1 - k) ** 1.2)


def fx_normal(g, t):
    def U(x, y):
        return ((x - 16) / 14.4, (y - 16) / 14.4)
    k = pulse(t, 3)                       # still on the held first frame
    star(g, *U(2.5, 2.5), 0.34 * k, k, rot=t / 4)
    k2 = saw(t)
    if 0.35 < k2 < 0.95:                  # a spark shed down the spine
        kk = (k2 - 0.35) / 0.60
        star(g, *U(5.3, lerp(8.0, 18.2, kk)), 0.15, math.sin(math.pi * kk), ORANGE)


def fx_move(g, t, color=GREEN):
    k = saw(t * 2)
    g.ring(lerp(0.98, 0.26, ease_out(k)), 0.05, mix(color, HOT, k), k ** 1.5 * 0.9)   # closing in
    star(g, 0, 0, 0.20 + 0.32 * k ** 3, 0.35 + 0.65 * k ** 3, rot=0.125)
    burst(g, t, 4, 0.26, 0.52, color, times=2, rot=0.125, length=0.12)


def fx_attack(g, t, color=RED):
    comets(g, t, 0.94, 2, color, turns=1)
    ping(g, t, color, 0.10, 0.58, times=2)
    star(g, 0, 0, 0.20 + 0.22 * pulse(t * 2), 1.0)


def fx_areaattack(g, t, color=RED):
    ping(g, t, color, 0.14, 0.96, times=2, w=0.09)
    ping(g, t, color, 0.14, 0.96, times=2, w=0.05, phase=0.5, peak=0.6)
    comets(g, t, 0.72, 3, color, turns=-1, tail=0.10, size=0.07)
    star(g, 0, 0, 0.18 + 0.20 * pulse(t * 2), 1.0)


def fx_setattack(g, t, color=ORANGE):
    k = pulse(t * 2)
    half = lerp(0.86, 0.70, k)
    for sx, sy in ((-1, -1), (1, -1), (1, 1), (-1, 1)):
        star(g, sx * half, sy * half, 0.26 * k ** 2, k ** 2, rot=0.125)
    ping(g, t, color, 0.20, 0.66, times=2, phase=0.5, w=0.05)
    star(g, 0, 0, 0.12 + 0.18 * k ** 2, 0.9)


def fx_fight(g, t, color=(132, 140, 255)):
    burst(g, t, 8, 0.10, 0.50, color, times=2, rot=0.0625)
    comets(g, t, 0.84, 3, color, turns=1, tail=0.12, size=0.075)
    star(g, 0, 0, 0.18 + 0.30 * pulse(t * 2, 2), 1.0, rot=0.125)


def fx_patrol(g, t, color=BLUE):
    for i in range(2):                    # the arrowheads burn white
        a = TAU * (t + i * 0.5 + 0.36)
        star(g, 0.66 * math.sin(a), -0.66 * math.cos(a), 0.26, 0.95, rot=t)
    comets(g, t, 0.95, 2, color, turns=-1, tail=0.14, size=0.07)
    ping(g, t, color, 0.10, 0.44, times=2, w=0.05)


def fx_defend(g, t, color=(96, 176, 255)):
    ping(g, t, color, 0.56, 0.98, times=1, w=0.07)
    ping(g, t, color, 0.56, 0.98, times=1, w=0.05, phase=0.5, peak=0.7)
    k = pulse(t, 3)
    star(g, 0.34, -0.40, 0.34 * k, k)
    k = pulse(t + 0.5, 3)
    star(g, -0.30, 0.02, 0.24 * k, k)


def fx_repair(g, t, color=CYAN):
    burst(g, t, 6, 0.14, 0.62, ORANGE, times=3, rot=0.04, length=0.14, w=0.05)       # welding sparks
    burst(g, t, 6, 0.14, 0.50, color, times=3, phase=0.5, rot=0.125, length=0.10, w=0.045)
    comets(g, t, 0.96, 2, color, turns=1, tail=0.12, size=0.07)
    star(g, 0, 0, 0.22 + 0.22 * pulse(t * 3), 1.0)


def fx_reclamate(g, t, color=(255, 92, 230)):
    for ph in (0.0, 0.5):
        k = saw(t * 2 + ph)
        g.ring(lerp(0.96, 0.16, k), 0.05, mix(color, HOT, k), k * 0.85)             # drawn inward
    for i in range(3):                    # the arrowheads burn white
        a = TAU * (-t / 3 + i / 3)
        star(g, 0.70 * math.sin(a), -0.70 * math.cos(a), 0.22, 0.9, rot=t)
    star(g, 0, 0, 0.16 + 0.26 * pulse(t * 3, 2), 1.0)


def fx_revive(g, t, color=(110, 190, 255)):
    for i in range(5):                    # motes rising
        k = saw(t + i / 5)
        x = (-0.50, 0.28, -0.14, 0.52, -0.34)[i]
        star(g, x, lerp(0.70, -0.80, k), 0.13, math.sin(math.pi * k) ** 0.7, mix(HOT, color, 0.3))
    k = pulse(t * 2, 2)
    star(g, 0, -0.60, 0.16 + 0.26 * k, 0.5 + 0.5 * k)
    ping(g, t, color, 0.20, 0.96, times=1, w=0.05)


def fx_capture(g, t, color=(255, 232, 84)):
    k = pulse(t * 2)
    half = lerp(0.90, 0.76, k)
    for sx, sy in ((-1, -1), (1, -1), (1, 1), (-1, 1)):
        star(g, sx * half, sy * half, 0.24 * k ** 2, k ** 2, rot=0.125)
    k = saw(t)                            # a glint crossing the flag
    star(g, lerp(-0.24, 0.40, k), -0.26, 0.24, math.sin(math.pi * k))
    star(g, -0.30, -0.52, 0.12 + 0.14 * pulse(t * 2), 0.9)


def fx_pickup(g, t, color=CYAN):
    for j in range(2):
        k = saw(t + j * 0.5)
        star(g, 0, lerp(0.30, -0.66, k) - 0.17, 0.20, math.sin(math.pi * k) ** 0.6)
    burst(g, t, 5, 0.10, 0.36, color, times=2, cy=-0.70, rot=0.0, length=0.10, w=0.045)
    comets(g, t, 0.94, 2, color, turns=1, tail=0.10, size=0.065)


def fx_unload(g, t, color=(255, 222, 72)):
    for j in range(2):
        k = saw(t + j * 0.5)
        star(g, 0, lerp(-0.72, 0.24, k) + 0.17, 0.20, math.sin(math.pi * k) ** 0.6)
    burst(g, t, 5, 0.10, 0.36, color, times=2, cy=0.40, rot=0.1, length=0.10, w=0.045)
    comets(g, t, 0.94, 2, color, turns=-1, tail=0.10, size=0.065)


def fx_dgun(g, t, color=(255, 190, 56)):
    import random
    rnd = random.Random(int(round(t * FRAMES)) * 7919 + 13)
    for _ in range(3):                    # arcs of lightning out to the ring
        a = rnd.random()
        pts, r = [], 0.34
        while r < 0.92:
            aa = TAU * (a + rnd.uniform(-0.035, 0.035))
            pts.append((r * math.sin(aa), -r * math.cos(aa)))
            r += rnd.uniform(0.10, 0.18)
        aa = TAU * a
        pts.append((0.92 * math.sin(aa), -0.92 * math.cos(aa)))
        g.line(pts, 0.045, HOT, rnd.uniform(0.6, 1.0))
        star(g, pts[-1][0], pts[-1][1], 0.16, 0.9)
    star(g, 0.02, -0.04, 0.30 + 0.20 * rnd.random(), 0.55)


def fx_wait(g, t, color=(196, 208, 222)):
    a = TAU * t
    star(g, 0.58 * math.sin(a), -0.58 * math.cos(a), 0.22, 1.0, rot=t)
    q = int(t * 4) % 4                    # each quarter mark flares as the hand passes
    k = saw(t * 4)
    aq = TAU * q / 4
    star(g, 0.80 * math.sin(aq), -0.80 * math.cos(aq), 0.30 * (1 - k), 1 - k)
    ping(g, t, ORANGE, 0.10, 0.50, times=2, w=0.045, peak=0.7)


def fx_selfd(g, t):
    k = pulse(t * 2)
    color = mix((255, 60, 48), (255, 224, 64), k)
    burst(g, t, 9, 0.66, 1.02, color, times=2, cy=0.14, rot=0.0, length=0.20, w=0.07)
    for x, y in ((0, -0.80), (0.82, 0.62), (-0.82, 0.62)):
        star(g, x, y, 0.28 * k, k)
    star(g, 0, -0.08, 0.20 + 0.26 * k, 0.5 + 0.5 * k)


def fx_jump(g, t, color=(140, 255, 204)):
    burst(g, t, 7, 0.08, 0.44, color, times=1, cx=0.58, cy=0.50, rot=0.07, length=0.14)      # landing
    k = saw(t)
    star(g, 0.58, 0.50, 0.40 * (1 - k) ** 2, (1 - k) ** 2)
    burst(g, t, 5, 0.06, 0.30, color, times=1, phase=0.92, cx=-0.62, cy=0.50, rot=0.9, length=0.10, w=0.045)   # launch
    star(g, lerp(-0.62, 0.58, k), 0.50 - 1.12 * math.sin(math.pi * k), 0.24, 1.0, rot=t)


def fx_bomb(g, t, color=(255, 116, 52)):
    k = saw(t)
    if k >= 0.55:
        b = (k - 0.55) / 0.45
        d = lerp(0.14, 0.86, ease_out(b))
        for i in range(10):
            a = TAU * (i / 10 + 0.03)
            dx, dy = math.sin(a), -math.cos(a)
            g.line([(dx * d, dy * d), (dx * (d + 0.20 * (1 - b)), dy * (d + 0.20 * (1 - b)))], 0.07, mix(HOT, color, b), 1 - b)
        star(g, 0, 0, 0.70 * (1 - b) ** 1.5, (1 - b) ** 1.2)
        g.ring(lerp(0.10, 0.96, ease_out(b)), 0.05, color, (1 - b) * 0.8)
    else:
        y = lerp(-0.86, 0.0, (k / 0.55) ** 2)
        star(g, 0, y - 0.22, 0.14 + 0.06 * math.sin(TAU * t * 6), 0.9, ORANGE)       # the marker's flame
    comets(g, t, 0.95, 2, color, turns=1, tail=0.10, size=0.065)


def fx_purchase(g, t, color=(190, 124, 255)):
    for i in range(6):                    # the corners twinkle in turn
        k = pulse(t * 2 + i / 3, 4)
        a = TAU * i / 6
        star(g, 0.80 * math.sin(a), -0.80 * math.cos(a), 0.30 * k, k)
    ping(g, t, color, 0.10, 0.70, times=2, w=0.05)
    star(g, 0, 0, 0.16 + 0.20 * pulse(t * 2, 2), 0.9, rot=0.125)


def fx_areamex(g, t, color=(169, 201, 234)):
    a = TAU * (t + 0.22)                  # the head of the sweep
    star(g, 0.90 * math.sin(a), -0.90 * math.cos(a), 0.26, 1.0, rot=t)
    for i in range(3):
        a = TAU * (i / 3 - t / 3)
        k = pulse(t * 3 + i / 3, 3)
        star(g, 0.60 * math.sin(a), -0.60 * math.cos(a), 0.10 + 0.20 * k, 0.4 + 0.6 * k)
    ping(g, t, color, 0.14, 0.80, times=2, w=0.05)


def fx_restore(g, t, color=(96, 232, 120)):
    for i, x in enumerate((-0.60, -0.20, 0.22, 0.62)):
        k = pulse(t * 2 + i / 4, 3)
        star(g, x, 0.30, 0.24 * k, k)
    k = saw(t)
    g.line([(lerp(-0.84, 0.60, k), 0.62), (lerp(-0.60, 0.84, k), 0.62)], 0.07, HOT, math.sin(math.pi * k))    # light along the level line
    star(g, -0.36, -0.62, 0.14 + 0.10 * pulse(t * 2), 0.8)
    star(g, 0.36, -0.14, 0.14 + 0.10 * pulse(t * 2 + 0.5), 0.8)


def flashy(base, fx):
    def draw(g, t):
        base(g, t)
        if g.fx:
            g.new_layer(glow=2.0)
            fx(g, t)
    return draw



# ----------------------------------------------------------------------------
# the Bastion glyphs: bold, solid icons. b_<name>(g, t) draws frame t of one loop.
# Few shapes, thick and filled, with facets (a lighter and a darker side); the
# Bastion style then gives them their gradient, outline and glow.
# ----------------------------------------------------------------------------

CREAM = (255, 244, 214)
BOLD_SIZE = 56              # pixels; the pointer keeps its own size


def lite(c, k=0.30):
    return mix(c, (255, 255, 255), k)


def deep(c, k=0.26):
    return mix(c, (0, 0, 0), k)


def turn(pts, ang, x=0.0, y=0.0):
    ca, sa = math.cos(TAU * ang), math.sin(TAU * ang)
    return [(x + px * ca - py * sa, y + px * sa + py * ca) for px, py in pts]


def polar(r, a):
    return (r * math.sin(TAU * a), -r * math.cos(TAU * a))


def cross(g, arm=0.20, gap=0.07, w=0.06, color=CREAM, x=0.0, y=0.0, alpha=1.0):
    """The fine sight at the middle of a cursor: four ticks with a gap between them."""
    for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
        g.bar((x + dx * gap, y + dy * gap), (x + dx * arm, y + dy * arm), w, color, alpha)


def chev(g, x, y, ang, size, thick, color, alpha=1.0, spread=0.62):
    """A solid V pointing along ang, its two arms a lighter and a darker facet."""
    h, w = size / 2, size * spread
    left = [(0, -h), (-w, h - thick), (-w, h), (0, -h + thick)]
    right = [(0, -h), (w, h - thick), (w, h), (0, -h + thick)]
    g.poly(turn(left, ang, x, y), lite(color), alpha)
    g.poly(turn(right, ang, x, y), deep(color, 0.12), alpha)


def diamond(g, x, y, r, color, alpha=1.0):
    g.poly([(x, y - r), (x + r, y), (x, y + r)], lite(color, 0.35), alpha)
    g.poly([(x, y - r), (x - r, y), (x, y + r)], color, alpha)


def sphere(g, x, y, r, color):
    g.dot(x, y, r, color)
    g.dot(x - r * 0.28, y - r * 0.30, r * 0.42, lite(color, 0.65))


def quadrants(g, r0, r1, color, n=4, fill=0.70, rot=0.0):
    for i in range(n):
        a0 = rot + i / n + (1 - fill) / (2 * n)
        g.band(r0, r1, a0, a0 + fill / n, color)


def curved_arrow(g, r, w, a0, a1, color, head=0.20):
    """A thick arc from a0 to a1 (turns) ending in an arrowhead."""
    d = 1 if a1 > a0 else -1
    g.band(r - w / 2, r + w / 2, a0, a1 - d * head * 0.55 / (TAU * r) * TAU / TAU, color)
    tip = polar(r, a1 + d * head * 0.45 / (TAU * r))
    b0, b1 = polar(r - head * 0.80, a1 - d * head * 0.62 / (TAU * r)), polar(r + head * 0.80, a1 - d * head * 0.62 / (TAU * r))
    g.poly([tip, b0, b1], lite(color, 0.18))


def b_normal(g, t):
    """The pointer: a faceted steel corner and shaft, a glint running down the shaft."""
    def U(x, y):
        return ((x - 16) / 14.4, (y - 16) / 14.4)
    hi, mid, lo = (238, 244, 252), (196, 212, 234), (150, 172, 204)
    g.poly([U(2, 2), U(24, 2), U(18.5, 8), U(8, 8)], hi)                 # top of the head
    g.poly([U(2, 2), U(8, 8), U(8, 18.5), U(2, 24)], lo)                 # its left side
    g.poly([U(12.5, 9.5), U(15.5, 9.5), U(30, 24), U(30, 27)], mid)      # shaft, upper facet
    g.poly([U(9.5, 12.5), U(12.5, 9.5), U(30, 27), U(27, 30)], hi)
    g.poly([U(9.5, 12.5), U(9.5, 15.5), U(24, 30), U(27, 30)], lo)       # lower facet
    k = saw(t)                                                           # still on the held first frame
    a = math.sin(math.pi * k) ** 0.8
    if a > 0.02:
        p = lerp(11.0, 27.0, k)
        g.bar(U(p - 2.2, p - 2.2), U(p + 2.2, p + 2.2), 0.20, (255, 255, 255), a)
    g.dot(*U(3.6, 3.6), 0.07 + 0.05 * pulse(t), ORANGE, 0.5 + 0.5 * pulse(t))


def b_move(g, t, color=(96, 226, 120)):
    """Double chevrons closing from both sides on a diamond."""
    for side in (-1, 1):
        for j in range(2):
            k = pulse(t * 2)
            x = side * (lerp(0.86, 0.70, k) - j * 0.26)
            a = 1.0 if j else 0.55 + 0.45 * k
            chev(g, x, 0, -side * 0.25, 0.30, 0.17, color, a, spread=0.90)
    diamond(g, 0, 0, 0.13 + 0.03 * pulse(t * 2), lite(color, 0.35))


def b_attack(g, t, color=(255, 78, 44)):
    """A sight: four solid quadrants squeezing in, long ticks through the gaps, a fine cross."""
    k = pulse(t * 2)
    r = lerp(0.74, 0.66, k)
    quadrants(g, r - 0.20, r, color, fill=0.72)
    for i in range(4):
        g.bar(polar(lerp(0.44, 0.36, k), i / 4), polar(lerp(1.0, 0.92, k), i / 4), 0.075, color)
    cross(g, 0.21, 0.06)


def b_areaattack(g, t, color=(255, 78, 44)):
    """The sight inside a ring of blocks that turns and breathes."""
    r = lerp(0.90, 0.96, pulse(t))
    for i in range(8):
        a = t / 8 + i / 8
        g.band(r - 0.13, r, a - 0.030, a + 0.030, color)
    quadrants(g, 0.38, 0.56, color, fill=0.70, rot=-t / 4)
    cross(g, 0.20, 0.06)


def b_setattack(g, t, color=ORANGE):
    """Set Target: solid lock brackets closing on a diamond."""
    k = pulse(t * 2)
    half, L, w = lerp(0.90, 0.72, k), 0.38, 0.17
    for sx, sy in ((-1, -1), (1, -1), (1, 1), (-1, 1)):
        g.poly([(sx * half, sy * half), (sx * (half - L), sy * half), (sx * (half - L), sy * (half - w)),
                (sx * (half - w), sy * (half - w)), (sx * (half - w), sy * (half - L)), (sx * half, sy * (half - L))],
               lite(color, 0.15) if sy < 0 else color)
    diamond(g, 0, 0, 0.20, CREAM)
    g.erase([(0, -0.09), (0.09, 0), (0, 0.09), (-0.09, 0)])
    diamond(g, 0, 0, 0.055, color)


def b_fight(g, t, color=(128, 132, 255)):
    """Attack-move: the sight's top and bottom, chevrons driving in from the sides."""
    g.band(0.56, 0.78, -0.17, 0.17, color)
    g.band(0.56, 0.78, 0.33, 0.67, color)
    k = saw(t * 2)
    for side in (-1, 1):
        x = side * lerp(0.92, 0.50, ease_out(k))
        chev(g, x, 0, -side * 0.25, 0.30, 0.18, (120, 230, 130), 0.35 + 0.65 * math.sin(math.pi * k) ** 0.5, spread=0.85)
    cross(g, 0.20, 0.06)


def b_patrol(g, t, color=(84, 150, 255)):
    """Three spheres riding a ring round a fine cross."""
    g.band(0.705, 0.765, 0, 1, deep(color, 0.25))
    for i in range(3):
        x, y = polar(0.735, t / 3 + i / 3)
        sphere(g, x, y, 0.155, lite(color, 0.25))
    cross(g, 0.24, 0.07, color=(240, 244, 248))


def b_defend(g, t, color=(92, 172, 255)):
    """Guard: a solid two-facet shield, two wards circling it."""
    for i in range(2):
        a = t / 2 + i / 2
        g.band(0.80, 0.96, a - 0.10, a + 0.10, color)
    left = [(0, -0.60), (-0.46, -0.44), (-0.46, 0.06), (0, 0.62)]
    right = [(0, -0.60), (0.46, -0.44), (0.46, 0.06), (0, 0.62)]
    g.poly(left, lite(color, 0.22))
    g.poly(right, deep(color, 0.14))
    k = 0.85 + 0.15 * pulse(t * 2)
    g.bar((0, -0.26 * k), (0, 0.26 * k), 0.11, CREAM)
    g.bar((-0.22 * k, -0.04), (0.22 * k, -0.04), 0.11, CREAM)


def b_repair(g, t, color=(64, 226, 226)):
    """Build / repair: a solid cog turning round a plus."""
    teeth, rot = 8, t / 8
    pts = []
    for i in range(teeth * 4):
        a = rot + (i - 0.5) / (teeth * 4)
        pts.append(polar(0.92 if (i % 4) in (0, 1) else 0.70, a))
    g.poly(pts, color)
    g.erase_dot(0, 0, 0.44)
    s = 0.24 + 0.03 * pulse(t * 2)
    g.bar((-s, 0), (s, 0), 0.12, CREAM)
    g.bar((0, -s), (0, s), 0.12, CREAM)


def b_reclamate(g, t, color=(255, 84, 224)):
    """Reclaim: two thick arrows chasing round, drawing a diamond down to nothing."""
    for i in range(2):
        a0 = -t / 2 + i / 2
        curved_arrow(g, 0.68, 0.20, a0 + 0.36, a0 + 0.04, color)
    k = saw(t * 2)
    diamond(g, 0, 0, lerp(0.26, 0.06, k), CREAM, 1 - 0.5 * k)


def b_revive(g, t, color=(104, 186, 255)):
    """Resurrect: solid chevrons rising between two wings."""
    g.band(0.74, 0.92, 0.12, 0.38, color)
    g.band(0.74, 0.92, 0.62, 0.88, color)
    for j in range(2):
        k = saw(t + j * 0.5)
        chev(g, 0, lerp(0.56, -0.56, k), 0, 0.40, 0.20, CREAM if j == 0 else lite(color, 0.4), math.sin(math.pi * k) ** 0.6, spread=0.80)


def b_restore(g, t, color=(88, 226, 112)):
    """Restore: rough ground settling flat under two arrows."""
    amp = 0.20 * (0.5 + 0.5 * math.cos(TAU * t))
    top = [(lerp(-0.90, 0.90, i / 20), 0.26 + amp * math.sin(TAU * i / 20 * 1.5)) for i in range(21)]
    g.poly(top + [(0.90, 0.56), (-0.90, 0.56)], color)
    g.bar((-0.90, 0.74), (0.90, 0.74), 0.10, deep(color, 0.2))
    k = pulse(t)
    y1, y2 = lerp(-0.62, -0.38, k), lerp(-0.38, -0.62, k)
    g.poly([(-0.40, y1 + 0.30), (-0.62, y1), (-0.18, y1)], CREAM)       # pressing down
    g.poly([(0.40, y2 - 0.02), (0.62, y2 + 0.28), (0.18, y2 + 0.28)], CREAM)   # lifting up


def b_capture(g, t, color=(255, 226, 72)):
    """Capture: a flag flying inside brackets that clamp shut."""
    k = pulse(t * 2)
    half, L, w = lerp(0.94, 0.80, k), 0.30, 0.13
    for sx, sy in ((-1, -1), (1, -1), (1, 1), (-1, 1)):
        g.poly([(sx * half, sy * half), (sx * (half - L), sy * half), (sx * (half - L), sy * (half - w)),
                (sx * (half - w), sy * (half - w)), (sx * (half - w), sy * (half - L)), (sx * half, sy * (half - L))], deep(color, 0.10))
    g.bar((-0.32, -0.54), (-0.32, 0.56), 0.11, CREAM)
    top, bot = [], []
    for i in range(9):
        x = -0.26 + 0.74 * i / 8
        wave = 0.07 * math.sin(TAU * (i / 8 * 1.2 - t)) * (i / 8)
        top.append((x, -0.52 + wave))
        bot.append((x, -0.06 + wave))
    mid = [((a[0] + b[0]) / 2, (a[1] + b[1]) / 2) for a, b in zip(top, bot)]
    g.poly(top + mid[::-1], lite(color, 0.25))
    g.poly(mid + bot[::-1], color)


def b_tray(g, color, y=0.66):
    g.poly([(-0.66, y - 0.34), (-0.50, y - 0.34), (-0.50, y - 0.16), (0.50, y - 0.16), (0.50, y - 0.34), (0.66, y - 0.34),
            (0.66, y), (-0.66, y)], color)


def b_pickup(g, t, color=(64, 226, 226)):
    """Load: solid chevrons lifting out of a cradle."""
    b_tray(g, color)
    for j in range(2):
        k = saw(t + j * 0.5)
        chev(g, 0, lerp(0.20, -0.70, k), 0, 0.38, 0.20, CREAM if j == 0 else lite(color, 0.4), math.sin(math.pi * k) ** 0.6, spread=0.80)


def b_unload(g, t, color=(255, 218, 64)):
    """Unload: solid chevrons dropping into a cradle."""
    b_tray(g, color)
    for j in range(2):
        k = saw(t + j * 0.5)
        chev(g, 0, lerp(-0.78, 0.14, k), 0.5, 0.38, 0.20, CREAM if j == 0 else lite(color, 0.4), math.sin(math.pi * k) ** 0.6, spread=0.80)


def b_dgun(g, t, color=(255, 184, 44)):
    """Manual fire: a faceted bolt in a ring that spins up and discharges."""
    quadrants(g, 0.76, 0.94, color, n=3, fill=0.62, rot=t / 3 * 2)
    flick = 0.5 + 0.5 * math.sin(TAU * t * 4)
    a = [(0.20, -0.72), (-0.34, 0.08), (0.00, 0.08)]
    b = [(0.00, 0.08), (-0.20, 0.72), (0.38, -0.16), (0.06, -0.16), (0.20, -0.72)]
    g.poly(a, mix(CREAM, (255, 255, 255), flick))
    g.poly(b, mix(lite(color, 0.35), CREAM, flick))


def b_wait(g, t):
    """Wait: an hourglass running out, then turning over."""
    glass, sand, frame = (150, 200, 255), (255, 188, 64), (236, 242, 250)
    k = min(1.0, saw(t) / 0.78)                       # sand run, 0..1
    flip = max(0.0, (saw(t) - 0.78) / 0.22)
    g.rot = 0.5 * (flip * flip * (3 - 2 * flip))
    g.bar((-0.52, -0.80), (0.52, -0.80), 0.14, frame)
    g.bar((-0.52, 0.80), (0.52, 0.80), 0.14, frame)
    g.poly([(-0.42, -0.72), (0.42, -0.72), (0.05, 0.0), (-0.05, 0.0)], lite(glass, 0.35), 0.80)
    g.poly([(-0.42, 0.72), (0.42, 0.72), (0.05, 0.0), (-0.05, 0.0)], glass, 0.80)
    lvl = lerp(-0.56, -0.06, k)                       # the top sand's surface sinks
    half = 0.05 + 0.37 * (-lvl) / 0.72
    if k < 0.98:
        g.poly([(-half, lvl), (half, lvl), (0.05, 0.0), (-0.05, 0.0)], sand)
        g.bar((0, 0.0), (0, 0.70), 0.05, sand)
    h = 0.50 * k ** 0.6                               # the heap below grows
    w = 0.42 * (1 - (0.72 - h) / 0.72 * 0.0)
    g.poly([(-w + 0.02, 0.72), (w - 0.02, 0.72), (0.04 + (w - 0.06) * (1 - min(1, h / 0.5)), 0.72 - h), (-0.04 - (w - 0.06) * (1 - min(1, h / 0.5)), 0.72 - h)], sand)
    g.rot = 0.0


def b_selfd(g, t):
    """Self-destruct: a solid hazard triangle, beating."""
    k = pulse(t * 2)
    color = (255, 206, 44)
    s = lerp(0.94, 1.0, k)
    tri = [(0, -0.86 * s), (0.90 * s, 0.68 * s), (-0.90 * s, 0.68 * s)]
    g.poly(tri, color)
    g.poly([(0, -0.86 * s), (0, 0.68 * s), (-0.90 * s, 0.68 * s)], lite(color, 0.20))
    g.poly([(0, -0.34), (0.11, -0.22), (0.06, 0.24), (-0.06, 0.24), (-0.11, -0.22)], DARK)
    g.dot(0, 0.44, 0.10, DARK)


def b_jump(g, t, color=(110, 246, 190)):
    """Jump: a ball leaping from a pad to a landing ring."""
    def arc_pt(k):
        return (lerp(-0.60, 0.56, k), 0.52 - 1.16 * math.sin(math.pi * k))
    for i in range(0, 10, 2):
        g.bar(arc_pt(i / 10 + 0.02), arc_pt((i + 1) / 10 + 0.02), 0.10, deep(color, 0.15))
    g.bar((-0.92, 0.70), (-0.30, 0.70), 0.14, color)
    k2 = saw(t)
    g.band(0.20, 0.34, 0, 1, color, cx=0.56, cy=0.56)
    g.band(lerp(0.34, 0.52, k2) - 0.05, lerp(0.34, 0.52, k2), 0, 1, color, 1 - k2, cx=0.56, cy=0.56)
    x, y = arc_pt(saw(t))
    sphere(g, x, y, 0.17, CREAM)


def b_bomb(g, t, color=(255, 122, 44)):
    """Bomb: a marker dropping into a zone, a ring bursting out."""
    quadrants(g, 0.70, 0.90, color, fill=0.60, rot=0.125)
    k = saw(t)
    if k < 0.55:
        y = lerp(-0.92, 0.0, (k / 0.55) ** 2)
        g.poly([(0, y + 0.26), (-0.17, y - 0.08), (0.17, y - 0.08)], CREAM)
        g.bar((-0.17, y - 0.17), (0.17, y - 0.17), 0.08, CREAM)
    else:
        b = (k - 0.55) / 0.45
        r = lerp(0.14, 0.62, ease_out(b))
        g.band(r - 0.16 * (1 - b) - 0.03, r, 0, 1, mix(CREAM, color, b), 1 - b * b)
    cross(g, 0.20, 0.07, color=color)


def b_purchase(g, t, color=(180, 112, 255)):
    """Purchase: a coin with a cut gem, rings spreading from it."""
    for ph in (0.0, 0.5):
        k = saw(t + ph)
        r = lerp(0.56, 0.98, k)
        g.band(r - 0.05, r, 0, 1, color, (1 - k) * 0.9)
    g.dot(0, 0, 0.58, deep(color, 0.20))
    g.dot(0, 0, 0.46, color)
    diamond(g, 0, 0, 0.26 + 0.03 * pulse(t * 2), CREAM)


def b_areamex(g, t, color=(150, 196, 240)):
    """Area mex: a three-armed extractor turning in a ring of studs, two markers sweeping it."""
    for i in range(12):
        x, y = polar(0.88, i / 12)
        diamond(g, x, y, 0.055, deep(color, 0.10))
    for i in range(2):
        x, y = polar(0.88, t + i / 2)
        diamond(g, x, y, 0.13, CREAM)
    for i in range(3):
        a = i / 3 - t / 3
        g.bar(polar(0.10, a), polar(0.50, a), 0.17, color)
        sphere(g, *polar(0.52, a), 0.14, lite(color, 0.2))
    g.dot(0, 0, 0.17, CREAM)


BOLD = {
    "grab": lambda g, t: h_grab(g, t),
    "normal": b_normal, "move": b_move, "attack": b_attack, "areaattack": b_areaattack, "setattack": b_setattack,
    "fight": b_fight, "patrol": b_patrol, "defend": b_defend, "repair": b_repair, "reclamate": b_reclamate,
    "revive": b_revive, "restore": b_restore, "capture": b_capture, "pickup": b_pickup, "unload": b_unload,
    "dgun": b_dgun, "wait": b_wait, "selfd": b_selfd, "jump": b_jump, "bomb": b_bomb, "purchase": b_purchase,
    "areamex": b_areamex,
}



# ----------------------------------------------------------------------------
# the Forboding Angel set, redrawn: the old set's motifs (red blades closing on
# a sight, a fan of blades for guard, lights walking a beat, crates, two halves
# and a spark, the green dart, the red W), drawn again smooth, large and without
# the ring that used to frame every one of them. Each is in the colour of its
# order line, and most move on a beat: a quick action, a hold, a release, a rest.
# Where the old set had nothing, the Bastion glyph for that order stands in.
# ----------------------------------------------------------------------------

def snap(t, up=0.20, hold=0.28, down=0.27):
    """The beat: 0 to 1 quickly, held, back to 0, then rest for what is left of the loop."""
    k = saw(t)
    if k < up:
        return ease_out(k / up)
    if k < up + hold:
        return 1.0
    if k < up + hold + down:
        x = (k - up - hold) / down
        return 1 - x * x * (3 - 2 * x)
    return 0.0


def wedge(g, a, tip_r, length, half, color, alpha=1.0):
    """A blade pointing at the centre along angle a, a lighter and a darker facet."""
    A = TAU * a
    dx, dy, px, py = math.sin(A), -math.cos(A), math.cos(A), math.sin(A)
    tip = (dx * tip_r, dy * tip_r)
    back = (dx * (tip_r + length), dy * (tip_r + length))
    m = tip_r + length * 0.68
    g.poly([tip, (dx * m + px * half, dy * m + py * half), back], lite(color, 0.28), alpha)
    g.poly([tip, (dx * m - px * half, dy * m - py * half), back], deep(color, 0.20), alpha)


def f_normal(g, t):
    """The pointer: the green dart, two facets and a ridge, a shine crossing it."""
    def U(x, y):
        return ((x - 16) / 14.4, (y - 16) / 14.4)
    tip, wing_r, notch, wing_b = U(2, 2), U(29.5, 15.5), U(14.5, 15.0), U(12.5, 29.5)
    g.poly([tip, wing_r, notch], (96, 240, 96))
    g.poly([tip, notch, wing_b], (26, 150, 44))
    g.line([tip, notch], 0.07, (214, 255, 214), 0.9)
    k = saw(t)                                       # still on the held first frame
    a = math.sin(math.pi * k)
    if a > 0.02:
        d = lerp(3.0, 24.0, k)
        g.bar(U(d + 4, d - 9), U(d - 9, d + 4), 0.16, (255, 255, 255), a * 0.85)
        g.erase([U(40, 0), wing_r, notch, wing_b, U(0, 40), U(40, 40)])      # keep the shine on the dart
        g.erase([U(-4, -4), tip, U(-4, 30)])
        g.erase([U(-4, -4), tip, U(34, -4), wing_r, U(40, 0)])


def cube(g, x, y, s, color, alpha=1.0):
    g.poly([(x - s, y - s), (x + s, y - s), (x + s, y + s), (x - s, y + s)], color, alpha)
    g.poly([(x - s, y - s), (x + s, y - s), (x + s * 0.4, y - s * 0.4), (x - s * 0.4, y - s * 0.4)], lite(color, 0.45), alpha)
    g.poly([(x - s, y - s), (x - s * 0.4, y - s * 0.4), (x - s * 0.4, y + s * 0.4), (x - s, y + s)], lite(color, 0.20), alpha)
    g.poly([(x + s, y + s), (x - s, y + s), (x - s * 0.4, y + s * 0.4), (x + s * 0.4, y + s * 0.4)], deep(color, 0.30), alpha)


def f_wait(g, t):
    """Wait: the red W, lit from inside, between bars that run."""
    pts = [(-0.46, -0.46), (-0.24, 0.46), (0.0, -0.08), (0.24, 0.46), (0.46, -0.46)]
    g.line(pts, 0.21, (232, 40, 24))
    g.line(pts, 0.085, mix((255, 150, 30), (255, 236, 90), pulse(t * 2)))
    for side in (-1, 1):
        for i in range(3):
            x = side * (0.70 + 0.12 * i)
            a = 0.30 + 0.70 * pulse(t * 2 - i / 3)
            g.bar((x, -0.50), (x, 0.50), 0.055, CREAM, a)


def f_bomb(g, t):
    """Bomb: a bundle of dynamite, the fuse burning."""
    red = (226, 62, 52)
    for i, off in enumerate((-0.25, 0.0, 0.25)):
        body = [(off - 0.115, -0.44), (off + 0.115, -0.44), (off + 0.115, 0.56), (off - 0.115, 0.56)]
        shine = [(off - 0.115, -0.44), (off - 0.04, -0.44), (off - 0.04, 0.56), (off - 0.115, 0.56)]
        g.poly(turn(body, 0.09), red if i != 1 else lite(red, 0.10))
        g.poly(turn(shine, 0.09), lite(red, 0.40))
    for y in (-0.16, 0.30):
        g.poly(turn([(-0.40, y - 0.055), (0.40, y - 0.055), (0.40, y + 0.055), (-0.40, y + 0.055)], 0.09), (60, 44, 40))
    fuse = turn([(0.0, -0.44), (0.02, -0.60), (0.12, -0.72)], 0.09)
    g.line(fuse, 0.05, (210, 190, 150))
    sx, sy = fuse[-1]
    fl = 0.5 + 0.5 * math.sin(TAU * t * 5)
    pts = [(sx + (0.22 + 0.07 * fl if i % 2 == 0 else 0.07) * math.sin(TAU * (i / 10 + t)),
            sy - (0.22 + 0.07 * fl if i % 2 == 0 else 0.07) * math.cos(TAU * (i / 10 + t))) for i in range(10)]
    g.poly(pts, (255, 208, 60))
    g.dot(sx, sy, 0.07, (255, 255, 255))


def h_normal(g, t):
    f_normal(g, t)
    def U(x, y):
        return ((x - 16) / 14.4, (y - 16) / 14.4)
    g.dot(*U(3.4, 3.4), 0.06 + 0.05 * pulse(t), (220, 255, 220), 0.5 + 0.5 * pulse(t))


def h_move(g, t, color=(110, 232, 132)):
    """Move: four chevrons snapping in on a green light."""
    k = snap(t)
    for i in range(4):
        x, y = polar(lerp(0.74, 0.50, k), i / 4)
        chev(g, x, y, i / 4 + 0.5, 0.40, 0.20, color, spread=0.74)
    g.dot(0, 0, 0.10 + 0.14 * k, color, 0.40 + 0.30 * k)
    diamond(g, 0, 0, 0.10 + 0.05 * k, (214, 255, 214))


def h_attack(g, t, color=(255, 72, 60)):
    """Attack: hairlines, and four red blades snapping shut on the centre."""
    k = snap(t)
    for i in range(4):
        g.bar(polar(0.30, i / 4), polar(0.96, i / 4), 0.055, CREAM, 0.85)
    for i in range(4):
        wedge(g, 0.125 + i / 4, lerp(0.56, 0.12, k), 0.44, 0.19, color)
    sq = 0.085
    g.line([(-sq, -sq), (sq, -sq), (sq, sq), (-sq, sq)], 0.05, mix(CREAM, (255, 255, 255), k), closed=True)


def h_areaattack(g, t, color=(255, 72, 60)):
    """Area attack: the blades, inside a turning ring of blocks that marks the area."""
    for i in range(10):
        a = -t / 10 + i / 10
        g.band(0.84, 0.98, a - 0.028, a + 0.028, (255, 130, 40))
    g.zoom = 0.72
    h_attack(g, t, color)
    g.zoom = 1.0


def h_fight(g, t, color=(132, 140, 255)):
    """Attack-move: a sight in the fight colour, its quarters turning a notch and squeezing on the beat."""
    k = snap(t)
    x = saw(t)
    step = ease_out(min(1.0, x / 0.20))                # a quarter turn at the start of every loop
    r = lerp(0.76, 0.68, k)
    quadrants(g, r - 0.21, r, color, fill=0.66, rot=step / 4)      # between the hairlines, before and after
    for i in range(4):
        g.bar(polar(0.30, i / 4), polar(0.98, i / 4), 0.065, lite(color, 0.45))
    cross(g, 0.19, 0.06)
    g.dot(0, 0, 0.035 + 0.03 * k, CREAM)


def h_patrol(g, t, color=(84, 156, 255)):
    """Patrol: lights walking a square beat round a post."""
    h = 0.26
    g.line([(-h, -h), (h, -h), (h, h), (-h, h)], 0.13, color, closed=True)
    g.dot(0, 0, 0.07, CREAM)
    def walk(s):
        s = (s % 1.0) * 4
        e, f, r = int(s), s - int(s), 0.74
        return [(lerp(-r, r, f), -r), (r, lerp(-r, r, f)), (lerp(r, -r, f), r), (-r, lerp(r, -r, f))][e]
    for i in range(8):
        x, y = walk(t * 2 / 8 + i / 8)
        if i % 4 == 0:
            sphere(g, x, y, 0.125, (232, 240, 255))
        else:
            g.dot(x, y, 0.075, lite(color, 0.20))


def h_defend(g, t, color=(96, 176, 255)):
    """Guard: a shield that braces on the beat, its outline thrown outward as it does."""
    shape = [(0, -0.60), (0.46, -0.44), (0.46, 0.06), (0, 0.62), (-0.46, 0.06), (-0.46, -0.44)]
    k = snap(t, 0.16, 0.22, 0.30)
    r = saw(t)                                         # the outline leaves as the shield braces
    z = lerp(1.36, 1.62, ease_out(r))
    g.line([(x * z, y * z + 0.02) for x, y in shape], 0.07 * (1 - r) + 0.02, lite(color, 0.25), (1 - r) ** 1.4, closed=True)
    z = 1.22 + 0.12 * k
    S = [(x * z, y * z + 0.02) for x, y in shape]
    g.poly([S[0], S[5], S[4], S[3]], lite(color, 0.24))            # left facet
    g.poly([S[0], S[1], S[2], S[3]], deep(color, 0.16))            # right facet
    zi = z * 0.56
    I = [(x * zi, y * zi + 0.02) for x, y in shape]
    g.poly([I[0], I[5], I[4], I[3]], CREAM)
    g.poly([I[0], I[1], I[2], I[3]], mix(CREAM, color, 0.30))


def h_repair(g, t, color=(72, 232, 232)):
    """Repair: two halves driven together and welded, the arc running up the seam and throwing sparks."""
    up, hold, down = 0.20, 0.42, 0.22
    k = snap(t, up, hold, down)
    x = saw(t)
    gap = lerp(0.48, 0.0, k)
    for side in (-1, 1):
        x0, x1 = side * gap, side * (gap + 0.38)
        g.poly([(x0, -0.36), (x1, -0.36), (x1, 0.36), (x0, 0.36)], color)
        g.poly([(x0, -0.36), (x1, -0.36), (x1, -0.14), (x0, -0.14)], lite(color, 0.50))
        g.poly([(x0, 0.16), (x1, 0.16), (x1, 0.36), (x0, 0.36)], deep(color, 0.32))
        g.bar((x1 - side * 0.07, -0.36), (x1 - side * 0.07, 0.36), 0.05, deep(color, 0.45))
    if up <= x < up + hold:                            # the weld: bottom to top
        w = (x - up) / hold
        y = lerp(0.40, -0.40, w)
        g.bar((0, 0.40), (0, y), 0.075, (255, 150, 40))                      # the seam behind the arc, still hot
        g.bar((0, min(0.40, y + 0.22)), (0, y), 0.075, (255, 236, 130))
        for j in range(7):                             # sparks thrown off the arc, to both sides and upward
            age = (w * 5 + j / 7) % 1.0
            side = -1 if j % 2 else 1
            ang = side * (0.10 + 0.13 * ((j * 0.37) % 1.0))
            d = 0.10 + 0.42 * age
            sx, sy = d * math.sin(TAU * ang), y - d * math.cos(TAU * ang) + 0.30 * age * age
            g.dot(sx, sy, 0.045 * (1 - 0.6 * age), mix((255, 255, 255), (255, 170, 50), age), 1 - age)
        g.poly([(px, py + y) for px, py in [polar(0.24 if i % 2 == 0 else 0.07, i / 8 + w) for i in range(8)]], (255, 244, 170))
        g.dot(0, y, 0.07, (255, 255, 255))
    elif up + hold <= x < up + hold + down:            # welded: the seam cools as the halves draw apart
        c = (x - up - hold) / down
        g.bar((0, 0.40), (0, -0.40), 0.075 * (1 - c), (255, 150, 40), 1 - c)


def h_revive(g, t, color=(110, 190, 255)):
    """Resurrect: a cross that beats, life spreading from it."""
    for ph in (0.0, 0.5):
        k = saw(t + ph)
        r = lerp(0.42, 0.96, k)
        g.band(r - 0.08 * (1 - 0.5 * k), r, 0, 1, color, (1 - k) ** 0.9)
    s = 1 + 0.08 * pulse(t * 2)
    arm, w = 0.50 * s, 0.15 * s
    g.poly([(-arm, -w), (arm, -w), (arm, w), (-arm, w)], color)
    g.poly([(-w, -arm), (w, -arm), (w, arm), (-w, arm)], lite(color, 0.18))
    g.bar((-arm + 0.10, 0), (arm - 0.10, 0), 0.11 * s, CREAM)
    g.bar((0, -arm + 0.10), (0, arm - 0.10), 0.11 * s, CREAM)


def h_capture(g, t, color=(255, 232, 84)):
    """Capture: your flag run up the pole, flying, and brought down again."""
    k = snap(t, 0.22, 0.40, 0.22)
    g.bar((-0.44, -0.90), (-0.44, 0.84), 0.11, CREAM)
    g.bar((-0.70, 0.84), (-0.18, 0.84), 0.12, deep(color, 0.25))
    g.dot(-0.44, -0.90, 0.085, CREAM)
    y0 = lerp(0.14, -0.82, k)
    top, bot = [], []
    for i in range(9):
        x = -0.38 + 0.98 * i / 8
        wave = 0.08 * math.sin(TAU * (i / 8 * 1.2 - t * 2)) * (i / 8)
        top.append((x, y0 + wave))
        bot.append((x, y0 + 0.58 + wave))
    mid = [((p[0] + q[0]) / 2, (p[1] + q[1]) / 2) for p, q in zip(top, bot)]
    g.poly(top + mid[::-1], lite(color, 0.28))
    g.poly(mid + bot[::-1], deep(color, 0.08))


def h_crates(g, t, gather, color):
    k = saw(t)
    if gather:
        k = 1 - k
    e = ease_out(k)
    fade = min(1.0, math.sin(math.pi * saw(t)) * 3.4)
    for i in range(4):
        x, y = polar(0.62 * e, 0.125 * e + i / 4)
        cube(g, x, y, lerp(0.24, 0.17, e), color, fade)


def h_pickup(g, t, color=(72, 232, 232)):
    """Load: four crates drawn in to one."""
    h_crates(g, t, True, color)


def h_unload(g, t, color=(255, 222, 72)):
    """Unload: one crate thrown out as four."""
    h_crates(g, t, False, color)


def h_dgun(g, t, color=(255, 190, 56)):
    """Manual fire: a bolt, rays leaving it on every beat."""
    k = saw(t * 2)
    for i in range(6):
        a = i / 6 + 1 / 12
        g.bar(polar(lerp(0.62, 0.82, k), a), polar(lerp(0.62, 0.82, k) + 0.16 * (1 - k), a), 0.07, color, 1 - k)
    flick = 0.5 + 0.5 * math.sin(TAU * t * 4)
    g.zoom = 1.22
    g.poly([(0.20, -0.72), (-0.34, 0.08), (0.00, 0.08)], mix(CREAM, (255, 255, 255), flick))
    g.poly([(0.00, 0.08), (-0.20, 0.72), (0.38, -0.16), (0.06, -0.16), (0.20, -0.72)], mix(color, lite(color, 0.4), flick))
    g.zoom = 1.0


def h_areamex(g, t, color=(169, 201, 234)):
    """Area mex: an extractor turning, the corners of its area marked."""
    half, L, w = 0.94, 0.26, 0.085
    for sx, sy in ((-1, -1), (1, -1), (1, 1), (-1, 1)):
        g.poly([(sx * half, sy * half), (sx * (half - L), sy * half), (sx * (half - L), sy * (half - w)),
                (sx * (half - w), sy * (half - w)), (sx * (half - w), sy * (half - L)), (sx * half, sy * (half - L))], deep(color, 0.25))
    for i in range(3):
        a = i / 3 - t / 3
        g.bar(polar(0.10, a), polar(0.56, a), 0.18, color)
        sphere(g, *polar(0.60, a), 0.155, lite(color, 0.25))
    g.dot(0, 0, 0.18, CREAM)


def h_grab(g, t, color=(236, 243, 255)):
    """Grab: a hand closed on the map, arrows showing it can be pulled any way.
    Shown by the Grab Pan widget while the middle mouse button drags the view."""
    k = pulse(t * 2)
    for i in range(4):                                   # the four ways it can go
        x, y = polar(lerp(0.80, 0.90, k), i / 4)
        chev(g, x, y, i / 4, 0.20, 0.10, (150, 196, 240), 0.55 + 0.45 * k, spread=0.80)
    # A cartoon glove closed into a fist, seen from the back of the hand: four
    # fat fingers in a row with a knuckle on each, the thumb tucked against the
    # side (it never crosses the back of the fingers), a rolled cuff below.
    # Every part is laid down twice, dark and a little larger first, so each
    # keeps a bold outline.
    skin, ink = (255, 251, 232), (38, 44, 58)
    g.zoom = 0.90
    edge = 0.085                                          # how much wider the dark pass is
    up = -0.10                                            # sits above centre, clear of the lower arrow
    tops = (-0.10, -0.19, -0.18, -0.08)                   # index, middle, ring, little
    xs = (-0.28, -0.08, 0.12, 0.32)
    body = [(-0.13, 0.22 + up), (0.17, 0.22 + up)]
    cuff = [(-0.21, 0.60 + up), (0.25, 0.60 + up)]
    thumb = [(-0.50, 0.12 + up), (-0.44, 0.32 + up)]      # beside the index finger, pointing up
    fingers = [[(x, 0.04 + up), (x, top + up)] for x, top in zip(xs, tops)]
    g.line(thumb, 0.20 + edge, ink)                       # the thumb first: the hand overlaps it
    g.line(thumb, 0.20, skin)
    g.line(body, 0.56 + edge, ink)
    for f in fingers:
        g.line(f, 0.21 + edge, ink)
    g.line(body, 0.56, skin)
    for f in fingers:
        g.line(f, 0.21, skin)
    for i in range(3):                                    # the gaps between the fingers
        x = (xs[i] + xs[i + 1]) / 2
        g.line([(x, max(tops[i], tops[i + 1]) + 0.03 + up), (x, 0.12 + up)], 0.035, ink)
    for x in xs:                                          # a knuckle on the back of each
        g.arc(0.06, 0.30, 0.70, 0.028, ink, 0.6, cx=x, cy=0.24 + up)
    g.line(cuff, 0.24 + edge, ink)                        # the cuff, over the wrist
    g.line(cuff, 0.24, skin)
    g.zoom = 1.0


FA = {
    "grab": h_grab,
    "normal": h_normal, "move": h_move, "attack": h_attack, "areaattack": h_areaattack, "setattack": b_setattack,
    "fight": h_fight, "patrol": h_patrol, "defend": h_defend, "repair": h_repair, "reclamate": b_reclamate,
    "revive": h_revive, "restore": b_restore, "capture": h_capture, "pickup": h_pickup, "unload": h_unload,
    "dgun": h_dgun, "wait": f_wait, "selfd": b_selfd, "jump": b_jump, "bomb": f_bomb, "purchase": b_purchase,
    "areamex": h_areamex,
}


# name -> (draw function, size, hotspot, seconds the first frame is held)
CURSORS = [
    ("normal",     flashy(c_normal, fx_normal), 32, "topleft", 1.6),
    ("move",       flashy(c_move, fx_move), 48, "center", 0),
    ("attack",     flashy(c_attack, fx_attack), 48, "center", 0),
    ("areaattack", flashy(c_areaattack, fx_areaattack), 48, "center", 0),
    ("setattack",  flashy(c_setattack, fx_setattack), 48, "center", 0),
    ("fight",      flashy(c_fight, fx_fight), 48, "center", 0),
    ("patrol",     flashy(c_patrol, fx_patrol), 48, "center", 0),
    ("defend",     flashy(c_defend, fx_defend), 48, "center", 0),
    ("repair",     flashy(c_repair, fx_repair), 48, "center", 0),
    ("reclamate",  flashy(c_reclamate, fx_reclamate), 48, "center", 0),
    ("revive",     flashy(c_revive, fx_revive), 48, "center", 0),
    ("restore",    flashy(c_restore, fx_restore), 48, "center", 0),
    ("capture",    flashy(c_capture, fx_capture), 48, "center", 0),
    ("pickup",     flashy(c_pickup, fx_pickup), 48, "center", 0),
    ("unload",     flashy(c_unload, fx_unload), 48, "center", 0),
    ("dgun",       flashy(c_dgun, fx_dgun), 48, "center", 0),
    ("wait",       flashy(c_wait, fx_wait), 48, "center", 0),
    ("selfd",      flashy(c_selfd, fx_selfd), 48, "center", 0),
    ("jump",       flashy(c_jump, fx_jump), 48, "center", 0),
    ("bomb",       flashy(c_bomb, fx_bomb), 48, "center", 0),
    ("purchase",   flashy(c_purchase, fx_purchase), 48, "center", 0),
    ("areamex",    flashy(c_areamex, fx_areamex), 48, "center", 0),
    ("grab",       lambda g, t: h_grab(g, t), 48, "center", 0),
]

LABELS = {"grab": "grab (pan the view)", "normal": "pointer", "setattack": "set target", "defend": "guard", "repair": "build / repair",
          "reclamate": "reclaim", "revive": "resurrect", "pickup": "load", "dgun": "manual fire",
          "selfd": "self-destruct", "areaattack": "area attack", "areamex": "area mex"}


# ----------------------------------------------------------------------------
# styles: what turns the vector drawing into a finished frame
# ----------------------------------------------------------------------------

def _np(img):
    return np.asarray(img, dtype=np.float32) / 255.0


def _blur1(ch, radius):
    """Gaussian blur of one float channel (PIL cannot blur floats), nothing beyond the edges."""
    n = max(1, int(radius * 3))
    taps = np.exp(-0.5 * (np.arange(-n, n + 1, dtype=np.float32) / radius) ** 2)
    taps /= taps.sum()
    out = ch.astype(np.float32)
    for axis in (0, 1):
        pad = [(0, 0), (0, 0)]
        pad[axis] = (n, n)
        src = np.pad(out, pad)
        acc = np.zeros_like(out)
        size = out.shape[axis]
        for i in range(2 * n + 1):
            acc += taps[i] * (src[i:i + size] if axis == 0 else src[:, i:i + size])
        out = acc
    return out


def _blur(a, radius):
    """Blur of a straight-alpha image, done premultiplied so edges keep their colour."""
    al = _blur1(a[..., 3], radius)
    out = np.empty_like(a)
    for c in range(3):
        out[..., c] = _blur1(a[..., c] * a[..., 3], radius) / np.maximum(al, 1e-5)
    out[..., 3] = al
    return np.clip(out, 0, 1)


def _over(dst, src):
    sa, da = src[..., 3:4], dst[..., 3:4]
    oa = sa + da * (1 - sa)
    rgb = (src[..., :3] * sa + dst[..., :3] * da * (1 - sa)) / np.maximum(oa, 1e-5)
    return np.concatenate([rgb, oa], axis=2)


def _mix(a, b, k):
    if np.ndim(k) == 2:
        k = k[..., None]
    return a + (np.asarray(b, dtype=np.float32) - a) * k


def _hsv(rgb):
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    mx, mn = rgb.max(axis=2), rgb.min(axis=2)
    d = mx - mn
    h = np.zeros_like(mx)
    m = d > 1e-6
    rc = np.where(m, (mx - r) / np.maximum(d, 1e-6), 0)
    gc = np.where(m, (mx - g) / np.maximum(d, 1e-6), 0)
    bc = np.where(m, (mx - b) / np.maximum(d, 1e-6), 0)
    h = np.where(mx == r, bc - gc, np.where(mx == g, 2.0 + rc - bc, 4.0 + gc - rc))
    h = np.where(m, (h / 6.0) % 1.0, 0)
    s = np.where(mx > 1e-6, d / np.maximum(mx, 1e-6), 0)
    return h, s, mx


def _rgb(h, s, v):
    h = (h % 1.0) * 6.0
    i = np.floor(h)
    f = h - i
    p, q, t = v * (1 - s), v * (1 - s * f), v * (1 - s * (1 - f))
    i = i.astype(int) % 6
    r = np.choose(i, [v, q, p, p, t, v])
    g = np.choose(i, [t, v, v, q, p, p])
    b = np.choose(i, [p, p, t, v, v, q])
    return np.stack([r, g, b], axis=2)


def _glow(ink, radius, gain, tint=None, amount=0.0):
    g = _blur(ink, radius)
    if tint is not None:
        g[..., :3] = _mix(g[..., :3], tint, amount)
    g[..., 3] = np.clip(g[..., 3] * gain, 0, 1)
    return g


def _rim(alpha, radius, gain, strength):
    """The dark edge that keeps a cursor readable on bright ground."""
    r = np.clip(_blur1(alpha, radius) * gain, 0, 1) * strength
    out = np.zeros(alpha.shape + (4,), dtype=np.float32)
    out[..., 0], out[..., 1], out[..., 2] = DARK[0] / 255, DARK[1] / 255, DARK[2] / 255
    out[..., 3] = r
    return out


def _core(alpha, S, width=0.55, edge=0.62):
    """1 along the middle of every stroke, 0 at its edges."""
    return np.clip((_blur1(alpha, width * S) - edge) / 0.25, 0, 1)


def _stack(parts):
    out = np.zeros_like(parts[0])
    for part in parts:
        out = _over(out, part)
    return out


def style_bastion(g, ink, X, Y, S, t):
    """Chunky enamel: every shape light at the top and deep at the bottom, bevelled,
    a dark outline, a soft glow in its own colour that breathes. Colours hold still."""
    A = ink[..., 3]
    h, s, v = _hsv(ink[..., :3])
    coloured = (s > 0.25) & (v > 0.25)      # not the creams, whites and near-blacks: those stay as drawn
    sat = np.where(coloured, np.clip(s * 1.45 + 0.12, 0, 1), s)     # the command's colour, full strength
    base = _rgb(h, sat, np.where(coloured, np.clip(v * 1.08, 0, 1), v))
    up = np.clip((1 - Y) / 2, 0, 1)                                  # 1 at the top
    # light at the top, deep at the bottom, staying in the colour: the top loses
    # only a little saturation, the bottom gains some and goes darker
    k = up * 2 - 1                                                   # -1 bottom .. 1 top
    # and the hue leans toward its bright neighbour (yellow or cyan) at the top, away at the bottom
    toward = np.where(np.abs(((h - 1 / 6 + 0.5) % 1.0) - 0.5) < np.abs(((h - 0.5 + 0.5) % 1.0) - 0.5), 1 / 6, 0.5)
    lean = ((toward - h + 0.5) % 1.0) - 0.5
    h = h + np.where(coloured, np.clip(lean, -0.045, 0.045) * k, 0)
    gs = np.where(coloured, np.clip(sat * np.where(k > 0, 1 - 0.30 * k, 1 - 0.10 * k), 0, 1), sat)
    gv = np.clip(np.where(k > 0, 1.0, 1 + 0.45 * k) * np.where(coloured, np.maximum(v, 0.92), v), 0, 1)
    col = _rgb(h, gs, gv)
    hgt = _blur1(A, 0.9 * S)
    gy, gx = np.gradient(hgt)
    d = (gx + gy) * S * 1.7
    col = _mix(col, (1, 1, 1), np.clip(-d, 0, 1) * 0.38)             # lit from the top left
    col = col * (1 - 0.45 * np.clip(d, 0, 1))[..., None]
    body = ink.copy()
    body[..., :3] = np.clip(col, 0, 1)
    lit = ink.copy()
    lit[..., :3] = base
    breathe = 0.70 + 0.30 * pulse(t * 2)
    return _stack([_glow(lit, 3.6 * S, 1.30 * breathe),
                   _glow(lit, 1.5 * S, 1.45 * breathe),
                   _rim(A, 0.65 * S, 5.0, 0.92),
                   body])


def style_forboding(g, ink, X, Y, S, t):
    """The colours as drawn, bevelled and a touch lighter at the top, a dark outline, a soft glow."""
    A = ink[..., 3]
    up = np.clip((1 - Y) / 2, 0, 1)
    h, sat, v = _hsv(ink[..., :3])
    coloured = (sat > 0.25) & (v > 0.25)                              # not the creams, whites and near-blacks
    sat = np.where(coloured, np.clip(sat * 1.45 + 0.08, 0, 1), sat)   # full-strength colour
    col = _rgb(h, sat, v) * (0.64 + 0.40 * up)[..., None]             # light at the top, deep at the bottom
    hgt = _blur1(A, 0.9 * S)
    gy, gx = np.gradient(hgt)
    d = (gx + gy) * S * 1.7
    col = _mix(col, (1, 1, 1), np.clip(-d, 0, 1) * 0.26)
    col = col * (1 - 0.42 * np.clip(d, 0, 1))[..., None]
    body = ink.copy()
    body[..., :3] = np.clip(col, 0, 1)
    solid = ink.copy()
    solid[..., 3] = np.clip(A * 1.6 - 0.45, 0, 1)                    # the dark glass does not glow
    return _stack([_glow(solid, 3.4 * S, 1.0),
                   _glow(solid, 1.4 * S, 1.2),
                   _rim(solid[..., 3], 0.65 * S, 5.0, 0.90),
                   body])


def style_neon(g, ink, X, Y, S, t):
    """Glass tubes: a white-hot core, a two-tone tube, a deep coloured glow."""
    A = ink[..., 3]
    h, s, v = _hsv(ink[..., :3])
    h = h + 0.075 * (X + Y) / 2            # the colour drifts across the cursor
    s = np.where(s > 0.12, np.clip(s * 1.2, 0, 1), s)
    tube = ink.copy()
    tube[..., :3] = _rgb(h, s, np.clip(v * 1.05, 0, 1))
    body = tube.copy()
    body[..., :3] = _mix(tube[..., :3], (1, 1, 1), _core(A, S) * 0.92)
    breathe = 0.85 + 0.15 * pulse(t * 2)
    return _stack([_rim(A, 1.2 * S, 2.6, 0.62),
                   _glow(tube, 4.0 * S, 1.25 * breathe),
                   _glow(tube, 1.6 * S, 1.6),
                   body])


def style_prism(g, ink, X, Y, S, t):
    """A rainbow turning through every shape; whites go pastel."""
    A = ink[..., 3]
    h, s, v = _hsv(ink[..., :3])
    ang = np.arctan2(X, -Y) / TAU
    R = np.sqrt(X * X + Y * Y)
    h = h + 0.17 * np.sin(TAU * (ang + t)) + 0.09 * np.sin(TAU * (R * 1.2 - t))
    white = s < 0.14
    h = np.where(white, ang * 2 + t + R * 0.5, h)
    s = np.where(white, 0.30, np.clip(s * 1.25, 0, 1))
    col = ink.copy()
    col[..., :3] = _rgb(h, s, np.clip(v * 1.08, 0, 1))
    body = col.copy()
    body[..., :3] = _mix(col[..., :3], (1, 1, 1), _core(A, S, 0.5, 0.70) * 0.75)
    return _stack([_rim(A, 1.1 * S, 2.8, 0.70),
                   _glow(col, 3.6 * S, 1.1),
                   _glow(col, 1.5 * S, 1.5),
                   body])


def style_molten(g, ink, X, Y, S, t):
    """Forged: white-hot at the top of every cursor, cooling to deep colour below, in a furnace glow."""
    A = ink[..., 3]
    rgb = ink[..., :3]
    up = np.clip((1 - Y) / 2, 0, 1) ** 1.25
    flick = 0.90 + 0.10 * math.sin(TAU * t * 3)
    h, s, v = _hsv(rgb)
    sat = _rgb(h, np.where(s > 0.12, np.clip(s * 1.6 + 0.10, 0, 1), s), v) # the command's colour, pushed hard
    deep = sat * np.array([0.98, 0.66, 0.60], dtype=np.float32)           # cooling: darker, redder
    hot = _mix(sat, (1.0, 0.90, 0.40), 0.50)                               # yellow-hot, still the colour
    col = np.where((up < 0.5)[..., None], _mix(deep, sat, up * 2), _mix(sat, hot, up * 2 - 1))
    body = ink.copy()
    body[..., :3] = np.clip(col * flick * 1.08, 0, 1)
    body[..., :3] = _mix(body[..., :3], (1, 0.97, 0.80), _core(A, S, 0.5, 0.74) * 0.38 * (0.4 + 0.6 * up))
    glowsrc = ink.copy()
    glowsrc[..., :3] = sat
    return _stack([_rim(A, 1.1 * S, 3.0, 0.80),
                   _glow(glowsrc, 3.8 * S, 1.05 * flick, (1.0, 0.36, 0.06), 0.30),
                   _glow(glowsrc, 1.5 * S, 1.4, (1.0, 0.50, 0.10), 0.15),
                   body])


def style_crystal(g, ink, X, Y, S, t):
    """Cut glass: lit from the top left, shaded bottom right, a band of light sliding across."""
    A = ink[..., 3]
    rgb = ink[..., :3]
    hgt = _blur1(A, 1.0 * S)
    gy, gx = np.gradient(hgt)
    d = (gx + gy) * S * 1.9
    light, shade = np.clip(-d, 0, 1), np.clip(d, 0, 1)
    col = rgb * (0.78 + 0.30 * np.clip((1 - Y) / 2, 0, 1))[..., None]
    col = _mix(col, (1, 1, 1), light * 0.90)
    col = col * (1 - 0.52 * shade)[..., None]
    band = np.exp(-(((X + Y) / 1.414 - lerp(-1.9, 1.9, t)) / 0.17) ** 2)
    col = _mix(col, (1, 1, 1), band * 0.88)
    body = ink.copy()
    body[..., :3] = np.clip(col, 0, 1)
    halo = _glow(ink, 2.6 * S, 1.1, (1, 1, 1), 0.35)
    halo[..., 3] = np.clip(halo[..., 3] * (1 + 1.6 * band), 0, 1)
    return _stack([_rim(A, 0.8 * S, 4.2, 0.92),
                   halo,
                   body])


def style_holo(g, ink, X, Y, S, t):
    """A projection: cyan-washed, scan lines crawling, colour fringes, the odd glitch."""
    ink = ink.copy()
    f = int(round(t * FRAMES)) % FRAMES
    if f in (7, 8, 19):                   # a slice of the picture jumps sideways
        n = ink.shape[0]
        y0 = int(n * (0.30 if f < 10 else 0.58))
        y1 = y0 + int(n * (0.16 if f != 8 else 0.08))
        ink[y0:y1] = np.roll(ink[y0:y1], int((3 if f != 8 else -2) * S), axis=1)
    A = ink[..., 3]
    rgb = _mix(ink[..., :3], (0.30, 0.95, 1.0), 0.38)
    wash = ink.copy()
    wash[..., :3] = rgb
    sh = max(1, int(round(0.8 * S)))
    P = rgb * A[..., None]
    Pr, Pb = np.roll(P[..., 0], -sh, axis=1), np.roll(P[..., 2], sh, axis=1)
    al = np.maximum(A, np.maximum(np.roll(A, -sh, axis=1), np.roll(A, sh, axis=1)) * 0.75)
    body = np.zeros_like(ink)
    body[..., 0] = Pr / np.maximum(al, 1e-5)
    body[..., 1] = P[..., 1] / np.maximum(al, 1e-5)
    body[..., 2] = Pb / np.maximum(al, 1e-5)
    rows = (Y + 1) / 2 * ink.shape[0] / S
    scan = 0.58 + 0.42 * (0.5 + 0.5 * np.sin(TAU * (rows / 3.0 - t * 2)))
    sweep = np.exp(-((Y - lerp(1.25, -1.25, t)) / 0.09) ** 2)
    body[..., :3] = np.clip(_mix(body[..., :3], (1, 1, 1), sweep * 0.85), 0, 1)
    flick = 0.90 + 0.10 * math.sin(TAU * t * 4)
    body[..., 3] = np.clip(al * (scan + sweep * 0.5) * flick, 0, 1)
    return _stack([_rim(A, 1.1 * S, 2.4, 0.55),
                   _glow(wash, 3.6 * S, 0.9 * flick),
                   _glow(wash, 1.5 * S, 1.2),
                   body])


def embers(g, t):
    """Molten's sparks, rising off every cursor."""
    for i in range(max(2, int(round(8 * (0.25 + 0.75 * SPARKLE))))):
        k = saw(t + i * 0.37)
        x = ((i * 0.618) % 1.0) * 1.7 - 0.85 + 0.07 * math.sin(TAU * (t * 2 + i / 8))
        g.dot(x, lerp(0.92, -0.96, k), 0.050 - 0.022 * k, mix(HOT, ORANGE, k), math.sin(math.pi * k) ** 0.8)


# key -> (name, look, extra vector layer or None, line width, flash layer, frames per loop, seconds per frame).
# The first is the game's set: the only one written unless --only names another, and it goes to
# Anims/ itself. The rest are other looks tried along the way, kept for --only and --previews.
STYLES = [
    ("forboding", "Forboding Angel", style_forboding, None,   1.0, False, 36,     1 / 30),     # 30 a second, 1.2 s
    ("bastion",   "Bastion",         style_bastion,   None,   1.0, False, FRAMES, FRAME_TIME),
    ("neon",      "Neon",            style_neon,      None,   1.0, True,  FRAMES, FRAME_TIME),
    ("prism",     "Prism",           style_prism,     None,   1.0, True,  FRAMES, FRAME_TIME),
    ("molten",    "Molten",          style_molten,    embers, 1.0, True,  FRAMES, FRAME_TIME),
    ("crystal",   "Crystal",         style_crystal,   None,   1.0, True,  FRAMES, FRAME_TIME),
    ("holo",      "Hologram",        style_holo,      None,   1.0, True,  FRAMES, FRAME_TIME),
]
STYLE = {st[0]: st[1:] for st in STYLES}
DEFAULT_STYLE = STYLES[0][0]


def render(g, style):
    look = STYLE[style][1]
    ink = np.zeros((g.px, g.px, 4), dtype=np.float32)
    for img, _ in g.layers:
        ink = _over(ink, _np(img))
    axis = (np.arange(g.px, dtype=np.float32) + 0.5 - g.c) / g.r
    X, Y = np.meshgrid(axis, axis)
    out = look(g, ink, X, Y, SS * g.scale, g.t)
    edge = np.maximum(np.abs(X), np.abs(Y)) * g.r / g.c        # 0 centre, 1 the frame's edge
    fade = np.clip((1.0 - edge) / 0.20, 0, 1)
    out[..., 3] *= fade * fade * (3 - 2 * fade)                # nothing may end in a hard square
    img = Image.fromarray((np.clip(out, 0, 1) * 255 + 0.5).astype(np.uint8), "RGBA")
    final = g.size * g.scale
    return img.resize((final, final), Image.LANCZOS)


def glyph(style, index):
    """The drawing function and size of a cursor in a style: Bastion has its own bold glyphs."""
    name, fn, size, hotspot, hold = CURSORS[index]
    if style == "bastion":
        return BOLD[name], (size if name == "normal" else BOLD_SIZE)
    if style == "forboding":
        return FA[name], (size if name == "normal" else BOLD_SIZE)
    return fn, size


def frames_of(fn, size, scale=1, style=DEFAULT_STYLE):
    out = []
    label, look, extra, wscale, fx, frames, frame_time = STYLE[style]
    for i in range(frames):
        g = G(size, scale)
        g.t = i / frames
        g.wscale, g.fx, g.style = wscale, fx, style
        fn(g, g.t)
        if extra and size > 32:           # not on the pointer
            g.new_layer(glow=2.0)
            extra(g, g.t)
        out.append(render(g, style))
    return out


def set_dir(style):
    return OUT if style == DEFAULT_STYLE else os.path.join(OUT, style)


def write_cursor(job):
    style, index = job
    name, fn, size, hotspot, hold = CURSORS[index]
    where = set_dir(style)
    prefix = "anims/" if style == DEFAULT_STYLE else "anims/%s/" % style
    lines = ["hotspot " + hotspot]
    fn, size = glyph(style, index)
    for i, im in enumerate(frames_of(fn, size, 1, style)):
        im.save(os.path.join(where, "cursor%s_%d.png" % (name, i)), optimize=True)
        dur = STYLE[style][6] + (hold if i == 0 else 0)
        lines.append("frame  %scursor%s_%d.png  %s" % (prefix, name, i, ("%.4f" % dur).rstrip("0").rstrip(".")))
    with open(os.path.join(where, "cursor%s.txt" % name), "w", newline="\n") as f:
        f.write("\n".join(lines) + "\n")


def write_sets(styles, pool):
    for style in styles:
        where = set_dir(style)
        os.makedirs(where, exist_ok=True)
        for f in os.listdir(where):
            if f.startswith("cursor") and (f.endswith(".png") or f.endswith(".txt")):
                os.remove(os.path.join(where, f))
    pool.map(write_cursor, [(style, i) for style in styles for i in range(len(CURSORS))])
    for style in styles:
        print("wrote %s: %d cursors, %d frames each, to %s" % (style, len(CURSORS), STYLE[style][5], set_dir(style)))


def font(size):
    for p in (os.path.join(REPO, "LuaUI", "fonts", "Saira_SemiCondensed-SemiBold.ttf"),
              os.path.join(REPO, "Fonts", "Saira_SemiCondensed-SemiBold.ttf"),
              "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"):
        if os.path.exists(p):
            return ImageFont.truetype(p, size)
    return ImageFont.load_default()


def background(w, h, kind):
    """Something like the ground a cursor sits on: dark panel, or sunlit dirt."""
    import random
    rnd = random.Random(7)
    base = {"dark": (18, 24, 31), "ground": (118, 96, 66), "grass": (74, 104, 52)}[kind]
    im = Image.new("RGB", (w, h), base)
    px = im.load()
    for y in range(h):
        for x in range(w):
            n = rnd.randint(-9, 9)
            px[x, y] = tuple(max(0, min(255, c + n)) for c in base)
    return im.filter(ImageFilter.GaussianBlur(0.8))


def preview_frames(job):
    style, index = job
    fn, size = glyph(style, index)
    return frames_of(fn, size, 2, style), frames_of(fn, size, 1, style)


def preview(style, path, pool, sheet=None):
    """An animated GIF of one set: every cursor at 2x and at actual size, on dark, dirt and grass."""
    cols = 6
    cell_w, cell_h = 150, 150
    rows = math.ceil(len(CURSORS) / cols)
    head = 54
    W, H = cols * cell_w, head + rows * cell_h
    bg = Image.new("RGB", (W, H), (11, 14, 18))
    kinds = ["dark", "ground", "grass"]
    tiles = {k: background(cell_w - 10, cell_h - 34, k) for k in kinds}
    d = ImageDraw.Draw(bg)
    d.text((14, 12), "SPLINTERFACTION  /  CURSOR SET:  " + STYLE[style][0].upper(), font=font(22), fill=WHITE)
    d.text((W - 250, 20), "shown at 2x and at actual size", font=font(13), fill=(133, 147, 161))
    d.line((14, 46, W - 14, 46), fill=ORANGE, width=2)
    rendered = pool.map(preview_frames, [(style, i) for i in range(len(CURSORS))])
    for i, (name, fn, size, hotspot, hold) in enumerate(CURSORS):
        cx, cy = (i % cols) * cell_w, head + (i // cols) * cell_h
        bg.paste(tiles[kinds[(i + i // cols) % 3]], (cx + 5, cy + 4))
        d.text((cx + 8, cy + cell_h - 27), LABELS.get(name, name).upper(), font=font(13), fill=(194, 204, 214))
    out = []
    for f in range(STYLE[style][5]):
        im = bg.copy().convert("RGBA")
        for i in range(len(CURSORS)):
            cx, cy = (i % cols) * cell_w, head + (i // cols) * cell_h
            b = rendered[i][0][f]
            im.alpha_composite(b, (cx + 8 + (96 - b.width) // 2, cy + 10 + (96 - b.height) // 2))
            s = rendered[i][1][f]
            im.alpha_composite(s, (cx + cell_w - 8 - 48 + (48 - s.width) // 2, cy + cell_h - 32 - 52 + (48 - s.height) // 2))
        out.append(im.convert("RGB"))
    q = [o.quantize(colors=255, method=Image.MEDIANCUT, dither=Image.FLOYDSTEINBERG) for o in out]
    q[0].save(path, save_all=True, append_images=q[1:], duration=int(round(STYLE[style][6] * 100)) * 10, loop=0, optimize=False, disposal=1)
    print("wrote", path)
    if sheet:
        out[5].save(sheet)
        print("wrote", sheet)


if __name__ == "__main__":
    import multiprocessing
    ap = argparse.ArgumentParser()
    ap.add_argument("--previews", metavar="DIR", help="write cursors-<style>.gif (and a still .png) of each set here")
    ap.add_argument("--no-write", action="store_true", help="do not write the sets, only the previews")
    ap.add_argument("--only", metavar="STYLE", action="append", help="only this style (may be repeated)")
    a = ap.parse_args()
    styles = a.only or [DEFAULT_STYLE]
    for style in styles:
        if style not in STYLE:
            sys.exit("no such style: %s (have: %s)" % (style, ", ".join(STYLE)))
    with multiprocessing.Pool() as pool:
        if not a.no_write:
            write_sets(styles, pool)
        if a.previews:
            os.makedirs(a.previews, exist_ok=True)
            for style in styles:
                preview(style, os.path.join(a.previews, "cursors-%s.gif" % style), pool,
                        os.path.join(a.previews, "cursors-%s.png" % style))
