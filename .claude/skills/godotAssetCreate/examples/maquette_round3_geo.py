# War maquettes, round 3: CCTV mast, fire sprinkler, document shredder, liability silo.
# Reuses maquette_geo.py's helpers (slab, put, cyl, stick, crate, scrap, splinter, finish_maquette, ...)
# without running its builds: prepend blender_lib.py and maquette_geo.py cut before its `objs = [` line:
#   awk '/^objs = \[/{exit} {print}' examples/maquette_geo.py > <scratch>/maquette_helpers.py
#   cat blender_lib.py <scratch>/maquette_helpers.py examples/maquette_round3_geo.py preview.py > build.py
# Blender X = Godot +X, Blender +Y = Godot -Z (a turret faces Blender +Y), Z up; origin at the
# footprint centre on the paper. GLB=<path> exports the twelve objects (glb_to_res.gd, prefix maquette).
M["ink"] = material("maquette_ink", (0.43, 0.15, 0.13), 0.0, 0.8)
M["steel_edge"] = material("maquette_steel_edge", (0.69, 0.71, 0.74), 0.6, 0.4)
N, K = 5, 6  # extra slots used below: ink, steel edge
SLOTS3 = [M["card"], M["shade"], M["core"], M["grey_board"], M["dark_board"], M["ink"], M["steel_edge"], M["balsa"]]
B = 7        # balsa slot
P1 = 0.066   # 1x1 site plate half size


def godot(v):
    return "(%.4f, %.4f, %.4f)" % (v.x, v.z, -v.y)


def plate(bm, half=P1):
    put(bm, slab((-half, -half, 0), (half, half, PL), G, G))


def tube_seam(bm, r, z0, z1, x=0.0, y=0.0):
    """A rolled card tube's glued seam strip, facing the camera (Blender -Y)."""
    put(bm, slab((-0.0035, -0.002, z0 + 0.003), (0.0035, 0.0, z1 - 0.002), C, E), at(x, y - r, 0))


def along_y(y0, y1, z, x=0.0):
    """cyl() runs along Z: this turns it to run along Blender +Y from y0 to y1 at height z."""
    return at(x, 0, z) @ rot("X", -90), (y0, y1)


def recolour(part, mat):
    for f in part.faces:
        f.material_index = mat
    return part


# ---------------------------------------------------------------- CCTV mast (1x1): the tallest thin piece
MAST_W, MAST_H = 0.014, 0.33          # balsa mast section, its top (the pan bearing sits on it)
HEAD_TILT = -10.0                      # the camera looks down a little
HEAD = (0.024, -0.05, 0.058, 0.012, 0.044)   # half width, back, front (Blender y), bottom, top (turret space)
LENS = (0.014, 0.007)                  # lens radius, how far it stands proud of the front


def cctv_head_matrix():
    return at(0, 0, 0.026) @ rot("X", -HEAD_TILT) @ at(0, 0, -0.026)


def cctv_head(bm, Mx=I):
    """The camera head: a grey-board yoke on the pan bearing, a card body under a dark-board sun hood
    (what the map camera sees: a long dark bar) that reaches past the lens with a pale steel visor edge,
    a dark lens in a pale ring. Slots SLOTS3."""
    hw, yb, yf, zb, zt = HEAD
    head = bmesh.new()
    put(head, cyl(0.016, 0.016, 0.0, 0.004, 20, G, G))                      # turntable
    put(head, slab((-0.004, -0.008, 0.004), (0.004, 0.008, zb + 0.004), G, E))  # yoke
    body = bmesh.new()
    put(body, slab((-hw, yb, zb), (hw, yf, zt), C, E))
    faces_mat(body, lambda n: C if abs(n.x) > 0.7 or n.z > 0.7 else (E if abs(n.y) > 0.7 else S))
    put(head, body, cctv_head_matrix())
    hood = slab((-hw - 0.004, yb - 0.004, zt), (hw + 0.004, yf + 0.016, zt + 0.006), D, K)
    put(head, hood, cctv_head_matrix())
    put(head, slab((-hw - 0.004, yf + 0.006, zt + 0.006), (hw + 0.004, yf + 0.016, zt + 0.0068), K, K), cctv_head_matrix())
    r, proud = LENS
    zc = (zb + zt) / 2
    lens_m = cctv_head_matrix() @ at(0, 0, zc) @ rot("X", -90)
    put(head, cyl(r + 0.003, r + 0.003, yf, yf + proud * 0.5, 20, E, E), lens_m)     # pale lens ring
    put(head, cyl(r, r, yf, yf + proud, 20, D, D), lens_m)                           # dark lens
    put(bm, head, Mx)


