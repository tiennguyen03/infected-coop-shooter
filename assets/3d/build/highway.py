"""Mile 14 kit: the interstate pieces (docs/LEVELS.md B3 "Mile 14 kit"; level designer 2026-11-09).

A set of related pieces shares one file (owner, 2026-11-08), registered into build_assets.py's
ASSETS table by `register(ba)`, the props.py pattern. Build with:

    blender --background --python assets/3d/build/build_assets.py -- --only env_overpass_span

Everything is built to the 5-stud character, long axis along X, pivot bottom centre. The look
is what makes Mile 14 read as a different place from Delta: concrete parapets, galvanised
guardrail, sodium poles, sign gantries, the toll canopy and a fuel canopy, wrecked convoy
traffic. No hesco, no T-walls, no containers here.
"""

import math

import props

# ------------------------------------------------------------------ the highway itself


def overpass_span(b):
    # The county road over the Jam: 126 long (X), 36 wide (Y), 4.5 deep. The deck top is at 4.5;
    # in game the span's top sits at level 26 (underside 21.5: a 2x Brute walks under it).
    L, W = 126.0, 36.0
    b.box((L, W, 1.5), (0, 0, 3.75), swatch="concrete")  # deck slab
    b.box((L, W - 1.0, 0.06), (0, 0, 4.53), swatch="asphalt")  # wearing course
    for s in (-1, 1):
        b.box((L, 0.8, 1.2), (0, s * (W / 2 - 0.4), 3.4), swatch="concrete_l")  # chamfered fascia
        b.box((L, 0.3, 0.3), (0, s * (W / 2 - 0.1), 2.65), swatch="concrete_d")  # drip edge
    for y in (-14.0, -7.0, 0.0, 7.0, 14.0):  # five girders under the deck
        b.box((L - 2.0, 1.0, 2.6), (0, y, 1.7), swatch="concrete_d")
        b.box((L - 2.0, 1.8, 0.4), (0, y, 0.2), swatch="concrete_d")  # bottom flange
    for x in (-50.0, 0.0, 50.0):  # bearing pads where the bents carry it
        b.box((4.0, W - 2.0, 0.3), (x, 0, 0.0 + 0.15), swatch="dark")
    for x in (-L / 2 + 1.0, -30.0, 30.0, L / 2 - 1.0):  # expansion joints
        b.box((0.3, W - 1.0, 0.06), (x, 0, 4.59), swatch="gun_d")
    for i in range(-6, 7):  # lane dashes on the county road
        b.box((4.0, 0.3, 0.04), (i * 9.0, 0, 4.6), swatch="white_d")
    # the edge parapets are env_parapet_12 instances placed on the deck (shared mesh)


SPAN_DEPTH = 4.5  # env_overpass_span: bottom of the bearing pads to the deck top
SPAN_TOP = 26.0  # the deck top in game (level 26)
JAM_TOP = 12.0  # the Jam deck


def bridge_bent(b, h=SPAN_TOP - SPAN_DEPTH):
    # Two octagonal columns under a cap beam, 34 across (Y): carries the span over the Jam.
    # Full height stands on the ground (0); the low one on the Jam deck. The cap top meets the
    # span's bearing pads exactly.
    for y in (-12.0, 12.0):
        b.box((3.0, 3.0, 0.8), (0, y, 0.4), swatch="concrete_d")  # footing
        b.cyl(1.3, h - 2.6, (0, y, 0.8 + (h - 2.6) / 2), segs=8, swatch="concrete")
        b.box((2.8, 2.8, 0.2), (0, y, h * 0.35), swatch="concrete_l")  # pour line
    b.box((5.0, 34.0, 2.0), (0, 0, h - 1.0), swatch="concrete")  # cap beam
    b.box((5.2, 34.2, 0.3), (0, 0, h - 2.0), swatch="concrete_d")  # its soffit
    b.box((5.0, 0.2, 1.2), (0, -12.0, h * 0.6), swatch="rust_d")  # rust bleed down one column
    b.box((5.0, 0.2, 2.5), (0, 12.0, h * 0.45), swatch="rust_d")


def bridge_bent_low(b):
    bridge_bent(b, h=SPAN_TOP - SPAN_DEPTH - JAM_TOP)


