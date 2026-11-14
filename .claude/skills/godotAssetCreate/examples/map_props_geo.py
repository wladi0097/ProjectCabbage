# Map table props (chapter 3): drafting weight, chart holder, roll core + label band + name tag, farm token, site token,
# desk call button. Prepend blender_lib.py + desk_vc_common.py, append preview.py. Static meshes, one object per
# part that Godot shows, hides or moves on its own; exported with GLB=<path> and turned into
# assets/meshes/Props/map_<object>.res by glb_to_res.gd (prefix "map").
# Every prop is built in the map table's screen frame: Blender X = screen right at the map camera, Y = screen up
# (towards the wall), Z up, origin on the desk / the sheet. glTF turns that into Godot (x, z, -y): place a prop
# with the sheets' basis (MapTable `Lay`), or as a child of a MapSheet.
# The objects are spread out along X for the preview only (LAYOUT); the meshes are about their own origins.
ASSET = "map_props"
G_, W, IR, O, C, WD, RF, PW, PB, SG, BD = range(7, 18)
# Vertex colours are sRGB bytes; these were settled in the engine under the map corner's key light.
COLOURS.update({
    G_: (0.26, 0.55, 0.09),      # cabbage green: owned roofs, ring, cabbages, pennant, the owned stud's boss
    W: (0.62, 0.64, 0.62),        # pale plaster: walls, silos, the for-sale rim ring
    IR: (0.11, 0.115, 0.12),   # cast iron (paint surface: mirror metal goes black in this corner)
    O: (0.16, 0.03, 0.027),      # company oxblood
    C: (0.62, 0.6, 0.5),       # cream card / ivory enamel
    WD: (0.2, 0.165, 0.13),      # bare soil
    RF: (0.27, 0.29, 0.3),    # dark grey roofs
    PW: (0.12, 0.13, 0.135),    # dark pewter (paint surface): a paler washer read as part of the print
    PB: (0.36, 0.37, 0.34),       # the core's paper wrap, as the sheet's plain back
    SG: (0.25, 0.31, 0.26),    # the cheeks' sage enamel, a step lighter than the desk machines' (dark corner)
})
COLOURS[BD] = (0.07, 0.075, 0.08)       # the token's dark board
SURFACE[BD] = 0
SURFACE.update({G_: 0, W: 0, IR: 0, O: 0, C: 0, WD: 0, RF: 0, PW: 0, PB: 0, SG: 0})
COLOURS[H] = (0.5, 0.51, 0.53)
COLOURS[B] = (0.62, 0.48, 0.22)
COLOURS[BD + 1] = (0.125, 0.026, 0.024)   # the call button's cap: a step darker than the plates, or it reads candy
SURFACE[BD + 1] = 0

YZ = Matrix.Rotation(math.pi / 2, 4, "Z") @ UP      # prism profile (Y, Z), extruded along X
AX = Matrix.Rotation(-math.pi / 2, 4, "Z")          # lathe axis along X


def rx(deg): return Matrix.Rotation(math.radians(deg), 4, "X")
def rz(deg): return Matrix.Rotation(math.radians(deg), 4, "Z")


def pbox(bm, lo, hi, bevel, mat, M=I, seg=1):
    part = bmesh.new(); box(part, lo, hi, bevel, seg); merge(bm, part, M, mat)


def prism(bm, pts, z0, z1, mat, M=I, bevel=0.0):
    part = bmesh.new()
    lo = [part.verts.new((x, y, z0)) for x, y in pts]; hi = [part.verts.new((x, y, z1)) for x, y in pts]
    n = len(pts)
    part.faces.new(lo[::-1]); part.faces.new(hi)
    for i in range(n):
        part.faces.new((lo[i], lo[(i + 1) % n], hi[(i + 1) % n], hi[i]))
    if bevel:
        bmesh.ops.bevel(part, geom=list(part.edges), offset=bevel, segments=1, affect="EDGES", profile=0.5)
    merge(bm, part, M, mat)


