# Cabbage gun, v2 (2026-11-19): built like a gravity-feed spray gun, so the function reads from the
# shape. A glass canister with the cabbage (own object "Glass"; the cabbage is the game's mesh,
# placed in Godot) is clamped by two tie rods onto a steel seat on the front half of a bevelled
# grey-sage housing; the housing necks down through a shroud into one plain thick steel barrel that
# ends in a chunky chamfered muzzle collar. The bore is real and 0.23 m deep (own object "Glow",
# unshaded, see below), so the down-the-barrel shot is a deep dark hole with a dim green bottom.
# Behind the canister: a pale inventory tag on the top deck and one big gauge on the rear cap (the
# faces the play camera sees). Bakelite grip raked back, a paddle trigger in a thick guard.
# Review: a pale lid was the brightest shape and stole from the cabbage (now housing enamel); a
# gauge with only a needle read as a keyhole (now bigger, ticks and a red end mark); one bar on the
# tag read as a coin slot (two typed lines); a wire trigger guard read flimsy; a bulbous collar
# read toy bazooka (smaller, flatter face); a green-lit bore read as a lit tube, not a hole.
# Blender Z-up, barrel along +Y (Godot -Z). Origin: top of the grip, where the hand closes.
# The muzzle face is at y 0.38, z 0.05 (the scene's Muzzle node). Prepend blender_lib.py + desk_vc_common.py.
ASSET = "cabbage_gun"
COLOURS[E] = (0.16, 0.175, 0.165)   # housing: dull grey-sage enamel
COLOURS[P] = (0.33, 0.33, 0.29)     # cream enamel: gauge face, tag
COLOURS[H] = (0.36, 0.37, 0.38)     # matte steel, not chrome
COLOURS[K] = (0.03, 0.03, 0.03)
AXIS = 0.05                          # barrel axis height
BACK = Matrix.Rotation(math.pi / 2, 4, "X")    # a spin() profile turned to face the rear (-Y)
CAN_Y = 0.035
CAN = at(0, CAN_Y, 0)                # canister axis: ahead of the grip, clear of the barrel

gun = bmesh.new()
# Housing, rear cap, gauge.
part_box(gun, (-0.056, -0.12, 0.0), (0.056, 0.15, 0.1), 0.02, E)
part_box(gun, (-0.05, -0.138, 0.012), (0.05, -0.11, 0.088), 0.012, K)
spin(gun, [(0, 0), (0.039, 0), (0.039, 0.006), (0.035, 0.01), (0, 0.01)], H, at(0, -0.136, AXIS) @ BACK, 32)
spin(gun, [(0, 0), (0.033, 0), (0.033, 0.003), (0, 0.003)], P, at(0, -0.145, AXIS) @ BACK, 32)
for k in range(5):                                                               # ticks, the last one red
    turn = at(0, 0, AXIS) @ Matrix.Rotation(math.radians(-70 + 35 * k), 4, "Y")
    part_box(gun, (-0.0025, -0.1495, 0.022), (0.0025, -0.1475, 0.03), 0.0, R if k == 0 else K, turn)
part_box(gun, (-0.0018, -0.1505, -0.006), (0.0018, -0.148, 0.021), 0.0, K, at(0, 0, AXIS) @ Matrix.Rotation(math.radians(25), 4, "Y"))   # needle
# Inventory tag on the top deck behind the canister: a cream plate with two typed lines.
part_box(gun, (-0.036, -0.104, 0.098), (0.036, -0.05, 0.1035), 0.002, P)
part_box(gun, (-0.027, -0.076, 0.103), (0.027, -0.069, 0.1045), 0.0, K)
part_box(gun, (-0.027, -0.09, 0.103), (0.006, -0.084, 0.1045), 0.0, K)
# Shroud: the housing necks down into the barrel.
merge(gun, lathed([(0.033, 0.0), (0.052, 0.0), (0.052, 0.014), (0.046, 0.04), (0.033, 0.04), (0.033, 0.0)], 40), at(0, 0.145, AXIS), E)
# Barrel: one plain steel tube, open down its length.
merge(gun, lathed([(0.031, 0.0), (0.042, 0.0), (0.042, 0.165), (0.031, 0.165), (0.031, 0.0)], 40), at(0, 0.15, AXIS), H)
# Muzzle collar with chamfered rims and its dark throat (the bore itself is the Glow object).
M0 = at(0, 0.31, AXIS)
merge(gun, lathed([(0.037, 0.0), (0.049, 0.0), (0.053, 0.004), (0.053, 0.065), (0.048, 0.07), (0.041, 0.07),
                   (0.037, 0.066), (0.037, 0.0)], 48), M0, H)
