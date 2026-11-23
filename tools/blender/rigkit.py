"""Block Duelist rig and posing kit (runs inside Blender 5.3 / the bpy module).

The fighter rig uses Godot's humanoid bone names (SkeletonProfileHumanoid),
so Godot needs no bone map and later mocap (HY-Motion, Mixamo...) can be
retargeted onto it by name.

Axes (Blender armature space): the character faces -Y, its left is +X,
Z is up. Distances in metres, angles in degrees.

Poses are written as a dict of high-level controls and solved to bone
rotations here:
  hips        (x, y, z) offset of the pelvis from rest
  hips_rot    (pitch, roll, yaw) of the pelvis
  spine / chest / upper / neck / head      (pitch, roll, yaw), relative
  clav_l / clav_r                          (pitch, roll, yaw), relative
  hand_l / hand_r   wrist target, in rest space of the upper chest (it
                    turns and bends with the torso)
  elbow_l / elbow_r direction the elbow points (chest space)
  grip_r / grip_l   blade direction for a held weapon (chest space); the
                    hand turns so the WeaponR/WeaponL socket bone points
                    along it. None = straight wrist.
  face_l / face_r   with a grip: the direction the weapon's front (the
                    socket's -Z) faces, chest space; e.g. a shield's painted
                    face. None = the wrist follows the forearm
  wrist_l / wrist_r (pitch, roll, yaw) extra wrist turn when no grip
  foot_l / foot_r   ankle target in armature space (feet stay planted
                    however the body moves)
  foot_l_rot / foot_r_rot  (pitch, roll, yaw); +pitch = toes down
  knee_l / knee_r   direction the knee points (armature space)
  toe_l / toe_r     toe bend in degrees (+ = curl down)

Sign conventions: +pitch bends forward, +roll leans to the character's
left, +yaw turns to the character's left.
"""

import math

from mathutils import Euler, Matrix, Quaternion, Vector

FPS = 30

# name, parent, head, tail, z-axis hint
BONES = [
    ("Root", None, (0, 0, 0), (0, 0, 0.2), (0, -1, 0)),
    ("Hips", "Root", (0, 0, 0.98), (0, 0, 1.08), (0, -1, 0)),
    ("Spine", "Hips", (0, 0, 1.08), (0, 0, 1.20), (0, -1, 0)),
    ("Chest", "Spine", (0, 0, 1.20), (0, 0, 1.32), (0, -1, 0)),
    ("UpperChest", "Chest", (0, 0, 1.32), (0, 0, 1.48), (0, -1, 0)),
    ("Neck", "UpperChest", (0, 0, 1.48), (0, 0, 1.58), (0, -1, 0)),
    ("Head", "Neck", (0, 0, 1.58), (0, 0, 1.90), (0, -1, 0)),
    ("LeftShoulder", "UpperChest", (0.04, 0, 1.44), (0.19, 0, 1.44), (0, -1, 0)),
    ("LeftUpperArm", "LeftShoulder", (0.19, 0, 1.44), (0.46, 0, 1.44), (0, -1, 0)),
    ("LeftLowerArm", "LeftUpperArm", (0.46, 0, 1.44), (0.72, 0, 1.44), (0, -1, 0)),
    ("LeftHand", "LeftLowerArm", (0.72, 0, 1.44), (0.84, 0, 1.44), (0, -1, 0)),
    ("WeaponL", "LeftHand", (0.79, 0, 1.44), (0.79, 0, 1.34), (0, -1, 0)),
    ("RightShoulder", "UpperChest", (-0.04, 0, 1.44), (-0.19, 0, 1.44), (0, -1, 0)),
    ("RightUpperArm", "RightShoulder", (-0.19, 0, 1.44), (-0.46, 0, 1.44), (0, -1, 0)),
    ("RightLowerArm", "RightUpperArm", (-0.46, 0, 1.44), (-0.72, 0, 1.44), (0, -1, 0)),
    ("RightHand", "RightLowerArm", (-0.72, 0, 1.44), (-0.84, 0, 1.44), (0, -1, 0)),
    ("WeaponR", "RightHand", (-0.79, 0, 1.44), (-0.79, 0, 1.54), (0, -1, 0)),
    ("LeftUpperLeg", "Hips", (0.11, 0, 0.94), (0.11, 0, 0.52), (0, -1, 0)),
    ("LeftLowerLeg", "LeftUpperLeg", (0.11, 0, 0.52), (0.11, 0, 0.10), (0, -1, 0)),
    ("LeftFoot", "LeftLowerLeg", (0.11, 0, 0.10), (0.11, -0.13, 0.03), (0, 0, 1)),
    ("LeftToes", "LeftFoot", (0.11, -0.13, 0.03), (0.11, -0.21, 0.03), (0, 0, 1)),
    ("RightUpperLeg", "Hips", (-0.11, 0, 0.94), (-0.11, 0, 0.52), (0, -1, 0)),
    ("RightLowerLeg", "RightUpperLeg", (-0.11, 0, 0.52), (-0.11, 0, 0.10), (0, -1, 0)),
    ("RightFoot", "RightLowerLeg", (-0.11, 0, 0.10), (-0.11, -0.13, 0.03), (0, 0, 1)),
    ("RightToes", "RightFoot", (-0.11, -0.13, 0.03), (-0.11, -0.21, 0.03), (0, 0, 1)),
]

