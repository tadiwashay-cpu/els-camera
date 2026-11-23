"""Builds assets/weapons/weapon_models.glb: a smooth, curved model for every
weapon (one mesh object per weapon id), from the designs below.

Run with Blender 5.3 as a Python module (pip install bpy==5.3.0):
    python tools/blender/build_weapons.py [--only sword,katana]
or with a Blender install:
    blender -b -P tools/blender/build_weapons.py

Models are in socket space (see weapon_kit.py): the grip at the origin, +Y
towards the tip, X the blade's width, Z its thickness; ranged weapons point
+Y with the grip hanging towards -Z. The sizes follow the weapons' hit
ranges in tools/gen_weapons.py. A colour's alpha is its finish: 1 matte,
0.5 metal, 0 glow (src/weapons/weapon.gdshader). The game falls back to the
box parts in gen_weapons.py for any weapon without a model here.
"""

import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import bpy  # noqa: E402
from mathutils import Matrix, Vector  # noqa: E402

from weapon_kit import Builder, T, arc  # noqa: E402

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "assets", "weapons", "weapon_models.glb")
MAX_TRIS = 2400

M, G = 0.5, 0.0
WOOD = (0.45, 0.3, 0.16)
DARKWOOD = (0.28, 0.18, 0.1)
LEATHER = (0.3, 0.17, 0.08)
WRAP = (0.16, 0.11, 0.08)
DARK = (0.18, 0.15, 0.13)
BLACK = (0.08, 0.08, 0.09)
WHITE = (0.95, 0.95, 0.95)
RED = (0.82, 0.14, 0.12)
BLUE = (0.18, 0.38, 0.85)
STEEL = (0.84, 0.87, 0.92, M)
STEEL_D = (0.58, 0.62, 0.68, M)
IRON = (0.34, 0.36, 0.4, M)
GUNMETAL = (0.26, 0.28, 0.32, M)
GOLD = (0.95, 0.72, 0.25, M)
BRASS = (0.8, 0.6, 0.28, M)
ROPE = (0.75, 0.65, 0.45)
ORANGE = (1.0, 0.5, 0.1)

# Turns: local Y onto socket Z (a disc facing +Z), onto socket X, and a side
# profile (outline (x, y) with x = -socket z) lying in the YZ plane.
TO_Z = (90, 0, 0)
TO_NZ = (-90, 0, 0)
TO_X = (0, 0, -90)
TO_NX = (0, 0, 90)
SIDE = T(rot=(0, 90, 0))


def side(pts):
    """Side-profile points given as (z, y) -> outline for `SIDE`."""
    return [(-z, y) for z, y in pts]


def mirror_x(pts):
    return [(-x, y) for x, y in pts]


def align(d, loc=(0, 0, 0), scale=1.0):
    """A transform turning local +Y towards direction `d`, placed at `loc`."""
    q = Vector((0, 1, 0)).rotation_difference(Vector(d).normalized())
    m = Matrix.Translation(Vector(loc)) @ q.to_matrix().to_4x4()
    return m @ Matrix.Scale(scale, 4) if scale != 1.0 else m


def ribbon(pts, widths, cap=4):
    """An outline around a 2D centreline with round ends (boomerangs, arms)."""
    P = [Vector(p) for p in pts]
    n = len(P)
    W = widths if isinstance(widths, (list, tuple)) else [widths] * n
    left, right, dirs = [], [], []
    for i in range(n):
        d = (P[min(i + 1, n - 1)] - P[max(i - 1, 0)]).normalized()
        nrm = Vector((-d.y, d.x))
        left.append(P[i] + nrm * W[i] * 0.5)
        right.append(P[i] - nrm * W[i] * 0.5)
        dirs.append((d, nrm))
    d, nrm = dirs[-1]
    end = [P[-1] + (nrm * math.cos(math.pi * k / cap) + d * math.sin(math.pi * k / cap)) * W[-1] * 0.5 for k in range(1, cap)]
    d, nrm = dirs[0]
    start = [P[0] + (-nrm * math.cos(math.pi * k / cap) - d * math.sin(math.pi * k / cap)) * W[0] * 0.5 for k in range(1, cap)]
    return [tuple(v) for v in left + end + list(reversed(right)) + start]


def grip(b, y0, y1, r, col, segs=12):
    """A handle along Y with a slight swell."""
    b.lathe([(0, y0), (r * 0.94, y0, "S"), (r, (y0 + y1) * 0.5), (r * 0.94, y1, "S"), (0, y1)], col, segs=segs)


def ring(b, y, R, r, col, segs=14, x=0.0, z=0.0):
    """A collar round the Y axis."""
    b.torus(R, r, col, T((x, y, z), TO_Z), segs, 6)


def wraps(b, y0, y1, n, R, col, r=0.005):
    for i in range(n):
        ring(b, y0 + (y1 - y0) * i / max(n - 1, 1), R, r, col, 12)


def knob(b, y, r, col, down=True):
    """A rounded pommel or end cap at `y` (below it when `down`)."""
    s = -1 if down else 1
    b.sphere(r, col, T((0, y + s * r * 0.6, 0), scale=(1, 0.8, 1)), segs=12, rings=7)


def jitter(b, faces, centre, amount, seed):
    rnd = random.Random(seed)
    c = Vector(centre)
    done = set()
    for f in faces:
        for v in f.verts:
            if v in done:
                continue
            done.add(v)
            d = v.co - c
            if d.length > 1e-6:
                v.co += d.normalized() * rnd.uniform(-amount, amount)


# ======================================================================= blades

def sword(b):
    grip(b, -0.11, 0.1, 0.021, LEATHER)
    wraps(b, -0.08, 0.07, 4, 0.022, WRAP)
    b.lathe([(0, -0.18), (0.022, -0.175), (0.034, -0.15), (0.028, -0.125), (0.016, -0.11, "S"), (0, -0.11)], GOLD)
    b.tube([(-0.17, 0.15, 0), (-0.09, 0.122, 0), (0, 0.115, 0), (0.09, 0.122, 0), (0.17, 0.15, 0)],
           [0.013, 0.017, 0.021, 0.017, 0.013], GOLD, subdiv=2)
    for sx in (-1, 1):
        b.sphere(0.021, GOLD, T((sx * 0.175, 0.153, 0)), segs=10, rings=6)
    b.sphere(0.017, (0.75, 0.08, 0.15, M), T((0, 0.117, 0), scale=(1, 1, 1.45)), segs=10, rings=6)
    b.slab([(-0.042, 0.13), (0.042, 0.13), (0.039, 0.72), (0.0, 0.94), (-0.039, 0.72)], 0.026, STEEL, bevel=0.03, edge=0.0)
    b.slab([(-0.008, 0.17), (0.008, 0.17), (0.006, 0.62), (0.0, 0.67), (-0.006, 0.62)], 0.028, STEEL_D)


