# Project Cabbage price slate: a desk A-frame slate in a dark steel frame, leaning back so it faces
# the game camera (61 deg from vertical), held by a wire kickstand. A chalk tray along the bottom
# with one stick of chalk. The price is chalk text drawn on it in Godot.
# Blender Z-up, front = -Y (Godot +Z). Origin: floor centre.
# Board frame FRAME_M: x right, y up the board (U), z out of the face (N), origin at the face centre.
#   Writing area: x -0.24..0.24, y -0.12..0.12, slate face at z 0.
# Surfaces: machine_paint (frame enamel, chalk), machine_metal (wire, screws), price_slate (slate face).
ASSET = "price_slate"
E, K, H, C, S = range(5)                 # enamel, bakelite, chrome, chalk, slate
COLOURS = {E: (0.06, 0.075, 0.068), K: (0.025, 0.025, 0.024), H: (0.62, 0.63, 0.65),
           C: (0.85, 0.84, 0.8), S: (1, 1, 1)}
SURFACE = {E: 0, K: 0, H: 1, C: 0, S: 2}


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
slate = material("price_slate", (1, 1, 1), 0.0, 0.92)
textured(slate, "price_slate", 1.0)

TILT = math.radians(61)
U = Vector((0, math.sin(TILT), math.cos(TILT)))          # up the board
N_ = Vector((0, -math.cos(TILT), math.sin(TILT)))        # out of the face, toward the camera
HW, HH, FW, T_ = 0.24, 0.12, 0.022, 0.016                # writing half size, frame width, thickness
BOTTOM = Vector((0, -0.13, 0.03))                        # bottom edge of the frame, face side
P = BOTTOM + U * (HH + FW)
FRAME_M = Matrix(((1, 0, 0, P.x), (0, U.y, N_.y, P.y), (0, U.z, N_.z, P.z), (0, 0, 0, 1)))

bm = bmesh.new()
part_box(bm, (-HW, -HH, -T_), (HW, HH, -0.001), 0.0, S, FRAME_M)                      # slate panel
part_box(bm, (-HW, -HH, -T_ - 0.006), (HW, HH, -T_), 0.0, E, FRAME_M)                 # backing
for lo, hi in [((-HW - FW, -HH - FW, -T_ - 0.008), (HW + FW, -HH, 0.008)), ((-HW - FW, HH, -T_ - 0.008), (HW + FW, HH + FW, 0.008)),
               ((-HW - FW, -HH, -T_ - 0.008), (-HW, HH, 0.008)), ((HW, -HH, -T_ - 0.008), (HW + FW, HH, 0.008))]:
    part_box(bm, lo, hi, 0.004, E, FRAME_M)                                            # enamel frame
for x in (-HW - FW / 2, HW + FW / 2):                                                  # corner screws
    for y in (-HH - FW / 2, HH + FW / 2):
        spin(bm, [(0, 0), (0.005, 0), (0.0045, 0.003), (0, 0.004)], H, FRAME_M @ at(x, y, 0.008), 10)
# Chalk tray: a lip standing out of the face along the bottom, with one stick of chalk in it.
part_box(bm, (-HW - FW, -HH - FW - 0.004, 0.008), (HW + FW, -HH - FW + 0.004, 0.04), 0.003, E, FRAME_M)
part_box(bm, (-HW - FW, -HH - FW + 0.004, 0.008), (HW + FW, -HH - FW + 0.012, 0.014), 0.002, E, FRAME_M)
rod(bm, (0.08, -HH - FW + 0.016, 0.02), (0.17, -HH - FW + 0.016, 0.02), 0.0065, C, FRAME_M, 10)
# Wire kickstand: a U of chrome rod from the back of the frame's top to the desk behind.
top_back = P + U * (HH + FW * 0.5) - N_ * (T_ + 0.012)
foot_y = 0.2
for x in (-0.21, 0.21):
    rod(bm, (x, top_back.y, top_back.z), (x, foot_y, 0.006), 0.0045, H)
    spin(bm, [(0, 0), (0.012, 0), (0.012, 0.008), (0, 0.008)], K, at(x, foot_y, 0), 12)    # rubber foot
rod(bm, (-0.21, foot_y, 0.006), (0.21, foot_y, 0.006), 0.0045, H)
rod(bm, (-0.22, top_back.y, top_back.z), (0.22, top_back.y, top_back.z), 0.006, H)        # hinge bar
for x in (-0.23, 0.23):                                                                   # front rubber feet
    part_box(bm, (x - 0.02, BOTTOM.y - 0.012, 0), (x + 0.02, BOTTOM.y + 0.025, 0.012), 0.003, K)

ob = finish("price_slate", bm, [paint, metal, slate])
me = ob.data
col = me.color_attributes.new("Col", "BYTE_COLOR", "CORNER")
me.color_attributes.active_color = col
me.color_attributes.render_color_index = me.color_attributes.find("Col")
for poly in me.polygons:
    for li in poly.loop_indices:
        col.data[li].color = (*COLOURS[poly.material_index], 1)
    poly.material_index = SURFACE[poly.material_index]
print("FACE_CENTRE_GODOT", (P.x, P.z, -P.y), "NORMAL_GODOT", (N_.x, N_.z, -N_.y), "UP_GODOT", (U.x, U.z, -U.y))

FRAME = ((0.0, -0.9, 1.1), (0.0, 0.0, 0.1), 50, 1280, 960)
