# Cabbage preview: (1) close 3/4 line-up on the leather mat, (2) ~60 copies at 1.5x, randomly
# rotated on all axes, from the fixed game camera. Appended after cabbage_geo.py (needs CABBAGES).
# SAVE=1 saves the .blend without preview objects.
import random
scene = bpy.context.scene
scene.render.engine = "BLENDER_EEVEE"
scene.view_settings.view_transform = "Standard"
scene.eevee.taa_render_samples = 48
world = bpy.data.worlds.new("World"); scene.world = world; world.use_nodes = True
world.node_tree.nodes["Background"].inputs[0].default_value = (0.030, 0.036, 0.040, 1)   # dim cool ambient
MAT_Z = 0.76

# dark grey-green leather: the game's own table_mat texture
leather = bpy.data.materials.new("leather-noimp"); leather.use_nodes = True
nt = leather.node_tree; p = nt.nodes["Principled BSDF"]
MATTEX = "C:/Users/wladi/Desktop/ProjectCabbage/assets/textures/table_mat/table_mat_"
ta = nt.nodes.new("ShaderNodeTexImage"); ta.image = bpy.data.images.load(MATTEX + "albedo.png")
nt.links.new(ta.outputs["Color"], p.inputs["Base Color"])
tn = nt.nodes.new("ShaderNodeTexImage"); tn.image = bpy.data.images.load(MATTEX + "normal.png"); tn.image.colorspace_settings.name = "Non-Color"
nm = nt.nodes.new("ShaderNodeNormalMap"); nt.links.new(tn.outputs["Color"], nm.inputs["Color"]); nt.links.new(nm.outputs["Normal"], p.inputs["Normal"])
p.inputs["Roughness"].default_value = 0.6
pl = bmesh.new(); bmesh.ops.create_grid(pl, x_segments=1, y_segments=1, size=3.0)
uvl = pl.loops.layers.uv.new("UVMap")
for f in pl.faces:
    for l in f.loops:
        l[uvl].uv = (l.vert.co.x / 6.0 + 0.5, l.vert.co.y / 6.0 + 0.5)
me = bpy.data.meshes.new("mat-noimp"); pl.to_mesh(me); me.materials.append(leather)
plane = bpy.data.objects.new("Mat-noimp", me); plane.location = (0.25, -0.25, MAT_Z); scene.collection.objects.link(plane)


def spot(name, loc, target, power, size, rgb, angle=55):
    l = bpy.data.objects.new(name + "-noimp", bpy.data.lights.new(name, "SPOT"))
    l.data.energy = power; l.data.shadow_soft_size = size; l.data.color = rgb; l.data.spot_size = math.radians(angle)
    l.data.spot_blend = 0.6; l.location = loc
    l.rotation_euler = (Vector(target) - Vector(loc)).to_track_quat("-Z", "Y").to_euler()
    scene.collection.objects.link(l); return l


cam = bpy.data.objects.new("Cam-noimp", bpy.data.cameras.new("Cam")); scene.collection.objects.link(cam); scene.camera = cam


def aim(loc, target):
    cam.location = loc; cam.rotation_euler = (Vector(target) - Vector(loc)).to_track_quat("-Z", "Y").to_euler()


def shoot(tag, w, h):
    scene.render.resolution_x = w; scene.render.resolution_y = h
    scene.render.filepath = PNG + "/" + ASSET + "_" + tag + ".png"
    bpy.ops.render.render(write_still=True)


# (1) line-up: each resting on the mat at 1.5x, 3/4 view
key = spot("Key", (-1.6, -0.2, 2.6), (0.25, -0.25, MAT_Z), 900, 0.25, (1.0, 0.84, 0.64), 70)
for k, ob in enumerate(CABBAGES):
    ob.scale = (1.5, 1.5, 1.5)
    ob.location = (-0.08 + 0.32 * k, -0.25, MAT_Z - 1.5 * min(v.co.z for v in ob.data.vertices)); ob.rotation_euler = (0, 0, 0.5 * k)
cam.data.sensor_fit = "AUTO"; cam.data.lens = 50
aim((0.25, -1.25, MAT_Z + 0.55), (0.25, -0.25, MAT_Z + 0.08))
shoot("lineup", 1280, 720)

# (2) game view: ~60 copies, uniform random rotation (physics can land any side up), loose mound
R = 0.135
random.seed(11); pile = []; tries = 0
while len(pile) < 60 and tries < 20000:
    tries += 1
    x, y = random.uniform(-0.45, 1.85), random.uniform(-1.05, 0.55)
    if random.random() < 0.5:   # half of them crowd a mound in the middle
        x, y = 0.6 + random.gauss(0, 0.35), -0.25 + random.gauss(0, 0.25)
    z = MAT_Z + R
    for (px, py, pz) in pile:
        d = math.hypot(x - px, y - py)
        if d < 2 * R:
            z = max(z, pz + math.sqrt(4 * R * R - d * d))
    if z > MAT_Z + R + 0.16:
        continue
    pile.append((x, y, z))
for (x, y, z) in pile:
    src = random.choice(CABBAGES)
    o = bpy.data.objects.new("pile-noimp", src.data); scene.collection.objects.link(o)
    o.location = (x, y, z - 0.012); o.scale = (1.5, 1.5, 1.5)
    o.rotation_mode = "QUATERNION"
    q = Vector([random.gauss(0, 1) for _ in range(4)]).normalized()
    o.rotation_quaternion = q
for ob in CABBAGES:
    ob.hide_render = True
cam.data.sensor_fit = "VERTICAL"; cam.data.angle = math.radians(40)
aim((0.25, -1.6, 3.2), (0.25, -0.25, 0.75))
shoot("game", 1280, 540)
cam.data.angle = math.radians(13)
aim((0.25, -1.6, 3.2), (0.6, -0.25, 0.80))
shoot("game_zoom", 1280, 540)

if os.environ.get("SAVE") == "1":
    for o in list(bpy.data.objects):
        if o.name.endswith("-noimp"):
            bpy.data.objects.remove(o)
    for k, ob in enumerate(CABBAGES):
        ob.hide_render = False; ob.scale = (1, 1, 1); ob.location = (-0.25 + 0.25 * k, 0, 0); ob.rotation_euler = (0, 0, 0)
    for m in list(bpy.data.materials):
        if m.name.endswith("-noimp"):
            bpy.data.materials.remove(m)
    bpy.ops.wm.save_as_mainfile(filepath=OUT)
    print("SAVED", OUT)