def guardrail(b, origin=(0, 0, 0)):
    # Galvanised W-beam guardrail, 12 long, 2.4 tall, on three posts. VAULT.
    ox, oy, oz = origin
    for x in (-5.5, 0.0, 5.5):
        b.box((0.4, 0.6, 2.4), (ox + x, oy + 0.15, oz + 1.2), swatch="gun_d")  # posts
        b.box((0.5, 0.3, 0.9), (ox + x, oy - 0.2, oz + 1.85), swatch="gun")  # blockouts
    b.box((12.0, 0.25, 0.4), (ox, oy - 0.45, oz + 2.1), swatch="gun_l")  # the W-beam: two ridges
    b.box((12.0, 0.25, 0.4), (ox, oy - 0.45, oz + 1.6), swatch="gun_l")
    b.box((12.0, 0.2, 0.15), (ox, oy - 0.4, oz + 1.85), swatch="gun")  # the valley between them
    b.box((0.6, 0.06, 0.2), (ox + 2.0, oy - 0.6, oz + 2.1), swatch="warning_orange")  # reflector


def guardrail_12(b):
    guardrail(b)


def parapet(b, origin=(0, 0, 0)):
    # Concrete jersey parapet, 12 long, 2.75 tall (the median and the span edges). VAULT.
    ox, oy, oz = origin
    b.box((12.0, 2.0, 0.5), (ox, oy, oz + 0.25), swatch="concrete")
    b.box((12.0, 1.3, 0.8), (ox, oy, oz + 0.9), swatch="concrete")
    b.box((12.0, 0.7, 1.45), (ox, oy, oz + 2.02), swatch="concrete")
    b.box((0.1, 0.72, 1.4), (ox + 5.95, oy, oz + 2.02), swatch="concrete_d")  # joint line
    b.box((3.0, 0.74, 0.16), (ox - 3.0, oy, oz + 1.4), swatch="rust_d")  # scrape at bumper height


def parapet_12(b):
    parapet(b)


def sign_gantry(b):
    # Overhead sign gantry spanning the Jam: legs at x +-27 on footings, a box truss at 18..22,
    # a catwalk on the sign side (-Y), two brackets for the sign panels (Parts with a SurfaceGui
    # in game, text per band; see the map).
    for x in (-27.0, 27.0):
        b.box((3.0, 3.0, 0.8), (x, 0, 0.4), swatch="concrete")
        for dy in (-0.6, 0.6):
            b.box((0.5, 0.5, 21.2), (x, dy, 11.4), swatch="gun")  # the two leg posts
        for z in range(3, 21, 3):
            b.box((0.3, 1.5, 0.3), (x, 0, z), rot=(35 if z % 6 else -35, 0, 0), swatch="gun_d")  # lacing
    for z in (18.2, 21.8):
        for dy in (-0.7, 0.7):
            b.box((58.0, 0.4, 0.4), (0, dy, z), swatch="gun")  # chords
    for i in range(-14, 15):
        x = i * 2.0
        b.box((0.2, 0.2, 3.6), (x, -0.7, 20.0), rot=(0, 30 if i % 2 else -30, 0), swatch="gun_d")  # truss web
        b.box((0.2, 0.2, 3.6), (x, 0.7, 20.0), rot=(0, 30 if i % 2 else -30, 0), swatch="gun_d")
    b.box((44.0, 1.6, 0.15), (0, -1.6, 17.0), swatch="gun_d")  # catwalk
    b.box((44.0, 0.1, 1.2), (0, -2.4, 17.6), swatch="gun_l")  # its rail
    for x in (-13.0, 13.0):
        b.box((0.4, 1.2, 10.4), (x, -1.0, 22.0), swatch="gun")  # panel brackets


