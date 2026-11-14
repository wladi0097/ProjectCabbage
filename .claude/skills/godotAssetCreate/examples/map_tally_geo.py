# Map tally (chapter 3): the long currency counter lying along the map table's right edge, one split-flap
# window per currency (coins, cabbages, Findings, farms), a black engraved symbol plate left of each.
# Prepend blender_lib.py + desk_vc_common.py, append preview.py. Static, one object, exported with GLB=<path>
# and turned into assets/meshes/Props/map_tally.res by glb_to_res.gd (prefix "map").
# Built in the map camera's screen frame like map_props_geo.py: Blender X = screen right, Y = screen up
# (towards the wall), Z up, origin on the desk in the middle. The numbers and symbols are Godot-side
# (entities/map_table/props/map_tally.tscn); the script prints where they go.
ASSET = "map_tally"
SG, IR, PL, FL, HG, CAP = range(7, 13)
COLOURS.update({
    SG: (0.25, 0.31, 0.26),      # the chart rack's sage enamel
    IR: (0.11, 0.115, 0.12),     # cast iron (paint surface: mirror metal goes black in this corner)
    PL: (0.36, 0.37, 0.38),      # pale pewter bezels (paint, matte: they frame numbers)
    FL: (0.012, 0.012, 0.013),   # the flaps: black
    HG: (0.11, 0.115, 0.12),     # the flaps' hinge line
    CAP: (0.18, 0.225, 0.19),    # the end blocks: the housing's sage, a step darker (cast iron read as another machine)
})
SURFACE.update({SG: 0, IR: 0, PL: 0, FL: 0, HG: 0, CAP: 0})
COLOURS[H] = (0.5, 0.51, 0.53)

W, L = 0.18, 0.56                 # half width, half length of the housing
TOP = 0.05
PITCH = 0.24
WIN = (-0.06, 0.155, 0.075)       # a window: x0, x1, half height
PLATE = (-0.165, -0.08, 0.055)    # its symbol plate: x0, x1, half height
BZ = 0.012


def pbox(bm, lo, hi, bevel, mat, seg=1):
    part = bmesh.new(); box(part, lo, hi, bevel, seg); merge(bm, part, I, mat)


tally = bmesh.new()
pbox(tally, (-W - 0.012, -L - 0.03, 0), (W + 0.012, L + 0.03, 0.012), 0.004, IR)          # base plate
pbox(tally, (-W, -L, 0.01), (W, L, TOP), 0.008, SG, 2)                                     # housing
for s in (-1, 1):                                                                          # cast end blocks
    y0, y1 = sorted((s * 0.497, s * (L + 0.022)))
    pbox(tally, (-W - 0.006, y0, 0.01), (W + 0.006, y1, 0.068), 0.008, CAP, 2)
    for x in (-0.12, 0.12):
        spin(tally, [(0, 0.068), (0.013, 0.068), (0.013, 0.072), (0.009, 0.075), (0, 0.075)], H, at(x, s * 0.536, 0), 12)
    spin(tally, [(0, 0.068), (0.03, 0.068), (0.03, 0.071), (0, 0.071)], B, at(0, s * 0.536, 0), 20)   # maker's boss
for i in range(4):
    cy = (1.5 - i) * PITCH
    x0, x1, hh = WIN
    pbox(tally, (x0, cy - hh, TOP - 0.002), (x1, cy + hh, TOP + 0.0025), 0.0, FL)          # the flaps
    pbox(tally, (x0, cy - 0.0025, TOP + 0.0025), (x1, cy + 0.0025, TOP + 0.0032), 0.0, HG)  # their hinge line
    for lo, hi in (((x0 - BZ, cy - hh - BZ), (x1 + BZ, cy - hh)), ((x0 - BZ, cy + hh), (x1 + BZ, cy + hh + BZ)),
                   ((x0 - BZ, cy - hh), (x0, cy + hh)), ((x1, cy - hh), (x1 + BZ, cy + hh))):
        pbox(tally, (*lo, TOP - 0.004), (*hi, TOP + 0.012), 0.003, PL)                     # bezel
    for x in (x0 + 0.004, x1 - 0.004):                                                     # hinge lugs
        pbox(tally, (x - 0.004, cy - 0.011, TOP + 0.002), (x + 0.004, cy + 0.011, TOP + 0.009), 0.002, PL)
    p0, p1, ph = PLATE
    pbox(tally, (p0, cy - ph, TOP - 0.002), (p1, cy + ph, TOP + 0.004), 0.002, K)          # symbol plate
    for x in (p0 + 0.009, p1 - 0.009):
        for y in (cy - ph + 0.009, cy + ph - 0.009):
            spin(tally, [(0, TOP + 0.004), (0.004, TOP + 0.004), (0.004, TOP + 0.0055), (0, TOP + 0.0055)], H, at(x, y, 0), 6)
    if i < 3:                                                                              # rib between two modules
        pbox(tally, (-W - 0.003, cy - PITCH / 2 - 0.007, 0.01), (W + 0.003, cy - PITCH / 2 + 0.007, TOP + 0.009), 0.003, IR)
    print("WINDOW", i, ((x0 + x1) / 2, cy, TOP + 0.0045), "PLATE", ((p0 + p1) / 2, cy, TOP + 0.0055))

ob = finish("Tally", tally, [paint, metal])
colourise(ob)
print("TRIS_OF Tally", sum(len(p.vertices) - 2 for p in ob.data.polygons))

FRAME = ((-0.5, -0.1, 2.2), (0.0, 0.0, 0.0), 50, 1200, 900)
GLB = os.environ.get("GLB")
if GLB:
    bpy.ops.object.select_all(action="DESELECT")
    ob.select_set(True)
    bpy.ops.export_scene.gltf(filepath=GLB, use_selection=True, export_apply=True, export_tangents=True,
                              export_vertex_color="ACTIVE", export_materials="EXPORT")
