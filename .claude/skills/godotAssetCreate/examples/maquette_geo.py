# War maquettes, round 1: farmhouse (3x3 cells) and wooden fence (1 cell), as architect's card / balsa
# massing models. Prepend blender_lib.py. Blender X = Godot +X (east), Blender +Y = Godot -Z (north, up
# the screen), Z up. Every piece: origin at its footprint centre on the paper. Cell 0.16 m.
# Materials are named like assets/materials/maquette/maquette_<name>.tres (glb_to_res.gd maps them).
# GLB=<path> exports the five objects; without it the mockup lays them out side by side.
import random

CELL = 0.16
COLS = {"card": (0.70, 0.66, 0.58), "shade": (0.50, 0.47, 0.42), "core": (0.84, 0.82, 0.77),
        "grey_board": (0.26, 0.255, 0.24), "balsa": (0.64, 0.52, 0.32),
        "dark_board": (0.04, 0.04, 0.045)}
M = {k: material("maquette_" + k, v, 0.0, 0.9) for k, v in COLS.items()}
GRAIN = None  # face int layer "grain": the axis balsa grain runs along (0 x, 1 y, 2 z); -1 = box projection


def faces_mat(part, mat_of):
    """Set each face's material index from its normal: mat_of(normal) -> slot."""
    for f in part.faces:
        f.material_index = mat_of(f.normal)


def put(bm, part, matrix=I, grain=-1):
    """Like merge() but keeps the part's per-face material indices and tags the grain axis."""
    bmesh.ops.transform(part, matrix=matrix, verts=part.verts)
    layer = part.faces.layers.int.get("grain") or part.faces.layers.int.new("grain")
    for f in part.faces:
        f[layer] = grain
    me = bpy.data.meshes.new("tmp"); part.to_mesh(me); part.free()
    bm.from_mesh(me); bpy.data.meshes.remove(me)


def slab(lo, hi, skin, edge):
    """A cut board: the faces across its thinnest axis are skin, its cut edges show the core."""
    part = boxed(lo, hi, 0.0)
    thin = min(range(3), key=lambda i: hi[i] - lo[i])
    faces_mat(part, lambda n: skin if abs(n[thin]) > 0.7 else edge)
    return part


def prism(profile, x0, x1, mat, along_y=False):
    """profile [(y, z)] extruded along X from x0 to x1 (a gable block); along_y: profile [(x, z)] along Y."""
    part = bmesh.new()
    v = (lambda u, a, z: (u, a, z)) if along_y else (lambda u, a, z: (a, u, z))
    a = [part.verts.new(v(u, x0, z)) for u, z in profile]
    b = [part.verts.new(v(u, x1, z)) for u, z in profile]
    part.faces.new(a); part.faces.new(list(reversed(b)))
    n = len(profile)
    for i in range(n):
        part.faces.new((a[i], a[(i + 1) % n], b[(i + 1) % n], b[i]))
    bmesh.ops.recalc_face_normals(part, faces=part.faces)
    for f in part.faces:
        f.material_index = mat
    return part


def cyl(r0, r1, z0, z1, sides, mat, cap_mat=None):
    part = bmesh.new()
    lathe(part, [(0, z0), (r0, z0), (r1, z1), (0, z1)], sides)
    bmesh.ops.transform(part, matrix=UP, verts=part.verts)
    faces_mat(part, lambda n: (cap_mat if cap_mat is not None and abs(n.z) > 0.9 else mat))
    return part


def finish_maquette(name, bm, mats):
    """finish() with UVs that follow balsa grain: on a tagged face U runs along its grain axis."""
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    layer = bm.faces.layers.int.get("grain")
    uv = bm.loops.layers.uv.get("UVMap") or bm.loops.layers.uv.new("UVMap")
    for e in bm.edges:
        if len(e.link_faces) == 2 and e.calc_face_angle(0) > math.radians(35):
            e.smooth = False
    for f in bm.faces:
        f.smooth = True
        axis = max(range(3), key=lambda i: abs(f.normal[i]))
        g = f[layer] if layer is not None else -1
        if g >= 0 and g != axis:
            a, b = g, [i for i in range(3) if i not in (g, axis)][0]
        else:
            a, b = [i for i in range(3) if i != axis]
        end = 100.0 if g == axis else 0.0  # end grain: V shifted past 50, the shader darkens it
        for loop in f.loops:
            loop[uv].uv = (loop.vert.co[a], loop.vert.co[b] + end)
    me = bpy.data.meshes.new(name); bm.to_mesh(me); bm.free()
    for m in mats:
        me.materials.append(m)
    ob = bpy.data.objects.new(name, me); bpy.context.scene.collection.objects.link(ob)
    wn = ob.modifiers.new("WeightedNormal", "WEIGHTED_NORMAL"); wn.keep_sharp = True; wn.weight = 100
    return ob