def katana(b):
    grip(b, -0.2, 0.13, 0.02, BLACK)
    for i in range(7):
        ring(b, -0.17 + i * 0.045, 0.021, 0.006, (0.9, 0.88, 0.8), 10)
    b.lathe([(0, -0.225), (0.02, -0.225, "S"), (0.023, -0.2, "S"), (0, -0.2)], GOLD)
    b.lathe([(0, 0.134), (0.064, 0.134, "S"), (0.064, 0.148, "S"), (0, 0.148)], IRON, segs=20)
    b.torus(0.064, 0.004, GOLD, T((0, 0.141, 0), TO_Z), 20, 4)
    b.box((0.05, 0.04, 0.026), GOLD, T((0, 0.168, 0)), bevel=0.005)
    n = 10
    left, right = [], []
    for i in range(n + 1):
        t = i / n
        x = 0.06 * t * t
        y = 0.15 + 0.94 * t
        w = 0.046 - 0.01 * t
        left.append((x - w * 0.5, y))
        if i < n:
            right.append((x + w * 0.5, y))
    tip = (0.06 + 0.012, 1.13)
    right[-1] = (right[-1][0], right[-1][1] - 0.02)
    b.slab(left + [tip] + list(reversed(right)), 0.019, STEEL, bevel=0.024, edge=0.004)


def dagger(b):
    grip(b, -0.075, 0.06, 0.018, LEATHER, 10)
    wraps(b, -0.05, 0.04, 3, 0.019, WRAP, 0.004)
    b.sphere(0.024, IRON, T((0, -0.1, 0)), segs=10, rings=6)
    b.tube([(-0.075, 0.1, 0), (-0.03, 0.076, 0), (0, 0.07, 0), (0.03, 0.076, 0), (0.075, 0.1, 0)], 0.011, IRON, subdiv=2)
    for sx in (-1, 1):
        b.sphere(0.014, IRON, T((sx * 0.078, 0.102, 0)), segs=8, rings=5)
    b.slab([(-0.026, 0.083), (0.026, 0.083), (0.03, 0.2), (0.018, 0.32), (0, 0.385), (-0.018, 0.32), (-0.03, 0.2)],
           0.018, STEEL, bevel=0.022, edge=0.0)
    b.slab([(-0.005, 0.1), (0.005, 0.1), (0.004, 0.28), (-0.004, 0.28)], 0.019, STEEL_D)


def rapier(b):
    grip(b, -0.075, 0.075, 0.016, WRAP, 10)
    wraps(b, -0.06, 0.06, 6, 0.0165, GOLD, 0.0035)
    b.lathe([(0, -0.125), (0.016, -0.12), (0.024, -0.1), (0.018, -0.08), (0.01, -0.075, "S"), (0, -0.075)], GOLD)
    b.lathe([(0, 0.086), (0.035, 0.091), (0.06, 0.106), (0.074, 0.13, "S"), (0.068, 0.133, "S"), (0.055, 0.114),
             (0.03, 0.103), (0, 0.1)], GOLD, segs=18)
    b.tube([(-0.13, 0.155, 0), (-0.1, 0.125, 0), (0, 0.118, 0), (0.1, 0.125, 0), (0.13, 0.155, 0)], 0.007, GOLD, subdiv=2, segs=6)
    b.tube([(0.0, -0.09, 0), (0.05, -0.075, 0), (0.078, 0.0, 0), (0.072, 0.07, 0), (0.05, 0.105, 0)], 0.006, GOLD, subdiv=2, segs=6)
    b.slab([(-0.012, 0.13), (0.012, 0.13), (0.008, 1.0), (0, 1.13), (-0.008, 1.0)], 0.012, STEEL, bevel=0.009, edge=0.0)


def hand_axe(b):
    b.tube([(0, -0.16, 0), (0.006, 0.05, 0), (-0.004, 0.3, 0), (0, 0.56, 0)], [0.022, 0.024, 0.026, 0.024], WOOD, subdiv=3, segs=10)
    grip(b, -0.12, 0.06, 0.027, LEATHER, 10)
    wraps(b, -0.1, 0.04, 3, 0.028, WRAP, 0.004)
    knob(b, -0.16, 0.026, IRON)
    b.box((0.065, 0.13, 0.06), IRON, T((0, 0.46, 0)), bevel=0.01)
    b.slab([(-0.03, 0.53), (-0.1, 0.52), (-0.19, 0.59), (-0.245, 0.555), (-0.262, 0.45), (-0.245, 0.35), (-0.19, 0.31),
            (-0.12, 0.39), (-0.03, 0.4)], 0.03, STEEL, bevel=0.026, edge=0.0)
    b.box((0.05, 0.07, 0.045), IRON, T((0.05, 0.46, 0)), bevel=0.012)


def plasma_blade(b):
    b.lathe([(0, -0.16), (0.024, -0.16, "S"), (0.026, -0.12), (0.026, 0.1, "S"), (0.032, 0.11), (0.034, 0.17, "S"),
             (0.024, 0.18, "S"), (0, 0.18)], GUNMETAL, segs=14)
    for y in (-0.09, -0.045, 0.0, 0.045):
        ring(b, y, 0.027, 0.006, BLACK, 12)
    ring(b, 0.168, 0.033, 0.006, (0.3, 0.9, 1.0, G), 14)
    b.sphere(0.009, (1.0, 0.2, 0.2, G), T((0.026, 0.06, 0)), segs=8, rings=5)
    b.lathe([(0, 0.18), (0.024, 0.19), (0.029, 0.24), (0.029, 1.1), (0.022, 1.18), (0, 1.23)], (0.45, 0.9, 1.0, G), segs=12)


# ======================================================================== heavy

def hammer(b):
    b.cylinder(0.026, -0.36, 0.66, WOOD, segs=10)
    grip(b, -0.3, 0.02, 0.03, LEATHER, 10)
    wraps(b, -0.27, -0.01, 4, 0.031, WRAP, 0.005)
    knob(b, -0.36, 0.035, IRON)
    b.lathe([(0, 0.6), (0.036, 0.6, "S"), (0.042, 0.64, "S"), (0, 0.64)], IRON, segs=12)
    b.box((0.3, 0.19, 0.19), IRON, T((0, 0.74, 0)), bevel=0.03, segs=3)
    for sx, rot in ((1, TO_X), (-1, TO_NX)):
        b.lathe([(0, 0.0), (0.1, 0.0, "S"), (0.105, 0.025), (0.098, 0.045, "S"), (0, 0.05)], STEEL_D, T((sx * 0.145, 0.74, 0), rot), segs=16)
    b.box((0.31, 0.03, 0.2), STEEL, T((0, 0.665, 0)), bevel=0.008)
    b.box((0.31, 0.03, 0.2), STEEL, T((0, 0.815, 0)), bevel=0.008)


def battle_axe(b):
    b.cylinder(0.027, -0.42, 0.84, DARKWOOD, segs=10)
    grip(b, -0.3, 0.04, 0.031, LEATHER, 10)
    wraps(b, -0.28, 0.02, 4, 0.032, WRAP, 0.005)
    b.cylinder(0.03, -0.5, -0.4, IRON, r1=0.03, segs=10)
    b.cylinder(0.028, 0.0, 0.1, STEEL, T((0, -0.5, 0), (180, 0, 0)), r1=0.0, segs=10)
    b.cylinder(0.032, 0.82, 0.98, STEEL, r1=0.0, segs=10)
    b.box((0.08, 0.3, 0.075), IRON, T((0, 0.64, 0)), bevel=0.015)
    blade = [(0.04, 0.58), (0.12, 0.55), (0.2, 0.47), (0.27, 0.43), (0.3, 0.52), (0.312, 0.64), (0.3, 0.76), (0.27, 0.85),
             (0.2, 0.81), (0.12, 0.73), (0.04, 0.7)]
    b.slab(blade, 0.034, STEEL, bevel=0.036, edge=0.0)
    b.slab(mirror_x(blade), 0.034, STEEL, bevel=0.036, edge=0.0)


