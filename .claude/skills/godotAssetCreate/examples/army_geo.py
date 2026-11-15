# War phase army figures: green plastic toy soldiers with a cabbage-head helmet on a moulded base.
# Prepend blender_lib.py only; append army_tail.py (preview shots, save, GLB export).
# Four static figures, one object each, one surface (army_plastic, vertex coloured): the body (base,
# figure and kit fused by a voxel remesh, so it reads as one moulded piece with soft edges and a
# parting-line ridge) plus the cabbage parts (helmet, ammo) in a fresher green.
# Blender -Y = Godot +Z = the figure's front; origin = base bottom centre. 1 unit = 1 m.
import random
from mathutils import noise

ASSET = "army"
# sRGB vertex colours: toy olive-green plastic a step under the cabbage, the helmet a fresh cabbage green.
PLASTIC = (0.34, 0.47, 0.19)
SEAM = (0.42, 0.55, 0.26)
CAB_DARK = (0.27, 0.54, 0.08)
CAB_LIGHT = (0.58, 0.79, 0.26)

mat = material("army_plastic", (1, 1, 1), 0.0, 0.42)
nt = mat.node_tree
attr = nt.nodes.new("ShaderNodeVertexColor"); attr.layer_name = "Col"
nt.links.new(attr.outputs["Color"], nt.nodes["Principled BSDF"].inputs["Base Color"])

MUZZLES = {}


def V(*a): return Vector(a)


def ell(bm, c, r, rot=I, seg=(14, 9)):
    part = bmesh.new()
    bmesh.ops.create_uvsphere(part, u_segments=seg[0], v_segments=seg[1], radius=1.0)
    merge(bm, part, at(*c) @ rot @ Matrix.Diagonal((*r, 1)))


def cone(bm, a, b, r0, r1, seg=12):
    a, b = Vector(a), Vector(b)
    part = bmesh.new()
    bmesh.ops.create_cone(part, cap_ends=True, segments=seg, radius1=r0, radius2=r1, depth=(b - a).length)
    q = (b - a).to_track_quat("Z", "Y").to_matrix().to_4x4()
    merge(bm, part, Matrix.Translation((a + b) / 2) @ q)


def limb(bm, a, b, r0, r1):
    cone(bm, a, b, r0, r1); ell(bm, a, (r0,) * 3); ell(bm, b, (r1,) * 3)


def cube(bm, c, size, rot=I, bevel=0.0):
    part = bmesh.new(); box(part, [-s / 2 for s in size], [s / 2 for s in size], bevel, 2)
    merge(bm, part, at(*c) @ rot)


def rx(d): return Matrix.Rotation(math.radians(d), 4, "X")
def ry(d): return Matrix.Rotation(math.radians(d), 4, "Y")
def rz(d): return Matrix.Rotation(math.radians(d), 4, "Z")


def base(bm, w, d, seed, t=0.008, shape=4):
    # A slightly irregular rounded slab, like a toy's moulded stand. shape: squircle power (2 = oval),
    # or "oct" for a chamfered octagon. Each unit type has its own base outline, read from above.
    rnd = random.Random(seed)
    n = 28
    wob = [1 + rnd.uniform(-0.018, 0.018) for _ in range(n)]
    pts = []
    for i in range(n):
        a = math.tau * i / n
        c, s = math.cos(a), math.sin(a)
        if shape == "oct":
            f = (a + math.pi / 8) % (math.pi / 4) - math.pi / 8
            k = math.cos(math.pi / 8) / math.cos(f)
        else:
            k = (abs(c) ** shape + abs(s) ** shape) ** (-1 / shape)
        pts.append((w / 2 * c * k * wob[i], d / 2 * s * k * wob[i]))
    part = bmesh.new()
    lo = [part.verts.new((x, y, 0)) for x, y in pts]; hi = [part.verts.new((x, y, t)) for x, y in pts]
    part.faces.new(lo[::-1]); part.faces.new(hi)
    for i in range(n):
        part.faces.new((lo[i], lo[(i + 1) % n], hi[(i + 1) % n], hi[i]))
    merge(bm, part)


