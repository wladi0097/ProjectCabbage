# Project Cabbage: the back wall behind the table, its half-open steel window over the cabbage mat, a strip of
# pavement outside with produce crates where sold cabbages "land", and a plain wall across the street (no skyline).
# Build: cat blender_lib.py room_geo.py > build.py   (has its own preview, no preview.py)
#   blender -b --factory-startup -P build.py -- <abs room.blend> <abs png dir>   (SAVE=1 saves)
# Textures (generated, no sources): python room_tex.py <abs assets/textures>
# Blender coords (Z-up): Godot (x, y, z) = Blender (x, -z, y). +Y here = outside.
# Wall inner face Godot z=-0.80 -> Blender y=0.80; outer face y=1.05. x -3.6..3.6, height 0..2.6.
# Window opening x -0.55..1.95 (centred on the mat), height 0.75..1.90.
# Steel sill: top 0.75 flat from y 0.75 (desk back edge, fills the 5 cm gap) to 0.86, then slopes out and down
#   to 0.57 at y 1.10 (5 cm past the outer face); x -0.61..2.01.
# Lower sash pushed up: clear gap 0.75..1.07 between the jambs (x -0.47..1.87). Upper fixed grid + blinds above.
# Street (pavement) at height 0.5 (ground floor: just below the 0.75 sill), y 1.0..3.0; crates on it at y 1.4..1.8; plain wall across the street at y 3.0.
from bpy_extras.object_utils import world_to_camera_view
import random
random.seed(3)

# ---------- materials (names = Godot .tres names) ----------
WALL_S = 1 / 2.4                               # keep equal to uv1_scale in the .tres (texture tiles every 2.4 m)
def env_rgb(k, d): return tuple(float(v) for v in os.environ.get(k, d).split(","))
WALL_T = env_rgb("WALLT", "0.56,0.61,0.56")    # grey-sage paint; = albedo_color in the .tres
m_wall = material("room_wall", (1, 1, 1), 0, 0.9); textured(m_wall, "room_wall", WALL_S, WALL_T)
m_win = material("room_window", env_rgb("WT", "0.085,0.095,0.095"), 0.0, 0.42)    # dark painted steel
m_bl = material("room_blinds", env_rgb("BT", "0.50,0.52,0.48"), 0.0, 0.55)         # dull grey venetian blinds
m_st = material("room_street", (1, 1, 1), 0, 0.8); textured(m_st, "room_street", 1 / 2.4, env_rgb("STT", "0.55,0.57,0.57"))
m_cr = material("room_crates", (1, 1, 1), 0, 0.88)                                  # atlas, colour baked in
nt = m_cr.node_tree; t = nt.nodes.new("ShaderNodeTexImage")
t.image = bpy.data.images.load(TEX + "room_crates/room_crates_albedo.png")
nt.links.new(t.outputs["Color"], nt.nodes["Principled BSDF"].inputs["Base Color"])

# ---------- back wall: four blocks around the opening ----------
X0, X1, Z0, Z1 = -0.55, 1.95, 0.75, 1.90       # opening; Z0 = sill top = desk top
SB = 0.53                                      # underside of the steel sill block, top of the wall below it
WX, WB, WT_, Y0, Y1 = 3.6, 0.0, 2.6, 0.80, 1.05
bm = bmesh.new()
for lo, hi in [((-WX, Y0, WB), (WX, Y1, SB)),          # below the sill
               ((-WX, Y0, Z1), (WX, Y1, WT_)),         # above the window
               ((-WX, Y0, SB), (X0, Y1, Z1)),          # left pier
               ((X1, Y0, SB), (WX, Y1, Z1))]:          # right pier
    part_box(bm, lo, hi, 0.0, 0)
finish("room_wall", bm, [m_wall])

def prism(bm, prof, xa, xb, mat):
    """Closed (y, z) profile extruded along x."""
    a = [bm.verts.new((xa, y, z)) for y, z in prof]; b = [bm.verts.new((xb, y, z)) for y, z in prof]
    f = bm.faces.new(a); f.material_index = mat; f = bm.faces.new(b[::-1]); f.material_index = mat
    n = len(prof)
    for i in range(n):
        f = bm.faces.new((a[i], a[(i + 1) % n], b[(i + 1) % n], b[i])); f.material_index = mat

