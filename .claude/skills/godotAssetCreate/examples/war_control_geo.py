# War control (chapter 3 fight): the steel desk unit beside the war sheet. A split-flap timer window (m:ss,
# the digits are Label3Ds), a big lamp-lit START button and a smaller oxblood ABORT button, each over a black
# engraved plate (Label3D). Prepend blender_lib.py + desk_vc_common.py (+ preview.py for a mockup).
# Built in the map camera's screen frame like war_props_geo.py: Blender X = screen right, Y = screen up (towards
# the wall), Z up, origin on the desk at the footprint's centre. Godot gets (x, z, -y).
# The control face is a panel sloped TILT toward the player (the map camera looks 10 deg toward the wall, so the
# face looks straight at it). Panel frame MP: u = X, v = up the slope, w = the face normal; origin = face centre.
# Objects: Body (static, vertex-coloured paint/metal), StartCap and AbortCap (the lenses, built upright in the
# panel frame with their origin on the face: the scene's `Panel` node carries the tilt and the caps move along
# its Y; Godot gives them their own lamp materials). Exported with GLB=<path>, turned into
# assets/meshes/War/control_<object>.res by glb_to_res.gd (prefix "control").
ASSET = "war_control"
SG, IR, PL, FL, HG, PN, OX, IV = range(7, 15)
COLOURS.update({
    SG: (0.25, 0.31, 0.26),      # our sage enamel (depot, map tally)
    IR: (0.11, 0.115, 0.12),     # cast iron foot (paint)
    PL: (0.36, 0.37, 0.38),      # pale pewter bezels (paint, matte: they frame numbers)
    FL: (0.012, 0.012, 0.013),   # flaps: black
    HG: (0.11, 0.115, 0.12),     # flap hinge line
    PN: (0.15, 0.185, 0.16),     # the face plate: the sage a step darker
    OX: (0.12, 0.025, 0.022),    # company oxblood (the depot's plate)
    IV: (0.62, 0.6, 0.5),        # ivory lens (Godot overrides it)
})
SURFACE.update({SG: 0, IR: 0, PL: 0, FL: 0, HG: 0, PN: 0, OX: 0, IV: 0})
COLOURS[H] = (0.5, 0.51, 0.53)

HX, HY = 0.095, 0.16             # housing half width / half depth (v2: tall and narrow, timer above buttons)
ZF, ZB = 0.04, 0.098             # housing top at the front / back edge (keeps the 10.3 deg slope)
TILT = math.atan2(ZB - ZF, 2 * HY)
ZM = (ZF + ZB) / 2
SL = HY / math.cos(TILT)         # half slope length
MP = at(0, 0, ZM) @ Matrix.Rotation(TILT, 4, "X")
PW = 0.003                       # face plate thickness above the housing top

START_AT, START_R = (-0.039, -0.049), 0.03
ABORT_AT, ABORT_R = (0.039, -0.049), 0.024
CELLS = {"Min": (-0.063, -0.029), "Colon": (-0.029, -0.009), "Sec10": (-0.009, 0.025), "Sec1": (0.029, 0.063)}
WV, WH = 0.086, 0.042            # window centre v, half height: the timer sits on top
BZ = 0.01
# plate: (u from, u to, v from, v to). TIME REMAINING under the window, START / ABORT under their buttons.
PLATES = {"TimePlate": (-0.073, 0.073, -0.002, 0.028), "StartPlate": (-0.075, -0.003, -0.126, -0.096),
          "AbortPlate": (0.003, 0.075, -0.126, -0.096)}


def pbox(bm, lo, hi, bevel, mat, M=I, seg=1):
    lo, hi = [min(a, b) for a, b in zip(lo, hi)], [max(a, b) for a, b in zip(lo, hi)]
    part = bmesh.new(); box(part, lo, hi, bevel, seg); merge(bm, part, M, mat)


def hull_bevel(bm, pts, bevel, mat):
    part = bmesh.new()
    bmesh.ops.convex_hull(part, input=[part.verts.new(p) for p in pts])
    bmesh.ops.bevel(part, geom=list(part.edges), offset=bevel, segments=2, affect="EDGES", profile=0.5)
    merge(bm, part, I, mat)


def on_face(u, v, w=0.0):
    return MP @ at(u, v, PW + w)


body = bmesh.new()
pbox(body, (-HX - 0.006, -HY - 0.008, 0), (HX + 0.006, HY + 0.006, 0.011), 0.004, IR)          # cast foot
hull_bevel(body, [(x, y, z) for x in (-HX, HX) for y, zt in ((-HY, ZF), (HY, ZB)) for z in (0.01, zt)], 0.007, SG)
pbox(body, (-HX + 0.008, -SL + 0.007, -0.004), (HX - 0.008, SL - 0.007, PW), 0.003, PN, MP)   # face plate
for x in (-HX + 0.016, HX - 0.016):                                                           # face screws
    for y in (-SL + 0.016, SL - 0.016):
        spin(body, [(0, 0), (0.0045, 0), (0.0045, 0.0012), (0.003, 0.0022), (0, 0.0024)], H, on_face(x, y), 8)

