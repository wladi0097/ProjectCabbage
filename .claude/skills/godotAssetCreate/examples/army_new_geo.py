# Two more army figures (2026-11-15). Append after army_geo.py (which builds the first four), before
# army_tail.py:  cat blender_lib.py army_geo.py army_new_geo.py army_tail.py > build.py
# - RestructuringCharge: a walking cabbage bomb, a leafy cabbage ball on two toy legs mid-stride, a
#   dark bomb collar and crossed leather straps, a braided tan fuse with an orange spark.
# - Courier: a toy soldier on a delivery bicycle, leaning forward, a crate of cabbages on the front carrier.
# Same conventions: one object each, one surface (army_plastic), origin = base bottom centre, front -Y.

CORD = (0.56, 0.42, 0.26)      # tan fuse cord, braided with a darker strand
CORD2 = (0.40, 0.29, 0.17)
SPARK = (0.92, 0.47, 0.13)     # the spark: orange spikes round a hot pale core
SPARK_CORE = (1.0, 0.80, 0.45)
STRAP = (0.20, 0.155, 0.11)    # dark leather straps crossed over the cabbage


def figure2(name, body_fn, cab_fn, voxel, offset, body_paint, body_tris=2200, cab_tris=1000):
    b = bmesh.new(); body_fn(b)
    body = soft(name, b, voxel, 6, body_tris, seam_x=0.0)
    paint(body, body_paint)
    c = bmesh.new(); cab_fn(c)
    cab = soft(name + "Cab", c, voxel * 0.7, 3, cab_tris, crinkle=0.0005)
    paint(cab, cabbage_colour)
    with bpy.context.temp_override(active_object=body, selected_editable_objects=[body, cab]):
        bpy.ops.object.join()
    me = body.data
    me.materials.append(mat)
    me.shade_smooth()
    body.location.x = offset
    print("FIG", name, "tris", sum(len(p.vertices) - 2 for p in me.polygons),
          "height", round(max(v.co.z for v in me.vertices), 4),
          "xy", [round(max(v.co[i] for v in me.vertices) - min(v.co[i] for v in me.vertices), 4) for i in (0, 1)])
    return body


def cabbage_ball(bm, c, r, n=8):
    """A round leafy cabbage: a core ball wrapped in overlapping outer leaves with pale midribs."""
    c = Vector(c)
    ell(bm, c, (r, r, r * 0.95))
    for i in range(n):
        a = math.tau * (i + 0.5 * (i % 2)) / n
        z = -0.12 * r if i % 2 else 0.14 * r
        lean = -(8 + 6 * (i % 3))     # tops lean in: the leaves hug the ball
        M = rz(math.degrees(a)) @ at(0, -0.80 * r, z) @ rx(lean)
        ell(bm, c, (0.55 * r, 0.15 * r, 0.62 * r), M, (14, 8))
        ell(bm, c, (0.07 * r, 0.18 * r, 0.52 * r), M @ at(0, -0.02 * r, 0), (8, 6))      # midrib ridge
        VEINS.append(((c + (M @ V(0, -0.16 * r, -0.52 * r)).to_3d()), (c + (M @ V(0, -0.16 * r, 0.52 * r)).to_3d())))
    for i in range(3):   # inner leaves cupping the crown round the collar
        a = math.tau * i / 3 + 0.4
        M = rz(math.degrees(a)) @ at(0, -0.42 * r, 0.78 * r) @ rx(-55)
        ell(bm, c, (0.45 * r, 0.13 * r, 0.32 * r), M, (12, 8))
        VEINS.append(((c + (M @ V(0, -0.13 * r, -0.3 * r)).to_3d()), (c + (M @ V(0, -0.13 * r, 0.3 * r)).to_3d())))


# ---------------------------------------------------------------- restructuring charge: walking cabbage bomb
RC_C, RC_R = V(0, 0, 0.081), 0.040
RC_TOP = RC_C.z + RC_R * 0.95
FUSE = [V(0, 0, RC_TOP + 0.004), V(0.003, 0.0, RC_TOP + 0.010), V(0.010, -0.002, RC_TOP + 0.014),
        V(0.017, -0.004, RC_TOP + 0.015), V(0.022, -0.004, RC_TOP + 0.019)]   # curls over the top: long from above
TIP = FUSE[-1]


