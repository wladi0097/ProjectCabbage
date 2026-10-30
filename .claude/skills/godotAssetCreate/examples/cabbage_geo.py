# Project Cabbage: the cabbage (3 variants, one material, atlas UVs).
#   cat blender_lib.py cabbage_geo.py cabbage_preview.py > build.py
# Texture atlas from cabbage_tex.py: rows = tint a/b/c, columns = outer leaf |
# inner leaf | head (top 60 %) + rim/stem (bottom 40 %).
# Each cabbage: a round head, 3-4 inner leaves wrapping diagonally over it
# (transverse coordinates, so no pinch at the pole), 3-5 thick outer leaves
# that cup the head and roll their tips and margins outward. All smooth shaded.
import random

ASSET = "cabbage"
INSET = 0.012                # UV inset inside each atlas cell (mip bleed)


def cells(row):
    y0, y1 = 1 - (row + 1) / 3, 1 - row / 3
    h = y1 - y0
    return {"outer": (0.0, 0.42, y0, y1), "inner": (0.42, 0.84, y0, y1),
            "head": (0.84, 1.0, y0 + h * 0.4, y1), "rim": (0.84, 1.0, y0, y0 + h * 0.4)}


def to_uv(rect, u, v):
    """u in [-1,1] across, v in [0,1] up -> atlas uv."""
    x0, x1, y0, y1 = rect
    x0, x1, y0, y1 = x0 + INSET, x1 - INSET, y0 + INSET, y1 - INSET
    return (x0 + (u + 1) / 2 * (x1 - x0), y0 + v * (y1 - y0))


def tdir(t, w):
    """Transverse sphere coords: t along the leaf's centre line (meridian, may pass 90 deg), w across it."""
    return Vector((math.cos(w) * math.cos(t), math.sin(w), math.cos(w) * math.sin(t)))