def water_tower(b):
    # The landmark: four splayed legs, X-bracing, riser, a 16-wide 12-sided tank at 32..46, cone
    # roof, balcony ring, a ladder mesh (not climbable in game). Red beacon is a Neon Part on top.
    top, foot = 32.0, 8.0
    for sx in (-1, 1):
        for sy in (-1, 1):
            a = (sx * foot, sy * foot, 0)
            t = (sx * 5.0, sy * 5.0, top)
            mid = ((a[0] + t[0]) / 2, (a[1] + t[1]) / 2, top / 2)
            tilt_y = math.degrees(math.atan2(t[0] - a[0], top))  # +Z leans toward the tank
            tilt_x = -math.degrees(math.atan2(t[1] - a[1], top))
            b.box((1.0, 1.0, top + 0.6), mid, rot=(tilt_x, tilt_y, 0), swatch="gun")
            b.box((2.0, 2.0, 1.0), (a[0], a[1], 0.5), swatch="concrete")  # foot pier
    for z in (10.0, 21.0):  # horizontal ring braces
        r = foot - (foot - 5.0) * z / top
        for s in (-1, 1):
            b.box((2 * r, 0.3, 0.3), (0, s * r, z), swatch="gun_d")
            b.box((0.3, 2 * r, 0.3), (s * r, 0, z), swatch="gun_d")
    for s in (-1, 1):  # X-bracing on two faces
        for ang in (40, -40):
            b.box((0.2, 0.2, 14.0), (0, s * 7.2, 5.0 + 10.0), rot=(0, ang, 0), swatch="gun_d")
            b.box((0.2, 0.2, 14.0), (s * 7.2, 0, 5.0 + 10.0), rot=(ang, 0, 0), swatch="gun_d")
    b.cyl(1.0, top, (0, 0, top / 2), segs=8, swatch="gun_d")  # riser
    b.cyl(8.0, 12.0, (0, 0, top + 1.0 + 6.0), segs=12, swatch="white_d")  # tank
    b.cyl(8.05, 1.2, (0, 0, top + 9.0), segs=12, swatch="rust")  # rust band where it weeps
    b.cyl(8.2, 0.4, (0, 0, top + 1.0), segs=12, swatch="gun_d")  # balcony floor
    b.cyl(8.25, 0.15, (0, 0, top + 2.2), segs=12, swatch="gun_l")  # balcony rail
    b.cyl(8.0, 3.0, (0, 0, top + 13.0 + 1.5), segs=12, r2=0.8, swatch="white")  # cone roof
    b.cyl(0.4, 1.4, (0, 0, top + 16.7), segs=6, swatch="gun_d")  # beacon mast
    for i in range(12):  # tank panel seams
        a = i * math.pi / 6 + math.pi / 12
        b.box((0.1, 0.1, 12.0), (math.cos(a) * 8.0, math.sin(a) * 8.0, top + 7.0), swatch="white")
    for z in range(1, int(top), 2):  # the ladder up one leg face
        b.box((1.4, 0.15, 0.15), (0, -6.8 + z * 0.02, z), swatch="gun_l")
    for dx in (-0.7, 0.7):
        b.box((0.15, 0.15, top), (dx, -6.6, top / 2), swatch="gun_l")
    b.box((10.0, 0.2, 3.0), (0, -8.12, top + 8.0), swatch="dark_d")  # the town name, painted out
    b.box((6.0, 0.22, 1.2), (0, -8.14, top + 8.0), swatch="red_d")  # sprayed over: the quarantine mark


def highway_light(b):
    # Sodium highway light for the median: a tapered 8-sided pole on a base plate, two arms out
    # over both carriageways, cobra heads. The lit lens is a Neon Part per head in game.
    b.box((1.6, 1.6, 0.4), (0, 0, 0.2), swatch="gun_d")
    b.cyl(0.45, 26.0, (0, 0, 13.4), segs=8, r2=0.25, swatch="gun")
    for s in (-1, 1):
        b.box((7.0, 0.3, 0.3), (s * 3.6, 0, 26.6), rot=(0, s * -8, 0), swatch="gun")  # arm
        b.box((2.2, 0.9, 0.5), (s * 7.3, 0, 27.0), swatch="gun_l")  # cobra head
        b.box((1.7, 0.7, 0.08), (s * 7.4, 0, 26.72), swatch="tan_l")  # dead sodium lens


# ------------------------------------------------------------------ the toll plaza


def toll_booth(b):
    # Curb island 20 x 4.5 (0.6 up) with a 6 x 4 booth, yellow bollards at the nose. CLIMB.
    b.box((20.0, 4.5, 0.6), (0, 0, 0.3), swatch="concrete_l")
    b.box((1.0, 4.5, 0.62), (-9.5, 0, 0.31), swatch="objective_yellow")  # painted nose
    for x in (-8.5, -6.5):
        b.cyl(0.35, 3.0, (x, 0, 2.1), segs=8, swatch="objective_yellow")  # bollards
    b.box((6.0, 4.0, 6.0), (2.0, 0, 3.6), swatch="white_d")  # booth
    b.box((6.4, 4.4, 0.4), (2.0, 0, 6.8), swatch="gun")  # roof
    b.box((5.0, 4.1, 2.0), (2.0, 0, 4.6), swatch="glass")  # window band
    b.box((4.6, 4.12, 0.3), (2.0, 0, 5.2), swatch="glass_l")  # sky glint
    b.box((0.1, 4.14, 2.0), (2.0, 0, 4.6), swatch="white")  # window post
    b.box((1.6, 0.14, 4.6), (4.0, 2.05, 3.0), swatch="gun_d")  # door
    b.box((2.4, 0.5, 0.2), (-1.3, -2.1, 3.0), swatch="gun_l")  # pay window ledge
    b.box((1.2, 0.3, 1.0), (2.0, -2.2, 7.6), swatch="red_d")  # lane signal: red X
    b.box((3.0, 0.2, 1.6), (8.0, 0, 1.4), swatch="dark")  # ticket machine


