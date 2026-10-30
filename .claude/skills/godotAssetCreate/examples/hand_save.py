if os.environ.get("HANDSAVE") == "1":
    arm.location.z = 0
    for o in list(bpy.data.objects):
        if o.name.endswith("-noimp"):
            bpy.data.objects.remove(o)
    bpy.ops.wm.save_as_mainfile(filepath=OUT)
