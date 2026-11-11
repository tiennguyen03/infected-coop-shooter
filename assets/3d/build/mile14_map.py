"""Mile 14 in Blender: the layout as a scene you can look at (docs/LEVELS.md C1).

Same job as delta_map.py, for a mission that has no mission data yet: until Mile 14 exists in
the game (PROGRESSION > Build order 4), its layout lives here as Python tables in the Luau
shape (`HILLS`, `PARTS`, `DRESSING`), in Roblox coordinates (x, y, z), +Z north, yaw in degrees
about up. The ground, slopes and axis mapping come from delta_map; the kit meshes come straight
from build_assets' builders (one mesh per piece, every placement a linked instance), so nothing
needs exporting first. Positions are a piece's design origin (bounds centre on the floor).

Live Blender (the owner's way: look at it):

    exec(open(r"assets/3d/build/mile14_map.py").read()); build()

Headless (writes assets/3d/mile14_map.blend and the previews):

    blender --background --python assets/3d/build/mile14_map.py
"""

import math
import os
import sys

import bpy

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import build_assets as ba  # noqa: E402
import delta_map as dm  # noqa: E402

BLEND = os.path.join(dm.ROOT, "assets", "3d", "mile14_map.blend")

JAM = 12.0  # the Jam deck
SPAN = 26.0  # the county road and the Overpass span
TOLL = 6.0
KNOLL = 8.0

# ------------------------------------------------------------------ earthworks (C1.1)
HILLS = [
    {"name": "JamS", "x": 0, "z": -172.5, "top": (60, 255), "height": JAM, "open": {"north": True, "south": True}},
    {"name": "JamN", "x": 0, "z": 132.5, "top": (60, 335), "height": JAM, "open": {"north": True, "south": True}},
    {"name": "OverpassW", "x": -181.5, "z": 60, "top": (237, 36), "height": SPAN, "open": {"east": True, "west": True}},
    {"name": "OverpassE", "x": 181.5, "z": 60, "top": (237, 36), "height": SPAN, "open": {"east": True, "west": True}},
    {"name": "TollPlaza", "x": 180, "z": 175, "top": (140, 70), "height": TOLL},
    {"name": "TowerKnoll", "x": 180, "z": -120, "top": (50, 50), "height": KNOLL},
]

# Plain Parts: (name, kind, centre (x, y, z), size (x, y, z), yaw). kind = delta_map KIND_COLORS
# key; "wedge" in the name builds a WedgePart (rises toward its +Z face).
PARTS = [
    ("CulvertRoof", "concrete", (0, 9.5, -40), (60, 5, 10), 0),
    ("JamRoad", "road", (0, JAM + 0.05, 0), (58, 0.1, 600), 0),
    ("CountyRoadW", "road", (-181.5, SPAN + 0.05, 60), (237, 0.1, 32), 0),
    ("CountyRoadE", "road", (181.5, SPAN + 0.05, 60), (237, 0.1, 32), 0),
    ("StairN_wedge", "concrete", (0, (JAM + SPAN) / 2, 88.75), (6, SPAN - JAM, 21.5), 180),
    ("StairS_wedge", "concrete", (0, (JAM + SPAN) / 2, 31.25), (6, SPAN - JAM, 21.5), 0),
    ("Ramp_wedge", "road", (-56, JAM / 2, -200), (16, JAM, 60), 180),
    ("RampLanding", "concrete", (-47.5, JAM / 2, -238), (33, JAM, 16), 0),
    ("RestStopLot", "concrete", (-130, 0.05, -170), (130, 0.1, 100), 0),
    ("TollPlazaPaving", "road", (180, TOLL + 0.05, 175), (140, 0.1, 66), 0),
    ("Diner", "building", (-140, 4.5, -205), (36, 9, 20), 0),
    ("DinerRoofTrim", "prop", (-140, 9.2, -205), (36.4, 0.6, 20.4), 0),
    ("DinerWindows", "steel", (-140, 5.0, -194.9), (28, 3.2, 0.2), 0),
    ("IslandW", "concrete", (-95, 0.3, -160), (4, 0.6, 18), 0),
    ("IslandE", "concrete", (-81, 0.3, -160), (4, 0.6, 18), 0),
    ("MainPad", "concrete", (225, TOLL + 0.15, 175), (26, 0.3, 26), 0),
    ("AltPad", "concrete", (-225, 0.15, -150), (26, 0.3, 26), 0),
]