def man(bm, j, k=1.2, broad=1.15):
    """A toy soldier from joint points (k scales limb thickness, broad the torso)."""
    hc, cc, hd = V(*j["hip"]), V(*j["chest"]), V(*j["head"])
    ell(bm, hc, (0.019 * broad, 0.013 * broad, 0.014 * k))
    ell(bm, cc, (0.021 * broad, 0.0145 * broad, 0.019 * k))
    limb(bm, hc, cc, 0.015 * broad, 0.016 * broad)
    limb(bm, cc + V(0, 0, 0.012 * k), hd, 0.0075 * k, 0.007 * k)        # neck
    ell(bm, hd, (0.0125 * k, 0.0125 * k, 0.0135 * k))                    # head
    ell(bm, hd + (V(*j.get("nose", (0, -1, 0))) * 0.011 * k) + V(0, 0, -0.002), (0.004 * k,) * 3)  # nose/chin
    cube(bm, hc + V(0, 0, 0.008 * k), (0.040 * broad, 0.028 * broad, 0.006 * k), bevel=0.002)      # belt
    for x in (-1, 1):
        cube(bm, hc + V(0.010 * x * broad, -0.013 * broad, 0.008 * k), (0.009, 0.006, 0.008), bevel=0.0015)  # pouches
    for side in ("r", "l"):
        s, e, h = (V(*j[side + "_" + n]) for n in ("shoulder", "elbow", "hand"))
        ell(bm, s, (0.009 * k,) * 3)
        limb(bm, s, e, 0.0078 * k, 0.0068 * k); limb(bm, e, h, 0.0068 * k, 0.0058 * k)
        ell(bm, h, (0.0068 * k,) * 3)
        hp, kn, an, to = (V(*j[side + "_" + n]) for n in ("hip", "knee", "ankle", "toe"))
        limb(bm, hp, kn, 0.0108 * k, 0.0092 * k); limb(bm, kn, an, 0.0092 * k, 0.0078 * k)
        foot = to - an
        ell(bm, (an + to) / 2 + V(0, 0, 0.0), (0.0075 * k, foot.length / 2 + 0.006 * k, 0.0065 * k),
            foot.to_track_quat("Y", "Z").to_matrix().to_4x4())


def soft(name, bm, voxel, smooth, target, crinkle=0.0, seam_x=None):
    """Voxel-remesh a block-out into one soft moulded skin, optional crinkle / parting ridge, decimate."""
    me = bpy.data.meshes.new(name); bm.to_mesh(me); bm.free()
    ob = bpy.data.objects.new(name, me); bpy.context.scene.collection.objects.link(ob)
    rm = ob.modifiers.new("Remesh", "REMESH"); rm.mode = "VOXEL"; rm.voxel_size = voxel; rm.adaptivity = 0
    sm = ob.modifiers.new("Smooth", "SMOOTH"); sm.factor = 0.6; sm.iterations = smooth
    dg = bpy.context.evaluated_depsgraph_get()
    me2 = bpy.data.meshes.new_from_object(ob.evaluated_get(dg)); ob.modifiers.clear(); ob.data = me2
    bm = bmesh.new(); bm.from_mesh(me2); bm.normal_update()
    if crinkle:
        for v in bm.verts:
            p = v.co * (1 / 0.006)
            v.co += v.normal * crinkle * (noise.noise(p) + 0.5 * noise.noise(p * 2.3))
    if seam_x is not None:
        for v in bm.verts:   # the mould's parting line: a faint raised ridge on the plane x = seam_x
            d = abs(v.co.x - seam_x)
            if d < voxel * 1.2 and v.co.z > 0.0085:
                v.co += v.normal * 0.0005 * (1 - d / (voxel * 1.2))
    bm.to_mesh(me2); bm.free()
    tris = sum(len(p.vertices) - 2 for p in me2.polygons)
    if tris > target:
        dm = ob.modifiers.new("Dec", "DECIMATE"); dm.ratio = target / tris
        dg = bpy.context.evaluated_depsgraph_get()
        me3 = bpy.data.meshes.new_from_object(ob.evaluated_get(dg)); ob.modifiers.clear(); ob.data = me3
    return ob


def paint(ob, fn):
    me = ob.data
    col = me.color_attributes.new("Col", "BYTE_COLOR", "CORNER")
    me.color_attributes.active_color = col
    me.color_attributes.render_color_index = me.color_attributes.find("Col")
    for poly in me.polygons:
        for li, vi in zip(poly.loop_indices, poly.vertices):
            col.data[li].color_srgb = (*fn(me.vertices[vi].co), 1)


