# Project Cabbage: the player's hand (the 3D cursor), a cartoon clerk's glove. One skinned mesh,
# one material, colours in a vertex colour attribute (glove, suit sleeve, shirt cuff).
#   cat blender_lib.py hand_geo.py preview.py hand_save.py > build.py
# Right hand, palm down, pointing along +Y (Godot -Z, into the scene). Origin = wrist.
# Bones: Palm (root), Sleeve (shirt cuff, sleeve; rigid), <Finger>1..3 chained per finger,
# Thumb1..3. The glove is blocked out from a palm ball and finger capsules, fused into one skin
# by a voxel remesh, and weighted per finger chain (chain_weights), so knuckles bend like cloth and
# no finger drags its neighbour. Bones end up pointing +Z so Godot gets identity rests at the pivots.
ASSET = "hand"
FRAME = ((0.0, -0.30, 0.78), (0.0, 0.08, 0.24), 50, 900, 700)
LIFT = 0.25  # preview only: the armature floats above the backdrop, reset before saving

GLOVE, STITCH, SLEEVE, SHIRT = 0, 1, 2, 3
# cold grey clerk's cotton glove, (unused stitch tone), charcoal suit, white shirt cuff
COLOURS = [(0.30, 0.32, 0.32), (0.24, 0.25, 0.26), (0.06, 0.065, 0.075), (0.74, 0.75, 0.74)]
SCALE = 0.76  # built at 1.6x a real hand, shown at ~1.2x
THUMB_YAW = math.radians(40)  # thumb points forward and out to the left (-X)

# Cartoon glove: three fat fingers and a thumb, with gaps between them so the remesh keeps
# them apart.
# name, knuckle (x, y, z), segment lengths, width, thickness
FINGERS = [
    ("Index", (-0.050, 0.140, 0.005), (0.030, 0.022, 0.022), 0.040, 0.040),
    ("Middle", (0.000, 0.146, 0.004), (0.030, 0.021, 0.021), 0.040, 0.039),
    ("Ring", (0.049, 0.136, 0.002), (0.026, 0.019, 0.019), 0.038, 0.037),
]
THUMB = ("Thumb", (-0.056, 0.040, -0.006), (0.038, 0.030, 0.030), 0.044, 0.042)
VOXEL = 0.0024      # remesh size at final scale; the finger gaps are ~3 voxels
GLOVE_FACES = 1800  # after decimation (~3.6k triangles)


def capsule(y0, y1, r, flat, sides=16, cap=4):
    """Capsule along +Y from y0 to y1 (round ends reach r past both), z squashed by flat."""
    prof = [(r * math.sin(a), y0 - r * math.cos(a)) for a in (i * math.pi / 2 / cap for i in range(cap + 1))]
    prof += [(r * math.cos(a), y1 + r * math.sin(a)) for a in (i * math.pi / 2 / cap for i in range(cap + 1))]
    part = lathed(prof, sides)
    bmesh.ops.scale(part, vec=(1, 1, flat), verts=part.verts)
    return part


def segment(length, width, thick, last):
    r = width / 2
    seg = capsule(0.0, max(length - (r if last else 0.0), 0.0), r, thick / width)
    if last:  # cartoon fingertips swell a little
        for v in seg.verts:
            k = 1 + 0.10 * max(0.0, min(1.0, v.co.y / length))
            v.co.x *= k; v.co.z *= k
    return seg


def lathe_y(profile, sides=24):
    """Lathe (r, y) around +Y, closed to the axis at both ends."""
    return lathed([(0, profile[0][1])] + profile + [(0, profile[-1][1])], sides)


parts = []  # (bone, parent, head, bmesh, colour)
tails = {"Palm": Vector((0, 0.12, 0)), "Sleeve": Vector((0, -0.12, 0.05))}
chains = {}  # finger -> [(bone, head, tail, radius)] at final scale, for the weights
palm = bmesh.new()
# puffy palm: a flattened ball, narrower at the wrist, domed on the back
pb = bmesh.new()
bmesh.ops.create_uvsphere(pb, u_segments=24, v_segments=14, radius=1.0)
for v in pb.verts:
    t = (v.co.y + 1) / 2
    v.co.x *= 0.074 * (0.78 + 0.26 * t ** 1.5)
    v.co.y = 0.072 + v.co.y * 0.082
    v.co.z *= 0.034 if v.co.z > 0 else 0.028
merge(palm, pb, I, GLOVE)
# the suit sleeve runs right up to the back of the hand, a thin white shirt edge at its mouth
SLEEVE_TILT = Matrix.Rotation(math.radians(-14), 4, "X")  # a short, flat stub kept below the back of the hand
# shirt cuff and sleeve hang on their own bone, so the glove can tip without lifting the sleeve
sleeve = bmesh.new()
merge(sleeve, lathe_y([(0.054, 0.016), (0.062, 0.012), (0.063, 0.000), (0.058, -0.004)]),
        SLEEVE_TILT @ Matrix.Diagonal((1.18, 1, 0.64, 1)), SHIRT)