def pickaxe(b):
    b.cylinder(0.026, -0.36, 0.66, WOOD, segs=10)
    grip(b, -0.3, -0.02, 0.029, LEATHER, 10)
    knob(b, -0.36, 0.03, IRON)
    b.box((0.075, 0.12, 0.075), IRON, T((0, 0.615, 0)), bevel=0.012)
    b.tube([(-0.46, 0.5, 0), (-0.3, 0.59, 0), (-0.12, 0.632, 0), (0, 0.64, 0), (0.12, 0.632, 0), (0.3, 0.59, 0), (0.46, 0.5, 0)],
           [0.005, 0.022, 0.035, 0.04, 0.035, 0.022, 0.005], IRON, subdiv=2, segs=8)


def anchor(b):
    b.cylinder(0.04, -0.33, 0.86, IRON, segs=12)
    b.sphere(0.065, IRON, T((0, 0.86, 0)), segs=12, rings=7)
    for sx in (-1, 1):
        b.tube([(0, 0.87, 0), (sx * 0.16, 0.86, 0), (sx * 0.3, 0.8, 0), (sx * 0.4, 0.68, 0), (sx * 0.43, 0.58, 0)],
               [0.05, 0.045, 0.04, 0.035, 0.03], IRON, subdiv=2, segs=10)
        fluke = [(0.35, 0.67), (0.47, 0.73), (0.5, 0.6), (0.44, 0.5)]
        b.slab(fluke if sx > 0 else mirror_x(fluke), 0.03, STEEL_D, bevel=0.014, edge=0.008)
    b.cylinder(0.034, -0.27, 0.27, DARKWOOD, T((0, -0.05, 0), TO_X), segs=10)
    for sx in (-1, 1):
        b.sphere(0.042, IRON, T((sx * 0.27, -0.05, 0)), segs=10, rings=6)
    for i in range(5):
        ring(b, 0.0 + i * 0.025, 0.044, 0.008, ROPE, 12)
    b.torus(0.075, 0.016, IRON, T((0, -0.41, 0)), 18, 6)


def lollipop(b):
    b.cylinder(0.02, -0.35, 0.66, WHITE, segs=10)
    disc = T((0, 0.9, 0), TO_Z)
    b.lathe([(0, -0.045), (0.22, -0.045), (0.262, -0.022), (0.27, 0.0), (0.262, 0.022), (0.22, 0.045), (0, 0.045)],
            (1.0, 0.4, 0.7), disc, segs=24)
    for face in (1, -1):
        for phase, col in ((0.0, WHITE), (math.pi, (0.5, 0.9, 1.0))):
            pts = []
            for i in range(30):
                th = phase + 4.0 * math.pi * i / 29
                r = 0.025 + 0.215 * i / 29
                pts.append((r * math.cos(th), 0.9 + r * math.sin(th), face * (0.04 - 0.012 * (i / 29) ** 2)))
            b.tube(pts, 0.011, col, segs=5, caps=False)
    for sx in (-1, 1):
        b.slab([(0.0, 0.6), (sx * 0.07, 0.65), (sx * 0.08, 0.58)], 0.015, (0.6, 0.85, 1.0), bevel=0.005)


def shovel(b):
    b.cylinder(0.022, -0.27, 0.75, WOOD, segs=10)
    b.tube([(0, -0.27, 0), (0.07, -0.31, 0), (0.075, -0.4, 0), (0, -0.41, 0), (-0.075, -0.4, 0), (-0.07, -0.31, 0)],
           0.014, BLACK, subdiv=2, segs=8, closed=True)
    b.cylinder(0.024, 0.66, 0.8, IRON, r1=0.04, segs=12)
    b.slab([(-0.13, 0.78), (-0.04, 0.77), (0.04, 0.77), (0.13, 0.78), (0.135, 0.98), (0.06, 1.08), (0, 1.12), (-0.06, 1.08),
            (-0.135, 0.98)], 0.02, STEEL_D, bevel=0.014, edge=0.006)
    b.box((0.27, 0.02, 0.04), IRON, T((0, 0.785, 0)), bevel=0.006)


def guitar(b):
    b.box((0.055, 0.66, 0.032), DARKWOOD, T((0, 0.05, 0)), bevel=0.008)
    b.box((0.05, 0.6, 0.008), BLACK, T((0, 0.07, 0.018)))
    for i in range(7):
        b.box((0.05, 0.004, 0.004), STEEL, T((0, -0.22 + i * 0.075, 0.023)))
    b.slab([(-0.04, -0.27), (0.04, -0.27), (0.052, -0.42), (0.0, -0.45), (-0.052, -0.43)], 0.026, BLACK, bevel=0.008, edge=0.012)
    for sx, rot in ((1, TO_X), (-1, TO_NX)):
        for y in (-0.31, -0.36, -0.41):
            b.cylinder(0.008, 0.0, 0.03, STEEL, T((sx * 0.04, y, 0), rot), segs=6)
    hw = [(0.3, 0.05), (0.33, 0.11), (0.38, 0.145), (0.43, 0.155), (0.48, 0.14), (0.53, 0.12), (0.58, 0.15), (0.64, 0.195),
          (0.7, 0.21), (0.77, 0.2), (0.83, 0.165), (0.875, 0.1), (0.895, 0.04)]
    body = [(w, y) for y, w in hw] + [(-w, y) for y, w in reversed(hw)]
    b.slab(body, 0.08, RED, bevel=0.022, edge=0.04)
    b.slab([(0.03, 0.5), (0.12, 0.56), (0.15, 0.66), (0.1, 0.74), (0.04, 0.7)], 0.088, BLACK)
    for y in (0.52, 0.61):
        b.box((0.1, 0.035, 0.01), WHITE, T((-0.01, y, 0.044)), bevel=0.003)
    b.box((0.1, 0.03, 0.012), BLACK, T((0, 0.76, 0.044)), bevel=0.004)
    for x in (-0.015, -0.005, 0.005, 0.015):
        b.box((0.002, 1.04, 0.002), (0.85, 0.85, 0.8, M), T((x, 0.24, 0.047)))
    for x, y in ((0.12, 0.76), (0.15, 0.7)):
        b.cylinder(0.016, 0.0, 0.016, WHITE, T((x, y, 0.04), TO_Z), segs=10)


# ===================================================================== polearms

def spear(b):
    b.cylinder(0.02, -0.74, 1.22, WOOD, segs=10)
    grip(b, -0.09, 0.09, 0.024, LEATHER, 10)
    grip(b, 0.51, 0.69, 0.024, LEATHER, 10)
    b.cylinder(0.024, -0.8, -0.72, IRON, r1=0.024, segs=10)
    b.lathe([(0, 1.17), (0.022, 1.17, "S"), (0.032, 1.26), (0.02, 1.3, "S"), (0, 1.3)], IRON, segs=10)
    b.cylinder(0.05, 1.06, 1.17, RED, r1=0.024, segs=10, smooth=False)
    b.slab([(-0.025, 1.28), (0.025, 1.28), (0.05, 1.36), (0.04, 1.45), (0, 1.58), (-0.04, 1.45), (-0.05, 1.36)], 0.024, STEEL,
           bevel=0.032, edge=0.0)
    b.box((0.012, 0.24, 0.026), STEEL_D, T((0, 1.4, 0)))