def toll_canopy(b):
    # The plaza canopy: a 24 x 66 roof at 16..18 over 8 columns standing on the islands, a lit
    # fascia band (the plaza name) and a lane signal box over each lane. Not reachable.
    b.box((24.0, 66.0, 2.0), (0, 0, 17.0), swatch="white_d")  # roof deck
    for s in (-1, 1):
        b.box((24.4, 0.4, 1.4), (0, s * 33.1, 17.0), swatch="dark")  # end fascia
        b.box((0.4, 66.4, 1.4), (s * 12.1, 0, 17.0), swatch="friendly_blue")  # lit band (lane side)
        b.box((0.42, 30.0, 0.6), (s * 12.12, 0, 17.0), swatch="white_l")  # its lettering block
    b.box((23.6, 65.6, 0.1), (0, 0, 15.95), swatch="white")  # soffit
    for y in (-24.0, -8.0, 8.0, 24.0):
        for x in (-8.0, 8.0):
            b.box((1.4, 1.4, 16.0), (x, y, 8.0), swatch="gun")  # columns on the islands
        b.box((0.8, 3.0, 0.4), (-8.0, y, 15.6), swatch="gun_d")
    for y in (-16.0, 0.0, 16.0, -32.0 + 2.0, 30.0):
        b.box((1.0, 1.4, 1.2), (-11.0, y, 15.2), swatch="dark")  # lane signal boxes
        b.box((0.1, 0.8, 0.6), (-11.52, y, 15.2), swatch="red")  # red X, every lane closed


# ------------------------------------------------------------------ the rest stop


def fuel_canopy(b):
    # Fuel station canopy, 30 x 20 roof at 12.4..14 on four columns, a branded fascia. Not
    # reachable (unlike Delta's walkable Pumps canopy).
    b.box((30.0, 20.0, 1.6), (0, 0, 13.2), swatch="white")
    for s in (-1, 1):
        b.box((30.4, 0.3, 1.8), (0, s * 10.15, 13.2), swatch="red")  # fascia
        b.box((0.3, 20.4, 1.8), (s * 15.15, 0, 13.2), swatch="red")
        b.box((30.5, 0.32, 0.3), (0, s * 10.17, 12.45), swatch="white_l")  # stripe
    b.box((8.0, 0.34, 1.2), (0, -10.2, 13.3), swatch="white_l")  # brand panel
    b.box((29.4, 19.4, 0.1), (0, 0, 12.35), swatch="white_d")  # soffit
    for sx in (-7.0, 7.0):
        for sy in (-7.5, 7.5):
            b.box((1.2, 1.2, 12.4), (sx, sy, 6.2), swatch="white_d")
            b.box((1.4, 1.4, 1.0), (sx, sy, 0.5), swatch="objective_yellow")  # bumper guard
    for sx in (-7.0, 7.0):
        for y in (-3.0, 3.0):
            b.box((2.6, 1.2, 0.15), (sx, y, 12.2), swatch="white_l")  # dead floodlights


def fuel_pump(b):
    # Fuel dispenser 3 x 2 x 6 with a hose and a dead screen. Burns when hit (game rule).
    b.box((3.0, 2.0, 0.4), (0, 0, 0.2), swatch="concrete_d")
    b.box((2.6, 1.6, 4.4), (0, 0, 2.6), swatch="white_d")
    b.box((2.7, 1.7, 1.1), (0, 0, 5.35), swatch="red")  # header
    b.box((1.2, 0.08, 0.8), (0, -0.84, 3.9), swatch="dark_d")  # screen
    b.box((0.6, 0.08, 0.4), (0, -0.84, 3.0), swatch="gun_l")  # keypad
    b.box((0.4, 0.5, 1.4), (1.4, -0.3, 2.8), swatch="dark")  # nozzle holster
    b.box((0.2, 0.2, 2.6), (1.55, -0.6, 1.6), swatch="dark_d")  # hose
    b.box((0.24, 0.1, 1.2), (-0.8, -0.84, 2.0), swatch="objective_yellow")  # grade stickers
    b.box((0.24, 0.1, 1.2), (0.0, -0.84, 2.0), swatch="red_l")


