"""A small modelling kit for the weapon models (tools/blender/build_weapons.py).

Everything is built in *socket space*, the space the game holds a weapon in:
+Y runs from the grip towards the tip, X is the blade's width (the cutting
edge), Z its thickness. build_weapons.py turns that into Blender's Z-up space
before exporting, so the GLB comes out in socket space again.

Each part gets one colour, whose alpha is its finish (see
src/weapons/weapon.gdshader): 1.0 matte, 0.5 metal, 0.0 glowing.

    b = Builder()
    b.lathe([(0, 0), (0.03, 0, "S"), (0.03, 0.2, "S"), (0, 0.2)], LEATHER)   # a grip
    b.slab([(-0.04, 0.1), (0.04, 0.1), (0, 0.9)], 0.02, STEEL, bevel=0.02)  # a blade
    b.tube([(0, 0, 0), (0.2, 0.3, 0), (0.1, 0.6, 0)], 0.02, WOOD, subdiv=4)  # a curved shaft
"""

import math

import bmesh
from mathutils import Euler, Matrix, Vector


def T(loc=(0.0, 0.0, 0.0), rot=(0.0, 0.0, 0.0), scale=1.0):
    """A transform in socket space: move to `loc`, turn by `rot` (degrees about
    X, Y, Z), scale (a number or (x, y, z))."""
    m = Matrix.Translation(Vector(loc)) @ Euler([math.radians(a) for a in rot], "XYZ").to_matrix().to_4x4()
    if isinstance(scale, (tuple, list)):
        m = m @ Matrix.Diagonal((scale[0], scale[1], scale[2], 1.0))
    elif scale != 1.0:
        m = m @ Matrix.Scale(scale, 4)
    return m


def rgba(color):
    return tuple(color) if len(color) == 4 else (color[0], color[1], color[2], 1.0)


def _catmull(pts, n):
    """Catmull-Rom through `pts`, `n` extra points per span."""
    if n <= 0 or len(pts) < 3:
        return list(pts)
    out = []
    for i in range(len(pts) - 1):
        p0 = pts[max(i - 1, 0)]
        p1, p2 = pts[i], pts[i + 1]
        p3 = pts[min(i + 2, len(pts) - 1)]
        for k in range(n + 1):
            t = k / (n + 1)
            t2, t3 = t * t, t * t * t
            out.append(0.5 * ((2 * p1) + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t2 + (-p0 + 3 * p1 - 3 * p2 + p3) * t3))
    out.append(pts[-1])
    return out


def _lerp_list(values, count):
    """Spreads a list of values evenly over `count` points."""
    if len(values) == 1:
        return [values[0]] * count
    out = []
    for i in range(count):
        f = i / max(count - 1, 1) * (len(values) - 1)
        j = min(int(f), len(values) - 2)
        out.append(values[j] + (values[j + 1] - values[j]) * (f - j))
    return out


def arc(cx, cy, r, a0, a1, n):
    """Points on a circle in the XY plane, angles in degrees (0 = +X, 90 = +Y)."""
    return [(cx + r * math.cos(math.radians(a0 + (a1 - a0) * i / n)), cy + r * math.sin(math.radians(a0 + (a1 - a0) * i / n)))
            for i in range(n + 1)]


