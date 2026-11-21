"""Mile 14 v2 in Blender: a proposal for the owner to compare with mile14_map.py (v1).

Owner, 2026-11-11: "make it bigger and better detailed, not hyperdetailed but looks good for a
Roblox game, and add a background, something like the skyscrapers we had". Nothing here is
loaded by the game. Same shape as v1: Python tables in the Luau shape (`HILLS`, `PARTS`,
`DRESSING`), Roblox coordinates (x, y, z), +Z north, yaw in degrees about up; ground, slopes
and axis mapping from delta_map; kit meshes straight from build_assets' builders, every
placement a linked instance. See docs/sprints/SPRINT_20_MILE14.md > "Mile 14 v2".

Frame: 640 x 900 (v1: 600 x 600). The interstate deck is 110 x 900 at level 12 (v1: 60 x 600):
two 3-lane carriageways, shoulders and a 20-wide grass median. South to north:
the lead bus and the south barricade, the Rest Stop (west, ground) and the Weigh Station (east,
ground) each with an exit and an entry ramp, the Culvert, the tanker jackknife, the Overpass
with four interchange ramps, the HARLAN 14 gantries, the Toll Plaza across both carriageways
with the main pad beside it, the north barricade, and Harlan's skyline beyond.

Live Blender (the owner's way: look at it):

    exec(open(r"assets/3d/build/mile14_v2.py").read()); build()

Headless (writes assets/3d/mile14_v2.blend and the previews):

    blender --background --python assets/3d/build/mile14_v2.py
"""

import math
import os
import random
import sys

import bpy

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import build_assets as ba  # noqa: E402
import delta_map as dm  # noqa: E402

BLEND = os.path.join(dm.ROOT, "assets", "3d", "mile14_v2.blend")
PREVIEWS = os.path.join(dm.ROOT, "assets", "3d", "build", "previews")

DECK = 12.0  # the interstate deck ("the Jam")
SPAN = 26.0  # the county road and the Overpass span
OVER_Z = 80.0  # the Overpass centre line
TOLL_Z = 310.0  # the booth row
X_HALF, Z_HALF = 320.0, 450.0  # the play frame: 640 x 900
DECK_HALF = 55.0  # deck half width: median 10, three 12-stud lanes, a 9-stud shoulder
LANES = (16.0, 28.0, 40.0)  # lane centres either side of the median
EYE = 5.0  # camera height above the floor for the eye-height previews

# The places the mission needs (sprint doc): zone centre (x, y, z) and size, for the overview.
SITES = {
    "Overpass span": ((0, SPAN, OVER_Z), (28, 28)),
    "Toll Plaza": ((0, DECK, TOLL_Z - 50), (46, 46)),
    "Rest Stop": ((-190, 0, -255), (46, 46)),
}
PADS = {"Main pad (insert, extract)": (130, DECK, TOLL_Z), "Alt pad": (-262, 0, -195)}
LEAD_BUS = (-16, DECK, -418)  # Open the Route; the Driver's entry
# Names printed on the overview (x, z): the other places a squad will call out.
LABELS = {
    "Weigh Station": (150, -112), "Jackknife": (118, -14), "Culvert": (106, -74), "The Halt": (-200, 312),
    "Lead bus": (-112, -424), "The Drop": (-150, -44), "Water tower": (225, -410), "Interchange ramps": (150, 148),
    "South barricade": (120, -440), "North barricade": (-128, 420), "HARLAN (skyline) ^": (190, 470),
}

# ------------------------------------------------------------------ earthworks
NS = {"north": True, "south": True}
EW = {"east": True, "west": True}
HILLS = [
    {"name": "JamS", "x": 0, "z": -263, "top": (110, 374), "height": DECK, "open": NS},  # z -450..-76
    {"name": "JamN", "x": 0, "z": 83, "top": (110, 294), "height": DECK, "open": NS},  # z -64..230
    {"name": "TollApron", "x": 0, "z": TOLL_Z, "top": (170, 160), "height": DECK},
    {"name": "AdminLot", "x": 125, "z": TOLL_Z, "top": (80, 100), "height": DECK, "open": {"west": True}},
    {"name": "JamNN", "x": 0, "z": 420, "top": (110, 60), "height": DECK, "open": NS},
    {"name": "BeyondN", "x": 0, "z": 750, "top": (110, 600), "height": DECK, "open": NS},  # backdrop
    {"name": "BeyondS", "x": 0, "z": -650, "top": (110, 400), "height": DECK, "open": NS},  # backdrop
    {"name": "OverpassW", "x": -241.5, "z": OVER_Z, "top": (357, 36), "height": SPAN, "open": EW},
    {"name": "OverpassE", "x": 241.5, "z": OVER_Z, "top": (357, 36), "height": SPAN, "open": EW},
    {"name": "TowerKnoll", "x": 225, "z": -370, "top": (50, 50), "height": 8.0},
]