def bo_staff(b):
    b.cylinder(0.026, -0.7, 1.1, DARKWOOD, segs=12)
    for y, s in ((-0.7, -1), (1.1, 1)):
        b.lathe([(0, 0), (0.03, 0, "S"), (0.031, 0.08), (0.022, 0.12), (0, 0.13)], BRASS,
                T((0, y, 0), (0 if s > 0 else 180, 0, 0)), segs=12)
    grip(b, -0.11, 0.11, 0.029, RED, 12)
    grip(b, 0.4, 0.62, 0.029, RED, 12)
    for y in (0.93, 0.97, -0.53, -0.57):
        ring(b, y, 0.028, 0.006, BRASS, 12)


def trident(b):
    b.cylinder(0.02, -0.68, 1.14, GOLD, segs=10)
    grip(b, -0.1, 0.1, 0.024, (0.15, 0.35, 0.5), 10)
    b.sphere(0.03, GOLD, T((0, -0.7, 0)), segs=10, rings=6)
    b.sphere(0.04, (0.2, 0.85, 0.9, G), T((0, 1.08, 0), scale=(1, 1.3, 1)), segs=10, rings=6)
    b.tube([(-0.16, 1.21, 0), (-0.12, 1.158, 0), (0, 1.14, 0), (0.12, 1.158, 0), (0.16, 1.21, 0)], 0.017, GOLD, subdiv=2, segs=8)
    b.lathe([(0, 1.13), (0.016, 1.14, "S"), (0.014, 1.46, "S"), (0, 1.46)], STEEL, segs=8)
    b.cylinder(0.03, 1.44, 1.6, STEEL, r1=0.0, segs=8)
    for sx in (-1, 1):
        b.tube([(sx * 0.16, 1.2, 0), (sx * 0.168, 1.3, 0), (sx * 0.155, 1.42, 0)], 0.013, STEEL, subdiv=2, segs=8)
        b.cylinder(0.026, 1.4, 1.53, STEEL, T((sx * 0.155, 0, 0)), r1=0.0, segs=8)
        b.slab([(sx * 0.135, 1.43), (sx * 0.11, 1.4), (sx * 0.14, 1.41)], 0.01, STEEL)


def scythe(b):
    b.tube([(0, -0.74, 0), (0.02, -0.3, 0), (-0.015, 0.3, 0), (0.01, 0.8, 0), (0, 1.22, 0)], 0.022, DARKWOOD, subdiv=3, segs=10)
    b.tube([(0, 0.5, 0), (0.08, 0.52, 0), (0.11, 0.56, 0)], 0.016, WOOD, subdiv=2, segs=8)
    b.sphere(0.02, WOOD, T((0.112, 0.565, 0)), segs=8, rings=5)
    knob(b, -0.74, 0.026, IRON)
    b.box((0.07, 0.12, 0.06), IRON, T((0, 1.19, 0)), bevel=0.012)
    spine = [(0.0, 1.26), (0.2, 1.272), (0.4, 1.24), (0.58, 1.17), (0.72, 1.08), (0.82, 0.975)]
    edge = [(0.7, 1.04), (0.55, 1.1), (0.38, 1.137), (0.2, 1.148), (0.0, 1.14)]
    b.slab(spine + edge, 0.022, STEEL_D, bevel=0.034, edge=0.0)


def lance(b):
    grip(b, -0.25, 0.05, 0.022, LEATHER, 10)
    b.lathe([(0, -0.31), (0.02, -0.31), (0.03, -0.285), (0.022, -0.25, "S"), (0, -0.25)], STEEL, segs=10)
    b.lathe([(0, 0.05), (0.035, 0.05, "S"), (0.14, 0.1, "S"), (0.135, 0.12, "S"), (0.035, 0.13), (0, 0.13)], STEEL, segs=20)
    prof = [(0.08, 0.14), (0.075, 0.4), (0.06, 0.7), (0.045, 1.0), (0.03, 1.25), (0.022, 1.3)]
    b.lathe([(0, 0.13), (0.08, 0.13, "S")] + prof[1:-1] + [(0.022, 1.3, "S"), (0, 1.3)], BLUE, segs=16)
    b.cylinder(0.022, 1.3, 1.56, STEEL, r1=0.0, segs=10)

    def r_at(y):
        for (r0, y0), (r1, y1) in zip(prof, prof[1:]):
            if y0 <= y <= y1:
                return r0 + (r1 - r0) * (y - y0) / (y1 - y0)
        return 0.03
    for y in (0.36, 0.7, 1.04):
        ring(b, y, r_at(y) + 0.001, 0.009, WHITE, 16)


# =========================================================== one-handed swingers

def flail(b):
    b.cylinder(0.022, -0.2, 0.2, WOOD, segs=10)
    grip(b, -0.15, 0.02, 0.025, LEATHER, 10)
    b.lathe([(0, -0.23), (0.028, -0.23, "S"), (0.028, -0.19, "S"), (0, -0.19)], IRON, segs=10)
    b.lathe([(0, 0.19), (0.03, 0.19, "S"), (0.026, 0.23, "S"), (0, 0.23)], IRON, segs=10)
    for i in range(6):
        y = 0.25 + i * 0.055
        rot = (0, 0, 0) if i % 2 == 0 else (0, 90, 0)
        b.torus(0.02, 0.006, IRON, T((0, y, 0), rot, (1, 1.5, 1)), 10, 5)
    c = Vector((0, 0.67, 0))
    b.sphere(0.095, IRON, T(tuple(c)), segs=14, rings=8)
    dirs = [(1, 0, 0), (-1, 0, 0), (0, 0, 1), (0, 0, -1), (0, 1, 0)]
    for k in range(4):
        a = math.radians(45 + 90 * k)
        dirs.append((math.cos(a), 0.55, math.sin(a)))
        dirs.append((math.cos(a), -0.55, math.sin(a)))
    for d in dirs:
        b.cylinder(0.026, 0.07, 0.15, STEEL, align(d, tuple(c)), r1=0.0, segs=7)


def nunchucks(b):
    def rod(m):
        b.cylinder(0.021, -0.15, 0.15, BLACK, m, segs=10)
        for y in (-0.15, 0.15):
            b.sphere(0.022, GOLD, m @ T((0, y, 0), scale=(1, 0.5, 1)), segs=10, rings=5)
        for y in (-0.11, 0.11):
            b.torus(0.022, 0.005, GOLD, m @ T((0, y, 0), TO_Z), 12, 4)
    rod(T())
    rod(T((0.1, 0.44, 0), (0, 0, -25)))
    for i, (x, y) in enumerate(((0.006, 0.185), (0.016, 0.225), (0.026, 0.262))):
        b.torus(0.014, 0.004, IRON, T((x, y, 0), (0, 90 if i % 2 else 0, -10), (1, 1.5, 1)), 8, 4)


def wrench(b):
    b.box((0.045, 0.42, 0.022), STEEL_D, T((0, 0.17, 0)), bevel=0.007)
    b.box((0.056, 0.22, 0.032), RED, T((0, -0.01, 0)), bevel=0.013)
    jaw = arc(0, 0.47, 0.095, 122, 418, 16) + [(0.03, 0.55), (0.03, 0.485), (-0.03, 0.485), (-0.03, 0.55)]
    b.slab(jaw, 0.03, STEEL, bevel=0.007, edge=0.016)
    b.cylinder(0.014, -0.03, 0.03, BRASS, T((0, 0.43, 0), TO_X), segs=10)
    b.torus(0.018, 0.005, STEEL_D, T((0, -0.13, 0)), 12, 4)


