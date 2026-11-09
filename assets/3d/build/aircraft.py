"""Aircraft (owner 2026-11-09: "build the actual helicopter in blender" for the Shrike gun run).

A set of related pieces shares one file (owner, 2026-11-08), registered into build_assets.py's
ASSETS table by `register(ba)`, the props.py pattern. Build with:

    blender --background --python assets/3d/build/build_assets.py -- --only veh_shrike_hull

The Shrike is an attack helicopter in the AH-64 mould (tandem cockpit, chin gun, stub wings
with rocket pods, a long tail boom), olive drab, built at its in-game size in studs: 30 long,
rotor 26 across, so it reads big passing 45 studs over the squad. Nose toward -Y (Roblox -Z,
a part's LookVector), origin at the fuselage centre (the rotor hub sits at ROTOR_HUB),
pivot "center" keeps that origin. The
main rotor is its own mesh (`veh_shrike_rotor`, origin at the hub) so the game spins it; the
small tail rotor is part of the hull. (Lantern, the transport, belongs here when it is built.)
"""

import math

# Where the rotor hub sits on the hull, Blender (x, y, z); in Roblox order (x, z, y).
ROTOR_HUB = (0.0, -1.5, 3.35)
# The chin gun's muzzle (tracers start here).
GUN_MUZZLE = (0.0, -11.4, -1.75)


