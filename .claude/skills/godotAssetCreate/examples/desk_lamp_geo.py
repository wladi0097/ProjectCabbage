# Desk lamp: heavy stepped round steel base, chrome stem with a knuckle, short arm, a conical
# enamel shade with a pale liner tilted 35 deg down. Two objects: "desk_lamp" (vertex-coloured
# machine_paint + machine_metal) and "Bulb" (own slot "lamp_bulb", code swaps in an emissive).
# Blender Z-up, front = -Y. Shade faces Blender (-cos15, -sin15) = Godot -X, slightly +Z. Origin: base bottom centre.
ASSET = "desk_lamp"
COLOURS[E] = (0.12, 0.15, 0.13)    # dark grey-sage enamel
COLOURS[P] = (0.55, 0.56, 0.50)    # pale liner inside the shade (bounces the bulb)
YAW = Matrix.Rotation(math.radians(15), 4, "Z")
TILT = math.radians(35)
bm = bmesh.new()
spin(bm, [(0, 0), (0.06, 0), (0.06, 0.014), (0.054, 0.024), (0.034, 0.03), (0.02, 0.034), (0, 0.034)], E, YAW, 32)  # heavy base
spin(bm, [(0, -0.002), (0.058, -0.002), (0.058, 0.001), (0, 0.001)], K, YAW, 32)                                   # felt foot ring
SX = 0.015                                                                                                         # stem a touch behind centre
spin(bm, [(0, 0.03), (0.016, 0.03), (0.016, 0.042), (0, 0.042)], H, YAW @ at(SX, 0, 0), 16)                      # stem collar
rod(bm, (SX, 0, 0.04), (SX, 0, 0.26), 0.0085, H, YAW, 12)                                                        # stem
spin(bm, [(0, 0.04), (0.012, 0.04), (0.012, 0.05), (0, 0.05)], K, YAW @ at(-0.025, 0, 0) , 12)                    # switch knob on the base
ELBOW = Vector((SX, 0, 0.27))
rod(bm, ELBOW + Vector((0, -0.016, 0)), ELBOW + Vector((0, 0.016, 0)), 0.014, K, YAW, 14)                        # knuckle
ARM_END = Vector((-0.045, 0, 0.29))
rod(bm, ELBOW, ARM_END, 0.008, H, YAW, 12)                                                                        # short arm
# Shade frame: local +Z = back of the shade, mouth at local z 0 opening along local -Z.
d = Vector((-math.cos(TILT), 0, -math.sin(TILT)))                                                                 # mouth direction
SHADE = at(*(ARM_END + d * 0.02)) @ Matrix.Rotation(math.pi / 2 - TILT, 4, "Y") @ at(0, 0, -0.12)

spin_m = lambda prof, mat: merge(bm, lathed(prof, 32), YAW @ SHADE @ UP, mat)
spin_m([(0, 0.12), (0.024, 0.12), (0.032, 0.105), (0.056, 0.03), (0.066, 0.004), (0.066, 0.0),
        (0.061, 0.0), (0.052, 0.03), (0.029, 0.1), (0, 0.104)], E)                                               # shade shell
spin_m([(0, 0.103), (0.029, 0.099), (0.052, 0.029), (0.0605, 0.002), (0.0595, 0.002), (0.05, 0.03), (0.027, 0.097), (0, 0.1)], P)  # liner
spin_m([(0, 0.13), (0.012, 0.13), (0.014, 0.118), (0, 0.118)], H)                                               # cap knob
ob = finish("desk_lamp", bm, [paint, metal])
colourise(ob)

bulb_mat = material("lamp_bulb", (0.85, 0.8, 0.62), 0.0, 0.4)
b = bmesh.new()
merge(b, lathed([(0, 0.075), (0.012, 0.074), (0.03, 0.055), (0.036, 0.035), (0.03, 0.02), (0.016, 0.012), (0, 0.01)], 24), UP)
M = YAW @ SHADE
BULB_C = M @ Vector((0, 0, 0.035))
bmesh.ops.transform(b, matrix=M, verts=b.verts)
finish("Bulb", b, [bulb_mat], tuple(BULB_C))
print("SHADE_DIR_BLENDER", (YAW.to_3x3() @ d)[:], "check", (M.to_3x3() @ Vector((0, 0, -1)))[:])
print("BULB_BLENDER", BULB_C[:], "BULB_GODOT", (BULB_C.x, BULB_C.z, -BULB_C.y))
FRAME = ((0.35, -0.75, 0.75), (-0.05, 0, 0.13), 50, 1280, 960)
