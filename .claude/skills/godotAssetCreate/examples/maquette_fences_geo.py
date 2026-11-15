# War maquettes: the stone and steel fences (1 cell each), siblings of maquette_geo.py's balsa picket.
# Prepend blender_lib.py (and preview.py after it for a mockup). Blender X = Godot +X (east), Blender
# +Y = Godot -Z (north), Z up; origin at the cell centre on the paper. Cell 0.16 m. An arm runs east
# from the post face to the cell edge (x = CELL / 2), where the neighbour's west arm meets it.
#   stone (PERIMETER FENCING): grey board scored into blocks, a low wide wall between square piers.
#   steel (security grade): dark board panels under a steel-edge mesh band and a wide flat top rail,
#   the tallest of the three tiers.
# GLB=<path> exports the six objects (glb_to_res.gd, prefix maquette); without it a mockup row.
import random

CELL = 0.16
H = CELL / 2
COLS = {"core": (0.84, 0.82, 0.77), "grey_board": (0.26, 0.255, 0.24),
        "dark_board": (0.04, 0.04, 0.045), "steel_edge": (0.42, 0.45, 0.49)}
M = {k: material("maquette_" + k, v, 0.6 if k == "steel_edge" else 0.0, 0.9) for k, v in COLS.items()}


def rot(axis, deg):
    return Matrix.Rotation(math.radians(deg), 4, axis)


def put(bm, part, matrix=I):
    """Like merge() but keeps the part's per-face material indices."""
    bmesh.ops.transform(part, matrix=matrix, verts=part.verts)
    me = bpy.data.meshes.new("tmp"); part.to_mesh(me); part.free()
    bm.from_mesh(me); bpy.data.meshes.remove(me)


def block(lo, hi, skin, edge, outer):
    """A box whose faces for which outer(centre, normal) holds are skin, the rest cut edges (core)."""
    part = boxed(lo, hi, 0.0)
    for f in part.faces:
        f.material_index = skin if outer(f.calc_center_median(), f.normal) else edge
    return part


def slab(lo, hi, skin, edge):
    """A cut board: the faces across its thinnest axis are skin, its narrow faces show the core."""
    thin = min(range(3), key=lambda i: hi[i] - lo[i])
    return block(lo, hi, skin, edge, lambda c, n: abs(n[thin]) > 0.7)


def finish_maquette(name, bm, mats):
    """Sharp edges, box-projected UVs in metres (the maquette shader reads UV as metres)."""
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    uv = bm.loops.layers.uv.get("UVMap") or bm.loops.layers.uv.new("UVMap")
    for e in bm.edges:
        if len(e.link_faces) == 2 and e.calc_face_angle(0) > math.radians(35):
            e.smooth = False
    for f in bm.faces:
        f.smooth = True
        axis = max(range(3), key=lambda i: abs(f.normal[i]))
        a, b = [i for i in range(3) if i != axis]
        for loop in f.loops:
            loop[uv].uv = (loop.vert.co[a], loop.vert.co[b])
    me = bpy.data.meshes.new(name); bm.to_mesh(me); bm.free()
    for m in mats:
        me.materials.append(m)
    ob = bpy.data.objects.new(name, me); bpy.context.scene.collection.objects.link(ob)
    wn = ob.modifiers.new("WeightedNormal", "WEIGHTED_NORMAL"); wn.keep_sharp = True; wn.weight = 100
    return ob


# ---------------------------------------------------------------- stone (grey board masonry)
G, E = 0, 1                      # slots: grey board, core
PIER = 0.064                     # pier section: chunky, wider than the picket's 24 mm post
J = 0.0012                       # score width: a thin cut into the board, not a mortar gap
COURSES = ((0.0, 0.0204), (0.0216, 0.0424), (0.0436, 0.064))   # pier courses: few, tall blocks
WALL_W = 0.046                   # wall thickness (the picket's cap is 34 mm)
WALL_C = ((0.0, 0.024), (0.0252, 0.049))   # wall courses (two long ones), the coping on top
COPE = (0.058, 0.049, 0.057)     # coping width, bottom, top: the wide flat top that reads from above
PCAP = (0.074, 0.064, 0.072)     # pier cap: width, bottom, top (lower than the picket's 88 mm posts)


