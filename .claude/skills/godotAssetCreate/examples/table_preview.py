# Moody desk preview (replaces preview.py for the table): dark room, cool dim ambient,
# one desk-lamp spot from the upper left, 20 cabbage stand-ins on the mat.
# Env: SAVE=1 saves the .blend (preview objects removed first). Both shots render every run.
scene = bpy.context.scene
scene.render.engine = "BLENDER_EEVEE"
try:
    scene.eevee.use_raytracing = True
    scene.eevee.use_shadows = True
except AttributeError:
    pass
world = bpy.data.worlds.new("World"); scene.world = world; world.use_nodes = True
world.node_tree.nodes["Background"].inputs[0].default_value = (0.010, 0.012, 0.016, 1)

env = bmesh.new()
box(env, (-4, -4, -0.05), (4, 0.80, 0), 0.0, 1)               # floor
box(env, (-4, 0.80, -0.05), (4, 0.95, 3.0), 0.0, 1)          # back wall (Godot z -0.80)
finish("Env-noimp", env, [material("room", (0.045, 0.05, 0.05), 0.0, 0.9)])

# Cabbage stand-ins: 20 spheres, d 0.18, scattered on the mat without overlap.
random.seed(5)
green = material("cabbage-noimp", (0.22, 0.55, 0.08), 0.0, 0.55)
placed = []
while len(placed) < 20:
    p = (random.uniform(MX0 + 0.14, MX1 - 0.14), random.uniform(MY0 + 0.14, MY1 - 0.14))
    if all((p[0] - q[0]) ** 2 + (p[1] - q[1]) ** 2 > 0.19 ** 2 for q in placed):
        placed.append(p)
for i, (px, py) in enumerate(placed):
    s = bmesh.new(); bmesh.ops.create_uvsphere(s, u_segments=24, v_segments=12, radius=0.09)
    o = finish("Cab%d-noimp" % i, s, [green]); o.location = (px, py, TOP + MT - 0.002 + 0.09)

lamp = bpy.data.objects.new("Lamp-noimp", bpy.data.lights.new("Lamp", "SPOT"))
lamp.data.energy = float(os.environ.get("LAMP", 1100)); lamp.data.color = (1.0, 0.86, 0.68)
lamp.data.spot_size = math.radians(95); lamp.data.spot_blend = 1.0; lamp.data.shadow_soft_size = 0.12
lamp.location = (-1.1, 0.25, 2.4)
lamp.rotation_euler = (Vector((0.3, -0.4, TOP)) - lamp.location).to_track_quat("-Z", "Y").to_euler()
scene.collection.objects.link(lamp)
fill = bpy.data.objects.new("Fill-noimp", bpy.data.lights.new("Fill", "AREA"))
fill.data.energy = 25; fill.data.size = 3.0; fill.data.color = (0.62, 0.74, 0.9)
fill.location = (1.0, -2.5, 2.6)
fill.rotation_euler = (Vector((0.3, -0.2, TOP)) - fill.location).to_track_quat("-Z", "Y").to_euler()
scene.collection.objects.link(fill)

cam = bpy.data.objects.new("Cam-noimp", bpy.data.cameras.new("Cam")); scene.collection.objects.link(cam)
scene.camera = cam
cam.data.sensor_fit = "VERTICAL"; cam.data.sensor_height = 24
scene.view_settings.exposure = float(os.environ.get("EXPO", 0))
scene.render.resolution_x, scene.render.resolution_y = 1280, 720


def shoot(tag, frame):
    loc, target, lens = frame
    cam.location = loc
    cam.rotation_euler = (Vector(target) - Vector(loc)).to_track_quat("-Z", "Y").to_euler()
    cam.data.lens = lens
    scene.render.filepath = PNG + "/" + ASSET + "_" + tag + ".png"
    bpy.ops.render.render(write_still=True)


shoot("game", ((0.25, -1.6, 3.2), (0.25, -0.25, 0.75), 12 / math.tan(math.radians(20))))
shoot("close", ((-1.25, -2.0, 1.4), (-0.35, -0.45, 0.76), 30))

for o in bpy.data.objects:
    if o.type == "MESH" and not o.name.endswith("-noimp"):
        print("TRIS", o.name, sum(len(p.vertices) - 2 for p in o.data.polygons), "SURF", len(o.data.materials), "LOC", tuple(round(c, 4) for c in o.location), "BBOX",
              [tuple(round(c, 4) for c in (o.matrix_world @ Vector(v))) for v in (o.bound_box[0], o.bound_box[6])])
if os.environ.get("SAVE") == "1":
    for o in list(bpy.data.objects):
        if o.name.endswith("-noimp"):
            bpy.data.objects.remove(o)
    for m in list(bpy.data.materials):
        if m.users == 0:
            bpy.data.materials.remove(m)
    bpy.ops.wm.save_as_mainfile(filepath=OUT)
