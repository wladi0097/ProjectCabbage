# Project Cabbage coin tally machine: collected coins drop into the brass hopper and the nine
# number drums on the sloped front roll up the total (odometer style, Drum0 = ones, rightmost).
# No keys or crank: nothing on it looks operable. Sits against the back wall, desk left section,
# with the hopper on a pedestal at its right end (the end nearest the mat, so coins fly less).
# Blender Z-up, front = -Y (Godot +Z). Origin: floor centre of the drum shell.
# Footprint x -0.255..0.385, y -0.1..0.095; slope from 0.105 (front) to 0.2 (back).
# One skinned mesh: bone Body (static) + Drum0..Drum8, each pivoting on the drum axis (X).
#   Drum k shows digit d at rotation +d*36 deg about X (Blender and Godot alike).
# Surfaces: machine_paint (enamel / bakelite by vertex colour), machine_metal (chrome / brass by
# vertex colour), machine_dial (atlas: drum digits + "$$$" plate), see machine_tex.py.
from mathutils import Quaternion
ASSET = "tally_machine"
E, K, H, B, D = range(5)               # logical parts: enamel, bakelite, chrome, brass, dial
COLOURS = {E: (0.15, 0.19, 0.16), K: (0.025, 0.025, 0.024), H: (0.62, 0.63, 0.65), B: (0.62, 0.42, 0.14), D: (1, 1, 1)}
SURFACE = {E: 0, K: 0, H: 1, B: 1, D: 2}
DRUMS, PITCH, DRUM_W, DRUM_R = 9, 0.049, 0.045, 0.06
DRUM_U = 0.12                      # drum face width in the atlas (keeps digits unstretched)
WIN = 0.022                        # half height of the drum window: one digit row shows
WX = (DRUMS - 1) / 2 * PITCH + DRUM_W / 2 + 0.004   # half width of the window
PLATE = (-0.0625, 0.0625, -0.092, -0.04)            # nameplate on the slope (x0, x1, s0, s1)


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


# Slope frame: the drum window sits mid-slope, facing up toward the camera.
LO, HI = Vector((0, -0.09, 0.105)), Vector((0, 0.09, 0.2))
SD = (HI - LO).normalized(); N_ = Vector((0, -SD.z, SD.y)); P = (LO + HI) / 2
FRAME_M = Matrix((( 1, 0, 0, P.x), (0, SD.y, N_.y, P.y), (0, SD.z, N_.z, P.z), (0, 0, 0, 1)))
FRAME_INV = FRAME_M.inverted()
def slope(x, s, n):
    return FRAME_M @ Vector((x, s, n))


body = bmesh.new()
part_box(body, (-0.255, -0.1, 0), (0.385, 0.095, 0.03), 0.012, K)               # bakelite plinth
# Enamel drum shell with the window recess cut in.
shell = bmesh.new()
prism(shell, [(-0.09, 0.03), (0.09, 0.03), (0.09, 0.2), (-0.09, 0.105)], -0.245, 0.245, 0, 0.018, 4)
shell_ob = finish("shell_tmp", shell, [paint])
cut = boxed((-WX, -WIN, -0.08), (WX, WIN, 0.05), 0.004)
bmesh.ops.transform(cut, matrix=FRAME_M, verts=cut.verts)
boolean(shell_ob, cut)
absorb(body, shell_ob)
# Hopper pedestal at the right end, flush with the back top of the shell.
part_box(body, (0.235, -0.09, 0.03), (0.375, 0.09, 0.2), 0.016, E)
# Dark tray behind the drums, chrome bezel around the window, dividers every three drums.
part_box(body, (-WX, -WIN, -0.085), (WX, WIN, -0.08), 0.0, K, FRAME_M)
B_ = 0.012
for lo, hi in [((-WX - B_, -WIN - B_, -0.004), (WX + B_, -WIN, 0.006)), ((-WX - B_, WIN, -0.004), (WX + B_, WIN + B_, 0.006)),
               ((-WX - B_, -WIN, -0.004), (-WX, WIN, 0.006)), ((WX, -WIN, -0.004), (WX + B_, WIN, 0.006))]:
    part_box(body, lo, hi, 0.003, H, FRAME_M)
x_of = lambda k: (DRUMS - 1) / 2 * PITCH - k * PITCH
for k in (2.5, 5.5):
    part_box(body, (x_of(k) - 0.0025, -WIN, -0.02), (x_of(k) + 0.0025, WIN, 0.004), 0.001, K, FRAME_M)
