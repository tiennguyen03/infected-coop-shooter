"""Retarget Mixamo clips onto the Roblox R15 rig, headless.

    "/c/Program Files/Blender Foundation/Blender 5.2/blender.exe" --background \
        --python assets/animations/build/retarget.py [-- clip_name ...]

Reads every FBX in assets/animations/source/mixamo (skeleton-only Mixamo exports, 30 fps,
"In Place" for locomotion) and writes one JSON per clip to src/shared/AnimationClips/ (git-ignored):
Motor6D transforms (joint space, Roblox axes) per keyframe for the 15 R15 limbs. Rojo syncs
that folder to ReplicatedStorage.Shared.AnimationClips (each clip a ModuleScript returning the
table); AnimationBuilder.luau turns a clip into a KeyframeSequence. See assets/animations/README.md.

How the retarget works (no IK, no rest-pose editing):
  * For every Mixamo bone we take its world-space rotation delta from its rest pose, D_b.
  * Mixamo rests in a T-pose, R15 rests with the arms down, so each R15 limb gets a fixed
    rest correspondence A (arms: +-90 degrees about the forward axis; everything else identity).
    The limb's world orientation on the R15 rig is then W = M * D_b * M^T * A, where M maps
    Blender axes (Z up, character facing -Y) to Roblox axes (Y up, character facing -Z).
  * A joint's Transform is W_parent^-1 * W_child; the Root joint also carries the hip
    translation (scaled metres -> studs) so idles bob and deaths drop.
Intermediate Mixamo bones (Spine, Spine1, Shoulder, Neck) fold into the parent/child deltas.
"""
import json
import math
import os
import sys

import bpy
from mathutils import Matrix, Vector

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
SRC = os.path.join(ROOT, "assets", "animations", "source", "mixamo")
OUT = os.path.join(ROOT, "src", "shared", "AnimationClips")  # Rojo: json -> ModuleScript
STUDS_PER_METRE = 5.0 / 1.82  # a 5-stud Chosen vs a 1.82 m Mixamo rig

# Blender (x, y, z) -> Roblox (-x, z, y): Z-up facing -Y becomes Y-up facing -Z.
M = Matrix(((-1, 0, 0), (0, 0, 1), (0, 1, 0)))

# R15 part <- Mixamo bone (without the "mixamorig:" prefix), parent part, rest correspondence.
def rz(deg: float) -> Matrix:
    return Matrix.Rotation(math.radians(deg), 3, "Z")

LIMBS = {
    "LowerTorso": ("Hips", "HumanoidRootPart", Matrix.Identity(3)),
    "UpperTorso": ("Spine2", "LowerTorso", Matrix.Identity(3)),
    "Head": ("Head", "UpperTorso", Matrix.Identity(3)),
    "LeftUpperArm": ("LeftArm", "UpperTorso", rz(-90)),
    "LeftLowerArm": ("LeftForeArm", "LeftUpperArm", rz(-90)),
    "LeftHand": ("LeftHand", "LeftLowerArm", rz(-90)),
    "RightUpperArm": ("RightArm", "UpperTorso", rz(90)),
    "RightLowerArm": ("RightForeArm", "RightUpperArm", rz(90)),
    "RightHand": ("RightHand", "RightLowerArm", rz(90)),
    "LeftUpperLeg": ("LeftUpLeg", "LowerTorso", Matrix.Identity(3)),
    "LeftLowerLeg": ("LeftLeg", "LeftUpperLeg", Matrix.Identity(3)),
    "LeftFoot": ("LeftFoot", "LeftLowerLeg", Matrix.Identity(3)),
    "RightUpperLeg": ("RightUpLeg", "LowerTorso", Matrix.Identity(3)),
    "RightLowerLeg": ("RightLeg", "RightUpperLeg", Matrix.Identity(3)),
    "RightFoot": ("RightFoot", "RightLowerLeg", Matrix.Identity(3)),
}
# Parts in parent-before-child order so W_parent exists when a child is computed.
ORDER = [
    "LowerTorso", "UpperTorso", "Head",
    "LeftUpperArm", "LeftLowerArm", "LeftHand",
    "RightUpperArm", "RightLowerArm", "RightHand",
    "LeftUpperLeg", "LeftLowerLeg", "LeftFoot",
    "RightUpperLeg", "RightLowerLeg", "RightFoot",
]

