# Coin collector dock: a low putty wedge on a dark rubber base plate. The open front (Blender -Y,
# Godot +Z) has a shallow ramp lip with two steel charge contacts; the sloped top carries a dark
# intake grille, a blank asset tag and an amber lamp (own object + material "Lamp").
# The vacuum backs in and parks at Godot (0, 0, +0.126), facing +Z (away from the dock).
# Blender Z-up. Origin: floor centre. Prepend blender_lib.py + desk_vc_common.py.
ASSET = "vacuum_dock"
U, L, D, S, T = range(7, 12)
COLOURS.update({U: (0.08, 0.079, 0.076), L: (0.118, 0.116, 0.11), D: (0.022, 0.022, 0.022),
                S: (0.30, 0.31, 0.32), T: (0.52, 0.51, 0.47)})
SURFACE.update({U: 0, L: 0, D: 0, S: 0, T: 0})
W, Y0, Y1, ZF, ZB = 0.064, -0.006, 0.03, 0.034, 0.05     # wedge half width, front/back y, front/back top
SLOPE = math.atan2(ZB - ZF, Y1 - Y0)


def wedge(bm, mat):
    part = bmesh.new()
    vs = bmesh.ops.create_cube(part, size=1.0)["verts"]
    bmesh.ops.transform(part, matrix=at(0, (Y0 + Y1) / 2, ZB / 2) @ Matrix.Diagonal((2 * W, Y1 - Y0, ZB, 1)), verts=vs)
    for v in vs:
        if v.co.z > 0.01 and v.co.y < 0:
            v.co.z = ZF
    edges = list({e for v in vs for e in v.link_edges})
    bmesh.ops.bevel(part, geom=vs + edges, offset=0.004, segments=2, profile=0.5, affect="EDGES")
    merge(bm, part, I, mat)


def on_top(y):
    """Matrix onto the sloped top at depth y (local Z = slope normal)."""
    return at(0, y, ZF + (y - Y0) * math.tan(SLOPE)) @ Matrix.Rotation(SLOPE, 4, "X")


bm = bmesh.new()
part_box(bm, (-0.07, -0.004, 0), (0.07, 0.03, 0.005), 0.0015, D)                     # base plate
ramp = bmesh.new()                                                                    # ramp lip
rv = bmesh.ops.create_cube(ramp, size=1.0)["verts"]
bmesh.ops.transform(ramp, matrix=at(0, -0.017, 0.0025) @ Matrix.Diagonal((0.12, 0.026, 0.005, 1)), verts=rv)
for v in rv:
    if v.co.y < -0.02 and v.co.z > 0.001:
        v.co.z = 0.0008
merge(bm, ramp, I, D)
for x in (-0.022, 0.022):                                                             # charge contacts
    part_box(bm, (x - 0.005, -0.026, 0.0035), (x + 0.005, -0.006, 0.0058), 0.001, S)
wedge(bm, U)
part_box(bm, (-0.04, -0.0075, 0.012), (0.04, -0.004, 0.026), 0.0015, D)              # front slot
part_box(bm, (-0.045, 0.002, -0.001), (0.02, 0.016, 0.0015), 0.0008, D, on_top(0.004))   # top grille well
for k in range(4):                                                                    # grille bars
    y = 0.0045 + k * 0.0035
    part_box(bm, (-0.043, y - 0.0007, 0.0), (0.018, y + 0.0007, 0.0022), 0.0003, S, on_top(0.004))
part_box(bm, (0.026, -0.006, -0.0005), (0.056, 0.004, 0.0012), 0.0005, T, on_top(0.004))  # asset tag
spin(bm, [(0, -0.001), (0.011, -0.001), (0.011, 0.0018), (0, 0.0018)], S, on_top(0.02) @ at(0.041, 0, 0), 16)
ob = finish("vacuum_dock", bm, [paint])
colourise(ob)

lamp_mat = emissive("Lamp", (1.0, 0.62, 0.22), 0.0, (0.75, 0.6, 0.38))
lp = bmesh.new()
spin(lp, [(0, 0.0), (0.0085, 0.0), (0.0085, 0.003), (0.0055, 0.0062), (0, 0.0072)], 0, on_top(0.02) @ at(0.041, 0, 0), 16)
lamp_at = (on_top(0.02) @ at(0.041, 0, 0)).translation
finish("Lamp", lp, [lamp_mat], tuple(lamp_at))
# Built at the brief's 0.11 m, then scaled 2x: at 0.11 m (and 1.5x) the puck was barely bigger than a coin and
# read as a button from the game camera.
K = 2.0
for o in bpy.data.objects:
    o.data.transform(Matrix.Scale(K, 4)); o.location = o.location * K
FRAME = ((0.14, -0.26, 0.2), (0.0, 0.0, 0.02), 50, 1280, 960)
