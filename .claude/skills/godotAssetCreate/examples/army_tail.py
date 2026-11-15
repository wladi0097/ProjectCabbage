# After preview.py: extra shots (game-like steep top view, close-up), then save + GLB.
def aim(loc, target, lens):
    cam.location = loc
    cam.rotation_euler = (Vector(target) - Vector(loc)).to_track_quat("-Z", "Y").to_euler()
    cam.data.lens = lens
aim((0.0, -0.55, 3.0), (0.0, 0.0, 0.0), 60); shoot("top")
ONLY = [n for n in os.environ.get("ONLY", "").split(",") if n]   # limit close shots + GLB to these figures
for o in objs:
    if ONLY and o.name not in ONLY:
        continue
    x = o.location.x
    aim((x + 0.30, -0.36, 0.30), (x, 0, 0.07), 50); shoot("close_" + o.name)
    aim((x - 0.42, -0.06, 0.16), (x, 0, 0.07), 50); shoot("side_" + o.name)
if os.environ.get("ARMY_SAVE") == "1":
    for o in list(bpy.data.objects):
        if o.name.endswith("-noimp"):
            bpy.data.objects.remove(o)
    bpy.ops.wm.save_as_mainfile(filepath=OUT)
GLB = os.environ.get("GLB")
if GLB:
    out = [o for o in objs if not ONLY or o.name in ONLY]
    for o in out:
        o.location.x = 0
    bpy.ops.object.select_all(action="DESELECT")
    for o in out:
        o.select_set(True)
    bpy.ops.export_scene.gltf(filepath=GLB, use_selection=True, export_apply=True, export_tangents=True,
                              export_vertex_color="ACTIVE", export_materials="EXPORT")