# Sign panels on the gantries (Parts with a SurfaceGui in game): (name, x, y, z).
SIGNS = [("SignHarlan14", 0, JAM + 22, 148.4), ("SignExit14", 0, JAM + 22, -98.4)]


def _jam_vehicles():
    out = []
    west = {  # W lane x -14 (C1.3)
        -270: "env_bus", -216: "env_bus", -162: "env_bus_burnt", -114: "prop_cargo_truck",
        -60: "env_bus", 12: "env_bus_burnt", 130: "env_bus", 190: "env_bus", 250: "env_bus_burnt",
    }
    east = {-264: "env_bus_burnt", -84: "env_bus", 12: "env_bus", 104: "env_bus", 140: "prop_cargo_truck", 176: "env_bus", 232: "env_bus"}
    for lane_x, lane in ((-14, west), (14, east)):
        for z, name in lane.items():
            out.append({"name": name, "x": lane_x, "z": z, "yaw": 90})
    out += [
        {"name": "env_box_trailer", "x": 16, "z": -156, "yaw": 70},  # the jackknife
        {"name": "env_semi_cab", "x": 12, "z": -124, "yaw": 20},
        {"name": "prop_car_sedan", "x": -14, "z": 50, "yaw": 92},  # under the span
        {"name": "prop_car_hatch", "x": -22, "z": 66, "yaw": 85},
        {"name": "prop_car_van", "x": 14, "z": 60, "yaw": 90},
        {"name": "prop_car_sedan", "x": 40, "z": 58, "yaw": 0, "y": SPAN},  # on the span
        {"name": "prop_car_hatch", "x": -40, "z": 64, "yaw": 175, "y": SPAN},
        {"name": "prop_car_sedan", "x": 24, "z": -30, "yaw": 88},  # shoulders
        {"name": "prop_car_hatch", "x": 23, "z": -210, "yaw": 90},
        {"name": "prop_car_van", "x": -24, "z": -140, "yaw": 90},
        {"name": "prop_car_sedan", "x": -24, "z": 170, "yaw": 90},
        {"name": "prop_car_pickup", "x": 24, "z": 200, "yaw": 88},
        {"name": "env_wreck_humvee", "x": -24, "z": 284, "yaw": 100},
    ]
    out += [{"name": "env_barrier_jersey", "x": x, "z": -296, "yaw": 0} for x in range(-24, 25, 6)]  # roadblock
    return out


def _jam_edges():
    out = []
    for x in (-28.5, 28.5):  # guardrail on both crests: runs of 4 then a 12 gap
        z = -300.0
        while z < 300:
            for k in range(4):
                zc = z + 6 + 12 * k
                if zc >= 300:
                    break
                if x < 0 and (-246 < zc < -230 or -88 < zc < -72):
                    continue  # the landing and the torn rail at the Drop
                if -45 < zc < -35:
                    continue  # over the Culvert mouth
                out.append({"name": "env_guardrail_12", "x": x, "z": zc, "yaw": 90 if x > 0 else -90})
            z += 60
    z = -300.0
    while z < 300:  # median parapet: runs of 3 then a 12 gap, none at the stair feet
        for k in range(3):
            zc = z + 6 + 12 * k
            if zc < 300 and not (16 < zc < 104):
                out.append({"name": "env_parapet_12", "x": 0, "z": zc, "yaw": 90})
        z += 48
    for zc in (-264, -192, -120, -48, 120, 192, 264):
        out.append({"name": "env_highway_light", "x": 0, "z": zc, "yaw": 90})
    for x in (-80, 80):
        out.append({"name": "env_highway_light", "x": x, "z": 44, "yaw": 0, "y": SPAN})
    out += [
        {"name": "env_sign_gantry", "x": 0, "z": 150, "yaw": 0},
        {"name": "env_sign_gantry", "x": 0, "z": -100, "yaw": 180},
        {"name": "prop_mile_marker", "x": -26.5, "z": 0, "yaw": 90},
        {"name": "prop_mile_marker", "x": 26.5, "z": -6, "yaw": -90},
    ]
    out += [{"name": "prop_traffic_cone", "x": -46 + 3 * k, "z": -232, "yaw": 0} for k in range(5)]
    return out


