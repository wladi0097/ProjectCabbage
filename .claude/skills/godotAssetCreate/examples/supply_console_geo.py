# Project Cabbage supply console: a squat slanted terminal. On its slope a recessed dark CRT
# window (the amber price and sparkline are drawn over it in Godot) with a chrome bezel, and one
# big chunky push button (the crate icon is a Sprite3D on it in Godot). Vents on the back.
# Blender Z-up, front = -Y (Godot +Z). Origin: floor centre.
# Slope frame: from (y -0.1, z 0.075) up to (y 0.1, z 0.135); centre P = (0, 0, 0.105).
#   Button on the left, screen on the right (user's pick).
#   CRT window centre (x 0.075, s 0), half size (0.085, 0.06), glass at n -0.004.
#   Button centre (x -0.115, s 0), cap top at n 0.035, presses 0.012 along -n.
# One skinned mesh: bones Body + Plunger. Surfaces: machine_paint, machine_metal.
ASSET = "supply_console"
E, K, H, C, G = range(5)                 # enamel, bakelite, chrome, cream bakelite, glass
COLOURS = {E: (0.15, 0.19, 0.16), K: (0.025, 0.025, 0.024), H: (0.62, 0.63, 0.65),
           C: (0.55, 0.53, 0.47), G: (0.012, 0.011, 0.01)}
SURFACE = {E: 0, K: 0, H: 1, C: 0, G: 0}


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


def prism(bm, pts, x0, x1, mat, bevel, segs):
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


LO, HI = Vector((0, -0.1, 0.075)), Vector((0, 0.1, 0.135))
SD = (HI - LO).normalized(); N_ = Vector((0, -SD.z, SD.y)); P = (LO + HI) / 2
FRAME_M = Matrix(((1, 0, 0, P.x), (0, SD.y, N_.y, P.y), (0, SD.z, N_.z, P.z), (0, 0, 0, 1)))
CX, CW, CH_ = 0.075, 0.085, 0.06
BX, BR = -0.115, 0.048

body = bmesh.new()
part_box(body, (-0.205, -0.115, 0), (0.205, 0.115, 0.022), 0.01, K)                     # plinth
shell = bmesh.new()
prism(shell, [(-0.11, 0.02), (0.11, 0.02), (0.11, 0.142), (-0.11, 0.072)], -0.2, 0.2, 0, 0.016, 4)
shell_ob = finish("shell_tmp", shell, [paint])
cut = boxed((CX - CW, -CH_, -0.03), (CX + CW, CH_, 0.05), 0.008)
bmesh.ops.transform(cut, matrix=FRAME_M, verts=cut.verts)
boolean(shell_ob, cut)
absorb(body, shell_ob)
# Slightly bulged CRT glass: a shallow box with a raised centre.
part_box(body, (CX - CW, -CH_, -0.03), (CX + CW, CH_, -0.006), 0.0, G, FRAME_M)
part_box(body, (CX - CW + 0.012, -CH_ + 0.012, -0.006), (CX + CW - 0.012, CH_ - 0.012, -0.004), 0.004, G, FRAME_M)
B_ = 0.012                                                                              # chrome bezel
for lo, hi in [((CX - CW - B_, -CH_ - B_, -0.004), (CX + CW + B_, -CH_, 0.006)), ((CX - CW - B_, CH_, -0.004), (CX + CW + B_, CH_ + B_, 0.006)),
               ((CX - CW - B_, -CH_, -0.004), (CX - CW, CH_, 0.006)), ((CX + CW, -CH_, -0.004), (CX + CW + B_, CH_, 0.006))]:
    part_box(body, lo, hi, 0.003, H, FRAME_M)
for x, s in [(CX - CW - B_ / 2, -CH_ - B_ / 2), (CX + CW + B_ / 2, -CH_ - B_ / 2), (CX - CW - B_ / 2, CH_ + B_ / 2), (CX + CW + B_ / 2, CH_ + B_ / 2)]:
    spin(body, [(0, 0), (0.0045, 0), (0.004, 0.003), (0, 0.004)], H, FRAME_M @ at(x, s, 0.006), 10)
# Button well: a chrome collar ring around a dark socket.
spin(body, [(0, -0.002), (BR + 0.016, -0.002), (BR + 0.016, 0.006), (BR + 0.012, 0.012), (BR + 0.002, 0.012), (BR + 0.002, 0.002), (0, 0.002)],
     H, FRAME_M @ at(BX, 0, 0), 40)
# Chrome waist trim, vents on the back face.
part_box(body, (-0.203, -0.118, 0.04), (0.203, -0.111, 0.05), 0.003, H)
part_box(body, (-0.203, 0.111, 0.04), (0.203, 0.118, 0.05), 0.003, H)
for k in range(6):
    x = -0.1 + k * 0.04
    part_box(body, (x - 0.012, 0.108, 0.075), (x + 0.012, 0.114, 0.12), 0.002, K)
for x in (-0.17, 0.17):                                                                  # rubber feet
    for y in (-0.085, 0.085):
        spin(body, [(0, 0), (0.016, 0), (0.018, 0.006), (0, 0.006)], K, at(x, y, -0.004), 16)

plunger = bmesh.new()
spin(plunger, [(0, -0.01), (BR - 0.004, -0.01), (BR - 0.004, 0.02), (BR, 0.024), (BR - 0.002, 0.031), (BR - 0.01, 0.035), (0, 0.035)],
     C, FRAME_M @ at(BX, 0, 0), 40)
parts = [("Body", (0, 0, 0), body), ("Plunger", tuple(FRAME_M @ Vector((BX, 0, 0))), plunger)]
ob, arm = rig("supply_console", parts, [paint, metal])

me = ob.data
col = me.color_attributes.new("Col", "BYTE_COLOR", "CORNER")
me.color_attributes.active_color = col
me.color_attributes.render_color_index = me.color_attributes.find("Col")
for poly in me.polygons:
    for li in poly.loop_indices:
        col.data[li].color = (*COLOURS[poly.material_index], 1)
    poly.material_index = SURFACE[poly.material_index]


def press(bones):
    bones["Plunger"].location = (0, -0.012, 0)   # bone Y = world Z (upright bone); roughly -n


STATES = {"pressed": press}
FRAME = ((0.0, -0.75, 0.95), (0.0, 0.0, 0.08), 50, 1280, 960)