class Builder:
    def __init__(self, row, A, C):
        self.bm = bmesh.new(); self.uv = self.bm.loops.layers.uv.new("UVMap"); self.cells = cells(row)
        self.A, self.C = A, C

    def E(self, d, s):
        return Vector((d.x * self.A * s, d.y * self.A * s, d.z * self.C * s))

    def face(self, verts, uvs, want=None):
        if want is not None:  # orient so the normal points along `want`
            n = Vector()
            for k in range(len(verts)):  # Newell normal
                a, b = verts[k].co, verts[(k + 1) % len(verts)].co
                n += Vector(((a.y - b.y) * (a.z + b.z), (a.z - b.z) * (a.x + b.x), (a.x - b.x) * (a.y + b.y)))
            if n.dot(want) < 0:
                verts, uvs = verts[::-1], uvs[::-1]
        f = self.bm.faces.new(verts)
        for l, uv in zip(f.loops, uvs):
            l[self.uv].uv = uv
        return f

    def leaf(self, phi0, roll, half_w, t0, t1, gap, kind, cols, rows, thick=0.0, flare=0.0, curl=0.0,
             edge=0.0, ripple=0.0, lift=0.02, bulge=0.0):
        """One leaf on the head ellipsoid, scaled out by gap + flare*v^2.2 (+ margins rolled out by `edge`).
        thick > 0: closed thick leaf (front, back, rim). thick == 0: front + skirt into the head."""
        rect = self.cells[kind]; rim = self.cells["rim"]
        tc = (t0 + t1) / 2
        R = Matrix.Rotation(phi0, 3, "Z") @ Matrix.Rotation(-tc, 3, "Y") @ Matrix.Rotation(roll, 3, "X") @ Matrix.Rotation(tc, 3, "Y")

        def P(i, j, s_off):
            u = -1 + 2 * i / cols; v = j / rows
            wid = math.sin(math.pi * (0.18 + 0.64 * v)) ** 0.7          # narrow foot, widest ~ 1/2 up, round top
            top = t1 - (t1 - t0) * 0.30 * u * u
            t = t0 + (top - t0) * v - curl * v ** 3
            w = half_w * u * wid
            s = (1 + gap + flare * v ** 2.2 + edge * abs(u) ** 2.5 * v + bulge * (1 - u * u) * math.sin(math.pi * v)
                 + ripple * v ** 2 * math.cos(u * math.pi * 3.0) + lift * max(0.0, 1 - abs(u) * 4))
            return self.E(R @ tdir(t, w), s + s_off * (1 - 0.4 * v)), u, v

        F = [[None] * (rows + 1) for _ in range(cols + 1)]; B = [[None] * (rows + 1) for _ in range(cols + 1)]
        UVf = {}; UVb = {}
        for i in range(cols + 1):
            for j in range(rows + 1):
                p, u, v = P(i, j, 0.0)
                F[i][j] = self.bm.verts.new(p); UVf[F[i][j]] = to_uv(rect, u, v)
                if thick > 0:
                    q, _, _ = P(i, j, -thick)
                else:  # skirt foot just inside the head
                    q = self.E((R @ tdir(t0 + ((t1 - (t1 - t0) * 0.30 * u * u) - t0) * v,
                                         half_w * u * math.sin(math.pi * (0.18 + 0.64 * v)) ** 0.7)), 0.97)
                B[i][j] = self.bm.verts.new(q); UVb[B[i][j]] = to_uv(rect, -u, v)
        for i in range(cols):
            for j in range(rows):
                q = [F[i][j], F[i + 1][j], F[i + 1][j + 1], F[i][j + 1]]
                self.face(q, [UVf[x] for x in q], q[0].co + q[2].co)
                if thick > 0:
                    q = [B[i][j + 1], B[i + 1][j + 1], B[i + 1][j], B[i][j]]
                    self.face(q, [UVb[x] for x in q], -(q[0].co + q[2].co))
        loop = [(i, 0) for i in range(cols)] + [(cols, j) for j in range(rows)] + \
               [(i, rows) for i in range(cols, 0, -1)] + [(0, j) for j in range(rows, 0, -1)]
        centre = sum((F[i][j].co for i in range(cols + 1) for j in range(rows + 1)), Vector()) / ((cols + 1) * (rows + 1))
        for k, (i, j) in enumerate(loop):
            i2, j2 = loop[(k + 1) % len(loop)]
            a, b = F[i][j], F[i2][j2]; c, d = B[i2][j2], B[i][j]
            mid = (a.co + b.co) / 2
            radial = mid.normalized(); out = mid - centre; out -= radial * out.dot(radial)
            t = k / len(loop)
            uvs = [to_uv(rim, -1 + 2 * t, 0.9), to_uv(rim, -1 + 2 * t, 0.9), to_uv(rim, -1 + 2 * t, 0.7), to_uv(rim, -1 + 2 * t, 0.7)]
            self.face([a, b, c, d], uvs, out)

    def head(self, segs=14, rings=9):
        rect = self.cells["head"]; vs = {}
        for j in range(1, rings):
            th = -math.pi / 2 + math.pi * j / rings
            for i in range(segs):
                ph = math.tau * i / segs
                vs[i, j] = self.bm.verts.new(self.E(Vector((math.cos(th) * math.cos(ph), math.cos(th) * math.sin(ph), math.sin(th))), 1.0))
        bot = self.bm.verts.new((0, 0, -self.C)); top = self.bm.verts.new((0, 0, self.C))
        uvj = lambda j: to_uv(rect, 0, j / rings)
        for i in range(segs):
            i2 = (i + 1) % segs
            for j in range(1, rings - 1):
                q = [vs[i, j], vs[i2, j], vs[i2, j + 1], vs[i, j + 1]]
                self.face(q, [uvj(j), uvj(j), uvj(j + 1), uvj(j + 1)])
            self.face([bot, vs[i2, 1], vs[i, 1]], [uvj(0), uvj(1), uvj(1)])
            self.face([vs[i, rings - 1], vs[i2, rings - 1], top], [uvj(rings - 1), uvj(rings - 1), uvj(rings)])

    def stem(self, r=0.008, sides=6):
        """Small dark-green cut stump, mostly hidden between the outer leaf feet."""
        rim = self.cells["rim"]; z0, z1 = -self.C * 0.9, -self.C * 1.12
        a = [self.bm.verts.new((r * math.cos(math.tau * k / sides), r * math.sin(math.tau * k / sides), z0)) for k in range(sides)]
        b = [self.bm.verts.new((r * 0.8 * math.cos(math.tau * k / sides), r * 0.8 * math.sin(math.tau * k / sides), z1)) for k in range(sides)]
        for k in range(sides):
            k2 = (k + 1) % sides
            self.face([a[k], b[k], b[k2], a[k2]], [to_uv(rim, 0, 0.25)] * 4, Vector((math.cos(math.tau * (k + .5) / sides), math.sin(math.tau * (k + .5) / sides), 0)))
        self.face(b, [to_uv(rim, 0, 0.08)] * sides, Vector((0, 0, -1)))

    def done(self, name, mat):
        bm = self.bm
        bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
        lo = Vector([min(v.co[i] for v in bm.verts) for i in range(3)]); hi = Vector([max(v.co[i] for v in bm.verts) for i in range(3)])
        com = (lo + hi) / 2   # ponytail: bbox centre as centre of mass; close for a near-symmetric head
        bmesh.ops.translate(bm, verts=bm.verts, vec=-com)
        me = bpy.data.meshes.new(name); bm.to_mesh(me); bm.free()
        for p in me.polygons:
            p.use_smooth = True
        me.materials.append(mat)
        ob = bpy.data.objects.new(name, me); bpy.context.scene.collection.objects.link(ob)
        print("SIZE", name, tuple(round(x, 3) for x in (hi - lo)), "TRIS", sum(len(p.vertices) - 2 for p in me.polygons), flush=True)
        return ob


