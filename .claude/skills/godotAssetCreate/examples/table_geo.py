# Project Cabbage main desk: a big corporate executive desk + the cabbage mat (desk blotter).
# Godot top y = 0.75, x -3.2..3.2, z -0.75..1.25. Blender Z-up, Blender y = -Godot z,
# so the top spans Blender y -1.25 (front) .. 0.75 (back, against the wall at y 0.80).
# Objects: "Table" (table_wood, table_steel) origin on the floor under the top's centre,
# Blender (0, -0.25, 0) = Godot (0, 0, 0.25); "cabbage_mat" (table_mat) origin at the mat's
# bottom centre, Blender (0.70, -0.25, 0.75) = Godot (0.70, 0.75, 0.25).
import random
random.seed(11)
ASSET = "table"
TOP, THICK = 0.75, 0.075
X0, X1, Y0, Y1 = -3.2, 3.2, -1.25, 0.75
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
y = Y0 + EB
inner = (Y1 - EB) - y
widths = [w * inner / sum(widths) for w in widths]
for i, w in enumerate(widths):
    xs = [X0 + EB] + ([joints[i]] if i in joints else []) + [X1 - EB]
    for a, b in zip(xs, xs[1:]):
        lo = (a + (gap / 2 if a > X0 + EB + 0.01 else 0), y + gap / 2, TOP - THICK)
        hi = (b - (gap / 2 if b < X1 - EB - 0.01 else 0), y + w - gap / 2, TOP)
        part_box(bm, lo, hi, 0.003, 0)
        pieces.append((lo[0], hi[0], lo[1], hi[1]))
    y += w
# Backing board so seams read dark, not floor.
part_box(bm, (X0 + 0.03, Y0 + 0.03, TOP - THICK - 0.012), (X1 - 0.03, Y1 - 0.03, TOP - 0.03), 0.0, 0)

# Steel edge band around the whole top: chunky, rounded, flush with the wood at TOP.
band = [((X0, Y0), (X1, Y0 + EB)), ((X0, Y1 - EB), (X1, Y1)),
        ((X0, Y0 + EB), (X0 + EB, Y1 - EB)), ((X1 - EB, Y0 + EB), (X1, Y1 - EB))]
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
