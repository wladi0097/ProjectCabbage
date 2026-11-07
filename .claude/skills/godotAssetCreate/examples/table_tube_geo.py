# Project Cabbage desk, mini tube variant (desk card mini_tube), shown instead of table.blend's Table
# and cabbage_mat once the card is stamped (entities/mini_drop/): the same desk (table_geo.py) with a
# trench routed into the top from the mat's back edge to the desk's back edge, where the minis roll
# out under a flush glass lid (mini_tube.blend) toward the window gap, and a square well for the
# intake right of the mat, above the feeder ramp; the same mat with a notch where the trench comes out from under it.
# Same origins, UVs and materials as table.blend.
ASSET = "table_tube"
EXIT_X, NOTCH_W, NOTCH_D = 0.48, 0.125, 0.07      # trench x (Godot), mat notch half width, depth into the mat
TRENCH_Z1, TRENCH_DEPTH = -0.53, 0.2              # Godot z where the trench starts (under the mat notch), depth
INTAKE_X, INTAKE_Z, WELL_HALF = 1.99, -0.07, 0.11  # Godot: right of the mat, above the feeder ramp
import random
random.seed(11)
TOP, THICK = 0.75, 0.075
X0, X1, Y0, Y1 = -2.0, 3.2, -1.25, 0.75   # main top; the L wing (below) carries on left of X0
CY = (Y0 + Y1) / 2
UVS = 0.6          # wood tile = 1.67 m; Godot uv1_scale must match
SPLIT = -0.58      # divider strip centre between the two sections

wood = material("table_wood", (1, 1, 1), 0.0, 0.6)
textured(wood, "table_wood", UVS)
steel = material("table_steel", (0.16, 0.165, 0.17), 1.0, 0.42)


# Mini tube variant: the boards, backing board and back edge band are cut around two openings
# (Blender x0, y0, x1, y1): the glass-lidded trench from the mat's notch to the desk's back edge, and
# the intake's square well. Each is lined with dark steel below the top.
TRENCH = (EXIT_X - 0.115, -TRENCH_Z1, EXIT_X + 0.115, Y1 + 0.01)
WELL = (INTAKE_X - WELL_HALF, -INTAKE_Z - WELL_HALF, INTAKE_X + WELL_HALF, -INTAKE_Z + WELL_HALF)
HOLES = (TRENCH, WELL)


def holed_box(bm, lo, hi, bevel, mat):
    """part_box minus every hole in HOLES (axis-aligned in x/y): the rest as up to four boxes per hole."""
    rects = [(lo[0], lo[1], hi[0], hi[1])]
    for hx0, hy0, hx1, hy1 in HOLES:
        out = []
        for x0, y0, x1, y1 in rects:
            if hx0 >= x1 or hx1 <= x0 or hy0 >= y1 or hy1 <= y0:
                out.append((x0, y0, x1, y1)); continue
            if y0 < hy0: out.append((x0, y0, x1, hy0))
            if hy1 < y1: out.append((x0, hy1, x1, y1))
            if x0 < hx0: out.append((x0, max(y0, hy0), hx0, min(y1, hy1)))
            if hx1 < x1: out.append((hx1, max(y0, hy0), x1, min(y1, hy1)))
        rects = out
    for x0, y0, x1, y1 in rects:
        if x1 - x0 > 0.002 and y1 - y0 > 0.002:
            part_box(bm, (x0, y0, lo[2]), (x1, y1, hi[2]), bevel if min(x1 - x0, y1 - y0) > 3 * bevel else 0.0, mat)

