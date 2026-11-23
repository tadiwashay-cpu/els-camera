"""The Block Duelist move set, authored for the block fighter rig.

Every clip is a function t -> pose (see rigkit.py for the controls).
Locomotion comes from a gait generator (feet stay planted, no sliding at
the clip's native speed); fighting moves are keyframed with anticipation,
a fast strike and follow-through.

MOVES[name] = dict(fn, length, loop, events, speed)
  events: {"hit": [start, end]} for strikes, {"release": t} for throws,
          {"catch": t} for catches, all in seconds.
  speed:  native ground speed (m/s) of a locomotion loop; the game scales
          playback to the real speed so the feet never slide.
"""

import math

from mathutils import Vector

from rigkit import ANKLE_Z, RESET, Keys, add

R = math.radians

# ------------------------------------------------------------ base poses

GUARD = {   # unarmed: fists up
    "hips": (0.0, 0.01, -0.07), "hips_rot": (3.0, 0.0, -12.0),
    "spine": (3.0, 0.0, 5.0), "chest": (3.0, 0.0, 4.0), "upper": (2.0, 0.0, 3.0),
    "neck": (-2.0, 0.0, 0.0), "head": (-4.0, 0.0, 0.0),
    "hand_l": (0.16, -0.38, 1.42), "elbow_l": (0.8, -0.1, -1.0),
    "hand_r": (-0.18, -0.33, 1.38), "elbow_r": (-0.8, -0.1, -1.0),
    "wrist_l": (0.0, 0.0, -20.0), "wrist_r": (0.0, 0.0, 20.0),
    "foot_l": (0.16, -0.15, ANKLE_Z), "foot_r": (-0.15, 0.16, ANKLE_Z),
    "foot_l_rot": (0.0, 0.0, -8.0), "foot_r_rot": (0.0, 0.0, -30.0),
    "knee_l": (0.25, -1.0, 0.0), "knee_r": (-0.35, -1.0, 0.0),
}

STANCE = {   # sword in the right hand, point forward and up
    "hips": (0.0, 0.02, -0.08), "hips_rot": (4.0, 0.0, -16.0),
    "spine": (3.0, 0.0, 5.0), "chest": (3.0, 0.0, 5.0), "upper": (2.0, 0.0, 4.0),
    "neck": (-2.0, 0.0, 1.0), "head": (-4.0, 0.0, 1.0),
    "hand_r": (-0.27, -0.31, 1.16), "elbow_r": (-0.7, 0.5, -0.8),
    "grip_r": (0.15, -0.6, 0.78),
    "hand_l": (0.17, -0.27, 1.25), "elbow_l": (0.7, 0.4, -0.8),
    "wrist_l": (0.0, 0.0, -25.0),
    "foot_l": (0.17, -0.17, ANKLE_Z), "foot_r": (-0.16, 0.18, ANKLE_Z),
    "foot_l_rot": (0.0, 0.0, -10.0), "foot_r_rot": (0.0, 0.0, -35.0),
    "knee_l": (0.3, -1.0, 0.0), "knee_r": (-0.45, -1.0, 0.0),
}

RELAXED_ARMS = {
    "hand_l": (0.31, -0.04, 1.02), "elbow_l": (0.4, 1.0, -0.3),
    "hand_r": (-0.31, -0.04, 1.02), "elbow_r": (-0.4, 1.0, -0.3),
}


def merge(*dicts):
    out = {}
    for d in dicts:
        out.update(d)
    return out


# ----------------------------------------------------------------- gaits

def gait(T, speed, direction=(0.0, -1.0), stance=0.6, lift=0.12, hips_z=-0.05, bob=0.02,
         running=False, lean=4.0, yaw_amp=6.0, sway=0.025, width=0.11, arm_amp=0.16,
         arm_z=1.02, arm_fwd=-0.02, elbow_bend=0.0, heel=0.06, armed=False, bounce_arms=0.02):
    """A locomotion cycle of length T moving at `speed` along `direction`.

    The left foot touches down at t = 0, the right at T/2.
    """
    d = Vector((direction[0], direction[1], 0.0)).normalized()
    fwd = -d.y          # +1 moving forward, -1 backward
    lat = d.x           # +1 moving to the character's left
    travel = speed * T * stance
    ahead, behind = 0.42 * travel, 0.58 * travel

    def foot(phase, side):
        """Ankle position, foot rotation and toe bend at a phase 0..1."""
        base = Vector((width * side, 0.0, ANKLE_Z))
        if phase < stance:
            s = phase / stance
            along = ahead - s * travel
            z = ANKLE_Z
            pitch = 0.0
            if s < 0.15:                      # heel strike, foot rolls flat
                pitch = -12.0 * (1 - s / 0.15)
            if s > 0.65:                      # heel comes up for toe-off
                k = (s - 0.65) / 0.35
                z += heel * k * k
                pitch = (30.0 if running else 24.0) * k
            bulge = 0.0
        else:
            s = (phase - stance) / (1 - stance)
            e = s * s * (3 - 2 * s)
            along = -behind + e * (ahead + behind)
            z = ANKLE_Z + heel * (1 - s) ** 2 + lift * math.sin(math.pi * min(1.0, s * 1.15))
            if running:                       # heel kicks up behind
                z += lift * 0.9 * math.sin(math.pi * min(1.0, s * 1.6)) * (1 - s)
            pitch = (30.0 if running else 24.0) * (1 - s) ** 2 - 12.0 * s * s
            bulge = 0.035 * math.sin(math.pi * s)   # swing foot passes slightly outside
        pos = base + d * along + Vector((side * bulge * abs(fwd), 0, 0))
        if abs(lat) > 0.5:                    # strafing: feet stay apart along X
            pos.x = width * side * 1.25 + d.x * along
            pos.y = -0.04 * side
        pitch_s = pitch * fwd
        roll_s = pitch * -lat * 0.5
        toe = -max(0.0, pitch_s) * 0.9
        return tuple(pos), (pitch_s, roll_s, 0.0), toe

    def pose(t):
        ph = (t / T) % 1.0
        P = {}
        for s, side, off in (("l", 1, 0.0), ("r", -1, 0.5)):
            pos, rot, toe = foot((ph + off) % 1.0, side)
            P["foot_" + s] = pos
            P["foot_%s_rot" % s] = rot
            P["toe_" + s] = toe
            P["knee_" + s] = (0.12 * side, -1.0, 0.0)
        c2 = math.cos(4 * math.pi * (ph - (stance * 0.5 if running else 0.0)))
        hz = hips_z - bob * c2 if not running else hips_z - bob * c2
        sx = sway * math.cos(2 * math.pi * (ph - stance * 0.5))
        yaw = -yaw_amp * math.cos(2 * math.pi * ph) * abs(fwd)
        P["hips"] = (sx * abs(fwd) + d.x * 0.02, d.y * 0.03, hz)
        P["hips_rot"] = (lean * fwd * 0.5 + 2.0, lean * lat * 0.6 + 2.5 * math.cos(2 * math.pi * (ph - 0.25)) * abs(fwd), yaw)
        P["spine"] = (lean * fwd * 0.5, lean * lat * 0.3, -yaw * 0.5)
        P["chest"] = (lean * 0.15 * fwd, 0.0, -yaw * 0.5)
        P["upper"] = (0.0, -2.0 * math.cos(2 * math.pi * (ph - 0.25)) * abs(fwd), -yaw * 0.6)
        P["neck"] = (-lean * 0.4 * fwd, 0.0, yaw * 0.3)
        P["head"] = (-lean * 0.5 * fwd, -lean * lat * 0.4, yaw * 0.3)
        swing = math.cos(2 * math.pi * ph) * abs(fwd)
        lift_l = max(0.0, -swing) * bounce_arms * 4
        lift_r = max(0.0, swing) * bounce_arms * 4
        if lat:
            swing *= 0.3
        # Hands swing beside the body (block torsos are wide), a little ahead
        # of the hips; bent arms (running) pump forward more than back.
        ax = 0.31 - elbow_bend * 0.04
        ay = arm_fwd - 0.08 * elbow_bend
        P["hand_l"] = (ax, ay + arm_amp * swing, arm_z + lift_l + elbow_bend * 0.1)
        P["hand_r"] = (-ax, ay - arm_amp * swing, arm_z + lift_r + elbow_bend * 0.1)
        P["elbow_l"] = (0.4, 1.0, -0.35)
        P["elbow_r"] = (-0.4, 1.0, -0.35)
        P["wrist_l"] = (0.0, 0.0, -10.0)
        P["wrist_r"] = (0.0, 0.0, 10.0)
        if armed:
            sw = math.cos(2 * math.pi * ph) * abs(fwd) * 0.6
            P["hand_r"] = (-0.27, -0.20 - 0.07 * sw, 1.08 + 0.03 * abs(sw))
            P["elbow_r"] = (-0.8, 0.6, -0.6)
            P["grip_r"] = (0.25, -0.55 - 0.1 * fwd, 0.8)
        else:
            P["grip_r"] = None
        return P

    return pose


def loop_idle(base, T=2.0, breathe=1.5, hand_bob=0.01):
    def pose(t):
        P = dict(base)
        b = math.sin(2 * math.pi * t / T)
        P["chest"] = add(base.get("chest", (0, 0, 0)), (-breathe * b, 0.0, 0.0))
        P["upper"] = add(base.get("upper", (0, 0, 0)), (-breathe * 0.6 * b, 0.0, 0.0))
        P["hips"] = add(base["hips"], (0.0, 0.0, -0.008 * (0.5 + 0.5 * b)))
        for h in ("hand_l", "hand_r"):
            if h in base:
                P[h] = add(base[h], (0.0, 0.0, hand_bob * b))
        P["head"] = add(base.get("head", (0, 0, 0)), (breathe * 0.5 * b, 0.0, 1.5 * math.sin(2 * math.pi * t / (T * 2))))
        return P
    return pose


# ----------------------------------------------------------- helpers

