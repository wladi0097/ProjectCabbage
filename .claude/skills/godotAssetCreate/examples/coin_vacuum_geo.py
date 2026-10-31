# Coin collector: a squat putty-grey robot puck that roams the mat and sucks up coins. Domed lid with
# a dark seam, dark rubber bumper arc round the front half, amber status lamp near the front edge
# (own object + material "Lamp" so code drives its emission), a blank asset-tag plate on the lid and
# a three-spoke side brush poking out front-left (own object "Brush", origin at its hub, spins about Z).
# Blender Z-up, front = +Y (Godot -Z, the caller's forward; unlike the other props). Origin: floor centre. Prepend blender_lib.py + desk_vc_common.py.
ASSET = "coin_vacuum"
U, L, D, S, T, G = range(7, 13)   # putty shell, pale putty lid, dark rubber, matte steel, tag, bristle grey
COLOURS.update({U: (0.08, 0.079, 0.076), L: (0.118, 0.116, 0.11), D: (0.022, 0.022, 0.022),
                S: (0.30, 0.31, 0.32), T: (0.52, 0.51, 0.47), G: (0.16, 0.16, 0.155)})
SURFACE.update({U: 0, L: 0, D: 0, S: 0, T: 0, G: 0})


def arc(bm, profile, a0, a1, mat, steps=14):
    """Solid partial lathe around Z: profile (r, z) closed polygon, angle 0 = front (+Y)."""
    part = bmesh.new()
    vs = [part.verts.new((r * math.sin(a0), r * math.cos(a0), z)) for r, z in profile]
    face = part.faces.new(vs)
    bmesh.ops.spin(part, geom=[face] + vs + list(face.edges), cent=(0, 0, 0), axis=(0, 0, 1),
                   angle=a0 - a1, steps=steps, use_merge=False)
    merge(bm, part, I, mat)


bm = bmesh.new()
spin(bm, [(0, 0.001), (0.047, 0.001), (0.0525, 0.006), (0.0525, 0.02), (0, 0.02)], D, I, 24)          # chassis
spin(bm, [(0, 0.019), (0.0535, 0.019), (0.0545, 0.025), (0.051, 0.0292), (0.037, 0.0305), (0, 0.0305)], U, I, 32)  # shell
spin(bm, [(0.0315, 0.0298), (0.0375, 0.0298), (0.0375, 0.0309), (0.0315, 0.0309), (0.0315, 0.0298)], D, I, 24)         # lid seam
spin(bm, [(0, 0.029), (0.0325, 0.029), (0.0325, 0.0325), (0.026, 0.0345), (0.012, 0.0352), (0, 0.0353)], L, I, 32)  # lid
arc(bm, [(0.0515, 0.004), (0.057, 0.004), (0.0585, 0.007), (0.0585, 0.021), (0.057, 0.024), (0.0515, 0.024)],
    math.radians(-95), math.radians(95), D)                                                          # front bumper
spin(bm, [(0, 0.0286), (0.0122, 0.0286), (0.0122, 0.0314), (0, 0.0314)], S, at(0, 0.043, 0), 16)     # lamp bezel
part_box(bm, (-0.011, -0.021, 0.0343), (0.011, -0.009, 0.0359), 0.0006, T)                             # asset tag
for x in (-0.0085, 0.0085):                                                                          # tag rivets
    spin(bm, [(0, 0.0358), (0.0012, 0.0358), (0, 0.0366)], S, at(x, -0.015, 0), 6)
part_box(bm, (-0.022, 0.044, 0.0015), (0.022, 0.0505, 0.006), 0.001, D)                            # intake mouth
spin(bm, [(0, 0.0), (0.0048, 0.0), (0.0048, 0.0013), (0, 0.0013)], S, at(-0.036, 0.036, 0), 10)  # brush axle
ob = finish("coin_vacuum", bm, [paint])
colourise(ob)

lamp_mat = emissive("Lamp", (1.0, 0.62, 0.22), 0.0, (0.75, 0.6, 0.38))
lp = bmesh.new()
spin(lp, [(0, 0.0298), (0.0095, 0.0298), (0.0095, 0.032), (0.0065, 0.0358), (0, 0.0368)], 0, at(0, 0.043, 0), 16)
finish("Lamp", lp, [lamp_mat], (0, 0.043, 0.0298))

HUB = (-0.036, 0.036, 0.0)
br = bmesh.new()
spin(br, [(0, 0.0012), (0.0055, 0.0012), (0.0055, 0.0037), (0, 0.0037)], S, at(*HUB), 10)
for k in range(3):
    R = at(*HUB) @ Matrix.Rotation(k * math.tau / 3 - 0.26, 4, "Z")
    merge(br, boxed((-0.0032, 0.003, 0.0012), (0.0032, 0.03, 0.0036), 0.0), R, G)
bo = finish("Brush", br, [paint], HUB)
colourise(bo)
# Built at the brief's 0.11 m, then scaled 2x: at 0.11 m (and 1.5x) the puck was barely bigger than a coin and
# read as a button from the game camera.
K = 2.0
for o in bpy.data.objects:
    o.data.transform(Matrix.Scale(K, 4)); o.location = o.location * K
FRAME = ((0.16, 0.22, 0.22), (0.0, 0.0, 0.015), 50, 1280, 960)