def cabbage_colour(co):
    t = 0.35 + 0.3 * noise.noise(co * (1 / 0.008))
    for a, b in VEINS:
        ab = b - a; u = max(0.0, min(1.0, (co - a).dot(ab) / ab.length_squared))
        d = (co - (a + ab * u)).length
        if d < 0.0028:
            t = max(t, 1.0 - d / 0.0028 * 0.35)
    return tuple(a + (b - a) * t for a, b in zip(CAB_DARK, CAB_LIGHT))


VEINS = []   # (a, b) midrib segments of the helmet leaves, painted pale


def helmet(bm, c, r, tilt=I):
    """The cabbage-head helmet: a round cabbage core, leaves overlapping round it like a roof, their
    lower edges flaring into a scalloped brim at brow height, each with a pale midrib."""
    c = Vector(c); s = r / 0.02
    ell(bm, c + tilt @ V(0, 0, 0.005 * s), (0.0165 * s, 0.0165 * s, 0.0125 * s), tilt)
    n = 7
    for i in range(n):
        a = math.tau * (i + 0.25 * (i % 2)) / n
        lean = 58 + 6 * (i % 3)
        M = tilt @ rz(math.degrees(a)) @ at(0, -0.0135 * s, 0.0015 * s) @ rx(-lean)
        ell(bm, c, (0.0135 * s, 0.003 * s, 0.0105 * s), M, (14, 8))
        ell(bm, c, (0.0018 * s, 0.0036 * s, 0.0095 * s), M @ at(0, -0.0006 * s, 0), (8, 6))   # midrib ridge
        VEINS.append(((c + (M @ V(0, -0.0035 * s, -0.0095 * s)).to_3d()), (c + (M @ V(0, -0.0035 * s, 0.0095 * s)).to_3d())))
    for i in range(3):   # inner leaves curling over the top
        a = math.tau * i / 3 + 0.5
        M = tilt @ rz(math.degrees(a)) @ at(0, -0.006 * s, 0.0145 * s) @ rx(-70)
        ell(bm, c, (0.009 * s, 0.0028 * s, 0.0065 * s), M, (12, 8))
        VEINS.append(((c + (M @ V(0, -0.003 * s, -0.006 * s)).to_3d()), (c + (M @ V(0, -0.003 * s, 0.006 * s)).to_3d())))


def ammo(bm, c, r):
    ell(bm, c, (r, r, r * 0.92))
    for i in range(5):
        a = math.tau * i / 5
        ell(bm, V(*c) + V(r * 0.55 * math.cos(a), r * 0.55 * math.sin(a), r * 0.15),
            (r * 0.55, r * 0.22, r * 0.6), rz(math.degrees(a) + 90) @ rx(-20), (10, 6))


def figure(name, body_fn, cab_fn, voxel, seam_x, offset, body_tris=2200, cab_tris=1000, accent=None):
    b = bmesh.new(); body_fn(b)
    body = soft(name, b, voxel, 6, body_tris, seam_x=seam_x)
    paint(body, lambda co: (accent and accent(co)) or (SEAM if abs(co.x - seam_x) < voxel * 0.9 and co.z > 0.0085 else PLASTIC))
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


# ---------------------------------------------------------------- field associate: rifleman
FA = dict(hip=(0, 0.002, 0.074), chest=(0, -0.004, 0.105), head=(-0.004, -0.008, 0.134), nose=(0, -1, -0.2),
          r_shoulder=(-0.020, 0.0, 0.117), r_elbow=(-0.032, -0.004, 0.100), r_hand=(-0.014, -0.010, 0.117),
          l_shoulder=(0.020, -0.004, 0.117), l_elbow=(0.020, -0.030, 0.103), l_hand=(-0.007, -0.046, 0.120),
          r_hip=(-0.011, 0.004, 0.070), r_knee=(-0.014, 0.016, 0.043), r_ankle=(-0.016, 0.026, 0.017), r_toe=(-0.019, 0.012, 0.012),
          l_hip=(0.011, 0.0, 0.070), l_knee=(0.015, -0.017, 0.045), l_ankle=(0.016, -0.024, 0.017), l_toe=(0.017, -0.040, 0.012))
RIFLE_Y = -0.082


