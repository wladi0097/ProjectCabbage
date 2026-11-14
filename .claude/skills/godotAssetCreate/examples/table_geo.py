# Project Cabbage main desk: a big corporate executive desk + the cabbage mat (desk blotter).
# Godot top y = 0.75, main top x -2.0..3.2, z -0.75..1.25, plus an L wing on the left (WX0..) and a right part (..RX1): a U. Blender Z-up, Blender y = -Godot z,
# so the top spans Blender y -1.25 (front) .. 0.75 (back, against the wall at y 0.80).
# Objects: "Table" (table_wood, table_steel) origin on the floor under the top's centre,
# Blender (0, -0.25, 0) = Godot (0, 0, 0.25); "cabbage_mat" (table_mat) origin at the mat's
# bottom centre, Blender (0.70, -0.25, 0.75) = Godot (0.70, 0.75, 0.25).
import random
random.seed(11)
ASSET = "table"
TOP, THICK = 0.75, 0.075
X0, X1, Y0, Y1 = -2.0, 3.2, -1.25, 0.75   # main top; the L wing (below) carries on left of X0
CY = (Y0 + Y1) / 2
UVS = 0.6          # wood tile = 1.67 m; Godot uv1_scale must match
SPLIT = -0.58      # divider strip centre between the two sections

wood = material("table_wood", (1, 1, 1), 0.0, 0.6)
textured(wood, "table_wood", UVS)
steel = material("table_steel", (0.16, 0.165, 0.17), 1.0, 0.42)

bm = bmesh.new()
# Top: wide, dead-straight boards along X with hairline seams; a few long boards are butt-jointed.
widths = [0.5, 0.48, 0.52, 0.5]   # four wide boards, no butt joints: clean executive top
gap = 0.003
joints = {}
pieces = []
EB = 0.014                                       # steel edge band width
# L desk (2026-11-08): the main top carries on left to WX0 at full depth, and a second arm as wide as
# the main top is deep (both ends the same size) runs from there along the left wall toward the
# camera to AY0. A 45 degree chamfer joins the main top's front edge (at X0) to the arm's inner edge
# (AX1). One desk: the same boards, seams, backing and steel band run round the L. The farm TV
# stands in the back-left corner. Blender plan (x, y); Godot z = -y.
WX0 = -4.6                                 # left edge of the L (Godot x)
AX1 = WX0 + (Y1 - Y0)                      # the arm's inner edge: the arm is as wide as the main top is deep
AY0 = -3.0                                 # the arm's front end (Godot z 3.0, past the desk view)
CH = X0 - Y0                               # x - y on the chamfer, from (X0, Y0) to (AX1, Y0 - (X0 - AX1))
# U desk (2026-11-13, chapter 3's map area): the top also carries on right of X1 to RX1 at full depth, and an arm
# runs from there toward the camera to RAY0 (Godot z 4.0), its inner edge at RAX0; a 45 degree chamfer joins the
# main top's front edge (at X1) to it. Its boards run along y (toward the camera), across the main top's, butt-
# jointed to them at X1; their grain is turned with them (UVs below). Backing and steel band run round the U.
RX1 = 5.8                                  # right edge of the U (Godot x)
RAX0 = 3.5                                 # the right arm's inner edge
RAY0 = -4.0                                # the right arm's front end (Godot z 4.0)
RCH = X1 + Y0                              # x + y on the right chamfer, from (X1, Y0) to (RAX0, RCH - RAX0)
y = Y0 + EB
inner = (Y1 - EB) - y
widths = [w * inner / sum(widths) for w in widths]
for i, w in enumerate(widths):
    xs = [WX0 + EB] + ([joints[i]] if i in joints else []) + [X1]   # butt joint with the right part at X1
    for a, b in zip(xs, xs[1:]):
        lo = (a + (gap / 2 if a > X0 + EB + 0.01 else 0), y + gap / 2, TOP - THICK)
        hi = (b - gap / 2, y + w - gap / 2, TOP)
        part_box(bm, lo, hi, 0.003, 0)
        pieces.append((lo[0], hi[0], lo[1], hi[1]))
    y += w
