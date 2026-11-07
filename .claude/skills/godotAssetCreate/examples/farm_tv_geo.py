# Farm TV: a 1970s office CRT standing on rubber feet on the desk's 45 degree corner step. Grey-sage enamel case, dark bakelite
# bezel, a wide right-hand panel carrying the BACK button (a steel plate with a stencilled arrow
# pointing right, towards the desk) and the red power lamp, chrome trim, rabbit ears, a tube hump.
# Objects: FarmTv (case + stand, vertex-coloured paint/metal), Screen (a slightly bulged 4:3 glass
# grid, UV 0-1 over the glass, own material for the ViewportTexture), Led (the power lamp) and
# BackArrow (the stencilled arrow, own material so Godot lights it on hover).
# Blender Z-up, front = -Y (Godot +Z). Origin: floor centre.
ASSET = "farm_tv"
S = 7                                     # dark stand steel
COLOURS[S] = (0.07, 0.075, 0.072); SURFACE[S] = 1
COLOURS[E] = (0.16, 0.18, 0.165)          # case: worn grey-sage enamel
COLOURS[P] = (0.2, 0.215, 0.2)            # button plate: paler worn grey
COLOURS[F] = (0.03, 0.032, 0.03)          # glass well
COLOURS[K] = (0.055, 0.05, 0.045)         # bezel: dark worn bakelite, not black
SX, SZ, GW, GH = -0.025, 0.33, 0.320625, 0.19  # screen centre and glass half size (1296:768, playtest: wider)
B = 0.028                                  # bezel width (playtest 2026-11-07: thinner, the glass gets the focus)
RIM = 0.03                                 # enamel left round the bezel
PW = 0.025                                 # narrow right panel half width (playtest: halved again)
PX = SX + GW + B + 0.008 + PW              # its centre x
XL, XR = SX - GW - B - RIM, PX + PW + 0.022  # case left and right
DEP, Z0, Z1 = 0.25, 0.045, SZ + GH + B + RIM   # case half depth, bottom (on taller feet), top
FRONT = -DEP
BZ, BHX, BHZ = SZ + 0.04, 0.019, 0.04     # back button centre z and half size: a tall narrow plate


def prism(bm, pts, y0, y1, mat):
    """A flat polygon (x, z) on the front, extruded from y0 (back) to y1 (front, more negative)."""
    part = bmesh.new()
    back = [part.verts.new((x, y0, z)) for x, z in pts]
    front = [part.verts.new((x, y1, z)) for x, z in pts]
    part.faces.new(back)
    part.faces.new(list(reversed(front)))
    n = len(pts)
    for k in range(n):
        part.faces.new((back[k], front[k], front[(k + 1) % n], back[(k + 1) % n]))
    merge(bm, part, I, mat)


bm = bmesh.new()
part_box(bm, (XL, -DEP, Z0), (XR, DEP, Z1), 0.035, E)                               # case shell
part_box(bm, (-0.3, DEP - 0.05, Z0 + 0.06), (0.3, DEP + 0.17, Z1 - 0.09), 0.06, E)  # tube hump
part_box(bm, (-0.17, DEP + 0.1, Z0 + 0.14), (0.17, DEP + 0.24, Z1 - 0.2), 0.04, E)
# Bezel: one moulded dark bakelite surround, the opening's corners rounded like a tube face; a dark
# well behind it.
bz = bmesh.new()
part_box(bz, (SX - GW - B, FRONT - 0.035, SZ - GH - B), (SX + GW + B, FRONT + 0.01, SZ + GH + B), 0.014, K)
bezel = finish("Bezel", bz, [paint, metal])
cut = bmesh.new()
box(cut, (SX - GW - 0.004, FRONT - 0.06, SZ - GH - 0.004), (SX + GW + 0.004, FRONT + 0.03, SZ + GH + 0.004), 0.03, 4)
for f in cut.faces:
    f.material_index = K
boolean(bezel, cut)
absorb(bm, bezel)
part_box(bm, (SX - GW - 0.005, FRONT - 0.002, SZ - GH - 0.005), (SX + GW + 0.005, FRONT + 0.005, SZ + GH + 0.005), 0.0, F)
# Chrome strip under the bezel, across the whole front.
part_box(bm, (XL + 0.03, FRONT - 0.012, Z0 + 0.012), (XR - 0.03, FRONT + 0.005, Z0 + 0.035), 0.005, H)
# Right panel: a dark inset; on it the BACK button (chrome rim, pale plate, corner rivets).
part_box(bm, (PX - PW, FRONT - 0.008, Z0 + 0.07), (PX + PW, FRONT + 0.005, Z1 - 0.04), 0.012, K)
part_box(bm, (PX - BHX - 0.005, FRONT - 0.018, BZ - BHZ - 0.005), (PX + BHX + 0.005, FRONT, BZ + BHZ + 0.005), 0.004, H)
part_box(bm, (PX - BHX, FRONT - 0.03, BZ - BHZ), (PX + BHX, FRONT - 0.01, BZ + BHZ), 0.004, P)
for rx in (-1, 1):
    for rz in (-1, 1):
        spin(bm, [(0, 0), (0.0035, 0), (0.003, 0.003), (0, 0.004)], H,
             at(PX + rx * (BHX - 0.006), FRONT - 0.03, BZ + rz * (BHZ - 0.006)) @ Matrix.Rotation(math.radians(90), 4, "X"), 10)