def fa_body(bm):
    base(bm, 0.10, 0.115, 1, shape=2)
    man(bm, FA)
    cube(bm, (0, 0.018, 0.104), (0.028, 0.013, 0.030), bevel=0.003)                   # backpack
    ell(bm, (0, 0.019, 0.122), (0.013, 0.008, 0.005))                                   # bedroll
    x, z = -0.011, 0.122
    cube(bm, (x, 0.006, z - 0.003), (0.008, 0.022, 0.012), rx(-6), 0.002)              # stock at the shoulder
    cube(bm, (x, -0.022, z), (0.008, 0.036, 0.008), bevel=0.0015)                       # receiver + fore-end
    cube(bm, (x, -0.012, z - 0.009), (0.006, 0.008, 0.012), rx(15), 0.0015)             # magazine
    limb(bm, (x, -0.035, z + 0.001), (x, RIFLE_Y + 0.010, z + 0.001), 0.0036, 0.0036)  # barrel
    cone(bm, (x, RIFLE_Y + 0.011, z + 0.001), (x, RIFLE_Y, z + 0.001), 0.0042, 0.0115, 14)  # launcher cup
    MUZZLES["field_associate"] = (x, RIFLE_Y - 0.008, z + 0.001)


def fa_cab(bm):
    helmet(bm, V(*FA["head"]) + V(0, 0.001, 0.006), 0.023, rx(-8))
    ammo(bm, (-0.011, RIFLE_Y - 0.003, 0.123), 0.0092)


# ---------------------------------------------------------------- compliance officer: running with the charge
CO = dict(hip=(0, 0.002, 0.072), chest=(0, -0.010, 0.102), head=(0, -0.019, 0.129), nose=(0, -1, -0.1),
          r_shoulder=(-0.020, -0.008, 0.113), r_elbow=(-0.034, -0.014, 0.118), r_hand=(-0.027, -0.012, 0.136),
          l_shoulder=(0.020, -0.008, 0.113), l_elbow=(0.027, -0.026, 0.097), l_hand=(0.020, -0.040, 0.110),
          r_hip=(-0.010, 0.005, 0.068), r_knee=(-0.012, 0.022, 0.044), r_ankle=(-0.013, 0.038, 0.022), r_toe=(-0.013, 0.044, 0.009),
          l_hip=(0.010, -0.002, 0.068), l_knee=(0.012, -0.024, 0.057), l_ankle=(0.013, -0.028, 0.030), l_toe=(0.013, -0.042, 0.027))


def co_body(bm):
    base(bm, 0.105, 0.12, 2, shape="oct")
    man(bm, CO)
    # the charge rides on the right shoulder, long side front to back, clipboard facing out (-X),
    # so from above it is a block beside the helmet
    c = V(-0.034, -0.008, 0.130); tilt = rz(-90) @ ry(-8) @ rx(-6)
    cube(bm, c, (0.066, 0.026, 0.048), tilt, 0.003)                                     # briefcase
    limb(bm, c + tilt.to_3x3() @ V(-0.010, 0, 0.026), c + tilt.to_3x3() @ V(0.010, 0, 0.026), 0.003, 0.003)  # handle
    cube(bm, c + tilt.to_3x3() @ V(0.003, -0.014, 0.002), (0.046, 0.005, 0.052), tilt @ ry(-6), 0.0015)  # clipboard
    cube(bm, c + tilt.to_3x3() @ V(0.003, -0.017, 0.026), (0.016, 0.005, 0.008), tilt, 0.0012)         # its clip
    for xs in (-0.018, 0.019):                                                          # two straps round it
        cube(bm, c + tilt.to_3x3() @ V(xs, -0.002, 0), (0.006, 0.036, 0.052), tilt, 0.0012)
    ell(bm, c + tilt.to_3x3() @ V(0.0, -0.018, -0.008), (0.010, 0.005, 0.010), tilt)   # timer dial
    for xs in (-0.008, 0.008):
        ell(bm, c + tilt.to_3x3() @ V(xs, -0.018, 0.003), (0.0042, 0.004, 0.0042), tilt)  # its two bells
    MUZZLES["compliance_officer"] = tuple(c + V(-0.02, 0, 0))


def co_cab(bm):
    helmet(bm, V(*CO["head"]) + V(0, 0.002, 0.006), 0.023, rx(-14))