class Builder:
    """Collects the parts of one weapon into one mesh with a colour per corner."""

    def __init__(self):
        self.bm = bmesh.new()
        self.col = self.bm.loops.layers.float_color.new("Col")

    # ------------------------------------------------------------ bookkeeping

    def _start(self):
        return set(self.bm.faces)

    def _finish(self, before, color, smooth):
        c = rgba(color)
        new = [f for f in self.bm.faces if f not in before]
        for f in new:
            f.smooth = smooth
            for loop in f.loops:
                loop[self.col] = c
        return new

    def _v(self, p, m):
        return self.bm.verts.new(m @ Vector(p))

    def _face(self, verts):
        try:
            return self.bm.faces.new(verts)
        except ValueError:
            return None

    def tri_count(self):
        return sum(len(f.verts) - 2 for f in self.bm.faces)

    # ------------------------------------------------------------- primitives

    def lathe(self, profile, color, m=Matrix(), segs=16, smooth=True, turn=360.0):
        """Revolves `profile` [(r, y), ...] about the local Y axis. Walk it so the
        outside is on your right: bottom pole, outwards, up, inwards, top pole.
        A point marked (r, y, "S") is a hard edge (the shading breaks there)."""
        before = self._start()
        pieces, cur = [], []
        for p in profile:
            cur.append((p[0], p[1]))
            if len(p) > 2 and p[2] == "S":
                pieces.append(cur)
                cur = [(p[0], p[1])]
        pieces.append(cur)
        full = abs(turn - 360.0) < 1e-3
        n_ang = segs if full else segs + 1
        for piece in pieces:
            if len(piece) < 2:
                continue
            rings = []
            for r, y in piece:
                if r < 1e-6:
                    rings.append([self._v((0.0, y, 0.0), m)])
                else:
                    ring = []
                    for k in range(n_ang):
                        a = math.radians(turn) * k / segs
                        ring.append(self._v((r * math.cos(a), y, r * math.sin(a)), m))
                    rings.append(ring)
            for i in range(len(rings) - 1):
                r0, r1 = rings[i], rings[i + 1]
                steps = segs if full else segs
                for k in range(steps):
                    k1 = (k + 1) % n_ang if full else k + 1
                    if len(r0) == 1 and len(r1) == 1:
                        continue
                    if len(r0) == 1:
                        self._face([r0[0], r1[k], r1[k1]])
                    elif len(r1) == 1:
                        self._face([r0[k], r1[0], r0[k1]])
                    else:
                        self._face([r0[k], r1[k], r1[k1], r0[k1]])
        return self._finish(before, color, smooth)

    def cylinder(self, r, y0, y1, color, m=Matrix(), segs=12, r1=None, smooth=True):
        """A capped cylinder (or cone frustum, `r1` at the top) along local Y."""
        top = r if r1 is None else r1
        prof = [(0.0, y0), (r, y0, "S"), (top, y1, "S"), (0.0, y1)] if top > 1e-6 else [(0.0, y0), (r, y0, "S"), (0.0, y1)]
        return self.lathe(prof, color, m, segs, smooth)

    def sphere(self, r, color, m=Matrix(), segs=14, rings=8, smooth=True):
        prof = [(r * math.sin(math.pi * i / rings), -r * math.cos(math.pi * i / rings)) for i in range(rings + 1)]
        prof[0] = (0.0, -r)
        prof[-1] = (0.0, r)
        return self.lathe(prof, color, m, segs, smooth)

    def tube(self, path, radius, color, m=Matrix(), segs=8, subdiv=0, caps=True, closed=False, smooth=True):
        """A round tube along `path` [(x, y, z), ...]; `radius` is a number or a
        list spread along the path. `subdiv` adds smooth points between."""
        before = self._start()
        pts = [Vector(p) for p in path]
        if closed:
            pts = _catmull([pts[-1]] + pts + [pts[0], pts[1]], subdiv)
            step = subdiv + 1
            pts = pts[step:-step]          # one lap, the seam handled below
        else:
            pts = _catmull(pts, subdiv)
        radii = _lerp_list(list(radius) if isinstance(radius, (tuple, list)) else [radius], len(pts))
        n = len(pts)
        tangents = []
        for i in range(n):
            if closed:
                t = pts[(i + 1) % n] - pts[i - 1]
            else:
                t = pts[min(i + 1, n - 1)] - pts[max(i - 1, 0)]
            tangents.append(t.normalized())
        t0 = tangents[0]
        helper = Vector((0, 0, 1)) if abs(t0.z) < 0.9 else Vector((1, 0, 0))
        nrm = (helper - t0 * helper.dot(t0)).normalized()
        rings = []
        for i in range(n):
            t = tangents[i]
            nrm = (nrm - t * nrm.dot(t)).normalized()
            bin_ = nrm.cross(t)
            ring = []
            for k in range(segs):
                a = 2.0 * math.pi * k / segs
                off = nrm * math.cos(a) + bin_ * math.sin(a)
                ring.append(self._v(pts[i] + off * radii[i], m))
            rings.append(ring)
        spans = n if closed else n - 1
        for i in range(spans):
            r0, r1 = rings[i], rings[(i + 1) % n]
            for k in range(segs):
                k1 = (k + 1) % segs
                self._face([r0[k], r1[k], r1[k1], r0[k1]])
        if caps and not closed:
            c0 = self._v(pts[0], m)
            c1 = self._v(pts[-1], m)
            for k in range(segs):
                k1 = (k + 1) % segs
                self._face([c0, rings[0][k1], rings[0][k]])
                self._face([c1, rings[-1][k], rings[-1][k1]])
        return self._finish(before, color, smooth)

    def torus(self, R, r, color, m=Matrix(), segs=20, tube_segs=8, smooth=True):
        """A ring in the local XY plane (around Z)."""
        path = [(R * math.cos(2 * math.pi * i / segs), R * math.sin(2 * math.pi * i / segs), 0.0) for i in range(segs)]
        return self.tube(path, r, color, m, tube_segs, 0, closed=True, smooth=smooth)

    def slab(self, outline, thick, color, m=Matrix(), bevel=0.0, edge=None, smooth=False):
        """A flat shape from a 2D outline [(x, y), ...] (local XY plane), `thick`
        deep along Z. `bevel` insets the flat faces from the outline (a chamfer);
        `edge` is the rim's own thickness at the outline: 0 makes a sharp blade
        edge, None a plain straight side."""
        before = self._start()
        pts = [Vector((p[0], p[1])) for p in outline]
        area = sum(pts[i].x * pts[(i + 1) % len(pts)].y - pts[(i + 1) % len(pts)].x * pts[i].y for i in range(len(pts)))
        if area < 0:
            pts.reverse()
        n = len(pts)
        h = thick * 0.5
        if bevel <= 0.0:
            f = [self._v((p.x, p.y, h), m) for p in pts]
            b = [self._v((p.x, p.y, -h), m) for p in pts]
            self._face(f)
            self._face(list(reversed(b)))
            for i in range(n):
                j = (i + 1) % n
                self._face([b[i], b[j], f[j], f[i]])
            return self._finish(before, color, smooth)
        inner = _inset(pts, bevel)
        e = h if edge is None else edge * 0.5
        if e <= 1e-6:
            rim = [self._v((p.x, p.y, 0.0), m) for p in pts]
            rim_f, rim_b = rim, rim
        else:
            rim_f = [self._v((p.x, p.y, e), m) for p in pts]
            rim_b = [self._v((p.x, p.y, -e), m) for p in pts]
        in_f = [self._v((p.x, p.y, h), m) for p in inner]
        in_b = [self._v((p.x, p.y, -h), m) for p in inner]
        self._face(in_f)
        self._face(list(reversed(in_b)))
        for i in range(n):
            j = (i + 1) % n
            self._face([rim_f[i], rim_f[j], in_f[j], in_f[i]])
            self._face([rim_b[j], rim_b[i], in_b[i], in_b[j]])
            if e > 1e-6:
                self._face([rim_b[i], rim_b[j], rim_f[j], rim_f[i]])
        return self._finish(before, color, smooth)

    def box(self, size, color, m=Matrix(), bevel=0.0, segs=2, smooth=False):
        """A box `size` (x, y, z) centred on the origin, edges rounded by `bevel`."""
        before = self._start()
        sx, sy, sz = size
        res = bmesh.ops.create_cube(self.bm, size=1.0, matrix=Matrix.Diagonal((sx, sy, sz, 1.0)))
        verts = res["verts"]
        if bevel > 0.0:
            edges = list({e for v in verts for e in v.link_edges})
            bmesh.ops.bevel(self.bm, geom=edges, offset=min(bevel, min(size) * 0.45), segments=segs, profile=0.5,
                            affect="EDGES", clamp_overlap=True)
        new = [f for f in self.bm.faces if f not in before]
        bmesh.ops.transform(self.bm, matrix=m, verts=list({v for f in new for v in f.verts}))
        return self._finish(before, color, smooth)


def _inset(pts, d):
    """The outline moved inwards by `d` (CCW outline), mitred at corners."""
    n = len(pts)
    out = []
    for i in range(n):
        p0, p1, p2 = pts[i - 1], pts[i], pts[(i + 1) % n]
        e1 = (p1 - p0).normalized()
        e2 = (p2 - p1).normalized()
        n1 = Vector((-e1.y, e1.x))
        n2 = Vector((-e2.y, e2.x))
        mid = n1 + n2
        if mid.length < 1e-6:
            mid = n1
        mid.normalize()
        k = max(mid.dot(n1), 0.3)
        out.append(p1 + mid * (d / k))
    return out
