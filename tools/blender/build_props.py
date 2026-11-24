"""Builds assets/props/props.glb: the organic scenery the arenas scatter
(0.8): palm trees, faceted rocks, bushes, driftwood, beach grass, starfish.

    python tools/blender/build_props.py          (Blender 5.3 as a module)

Modelled in code with the weapon kit (weapon_kit.py) in Godot's space: Y up,
metres, the prop standing on its origin. Colours are per corner (toon-lit
in the game by src/shaders/toon_vertex.gdshader); low-poly and faceted so
they sit with the block fighters. One mesh per prop id; src/arenas/props.gd
loads them and draws each kind as one MultiMesh.
"""

import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import bpy  # noqa: E402  (first: it makes bmesh importable)
import bmesh  # noqa: E402,I001
from mathutils import Matrix, Vector  # noqa: E402

from weapon_kit import T, Builder  # noqa: E402

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "assets", "props", "props.glb")
MAX_TRIS = 1600

BARK = (0.55, 0.42, 0.28)
BARK_DARK = (0.42, 0.31, 0.2)
LEAF = (0.22, 0.62, 0.24)
LEAF_DARK = (0.14, 0.45, 0.18)
COCONUT = (0.42, 0.3, 0.16)
ROCK = (0.56, 0.54, 0.5)
ROCK_DARK = (0.4, 0.39, 0.37)
SAND_DUST = (0.86, 0.78, 0.58)
MOSS = (0.36, 0.5, 0.26)
DRIFT = (0.66, 0.6, 0.52)
GRASS = (0.55, 0.62, 0.3)
GRASS_DRY = (0.74, 0.7, 0.42)
STAR = (0.95, 0.45, 0.2)


# --------------------------------------------------------------- helpers

def blob(b, radius, color, m=Matrix(), rough=0.25, subdiv=1, seed=0, flat_top=0.0, top_color=None, squash=(1, 1, 1)):
    """A faceted lump: an icosphere pushed in and out at random. With
    `top_color`, faces looking up take that colour (sand dust, moss)."""
    rnd = random.Random(seed)
    before = b._start()
    res = bmesh.ops.create_icosphere(b.bm, subdivisions=subdiv, radius=radius)
    verts = res["verts"]
    for v in verts:
        d = v.co.normalized()
        k = 1.0 + rnd.uniform(-rough, rough)
        p = Vector((d.x * squash[0], d.y * squash[1], d.z * squash[2])) * radius * k
        if flat_top > 0.0 and p.y > radius * squash[1] * (1.0 - flat_top):
            p.y = radius * squash[1] * (1.0 - flat_top)
        v.co = m @ p
    faces = b._finish(before, color, smooth=False)
    if top_color is not None:
        bmesh.ops.recalc_face_normals(b.bm, faces=faces)
        for f in faces:
            f.normal_update()
            if f.normal.y > 0.62:   # Y up in prop space
                for loop in f.loops:
                    loop[b.col] = (top_color[0], top_color[1], top_color[2], 1.0)
    return faces


def leaf(b, length, width, color, m, droop=0.5, segs=4):
    """A palm frond: a tapered strip bending down along its length."""
    pts_l, pts_r = [], []
    for i in range(segs + 1):
        u = i / segs
        w = width * math.sin(math.pi * min(u * 1.15, 1.0)) * 0.5 + 0.02
        z = u * length
        y = -droop * (u ** 2) * length
        pts_l.append(m @ Vector((-w, y, z)))
        pts_r.append(m @ Vector((w, y + w * 0.25, z)))
    before = b._start()
    vl = [b.bm.verts.new(p) for p in pts_l]
    vr = [b.bm.verts.new(p) for p in pts_r]
    for i in range(segs):
        b._face([vl[i], vr[i], vr[i + 1], vl[i + 1]])      # one face: the props shader draws both sides
    return b._finish(before, color, smooth=False)


def palm(b, seed, height=6.0, lean=0.18):
    rnd = random.Random(seed)
    side = rnd.uniform(0, math.tau)
    pts = []
    for i in range(6):
        u = i / 5
        off = lean * height * (u ** 1.6)
        pts.append((math.cos(side) * off, u * height, math.sin(side) * off))
    # Trunk: rings of bark, thinner towards the top.
    for i in range(5):
        a, c = Vector(pts[i]), Vector(pts[i + 1])
        r0 = 0.24 - 0.025 * i
        b.tube([tuple(a), tuple(c)], r0, BARK if i % 2 == 0 else BARK_DARK, segs=8, caps=False, smooth=False)
        b.torus(r0 + 0.015, 0.03, BARK_DARK, T(tuple(c), (90, 0, 0)), segs=8, tube_segs=3, smooth=False)
    top = Vector(pts[-1])
    # Crown: fronds all round, coconuts underneath.
    n = 8
    for k in range(n):
        yaw = k * (360.0 / n) + rnd.uniform(-12, 12)
        rise = rnd.uniform(15, 35)
        m = (Matrix.Translation(top) @ Matrix.Rotation(math.radians(yaw), 4, "Y")
             @ Matrix.Rotation(math.radians(-rise), 4, "X"))
        leaf(b, rnd.uniform(2.4, 3.0), rnd.uniform(0.7, 0.9), LEAF if k % 2 == 0 else LEAF_DARK, m, droop=rnd.uniform(0.35, 0.55))
    for k in range(3):
        a = k * 2.1 + rnd.uniform(0, 0.4)
        b.sphere(0.13, COCONUT, T(tuple(top + Vector((math.cos(a) * 0.2, -0.15, math.sin(a) * 0.2)))), segs=6, rings=4, smooth=False)