def spin_keys(base, t0, t1, yaw0, yaw1, steps, extra):
    """Keys that turn the whole fighter (feet pivot with the hips)."""
    keys = []
    for i in range(steps + 1):
        u = i / steps
        yaw = yaw0 + (yaw1 - yaw0) * u
        c, s = math.cos(R(yaw - yaw0)), math.sin(R(yaw - yaw0))
        k = dict(extra(u))
        for f in ("foot_l", "foot_r"):
            p = base[f]
            k[f] = (p[0] * c - p[1] * s, p[0] * s + p[1] * c, p[2])
        for f in ("foot_l_rot", "foot_r_rot"):
            r = base[f]
            k[f] = (r[0], r[1], r[2] + yaw - yaw0)
        k["hips_rot"] = (base["hips_rot"][0], base["hips_rot"][1], yaw)
        keys.append((t0 + (t1 - t0) * u, k, "lin"))
    return keys


def tumble_keys(t0, t1, pitch0, pitch1, steps, hips_z, tuck):
    """Keys for a tucked forward roll/flip about the pelvis."""
    keys = []
    for i in range(steps + 1):
        u = i / steps
        a = pitch0 + (pitch1 - pitch0) * u
        c, s = math.cos(R(a)), math.sin(R(a))
        k = {"hips_rot": (a, 0.0, 0.0), "hips": (0.0, 0.0, hips_z(u))}
        pelvis = Vector((0, 0, 0.98 + hips_z(u)))
        for f, x in (("foot_l", 0.11), ("foot_r", -0.11)):
            # tucked: ankles near the backside, knees to the chest
            off = Vector((x, tuck[0], tuck[1]))
            rot = Vector((off.x, off.y * c - off.z * s, off.y * s + off.z * c))
            p = pelvis + rot
            k[f] = (p.x, p.y, p.z)
            k[f + "_rot"] = (a + 40.0, 0.0, 0.0)
            kp = Vector((0, -1.0, 0.3))
            k["knee_" + f[-1]] = (x, kp.y * c - kp.z * s, kp.y * s + kp.z * c)
        keys.append((t0 + (t1 - t0) * u, k, "lin"))
    return keys


# ------------------------------------------------------------ the moves

MOVES = {}


def move(name, fn, length, loop=False, events=None, speed=0.0):
    MOVES[name] = {"fn": fn, "length": length, "loop": loop, "events": events or {}, "speed": speed}


# Idles
move("Idle", loop_idle(GUARD), 2.0, loop=True)
move("Sword_Idle", loop_idle(STANCE), 2.0, loop=True)

# Locomotion (unarmed and armed variants)
_loco = {
    "Walk": dict(T=1.0, speed=1.7, stance=0.6, lift=0.10, hips_z=-0.05, bob=0.018, lean=3.0, yaw_amp=7.0, arm_amp=0.15),
    "Run": dict(T=0.6, speed=4.6, stance=0.36, lift=0.20, hips_z=-0.09, bob=0.03, running=True, lean=10.0, yaw_amp=9.0,
                arm_amp=0.22, arm_z=1.18, elbow_bend=0.6, heel=0.09, sway=0.015),
    "Sprint": dict(T=0.52, speed=6.4, stance=0.3, lift=0.26, hips_z=-0.11, bob=0.035, running=True, lean=20.0, yaw_amp=10.0,
                   arm_amp=0.3, arm_z=1.24, elbow_bend=0.8, heel=0.11, sway=0.01),
    "Strafe_L": dict(T=0.62, speed=2.6, direction=(1.0, 0.0), stance=0.5, lift=0.12, hips_z=-0.08, bob=0.02, lean=6.0, yaw_amp=0.0, width=0.12),
    "Strafe_R": dict(T=0.62, speed=2.6, direction=(-1.0, 0.0), stance=0.5, lift=0.12, hips_z=-0.08, bob=0.02, lean=6.0, yaw_amp=0.0, width=0.12),
    "Backpedal": dict(T=0.7, speed=2.6, direction=(0.0, 1.0), stance=0.55, lift=0.11, hips_z=-0.07, bob=0.02, lean=6.0, yaw_amp=5.0),
}
for _name, _kw in _loco.items():
    move(_name, gait(**_kw), _kw["T"], loop=True, speed=_kw["speed"])
    move(_name + "_Sword", gait(armed=True, **_kw), _kw["T"], loop=True, speed=_kw["speed"])

# Air ---------------------------------------------------------------------
# Every air move has a "_Sword" twin so the blade is held properly.
# The game picks Jump_Rise while going up and Fall while coming down.

def _air_arms(armed, phase):
    """Hands for the air poses. phase: crouch, launch, rise, rise2, fall, fall2, tuck."""
    if armed:
        return {
            "crouch": {"hand_r": (-0.3, 0.14, 1.04), "elbow_r": (-0.6, 0.6, -0.5), "grip_r": (0.15, 0.35, -0.92),
                       "hand_l": (0.28, 0.2, 1.02), "elbow_l": (0.4, 0.8, -0.4)},
            "launch": {"hand_r": (-0.32, -0.08, 1.72), "elbow_r": (-0.8, 0.2, -0.2), "grip_r": (0.1, 0.45, 0.88),
                       "hand_l": (0.4, -0.4, 1.6), "elbow_l": (0.7, 0.3, -0.5)},
            "rise": {"hand_r": (-0.28, 0.16, 1.78), "elbow_r": (-0.8, -0.1, 0.3), "grip_r": (0.15, 0.72, 0.68),
                     "hand_l": (0.26, -0.36, 1.56), "elbow_l": (0.7, 0.3, -0.6)},
            "rise2": {"hand_r": (-0.27, 0.18, 1.82), "elbow_r": (-0.8, -0.1, 0.3), "grip_r": (0.18, 0.76, 0.62),
                      "hand_l": (0.27, -0.38, 1.6), "elbow_l": (0.7, 0.3, -0.6)},
            "fall": {"hand_r": (-0.42, -0.22, 1.4), "elbow_r": (-0.5, 0.6, -0.6), "grip_r": (-0.45, -0.5, -0.74),
                     "hand_l": (0.5, -0.06, 1.55), "elbow_l": (0.2, 0.6, -0.8)},
            "fall2": {"hand_r": (-0.44, -0.18, 1.44), "elbow_r": (-0.5, 0.6, -0.6), "grip_r": (-0.5, -0.45, -0.74),
                      "hand_l": (0.52, -0.12, 1.6), "elbow_l": (0.2, 0.6, -0.8)},
            "tuck": {"hand_r": (-0.56, -0.18, 1.3), "elbow_r": (-0.3, 0.6, -0.7), "grip_r": (0.0, -1.0, 0.12),
                     "hand_l": (0.2, -0.4, 1.12), "elbow_l": (0.6, 0.3, -0.7)},
        }[phase]
    return {
        "crouch": {"hand_l": (0.26, 0.24, 1.0), "hand_r": (-0.26, 0.24, 1.0), "elbow_l": (0.3, 0.8, -0.4), "elbow_r": (-0.3, 0.8, -0.4)},
        "launch": {"hand_l": (0.4, -0.4, 1.62), "hand_r": (-0.4, -0.36, 1.6), "elbow_l": (0.7, 0.3, -0.5), "elbow_r": (-0.7, 0.3, -0.5)},
        "rise": {"hand_l": (0.3, -0.2, 1.7), "hand_r": (-0.36, 0.06, 1.6), "elbow_l": (0.6, 0.4, -0.6), "elbow_r": (-0.6, 0.4, -0.6)},
        "rise2": {"hand_l": (0.31, -0.22, 1.75), "hand_r": (-0.37, 0.08, 1.65), "elbow_l": (0.6, 0.4, -0.6), "elbow_r": (-0.6, 0.4, -0.6)},
        "fall": {"hand_l": (0.5, -0.06, 1.55), "hand_r": (-0.5, -0.06, 1.55), "elbow_l": (0.2, 0.6, -0.8), "elbow_r": (-0.2, 0.6, -0.8)},
        "fall2": {"hand_l": (0.52, -0.12, 1.6), "hand_r": (-0.52, 0.0, 1.5), "elbow_l": (0.2, 0.6, -0.8), "elbow_r": (-0.2, 0.6, -0.8)},
        "tuck": {"hand_l": (0.2, -0.4, 1.12), "hand_r": (-0.2, -0.4, 1.12), "elbow_l": (0.6, 0.3, -0.7), "elbow_r": (-0.6, 0.3, -0.7)},
    }[phase]


_CROUCH = {"hips": (0.0, 0.03, -0.2), "hips_rot": (16.0, 0.0, 0.0), "spine": (8.0, 0, 0), "chest": (2.0, 0, 0), "head": (-6.0, 0, 0),
           "foot_l": (0.13, -0.02, ANKLE_Z), "foot_r": (-0.13, 0.04, ANKLE_Z), "knee_l": (0.2, -1, 0), "knee_r": (-0.2, -1, 0)}
_LAUNCH = {"hips": (0.0, 0.0, 0.04), "hips_rot": (-4.0, 0, 0), "spine": (-6.0, 0, 0), "chest": (-4.0, 0, 0), "head": (-10.0, 0, 0),
           "foot_l": (0.12, 0.06, 0.16), "foot_r": (-0.12, 0.1, 0.12), "foot_l_rot": (40, 0, 0), "foot_r_rot": (45, 0, 0),
           "toe_l": -20.0, "toe_r": -20.0, "knee_l": (0.1, -1, 0), "knee_r": (-0.1, -1, 0)}
_crouch = merge(_CROUCH, {"hand_l": (0.26, 0.15, 1.0), "hand_r": (-0.26, 0.15, 1.0)})   # used by the dodge roll
_RISE = {"hips": (0.0, 0.0, 0.02), "hips_rot": (-2.0, 0, 0), "spine": (-3.0, 0, 0), "chest": (-2.0, 0, 0), "head": (-6.0, 0, 0),
         "foot_l": (0.12, -0.26, 0.6), "foot_l_rot": (25, 0, 0), "knee_l": (0.15, -1, 0.5),
         "foot_r": (-0.12, 0.18, 0.2), "foot_r_rot": (50, 0, 0), "knee_r": (-0.1, -1, 0.0), "toe_l": -8.0, "toe_r": -15.0}