merge(sleeve, lathe_y([(0.056, 0.008), (0.064, 0.004), (0.068, -0.008)] + [(0.068 * math.cos(a), -0.12 - 0.045 * math.sin(a)) for a in (0, 0.5, 0.9, 1.25, 1.5)]),
        SLEEVE_TILT @ Matrix.Diagonal((1.15, 1, 0.62, 1)), SLEEVE)
parts.append(("Palm", None, (0, 0, 0), palm, GLOVE))
parts.append(("Sleeve", "Palm", (0, 0, 0), sleeve, SLEEVE))

for name, knuckle, lengths, width, thick in FINGERS + [THUMB]:
    head = Vector(knuckle)
    direction = Vector((0, 1, 0))
    yaw = Matrix.Identity(4)
    if name == "Thumb":
        yaw = Matrix.Rotation(THUMB_YAW, 4, "Z")
        direction = yaw.to_3x3() @ direction
    parent = "Palm"
    for i, length in enumerate(lengths):
        bone = "%s%d" % (name, i + 1)
        seg = segment(length, width * (1 - 0.04 * i), thick * (1 - 0.04 * i), i == len(lengths) - 1)
        bmesh.ops.transform(seg, matrix=Matrix.Translation(head) @ yaw, verts=seg.verts)
        parts.append((bone, parent, tuple(head), seg, GLOVE))
        tails[bone] = head + direction * length
        chains.setdefault(name, []).append((bone, head * SCALE, tails[bone] * SCALE, width * (1 - 0.04 * i) / 2 * SCALE))
        parent = bone
        head = head + direction * length



def apply_mod(ob, kind, **props):
    m = ob.modifiers.new(kind, kind)
    for k, v in props.items():
        setattr(m, k, v)
    with bpy.context.temp_override(object=ob, active_object=ob):
        bpy.ops.object.modifier_apply(modifier=m.name)


def paint(me, colour_of):
    """Write the Col attribute per face from colour_of(material_index)."""
    bm = bmesh.new(); bm.from_mesh(me)
    col = bm.loops.layers.color.get("Col") or bm.loops.layers.color.new("Col")
    for f in bm.faces:
        for l in f.loops:
            l[col] = (*colour_of(f.material_index), 1.0)
        f.material_index = 0
    bm.to_mesh(me); bm.free()


mat = material("hand", (1, 1, 1), 0.0, 0.7)
nt = mat.node_tree
vc = nt.nodes.new("ShaderNodeVertexColor"); vc.layer_name = "Col"
nt.links.new(vc.outputs["Color"], nt.nodes["Principled BSDF"].inputs["Base Color"])

def smooth01(e0, e1, x):
    t = min(max((x - e0) / (e1 - e0), 0.0), 1.0)
    return t * t * (3 - 2 * t)


def chain_weights(p):
    """[(bone, weight)] for a glove vertex. A vertex on a finger follows only that finger's
    bones, by its distance s along the finger, blended across each knuckle; the rest is Palm."""
    best = None
    for name, segs in chains.items():
        start = 0.0
        for k, (bone, a, b, r) in enumerate(segs):
            ab = b - a; length = ab.length
            t = (p - a).dot(ab) / (length * length)
            tc = min(max(t, 0.0), 1.0)
            gap = (p - (a + ab * tc)).length - r
            lo = -1e9 if k == 0 else 0.0  # before the knuckle counts as palm side
            hi = 1e9 if k == len(segs) - 1 else 1.0
            if best is None or gap < best[0]:
                best = (gap, name, start + min(max(t, lo), hi) * length)
            start += length
    gap, name, s = best
    if gap > 0.25 * chains[name][0][3]:
        return [("Palm", 1.0)]
    segs = chains[name]
    joints = [0.0]
    for _bone, a, b, _r in segs[:-1]:
        joints.append(joints[-1] + (b - a).length)
    blend = 0.45 * segs[0][3]
    steps = [smooth01(j - blend, j + blend, s) for j in joints]  # 1 once past each joint
    out = [("Palm", 1.0 - steps[0])]
    for k, (bone, *_rest) in enumerate(segs):
        out.append((bone, steps[k] - (steps[k + 1] if k + 1 < len(steps) else 0.0)))
    return [(bone, w) for bone, w in out if w > 1e-4]


# the glove: every part but the sleeve, fused into one skin
glove = bmesh.new()
for bone, _parent, _head, part, _colour in parts:
    if bone != "Sleeve":
        merge(glove, part, Matrix.Diagonal((SCALE, SCALE, SCALE, 1)))