D = math.radians
VARIANTS = {
    # name: (tint row, seed, A, C, [outer], [inner])
    # outer: (phi, half width, top t, flare)   inner: (phi, roll, half width, top t)   all degrees
    "cabbage_a": (0, 1, 0.062, 0.060,
                  [(10, 58, 70, 0.22), (100, 56, 64, 0.20), (190, 60, 74, 0.24), (280, 57, 66, 0.22)],
                  [(30, 42, 74, 112), (160, -38, 72, 96), (275, 46, 70, 84)]),
    "cabbage_b": (1, 2, 0.066, 0.056,
                  [(0, 50, 58, 0.24), (72, 48, 64, 0.26), (144, 52, 56, 0.22), (216, 49, 62, 0.26), (288, 51, 54, 0.24)],
                  [(60, -44, 74, 108), (190, 40, 72, 92), (310, -36, 70, 80)]),
    "cabbage_c": (2, 3, 0.058, 0.066,
                  [(40, 72, 76, 0.18), (160, 68, 70, 0.16), (280, 70, 80, 0.20)],
                  [(0, 36, 70, 116), (120, -42, 72, 100), (240, 40, 68, 88)]),
}

mat = material("cabbage", (1, 1, 1), 0.0, 0.5)
textured(mat, "cabbage", 1.0)
_p = mat.node_tree.nodes["Principled BSDF"]
_p.inputs["Coat Weight"].default_value = 0.35; _p.inputs["Coat Roughness"].default_value = 0.3   # waxy sheen (Godot: clearcoat)
CABBAGES = []
for name, (row, seed, A, C, outer, inner) in VARIANTS.items():
    random.seed(seed); b = Builder(row, A, C)
    b.head()
    for k, (ph, rl, hw, top) in enumerate(inner):
        b.leaf(D(ph), D(rl), D(hw), D(-40), D(top), 0.012 + 0.024 * k, "inner", cols=7, rows=6, lift=0.015, bulge=0.02)
    for k, (ph, hw, top, fl) in enumerate(outer):
        b.leaf(D(ph + random.uniform(-6, 6)), D(random.uniform(-10, 10)), D(hw), D(-80), D(top), 0.10 + 0.025 * k,
               "outer", cols=9, rows=7, thick=0.10, flare=fl, curl=D(30), edge=0.07, ripple=0.008, lift=0.03, bulge=0.04)
    b.stem()
    CABBAGES.append(b.done(name, mat))