# timer window: black base, one raised flap per digit with its hinge line, pewter bezel and dividers
x0, x1 = CELLS["Min"][0], CELLS["Sec1"][1]
pbox(body, (x0, WV - WH, -0.002), (x1, WV + WH, 0.001), 0.0, FL, on_face(0, 0))
for name in ("Min", "Sec10", "Sec1"):
    a, b = CELLS[name]
    pbox(body, (a + 0.002, WV - WH + 0.003, 0.0), (b - 0.002, WV + WH - 0.003, 0.0025), 0.001, FL, on_face(0, 0))
    pbox(body, (a + 0.002, WV - 0.0012, 0.0025), (b - 0.002, WV + 0.0012, 0.003), 0.0, HG, on_face(0, 0))
    print("CELL", name, ((a + b) / 2, WV, PW + 0.0035))
print("CELL Colon", ((CELLS["Colon"][0] + CELLS["Colon"][1]) / 2, WV, PW + 0.0035))
for lo, hi in (((x0 - BZ, WV - WH - BZ), (x1 + BZ, WV - WH)), ((x0 - BZ, WV + WH), (x1 + BZ, WV + WH + BZ)),
               ((x0 - BZ, WV - WH), (x0, WV + WH)), ((x1, WV - WH), (x1 + BZ, WV + WH))):
    pbox(body, (*lo, -0.002), (*hi, 0.009), 0.0025, PL, on_face(0, 0))
for x in (CELLS["Colon"][1] + 0.002, CELLS["Sec10"][1] + 0.002):                             # flap dividers
    pbox(body, (x - 0.0015, WV - WH, 0.0), (x + 0.0015, WV + WH, 0.004), 0.0, PL, on_face(0, 0))

# buttons: a dark well inside a raised pewter collar; the lens is its own object
for (u, v), r in ((START_AT, START_R), (ABORT_AT, ABORT_R)):
    spin(body, [(0, -0.003), (r + 0.002, -0.003), (r + 0.002, 0.001), (0, 0.001)], K, on_face(u, v), 32)
    spin(body, [(r + 0.002, -0.002), (r + 0.009, -0.002), (r + 0.009, 0.006), (r + 0.006, 0.009), (r + 0.002, 0.009),
                (r + 0.002, -0.002)], PL, on_face(u, v), 32)
    print("BUTTON", (u, v, PW), "r", r)

# engraved plates under the buttons (text: Label3D)
for name, (a, b, c, d) in PLATES.items():
    pbox(body, (a, c, -0.001), (b, d, 0.003), 0.0015, K, on_face(0, 0))
    print("PLATE", name, ((a + b) / 2, (c + d) / 2, PW + 0.0035))
# the lenses: upright mushroom caps, origin on the face (panel frame)
def cap(r, h):
    bm = bmesh.new()
    spin(bm, [(0, -0.004), (r * 0.9, -0.004), (r * 0.9, 0.004), (r, 0.006), (r, h * 0.62), (r * 0.82, h * 0.92),
              (r * 0.45, h), (0, h)], IV, I, 32)
    return bm


objs = {"Body": finish("Body", body, [paint, metal]),
        "StartCap": finish("StartCap", cap(START_R, 0.02), [paint, metal]),
        "AbortCap": finish("AbortCap", cap(ABORT_R, 0.015), [paint, metal])}
for ob in objs.values():
    colourise(ob)
    print("TRIS_OF", ob.name, sum(len(p.vertices) - 2 for p in ob.data.polygons))
print("TRIS", ASSET, sum(len(p.vertices) - 2 for o in objs.values() for p in o.data.polygons))
c, s = math.cos(TILT), math.sin(TILT)
print("GODOT Panel x1.4 Transform3D(1.4, 0, 0, 0, %.4f, %.4f, 0, %.4f, %.4f, 0, %.4f, 0)  tilt %.2f deg" % (1.4 * c, -1.4 * s, 1.4 * s, 1.4 * c, 1.4 * ZM, math.degrees(TILT)))

GLB = os.environ.get("GLB")
if GLB:
    bpy.ops.object.select_all(action="DESELECT")
    for ob in objs.values():
        ob.select_set(True)
    bpy.ops.export_scene.gltf(filepath=GLB, use_selection=True, export_apply=True, export_tangents=True,
                              export_vertex_color="ACTIVE", export_materials="EXPORT")
else:  # mockup: show the caps seated on the face
    for name, (u, v) in (("StartCap", START_AT), ("AbortCap", ABORT_AT)):
        objs[name].matrix_world = on_face(u, v)
FRAME = ((0.0, -0.3, 0.7), (0.0, 0.0, 0.05), 50, 900, 1200)