ANKLE_Z = 0.10
RESET = {"_reset": True}   # in a key: start again from DEFAULT, then apply the key
UPPER_CHEST_REST = Vector((0, 0, 1.32))

# Default pose: relaxed, standing, arms down. Every control has a value
# here so a move only lists what it changes.
DEFAULT = {
    "hips": (0.0, 0.0, -0.02), "hips_rot": (0.0, 0.0, 0.0),
    "spine": (0.0, 0.0, 0.0), "chest": (0.0, 0.0, 0.0), "upper": (0.0, 0.0, 0.0),
    "neck": (0.0, 0.0, 0.0), "head": (0.0, 0.0, 0.0),
    "clav_l": (0.0, 0.0, 0.0), "clav_r": (0.0, 0.0, 0.0),
    "hand_l": (0.24, 0.02, 0.92), "hand_r": (-0.24, 0.02, 0.92),
    "elbow_l": (0.3, 1.0, -0.2), "elbow_r": (-0.3, 1.0, -0.2),
    "grip_l": None, "grip_r": None, "face_l": None, "face_r": None,
    "wrist_l": (0.0, 0.0, 0.0), "wrist_r": (0.0, 0.0, 0.0),
    "foot_l": (0.12, 0.0, ANKLE_Z), "foot_r": (-0.12, 0.0, ANKLE_Z),
    "foot_l_rot": (0.0, 0.0, 0.0), "foot_r_rot": (0.0, 0.0, 0.0),
    "knee_l": (0.1, -1.0, 0.0), "knee_r": (-0.1, -1.0, 0.0),
    "toe_l": 0.0, "toe_r": 0.0,
}


def euler_q(pry):
    """(pitch, roll, yaw) degrees -> quaternion, applied X, then Y, then Z."""
    p, r, y = pry
    return Euler((math.radians(p), math.radians(r), math.radians(y)), "XYZ").to_quaternion()


def frame(y_axis: Vector, z_hint: Vector) -> Matrix:
    """Orthonormal 3x3 with the given Y axis and Z as close to z_hint as possible."""
    y = y_axis.normalized()
    x = y.cross(z_hint)
    if x.length < 1e-6:
        x = y.cross(Vector((0, 0, 1))) if abs(y.z) < 0.9 else y.cross(Vector((1, 0, 0)))
    x.normalize()
    z = x.cross(y).normalized()
    m = Matrix((x, y, z)).transposed()
    return m