gob = finish("Hand", glove, [mat])
gob.modifiers.clear()
apply_mod(gob, "REMESH", mode="VOXEL", voxel_size=VOXEL)
apply_mod(gob, "SMOOTH", factor=0.6, iterations=4)
apply_mod(gob, "DECIMATE", ratio=min(1.0, GLOVE_FACES / len(gob.data.polygons)))
for poly in gob.data.polygons:
    poly.use_smooth = True
paint(gob.data, lambda _i: COLOURS[GLOVE])

# the sleeve: rigid, its own bone
sleeve_part = next(part for bone, _p, _h, part, _c in parts if bone == "Sleeve")
bmesh.ops.scale(sleeve_part, vec=(SCALE,) * 3, verts=sleeve_part.verts)
sob = finish("SleeveTmp", sleeve_part, [mat])
paint(sob.data, lambda i: COLOURS[i])
sob.vertex_groups.new(name="Sleeve").add(range(len(sob.data.vertices)), 1.0, "REPLACE")

arm_data = bpy.data.armatures.new("Armature")
arm = bpy.data.objects.new("Armature", arm_data); bpy.context.scene.collection.objects.link(arm)
bpy.context.view_layer.objects.active = arm
bpy.ops.object.mode_set(mode="EDIT")
for bone, parent, head, *_ in parts:
    eb = arm_data.edit_bones.new(bone)
    eb.head = Vector(head) * SCALE; eb.tail = tails[bone] * SCALE
    if parent:
        eb.parent = arm_data.edit_bones[parent]
bpy.ops.object.mode_set(mode="OBJECT")

groups = {bone: gob.vertex_groups.new(name=bone) for bone, *_ in parts if bone != "Sleeve"}
for v in gob.data.vertices:
    for bone, w in chain_weights(v.co):
        groups[bone].add([v.index], w, "REPLACE")
gob.parent = arm
gob.modifiers.new("Armature", "ARMATURE").object = arm

for o in bpy.context.view_layer.objects:
    o.select_set(False)
gob.select_set(True); sob.select_set(True)
bpy.context.view_layer.objects.active = gob
bpy.ops.object.join()
ob = gob
while len(ob.data.materials) > 1:
    ob.data.materials.pop()
ob.data.color_attributes.active_color_index = 0
ob.data.color_attributes.render_color_index = 0
print("GROUPS", sorted(g.name for g in ob.vertex_groups))

# bones back to +Z, so Godot's rests are identity rotations at the pivots
bpy.context.view_layer.objects.active = arm
bpy.ops.object.mode_set(mode="EDIT")
for eb in arm_data.edit_bones:
    eb.tail = eb.head + Vector((0, 0, 0.03)); eb.roll = 0
bpy.ops.object.mode_set(mode="OBJECT")
arm.location.z = LIFT

# preview only: the cabbage the hand closes on (0.27 m across)
ball = bmesh.new(); bmesh.ops.create_uvsphere(ball, u_segments=24, v_segments=12, radius=0.135)
cab = finish("Cabbage-noimp", ball, [material("cab", (0.25, 0.55, 0.18), 0.0, 0.6)])
cab.location = (0, 0.06, LIFT - 0.16); cab.hide_render = True

# Preview poses, world-space angles in degrees (curl: about X, negative = down; spread: about up).
# Copied from Godot's hand_model.gd, which holds the real table.
POSES = {
    "point": {"Index": (-12, -5, -3, 4), "Middle": (-75, -65, -35, 0), "Ring": (-75, -65, -35, -4), "Thumb": (-35, -30, -20, -40)},
    "open": {"Index": (-14, -12, -8, 16), "Middle": (-10, -12, -8, 0), "Ring": (-14, -14, -8, -16), "Thumb": (-12, -6, 0, 28)},
    "grab": {"Index": (-55, -40, -28, 12), "Middle": (-55, -40, -28, 0), "Ring": (-55, -40, -28, -12), "Thumb": (-55, -30, -20, 10)},
}


def apply(pose, pb):
    for finger, (c1, c2, c3, spread) in POSES[pose].items():
        for i, curl in enumerate((c1, c2, c3)):
            b = pb["%s%d" % (finger, i + 1)]
            b.rotation_mode = "QUATERNION"
            if finger == "Thumb":
                side = Matrix.Rotation(THUMB_YAW, 3, "Z") @ Vector((1, 0, 0))
                q = Matrix.Rotation(math.radians(curl), 3, side).to_quaternion()
                if i == 0:
                    q = Matrix.Rotation(math.radians(spread), 3, "Z").to_quaternion() @ q
            else:
                q = Matrix.Rotation(math.radians(curl), 3, "X").to_quaternion()
                if i == 0:
                    q = Matrix.Rotation(math.radians(spread), 3, "Z").to_quaternion() @ q
            rest = b.bone.matrix_local.to_quaternion()
            b.rotation_quaternion = rest.inverted() @ q @ rest
    bpy.data.objects["Cabbage-noimp"].hide_render = pose != "grab"


STATES = {tag: (lambda pb, tag=tag: apply(tag, pb)) for tag in POSES}