def rc_body(bm):
    base(bm, 0.100, 0.106, 5, shape=3)
    k = 1.25
    for x, knee, ankle, toe in ((-1, (-0.012, -0.013, 0.031), (-0.013, -0.019, 0.015), (-0.013, -0.034, 0.011)),
                                (1, (0.012, 0.012, 0.030), (0.013, 0.021, 0.017), (0.013, 0.008, 0.011))):
        hp = V(0.011 * x, 0.0, 0.050)
        limb(bm, hp, V(*knee), 0.0108 * k, 0.0092 * k); limb(bm, V(*knee), V(*ankle), 0.0092 * k, 0.0078 * k)
        an, to = V(*ankle), V(*toe); foot = to - an
        ell(bm, (an + to) / 2, (0.0085 * k, foot.length / 2 + 0.006 * k, 0.0068 * k), foot.to_track_quat("Y", "Z").to_matrix().to_4x4())
    cone(bm, (0, 0, RC_TOP - 0.008), (0, 0, RC_TOP + 0.006), 0.0165, 0.0155, 16)       # bomb collar
    ell(bm, (0, 0, RC_TOP + 0.006), (0.0155, 0.0155, 0.003))                             # its rounded lip
    for a, b in zip(FUSE, FUSE[1:]):                                                       # the fuse cord
        limb(bm, a, b, 0.0048, 0.0048)
    ell(bm, TIP, (0.0058, 0.0058, 0.0058))                                                # the spark: a spiky star
    for i in range(7):
        d = V(math.cos(math.tau * i / 7), math.sin(math.tau * i / 7), 0.9 if i % 2 else 0.15).normalized()
        cone(bm, TIP + d * 0.003, TIP + d * 0.0135, 0.0032, 0.0008, 8)
    cone(bm, TIP, TIP + V(0, 0, 0.0145), 0.0034, 0.0008, 8)
    for d in (V(1, 0, 0), V(-1, 0, 0), V(0, 1, 0), V(0, -1, 0)):                         # crossed straps
        for i in range(15):
            a = math.radians(24 + i * 5.5)
            ell(bm, RC_C + (d * math.sin(a) * (RC_R + 0.0012)) + V(0, 0, math.cos(a) * (RC_R * 0.95 + 0.0012)), (0.0034,) * 3, I, (8, 6))
    MUZZLES["restructuring_charge"] = tuple(TIP)


def rc_paint(co):
    if (co - TIP).length < 0.0085:
        return SPARK_CORE if (co - TIP).length < 0.0062 else SPARK
    if co.z > RC_TOP + 0.0095:
        return CORD if math.sin((co.z * 1.4 + (co.xy.length) * 0.8) * 1600) > 0 else CORD2
    if co.z > RC_TOP - 0.010 and co.xy.length < 0.019:
        return GUN
    if co.z > RC_C.z - 0.6 * RC_R and (co - RC_C).length > RC_R - 0.004:
        return STRAP
    if abs(co.x) < 0.0016 * 0.9 and co.z > 0.0085:
        return SEAM
    return PLASTIC


def rc_cab(bm):
    cabbage_ball(bm, RC_C, RC_R)


# ---------------------------------------------------------------- courier: delivery bicycle
WR = 0.026                      # wheel radius
WZ = 0.008 + WR                 # axle height (tyres sit on the base)
FRONT, REAR = V(0, -0.066, WZ), V(0, 0.056, WZ)   # long wheelbase: the wheels stick out past the rider from above
BB = V(0, 0.006, 0.037)         # bottom bracket
SEAT = V(0, 0.026, 0.073)
HEAD = V(0, -0.034, 0.070)      # head tube top
BAR = V(0, -0.031, 0.084)       # handlebar centre
CRATE = V(0, -0.047, 0.074)     # front carrier crate centre
CR = dict(hip=(0, 0.025, 0.081), chest=(0, 0.001, 0.099), head=(0, -0.021, 0.115), nose=(0, -1, -0.45),
          r_shoulder=(-0.019, -0.006, 0.105), r_elbow=(-0.027, -0.019, 0.094), r_hand=(-0.020, -0.032, 0.086),
          l_shoulder=(0.019, -0.006, 0.105), l_elbow=(0.027, -0.019, 0.094), l_hand=(0.020, -0.032, 0.086),
          r_hip=(-0.010, 0.025, 0.077), r_knee=(-0.013, -0.004, 0.073), r_ankle=(-0.014, -0.005, 0.048), r_toe=(-0.014, -0.017, 0.046),
          l_hip=(0.010, 0.025, 0.077), l_knee=(0.013, 0.013, 0.053), l_ankle=(0.014, 0.018, 0.028), l_toe=(0.014, 0.006, 0.025))


