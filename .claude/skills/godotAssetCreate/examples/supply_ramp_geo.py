# Project Cabbage supply ramp: a folded sheet-steel chute coming in from off-screen right, riveted
# side walls with rolled top rails, a bent lip, square legs down to the desk. The stock counter (4
# number drums, same drums and dial atlas as the tally machine) hangs on the chute's front wall, and
# a steel dock plate braced to the front legs sits below it, where the supply console lands.
# Blender Z-up, front = -Y (Godot +Z). Origin: the cabbage's centre at the lip (the CabbageFeeder
# node), 1.0 above the floor of the scene. The desk is at z -0.24. Godot ramp direction (0.65, 0.3, 0.12) = Blender (0.65, -0.12, 0.3).
# One skinned mesh: bone Body + Drum0..Drum3 (Drum0 = ones), digit d at +d*36 deg about the front
# wall direction TW (printed as DRUM_AXIS, in Godot space).
from mathutils import Quaternion
ASSET = "supply_ramp"
E, K, H, B, D, S = range(6)
COLOURS = {E: (0.15, 0.19, 0.16), K: (0.025, 0.025, 0.024), H: (0.62, 0.63, 0.65), B: (0.62, 0.42, 0.14),
           D: (1, 1, 1), S: (0.19, 0.2, 0.2)}
SURFACE = {E: 0, K: 0, H: 1, B: 1, D: 2, S: 3}
DRUMS, PITCH, DRUM_W, DRUM_R = 4, 0.049, 0.045, 0.06
DRUM_U = 0.12
WIN = 0.022
WX = (DRUMS - 1) / 2 * PITCH + DRUM_W / 2 + 0.004
DESK = -0.24
CABBAGE_R = 0.135


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
steel = material("ramp_steel", (1, 1, 1), 1.0, 0.5)
textured(steel, "ramp_steel", 5.0, (0.6, 0.64, 0.68))


def prism(bm, pts, x0, x1, mat, bevel, segs, M=I):
    part = bmesh.new()
    a = [part.verts.new((x0, y, z)) for y, z in pts]
    b = [part.verts.new((x1, y, z)) for y, z in pts]
    part.faces.new(a[::-1]); part.faces.new(b)
    for i in range(len(pts)):
        j = (i + 1) % len(pts)
        part.faces.new((a[i], a[j], b[j], b[i]))
    bmesh.ops.recalc_face_normals(part, faces=part.faces)
    bmesh.ops.bevel(part, geom=list(part.verts) + list(part.edges), offset=bevel, segments=segs, profile=0.5, affect="EDGES")
    merge(bm, part, M, mat)


# --- Chute frame: s along the ramp (up toward the top), w across, n = floor normal; n 0 = floor.
T = Vector((0.65, -0.12, 0.3)).normalized()
W = Vector((0, 0, 1)).cross(T).normalized()
N = T.cross(W)
CH = Matrix(((T.x, W.x, N.x, 0), (T.y, W.y, N.y, 0), (T.z, W.z, N.z, 0), (0, 0, 0, 1)))
CH = Matrix.Translation(-N * CABBAGE_R) @ CH
CH3 = CH.to_3x3()
# Tapered: wide at the lip so cabbages spread out, narrow at the top so they come down in a line.
LEN, H0, H1, WALL, TH = 1.25, 0.25, 0.16, 0.1, 0.007
SHELF = 0.012
LIPM = CH @ Matrix.Rotation(math.radians(28), 4, "Y")        # the bent lip past s = 0
half = lambda s: H0 + (H1 - H0) * s / LEN


def hull(bm, points, mat):
    part = bmesh.new()
    for p in points:
        part.verts.new(p)
    bmesh.ops.convex_hull(part, input=part.verts)
    merge(bm, part, I, mat)


def slab(s0, s1, w, n0, n1, M=CH):
    """Corner points of a thin piece from s0 to s1 at |w| = w(s) (callable) on one side."""
    return [M @ Vector((s, w(s), n)) for s in (s0, s1) for n in (n0, n1)]


body = bmesh.new()
for n0, n1 in ((-0.008, 0.0),):
    hull(body, slab(0, LEN, lambda s: half(s), n0, n1) + slab(0, LEN, lambda s: -half(s), n0, n1), S)          # floor
    hull(body, [LIPM @ Vector((s, side * H0, n)) for s in (-0.05, 0) for side in (-1, 1) for n in (n0, n1)], S)  # lip
