"""The distant city: skyline towers seen past the perimeter (docs/STYLES.md §7 Stage 1 sky).

Owner, 2026-11-08: the old flat-slab skyline "looks really goofy... should still be detailed".
Six tower types share one file (a set, like props.py), each built floor by floor: a glass
core, a concrete spandrel ring per storey (ribbon or punched windows), piers on the window
grid, setbacks, a parapet and rooftop plant (stair hut, lift room, tanks, masts). Every tower
has a `<name>_lit` twin: the lit windows as thin slabs on the same grid, uploaded as a second
mesh that SkyService paints Neon (sodium / fluorescent), so a window glows one window at a
time instead of the old storey-wide bars.

Scale: built to the 5-stud figure (a storey is 10 studs, a bay 6), then placed 470-560 studs
out by SkyService at a uniform scale per entry. Pivot at the bottom centre; the facade grid
runs on all four sides (the player sees two faces from inside the arena). Build with:

    blender --background --python assets/3d/build/build_assets.py -- --only env_city_office
"""

import math
import random

STOREY = 10.0


# ------------------------------------------------------------------ kit
def facade(b, w, d, z0, z1, *, bay=6.0, band=4.0, pier=0.6, pier_out=0.5, band_out=0.8,
           core="glass", band_sw="concrete", pier_sw="concrete_d", lit=None, rng=None,
           lit_rate=0.06, cx=0.0, cy=0.0, storey=STOREY):
    """A shaft w x d from z0 to z1: glass core, one spandrel ring per storey (`band` tall,
    `band_out` proud), piers every `bay` (`pier` wide, `pier_out` proud). Window openings are
    what is left between them. Appends lit-window slabs to `lit` (a Builder) at `lit_rate`."""
    h = z1 - z0
    b.box((w, d, h), (cx, cy, z0 + h / 2), swatch=core)
    floors = max(1, int(round(h / storey)))
    st = h / floors
    for i in range(floors + 1):
        z = z0 + i * st
        zb = z - band / 2 if i else z0 + band / 4
        hb = band if 0 < i < floors else band / 2
        b.box((w + 2 * band_out, d + 2 * band_out, hb), (cx, cy, min(max(zb, z0 + hb / 2), z1 - hb / 2)), swatch=band_sw)
    # piers on the long (x) faces and the short (y) faces
    for axis, length, other in (("x", w, d), ("y", d, w)):
        n = max(1, int(round(length / bay)))
        step = length / n
        for k in range(n + 1):
            t = -length / 2 + k * step
            for side in (-1, 1):
                if axis == "x":
                    loc = (cx + t, cy + side * (other / 2 + pier_out / 2), z0 + h / 2)
                    size = (pier, pier_out, h)
                else:
                    loc = (cx + side * (other / 2 + pier_out / 2), cy + t, z0 + h / 2)
                    size = (pier_out, pier, h)
                b.box(size, loc, swatch=pier_sw)
        if lit is None:
            continue
        # lit windows: a slab in a window opening, 0.12 proud of the glass
        win_h = st - band - 0.8
        for k in range(n):
            t = -length / 2 + (k + 0.5) * step
            for f in range(floors):
                for side in (-1, 1):
                    if rng.random() > lit_rate:
                        continue
                    zc = z0 + f * st + st / 2
                    ww = step - pier - 0.8
                    if axis == "x":
                        lit.box((ww, 0.1, win_h), (cx + t, cy + side * (other / 2 + 0.12), zc), swatch="white_l")
                    else:
                        lit.box((0.1, ww, win_h), (cx + side * (other / 2 + 0.12), cy + t, zc), swatch="white_l")


def parapet(b, w, d, z, h=1.6, t=0.6, sw="concrete_d", cx=0.0, cy=0.0):
    b.box((w, t, h), (cx, cy - d / 2 + t / 2, z + h / 2), swatch=sw)
    b.box((w, t, h), (cx, cy + d / 2 - t / 2, z + h / 2), swatch=sw)
    b.box((t, d - 2 * t, h), (cx - w / 2 + t / 2, cy, z + h / 2), swatch=sw)
    b.box((t, d - 2 * t, h), (cx + w / 2 - t / 2, cy, z + h / 2), swatch=sw)


