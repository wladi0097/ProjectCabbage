# Chute lever: a guillotine supply-interruption gate across the supply chute. Prepend
# blender_lib.py + desk_vc_common.py. Three objects, each with its origin at its pivot, so Godot
# turns plain Node3Ds (Arm, Flap) as before:
#   Frame  static: two cast uprights clamped by saddles onto the chute walls' rolled rims (measured,
#          so nothing pokes through the walls), a matte steel axle and front hub.
#          (A quadrant plate behind the arm was dropped: invisible from the game camera.)
#   Flap   pivot on the axle, hangs down: a sheet steel plate (ramp_steel), rolled hinge knuckles
#          with straps and a heavy bottom rib, all steel, a pale stencil band on the -x face for SUPPLY SUSPENDED.
#   Arm    pivot on the axle's front end, points up: a tapered enamel bar, a hub boss, a counterweight
#          tail and a ribbed black rubber T-grip toward the camera, short enough to clear the stock
#          counter below when pulled.
# Built in Godot's local frame of chute_lever.tscn (x up the chute, y up, z across, front +z) via
# G(): Godot (x, y, z) = Blender (x, -z, y).
ASSET = "chute_lever"
W, S, D = 7, 8, 9                            # pale stencil band, sheet steel (own surface), matte axle steel
COLOURS[D] = (0.3, 0.31, 0.32); SURFACE[D] = 1
COLOURS[W] = (0.4, 0.42, 0.39); SURFACE[W] = 0
COLOURS[S] = (1, 1, 1); SURFACE[S] = 2
AXLE_Y = 0.34
ARM_Z = 0.34
OPEN, PULLED, FLAP_OPEN = 0.95, 1.55, -1.75    # chute_lever.gd


def G(x, y, z):
    return Vector((x, -z, y))


def gbox(bm, lo, hi, bevel, mat):
    part_box(bm, (lo[0], -hi[2], lo[1]), (hi[0], -lo[2], hi[1]), bevel, mat)


def grod(bm, a, b, r, mat, sides=16):
    rod(bm, G(*a), G(*b), r, mat, I, sides)


def prism(bm, pts, z0, z1, mat, bevel=0.004):
    """A bevelled prism from a convex outline in Godot's xy plane, between Godot z0 and z1."""
    t = bmesh.new()
    for x, y in pts:
        t.verts.new(G(x, y, z0)); t.verts.new(G(x, y, z1))
    bmesh.ops.convex_hull(t, input=t.verts)
    bmesh.ops.dissolve_limit(t, angle_limit=0.02, verts=t.verts, edges=t.edges)
    bmesh.ops.bevel(t, geom=list(t.edges), offset=bevel, segments=2, affect="EDGES", profile=0.5)
    merge(bm, t, I, mat)


def hull3(bm, pts, mat, bevel=0.003):
    t = bmesh.new()
    for p in pts:
        t.verts.new(G(*p))
    bmesh.ops.convex_hull(t, input=t.verts)
    bmesh.ops.dissolve_limit(t, angle_limit=0.02, verts=t.verts, edges=t.edges)
    bmesh.ops.bevel(t, geom=list(t.edges), offset=bevel, segments=2, affect="EDGES", profile=0.5)
    merge(bm, t, I, mat)


def arc(r, a0, a1, n, cx=0.0, cy=AXLE_Y):
    return [(cx + r * math.cos(a0 + (a1 - a0) * i / n), cy + r * math.sin(a0 + (a1 - a0) * i / n)) for i in range(n + 1)]


steel = material("ramp_steel", (1, 1, 1), 1.0, 0.4); textured(steel, "ramp_steel", 2.0, (0.6, 0.64, 0.68))

# --- Frame ---------------------------------------------------------------------------------------
frame = bmesh.new()
# The chute walls end in a rolled bead, measured in this frame (rays against supply_ramp in Godot):
# top at RIM0 + RIM_K * x, 15 mm wide, centred at ZC0 - ZC_K * x (the chute tapers up its length).
RIM0, RIM_K, ZC0, ZC_K = 0.117, 0.448, 0.2335, 0.078
def rim(x):
    return RIM0 + RIM_K * x
def zc(x):
    return ZC0 - ZC_K * x
