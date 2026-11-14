# Cog switch (entities/components/light_switch.tscn, class LightSwitch): a chunky machined steel cog
# on a short post, tilted 45 degrees toward the camera, on a small sage enamel base plate. Prepend
# blender_lib.py + desk_vc_common.py. Two objects, exported with GLB=<path> + glb_to_res.gd
# (prefix cog_switch):
#   Mount  static, in the switch's frame (Godot: plate in XY facing +Z, like the old switch plate):
#          bevelled base plate with four chrome screws, a cast foot and a dark steel post running
#          back-down from the hub, and a fixed collar behind the cog.
#   Cog    origin at the hub, axis along Godot +Z (the scene's Pivot tilts it): 8 big teeth, a
#          recessed web, a knurled hub ring round a hole where the scene's amber Lamp sits.
# Godot (x, y, z) = Blender (x, -z, y), via G().
ASSET = "cog_switch"
GM, D = 7, 8                                         # gunmetal cog, dark post steel
COLOURS[GM] = (1, 1, 1); SURFACE[GM] = 2         # ramp_steel: cold machined steel
COLOURS[D] = (0.2, 0.21, 0.22); SURFACE[D] = 1

TEETH = 8
R_ROOT, R_TIP, HALF = 0.0135, 0.0195, 0.0035         # tooth root / tip radius, half thickness
C = (0.0, -0.002, 0.0215)                            # hub centre in the switch frame (scene Pivot)
S45 = math.sqrt(0.5)
AXIS = (0.0, -S45, S45)                              # leans toward the camera (-Y) and up


def G(x, y, z):
    return Vector((x, -z, y))


def hull(bm, pts, mat, bevel=0.0007):
    t = bmesh.new()
    for p in pts:
        t.verts.new(G(*p))
    bmesh.ops.convex_hull(t, input=t.verts)
    bmesh.ops.dissolve_limit(t, angle_limit=0.02, verts=t.verts, edges=t.edges)
    bmesh.ops.bevel(t, geom=list(t.edges), offset=bevel, segments=2, affect="EDGES", profile=0.5)
    merge(bm, t, I, mat)


def gbox(bm, lo, hi, bevel, mat):
    part_box(bm, (lo[0], -hi[2], lo[1]), (hi[0], -lo[2], hi[1]), bevel, mat)


def grod(bm, a, b, r, mat, sides=16):
    rod(bm, G(*a), G(*b), r, mat, I, sides)


def along(p, d):
    return tuple(p[i] + AXIS[i] * d for i in range(3))


# --- Cog (about its own hub, axis Godot +Z) ------------------------------------------------------
cog = bmesh.new()
# Lathed body: rim, a recessed web, a raised hub with a lamp hole. lathe() turns about Blender Y
# (= Godot -Z), so each (r, z) goes in as (r, -z). Closed profile, axis to axis.
prof = [(0.0035, -0.0045), (0.0085, -0.0045), (0.0085, -0.002), (0.0115, -0.002), (0.0115, -HALF),
        (R_ROOT + 0.0005, -HALF), (R_ROOT + 0.0005, HALF), (0.0115, HALF), (0.0115, 0.002),
        (0.0085, 0.002), (0.0085, 0.0055), (0.0052, 0.0055), (0.0052, 0.002), (0.0035, 0.002)]
merge(cog, lathed([(r, -z) for r, z in prof] + [(0.0035, 0.0045)], 40), I, GM)
for k in range(TEETH):                                        # chunky trapezoid teeth
    a = k * math.tau / TEETH
    c, s = math.cos(a), math.sin(a)
    pts = []
    for r, w in ((R_ROOT, 0.0036), (R_TIP, 0.0022)):
        for side in (-1, 1):
            for z in (-HALF, HALF):
                pts.append((c * r - s * w * side, s * r + c * w * side, z))
    hull(cog, pts, GM, 0.0008)
for k in range(12):                                           # knurl ridges round the hub
    a = k * math.tau / 12
    c, s = math.cos(a), math.sin(a)
    pts = []
    for r in (0.0082, 0.0094):
        for side in (-1, 1):
            for z in (0.0022, 0.0052):
                pts.append((c * r - s * 0.0007 * side, s * r + c * 0.0007 * side, z))
    hull(cog, pts, GM, 0.0002)

# --- Mount (switch frame) -------------------------------------------------------------------------
mount = bmesh.new()
gbox(mount, (-0.02, -0.025, -0.003), (0.02, 0.025, 0.003), 0.0016, E)        # base plate
for x in (-0.0155, 0.0155):
    for y in (-0.0205, 0.0205):
        grod(mount, (x, y, 0.002), (x, y, 0.0042), 0.0021, H, 10)            # screw heads
foot_y = C[1] + C[2]                                                          # where the post meets the plate
hull(mount, [(x, foot_y + dy, z) for x in (-0.007, 0.007) for dy in (-0.0075, 0.0065) for z in (0.002, 0.0065)]
     + [(x, foot_y + 0.004, 0.011) for x in (-0.0045, 0.0045)], E, 0.0012)   # cast foot
grod(mount, along(C, -0.0042), (0, foot_y, 0.004), 0.0038, D, 16)            # post
grod(mount, along(C, -0.0078), along(C, -0.0044), 0.0058, H, 20)            # fixed collar

objs = []
steel = material("ramp_steel", (1, 1, 1), 1.0, 0.4); textured(steel, "ramp_steel", 2.0, (0.6, 0.64, 0.68))
for name, bm, origin in (("Cog", cog, (0, 0, 0)), ("Mount", mount, (0, 0, 0))):
    ob = finish(name, bm, [paint, metal, steel], origin)
    colourise(ob)
    objs.append(ob)

GLB = os.environ.get("GLB")
if GLB:
    bpy.ops.object.select_all(action="DESELECT")
    for ob in objs:
        ob.select_set(True)
    bpy.ops.export_scene.gltf(filepath=GLB, use_selection=True, export_apply=True, export_tangents=True,
                              export_vertex_color="ACTIVE", export_materials="EXPORT")

# Preview: place the cog on its tilted pivot over the plate (Godot rot.x 45 deg = Blender rot.x 45).
cogo = bpy.data.objects["Cog"]
cogo.location = G(*C)
cogo.rotation_euler = (math.radians(45), 0, 0)
for ob in objs:
    ob.scale = (25, 25, 25); ob.location = ob.location * 25
FRAME = ((0, -1.2, 2.0), (0, 0, 0.35), 50, 900, 900)