def stone_course(bm, z0, z1, k, cut=True):
    """One pier course: two blocks split across x or y in turn (a scored joint between them)."""
    h = PIER / 2
    outer = lambda c, n: (max(abs(c.x), abs(c.y)) > h - 1e-5 and abs(n.z) < 0.5) or n.z > 0.7   # tops board: a stump reads grey
    if not cut:
        put(bm, block((-h, -h, z0), (h, h, z1), G, E, outer)); return
    ax = k % 2
    for lo, hi in ((-h, -J / 2), (J / 2, h)):
        a = [-h, -h, z0]; b = [h, h, z1]
        a[ax], b[ax] = lo, hi
        put(bm, block(tuple(a), tuple(b), G, E, outer))


def stone_post():
    bm = bmesh.new()
    h = PIER / 2
    put(bm, boxed((-h + J, -h + J, 0), (h - J, h - J, COURSES[-1][1]), 0.0))   # core behind the scores
    for f in bm.faces:
        f.material_index = E
    for k, (z0, z1) in enumerate(COURSES):
        stone_course(bm, z0, z1, k)
    c = PCAP[0] / 2
    put(bm, slab((-c, -c, PCAP[1]), (c, c, PCAP[2]), G, E))
    return finish_maquette("WallStonePost", bm, [M["grey_board"], M["core"]])


def stone_arm():
    """East arm: two courses in running bond and two coping stones, ending on the cell edge."""
    bm = bmesh.new()
    x0, w = PIER / 2 - 0.002, WALL_W / 2
    core = boxed((x0, -w + J, 0), (H, w - J, WALL_C[-1][1]), 0.0)
    for f in core.faces:
        f.material_index = E
    put(bm, core)
    outer = lambda c, n: abs(n.y) > 0.7
    for k, (z0, z1) in enumerate(WALL_C):
        joints = (0.056,) if k % 2 == 0 else (0.044, 0.068)
        xs = [x0, *joints, H]
        for i in range(len(xs) - 1):
            a = xs[i] + (J / 2 if i > 0 else 0)
            b = xs[i + 1] - (J / 2 if i < len(xs) - 2 else 0)
            put(bm, block((a, -w, z0), (b, w, z1), G, E, outer))
    c = COPE[0] / 2
    for a, b in ((x0, 0.06 - J / 2), (0.06 + J / 2, H)):
        put(bm, block((a, -c, COPE[1]), (b, c, COPE[2]), G, E, lambda c_, n: abs(n.z) > 0.7 or abs(n.y) > 0.7))
    return finish_maquette("WallStoneArm", bm, [M["grey_board"], M["core"]])


def stone_rubble():
    """The pier knocked down to a ragged stump, its blocks and the coping stones tumbled round it."""
    rng = random.Random(21)
    bm = bmesh.new()
    h = PIER / 2
    stone_course(bm, *COURSES[0], 0)
    put(bm, block((-h, J / 2, COURSES[1][0]), (h, h, COURSES[1][1]), G, E,
                  lambda c, n: ((abs(c.x) > h - 1e-5 or c.y > h - 1e-5) and abs(n.z) < 0.5) or n.z > 0.7))   # half a course left
    outer = lambda c, n: abs(n.x) < 0.7     # a loose block shows board on its faces, core on its broken ends
    for (x, y), (l, w, t), rz, tilt in (((0.05, -0.012), (0.024, 0.044, 0.015), 12, 0),
                                        ((-0.052, 0.02), (0.022, 0.044, 0.015), -70, 8),
                                        ((0.018, 0.052), (0.03, 0.022, 0.015), 35, 0),
                                        ((-0.03, -0.054), (0.032, 0.022, 0.015), -20, -10),
                                        ((0.056, 0.048), (0.018, 0.02, 0.014), 60, 15),
                                        ((-0.06, -0.035), (0.016, 0.02, 0.014), 25, 0)):
        part = block((-l / 2, -w / 2, 0), (l / 2, w / 2, t), G, E, outer)
        for v in part.verts:            # broken: one end knocked off at a slant
            if v.co.x > 0:
                v.co.x -= rng.uniform(0, l * 0.25) * (v.co.z / t)
        put(bm, part, at(x, y, 0) @ rot("Z", rz) @ rot("Y", tilt))
    # the pier cap and a coping stone, fallen and propped on the stump
    c = PCAP[0] / 2 * 0.8
    put(bm, slab((-c, -c, 0), (c, c, 0.008), G, E), at(0.012, -0.03, 0.026) @ rot("Z", 22) @ rot("X", 26))
    put(bm, slab((-0.026, -0.024, 0), (0.026, 0.024, 0.008), G, E), at(-0.034, 0.032, 0.006) @ rot("Z", -35) @ rot("Y", 10))
    return finish_maquette("WallStoneRubble", bm, [M["grey_board"], M["core"]])