# Plain Parts: (name, kind, centre (x, y, z), size (x, y, z), yaw). kind = KINDS key; "wedge"
# in the name builds a WedgePart (rises toward its +Z face).
PARTS = [
    ("CulvertRoof", "concrete", (0, 9.5, -70), (110, 5, 12), 0),  # 7 clear under it, 110 long
    ("JamRoad", "road", (0, DECK + 0.05, 0), (108, 0.1, 900), 0),
    ("BeyondRoadN", "road", (0, DECK + 0.05, 750), (108, 0.1, 600), 0),
    ("BeyondRoadS", "road", (0, DECK + 0.05, -650), (108, 0.1, 400), 0),
    ("MedianS", "grass", (0, DECK + 0.12, -111), (19, 0.14, 678), 0),
    ("MedianN", "grass", (0, DECK + 0.12, 420), (19, 0.14, 58), 0),
    ("CountyRoadW", "road", (-241.5, SPAN + 0.05, OVER_Z), (357, 0.1, 30), 0),
    ("CountyRoadE", "road", (241.5, SPAN + 0.05, OVER_Z), (357, 0.1, 30), 0),
    # Toll Plaza and the admin lot beside it (the main pad)
    ("TollPaving", "concrete", (0, DECK + 0.1, TOLL_Z), (168, 0.2, 158), 0),
    ("AdminPaving", "road", (125, DECK + 0.1, TOLL_Z), (78, 0.2, 98), 0),
    ("MainPad", "pad", (130, DECK + 0.3, TOLL_Z), (26, 0.3, 26), 0),
    ("TollOffice", "building", (142, DECK + 6, TOLL_Z + 40), (36, 12, 14), 0),
    ("TollOfficeRoof", "steel", (142, DECK + 12.3, TOLL_Z + 40), (37.6, 0.6, 15.6), 0),
    ("TollOfficeWindows", "glass", (136, DECK + 7.0, TOLL_Z + 32.9), (22, 3.2, 0.2), 0),
    ("TollOfficeDoor", "steel", (154, DECK + 3.6, TOLL_Z + 32.9), (4, 7.2, 0.2), 0),
    ("TollOfficePlant", "steel", (150, DECK + 13.8, TOLL_Z + 42), (8, 2.4, 5), 0),
    # Rest Stop (west, ground level)
    ("RestLot", "concrete", (-172.5, 0.05, -252.5), (235, 0.1, 165), 0),
    ("RestExit_wedge", "road", (-63, DECK / 2, -195), (16, DECK, 70), 0),
    ("RestExitLanding", "road", (-63, DECK / 2, -150), (16, DECK, 20), 0),
    ("RestEntry_wedge", "road", (-63, DECK / 2, -365), (16, DECK, 70), 180),
    ("RestEntryLanding", "road", (-63, DECK / 2, -410), (16, DECK, 20), 0),
    ("Diner", "building", (-240, 5.0, -312), (48, 10, 22), 0),
    ("DinerRoofTrim", "red", (-240, 10.3, -312), (49.6, 0.6, 23.6), 0),
    ("DinerWindows", "glass", (-240, 5.4, -300.9), (38, 3.4, 0.2), 0),
    ("DinerAwning", "red", (-240, 8.4, -298), (40, 0.4, 6), 0),
    ("IslandW", "concrete", (-157, 0.35, -225), (4, 0.6, 18), 0),
    ("IslandE", "concrete", (-143, 0.35, -225), (4, 0.6, 18), 0),
    ("AltPad", "pad", (-262, 0.25, -195), (26, 0.3, 26), 0),
    ("TruckBays", "road", (-272, 0.12, -265), (30, 0.1, 70), 0),
    ("RestDriveE", "road", (-80, 0.12, -280), (30, 0.1, 110), 0),  # ramp foot to ramp foot
    ("RestDriveFuel", "road", (-150, 0.12, -225), (110, 0.1, 36), 0),
    # Weigh Station (east, ground level)
    ("WeighLot", "concrete", (150, 0.05, -185), (190, 0.1, 120), 0),
    ("WeighExit_wedge", "road", (63, DECK / 2, -275), (16, DECK, 70), 180),
    ("WeighExitLanding", "road", (63, DECK / 2, -320), (16, DECK, 20), 0),
    ("WeighEntry_wedge", "road", (63, DECK / 2, -112.5), (16, DECK, 45), 0),
    ("WeighEntryLanding", "road", (63, DECK / 2, -83), (16, DECK, 14), 0),
    ("ScalePlate", "steel", (120, 0.2, -205), (70, 0.2, 12), 0),
    ("ScaleLane", "road", (150, 0.12, -205), (188, 0.1, 18), 0),
    # the Halt (north-west): trodden ground under the tents
    ("HaltGround", "patch", (-200, 0.05, 250), (130, 0.1, 90), 0),
]
for _name, (_x, _y, _z) in (("Main", (130, DECK + 0.45, TOLL_Z)), ("Alt", (-262, 0.4, -195))):  # the painted H
    PARTS += [
        ("%sPadH1" % _name, "line", (_x - 4, _y + 0.02, _z), (1.5, 0.06, 12), 0),
        ("%sPadH2" % _name, "line", (_x + 4, _y + 0.02, _z), (1.5, 0.06, 12), 0),
        ("%sPadH3" % _name, "line", (_x, _y + 0.02, _z), (6.5, 0.06, 1.5), 0),
    ]
for _sx in (-1, 1):  # solid edge lines of both carriageways
    for _x in (10.6, 46.0):
        PARTS.append(("EdgeLine", "line", (_sx * _x, DECK + 0.13, -111), (0.5, 0.06, 678), 0))
for _sx, _ew in ((-1, "W"), (1, "E")):  # the interchange: four ramps from the county road to the deck
    for _sz, _ns in ((-1, "S"), (1, "N")):
        _z = OVER_Z + _sz * 50
        PARTS += [
            ("Ramp%s%s_wedge" % (_ns, _ew), "road", (_sx * 71, (DECK + SPAN) / 2, _z), (14, SPAN - DECK, 64), 180 if _sz > 0 else 0),
            ("Ramp%s%sFill" % (_ns, _ew), "slope", (_sx * 71, DECK / 2 - 0.05, _z), (14, DECK - 0.1, 64), 0),
            ("Ramp%s%sLanding" % (_ns, _ew), "road", (_sx * 66.5, DECK / 2, OVER_Z + _sz * 89), (23, DECK, 14), 0),
        ]

# Sign panels on the gantries (Parts with a SurfaceGui in game): (name, x, y, z).
SIGNS = [
    ("SignHarlan14", 27.5, DECK + 22, 198.4),
    ("SignTollAhead", -27.5, DECK + 22, 201.6),
    ("SignRestArea", -27.5, DECK + 22, -118.4),
    ("SignWeighStation", 27.5, DECK + 22, -331.6),
]

SOUTH = -90  # every vehicle left Harlan heading south: nose toward -Z


