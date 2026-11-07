# Ledger binder: a bound grey-green office ledger lying closed on the desk, portrait. Two thick
# boards over a block of pale pages, a rounded dark cloth spine down the left (-X), matte steel
# corner guards on the two free front corners, and a steel label frame on the cover (the paper
# label's LEDGER text is a Label3D in Godot). Static: the game lifts the whole thing on hover.
# Blender Z-up, front = -Y (Godot +Z). Origin: floor centre.
ASSET = "ledger_binder"
S, C = 7, 8
COLOURS[E] = (0.085, 0.11, 0.095)    # board cloth: grey-green
COLOURS[C] = (0.04, 0.05, 0.045)     # spine cloth, darker
COLOURS[S] = (0.36, 0.36, 0.33)      # page block
COLOURS[P] = (0.42, 0.42, 0.38)      # the pasted label
COLOURS[H] = (0.4, 0.41, 0.42)       # steel, matte surface
SURFACE.update({S: 0, C: 0})
W, D, T = 0.11, 0.145, 0.05          # half width, half depth, height
BT = 0.008                           # board thickness

bm = bmesh.new()
part_box(bm, (-W + 0.012, -D, 0.0), (W, D, BT), 0.003, E)                        # back board
part_box(bm, (-W + 0.012, -D, T - BT), (W, D, T), 0.003, E)                      # front board
part_box(bm, (-W + 0.016, -D + 0.006, BT), (W - 0.006, D - 0.006, T - BT), 0.001, S)   # pages
# Page edges: faint ruled bands on the block's front and right faces.
for i in range(1, 6):
    z = BT + i * (T - 2 * BT) / 6
    part_box(bm, (-W + 0.02, -D + 0.0055, z - 0.0007), (W - 0.0065, -D + 0.0065, z + 0.0007), 0.0, P)
    part_box(bm, (W - 0.0065, -D + 0.01, z - 0.0007), (W - 0.0055, D - 0.01, z + 0.0007), 0.0, P)
# Rounded spine: a lathed half-round along Y over the left edge.
spine = bmesh.new()
bmesh.ops.create_cone(spine, cap_ends=True, segments=16, radius1=T / 2 + 0.002, radius2=T / 2 + 0.002, depth=2 * D + 0.002)
merge(bm, spine, at(-W + 0.016, 0, T / 2) @ Matrix.Rotation(math.radians(90), 4, "X") @ Matrix.Scale(0.55, 4, (1, 0, 0)), C)
# Corner guards: steel triangles wrapping the two free corners of the front board.
for sy in (-1, 1):
    y0 = -D if sy < 0 else D
    tri = [(W + 0.002, y0 + sy * 0.002), (W - 0.04, y0 + sy * 0.002), (W + 0.002, y0 - sy * 0.04)]
    for z0, z1 in ((T - BT - 0.001, T + 0.0015), (-0.0015, BT + 0.001)):
        part = bmesh.new()
        lo = [part.verts.new((x, y, z0)) for x, y in tri]
        hi = [part.verts.new((x, y, z1)) for x, y in tri]
        part.faces.new(list(reversed(lo))); part.faces.new(hi)
        for k in range(3):
            part.faces.new((lo[k], lo[(k + 1) % 3], hi[(k + 1) % 3], hi[k]))
        merge(bm, part, I, H)
# Label frame: a steel rim with a pasted paper label, upper half of the cover.
LX, LY0, LY1 = 0.06, 0.02, 0.09
for lo, hi in [((-LX - 0.006, LY0 - 0.006, T), (LX + 0.006, LY0, T + 0.003)),
               ((-LX - 0.006, LY1, T), (LX + 0.006, LY1 + 0.006, T + 0.003)),
               ((-LX - 0.006, LY0, T), (-LX, LY1, T + 0.003)),
               ((LX, LY0, T), (LX + 0.006, LY1, T + 0.003))]:
    part_box(bm, lo, hi, 0.001, H)
part_box(bm, (-LX, LY0, T - 0.001), (LX, LY1, T + 0.0012), 0.0, P)
ob = finish("ledger_binder", bm, [paint, metal])
colourise(ob)
print("LABEL_CENTRE", 0, (LY0 + LY1) / 2, T + 0.0012)

STATES = {}
FRAME = ((0.35, -0.6, 0.6), (0.0, -0.02, 0.02), 50, 960, 1280)