def scrap(radius, crumple, thick, rng, skin, edge, jag=10):
    """A torn, crumpled card scrap lying flat: a jagged fan whose spokes and rim lift at random,
    given a thickness by hand (top skin up, bottom skin down, a cut edge round the rim)."""
    ring, mids = [], []
    for k in range(jag):
        a = k / jag * math.tau + rng.uniform(-0.18, 0.18)
        r = radius * rng.uniform(0.6, 1.1)
        ring.append(Vector((math.cos(a) * r * 1.25, math.sin(a) * r * 0.85, rng.uniform(0, crumple) * 0.35)))
        mids.append(ring[-1] * 0.5 + Vector((0, 0, rng.uniform(0, crumple * 0.45))))
    centre = Vector((0, 0, crumple * 0.3))
    part = bmesh.new()
    def layer(dz):
        return ([part.verts.new(v + Vector((0, 0, dz))) for v in ring], [part.verts.new(v + Vector((0, 0, dz))) for v in mids],
                part.verts.new(centre + Vector((0, 0, dz))))
    top, bot = layer(0.0), layer(-thick)
    for (rv, mv, c), flip, mat in ((top, False, skin), (bot, True, skin)):
        for k in range(jag):
            n = (k + 1) % jag
            for quad in ((c, mv[k], mv[n]), (mv[k], rv[k], rv[n], mv[n])):
                f = part.faces.new(tuple(reversed(quad)) if flip else quad)
                f.material_index = mat
    for k in range(jag):
        n = (k + 1) % jag
        part.faces.new((top[0][n], top[0][k], bot[0][k], bot[0][n])).material_index = edge
    bmesh.ops.recalc_face_normals(part, faces=part.faces)
    return part


def rot(axis, deg):
    return Matrix.Rotation(math.radians(deg), 4, axis)


C, S, E, G, D = 0, 1, 2, 3, 4  # slots: card, shade, core (cut edge), grey board, dark board
SLOTS = [M["card"], M["shade"], M["core"], M["grey_board"], M["dark_board"]]

# ---------------------------------------------------------------- farmhouse
HALF = 0.152          # footprint half size: 2x2 cells (0.32) less a 8 mm margin, like the old 3x3 one
PL = 0.008            # plinth: grey board site plate
T = 0.007             # card thickness (walls and roof boards): the cut edges show the core
EAVE, RIDGE = 0.07, 0.185            # above the plinth
BX0, BX1, BY0, BY1 = -0.14, 0.03, -0.08, 0.14   # main block
SILO = (0.09, 0.095, 0.045, 0.215)  # x, y, r, height above plinth
LX0, LX1, LY0, LY1, LHI, LLO = 0.03, 0.14, -0.13, 0.035, 0.058, 0.038  # lean-to


def roof_plane(bm, y_eave, y_ridge, z_eave, z_ridge, x0, x1, over):
    """One roof board from the eave to the ridge, overhanging `over` at the eave and gables."""
    run = y_ridge - y_eave
    length = math.hypot(run, z_ridge - z_eave)
    ang = math.atan2(z_ridge - z_eave, abs(run))
    part = slab((x0 - over, -over, 0), (x1 + over, length + T * 0.5, T), S, E)
    if run > 0:
        mat = at(0, y_eave, z_eave) @ rot("X", math.degrees(ang))
    else:  # turned round: X flips, so shift it back over x0..x1
        mat = at(x0 + x1, y_eave, z_eave) @ rot("Z", 180) @ rot("X", math.degrees(ang))
    put(bm, part, mat)