def _jam_vehicles():
    out = []
    # The convoy: 20 buses in the inner lanes, 6 burnt. With two at the booths, one in the Rest
    # Stop and the Drop's that is Control's 24; nothing past the frame is a bus.
    west = (-418, -366, -312, -262, -212, -160, -110, 34, 92, 142)
    east = (-410, -356, -300, -246, -190, -132, 30, 84, 136, 186)
    burnt = {(-1, -312), (-1, -110), (-1, 142), (1, -410), (1, -190), (1, 84)}
    for s, lane in ((-1, west), (1, east)):
        for z in lane:
            out.append({"name": "env_bus_burnt" if (s, z) in burnt else "env_bus", "x": s * LANES[0], "z": z, "yaw": SOUTH})
    # Civilian traffic caught in the other lanes: seeded, so the build is the same every time.
    rng = random.Random(14)
    cars = ["prop_car_sedan"] * 3 + ["prop_car_hatch"] * 3 + ["prop_car_pickup"] * 2 + ["prop_car_van"] * 2
    for s in (-1, 1):
        for lane, skip in ((LANES[1], 0.25), (LANES[2], 0.45)):
            z = -436.0 + rng.uniform(0, 14)
            while z < 224:
                step = rng.uniform(21, 40)
                clear = -52 < z < 16 or OVER_Z - 22 < z < OVER_Z + 22  # the jackknife; under the span
                if not clear and rng.random() > skip:
                    name = "prop_cargo_truck" if lane == LANES[1] and rng.random() < 0.14 else rng.choice(cars)
                    skew = rng.uniform(18, 40) * rng.choice((-1, 1)) if rng.random() < 0.18 else rng.uniform(-5, 5)
                    out.append({"name": name, "x": s * lane + rng.uniform(-1.2, 1.2), "z": round(z, 1), "yaw": SOUTH + round(skew)})
                    if name == "prop_cargo_truck":
                        step += 12
                z += step
    out += [
        # the jackknife (z -20): a fuel tanker across the west carriageway, its cab in the median;
        # a van trailer askew over the east lanes. Gaps: both shoulders, and under the tank's neck.
        {"name": "env_tanker_trailer", "x": -27, "z": -20, "yaw": 196},
        {"name": "env_semi_cab", "x": -4.8, "z": -20.3, "yaw": 120},  # folded back on its own trailer
        {"name": "env_box_trailer", "x": 24, "z": -24, "yaw": 158},
        {"name": "env_semi_cab", "x": 41.7, "z": -21.7, "yaw": -72},
        {"name": "prop_car_sedan", "x": -40, "z": -38, "yaw": -60},
        {"name": "prop_car_hatch", "x": 14, "z": -44, "yaw": -115},
        {"name": "prop_car_pickup", "x": -22, "z": 2, "yaw": -70},
        {"name": "prop_road_debris", "x": -34, "z": -4, "yaw": 0},
        {"name": "prop_road_debris", "x": 8, "z": -30, "yaw": 80},
        {"name": "prop_road_debris", "x": 36, "z": -8, "yaw": 200},
        # in the median and on the shoulders: the ones that tried to go round
        {"name": "prop_car_sedan", "x": 4, "z": -236, "yaw": -70},
        {"name": "prop_car_van", "x": -5, "z": -140, "yaw": -112},
        {"name": "prop_car_pickup", "x": 3, "z": 172, "yaw": -50},
        {"name": "prop_car_hatch", "x": -4, "z": -356, "yaw": -100},
        {"name": "env_wreck_humvee", "x": 5, "z": 46, "yaw": -80},
        {"name": "prop_car_sedan", "x": 50.5, "z": -200, "yaw": SOUTH + 4},
        {"name": "prop_car_hatch", "x": -50.5, "z": -100, "yaw": SOUTH - 6},
        {"name": "prop_car_van", "x": 50.5, "z": 150, "yaw": SOUTH},
        {"name": "prop_car_pickup", "x": -50, "z": 210, "yaw": SOUTH + 8},
        {"name": "prop_road_debris", "x": -30, "z": -288, "yaw": 30},
        {"name": "prop_road_debris", "x": 34, "z": 118, "yaw": 140},
        {"name": "prop_road_debris", "x": -42, "z": 58, "yaw": 260},
        # on the span and the county road
        {"name": "prop_car_sedan", "x": 38, "z": OVER_Z - 6, "yaw": 0, "y": SPAN},
        {"name": "prop_car_hatch", "x": -44, "z": OVER_Z + 7, "yaw": 172, "y": SPAN},
        {"name": "prop_car_pickup", "x": 120, "z": OVER_Z - 7, "yaw": 6},
        {"name": "prop_car_van", "x": -150, "z": OVER_Z + 7, "yaw": 180},
        {"name": "prop_cargo_truck", "x": 210, "z": OVER_Z + 6, "yaw": 178},
        {"name": "prop_car_sedan", "x": -235, "z": OVER_Z - 6, "yaw": -15},
    ]
    # the south barricade (state police, then the army): the lead bus stopped against it
    out += [{"name": "env_barrier_jersey", "x": x, "z": -440, "yaw": 0} for x in range(-51, 52, 6) if abs(x) > 9]
    out += [
        {"name": "env_wreck_humvee", "x": -30, "z": -447, "yaw": 20},
        {"name": "env_wreck_humvee", "x": 26, "z": -448, "yaw": 165},
        {"name": "prop_light_tower", "x": -48, "z": -432, "yaw": 0},
        {"name": "prop_light_tower", "x": 48, "z": -432, "yaw": 180},
        {"name": "prop_concertina", "x": -40, "z": -434, "yaw": 0},
        {"name": "prop_concertina", "x": 22, "z": -434, "yaw": 0},
        {"name": "prop_concertina", "x": 34, "z": -434, "yaw": 0},
    ]
    out += [{"name": "prop_traffic_cone", "x": -46 + 5 * k, "z": -426 + 1.5 * k, "yaw": 0} for k in range(5)]
    # past the frame, both ways: the jam goes on (no collision; the eye fills in the rest)
    for z in (-470, -520, -575, -640, -720, 480, 530, 600, 680, 790, 900):
        for s in (-1, 1):
            if rng.random() < 0.75:
                out.append({"name": rng.choice(["prop_cargo_truck", "prop_car_van"]), "x": s * LANES[0], "z": z + rng.uniform(-8, 8), "yaw": SOUTH})
            if rng.random() < 0.6:
                out.append({"name": rng.choice(cars), "x": s * rng.choice(LANES[1:]), "z": z + rng.uniform(-14, 14), "yaw": SOUTH + rng.uniform(-8, 8)})
    return out


def _between(z, spans):
    return any(a < z < b for a, b in spans)


def _jam_edges():
    out = []
    apron = (TOLL_Z - 84, TOLL_Z + 84)
    ramps = (OVER_Z + 80, OVER_Z + 98), (OVER_Z - 98, OVER_Z - 80)
    gaps = {
        -1: ((-162, -138), (-422, -398), (-52, -22)) + ramps,  # rest stop landings, the Drop's torn rail
        1: ((-332, -308), (-92, -76)) + ramps,  # weigh station landings
    }
    for s in (-1, 1):  # guardrail on both crests: runs of four, then a 12 gap to drop through
        k = 0
        z = -Z_HALF + 6
        while z < Z_HALF:
            k += 1
            if k % 5 and not _between(z, gaps[s] + (apron, (-78, -62))):
                out.append({"name": "env_guardrail_12", "x": s * (DECK_HALF - 1.5), "z": z, "yaw": 90 * s})
            z += 12
    z = -Z_HALF
    i = 0
    while z < Z_HALF:  # the median: parapet runs of three, a 12 gap, a light in every other gap
        for k in range(3):
            zc = z + 6 + 12 * k
            if not _between(zc, (apron, (-46, 12), (OVER_Z - 20, OVER_Z + 20), (-78, -62))):
                out.append({"name": "env_parapet_12", "x": 0, "z": zc, "yaw": 90})
        zc = z + 42
        if i % 2 == 0 and not _between(zc, (apron, (OVER_Z - 20, OVER_Z + 20), (-78, -62))):
            out.append({"name": "env_highway_light", "x": 0, "z": zc, "yaw": 0})
        z += 48
        i += 1
    for s in (-1, 1):
        for lane_x in (22.0, 34.0):  # lane lines, one 96-stud mesh at a time
            for zc in list(range(-402, 180, 96)) + [420, 516, 612, 708, 804, 900, -498, -594, -690, -786]:
                out.append({"name": "env_lane_dashes_96", "x": s * lane_x, "z": zc, "yaw": 90, "y": DECK + 0.1})
    for x in (-270, -150, 150, 270):  # the county road's own lights
        out.append({"name": "env_highway_light", "x": x, "z": OVER_Z, "yaw": 90, "y": SPAN})
    out += [
        {"name": "env_sign_gantry", "x": 27.5, "z": 200, "yaw": 0},
        {"name": "env_sign_gantry", "x": -27.5, "z": 200, "yaw": 180},
        {"name": "env_sign_gantry", "x": -27.5, "z": -120, "yaw": 180},
        {"name": "env_sign_gantry", "x": 27.5, "z": -330, "yaw": 0},
        {"name": "prop_mile_marker", "x": -52, "z": 0, "yaw": 90},
        {"name": "prop_mile_marker", "x": 52, "z": -6, "yaw": -90},
        {"name": "prop_road_sign", "x": -51, "z": -128, "yaw": 180},  # REST AREA, read coming south
        {"name": "prop_road_sign", "x": 51, "z": -338, "yaw": 0},  # WEIGH STATION, read coming north
        {"name": "prop_road_sign", "x": 51, "z": 20, "yaw": 0},  # EXIT 14
        {"name": "prop_road_sign", "x": -51, "z": 186, "yaw": 180},
        {"name": "env_billboard", "x": -112, "z": 8, "yaw": 12},
        {"name": "env_billboard", "x": 118, "z": 196, "yaw": -14},
    ]
    return out