def cctv_muzzle():
    hw, yb, yf, zb, zt = HEAD
    return cctv_head_matrix() @ Vector((0, yf + LENS[1], (zb + zt) / 2))


def cctv_base():
    bm = bmesh.new()
    plate(bm)
    put(bm, recolour(boxed((-MAST_W / 2, -MAST_W / 2, PL), (MAST_W / 2, MAST_W / 2, MAST_H), 0.0), B), I, 2)
    for k in range(3):       # three splayed balsa struts: a three-leg star from above
        a = math.radians(90 + 120 * k)
        stick(bm, (math.cos(a) * 0.058, math.sin(a) * 0.058, PL), (math.cos(a) * 0.006, math.sin(a) * 0.006, 0.1), 0.007, 2, B)
        put(bm, slab((-0.007, -0.007, PL), (0.007, 0.007, PL + 0.004), G, E), at(math.cos(a) * 0.056, math.sin(a) * 0.056, 0))  # foot pad
    put(bm, slab((-0.016, -0.016, 0.16), (0.016, 0.016, 0.166), C, E))      # a card collar halfway
    put(bm, slab((-0.014, -0.021, 0.095), (0.014, -0.007, 0.13), C, E))     # a junction box on the camera side
    put(bm, cyl(0.013, 0.013, MAST_H, MAST_H + 0.004, 16, G, G))            # pan bearing
    return finish_maquette("CctvBase", bm, SLOTS3)


def cctv_turret():
    bm = bmesh.new()
    cctv_head(bm)
    return finish_maquette("CctvTurret", bm, SLOTS3)


def cctv_rubble():
    rng = random.Random(21)
    bm = bmesh.new()
    plate(bm)
    stump = boxed((-MAST_W / 2, -MAST_W / 2, PL), (MAST_W / 2, MAST_W / 2, 0.04), 0.0)
    for v in stump.verts:
        if v.co.z > 0.03:
            v.co.z += rng.uniform(-0.01, 0.008)
    put(bm, recolour(stump, B), I, 2)
    # the mast toppled as one long stick across the cell (snapped at the stump), the head beside its top
    put(bm, recolour(splinter(0.13, MAST_W, rng), B), at(0.0, -0.035, PL) @ rot("Z", 8), 0)
    for (x, y), rz in (((-0.05, 0.045), 70), ((0.03, -0.06), 160)):  # two struts
        put(bm, recolour(splinter(0.05, 0.007, rng), B), at(x, y, PL) @ rot("Z", rz), 0)
    cctv_head(bm, at(0.008, 0.016, PL + 0.024) @ rot("Z", 95) @ rot("Y", 90))   # the head on its side
    return finish_maquette("CctvRubble", bm, SLOTS3)


# ---------------------------------------------------------------- fire safety sprinkler (1x1)
TANK_R, TANK_TOP, LID_TOP = 0.046, 0.058, 0.08
ARM_LEN, ARM_Z = 0.064, 0.008          # rotor arm reach (past the tank rim) and height (turret space)