def panel_x(bm, profile, x0, x1):
    """A wall board across X (a gable): profile [(y, z)], skin faces +-X, every other face a cut edge."""
    part = prism(profile, x0, x1, C)
    faces_mat(part, lambda n: C if abs(n.x) > 0.7 else E)
    put(bm, part)


def panel_y(bm, profile, y0, y1):
    """A wall board across Y (an eave wall): profile [(x, z)], skin faces +-Y."""
    part = prism(profile, y0, y1, C, along_y=True)
    faces_mat(part, lambda n: C if abs(n.y) > 0.7 else E)
    put(bm, part)


def farmhouse():
    bm = bmesh.new()
    put(bm, slab((-HALF, -HALF, 0), (HALF, HALF, PL), G, G))
    z0 = PL
    # main block, built with its ridge along local X, then turned so the ridge runs north-south: the
    # desk lamp falls from the west, so one roof plane is lit and the other in shade from above.
    # The eave walls run the full length and the gables sit between them, so every corner shows a
    # cut edge.
    hl, hw = (BY1 - BY0) / 2, (BX1 - BX0) / 2
    block = bmesh.new()
    wz = (z0 + 0.026, z0 + 0.056)      # window sill and head
    for y0 in (-hw, hw - T):           # eave walls (east, west): three punched windows each
        holed(block, -hl, hl, z0, z0 + EAVE, [(u - 0.016, u + 0.016, *wz) for u in (-0.06, 0.0, 0.06)], at(0, y0, 0))
    for x0, holes in ((-hl, [(-0.018, 0.018, z0, z0 + 0.052)]), (hl - T, [(-0.016, 0.016, *wz)])):
        # gables: a door in the south one, a window in the north one, the triangle above the eaves
        holed(block, -hw + T, hw - T, z0, z0 + EAVE, holes, at(x0 + T, 0, 0) @ rot("Z", 90))
        panel_x(block, [(-hw + T, z0 + EAVE), (hw - T, z0 + EAVE), (0, z0 + RIDGE - 0.004)], x0, x0 + T)
    liner = boxed((-hl + T + 0.004, -hw + T + 0.004, z0), (hl - T - 0.004, hw - T - 0.004, z0 + EAVE), 0.0)
    for f in liner.faces:              # a dark board inside, so the openings read as dark holes
        f.material_index = D
    put(block, liner)
    for y_eave in (-hw, hw):
        roof_plane(block, y_eave, 0, z0 + EAVE, z0 + RIDGE, -hl, hl, 0.012)
    put(bm, block, at((BX0 + BX1) / 2, (BY0 + BY1) / 2, 0) @ rot("Z", 90))
    # lean-to against the main block's east gable, its board roof falling to the east
    holed(bm, BX1, LX1, z0, z0 + LLO, [(0.058, 0.088, z0, z0 + 0.034), (0.104, 0.126, z0 + 0.012, z0 + 0.03)], at(0, LY0, 0))
    panel_y(bm, [(BX1, z0 + LLO), (LX1, z0 + LLO), (BX1, z0 + LHI)], LY0, LY0 + T)
    lin = boxed((BX1 + 0.002, LY0 + T + 0.004, z0), (LX1 - T - 0.004, LY1 - T - 0.004, z0 + LLO), 0.0)
    for f in lin.faces:
        f.material_index = D
    put(bm, lin)
    panel_y(bm, [(BX1, z0), (LX1, z0), (LX1, z0 + LLO), (BX1, z0 + LHI)], LY1 - T, LY1)
    panel_x(bm, [(LY0 + T, z0), (BY0, z0), (BY0, z0 + LHI), (LY0 + T, z0 + LHI)], BX1 - T, BX1)
    panel_x(bm, [(LY0 + T, z0), (LY1 - T, z0), (LY1 - T, z0 + LLO), (LY0 + T, z0 + LLO)], LX1 - T, LX1)
    lean = bmesh.new()
    put(lean, slab((0, LY0 - 0.012, 0), (math.hypot(LX1 - LX0, LHI - LLO) + 0.012, LY1 + 0.012, T), S, E))
    for f in lean.faces:  # the lean-to roof in pale card, so it parts from the main roof and the plate
        f.material_index = C if f.material_index == S else f.material_index
    put(bm, lean, at(LX0, 0, z0 + LHI) @ rot("Y", math.degrees(math.atan2(LHI - LLO, LX1 - LX0))))
    # silo: a rolled card tube, a glued seam strip facing the camera, a shallow paper cone cap
    x, y, r, h = SILO
    put(bm, cyl(r, r, z0, z0 + h, 28, C), at(x, y, 0))
    put(bm, slab((-0.0035, -0.002, z0 + 0.004), (0.0035, 0.0, z0 + h - 0.002), C, E), at(x, y - r, 0))
    put(bm, cyl(r + 0.007, r + 0.007, z0 + h, z0 + h + 0.005, 28, E, S), at(x, y, 0))
    put(bm, cyl(r + 0.004, 0.006, z0 + h + 0.005, z0 + h + 0.035, 28, S), at(x, y, 0))
    for cx, cy in CRATES:  # two open card crates on the plate in front (cabbages: a MultiMesh in the scene)
        crate(bm, cx, cy, z0)
    return finish_maquette("Farmhouse", bm, SLOTS)