# LED bezel below the button (the lamp itself is the Led object).
LX, LZ = PX, BZ - BHZ - 0.05
spin(bm, [(0, 0), (0.016, 0), (0.016, 0.008), (0.0, 0.008)], H, at(LX, FRONT - 0.006, LZ) @ Matrix.Rotation(math.radians(90), 4, "X"), 16)
# Rabbit ears: a bakelite dome on top, two splayed chrome rods with ball tips.
AX = 0.0
spin(bm, [(0, 0), (0.07, 0), (0.065, 0.03), (0.04, 0.05), (0.0, 0.055)], K, at(AX, 0.05, Z1 - 0.005), 24)
for side in (-1, 1):
    tip = Vector((AX + side * 0.24, 0.12, Z1 + 0.44))
    rod(bm, (AX + side * 0.012, 0.05, Z1 + 0.04), tip, 0.0075, H, I, 10)
    spin(bm, [(0, -0.013), (0.009, -0.011), (0.013, 0), (0.009, 0.011), (0, 0.013)], H, at(*tip), 12)
# Rubber feet under the case.
for fx in (XL + 0.08, XR - 0.08):
    for fy in (-DEP + 0.07, DEP - 0.07):
        spin(bm, [(0, 0), (0.03, 0), (0.028, Z0 + 0.01), (0, Z0 + 0.01)], K, at(fx, fy, 0), 12)
case = finish("FarmTv", bm, [paint, metal])
colourise(case)

# Screen: a 4:3 glass grid bulging 1.4 cm at its centre, UV 0-1 left->right, bottom->top.
g = bmesh.new()
NU, NV = 16, 12
uv = g.loops.layers.uv.new("UVMap")
vs = [[g.verts.new((SX + (u / NU * 2 - 1) * GW, FRONT - 0.006 - 0.014 * (1 - (u / NU * 2 - 1) ** 2) * (1 - (v / NV * 2 - 1) ** 2),
                    SZ + (v / NV * 2 - 1) * GH)) for v in range(NV + 1)] for u in range(NU + 1)]
for u in range(NU):
    for v in range(NV):
        f = g.faces.new((vs[u][v], vs[u + 1][v], vs[u + 1][v + 1], vs[u][v + 1]))
        for loop, (a, b) in zip(f.loops, [(u, v), (u + 1, v), (u + 1, v + 1), (u, v + 1)]):
            loop[uv].uv = (a / NU, b / NV)
bmesh.ops.recalc_face_normals(g, faces=g.faces)
if g.faces[0].normal.y > 0:
    bmesh.ops.reverse_faces(g, faces=g.faces)
me = bpy.data.meshes.new("Screen"); g.to_mesh(me); g.free()
for p in me.polygons:
    p.use_smooth = True
me.materials.append(emissive("farm_tv_screen", (0.25, 0.28, 0.27), 0.6, (0.05, 0.06, 0.055)))
scr = bpy.data.objects.new("Screen", me); bpy.context.scene.collection.objects.link(scr)
print("SCREEN centre (godot)", (SX, SZ, -(FRONT - 0.006)), "half", (GW, GH))

led = bmesh.new()
spin(led, [(0, 0), (0.008, 0), (0.008, 0.006), (0.005, 0.01), (0, 0.011)], 0, at(LX, FRONT - 0.008, LZ) @ Matrix.Rotation(math.radians(90), 4, "X"), 12)
finish("Led", led, [emissive("farm_tv_led", (0.5, 0.05, 0.03), 0.5, (0.2, 0.03, 0.02))])

arrow = bmesh.new()
AF = FRONT - 0.03
AZ, K8 = BZ + 0.014, 0.8 * BHX / 0.105                 # arrow centre (above the TO DESK stencil) and scale
prism(arrow, [(PX + K8 * x, AZ + K8 * z) for x, z in [(-0.07, -0.022), (0.005, -0.022), (0.005, -0.055), (0.075, 0),
              (0.005, 0.055), (0.005, 0.022), (-0.07, 0.022)]], AF + 0.002, AF - 0.008, 0)
finish("BackArrow", arrow, [emissive("farm_tv_arrow", (0.6, 0.65, 0.62), 0.0, (0.55, 0.58, 0.55))])
print("BACK button centre (godot)", (PX, BZ, -(FRONT - 0.03)), "half", (BHX, BHZ))

FRAME = ((0.9, -2.0, 1.25), (0.0, 0.0, 0.75), 40, 960, 1280)