def rock(b, seed, size, squash):
    blob(b, size, ROCK, rough=0.22, subdiv=2, seed=seed, squash=squash, top_color=SAND_DUST, m=T((0, size * squash[1] * 0.55, 0)))


def bush(b, seed):
    rnd = random.Random(seed)
    for k in range(6):
        a = rnd.uniform(0, math.tau)
        r = rnd.uniform(0.0, 0.45)
        s = rnd.uniform(0.35, 0.55)
        blob(b, s, LEAF if k % 2 else LEAF_DARK, T((math.cos(a) * r, s * 0.75 + rnd.uniform(0, 0.2), math.sin(a) * r)),
             rough=0.18, subdiv=1, seed=seed * 10 + k)


def driftwood(b, seed):
    rnd = random.Random(seed)
    pts = [(-1.4, 0.12, 0.0), (-0.5, 0.18, 0.15), (0.4, 0.14, -0.1), (1.3, 0.1, 0.12)]
    b.tube(pts, 0.13, DRIFT, segs=7, subdiv=2, smooth=False)
    b.tube([(0.2, 0.15, -0.05), (0.6, 0.35, -0.45), (0.8, 0.5, -0.7)], 0.06, DRIFT, segs=6, subdiv=1, smooth=False)
    b.tube([(-0.8, 0.15, 0.1), (-1.0, 0.3, 0.5)], 0.05, DRIFT, segs=6, smooth=False)
    blob(b, 0.22, DRIFT, T((-1.45, 0.14, 0.0)), rough=0.3, subdiv=1, seed=seed)


def grass(b, seed, dry=False):
    rnd = random.Random(seed)
    for k in range(9):
        a = rnd.uniform(0, math.tau)
        h = rnd.uniform(0.45, 0.85)
        tilt = rnd.uniform(10, 32)
        m = T((math.cos(a) * 0.08, 0.0, math.sin(a) * 0.08), (0.0, -math.degrees(a), 0.0)) @ T(rot=(0.0, 0.0, -tilt))
        col = GRASS_DRY if (dry or k % 3 == 0) else GRASS
        b.slab([(-0.035, 0.0), (0.035, 0.0), (0.0, h)], 0.01, col, m)


def starfish(b, seed):
    pts = []
    for k in range(10):
        a = math.pi * 0.5 + k * math.pi / 5
        r = 0.2 if k % 2 == 0 else 0.08
        pts.append((math.cos(a) * r, math.sin(a) * r))
    b.slab(pts, 0.03, STAR, T((0, 0.02, 0), (90, 0, 0)), bevel=0.01)


PROPS = {
    "palm_a": lambda b: palm(b, 1, 6.2, 0.18),
    "palm_b": lambda b: palm(b, 7, 5.2, 0.28),
    "palm_c": lambda b: palm(b, 13, 7.0, 0.1),
    "rock_a": lambda b: rock(b, 3, 1.0, (1.2, 0.8, 1.0)),
    "rock_b": lambda b: rock(b, 5, 1.0, (1.0, 1.1, 0.9)),
    "rock_c": lambda b: rock(b, 9, 1.0, (1.5, 0.55, 1.1)),
    "rock_d": lambda b: rock(b, 21, 1.0, (0.8, 1.4, 0.8)),
    "bush": lambda b: bush(b, 4),
    "driftwood": lambda b: driftwood(b, 2),
    "grass": lambda b: grass(b, 6),
    "grass_dry": lambda b: grass(b, 8, True),
    "starfish": lambda b: starfish(b, 1),
}


def build():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    to_blender = Matrix.Rotation(math.radians(90), 4, "X")     # Godot (x, y, z) -> Blender (x, -z, y)
    total = 0
    for pid, design in PROPS.items():
        b = Builder()
        design(b)
        tris = b.tri_count()
        total += tris
        if tris > MAX_TRIS:
            raise SystemExit("%s: %d triangles (budget %d)" % (pid, tris, MAX_TRIS))
        b.bm.transform(to_blender)
        bmesh.ops.recalc_face_normals(b.bm, faces=list(b.bm.faces))
        me = bpy.data.meshes.new(pid)
        b.bm.to_mesh(me)
        b.bm.free()
        attr = me.color_attributes.get("Col")
        if attr is not None:
            me.color_attributes.active_color = attr
        ob = bpy.data.objects.new(pid, me)
        bpy.context.scene.collection.objects.link(ob)
        print("%-10s %5d tris" % (pid, tris))
    print("total %d tris, %d props" % (total, len(PROPS)))
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    bpy.ops.export_scene.gltf(filepath=OUT, export_format="GLB", export_materials="NONE", export_vertex_color="ACTIVE",
                              export_yup=True, export_apply=False, export_texcoords=False, export_normals=True)
    print("wrote", OUT)


if __name__ == "__main__":
    build()