def farmhouse_rubble():
    rng = random.Random(7)
    bm = bmesh.new()
    put(bm, slab((-HALF, -HALF, 0), (HALF, HALF, PL), G, G))
    z0 = PL
    # the walls folded flat: a big crumpled sheet over the old block, smaller torn pieces around it
    for (x, y), r, cr, rz in (((-0.055, 0.015), 0.07, 0.018, 10), ((0.015, -0.08), 0.05, 0.014, -25),
                              ((-0.105, -0.1), 0.035, 0.01, 40), ((0.085, -0.065), 0.04, 0.012, 75),
                              ((-0.11, 0.105), 0.032, 0.008, -60), ((0.035, 0.11), 0.03, 0.008, 15)):
        put(bm, scrap(r, cr, 0.004, rng, C, E), at(x, y, z0) @ rot("Z", rz))
    # the two roof boards fallen in, one propped on the heap, one flat and buckled
    put(bm, slab((-0.07, -0.045, 0), (0.07, 0.045, T), S, E), at(-0.045, 0.05, z0 + 0.018) @ rot("Z", 8) @ rot("X", 9) @ rot("Y", -5))
    put(bm, scrap(0.052, 0.022, T, rng, S, E, 8), at(-0.02, -0.04, z0 + 0.004) @ rot("Z", -30))
    # the silo: crushed flat and rolled over on its side, its cone cap knocked off
    x, y, r, h = SILO
    tube = cyl(r, r, -0.07, 0.07, 20, C)
    bmesh.ops.scale(tube, vec=(0.45, 1.0, 1.0), verts=tube.verts)
    put(bm, tube, at(0.07, 0.075, z0 + r * 0.45) @ rot("Z", -12) @ rot("Y", 90))
    put(bm, cyl(r + 0.004, 0.006, 0, 0.025, 20, S), at(0.105, -0.1, z0 + 0.006) @ rot("Y", 20) @ rot("X", -8))
    return finish_maquette("FarmhouseRubble", bm, SLOTS[:4])


# ---------------------------------------------------------------- wooden fence (balsa)
PW = 0.024           # post section
PH = 0.088           # post height
CAP_W, CAP_T, CAP_TOP = 0.034, 0.006, 0.075     # the flat capping strip along the top: what reads from above
RAILS = ((0.02, 0.032), (0.045, 0.057))          # (bottom, top) of the two side rails
RAIL_T = 0.005


def wall_post():
    bm = bmesh.new()
    put(bm, boxed((-PW / 2, -PW / 2, 0), (PW / 2, PW / 2, PH), 0.0), I, 2)
    return finish_maquette("WallWoodPost", bm, [M["balsa"]])