def two_bone_ik(start: Vector, target: Vector, a: float, b: float, pole: Vector):
    """Returns (mid joint, end point) for a 2-bone chain reaching for target."""
    d_vec = target - start
    d = d_vec.length
    if d < 1e-5:
        d_vec = Vector((0, 0, -1e-3))
        d = 1e-3
    u = d_vec / d
    d_c = min(max(d, abs(a - b) + 1e-3), a + b - 1e-4)
    cos_a = (a * a + d_c * d_c - b * b) / (2 * a * d_c)
    cos_a = max(-1.0, min(1.0, cos_a))
    sin_a = math.sqrt(max(0.0, 1 - cos_a * cos_a))
    p = pole - u * pole.dot(u)
    if p.length < 1e-6:
        p = u.orthogonal()
    p.normalize()
    mid = start + (u * cos_a + p * sin_a) * a
    end = start + u * d_c
    return mid, end, p


# The block body's torso, in rest model space (metres): (z from, z to,
# half width, half depth) per box, from src/fighter/block_body.gd PARTS.
TORSO = [(1.315, 1.49, 0.22, 0.125), (1.18, 1.35, 0.185, 0.115), (1.05, 1.19, 0.155, 0.10), (0.88, 1.06, 0.17, 0.11)]


def torso_push(v: Vector, side: int, margin: float):
    """If chest-space point `v` is inside the torso (grown by `margin`),
    return it moved just outside (sideways on its own side, or to the
    front), else None."""
    for z0, z1, hw, hd in TORSO:
        if not (z0 - margin * 0.5 <= v.z <= z1 + margin * 0.5):
            continue
        w, d = hw + margin, hd + margin
        if abs(v.x) >= w or abs(v.y) >= d:
            continue
        options = []
        if v.x * side >= -0.02:                       # on its own side: out sideways
            options.append((w - abs(v.x), Vector((side * w, v.y, v.z))))
        if v.y <= 0.04:                               # in front: forward
            options.append((d + v.y, Vector((v.x, -d, v.z))))
        else:                                         # behind: back
            options.append((d - v.y, Vector((v.x, d, v.z))))
        return min(options, key=lambda o: o[0])[1]
    return None


