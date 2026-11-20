# Unrest clock (chapter 4): the bandit camps' countdown unit clamped to the top edge of the world sheet,
# over its survey pole. An institutional timer box like the map tally: a cast-iron base, a sage enamel
# housing with chunky bevels and corner screws, one moulded pewter bezel round a recessed black window
# (the smoked glass and the green DSEG digits are Godot-side), a sunk deck on the right for the RESURVEY
# desk button, and a cast clamp bar with two thumbscrews along the back edge, gripping the paper.
# Prepend blender_lib.py + desk_vc_common.py, append preview.py. Static, one object, exported with
# GLB=<path> and turned into assets/meshes/Props/map_unrest_clock.res by glb_to_res.gd (prefix "map").
# Map camera's screen frame (map_props_geo.py): Blender X = screen right, Y = up the screen, Z up,
# origin in the middle of the footprint on the paper. The footprint stays 0.62 x 0.36 m (UnrestClock.FACE_HALF).
ASSET = "unrest_clock"
SG, IR, PL, DK = range(7, 11)
COLOURS.update({
    SG: (0.25, 0.31, 0.26),      # the map tally's sage enamel
    IR: (0.11, 0.115, 0.12),     # cast iron (paint: mirror metal goes black in the map corner)
    PL: (0.42, 0.43, 0.44),      # pale pewter bezel (matte: it frames numbers)
    DK: (0.12, 0.15, 0.13),      # the button deck: the housing's sage, two steps darker
})
SURFACE.update({SG: 0, IR: 0, PL: 0, DK: 0})
COLOURS[H] = (0.5, 0.51, 0.53)

HX, HY0, HY1 = 0.302, -0.17, 0.132   # housing: half width, front and back edge
TOP = 0.045
WX, WY = -0.155, -0.015              # window centre (the readout's)
WW, WH = 0.122, 0.056                # window half size
BZ = 0.016                           # bezel width
FLOOR = TOP - 0.012
DECK = (0.152, -0.015)               # the RESURVEY plinth's centre (it is 0.30 x 0.13, sunk to stand 3 mm proud)


def pbox(bm, lo, hi, bevel, mat, seg=1):
    part = bmesh.new(); box(part, lo, hi, bevel, seg); merge(bm, part, I, mat)


def screw(bm, x, y, z, r, mat=H):
    spin(bm, [(0, z), (r, z), (r, z + 0.002), (r * 0.7, z + 0.0035), (0, z + 0.004)], mat, at(x, y, 0), 8)
    pbox(bm, (x - r * 0.8, y - 0.0008, z + 0.0032), (x + r * 0.8, y + 0.0008, z + 0.0042), 0.0, K)   # slot


bm = bmesh.new()
pbox(bm, (-0.31, -0.18, 0), (0.31, 0.18, 0.012), 0.004, IR)                      # cast base: the whole footprint
# Housing, with the window's recess cut into it.
hb = bmesh.new(); part_box(hb, (-HX, HY0, 0.01), (HX, HY1, TOP), 0.009, SG)
housing = finish("Housing", hb, [paint, metal])
cut = bmesh.new(); box(cut, (WX - WW, WY - WH, FLOOR), (WX + WW, WY + WH, TOP + 0.05), 0.0)
for f in cut.faces:
    f.material_index = K
boolean(housing, cut)
absorb(bm, housing)
pbox(bm, (WX - WW, WY - WH, FLOOR - 0.002), (WX + WW, WY + WH, FLOOR), 0.0, K)    # window floor
# One moulded bezel round the window, bevelled outside and in.
bb = bmesh.new(); part_box(bb, (WX - WW - BZ, WY - WH - BZ, TOP - 0.004), (WX + WW + BZ, WY + WH + BZ, TOP + 0.009), 0.005, PL)
bezel = finish("Bezel", bb, [paint, metal])
cut = bmesh.new(); box(cut, (WX - WW, WY - WH, TOP - 0.02), (WX + WW, WY + WH, TOP + 0.03), 0.0)
for f in cut.faces:
    f.material_index = PL
boolean(bezel, cut)
absorb(bm, bezel)
for x in (WX - WW - BZ / 2, WX + WW + BZ / 2):
    for y in (WY - WH - BZ / 2, WY + WH + BZ / 2):
        screw(bm, x, y, TOP + 0.009, 0.0058)
# Button deck: a darker sunk panel the RESURVEY plinth stands in; bare it reads as a blanked-off slot.
dx, dy = DECK
pbox(bm, (dx - 0.142, dy - 0.07, TOP - 0.004), (dx + 0.142, dy + 0.07, TOP + 0.0015), 0.003, DK)
for x in (dx - 0.128, dx + 0.128):
    for y in (dy - 0.056, dy + 0.056):
        screw(bm, x, y, TOP + 0.0015, 0.005)
# Pewter line round the deck, and a blanking cap where the button will stand (the plinth covers both).
for lo, hi in (((dx - 0.146, dy - 0.074), (dx + 0.146, dy - 0.07)), ((dx - 0.146, dy + 0.07), (dx + 0.146, dy + 0.074)),
               ((dx - 0.146, dy - 0.07), (dx - 0.142, dy + 0.07)), ((dx + 0.142, dy - 0.07), (dx + 0.146, dy + 0.07))):
    pbox(bm, (*lo, TOP - 0.002), (*hi, TOP + 0.0018), 0.0, PL)
spin(bm, [(0, TOP), (0.04, TOP), (0.04, TOP + 0.0026), (0, TOP + 0.0026)], PL, at(dx - 0.09, dy, 0), 24)
spin(bm, [(0, TOP), (0.033, TOP), (0.033, TOP + 0.0028), (0, TOP + 0.0028)], K, at(dx - 0.09, dy, 0), 24)
# Corner screws on the housing.
for x in (-HX + 0.022, HX - 0.022):
    screw(bm, x, HY0 + 0.024, TOP, 0.009)
# Clamp bar along the back edge, over the paper's edge, with two thumbscrews.
pbox(bm, (-0.29, HY1 - 0.006, 0.008), (0.29, 0.178, 0.026), 0.005, IR, 2)
for x in (-0.2, 0.2):
    spin(bm, [(0, 0.026), (0.019, 0.026), (0.019, 0.036), (0.016, 0.04), (0, 0.041)], H, at(x, 0.155, 0), 14)
    spin(bm, [(0, 0.041), (0.006, 0.041), (0.006, 0.045), (0, 0.046)], IR, at(x, 0.155, 0), 8)
for x in (-0.272, -0.1, 0.1, 0.272):
    screw(bm, x, 0.155, 0.026, 0.0045)

ob = finish("UnrestClock", bm, [paint, metal])
colourise(ob)
print("TRIS_OF UnrestClock", sum(len(p.vertices) - 2 for p in ob.data.polygons))
print("GLASS centre (godot)", (WX, FLOOR + 0.002, -WY), "size", (2 * WW, 0.004, 2 * WH))
print("PLINTH (godot)", (dx, TOP - 0.013, -dy), "FACE y", TOP + 0.009)

FRAME = ((0.0, -0.9, 1.4), (0.0, 0.0, 0.0), 50, 1200, 900)
GLB = os.environ.get("GLB")
if GLB:
    bpy.ops.object.select_all(action="DESELECT")
    ob.select_set(True)
    bpy.ops.export_scene.gltf(filepath=GLB, use_selection=True, export_apply=True, export_tangents=True,
                              export_vertex_color="ACTIVE", export_materials="EXPORT")
