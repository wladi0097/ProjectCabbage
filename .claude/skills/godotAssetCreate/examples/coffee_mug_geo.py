# Coffee mug: a chunky enamel office mug of cold coffee with the No More Sleep logo printed on its
# front. Three objects: Mug (vertex-coloured machine_paint: enamel, dark inside, coffee),
# Print (a curved strip just proud of the body, UV 0-1 over the logo, own slot `mug_print`).
# The coffee rings on the desk are a Decal in Godot. Static. Blender Z-up, front = -Y (Godot +Z).
# Origin: floor centre. Built at real size times K: at 1x a mug vanishes from the desk camera.
ASSET = "coffee_mug"
K = 1.6
M, N, C = 7, 8, 9
ENAMEL = {"dark": (0.045, 0.052, 0.05), "pale": (0.40, 0.41, 0.385)}
COLOURS[N] = (0.03, 0.03, 0.028)     # inside, stained
COLOURS[C] = (0.028, 0.02, 0.014)    # cold coffee: dark, matte, barely warm
SURFACE.update({M: 0, N: 0, C: 0})
R, H, WALL = 0.041 * K, 0.095 * K, 0.0045 * K
CZ = H - 0.016 * K                   # coffee level
PH = 0.056 * K                       # print height (square logo)
PZ0 = 0.022 * K                      # print bottom
HALF = PH / R / 2                    # half arc of the print, radians (keeps the logo square)


def build(name, enamel):
    COLOURS[M] = enamel
    bm = bmesh.new()
    # Body as one closed profile: base, outside up, rounded rim, inside down to below the coffee.
    spin(bm, [(0, 0), (R - 0.004 * K, 0), (R, 0.004 * K), (R, H - 0.002 * K), (R - WALL / 2, H),
              (R - WALL, H - 0.002 * K), (R - WALL, CZ - 0.01 * K), (0, CZ - 0.01 * K)], M, I, 40)
    # Paint the inside dark: faces whose centre is inside the wall radius and above the base.
    for f in bm.faces:
        c = f.calc_center_median()
        if math.hypot(c.x, c.y) < R - WALL * 0.6 and c.z > 0.01 * K:
            f.material_index = N
    spin(bm, [(0, CZ), (R - WALL + 0.0005, CZ), (R - WALL + 0.0005, CZ - 0.004 * K), (0, CZ - 0.004 * K)], C, I, 40)
    # Handle: a thick C on the right (+X), seen in profile from the desk.
    pts = []
    for i in range(13):
        a = math.radians(-80 + 160 * i / 12)
        pts.append((R - 0.003 * K + 0.026 * K * math.cos(a), 0, H * 0.52 + 0.03 * K * math.sin(a)))
    merge(bm, tube(pts, 0.0065 * K, 12), I, M)
    ob = finish(name, bm, [paint, metal])
    colourise(ob)
    # Print: a curved strip centred on the front, just proud of the body.
    me = bpy.data.meshes.new(name + "Print")
    steps, r = 12, R + 0.0006
    verts, faces = [], []
    for i in range(steps + 1):
        a = -HALF + 2 * HALF * i / steps
        verts += [(r * math.sin(a), -r * math.cos(a), PZ0), (r * math.sin(a), -r * math.cos(a), PZ0 + PH)]
    for i in range(steps):
        faces.append((2 * i, 2 * i + 2, 2 * i + 3, 2 * i + 1))
    me.from_pydata(verts, [], faces)
    uvl = me.uv_layers.new(name="UVMap")
    for poly in me.polygons:
        for li in poly.loop_indices:
            v = me.vertices[me.loops[li].vertex_index].co
            uvl.data[li].uv = ((math.atan2(v.x, -v.y) + HALF) / (2 * HALF), (v.z - PZ0) / PH)
    for poly in me.polygons:
        poly.use_smooth = True
    me.materials.append(print_mat)
    pr = bpy.data.objects.new(name.replace("Mug", "Print") if name == "Mug" else name + "Print", me)
    bpy.context.scene.collection.objects.link(pr)
    return ob, pr


print_mat = material("mug_print", (0.8, 0.78, 0.72), 0.0, 0.5)
nt = print_mat.node_tree
tex = nt.nodes.new("ShaderNodeTexImage"); tex.image = bpy.data.images.load(TEX + "no_more_sleep/no_more_sleep_logo.png")
bsdf = nt.nodes["Principled BSDF"]
nt.links.new(tex.outputs["Alpha"], bsdf.inputs["Alpha"])
print_mat.blend_method = "CLIP" if hasattr(print_mat, "blend_method") else None

mug, prt = build("Mug", ENAMEL[os.environ.get("ENAMEL", "dark")])
if os.environ.get("SAVE") != "1":
    other = "pale" if os.environ.get("ENAMEL", "dark") == "dark" else "dark"
    for o in build("Mug-alt-noimp", ENAMEL[other]):
        o.location.x = 0.25
    for o in bpy.context.scene.collection.objects:
        if o.name.startswith(("Mug", "Print")):
            pass
    wood = bmesh.new(); box(wood, (-0.6, -0.5, -0.02), (0.8, 0.5, 0.0), 0.0)
    finish("Desk-noimp", wood, [material("desk_wood", (0.09, 0.075, 0.06), 0.0, 0.6)])
print("TOP", H, "R", R)

STATES = {}
FRAME = ((0.12, -0.75, 0.55), (0.12, 0.0, 0.07), 50, 1600, 900)