def roof_slab(b, w, d, z, sw="concrete_d", cx=0.0, cy=0.0, over=1.0):
    b.box((w + 2 * over, d + 2 * over, 1.0), (cx, cy, z + 0.5), swatch=sw)
    return z + 1.0


def tank(b, x, y, z, r=3.0, h=6.0):
    """A water tank on four legs with a conical cap."""
    for sx in (-1, 1):
        for sy in (-1, 1):
            b.box((0.5, 0.5, 4.0), (x + sx * r * 0.6, y + sy * r * 0.6, z + 2.0), swatch="dark")
    b.box((2 * r + 0.4, 2 * r + 0.4, 0.4), (x, y, z + 4.2), swatch="dark")
    b.cyl(r, h, (x, y, z + 4.4 + h / 2), segs=10, swatch="tan_d")
    b.cyl(r, 1.6, (x, y, z + 4.4 + h + 0.8), segs=10, r2=0.4, swatch="dark")


def plant(b, x, y, z, w, d, h, sw="concrete"):
    """A rooftop box (stair hut, lift room, chiller) with a dark band and louvre."""
    b.box((w, d, h), (x, y, z + h / 2), swatch=sw)
    b.box((w + 0.4, d + 0.4, 0.5), (x, y, z + h + 0.25), swatch="dark")
    b.box((w * 0.6, 0.12, h * 0.4), (x, y - d / 2 - 0.06, z + h * 0.45), swatch="dark_d")


def mast(b, x, y, z, h, guy=True, tip=True):
    b.box((0.8, 0.8, h), (x, y, z + h / 2), swatch="gun_d")
    for k in range(1, 4):
        b.box((2.6 - k * 0.5, 0.25, 0.25), (x, y, z + h * k / 4), swatch="gun_d")
    if tip:
        b.box((1.2, 1.2, 1.2), (x, y, z + h + 0.6), swatch="red")


# ------------------------------------------------------------------ towers
def office(b, lit):
    """A 15-storey office slab: ribbon windows, a two-storey glass lobby, plant on the roof."""
    rng = random.Random(11)
    w, d = 60.0, 40.0
    facade(b, w + 4, d + 4, 0, 20, bay=8, band=2.0, pier=1.2, pier_out=0.8, band_out=0.6,
           core="glass_l", band_sw="concrete_d", pier_sw="dark", lit=lit, rng=rng, lit_rate=0.2)
    facade(b, w, d, 20, 150, bay=6, band=4.2, pier=0.5, pier_out=0.4, band_out=0.9,
           core="glass", band_sw="concrete", pier_sw="concrete_d", lit=lit, rng=rng, lit_rate=0.07)
    top = roof_slab(b, w, d, 150)
    parapet(b, w + 2, d + 2, top)
    plant(b, -12, 4, top, 16, 12, 9)
    plant(b, 10, -6, top, 10, 10, 6, sw="concrete_d")
    tank(b, 20, 10, top)
    mast(b, -12, 4, top + 9.5, 18, tip=False)


def residential(b, lit):
    """An 11-storey apartment block: punched windows between wide piers, balconies on the
    long faces, AC boxes, tanks and a stair hut on the roof."""
    rng = random.Random(23)
    w, d = 50.0, 32.0
    facade(b, w, d, 0, 108, bay=5, band=4.6, pier=2.2, pier_out=0.7, band_out=0.7, storey=9,
           core="glass", band_sw="tan", pier_sw="tan_d", lit=lit, rng=rng, lit_rate=0.09)
    for f in range(1, 12):
        z = f * 9 - 4.4
        for k in range(10):
            if rng.random() < 0.25:  # a balcony slab with a rail
                x = -w / 2 + 2.5 + k * 5
                side = rng.choice((-1, 1))
                b.box((4.2, 1.8, 0.4), (x, side * (d / 2 + 1.6), z), swatch="concrete_d")
                b.box((4.2, 0.2, 1.4), (x, side * (d / 2 + 2.4), z + 0.9), swatch="dark")
            elif rng.random() < 0.15:  # an AC box under the window
                x = -w / 2 + 2.5 + k * 5
                side = rng.choice((-1, 1))
                b.box((1.6, 1.0, 1.0), (x, side * (d / 2 + 1.2), z + 0.4), swatch="white_d")
    top = roof_slab(b, w, d, 108, sw="tan_d")
    parapet(b, w + 2, d + 2, top, sw="tan_d")
    plant(b, 14, 0, top, 8, 8, 7, sw="tan")
    tank(b, -14, 5, top, r=2.6)
    tank(b, -6, -6, top, r=2.6, h=5)
    mast(b, 14, 0, top + 7.5, 10, tip=False)


