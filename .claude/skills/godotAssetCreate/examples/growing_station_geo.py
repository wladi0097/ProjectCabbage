# Growing station: a low steel collar round the mini tube's intake well (the user: the earlier
# chimney + cabinet hid the finished-cards spike). Prepend blender_lib.py + desk_vc_common.py.
# Godot local frame of growing_station.tscn (origin at the well's centre on the desk top, y up), via
# G(): Godot (x, y, z) = Blender (x, -z, y). Two objects:
#   Collar  a square dark steel ring 10 cm high standing on the well's 14 mm trim (mini_tube_geo.py:
#           well half 0.11, trim to 0.124, 3 mm proud), a bevelled lip flaring out at the top and
#           corner bolts. Open in the middle: the minis fall straight through.
#   Glow    an inset band round the collar's outer faces, its own material, lit cold blue from code
#           when a mini grows.
ASSET = "growing_station"
S = 8
COLOURS[S] = (0.3, 0.32, 0.33); SURFACE[S] = 1
IN, OUT_, BASE, TOP = 0.112, 0.124, 0.0035, 0.1      # ring inner / outer half width, bottom (on the trim), top
LIP_IN, LIP_OUT, LIP_Y = 0.104, 0.134, 0.082         # top lip
GLOW_Y0, GLOW_Y1, GLOW_D = 0.03, 0.062, 0.003        # glow band height and how far it stands proud


def G(x, y, z):
    return Vector((x, -z, y))


def gbox(bm, lo, hi, bevel, mat):
    part_box(bm, (lo[0], -hi[2], lo[1]), (hi[0], -lo[2], hi[1]), bevel, mat)


def ring(bm, i, o, y0, y1, bevel, mat):
    """A square ring between half widths i and o, from y0 to y1."""
    gbox(bm, (-o, y0, i), (o, y1, o), bevel, mat)
    gbox(bm, (-o, y0, -o), (o, y1, -i), bevel, mat)
    gbox(bm, (-o, y0, -i), (-i, y1, i), bevel, mat)
    gbox(bm, (i, y0, -i), (o, y1, i), bevel, mat)


collar = bmesh.new()
ring(collar, IN, OUT_, BASE, LIP_Y + 0.002, 0.002, S)
ring(collar, LIP_IN, LIP_OUT, LIP_Y, TOP, 0.004, S)
for x in (-1, 1):
    for z in (-1, 1):
        rod(collar, G(x * 0.119, TOP, z * 0.119), G(x * 0.119, TOP + 0.006, z * 0.119), 0.008, H, I, 8)

glow = bmesh.new()
ring(glow, OUT_ - 0.002, OUT_ + GLOW_D, GLOW_Y0, GLOW_Y1, 0.0015, S)

for name, bm in (("Collar", collar), ("Glow", glow)):
    ob = finish(name, bm, [paint, metal])
    colourise(ob)
FRAME = ((-0.55, -0.6, 0.6), (0.0, 0.0, 0.05), 45, 1280, 960)
GLB = os.environ.get("GLB")
if GLB:
    bpy.ops.object.select_all(action="DESELECT")
    for name in ("Collar", "Glow"):
        bpy.data.objects[name].select_set(True)
    bpy.ops.export_scene.gltf(filepath=GLB, use_selection=True, export_apply=True, export_tangents=True,
                              export_vertex_color="ACTIVE", export_materials="EXPORT")