# Backing board so seams read dark, not floor.
part_box(bm, (WX0 + 0.03, Y0 + 0.03, TOP - THICK - 0.012), (X1 - 0.03, Y1 - 0.03, TOP - 0.03), 0.0, 0)

# Steel edge band around the whole top: chunky, rounded, flush with the wood at TOP.
band = [((X0, Y0), (X1, Y0 + EB)), ((WX0, Y1 - EB), (RX1, Y1))]   # front, back (round the U); no band at X1
for (ax, ay), (bx, by) in band:
    part_box(bm, (ax, ay, TOP - THICK - 0.006), (bx, by, TOP), 0.005, 1)

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

# The L's arm (2026-11-08): four boards like the main top's, cut by the chamfer at their right end;
# the same gaps, bevel and grain. Backing and steel band run on round the L.
R2 = math.sqrt(2)
CHY = Y0 - (X0 - AX1)                      # where the chamfer meets the arm's inner edge
YC = AX1 - EB - CH + EB * R2               # the inset chamfer meets the arm's inner band


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


def arm_right(y):
    """The arm boards' right end at plan y: the inset chamfer, then the arm's inner band."""
    return AX1 - EB if y <= YC else y + CH - EB * R2


MAIN = len(pieces)
ARM = 4
a_lo, a_w = AY0 + EB, (Y0 + EB - (AY0 + EB)) / ARM
for k in range(ARM):
    lo, hi = a_lo + k * a_w + gap / 2, a_lo + (k + 1) * a_w - gap / 2
    ys = [lo] + ([YC] if lo < YC < hi else []) + [hi]
    pts = [(WX0 + EB, lo)] + [(arm_right(y), y) for y in ys] + [(WX0 + EB, hi)]
    plan_slab(bm, pts, TOP - THICK, TOP, 0.003, 0)
    pieces.append((WX0 + EB, max(x for x, _ in pts), lo, hi))
plan_slab(bm, [(WX0 + 0.03, Y0 + 0.03), (WX0 + 0.03, AY0 + 0.03), (AX1 - 0.03, AY0 + 0.03),
               (AX1 - 0.03, AX1 - 0.03 - CH + 0.03 * R2), (Y0 + 0.03 + CH - 0.03 * R2, Y0 + 0.03)],
          TOP - THICK - 0.012, TOP - 0.03, 0.0, 0)                 # backing board under the arm
# Steel band: the L's left side, the arm's front end and inner side, the chamfer. Same section and
# bevel as the main band.
BZ = TOP - THICK - 0.006
for lo, hi in (((WX0, AY0 + EB), (WX0 + EB, Y1 - EB)), ((WX0, AY0), (AX1, AY0 + EB)), ((AX1 - EB, AY0 + EB), (AX1, CHY))):
    part_box(bm, (*lo, BZ), (*hi, TOP), 0.005, 1)
plan_slab(bm, [(X0, Y0), (AX1, CHY), (AX1 - EB, CHY), (AX1 - EB, YC), (Y0 + EB + CH - EB * R2, Y0 + EB), (X0, Y0 + EB)],
          BZ, TOP, 0.005, 1)
for x, z in ((WX0 + 0.1, -0.65), (WX0 + 0.1, -AY0 - 0.1), (AX1 - 0.1, -AY0 - 0.1), (AX1 - 0.1, -CHY + 0.1)):  # steel legs
    part_box(bm, (x - 0.035, -z - 0.035, 0.0), (x + 0.035, -z + 0.035, TOP - THICK), 0.01, 1)
part_box(bm, (WX0 + 0.1, 0.6, 0.25), (X0, 0.62, TOP - THICK), 0.006, 1)  # modesty panel along the back