def deco(b, lit):
    """A stepped pre-war tower: three setbacks, strong piers, a finned crown and a spire.
    The tallest in the city: the red light on the spire is its own lit window."""
    rng = random.Random(37)
    tiers = ((56, 56, 0, 110), (42, 42, 110, 170), (30, 30, 170, 200))
    for w, d, z0, z1 in tiers:
        facade(b, w, d, z0, z1, bay=7, band=2.6, pier=2.0, pier_out=1.0, band_out=0.3,
               core="glass", band_sw="concrete_l", pier_sw="concrete", lit=lit, rng=rng, lit_rate=0.07)
        top = roof_slab(b, w, d, z1, sw="concrete", over=0.6)
        if z1 < 200:
            parapet(b, w, d, top, h=2.2, sw="concrete_l")
    # crown: fins round a lantern, then the spire
    for k in range(8):
        a = k * math.pi / 4
        b.box((1.0, 4.0, 18.0), (math.cos(a) * 11, math.sin(a) * 11, 201 + 9), rot=(0, 0, math.degrees(a) + 90), swatch="concrete_l")
    b.box((16, 16, 16), (0, 0, 201 + 8), swatch="glass")
    b.cyl(6.0, 10.0, (0, 0, 217 + 5), segs=8, r2=2.0, swatch="concrete")
    b.cyl(0.8, 26.0, (0, 0, 227 + 13), segs=6, r2=0.2, swatch="gun_d")
    lit.box((1.4, 1.4, 1.4), (0, 0, 253.5), swatch="red")


def glass_tower(b, lit):
    """A 17-storey curtain-wall tower: dense mullions, thin light-glass spandrels, chamfered
    corners, an open steel crown frame."""
    rng = random.Random(41)
    w = 48.0
    facade(b, w, w, 0, 170, bay=4, band=1.4, pier=0.3, pier_out=0.3, band_out=0.25,
           core="glass", band_sw="glass_l", pier_sw="gun_d", lit=lit, rng=rng, lit_rate=0.05)
    for sx in (-1, 1):  # chamfered corners: a dark pier box on each
        for sy in (-1, 1):
            b.box((2.4, 2.4, 170), (sx * (w / 2), sy * (w / 2), 85), rot=(0, 0, 45), swatch="dark")
    top = roof_slab(b, w, w, 170, sw="dark", over=0.4)
    plant(b, 0, 0, top, 20, 20, 8, sw="dark")
    # crown frame: four posts and two rings of beams
    for sx in (-1, 1):
        for sy in (-1, 1):
            b.box((1.0, 1.0, 16), (sx * 22, sy * 22, top + 8), swatch="gun_d")
    for z in (top + 8, top + 15.5):
        for s in (-1, 1):
            b.box((45, 0.8, 0.8), (0, s * 22, z), swatch="gun_d")
            b.box((0.8, 45, 0.8), (s * 22, 0, z), swatch="gun_d")
    mast(b, 0, 0, top + 8, 22)


