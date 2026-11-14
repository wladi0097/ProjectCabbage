# The condensed cabbage's paper belt (entities/cabbage/): a printed manila band round the cabbage's
# middle with a glued overlap where the strip's end runs over its start. Only the part the camera can
# see is built, ARC either side of the front: the belt always turns its front to the camera, so the
# back is never seen, and stopping short of the sides tucks the ends in round the cabbage's outline
# (a full ring stood out past it on both sides like a flat label). Prepend blender_lib.py, append
# preview.py; exported with GLB=<path> and turned into assets/meshes/Props/cabbage_belt.res by
# glb_to_res.gd (prefix cabbage).
# Built round Blender Z (Godot Y, the belt's axis) at a nominal radius RB: the shader
# (assets/shaders/cabbage_belt.gdshader) moves every vertex out to the cabbage's own reach in its
# direction and keeps only its offset from RB, so the paper's thickness and the overlap survive.
# UVs: the front (u) runs round three tiles of the print, a count centred at the front (Blender -Y,
# Godot +Z, the side facing the camera); v is 0..1 across the width, top to bottom, in Godot. The back,
# the edges and the overlap's end take v 2..3 (the shader prints nothing there).
RB = 0.15        # nominal radius (m); keep in step with the shader's BASE
W = 0.074        # width
T = 0.0012       # paper thickness
ARC = 60.0       # degrees either side of the front; keep in step with cabbage_test.gd and the shader
SEG = 32         # segments across the arc (3.75 degrees each)
TILES = 3        # tiles of print per full turn: one count at the front
LAP = (32.0, 52.0)     # the glued overlap, degrees from the front toward +X (screen right)
RAMP = 4.0       # the overlap climbs from the band to its full thickness over these degrees

bm = bmesh.new()
uv = bm.loops.layers.uv.new("UVMap")


def point(deg, r, z):
    a = math.radians(deg)
    return Vector((r * math.sin(a), -r * math.cos(a), z))


def u_of(deg):
    return 0.5 + deg / 360.0 * TILES


def quad(corners, uvs, smooth):
    vs = [bm.verts.new(c) for c in corners]
    f = bm.faces.new(vs)
    f.smooth = smooth
    for loop, (u, v) in zip(f.loops, uvs):
        loop[uv].uv = (u, 1.0 - v)   # Blender v runs up; Godot's runs down
    return f


def strip(degs, r_of, face_out, printed):
    """A ring face round the angles, at radius r_of(deg): outward (front) or inward (back)."""
    for a, b in zip(degs, degs[1:]):
        ra, rb = r_of(a), r_of(b)
        top_a, bot_a, top_b, bot_b = point(a, ra, W / 2), point(a, ra, -W / 2), point(b, rb, W / 2), point(b, rb, -W / 2)
        if printed:
            uvs = [(u_of(a), 0), (u_of(a), 1), (u_of(b), 1), (u_of(b), 0)]
        else:
            uvs = [(u_of(a), 2), (u_of(a), 3), (u_of(b), 3), (u_of(b), 2)]
        if face_out:
            quad([top_a, bot_a, bot_b, top_b], uvs, True)
        else:
            quad([top_b, bot_b, bot_a, top_a], [uvs[3], uvs[2], uvs[1], uvs[0]], True)


def rims(degs, r_in, r_out):
    """The paper's cut edges along the top and bottom, between two radii."""
    for a, b in zip(degs, degs[1:]):
        for z, up in ((W / 2, True), (-W / 2, False)):
            c = [point(a, r_in(a), z), point(a, r_out(a), z), point(b, r_out(b), z), point(b, r_in(b), z)]
            uvs = [(u_of(a), 2), (u_of(a), 2.05), (u_of(b), 2.05), (u_of(b), 2)]
            if up:
                c.reverse(); uvs.reverse()
            quad(c, uvs, False)


ring = [-ARC + 2.0 * ARC * i / SEG for i in range(SEG + 1)]
band_in = lambda d: RB
band_out = lambda d: RB + T
strip(ring, band_out, True, True)
strip(ring, band_in, False, False)
rims(ring, band_in, band_out)
for end, side in ((-ARC, -1), (ARC, 1)):   # the cut ends, across the paper's thickness
    c = [point(end, RB, W / 2), point(end, RB, -W / 2), point(end, RB + T, -W / 2), point(end, RB + T, W / 2)]
    if side < 0:
        c.reverse()
    quad(c, [(u_of(end), 2), (u_of(end), 3), (u_of(end), 3), (u_of(end), 2)], False)

lap = [LAP[0] + (LAP[1] - LAP[0]) * i / 6 for i in range(7)]
lap_out = lambda d: RB + T + T * min(1.0, (d - LAP[0]) / RAMP)
strip(lap, lap_out, True, True)
rims(lap, band_out, lap_out)
end = LAP[1]
quad([point(end, RB + T, W / 2), point(end, RB + T, -W / 2), point(end, RB + 2 * T, -W / 2), point(end, RB + 2 * T, W / 2)],
     [(u_of(end), 2), (u_of(end), 3), (u_of(end), 3.0), (u_of(end), 2)], False)

bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-6)
for e in bm.edges:
    if len(e.link_faces) == 2 and e.link_faces[0].smooth != e.link_faces[1].smooth:
        e.smooth = False
paper = material("cabbage_belt", (0.6, 0.585, 0.52), 0.0, 0.9)
me = bpy.data.meshes.new("Belt")
bm.to_mesh(me)
bm.free()
me.materials.append(paper)
ob = bpy.data.objects.new("Belt", me)
bpy.context.scene.collection.objects.link(ob)
print("TRIS_OF Belt", sum(len(p.vertices) - 2 for p in me.polygons), "verts", len(me.vertices))

ASSET = "cabbage_belt"
FRAME = ((0.0, -0.7, 0.35), (0.0, 0.0, 0.0), 50, 1000, 700)
GLB = os.environ.get("GLB")
if GLB:
    bpy.ops.object.select_all(action="DESELECT")
    ob.select_set(True)
    bpy.ops.export_scene.gltf(filepath=GLB, use_selection=True, export_apply=True, export_materials="EXPORT")