# The U's right part (2026-11-13): five boards along y from X1 to the outer band, the first cut by the inset chamfer
# and the arm's inner band. Backing, band, legs and modesty panel as on the L.
RCHY = RCH - RAX0                          # where the chamfer meets the arm's inner edge
RI = RCH + EB * R2                         # x + y on the chamfer band's inner edge
R_BOARDS = 5
r_w = (RX1 - EB - X1) / R_BOARDS
for k in range(R_BOARDS):
    a, b = X1 + k * r_w + gap / 2, X1 + (k + 1) * r_w - (gap / 2 if k < R_BOARDS - 1 else 0)
    if k == 0:
        plan_slab(bm, [(a, Y1 - EB), (a, RI - a), (RAX0 + EB, RI - RAX0 - EB), (RAX0 + EB, RAY0 + EB),
                       (b, RAY0 + EB), (b, Y1 - EB)], TOP - THICK, TOP, 0.003, 0)
    else:
        part_box(bm, (a, RAY0 + EB, TOP - THICK), (b, Y1 - EB, TOP), 0.003, 0)
    pieces.append((a, b, RAY0 + EB, Y1 - EB))
RB = RCH + 0.03 * R2                       # backing board, 3 cm in from the chamfer
plan_slab(bm, [(X1 - 0.03, Y1 - 0.03), (RX1 - 0.03, Y1 - 0.03), (RX1 - 0.03, RAY0 + 0.03), (RAX0 + 0.03, RAY0 + 0.03),
               (RAX0 + 0.03, RB - RAX0 - 0.03), (RB - Y0 - 0.03, Y0 + 0.03), (X1 - 0.03, Y0 + 0.03)],
          TOP - THICK - 0.012, TOP - 0.03, 0.0, 0)
for lo, hi in (((RX1 - EB, RAY0 + EB), (RX1, Y1 - EB)), ((RAX0, RAY0), (RX1, RAY0 + EB)), ((RAX0, RAY0 + EB), (RAX0 + EB, RCHY))):
    part_box(bm, (*lo, BZ), (*hi, TOP), 0.005, 1)
plan_slab(bm, [(X1, Y0), (RAX0, RCHY), (RAX0 + EB, RCHY), (RAX0 + EB, RI - RAX0 - EB), (X1, RI - X1)], BZ, TOP, 0.005, 1)
for x, z in ((RX1 - 0.1, -0.65), (RX1 - 0.1, -RAY0 - 0.1), (RAX0 + 0.1, -RAY0 - 0.1), (RAX0 + 0.1, -RCHY + 0.1)):  # steel legs
    part_box(bm, (x - 0.035, -z - 0.035, 0.0), (x + 0.035, -z + 0.035, TOP - THICK), 0.01, 1)
part_box(bm, (X1, 0.6, 0.25), (RX1 - 0.1, 0.62, TOP - THICK), 0.006, 1)  # modesty panel along the back

ob = finish("Table", bm, [wood, steel], (0, CY, 0))

# Offset each board's UVs so the grain never runs continuously across boards.
me = ob.data; uv = me.uv_layers["UVMap"].data
offs = [(random.uniform(0, 3), random.uniform(0, 3)) for _ in pieces]
for p in me.polygons:
    if p.material_index:
        continue
    c = ob.location + p.center
    if c.z < TOP - THICK - 0.005:
        continue
    if c.x > X1 and abs(p.normal.z) > 0.5:   # the right part: boards (and grain) run along y
        for li in p.loop_indices:
            uv[li].uv = (uv[li].uv[1], uv[li].uv[0])
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
mat_ob = finish("cabbage_mat", mb, [matm], ((MX0 + MX1) / 2, (MY0 + MY1) / 2, TOP))
# Non-tiling UVs: 0..1 over the mat's bounding box, straight down.
muv = mat_ob.data.uv_layers["UVMap"].data
for p in mat_ob.data.polygons:
    for li in p.loop_indices:
        co = mat_ob.location + mat_ob.data.vertices[mat_ob.data.loops[li].vertex_index].co
        muv[li].uv = ((co.x - MX0) / (MX1 - MX0), (co.y - MY0) / (MY1 - MY0))