def ruined(b, lit):
    """A burned-out office block: whole to the 7th floor, then a skeleton of slabs and
    columns, the top slabs sagging; scorch on the spandrels below the fire line."""
    rng = random.Random(53)
    w, d = 54.0, 36.0
    facade(b, w, d, 0, 70, bay=6, band=4.0, pier=0.6, pier_out=0.4, band_out=0.8,
           core="glass", band_sw="concrete", pier_sw="concrete_d", lit=lit, rng=rng, lit_rate=0.04)
    for k in range(9):  # scorch streaks above the burnt windows
        x = -w / 2 + 3 + k * 6
        if rng.random() < 0.6:
            b.box((4.4, 0.2, 9 + rng.random() * 8), (x, -(d / 2 + 0.95), 62), swatch="dark_d")
    # the skeleton: the stair core, columns, slabs with bites out of them; the sky shows
    # between the floors (a ruin reads by its holes)
    b.box((12, 10, 44), (-6, 2, 92), swatch="concrete_d")
    b.box((12.4, 10.4, 30), (-6, 2, 85), swatch="dark_d")  # scorched lower half of the core
    for k in range(6):  # torn facade remnants hanging off the 70 line
        x = -w / 2 + 4 + k * 9 + rng.uniform(-1.5, 1.5)
        hgt = rng.uniform(4, 13)
        b.box((rng.uniform(3, 6), 0.5, hgt), (x, -(d / 2 + 0.6), 70 + hgt / 2), rot=(0, rng.uniform(-8, 8), 0), swatch="concrete")
    for x in (-24, -12, 0, 12, 24):
        for y in (-15, 0, 15):
            hgt = 40 - (rng.random() * 18 if abs(x) > 6 else 0)
            b.box((1.4, 1.4, hgt), (x, y, 70 + hgt / 2), swatch="concrete_d")
    for f, z in enumerate((80, 90, 100, 110)):
        bite = rng.uniform(4, 18)
        sw = "concrete" if f < 2 else "concrete_d"
        b.box((w - bite, d, 1.2), (-bite / 2, 0, z), swatch=sw)
        b.box((w - bite - 3, 0.6, 1.0), (-bite / 2, -(d / 2 + 0.3), z - 1.0), swatch="concrete_l")
    b.box((22, d - 2, 1.2), (14, 0, 113), rot=(0, -14, 0), swatch="concrete_d")  # the sagging top slab
    mast(b, -20, 8, 111, 14, tip=False)
    b.box((0.6, 0.6, 9), (-18, 8, 129), rot=(0, 40, 0), swatch="gun_d")  # its bent top


def midrise(b, lit):
    """A wide six-storey block (a hotel or offices over shops): tan punched facade, a dark
    shopfront band, a rooftop billboard frame and two tanks."""
    rng = random.Random(67)
    w, d = 90.0, 40.0
    facade(b, w + 2, d + 2, 0, 10, bay=9, band=1.6, pier=1.2, pier_out=0.6, band_out=0.4,
           core="dark", band_sw="dark", pier_sw="dark_l", lit=lit, rng=rng, lit_rate=0.15)
    facade(b, w, d, 10, 62, bay=6, band=4.6, pier=2.0, pier_out=0.6, band_out=0.5,
           core="glass", band_sw="tan_l", pier_sw="tan", lit=lit, rng=rng, lit_rate=0.08)
    top = roof_slab(b, w, d, 62, sw="tan_d")
    parapet(b, w + 2, d + 2, top, sw="tan_d")
    # billboard on a lattice, facing -Y
    for x in (-16, 0, 16):
        b.box((0.8, 0.8, 10), (x, 6, top + 5), swatch="gun_d")
        b.box((0.6, 6, 0.6), (x, 3, top + 4), rot=(35, 0, 0), swatch="gun_d")
    b.box((40, 0.8, 12), (0, 6, top + 16), swatch="white_d")
    b.box((38, 0.3, 10), (0, 5.5, top + 16), swatch="paint_navy")
    b.box((14, 0.2, 3), (-8, 5.3, top + 18), swatch="white_l")
    tank(b, 30, -8, top)
    tank(b, -32, -6, top, r=2.6)
    plant(b, -14, -8, top, 10, 8, 6, sw="tan")


TOWERS = {
    "env_city_office": office,
    "env_city_residential": residential,
    "env_city_deco": deco,
    "env_city_glass": glass_tower,
    "env_city_ruined": ruined,
    "env_city_midrise": midrise,
}


def register(ba):
    """Adds every tower and its `_lit` twin to build_assets' ASSETS table."""
    cache = {}

    def build(name, want_lit):
        def fn(b):
            if want_lit:
                if name not in cache:  # build the tower once into a scratch Builder
                    scratch = ba.Builder()
                    lit = ba.Builder()
                    TOWERS[name](scratch, lit)
                    scratch.bm.free()
                    cache[name] = lit
                b.merge(cache.pop(name))
            else:
                TOWERS[name](b, _NullLit())
        return fn

    for name in TOWERS:
        ba.ASSETS[name] = (build(name, False), "City", "bottom")
        # The lit twin keeps the tower's origin (pivot "origin", no re-seat) so both meshes
        # line up from one placement: SkyService offsets each by its own bounds centre.
        ba.ASSETS[name + "_lit"] = (build(name, True), "City", "origin")


class _NullLit:
    """Swallows lit-window slabs when building the tower itself."""

    def box(self, *a, **k):
        return []
