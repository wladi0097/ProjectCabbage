# Project Cabbage quality assurance bay: a steel inspection cabinet fitted into the left third of the
# window gap (Card 5). A cabbage flicked into its open mouth is sucked in through the suction port at
# the back while the scan head rides across the glass top; the needle on the sloped console sweeps
# and the busy lamp glows, then the Findings counter ticks. While busy the front flap is up.
# Blender Z-up, front = -Y (Godot +Z). Origin: on the sill at the wall's inner face, at the centre of
# the gap's left third: Godot (-0.08, 0.75, -0.80). The chamber fits under the raised sash (gap top
# 0.32 above); the console's sloped face rises in front of the sash rail (y < 0.085) to 0.37.
# One skinned mesh: bone Body (static); Flap (hinge on the mouth's front bottom edge, bone X; rests
# flat on the desk as a lip, -90 deg stands it up); Needle (turns about the console face normal,
# bone-local NEEDLE_AXIS = Godot (0, 0.7615, 0.648): (120 - 240 p) deg for p 0..1); ScanHead (slides
# along bone X = world X, 0 at the chamber's left end, SCAN_RUN at the right).
# The busy lamp's glowing lens lives in the Godot scene (see the GODOT prints). No name plate: the
# dial sits centred on the face, the lamp in its lower right corner.
# Surfaces: machine_paint, machine_metal (vertex colour tinted), qa_glass (the chamber's top pane).
from mathutils import Quaternion
ASSET = "qa_bay"
E, K, H, G, F, P = range(6)            # enamel, bakelite/rubber, chrome, glass, dark flap enamel, dial face
COLOURS = {E: (0.15, 0.19, 0.16), K: (0.025, 0.025, 0.024), H: (0.62, 0.63, 0.65), G: (1, 1, 1),
           F: (0.075, 0.095, 0.085), P: (0.78, 0.77, 0.71)}
SURFACE = {E: 0, K: 0, H: 1, G: 2, F: 0, P: 0}
# outer x, chamber's left wall (console on the left of it). X1 puts the right cheek's outer face on the
# sales split (SaleWindow.SPLIT_X 0.33 = bay x 0.41) and centres the 4 cm cheek under the window's heavy
# mullion (world x 0.31 = bay x 0.39, room_geo.py COLS[1]).
X0, X1, XC = -0.37, 0.41, -0.09
Y0, Y1 = -0.17, 0.24                   # front (room side), back (outside)
TOP = 0.30
MOUTH = (XC + 0.02, X1 - 0.04)         # open front of the chamber


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
glass = material("qa_glass", (0.55, 0.65, 0.65), 0.0, 0.05)
glass.surface_render_method = "BLENDED"
glass.node_tree.nodes["Principled BSDF"].inputs["Alpha"].default_value = 0.25


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


body = bmesh.new()
part_box(body, (X0, Y0, 0), (X1, Y1, 0.014), 0.003, K)                          # bakelite base plate
# Instrument console: its face slopes back toward the camera, rising in front of the sash rail, then
# drops to TOP behind it.
FACE_LO, FACE_HI = Vector((0, Y0 + 0.01, 0.17)), Vector((0, 0.075, 0.37))
prism(body, [(Y0 + 0.01, 0.014), (Y0 + 0.01, 0.17), (0.075, 0.37), (0.075, TOP), (Y1, TOP), (Y1, 0.014)],
      X0, XC, E, 0.006, 2)
SD = (FACE_HI - FACE_LO).normalized(); NF = Vector((0, -SD.z, SD.y)); PF = (FACE_LO + FACE_HI) / 2
FACE_M = Matrix(((1, 0, 0, 0), (0, SD.y, NF.y, PF.y), (0, SD.z, NF.z, PF.z), (0, 0, 0, 1)))
def face(x, s, n): return FACE_M @ Vector((x, s, n))
part_box(body, (X0 + 0.004, Y0 + 0.006, 0.14), (XC - 0.004, Y0 + 0.012, 0.15), 0.002, H)   # waist trim
for k in range(4):                                                                  # vents on the back top
    y = 0.11 + k * 0.03
    part_box(body, (X0 + 0.04, y, TOP - 0.004), (XC - 0.04, y + 0.012, TOP + 0.002), 0.002, K)
# Dial: pale face, chrome bezel, black tick studs; the needle is its own bone.
DIAL, DIAL_R = (-0.23, 0.01), 0.085
spin(body, [(0, 0), (DIAL_R + 0.012, 0), (DIAL_R + 0.012, 0.01), (DIAL_R + 0.004, 0.014), (DIAL_R, 0.006), (0, 0.006)], H,
     FACE_M @ at(DIAL[0], DIAL[1], 0), 40)