# ---------- window: steel sill, frame, fixed upper grid, lower sash pushed up ----------
B = 0.012
F, FY0, FY1 = 0.08, 0.88, 1.02                 # outer frame width, depth
GAP = 1.07                                     # bottom of the raised lower sash = top of the clear gap
bm = bmesh.new()
prism(bm, [(0.75, SB), (0.75, Z0), (0.86, Z0), (1.10, 0.57), (1.10, SB)], X0 - 0.06, X1 + 0.06, 0)   # sill, flush
part_box(bm, (X0, FY0, 0.60), (X0 + F, FY1, Z1), B, 0)                                # jambs (feet in the sill)
part_box(bm, (X1 - F, FY0, 0.60), (X1, FY1, Z1), B, 0)
part_box(bm, (X0, FY0, Z1 - F), (X1, FY1, Z1), B, 0)                                  # head
IX0, IX1 = X0 + F, X1 - F
COLS = [IX0 + (IX1 - IX0) * k / 6 for k in range(1, 6)]                               # 6 columns; 2 and 4 heavy
U0 = 1.30                                                                              # upper fixed grid
part_box(bm, (IX0, 0.94, U0), (IX1, 1.00, U0 + 0.06), B, 0)                            # its bottom rail
for k, x in enumerate(COLS):
    w, y0, y1 = (0.04, 0.93, 1.01) if k in (1, 3) else (0.018, 0.95, 0.99)
    part_box(bm, (x - w, y0, U0 + 0.06), (x + w, y1, Z1 - F), 0, 0)
zm = (U0 + 0.06 + Z1 - F) / 2
part_box(bm, (IX0, 0.95, zm - 0.018), (IX1, 0.99, zm + 0.018), 0, 0)
L0, L1, SY0, SY1 = GAP, GAP + 0.55, 0.885, 0.925                                       # raised lower sash
part_box(bm, (IX0, SY0, L0), (IX1, SY1, L0 + 0.06), B, 0)                              # bottom (meeting) rail
part_box(bm, (IX0, SY0, L1 - 0.045), (IX1, SY1, L1), B, 0)                             # top rail
part_box(bm, (IX0, SY0, L0), (IX0 + 0.045, SY1, L1), B, 0)                             # stiles
part_box(bm, (IX1 - 0.045, SY0, L0), (IX1, SY1, L1), B, 0)
for k, x in enumerate(COLS):
    w = 0.03 if k in (1, 3) else 0.016
    part_box(bm, (x - w, SY0 + 0.005, L0 + 0.06), (x + w, SY1 - 0.005, L1 - 0.045), 0, 0)
zm = (L0 + L1) / 2
part_box(bm, (IX0, SY0 + 0.005, zm - 0.016), (IX1, SY1 - 0.005, zm + 0.016), 0, 0)
for x in (IX0 + 0.45, IX1 - 0.45):                                                      # sash lifts, room side
    part_box(bm, (x - 0.05, SY0 - 0.025, L0 + 0.01), (x + 0.05, SY0, L0 + 0.035), 0.004, 0)
finish("window", bm, [m_win])

# ---------- venetian blinds in the reveal, one per bay, hung at uneven heights (all above the gap) ----------
bm = bmesh.new()
bays = [(IX0 + 0.01, COLS[1] - 0.045, 1.30, 0.0), (COLS[1] + 0.045, COLS[3] - 0.045, 1.58, 0.0),
        (COLS[3] + 0.045, IX1 - 0.01, 1.42, 0.05)]   # x0, x1, bottom z, crooked tilt
for bx0, bx1, bot, tilt in bays:
    part_box(bm, (bx0, 0.815, Z1 - 0.06), (bx1, 0.875, Z1 - 0.005), 0.008, 0)       # headrail
    z = Z1 - 0.10
    while z > bot + 0.02:
        L = bx1 - bx0
        R = Matrix.Rotation(math.radians(-38), 4, "X")
        M = at((bx0 + bx1) / 2, 0.845, z) @ Matrix.Rotation(tilt * (Z1 - z) / (Z1 - bot), 4, "Y") @ R
        part_box(bm, (-L / 2, -0.032, -0.006), (L / 2, 0.032, 0.006), 0.0, 0, M)
        z -= 0.058
    M = at((bx0 + bx1) / 2, 0.845, bot) @ Matrix.Rotation(tilt, 4, "Y")
    part_box(bm, (-(bx1 - bx0) / 2, -0.03, -0.012), ((bx1 - bx0) / 2, 0.03, 0.012), 0.006, 0, M)   # bottom rail