SX = 0.075                                                                                 # saddle half length
for side in (-1, 1):
    # Saddle clamp over the bead: a cap 2 mm above it and a cheek down each face, 3 mm clear.
    for z_in, z_out, y_lo in ((-0.0185, 0.0185, 0.002), (-0.0185, -0.0105, -0.03), (0.0105, 0.0185, -0.03)):
        pts = []
        for x in (-SX, SX):
            for dz in (z_in, z_out):
                z = side * (zc(x) + dz)
                pts += [(x, rim(x) + y_lo, z), (x, rim(x) + 0.016, z)]
        hull3(frame, pts, E, 0.003)
    for x in (-0.048, 0.048):                                                              # clamp bolts, outer cheek
        z = side * (zc(x) + 0.0185)
        grod(frame, (x, rim(x) - 0.014, z), (x, rim(x) - 0.014, z + side * 0.007), 0.009, H, 8)
    # The cast upright from the cap to the axle, on the bead's centre line at the axle.
    z0 = side * ZC0
    prism(frame, [(-0.068, rim(-0.068) + 0.012), (0.068, rim(0.068) + 0.012), (0.045, AXLE_Y), (-0.045, AXLE_Y)],
          z0 - 0.014, z0 + 0.014, E, 0.005)
    grod(frame, (0, AXLE_Y, z0 - 0.022), (0, AXLE_Y, z0 + 0.022), 0.056, E, 24)           # cast boss round the axle
    for x, y in ((-0.03, rim(-0.03) + 0.05), (0.03, rim(0.03) + 0.05)):                   # rivets, outer face
        grod(frame, (x, y, z0 + side * 0.013), (x, y, z0 + side * 0.021), 0.01, H, 10)
grod(frame, (0, AXLE_Y, -ZC0 - 0.04), (0, AXLE_Y, 0.37), 0.026, D, 20)                     # axle
grod(frame, (0, AXLE_Y, -ZC0 - 0.046), (0, AXLE_Y, -ZC0 - 0.026), 0.04, D, 6)               # hex nut, back end
grod(frame, (0, AXLE_Y, ZC0 + 0.024), (0, AXLE_Y, 0.308), 0.05, D, 24)                     # front hub collar

# --- Flap (pivot on the axle; built hanging straight down) ---------------------------------------
flap = bmesh.new()
gbox(flap, (-0.016, -0.31, -0.215), (0.016, -0.03, 0.215), 0.006, S)                    # steel plate
gbox(flap, (-0.022, -0.324, -0.222), (0.022, -0.284, 0.222), 0.007, S)                     # heavy bottom rib, 3 mm over the sloped floor
for z0, z1 in ((-0.205, -0.1), (-0.04, 0.04), (0.1, 0.205)):                               # hinge knuckles + straps
    grod(flap, (0, 0, z0), (0, 0, z1), 0.04, S, 18)
    gbox(flap, (-0.024, -0.13, z0 + 0.008), (0.024, -0.02, z1 - 0.008), 0.005, S)
band = bmesh.new()                                                                         # stencil band, -x face: its own
gbox(band, (-0.021, -0.232, -0.2), (-0.012, -0.148, 0.2), 0.002, W)                       # object, shown only while shut

# --- Arm (pivot at the hub; built pointing straight up) ------------------------------------------
lever = bmesh.new()
prism(lever, [(-0.036, -0.02), (0.036, -0.02), (0.024, 0.235), (-0.024, 0.235)], -0.019, 0.019, E, 0.006)
grod(lever, (0, 0, -0.03), (0, 0, 0.03), 0.048, E, 20)                                     # hub boss
grod(lever, (0, 0, 0.03), (0, 0, 0.04), 0.03, E, 6)                                        # hex nut
gbox(lever, (-0.045, -0.12, -0.028), (0.045, -0.035, 0.028), 0.01, E)                     # counterweight tail
grod(lever, (0, 0.222, -0.02), (0, 0.222, 0.08), 0.03, K, 18)                             # rubber T-grip
for z in (0.01, 0.035, 0.06):
    grod(lever, (0, 0.222, z), (0, 0.222, z + 0.01), 0.034, K, 18)                         # grip ribs
grod(lever, (0, 0.222, 0.078), (0, 0.222, 0.094), 0.035, K, 18)                              # end knob

objs = []
for name, bm, pivot in (("Frame", frame, (0, 0, 0)), ("Flap", flap, (0, AXLE_Y, 0)), ("Band", band, (0, AXLE_Y, 0)), ("Arm", lever, (0, AXLE_Y, ARM_Z))):
    bmesh.ops.translate(bm, verts=bm.verts, vec=G(*pivot))      # parts are built about their pivot
    ob = finish(name, bm, [paint, metal, steel], G(*pivot))
    colourise(ob)
    objs.append(ob)

# Preview states: Blender rotates these about its -Y, which is Godot +z.
def pose(arm_a, flap_a):
    bpy.data.objects["Arm"].rotation_euler = (0, -arm_a, 0)
    bpy.data.objects["Flap"].rotation_euler = (0, -flap_a, 0)
    bpy.data.objects["Band"].rotation_euler = (0, -flap_a, 0)


pose(PULLED, 0.0) if os.environ.get('SHUT') else pose(OPEN, FLAP_OPEN)
FRAME = ((-0.75, -1.15, 1.05), (0.0, -0.05, 0.22), 45, 1280, 960)
GLB = os.environ.get("GLB")
if GLB:
    bpy.ops.object.select_all(action="DESELECT")
    for ob in objs:
        ob.select_set(True)
    for ob in objs:
        ob.rotation_euler = (0, 0, 0)
    bpy.ops.export_scene.gltf(filepath=GLB, use_selection=True, export_apply=True, export_tangents=True,
                              export_vertex_color="ACTIVE", export_materials="EXPORT")
    pose(OPEN, FLAP_OPEN)