def _overpass():
    out = [
        {"name": "env_overpass_span", "x": 0, "z": OVER_Z, "yaw": 0, "y": SPAN - 4.5},
        {"name": "env_bridge_bent_low", "x": -50, "z": OVER_Z, "yaw": 0, "y": DECK},
        {"name": "env_bridge_bent_low", "x": 0, "z": OVER_Z, "yaw": 0, "y": DECK},
        {"name": "env_bridge_bent_low", "x": 50, "z": OVER_Z, "yaw": 0, "y": DECK},
    ]
    for s in (-1, 1):
        for k in range(10):
            out.append({"name": "env_parapet_12", "x": -54 + 12 * k, "z": OVER_Z + s * 16.8, "yaw": 0, "y": SPAN})
        for sx in (-1, 1):  # county road guardrail from the ramp mouths out to the tree line
            for k in range(20):
                if k % 6 != 5:
                    out.append({"name": "env_guardrail_12", "x": sx * (84 + 12 * k), "z": OVER_Z + s * 17.2, "yaw": 0 if s < 0 else 180})
    for sx in (-1, 1):  # the county road is shut at both ends
        out += [{"name": "env_barrier_jersey", "x": sx * 304, "z": OVER_Z - 12 + 6 * k, "yaw": 90} for k in range(5)]
        out.append({"name": "prop_cargo_truck", "x": sx * 312, "z": OVER_Z, "yaw": 90})
    return out


def _toll():
    out = []
    for cx in (-33.2, 33.2):
        out.append({"name": "env_toll_canopy", "x": cx, "z": TOLL_Z, "yaw": 90})
        for dx in (-24, -8, 8, 24):
            out.append({"name": "env_toll_booth", "x": cx + dx, "z": TOLL_Z, "yaw": 90})
            out.append({"name": "env_barrier_jersey", "x": cx + dx, "z": TOLL_Z - 16, "yaw": 90})
    out += [
        # stopped in the lanes: the buses that reached the booths, cars that did not
        {"name": "env_bus", "x": -17.2, "z": TOLL_Z + 4, "yaw": SOUTH},
        {"name": "env_bus_burnt", "x": 17.2, "z": TOLL_Z - 30, "yaw": SOUTH - 5},
        {"name": "prop_car_sedan", "x": -49.2, "z": TOLL_Z - 10, "yaw": SOUTH},
        {"name": "prop_car_van", "x": 49.2, "z": TOLL_Z + 14, "yaw": SOUTH},
        {"name": "prop_car_hatch", "x": 33.2, "z": TOLL_Z + 44, "yaw": SOUTH + 25},
        {"name": "prop_car_pickup", "x": -33.2, "z": TOLL_Z + 52, "yaw": SOUTH - 20},
        {"name": "prop_car_sedan", "x": 0, "z": TOLL_Z + 36, "yaw": SOUTH + 10},
        {"name": "prop_car_hatch", "x": -68, "z": TOLL_Z - 44, "yaw": SOUTH - 30},
        {"name": "prop_cargo_truck", "x": 70, "z": TOLL_Z - 52, "yaw": SOUTH + 12},
        {"name": "prop_car_van", "x": -4, "z": TOLL_Z - 62, "yaw": SOUTH - 8},
        # checkpoint dressing on the apron
        {"name": "env_checkpoint", "x": -70, "z": TOLL_Z + 30, "yaw": 90},
        {"name": "env_checkpoint", "x": 72, "z": TOLL_Z + 62, "yaw": 90},
        {"name": "prop_generator", "x": 76, "z": TOLL_Z - 20, "yaw": 0},
        {"name": "prop_light_tower", "x": -78, "z": TOLL_Z - 30, "yaw": 0},
        {"name": "prop_light_tower", "x": 80, "z": TOLL_Z + 36, "yaw": 180},
        {"name": "prop_light_tower", "x": 100, "z": TOLL_Z - 40, "yaw": 90},
        {"name": "prop_portable_toilet", "x": -80, "z": TOLL_Z + 60, "yaw": 90},
        {"name": "prop_portable_toilet", "x": -80, "z": TOLL_Z + 66, "yaw": 90},
        {"name": "prop_pallet", "x": 62, "z": TOLL_Z + 20, "yaw": 15},
        {"name": "prop_pallet", "x": 68, "z": TOLL_Z + 24, "yaw": -10},
        {"name": "prop_road_debris", "x": 20, "z": TOLL_Z - 56, "yaw": 0},
        {"name": "prop_road_debris", "x": -40, "z": TOLL_Z + 26, "yaw": 120},
        # the admin lot: the main pad needs open sky, so the dressing keeps to its edges
        {"name": "prop_car_sedan", "x": 100, "z": TOLL_Z + 28, "yaw": 0},
        {"name": "prop_car_pickup", "x": 118, "z": TOLL_Z + 28, "yaw": 0},
        {"name": "env_wreck_humvee", "x": 152, "z": TOLL_Z - 34, "yaw": 100},
        {"name": "prop_dumpster", "x": 160, "z": TOLL_Z + 20, "yaw": 90},
        {"name": "prop_body_bag", "x": 104, "z": TOLL_Z - 30, "yaw": 0},
        {"name": "prop_body_bag", "x": 104, "z": TOLL_Z - 34, "yaw": 5},
        {"name": "prop_body_bag", "x": 104, "z": TOLL_Z - 38, "yaw": -4},
    ]
    for k in range(6):  # the coned-off lane to the pad
        out.append({"name": "prop_traffic_cone", "x": 88 + 0.5 * k, "z": TOLL_Z - 18 + 7 * k, "yaw": 0})
    # the north barricade: trailers pulled across both carriageways, jerseys in the gaps
    out += [
        {"name": "env_box_trailer", "x": -30, "z": 441, "yaw": 4},
        {"name": "env_box_trailer", "x": 31, "z": 443, "yaw": -3},
        {"name": "env_semi_cab", "x": -2, "z": 436, "yaw": 150},
        {"name": "prop_light_tower", "x": -46, "z": 428, "yaw": 0},
        {"name": "prop_light_tower", "x": 46, "z": 428, "yaw": 180},
        {"name": "prop_concertina", "x": -20, "z": 432, "yaw": 0},
        {"name": "prop_concertina", "x": 24, "z": 432, "yaw": 0},
    ]
    out += [{"name": "env_barrier_jersey", "x": x, "z": 433, "yaw": 0} for x in (-52, -8, 8, 53)]
    return out