def sprinkler_head(bm, Mx=I):
    """A steel hub, four pale steel arms reaching past the tank rim, each ending in a chunky nozzle block
    turned sideways (the spin direction), so from above it reads as a rotor, not a cross-hair."""
    head = bmesh.new()
    put(head, cyl(0.012, 0.012, 0.0, 0.014, 16, K, K))
    for k in range(4):
        arm = bmesh.new()
        stick(arm, (0, 0.006, ARM_Z), (0, ARM_LEN - 0.008, ARM_Z), 0.007, 1, K)
        put(arm, slab((-0.002, ARM_LEN - 0.014, ARM_Z - 0.006), (0.012, ARM_LEN, ARM_Z + 0.006), D, K))  # nozzle block
        put(head, arm, rot("Z", 90 * k))
    put(head, cyl(0.02, 0.02, 0.014, 0.018, 20, D, K))   # dark deflector cap, steel rim
    put(bm, head, Mx)


def sprinkler_muzzle():
    return Vector((0, ARM_LEN - 0.007, ARM_Z + 0.006))


def sprinkler_tank(bm, Mx=I):
    tank = bmesh.new()
    put(tank, cyl(TANK_R, TANK_R, PL, TANK_TOP, 24, C))
    tube_seam(tank, TANK_R, PL, TANK_TOP)
    for z in (PL + 0.012, TANK_TOP - 0.014):        # steel hoops
        put(tank, cyl(TANK_R + 0.0025, TANK_R + 0.0025, z, z + 0.004, 24, K, K))
    put(tank, cyl(TANK_R + 0.004, TANK_R + 0.004, TANK_TOP, TANK_TOP + 0.004, 24, K, K))   # pale steel lid rim
    put(tank, cyl(TANK_R - 0.002, 0.012, TANK_TOP + 0.004, LID_TOP, 24, D))                # shallow dark lid
    put(bm, tank, Mx)


def sprinkler_base():
    bm = bmesh.new()
    plate(bm)
    sprinkler_tank(bm)
    put(bm, cyl(0.007, 0.007, LID_TOP - 0.004, LID_TOP + 0.01, 12, G, G))      # riser
    for rz in (0, 90):   # two feed pipes along the plate from the tank to the plate's east and north edges
        pipe = bmesh.new()
        put(pipe, cyl(0.006, 0.006, TANK_R - 0.004, P1 - 0.002, 12, G, G), at(0, 0, PL + 0.007) @ rot("Y", 90))
        put(pipe, cyl(0.008, 0.008, P1 - 0.012, P1 - 0.006, 12, K, K), at(0, 0, PL + 0.007) @ rot("Y", 90))  # flange
        put(bm, pipe, rot("Z", rz))
    put(bm, cyl(0.011, 0.011, 0.0, 0.003, 12, K, K), at(0.056, 0.0, PL + 0.016))   # valve wheel on the east pipe
    return finish_maquette("SprinklerBase", bm, SLOTS3)


SPRINKLER_TURRET_Z = LID_TOP + 0.01


def sprinkler_turret():
    bm = bmesh.new()
    sprinkler_head(bm)
    return finish_maquette("SprinklerTurret", bm, SLOTS3)