def umbrella(b):
    b.tube([(0, -0.02, 0), (0, -0.12, 0), (-0.02, -0.17, 0), (-0.07, -0.18, 0), (-0.1, -0.14, 0)], 0.016, BLACK, subdiv=3, segs=8)
    b.cylinder(0.01, -0.03, 0.92, STEEL_D, segs=8)
    b.lathe([(0, 0.22), (0.035, 0.25), (0.075, 0.42), (0.07, 0.6), (0.045, 0.75), (0.02, 0.85), (0, 0.88)],
            (0.15, 0.55, 0.9), segs=8, smooth=False)
    ring(b, 0.5, 0.075, 0.01, (0.95, 0.85, 0.2), 16)
    b.cylinder(0.009, 0.88, 0.96, STEEL, r1=0.0, segs=6)


def ice_cream(b):
    waffle = (0.85, 0.62, 0.32)
    b.lathe([(0, -0.08), (0.012, -0.075), (0.07, 0.3, "S"), (0.075, 0.32, "S"), (0, 0.32)], waffle, segs=10, smooth=False)
    for y in (0.03, 0.11, 0.19, 0.26):
        r = 0.012 + (0.07 - 0.012) * (y + 0.075) / 0.375
        ring(b, y, r + 0.001, 0.0035, (0.6, 0.4, 0.18), 10)
    mint = (0.55, 0.95, 0.85)
    b.sphere(0.095, mint, T((0, 0.39, 0)), segs=14, rings=8)
    for k in range(5):
        a = math.radians(72 * k + 10)
        b.tube([(0.085 * math.cos(a), 0.36, 0.085 * math.sin(a)), (0.088 * math.cos(a), 0.31 - 0.015 * (k % 2), 0.088 * math.sin(a))],
               0.018, mint, segs=6)
        b.sphere(0.018, mint, T((0.088 * math.cos(a), 0.31 - 0.015 * (k % 2), 0.088 * math.sin(a))), segs=6, rings=4)
    b.sphere(0.08, (1.0, 0.6, 0.75), T((0, 0.51, 0)), segs=14, rings=8)
    b.sphere(0.03, RED, T((0, 0.605, 0)), segs=10, rings=6)
    b.tube([(0, 0.62, 0), (0.01, 0.66, 0), (0.03, 0.69, 0)], 0.004, DARKWOOD, subdiv=1, segs=4)


# ======================================================================== fists

def boxing_gloves(b):
    b.sphere(0.105, RED, T((0, 0.035, 0), scale=(1.0, 1.15, 1.1)), segs=14, rings=9)
    b.tube([(0.07, -0.04, 0.03), (0.1, 0.02, 0.05), (0.085, 0.08, 0.06)], 0.035, RED, subdiv=2, segs=8)
    b.lathe([(0, -0.18), (0.07, -0.18, "S"), (0.078, -0.12), (0.075, -0.065, "S"), (0, -0.065)], WHITE, segs=14)
    ring(b, -0.068, 0.077, 0.01, RED, 14)


def power_gauntlet(b):
    b.box((0.2, 0.2, 0.2), IRON, T((0, 0.0, 0)), bevel=0.04, segs=3)
    for i in range(4):
        b.box((0.044, 0.06, 0.07), STEEL, T((-0.075 + 0.05 * i, 0.1, 0.03)), bevel=0.012)
    b.sphere(0.036, (1.0, 0.6, 0.2, G), T((0, 0.0, 0.1), scale=(1, 1, 0.6)), segs=12, rings=6)
    b.torus(0.046, 0.01, STEEL, T((0, 0, 0.1)), 14, 5)
    b.lathe([(0, -0.24), (0.095, -0.24, "S"), (0.11, -0.16), (0.1, -0.09, "S"), (0, -0.09)], GUNMETAL, segs=14)
    ring(b, -0.11, 0.104, 0.008, (1.0, 0.6, 0.2, G), 14)
    for sx in (-1, 1):
        b.tube([(sx * 0.115, -0.2, 0), (sx * 0.115, 0.0, 0)], 0.017, STEEL, segs=8)


def shield(b):
    # Built facing +Z, then turned round (F): on the left forearm the socket's
    # +Z points back at the fighter, so the painted face must look along -Z.
    F = T(rot=(0, 180, 0))
    face = F @ T((0, 0, 0.07), TO_Z)
    b.lathe([(0, -0.02), (0.36, -0.02, "S"), (0.36, 0.012)], WOOD, face, segs=28)
    dome = [(0.36, 0.012), (0.25, 0.03), (0.12, 0.038), (0, 0.04)]
    for k in range(8):
        col = RED if k % 2 == 0 else (0.95, 0.88, 0.7)
        b.lathe(dome, col, face @ T(rot=(0, 45 * k, 0)), segs=4, turn=45)
    b.torus(0.36, 0.024, IRON, F @ T((0, 0, 0.068)), 36, 6)
    b.lathe([(0.095, 0.03), (0.09, 0.06), (0.065, 0.09), (0.0, 0.107)], STEEL, face, segs=16)
    b.torus(0.093, 0.012, IRON, F @ T((0, 0, 0.104)), 16, 5)
    for k in range(12):
        a = 2 * math.pi * k / 12 + 0.26
        b.sphere(0.013, IRON, F @ T((0.315 * math.cos(a), 0.315 * math.sin(a), 0.087)), segs=6, rings=4)
    b.tube([(-0.11, 0.0, 0.045), (-0.07, 0.0, 0.018), (0.07, 0.0, 0.018), (0.11, 0.0, 0.045)], 0.011, LEATHER, F, subdiv=2, segs=6)


# ======================================================================= thrown

def shuriken(b):
    pts = []
    for k in range(4):
        a = 90 * k
        for da, r in ((0, 0.13), (28, 0.062), (45, 0.032), (68, 0.05)):
            t = math.radians(a + da)
            pts.append((r * math.sin(t), r * math.cos(t)))
    b.slab(pts, 0.016, STEEL, bevel=0.02, edge=0.0)
    b.torus(0.022, 0.009, DARK, T(), 14, 5)


def throwing_knives(b):
    b.slab([(-0.017, 0.06), (0.017, 0.06), (0.019, 0.16), (0, 0.28), (-0.019, 0.16)], 0.012, STEEL, bevel=0.014, edge=0.0)
    b.cylinder(0.013, -0.065, 0.06, WRAP, segs=8)
    wraps(b, -0.045, 0.04, 3, 0.014, RED, 0.004)
    b.torus(0.02, 0.005, STEEL, T((0, -0.085, 0)), 12, 4)


def kunai(b):
    b.slab([(-0.012, 0.08), (0.012, 0.08), (0.04, 0.15), (0.03, 0.22), (0, 0.3), (-0.03, 0.22), (-0.04, 0.15)], 0.016, STEEL,
           bevel=0.03, edge=0.0)
    b.cylinder(0.014, -0.085, 0.08, (0.15, 0.15, 0.18), segs=8)
    for i in range(6):
        ring(b, -0.07 + i * 0.028, 0.015, 0.0045, (0.7, 0.15, 0.15), 10)
    b.torus(0.028, 0.006, IRON, T((0, -0.115, 0)), 14, 5)