spin(body, [(0, 0), (DIAL_R, 0), (DIAL_R, 0.007), (0, 0.007)], P, FACE_M @ at(DIAL[0], DIAL[1], 0), 40)
for a in range(-120, 121, 30):
    r = DIAL_R - 0.016
    x, s = DIAL[0] + math.sin(math.radians(a)) * r, DIAL[1] + math.cos(math.radians(a)) * r
    w = 0.006 if a % 120 else 0.01
    part_box(body, (x - w / 2, s - w / 2, 0.006), (x + w / 2, s + w / 2, 0.009), 0.0, K, FACE_M)
# Busy lamp bezel (the glowing lens is a mesh in the Godot scene).
LAMP = (-0.13, -0.095)
spin(body, [(0, 0), (0.03, 0), (0.03, 0.008), (0.024, 0.014), (0.02, 0.006), (0, 0.006)], H, FACE_M @ at(LAMP[0], LAMP[1], 0), 24)

# Chamber: enamel cheeks and back, dark liners inside, a black rubber floor and a suction port.
part_box(body, (MOUTH[1], Y0 + 0.01, 0.014), (X1, Y1, TOP), 0.005, E)             # right cheek
part_box(body, (XC, Y1 - 0.04, 0.014), (X1, Y1, TOP), 0.005, E)                   # back wall
part_box(body, (XC, Y0 + 0.01, 0.014), (MOUTH[0], Y1, TOP), 0.004, E)             # left cheek
part_box(body, (MOUTH[0], Y0 + 0.02, 0.014), (MOUTH[1], Y1 - 0.04, 0.024), 0.002, K)        # rubber floor
for lo, hi in [((MOUTH[0], Y0 + 0.03, 0.02), (MOUTH[0] + 0.006, Y1 - 0.04, TOP - 0.01)),
               ((MOUTH[1] - 0.006, Y0 + 0.03, 0.02), (MOUTH[1], Y1 - 0.04, TOP - 0.01)),
               ((MOUTH[0], Y1 - 0.046, 0.02), (MOUTH[1], Y1 - 0.04, TOP - 0.01))]:
    part_box(body, lo, hi, 0.0, K)
PORT = at((MOUTH[0] + MOUTH[1]) / 2, Y1 - 0.046, 0.13) @ Matrix.Rotation(math.pi / 2, 4, "X")   # facing the mouth
spin(body, [(0, 0), (0.085, 0), (0.085, 0.012), (0.07, 0.016), (0.065, 0.006), (0, 0.006)], H, PORT, 32)
spin(body, [(0, 0.004), (0.066, 0.004), (0.066, 0.008), (0, 0.008)], K, PORT, 32)
# Mouth: black rubber gasket inside a chrome lip; on the right the lip faces the whole cheek, so the wall
# reads as one chrome-edged pilaster under the mullion.
for lo, hi, m in [((MOUTH[0] - 0.012, Y0 - 0.004, 0.014), (MOUTH[0] + 0.01, Y0 + 0.03, TOP - 0.012), K),
                  ((MOUTH[1] - 0.01, Y0 - 0.004, 0.014), (MOUTH[1] + 0.012, Y0 + 0.03, TOP - 0.012), K),
                  ((MOUTH[0] - 0.012, Y0 - 0.004, TOP - 0.04), (MOUTH[1] + 0.012, Y0 + 0.03, TOP - 0.012), K),
                  ((MOUTH[0] - 0.024, Y0 - 0.012, 0.014), (MOUTH[0] - 0.01, Y0 + 0.01, TOP - 0.004), H),
                  ((MOUTH[1] + 0.01, Y0 - 0.012, 0.014), (X1, Y0 + 0.01, TOP - 0.004), H)]:
    part_box(body, lo, hi, 0.002, m)
# Glass top in a chrome frame over the chamber; its front and back bars are the scan head's rails. The
# right bar caps the whole cheek (no bare enamel strip beside it).
fx0, fx1, fy0, fy1 = MOUTH[0] - 0.01, X1, Y0 + 0.005, Y1 - 0.03
for lo, hi in [((fx0, fy0, TOP - 0.012), (fx1, fy0 + 0.025, TOP + 0.008)), ((fx0, fy1 - 0.025, TOP - 0.012), (fx1, fy1, TOP + 0.008)),
               ((fx0, fy0, TOP - 0.012), (fx0 + 0.02, fy1, TOP + 0.006)), ((MOUTH[1] - 0.01, fy0, TOP - 0.012), (fx1, fy1, TOP + 0.006))]:
    part_box(body, lo, hi, 0.003, H)