def sprinkler_rubble():
    rng = random.Random(23)
    bm = bmesh.new()
    plate(bm)
    # the tank split open into flat card sheets, its steel hoops lying loose, the dark lid flat on the plate
    for (x, y), rad, rz in (((-0.025, 0.022), 0.034, 10), ((0.026, 0.03), 0.026, -40), ((-0.02, -0.035), 0.024, 70)):
        put(bm, scrap(rad, 0.006, 0.003, rng, C, E, 9), at(x, y, PL) @ rot("Z", rz))
    for (x, y), tilt in (((0.0, 0.005), 6), ((0.03, -0.022), -8)):
        ring = bmesh.new()
        lathe(ring, [(TANK_R - 0.012, 0), (TANK_R - 0.009, 0), (TANK_R - 0.009, 0.003), (TANK_R - 0.012, 0.003)], 24)
        bmesh.ops.transform(ring, matrix=UP, verts=ring.verts)
        put(bm, recolour(ring, K), at(x, y, PL + 0.004) @ rot("X", tilt))
    put(bm, cyl(TANK_R * 0.75, 0.01, 0, 0.007, 20, D, D), at(0.04, -0.04, PL + 0.002) @ rot("X", 8))   # lid
    for (x, y), length, rz in (((0.045, 0.03), 0.05, 70), ((-0.045, -0.04), 0.04, -20)):         # pipe pieces
        pipe = cyl(0.006, 0.006, -length / 2, length / 2, 10, G, G)
        put(bm, pipe, at(x, y, PL + 0.006) @ rot("Z", rz) @ rot("Y", 90))
    for (x, y), rz in (((-0.05, 0.0), 30), ((0.045, 0.05), 110)):   # two rotor arms broken off
        put(bm, recolour(splinter(0.04, 0.007, rng), K), at(x, y, PL) @ rot("Z", rz), 0)
    put(bm, cyl(0.012, 0.012, 0, 0.014, 16, K, K), at(-0.04, -0.05, PL + 0.012) @ rot("Y", 90))   # the hub
    return finish_maquette("SprinklerRubble", bm, SLOTS3)


# ---------------------------------------------------------------- document shredder (1x1)
SH_TOP = 0.05                          # plinth top: the turret's pivot
SHB = (0.042, -0.036, 0.032, 0.006, 0.046)  # head half width, back, front (Blender y), bottom, top (turret space)
SLOT = (0.008, 0.024)                  # the feed slot in the top (Blender y from, to): the cutters show in it
DRUM_R = 0.011
BIN = (0.05, -0.05, 0.05, 0.024)       # strip bin centre x, y (south-east, toward the camera), outer size, height


def shredder_drum(bm, Mx=I):
    """The cutter drum along X: a steel core and toothed discs (octagons, each turned a little)."""
    hw = SHB[0] - 0.008
    drum = bmesh.new()
    put(drum, cyl(DRUM_R * 0.6, DRUM_R * 0.6, -hw, hw, 12, K, K), rot("Y", 90))
    for k in range(9):
        x = -hw + 0.003 + k * (2 * hw - 0.006) / 8
        put(drum, cyl(DRUM_R, DRUM_R, x - 0.0016, x + 0.0016, 8, K, K), rot("Y", 90) @ rot("Z", k * 22.5))
    put(bm, drum, Mx)


def shredder_head(bm, Mx=I):
    """A dark-board head on a steel swivel, overhanging its plinth. From above: a dark block with a feed
    slot framed in pale steel, the steel cutter teeth showing in it, and a pale grey-board feed tray with
    an ink hazard line leaning out toward the target (Blender +Y)."""
    hw, yb, yf, zb, zt = SHB
    s0, s1 = SLOT
    head = bmesh.new()
    put(head, cyl(0.024, 0.024, 0.0, zb, 20, K, K))
    put(head, slab((-hw, yb, zb), (hw, yf, zt - 0.014), D, K))                 # lower block
    for y0, y1 in ((yb, s0), (s1, yf)):                                         # top layer round the slot
        put(head, slab((-hw, y0, zt - 0.014), (hw, y1, zt), D, K))
    for sx in (-1, 1):
        put(head, slab((-0.006, s0, zt - 0.014), (0.0, s1, zt), D, K), at(sx * hw + (0.006 if sx < 0 else 0.0), 0, 0))
    for y0, y1 in ((s0 - 0.0035, s0), (s1, s1 + 0.0035)):                       # pale steel slot lips
        put(head, slab((-hw + 0.004, y0, zt), (hw - 0.004, y1, zt + 0.0015), K, K))
    shredder_drum(head, at(0, (s0 + s1) / 2, zt - DRUM_R - 0.0015))
    tray = slab((-hw + 0.004, 0.0, 0.0), (hw - 0.004, 0.022, 0.003), G, E)     # feed tray
    put(head, tray, at(0, yf, zt - 0.006) @ rot("X", -22))
    put(head, slab((-hw + 0.006, 0.012, 0.003), (hw - 0.006, 0.016, 0.0035), N, N), at(0, yf, zt - 0.006) @ rot("X", -22))
    put(bm, head, Mx)