def _rest_stop():
    out = [
        {"name": "env_fuel_canopy", "x": -150, "z": -225, "yaw": 0},
        {"name": "env_diner_sign", "x": -100, "z": -322, "yaw": 90},
        {"name": "prop_road_sign", "x": -84, "z": -178, "yaw": 180},
        {"name": "env_lamp_post", "x": -96, "z": -190, "yaw": 180},
        {"name": "env_lamp_post", "x": -96, "z": -300, "yaw": 180},
        {"name": "env_lamp_post", "x": -200, "z": -172, "yaw": 90},
        {"name": "env_lamp_post", "x": -200, "z": -333, "yaw": -90},
        {"name": "env_lamp_post", "x": -288, "z": -235, "yaw": 0},
        # the truck bays on the west edge
        {"name": "env_box_trailer", "x": -266, "z": -262, "yaw": -90},
        {"name": "env_semi_cab", "x": -266, "z": -292, "yaw": -90},
        {"name": "env_tanker_trailer", "x": -280, "z": -258, "yaw": 90},
        {"name": "env_box_trailer", "x": -252, "z": -250, "yaw": 84},
        # cars that pulled in
        {"name": "prop_car_sedan", "x": -205, "z": -292, "yaw": 0},
        {"name": "prop_car_hatch", "x": -222, "z": -290, "yaw": 0},
        {"name": "prop_car_van", "x": -180, "z": -200, "yaw": 80},
        {"name": "prop_car_pickup", "x": -125, "z": -262, "yaw": 20},
        {"name": "prop_car_sedan", "x": -150, "z": -229, "yaw": 90},
        {"name": "prop_car_hatch", "x": -118, "z": -196, "yaw": -40},
        {"name": "prop_cargo_truck", "x": -205, "z": -215, "yaw": 5},
        {"name": "env_bus", "x": -128, "z": -310, "yaw": 8},  # one bus made it down the ramp
        {"name": "prop_dumpster", "x": -272, "z": -318, "yaw": 0},
        {"name": "prop_dumpster", "x": -210, "z": -322, "yaw": 0},
        {"name": "prop_portable_toilet", "x": -196, "z": -326, "yaw": 0},
        {"name": "env_barrier_jersey", "x": -170, "z": -180, "yaw": 0},
        {"name": "env_barrier_jersey", "x": -163, "z": -180, "yaw": 0},
        {"name": "env_barrier_jersey", "x": -232, "z": -214, "yaw": 90},
        {"name": "prop_pallet", "x": -238, "z": -286, "yaw": 0},
        {"name": "prop_road_debris", "x": -100, "z": -240, "yaw": 0},
    ]
    for x in (-157, -143):
        for z in (-229, -221):
            out.append({"name": "prop_fuel_pump", "x": x, "z": z, "yaw": 90, "y": 0.65})
    for k in range(5):  # cones down the exit ramp's foot
        out.append({"name": "prop_traffic_cone", "x": -74 - 4 * k, "z": -236 - 2 * k, "yaw": 0})
    return out


def _weigh_station():
    out = [
        {"name": "env_scale_house", "x": 120, "z": -186, "yaw": 0},
        {"name": "prop_road_sign", "x": 84, "z": -236, "yaw": 0},
        {"name": "env_box_trailer", "x": 128, "z": -205, "yaw": 0},  # on the scale
        {"name": "env_semi_cab", "x": 98, "z": -205, "yaw": 0},
        {"name": "prop_cargo_truck", "x": 186, "z": -206, "yaw": 172},  # the queue behind it
        {"name": "env_box_trailer", "x": 205, "z": -150, "yaw": 20},
        {"name": "env_semi_cab", "x": 177, "z": -140, "yaw": 20},
        {"name": "env_tanker_trailer", "x": 136, "z": -140, "yaw": 0},
        {"name": "prop_cargo_truck", "x": 222, "z": -228, "yaw": 90},
        {"name": "prop_car_pickup", "x": 96, "z": -160, "yaw": 90},  # the inspector's
        {"name": "prop_car_sedan", "x": 88, "z": -142, "yaw": -30},
        {"name": "env_lamp_post", "x": 78, "z": -200, "yaw": 0},
        {"name": "env_lamp_post", "x": 160, "z": -128, "yaw": -90},
        {"name": "env_lamp_post", "x": 240, "z": -190, "yaw": 180},
        {"name": "prop_generator", "x": 142, "z": -176, "yaw": 0},
        {"name": "prop_dumpster", "x": 150, "z": -186, "yaw": 90},
        {"name": "prop_pallet", "x": 228, "z": -160, "yaw": 0},
        {"name": "prop_pallet", "x": 234, "z": -164, "yaw": 30},
        {"name": "prop_road_debris", "x": 110, "z": -226, "yaw": 0},
        {"name": "env_water_tower", "x": 225, "z": -370, "yaw": 20},
    ]
    out += [{"name": "env_barrier_jersey", "x": 100 + 7 * k, "z": -216, "yaw": 0} for k in range(0, 10, 2)]
    out += [{"name": "prop_traffic_cone", "x": 70 + 3 * k, "z": -238 + 2 * k, "yaw": 0} for k in range(5)]
    return out