bm = bmesh.new()
# Top: wide, dead-straight boards along X with hairline seams; a few long boards are butt-jointed.
widths = [0.5, 0.48, 0.52, 0.5]   # four wide boards, no butt joints: clean executive top
gap = 0.003
joints = {}
pieces = []
EB = 0.014                                       # steel edge band width
# L wing (2026-11-07, joined seamlessly 2026-11-07): left of X0 a 45 degree corner step (the farm TV
# stands on it), then a short return toward the camera. One desk: the same boards, seams, backing and
# steel band run on round the L. Blender plan (x, y); Godot z = -y.
WX0, RX, RY0 = -3.4, -2.7, -1.6            # wing left edge, return right edge, return front edge
DX, DY = X0, 0.1                           # the diagonal runs from (RX, -0.6) to (DX, DY), x = y - 2.1
DIAG = DX - DY                             # x - y on the diagonal
QY = X0 + EB - DIAG + EB * math.sqrt(2)  # y where the inset diagonal meets the main top's left band
y = Y0 + EB
inner = (Y1 - EB) - y
widths = [w * inner / sum(widths) for w in widths]
for i, w in enumerate(widths):
    xs = [(WX0 if y + gap / 2 >= QY else X0) + EB] + ([joints[i]] if i in joints else []) + [X1 - EB]
    for a, b in zip(xs, xs[1:]):
        lo = (a + (gap / 2 if a > X0 + EB + 0.01 else 0), y + gap / 2, TOP - THICK)
        hi = (b - (gap / 2 if b < X1 - EB - 0.01 else 0), y + w - gap / 2, TOP)
        holed_box(bm, lo, hi, 0.003, 0)
        pieces.append((lo[0], hi[0], lo[1], hi[1]))
    y += w
# Backing board so seams read dark, not floor.
holed_box(bm, (X0 + 0.03, Y0 + 0.03, TOP - THICK - 0.012), (X1 - 0.03, Y1 - 0.03, TOP - 0.03), 0.0, 0)

# Steel edge band around the whole top: chunky, rounded, flush with the wood at TOP.
band = [((X0, Y0), (X1, Y0 + EB)), ((WX0, Y1 - EB), (X1, Y1)), ((X1 - EB, Y0 + EB), (X1, Y1 - EB))]
for (ax, ay), (bx, by) in band:
    holed_box(bm, (ax, ay, TOP - THICK - 0.006), (bx, by, TOP), 0.005, 1)

# Divider between the sections: a low flat steel bar, like the edge band; cabbages may roll against it.
part_box(bm, (SPLIT - 0.016, Y0 + EB, TOP - 0.01), (SPLIT + 0.016, Y1 - EB, TOP + 0.014), 0.006, 1)

# Base: two steel pedestal frames (mid-century office desk), a steel modesty panel at the back.
under = TOP - THICK
for x in (X0 + 0.18, X1 - 0.18):
    for yy in (Y0 + 0.12, Y1 - 0.12):
        part_box(bm, (x - 0.035, yy - 0.035, 0.0), (x + 0.035, yy + 0.035, under), 0.01, 1)
    part_box(bm, (x - 0.03, Y0 + 0.12, 0.10), (x + 0.03, Y1 - 0.12, 0.15), 0.008, 1)    # foot rail
    part_box(bm, (x - 0.03, Y0 + 0.12, under - 0.09), (x + 0.03, Y1 - 0.12, under), 0.008, 1)
part_box(bm, (X0 + 0.18, Y1 - 0.16, 0.25), (X1 - 0.18, Y1 - 0.14, under), 0.006, 1)
part_box(bm, (X0 + 0.18, Y0 + 0.10, under - 0.11), (X1 - 0.18, Y0 + 0.13, under), 0.006, 0)  # front apron


# Steel liners: the trench (floor TRENCH_DEPTH down, open at the back toward the window) and the well.
D = TOP - TRENCH_DEPTH
tx0, ty0, tx1, ty1 = TRENCH
part_box(bm, (tx0, ty0, D - 0.008), (tx1, Y1, D), 0.0, 1)
part_box(bm, (tx0 - 0.008, ty0 - 0.008, D - 0.008), (tx0, Y1, TOP - 0.002), 0.0, 1)
part_box(bm, (tx1, ty0 - 0.008, D - 0.008), (tx1 + 0.008, Y1, TOP - 0.002), 0.0, 1)
part_box(bm, (tx0, ty0 - 0.008, D - 0.008), (tx1, ty0, TOP - 0.002), 0.0, 1)
wx0, wy0, wx1, wy1 = WELL
part_box(bm, (wx0, wy0, TOP - 0.2), (wx1, wy1, TOP - 0.19), 0.0, 1)
for lo, hi in (((wx0 - 0.008, wy0, TOP - 0.2), (wx0, wy1, TOP - 0.002)), ((wx1, wy0, TOP - 0.2), (wx1 + 0.008, wy1, TOP - 0.002)),
               ((wx0, wy0 - 0.008, TOP - 0.2), (wx1, wy0, TOP - 0.002)), ((wx0, wy1, TOP - 0.2), (wx1, wy1 + 0.008, TOP - 0.002))):
    part_box(bm, lo, hi, 0.0, 1)
