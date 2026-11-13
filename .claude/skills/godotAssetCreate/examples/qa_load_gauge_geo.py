# Project Cabbage research station load gauge: a row of five jewel lamp sockets under one chrome bezel on
# the QA bay's sloped console face, left of the busy lamp and under the dial, one socket per bench (the
# lab has at most five). Each socket is a stepped chrome ring round a sage enamel blanking disc; the
# jewel lenses themselves are meshes in the Godot scene (dark glass while a bench is free, cold cyan
# while busy, hidden for a bench not bought yet, so its socket reads as blanked off). Static, built in
# the bay's own space (see qa_bay_geo.py for FACE_M). Prepend desk_vc_common.py.
ASSET = "qa_load_gauge"
Y0 = -0.17
FACE_LO, FACE_HI = Vector((0, Y0 + 0.01, 0.17)), Vector((0, 0.075, 0.37))
SD = (FACE_HI - FACE_LO).normalized(); NF = Vector((0, -SD.z, SD.y)); PF = (FACE_LO + FACE_HI) / 2
FACE_M = Matrix(((1, 0, 0, 0), (0, SD.y, NF.y, PF.y), (0, SD.z, NF.z, PF.z), (0, 0, 0, 1)))
def face(x, s, n): return FACE_M @ Vector((x, s, n))

GX0, GX1, GS0, GS1 = -0.358, -0.170, -0.147, -0.095    # bezel on the face (x, slope)
SM = (GS0 + GS1) / 2
LAMPS, PITCH = 5, 0.034
LX = [(GX0 + GX1) / 2 + (i - (LAMPS - 1) / 2) * PITCH for i in range(LAMPS)]
RIM, PLATE, BEZEL = 0.008, 0.006, 0.011                  # bezel band width; plate and bezel heights
SOCKET_R, PLUG_R = 0.0145, 0.0105
D = 7; COLOURS[D] = (0.07, 0.09, 0.08); SURFACE[D] = 0     # dark enamel, as the bay's flap
gauge = bmesh.new()
part_box(gauge, (GX0, GS0, 0), (GX1, GS1, PLATE), 0.002, D, FACE_M)                   # dark enamel plate
for lo, hi in [((GX0, GS0), (GX1, GS0 + RIM)), ((GX0, GS1 - RIM), (GX1, GS1)),        # chrome bezel
               ((GX0, GS0), (GX0 + RIM, GS1)), ((GX1 - RIM, GS0), (GX1, GS1))]:
    part_box(gauge, (lo[0], lo[1], 0), (hi[0], hi[1], BEZEL), 0.003, H, FACE_M)
for x in LX:
    m = FACE_M @ at(x, SM, PLATE)
    spin(gauge, [(0, 0), (SOCKET_R, 0), (SOCKET_R, 0.004), (SOCKET_R - 0.002, 0.006), (PLUG_R + 0.0005, 0.003), (0, 0.003)], H, m, 20)
    spin(gauge, [(0, 0.002), (PLUG_R, 0.002), (PLUG_R, 0.0035), (0, 0.0035)], E, m, 20)   # blanking disc, painted like the console
ob = finish("Gauge", gauge, [paint, metal])
colourise(ob)


def g(v): return "(%.4f, %.4f, %.4f)" % (v.x, v.z, -v.y)
print("GODOT first lamp", g(face(LX[0], SM, PLATE + 0.0035)), "pitch", PITCH)
FRAME = ((-0.1, -0.6, 0.7), tuple(face(-0.26, -0.12, 0)), 30, 1280, 960)
GLB = os.environ.get("GLB")
if GLB:
    bpy.ops.object.select_all(action="DESELECT")
    ob.select_set(True)
    bpy.ops.export_scene.gltf(filepath=GLB, use_selection=True, export_apply=True, export_tangents=True,
                              export_vertex_color="ACTIVE", export_materials="EXPORT")
