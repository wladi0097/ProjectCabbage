# Research light (entities/golden_lamp/research_light.tscn, the GoldenLamp script with research
# exports): the golden lamp's research twin. A heavy round gunmetal plinth with a chrome lip and a
# chrome post, holding three nested machined rings that the scene tilts and turns slowly (each ring
# precesses about the post, so from the desk camera the ellipses swing round each other) and a small
# core ball on top of the post. Prepend blender_lib.py + desk_vc_common.py. Exported with GLB=<path> +
# glb_to_res.gd (prefix research_light):
#   Base         static, origin on the desk at the post, Godot +Y up.
#   Ring1..3     each about its own centre, axis Godot +Y (the scene tilts and spins it). The rings
#                and the core get the lamp's glow material in the scene (material_override), so
#                their Blender material is only a stand-in.
#   Core         a faceted ball, the bulb at the rings' centre.
# Godot (x, y, z) = Blender (x, -z, y), via G(). Design from the top-down camera first: the rings'
# top faces and the plinth's chrome lip carry the read, side detail barely shows.
ASSET = "research_light"
GM = 7                                              # dark gunmetal enamel
COLOURS[GM] = (0.06, 0.07, 0.075); SURFACE[GM] = 0

PLINTH_R, PLINTH_H = 0.078, 0.026
CENTRE_Y = 0.135                                    # the rings' centre above the desk
RINGS = ((0.108, 0.022, 0.012), (0.083, 0.019, 0.011), (0.059, 0.016, 0.010))   # radius, radial w, axial h
CORE_R = 0.019


def G(x, y, z):
    return Vector((x, -z, y))


def up_spin(bm, profile, mat, steps=48):
    # profile in Godot (r, y); lathe() turns about Blender Y, so lathe in Godot space then map.
    part = lathed(list(profile), steps)
    for v in part.verts:
        v.co = G(v.co.x, v.co.y, v.co.z)
    merge(bm, part, I, mat)


base = bmesh.new()
# Plinth: a stepped, chamfered puck, closed profile axis to axis.
up_spin(base, [(0.0, 0.0), (PLINTH_R, 0.0), (PLINTH_R, 0.012), (PLINTH_R - 0.006, PLINTH_H),
               (0.03, PLINTH_H), (0.03, PLINTH_H + 0.004), (0.0, PLINTH_H + 0.004)], GM, 48)
# Chrome lip round the top chamfer, and a chrome collar where the post stands.
up_spin(base, [(PLINTH_R - 0.003, 0.0118), (PLINTH_R + 0.001, 0.0118), (PLINTH_R + 0.001, 0.0148), (PLINTH_R - 0.003, 0.0148)], H, 48)
up_spin(base, [(0.0, PLINTH_H), (0.011, PLINTH_H), (0.011, PLINTH_H + 0.008), (0.008, PLINTH_H + 0.012), (0.0, PLINTH_H + 0.012)], H, 32)
# Post up to under the core, a small cup holding the ball.
up_spin(base, [(0.0, PLINTH_H), (0.0055, PLINTH_H), (0.0055, CENTRE_Y - CORE_R + 0.004), (0.011, CENTRE_Y - CORE_R + 0.002),
               (0.012, CENTRE_Y - 0.008), (0.0, CENTRE_Y - 0.008)], H, 24)

objs = []
glow = material("research_glow", (0.45, 0.7, 0.75), 0.0, 0.3)
ob = finish("Base", base, [paint, metal], (0, 0, 0))
colourise(ob)
objs.append(ob)
for i, (r, w, h) in enumerate(RINGS):
    ring = bmesh.new()
    b = 0.0025  # chamfered rectangle section: a machined band, flat top face to catch the camera
    up_spin(ring, [(r - w / 2 + b, -h / 2), (r + w / 2 - b, -h / 2), (r + w / 2, -h / 2 + b), (r + w / 2, h / 2 - b),
                   (r + w / 2 - b, h / 2), (r - w / 2 + b, h / 2), (r - w / 2, h / 2 - b), (r - w / 2, -h / 2 + b),
                   (r - w / 2 + b, -h / 2)], 0, 64)
    objs.append(finish("Ring%d" % (i + 1), ring, [glow]))
core = bmesh.new()
bmesh.ops.create_icosphere(core, subdivisions=2, radius=CORE_R)
objs.append(finish("Core", core, [glow]))

GLB = os.environ.get("GLB")
if GLB:
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.ops.export_scene.gltf(filepath=GLB, use_selection=True, export_apply=True, export_tangents=True,
                              export_vertex_color="ACTIVE", export_materials="EXPORT")

# Preview: rings tilted and turned as in the scene, the core on the post, shown at 4x.
TILTS = ((22, 0), (44, 120), (64, 240))
for i, (tilt, yaw) in enumerate(TILTS):
    o = bpy.data.objects["Ring%d" % (i + 1)]
    o.location = G(0, CENTRE_Y, 0)
    o.rotation_mode = "ZXY"
    o.rotation_euler = (math.radians(tilt), 0, math.radians(yaw))
bpy.data.objects["Core"].location = G(0, CENTRE_Y, 0)
for o in objs:
    o.scale = (4, 4, 4); o.location = o.location * 4
FRAME = ((0, -1.4, 2.2), (0, 0, 0.45), 50, 900, 900)
