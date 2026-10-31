# Project Cabbage acceptance gauge: a round steel pressure-style gauge clamped onto the price slate's
# top-right frame corner. Its needle shows the chance the street buys at the chalked price.
# Built upright, face toward the front (-Y = Godot +Z); in Godot it takes the slate face's tilt.
# Origin: back centre of the case. Case radius 0.066, depth 0.034. A strap hooks over the slate frame.
# One skinned mesh: bone Body (static) + Needle, pivoting on the face normal at the face centre.
#   Needle points straight up at rest; p (0..1) is a clockwise turn of -120 + 240 p deg seen from the
#   front, i.e. a rotation of (120 - 240 p) deg about bone-local Z (= world -Y, out of the face).
# Surfaces: machine_paint, machine_metal (vertex colour tinted), machine_dial (atlas face, see
# machine_tex.py: centre (768, 512) px, radius 250 px).
from mathutils import Quaternion
ASSET = "acceptance_gauge"
E, K, H, D, P = range(5)              # enamel, bakelite, chrome, dial, pale needle
COLOURS = {E: (0.06, 0.075, 0.068), K: (0.025, 0.025, 0.024), H: (0.62, 0.63, 0.65), D: (1, 1, 1), P: (0.86, 0.84, 0.78)}
SURFACE = {E: 0, K: 0, H: 1, D: 2, P: 0}
R, FACE_R, FACE_H = 0.066, 0.056, 0.024
FRONT = Matrix.Rotation(math.pi, 4, "X")               # lathe axis (+Y) -> out of the face (-Y)
# Where the gauge sits on the slate, in the slate's board frame (x right, y up the board, z out).
ON_SLATE = Vector((0.196, 0.177, 0.009))


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


def lathe_front(bm, profile, mat, steps=40):
    merge(bm, lathed(list(profile), steps), FRONT, mat)


body = bmesh.new()
lathe_front(body, [(0, 0), (R - 0.004, 0), (R, 0.004), (R, 0.026), (FACE_R, 0.026), (FACE_R, 0.02), (0, 0.02)], E)                 # enamel case
lathe_front(body, [(0, FACE_H - 0.004), (FACE_R, FACE_H - 0.004), (FACE_R, FACE_H), (0, FACE_H)], D)  # dial face
lathe_front(body, [(FACE_R - 0.002, 0.024), (R + 0.002, 0.024), (R + 0.002, 0.03), (R - 0.002, 0.034),
                   (FACE_R + 0.001, 0.034), (FACE_R - 0.002, 0.03)], H)                            # chrome bezel
for a in (45, 135, 225, 315):                                                                     # bezel screws
    x, z = math.cos(math.radians(a)) * 0.0605, math.sin(math.radians(a)) * 0.0605
    merge(body, lathed([(0, 0), (0.0032, 0), (0.0028, 0.002), (0, 0.003)], 10), at(x, -0.033, z) @ FRONT, K)
# Strap: over the frame's top edge (local z -0.035) and down behind it, with a thumb screw.
part_box(body, (-0.014, -0.001, -0.035), (0.014, 0.038, -0.03), 0.0015, H)
part_box(body, (-0.014, 0.033, -0.08), (0.014, 0.038, -0.03), 0.0015, H)
rod(body, (0, 0.038, -0.065), (0, 0.052, -0.065), 0.004, H, I, 10)
merge(body, lathed([(0, 0), (0.011, 0), (0.011, 0.006), (0, 0.006)], 14), at(0, 0.05, -0.065), K)

needle = bmesh.new()
n0 = FACE_H + 0.002
part_box(needle, (-0.0028, -n0 - 0.0015, -0.012), (0.0028, -n0, 0.0), 0.0, P)   # counterweight tail
tip = bmesh.new()                                                                 # tapered pointer, up
vs = [tip.verts.new((x, -n0 - t, z)) for t in (0, 0.0015) for x, z in [(-0.0022, 0), (0.0022, 0), (0.0006, 0.05), (-0.0006, 0.05)]]
for f in [(0, 3, 2, 1), (4, 5, 6, 7), (0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7)]:
    tip.faces.new([vs[i] for i in f])
bmesh.ops.recalc_face_normals(tip, faces=tip.faces)
merge(needle, tip, I, P)
lathe_front(needle, [(0, FACE_H), (0.0075, FACE_H), (0.0075, n0 + 0.002), (0.004, n0 + 0.005), (0, n0 + 0.005)], H, 20)  # hub

ob, arm = rig("acceptance_gauge", [("Body", (0, 0, 0), body), ("Needle", (0, -FACE_H, 0), needle)], [paint, metal, dial])

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
            co = me.vertices[me.loops[li].vertex_index].co
            uv.data[li].uv = ((768 + co.x / FACE_R * 250) / 1024, 1 - (512 - co.z / FACE_R * 250) / 1024)
    poly.material_index = SURFACE[part]


def point(bones, p):
    b = bones["Needle"]; b.rotation_mode = "QUATERNION"
    b.rotation_quaternion = Quaternion((0, 0, 1), math.radians(120 - 240 * p))


# Mockup only: the price slate around it, lifted off the backdrop floor. Not saved.
if os.environ.get("SAVE") != "1":
    TILT = math.radians(61)
    U = Vector((0, math.sin(TILT), math.cos(TILT))); N_ = Vector((0, -math.cos(TILT), math.sin(TILT)))
    P = Vector((0, -0.13, 0.03)) + U * 0.142
    BOARD = Matrix(((1, 0, 0, P.x), (0, U.y, N_.y, P.y), (0, U.z, N_.z, P.z), (0, 0, 0, 1)))
    O = ON_SLATE
    G = Matrix(((1, 0, 0, -O.x), (0, 0, -1, O.z), (0, 1, 0, -O.y), (0, 0, 0, 1)))
    LIFT = at(0, 0, 0.45)
    with bpy.data.libraries.load("C:/Users/wladi/Desktop/ProjectCabbage/assets/meshes/Machines/price_slate.blend") as (src, dst):
        dst.objects = [n for n in src.objects]
    for o in dst.objects:
        if o is None or o.type != "MESH":
            continue
        scene_ob = o; scene_ob.name = "Slate-noimp"
        bpy.context.scene.collection.objects.link(scene_ob)
        scene_ob.matrix_world = LIFT @ G @ BOARD.inverted() @ scene_ob.matrix_world
    arm.location = (0, 0, 0.45)

STATES = {"p0": lambda b: point(b, 0.0), "p55": lambda b: point(b, 0.55), "p100": lambda b: point(b, 1.0)}
FRAME = ((-0.1, -1.1, 0.75), (-0.1, 0.0, 0.33), 60, 1280, 960)