_RISE2 = dict(_RISE, **{"foot_l": (0.12, -0.24, 0.66), "foot_r": (-0.12, 0.22, 0.16)})
_FALL = {"hips": (0.0, 0.0, 0.0), "hips_rot": (6.0, 0, 0), "spine": (4.0, 0, 0), "chest": (2.0, 0, 0), "head": (10.0, 0, 0),
         "foot_l": (0.15, -0.16, 0.34), "foot_l_rot": (15, 0, 0), "knee_l": (0.25, -1, 0.2),
         "foot_r": (-0.15, 0.04, 0.26), "foot_r_rot": (20, 0, 0), "knee_r": (-0.25, -1, 0.1), "toe_l": 0.0, "toe_r": 0.0}
_FALL2 = dict(_FALL, **{"foot_l": (0.15, -0.06, 0.26), "foot_r": (-0.15, -0.14, 0.32), "hips_rot": (8.0, 0, 0)})

for _armed, _sfx in ((False, ""), (True, "_Sword")):
    _base = STANCE if _armed else GUARD
    _a = lambda ph, a=_armed: _air_arms(a, ph)
    move("Jump_Start" + _sfx, Keys(merge(_CROUCH, _a("crouch")), [
        (0.0, {}),
        (0.1, merge(_LAUNCH, _a("launch")), "snap"),
        (0.22, merge(RESET, _RISE, _a("rise")), "smooth"),
    ]), 0.22)
    move("Jump_Rise" + _sfx, Keys(merge(_RISE, _a("rise")), [
        (0.0, {}),
        (0.35, merge(_RISE2, _a("rise2"))),
        (0.7, merge(_RISE, _a("rise"))),
    ]), 0.7, loop=True)
    move("Fall" + _sfx, Keys(merge(_FALL, _a("fall")), [
        (0.0, {}),
        (0.35, merge(_FALL2, _a("fall2"))),
        (0.7, merge(_FALL, _a("fall"))),
    ]), 0.7, loop=True)
    move("Double_Jump" + _sfx, Keys(merge(_RISE, _a("rise")), [
        (0.0, {}),
        (0.05, merge(_a("tuck"), {"spine": (12, 0, 0), "head": (14, 0, 0)}), "out"),
    ] + tumble_keys(0.07, 0.42, 0.0, 360.0, 12, lambda u: -0.15 * math.sin(math.pi * u), (-0.16, -0.32)) + [
        (0.55, merge(RESET, _FALL, _a("fall")), "smooth"),
    ]), 0.55)
    _ground = {"foot_l": (0.13, -0.06, ANKLE_Z), "foot_r": (-0.13, 0.06, ANKLE_Z), "foot_l_rot": (0, 0, 0), "foot_r_rot": (0, 0, 0),
               "toe_l": 0.0, "toe_r": 0.0, "knee_l": (0.2, -1, 0), "knee_r": (-0.2, -1, 0)}
    move("Land" + _sfx, Keys(merge(_FALL, _a("fall"), _ground), [
        (0.0, {}),
        (0.06, merge({"hips": (0.0, 0.03, -0.28), "hips_rot": (18, 0, 0), "spine": (12, 0, 0), "chest": (4, 0, 0), "head": (-12, 0, 0)},
                     _a("crouch") if not _armed else {"hand_r": (-0.45, -0.1, 1.1), "grip_r": (-0.6, -0.2, -0.75),
                                                       "hand_l": (0.32, -0.25, 1.08)}), "snap"),
        (0.32, merge(RESET, _base), "smooth"),
    ]), 0.32)
    _hero = {"hips": (0.0, 0.12, -0.55), "hips_rot": (32.0, 0, -10.0), "spine": (12, 0, 4), "chest": (6, 0, 2), "head": (-24, 0, 6),
             "foot_l": (0.2, -0.26, ANKLE_Z), "foot_r": (-0.14, 0.34, ANKLE_Z), "foot_l_rot": (0, 0, -6), "foot_r_rot": (55, 0, -20),
             "toe_r": -50.0, "knee_l": (0.3, -1, 0.2), "knee_r": (-0.1, -1, -0.6)}
    if _armed:
        _hero_arms = {"hand_l": (0.24, -0.52, 1.0), "elbow_l": (0.7, 0.3, -0.5),
                      "hand_r": (-0.52, 0.22, 1.36), "elbow_r": (-0.4, 0.6, -0.6), "grip_r": (-0.45, 0.85, 0.2)}
    else:
        _hero_arms = {"hand_r": (-0.24, -0.52, 1.0), "elbow_r": (-0.7, 0.3, -0.5),
                      "hand_l": (0.46, 0.2, 1.3), "elbow_l": (0.4, 0.6, -0.6)}
    move("Land_Hard" + _sfx, Keys(merge(_FALL, _a("fall"), _ground), [
        (0.0, {}),
        (0.07, merge(_hero, _hero_arms), "snap"),
        (0.3, {"hips": (0.0, 0.12, -0.52), "head": (-30, 0, 6)}, "lin"),
        (0.62, merge(RESET, _base), "smooth"),
    ]), 0.62)

move("Wall_Kick", Keys(merge(_LAUNCH, _air_arms(False, "launch")), [
    (0.0, {}),
] + tumble_keys(0.04, 0.4, 0.0, -360.0, 12, lambda u: -0.1 * math.sin(math.pi * u), (-0.16, -0.3)) + [
    (0.5, merge(RESET, _FALL, _air_arms(False, "fall")), "smooth"),
]), 0.5)

# Water -----------------------------------------------------------------------
# Treading water: upright with a little lean, legs in a slow alternating
# kick, both hands sculling out and in at chest height. Armed, the weapon
# hand stays up out of the water. The game floats the fighter so the water
# line sits at the lower chest.

def swim(armed, T=1.1):
    def pose(t):
        u = 2 * math.pi * t / T
        s, c = math.sin(u), math.cos(u)
        P = {"hips": (0.0, 0.0, -0.05 + 0.025 * math.sin(2 * u)), "hips_rot": (12.0, 0.0, 0.0),
             "spine": (6.0, 0.0, 0.0), "chest": (2.0, 0.0, 0.0), "upper": (0.0, 0.0, 0.0),
             "neck": (-8.0, 0.0, 0.0), "head": (-10.0, 0.0, 3.0 * s),
             "foot_l": (0.16, 0.05 + 0.16 * s, 0.24 + 0.07 * c), "foot_r": (-0.16, 0.05 - 0.16 * s, 0.24 - 0.07 * c),
             "foot_l_rot": (35.0 + 15.0 * s, 0.0, -10.0), "foot_r_rot": (35.0 - 15.0 * s, 0.0, 10.0),
             "knee_l": (0.35, -1.0, 0.2), "knee_r": (-0.35, -1.0, 0.2), "toe_l": -20.0, "toe_r": -20.0,
             "hand_l": (0.36 + 0.14 * c, -0.3 + 0.05 * s, 1.1), "elbow_l": (0.9, 0.3, -0.3), "wrist_l": (0.0, 0.0, -30.0 * c)}
        if armed:
            P.update({"hand_r": (-0.3, -0.22, 1.55 + 0.03 * s), "elbow_r": (-0.8, 0.2, -0.3), "grip_r": (0.1, -0.45, 0.88)})
        else:
            P.update({"hand_r": (-0.36 - 0.14 * c, -0.3 + 0.05 * s, 1.1), "elbow_r": (-0.9, 0.3, -0.3),
                      "wrist_r": (0.0, 0.0, 30.0 * c)})
        return P
    return pose


move("Swim", swim(False), 1.1, loop=True)
move("Swim_Sword", swim(True), 1.1, loop=True)

# Sword attacks ------------------------------------------------------------
move("Slash_A", Keys(STANCE, [   # forehand, right to left
    (0.0, {}),
    (0.12, {"hips": (-0.04, 0.05, -0.09), "hips_rot": (2.0, -3.0, -40.0), "upper": (0, 0, -18.0), "chest": (0, 0, -6.0),
            "hand_r": (-0.47, 0.06, 1.42), "elbow_r": (-0.3, 0.6, -1.0), "grip_r": (0.35, 0.82, 0.45),
            "hand_l": (0.25, -0.36, 1.32), "head": (-4, 0, 22.0)}, "smooth"),
    (0.2, {"hips": (0.0, -0.04, -0.11), "hips_rot": (5.0, 0.0, 8.0), "upper": (2, 0, 14.0), "chest": (2, 0, 6.0),
           "hand_r": (-0.12, -0.5, 1.3), "elbow_r": (-0.6, 0.4, -0.8), "grip_r": (0.78, -0.62, 0.05),
           "hand_l": (0.3, -0.1, 1.22), "head": (-4, 0, -2.0)}, "snap"),
    (0.29, {"hips": (0.02, -0.07, -0.13), "hips_rot": (7.0, 2.0, 30.0), "upper": (3, 0, 20.0), "chest": (3, 0, 8.0),
            "hand_r": (0.26, -0.28, 1.2), "elbow_r": (-0.5, -0.2, -1.0), "grip_r": (0.78, 0.45, -0.2),
            "hand_l": (0.36, 0.08, 1.16), "head": (-4, 0, -18.0)}, "out"),
    (0.55, merge(RESET, STANCE), "smooth"),
]), 0.55, events={"hit": [0.13, 0.27]})

