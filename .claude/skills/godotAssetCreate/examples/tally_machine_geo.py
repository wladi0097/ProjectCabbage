# Project Cabbage coin tally machine: collected coins drop into the brass hopper and the nine
# number drums on the sloped front roll up the total (odometer style, Drum0 = ones, rightmost).
# No keys or crank: nothing on it looks operable. Sits against the back wall, desk left section,
# with the hopper on a pedestal at its right end (the end nearest the mat, so coins fly less).
# Two rows on the slope: the money drums low down with the brass "$$$" plate left of them, and an
# empty slot above, where the Findings row (findings_counter_geo.py, built by this same script with
# COUNTER = "findings") drops in once Quality Assurance is bought.
# Blender Z-up, front = -Y (Godot +Z). Origin: floor centre of the drum shell. Both assets share it.
# Footprint x -0.38..0.385, y -0.13..0.095; the face rises at 50 deg from 0.075 (front) to 0.23, then a
# flat top: steep enough that the drums face the game camera (it sees the machine from ~40 deg up)
# nearly head-on. The drum faces get their own unshaded surface (machine_digits) so lamp and
# shadow never wash out the numbers.
# One skinned mesh: bone Body (static) + Drum0..Drum8, each pivoting on the drum axis (X).
#   Drum k shows digit d at rotation +d*36 deg about X (Blender and Godot alike).
# Surfaces: machine_paint (enamel / bakelite by vertex colour), machine_metal (chrome / brass by
# vertex colour), machine_dial (atlas: plates), machine_digits (same atlas, unshaded: the drum
# faces), see machine_tex.py.
from mathutils import Quaternion
COUNTER = globals().get("COUNTER", "money")
E, K, H, B, D, G = range(6)            # logical parts: enamel, bakelite, chrome, brass, dial, digits
COLOURS = {E: (0.15, 0.19, 0.16), K: (0.025, 0.025, 0.024), H: (0.62, 0.63, 0.65), B: (0.62, 0.42, 0.14), D: (1, 1, 1), G: (1, 1, 1)}
SURFACE = {E: 0, K: 0, H: 1, B: 1, D: 2, G: 3}
PITCH, DRUM_W, DRUM_R = 0.049, 0.045, 0.06
DRUM_U = 0.12                      # drum face width in the atlas (keeps digits unstretched)
WIN = 0.022                        # half height of a drum window: one digit row shows
def half_width(drums): return (drums - 1) / 2 * PITCH + DRUM_W / 2 + 0.004
# Rows (slope offset of the window centre, drums); each window starts at the same x, right of its plate.
ROWS = {"money": (-0.042, 9), "findings": (0.042, 6)}
WIN_LEFT = -half_width(9)
PLATE_X = (-0.362, -0.242)                          # brass plate left of each row, its s is the row's ±0.025
PLATE_UV = {"money": (0.5, 0.8, 0.5, 0.2), "findings": (0.25, 0.9, 0.25, 0.1)}   # (u0, v0, du, dv)
LEFT = -0.37                                        # shell's left end
ASSET = "tally_machine" if COUNTER == "money" else "findings_counter"
ROW, DRUMS = ROWS[COUNTER]
WX = half_width(DRUMS)
CX = WIN_LEFT + WX                                  # the row's window centre x


def vc_textured(name, rough, metal, scale):
    m = material(name, (1, 1, 1), metal, rough)
    textured(m, name, scale)
    nt = m.node_tree
    mix = next(n for n in nt.nodes if n.bl_idname == "ShaderNodeMix")
    col = nt.nodes.new("ShaderNodeVertexColor"); col.layer_name = "Col"
    nt.links.new(col.outputs["Color"], mix.inputs["B"])
    return m


paint = vc_textured("machine_paint", 0.45, 0.0, 4.0)
metal = vc_textured("machine_metal", 0.3, 1.0, 4.0)
dial = material("machine_dial", (1, 1, 1), 0.0, 0.5)
textured(dial, "machine_dial", 1.0)
digits = material("machine_digits", (1, 1, 1), 0.0, 0.5)
textured(digits, "machine_dial", 1.0)


def prism(bm, pts, x0, x1, mat, bevel, segs):
    """Side profile (y, z) extruded along X, all edges bevelled."""
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