def teardrop(bm, w, d, seed, t=0.008):
    """A base that tapers to a point at the front (-Y): the courier's speed cue from above."""
    base(bm, w, d, seed, t, 2.4)
    for v in bm.verts:
        if v.co.z <= t + 1e-6 and v.co.y < 0:
            v.co.x *= 1 - 0.55 * (-v.co.y / (d / 2)) ** 1.5


def wheel(bm, c):
    for i in range(32):                                                                    # the tyre, fused by the remesh
        a = math.tau * i / 32
        ell(bm, c + V(0, math.cos(a), math.sin(a)) * (WR - 0.005), (0.0085, 0.0058, 0.0058), I, (8, 6))
    cone(bm, c + V(-0.0019, 0, 0), c + V(0.0019, 0, 0), WR - 0.005, WR - 0.005, 18)       # moulded web
    cone(bm, c + V(-0.0045, 0, 0), c + V(0.0045, 0, 0), 0.0045, 0.0045, 12)               # hub
    for i in range(4):                                                                     # four bold spokes
        a = math.tau * i / 4 + 0.4
        d = V(0, math.cos(a), math.sin(a)) * (WR - 0.006)
        limb(bm, c - d, c + d, 0.0024, 0.0024)


def cr_body(bm):
    global cube
    teardrop(bm, 0.056, 0.190, 6)
    wheel(bm, FRONT); wheel(bm, REAR)
    for a, b in ((REAR, BB), (BB, SEAT), (SEAT, REAR), (BB, HEAD), (SEAT + V(0, 0, -0.004), HEAD)):  # frame
        limb(bm, a, b, 0.0032, 0.0032)
    for x in (-1, 1):                                                                      # fork + rear stays
        limb(bm, HEAD, FRONT + V(0.005 * x, 0, 0), 0.003, 0.0026)
    limb(bm, HEAD, BAR, 0.003, 0.003)                                                      # stem
    limb(bm, BAR + V(-0.024, 0.003, 0), BAR + V(0.024, 0.003, 0), 0.003, 0.003)           # handlebar
    ell(bm, SEAT + V(0, 0.002, 0.004), (0.008, 0.011, 0.004))                             # saddle
    for x, pedal in ((-1, CR["r_ankle"]), (1, CR["l_ankle"])):                            # cranks + pedals
        p = V(*pedal) + V(0, 0, -0.004)
        limb(bm, BB + V(0.007 * x, 0, 0), V(0.012 * x, p.y, p.z), 0.0026, 0.0026)
        cube(bm, (0.014 * x, p.y, p.z), (0.009, 0.010, 0.004), bevel=0.001)
    ell(bm, BB, (0.008, 0.008, 0.008))                                                     # chainring
    keep, cube = cube, (lambda *a, **kw: None)    # man() without belt + pouches: on a rider bent forward they stick out
    man(bm, CR, 1.15)
    cube = keep
    ell(bm, V(*CR["hip"]) + V(0, 0.003, 0.0), (0.021, 0.018, 0.014))                      # seat on the saddle
    # front carrier: an open crate on struts over the front wheel
    limb(bm, HEAD + V(0, 0, -0.004), CRATE + V(0, 0, -0.010), 0.003, 0.003)
    for x in (-1, 1):
        limb(bm, CRATE + V(0.014 * x, -0.004, -0.010), FRONT + V(0.006 * x, 0, 0), 0.0024, 0.0024)
    cube(bm, CRATE + V(0, 0, -0.008), (0.044, 0.034, 0.004), bevel=0.001)                 # floor
    for x in (-1, 1):
        cube(bm, CRATE + V(0.0205 * x, 0, -0.002), (0.004, 0.034, 0.014), bevel=0.001)
    for y in (-1, 1):
        cube(bm, CRATE + V(0, 0.0155 * y, -0.002), (0.044, 0.004, 0.014), bevel=0.001)
    MUZZLES["courier"] = tuple(CRATE + V(0, 0, 0.016))


