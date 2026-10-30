# Generic preview + save. Appended after <asset>_geo.py, which must define:
#   ASSET  name used in the png filenames
#   FRAME  (cam location, target, lens mm, width, height)
#   STATES optional {"tag": fn(pose_bones)} to pose and shoot extra states
# Env: SAVE=1 saves the .blend (preview objects removed first).
scene = bpy.context.scene
scene.render.engine = "BLENDER_EEVEE"
world = bpy.data.worlds.new("World"); scene.world = world; world.use_nodes = True
world.node_tree.nodes["Background"].inputs[0].default_value = (0.20, 0.19, 0.17, 1)

env = bmesh.new()
box(env, (-3, -3, -0.05), (3, 1.0, 0), 0.0, 1)
box(env, (-3, 1.0, -0.05), (3, 1.1, 3.0), 0.0, 1)
finish("Env-noimp", env, [material("backdrop", (0.42, 0.40, 0.36), 0.0, 0.9)])

# 1.85 m reference capsule (a person), off to the side for scale.
ref = bmesh.new(); spin(ref, [(0, 0), (0.25, 0.05), (0.29, 0.3), (0.29, 1.55), (0.25, 1.8), (0, 1.85)], 0, I, 16)
finish("Scale-noimp", ref, [material("scale_ref", (0.3, 0.32, 0.36), 0.0, 0.8)], (0, 0, 0)).location = (-2.0, 0.3, 0)  # outside the 2.4 m table


def light(name, loc, target, power, size, rgb):
    l = bpy.data.objects.new(name + "-noimp", bpy.data.lights.new(name, "AREA"))
    l.data.energy = power; l.data.size = size; l.data.color = rgb; l.location = loc
    l.rotation_euler = (Vector(target) - Vector(loc)).to_track_quat("-Z", "Y").to_euler()
    scene.collection.objects.link(l)


light("Key", (-1.5, -2.0, 2.5), (0, 0, 0.4), 400, 1.5, (1.0, 0.88, 0.72))
light("Fill", (2.0, -1.5, 1.2), (0, 0, 0.5), 120, 2.0, (0.75, 0.85, 1.0))
cam = bpy.data.objects.new("Cam-noimp", bpy.data.cameras.new("Cam")); scene.collection.objects.link(cam)
scene.camera = cam
scene.view_settings.exposure = -0.5
loc, target, lens, w, h = FRAME
cam.location = loc
cam.rotation_euler = (Vector(target) - Vector(loc)).to_track_quat("-Z", "Y").to_euler()
cam.data.lens = lens
scene.render.resolution_x = w; scene.render.resolution_y = h


def shoot(tag):
    scene.render.filepath = PNG + "/" + ASSET + "_" + tag + ".png"
    bpy.ops.render.render(write_still=True)


shoot("rest")
arm = bpy.data.objects.get("Armature")
if arm:
    for tag, pose in globals().get("STATES", {}).items():
        pose(arm.pose.bones)
        bpy.context.view_layer.update()
        shoot(tag)
        for b in arm.pose.bones:
            b.location = (0, 0, 0); b.rotation_euler = (0, 0, 0); b.rotation_quaternion = (1, 0, 0, 0)

tris = sum(len(p.vertices) - 2 for o in bpy.data.objects if o.type == "MESH" and not o.name.endswith("-noimp") for p in o.data.polygons)
print("TRIS", ASSET, tris)
if os.environ.get("SAVE") == "1":
    for o in list(bpy.data.objects):
        if o.name.endswith("-noimp"):
            bpy.data.objects.remove(o)
    bpy.ops.wm.save_as_mainfile(filepath=OUT)
