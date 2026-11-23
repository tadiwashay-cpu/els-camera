"""Builds assets/fighters/fp_weapon.glb (+ .json): the first-person weapon
moves from fp_moves.py, keyed on one empty called "FP" in Blender and
exported as one animation per move. The game samples them for the floating
weapon in first person (src/fighter/fp_view_model.gd).

    python tools/blender/build_fp.py       (Blender 5.3 as a module)

Two empties are keyed: "FP" moves (the grip offset) and "Aim" (its
location channels carry the aim offsets yaw, pitch, roll in radians, so the
game can add them to a family's rest aim; see fp_moves.py). Both are
written in Godot camera space converted to Blender's Z-up (the GLB comes
back out in Godot space). One second of animation per move: t 0..1 is the
whole move; the game stretches it over the real move.
"""

import json
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import bpy  # noqa: E402
from mathutils import Matrix, Vector  # noqa: E402

from fp_moves import FP_MOVES  # noqa: E402

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT_GLB = os.path.join(ROOT, "assets", "fighters", "fp_weapon.glb")
OUT_JSON = os.path.join(ROOT, "assets", "fighters", "fp_weapon.json")
FPS = 60

# Godot (y up) -> Blender (z up): a +90 degree turn about X.
C = Matrix.Rotation(math.radians(90.0), 4, "X")


def build():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    scene.render.fps = FPS
    scene.frame_start = 0
    scene.frame_end = FPS
    grip = bpy.data.objects.new("FP", None)
    aim = bpy.data.objects.new("Aim", None)
    for ob in (grip, aim):
        scene.collection.objects.link(ob)
        ob.animation_data_create()
    info = {}
    for name, mv in FP_MOVES.items():
        for ob in (grip, aim):
            act = bpy.data.actions.new(name)
            ob.animation_data.action = act
            for t, pos, ang in mv["keys"]:
                value = pos if ob is grip else [math.radians(a) for a in ang]
                ob.location = C @ Vector(value)
                ob.keyframe_insert("location", frame=round(t * FPS))
            act.use_fake_user = True
            track = ob.animation_data.nla_tracks.new()
            track.name = name
            track.strips.new(name, 0, act)
            ob.animation_data.action = None
        info[name] = {"loop": mv["loop"], "strike": mv["strike"]}
    os.makedirs(os.path.dirname(OUT_GLB), exist_ok=True)
    bpy.ops.export_scene.gltf(filepath=OUT_GLB, export_format="GLB", export_animations=True,
                              export_animation_mode="NLA_TRACKS", export_force_sampling=True, export_frame_range=False,
                              export_yup=True, export_materials="NONE")
    with open(OUT_JSON, "w") as fh:
        json.dump({"fps": FPS, "moves": info}, fh, indent=1, sort_keys=True)
    print("wrote", OUT_GLB, len(info), "moves")


if __name__ == "__main__":
    build()