def bomb(b):
    b.sphere(0.125, (0.12, 0.12, 0.14), T((0, 0.04, 0)), segs=16, rings=10)
    b.lathe([(0, 0.148), (0.045, 0.148, "S"), (0.045, 0.19, "S"), (0.036, 0.2, "S"), (0, 0.2)], IRON, segs=12)
    b.tube([(0, 0.2, 0), (0.005, 0.24, 0), (0.02, 0.27, 0), (0.04, 0.29, 0)], 0.009, ROPE, subdiv=2, segs=6)
    b.sphere(0.02, (1.0, 0.6, 0.1, G), T((0.045, 0.297, 0)), segs=8, rings=5)
    star = []
    for k in range(8):
        r = 0.045 if k % 2 == 0 else 0.015
        a = math.radians(45 * k)
        star.append((0.045 + r * math.cos(a), 0.297 + r * math.sin(a)))
    b.slab(star, 0.006, (1.0, 0.85, 0.3, G))


def snowball(b):
    faces = b.sphere(0.09, (0.94, 0.97, 1.0), T(), segs=12, rings=8)
    jitter(b, faces, (0, 0, 0), 0.008, 7)
    for i, (x, y, z) in enumerate(((0.06, 0.05, 0.04), (-0.05, -0.04, 0.06), (0.02, -0.07, -0.05))):
        b.sphere(0.028, (0.86, 0.93, 1.0), T((x, y, z)), segs=8, rings=5)


def saw_blade(b):
    n = 14
    pts = []
    for k in range(n):
        a = 2 * math.pi * k / n
        a2 = a + 2 * math.pi / n * 0.75
        pts.append((0.15 * math.cos(a), 0.15 * math.sin(a)))
        pts.append((0.19 * math.cos(a2), 0.19 * math.sin(a2)))
    b.slab(pts, 0.016, STEEL, bevel=0.005, edge=0.006)
    b.cylinder(0.05, -0.014, 0.014, IRON, T(rot=TO_Z), segs=16)
    b.cylinder(0.018, -0.017, 0.017, BLACK, T(rot=TO_Z), segs=10)
    for k in range(3):
        a = 2 * math.pi * k / 3 + 0.5
        b.cylinder(0.022, -0.0085, 0.0085, (0.25, 0.27, 0.3, M), T((0.1 * math.cos(a), 0.1 * math.sin(a), 0), TO_Z), segs=10)


def thunderbolt(b):
    bolt = [(-0.03, 0.06), (0.03, 0.06), (0.06, 0.25), (0.025, 0.25), (0.08, 0.45), (0.045, 0.45), (0.07, 0.64),
            (-0.035, 0.38), (0.0, 0.38), (-0.05, 0.19), (-0.012, 0.19)]
    b.slab(bolt, 0.035, (1.0, 0.9, 0.3, G), bevel=0.012, edge=0.012)
    b.lathe([(0, -0.09), (0.02, -0.09, "S"), (0.023, -0.01), (0.03, 0.06, "S"), (0, 0.065)], (0.6, 0.45, 0.15, M), segs=10)
    wraps(b, -0.07, 0.0, 3, 0.022, GOLD, 0.004)


def boomerang(b):
    centre = [(-0.21, 0.28), (-0.14, 0.15), (-0.06, 0.035), (0, 0.0), (0.06, 0.035), (0.14, 0.15), (0.21, 0.28)]
    widths = [0.045, 0.07, 0.08, 0.085, 0.08, 0.07, 0.045]
    b.slab(ribbon(centre, widths), 0.026, (0.85, 0.55, 0.2), bevel=0.013, edge=0.008)
    for sx in (-1, 1):
        stripe = [(sx * 0.195, 0.255), (sx * 0.165, 0.2)]
        b.slab(ribbon(stripe, 0.058, 2), 0.028, BLUE)


def yoyo(b):
    half = [(0.01, 0.006), (0.09, 0.008), (0.1, 0.03), (0.095, 0.05), (0.07, 0.06), (0.0, 0.062)]
    b.lathe(half, RED, T(rot=TO_Z), segs=20)
    b.lathe(half, RED, T(rot=TO_NZ), segs=20)
    b.cylinder(0.012, -0.01, 0.01, WHITE, T(rot=TO_Z), segs=10)
    sticker = [(0, 0.06), (0.04, 0.06, "S"), (0.04, 0.066, "S"), (0, 0.066)]
    b.lathe(sticker, (1.0, 0.85, 0.2), T(rot=TO_Z), segs=14)
    b.lathe(sticker, (1.0, 0.85, 0.2), T(rot=TO_NZ), segs=14)
    b.tube([(0, 0, 0), (0, -0.06, 0), (0.01, -0.15, 0), (0, -0.22, 0)], 0.003, WHITE, subdiv=2, segs=4)


def rocket_fist(b):
    b.box((0.2, 0.18, 0.22), IRON, T((0, 0.05, 0)), bevel=0.04, segs=3)
    for i in range(4):
        b.box((0.045, 0.07, 0.08), STEEL, T((-0.075 + 0.05 * i, 0.15, 0.04)), bevel=0.016)
    b.box((0.06, 0.1, 0.07), IRON, T((0.12, 0.04, 0.05), (0, 0, -20)), bevel=0.02)
    b.lathe([(0, -0.22), (0.085, -0.22, "S"), (0.09, -0.12), (0.095, -0.04, "S"), (0, -0.04)], GUNMETAL, segs=14)
    b.lathe([(0.045, -0.22), (0.07, -0.3, "S"), (0.06, -0.3, "S"), (0.035, -0.23)], DARK, segs=14)
    b.cylinder(0.055, -0.29, -0.28, (1.0, 0.55, 0.15, G), segs=14)
    for sx in (-1, 1):
        fin = [(0.09, -0.1), (0.145, -0.2), (0.145, -0.26), (0.09, -0.2)]
        b.slab(fin if sx > 0 else mirror_x(fin), 0.012, RED, bevel=0.004)


# ======================================================================= ranged

def blaster(b):
    b.box((0.07, 0.3, 0.11), GUNMETAL, T((0, 0.12, 0.0)), bevel=0.026, segs=3)
    b.cylinder(0.024, 0.26, 0.4, IRON, segs=12)
    for y in (0.3, 0.34):
        ring(b, y, 0.025, 0.006, GUNMETAL, 12)
    ring(b, 0.398, 0.024, 0.007, (0.4, 1.0, 0.6, G), 12)
    b.box((0.055, 0.07, 0.15), BLACK, T((0, -0.02, -0.08), (-15, 0, 0)), bevel=0.02)
    b.box((0.074, 0.14, 0.018), (0.4, 1.0, 0.6, G), T((0, 0.13, 0.02)))
    b.box((0.02, 0.04, 0.025), BLACK, T((0, 0.2, 0.065)), bevel=0.006)
    b.box((0.012, 0.03, 0.04), BLACK, T((0, 0.05, -0.065)), bevel=0.004)


def plasma_pistols(b):
    body = (0.85, 0.3, 0.2, M)
    b.box((0.055, 0.2, 0.085), body, T((0, 0.07, 0)), bevel=0.022, segs=3)
    b.cylinder(0.02, 0.17, 0.27, GUNMETAL, segs=10)
    for y in (0.19, 0.22, 0.25):
        ring(b, y, 0.021, 0.005, (1.0, 0.35, 0.75, G), 10)
    b.sphere(0.016, (1.0, 0.5, 0.85, G), T((0, 0.28, 0)), segs=8, rings=5)
    b.box((0.057, 0.07, 0.04), (1.0, 0.35, 0.75, G), T((0, 0.12, 0.0)))
    b.box((0.042, 0.055, 0.12), BLACK, T((0, -0.02, -0.075), (-12, 0, 0)), bevel=0.016)