# Per-clip settings: loop, keyframe step (1 = every frame at 30 fps), upper = upper-body
# overlay (the builder gives hips and legs zero weight so a locomotion clip shows through).
CLIPS = {
    "rifle_idle": {"loop": True, "step": 2},
    "rifle_walk": {"loop": True, "step": 1},
    "rifle_run": {"loop": True, "step": 1},
    "rifle_aiming_idle": {"loop": True, "step": 2, "upper": True},
    "firing_rifle": {"loop": False, "step": 1, "upper": True},
    "hit_reaction": {"loop": False, "step": 1, "upper": True},
    "zombie_hit": {"loop": False, "step": 1, "upper": True},  # Zombie Reaction Hit: the Infected flinch (satisfying pass)
    "rifle_reload": {"loop": False, "step": 1, "upper": True},  # Reloading (rifle, standing): R, rate fitted to the gun's ReloadTime
    "death_from_the_front": {"loop": False, "step": 2},
    "grenade_throw": {"loop": False, "step": 1, "upper": True},
    "zombie_idle": {"loop": True, "step": 2},
    "zombie_walk": {"loop": True, "step": 1},
    "zombie_running": {"loop": True, "step": 1},
    "zombie_attack": {"loop": False, "step": 1},
    "zombie_death": {"loop": False, "step": 2},
    "mutant_walking": {"loop": True, "step": 1},
    "mutant_swiping": {"loop": False, "step": 1},
    # Rifle 8-Way Locomotion Pack (walk / sprint, four directions): root motion is baked
    # in, so `in_place` strips the horizontal hip travel and reports the ground speed the
    # clip was authored at (-> Config.Animations.MoveClipSpeed).
    "loco_walk_f": {"loop": True, "step": 1, "in_place": True},
    "loco_walk_b": {"loop": True, "step": 1, "in_place": True},
    "loco_walk_l": {"loop": True, "step": 1, "in_place": True},
    "loco_walk_r": {"loop": True, "step": 1, "in_place": True},
    "loco_run_f": {"loop": True, "step": 1, "in_place": True},
    "loco_run_b": {"loop": True, "step": 1, "in_place": True},
    "loco_run_l": {"loop": True, "step": 1, "in_place": True},
    "loco_run_r": {"loop": True, "step": 1, "in_place": True},
    # Movement set (2026-11-07). Climb clips: `root_lock` drops every hip translation; the
    # game moves the root along the climb itself (client StanceController / MovementController,
    # server EnemyService) and reports the clip's hip rise and reach for tuning.
    "vault_low": {"loop": False, "step": 1, "root_lock": True},  # players over jersey / hesco
    "climb_ledge": {"loop": False, "step": 1, "root_lock": True},  # players onto bunker / container
    "climb_low": {"loop": False, "step": 1, "root_lock": True},  # Walkers / Runners over hesco
    "climb_high": {"loop": False, "step": 1, "root_lock": True},  # Runners onto containers
    # Sprint-roll and slide (2026-11-07): the hip drop to the ground stays (vertical), the
    # horizontal travel is stripped; the game carries the body (client MovementController).
    "sprint_roll": {"loop": False, "step": 1, "in_place": True},
    "running_slide": {"loop": False, "step": 1, "in_place": True},
    # Downed (Squad): crawl on hands and knees while waiting for a revive (2026-11-07).
    "downed_crawl": {"loop": True, "step": 1, "in_place": True},
    # Crouch: hip drop stays (vertical), horizontal travel stripped.
    "crouch_idle": {"loop": True, "step": 2, "in_place": True},
    "crouch_enter": {"loop": False, "step": 1, "in_place": True},
    "crouch_exit": {"loop": False, "step": 1, "in_place": True},
    "crouch_aim": {"loop": True, "step": 2, "in_place": True, "upper": True},
    "crouch_walk_f": {"loop": True, "step": 1, "in_place": True},
    "crouch_walk_b": {"loop": True, "step": 1, "in_place": True},
    "crouch_walk_l": {"loop": True, "step": 1, "in_place": True},
    "crouch_walk_r": {"loop": True, "step": 1, "in_place": True},
    # Prone: the hips drop to the ground inside the clip (the root part stays at hip height).
    "prone_idle": {"loop": True, "step": 2, "in_place": True},
    "prone_enter": {"loop": False, "step": 1, "in_place": True},
    "prone_exit": {"loop": False, "step": 1, "in_place": True},
    "prone_fire": {"loop": True, "step": 2, "in_place": True, "upper": True},
    "prone_walk_f": {"loop": True, "step": 1, "in_place": True},
    "prone_walk_b": {"loop": True, "step": 1, "in_place": True},
    # Infected extras for later: Crawler move, flinch, Hocker windup.
    "zombie_crawl": {"loop": True, "step": 1, "in_place": True},
    "zombie_stumble": {"loop": False, "step": 1, "in_place": True},
    "zombie_scream": {"loop": False, "step": 1, "in_place": True},
    # The Warden (2026-11-07): Mixamo Sword And Shield pack, shield on the left arm like his.
    # Walk / run in place (locomotion), the rest keep their hip motion; guard and idle loop.
    "warden_walk": {"loop": True, "step": 1, "in_place": True},
    "warden_run": {"loop": True, "step": 1, "in_place": True},
    "warden_idle": {"loop": True, "step": 2},
    "warden_guard": {"loop": True, "step": 2, "upper": True},  # Sword And Shield Block Idle: shield up, the walk shows through the legs
    "warden_bash": {"loop": False, "step": 1},  # Sword And Shield Power Slash
    "warden_riot": {"loop": False, "step": 1},  # Sword And Shield Power Up
    "warden_death": {"loop": False, "step": 2},  # Sword And Shield Falling Forward Death
    # Kit expansion (2026-11-07): the new attacks and his flinch, all in place so he never
    # drifts off his root while he swings.
    "warden_pound": {"loop": False, "step": 1, "in_place": True},  # Sword And Shield Jump Attack: the Ground Pound
    "warden_sweep": {"loop": False, "step": 1, "in_place": True},  # Sword And Shield Cross Slash: the Shield Sweep
    "warden_slam": {"loop": False, "step": 1, "in_place": True},  # Sword And Shield Downward Slash: the Overhead Slam
    "warden_stomp": {"loop": False, "step": 1, "in_place": True},  # Stomp (Hard Floor Stomp)
    "warden_hit": {"loop": False, "step": 1, "in_place": True},  # Sword And Shield Impact (head): a plate coming off
    # Player knockdown (the Pound and the Stomp): the fall and the get-up, trimmed to the
    # part that moves (`trim` = fractions of the clip kept); hips keep their drop.
    "knockdown_back": {"loop": False, "step": 1, "in_place": True, "trim": (0.0, 0.45)},  # Knocked Out (falling to back)
    "getup_back": {"loop": False, "step": 1, "in_place": True, "trim": (0.55, 1.0)},  # Getting Up (from back)
}