# L wing (2026-11-07): one desk with the main top. The boards above carry on to WX0 where the corner
# step is full width; below that each board gets a wing piece cut by the diagonal, the same gaps,
# bevel and grain offset as its main board. Backing and steel band run on round the L.
R2 = math.sqrt(2)
YC = RX - EB - DIAG + EB * R2              # inset diagonal meets the return's right band
JX = X0 + EB - gap / 2                     # wing pieces stop a hairline short of the main boards


def plan_slab(bm, pts, z0, z1, bevel, mat):
    """A Blender-plan polygon (x, y) extruded from z0 to z1, every edge bevelled like part_box."""
    part = bmesh.new()
    lo = [part.verts.new((x, y, z0)) for x, y in pts]
    hi = [part.verts.new((x, y, z1)) for x, y in pts]
    part.faces.new(lo); part.faces.new(list(reversed(hi)))
    n = len(pts)
    for k in range(n):
        part.faces.new((lo[k], lo[(k + 1) % n], hi[(k + 1) % n], hi[k]))
    bmesh.ops.recalc_face_normals(part, faces=part.faces)
    if bevel > 0:
        bmesh.ops.bevel(part, geom=list(part.verts) + list(part.edges), offset=bevel, segments=3, profile=0.5,
                        affect="EDGES", clamp_overlap=True)
    merge(bm, part, I, mat)


def wing_right(y):
    """The wing boards' right end at plan y: the return's band, then the diagonal, then the main top."""
    return RX - EB if y <= YC else min(JX, y + DIAG - EB * R2)


wing_of = []                               # each wing piece's main board (its grain offset)
MAIN = len(pieces)
wing_bands = [(k, lo, hi) for k, (a, b, lo, hi) in enumerate(pieces) if lo < QY]
wing_bands.append((len(pieces), RY0 + EB, Y0 + EB - gap / 2))     # the return's front board, past the main top
for k, lo, hi in wing_bands:
    ys = [lo] + [b for b in (YC, JX - DIAG + EB * R2) if lo < b < hi] + [hi]
    pts = [(WX0 + EB, lo)] + [(wing_right(y), y) for y in ys] + [(WX0 + EB, hi)]
    plan_slab(bm, pts, TOP - THICK, TOP, 0.003, 0)
    wing_of.append(k)
    pieces.append((WX0 + EB, max(x for x, _ in pts), lo, hi))
plan_slab(bm, [(X0 + 0.03, Y1 - 0.03), (WX0 + 0.03, Y1 - 0.03), (WX0 + 0.03, RY0 + 0.03), (RX - 0.03, RY0 + 0.03),
               (RX - 0.03, RX - 0.03 - DIAG + 0.03 * R2), (X0 + 0.03, X0 + 0.03 - DIAG + 0.03 * R2)],
          TOP - THICK - 0.012, TOP - 0.03, 0.0, 0)                 # backing board
# Steel band: the wing's left side, the return's front and right side, the diagonal, the main top's
# short left end. Same section and bevel as the main band.
BZ = TOP - THICK - 0.006
for lo, hi in (((WX0, RY0 + EB), (WX0 + EB, Y1 - EB)), ((WX0, RY0), (RX, RY0 + EB)),
               ((RX - EB, RY0 + EB), (RX, RX - DIAG)), ((X0, Y0 + EB), (X0 + EB, DY))):
    part_box(bm, (*lo, BZ), (*hi, TOP), 0.005, 1)
plan_slab(bm, [(RX - EB, RX - DIAG), (RX, RX - DIAG), (DX, DY), (X0 + EB, DY), (X0 + EB, QY), (RX - EB, YC)],
          BZ, TOP, 0.005, 1)
for x, z in ((-3.3, -0.65), (-3.3, 1.5), (-2.8, 1.5), (-2.15, -0.25)):  # steel legs
    part_box(bm, (x - 0.035, -z - 0.035, 0.0), (x + 0.035, -z + 0.035, TOP - THICK), 0.01, 1)
part_box(bm, (-3.3, 0.6, 0.25), (-2.0, 0.62, TOP - THICK), 0.006, 1)  # modesty panel along the back

