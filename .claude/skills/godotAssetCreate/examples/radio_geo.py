# Desk radio: a portrait Bakelite box lying flat on the desk, rounded edges. Back half (+Y, the top
# of the screen) a slotted speaker grille in a raised frame; front half two chunky round push-keys
# one below the other (PlayKey: play/stop, SkipKey: skip) with a small dark track window between
# them (the amber number is a Label3D in Godot). Icons are raised dark prisms on the key caps.
# Blender Z-up, front = -Y (Godot +Z). Origin: floor centre. Bones PlayKey / SkipKey at the cap
# bases: they sink KEY_DEPTH along -Z when pressed.
ASSET = "radio"
COLOURS[E] = (0.12, 0.14, 0.125)     # body: dull grey-sage bakelite
COLOURS[P] = (0.24, 0.25, 0.225)     # key caps: paler worn grey
COLOURS[F] = (0.055, 0.058, 0.055)   # grille cavity: lifted off black so the slots read
W, D, TOP = 0.12, 0.32, 0.055
PLAY_Y, SKIP_Y, WIN_Y = -0.072, -0.245, -0.1585
KEY_DEPTH = 0.024


def prism(bm, pts, z0, z1, mat, M=I):
    """A flat polygon (x, y) extruded from z0 to z1."""
    part = bmesh.new()
    lo = [part.verts.new((x, y, z0)) for x, y in pts]
    hi = [part.verts.new((x, y, z1)) for x, y in pts]
    part.faces.new(list(reversed(lo)))
    part.faces.new(hi)
    n = len(pts)
    for k in range(n):
        part.faces.new((lo[k], lo[(k + 1) % n], hi[(k + 1) % n], hi[k]))
    merge(bm, part, M, mat)


body = bmesh.new()
part_box(body, (-W, -D, 0.006), (W, D, TOP), 0.018, E)                                  # bakelite shell
for x in (-W + 0.025, W - 0.025):                                                     # rubber feet
    for y in (-D + 0.03, D - 0.03):
        spin(body, [(0, 0), (0.016, 0), (0.016, 0.008), (0, 0.008)], K, at(x, y, 0), 12)
# Grille: raised frame, dark cavity, chunky slats across the short side.
G0, G1, GX = 0.0, 0.285, 0.094
for lo, hi in [((-GX - 0.012, G0 - 0.012, TOP - 0.004), (GX + 0.012, G0, TOP + 0.008)),
               ((-GX - 0.012, G1, TOP - 0.004), (GX + 0.012, G1 + 0.012, TOP + 0.008)),
               ((-GX - 0.012, G0, TOP - 0.004), (-GX, G1, TOP + 0.008)),
               ((GX, G0, TOP - 0.004), (GX + 0.012, G1, TOP + 0.008))]:
    part_box(body, lo, hi, 0.004, E)
part_box(body, (-GX, G0, TOP - 0.006), (GX, G1, TOP + 0.001), 0.001, F)              # cavity floor
SLATS = 7
pitch = (G1 - G0) / SLATS
for i in range(SLATS):
    y = G0 + pitch * (i + 0.5)
    part_box(body, (-GX, y - 0.0085, TOP - 0.004), (GX, y + 0.0085, TOP + 0.006), 0.003, E)
# Key collars (dark bakelite rings the keys sink into).
for y in (PLAY_Y, SKIP_Y):
    spin(body, [(0, TOP - 0.002), (0.06, TOP - 0.002), (0.06, TOP + 0.004), (0.054, TOP + 0.009),
                (0.0, TOP + 0.009)], K, at(0, y, 0), 32)
# Track window: raised bezel around a dark glass recess.
for lo, hi in [((-0.05, WIN_Y - 0.024, TOP - 0.002), (0.05, WIN_Y - 0.016, TOP + 0.007)),
               ((-0.05, WIN_Y + 0.016, TOP - 0.002), (0.05, WIN_Y + 0.024, TOP + 0.007)),
               ((-0.05, WIN_Y - 0.024, TOP - 0.002), (-0.042, WIN_Y + 0.024, TOP + 0.007)),
               ((0.042, WIN_Y - 0.024, TOP - 0.002), (0.05, WIN_Y + 0.024, TOP + 0.007))]:
    part_box(body, lo, hi, 0.002, K)
part_box(body, (-0.042, WIN_Y - 0.016, TOP - 0.002), (0.042, WIN_Y + 0.016, TOP + 0.002), 0.0005, K)

CAP = [(0, TOP + 0.002), (0.046, TOP + 0.002), (0.046, TOP + 0.03), (0.042, TOP + 0.036), (0.025, TOP + 0.039),
       (0.0, TOP + 0.04)]
ICON0, ICON1 = TOP + 0.036, TOP + 0.043


def tri(cx, cy, s):
    return [(cx - s * 0.45, cy - s * 0.55), (cx - s * 0.45, cy + s * 0.55), (cx + s * 0.6, cy)]


def key(y, icons):
    bm = bmesh.new()
    spin(bm, CAP, P, at(0, y, 0), 32)
    for pts in icons:
        prism(bm, pts, ICON0, ICON1, K)
    return bm


S = 0.034
# Play/stop: a play triangle beside a stop square. Triangles point right (+X) on screen.
play = key(PLAY_Y, [tri(-0.012, PLAY_Y, S),
                    [(0.008, PLAY_Y - 0.0135), (0.008, PLAY_Y + 0.0135), (0.035, PLAY_Y + 0.0135), (0.035, PLAY_Y - 0.0135)]])
# Skip: two triangles and a bar.
skip = key(SKIP_Y, [tri(-0.024, SKIP_Y, S * 0.85), tri(0.0, SKIP_Y, S * 0.85),
                    [(0.021, SKIP_Y - 0.016), (0.021, SKIP_Y + 0.016), (0.031, SKIP_Y + 0.016), (0.031, SKIP_Y - 0.016)]])
ob, arm = rig("radio", [("Case", (0, 0, 0), body), ("PlayKey", (0, PLAY_Y, TOP), play), ("SkipKey", (0, SKIP_Y, TOP), skip)],
              [paint, metal])
colourise(ob)


def pressed(bones):
    bones["PlayKey"].location = (0, -KEY_DEPTH, 0)    # upright bone: local Y = world Z


STATES = {"pressed": pressed}
FRAME = ((0.35, -0.75, 0.9), (0.0, -0.02, 0.03), 50, 960, 1280)
