# TV remote (keys only 3-4 mm proud, user 2026-11-08: "too hard 3d"): a chunky dark bakelite brick lying flat, long side along Y (front = -Y end towards the
# player). A chrome band near the top, a red bakelite power key, a big pale channel rocker and a 2x3
# grid of pale keys. One static object, vertex-coloured paint/metal. Origin: floor centre.
ASSET = "tv_remote"
COLOURS[K] = (0.03, 0.032, 0.03)
COLOURS[P] = (0.25, 0.26, 0.24)
W, D, T = 0.042, 0.12, 0.032

bm = bmesh.new()
part_box(bm, (-W, -D, 0.0), (W, D, T), 0.014, K)
part_box(bm, (-W + 0.004, D - 0.05, T - 0.004), (W - 0.004, D - 0.036, T + 0.0015), 0.0015, H)  # chrome band
spin(bm, [(0, 0), (0.012, 0), (0.012, 0.005), (0.01, 0.0065), (0, 0.007)], R, at(0, D - 0.022, T - 0.003), 20)  # power
part_box(bm, (-0.026, 0.005, T - 0.003), (0.026, 0.055, T + 0.004), 0.002, P)                 # channel rocker
part_box(bm, (-0.003, 0.012, T + 0.0025), (0.003, 0.048, T + 0.0048), 0.0005, K)             # its split
for row in range(3):
    for col in (-1, 1):
        part_box(bm, (col * 0.019 - 0.012, -0.085 + row * 0.03 - 0.01, T - 0.003),
                 (col * 0.019 + 0.012, -0.085 + row * 0.03 + 0.01, T + 0.003), 0.0015, P)
COLOURS[R] = (0.2, 0.05, 0.04)
ob = finish("TvRemote", bm, [paint, metal])
colourise(ob)
FRAME = ((0.18, -0.35, 0.3), (0.0, 0.0, 0.01), 50, 960, 720)