def diner_sign(b):
    # Roadside sign: two legs and a sign box at 23..30 ("DINER" and an arrow; Neon on a lit twin).
    for x in (-5.0, 5.0):
        b.box((1.0, 1.0, 23.0), (x, 0, 11.5), swatch="gun_d")
        b.box((2.0, 2.0, 0.8), (x, 0, 0.4), swatch="concrete")
    b.box((14.0, 1.6, 7.0), (0, 0, 26.5), swatch="white_d")
    b.box((14.2, 1.7, 0.4), (0, 0, 30.1), swatch="red_d")
    b.box((14.2, 1.7, 0.4), (0, 0, 22.9), swatch="red_d")
    for s in (-1, 1):
        b.box((10.0, 0.1, 2.4), (0, s * 0.85, 27.4), swatch="red")  # DINER letters band
        b.box((6.0, 0.1, 1.0), (-1.0, s * 0.85, 24.8), swatch="brass")  # the arrow
        b.wedge((1.6, 0.1, 1.6), (2.8, s * 0.85, 24.8), rot=(0, 0, 0), swatch="brass")


# ------------------------------------------------------------------ convoy traffic


def semi_cab(b):
    # Tractor unit, 18 x 8.5 x 11 (nose toward -X): bumper, long hood, cab, sleeper, stacks,
    # tanks. Three-step composite in game (a Walker staircase: 3 / 6.5 / 11).
    b.box((2.0, 8.5, 1.6), (-8.0, 0, 1.6), swatch="gun_l")  # bumper
    b.box((6.0, 7.0, 3.6), (-5.0, 0, 4.4), swatch="paint_navy")  # hood
    b.box((0.2, 5.0, 2.6), (-8.05, 0, 4.4), swatch="gun_l")  # grille
    b.box((6.0, 8.4, 6.5), (1.0, 0, 6.85), swatch="paint_navy")  # cab
    b.box((0.2, 7.4, 2.6), (-2.05, 0, 8.4), swatch="glass")  # windscreen
    b.box((0.22, 7.0, 0.6), (-2.06, 0, 9.3), swatch="glass_l")
    b.box((3.6, 8.4, 7.5), (5.6, 0, 7.35), swatch="paint_navy")  # sleeper
    b.box((3.0, 8.0, 1.2), (5.6, 0, 11.4), swatch="white_d")  # roof fairing
    for s in (-1, 1):
        b.cyl(0.4, 4.0, (3.5, s * 4.4, 9.4), segs=6, swatch="gun_l")  # exhaust stacks
        b.cyl(1.0, 3.0, (1.0, s * 4.0, 2.6), segs=8, rot=(0, 90, 0), swatch="gun_l")  # fuel tanks
        b.box((0.3, 0.6, 1.4), (-2.6, s * 4.6, 8.2), swatch="dark")  # mirrors
        b.box((1.8, 0.1, 3.0), (-0.2, s * 4.22, 6.5), swatch="dark_d")  # door window
        for x in (-6.0, 4.0, 7.0):
            b.cyl(1.6, 1.0, (x, s * 3.6, 1.6), segs=10, rot=(90, 0, 0), swatch="dark_d")
            b.cyl(0.7, 1.05, (x, s * 3.6, 1.6), segs=8, rot=(90, 0, 0), swatch="gun")
    b.box((6.0, 7.0, 0.6), (6.0, 0, 3.4), swatch="gun_d")  # fifth wheel deck
    b.box((3.0, 0.12, 1.4), (-5.0, -3.56, 4.6), swatch="rust")  # scrape