def wall_arm():
    """East arm: from the post face to the cell edge, where the neighbour's west arm meets it."""
    bm = bmesh.new()
    x0, x1 = PW / 2 - 0.001, CELL / 2
    put(bm, boxed((x0, -CAP_W / 2, CAP_TOP - CAP_T), (x1, CAP_W / 2, CAP_TOP), 0.0), I, 0)
    for z0, z1 in RAILS:
        for side in (-1, 1):  # a rail nailed on each outer face of the posts, running on past the post
            y = side * (PW / 2 + RAIL_T / 2)
            put(bm, boxed((0, y - RAIL_T / 2, z0), (x1, y + RAIL_T / 2, z1), 0.0), I, 0)
    return finish_maquette("WallWoodArm", bm, [M["balsa"]])


def splinter(length, w, rng):
    """A snapped balsa stick: a box whose ends are cut ragged (end vertices pulled apart)."""
    part = boxed((-length / 2, -w / 2, 0), (length / 2, w / 2, w * 0.8), 0.0)
    for v in part.verts:
        v.co.x += math.copysign(rng.uniform(0, length * 0.18), v.co.x) * (1 if rng.random() < 0.6 else -0.3)
        v.co.y *= rng.uniform(0.6, 1.0)
    return part


def wall_rubble():
    rng = random.Random(3)
    bm = bmesh.new()
    # the post snapped off low, its top ragged
    stump = boxed((-PW / 2, -PW / 2, 0), (PW / 2, PW / 2, 0.026), 0.0)
    for v in stump.verts:
        if v.co.z > 0.02:
            v.co.z += rng.uniform(-0.008, 0.01)
    put(bm, stump, I, 2)
    # the broken post top lying down, the capping strip and rails as splinters
    put(bm, boxed((-0.025, -PW / 2, 0), (0.025, PW / 2, PW), 0.0), at(0.03, 0.035, 0) @ rot("Z", 32), 0)
    for (x, y), length, w, rz in (((-0.03, -0.03), 0.075, 0.012, -18), ((0.035, -0.04), 0.06, 0.009, 64),
                                  ((-0.045, 0.035), 0.05, 0.009, 105), ((0.0, 0.0), 0.055, 0.007, 150),
                                  ((0.05, 0.01), 0.035, 0.006, 12), ((-0.055, -0.005), 0.03, 0.005, 80)):
        put(bm, splinter(length, w, rng), at(x, y, 0) @ rot("Z", rz) @ rot("X", rng.uniform(-6, 6)), 0)
    return finish_maquette("WallWoodRubble", bm, [M["balsa"]])




def holed(bm, u0, u1, z0, z1, holes, M, thick=None):
    """A wall board in its own frame (u along the wall, v 0..thick through it, z up) with rectangular
    openings [(ua, ub, za, zb)] punched through: built as boxes round the holes, so every reveal is a
    cut edge (core). M places it."""
    thick = thick or T
    us = sorted({u0, u1, *[h[0] for h in holes], *[h[1] for h in holes]})
    for a, b in zip(us, us[1:]):
        gaps = sorted((h[2], h[3]) for h in holes if h[0] < (a + b) / 2 < h[1])
        cur, spans = z0, []
        for za, zb in gaps:
            if za > cur:
                spans.append((cur, za))
            cur = zb
        if cur < z1:
            spans.append((cur, z1))
        for lo, hi in spans:
            part = boxed((a, 0, lo), (b, thick, hi), 0.0)
            faces_mat(part, lambda n: C if abs(n.y) > 0.7 else E)
            put(bm, part, M)


def stick(bm, a, b, w, grain, mat_index=0):
    """A square balsa stick from point a to point b (section w), grain along it."""
    a, b = Vector(a), Vector(b)
    d = b - a
    part = boxed((0, -w / 2, -w / 2), (d.length, w / 2, w / 2), 0.0)
    for f in part.faces:
        f.material_index = mat_index
    put(bm, part, at(*a) @ d.to_track_quat("X", "Z").to_matrix().to_4x4(), grain)


CRATES = ((-0.1, -0.118), (-0.04, -0.12))
CRATE = (0.054, 0.036, 0.02, 0.003)   # outer x, outer y, height, card thickness