def ball(bm, r, mat, M=I, n=3, steps=6):
    spin(bm, [(r * math.sin(math.pi * i / n), -r * math.cos(math.pi * i / n)) for i in range(n + 1)], mat, M, steps)


def scaled(bm, s):
    bmesh.ops.scale(bm, vec=(s, s, s), verts=bm.verts)


# ---------------------------------------------------------------- drafting weight (r 61 mm, 105 mm tall)
weight = bmesh.new()
spin(weight, [(0, 0), (0.056, 0), (0.056, 0.004), (0, 0.004)], F, I, 24)
spin(weight, [(0, 0.004), (0.058, 0.004), (0.061, 0.008), (0.061, 0.026), (0.054, 0.031), (0.054, 0.047), (0.061, 0.052),
              (0.061, 0.058), (0.057, 0.063), (0, 0.063)], IR, I, 24)
for i in range(24):                                   # the knurled waist
    pbox(weight, (0.0535, -0.0035, 0.032), (0.0578, 0.0035, 0.046), 0.0, H, rz(i * 15))
spin(weight, [(0, 0.063), (0.05, 0.063), (0.05, 0.066), (0, 0.066)], B, I, 24)
spin(weight, [(0, 0.066), (0.014, 0.066), (0.011, 0.074), (0.011, 0.082), (0.022, 0.088), (0.024, 0.096),
              (0.019, 0.103), (0, 0.105)], K, I, 16)

# ---------------------------------------------------------------- chart holder: two end cheeks, one saddle
# The rolled-up parent of the open sheet lies across the top of the table in it (one roll: the sheets are nested,
# WORLD > COUNTRY > WAR, so a slot per sheet is not possible). The roll's middle from the holder's origin
# (towards the wall, up): the saddle. The roll clears the desk by 18 mm. (Until 2026-11-14 this was a three-step
# rack with a slot, a brass label holder and a number plate per sheet.)
SL = [(0.0, 0.092)]
STUB = 0.022
TREAD = SL[0][1] - STUB
CHEEK = (1.63, 1.89)
holder = bmesh.new()
block = [(-0.115, 0), (-0.115, 0.04), (-0.085, TREAD), (0.085, TREAD), (0.115, 0.04), (0.115, 0)]
for s in (-1, 1):
    prism(holder, block, min(s * CHEEK[0], s * CHEEK[1]), max(s * CHEEK[0], s * CHEEK[1]), SG, YZ, 0.005)
    for dy in (-0.037, 0.037):                        # bakelite saddle blocks either side of the core's stub
        pbox(holder, (min(s * 1.632, s * 1.672), dy - 0.012, TREAD), (max(s * 1.632, s * 1.672), dy + 0.012, TREAD + 0.03), 0.004, K)
    pbox(holder, (min(s * 1.72, s * 1.86), -0.05, TREAD), (max(s * 1.72, s * 1.86), 0.05, TREAD + 0.004), 0.0, O)   # oxblood enamel plate
    for dy in (-0.04, 0.04):                          # its two screws
        spin(holder, [(0, TREAD + 0.004), (0.006, TREAD + 0.004), (0.006, TREAD + 0.0065), (0, TREAD + 0.0065)], H, at(s * 1.79, dy, 0), 8)
rod(holder, (-1.63, 0.09, 0.022), (1.63, 0.09, 0.022), 0.011, IR, I, 8)   # tie rail, low behind the roll

# ---------------------------------------------------------------- roll core (on the roll's axis) + label band
CAP_R, ROLL_R = 0.055, 0.07405
core = bmesh.new()
merge(core, lathed([(0, -1.6), (0.028, -1.6), (0.028, 1.6), (0, 1.6)], 16), AX, PB)
for s in (1, -1):
    T = AX @ Matrix.Diagonal((1, s, 1, 1))
    merge(core, lathed([(0, 1.6), (0.052, 1.6), (CAP_R, 1.603), (CAP_R, 1.612), (0.05, 1.615), (0, 1.615)], 24), T, K)
    merge(core, lathed([(0, 1.615), (STUB, 1.615), (STUB, 1.654), (0.018, 1.658), (0, 1.658)], 12), T, H)
