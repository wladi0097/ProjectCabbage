# Approval press: a cast-iron C-frame desk press worked by a lever. Base plate with a felt pad
# (the card lies on it, top at 0.046), a column at the back, an arm with a guide sleeve over the
# pad. The Head (steel stamp block, red rubber die, rod) slides down HEAD_DROP onto the pad; the
# Lever pivots at the column top, presses the rod, and ends in a red bakelite handle toward the
# player. The player grabs the handle and drags it down LEVER_SWING. Brass plate on the base front
# (APPROVALS is a Label3D in Godot). Blender Z-up, front = -Y (Godot +Z). Origin: floor centre.
ASSET = "approval_press"
HEAD_DROP = 0.08
LEVER_SWING = math.radians(35)
LEVER_X = 0.085                     # the lever runs beside the arm, so it swings past it
PIVOT = (0, 0.12, 0.27)
REST = math.radians(10)
base = bmesh.new()
part_box(base, (-0.21, -0.14, 0), (0.21, 0.14, 0.032), 0.008, E)                       # cast base
part_box(base, (-0.19, -0.125, 0.032), (0.19, 0.1, 0.046), 0.003, F)                   # felt pad
for x in (-0.175, 0.175):                                                              # hold-down screws
    for y in (-0.112, 0.085):
        spin(base, [(0, 0), (0.008, 0), (0.007, 0.004), (0, 0.005)], H, at(x, y, 0.046), 12)
part_box(base, (-0.075, -0.146, 0.008), (0.075, -0.139, 0.026), 0.002, B)              # brass plate
part_box(base, (-0.07, 0.08, 0.03), (0.07, 0.145, 0.065), 0.008, E)                    # column foot
part_box(base, (-0.055, 0.085, 0.05), (0.055, 0.145, 0.255), 0.016, E)                   # column
for x in (-0.05, 0.05):                                                              # lever yoke cheeks
    part_box(base, (x - 0.006, 0.1, 0.235), (x + 0.006, 0.14, 0.29), 0.004, E)
rod(base, (-0.062, PIVOT[1], PIVOT[2]), (0.11, PIVOT[1], PIVOT[2]), 0.011, H)          # pivot pin, out to the lever
rod(base, (0.056, PIVOT[1], PIVOT[2]), (0.066, PIVOT[1], PIVOT[2]), 0.032, E, I, 24)    # pinion housing
part_box(base, (-0.055, -0.05, 0.172), (0.055, 0.14, 0.222), 0.016, E)                 # arm
spin(base, [(0, 0.168), (0.03, 0.168), (0.03, 0.226), (0.025, 0.231), (0, 0.231)], H, I, 24)  # guide sleeve
for x in (-0.2, 0.2):                                                                  # feet
    for y in (-0.125, 0.125):
        spin(base, [(0, -0.004), (0.014, -0.004), (0.016, 0.002), (0, 0.002)], K, at(x, y, 0), 12)
head = bmesh.new()
part_box(head, (-0.09, -0.06, 0.138), (0.09, 0.06, 0.168), 0.01, H)                 # stamp block
part_box(head, (-0.084, -0.054, 0.127), (0.084, 0.054, 0.138), 0.002, R)               # rubber die
rod(head, (0, 0, 0.168), (0, 0, 0.266), 0.0075, H)
spin(head, [(0, 0.262), (0.013, 0.262), (0.013, 0.27), (0, 0.273)], H, I, 16)           # rod cap
lever = bmesh.new()
# Built at its rest angle: from the pivot forward (-Y) and up by REST.
L = Matrix.Translation((LEVER_X, PIVOT[1], PIVOT[2])) @ Matrix.Rotation(-REST, 4, "X")   # local -Y = forward along the lever
part_box(lever, (-0.02, -0.25, -0.016), (0.02, 0.035, 0.016), 0.008, E, L)           # lever bar
rod(lever, (0, -0.25, 0), (0, -0.27, 0), 0.012, K, L)                                  # grip neck
spin(lever, [(0, -0.048), (0.03, -0.042), (0.044, -0.017), (0.046, 0), (0.044, 0.017), (0.03, 0.042), (0, 0.048)],
     R, L @ at(0, -0.31, 0) @ Matrix.Rotation(math.radians(-90), 4, "X"), 24)          # red handle ball
ob, arm = rig("approval_press", [("Body", (0, 0, 0), base), ("Head", (0, 0, 0.2), head), ("Lever", (LEVER_X, PIVOT[1], PIVOT[2]), lever)], [paint, metal])
colourise(ob)


def pressed(bones):
    bones["Head"].location = (0, -HEAD_DROP, 0)    # upright bone: local Y = world Z
    bones["Lever"].rotation_mode = "XYZ"
    bones["Lever"].rotation_euler = (LEVER_SWING, 0, 0)


STATES = {"pressed": pressed}
FRAME = ((0.55, -1.0, 0.9), (0.0, -0.1, 0.17), 50, 1280, 960)