def slingshot(b):
    grip(b, -0.11, 0.04, 0.02, WOOD, 10)
    wraps(b, -0.09, 0.02, 4, 0.021, LEATHER, 0.005)
    for sx in (-1, 1):
        b.tube([(0, 0.03, 0), (sx * 0.035, 0.09, 0), (sx * 0.07, 0.15, 0), (sx * 0.08, 0.21, 0)], [0.019, 0.016, 0.014, 0.013],
               WOOD, subdiv=2, segs=8)
        b.tube([(sx * 0.08, 0.2, 0), (sx * 0.04, 0.2, -0.07), (0.0, 0.2, -0.13)], 0.006, RED, subdiv=1, segs=5)
    b.sphere(0.025, LEATHER, T((0, 0.2, -0.135), scale=(1.4, 0.8, 0.6)), segs=8, rings=5)


def bazooka(b):
    olive = (0.35, 0.4, 0.28)
    b.cylinder(0.07, -0.24, 0.6, olive, segs=16)
    b.lathe([(0.065, -0.24), (0.09, -0.34, "S"), (0.08, -0.345, "S"), (0.058, -0.25)], DARK, segs=16)
    b.lathe([(0, 0.58), (0.078, 0.58, "S"), (0.085, 0.62), (0.08, 0.66, "S"), (0, 0.66)], IRON, segs=16)
    b.cylinder(0.055, 0.66, 0.78, RED, r1=0.0, segs=12)
    b.cylinder(0.073, 0.28, 0.36, (0.95, 0.75, 0.2), segs=16)
    for y in (-0.15, 0.52):
        ring(b, y, 0.071, 0.009, DARK, 16)
    b.box((0.04, 0.05, 0.13), BLACK, T((0, 0.0, -0.1)), bevel=0.016)
    b.box((0.04, 0.05, 0.12), BLACK, T((0, 0.25, -0.1)), bevel=0.016)
    b.box((0.03, 0.06, 0.05), BLACK, T((0, 0.22, 0.095)), bevel=0.008)
    b.cylinder(0.012, 0.25, 0.26, (0.3, 0.6, 1.0, G), T((0, 0, 0.1)), segs=8)


def sniper(b):
    stock = side([(-0.12, -0.32), (-0.02, -0.32), (0.025, -0.24), (0.03, 0.02), (-0.02, 0.02), (-0.035, -0.06), (-0.1, -0.12),
                  (-0.125, -0.22)])
    b.slab(stock, 0.05, DARKWOOD, SIDE, bevel=0.012, edge=0.028)
    b.box((0.065, 0.3, 0.085), GUNMETAL, T((0, 0.16, 0.0)), bevel=0.016)
    b.cylinder(0.016, 0.3, 0.95, IRON, segs=10)
    b.box((0.05, 0.07, 0.045), IRON, T((0, 0.95, 0)), bevel=0.01)
    b.lathe([(0, 0.04), (0.028, 0.04, "S"), (0.022, 0.1), (0.02, 0.26), (0.032, 0.32, "S"), (0, 0.32)], BLACK, T((0, 0, 0.085)), segs=12)
    b.cylinder(0.026, 0.318, 0.324, (0.3, 0.6, 1.0, G), T((0, 0, 0.085)), segs=12)
    b.cylinder(0.022, 0.036, 0.042, (0.3, 0.6, 1.0, G), T((0, 0, 0.085)), segs=12)
    for y in (0.1, 0.24):
        b.box((0.02, 0.025, 0.04), BLACK, T((0, y, 0.05)))
    b.tube([(0.03, 0.1, 0.02), (0.06, 0.09, 0.0)], 0.006, STEEL, segs=6)
    b.sphere(0.012, STEEL, T((0.062, 0.09, 0.0)), segs=8, rings=5)
    b.box((0.04, 0.07, 0.06), BLACK, T((0, 0.13, -0.07)), bevel=0.008)
    b.box((0.04, 0.06, 0.1), BLACK, T((0, 0.0, -0.07), (-15, 0, 0)), bevel=0.012)


def scepter(b):
    navy = (0.2, 0.25, 0.65)
    b.cylinder(0.018, -0.2, 0.5, navy, segs=10)
    for y in (0.0, 0.3):
        ring(b, y, 0.02, 0.008, GOLD, 12)
    b.lathe([(0, -0.27), (0.02, -0.26), (0.03, -0.235), (0.02, -0.21), (0.012, -0.2, "S"), (0, -0.2)], GOLD, segs=12)
    b.lathe([(0, 0.47), (0.03, 0.48), (0.036, 0.51, "S"), (0.0, 0.53)], GOLD, segs=12)
    for k in range(4):
        a = math.radians(45 + 90 * k)
        c, s = math.cos(a), math.sin(a)
        b.tube([(0.02 * c, 0.5, 0.02 * s), (0.05 * c, 0.56, 0.05 * s), (0.06 * c, 0.64, 0.06 * s), (0.025 * c, 0.71, 0.025 * s)],
               0.007, GOLD, subdiv=2, segs=5)
    b.sphere(0.055, (0.8, 0.6, 1.0, G), T((0, 0.64, 0)), segs=14, rings=8)
    wing = [(0.03, 0.48), (0.1, 0.56), (0.12, 0.62), (0.06, 0.565), (0.03, 0.52)]
    b.slab(wing, 0.01, GOLD, bevel=0.004)
    b.slab(mirror_x(wing), 0.01, GOLD, bevel=0.004)


def grapple(b):
    body = (0.25, 0.3, 0.45, M)
    b.box((0.08, 0.22, 0.1), body, T((0, 0.08, 0)), bevel=0.026, segs=3)
    b.cylinder(0.055, -0.05, 0.05, DARK, T((0, 0.04, 0.07), TO_X), segs=14)
    for x in (-0.03, -0.01, 0.01, 0.03):
        b.torus(0.056, 0.008, ROPE, T((x, 0.04, 0.07), (0, 90, 0)), 14, 4)
    b.cylinder(0.022, 0.19, 0.3, IRON, segs=10)
    b.cylinder(0.014, 0.3, 0.38, STEEL, r1=0.0, segs=8)
    for k in range(3):
        a = 2 * math.pi * k / 3
        c, s = math.cos(a), math.sin(a)
        b.tube([(0, 0.3, 0), (0.04 * c, 0.34, 0.04 * s), (0.065 * c, 0.37, 0.065 * s), (0.06 * c, 0.33, 0.06 * s)],
               [0.01, 0.009, 0.007, 0.003], STEEL, subdiv=2, segs=6)
    b.box((0.05, 0.055, 0.13), BLACK, T((0, 0.0, -0.085), (-12, 0, 0)), bevel=0.016)