ob = finish("table_tube", bm, [wood, steel], (0, CY, 0))

# Offset each board's UVs so the grain never runs continuously across boards.
me = ob.data; uv = me.uv_layers["UVMap"].data
offs = [(random.uniform(0, 3), random.uniform(0, 3)) for _ in range(MAIN + 1)]   # + the return's front board
offs = offs[:MAIN] + [offs[k] for k in wing_of]
for p in me.polygons:
    if p.material_index:
        continue
    c = ob.location + p.center
    if c.z < TOP - THICK - 0.005:
        continue
    for k, (a, b, lo, hi) in enumerate(pieces):
        if a <= c.x <= b and lo <= c.y <= hi:
            for li in p.loop_indices:
                uv[li].uv = (uv[li].uv[0] + offs[k][0], uv[li].uv[1] + offs[k][1])

# ---- cabbage mat: bound leather blotter, 1 cm thick, rounded corners, raised border ----
MX0, MX1, MY0, MY1 = -0.45, 1.85, -1.10, 0.60      # Godot z -0.60..1.10
MT, MR, MB = 0.010, 0.025, 0.06                   # thickness, corner radius, border width (= table_mat_pack.py)
matm = material("table_mat", (1, 1, 1), 0.0, 0.7)
textured(matm, "table_mat", 1.0)
mb = bmesh.new()
outline = []
for cx, cy, a0 in ((MX1 - MR, MY0 + MR, -90), (MX1 - MR, MY1 - MR, 0), (MX0 + MR, MY1 - MR, 90), (MX0 + MR, MY0 + MR, 180)):
    for k in range(7):
        a = math.radians(a0 + k * 15)
        outline.append(mb.verts.new((cx + MR * math.cos(a), cy + MR * math.sin(a), TOP)))
    if a0 == 0:   # back edge, right to left: the notch for the tube
        for x, y in ((EXIT_X + NOTCH_W, MY1), (EXIT_X + NOTCH_W, MY1 - NOTCH_D), (EXIT_X - NOTCH_W, MY1 - NOTCH_D), (EXIT_X - NOTCH_W, MY1)):
            outline.append(mb.verts.new((x, y, TOP)))
base = mb.faces.new(outline)
ext = bmesh.ops.extrude_face_region(mb, geom=[base])
top_verts = [v for v in ext["geom"] if isinstance(v, bmesh.types.BMVert)]
bmesh.ops.translate(mb, verts=top_verts, vec=(0, 0, MT))
bmesh.ops.recalc_face_normals(mb, faces=mb.faces)
top_face = [f for f in mb.faces if f.normal.z > 0.9][0]
rim = [e for e in top_face.edges]
bmesh.ops.bevel(mb, geom=rim, offset=0.004, segments=3, profile=0.5, affect="EDGES")
top_face = max((f for f in mb.faces if f.normal.z > 0.99), key=lambda f: f.calc_area())
# Border binding: inset to the border width, then a short slope down 2 mm into the field.
r1 = bmesh.ops.inset_region(mb, faces=[top_face], thickness=MB - 0.006 - 0.004, depth=0)
r2 = bmesh.ops.inset_region(mb, faces=[top_face], thickness=0.006, depth=-0.002)
bmesh.ops.triangulate(mb, faces=[f for f in mb.faces if len(f.verts) > 4], ngon_method="BEAUTY")  # no long fan slivers
for e in mb.edges:   # crisp binding edge; also stops the big field n-gon from shading a diagonal
    if len(e.link_faces) == 2 and e.calc_face_angle(0) > math.radians(10):
        e.smooth = False
mat_ob = finish("cabbage_mat_tube", mb, [matm], ((MX0 + MX1) / 2, (MY0 + MY1) / 2, TOP))
muv = mat_ob.data.uv_layers["UVMap"].data
for p in mat_ob.data.polygons:
    for li in p.loop_indices:
        co = mat_ob.location + mat_ob.data.vertices[mat_ob.data.loops[li].vertex_index].co
        muv[li].uv = ((co.x - MX0) / (MX1 - MX0), (co.y - MY0) / (MY1 - MY0))
FRAME = ((0.3, -0.6, 1.5), (0.1, 0.4, 0.7), 30, 1280, 960)