class Rig:
    """Turns pose dicts into armature-space bone matrices for one armature."""

    def __init__(self, arm_obj):
        self.obj = arm_obj
        bones = arm_obj.data.bones
        self.rest = {b.name: b.matrix_local.copy() for b in bones}
        self.rest_rot = {n: m.to_3x3() for n, m in self.rest.items()}
        self.parent = {b.name: (b.parent.name if b.parent else None) for b in bones}
        self.length = {b.name: b.length for b in bones}
        self.order = [name for name, *_ in BONES]

    def _offset(self, name):
        par = self.parent[name]
        return (self.rest[par].inverted() @ self.rest[name]).translation

    def solve(self, pose: dict) -> dict:
        P = dict(DEFAULT)
        P.update(pose)
        M = {}

        def place(name, rot3):
            par = self.parent[name]
            head = self.rest[name].translation if par is None else M[par] @ self._offset(name)
            M[name] = Matrix.Translation(head) @ rot3.to_4x4()

        def fk(name, q):
            place(name, q.to_matrix() @ self.rest_rot[name])

        M["Root"] = self.rest["Root"].copy()
        q_hips = euler_q(P["hips_rot"])
        hips_head = self.rest["Hips"].translation + Vector(P["hips"])
        M["Hips"] = Matrix.Translation(hips_head) @ (q_hips.to_matrix() @ self.rest_rot["Hips"]).to_4x4()
        q_spine = q_hips @ euler_q(P["spine"])
        fk("Spine", q_spine)
        q_chest = q_spine @ euler_q(P["chest"])
        fk("Chest", q_chest)
        q_upper = q_chest @ euler_q(P["upper"])
        fk("UpperChest", q_upper)
        q_neck = q_upper @ euler_q(P["neck"])
        fk("Neck", q_neck)
        fk("Head", q_neck @ euler_q(P["head"]))

        upper_head = M["UpperChest"].translation
        chest_to_world = lambda v: upper_head + q_upper @ (Vector(v) - UPPER_CHEST_REST)

        world_to_chest = lambda w: q_upper.inverted() @ (w - upper_head) + UPPER_CHEST_REST
        for side, s in (("Left", "l"), ("Right", "r")):
            sgn = 1 if s == "l" else -1
            fk(side + "Shoulder", q_upper @ euler_q(P["clav_" + s]))
            ua, la, hand = side + "UpperArm", side + "LowerArm", side + "Hand"
            start = M[side + "Shoulder"] @ self._offset(ua)
            # Keep the hand out of the body (block torsos are wide).
            hand_local = Vector(P["hand_" + s])
            pushed = torso_push(hand_local, sgn, 0.075)
            if pushed is not None:
                hand_local = pushed
            target = chest_to_world(hand_local)
            # Try the authored elbow direction first, then ones that swing the
            # elbow out and back, and keep the first that clears the torso.
            poles = [Vector(P["elbow_" + s]), Vector((sgn * 1.0, 0.5, -0.4)), Vector((sgn * 1.0, 0.0, -0.6)),
                     Vector((sgn * 0.8, 0.8, 0.0)), Vector((sgn * 1.0, -0.3, -0.8))]
            best = None
            for k, pv in enumerate(poles):
                pole = q_upper @ pv.normalized()
                mid, end, p = two_bone_ik(start, target, self.length[ua], self.length[la], pole)
                inside = 0
                for pt in (mid, (start + mid) * 0.5 + (mid - start) * 0.15, (mid + end) * 0.5):
                    if torso_push(world_to_chest(pt), sgn, 0.06) is not None:
                        inside += 1
                if best is None or inside < best[0]:
                    best = (inside, mid, end, p)
                if inside == 0:
                    break
            _, mid, end, p = best
            z_hint = -p          # rest: elbow points back (+Y), bone Z points forward (-Y)
            place(ua, frame(mid - start, z_hint))
            place(la, frame(end - mid, z_hint))
            grip = P["grip_" + s]
            lower_rot = M[la].to_3x3()
            if grip is None:
                place(hand, lower_rot @ euler_q(P["wrist_" + s]).to_matrix())
            else:
                blade = (q_upper @ Vector(grip)).normalized()
                fingers = lower_rot.col[1].normalized()
                face = P.get("face_" + s)
                if face is not None:
                    # The hand's Z (blade x fingers) is the socket's back
                    # (-Z faces out): fingers = blade x face puts the
                    # weapon's front along `face` (checked with the shield).
                    fingers = blade.cross((q_upper @ Vector(face)).normalized())
                fingers = fingers - blade * fingers.dot(blade)
                if fingers.length < 1e-4:
                    fingers = blade.orthogonal()
                fingers.normalize()
                # The socket bones (WeaponR / WeaponL) point along the
                # hand's X axis, so X = blade on both sides.
                z_axis = blade.cross(fingers).normalized()
                place(hand, Matrix((blade, fingers, z_axis)).transposed())
            socket = "WeaponR" if s == "r" else "WeaponL"
            M[socket] = M[hand] @ (self.rest[hand].inverted() @ self.rest[socket])

        for side, s in (("Left", "l"), ("Right", "r")):
            ul, ll, foot, toes = side + "UpperLeg", side + "LowerLeg", side + "Foot", side + "Toes"
            start = M["Hips"] @ self._offset(ul)
            target = Vector(P["foot_" + s])
            pole = Vector(P["knee_" + s])
            mid, end, p = two_bone_ik(start, target, self.length[ul], self.length[ll], pole)
            place(ul, frame(mid - start, p))
            place(ll, frame(end - mid, p))
            q_foot = euler_q(P["foot_%s_rot" % s])
            M[foot] = Matrix.Translation(end) @ (q_foot.to_matrix() @ self.rest_rot[foot]).to_4x4()
            fk(toes, q_foot @ euler_q((P["toe_" + s], 0, 0)))
        return M

    def basis(self, M: dict) -> dict:
        """Armature-space matrices -> per-bone (location, quaternion) in pose space."""
        out = {}
        for name in self.order:
            par = self.parent[name]
            base = self.rest[name] if par is None else M[par] @ self.rest[par].inverted() @ self.rest[name]
            local = base.inverted() @ M[name]
            loc, rot, _ = local.decompose()
            out[name] = (loc, rot)
        return out


