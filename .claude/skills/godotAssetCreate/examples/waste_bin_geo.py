# Waste bin: plain enamel-painted steel can, slight taper, two pressed beads, a fat rolled rim,
# near-black inside and floor (faces whose normal points inward or up below the rim are recoloured).
# One object, one surface (machine_paint -> machine_paint_matte in Godot). Origin: floor centre.
ASSET = "waste_bin"
COLOURS[E] = (0.13, 0.16, 0.14)
COLOURS[K] = (0.018, 0.019, 0.018)
H_ = 0.26
bm = bmesh.new()
prof = [(0, 0), (0.122, 0), (0.128, 0.006),                       # foot
        (0.130, 0.03), (0.134, 0.036), (0.131, 0.042),             # lower bead
        (0.142, 0.205), (0.146, 0.211), (0.143, 0.217),            # upper bead
        (0.146, 0.244), (0.153, 0.248), (0.157, 0.254), (0.155, 0.26), (0.148, 0.262), (0.142, 0.258),  # rolled rim
        (0.140, 0.25),                                             # inner mouth
        (0.120, 0.018), (0, 0.018)]                                # inner wall, floor
spin(bm, prof, E, I, 40)
bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
for f in bm.faces:
    c = f.calc_center_median()
    rxy = Vector((c.x, c.y, 0))
    if c.z > 0.01 and c.z < 0.249 and (f.normal.dot(rxy) < 0 or f.normal.z > 0.9):
        f.material_index = K                                     # dark inside
ob = finish("waste_bin", bm, [paint])
colourise(ob)
FRAME = ((0.35, -0.75, 0.9), (0, 0, 0.12), 50, 1280, 960)