def crate(bm, cx, cy, z0):
    """An open card crate (floor and four walls); the cabbages in it are a MultiMesh in the scene."""
    w, d, h, t = CRATE
    part = bmesh.new()
    put(part, slab((-w / 2, -d / 2, 0), (w / 2, d / 2, t), C, E))
    put(part, slab((-w / 2, -d / 2, 0), (w / 2, -d / 2 + t, h), C, E))
    put(part, slab((-w / 2, d / 2 - t, 0), (w / 2, d / 2, h), C, E))
    put(part, slab((-w / 2, -d / 2 + t, 0), (-w / 2 + t, d / 2 - t, h), C, E))
    put(part, slab((w / 2 - t, -d / 2 + t, 0), (w / 2, d / 2 - t, h), C, E))
    put(bm, part, at(cx, cy, z0))


# ---------------------------------------------------------------- cannon on a balsa watchtower (1 cell)
TW_BASE, TW_TOP, TW_H, TW_LEG = 0.064, 0.036, 0.125, 0.011   # leg corners (half), platform underside, leg section
PLAT = 0.06                                               # platform half size (card board)
PLAT_TOP = TW_H + T
BARREL = (0.0125, -0.026, 0.066, 0.032, 8.0)                 # radius, from, to (along Blender +Y = Godot -Z), axis height, elevation deg
CORNERS = ((-1, -1), (1, -1), (1, 1), (-1, 1))


def leg_at(k, z):
    s = TW_BASE + (TW_TOP - TW_BASE) * z / TW_H
    return Vector((CORNERS[k][0] * s, CORNERS[k][1] * s, z))


def tower_frame(bm):
    """Four splayed legs, a girth ring halfway and a cross brace on each face (slot 0: balsa)."""
    for k in range(4):
        stick(bm, leg_at(k, 0), leg_at(k, TW_H), TW_LEG, 2)
    zm = TW_H * 0.48
    for k in range(4):
        n = (k + 1) % 4
        axis = 0 if CORNERS[k][1] == CORNERS[n][1] else 1
        stick(bm, leg_at(k, zm), leg_at(n, zm), 0.007, axis)
        stick(bm, leg_at(k, 0.004), leg_at(n, zm - 0.004), 0.005, 2)          # lower brace
        stick(bm, leg_at(n, zm + 0.004), leg_at(k, TW_H - 0.004), 0.005, 2)   # upper brace, the other way


def platform(bm):
    """The card platform (slots 1 card, 2 core) and a low balsa rail on corner stubs."""
    put(bm, slab((-PLAT, -PLAT, TW_H), (PLAT, PLAT, PLAT_TOP), 1, 2))
    q = PLAT - 0.005
    for sx, sy in CORNERS:
        stick(bm, (sx * q, sy * q, PLAT_TOP), (sx * q, sy * q, PLAT_TOP + 0.02), 0.007, 2)
    for k in range(4):
        a, b = CORNERS[k], CORNERS[(k + 1) % 4]
        stick(bm, (a[0] * q, a[1] * q, PLAT_TOP + 0.017), (b[0] * q, b[1] * q, PLAT_TOP + 0.017), 0.005, 0 if a[1] == b[1] else 1)


def barrel_matrix():
    r, y0, y1, z, el = BARREL
    return at(0, 0, z) @ rot("X", el) @ rot("X", -90)   # cyl() runs along Z: turned to +Y, raised by el


def cannon_gun(bm, M=I):
    """The gun, origin on the turntable's foot, barrel to Blender +Y (Godot -Z). Slots: grey, card, core, dark."""
    gun = bmesh.new()
    put(gun, cyl(0.034, 0.034, 0.003, 0.011, 24, 0, 0))     # grey-board turntable
    put(gun, cyl(0.035, 0.035, 0.0, 0.003, 24, 2, 2))    # under it a pale cut-edge disc
    for sx in (-1, 1):                                    # card cheeks
        put(gun, slab((sx * 0.0175 - 0.003, -0.024, 0.011), (sx * 0.0175 + 0.003, 0.024, 0.042), 1, 2))
    r, y0, y1, z, el = BARREL
    put(gun, cyl(r, r, y0, y1, 16, 3, 3), barrel_matrix())                      # dark rolled-board barrel
    put(gun, cyl(r + 0.0025, r + 0.0025, y1 - 0.006, y1, 16, 2, 3), barrel_matrix())  # its rolled mouth
    put(bm, gun, M)