# Slope frame (x, s up the slope, n out of it), facing up toward the camera; each row has its own
# frame shifted to its window centre.
FRONT, TOP = -0.12, 0.23                            # shell front face y, flat top z
LO, HI = Vector((0, FRONT, 0.075)), Vector((0, 0.01, 0.23))
SD = (HI - LO).normalized(); N_ = Vector((0, -SD.z, SD.y)); P = (LO + HI) / 2
FRAME_M = Matrix((( 1, 0, 0, P.x), (0, SD.y, N_.y, P.y), (0, SD.z, N_.z, P.z), (0, 0, 0, 1)))
ROW_M = FRAME_M @ at(CX, ROW, 0)
ROW_INV = ROW_M.inverted()
def row_point(x, n):
    return ROW_M @ Vector((x, 0, n))


body = bmesh.new()
if COUNTER == "money":
    part_box(body, (LEFT - 0.01, FRONT - 0.01, 0), (0.385, 0.095, 0.03), 0.012, K)           # bakelite plinth
    # Enamel drum shell with both window recesses cut in.
    shell = bmesh.new()
    prism(shell, [(FRONT, 0.03), (0.09, 0.03), (0.09, TOP), (HI.y, TOP), (FRONT, LO.z)], LEFT, 0.245, 0, 0.018, 4)
    shell_ob = finish("shell_tmp", shell, [paint])
    for row, drums in ROWS.values():
        wx = half_width(drums)
        cut = boxed((-wx, -WIN, -0.08), (wx, WIN, 0.05), 0.004)
        bmesh.ops.transform(cut, matrix=FRAME_M @ at(WIN_LEFT + wx, row, 0), verts=cut.verts)
        boolean(shell_ob, cut)
        # Dark tray at the bottom of each recess (the upper one stays empty until Findings arrive).
        part_box(body, (-wx, -WIN, -0.085), (wx, WIN, -0.08), 0.0, K, FRAME_M @ at(WIN_LEFT + wx, row, 0))
    absorb(body, shell_ob)
    # Hopper pedestal at the right end, flush with the back top of the shell.
    part_box(body, (0.235, FRONT, 0.03), (0.375, 0.09, TOP), 0.016, E)
    # Chrome waist trim around shell and pedestal.
    X0, X1, Y0, Y1 = LEFT - 0.007, 0.382, FRONT - 0.007, 0.092
    part_box(body, (X0, Y0, 0.048), (X1, Y0 + 0.007, 0.058), 0.003, H)
    part_box(body, (X0, Y1 - 0.007, 0.048), (X1, Y1, 0.058), 0.003, H)
    part_box(body, (X0, Y0, 0.048), (X0 + 0.007, Y1, 0.058), 0.003, H)
    part_box(body, (X1 - 0.007, Y0, 0.048), (X1, Y1, 0.058), 0.003, H)
    # Brass coin hopper on the pedestal: rolled rim, chrome collar.
    hop = at(0.305, 0.0, TOP - 0.002)
    spin(body, [(0, 0), (0.024, 0), (0.026, 0.012), (0.052, 0.058), (0.06, 0.066), (0.064, 0.072), (0.06, 0.077),
                (0.054, 0.072), (0.022, 0.016), (0, 0.016)], B, hop, 40)
    spin(body, [(0, -0.002), (0.034, -0.002), (0.034, 0.012), (0.03, 0.016), (0, 0.016)], H, hop, 32)
    # Rubber feet peeking out under the plinth corners.
    for x in (LEFT + 0.025, 0.35):
        for y in (FRONT + 0.03, 0.065):
            spin(body, [(0, 0), (0.018, 0), (0.02, 0.006), (0, 0.006)], K, at(x, y, -0.004), 16)

# The row itself: chrome bezel round its window, a divider every three drums, the brass plate.
B_ = 0.012
for lo, hi in [((-WX - B_, -WIN - B_, -0.004), (WX + B_, -WIN, 0.006)), ((-WX - B_, WIN, -0.004), (WX + B_, WIN + B_, 0.006)),
               ((-WX - B_, -WIN, -0.004), (-WX, WIN, 0.006)), ((WX, -WIN, -0.004), (WX + B_, WIN, 0.006))]:
    part_box(body, lo, hi, 0.003, H, ROW_M)
x_of = lambda k: (DRUMS - 1) / 2 * PITCH - k * PITCH
for k in range(3, DRUMS, 3):
    part_box(body, (x_of(k - 0.5) - 0.0025, -WIN, -0.02), (x_of(k - 0.5) + 0.0025, WIN, 0.004), 0.001, K, ROW_M)
for x in (-WX - B_ / 2, WX + B_ / 2):                                            # bezel screws
    spin(body, [(0, 0), (0.005, 0), (0.004, 0.003), (0, 0.004)], H, ROW_M @ at(x, 0, 0.006), 10)