move("Slash_B", Keys(STANCE, [   # backhand, left to right, rising
    (0.0, {}),
    (0.12, {"hips": (0.02, 0.04, -0.09), "hips_rot": (3.0, 2.0, 22.0), "upper": (0, 0, 16.0),
            "hand_r": (0.12, -0.12, 1.42), "elbow_r": (-0.9, -0.1, 0.2), "grip_r": (0.55, 0.35, 0.75),
            "hand_l": (0.3, -0.05, 1.2), "head": (-4, 0, -14.0)}, "smooth"),
    (0.2, {"hips": (-0.01, -0.04, -0.1), "hips_rot": (4.0, 0.0, -10.0), "upper": (2, 0, -8.0),
           "hand_r": (-0.24, -0.52, 1.34), "elbow_r": (-0.8, 0.1, -0.5), "grip_r": (-0.8, -0.55, 0.22),
           "hand_l": (0.28, -0.3, 1.26), "head": (-4, 0, 4.0)}, "snap"),
    (0.29, {"hips": (-0.03, -0.05, -0.11), "hips_rot": (5.0, -2.0, -38.0), "upper": (2, 0, -16.0),
            "hand_r": (-0.5, -0.12, 1.4), "elbow_r": (-0.4, 0.6, -0.8), "grip_r": (-0.7, 0.58, 0.35),
            "hand_l": (0.22, -0.38, 1.32), "head": (-4, 0, 20.0)}, "out"),
    (0.55, merge(RESET, STANCE), "smooth"),
]), 0.55, events={"hit": [0.13, 0.27]})

move("Slash_C", Keys(STANCE, [   # overhead slam, two hands
    (0.0, {}),
    (0.22, {"hips": (0.0, 0.08, 0.0), "hips_rot": (-8.0, 0, -6.0), "spine": (-8, 0, 2), "chest": (-6, 0, 2), "upper": (-4, 0, 2),
            "foot_r_rot": (12, 0, -35), "toe_r": -12.0,
            "hand_r": (-0.12, 0.08, 1.84), "elbow_r": (-0.9, -0.2, 0.3), "grip_r": (0.0, 0.75, 0.66),
            "hand_l": (-0.02, 0.06, 1.8), "elbow_l": (0.9, -0.2, 0.3), "head": (-12, 0, 0)}, "smooth"),
    (0.33, {"hips": (0.0, -0.12, -0.2), "hips_rot": (10.0, 0, -4.0), "spine": (8, 0, 2), "chest": (4, 0, 2), "upper": (4, 0, 2),
            "foot_r_rot": (0, 0, -35), "toe_r": 0.0,
            "hand_r": (-0.12, -0.56, 1.12), "elbow_r": (-0.7, 0.5, -0.4), "grip_r": (0.05, -0.85, -0.52),
            "hand_l": (-0.03, -0.52, 1.15), "elbow_l": (0.7, 0.5, -0.4), "head": (2, 0, 0)}, "snap"),
    (0.46, {"hips": (0.0, -0.13, -0.22), "hand_r": (-0.12, -0.56, 1.08), "hand_l": (-0.03, -0.52, 1.11)}, "lin"),
    (0.75, merge(RESET, STANCE), "smooth"),
]), 0.75, events={"hit": [0.25, 0.38]})

_coil = {"hips": (-0.03, 0.06, -0.16), "hips_rot": (8.0, -2.0, -48.0), "spine": (6, 0, -6), "chest": (4, 0, -6), "upper": (2, 0, -8),
         "hand_r": (-0.44, 0.3, 1.02), "elbow_r": (-0.5, 0.5, -0.8), "grip_r": (0.2, 0.82, -0.52),
         "hand_l": (0.24, -0.42, 1.3), "elbow_l": (0.7, 0.3, -0.8), "head": (-6, 0, 38.0),
         "foot_l": (0.2, -0.22, ANKLE_Z), "foot_r": (-0.18, 0.22, ANKLE_Z)}


def _charge(t):
    P = Keys(STANCE, [(0.0, _coil)])(0.0)
    w = math.sin(2 * math.pi * t / 0.15) * 0.006   # trembling with power
    P["hand_r"] = add(P["hand_r"], (w, 0.0, w))
    P["hips"] = add(P["hips"], (0.0, 0.0, w * 0.5))
    return P


move("Heavy_Charge", _charge, 0.6, loop=True)


def _spin_extra(u):
    return {"hand_r": (-0.6, -0.12, 1.32), "elbow_r": (-0.2, 0.6, -0.6), "grip_r": (-0.95, -0.25, 0.05),
            "hand_l": (0.42, 0.05, 1.3), "upper": (0, 0, 0), "chest": (0, 0, 0), "spine": (6, 0, 0),
            "hips": (0.0, 0.0, -0.14), "head": (-4, 0, -10 * (1 - u))}


move("Heavy_Release", Keys(merge(STANCE, _coil), [(0.0, {})] + spin_keys(merge(STANCE, _coil), 0.06, 0.42, -48.0, 312.0, 12, _spin_extra) + [
    (0.56, {"hips_rot": (6.0, 0.0, 330.0), "hand_r": (-0.4, -0.35, 1.14), "grip_r": (-0.5, -0.6, 0.5), "hips": (0, 0, -0.1)}, "out"),
    (0.8, merge(RESET, STANCE, {"hips_rot": (4.0, 0.0, 344.0), "foot_l_rot": (0, 0, 350), "foot_r_rot": (0, 0, 325)}), "smooth"),
]), 0.8, events={"hit": [0.08, 0.44]})

# Fists ---------------------------------------------------------------------
move("Jab", Keys(GUARD, [
    (0.0, {}),
    (0.09, {"hand_l": (0.06, -0.62, 1.44), "elbow_l": (0.6, 0.0, -0.8), "hips_rot": (3, 0, -20), "upper": (2, 0, -6),
            "hips": (0.0, -0.03, -0.08), "wrist_l": (0, 0, -60)}, "snap"),
    (0.15, {}, "lin"),
    (0.35, merge(RESET, GUARD), "smooth"),
]), 0.35, events={"hit": [0.06, 0.15]})
move("Cross", Keys(GUARD, [
    (0.0, {}),
    (0.06, {"hips_rot": (3, 0, -18)}, "in"),
    (0.15, {"hand_r": (-0.03, -0.64, 1.44), "elbow_r": (-0.6, 0.0, -0.8), "hips_rot": (5, 0, 18), "upper": (3, 0, 12),
            "hips": (0.0, -0.05, -0.1), "foot_r_rot": (20, 0, -10), "toe_r": -18.0, "wrist_r": (0, 0, 60)}, "snap"),
    (0.22, {}, "lin"),
    (0.45, merge(RESET, GUARD), "smooth"),
]), 0.45, events={"hit": [0.11, 0.22]})
# Rocket Fist: wind up, then a straight right that lets the fist fly.
move("Rocket_Punch", Keys(GUARD, [
    (0.0, {}),
    (0.1, {"hand_r": (-0.2, 0.08, 1.3), "elbow_r": (-0.7, 0.6, -0.6), "hips_rot": (3, 0, -26), "upper": (0, 0, -10),
           "hips": (0.0, 0.04, -0.1)}, "in"),
    (0.18, {"hand_r": (-0.03, -0.7, 1.42), "elbow_r": (-0.6, 0.0, -0.8), "hips_rot": (5, 0, 20), "upper": (3, 0, 14),
            "hips": (0.0, -0.06, -0.12), "foot_r_rot": (20, 0, -10), "toe_r": -18.0, "wrist_r": (0, 0, 60)}, "snap"),
    (0.3, {}, "lin"),
    (0.55, merge(RESET, GUARD), "smooth"),
]), 0.55, events={"release": 0.17})
move("Kick", Keys(GUARD, [
    (0.0, {}),
    (0.14, {"foot_r": (-0.08, -0.22, 0.58), "foot_r_rot": (10, 0, 0), "knee_r": (0, -0.4, 1.0), "hips_rot": (-6, 0, -4),
            "spine": (-6, 0, 0), "hips": (0.02, 0.04, -0.06)}, "smooth"),
    (0.24, {"foot_r": (-0.05, -0.78, 0.82), "foot_r_rot": (-40, 0, 0), "knee_r": (0, -0.2, 1.0), "hips_rot": (-14, 0, 4),
            "spine": (-10, 0, 0), "hips": (0.0, -0.02, -0.04), "hand_l": (0.24, -0.2, 1.38), "hand_r": (-0.34, 0.08, 1.26)}, "snap"),
    (0.34, {}, "lin"),
    (0.46, {"foot_r": (-0.1, -0.24, 0.5), "foot_r_rot": (10, 0, 0), "knee_r": (0, -0.5, 1.0)}, "smooth"),
    (0.6, merge(RESET, GUARD), "smooth"),
]), 0.6, events={"hit": [0.2, 0.34]})

# Throw and catch -----------------------------------------------------------
move("Throw", Keys(STANCE, [
    (0.0, {}),
    (0.22, {"hips": (-0.02, 0.08, -0.08), "hips_rot": (-4, 0, -38), "spine": (-6, 0, -4), "upper": (-4, 0, -14),
            "hand_r": (-0.36, 0.36, 1.66), "elbow_r": (-0.6, 0.3, -0.5), "grip_r": (-0.1, 0.25, 0.96),
            "hand_l": (0.16, -0.56, 1.52), "elbow_l": (0.8, 0.2, -0.4), "head": (-6, 0, 30)}, "smooth"),
    (0.3, {"hips": (0.0, -0.05, -0.1), "hips_rot": (8, 0, 12), "spine": (10, 0, 6), "upper": (6, 0, 14),
           "hand_r": (-0.14, -0.52, 1.52), "elbow_r": (-0.8, 0.2, -0.4), "grip_r": (0.0, -0.9, 0.4),
           "hand_l": (0.3, -0.05, 1.2), "head": (-4, 0, -4)}, "snap"),
    (0.42, {"hips": (0.01, -0.08, -0.12), "hips_rot": (12, 0, 24), "spine": (14, 0, 6),
            "hand_r": (0.12, -0.36, 1.06), "elbow_r": (-0.6, 0.0, -0.8), "grip_r": None, "wrist_r": (30, 0, 0)}, "out"),
    (0.6, merge(RESET, STANCE, {"grip_r": None, "hand_r": (-0.25, -0.12, 1.02)}), "smooth"),
]), 0.6, events={"release": 0.3})