# ---------------------------------------------------------------- steel (security grade)
D, S, C = 0, 1, 2                 # slots: dark board, steel edge, core
SPOST = 0.022                     # post section
SPOST_H = 0.114                   # post height, under its cap: the tallest of the three tiers
SCAP = (0.046, 0.007)             # post cap: width, thickness; from above a pale square on the dark line
PANEL = (0.008, 0.078, 0.007)     # dark board panel: bottom, top, thickness
FOOT = (0.032, 0.007)             # dark board footing strip: width, height
MESH = (0.078, 0.104, 0.007, 0.0016)   # mesh band: bottom, top, wire pitch, wire section
RAIL = (0.036, 0.104, 0.006)      # dark board coping on the mesh: width, bottom, thickness
STRIP = (0.012, 0.003)            # steel-edge strip along the coping's middle: width, thickness
# From above the steel tier is a dark band with a pale centre line and big pale post caps (stone: a solid
# mid-grey band, wood: a pale strip).


def steel_post():
    bm = bmesh.new()
    p = SPOST / 2
    post = boxed((-p, -p, 0), (p, p, SPOST_H), 0.0)
    for f in post.faces:
        f.material_index = D
    put(bm, post)
    c = SCAP[0] / 2
    put(bm, slab((-c, -c, SPOST_H), (c, c, SPOST_H + SCAP[1]), S, S))
    f = FOOT[0] / 2 + 0.004
    put(bm, slab((-f, -f, 0), (f, f, FOOT[1]), D, C))
    return finish_maquette("WallSteelPost", bm, [M["dark_board"], M["steel_edge"], M["core"]])


def steel_arm():
    """East arm: footing, dark panel, a band of steel wires and a wide flat steel rail on top."""
    bm = bmesh.new()
    x0 = SPOST / 2 - 0.001
    f = FOOT[0] / 2
    put(bm, slab((x0, -f, 0), (H, f, FOOT[1]), D, C))
    b, t, th = PANEL
    put(bm, slab((x0, -th / 2, b), (H, th / 2, t), D, C))
    put(bm, slab((x0, -th / 2 - 0.001, t - 0.002), (H, th / 2 + 0.001, t + 0.004), S, S))   # frame rail on the panel
    mb, mt, pitch, wire = MESH
    x = pitch / 2
    while x < H:
        if x - wire / 2 > x0:
            part = boxed((x - wire / 2, -wire / 2, mb), (x + wire / 2, wire / 2, mt), 0.0)
            for fc in part.faces:
                fc.material_index = S
            put(bm, part)
        x += pitch
    mid = (mb + mt) / 2
    put(bm, slab((x0, -wire / 2, mid - wire / 2), (H, wire / 2, mid + wire / 2), S, S))
    w = RAIL[0] / 2
    put(bm, slab((x0, -w, RAIL[1]), (H, w, RAIL[1] + RAIL[2]), D, C))
    w = STRIP[0] / 2
    top = RAIL[1] + RAIL[2]
    put(bm, slab((x0, -w, top), (H, w, top + STRIP[1]), S, S))
    return finish_maquette("WallSteelArm", bm, [M["dark_board"], M["steel_edge"], M["core"]])


def bent_panel(length, height, kink):
    """A dark panel folded at its middle (the fold on the paper, both ends lifted by `kink` degrees),
    lying on its face, the rail still on one long edge."""
    part = bmesh.new()
    th = PANEL[2]
    for side in (-1, 1):
        half = bmesh.new()
        put(half, slab((0, 0, 0), (length / 2, height, th), D, C))
        put(half, slab((0, height - 0.004, th), (length / 2, height + 0.002, th + 0.004), S, S))
        put(part, half, rot("Y", -side * kink / 2) @ Matrix.Scale(side, 4, (1, 0, 0)))
    return part


