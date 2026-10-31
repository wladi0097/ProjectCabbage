# Inbox tray: a dented-looking pressed-steel desk tray, low walls with a rolled rim, a lower front
# lip with a finger scoop and a riveted brass plate (REQUISITIONS is a Label3D in Godot). Holds
# three cards one below the other; floor top at 0.018. Blender Z-up, front = -Y. Origin: floor centre.
ASSET = "inbox_tray"
COLOURS[P] = (0.05, 0.06, 0.055)   # far darker than the shared pale enamel: under the lamp it read white
W, D = 0.21, 0.37
bm = bmesh.new()
part_box(bm, (-W, -D, 0), (W, D, 0.018), 0.004, P)                                     # floor
for lo, hi in [((-W, D - 0.012, 0.01), (W, D, 0.05)), ((-W, -D, 0.01), (-W + 0.012, D, 0.05)), ((W - 0.012, -D, 0.01), (W, D, 0.05))]:
    part_box(bm, lo, hi, 0.004, P)                                                     # back and side walls
for x in (-W + 0.006, W - 0.006):                                                      # rolled rim
    rod(bm, (x, -D + 0.006, 0.05), (x, D - 0.006, 0.05), 0.007, P, I, 10)
rod(bm, (-W + 0.006, D - 0.006, 0.05), (W - 0.006, D - 0.006, 0.05), 0.007, P, I, 10)
for x0, x1 in [(-W, -0.07), (0.07, W)]:                                                # front lip, scooped in the middle
    part_box(bm, (x0, -D, 0.01), (x1, -D + 0.012, 0.034), 0.004, P)
part_box(bm, (-0.07, -D, 0.01), (0.07, -D + 0.012, 0.022), 0.004, P)
part_box(bm, (-0.2, -D - 0.005, 0.012), (-0.075, -D, 0.034), 0.0015, B)             # brass plate (left of the scoop)
for x in (-0.192, -0.083):
    spin(bm, [(0, 0), (0.0025, 0), (0, 0.0015)], H, at(x, -D - 0.004, 0.025) @ Matrix.Rotation(math.radians(90), 4, "X"), 8)
for y in (-0.25, 0.0, 0.25):                                                           # pressed ribs under the cards
    part_box(bm, (-0.17, y - 0.008, 0.016), (0.17, y + 0.008, 0.021), 0.004, P)
for x in (-0.195, 0.195):                                                              # corner rivets
    for y in (-0.355, 0.355):
        spin(bm, [(0, 0), (0.004, 0), (0, 0.003)], H, at(x, y, 0.018), 8)
for x in (-0.18, 0.18):
    for y in (-0.34, 0.34):
        spin(bm, [(0, -0.003), (0.012, -0.003), (0.012, 0.001), (0, 0.001)], K, at(x, y, 0), 10)
ob = finish("inbox_tray", bm, [paint, metal])
colourise(ob)
FRAME = ((0.4, -1.0, 1.2), (0.0, 0.0, 0.0), 50, 1280, 960)