band = bmesh.new()                                    # cream paper band with an oxblood stripe, near the left end
r = ROLL_R
merge(band, lathed([(r - 0.004, -1.44), (r + 0.0015, -1.44), (r + 0.0015, -1.30), (r - 0.004, -1.30), (r - 0.004, -1.44)], 24), AX, C)
merge(band, lathed([(r - 0.004, -1.458), (r + 0.0022, -1.458), (r + 0.0022, -1.44), (r - 0.004, -1.44), (r - 0.004, -1.458)], 24), AX, O)
# The roll's name tag: a cream card lying on top of the roll, mid-length, held by a paper strap round it with an
# oxblood edge either side. The sheet's name is a Label3D on it (MapSheet): "WORLD", a country's name.
TAG_W, TAG_D = 0.62, 0.084
tag = bmesh.new()
pbox(tag, (-TAG_W / 2, -TAG_D / 2, r + 0.001), (TAG_W / 2, TAG_D / 2, r + 0.005), 0.0, C)
for sx in (-1, 1):
    x0, x1 = sorted((sx * (TAG_W / 2 - 0.004), sx * (TAG_W / 2 + 0.018)))
    merge(tag, lathed([(r - 0.004, x0), (r + 0.0025, x0), (r + 0.0025, x1), (r - 0.004, x1), (r - 0.004, x0)], 24), AX, O)
print("TAG", (0, 0, round(r + 0.0055, 4)))

# ---------------------------------------------------------------- farm token (diorama, board r 92 mm)
base, sale, owned = bmesh.new(), bmesh.new(), bmesh.new()
spin(base, [(0, 0), (0.08, 0), (0.08, 0.005), (0.077, 0.008), (0, 0.008)], BD, I, 32)
pbox(base, (-0.056, 0.012, 0.008), (0.01, 0.05, 0.03), 0.0, W)                      # shed walls
ROWS = []
for i in range(4):
    y = -0.052 + i * 0.014
    half = math.sqrt(0.064 ** 2 - (abs(y) + 0.005) ** 2) - 0.004
    pbox(base, (-half, y - 0.0045, 0.008), (half, y + 0.0045, 0.0105), 0.0, WD)       # furrow
    ROWS.append((y, half))
SILOS = ((0.03, 0.034), (0.054, 0.012))
for x, y in SILOS:
    spin(base, [(0, 0), (0.013, 0), (0.013, 0.05), (0, 0.05)], W, at(x, y, 0.008), 12)
for bm, roof, ring in ((sale, RF, W), (owned, G_, G_)):
    # The owned ring is green inside an ivory line: all green, the token lost its outline on the green land.
    spin(bm, [(0.067, 0.008), (0.0725, 0.008), (0.0725, 0.0108), (0.067, 0.0108), (0.067, 0.008)], ring, I, 32)
    spin(bm, [(0.0725, 0.008), (0.0765, 0.008), (0.0765, 0.0108), (0.0725, 0.0108), (0.0725, 0.008)], W if bm is sale else C, I, 32)
    prism(bm, [(0.008, 0.03), (0.054, 0.03), (0.031, 0.047)], -0.06, 0.014, roof, YZ)   # gabled roof
    for x, y in SILOS:
        spin(bm, [(0, 0.05), (0.0138, 0.05), (0.008, 0.058), (0, 0.06)], roof, at(x, y, 0.008), 12)
for y, half in ROWS:                                  # rows of tiny cabbages
    n = int(half * 2 / 0.014)
    for k in range(n):
        ball(owned, 0.0062, G_, at(-half + 0.007 + k * (half * 2 - 0.014) / max(n - 1, 1), y, 0.0128))