# ---------------------------------------------------------------- senior asset: big, riot shield, rubber stamp mace
SS = 1.45
SA = dict(hip=(0, 0.004, 0.073), chest=(0, 0.0, 0.106), head=(0, -0.004, 0.135), nose=(0, -1, 0),
          r_shoulder=(-0.027, 0.002, 0.118), r_elbow=(-0.037, 0.006, 0.134), r_hand=(-0.030, -0.002, 0.150),
          l_shoulder=(0.027, -0.002, 0.118), l_elbow=(0.031, -0.020, 0.098), l_hand=(0.014, -0.031, 0.094),
          r_hip=(-0.013, 0.004, 0.069), r_knee=(-0.020, 0.008, 0.043), r_ankle=(-0.022, 0.010, 0.017), r_toe=(-0.024, -0.004, 0.012),
          l_hip=(0.013, 0.0, 0.069), l_knee=(0.019, -0.008, 0.043), l_ankle=(0.021, -0.012, 0.017), l_toe=(0.022, -0.026, 0.012))


def shield(bm, c, w, h, t, bend):
    # A curved riot shield: a bent bevelled slab with a raised rim and a view slot ridge.
    part = bmesh.new(); box(part, (-w / 2, -t / 2, -h / 2), (w / 2, t / 2, h / 2), t * 0.45, 2)
    bmesh.ops.subdivide_edges(part, edges=[e for e in part.edges if abs(e.verts[0].co.x - e.verts[1].co.x) > w * 0.5],
                              cuts=8, use_grid_fill=True)
    for v in part.verts:
        v.co.y += (v.co.x / (w / 2)) ** 2 * bend
    merge(bm, part, at(*c))
    for z in (-h / 2 + t * 0.6, h / 2 - t * 0.6):     # top + bottom rim
        rim = bmesh.new(); box(rim, (-w / 2, -t, -t * 0.6), (w / 2, t * 0.2, t * 0.6), t * 0.4, 2)
        bmesh.ops.subdivide_edges(rim, edges=[e for e in rim.edges if abs(e.verts[0].co.x - e.verts[1].co.x) > w * 0.5], cuts=8)
        for v in rim.verts:
            v.co.y += (v.co.x / (w / 2)) ** 2 * bend
        merge(bm, rim, at(c[0], c[1], c[2] + z))
    slot = bmesh.new(); box(slot, (-w * 0.32, -t * 1.1, -t * 0.7), (w * 0.32, 0, t * 0.7), t * 0.4, 2)
    merge(bm, slot, at(c[0], c[1] - t * 0.1, c[2] + h * 0.27))


def sa_body(bm):
    base(bm, 0.115, 0.115, 3, shape=6)
    man(bm, SA, 1.4, 1.45)
    for x in (-1, 1):
        ell(bm, (0.024 * x, 0.0, 0.121), (0.013, 0.014, 0.008), ry(-20 * x))            # shoulder pads
    shield(bm, (0.006, -0.040, 0.082), 0.074, 0.088, 0.0055, 0.014)
    h = V(*SA["r_hand"])
    # the giant rubber stamp held up like a hammer: knob in the fist, big flat block on top (reads from above)
    ell(bm, h + V(0, 0.002, -0.006), (0.0075, 0.0075, 0.0065))                          # knob
    limb(bm, h + V(0, 0.002, -0.004), h + V(0, -0.002, 0.020), 0.0042, 0.0042)       # handle
    cube(bm, h + V(0, -0.003, 0.026), (0.038, 0.028, 0.013), bevel=0.0025)             # stamp block
    cube(bm, h + V(0, -0.003, 0.035), (0.041, 0.031, 0.006), bevel=0.0015)             # rubber face


def sa_cab(bm):
    helmet(bm, V(*SA["head"]) + V(0, 0.001, 0.0065), 0.024, I)


def scaled_fn(fn, k):
    def f(bm):
        part = bmesh.new(); n0 = len(VEINS); fn(part)
        VEINS[n0:] = [(a * k, b * k) for a, b in VEINS[n0:]]
        bmesh.ops.scale(part, vec=(k, k, k), verts=part.verts)
        merge(bm, part)
    return f


