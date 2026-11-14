# Project Cabbage FIELD LINE (chapter 3, replaces the supply console on its 0.42 x 0.24 m plinth):
# a switchboard box. On the slope a black bakelite panel with 24 jewel lamp sockets (3 x 8, one per
# farm) and a count window ("n/24" is a Label3D in Godot); across the front deck a telephone handset
# lying in two chrome cradle rings over a hook switch, with a coiled cord to a grommet on the deck.
# Lifting the handset is the "go to the maps" control.
# Prepend blender_lib.py + desk_vc_common.py. Blender Z-up, front = -Y (Godot +Z). Origin: floor centre.
# Objects: field_line (skinned: bones Body, Receiver; the cord's weights blend from Body to Receiver
# along its length, so it follows the lifted handset) and Lamps (24 lenses, one surface
# `field_line_lamps`, UV.x = (lamp index + 0.5) / 24: the shader lights the first `lit` of them).
ASSET = "field_line"
G, O, C, N = 7, 8, 9, 10                   # window glass, dull oxblood bakelite, cord rubber, dull nickel (lamp sockets)
COLOURS.update({G: (0.012, 0.011, 0.01), O: tuple(float(v) for v in os.environ.get("OXBLOOD", "0.075,0.017,0.015").split(",")), C: (0.05, 0.04, 0.036), N: (0.2, 0.2, 0.21)})
SURFACE.update({G: 0, O: 0, C: 0, N: 1})


def prism(bm, pts, x0, x1, mat, bevel, segs=3):
    part = bmesh.new()
    a = [part.verts.new((x0, y, z)) for y, z in pts]
    b = [part.verts.new((x1, y, z)) for y, z in pts]
    part.faces.new(a[::-1]); part.faces.new(b)
    for i in range(len(pts)):
        j = (i + 1) % len(pts)
        part.faces.new((a[i], a[j], b[j], b[i]))
    bmesh.ops.recalc_face_normals(part, faces=part.faces)
    bmesh.ops.bevel(part, geom=list(part.verts) + list(part.edges), offset=bevel, segments=segs, profile=0.5, affect="EDGES")
    merge(bm, part, I, mat)


def slope_frame(lo, hi):
    """Frame on a slope running from lo to hi (y, z): columns x, s (up the slope), n (out of it)."""
    lo, hi = Vector((0, *lo)), Vector((0, *hi))
    sd = (hi - lo).normalized(); n = Vector((0, -sd.z, sd.y)); p = (lo + hi) / 2
    return Matrix(((1, 0, 0, 0), (0, sd.y, n.y, p.y), (0, sd.z, n.z, p.z), (0, 0, 0, 1)))


def ring(bm, r0, r1, z0, z1, mat, Mx=I, steps=32):
    spin(bm, [(r0, z0), (r1, z0), (r1, z1), (r0, z1), (r0, z0)], mat, Mx, steps)


def spline(pts, n):
    """n + 1 points on a Catmull-Rom curve through pts."""
    p = [Vector(pts[0])] + [Vector(q) for q in pts] + [Vector(pts[-1])]
    out = []
    for k in range(n + 1):
        u = k / n * (len(pts) - 1); i = min(int(u), len(pts) - 2); t = u - i
        a, b, c, d = p[i], p[i + 1], p[i + 2], p[i + 3]
        out.append(0.5 * ((2 * b) + (c - a) * t + (2 * a - 5 * b + 4 * c - d) * t * t + (3 * b - 3 * c + d - a) * t ** 3))
    return out


def coil(guide, radius, turns, per_turn=10):
    """A helix of `turns` round the guide curve; the first and last turn wind in from the centre line."""
    n = turns * per_turn
    g = spline(guide, n)
    out, nrm = [], None
    for k, p in enumerate(g):
        t = (g[min(k + 1, n)] - g[max(k - 1, 0)]).normalized()
        nrm = t.cross(Vector((0, 0, 1))).normalized() if nrm is None else (nrm - t * nrm.dot(t)).normalized()
        b = t.cross(nrm)
        r = radius * min(1.0, k / per_turn, (n - k) / per_turn)
        a = k / per_turn * math.tau
        out.append(p + (nrm * math.cos(a) + b * math.sin(a)) * r)
    return out