rod(owned, (-0.046, 0.0, 0.004), (-0.046, 0.0, 0.085), 0.0026, C, I, 6)              # pennant pin
ball(owned, 0.0045, C, at(-0.046, 0.0, 0.085))
prism(owned, [(0, 0.015), (0.046, 0), (0, -0.015)], 0, 0.0025, G_, at(-0.046, 0.0, 0.076) @ rx(30))
for bm in (base, sale, owned):
    scaled(bm, 1.15)

# ---------------------------------------------------------------- world-map site token (final size)
washer, stud = bmesh.new(), bmesh.new()
spin(washer, [(0.012, 0), (0.024, 0), (0.026, 0.002), (0.026, 0.005), (0.024, 0.007), (0.014, 0.007), (0.012, 0.005), (0.012, 0)], PW, I, 24)
spin(stud, [(0, 0), (0.025, 0), (0.027, 0.003), (0.027, 0.008), (0, 0.008)], B, I, 24)
spin(stud, [(0, 0.008), (0.023, 0.008), (0.021, 0.013), (0.013, 0.017), (0, 0.018)], C, I, 24)
spin(stud, [(0, 0.016), (0.015, 0.016), (0.015, 0.021), (0.011, 0.024), (0, 0.025)], G_, I, 16)

# ---------------------------------------------------------------- desk call button (300 x 130 mm)
BUTTON_X = -0.09
plinth, cap = bmesh.new(), bmesh.new()
pbox(plinth, (-0.15, -0.065, 0), (0.15, 0.065, 0.016), 0.005, SG, I, 2)
spin(plinth, [(0, 0.016), (0.047, 0.016), (0.047, 0.022), (0.041, 0.026), (0, 0.026)], H, at(BUTTON_X, 0, 0), 28)
pbox(plinth, (-0.03, -0.042, 0.016), (0.138, 0.042, 0.018), 0.0, K)                 # engraved plate
for x in (-0.022, 0.13):
    for y in (-0.034, 0.034):
        spin(plinth, [(0, 0.018), (0.004, 0.018), (0.004, 0.0195), (0, 0.0195)], H, at(x, y, 0), 6)
spin(cap, [(0, 0.02), (0.035, 0.02), (0.035, 0.036), (0.029, 0.042), (0, 0.043)], BD + 1, at(BUTTON_X, 0, 0), 28)
print("STENCIL", (0.054, 0, 0.0185))

LAYOUT = [("DraftingWeight", weight, -0.75), ("ChartHolder", holder, 0.0), ("RollCore", core, 0.0), ("RollBand", band, 0.0),
          ("RollTag", tag, 0.0),
          ("FarmTokenBase", base, -0.5), ("FarmTokenForSale", sale, -0.5), ("FarmTokenOwned", owned, -0.25),
          ("SiteTokenForSale", washer, 0.0), ("SiteTokenOwned", stud, 0.1), ("DeskButtonPlinth", plinth, 0.4),
          ("DeskButtonCap", cap, 0.4)]
objs = []
for name, bm, x in LAYOUT:
    y = {"ChartHolder": 0.4, "RollCore": 0.4, "RollBand": 0.4, "RollTag": 0.4}.get(name, -0.3)
    z = SL[0][1] if name in ("RollCore", "RollBand", "RollTag") else 0.0
    ob = finish(name, bm, [paint, metal])
    colourise(ob)
    ob.location = (x, y, z)
    print("TRIS_OF", name, sum(len(p.vertices) - 2 for p in ob.data.polygons))
    objs.append(ob)

FRAME = ((-0.1, -1.6, 1.3), (-0.1, -0.2, 0.0), 50, 1600, 900)
GLB = os.environ.get("GLB")
if GLB:
    bpy.ops.object.select_all(action="DESELECT")
    for ob in objs:
        ob.select_set(True)
    bpy.ops.export_scene.gltf(filepath=GLB, use_selection=True, export_apply=True, export_tangents=True,
                              export_vertex_color="ACTIVE", export_materials="EXPORT")