def shredder_muzzle():
    return Vector((0, SLOT[1], SHB[4]))


def strip_bin(bm, Mx=I):
    x, y, w, h = BIN
    part = bmesh.new()
    t = 0.003
    put(part, slab((-w / 2, -w / 2, 0), (w / 2, w / 2, t), C, E))
    put(part, slab((-w / 2, -w / 2, 0), (w / 2, -w / 2 + t, h), C, E))
    put(part, slab((-w / 2, w / 2 - t, 0), (w / 2, w / 2, h), C, E))
    put(part, slab((-w / 2, -w / 2 + t, 0), (-w / 2 + t, w / 2 - t, h), C, E))
    put(part, slab((w / 2 - t, -w / 2 + t, 0), (w / 2, w / 2 - t, h), C, E))
    put(bm, part, Mx)


def shredder_base():
    bm = bmesh.new()
    plate(bm)
    put(bm, slab((-0.03, -0.03, PL), (0.03, 0.03, SH_TOP - 0.004), C, E))     # card plinth
    put(bm, slab((-0.034, -0.034, SH_TOP - 0.004), (0.034, 0.034, SH_TOP), G, E))   # grey-board cap
    strip_bin(bm, at(BIN[0], BIN[1], PL))
    return finish_maquette("ShredderBase", bm, SLOTS3)


def shredder_turret():
    bm = bmesh.new()
    shredder_head(bm)
    return finish_maquette("ShredderTurret", bm, SLOTS3)


def shredder_rubble():
    """Down to a third of its height: the plinth folded flat, the head crushed flat, the drum rolled off."""
    rng = random.Random(25)
    bm = bmesh.new()
    plate(bm)
    for (x, y), rad, rz in (((-0.03, 0.03), 0.03, 15), ((0.02, 0.04), 0.022, -50)):   # plinth card folded flat
        put(bm, scrap(rad, 0.008, 0.003, rng, C, E, 8), at(x, y, PL) @ rot("Z", rz))
    hw, yb, yf, zb, zt = SHB
    crushed = slab((-hw, yb, 0), (hw, yf, 0.01), D, K)                         # the head, crushed flat
    for v in crushed.verts:
        v.co.z += rng.uniform(-0.002, 0.003) if v.co.z > 0.005 else 0.0
    put(bm, crushed, at(-0.008, -0.002, PL + 0.004) @ rot("Z", -25) @ rot("X", 5))
    put(bm, slab((-hw + 0.004, 0, 0), (hw - 0.004, 0.0035, 0.0015), K, K), at(-0.004, 0.002, PL + 0.016) @ rot("Z", -25))
    shredder_drum(bm, at(0.03, -0.045, PL + DRUM_R) @ rot("Z", 30))           # the drum rolled off
    put(bm, scrap(0.026, 0.006, 0.003, rng, C, E, 8), at(-0.045, -0.045, PL) @ rot("Z", 40))   # the bin trampled
    return finish_maquette("ShredderRubble", bm, SLOTS3)


# ---------------------------------------------------------------- liability silo (2x2)
SR, S0, S1 = 0.092, 0.016, 0.15       # silo radius, foot, eaves
BAND = (0.118, 0.13, 32)               # hazard ticks: z from, to, segments (every second one ink)
ROOF_TOP = 0.178
SILO_TURRET_Z = ROOF_TOP + 0.006
SBARREL = (0.011, -0.004, 0.05, 0.018, 28.0)   # radius, from, to (Blender +Y), axis height, elevation deg


