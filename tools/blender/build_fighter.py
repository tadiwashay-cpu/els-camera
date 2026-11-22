"""Builds assets/fighters/block_fighter.glb (+ .moves.json) from the rig and move set.

Run with Blender 5.3 as a Python module (pip install bpy==5.3.0):
    python tools/blender/build_fighter.py [--only Slash_A,Run]
or with a Blender install:
    blender -b -P tools/blender/build_fighter.py

The GLB holds the skeleton, a preview block mesh (the game builds its own
skinned mesh from SkinData) and one animation per move.
"""

import json
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import bpy  # noqa: E402
from mathutils import Vector  # noqa: E402

import rigkit  # noqa: E402
from moves import MOVES  # noqa: E402

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT_GLB = os.path.join(ROOT, "assets", "fighters", "block_fighter.glb")
OUT_JSON = os.path.join(ROOT, "assets", "fighters", "block_fighter.moves.json")

# Preview body: bone, size (x, y, z), centre in rest armature space.
PARTS = [
    ("Hips", (0.34, 0.22, 0.16), (0, 0, 0.98)),
    ("Spine", (0.32, 0.2, 0.14), (0, 0, 1.13)),
    ("Chest", (0.38, 0.23, 0.16), (0, 0, 1.27)),
    ("UpperChest", (0.44, 0.25, 0.16), (0, 0, 1.40)),
    ("Neck", (0.1, 0.1, 0.1), (0, 0, 1.52)),
    ("Head", (0.3, 0.3, 0.3), (0, -0.01, 1.72)),
    ("LeftUpperArm", (0.26, 0.11, 0.11), (0.32, 0, 1.44)),
    ("LeftLowerArm", (0.25, 0.1, 0.1), (0.59, 0, 1.44)),
    ("LeftHand", (0.11, 0.1, 0.1), (0.78, 0, 1.44)),
    ("RightUpperArm", (0.26, 0.11, 0.11), (-0.32, 0, 1.44)),
    ("RightLowerArm", (0.25, 0.1, 0.1), (-0.59, 0, 1.44)),
    ("RightHand", (0.11, 0.1, 0.1), (-0.78, 0, 1.44)),
    ("LeftUpperLeg", (0.14, 0.14, 0.42), (0.11, 0, 0.73)),
    ("LeftLowerLeg", (0.12, 0.12, 0.42), (0.11, 0, 0.31)),
    ("LeftFoot", (0.12, 0.22, 0.08), (0.11, -0.05, 0.05)),
    ("RightUpperLeg", (0.14, 0.14, 0.42), (-0.11, 0, 0.73)),
    ("RightLowerLeg", (0.12, 0.12, 0.42), (-0.11, 0, 0.31)),
    ("RightFoot", (0.12, 0.22, 0.08), (-0.11, -0.05, 0.05)),
]


def build_armature():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    scene.render.fps = rigkit.FPS
    data = bpy.data.armatures.new("FighterRig")
    obj = bpy.data.objects.new("Fighter", data)
    scene.collection.objects.link(obj)
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    bpy.ops.object.mode_set(mode="EDIT")
    for name, parent, head, tail, z_hint in rigkit.BONES:
        eb = data.edit_bones.new(name)
        eb.head = head
        eb.tail = tail
        eb.align_roll(Vector(z_hint))
        if parent:
            eb.parent = data.edit_bones[parent]
            eb.use_connect = False
        eb.use_deform = name not in ("Root", "WeaponR", "WeaponL")
    bpy.ops.object.mode_set(mode="OBJECT")
    return obj


def build_preview_mesh(arm_obj):
    verts, faces, groups = [], [], []
    for bone, size, centre in PARTS:
        sx, sy, sz = (s * 0.5 for s in size)
        cx, cy, cz = centre
        base = len(verts)
        for dx in (-sx, sx):
            for dy in (-sy, sy):
                for dz in (-sz, sz):
                    verts.append((cx + dx, cy + dy, cz + dz))
        for f in ((0, 1, 3, 2), (4, 6, 7, 5), (0, 4, 5, 1), (2, 3, 7, 6), (0, 2, 6, 4), (1, 5, 7, 3)):
            faces.append(tuple(base + i for i in f))
        groups.append((bone, range(base, base + 8)))
    mesh = bpy.data.meshes.new("BlockPreview")
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    obj = bpy.data.objects.new("BlockPreview", mesh)
    bpy.context.scene.collection.objects.link(obj)
    for bone, idx in groups:
        vg = obj.vertex_groups.new(name=bone)
        vg.add(list(idx), 1.0, "REPLACE")
    mod = obj.modifiers.new("Armature", "ARMATURE")
    mod.object = arm_obj
    obj.parent = arm_obj
    return obj


def bake(arm_obj, only=None):
    rig = rigkit.Rig(arm_obj)
    arm_obj.animation_data_create()
    for pb in arm_obj.pose.bones:
        pb.rotation_mode = "QUATERNION"
    meta = {}
    for name, mv in MOVES.items():
        if only and name not in only:
            continue
        action = bpy.data.actions.new(name)
        action.use_fake_user = True
        arm_obj.animation_data.action = action
        frames = max(1, round(mv["length"] * rigkit.FPS))
        prev = {}
        for f in range(frames + 1):
            t = min(f / rigkit.FPS, mv["length"])
            if mv["loop"] and f == frames:
                t = 0.0     # close the loop exactly
            pose = rig.basis(rig.solve(mv["fn"](t)))
            for bone, (loc, rot) in pose.items():
                if bone in ("Root", "WeaponR", "WeaponL"):
                    continue
                if bone in prev and prev[bone].dot(rot) < 0.0:
                    rot.negate()
                prev[bone] = rot.copy()
                pb = arm_obj.pose.bones[bone]
                pb.rotation_quaternion = rot
                pb.keyframe_insert("rotation_quaternion", frame=f, group=bone)
                if bone == "Hips":
                    pb.location = loc
                    pb.keyframe_insert("location", frame=f, group=bone)
        action.frame_range = (0, frames)
        action.use_frame_range = True
        meta[name] = {"length": round(frames / rigkit.FPS, 4), "loop": mv["loop"], "events": mv["events"], "speed": mv["speed"]}
        print("baked %-16s %3d frames" % (name, frames + 1))
    # rest pose for the file itself
    arm_obj.animation_data.action = None
    for pb in arm_obj.pose.bones:
        pb.rotation_quaternion = (1, 0, 0, 0)
        pb.location = (0, 0, 0)
    return meta


def export(path):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    bpy.ops.export_scene.gltf(
        filepath=path,
        export_format="GLB",
        export_animations=True,
        export_animation_mode="ACTIONS",
        export_force_sampling=True,
        export_frame_range=True,
        export_anim_single_armature=True,
        export_reset_pose_bones=True,
        export_def_bones=False,
        export_yup=True,
        export_apply=False,
        export_materials="NONE",
        export_morph=False,
    )


def main():
    only = None
    if "--only" in sys.argv:
        only = set(sys.argv[sys.argv.index("--only") + 1].split(","))
    arm = build_armature()
    build_preview_mesh(arm)
    meta = bake(arm, only)
    export(OUT_GLB)
    with open(OUT_JSON, "w") as fh:
        json.dump({"fps": rigkit.FPS, "moves": meta}, fh, indent=1, sort_keys=True)
    print("wrote", OUT_GLB, os.path.getsize(OUT_GLB), "bytes;", len(meta), "moves")


main()