def cr_cab(bm):
    helmet(bm, V(*CR["head"]) + V(0, 0.001, 0.006), 0.023, rx(-16))
    for p in ((-0.011, -0.0065, 0.004), (0.011, -0.0055, 0.004), (0.0, 0.0075, 0.005), (0.0, -0.004, 0.006), (0.0, -0.001, 0.013)):
        ammo(bm, CRATE + V(*p), 0.0078)


FRAME_SEGS = [(REAR, BB), (BB, SEAT), (SEAT, REAR), (BB, HEAD), (SEAT + V(0, 0, -0.004), HEAD), (HEAD, BAR),
              (HEAD, FRONT + V(0.005, 0, 0)), (HEAD, FRONT + V(-0.005, 0, 0)),
              (BAR + V(-0.024, 0.003, 0), BAR + V(0.024, 0.003, 0)), (HEAD + V(0, 0, -0.004), CRATE + V(0, 0, -0.010)),
              (CRATE + V(0.014, -0.004, -0.010), FRONT + V(0.006, 0, 0)), (CRATE + V(-0.014, -0.004, -0.010), FRONT + V(-0.006, 0, 0))]
RIDER_SEGS = [(CR[a], CR[b], r) for a, b, r in (("r_hip", "r_knee", 0.0124), ("r_knee", "r_ankle", 0.0106), ("l_hip", "l_knee", 0.0124),
              ("l_knee", "l_ankle", 0.0106), ("r_shoulder", "r_elbow", 0.009), ("r_elbow", "r_hand", 0.0078),
              ("l_shoulder", "l_elbow", 0.009), ("l_elbow", "l_hand", 0.0078), ("hip", "chest", 0.02),
              ("r_ankle", "r_toe", 0.0105), ("l_ankle", "l_toe", 0.0105))]


def cr_paint(co):
    if co.z <= 0.0085:
        return PLASTIC
    for c in (FRONT, REAR):   # black tyres: two dark bars front and back of the rider from above
        if abs(co.x) < 0.0125 and WR - 0.0095 < (co.yz - c.yz).length < WR + 0.006:
            return TYRE
    if in_box(co, CRATE + V(0, 0, -0.003), (0.0245, 0.0195, 0.009)):
        return CARD                                                 # cardboard parcel crate
    rider = min(seg_d(co, a, b) - r for a, b, r in RIDER_SEGS)
    if (co - SEAT - V(0, 0.002, 0.004)).length < 0.012 and rider > -0.002:
        return TYRE                                                 # black saddle
    if (co - BB).length < 0.011 or min(seg_d(co, a, b) for a, b in FRAME_SEGS) < 0.0062:
        if rider > 0.0065:
            return STEEL                                            # dull steel frame, fork, bars, cranks
    for x in (-1, 1):
        p = V(*CR["r_ankle" if x < 0 else "l_ankle"]) + V(0, 0, -0.004)
        if seg_d(co, BB + V(0.007 * x, 0, 0), V(0.012 * x, p.y, p.z)) < 0.005 and rider > 0.0065:
            return STEEL
    for c in (FRONT, REAR):   # the moulded wheel web: steel spokes
        if abs(co.x) < 0.0075 and (co.yz - c.yz).length <= WR - 0.0095 and rider > 0.0065:
            return STEEL
    if abs(co.x) < 0.0016 * 0.9 and co.z > 0.0085:
        return SEAM
    return PLASTIC


objs += [
    figure2("RestructuringCharge", rc_body, rc_cab, 0.0016, -2.5 * GAP, rc_paint),
    figure2("Courier", cr_body, cr_cab, 0.0016, 2.5 * GAP, cr_paint, 3200, 1400),
]
for k in ("restructuring_charge", "courier"):
    x, y, z = MUZZLES[k]
    print("MUZZLE", k, "godot", (round(x, 4), round(z, 4), round(-y, 4)))
cells = bmesh.new()
for o in objs[-2:]:
    x0 = o.location.x
    for (a, b) in (((-0.1, -0.1), (0.1, -0.098)), ((-0.1, 0.098), (0.1, 0.1)), ((-0.1, -0.1), (-0.098, 0.1)), ((0.098, -0.1), (0.1, 0.1))):
        box(cells, (x0 + a[0], a[1], 0.0), (x0 + b[0], b[1], 0.0005), 0, 1)
finish("Cells2-noimp", cells, [material("cell2", (0.08, 0.08, 0.08), 0, 0.9)])
FRAME = ((0.0, -1.55, 0.75), (0.0, 0.0, 0.07), 50, 2000, 700)