body = bmesh.new()
part_box(body, (-0.21, -0.12, 0), (0.21, 0.12, 0.022), 0.01, K)                     # plinth
prism(body, [(-0.112, 0.02), (0.112, 0.02), (0.112, 0.142), (0.092, 0.142), (-0.03, 0.082), (-0.112, 0.082)], -0.2, 0.2, E, 0.012, 4)
FM = slope_frame((-0.03, 0.082), (0.092, 0.142))
part_box(body, (-0.186, -0.05, -0.002), (0.186, 0.05, 0.003), 0.002, K, FM)       # bakelite panel
LR, LAMPS = 0.0088, [(-0.168 + 0.0275 * k, s) for s in (0.031, 0.0, -0.031) for k in range(8)]
for x, s in LAMPS:
    ring(body, LR + 0.0004, LR + 0.004, 0.003, 0.0075, N, FM @ at(x, s, 0), 16)
WX, WW, WS = 0.113, 0.058, 0.032                                                    # count window
part_box(body, (WX - WW, -WS, 0.002), (WX + WW, WS, 0.005), 0.0, G, FM)
for lo, hi in [((WX - WW - 0.008, -WS - 0.008, 0.002), (WX + WW + 0.008, -WS, 0.01)), ((WX - WW - 0.008, WS, 0.002), (WX + WW + 0.008, WS + 0.008, 0.01)),
               ((WX - WW - 0.008, -WS, 0.002), (WX - WW, WS, 0.01)), ((WX + WW, -WS, 0.002), (WX + WW + 0.008, WS, 0.01))]:
    part_box(body, lo, hi, 0.003, H, FM)
HY, DZ, CUP = -0.07, 0.082, 0.09
for x in (-CUP, CUP):                                                               # cradle rings
    ring(body, 0.037, 0.045, DZ - 0.002, DZ + 0.01, H, at(x, HY, 0), 32)
    spin(body, [(0, DZ), (0.037, DZ), (0.037, DZ + 0.003), (0, DZ + 0.003)], F, at(x, HY, 0), 32)   # dark felt in the ring
spin(body, [(0, DZ), (0.013, DZ), (0.013, DZ + 0.004), (0.008, DZ + 0.004), (0.008, DZ + 0.02), (0, DZ + 0.02)], H, at(0, HY, 0), 12)   # hook switch
for x in (-0.17, 0.17):                                                             # rubber feet
    for y in (-0.085, 0.085):
        spin(body, [(0, 0), (0.016, 0), (0.018, 0.006), (0, 0.006)], K, at(x, y, -0.004), 16)
part_box(body, (-0.203, 0.105, 0.05), (0.203, 0.116, 0.06), 0.003, H)               # chrome trim on the back
part_box(body, (-0.203, -0.116, 0.04), (0.203, -0.109, 0.048), 0.003, H)            # and the front
# The cord: from a grommet on the deck's back-left corner in a C over the deck into the left cup.
GROM = Vector((-0.178, -0.044, DZ))
ring(body, 0.004, 0.011, DZ - 0.001, DZ + 0.005, H, at(GROM.x, GROM.y, 0), 16)
ENTRY = Vector((-CUP - 0.034 * 0.7071, HY - 0.034 * 0.7071, DZ + 0.026))
CORD = coil([GROM + Vector((0, 0, -0.004)), GROM + Vector((0, 0, 0.02)), (-0.187, -0.074, 0.112), (-0.164, -0.099, 0.112), ENTRY], 0.006, 11)
merge(body, tube(CORD, 0.004, 6), I, C)