def muzzle():
    r, y0, y1, z, el = BARREL
    return barrel_matrix() @ Vector((0, 0, y1))


def cannon_base():
    bm = bmesh.new()
    tower_frame(bm)
    platform(bm)
    return finish_maquette("CannonBase", bm, [M["balsa"], M["card"], M["core"]])


def cannon_turret():
    bm = bmesh.new()
    cannon_gun(bm)
    return finish_maquette("CannonTurret", bm, [M["grey_board"], M["card"], M["core"], M["dark_board"]])


def cannon_rubble():
    """Slots: grey, card, core, dark, balsa."""
    rng = random.Random(11)
    bm = bmesh.new()
    # the platform came down flat on the wreck, the legs and braces lie about as splinters
    put(bm, slab((-PLAT * 0.85, -PLAT * 0.85, 0), (PLAT * 0.85, PLAT * 0.85, T), 1, 2), at(0.014, -0.016, 0.017) @ rot("Z", 14) @ rot("X", 20))
    for (x, y), length, w, rz in (((-0.04, -0.045), 0.06, TW_LEG, 20), ((0.042, -0.035), 0.055, TW_LEG, -70),
                                  ((0.035, 0.038), 0.05, TW_LEG, 115), ((-0.045, 0.035), 0.045, 0.007, 60),
                                  ((0.0, -0.055), 0.05, 0.006, 5), ((0.055, 0.0), 0.035, 0.005, 95)):
        part = splinter(length, w, rng)
        for f in part.faces:
            f.material_index = 4
        put(bm, part, at(x, y, 0) @ rot("Z", rz) @ rot("X", rng.uniform(-6, 6)), 0)
    # the gun tipped over on the platform
    cannon_gun(bm, at(-0.008, -0.01, 0.035) @ rot("Z", 50) @ rot("Y", 90))   # on its side, barrel flat
    return finish_maquette("CannonRubble", bm, [M["grey_board"], M["card"], M["core"], M["dark_board"], M["balsa"]])


# ---------------------------------------------------------------- mortar in a sandbag ring (2x2 cells)
RING_R, BAG = 0.118, (0.046, 0.024, 0.018)    # ring radius, sandbag block (along, across, high)
TUBE = (0.03, 0.078, 35.0, 0.022)             # radius, length, tilt from upright (toward Blender +Y), pivot height


def sandbag(rng, slot=4):
    a, c, h = BAG
    part = bmesh.new(); box(part, (-a / 2, -c / 2, 0), (a / 2, c / 2, h), 0.004, 1)    # a folded grey-board block, chamfered
    for v in part.verts:
        v.co.z *= rng.uniform(0.92, 1.05)
    for f in part.faces:
        f.material_index = slot
    return part


def ring_spots(rng):
    """(course, k, matrix) for every bag of the two-course ring, with a gap to the south."""
    a, c, h = BAG
    n = 16
    out = []
    for course in (0, 1):
        for k in range(n):
            ang = (k + 0.5 * course) / n * math.tau
            if abs(math.degrees(ang) - 270) < 16:
                continue
            r = RING_R - course * 0.004
            out.append((course, k, at(math.cos(ang) * r, math.sin(ang) * r, PL + course * h * 0.95) @ rot("Z", math.degrees(ang) + 90)))
    return out


def site_disc(bm):
    put(bm, cyl(0.15, 0.15, 0, PL, 8, 0, 0), rot("Z", 22.5))    # grey-board site disc (octagon), like the farmhouse plate


def mortar_base():
    rng = random.Random(5)
    bm = bmesh.new()
    site_disc(bm)
    for course, k, Mx in ring_spots(rng):
        put(bm, sandbag(rng), Mx)
    return finish_maquette("MortarBase", bm, [M["grey_board"], M["card"], M["core"], M["dark_board"], M["shade"]])


def tube_matrix():
    r, length, tilt, pz = TUBE
    return at(0, -0.012, pz) @ rot("X", -tilt)