def hazard_band(bm, r, z0, z1, n, sides=32, top=False):
    """A ring of alternating ink / card segments on its sides (top=False) or on its top face (top=True,
    what the map camera sees); the other faces are cut edges."""
    band = cyl(r, r, z0, z1, sides, C, C)
    for f in band.faces:
        cap = abs(f.normal.z) > 0.5   # (cyl's cap normals point inward until finish: test the cap's height)
        if not ((cap and f.calc_center_median().z > (z0 + z1) / 2) if top else not cap):
            f.material_index = E
            continue
        a = math.atan2(f.calc_center_median().y, f.calc_center_median().x) % math.tau
        f.material_index = N if int(a / math.tau * n) % 2 == 0 else C
    put(bm, band)


def silo_barrel_matrix():
    r, y0, y1, z, el = SBARREL
    return at(0, 0, z) @ rot("X", el) @ rot("X", -90)


def silo_head(bm, Mx=I):
    """A squat grey-board drum with a card hood and a short dark lobbing barrel."""
    head = bmesh.new()
    put(head, cyl(0.034, 0.034, 0.0, 0.026, 20, G, E))
    put(head, slab((-0.024, -0.028, 0.026), (0.024, 0.016, 0.032), S, E))
    r, y0, y1, z, el = SBARREL
    put(head, cyl(r, r, y0, y1, 14, D, D), silo_barrel_matrix())
    put(head, cyl(r + 0.0025, r + 0.0025, y1 - 0.006, y1, 14, E, D), silo_barrel_matrix())
    put(bm, head, Mx)


def silo_muzzle():
    r, y0, y1, z, el = SBARREL
    return silo_barrel_matrix() @ Vector((0, 0, y1))


def silo_base():
    bm = bmesh.new()
    put(bm, slab((-HALF, -HALF, 0), (HALF, HALF, PL), G, G))
    put(bm, cyl(SR + 0.012, SR + 0.012, PL, S0, 32, G, G))                  # concrete footing ring
    put(bm, cyl(SR, SR, S0, S1, 32, C))
    tube_seam(bm, SR, S0, S1)
    hazard_band(bm, SR + 0.0025, BAND[0], BAND[1], BAND[2])
    put(bm, cyl(SR + 0.0025, SR + 0.0025, BAND[1] + 0.003, BAND[1] + 0.007, 32, N, N))   # an ink stripe over the ticks
    hazard_band(bm, SR + 0.012, S1, S1 + 0.004, 24, 48, True)   # eaves rim printed with hazard wedges: read from above
    put(bm, cyl(SR - 0.003, 0.036, S1 + 0.004, ROOF_TOP, 32, S))
    put(bm, cyl(0.03, 0.03, ROOF_TOP - 0.002, SILO_TURRET_Z, 20, G, G))      # turret ring
    x = SR + 0.006                                                           # a balsa ladder on the east side
    for sy in (-1, 1):
        stick(bm, (x, sy * 0.009, S0), (x, sy * 0.009, S1 + 0.012), 0.004, 2, B)
    for k in range(7):
        z = S0 + 0.012 + k * 0.019
        stick(bm, (x, -0.009, z), (x, 0.009, z), 0.003, 1, B)
    return finish_maquette("SiloBase", bm, SLOTS3)


def silo_turret():
    bm = bmesh.new()
    silo_head(bm)
    return finish_maquette("SiloTurret", bm, SLOTS3)


def ragged_tube(r, z0, heights, a0, a1, thick):
    """An open-topped piece of rolled card tube from angle a0 to a1 (degrees), its torn top at
    heights[i] above z0 per step: card skin outside and in, core on the torn rim and the ends."""
    part = bmesh.new()
    n = len(heights) - 1
    rows = []
    for i, h in enumerate(heights):
        a = math.radians(a0 + (a1 - a0) * i / n)
        c, s = math.cos(a), math.sin(a)
        rows.append([part.verts.new((c * rr, s * rr, z)) for rr, z in ((r, z0), (r, z0 + h), (r - thick, z0 + h), (r - thick, z0))])
    for i in range(n):
        p, q = rows[i], rows[i + 1]
        for k, mat in ((0, C), (1, E), (2, C), (3, E)):   # outside, torn rim, inside, bottom
            part.faces.new((p[k], q[k], q[(k + 1) % 4], p[(k + 1) % 4])).material_index = mat
    part.faces.new(rows[0]).material_index = E
    part.faces.new(list(reversed(rows[-1]))).material_index = E
    bmesh.ops.recalc_face_normals(part, faces=part.faces)
    return part


