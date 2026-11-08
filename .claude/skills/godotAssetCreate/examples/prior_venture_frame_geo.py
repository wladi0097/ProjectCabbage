# Prior venture frame: a chunky dark steel "employee of the month" frame for the back wall, holding
# one of the developer's earlier game covers (2:3 portrait) on a pale mat with a dull brass
# nameplate below (its text is a Label3D in Godot). Two objects: Frame (vertex-coloured
# machine_paint + machine_metal) and Cover (a quad, UV 0-1, own slot; Godot swaps its material per
# frame). Static. Blender Z-up, front = -Y (Godot +Z). Origin: back centre (wall-mounted).
ASSET = "prior_venture_frame"
COLOURS[E] = (0.035, 0.038, 0.038)      # frame steel: dark gunmetal
COLOURS[P] = (0.21, 0.22, 0.205)      # mat: cold off-white card
COLOURS[K] = (0.03, 0.03, 0.03)      # backing board
COLOURS[B] = (0.24, 0.19, 0.09)      # nameplate: dull brass paint (matte, readable under the lamp)
SURFACE.update({E: 0, B: 0})   # all matte paint: the lamp glares shiny metal
CW, CH = 0.28, 0.42                  # cover
MS, MT, MB = 0.045, 0.045, 0.10      # mat border: sides, top, bottom (plate lives here)
FB, FD = 0.04, 0.04                  # frame bar width, depth
MX = CW / 2 + MS                     # mat half width
MZ0, MZ1 = -CH / 2 - MB, CH / 2 + MT
DZ = -(MZ0 + MZ1) / 2                # shift so the frame's centre sits on the origin
MZ0, MZ1 = MZ0 + DZ, MZ1 + DZ
CZ = DZ                              # cover centre
MY = -0.012                          # mat face

bm = bmesh.new()
part_box(bm, (-MX - FB, -0.006, MZ0 - FB), (MX + FB, 0.0, MZ1 + FB), 0.0, K)               # backing
part_box(bm, (-MX - 0.002, MY, MZ0 - 0.002), (MX + 0.002, -0.006, MZ1 + 0.002), 0.0, P)        # mat, one card
# Frame: one moulded steel surround (bevelled box minus a bevelled cutter), no visible joints.
fr = bmesh.new()
part_box(fr, (-MX - FB, -FD, MZ0 - FB), (MX + FB, 0.0, MZ1 + FB), 0.01, E)
surround = finish("Surround", fr, [paint, metal])
cut = bmesh.new()
box(cut, (-MX, -FD - 0.03, MZ0), (MX, 0.02, MZ1), 0.008, 3)
for f in cut.faces:
    f.material_index = E
boolean(surround, cut)
absorb(bm, surround)
PZ = (MZ0 + CZ - CH / 2) / 2         # nameplate centre, in the mat's bottom border
PW, PH = 0.26, 0.04
part_box(bm, (-PW / 2, MY - 0.004, PZ - PH / 2), (PW / 2, MY, PZ + PH / 2), 0.0015, B)
frame = finish("Frame", bm, [paint, metal])
colourise(frame)

# Cover: a quad set into the mat opening, UV 0-1 (v up in Blender = top of the picture).
cov = bpy.data.meshes.new("Cover")
y = MY - 0.001                       # just proud of the mat
cov.from_pydata([(-CW / 2, y, CZ - CH / 2), (CW / 2, y, CZ - CH / 2), (CW / 2, y, CZ + CH / 2), (-CW / 2, y, CZ + CH / 2)], [], [(0, 1, 2, 3)])
uvl = cov.uv_layers.new(name="UVMap")
for i, uv in enumerate([(0, 0), (1, 0), (1, 1), (0, 1)]):
    uvl.data[i].uv = uv
cov.polygons[0].flip() if cov.polygons[0].normal.y > 0 else None
cov_mat = material("prior_cover", (1, 1, 1), 0.0, 0.15)
nt = cov_mat.node_tree
tex = nt.nodes.new("ShaderNodeTexImage"); tex.image = bpy.data.images.load(TEX + "prior_ventures/cover_1.png")
nt.links.new(tex.outputs["Color"], nt.nodes["Principled BSDF"].inputs["Base Color"])
cov.materials.append(cov_mat)
cover = bpy.data.objects.new("Cover", cov); bpy.context.scene.collection.objects.link(cover)
print("PLATE_CENTRE", 0, PZ, -(MY - 0.004), "(Godot x, y, z)")
print("OUTER", 2 * (MX + FB), MZ1 - MZ0 + 2 * FB)

# Mockup only: a grey wall and the other two covers beside it.
wall = bmesh.new(); box(wall, (-1.2, 0.0, -0.6), (1.2, 0.05, 0.6), 0.0)
finish("Wall-noimp", wall, [material("wall_grey", (0.22, 0.26, 0.24), 0.0, 0.9)])
for n, dx in ((2, 0.6), (3, -0.6)):
    for src in (frame, cover):
        c = src.copy(); c.data = src.data.copy(); c.name = src.name + str(n) + "-noimp"; c.location.x = dx
        bpy.context.scene.collection.objects.link(c)
        if src is cover:
            m = cov_mat.copy(); m.node_tree.nodes["Image Texture"].image = bpy.data.images.load(TEX + "prior_ventures/cover_%d.png" % n)
            c.data.materials[0] = m

# Mockup runs lift everything above preview.py's floor; the saved run keeps the origin.
if os.environ.get("SAVE") != "1":
    for o in bpy.context.scene.collection.objects:
        o.location.z += 1.0
STATES = {}
FRAME = ((0.25, -2.6, 1.5), (0.0, 0.0, 1.0), 40, 1600, 900)