for x in (-WX - B_ / 2, WX + B_ / 2):                                            # bezel screws
    spin(body, [(0, 0), (0.005, 0), (0.004, 0.003), (0, 0.004)], H, FRAME_M @ at(x, 0, 0.006), 10)
# Chrome waist trim around shell and pedestal.
X0, X1, Y0, Y1 = -0.252, 0.382, -0.097, 0.092
part_box(body, (X0, Y0, 0.048), (X1, Y0 + 0.007, 0.058), 0.003, H)
part_box(body, (X0, Y1 - 0.007, 0.048), (X1, Y1, 0.058), 0.003, H)
part_box(body, (X0, Y0, 0.048), (X0 + 0.007, Y1, 0.058), 0.003, H)
part_box(body, (X1 - 0.007, Y0, 0.048), (X1, Y1, 0.058), 0.003, H)
# Brass coin hopper on the pedestal: rolled rim, chrome collar.
hop = at(0.305, 0.0, 0.198)
spin(body, [(0, 0), (0.024, 0), (0.026, 0.012), (0.052, 0.058), (0.06, 0.066), (0.064, 0.072), (0.06, 0.077),
            (0.054, 0.072), (0.022, 0.016), (0, 0.016)], B, hop, 40)
spin(body, [(0, -0.002), (0.034, -0.002), (0.034, 0.012), (0.03, 0.016), (0, 0.016)], H, hop, 32)
# Engraved brass nameplate on the slope under the drums, four chrome screws.
px0, px1, ps0, ps1 = PLATE
part_box(body, (px0, ps0, -0.002), (px1, ps1, 0.005), 0.002, D, FRAME_M)
for x, s in [(px0 + 0.007, ps0 + 0.007), (px1 - 0.007, ps0 + 0.007), (px0 + 0.007, ps1 - 0.007), (px1 - 0.007, ps1 - 0.007)]:
    spin(body, [(0, 0), (0.0035, 0), (0.003, 0.002), (0, 0.003)], H, FRAME_M @ at(x, s, 0.005), 8)
# Rubber feet peeking out under the plinth corners.
for x in (-0.22, 0.35):
    for y in (-0.07, 0.065):
        spin(body, [(0, 0), (0.018, 0), (0.02, 0.006), (0, 0.006)], K, at(x, y, -0.004), 16)


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
            part.faces.new((r0[j], r1[j], r1[j + 1], r0[j + 1])).material_index = D
    for j in (0, len(across) - 1):
        cap = part.faces.new([r[j] for r in rings[:-1]] if j else [r[j] for r in rings[:-1]][::-1])
        cap.material_index = K
    bmesh.ops.recalc_face_normals(part, faces=part.faces)
    # Into slope space: local Y -> slope up, local Z -> window normal, centre below the window.
    bmesh.ops.transform(part, matrix=FRAME_M @ at(0, 0, -DRUM_R - 0.004), verts=part.verts)
    return part


parts = [("Body", (0, 0, 0), body)]
for k in range(DRUMS):
    parts.append(("Drum%d" % k, tuple(slope(x_of(k), 0, -DRUM_R - 0.004)), drum(k)))
ob, arm = rig("tally_machine", parts, [paint, metal, dial])

# Vertex colours per logical part, drum and plate UVs into the dial atlas, then 3 real surfaces.
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
        if (FRAME_INV @ c).z > 0:                            # nameplate (above the slope)
            for li in poly.loop_indices:
                lo = FRAME_INV @ me.vertices[me.loops[li].vertex_index].co
                uv.data[li].uv = (0.5 + (lo.x - px0) / (px1 - px0) * 0.5, 0.8 + (lo.y - ps0) / (ps1 - ps0) * 0.2)
        else:                                                # drum surface
            k = round(((DRUMS - 1) / 2 * PITCH - c.x) / PITCH)
            centre = slope(x_of(k), 0, -DRUM_R - 0.004)
            vs = []
            for li in poly.loop_indices:
                co = me.vertices[me.loops[li].vertex_index].co
                d = co - centre
                v = math.atan2(d.dot(SD), d.dot(N_)) / math.tau + 0.05
                u = min(max((co.x - (x_of(k) - DRUM_W / 2)) / DRUM_W, 0), 1) * DRUM_U
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
