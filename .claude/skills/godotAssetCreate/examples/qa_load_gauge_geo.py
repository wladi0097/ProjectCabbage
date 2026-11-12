# Project Cabbage research station load gauge: a dark enamel housing on the QA bay's sloped console
# face, left of the busy lamp and under the dial. Two sunk windows: a long one for the row of bench
# cells (a shader quad in the Godot scene, one cell per bench, lit cold cyan while a cabbage is on
# it) and a short one for the count ("1/3", a Label3D). Static, one surface (machine_paint, vertex
# coloured), built in the bay's own space (see qa_bay_geo.py for FACE_M). Prepend desk_vc_common.py.
ASSET = "qa_load_gauge"
Y0 = -0.17
FACE_LO, FACE_HI = Vector((0, Y0 + 0.01, 0.17)), Vector((0, 0.075, 0.37))
SD = (FACE_HI - FACE_LO).normalized(); NF = Vector((0, -SD.z, SD.y)); PF = (FACE_LO + FACE_HI) / 2
FACE_M = Matrix(((1, 0, 0, 0), (0, SD.y, NF.y, PF.y), (0, SD.z, NF.z, PF.z), (0, 0, 0, 1)))
def face(x, s, n): return FACE_M @ Vector((x, s, n))

GX0, GX1, GS0, GS1 = -0.358, -0.170, -0.147, -0.095    # housing on the face (x, slope)
RIM, PROUD, FLOOR = 0.007, 0.012, 0.003
SPLIT = (-0.243, -0.236)                                 # bar between the cells and the count
D = 7; COLOURS[D] = (0.07, 0.09, 0.08); SURFACE[D] = 0     # dark enamel, as the bay's flap
gauge = bmesh.new()
part_box(gauge, (GX0, GS0, 0), (GX1, GS1, FLOOR), 0.0, K, FACE_M)                       # window floors
for lo, hi in [((GX0, GS0), (GX1, GS0 + RIM)), ((GX0, GS1 - RIM), (GX1, GS1)),
               ((GX0, GS0), (GX0 + RIM, GS1)), ((GX1 - RIM, GS0), (GX1, GS1)),
               ((SPLIT[0], GS0), (SPLIT[1], GS1))]:
    part_box(gauge, (lo[0], lo[1], 0), (hi[0], hi[1], PROUD), 0.003, D, FACE_M)
ob = finish("Gauge", gauge, [paint, metal])
colourise(ob)


def g(v): return "(%.4f, %.4f, %.4f)" % (v.x, v.z, -v.y)
SM = (GS0 + GS1) / 2
cx0, cx1 = GX0 + RIM, SPLIT[0]
print("GODOT cells centre", g(face((cx0 + cx1) / 2, SM, FLOOR + 0.001)), "size", cx1 - cx0 - 0.004, GS1 - GS0 - 2 * RIM - 0.004)
print("GODOT count centre", g(face((SPLIT[1] + GX1 - RIM) / 2, SM, FLOOR + 0.001)), "width", GX1 - RIM - SPLIT[1])
FRAME = ((-0.1, -0.6, 0.7), tuple(face(-0.26, -0.12, 0)), 30, 1280, 960)
GLB = os.environ.get("GLB")
if GLB:
    bpy.ops.object.select_all(action="DESELECT")
    ob.select_set(True)
    bpy.ops.export_scene.gltf(filepath=GLB, use_selection=True, export_apply=True, export_tangents=True,
                              export_vertex_color="ACTIVE", export_materials="EXPORT")