move("Catch", Keys(merge(STANCE, {"grip_r": None, "hand_r": (-0.25, -0.12, 1.02)}), [
    (0.0, {}),
    (0.08, {"hand_r": (-0.2, -0.54, 1.56), "elbow_r": (-0.8, 0.2, -0.3), "wrist_r": (-50, 0, 0), "spine": (-8, 0, 0),
            "hips": (0, 0.05, -0.08), "head": (-12, 0, 0)}, "snap"),
    (0.2, {"hand_r": (-0.26, -0.28, 1.3), "grip_r": (0.1, -0.5, 0.86), "wrist_r": (0, 0, 0), "spine": (3, 0, 5), "head": (-4, 0, 1)}, "smooth"),
    (0.4, merge(RESET, STANCE), "smooth"),
]), 0.4, events={"catch": 0.08})

move("Pickup", Keys(merge(STANCE, {"grip_r": None}), [
    (0.0, {"hand_r": (-0.25, -0.12, 1.02)}),
    (0.18, {"hips": (0.0, 0.06, -0.32), "hips_rot": (30, 0, -10), "spine": (16, 0, 0), "chest": (8, 0, 0),
            "hand_r": (-0.2, -0.46, 1.06), "elbow_r": (-0.6, 0.6, 0.0), "head": (-10, 0, 0)}, "smooth"),
    (0.45, merge(RESET, STANCE), "smooth"),
]), 0.45, events={"grab": 0.18})

# Defence -------------------------------------------------------------------
move("Dodge_Roll", Keys(merge(STANCE, {"grip_r": (0.2, -0.3, 0.93)}), [
    (0.0, {}),
    (0.08, merge(_crouch, {"hand_r": (-0.2, -0.3, 1.1), "hand_l": (0.2, -0.3, 1.1)}), "out"),
] + tumble_keys(0.1, 0.46, 20.0, 360.0, 10, lambda u: -0.24 - 0.4 * math.sin(math.pi * min(1.0, u * 1.2)), (-0.16, -0.34)) + [
    (0.6, merge(RESET, STANCE), "smooth"),
]), 0.6)

# Getting hit ---------------------------------------------------------------
move("Hit_Front", Keys(STANCE, [
    (0.0, {}),
    (0.06, {"spine": (-12, 0, 4), "chest": (-10, 0, 0), "upper": (-8, 0, 0), "head": (-22, 0, 10), "hips": (0.0, 0.08, -0.1),
            "hips_rot": (-6, 0, -16), "hand_l": (0.34, -0.1, 1.42), "hand_r": (-0.42, -0.05, 1.32)}, "snap"),
    (0.4, merge(RESET, STANCE), "smooth"),
]), 0.4)
move("Hit_Back", Keys(STANCE, [
    (0.0, {}),
    (0.06, {"spine": (14, 0, 0), "chest": (10, 0, 0), "head": (16, 0, 0), "hips": (0.0, -0.08, -0.1), "hips_rot": (8, 0, -16),
            "hand_l": (0.34, 0.08, 1.2), "hand_r": (-0.42, 0.1, 1.15)}, "snap"),
    (0.4, merge(RESET, STANCE), "smooth"),
]), 0.4)

_lie_back = {"hips": (0.0, 0.28, -0.84), "hips_rot": (-88.0, 0.0, 0.0), "spine": (-2, 0, 0), "chest": (0, 0, 0), "upper": (0, 0, 0),
             "neck": (4, 0, 0), "head": (6, 0, 0), "grip_r": None,
             "foot_l": (0.16, -0.55, 0.08), "foot_r": (-0.16, -0.56, 0.08), "foot_l_rot": (-60, 0, 10), "foot_r_rot": (-60, 0, -10),
             "knee_l": (0.2, 0, 1), "knee_r": (-0.2, 0, 1),
             "hand_l": (0.5, 0.05, 1.3), "hand_r": (-0.5, 0.05, 1.3), "elbow_l": (0.4, 0.0, -1), "elbow_r": (-0.4, 0, -1)}
move("GetUp_Back", Keys(_lie_back, [
    (0.0, {}),
    (0.3, {"hips_rot": (-30.0, 0, 0), "hips": (0.0, 0.26, -0.82), "spine": (20, 0, 0), "chest": (14, 0, 0), "head": (10, 0, 0),
           "foot_l": (0.16, -0.18, ANKLE_Z), "foot_r": (-0.16, -0.12, ANKLE_Z), "foot_l_rot": (0, 0, 10), "foot_r_rot": (0, 0, -10),
           "knee_l": (0.3, -0.4, 1), "knee_r": (-0.3, -0.4, 1),
           "hand_l": (0.3, 0.45, 0.96), "hand_r": (-0.3, 0.45, 0.96)}, "smooth"),
    (0.6, {"hips_rot": (36.0, 0, 0), "hips": (0.0, 0.08, -0.5), "spine": (16, 0, 0), "chest": (8, 0, 0), "head": (-14, 0, 0),
           "foot_l": (0.16, -0.08, ANKLE_Z), "foot_r": (-0.16, -0.02, ANKLE_Z),
           "knee_l": (0.3, -1, 0.2), "knee_r": (-0.3, -1, 0.2),
           "hand_l": (0.28, -0.3, 1.0), "hand_r": (-0.28, -0.3, 1.0)}, "smooth"),
    (1.1, merge(RESET, STANCE), "smooth"),
]), 1.1)

_lie_front = {"hips": (0.0, 0.42, -0.82), "hips_rot": (90.0, 0.0, 0.0), "spine": (-4, 0, 0), "chest": (-2, 0, 0), "upper": (0, 0, 0),
              "neck": (-16, 0, 0), "head": (-10, 0, 8), "grip_r": None,
              "foot_l": (0.15, 1.2, 0.1), "foot_r": (-0.15, 1.22, 0.1), "foot_l_rot": (90, 0, 0), "foot_r_rot": (90, 0, 0),
              "knee_l": (0.2, 0, -1), "knee_r": (-0.2, 0, -1),
              "hand_l": (0.42, -0.2, 1.36), "hand_r": (-0.42, -0.2, 1.36), "elbow_l": (0.6, 0.2, 0.6), "elbow_r": (-0.6, 0.2, 0.6)}
move("GetUp_Front", Keys(_lie_front, [
    (0.0, {}),
    (0.3, {"hips_rot": (70.0, 0, 0), "hips": (0.0, 0.38, -0.66), "spine": (-6, 0, 0), "neck": (-20, 0, 0),
           "hand_l": (0.26, -0.4, 1.12), "hand_r": (-0.26, -0.4, 1.12), "elbow_l": (0.4, 0.8, 0), "elbow_r": (-0.4, 0.8, 0)}, "smooth"),
    (0.62, {"hips_rot": (40.0, 0, 0), "hips": (0.0, 0.18, -0.52), "spine": (10, 0, 0), "neck": (-10, 0, 0), "head": (-14, 0, 0),
            "foot_l": (0.16, 0.02, ANKLE_Z), "foot_r": (-0.16, 0.12, ANKLE_Z), "foot_l_rot": (0, 0, 0), "foot_r_rot": (14, 0, 0),
            "knee_l": (0.3, -1, 0.3), "knee_r": (-0.3, -1, 0.0),
            "hand_l": (0.3, -0.5, 1.02), "hand_r": (-0.3, -0.5, 1.02), "elbow_l": (0.4, 0.8, -0.3), "elbow_r": (-0.4, 0.8, -0.3)}, "smooth"),
    (1.1, merge(RESET, STANCE), "smooth"),
]), 1.1)

# Fun -------------------------------------------------------------------------
move("Taunt", Keys(STANCE, [
    (0.0, {}),
    (0.25, {"hand_r": (-0.3, -0.48, 1.38), "grip_r": (0.12, -0.98, 0.1), "elbow_r": (-0.8, 0.3, -0.5),
            "hand_l": (0.24, -0.4, 1.26), "wrist_l": (0, -80, 0), "head": (-8, 0, 2), "hips_rot": (2, 0, -24)}, "out"),
    (0.5, {"wrist_l": (-60, -80, 0)}, "smooth"),
    (0.72, {"wrist_l": (0, -80, 0)}, "smooth"),
    (0.94, {"wrist_l": (-60, -80, 0)}, "smooth"),
    (1.16, {"wrist_l": (0, -80, 0), "head": (-14, 0, 2)}, "smooth"),
    (1.6, merge(RESET, STANCE), "smooth"),
]), 1.6)

_victory = merge(STANCE, {"hand_r": (-0.2, 0.0, 1.9), "grip_r": (0.05, 0.0, 1.0), "elbow_r": (-0.9, 0.2, 0.2),
                          "hand_l": (0.3, 0.0, 1.0), "elbow_l": (0.9, 0.5, 0.0), "hips_rot": (-2, 0, 0), "spine": (-6, 0, 0),
                          "head": (-14, 0, 0), "foot_l": (0.16, -0.05, ANKLE_Z), "foot_r": (-0.16, 0.05, ANKLE_Z),
                          "foot_r_rot": (0, 0, -12), "foot_l_rot": (0, 0, 8), "hips": (0, 0, -0.04)})
move("Victory", Keys(_victory, [
    (0.0, {}),
    (0.5, {"hand_r": (-0.2, 0.0, 1.98), "hips": (0, 0, -0.01), "head": (-20, 0, 0)}, "out"),
    (1.0, {"hand_r": (-0.2, 0.0, 1.9), "hips": (0, 0, -0.06), "head": (-12, 0, 0)}, "smooth"),
    (1.5, {"hand_r": (-0.2, 0.0, 1.98), "hips": (0, 0, -0.01), "head": (-20, 0, 0)}, "out"),
    (2.0, {"hand_r": (-0.2, 0.0, 1.9), "hips": (0, 0, -0.04), "head": (-14, 0, 0)}, "smooth"),
]), 2.0, loop=True)

