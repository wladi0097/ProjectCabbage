# Builds and exports only the farmhouse and silo wrecks: cat blender_lib.py <maquette_geo.py helpers> <maquette_round3_geo.py helpers> this > build.py; GLB=<path> blender -b -P build.py -- <blend> <png dir>
objs = [farmhouse_rubble(), silo_rubble()]
for ob in objs:
    tris = sum(len(p.vertices) - 2 for p in ob.data.polygons)
    used = sorted({p.material_index for p in ob.data.polygons})
    print("TRIS_OF", ob.name, tris, "slots used", used, "dims", tuple(round(d, 3) for d in ob.dimensions), "min", [round(min(v.co[i] for v in ob.data.vertices), 3) for i in range(3)], "max", [round(max(v.co[i] for v in ob.data.vertices), 3) for i in range(3)])
bpy.ops.object.select_all(action="DESELECT")
for ob in objs:
    ob.select_set(True)
bpy.ops.export_scene.gltf(filepath=os.environ["GLB"], use_selection=True, export_apply=True, export_tangents=True,
                          export_materials="EXPORT")
