# FILES folder: a dull manila office folder lying flat on the desk, portrait. Back board with a tab
# sticking out of the front edge (toward the camera), a stack of papers inside whose edges peek out
# at the front and the right, and a cover hinged along the back edge (+Y), cut shorter so the tab
# shows. A thin band round the back board's edge is its own surface (files_glow) that the game
# lights up softly when a memo is filed. The FILES stamp is a Label3D on the cover in Godot.
# Blender Z-up, front = -Y (Godot +Z). Origin: floor centre.
# Bones: Base (back board, glow band), Papers (the stack: rises), CoverHinge (at the back edge,
# top of the stack: the cover turns about X, lifting its front edge).
ASSET = "files_folder"
M, S, N, G = 7, 8, 9, 10
COLOURS[M] = (0.092, 0.09, 0.07)    # dull manila board
COLOURS[N] = (0.07, 0.068, 0.054)     # the back board, a shade darker
COLOURS[S] = (0.17, 0.17, 0.155)       # papers: grey office stock
COLOURS[G] = (0.085, 0.083, 0.065)    # glow band (unlit: the board's edge)
COLOURS[K] = (0.03, 0.03, 0.028)
SURFACE.update({M: 0, S: 0, N: 0, G: 2})
glow = emissive("files_glow", (0.85, 0.86, 0.78), 0.0, (0.085, 0.083, 0.065))
W, D = 0.095, 0.125           # half width, half depth of the back board
BOARD = 0.006
STACK = 0.022                 # papers' top
COVER = 0.006
TAB_X0, TAB_X1, TAB_Y = 0.01, 0.075, 0.026   # tab along the front edge, how far it sticks out

base = bmesh.new()
part_box(base, (-W, -D, 0.0), (W, D, BOARD), 0.002, N)
part_box(base, (TAB_X0, -D - TAB_Y, 0.0), (TAB_X1, -D + 0.01, BOARD), 0.004, N)          # the tab
E_ = 0.016
for lo, hi in [((-W - E_, -D - E_, 0.0), (W + E_, -D, BOARD + 0.008)),
               ((-W - E_, D, 0.0), (W + E_, D + E_, BOARD + 0.008)),
               ((-W - E_, -D, 0.0), (-W, D, BOARD + 0.008)),
               ((W, -D, 0.0), (W + E_, D, BOARD + 0.008))]:
    part_box(base, lo, hi, 0.0015, G)                                                    # glow band

papers = bmesh.new()
SHEETS = [  # (x0, y0, x1, y1, z0, turn) : each sheet a little offset, so edges peek out
    (-W + 0.006, -D + 0.004, W - 0.004, D - 0.006, BOARD, 0.0),
    (-W + 0.012, -D - 0.008, W + 0.006, D - 0.012, BOARD + 0.004, 0.025),
    (-W + 0.004, -D - 0.002, W + 0.012, D - 0.004, BOARD + 0.008, -0.03),
    (-W + 0.008, -D + 0.002, W - 0.002, D - 0.008, BOARD + 0.012, 0.012),
]
for x0, y0, x1, y1, z0, turn in SHEETS:
    sheet = boxed((x0, y0, z0), (x1, y1, z0 + 0.0035), 0.0008)
    merge(papers, sheet, Matrix.Rotation(turn, 4, "Z"), S)
part_box(papers, (-W + 0.01, -D + 0.01, BOARD + 0.015), (W - 0.01, D - 0.01, STACK), 0.001, S)
# A typed line block on the top sheet, where the cover will show it opened.
for i in range(4):
    y = -D + 0.03 + i * 0.016
    part_box(papers, (-W + 0.025, y, STACK - 0.0002), (W - 0.03 - 0.02 * (i % 2), y + 0.004, STACK + 0.0006), 0.0, K)

cover = bmesh.new()
part_box(cover, (-W + 0.001, -D + 0.012, STACK), (W - 0.001, D, STACK + COVER), 0.002, M)
# A crease along the hinge, like a real fold.
part_box(cover, (-W + 0.001, D - 0.012, STACK + COVER - 0.001), (W - 0.001, D - 0.006, STACK + COVER + 0.0008), 0.0, N)

ob, arm = rig("files_folder", [("Base", (0, 0, 0), base), ("Papers", (0, 0, BOARD), papers),
                               ("CoverHinge", (0, D, STACK), cover)], [paint, metal, glow])
colourise(ob)
print("COVER_TOP", STACK + COVER, "HINGE_Y", D)


def opened(bones):
    bones["CoverHinge"].rotation_mode = "XYZ"
    bones["CoverHinge"].rotation_euler = (math.radians(-22), 0, 0)
    bones["Papers"].location = (0, 0.006, 0)       # upright bone: local Y = world Z


STATES = {"open": opened}
FRAME = ((0.3, -0.55, 0.55), (0.0, -0.02, 0.01), 50, 960, 1280)