# Block, parry, stagger ---------------------------------------------------------
# Block / Block_Fists are held as an upper-body layer while the legs keep
# moving; Parry is a quick upper-body flick; Stagger is what a parried
# attacker does.
_BLOCK = {"hand_r": (-0.18, -0.38, 1.42), "elbow_r": (-0.8, 0.3, -0.4), "grip_r": (0.85, -0.12, 0.5),
          "hand_l": (0.2, -0.42, 1.5), "elbow_l": (0.8, 0.3, -0.4), "wrist_l": (0, -60, 0),
          "spine": (6.0, 0, 4.0), "chest": (4.0, 0, 3.0), "upper": (3.0, 0, 2.0), "head": (-2.0, 0, 0)}
_BLOCK_FISTS = {"hand_l": (0.1, -0.27, 1.62), "elbow_l": (0.4, -0.3, -1.0), "hand_r": (-0.1, -0.25, 1.6), "elbow_r": (-0.4, -0.3, -1.0),
                "wrist_l": (0, 0, -40), "wrist_r": (0, 0, 40), "grip_r": None,
                "spine": (8.0, 0, 0), "chest": (6.0, 0, 0), "upper": (4.0, 0, 0), "head": (6.0, 0, 0)}


def _breathing(base, T=1.0):
    def pose(t):
        P = dict(base)
        b = math.sin(2 * math.pi * t / T)
        P["chest"] = add(base.get("chest", (0, 0, 0)), (-1.2 * b, 0, 0))
        for h in ("hand_l", "hand_r"):
            P[h] = add(base[h], (0.0, 0.0, 0.006 * b))
        return P
    return pose


move("Block", _breathing(merge(STANCE, _BLOCK)), 1.0, loop=True)
move("Block_Fists", _breathing(merge(GUARD, _BLOCK_FISTS)), 1.0, loop=True)
move("Parry", Keys(merge(STANCE, _BLOCK), [
    (0.0, {}),
    (0.07, {"hand_r": (-0.46, -0.4, 1.5), "elbow_r": (-0.6, 0.4, -0.6), "grip_r": (-0.4, -0.8, 0.45),
            "upper": (3, 0, -12.0), "hand_l": (0.3, -0.25, 1.4)}, "snap"),
    (0.32, merge(STANCE, _BLOCK), "smooth"),
]), 0.32)
move("Parry_Fists", Keys(merge(GUARD, _BLOCK_FISTS), [
    (0.0, {}),
    (0.07, {"hand_l": (0.46, -0.46, 1.48), "elbow_l": (0.6, 0.2, -0.7), "wrist_l": (0, -70, 0), "upper": (3, 0, 14.0)}, "snap"),
    (0.3, merge(GUARD, _BLOCK_FISTS), "smooth"),
]), 0.3)
move("Stagger", Keys(STANCE, [
    (0.0, {}),
    (0.1, {"hips": (0.0, 0.14, -0.06), "hips_rot": (-8, 2, -20), "spine": (-14, 0, 6), "chest": (-8, 0, 0), "head": (-22, 0, 8),
           "hand_l": (0.46, 0.22, 1.42), "hand_r": (-0.46, 0.26, 1.36), "grip_r": (-0.5, 0.6, 0.6),
           "foot_r": (-0.16, 0.42, ANKLE_Z), "foot_r_rot": (0, 0, -40)}, "snap"),
    (0.32, {"hips": (0.0, 0.2, -0.1), "spine": (-8, 0, 4), "head": (-10, 0, 4)}, "smooth"),
    (0.62, merge(RESET, STANCE), "smooth"),
]), 0.62)

# Shield ------------------------------------------------------------------------
# The shield rides on the left forearm, held upright in front so its face
# points forward; the right fist waits by the ribs. Bashes shove it out with
# a step, the heavy lifts it overhead and slams it down.
SHIELD_GUARD = merge(GUARD, {
    "hips_rot": (3.0, 0.0, -18.0), "upper": (2.0, 0.0, -4.0),
    "hand_l": (0.1, -0.3, 1.36), "elbow_l": (0.4, -0.3, -1.0), "grip_l": (0.12, 0.0, 1.0), "face_l": (0.25, -1.0, 0.0),
    "hand_r": (-0.2, -0.2, 1.22), "elbow_r": (-0.8, 0.4, -0.6), "wrist_r": (0.0, 0.0, 20.0),
})
_SHIELD_RAISE = {"hand_l": (0.1, -0.24, 1.86), "elbow_l": (0.9, 0.2, 0.0), "grip_l": (0.0, 0.6, 0.8), "face_l": (0.0, -0.8, 0.6),
                 "hips": (0.0, 0.03, -0.13), "spine": (-6.0, 0, 0), "chest": (-4.0, 0, 0), "head": (-6.0, 0, 0),
                 "hand_r": (-0.24, -0.1, 1.2), "knee_l": (0.3, -1.0, 0.0), "knee_r": (-0.4, -1.0, 0.0)}
_SHIELD_BLOCK = {"hand_l": (0.06, -0.32, 1.5), "elbow_l": (0.4, -0.3, -1.0), "grip_l": (0.0, 0.0, 1.0), "face_l": (0.5, -1.0, 0.0),
                 "hand_r": (-0.14, -0.16, 1.32), "elbow_r": (-0.7, 0.2, -0.7),
                 "spine": (8.0, 0, 0), "chest": (6.0, 0, 0), "upper": (4.0, 0, -6.0), "head": (6.0, 0, 0),
                 "hips": (0.0, 0.02, -0.11)}

move("Shield_Idle", loop_idle(SHIELD_GUARD), 2.0, loop=True)
move("Shield_Bash", Keys(SHIELD_GUARD, [
    (0.0, {}),
    (0.08, {"hand_l": (0.13, -0.18, 1.34), "hips_rot": (3, 0, -10), "hips": (0.0, 0.04, -0.08), "spine": (-2, 0, 0)}, "in"),
    (0.16, {"hand_l": (0.08, -0.54, 1.38), "elbow_l": (0.4, -0.45, -1.0), "grip_l": (0.0, 0.0, 1.0), "face_l": (0.65, -1.0, 0.1),
            "hips_rot": (5, 0, -24), "upper": (4, 0, -8),
            "hips": (0.0, -0.16, -0.1), "spine": (12, 0, 0), "chest": (6, 0, 0), "head": (-10, 0, 0),
            "foot_l": (0.16, -0.36, ANKLE_Z)}, "snap"),
    (0.26, {}, "lin"),
    (0.5, merge(RESET, SHIELD_GUARD), "smooth"),
]), 0.5, events={"hit": [0.1, 0.26]})
move("Shield_Bash_B", Keys(SHIELD_GUARD, [
    (0.0, {}),
    (0.1, {"hand_l": (0.36, -0.22, 1.34), "elbow_l": (0.7, 0.0, -1.0), "face_l": (0.8, -0.6, 0.0), "hips_rot": (3, 0, -36),
           "upper": (2, 0, -12)}, "in"),
    (0.2, {"hand_l": (-0.06, -0.5, 1.44), "elbow_l": (0.2, -0.4, -1.0), "face_l": (-0.35, -1.0, 0.0), "hips_rot": (4, 0, 8),
           "upper": (3, 0, 12),
           "hips": (0.0, -0.08, -0.1), "spine": (6, 0, 0)}, "snap"),
    (0.3, {}, "lin"),
    (0.56, merge(RESET, SHIELD_GUARD), "smooth"),
]), 0.56, events={"hit": [0.12, 0.3]})
move("Shield_Raise", _breathing(merge(SHIELD_GUARD, _SHIELD_RAISE)), 1.0, loop=True)
move("Shield_Slam", Keys(merge(SHIELD_GUARD, _SHIELD_RAISE), [
    (0.0, {}),
    (0.06, {"hand_l": (0.1, -0.18, 1.96), "hips": (0.0, 0.04, -0.1)}, "in"),
    (0.16, {"hand_l": (0.06, -0.56, 0.86), "elbow_l": (0.9, 0.1, -0.2), "grip_l": (0.0, 0.55, 0.85), "face_l": (0.25, -0.85, 0.55),
            "hips": (0.0, -0.08, -0.32), "spine": (24, 0, 0),
            "chest": (12, 0, 0), "upper": (6, 0, -8), "head": (-12, 0, 0), "foot_l": (0.17, -0.36, ANKLE_Z),
            "knee_l": (0.3, -1.0, 0.0), "knee_r": (-0.4, -1.0, 0.0)}, "snap"),
    (0.34, {}, "lin"),
    (0.72, merge(RESET, SHIELD_GUARD), "smooth"),
]), 0.72, events={"hit": [0.08, 0.24], "slam": 0.17})
move("Shield_Block", _breathing(merge(SHIELD_GUARD, _SHIELD_BLOCK)), 1.0, loop=True)
move("Shield_Parry", Keys(merge(SHIELD_GUARD, _SHIELD_BLOCK), [
    (0.0, {}),
    (0.07, {"hand_l": (0.2, -0.48, 1.5), "elbow_l": (0.6, -0.3, -1.0), "face_l": (0.9, -1.0, 0.0), "upper": (3, 0, -16.0),
            "hips": (0.0, -0.08, -0.1),
            "spine": (12, 0, 0)}, "snap"),
    (0.32, merge(SHIELD_GUARD, _SHIELD_BLOCK), "smooth"),
]), 0.32)