def _fields():
    out = [
        # the Drop: the bus the drivers went over the rail with, on its side below the torn rail
        {"name": "env_bus", "x": -84, "z": -38, "yaw": 80, "roll": 90},
        {"name": "prop_road_debris", "x": -72, "z": -30, "yaw": 0},
        # the Halt (north-west): where the ones who walked stopped
        {"name": "env_tent", "x": -230, "z": 232, "yaw": 0},
        {"name": "env_tent", "x": -230, "z": 258, "yaw": 0},
        {"name": "env_tent", "x": -196, "z": 232, "yaw": 0},
        {"name": "env_tent", "x": -196, "z": 270, "yaw": 90},
        {"name": "prop_car_sedan", "x": -160, "z": 224, "yaw": 30},
        {"name": "prop_car_hatch", "x": -148, "z": 252, "yaw": -20},
        {"name": "prop_car_van", "x": -170, "z": 282, "yaw": 75},
        {"name": "prop_light_tower", "x": -212, "z": 246, "yaw": 0},
        {"name": "prop_generator", "x": -250, "z": 246, "yaw": 90},
        {"name": "prop_portable_toilet", "x": -256, "z": 276, "yaw": 0},
        {"name": "prop_portable_toilet", "x": -250, "z": 276, "yaw": 0},
        {"name": "prop_cot", "x": -180, "z": 244, "yaw": 0},
        {"name": "prop_cot", "x": -180, "z": 250, "yaw": 0},
        {"name": "prop_cot", "x": -172, "z": 246, "yaw": 20},
        {"name": "prop_chainlink_panel", "x": -140, "z": 280, "yaw": 90},
        {"name": "prop_chainlink_panel", "x": -140, "z": 268, "yaw": 90},
    ]
    for k in range(6):  # the black-tagged row beside the tents
        out.append({"name": "prop_body_bag", "x": -212 + 3.0 * k, "z": 290, "yaw": 90 + 6 * (k % 3)})
    for k in range(4):
        out.append({"name": "prop_body_bag", "x": -92 - 2.5 * k, "z": -52 + 3 * k, "yaw": 15 * k})
    # the ones that left the road: cars run out into the fields, a rut behind each
    for x, z, yaw, name in (
        (-150, -20, 200, "prop_car_sedan"), (-215, 60, 150, "prop_car_pickup"), (130, 20, -20, "prop_car_van"),
        (205, 150, 30, "prop_car_hatch"), (160, 250, -150, "prop_car_sedan"), (150, -60, 10, "prop_car_pickup"),
        (-120, 130, 170, "prop_car_hatch"), (250, -100, -40, "prop_cargo_truck"),
    ):
        out.append({"name": name, "x": x, "z": z, "yaw": yaw})
        out.append({"name": "prop_road_debris", "x": x + 9, "z": z + 6, "yaw": yaw})
    trees = (
        (-250, 160), (-120, 170), (-90, 300), (-285, 330), (-140, 380), (-250, 410), (-100, -60), (-200, -80),
        (-280, -120), (-150, -130), (-270, 10), (-170, 20), (-110, -400), (-230, -400), (130, -40), (220, -60),
        (280, 10), (110, -330), (160, -400), (285, -290), (200, 170), (280, 200), (190, 400), (270, 330), (120, 420),
    )
    for i, (x, z) in enumerate(trees):
        out.append({"name": "env_dead_tree", "x": x, "z": z, "yaw": 47 * i % 360})
    return out


def _edges():
    """What hides the frame: sound walls flanking the road at both ends, a pine line east and west."""
    out = []
    for sz in (-1, 1):
        for sx in (-1, 1):
            for k in range(11):
                x = sx * (72 + 12 + 24 * k)
                out.append({"name": "env_sound_wall_24", "x": x, "z": sz * (Z_HALF + 2), "yaw": 0 if sz < 0 else 180, "y": 0})
            for k in range(6):  # pines over the wall
                out.append({"name": "env_pine_stand", "x": sx * (96 + 44 * k), "z": sz * (Z_HALF + 26 + 9 * (k % 2)), "yaw": 180 * (k % 2), "y": 0})
    for sx in (-1, 1):
        z = -Z_HALF + 10
        k = 0
        while z < Z_HALF:
            if not (OVER_Z - 40 < z < OVER_Z + 40):  # the county road embankment runs through here
                out.append({"name": "env_pine_stand", "x": sx * (X_HALF + 8 + 7 * (k % 2)), "z": z, "yaw": 90 + 180 * (k % 2), "y": 0})
            z += 45
            k += 1
        for dz in (-58, 58):  # pines on the embankment's shoulders, where the county road leaves
            out.append({"name": "env_pine_stand", "x": sx * (X_HALF + 30), "z": OVER_Z + dz, "yaw": 90, "y": 0})
    return out


# Harlan, to the north, where the road goes: (kind, x, z, scale, yaw, burning). No collision.
def _skyline():
    rng = random.Random(1408)
    kinds = ("office", "residential", "deco", "glass", "ruined", "midrise")
    out = []
    # Three arcs about the Toll Plaza, 128 degrees wide, so some of Harlan shows over the pines
    # from anywhere north of the Overpass: (radius, scale low, scale high, towers).
    rows = ((880, 1.0, 1.4, 14), (1120, 1.4, 1.9, 12), (1400, 1.9, 2.6, 10))
    for i, (radius, s0, s1, n) in enumerate(rows):
        for k in range(n):
            a = -64 + 128 * (k + 0.5) / n + rng.uniform(-3, 3)  # degrees east of north
            r = radius + rng.uniform(-50, 50)
            mid = 1.0 - 0.55 * abs(a) / 64  # tallest downtown where the interstate goes, low at the ends
            out.append({
                "kind": kinds[(k * 5 + i) % 6] if rng.random() < 0.7 else rng.choice(kinds),
                "x": round(r * math.sin(math.radians(a))), "z": round(TOLL_Z + r * math.cos(math.radians(a))),
                "scale": round(rng.uniform(s0, s1) * mid, 2),
                "yaw": rng.choice((0, 8, -12, 15, 45, 90, 180)), "burning": rng.random() < 0.2,
            })
    return out


SKYLINE = _skyline()
DRESSING = _jam_vehicles() + _jam_edges() + _overpass() + _toll() + _rest_stop() + _weigh_station() + _fields() + _edges()
BACKDROP = {"env_sound_wall_24", "env_pine_stand"}  # no collision, outside the frame

# ------------------------------------------------------------------ scene

KINDS = {
    "grass": (0.20, 0.18, 0.09, 1),  # dead grass, not Delta's dust
    "slope": (0.17, 0.15, 0.08, 1),
    "road": (0.115, 0.12, 0.13, 1),
    "concrete": (0.36, 0.355, 0.335, 1),
    "building": (0.50, 0.49, 0.44, 1),
    "steel": (0.25, 0.26, 0.275, 1),
    "glass": (0.06, 0.09, 0.11, 1),
    "red": (0.42, 0.07, 0.07, 1),
    "pad": (0.52, 0.50, 0.44, 1),
    "patch": (0.16, 0.13, 0.09, 1),
    "line": (0.62, 0.62, 0.60, 1),
    "sign": (0.03, 0.18, 0.08, 1),  # highway sign green
    "zone": (0.90, 0.74, 0.38, 1),  # objective yellow: overview markers only
}
HAZE = (0.42, 0.30, 0.24)  # the smoke-stained dusk the towers fade into


def _mat(name, rgba, emit=0.0):
    m = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    m.use_nodes = True
    bsdf = next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    bsdf.inputs["Base Color"].default_value = rgba
    bsdf.inputs["Roughness"].default_value = 0.95
    if emit:
        bsdf.inputs["Emission Color"].default_value = rgba
        bsdf.inputs["Emission Strength"].default_value = emit
    m.diffuse_color = rgba
    return m