def load(path: str):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.fbx(filepath=path)
    arm = next(o for o in bpy.data.objects if o.type == "ARMATURE")
    bones = {b.name.split(":")[-1]: b.name for b in arm.data.bones}
    return arm, bones


def world_rotation(arm, pose_bone) -> Matrix:
    return (arm.matrix_world @ pose_bone.matrix).to_3x3().normalized()


def rest_rotation(arm, bone) -> Matrix:
    return (arm.matrix_world @ bone.matrix_local).to_3x3().normalized()


def to_cframe_values(rot: Matrix, pos: Vector):
    q = rot.to_quaternion()
    return [round(pos.x, 4), round(pos.y, 4), round(pos.z, 4),
            round(q.x, 5), round(q.y, 5), round(q.z, 5), round(q.w, 5)]


def retarget(name: str, cfg: dict):
    arm, bones = load(os.path.join(SRC, name + ".fbx"))
    scene = bpy.context.scene
    fps = scene.render.fps
    action = arm.animation_data.action
    f0, f1 = (int(round(v)) for v in action.frame_range)
    trim = cfg.get("trim")
    if trim:  # keep a fraction of the clip (start, end), e.g. the fall without the lying still
        span = f1 - f0
        f0, f1 = f0 + int(round(span * trim[0])), f0 + int(round(span * trim[1]))
    rest = {part: rest_rotation(arm, arm.data.bones[bones[bone]]) for part, (bone, _, _) in LIMBS.items()}
    hips_rest = (arm.matrix_world @ arm.data.bones[bones["Hips"]].head_local).copy()

    keyframes = []
    frames = list(range(f0, f1 + 1, cfg["step"]))
    if frames[-1] != f1:
        frames.append(f1)
    in_place = bool(cfg.get("in_place", False))
    root_lock = bool(cfg.get("root_lock", False))
    hips_bone = arm.pose.bones[bones["Hips"]]
    scene.frame_set(f0)
    hips_start = (arm.matrix_world @ hips_bone.head).copy()
    scene.frame_set(f1)
    hips_end = (arm.matrix_world @ hips_bone.head).copy()
    travel = M @ (hips_end - hips_start)
    ground_speed = Vector((travel.x, 0, travel.z)).length * STUDS_PER_METRE * fps / max(1, f1 - f0)
    rise = travel.y * STUDS_PER_METRE
    reach = Vector((travel.x, 0, travel.z)).length * STUDS_PER_METRE
    for f in frames:
        scene.frame_set(f)
        world = {"HumanoidRootPart": Matrix.Identity(3)}
        poses = {}
        for part in ORDER:
            bone, parent, A = LIMBS[part]
            pb = arm.pose.bones[bones[bone]]
            delta = world_rotation(arm, pb) @ rest[part].transposed()
            W = M @ delta @ M.transposed() @ A
            world[part] = W
            transform = world[parent].transposed() @ W
            pos = Vector((0, 0, 0))
            if part == "LowerTorso":
                hips = arm.matrix_world @ pb.head
                pos = (M @ (hips - hips_rest)) * STUDS_PER_METRE
                if root_lock:
                    pos = Vector((0, 0, 0))
                elif in_place:
                    pos = Vector((0, pos.y, 0))
            poses[part] = to_cframe_values(transform, pos)
        keyframes.append({"t": round((f - f0) / fps, 4), "poses": poses})

    clip = {
        "name": name,
        "fps": fps,
        "loop": cfg["loop"],
        "upperBody": bool(cfg.get("upper", False)),
        "duration": round((f1 - f0) / fps, 4),
        "groundSpeed": round(ground_speed, 2),
        "keyframes": keyframes,
    }
    os.makedirs(OUT, exist_ok=True)
    with open(os.path.join(OUT, name + ".json"), "w", encoding="utf-8", newline="\n") as fh:
        json.dump(clip, fh, separators=(",", ":"))
    print(f"{name}: {len(keyframes)} keyframes, {clip['duration']} s, loop={cfg['loop']}, "
          f"ground speed {ground_speed:.1f} studs/s{' (stripped)' if in_place else ''}"
          + (f", hips rise {rise:.1f} reach {reach:.1f} studs (root locked)" if root_lock else ""))


def main():
    wanted = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    for name, cfg in CLIPS.items():
        if wanted and name not in wanted:
            continue
        if not os.path.exists(os.path.join(SRC, name + ".fbx")):
            print(f"{name}: missing source, skipped")
            continue
        retarget(name, cfg)


main()