# Powers ------------------------------------------------------------------------
for _armed, _sfx in ((False, ""), (True, "_Sword")):
    _base = STANCE if _armed else GUARD
    _g = (lambda d: {"grip_r": d}) if _armed else (lambda d: {"grip_r": None})
    move("Power_Stomp" + _sfx, Keys(_base, [
        (0.0, {}),
        (0.2, merge({"foot_r": (-0.1, -0.12, 0.62), "foot_r_rot": (10, 0, 0), "knee_r": (0, -0.6, 1.0), "hips": (0.02, 0.0, 0.02),
                     "hips_rot": (-4, 0, -6), "spine": (-6, 0, 0), "hand_l": (0.3, -0.2, 1.72), "hand_r": (-0.3, -0.2, 1.72),
                     "elbow_l": (0.8, 0.2, -0.3), "elbow_r": (-0.8, 0.2, -0.3)}, _g((0.0, 0.1, 1.0))), "smooth"),
        (0.3, merge({"foot_r": (-0.15, -0.1, ANKLE_Z), "foot_r_rot": (0, 0, 0), "knee_r": (-0.2, -1, 0), "hips": (0.0, 0.02, -0.24),
                     "hips_rot": (16, 0, 0), "spine": (12, 0, 0), "head": (-8, 0, 0), "hand_l": (0.3, -0.36, 1.0), "hand_r": (-0.3, -0.36, 1.0)},
                    _g((0.1, -0.5, -0.86))), "snap"),
        (0.44, {"hips": (0.0, 0.02, -0.26)}, "lin"),
        (0.65, merge(RESET, _base), "smooth"),
    ]), 0.65, events={"power": 0.3})
    move("Power_Roar" + _sfx, Keys(_base, [
        (0.0, {}),
        (0.16, merge({"hips": (0.0, 0.03, -0.16), "hips_rot": (14, 0, 0), "spine": (12, 0, 0), "chest": (8, 0, 0), "head": (10, 0, 0),
                      "hand_l": (-0.12, -0.24, 1.36), "hand_r": (0.12, -0.24, 1.36), "elbow_l": (0.7, 0.2, -0.6), "elbow_r": (-0.7, 0.2, -0.6)},
                     _g((0.2, -0.3, 0.93))), "smooth"),
        (0.3, merge({"hips": (0.0, 0.0, 0.0), "hips_rot": (-6, 0, 0), "spine": (-10, 0, 0), "chest": (-8, 0, 0), "head": (-22, 0, 0),
                     "hand_l": (0.62, -0.05, 1.68), "hand_r": (-0.62, -0.05, 1.68), "elbow_l": (0.4, 0.3, -0.8), "elbow_r": (-0.4, 0.3, -0.8)},
                    _g((-0.4, 0.0, 0.92))), "snap"),
        (0.5, {"hand_l": (0.6, -0.05, 1.64), "hand_r": (-0.6, -0.05, 1.64)}, "lin"),
        (0.72, merge(RESET, _base), "smooth"),
    ]), 0.72, events={"power": 0.3})
    move("Power_Blink" + _sfx, Keys(_base, [
        (0.0, {}),
        (0.08, merge({"hips": (0.0, -0.06, -0.18), "hips_rot": (24, 0, 0), "spine": (14, 0, 0), "head": (-14, 0, 0),
                      "hand_l": (0.3, 0.32, 1.1), "hand_r": (-0.3, 0.32, 1.1), "elbow_l": (0.3, 0.8, 0.2), "elbow_r": (-0.3, 0.8, 0.2)},
                     _g((0.0, 0.7, -0.7))), "snap"),
        (0.3, merge(RESET, _base), "smooth"),
    ]), 0.3, events={"power": 0.08})

# Weapon families (Phase 2) -----------------------------------------------------
# Two-handed weapons: the left hand sits on the handle below the right.

def two_hand(hand_r, grip, gap=0.22):
    g = Vector(grip).normalized()
    h = Vector(hand_r) - g * gap
    return {"hand_r": tuple(hand_r), "grip_r": tuple(grip), "hand_l": (h.x, h.y, h.z), "grip_l": None,
            "elbow_l": (0.7, 0.2, -0.7), "elbow_r": (-0.7, 0.2, -0.7)}


def front_hand(hand_r, grip, gap=0.42):
    """Polearms: the left hand forward on the shaft."""
    g = Vector(grip).normalized()
    h = Vector(hand_r) + g * gap
    return {"hand_r": tuple(hand_r), "grip_r": tuple(grip), "hand_l": (h.x, h.y, h.z),
            "elbow_l": (0.6, 0.4, -0.7), "elbow_r": (-0.6, 0.5, -0.7)}


_HEAVY_BASE = merge(STANCE, {"hips": (0.0, 0.03, -0.1), "foot_l": (0.2, -0.16, ANKLE_Z), "foot_r": (-0.2, 0.2, ANKLE_Z)},
                    two_hand((-0.2, -0.28, 1.25), (-0.2, 0.55, 0.81)))
move("Heavy_Idle", loop_idle(_HEAVY_BASE), 2.0, loop=True)
move("Smash_A", Keys(_HEAVY_BASE, [     # two-handed horizontal swing
    (0.0, {}),
    (0.25, merge({"hips_rot": (4, 0, -46), "upper": (2, 0, -18), "hips": (-0.03, 0.06, -0.12), "head": (-4, 0, 30)},
                 two_hand((-0.46, 0.14, 1.18), (0.2, 0.9, 0.3))), "smooth"),
    (0.36, merge({"hips_rot": (6, 0, 6), "upper": (3, 0, 14), "hips": (0.0, -0.06, -0.14), "head": (-4, 0, -4)},
                 two_hand((-0.1, -0.52, 1.16), (0.9, -0.42, 0.05))), "snap"),
    (0.48, merge({"hips_rot": (8, 0, 34), "upper": (3, 0, 22), "hips": (0.03, -0.08, -0.15), "head": (-4, 0, -24)},
                 two_hand((0.3, -0.2, 1.1), (0.6, 0.75, -0.2))), "out"),
    (0.75, merge(RESET, _HEAVY_BASE), "smooth"),
]), 0.75, events={"hit": [0.3, 0.46]})
move("Smash_B", Keys(_HEAVY_BASE, [     # two-handed overhead slam
    (0.0, {}),
    (0.3, merge({"hips": (0.0, 0.08, 0.0), "hips_rot": (-8, 0, -4), "spine": (-8, 0, 0), "head": (-12, 0, 0)},
                two_hand((-0.1, 0.05, 1.86), (0.0, 0.6, 0.8))), "smooth"),
    (0.42, merge({"hips": (0.0, -0.12, -0.26), "hips_rot": (14, 0, -4), "spine": (10, 0, 0), "head": (6, 0, 0)},
                 two_hand((-0.05, -0.5, 1.02), (0.0, -0.55, -0.84))), "snap"),
    (0.58, {"hips": (0.0, -0.13, -0.27)}, "lin"),
    (0.85, merge(RESET, _HEAVY_BASE), "smooth"),
]), 0.85, events={"hit": [0.34, 0.5]})
_SMASH_COIL = merge({"hips": (0.0, 0.06, -0.2), "hips_rot": (10, 0, -10), "spine": (6, 0, 0), "head": (-8, 0, 6)},
                    two_hand((-0.14, 0.14, 1.82), (0.1, 0.8, 0.6)))


def _smash_charge(t):
    P = Keys(_HEAVY_BASE, [(0.0, _SMASH_COIL)])(0.0)
    w = math.sin(2 * math.pi * t / 0.15) * 0.006
    P["hips"] = add(P["hips"], (0.0, 0.0, w))
    return P


move("Smash_Charge", _smash_charge, 0.6, loop=True)
move("Smash_Release", Keys(merge(_HEAVY_BASE, _SMASH_COIL), [   # leaping slam
    (0.0, {}),
    (0.16, merge({"hips": (0.0, 0.0, 0.12), "hips_rot": (-10, 0, 0), "spine": (-8, 0, 0), "head": (-14, 0, 0),
                  "foot_l": (0.16, -0.1, 0.3), "foot_r": (-0.16, 0.12, 0.24), "foot_l_rot": (30, 0, 0), "foot_r_rot": (30, 0, 0)},
                 two_hand((-0.1, 0.1, 1.9), (0.0, 0.5, 0.86))), "out"),
    (0.32, merge({"hips": (0.0, -0.14, -0.32), "hips_rot": (20, 0, 0), "spine": (12, 0, 0), "head": (4, 0, 0),
                  "foot_l": (0.2, -0.22, ANKLE_Z), "foot_r": (-0.18, 0.2, ANKLE_Z), "foot_l_rot": (0, 0, 0), "foot_r_rot": (0, 0, -20)},
                 two_hand((-0.05, -0.52, 0.98), (0.0, -0.5, -0.86))), "snap"),
    (0.5, {"hips": (0.0, -0.15, -0.33)}, "lin"),
    (0.9, merge(RESET, _HEAVY_BASE), "smooth"),
]), 0.9, events={"hit": [0.26, 0.42], "slam": 0.32})