def _overpass():
    out = [
        {"name": "env_overpass_span", "x": 0, "z": 60, "yaw": 0, "y": SPAN - 4.5},
        {"name": "env_bridge_bent", "x": -50, "z": 60, "yaw": 0, "y": 0},
        {"name": "env_bridge_bent", "x": 50, "z": 60, "yaw": 0, "y": 0},
        {"name": "env_bridge_bent_low", "x": 0, "z": 60, "yaw": 0, "y": JAM},
    ]
    for s in (-1, 1):
        for k in range(10):
            out.append({"name": "env_parapet_12", "x": -54 + 12 * k, "z": 60 + s * 16.8, "yaw": 0, "y": SPAN})
        for x0 in (-135, 63):  # guardrails on the county road out to x +-135
            for k in range(6):
                out.append({"name": "env_guardrail_12", "x": x0 + 6 + 12 * k, "z": 60 + s * 17.4, "yaw": 0 if s < 0 else 180})
    return out


def _sites():
    out = []
    for z in (151, 167, 183, 199):  # Toll Plaza
        out.append({"name": "env_toll_booth", "x": 165, "z": z, "yaw": 0})
    out += [
        {"name": "env_toll_canopy", "x": 165, "z": 175, "yaw": 0},
        {"name": "env_barrier_jersey", "x": 149, "z": 159, "yaw": 0},
        {"name": "env_barrier_jersey", "x": 149, "z": 191, "yaw": 0},
        {"name": "env_barrier_jersey", "x": 181, "z": 175, "yaw": 0},
        {"name": "prop_generator", "x": 128, "z": 150, "yaw": 0},
        {"name": "prop_light_tower", "x": 128, "z": 205, "yaw": 0},
        {"name": "prop_light_tower", "x": 205, "z": 145, "yaw": 0},
        {"name": "env_water_tower", "x": 185, "z": -125, "yaw": 20},
        # Rest Stop
        {"name": "env_fuel_canopy", "x": -88, "z": -160, "yaw": 0},
        {"name": "env_diner_sign", "x": -112, "z": -212, "yaw": 90},
        {"name": "env_lamp_post", "x": -68.5, "z": -168, "yaw": 180},
        {"name": "env_lamp_post", "x": -68.5, "z": -185, "yaw": 180},
        {"name": "prop_car_sedan", "x": -170, "z": -135, "yaw": 0},
        {"name": "prop_car_hatch", "x": -115, "z": -128, "yaw": 10},
        {"name": "prop_car_pickup", "x": -180, "z": -170, "yaw": 90},
        {"name": "env_box_trailer", "x": -215, "z": -195, "yaw": 90},
        {"name": "env_semi_cab", "x": -215, "z": -226, "yaw": 90},
        {"name": "prop_dumpster", "x": -150, "z": -218, "yaw": 0},
        # the Drop: the bus the drivers went over the rail with
        {"name": "env_bus", "x": -66, "z": -80, "yaw": 80, "roll": 90},
        # the Halt (NW)
        {"name": "env_tent", "x": -160, "z": 200, "yaw": 0},
        {"name": "env_tent", "x": -160, "z": 225, "yaw": 0},
        {"name": "prop_car_sedan", "x": -125, "z": 205, "yaw": 30},
        {"name": "prop_car_hatch", "x": -100, "z": 190, "yaw": -20},
        {"name": "env_dead_tree", "x": -190, "z": 170, "yaw": 0},
        {"name": "env_dead_tree", "x": -90, "z": 240, "yaw": 0},
        {"name": "env_dead_tree", "x": 240, "z": -40, "yaw": 0},
        {"name": "env_dead_tree", "x": 120, "z": -230, "yaw": 0},
    ]
    for x in (-95, -81):
        for z in (-163, -157):
            out.append({"name": "prop_fuel_pump", "x": x, "z": z, "yaw": 90, "y": 0.6})
    for k in range(4):
        out.append({"name": "prop_body_bag", "x": -72 - 2.5 * k, "z": -94 + 3 * k, "yaw": 15 * k})
    return out


def _skyline():
    # The burning city to the north (SkyService does this in game); a few towers for the view.
    out = []
    for k, name in enumerate(("env_city_office", "env_city_residential", "env_city_ruined", "env_city_deco", "env_city_glass", "env_city_midrise")):
        out.append({"name": name, "x": -500 + 200 * k, "z": 760 + 120 * (k % 2), "yaw": 15 * k, "y": 0})
    return out