finish("blinds", bm, [m_bl])

# ---------- street: pavement quad just below the sill (we're on the ground floor) ----------
SZ = 0.5
SX, SY0_, SY1_ = 5.0, 1.0, 3.0
bm = bmesh.new()
bm.faces.new([bm.verts.new(c) for c in [(-SX, SY0_, SZ), (SX, SY0_, SZ), (SX, SY1_, SZ), (-SX, SY1_, SZ)]])
finish("street", bm, [m_st])

# ---------- crates: slatted 0.60 x 0.40 x 0.30, empty, no label (user: lumps and text looked bad) ----------
CL, CD, CH = 0.60, 0.40, 0.30
def crate(bm, cx, cy, cz, deg):
    M = at(cx, cy, cz) @ Matrix.Rotation(math.radians(deg), 4, "Z")
    hx, hy, p, t = CL / 2, CD / 2, 0.04, 0.02
    for sx in (-1, 1):
        for sy in (-1, 1):
            part_box(bm, (sx * hx - (p if sx > 0 else 0), sy * hy - (p if sy > 0 else 0), 0),
                     (sx * hx + (0 if sx > 0 else p), sy * hy + (0 if sy > 0 else p), CH), 0, 0, M)
    for i, (z0, z1) in enumerate([(0.02, 0.095), (0.115, 0.19), (0.21, 0.285)]):
        part_box(bm, (-hx + p, -hy, z0), (hx - p, -hy + t, z1), 0, 0, M)   # front slats
        part_box(bm, (-hx + p, hy - t, z0), (hx - p, hy, z1), 0, 0, M)
        for sx in (-1, 1):
            part_box(bm, (sx * hx - (t if sx > 0 else 0), -hy + p, z0), (sx * hx + (0 if sx > 0 else t), hy - p, z1), 0, 0, M)
    for y in (-0.13, 0.0, 0.13):
        part_box(bm, (-hx + p, y - 0.055, 0.0), (hx - p, y + 0.055, 0.02), 0, 0, M)
CRATES = [(0.10, 1.42, SZ, 6), (0.82, 1.36, SZ, -7), (1.55, 1.45, SZ, 3), (1.53, 1.46, SZ + CH, -4),
          (-0.40, 1.82, SZ, 24)]   # x, y, base z, yaw deg
bm = bmesh.new()
for c in CRATES:
    crate(bm, *c)
cr = finish("crates", bm, [m_cr])
uvl = cr.data.uv_layers["UVMap"].data
for poly in cr.data.polygons:                                      # random grain offset per slat
    li = list(poly.loop_indices); v0 = min(uvl[i].uv[1] for i in li); o = random.uniform(0, 0.42)
    for i in li:
        uvl[i].uv = (uvl[i].uv[0], uvl[i].uv[1] - v0 + o)

# ---------- across the street: a plain wall, no skyline (user: "just a wall") ----------
FY = 3.0                                       # Godot z -3.0
bm = bmesh.new()
part_box(bm, (-5.0, FY, SZ - 0.05), (5.0, FY + 0.3, 3.6), 0.0, 0)
finish("facade", bm, [m_wall])

# ---------- preview (all -noimp, removed before saving) ----------
scene = bpy.context.scene
scene.render.engine = "BLENDER_EEVEE"
scene.eevee.taa_render_samples = 64
try:
    scene.eevee.use_shadows = True; scene.eevee.use_raytracing = True
except Exception: pass
scene.view_settings.view_transform = "AgX"
world = bpy.data.worlds.new("World"); scene.world = world; world.use_nodes = True
bg = world.node_tree.nodes["Background"]; bg.inputs[0].default_value = (0.05, 0.06, 0.09, 1); bg.inputs[1].default_value = 1.0

tb = bmesh.new()
part_box(tb, (-3.2, -1.25, 0.68), (3.2, 0.75, 0.75), 0.0, 0)
part_box(tb, (-0.45, -1.1, 0.75), (1.85, 0.6, 0.76), 0.004, 1)
finish("Table-noimp", tb, [material("table_ph", (0.11, 0.075, 0.055), 0, 0.55), material("mat_ph", (0.05, 0.06, 0.055), 0, 0.7)])
cb = bmesh.new()
for x, y, z in [(0.1, -0.3, 0.895), (0.6, 0.1, 0.895), (1.2, -0.5, 0.895), (1.5, 0.35, 0.895), (0.85, 0.55, 0.895),
                (0.25, 0.45, 0.895), (1.0, 0.92, 0.885)]:   # last one on the sill, about to roll out
    s = bmesh.new(); bmesh.ops.create_icosphere(s, subdivisions=2, radius=0.135); merge(cb, s, at(x, y, z))
