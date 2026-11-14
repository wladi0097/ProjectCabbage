
# Appended after preview.py: the asset in place in the room, seen from the game camera.
M = "C:/Users/wladi/Desktop/ProjectCabbage/assets/meshes/"
def g2b(x, y, z): return Vector((x, -z, y))
PLACE = {"Room/room.blend": (g2b(0, 0, 0), 1.0), "Table/table.blend": (g2b(0, 0, 0), 1.0),
         "Machines/tally_machine.blend": (g2b(-1.14, 0.76, -0.67 + float(os.environ.get("TALLY_DZ", "0"))), 1.3),
         "Machines/price_slate.blend": (g2b(-0.8, 0.75, -0.3816 + float(os.environ.get("TALLY_DZ", "0"))), 0.8),
         "Props/cabbage.blend": (g2b(0.1, 0.885, -0.82), 1.5)}
for path, (loc, s) in PLACE.items():
    with bpy.data.libraries.load(M + path) as (src, dst):
        dst.objects = list(src.objects)
    first = True
    for o in dst.objects:
        if o is None:
            continue
        if path.startswith("Props/cabbage") and not first:
            continue
        first = False
        o.name = o.name + "-noimp"
        scene.collection.objects.link(o)
        if o.parent is None:
            # matrix_world is still identity on a just-appended object: use matrix_basis
            o.matrix_world = Matrix.Translation(loc) @ Matrix.Scale(s, 4) @ o.matrix_basis
for n in ("Env-noimp", "Scale-noimp"):
    bpy.data.objects[n].hide_render = True
arm.location = g2b(-0.08, 0.75, -0.80)
STATES["busy"](arm.pose.bones)
# Findings counter placeholder: a dark drum strip with a chrome bezel, where the user wants it.
FC = os.environ.get("FC", "-1.14,1.06,-0.78").split(",")
fc = bmesh.new(); part_box(fc, (-0.17, -0.03, -0.035), (0.17, 0.03, 0.035), 0.006, 0)
finish("Counter-noimp", fc, [material("fc", (0.12, 0.15, 0.13), 0, 0.5)]).location = g2b(*map(float, FC))
lamp = bpy.data.objects.new("Lamp-noimp", bpy.data.lights.new("Lamp", "SPOT"))
lamp.data.energy = 900; lamp.data.spot_size = math.radians(104); lamp.data.color = (1.0, 0.85, 0.65)
lamp.location = g2b(-1.7, 2.5, 0.7)
lamp.rotation_euler = Vector((0.657, 0.226, -0.719)).to_track_quat("-Z", "Y").to_euler()
scene.collection.objects.link(lamp)
for o in bpy.data.objects:
    if o.type == "LIGHT" and o.name in ("Key-noimp", "Fill-noimp"):
        o.data.energy *= 0.3
cam.location = g2b(0.25, 3.2, 1.6)
cam.rotation_euler = (g2b(0.25, 0.75, 0.25) - cam.location).to_track_quat("-Z", "Y").to_euler()
cam.data.sensor_fit = "VERTICAL"; cam.data.sensor_height = 24; cam.data.lens = 12 / math.tan(math.radians(20))
scene.render.resolution_x = 1680; scene.render.resolution_y = 720
shoot("game" + os.environ.get("TAG", ""))