def hazard_arc(r0, r1, deg, n, thick):
    """A broken length of the eaves rim lying flat: an annulus piece centred on +X, its top printed
    with alternating ink / card wedges like the standing silo's rim, cut edges round it."""
    part = bmesh.new()
    for k in range(n):
        a, b = [math.radians(-deg / 2 + deg * (k + j) / n) for j in (0, 1)]
        vs = [part.verts.new((math.cos(t) * rr, math.sin(t) * rr, z))
              for z in (0.0, thick) for t, rr in ((a, r0), (a, r1), (b, r1), (b, r0))]
        bot, top = vs[:4], vs[4:]
        part.faces.new(top).material_index = N if k % 2 == 0 else C
        part.faces.new(list(reversed(bot))).material_index = E
        for i in range(4):
            part.faces.new((bot[i], bot[(i + 1) % 4], top[(i + 1) % 4], top[i])).material_index = E
    bmesh.ops.recalc_face_normals(part, faces=part.faces)
    return part


def roof_piece(deg, rng, n):
    """A broken wedge of the shallow roof, flat card (shade) with its printed eaves rim along the arc."""
    r = SR * 0.86
    poly = [(rng.uniform(0.004, 0.012), rng.uniform(-0.004, 0.004))]
    poly += [(math.cos(t) * r, math.sin(t) * r) for t in [math.radians(-deg / 2 + deg * k / n) for k in range(n + 1)]]
    side = len(poly)
    poly.insert(side, (r * 0.5 * math.cos(math.radians(deg / 2)) + rng.uniform(-0.006, 0.006),
                       r * 0.5 * math.sin(math.radians(deg / 2)) + rng.uniform(0.0, 0.008)))   # torn sides
    poly.insert(1, (r * 0.5 * math.cos(math.radians(deg / 2)) + rng.uniform(-0.006, 0.006),
                    -r * 0.5 * math.sin(math.radians(deg / 2)) - rng.uniform(0.0, 0.008)))
    part = card_sheet(poly, 0.004, S, E)
    put(part, hazard_arc(r - 0.011, r + 0.001, deg, max(3, n), 0.0045), at(0, 0, 0.0))
    return part