def _materials():
    mats = {kind: _mat("m14v2_" + kind, rgba) for kind, rgba in KINDS.items()}
    mats["haze"] = _mat("m14v2_tower", (0.19, 0.155, 0.14, 1))  # replaced by the hazed palette in build()
    mats["lit"] = _mat("m14v2_lit", (1.0, 0.62, 0.25, 1), emit=3.0)  # sodium windows
    mats["fire"] = _mat("m14v2_fire", (1.0, 0.32, 0.08, 1), emit=5.0)
    mats["mark"] = _mat("m14v2_mark", (1.0, 1.0, 1.0, 1), emit=1.0)
    mats["zone"] = _mat("m14v2_zone", KINDS["zone"], emit=1.0)
    return mats


def _hazed(palette_mat, amount=0.6):
    """The palette material faded toward the sky colour: what the game's Atmosphere does to the
    towers at that distance. Facade bands and windows stay readable, nothing pops."""
    m = bpy.data.materials.get("m14v2_tower_palette")
    if m is not None:
        bpy.data.materials.remove(m)
    m = palette_mat.copy()
    m.name = "m14v2_tower_palette"
    tree = m.node_tree
    bsdf = next(n for n in tree.nodes if n.type == "BSDF_PRINCIPLED")
    tex = next(n for n in tree.nodes if n.type == "TEX_IMAGE")
    mix = tree.nodes.new("ShaderNodeMix")
    mix.data_type = "RGBA"
    sock = {i.identifier: i for i in mix.inputs}
    sock["Factor_Float"].default_value = amount
    sock["B_Color"].default_value = HAZE + (1,)
    tree.links.new(tex.outputs["Color"], sock["A_Color"])
    tree.links.new(next(o for o in mix.outputs if o.identifier == "Result_Color"), bsdf.inputs["Base Color"])
    m.diffuse_color = (0.3, 0.24, 0.21, 1)
    return m


def _paint(obj, mat):
    obj.data.materials.clear()
    obj.data.materials.append(mat)
    obj.color = mat.diffuse_color


MARK_Y = 70.0  # overview markers float above everything


def _frame(col, name, c, size, mat, t=2.0):
    """A zone outline for the overview: four bars, so the place under it still shows."""
    for dx, dz, sx, sz in ((0, 1, size[0], t), (0, -1, size[0], t), (1, 0, t, size[1]), (-1, 0, t, size[1])):
        bar = dm.box(name, col, "warn", (c[0] + dx * size[0] / 2, MARK_Y, c[2] + dz * size[1] / 2), (sx, 0.2, sz))
        _paint(bar, mat)
        bar.visible_shadow = False


def _label(col, text, x, z, mat, size=17.0):
    curve = bpy.data.curves.new("label_" + text, "FONT")
    curve.body = text
    curve.size = size
    curve.align_x = "CENTER"
    obj = bpy.data.objects.new("label_" + text, curve)
    col.objects.link(obj)
    obj.location = dm.rb(x, MARK_Y, z)
    curve.materials.append(mat)
    obj.visible_shadow = False
    return obj


def clear():
    for name in ("Mile14v2", "M14v2_Kit"):
        col = bpy.data.collections.get(name)
        if col is None:
            continue
        for child in list(col.children_recursive) + [col]:
            for o in list(child.objects):
                me = o.data
                bpy.data.objects.remove(o, do_unlink=True)
                if me is not None and me.users == 0:
                    (bpy.data.meshes if isinstance(me, bpy.types.Mesh) else bpy.data.curves).remove(me)
        for child in list(col.children_recursive):
            bpy.data.collections.remove(child)
        bpy.data.collections.remove(col)


def build_kit(names, palette_mat):
    """One mesh per kit piece, built from build_assets' builders into a hidden library."""
    lib = dm.collection("M14v2_Kit")
    lib.hide_render = True
    lib.hide_viewport = True
    meshes = {}
    for name in sorted(names):
        fn, col_name, pivot = ba.ASSETS[name]
        b = ba.Builder()
        fn(b)
        meshes[name] = b.finish(name, lib, palette_mat, pivot=pivot).data
    return meshes


def _tris(mesh):
    return sum(len(p.vertices) - 2 for p in mesh.polygons)


def report(meshes):
    """Counts against STYLES: tris by layer, instances, distinct meshes, Parts."""
    layers = {"play": [0, 0], "edge": [0, 0], "skyline": [0, 0]}
    for e in DRESSING:
        key = "edge" if e["name"] in BACKDROP else "play"
        layers[key][0] += 1
        layers[key][1] += _tris(meshes[e["name"]])
    for t in SKYLINE:
        layers["skyline"][0] += 2
        layers["skyline"][1] += _tris(meshes["env_city_" + t["kind"]]) + _tris(meshes["env_city_" + t["kind"] + "_lit"])
    hill_parts = 0
    for h in HILLS:
        open_ = h.get("open") or {}
        sides = [s for s in ("north", "south", "east", "west") if not open_.get(s)]
        corners = sum(1 for a in ("east", "west") for b in ("north", "south") if a in sides and b in sides)
        hill_parts += 1 + len(sides) + corners
    worst = max(meshes, key=lambda n: _tris(meshes[n]))
    print("Mile 14 v2: frame %d x %d, deck %d x %d" % (2 * X_HALF, 2 * Z_HALF, 2 * DECK_HALF, 2 * Z_HALF))
    for key, (n, tris) in layers.items():
        print("  %-8s %4d instances %7d tris" % (key, n, tris))
    print("  %d distinct meshes (largest %s, %d tris); %d Parts + %d earthwork Parts + %d sign panels" % (
        len(meshes), worst, _tris(meshes[worst]), len(PARTS), hill_parts, len(SIGNS)))
    return layers