for side in (-1, 1):
    inner, outer = (lambda s: side * half(s)), (lambda s: side * (half(s) + TH))
    hull(body, slab(0, LEN, inner, -0.008, WALL) + slab(0, LEN, outer, -0.008, WALL), S)                      # wall
    ends = [LIPM @ Vector((-0.05, side * (H0 + t), n)) for t in (0, TH) for n in (-0.008, 0.035)]
    hull(body, ends + [CH @ Vector((0, side * (H0 + t), n)) for t in (0, TH) for n in (-0.008, WALL)], S)    # wall over the lip
    rod(body, CH @ Vector((-0.02, side * (H0 + TH / 2), WALL - 0.004)), CH @ Vector((LEN, side * (H1 + TH / 2), WALL)), 0.009, S, I, 10)
    d = Vector((LEN, side * (H1 - H0), 0)).normalized()
    o = Vector((H0 - H1, side * LEN, 0)).normalized()
    Xc, Zc = CH3 @ d, CH3 @ o
    Yc = Zc.cross(Xc)
    for k in range(10):                                                                     # rivets
        s = 0.06 + k * 0.12
        p = CH @ Vector((s, side * (half(s) + TH), 0.03))
        R = Matrix(((Xc.x, Yc.x, Zc.x, p.x), (Xc.y, Yc.y, Zc.y, p.y), (Xc.z, Yc.z, Zc.z, p.z), (0, 0, 0, 1)))
        spin(body, [(0, 0), (0.006, 0), (0.005, 0.003), (0, 0.004)], H, R, 8)
for s in (0.2, 0.55, 0.9):                                                                  # ribs underneath
    part_box(body, (s - 0.015, -half(s), -0.03), (s + 0.015, half(s), -0.008), 0.003, S, CH)
# Square legs from the ribs straight down to the desk, with foot plates and a cross brace.
for s in (0.2, 0.55):
    for side in (-1, 1):
        top = CH @ Vector((s, side * (half(s) - 0.02), -0.03))
        part_box(body, (top.x - 0.012, top.y - 0.012, DESK + 0.006), (top.x + 0.012, top.y + 0.012, top.z), 0.003, S)
        part_box(body, (top.x - 0.03, top.y - 0.03, DESK), (top.x + 0.03, top.y + 0.03, DESK + 0.006), 0.002, S)
    a, b = CH @ Vector((s, -half(s) + 0.02, -0.03)), CH @ Vector((s, half(s) - 0.02, -0.03))
    rod(body, Vector((a.x, a.y, DESK + 0.05)), Vector((b.x, b.y, DESK + 0.05)), 0.007, S, I, 8)

# --- Dock plate below the chute, braced to the front legs; the console lands on it
#     (console centre at x 0.05, y -0.6, on top of the plate).
DOCK = (-0.18, -0.73, 0.28, -0.47)
part_box(body, (DOCK[0], DOCK[1], DESK), (DOCK[2], DOCK[3], DESK + SHELF), 0.003, S)
part_box(body, (DOCK[0], DOCK[3] - 0.012, DESK), (DOCK[2], DOCK[3], DESK + 0.045), 0.003, S)      # back flange
for x in (DOCK[0] + 0.02, DOCK[2] - 0.02):
    for y in (DOCK[1] + 0.02, DOCK[3] - 0.03):
        spin(body, [(0, 0), (0.007, 0), (0.006, 0.003), (0, 0.005)], H, at(x, y, DESK + SHELF), 8)
for s in (0.2, 0.55):                                                                       # braces to the legs
    leg = CH @ Vector((s, -half(s) + 0.02, -0.03))
    end = Vector((min(max(leg.x, DOCK[0] + 0.03), DOCK[2] - 0.03), DOCK[3] - 0.006, DESK + 0.03))
    rod(body, Vector((leg.x, leg.y, DESK + 0.03)), end, 0.009, S, I, 8)

# --- Stock counter: a small steel drum bar hung right under the chute's front edge, its window
#     tilted toward the camera, the number row along the wall (x = TW, ones at the top end). The
#     bar's body tucks under the chute floor, so no steel shows between the wall and the numbers.
S_C = 0.17
TW = CH3 @ Vector((LEN, H0 - H1, 0)).normalized()             # along the front wall
WO = CH3 @ Vector((H0 - H1, -LEN, 0)).normalized()            # front wall outward normal
NRM = (WO * math.cos(math.radians(35)) + N * math.sin(math.radians(35))).normalized()   # faces the camera
SDV = NRM.cross(TW)
P0 = CH @ Vector((S_C, -(half(S_C) + TH), -0.012))     # the wall's bottom outer edge
HX, HY, HD = WX + 0.015, DRUM_R + 0.008, 0.128       # housing half length, half width, depth
# The window's top edge sits right under the wall's bottom edge; the body tucks under the floor.
origin = P0 - SDV * HY
FRAME_M = Matrix(((TW.x, SDV.x, NRM.x, origin.x), (TW.y, SDV.y, NRM.y, origin.y), (TW.z, SDV.z, NRM.z, origin.z), (0, 0, 0, 1)))
FRAME_INV = FRAME_M.inverted()
x_of = lambda k: (DRUMS - 1) / 2 * PITCH - k * PITCH
SDW, NW = SDV, NRM
for lo, hi in [((-HX, WIN, -HD), (HX, HY, -0.004)), ((-HX, -HY, -HD), (HX, -WIN, -0.004)),
               ((-HX, -WIN, -HD), (-WX, WIN, -0.004)), ((WX, -WIN, -HD), (HX, WIN, -0.004)),
               ((-HX, -HY, -HD - 0.006), (HX, HY, -HD))]:
    part_box(body, lo, hi, 0.004, S, FRAME_M)