def mortar_gun(bm, M=I):
    """Slots: grey, card, core, dark. Origin on the floor at the pivot, the tube leaning to Blender +Y."""
    r, length, tilt, pz = TUBE
    gun = bmesh.new()
    put(gun, slab((-0.04, -0.04, 0), (0.04, 0.04, 0.006), 3, 2))                  # dark baseplate
    put(gun, cyl(r, r, -0.012, length, 20, 0, 0), tube_matrix())                  # grey-board tube
    put(gun, cyl(r + 0.003, r + 0.003, length - 0.007, length, 20, 2, 2), tube_matrix())      # rolled rim
    put(gun, cyl(r - 0.004, r - 0.004, length - 0.012, length + 0.0005, 20, 3, 3), tube_matrix())  # dark bore
    for sx in (-1, 1):                                                               # a card bipod
        stick(gun, (sx * 0.03, 0.035, 0.004), (sx * 0.009, 0.014, pz + 0.035), 0.005, 2, 1)
    put(bm, gun, M)


def mortar_muzzle():
    r, length, tilt, pz = TUBE
    return tube_matrix() @ Vector((0, 0, length))


def mortar_turret():
    bm = bmesh.new()
    mortar_gun(bm)
    return finish_maquette("MortarTurret", bm, [M["grey_board"], M["card"], M["core"], M["dark_board"]])


def mortar_rubble():
    rng = random.Random(9)
    bm = bmesh.new()
    site_disc(bm)
    for course, k, Mx in ring_spots(rng):
        if course == 0 and k % 3 != 1:                       # the top course knocked off, gaps blown in
            put(bm, sandbag(rng), Mx)
    for k in range(9):                                       # tumbled bags
        ang = rng.uniform(0, math.tau); r = rng.uniform(0.05, 0.125)
        put(bm, sandbag(rng), at(math.cos(ang) * r, math.sin(ang) * r, PL) @ rot("Z", rng.uniform(0, 180)) @ rot("Y", rng.uniform(-20, 20)))
    mortar_gun(bm, at(0.01, 0.0, PL + 0.03) @ rot("Y", 85) @ rot("Z", 40))   # the tube on its side
    return finish_maquette("MortarRubble", bm, [M["grey_board"], M["card"], M["core"], M["dark_board"], M["shade"]])


objs = [farmhouse(), farmhouse_rubble(), wall_post(), wall_arm(), wall_rubble(),
        cannon_base(), cannon_turret(), cannon_rubble(), mortar_base(), mortar_turret(), mortar_rubble()]
m = muzzle(); print("GODOT cannon Turret y %.4f Muzzle (0, %.4f, %.4f)" % (PLAT_TOP, m.z, -m.y))
m = mortar_muzzle(); print("GODOT mortar Turret y %.4f Muzzle (0, %.4f, %.4f)" % (PL, m.z, -m.y))
for ob in objs:
    tris = sum(len(p.vertices) - 2 for p in ob.data.polygons)
    print("TRIS_OF", ob.name, tris, "slots", len(ob.data.materials), "dims", tuple(round(d, 3) for d in ob.dimensions))
ASSET = "maquette"
GLB = os.environ.get("GLB")
if GLB:
    bpy.ops.object.select_all(action="DESELECT")
    for ob in objs:
        ob.select_set(True)
    bpy.ops.export_scene.gltf(filepath=GLB, use_selection=True, export_apply=True, export_tangents=True,
                              export_materials="EXPORT")
else:  # mockup: farmhouse, its rubble, and a fence run with a corner
    objs[1].location = (0.6, 0, 0)
    for k, ob in enumerate(objs[5:]):
        ob.location = (-0.6 + k * 0.3, 0.6, PLAT_TOP if ob.name == "CannonTurret" else (PL if ob.name == "MortarTurret" else 0))
    for k, ob in enumerate(objs[2:5]):
        ob.location = (-0.5 + k * 0.2, -0.4, 0)
    ring = [(-0.4 + i * CELL, 0.32) for i in range(6)]
    for x, y in ring:
        p = objs[2].copy(); p.location = (x, y, 0); bpy.context.scene.collection.objects.link(p)
        for rz in (0, 180):
            a = objs[3].copy(); a.location = (x, y, 0); a.rotation_euler = (0, 0, math.radians(rz))
            bpy.context.scene.collection.objects.link(a)
FRAME = ((0.1, -1.1, 1.0), (0.1, 0.0, 0.05), 50, 1400, 900)