merge(gun, lathed([(0.0308, 0.002), (0.0375, 0.002), (0.0375, 0.063), (0.0308, 0.063), (0.0308, 0.002)], 48), M0, K)
# Canister seat, lid and the two tie rods that clamp the lid down (the glass is its own object).
spin(gun, [(0, 0.09), (0.072, 0.09), (0.072, 0.106), (0.066, 0.114), (0, 0.114)], H, CAN, 40)
spin(gun, [(0, 0.216), (0.066, 0.216), (0.072, 0.222), (0.072, 0.234), (0.064, 0.242), (0, 0.242)], E, CAN, 40)
for x in (-0.064, 0.064):
    rod(gun, (x, CAN_Y, 0.11), (x, CAN_Y, 0.22), 0.0065, H)
# Pistol grip, raked back, the trigger guard and a paddle trigger.
merge(gun, boxed((-0.03, -0.035, -0.15), (0.03, 0.035, 0.0), 0.014), at(0, -0.07, 0.01) @ Matrix.Rotation(math.radians(-16), 4, "X"), K)
merge(gun, tube([(0, -0.02, -0.005), (0, -0.02, -0.06), (0, 0.045, -0.06), (0, 0.065, -0.005)], 0.011, 8), I, E)
part_box(gun, (-0.008, 0.0, -0.045), (0.008, 0.014, 0.0), 0.004, K)
ob = finish("cabbage_gun", gun, [paint, metal])
colourise(ob)

# The bore, own object "Glow" on an unshaded vertex-colour material: a liner down the whole barrel,
# four step rings and the bottom disc. Unshaded because the gun's fill light has no shadows and lit
# the inside of the barrel pale. Near-black all the way: the step rings are faint near the mouth
# and gone a third of the way down, and the bottom keeps only a trace of the canister's green.
BORE_Y0, BORE_Y1 = 0.15, 0.375
glow = bmesh.new()
merge(glow, lathed([(0.03, 0.0), (0.0315, 0.0), (0.0315, 0.225), (0.03, 0.225), (0.03, 0.0)], 40), at(0, BORE_Y0, AXIS), 0)
for y in (0.19, 0.24, 0.29, 0.34):
    merge(glow, lathed([(0.027, 0), (0.031, 0), (0.031, 0.005), (0.027, 0.005), (0.027, 0)], 40), at(0, y, AXIS), 1)
merge(glow, lathed([(0, 0.0), (0.0315, 0.0), (0.0315, 0.003), (0, 0.003)], 40), at(0, BORE_Y0 - 0.002, AXIS), 2)
bore = finish("Glow", glow, [material("gun_bore", (1, 1, 1), 0.0, 1.0)])
BORE = (((0.003, 0.003, 0.003), (0.0, 0.0, 0.0)),            # liner: mouth, bottom
        ((0.026, 0.028, 0.026), (0.0, 0.0, 0.0)),            # step rings
        ((0.0, 0.008, 0.001), (0.0, 0.008, 0.001)))          # bottom disc (0.2 read as a lit lens, 0.04 as a green tube)
col = bore.data.color_attributes.new("Col", "BYTE_COLOR", "CORNER")
bore.data.color_attributes.active_color = col
bore.data.color_attributes.render_color_index = bore.data.color_attributes.find("Col")
for poly in bore.data.polygons:
    mouth, bottom = BORE[poly.material_index]
    for li in poly.loop_indices:
        d = (BORE_Y1 - bore.data.vertices[bore.data.loops[li].vertex_index].co.y) / (BORE_Y1 - BORE_Y0)
        d = min(max(d * 2.2, 0.0), 1.0) ** 0.7
        col.data[li].color = (*(m + (b - m) * d for m, b in zip(mouth, bottom)), 1)
    poly.material_index = 0

glass = bmesh.new()
spin(glass, [(0, 0.11), (0.058, 0.11), (0.058, 0.22), (0, 0.22)], 0, CAN, 32)
finish("Glass", glass, [material("gun_glass", (0.6, 0.66, 0.64), 0.0, 0.1)])
FRAME = ((0.75, -0.9, 0.55), (0, 0.09, 0.03), 60, 1280, 960)