def shrike_hull(b):
    o, od, dk = "olive", "olive_d", "dark"
    # fuselage: the main body, the nose taper and the chin
    b.box((3.2, 9.0, 3.6), (0, -2.0, 0.0), swatch=o)
    b.box((2.7, 2.6, 2.6), (0, -7.6, -0.4), swatch=o)  # nose
    b.box((2.0, 1.6, 1.8), (0, -9.6, -0.6), swatch=o)  # nose tip (sensor housing)
    b.box((1.4, 0.3, 1.2), (0, -10.45, -0.5), swatch="glass")  # sensor window
    b.box((3.0, 8.6, 0.6), (0, -2.0, -2.05), swatch=od)  # belly
    # tandem cockpit: gunner in front, pilot raised behind
    b.box((2.3, 2.4, 1.4), (0, -6.2, 1.6), swatch="glass")
    b.box((2.3, 2.6, 1.9), (0, -3.8, 2.05), swatch="glass")
    b.box((2.36, 0.15, 1.5), (0, -5.0, 1.75), swatch=dk)  # frame between the seats
    b.box((2.4, 0.2, 2.0), (0, -2.45, 2.0), swatch=dk)  # rear frame
    b.box((0.12, 5.0, 0.2), (0, -5.0, 3.05), swatch=dk)  # canopy spine
    b.box((2.36, 2.5, 0.12), (0, -6.2, 0.9), swatch="glass_l")  # glint
    # engines either side of the mast, exhausts aft
    for s in (-1, 1):
        b.box((1.3, 4.2, 1.4), (s * 2.15, 0.2, 1.3), swatch=od)
        b.cyl(0.55, 0.6, (s * 2.15, 2.5, 1.3), segs=8, rot=(90, 0, 0), swatch=dk)  # exhaust
        b.box((0.9, 1.2, 0.5), (s * 2.15, -2.0, 1.9), swatch=od)  # intake
    # rotor mast and the hub fairing (the blades are veh_shrike_rotor)
    b.cyl(0.35, 1.4, (0, -1.5, 2.6), segs=8, swatch=dk)
    b.cyl(0.75, 0.4, (0, -1.5, 3.15), segs=8, swatch="gun_d")
    b.box((1.2, 1.2, 0.6), (0, -1.5, 2.1), swatch=od)  # mast fairing
    # stub wings with rocket pods and missiles
    b.box((8.4, 1.8, 0.25), (0, -1.6, 0.4), swatch=od)
    for s in (-1, 1):
        for x in (2.9, 4.0):
            b.box((0.25, 0.8, 0.6), (s * x, -1.6, 0.0), swatch=dk)  # pylons
        b.cyl(0.45, 2.4, (s * 2.9, -1.6, -0.6), segs=8, rot=(90, 0, 0), swatch=od)  # rocket pod
        b.cyl(0.36, 0.04, (s * 2.9, -2.82, -0.6), segs=8, rot=(90, 0, 0), swatch=dk)  # pod face
        for z in (-0.25, -0.75):
            b.cyl(0.13, 1.8, (s * 4.0, -1.8, z), segs=6, rot=(90, 0, 0), swatch="white_d")  # missiles
            b.cyl(0.13, 0.25, (s * 4.0, -2.8, z), segs=6, r2=0.02, rot=(90, 0, 0), swatch="white_d")
    # chin gun turret
    b.cyl(0.55, 0.6, (0, -9.0, -1.65), segs=8, swatch=dk)
    b.cyl(0.1, 2.3, (0, -10.3, -1.75), segs=6, rot=(90, 0, 0), swatch="gun_d")  # barrel
    # tail boom, fin, stabiliser, tail rotor
    b.box((1.5, 11.5, 1.5), (0, 8.5, 0.7), swatch=o)
    b.box((1.1, 3.0, 1.1), (0, 15.4, 0.9), swatch=o)  # boom end
    b.box((0.3, 2.6, 4.2), (0, 16.4, 2.7), rot=(-12, 0, 0), swatch=o)  # vertical fin
    b.box((4.8, 1.6, 0.2), (0, 15.6, 0.4), swatch=o)  # horizontal stabiliser
    for a in (0, 90):
        b.box((0.08, 0.35, 3.4), (0.3, 16.6, 3.3), rot=(a, 0, 0), swatch=dk)  # tail rotor blades
    b.cyl(0.2, 0.3, (0.25, 16.6, 3.3), segs=6, rot=(0, 90, 0), swatch="gun_d")  # tail rotor hub
    # landing gear: two main wheels, a tail wheel
    for s in (-1, 1):
        b.box((0.2, 0.3, 1.4), (s * 1.5, -4.0, -2.6), rot=(0, s * 20, 0), swatch=dk)  # strut
        b.cyl(0.45, 0.35, (s * 1.75, -4.0, -3.15), segs=8, rot=(0, 90, 0), swatch="dark_d")  # wheel
    b.box((0.15, 0.2, 0.9), (0, 15.0, -0.4), swatch=dk)
    b.cyl(0.25, 0.2, (0, 15.0, -0.85), segs=8, rot=(0, 90, 0), swatch="dark_d")
    # markings: a dull white star patch and a tail stripe
    b.box((0.04, 1.0, 1.0), (1.62, 1.2, 0.0), swatch="white_d")
    b.box((0.04, 1.2, 0.3), (0.77, 12.0, 0.7), swatch="dark_l")


def shrike_rotor(b):
    # Four blades from the hub, 26 across, yellow tips; origin at the hub so it spins in place.
    b.cyl(0.6, 0.35, (0, 0, 0), segs=8, swatch="gun_d")
    for i in range(4):
        a = math.radians(i * 90 + 45)
        c, s = math.cos(a), math.sin(a)
        b.box((12.6, 0.8, 0.1), (c * 6.6, s * 6.6, 0.05), rot=(0, 0, math.degrees(a)), swatch="dark")
        b.box((0.6, 0.82, 0.12), (c * 12.6, s * 12.6, 0.05), rot=(0, 0, math.degrees(a)), swatch="objective_yellow")


AIRCRAFT = {
    "veh_shrike_hull": shrike_hull,
    "veh_shrike_rotor": shrike_rotor,
}


def register(ba):
    """Adds every aircraft mesh to build_assets' ASSETS table (pivot center: the design origin stays)."""
    for name, fn in AIRCRAFT.items():
        ba.ASSETS[name] = (fn, "Props", "center")