# ---------------------------------------------------------------- pult crew: kneeling at a small cabbage catapult
FX, CX = -0.030, 0.026
PC = dict(hip=(FX, 0.004, 0.052), chest=(FX + 0.002, -0.002, 0.084), head=(FX + 0.004, -0.005, 0.112), nose=(0.35, -1, 0),
          r_shoulder=(FX - 0.019, 0.0, 0.096), r_elbow=(FX - 0.026, -0.010, 0.076), r_hand=(FX - 0.018, -0.022, 0.070),
          l_shoulder=(FX + 0.020, -0.004, 0.096), l_elbow=(FX + 0.034, 0.004, 0.080), l_hand=(CX - 0.021, 0.014, 0.068),
          r_hip=(FX - 0.010, 0.006, 0.048), r_knee=(FX - 0.012, 0.024, 0.014), r_ankle=(FX - 0.013, 0.044, 0.016), r_toe=(FX - 0.013, 0.052, 0.010),
          l_hip=(FX + 0.010, 0.0, 0.048), l_knee=(FX + 0.013, -0.022, 0.050), l_ankle=(FX + 0.014, -0.024, 0.016), l_toe=(FX + 0.015, -0.040, 0.012))
PIVOT = V(CX, 0.010, 0.026)
CUP = V(CX, 0.050, 0.030)


def pc_body(bm):
    base(bm, 0.17, 0.12, 4, shape=8)
    man(bm, PC)
    for x in (-0.016, 0.016):                                                           # sled rails
        cube(bm, (CX + x, 0.004, 0.0135), (0.006, 0.090, 0.010), bevel=0.0015)
        for y in (-0.034, 0.040):                                                       # wheels
            cone(bm, (CX + x * 1.35, y, 0.016), (CX + x * 1.7, y, 0.016), 0.0085, 0.0085, 14)
    for y in (-0.030, 0.042):
        cube(bm, (CX, y, 0.0135), (0.034, 0.006, 0.006), bevel=0.0012)                  # cross ties
    for x in (-0.016, 0.016):                                                           # A-frame uprights
        limb(bm, (CX + x, -0.024, 0.016), (CX + x * 0.8, -0.010, 0.060), 0.0042, 0.0042)
        limb(bm, (CX + x, 0.012, 0.016), (CX + x * 0.8, -0.010, 0.060), 0.0042, 0.0042)
    limb(bm, (CX - 0.014, -0.010, 0.060), (CX + 0.014, -0.010, 0.060), 0.0045, 0.0045)  # padded stop bar
    limb(bm, (CX - 0.017, PIVOT.y, PIVOT.z), (CX + 0.017, PIVOT.y, PIVOT.z), 0.0035, 0.0035)  # axle
    limb(bm, PIVOT + V(0, -0.006, 0), CUP + V(0, -0.006, 0), 0.0045, 0.0045)           # throwing arm, cocked back
    cone(bm, CUP + V(0, 0, -0.006), CUP + V(0, 0, 0.004), 0.004, 0.0105, 14)            # cup
    limb(bm, (CX - 0.017, 0.016, 0.016), (CX - 0.021, 0.014, 0.064), 0.0034, 0.0034)   # release lever
    ell(bm, (CX - 0.021, 0.014, 0.066), (0.0045,) * 3)
    MUZZLES["pult_crew"] = tuple(CUP + V(0, 0, 0.012))


def pc_cab(bm):
    helmet(bm, V(*PC["head"]) + V(0, 0.001, 0.006), 0.023, rz(-15))
    ammo(bm, CUP + V(0, 0, 0.006), 0.0085)                                              # loaded cabbage
    ammo(bm, V(*PC["r_hand"]) + V(0, -0.004, 0.004), 0.0065)                            # spare in the hand
    for i, p in enumerate(((CX + 0.045, 0.040, 0.0145), (CX + 0.045, 0.054, 0.0145), (CX + 0.052, 0.047, 0.0215))):
        ammo(bm, p, 0.0065)                                                              # small stack on the base



# ---------------------------------------------------------------- painted accents (2026-11-15)
# Like hand-painted toy soldiers: the body stays toy-green plastic, the helmet fresh cabbage green, and a few
# small, muted parts get their real colours so each type reads apart from the map camera. sRGB.
STOCK = (0.76, 0.67, 0.50)      # pale cream wood
GUN = (0.13, 0.14, 0.13)        # dark gunmetal / black plastic
TYRE = (0.07, 0.07, 0.075)
STEEL = (0.50, 0.52, 0.53)      # dull grey steel
WOOD = (0.46, 0.32, 0.20)       # brown wood
LEATHER = (0.40, 0.26, 0.16)
INK = (0.36, 0.11, 0.09)        # stamp-pad oxblood, muted
TIE = (0.11, 0.11, 0.14)
ROPE = (0.21, 0.17, 0.12)
CARD = (0.60, 0.46, 0.29)       # cardboard