px0, px1, ps0, ps1 = PLATE_X[0] - CX, PLATE_X[1] - CX, -0.025, 0.025            # in row space
part_box(body, (px0, ps0, -0.002), (px1, ps1, 0.005), 0.002, D, ROW_M)
for x, s in [(px0 + 0.007, ps0 + 0.007), (px1 - 0.007, ps0 + 0.007), (px0 + 0.007, ps1 - 0.007), (px1 - 0.007, ps1 - 0.007)]:
    spin(body, [(0, 0), (0.0035, 0), (0.003, 0.002), (0, 0.003)], H, ROW_M @ at(x, s, 0.005), 8)


def drum(k):
    """Seam-split drum around X: outer surface (dial) with chamfers, bakelite side caps."""
    part = bmesh.new(); steps = 32
    x0, x1 = x_of(k) - DRUM_W / 2, x_of(k) + DRUM_W / 2
    across = [(x0, DRUM_R - 0.004), (x0 + 0.003, DRUM_R), (x1 - 0.003, DRUM_R), (x1, DRUM_R - 0.004)]
    rings = []
    for i in range(steps + 1):
        a = i / steps * math.tau
        rings.append([part.verts.new((x, 0, 0)) for x, _r in across])
        for v, (_x, r) in zip(rings[-1], across):
            v.co.y, v.co.z = math.sin(a) * r, math.cos(a) * r   # a = 0 faces the window (local +Z)
    for r0, r1 in zip(rings, rings[1:]):
        for j in range(len(across) - 1):
            part.faces.new((r0[j], r1[j], r1[j + 1], r0[j + 1])).material_index = G
    for j in (0, len(across) - 1):
        cap = part.faces.new([r[j] for r in rings[:-1]] if j else [r[j] for r in rings[:-1]][::-1])
        cap.material_index = K
    bmesh.ops.recalc_face_normals(part, faces=part.faces)
    # Into row space: local Y -> slope up, local Z -> window normal, centre below the window.
    bmesh.ops.transform(part, matrix=ROW_M @ at(0, 0, -DRUM_R - 0.004), verts=part.verts)
    return part


parts = [("Body", (0, 0, 0), body)]
for k in range(DRUMS):
    parts.append(("Drum%d" % k, tuple(row_point(x_of(k), -DRUM_R - 0.004)), drum(k)))
ob, arm = rig(ASSET, parts, [paint, metal, dial, digits])

# Vertex colours per logical part, drum and plate UVs into the dial atlas, then 3 real surfaces.
me = ob.data
col = me.color_attributes.new("Col", "BYTE_COLOR", "CORNER")
me.color_attributes.active_color = col
me.color_attributes.render_color_index = me.color_attributes.find("Col")
uv = me.uv_layers["UVMap"]
u0, v0, du, dv = PLATE_UV[COUNTER]
for poly in me.polygons:
    part = poly.material_index
    for li in poly.loop_indices:
        col.data[li].color = (*COLOURS[part], 1)
    if part in (D, G):
        c = poly.center
        if part == D:                                        # nameplate
            for li in poly.loop_indices:
                lo = ROW_INV @ me.vertices[me.loops[li].vertex_index].co
                uv.data[li].uv = (u0 + (lo.x - px0) / (px1 - px0) * du, v0 + (lo.y - ps0) / (ps1 - ps0) * dv)
        else:                                                # drum surface
            k = round(((DRUMS - 1) / 2 * PITCH - (c.x - CX)) / PITCH)
            centre = row_point(x_of(k), -DRUM_R - 0.004)
            vs = []
            for li in poly.loop_indices:
                co = me.vertices[me.loops[li].vertex_index].co
                d = co - centre
                v = math.atan2(d.dot(SD), d.dot(N_)) / math.tau + 0.05
                u = min(max((co.x - CX - (x_of(k) - DRUM_W / 2)) / DRUM_W, 0), 1) * DRUM_U
                vs.append([li, u, v])
            if max(e[2] for e in vs) - min(e[2] for e in vs) > 0.5:
                for e in vs:
                    e[2] += 1 if e[2] < 0.5 else 0
            for li, u, v in vs:
                uv.data[li].uv = (u, v)
    poly.material_index = SURFACE[part]


def show(bones, digits):
    for k, d in enumerate(digits):
        b = bones["Drum%d" % k]; b.rotation_mode = "QUATERNION"
        b.rotation_quaternion = Quaternion((1, 0, 0), math.radians(d * 36))


STATES = {"total": lambda b: show(b, [4, 3, 2, 1]), "rolling": lambda b: show(b, [4.5, 3, 2, 1])}
FRAME = ((0.065, -0.72, 1.3), (0.065, 0.0, 0.12), 50, 1280, 960)