def silo_rubble():
    """Read from above as a burst silo, not a ring: the tube split open on its south-east side, a ragged
    horseshoe of wall still standing, three big sheets of it peeled out flat through the gap, the roof
    broken into wedges (their hazard rim with them), one fallen inside, one over the wall, a loose
    length of rim and the head on its side (a fallen ladder was too fussy at 720p). Nothing repeats round the circle (a ring
    of even petals read as a saw blade)."""
    rng = random.Random(27)
    bm = bmesh.new()
    put(bm, slab((-HALF, -HALF, 0), (HALF, HALF, PL), G, G))
    put(bm, cyl(SR + 0.012, SR + 0.012, PL, S0, 32, G, G))
    gap = -40.0                                                              # the burst faces south-east
    a0, a1 = gap + 70, gap + 360 - 70
    steps = 18
    heights = []
    for i in range(steps + 1):                                                # tallest at the back, torn low at the gap
        u = i / steps
        heights.append(0.008 + 0.042 * math.sin(math.pi * u) ** 0.8 + rng.uniform(-0.007, 0.007))
    put(bm, ragged_tube(SR, S0, heights, a0, a1, 0.006))
    # three wall sheets peeled out flat through the gap, each a different size and angle
    for a, w, length, lift, ink in ((gap - 52, 0.085, 0.058, 7, None), (gap - 4, 0.1, 0.07, 4, (0.046, 0.057)),
                                    (gap + 44, 0.075, 0.056, 11, (0.04, 0.05))):
        poly = [(-w / 2, 0.0), (w / 2, 0.0)] + [(w / 2 - w * k / 4 + rng.uniform(-0.006, 0.006),
                                                  length * rng.uniform(0.75, 1.05)) for k in range(5)]
        sheet = card_sheet(poly, 0.004, C, E)
        if ink:   # a strip of the printed hazard band, torn with the sheet
            put(sheet, slab((-w * 0.42, ink[0], 0.004), (w * 0.3, ink[1], 0.0046), N, N))
        put(bm, sheet, at(math.cos(math.radians(a)) * (SR - 0.004), math.sin(math.radians(a)) * (SR - 0.004), S0 + 0.001)
            @ rot("Z", a - 90) @ rot("X", lift))
    # the roof broken in wedges: one fallen in, its rim propped on the wall; one slid off north-west
    put(bm, roof_piece(110, rng, 6), at(0.035, -0.012, S0 + 0.003) @ rot("Z", 172) @ rot("Y", -7))
    put(bm, roof_piece(70, rng, 4), at(-0.064, 0.064, S0 + 0.002) @ rot("Z", 135) @ rot("Y", 6))
    # a loose length of rim on the plate, north-east
    put(bm, hazard_arc(SR, SR + 0.012, 46, 4, 0.004), at(0.1, 0.11, PL) @ rot("Z", -20) @ at(-SR - 0.006, 0, 0))
    # the head on its side in the south-west corner
    silo_head(bm, at(-0.1, -0.1, PL + 0.018) @ rot("Z", 200) @ rot("Y", 80))
    return finish_maquette("SiloRubble", bm, SLOTS3)


objs = [cctv_base(), cctv_turret(), cctv_rubble(), sprinkler_base(), sprinkler_turret(), sprinkler_rubble(),
        shredder_base(), shredder_turret(), shredder_rubble(), silo_base(), silo_turret(), silo_rubble()]
print("GODOT cctv Turret y %.4f Muzzle %s" % (MAST_H + 0.004, godot(cctv_muzzle())))
print("GODOT sprinkler Turret y %.4f Muzzle %s" % (SPRINKLER_TURRET_Z, godot(sprinkler_muzzle())))
print("GODOT shredder Turret y %.4f Muzzle %s" % (SH_TOP, godot(shredder_muzzle())))
print("GODOT silo Turret y %.4f Muzzle %s Burst (0, %.4f, 0)" % (SILO_TURRET_Z, godot(silo_muzzle()), (S0 + S1) / 2))
for ob in objs:
    tris = sum(len(p.vertices) - 2 for p in ob.data.polygons)
    used = sorted({p.material_index for p in ob.data.polygons})
    print("TRIS_OF", ob.name, tris, "slots used", used, "dims", tuple(round(d, 3) for d in ob.dimensions))
ASSET = "maquette3"
GLB = os.environ.get("GLB")
if GLB:
    bpy.ops.object.select_all(action="DESELECT")
    for ob in objs:
        ob.select_set(True)
    bpy.ops.export_scene.gltf(filepath=GLB, use_selection=True, export_apply=True, export_tangents=True,
                              export_materials="EXPORT")
else:  # mockup: standing row in front, wrecks behind, turrets on their bases
    tz = {"CctvTurret": MAST_H + 0.004, "SprinklerTurret": SPRINKLER_TURRET_Z, "ShredderTurret": SH_TOP, "SiloTurret": SILO_TURRET_Z}
    xs = (-0.42, -0.2, 0.0, 0.3)
    for k in range(4):
        base, turret, rubble = objs[3 * k: 3 * k + 3]
        base.location = (xs[k], 0, 0)
        turret.location = (xs[k], 0, tz[turret.name])
        rubble.location = (xs[k], 0.4, 0)
FRAME = ((0.0, -1.0, 0.75), (-0.05, 0.15, 0.08), 50, 1600, 900)