# ------------------------------------------------------------ interpolation

def _ease(kind, u):
    if kind == "lin":
        return u
    if kind == "in":          # slow start (wind-up into a strike)
        return u * u * u
    if kind == "out":         # fast start, soft stop (the strike itself)
        return 1 - (1 - u) ** 3
    if kind == "snap":        # very fast start
        return 1 - (1 - u) ** 5
    if kind == "back":        # overshoot then settle
        c = 1.6
        return 1 + (c + 1) * (u - 1) ** 3 + c * (u - 1) ** 2
    return u * u * (3 - 2 * u)  # "smooth"


def _catmull(p0, p1, p2, p3, t):
    t2, t3 = t * t, t * t * t
    return 0.5 * ((2 * p1) + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t2 + (-p0 + 3 * p1 - 3 * p2 + p3) * t3)


def _lerp_value(vals, i, u, curve):
    """Interpolates key i -> i+1 with Catmull-Rom (curve=True) or linear."""
    v1, v2 = vals[i], vals[i + 1]
    if v1 is None or v2 is None:
        return v1 if u < 0.5 else v2
    if isinstance(v1, (int, float)):
        v0 = vals[i - 1] if i > 0 and vals[i - 1] is not None else v1
        v3 = vals[i + 2] if i + 2 < len(vals) and vals[i + 2] is not None else v2
        return _catmull(v0, v1, v2, v3, u) if curve else v1 + (v2 - v1) * u
    a, b = Vector(v1), Vector(v2)
    p0 = Vector(vals[i - 1]) if i > 0 and vals[i - 1] is not None else a
    p3 = Vector(vals[i + 2]) if i + 2 < len(vals) and vals[i + 2] is not None else b
    if curve:
        return tuple(_catmull(p0, a, b, p3, u))
    return tuple(a.lerp(b, u))


class Keys:
    """A keyframed move: [(time_s, {controls}, ease_into_this_key), ...].

    Each key inherits the previous key's controls, so a key only lists
    what changes. Vectors follow Catmull-Rom curves through the keys
    (arcs, not straight lines); `ease` shapes the timing of the segment
    that ends on that key.
    """

    def __init__(self, base: dict, keys: list, curve=True):
        self.curve = curve
        merged = []
        cur = dict(DEFAULT)
        cur.update(base)
        for k in keys:
            t, ctrl = k[0], k[1]
            ease = k[2] if len(k) > 2 else "smooth"
            if ctrl.get("_reset"):
                cur = dict(DEFAULT)
            else:
                cur = dict(cur)
            cur.update({k: v for k, v in ctrl.items() if k != "_reset"})
            merged.append((t, cur, ease))
        self.keys = merged
        self.length = merged[-1][0]

    def __call__(self, t: float) -> dict:
        ks = self.keys
        if t <= ks[0][0]:
            return dict(ks[0][1])
        if t >= ks[-1][0]:
            return dict(ks[-1][1])
        i = 0
        while i + 1 < len(ks) and ks[i + 1][0] < t:
            i += 1
        t0, t1 = ks[i][0], ks[i + 1][0]
        u = _ease(ks[i + 1][2], (t - t0) / max(t1 - t0, 1e-6))
        out = {}
        for name in ks[0][1]:
            vals = [k[1][name] for k in ks]
            out[name] = _lerp_value(vals, i, u, self.curve)
        return out


def add(a, b):
    return tuple(x + y for x, y in zip(a, b))


def scale(a, s):
    return tuple(x * s for x in a)