def build(palette_mat=None):
    clear()
    mats = _materials()
    if palette_mat is None:
        palette_mat = ba.build_palette_material(ba.build_palette_image())
    root = dm.collection("Mile14v2")
    terrain = dm.collection("M14v2_Terrain", root)
    parts = dm.collection("M14v2_Parts", root)
    dressing = dm.collection("M14v2_Dressing", root)
    edge = dm.collection("M14v2_Edge", root)
    sky = dm.collection("M14v2_Skyline", root)
    marks = dm.collection("M14v2_Marks", root)  # zones and pads, for the overview only
    marks.hide_render = True
    marks.hide_viewport = True

    ground = dm.box("Ground", terrain, "hill", (0, -0.5, 600), (5200, 1, 4400))  # reaches under the skyline
    _paint(ground, mats["grass"])
    for h in HILLS:
        dm.build_hill(h, terrain)
    tops = {h["name"] for h in HILLS}
    for o in terrain.objects:
        if o is not ground:
            _paint(o, mats["grass"] if o.name.split(".")[0] in tops else mats["slope"])
    for name, kind, c, size, yaw in PARTS:
        fn = dm.wedge if "_wedge" in name else dm.box
        _paint(fn(name, parts, "concrete", c, size, yaw), mats[kind])
    for name, x, y, z in SIGNS:
        _paint(dm.box(name, parts, "steel", (x, y, z), (24, 10, 0.3)), mats["sign"])
    for name, (c, size) in SITES.items():
        _frame(marks, "Zone " + name, c, size, mats["zone"])
        _label(marks, name, c[0], c[2] + size[1] / 2 + 6, mats["zone"])
    for name, c in PADS.items():
        _frame(marks, "Pad " + name, c, (26, 26), mats["mark"])
        _label(marks, name, c[0], c[2] + 19, mats["mark"])
    for name, (x, z) in LABELS.items():
        _label(marks, name, x, z, mats["mark"])

    mats["haze"] = _hazed(palette_mat)
    names = {e["name"] for e in DRESSING}
    for t in SKYLINE:
        names |= {"env_city_" + t["kind"], "env_city_" + t["kind"] + "_lit"}
    meshes = build_kit(names, palette_mat)
    for e in DRESSING:
        y = e.get("y")
        if y is None:
            y = dm.ground_height(HILLS, e["x"], e["z"])
        mesh = meshes[e["name"]]
        obj = bpy.data.objects.new(e["name"], mesh)
        (edge if e["name"] in BACKDROP else dressing).objects.link(obj)
        obj.location = dm.rb(e["x"], y, e["z"])
        obj.rotation_euler = (math.radians(e.get("roll") or 0), 0, math.radians(-e["yaw"]))
        if e.get("roll"):
            obj.location.z += max(v.co.y for v in mesh.vertices)
    for t in SKYLINE:
        for suffix in ("", "_lit"):
            mesh = meshes["env_city_" + t["kind"] + suffix]
            obj = bpy.data.objects.new("sky_" + t["kind"] + suffix, mesh)
            sky.objects.link(obj)
            obj.location = dm.rb(t["x"], 0, t["z"])
            obj.rotation_euler = (0, 0, math.radians(-t["yaw"]))
            obj.scale = (t["scale"],) * 3
            # One hazed tone per tower (the game's Atmosphere does this); windows glow through.
            obj.material_slots[0].link = "OBJECT"
            obj.material_slots[0].material = mats["haze"] if not suffix else (mats["fire"] if t["burning"] else mats["lit"])
            obj.color = obj.material_slots[0].material.diffuse_color
    report(meshes)
    return root


# ------------------------------------------------------------------ previews

# name: (eye (x, y, z), look-at (x, y, z), lens). Eye height is EYE above the floor there.
VIEWS = {
    "mile14_v2_skyline": ((8, SPAN + EYE, OVER_Z + 14.8), (0, DECK + 60, 1000), 24),  # at the span's north parapet
    "mile14_v2_insert": ((140, DECK + EYE, TOLL_Z - 6), (-40, DECK + 22, TOLL_Z + 150), 20),  # from the main pad
    "mile14_v2_toll": ((6, DECK + EYE, TOLL_Z - 92), (0, DECK + 14, TOLL_Z + 200), 24),  # the Toll Plaza site, looking north
    "mile14_v2_span": ((-22, SPAN + EYE, OVER_Z - 14.8), (6, DECK - 10, -90), 20),  # at the span's south parapet
    "mile14_v2_jackknife": ((-51, DECK + EYE, 20), (-18, DECK + 6, -26), 20),  # the choke point, from the west shoulder
    "mile14_v2_reststop": ((-98, EYE, -210), (-230, 6, -285), 20),  # the Rest Stop from the exit ramp's foot
    "mile14_v2_weigh": ((76, EYE, -197), (160, 6, -198), 20),  # the Weigh Station from its exit ramp's foot
    "mile14_v2_oblique": ((270, 120, 310), (10, 12, 30), 24),  # from above the north-east, not eye height
    "mile14_v2_altpad": ((-262, EYE, -195), (-60, 16, -240), 22),  # the alt pad, looking back at the deck
}


def _look_at(cam, eye, target):
    cam.location = dm.rb(*eye)
    cam.rotation_euler = (dm.rb(*target) - cam.location).to_track_quat("-Z", "Y").to_euler()


def setup_look(scene):
    """Dusk light for judging shapes (the mission itself is full dark; that is the game's job)."""
    world = scene.world or bpy.data.worlds.new("m14v2_dusk")
    scene.world = world
    world.use_nodes = True
    bg = next(n for n in world.node_tree.nodes if n.type == "BACKGROUND")
    bg.inputs["Color"].default_value = HAZE + (1,)
    bg.inputs["Strength"].default_value = 1.0
    sun = bpy.data.objects.get("m14v2_sun")
    if sun is None:
        sun = bpy.data.objects.new("m14v2_sun", bpy.data.lights.new("m14v2_sun", "SUN"))
        scene.collection.objects.link(sun)
    sun.data.energy = 2.6
    sun.data.color = (1.0, 0.78, 0.6)
    sun.rotation_euler = (math.radians(62), 0, math.radians(-125))  # low, from the south-west
    return sun


def render_previews(size=(1600, 900)):
    os.makedirs(PREVIEWS, exist_ok=True)
    scene = bpy.context.scene
    setup_look(scene)
    for engine in ("BLENDER_EEVEE", "BLENDER_EEVEE_NEXT", "BLENDER_WORKBENCH"):
        try:
            scene.render.engine = engine
            break
        except TypeError:
            continue
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGB"
    scene.render.image_settings.color_depth = "8"
    scene.render.image_settings.compression = 100
    try:
        scene.view_settings.view_transform = "Standard"
    except TypeError:
        pass
    cam_data = bpy.data.cameras.get("m14v2_cam") or bpy.data.cameras.new("m14v2_cam")
    cam = bpy.data.objects.get("m14v2_cam")
    if cam is None:
        cam = bpy.data.objects.new("m14v2_cam", cam_data)
        scene.collection.objects.link(cam)
    scene.camera = cam
    cam_data.clip_start = 0.5
    cam_data.clip_end = 6000
    marks = bpy.data.collections.get("M14v2_Marks")
    scene.render.resolution_x, scene.render.resolution_y = size
    cam_data.type = "PERSP"
    for name, (eye, target, lens) in VIEWS.items():
        cam_data.lens = lens
        _look_at(cam, eye, target)
        scene.render.filepath = os.path.join(PREVIEWS, name + ".png")
        bpy.ops.render.render(write_still=True)
    # top-down, the whole frame, zones and pads marked
    if marks is not None:
        marks.hide_render = False
    cam_data.type = "ORTHO"
    cam_data.ortho_scale = 2 * Z_HALF + 80
    cam.location = dm.rb(0, 900, 0)
    cam.rotation_euler = (0, 0, 0)
    scene.render.resolution_x, scene.render.resolution_y = 1100, 1400
    scene.render.filepath = os.path.join(PREVIEWS, "mile14_v2_overview.png")
    bpy.ops.render.render(write_still=True)
    if marks is not None:
        marks.hide_render = True


if __name__ == "__main__":
    ba.reset_scene()
    build()
    render_previews()
    bpy.ops.wm.save_as_mainfile(filepath=BLEND)
    print(f"saved {BLEND}")