B_ = 0.012
for lo, hi in [((-WX - B_, -WIN - B_, -0.004), (WX + B_, -WIN, 0.006)), ((-WX - B_, WIN, -0.004), (WX + B_, WIN + B_, 0.006)),
               ((-WX - B_, -WIN, -0.004), (-WX, WIN, 0.006)), ((WX, -WIN, -0.004), (WX + B_, WIN, 0.006))]:
    part_box(body, lo, hi, 0.003, H, FRAME_M)
for x in (-WX - B_ / 2, WX + B_ / 2):
    spin(body, [(0, 0), (0.005, 0), (0.004, 0.003), (0, 0.004)], H, FRAME_M @ at(x, 0, 0.006), 10)


def drum(k):
    part = bmesh.new(); steps = 32
    x0, x1 = x_of(k) - DRUM_W / 2, x_of(k) + DRUM_W / 2
    across = [(x0, DRUM_R - 0.004), (x0 + 0.003, DRUM_R), (x1 - 0.003, DRUM_R), (x1, DRUM_R - 0.004)]
    rings = []
    for i in range(steps + 1):
        a = i / steps * math.tau
        rings.append([part.verts.new((x, 0, 0)) for x, _r in across])
        for v, (_x, r) in zip(rings[-1], across):
            v.co.y, v.co.z = math.sin(a) * r, math.cos(a) * r
    for r0, r1 in zip(rings, rings[1:]):
        for j in range(len(across) - 1):
            part.faces.new((r0[j], r1[j], r1[j + 1], r0[j + 1])).material_index = D
    for j in (0, len(across) - 1):
        cap = part.faces.new([r[j] for r in rings[:-1]] if j else [r[j] for r in rings[:-1]][::-1])
        cap.material_index = K
    bmesh.ops.recalc_face_normals(part, faces=part.faces)
    bmesh.ops.transform(part, matrix=FRAME_M @ at(0, 0, -DRUM_R - 0.004), verts=part.verts)
    return part


def drum_centre(k):
    return FRAME_M @ Vector((x_of(k), 0, -DRUM_R - 0.004))


parts = [("Body", (0, 0, 0), body)]
for k in range(DRUMS):
    parts.append(("Drum%d" % k, tuple(drum_centre(k)), drum(k)))
ob, arm = rig("supply_ramp", parts, [paint, metal, dial, steel])

me = ob.data
col = me.color_attributes.new("Col", "BYTE_COLOR", "CORNER")
me.color_attributes.active_color = col
me.color_attributes.render_color_index = me.color_attributes.find("Col")
uv = me.uv_layers["UVMap"]
for poly in me.polygons:
    part = poly.material_index
    for li in poly.loop_indices:
        col.data[li].color = (*COLOURS[part], 1)
    if part == D:
        c = poly.center
        k = round(((DRUMS - 1) / 2 * PITCH - (FRAME_INV @ c).x) / PITCH)
        centre = drum_centre(k)
        vs = []
        for li in poly.loop_indices:
            co = me.vertices[me.loops[li].vertex_index].co
            d = co - centre
            v = math.atan2(d.dot(SDW), d.dot(NW)) / math.tau + 0.05
            u = min(max(((FRAME_INV @ co).x - (x_of(k) - DRUM_W / 2)) / DRUM_W, 0), 1) * DRUM_U
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
        b.rotation_quaternion = Quaternion((TW.x, TW.z, -TW.y), math.radians(d * 36))   # bone space: Y = world Z


STATES = {"stock": lambda b: show(b, [7, 2, 0, 0])}
# Roughly the game camera's angle onto this corner.
FRAME = ((-0.35, -1.6, 1.55), (0.12, -0.05, -0.08), 40, 1280, 960)


def godot(v):
    return Vector((v.x, v.z, -v.y))


gX, gY = godot(T), godot(N)
gZ = gX.cross(gY)
c = godot(CH @ Vector((0.5, 0, -0.015)))
print("RAMP_SHAPE Transform3D(%s)" % ", ".join("%.4f" % v for v in (gX.x, gY.x, gZ.x, gX.y, gY.y, gZ.y, gX.z, gY.z, gZ.z, c.x, c.y, c.z)))
print("COUNTER_AT %.3f %.3f %.3f" % tuple(godot(origin)))
print("DRUM_AXIS %.4f %.4f %.4f" % tuple(godot(TW)))