_SPEAR_BASE = merge(STANCE, {"hips_rot": (4, 0, -24), "upper": (2, 0, 10)}, front_hand((-0.18, -0.16, 1.12), (0.05, -0.95, 0.22)))
move("Spear_Idle", loop_idle(_SPEAR_BASE), 2.0, loop=True)
move("Spear_Thrust_A", Keys(_SPEAR_BASE, [
    (0.0, {}),
    (0.12, merge({"hips": (0.0, 0.06, -0.1)}, front_hand((-0.2, 0.08, 1.12), (0.05, -0.95, 0.22))), "smooth"),
    (0.2, merge({"hips": (0.0, -0.1, -0.12), "hips_rot": (6, 0, -14), "foot_l": (0.18, -0.34, ANKLE_Z)},
                front_hand((-0.12, -0.5, 1.2), (0.04, -0.97, 0.2))), "snap"),
    (0.5, merge(RESET, _SPEAR_BASE), "smooth"),
]), 0.5, events={"hit": [0.14, 0.27]})
move("Spear_Thrust_B", Keys(_SPEAR_BASE, [
    (0.0, {}),
    (0.12, merge({"hips": (0.0, 0.06, -0.14)}, front_hand((-0.22, 0.06, 1.0), (0.05, -0.85, 0.5))), "smooth"),
    (0.21, merge({"hips": (0.0, -0.12, -0.08), "hips_rot": (2, 0, -10), "foot_l": (0.18, -0.34, ANKLE_Z), "head": (-10, 0, 0)},
                 front_hand((-0.12, -0.46, 1.42), (0.04, -0.82, 0.57))), "snap"),
    (0.55, merge(RESET, _SPEAR_BASE), "smooth"),
]), 0.55, events={"hit": [0.15, 0.29]})
move("Spear_Sweep", Keys(_SPEAR_BASE, [
    (0.0, {}),
    (0.18, merge({"hips_rot": (4, 0, -50), "upper": (2, 0, -16)}, front_hand((-0.3, 0.0, 1.15), (-0.75, -0.62, 0.1))), "smooth"),
    (0.3, merge({"hips_rot": (6, 0, 0), "upper": (2, 0, 10)}, front_hand((-0.1, -0.36, 1.15), (0.1, -0.99, 0.05))), "snap"),
    (0.42, merge({"hips_rot": (8, 0, 40), "upper": (2, 0, 22)}, front_hand((0.1, -0.2, 1.12), (0.85, -0.5, 0.0))), "out"),
    (0.72, merge(RESET, _SPEAR_BASE), "smooth"),
]), 0.72, events={"hit": [0.22, 0.44]})
move("Spear_Lunge", Keys(_SPEAR_BASE, [   # heavy: long running lunge
    (0.0, {}),
    (0.16, merge({"hips": (0.0, 0.1, -0.2), "hips_rot": (10, 0, -20), "foot_l": (0.18, -0.1, ANKLE_Z), "foot_r": (-0.16, 0.3, ANKLE_Z)},
                 front_hand((-0.24, 0.14, 1.1), (0.05, -0.95, 0.15))), "smooth"),
    (0.3, merge({"hips": (0.0, -0.22, -0.2), "hips_rot": (12, 0, -10), "spine": (10, 0, 0),
                 "foot_l": (0.2, -0.6, ANKLE_Z), "foot_r": (-0.16, 0.36, ANKLE_Z), "foot_r_rot": (30, 0, -30), "toe_r": -30.0},
                front_hand((-0.1, -0.56, 1.2), (0.03, -0.98, 0.12))), "snap"),
    (0.5, {}, "lin"),
    (0.82, merge(RESET, _SPEAR_BASE), "smooth"),
]), 0.82, events={"hit": [0.24, 0.48]})

# Dagger and rapier
move("Stab_A", Keys(STANCE, [
    (0.0, {}),
    (0.07, {"hand_r": (-0.2, -0.1, 1.3), "grip_r": (0.0, -0.9, 0.3), "hips_rot": (4, 0, -26)}, "smooth"),
    (0.13, {"hand_r": (-0.08, -0.58, 1.34), "grip_r": (0.05, -0.98, 0.1), "elbow_r": (-0.6, 0.3, -0.8), "hips_rot": (6, 0, 6),
            "hips": (0, -0.05, -0.1)}, "snap"),
    (0.3, merge(RESET, STANCE), "smooth"),
]), 0.3, events={"hit": [0.09, 0.17]})
move("Stab_B", Keys(STANCE, [
    (0.0, {}),
    (0.07, {"hand_r": (-0.3, -0.1, 1.0), "grip_r": (0.2, -0.6, 0.77), "hips_rot": (6, 0, -8)}, "smooth"),
    (0.14, {"hand_r": (-0.1, -0.5, 1.5), "grip_r": (0.1, -0.5, 0.86), "elbow_r": (-0.6, 0.3, -0.6), "hips_rot": (2, 0, 14),
            "hips": (0, -0.04, -0.06), "head": (-10, 0, 0)}, "snap"),
    (0.32, merge(RESET, STANCE), "smooth"),
]), 0.32, events={"hit": [0.09, 0.18]})
move("Stab_C", Keys(STANCE, [   # overhead ice-pick stab
    (0.0, {}),
    (0.12, {"hand_r": (-0.18, 0.0, 1.8), "grip_r": (0.0, -0.3, -0.95), "elbow_r": (-0.9, -0.1, 0.2), "hips": (0, 0.04, 0.0)}, "smooth"),
    (0.2, {"hand_r": (-0.1, -0.5, 1.1), "grip_r": (0.0, -0.2, -0.98), "hips": (0, -0.08, -0.16), "hips_rot": (12, 0, 0), "spine": (8, 0, 0)}, "snap"),
    (0.45, merge(RESET, STANCE), "smooth"),
]), 0.45, events={"hit": [0.14, 0.24]})
_FENCE = merge(STANCE, {"hips_rot": (2, 0, -62), "upper": (0, 0, 18), "head": (-2, 0, 40), "foot_l": (0.2, -0.24, ANKLE_Z),
                        "foot_r": (-0.16, 0.24, ANKLE_Z), "foot_r_rot": (0, 0, -80),
                        "hand_r": (-0.24, -0.34, 1.32), "grip_r": (0.15, -0.95, 0.2), "hand_l": (0.3, 0.2, 1.6), "elbow_l": (0.5, 0.5, -0.4)})
move("Thrust", Keys(_FENCE, [
    (0.0, {}),
    (0.06, {"hand_r": (-0.26, -0.18, 1.32)}, "smooth"),
    (0.14, {"hand_r": (-0.12, -0.62, 1.36), "grip_r": (0.05, -0.99, 0.1), "hips": (0, -0.16, -0.14), "foot_l": (0.22, -0.5, ANKLE_Z)}, "snap"),
    (0.4, merge(RESET, _FENCE), "smooth"),
]), 0.4, events={"hit": [0.08, 0.2]})
move("Thrust_B", Keys(_FENCE, [
    (0.0, {}),
    (0.07, {"hand_r": (-0.28, -0.16, 1.2), "grip_r": (0.1, -0.85, 0.5)}, "smooth"),
    (0.15, {"hand_r": (-0.14, -0.6, 1.55), "grip_r": (0.05, -0.9, 0.42), "hips": (0, -0.14, -0.1), "foot_l": (0.22, -0.48, ANKLE_Z),
            "head": (-10, 0, 40)}, "snap"),
    (0.44, merge(RESET, _FENCE), "smooth"),
]), 0.44, events={"hit": [0.09, 0.21]})

# Thrown weapons and guns
move("Toss", Keys(STANCE, [
    (0.0, {"grip_r": None}),
    (0.1, {"hand_r": (-0.4, 0.12, 1.52), "elbow_r": (-0.6, 0.6, -0.4), "hips_rot": (4, 0, -30), "upper": (0, 0, -10), "grip_r": None}, "smooth"),
    (0.17, {"hand_r": (-0.08, -0.56, 1.42), "elbow_r": (-0.7, 0.3, -0.6), "hips_rot": (6, 0, 18), "upper": (2, 0, 10), "wrist_r": (20, 0, 0)}, "snap"),
    (0.4, merge(RESET, STANCE, {"grip_r": None, "hand_r": (-0.25, -0.12, 1.1)}), "smooth"),
]), 0.4, events={"release": 0.16})
move("Bomb_Lob", Keys(STANCE, [
    (0.0, {"grip_r": None}),
    (0.18, {"hand_r": (-0.28, 0.32, 0.98), "elbow_r": (-0.3, 0.8, -0.3), "hips_rot": (8, 0, -12), "spine": (8, 0, 0), "grip_r": None,
            "hips": (0, 0.04, -0.12)}, "smooth"),
    (0.3, {"hand_r": (-0.18, -0.5, 1.5), "elbow_r": (-0.6, 0.2, -0.7), "hips_rot": (-4, 0, 8), "spine": (-6, 0, 0), "head": (-12, 0, 0),
           "hips": (0, -0.04, -0.04)}, "snap"),
    (0.55, merge(RESET, STANCE, {"grip_r": None, "hand_r": (-0.25, -0.12, 1.1)}), "smooth"),
]), 0.55, events={"release": 0.28})
_AIM = {"hand_r": (-0.1, -0.56, 1.42), "grip_r": (0.0, -1.0, 0.04), "elbow_r": (-0.6, 0.4, -0.7),
        "hand_l": (-0.02, -0.5, 1.36), "elbow_l": (0.6, 0.4, -0.7), "hips_rot": (2, 0, -14), "upper": (0, 0, 12), "head": (-2, 0, 2)}
move("Aim", _breathing(merge(STANCE, _AIM), 1.2), 1.2, loop=True)
move("Shoot", Keys(merge(STANCE, _AIM), [
    (0.0, {}),
    (0.04, {"hand_r": (-0.1, -0.48, 1.5), "grip_r": (0.0, -0.9, 0.42), "hand_l": (-0.02, -0.44, 1.42)}, "snap"),
    (0.22, merge(STANCE, _AIM), "smooth"),
]), 0.22, events={"fire": 0.01})
_BOW = {"hips_rot": (2, 0, -70), "upper": (0, 0, 22), "head": (-2, 0, 46),
        "hand_l": (0.06, -0.62, 1.44), "grip_l": (0.0, 0.1, 1.0), "elbow_l": (0.5, 0.3, -0.8),
        "hand_r": (-0.12, -0.02, 1.48), "grip_r": None, "elbow_r": (-0.9, 0.2, 0.0), "wrist_r": (0, 0, 30),
        "foot_l": (0.2, -0.22, ANKLE_Z), "foot_r": (-0.18, 0.22, ANKLE_Z), "foot_r_rot": (0, 0, -80)}
move("Bow_Draw", _breathing(merge(STANCE, _BOW), 1.0), 1.0, loop=True)
move("Bow_Release", Keys(merge(STANCE, _BOW), [
    (0.0, {}),
    (0.05, {"hand_r": (-0.2, 0.18, 1.5), "wrist_r": (0, 0, 60)}, "snap"),
    (0.32, merge(STANCE, _BOW), "smooth"),
]), 0.32, events={"fire": 0.01})