def fan(b):
    pivot = Vector((0, -0.07))
    def at(a, r):
        t = math.radians(a)
        return (pivot.x + r * math.sin(t), pivot.y + r * math.cos(t))
    angles = [-50 + 12.5 * i for i in range(9)]
    for i in range(8):
        a0, a1 = angles[i], angles[i + 1]
        col = RED if i % 2 == 0 else WHITE
        panel = [at(a0, 0.12), at(a0, 0.34), at((a0 + a1) * 0.5, 0.345), at(a1, 0.34), at(a1, 0.12)]
        b.slab(panel, 0.006, col, T((0, 0, 0.003 if i % 2 == 0 else -0.003)))
    for i, a in enumerate(angles):
        r = 0.009 if i in (0, 8) else 0.005
        b.tube([(pivot.x, pivot.y, 0.0), (*at(a, 0.345), 0.0)], r, DARKWOOD, segs=4)
    b.cylinder(0.013, -0.012, 0.012, BRASS, T((0, -0.07, 0), TO_Z), segs=10)
    b.box((0.03, 0.12, 0.02), DARKWOOD, T((0, -0.1, 0)), bevel=0.007)
    b.tube([(0, -0.16, 0), (0.005, -0.2, 0), (0.0, -0.24, 0)], 0.006, RED, segs=5)
    b.sphere(0.014, RED, T((0, -0.25, 0)), segs=6, rings=4)


def bow(b):
    path = [(0, -0.64, -0.03), (0, -0.58, -0.07), (0, -0.4, -0.03), (0, -0.2, 0.01), (0, 0, 0.02), (0, 0.2, 0.01),
            (0, 0.4, -0.03), (0, 0.58, -0.07), (0, 0.64, -0.03)]
    b.tube(path, [0.01, 0.014, 0.019, 0.023, 0.026, 0.023, 0.019, 0.014, 0.01], WOOD, T(scale=(1.6, 1, 1)), subdiv=2, segs=8)
    for y in (-0.6, 0.6):
        b.sphere(0.013, DARKWOOD, T((0, y, -0.068)), segs=8, rings=5)
    b.tube([(0, -0.59, -0.075), (0, 0.59, -0.075)], 0.003, WHITE, segs=4)
    grip(b, -0.08, 0.08, 0.03, LEATHER, 10)
    wraps(b, -0.06, 0.06, 4, 0.031, (0.75, 0.6, 0.3), 0.004)
    b.box((0.012, 0.025, 0.02), DARKWOOD, T((0.02, 0.09, 0.0)), bevel=0.004)


# ========================================================================= joke

def frying_pan(b):
    pan = T((0, 0.44, 0), TO_Z)
    b.lathe([(0, -0.02), (0.15, -0.02, "S"), (0.172, 0.035), (0.178, 0.045, "S"), (0.17, 0.048)], IRON, pan, segs=24)
    b.lathe([(0.17, 0.048), (0.148, 0.002, "S"), (0, 0.002)], (0.15, 0.15, 0.17), pan, segs=24)
    b.tube([(0, 0.28, 0.005), (0, 0.15, 0.01), (0, 0.0, 0.015), (0, -0.12, 0.02)], [0.016, 0.019, 0.021, 0.02], BLACK,
           subdiv=2, segs=8)
    b.sphere(0.021, BLACK, T((0, -0.125, 0.02)), segs=8, rings=5)
    for sx in (-1, 1):
        b.sphere(0.01, IRON, T((sx * 0.02, 0.27, 0.012)), segs=6, rings=4)


def rubber_chicken(b):
    yellow = (1.0, 0.85, 0.2)
    b.lathe([(0, 0.06), (0.04, 0.07), (0.07, 0.14), (0.075, 0.3), (0.06, 0.45), (0.035, 0.55), (0.028, 0.62), (0, 0.64)],
            yellow, T(scale=(1, 1, 0.85)), segs=12)
    b.sphere(0.05, yellow, T((0, 0.68, 0.02)), segs=12, rings=7)
    b.cylinder(0.02, 0.0, 0.05, ORANGE, T((0, 0.67, 0.06), TO_Z), r1=0.0, segs=8)
    comb = side([(-0.03, 0.71), (0.04, 0.71), (0.05, 0.745), (0.03, 0.75), (0.02, 0.775), (0.0, 0.76), (-0.015, 0.785), (-0.03, 0.75)])
    b.slab(comb, 0.012, RED, SIDE, bevel=0.003)
    for sx in (-1, 1):
        b.sphere(0.009, BLACK, T((sx * 0.035, 0.69, 0.05)), segs=6, rings=4)
        wing = [(0.06, 0.22), (0.11, 0.3), (0.1, 0.42), (0.07, 0.36)]
        b.slab(wing if sx > 0 else mirror_x(wing), 0.02, (1.0, 0.8, 0.15), bevel=0.007)
        b.tube([(sx * 0.025, 0.08, 0), (sx * 0.025, 0.0, 0), (sx * 0.03, -0.05, 0)], 0.012, ORANGE, subdiv=1, segs=6)
        foot = [(0, 0), (0.02, 0.05), (0.006, 0.03), (0, 0.06), (-0.006, 0.03), (-0.02, 0.05)]
        b.slab(foot, 0.008, ORANGE, T((sx * 0.03, -0.055, 0), TO_Z))


MODELS = {
    "sword": sword, "katana": katana, "dagger": dagger, "rapier": rapier, "hand_axe": hand_axe, "plasma_blade": plasma_blade,
    "hammer": hammer, "battle_axe": battle_axe, "pickaxe": pickaxe, "anchor": anchor, "lollipop": lollipop, "shovel": shovel,
    "guitar": guitar, "spear": spear, "bo_staff": bo_staff, "trident": trident, "scythe": scythe, "lance": lance,
    "flail": flail, "nunchucks": nunchucks, "wrench": wrench, "umbrella": umbrella, "ice_cream": ice_cream,
    "boxing_gloves": boxing_gloves, "power_gauntlet": power_gauntlet, "shield": shield,
    "shuriken": shuriken, "throwing_knives": throwing_knives, "kunai": kunai, "bomb": bomb, "snowball": snowball,
    "saw_blade": saw_blade, "thunderbolt": thunderbolt, "boomerang": boomerang, "yoyo": yoyo, "rocket_fist": rocket_fist,
    "blaster": blaster, "plasma_pistols": plasma_pistols, "slingshot": slingshot, "bazooka": bazooka, "sniper": sniper,
    "scepter": scepter, "grapple": grapple, "fan": fan, "bow": bow, "frying_pan": frying_pan, "rubber_chicken": rubber_chicken,
}


def build(only=None):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    to_blender = Matrix.Rotation(math.radians(90), 4, "X")      # socket (x, y, z) -> Blender (x, -z, y)
    total = 0
    for wid, design in MODELS.items():
        if only and wid not in only:
            continue
        b = Builder()
        design(b)
        tris = b.tri_count()
        total += tris
        if tris > MAX_TRIS:
            raise SystemExit("%s: %d triangles (budget %d)" % (wid, tris, MAX_TRIS))
        b.bm.transform(to_blender)
        me = bpy.data.meshes.new(wid)
        b.bm.to_mesh(me)
        b.bm.free()
        attr = me.color_attributes.get("Col")
        if attr is not None:
            me.color_attributes.active_color = attr
        ob = bpy.data.objects.new(wid, me)
        bpy.context.scene.collection.objects.link(ob)
        print("%-16s %5d tris" % (wid, tris))
    print("total %d tris, %d models" % (total, len(bpy.context.scene.objects)))
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    bpy.ops.export_scene.gltf(filepath=OUT, export_format="GLB", export_materials="NONE", export_vertex_color="ACTIVE",
                              export_yup=True, export_apply=False, export_texcoords=False, export_normals=True)
    print("wrote", OUT)


if __name__ == "__main__":
    only = None
    if "--only" in sys.argv:
        only = set(sys.argv[sys.argv.index("--only") + 1].split(","))
    build(only)