def box_trailer(b):
    # 42-long van trailer (white body, a faded red stripe, side skirts, tandem axles, landing
    # legs). WALL / HIDE. Kingpin end toward -X.
    L, W, H0, H = 42.0, 8.5, 4.2, 13.5
    b.box((L, W, H - H0), (0, 0, (H + H0) / 2), swatch="white_d")
    b.box((L - 0.4, W - 0.4, 0.3), (0, 0, H + 0.1), swatch="white")
    for s in (-1, 1):
        b.box((L - 2.0, 0.1, 1.2), (0, s * (W / 2 + 0.05), H0 + 2.5), swatch="red_d")  # stripe
        b.box((22.0, 0.1, 2.4), (-2.0, s * (W / 2 - 0.2), 3.0), swatch="gun_d")  # skirt
        for x in (L / 2 - 6.0, L / 2 - 9.4):
            b.cyl(1.6, 1.0, (x, s * 3.4, 1.6), segs=10, rot=(90, 0, 0), swatch="dark_d")
        b.box((0.4, 0.4, 3.8), (-L / 2 + 8.0, s * 3.0, 2.3), swatch="gun")  # landing legs
    b.box((L, W - 1.0, 0.6), (0, 0, H0 - 0.3), swatch="gun_d")  # frame
    b.box((0.2, W, H - H0), (L / 2 + 0.1, 0, (H + H0) / 2), swatch="white")  # rear doors
    b.box((0.25, 0.2, H - H0), (L / 2 + 0.15, 0, (H + H0) / 2), swatch="gun_l")
    for i in range(10):
        b.box((0.12, W + 0.04, H - H0), (-L / 2 + 2.0 + i * 4.2, 0, (H + H0) / 2), swatch="white")  # panel ribs
    b.box((9.0, 0.12, 4.0), (6.0, -W / 2 - 0.08, 9.0), swatch="rust")  # rust run


BURNT = {
    "white_d": "dark_l", "white": "dark", "gun": "dark_d", "gun_d": "dark_d", "gun_l": "dark",
    "brass": "dark_d", "rust": "rust_d",
}


def bus_burnt(b):
    # A burnt-out env_bus: the same builder through a charred palette (empty window band, no lit
    # destination sign), with soot runs above the windows and a buckled roof patch.
    orig = b._paint
    b._paint = lambda verts, swatch: orig(verts, BURNT.get(swatch, swatch))
    props.bus(b)
    b._paint = orig
    for s in (-1, 1):
        for x in (-12.0, 2.0, 14.0):
            b.box((5.0, 0.14, 1.6), (x, s * 5.2, 11.5), swatch="dark_d")  # soot over the windows
        b.box((10.0, 0.14, 1.2), (-4.0, s * 5.18, 4.6), swatch="rust")  # paint burnt to the metal
    b.box((8.0, 5.0, 0.3), (-6.0, 0, 12.3), rot=(4, 0, 0), swatch="rust_d")  # sagging roof


# ------------------------------------------------------------------ small dressing


def mile_marker(b):
    # Green "14" mile marker on a post (white_l digits on a dark plate stand in for the green).
    b.box((0.25, 0.25, 4.5), (0, 0.1, 2.25), swatch="gun")
    b.box((1.4, 0.12, 1.8), (0, -0.08, 3.5), swatch="olive_d")
    b.box((0.3, 0.14, 0.9), (-0.3, -0.1, 3.4), swatch="white_l")
    b.box((0.5, 0.14, 0.9), (0.25, -0.1, 3.4), swatch="white_l")


def traffic_cone(b):
    b.box((1.4, 1.4, 0.2), (0, 0, 0.1), swatch="dark")
    b.cyl(0.6, 1.8, (0, 0, 1.1), segs=8, r2=0.12, swatch="warning_orange")
    b.cyl(0.42, 0.3, (0, 0, 1.15), segs=8, swatch="white_l")  # reflective band


HIGHWAY_PIECES = {
    "env_overpass_span": overpass_span,
    "env_bridge_bent": bridge_bent,
    "env_bridge_bent_low": bridge_bent_low,
    "env_guardrail_12": guardrail_12,
    "env_parapet_12": parapet_12,
    "env_sign_gantry": sign_gantry,
    "env_water_tower": water_tower,
    "env_highway_light": highway_light,
    "env_toll_booth": toll_booth,
    "env_toll_canopy": toll_canopy,
    "env_fuel_canopy": fuel_canopy,
    "prop_fuel_pump": fuel_pump,
    "env_diner_sign": diner_sign,
    "env_semi_cab": semi_cab,
    "env_box_trailer": box_trailer,
    "env_bus_burnt": bus_burnt,
    "prop_mile_marker": mile_marker,
    "prop_traffic_cone": traffic_cone,
}


def register(ba):
    """Adds every Mile 14 kit piece to build_assets' ASSETS table."""
    for name, fn in HIGHWAY_PIECES.items():
        ba.ASSETS[name] = (fn, "Props" if name.startswith("prop_") else "Environment", "bottom")