finish("Cabbages-noimp", cb, [material("cab_ph", (0.25, 0.55, 0.10), 0, 0.6)])

def add_light(name, kind, loc, target, power, rgb, size=1.0, size_y=None):
    l = bpy.data.objects.new(name + "-noimp", bpy.data.lights.new(name, kind))
    l.data.energy = power; l.data.color = rgb; l.location = loc
    if kind == "AREA":
        l.data.size = size
        if size_y: l.data.shape = "RECTANGLE"; l.data.size_y = size_y
    if kind == "SPOT": l.data.spot_size = math.radians(75); l.data.spot_blend = 0.8; l.data.shadow_soft_size = 0.15
    if kind == "SUN": l.data.angle = math.radians(20)
    l.rotation_euler = (Vector(target) - Vector(loc)).to_track_quat("-Z", "Y").to_euler()
    scene.collection.objects.link(l)
add_light("Lamp", "SPOT", (-1.55, -0.35, 1.75), (-0.75, -0.05, 0.75), 140, (1.0, 0.80, 0.58))   # desk lamp, upper left
add_light("Window", "AREA", (0.7, 1.12, 1.30), (0.7, -0.7, 0.75), 140, (0.72, 0.82, 0.98), 2.6, 1.0)  # cold light through the window
add_light("Fill", "AREA", (1.6, -2.2, 2.6), (0, 0.4, 1.0), 10, (0.72, 0.76, 0.88), 2.5)
add_light("Spill", "POINT", (-1.5, 0.2, 1.6), (0, 0, 0), 12, (1.0, 0.82, 0.62))   # lamp shade glow on the wall
add_light("Overcast", "SUN", (0.7, 3.5, 4.0), (0.5, 1.0, 0.0), float(os.environ.get("SUN", "1.2")), (0.75, 0.82, 0.92))  # street daylight

cam = bpy.data.objects.new("Cam-noimp", bpy.data.cameras.new("Cam")); scene.collection.objects.link(cam)
scene.camera = cam
scene.view_settings.exposure = float(os.environ.get("EXPO", "0"))
cam.data.sensor_fit = "VERTICAL"

def shoot(tag, loc, target, fov, res=(1280, 720)):
    scene.render.resolution_x, scene.render.resolution_y = res
    cam.location = loc
    cam.rotation_euler = (Vector(target) - Vector(loc)).to_track_quat("-Z", "Y").to_euler()
    cam.data.angle_y = math.radians(fov)
    bpy.context.view_layer.update()
    pts = {"sill_edge": (0.7, 0.86, Z0), "sill_out": (0.7, 1.10, 0.57), "sash_rail": (0.7, SY0, GAP),
           "crateA_top": (0.1, 1.42, SZ + CH), "stack_top": (1.53, 1.46, SZ + 2 * CH)}
    print("VIEW", tag, {k: round(world_to_camera_view(scene, cam, Vector(p)).y, 3) for k, p in pts.items()})
    scene.render.filepath = PNG + "/room_" + tag + ".png"
    bpy.ops.render.render(write_still=True)

G = (0.25, -1.6, 3.2)
shoot("game", G, (0.25, -0.25, 0.75), 40)
shoot("game21", G, (0.25, -0.25, 0.75), 40, (1280, 540))
shoot("close", (0.7, -0.15, 1.8), (0.75, 1.55, 0.2), 50)
shoot("front", (-0.3, -1.6, 1.3), (0.7, 0.9, 1.1), 50)

for o in bpy.data.objects:
    if o.type == "MESH" and not o.name.endswith("-noimp"):
        print("TRIS", o.name, sum(len(p.vertices) - 2 for p in o.data.polygons), [m.name for m in o.data.materials])
if os.environ.get("SAVE") == "1":
    for o in list(bpy.data.objects):
        if o.name.endswith("-noimp"):
            bpy.data.objects.remove(o)
    bpy.ops.wm.save_as_mainfile(filepath=OUT)