def seg_d(p, a, b):
    a, b = Vector(a), Vector(b); ab = b - a
    u = max(0.0, min(1.0, (p - a).dot(ab) / ab.length_squared))
    return (p - (a + ab * u)).length


def in_box(p, c, half):
    return all(abs(p[i] - c[i]) < half[i] for i in range(3))


def fa_accent(co):
    if min((co - V(*FA[h])).length for h in ("r_hand", "l_hand")) < 0.0085:
        return None
    x, z = -0.011, 0.122
    if co.y < -0.036 and seg_d(co, (x, -0.036, z + 0.001), (x, RIFLE_Y, z + 0.001)) < 0.013:
        return GUN                                                  # barrel + launcher cup
    if abs(co.x - x) < 0.0065 and z - 0.011 < co.z < z + 0.0075 and -0.036 < co.y < 0.019:
        return STOCK                                                # cream stock + fore-end
    return None


def sa_accent(co):
    p = co / SS
    h = V(*SA["r_hand"])
    if p.z > h.z + 0.031 and in_box(p, h + V(0, -0.003, 0.035), (0.022, 0.017, 0.006)):
        return INK                                                  # the stamp's rubber face (on top)
    if in_box(p, h + V(0, -0.003, 0.026), (0.020, 0.015, 0.0075)):
        return WOOD                                                 # stamp block
    if (p - h).length > 0.0085 and seg_d(p, h + V(0, 0.002, -0.004), h + V(0, -0.002, 0.020)) < 0.0058:
        return WOOD                                                 # handle
    if abs(p.x - 0.006) < 0.039 and p.y < -0.026 and 0.035 < p.z < 0.130:   # the riot shield
        if p.z > 0.1185 or p.z < 0.0455:
            return LEATHER                                          # leather-bound top + bottom rims
        if abs(p.z - 0.1058) < 0.0042 and abs(p.x - 0.006) < 0.025 and p.y < -0.040:
            return GUN                                              # view slot
        return None
    if abs(p.x) < 0.0038 and -0.026 < p.y < -0.010 and 0.093 < p.z < 0.117:
        return TIE
    return None


def pc_accent(co):
    if co.z <= 0.0085 or seg_d(co, PC["l_elbow"], PC["l_hand"]) < 0.0115 or (co - V(*PC["l_hand"])).length < 0.0105:
        return None
    for y in (-0.034, 0.040):                                       # wheels
        if (Vector((co.y, co.z)) - Vector((y, 0.016))).length < 0.0098 and 0.019 < abs(co.x - CX) < 0.032:
            return TYRE
    if (co - CUP).length < 0.0135:
        return ROPE                                                 # the sling cup
    if co.x > CX - 0.0195:
        return WOOD                                                 # the catapult
    return None

GAP = 0.24
objs = [
    figure("FieldAssociate", fa_body, fa_cab, 0.0016, -0.004, -1.5 * GAP, accent=fa_accent),
    figure("ComplianceOfficer", co_body, co_cab, 0.0016, 0.0, -0.5 * GAP),
    figure("SeniorAsset", scaled_fn(sa_body, SS), scaled_fn(sa_cab, SS), 0.0016 * SS, 0.0, 0.5 * GAP, 2600, 1100, sa_accent),
    figure("PultCrew", pc_body, pc_cab, 0.0016, FX, 1.5 * GAP, 2600, 1300, pc_accent),
]
MUZZLES["senior_asset"] = tuple(v * SS for v in (V(*SA["r_hand"]) + V(0, -0.003, 0.039)))
for k, (x, y, z) in MUZZLES.items():
    print("MUZZLE", k, "godot", (round(x, 4), round(z, 4), round(-y, 4)))

# 0.2 m grid cells under each figure for scale (a war map cell is about 0.2 m).
cells = bmesh.new()
for o in objs:
    x0 = o.location.x
    for (a, b) in (((-0.1, -0.1), (0.1, -0.098)), ((-0.1, 0.098), (0.1, 0.1)), ((-0.1, -0.1), (-0.098, 0.1)), ((0.098, -0.1), (0.1, 0.1))):
        box(cells, (x0 + a[0], a[1], 0.0), (x0 + b[0], b[1], 0.0005), 0, 1)
finish("Cells-noimp", cells, [material("cell", (0.08, 0.08, 0.08), 0, 0.9)])

FRAME = ((0.0, -1.05, 0.55), (0.0, 0.0, 0.07), 50, 1600, 700)