hand = bmesh.new()
BAND = int(os.environ.get("BAND", "0"))    # 1: black bakelite handset with an oxblood grip band
HC = K if BAND else O
for x in (-CUP, CUP):
    spin(hand, [(0, DZ + 0.004), (0.033, DZ + 0.004), (0.036, DZ + 0.02), (0.03, DZ + 0.04), (0, DZ + 0.045)], HC, at(x, HY, 0), 32)
    ring(hand, 0.0345, 0.0375, DZ + 0.017, DZ + 0.023, H, at(x, HY, 0), 32)
part_box(hand, (-CUP, HY - 0.0125, DZ + 0.026), (CUP, HY + 0.0125, DZ + 0.05), 0.009, HC)      # a slim grip between fat cups
if BAND:
    part_box(hand, (-0.035, HY - 0.014, DZ + 0.0245), (0.035, HY + 0.014, DZ + 0.0515), 0.009, O)

ob, arm = rig(ASSET, [("Body", (0, 0, 0), body), ("Receiver", (0, HY, DZ + 0.02), hand)], [paint, metal])
# Cord: weights blend from Body (grommet end) to Receiver (cup end); its tube shades smooth.
me = ob.data
cord_polys = [p for p in me.polygons if p.material_index == C]
cord_verts = {v for p in cord_polys for v in p.vertices}
for v in cord_verts:
    co = me.vertices[v].co
    k = min(range(len(CORD)), key=lambda i: (CORD[i] - co).length_squared)
    t = min(1.0, max(0.0, (k / (len(CORD) - 1) - 0.12) / 0.76)); w = t * t * (3 - 2 * t)
    ob.vertex_groups["Body"].add([v], 1 - w, "REPLACE"); ob.vertex_groups["Receiver"].add([v], w, "REPLACE")
cord_edges = {key for p in cord_polys for key in p.edge_keys}
for e in me.edges:
    if e.key in cord_edges:
        e.use_edge_sharp = False
colourise(ob)

# The 24 lenses: faceted jewels, one object and one surface; UV.x carries the lamp's index.
lens_mat = emissive("field_line_lamps", (0.5, 0.045, 0.03), float(os.environ.get("LIT", "0")), (0.05, 0.012, 0.01))
lenses = bmesh.new()
for x, s in LAMPS:
    spin(lenses, [(0, 0.003), (LR, 0.003), (LR, 0.003 + LR * 0.45), (LR * 0.62, 0.003 + LR * 0.9), (0, 0.003 + LR)], 0, FM @ at(x, s, 0), 8)
lamps = finish("Lamps", lenses, [lens_mat])
centres = [FM @ Vector((x, s, 0.003)) for x, s in LAMPS]
uv = lamps.data.uv_layers["UVMap"]
for poly in lamps.data.polygons:
    i = min(range(24), key=lambda i: (centres[i] - poly.center).length_squared)
    for li in poly.loop_indices:
        uv.data[li].uv = ((i + 0.5) / 24, 0.5)


def lifted(bones):
    b = bones["Receiver"]; inv = b.bone.matrix_local.to_3x3().inverted()
    b.rotation_mode = "QUATERNION"
    from mathutils import Quaternion
    b.rotation_quaternion = Quaternion(inv @ Vector((0, 0, 1)), math.radians(20))
    b.location = inv @ Vector((-0.012, -0.022, 0.05))


STATES = {"lifted": lifted}
FRAME = ((0.42, -0.62, 0.62), (0.0, 0.0, 0.07), 50, 1280, 960)

# For the Godot scene: (x, y, z) Godot = (x, z, -y) Blender. Transform3D rows.
def godot(v): return Vector((v.x, v.z, -v.y))
sd, nn, wc = godot(FM.col[1].to_3d()), godot(FM.col[2].to_3d()), godot(FM @ Vector((WX, 0, 0.0056)))
print("WINDOW Transform3D(1, %.4f, %.4f, 0, %.4f, %.4f, 0, %.4f, %.4f, %.4f, %.4f, %.4f)" % (sd.x, nn.x, sd.y, nn.y, sd.z, nn.z, wc.x, wc.y, wc.z))
print("WINDOW_SIZE", WW * 2, WS * 2, "RECEIVER_PIVOT", tuple(godot(Vector((0, HY, DZ + 0.02)))))