DRESSING = _jam_vehicles() + _jam_edges() + _overpass() + _sites() + _skyline()


# ------------------------------------------------------------------ scene


def _materials():
    mats = {}
    for kind, rgba in dm.KIND_COLORS.items():
        m = bpy.data.materials.get("m14_" + kind) or bpy.data.materials.new("m14_" + kind)
        m.use_nodes = True
        bsdf = next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
        bsdf.inputs["Base Color"].default_value = rgba
        bsdf.inputs["Roughness"].default_value = 0.95
        m.diffuse_color = rgba
        mats[kind] = m
    grass = bpy.data.materials.get("m14_grass") or bpy.data.materials.new("m14_grass")
    grass.use_nodes = True
    bsdf = next(n for n in grass.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    bsdf.inputs["Base Color"].default_value = (0.20, 0.18, 0.09, 1)  # dead grass, not Delta's dust
    bsdf.inputs["Roughness"].default_value = 1.0
    mats["grass"] = grass
    sign = bpy.data.materials.get("m14_sign") or bpy.data.materials.new("m14_sign")
    sign.use_nodes = True
    bsdf = next(n for n in sign.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    bsdf.inputs["Base Color"].default_value = (0.03, 0.18, 0.08, 1)  # highway sign green
    mats["sign"] = sign
    return mats


def _paint(obj, mat):
    obj.data.materials.clear()
    obj.data.materials.append(mat)


def clear():
    for name in ("Mile14", "M14_Kit"):
        col = bpy.data.collections.get(name)
        if col is None:
            continue
        for child in list(col.children_recursive) + [col]:
            for o in list(child.objects):
                bpy.data.objects.remove(o, do_unlink=True)
        for child in list(col.children_recursive):
            bpy.data.collections.remove(child)
        bpy.data.collections.remove(col)


def build_kit(names, palette_mat):
    """One mesh per kit piece, built from build_assets' builders into a hidden library."""
    lib = dm.collection("M14_Kit")
    lib.hide_render = True
    lib.hide_viewport = True
    meshes = {}
    for name in sorted(names):
        fn, col_name, pivot = ba.ASSETS[name]
        b = ba.Builder()
        fn(b)
        meshes[name] = b.finish(name, lib, palette_mat, pivot=pivot).data
    return meshes


def build(palette_mat=None):
    clear()
    mats = _materials()
    if palette_mat is None:
        palette_mat = ba.build_palette_material(ba.build_palette_image())
    root = dm.collection("Mile14")
    terrain = dm.collection("M14_Terrain", root)
    parts = dm.collection("M14_Parts", root)
    dressing = dm.collection("M14_Dressing", root)

    ground = dm.box("Ground", terrain, "hill", (0, -0.5, 300), (2400, 1, 2400))  # reaches under the skyline
    _paint(ground, mats["grass"])
    for h in HILLS:
        dm.build_hill(h, terrain)
    for o in terrain.objects:
        if o is not ground:
            _paint(o, mats["grass"] if o.name.split("_")[0] in ("JamS", "JamN", "OverpassW", "OverpassE", "TollPlaza", "TowerKnoll") else mats["slope"])
    for name, kind, c, size, yaw in PARTS:
        fn = dm.wedge if "_wedge" in name else dm.box
        _paint(fn(name, parts, kind, c, size, yaw), mats[kind])
    for name, x, y, z in SIGNS:
        _paint(dm.box(name, parts, "steel", (x, y, z), (24, 10, 0.3)), mats["sign"])

    meshes = build_kit({e["name"] for e in DRESSING}, palette_mat)
    for e in DRESSING:
        y = e.get("y")
        if y is None:
            y = dm.ground_height(HILLS, e["x"], e["z"])
        obj = bpy.data.objects.new(e["name"], meshes[e["name"]])
        dressing.objects.link(obj)
        obj.location = dm.rb(e["x"], y, e["z"])
        obj.rotation_euler = (math.radians(e.get("roll") or 0), 0, math.radians(-e["yaw"]))
        if e.get("roll"):
            obj.location.z += meshes[e["name"]].vertices and max(v.co.y for v in meshes[e["name"]].vertices)
    print(f"Mile 14: {len(DRESSING)} placements, {len(meshes)} kit meshes")
    return root


if __name__ == "__main__":
    ba.reset_scene()
    build()
    bpy.ops.wm.save_as_mainfile(filepath=BLEND)
    print(f"saved {BLEND}")