part_box(body, (fx0 + 0.02, fy0 + 0.025, TOP - 0.006), (MOUTH[1] - 0.01, fy1 - 0.025, TOP - 0.002), 0.0, G)

flap = bmesh.new()                                                                 # hinged at y = Y0, z = 0.014
part_box(flap, (MOUTH[0], Y0 - 0.2, 0.0), (MOUTH[1], Y0, 0.012), 0.003, F, at(0, 0, 0.002))
for x in (MOUTH[0] + 0.05, (MOUTH[0] + MOUTH[1]) / 2, MOUTH[1] - 0.05):            # pressed ribs
    part_box(flap, (x - 0.008, Y0 - 0.15, 0.012), (x + 0.008, Y0 - 0.02, 0.018), 0.003, F)
rod(flap, (MOUTH[0], Y0, 0.014), (MOUTH[1], Y0, 0.014), 0.011, H, I, 12)          # hinge barrel
for x in (MOUTH[0] + 0.1, MOUTH[1] - 0.1):                                          # pull bar
    rod(flap, (x, Y0 - 0.175, 0.012), (x, Y0 - 0.175, 0.03), 0.005, H, I, 8)
rod(flap, (MOUTH[0] + 0.1, Y0 - 0.175, 0.03), (MOUTH[1] - 0.1, Y0 - 0.175, 0.03), 0.007, H, I, 10)

needle = bmesh.new()                                                               # thick black pointer
NEEDLE_M = FACE_M @ at(DIAL[0], DIAL[1], 0.008)
part_box(needle, (-0.004, -0.012, 0.0), (0.004, DIAL_R - 0.01, 0.004), 0.0, K, NEEDLE_M)
spin(needle, [(0, 0), (0.011, 0), (0.011, 0.007), (0, 0.007)], H, NEEDLE_M, 14)

head = bmesh.new()                                                                 # scan head riding the rails
SCAN0 = MOUTH[0] + 0.03
part_box(head, (SCAN0 - 0.012, fy0 - 0.004, TOP + 0.008), (SCAN0 + 0.012, fy1 + 0.004, TOP + 0.03), 0.004, H)
for y in (fy0 + 0.0125, fy1 - 0.0125):
    part_box(head, (SCAN0 - 0.02, y - 0.016, TOP + 0.006), (SCAN0 + 0.02, y + 0.016, TOP + 0.034), 0.004, K)
SCAN_RUN = MOUTH[1] - 0.03 - SCAN0

ob, arm = rig("qa_bay", [("Body", (0, 0, 0), body), ("Flap", (0, Y0, 0.014), flap),
                         ("Needle", tuple(face(DIAL[0], DIAL[1], 0.008)), needle),
                         ("ScanHead", (SCAN0, (fy0 + fy1) / 2, TOP + 0.02), head)], [paint, metal, glass])
me = ob.data
col = me.color_attributes.new("Col", "BYTE_COLOR", "CORNER")
me.color_attributes.active_color = col
me.color_attributes.render_color_index = me.color_attributes.find("Col")
for poly in me.polygons:
    part = poly.material_index
    for li in poly.loop_indices:
        col.data[li].color = (*COLOURS[part], 1)
    poly.material_index = SURFACE[part]


# Godot placements for the scene (Godot (x, y, z) = Blender (x, z, -y)).
def g(v): return "(%.4f, %.4f, %.4f)" % (v.x, v.z, -v.y)
print("GODOT face normal", g(NF), "slope up", g(SD))
print("GODOT lamp", g(face(LAMP[0], LAMP[1], 0.006)), "scan x0", SCAN0, "run", SCAN_RUN, "mouth", MOUTH, "x1", X1)


def pose_bay(bones, flap_up, p, scan):
    b = bones["Flap"]; b.rotation_mode = "QUATERNION"
    b.rotation_quaternion = Quaternion((1, 0, 0), math.radians(-90 * flap_up))
    b = bones["Needle"]; b.rotation_mode = "QUATERNION"
    b.rotation_quaternion = Quaternion((0, NF.z, -NF.y), math.radians(120 - 240 * p))
    bones["ScanHead"].location = (scan * SCAN_RUN, 0, 0)


STATES = {"busy": lambda b: pose_bay(b, 1, 0.6, 0.5)}
FRAME = ((0.35, -1.0, 0.85), (0.0, 0.0, 0.16), 45, 1280, 960)