def steel_rubble():
    """The post bent over from a stump, the panels torn off and folded, the rail lying twisted."""
    bm = bmesh.new()
    p = SPOST / 2
    put(bm, slab((-FOOT[0] / 2 - 0.004, -FOOT[0] / 2 - 0.004, 0), (FOOT[0] / 2 + 0.004, FOOT[0] / 2 + 0.004, FOOT[1]), D, C))
    stump = boxed((-p, -p, 0), (p, p, 0.048), 0.0)   # half height still standing
    for f in stump.faces:
        f.material_index = D
    put(bm, stump)
    top = bmesh.new()
    part = boxed((-p, -p, 0), (p, p, 0.062), 0.0)
    for f in part.faces:
        f.material_index = D
    put(top, part)
    c = SCAP[0] / 2
    put(top, slab((-c, -c, 0.062), (c, c, 0.062 + SCAP[1]), S, S))
    put(bm, top, at(0.0, 0.0, 0.046) @ rot("X", -72) @ rot("Y", 6))        # bent over at the stump, falling north
    put(bm, bent_panel(0.07, 0.05, 28), at(-0.032, -0.072, 0.0) @ rot("Z", 8))
    put(bm, bent_panel(0.06, 0.044, 18), at(0.04, 0.03, 0.0) @ rot("Z", 100))
    rail = ((-0.062, 0.058), (0.004, 0.062), (0.06, 0.012), (0.058, -0.05))   # one long pale rail, kinked twice
    for a, b in zip(rail, rail[1:]):
        a, b = Vector((*a, 0.008)), Vector((*b, 0.008))
        d = b - a
        r = slab((0, -RAIL[0] / 2 * 0.5, -0.002), (d.length, RAIL[0] / 2 * 0.5, 0.002 + RAIL[2] * 0.5), D, C)
        put(bm, r, at(*a) @ d.to_track_quat("X", "Z").to_matrix().to_4x4())
        r = slab((0, -STRIP[0] / 2, 0.002 + RAIL[2] * 0.5), (d.length, STRIP[0] / 2, 0.002 + RAIL[2] * 0.5 + STRIP[1]), S, S)
        put(bm, r, at(*a) @ d.to_track_quat("X", "Z").to_matrix().to_4x4())
    return finish_maquette("WallSteelRubble", bm, [M["dark_board"], M["steel_edge"], M["core"]])


objs = [stone_post(), stone_arm(), stone_rubble(), steel_post(), steel_arm(), steel_rubble()]
for ob in objs:
    tris = sum(len(p.vertices) - 2 for p in ob.data.polygons)
    bb = [ob.matrix_world @ Vector(c) for c in ob.bound_box]
    print("TRIS_OF", ob.name, tris, "slots", len(ob.data.materials),
          "x %.4f..%.4f y %.4f..%.4f z %.4f..%.4f" % (min(v.x for v in bb), max(v.x for v in bb),
                                                    min(v.y for v in bb), max(v.y for v in bb),
                                                    min(v.z for v in bb), max(v.z for v in bb)))
ASSET = "maquette_fences"
GLB = os.environ.get("GLB")
if GLB:
    bpy.ops.object.select_all(action="DESELECT")
    for ob in objs:
        ob.select_set(True)
    bpy.ops.export_scene.gltf(filepath=GLB, use_selection=True, export_apply=True, export_tangents=True,
                              export_materials="EXPORT")
else:  # mockup: a run with a corner per tier, the rubble beside it
    for row, (post, arm, rubble) in enumerate((objs[0:3], objs[3:6])):
        y = row * 0.4
        cells = [(i, 0) for i in range(4)] + [(3, 1), (3, 2)]
        for i, j in cells:
            x, yy = i * CELL, y + j * CELL
            p = post.copy(); p.location = (x, yy, 0); bpy.context.scene.collection.objects.link(p)
            for di, dj, rz in ((1, 0, 0), (-1, 0, 180), (0, 1, 90), (0, -1, -90)):
                if (i + di, j + dj) in cells:
                    a = arm.copy(); a.location = (x, yy, 0); a.rotation_euler = (0, 0, math.radians(rz))
                    bpy.context.scene.collection.objects.link(a)
        rubble.location = (-0.3, y, 0)
        post.location = (-10, 0, 0); arm.location = (-10, 0, 0)
FRAME = ((0.25, -0.7, 0.6), (0.2, 0.25, 0.04), 50, 1400, 900)
