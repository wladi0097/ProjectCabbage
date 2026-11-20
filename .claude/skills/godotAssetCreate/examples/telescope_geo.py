# Telescope (desk card TELESCOPE, chapter 4): the room end of a survey telescope clamped under the
# raised sash's meeting rail, its barrel running out through the open gap toward the street. Prepend
# blender_lib.py + desk_vc_common.py. Two objects, both in Godot frames via G() (Godot (x, y, z) =
# Blender (x, -z, y)):
#   Mount  static, origin on the rail's underside: a C-clamp round the rail, a screw knob on the
#          room side, a stem down to a cradle ring round the barrel.
#   Tube   origin on the barrel's axis at the cradle, axis along -z (out of the window); the scene
#          tilts it up (telescope.tscn) and slides it along its axis when it arrives. Pale grey-sage
#          enamel barrel, gunmetal ring bands, focuser with chunky knobs, a finder scope on top and a
#          diagonal eyepiece aimed back at the game camera, its lens a separate object (Lens).
ASSET = "telescope"
D = 7
COLOURS[D] = (0.26, 0.27, 0.28); SURFACE[D] = 1       # gunmetal (machine_metal)
COLOURS[P] = (0.34, 0.38, 0.35)                        # barrel enamel, a touch paler than P
AY = -0.085                                            # barrel axis under the rail's underside
R = 0.05                                               # barrel radius


def G(x, y, z):
    return Vector((x, -z, y))


def gbox(bm, lo, hi, bevel, mat):
    part_box(bm, (lo[0], -hi[2], lo[1]), (hi[0], -lo[2], hi[1]), bevel, mat)


def grod(bm, a, b, r, mat, sides=24):
    rod(bm, G(*a), G(*b), r, mat, I, sides)


# --- Mount ------------------------------------------------------------------------------------------
mount = bmesh.new()
gbox(mount, (-0.05, 0.0, -0.035), (0.05, 0.075, -0.024), 0.004, D)    # jaw behind the rail
gbox(mount, (-0.05, 0.0, 0.024), (0.05, 0.075, 0.036), 0.004, D)      # jaw in front (room side)
gbox(mount, (-0.05, 0.06, -0.035), (0.05, 0.074, 0.036), 0.004, D)    # bridge over the rail
grod(mount, (0, 0.035, 0.036), (0, 0.035, 0.075), 0.009, D, 12)       # clamp screw
grod(mount, (0, 0.035, 0.07), (0, 0.035, 0.088), 0.022, K, 8)         # its wing knob, bakelite
gbox(mount, (-0.024, AY + R - 0.004, -0.012), (0.024, 0.004, 0.024), 0.004, D)  # stem down to the cradle
gbox(mount, (-0.05, -0.006, -0.03), (0.05, 0.004, 0.036), 0.003, D)  # foot plate under the rail
# cradle ring round the barrel, a bolted strap
grod(mount, (0, AY, -0.022), (0, AY, 0.022), R + 0.012, D, 28)
for x in (-1, 1):
    gbox(mount, (x * (R + 0.006) - 0.012, AY - 0.012, -0.016), (x * (R + 0.006) + 0.012, AY + 0.012, 0.016), 0.003, D)

# --- Tube (axis along -z, origin on the axis at the cradle) ------------------------------------------
tube_bm = bmesh.new()
Z_OUT, Z_IN = -0.75, 0.12
grod(tube_bm, (0, 0, Z_OUT), (0, 0, Z_IN), R, P, 32)                  # barrel
grod(tube_bm, (0, 0, Z_OUT - 0.14), (0, 0, Z_OUT + 0.02), R + 0.012, D, 32)   # dew shield, out of sight
for z in (-0.32, -0.12, 0.085):
    grod(tube_bm, (0, 0, z - 0.012), (0, 0, z + 0.012), R + 0.007, D, 32)     # ring bands
grod(tube_bm, (0, 0, Z_IN), (0, 0, Z_IN + 0.012), R + 0.004, D, 32)          # end cap
grod(tube_bm, (0, 0, Z_IN + 0.012), (0, 0, 0.215), 0.03, D, 24)               # focuser drawtube
grod(tube_bm, (-0.085, 0, 0.165), (0.085, 0, 0.165), 0.007, D, 10)           # focus shaft
for x in (-1, 1):
    grod(tube_bm, (x * 0.056, 0, 0.165), (x * 0.086, 0, 0.165), 0.02, K, 10)  # focus knobs, ten-sided grip
# diagonal: a block at the drawtube's end, the eyepiece aimed at the game camera (y 0.876, z 0.483)
gbox(tube_bm, (-0.032, -0.032, 0.205), (0.032, 0.032, 0.262), 0.006, D)
EY = Vector((0, 0.876, 0.483))
base = Vector((0, 0.0, 0.234))
def along(t):
    p = base + EY * t
    return (p.x, p.y, p.z)
grod(tube_bm, along(0.02), along(0.075), 0.022, D, 20)                      # eyepiece barrel
grod(tube_bm, along(0.075), along(0.112), 0.03, K, 20)                      # rubber eyecup
grod(tube_bm, along(0.108), along(0.112), 0.021, K, 20)                     # dark bore behind the lens
# finder scope on two little stands on top of the barrel
FY = R + 0.032
grod(tube_bm, (0, FY, -0.2), (0, FY, 0.04), 0.017, P, 18)
grod(tube_bm, (0, FY, -0.22), (0, FY, -0.2), 0.022, D, 18)
grod(tube_bm, (0, FY, 0.04), (0, FY, 0.06), 0.012, D, 14)
for z in (-0.15, -0.01):
    gbox(tube_bm, (-0.008, R - 0.006, z - 0.011), (0.008, FY - 0.01, z + 0.011), 0.002, D)
    grod(tube_bm, (0, FY, z - 0.009), (0, FY, z + 0.009), 0.022, D, 18)

lens_bm = bmesh.new()
grod(lens_bm, along(0.1105), along(0.1125), 0.02, 0, 24)                      # eyepiece lens

objs = []
for name, bm, mats in (("Mount", mount, [paint, metal]), ("Tube", tube_bm, [paint, metal])):
    ob = finish(name, bm, mats)
    colourise(ob)
    objs.append(ob)
glass = material("telescope_lens", (0.1, 0.12, 0.13), 0.4, 0.05)
objs.append(finish("Lens", lens_bm, [glass]))

# preview: the tube tilted and parked under the mount as in the scene
TILT = math.radians(8)
bpy.data.objects["Tube"].location = G(0, AY, 0)
bpy.data.objects["Tube"].rotation_euler = (TILT, 0, 0)
bpy.data.objects["Lens"].location = G(0, AY, 0)
bpy.data.objects["Lens"].rotation_euler = (TILT, 0, 0)
FRAME = ((0.0, -1.1, 0.75), (0.0, 0.0, -0.05), 60, 1280, 960)
GLB = os.environ.get("GLB")
if GLB:
    bpy.ops.object.select_all(action="DESELECT")
    for ob in objs:
        ob.select_set(True)
        ob.location = (0, 0, 0); ob.rotation_euler = (0, 0, 0)
    bpy.ops.export_scene.gltf(filepath=GLB, use_selection=True, export_apply=True, export_tangents=True,
                              export_vertex_color="ACTIVE", export_materials="EXPORT")
    for name in ("Tube", "Lens"):
        bpy.data.objects[name].location = G(0, AY, 0); bpy.data.objects[name].rotation_euler = (TILT, 0, 0)
