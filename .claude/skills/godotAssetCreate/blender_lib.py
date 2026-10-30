# Shared Blender helpers. Prepend to an asset script:
#   cat blender_lib.py <asset>_geo.py preview.py > build.py
#   blender.exe -b --factory-startup -P build.py -- <abs .blend path> <abs png dir>
import bpy, bmesh, math, os, sys
from mathutils import Vector, Matrix

OUT = sys.argv[sys.argv.index("--") + 1]
PNG = sys.argv[sys.argv.index("--") + 2]
TEX = os.environ.get("TEX", "C:/Users/wladi/Desktop/ProjectCabbage/assets/textures/")
UP = Matrix.Rotation(math.radians(90), 4, "X")
I = Matrix.Identity(4)

bpy.ops.wm.read_homefile(use_empty=True, use_factory_startup=True)


def material(name, rgb, metallic, rough):
    m = bpy.data.materials.new(name)
    m.diffuse_color = (*rgb, 1)
    m.use_nodes = True
    p = m.node_tree.nodes["Principled BSDF"]
    p.inputs["Base Color"].default_value = (*rgb, 1)
    p.inputs["Metallic"].default_value = metallic
    p.inputs["Roughness"].default_value = rough
    return m


def emissive(name, rgb, strength, base=None):
    m = material(name, base or rgb, 0.0, 0.2)
    p = m.node_tree.nodes["Principled BSDF"]
    p.inputs["Emission Color"].default_value = (*rgb, 1)
    p.inputs["Emission Strength"].default_value = strength
    return m


def textured(m, name, scale, tint=(1, 1, 1)):
    """Wire assets/textures/<name>/<name>_albedo|normal|orm.png into m (UV1 only)."""
    nt = m.node_tree; p = nt.nodes["Principled BSDF"]
    uv = nt.nodes.new("ShaderNodeTexCoord"); mp = nt.nodes.new("ShaderNodeMapping")
    mp.inputs["Scale"].default_value = (scale, scale, scale)
    nt.links.new(uv.outputs["UV"], mp.inputs["Vector"])
    def img(kind, data):
        t = nt.nodes.new("ShaderNodeTexImage"); t.image = bpy.data.images.load(TEX + name + "/" + name + "_" + kind + ".png")
        if data: t.image.colorspace_settings.name = "Non-Color"
        nt.links.new(mp.outputs["Vector"], t.inputs["Vector"]); return t
    mix = nt.nodes.new("ShaderNodeMix"); mix.data_type = "RGBA"; mix.blend_type = "MULTIPLY"
    mix.inputs["Factor"].default_value = 1; mix.inputs["B"].default_value = (*tint, 1)
    nt.links.new(img("albedo", False).outputs["Color"], mix.inputs["A"])
    nt.links.new(mix.outputs["Result"], p.inputs["Base Color"])
    orm = nt.nodes.new("ShaderNodeSeparateColor"); nt.links.new(img("orm", True).outputs["Color"], orm.inputs["Color"])
    nt.links.new(orm.outputs[1], p.inputs["Roughness"]); nt.links.new(orm.outputs[2], p.inputs["Metallic"])
    nm = nt.nodes.new("ShaderNodeNormalMap"); nt.links.new(img("normal", True).outputs["Color"], nm.inputs["Color"])
    nt.links.new(nm.outputs["Normal"], p.inputs["Normal"])


def at(x, y, z):
    return Matrix.Translation((x, y, z))


def box(bm, lo, hi, bevel, segments=3):
    geom = bmesh.ops.create_cube(bm, size=1.0)["verts"]
    size = Vector(hi) - Vector(lo)
    center = (Vector(hi) + Vector(lo)) / 2
    bmesh.ops.transform(bm, matrix=Matrix.Translation(center) @ Matrix.Diagonal((*size, 1)), verts=geom)
    if bevel > 0:
        edges = list({e for v in geom for e in v.link_edges})
        bmesh.ops.bevel(bm, geom=geom + edges, offset=bevel, segments=segments, profile=0.5, affect="EDGES")


def lathe(bm, profile, steps=48):
    # profile: (radius, y) points, revolved around the Y axis. Lathe cups as a
    # closed profile (outside, rim, inside, back to the axis) or Godot culls them.
    verts = [bm.verts.new((r, y, 0)) for r, y in profile]
    edges = [bm.edges.new((verts[i], verts[i + 1])) for i in range(len(verts) - 1)]
    bmesh.ops.spin(bm, geom=verts + edges, cent=(0, 0, 0), axis=(0, 1, 0),
            angle=math.tau, steps=steps, use_merge=True)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-6)


def boxed(lo, hi, bevel):
    part = bmesh.new(); box(part, lo, hi, bevel); return part


def lathed(profile, steps):
    part = bmesh.new(); lathe(part, profile, steps); return part


def tube(points, radius, sides=10, caps=True):
    part = bmesh.new()
    pts = [Vector(p) for p in points]
    rings = []
    n = None
    for i, p in enumerate(pts):
        t = (pts[min(i + 1, len(pts) - 1)] - pts[max(i - 1, 0)]).normalized()
        if n is None:
            ref = Vector((0, 0, 1)) if abs(t.z) < 0.9 else Vector((1, 0, 0))
            n = t.cross(ref).normalized()
        else:
            n = (n - t * n.dot(t)).normalized()
        b = t.cross(n)
        rings.append([part.verts.new(p + (n * math.cos(k * math.tau / sides) + b * math.sin(k * math.tau / sides)) * radius) for k in range(sides)])
    for r0, r1 in zip(rings, rings[1:]):
        for k in range(sides):
            part.faces.new((r0[k], r0[(k + 1) % sides], r1[(k + 1) % sides], r1[k]))
    if caps:
        part.faces.new(list(reversed(rings[0])))
        part.faces.new(rings[-1])
    return part


def merge(bm, part, matrix=I, material_index=0):
    bmesh.ops.transform(part, matrix=matrix, verts=part.verts)
    for f in part.faces:
        f.material_index = material_index
    me = bpy.data.meshes.new("tmp")
    part.to_mesh(me); part.free()
    bm.from_mesh(me)
    bpy.data.meshes.remove(me)


def part_box(bm, lo, hi, bevel, mat, M=I):
    merge(bm, boxed(lo, hi, bevel), M, mat)


def spin(bm, profile, mat, M=I, steps=48):
    """Lathe around world Z (upright)."""
    merge(bm, lathed(list(profile), steps), M @ UP, mat)


def rod(bm, a, b, r, mat, M=I, sides=16):
    merge(bm, tube([a, b], r, sides), M, mat)


def finish(name, bm, mats, origin=(0, 0, 0)):
    """Sharp edges > 35 deg, WeightedNormal, box-projected UVs at 1 unit = 1 m."""
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    for e in bm.edges:
        if len(e.link_faces) == 2 and e.calc_face_angle(0) > math.radians(35):
            e.smooth = False
    uv = bm.loops.layers.uv.get("UVMap") or bm.loops.layers.uv.new("UVMap")
    for f in bm.faces:
        f.smooth = True
        axis = max(range(3), key=lambda i: abs(f.normal[i]))
        a, b = [i for i in range(3) if i != axis]
        for loop in f.loops:
            loop[uv].uv = (loop.vert.co[a], loop.vert.co[b])
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me); bm.free()
    me.transform(Matrix.Translation(-Vector(origin)))
    for m in mats:
        me.materials.append(m)
    ob = bpy.data.objects.new(name, me)
    ob.location = origin
    bpy.context.scene.collection.objects.link(ob)
    wn = ob.modifiers.new("WeightedNormal", "WEIGHTED_NORMAL")
    wn.keep_sharp = True
    wn.weight = 100
    return ob


def boolean(target, cutter_bm):
    """Exact boolean difference. The cutter needs recalc_face_normals or the cut silently fails."""
    bmesh.ops.recalc_face_normals(cutter_bm, faces=cutter_bm.faces)
    me = bpy.data.meshes.new("cutter"); cutter_bm.to_mesh(me); cutter_bm.free()
    cutter = bpy.data.objects.new("Cutter", me); bpy.context.scene.collection.objects.link(cutter)
    cutter.location = target.location
    for m in list(target.modifiers):
        target.modifiers.remove(m)
    mod = target.modifiers.new("Cut", "BOOLEAN"); mod.operation = "DIFFERENCE"; mod.object = cutter; mod.solver = "EXACT"
    with bpy.context.temp_override(object=target, active_object=target):
        bpy.ops.object.modifier_apply(modifier=mod.name)
    bpy.data.objects.remove(cutter)


def absorb(bm, ob):
    """Pull a finished object (e.g. after boolean) back into a bmesh. It keeps its UVMap."""
    me = ob.data.copy(); me.transform(ob.matrix_basis)
    bm.from_mesh(me)
    bpy.data.meshes.remove(me); bpy.data.objects.remove(ob)


def rig(name, parts, mats, origin=(0, 0, 0)):
    """One skinned mesh for moving parts. parts: [(bone, pivot, bmesh)], rigid weights."""
    bm = bmesh.new()
    for index, (_bone, _pivot, part) in enumerate(parts):
        me = bpy.data.meshes.new("part"); part.to_mesh(me); part.free()
        first = len(bm.verts)
        bm.from_mesh(me); bpy.data.meshes.remove(me)
        deform = bm.verts.layers.deform.verify()
        bm.verts.ensure_lookup_table()
        for v in bm.verts[first:]:
            v[deform][index] = 1.0
    bmesh.ops.translate(bm, verts=bm.verts, vec=-Vector(origin))
    ob = finish(name, bm, mats)
    for bone, _pivot, _part in parts:
        ob.vertex_groups.new(name=bone)
    arm_data = bpy.data.armatures.new("Armature")
    arm = bpy.data.objects.new("Armature", arm_data); bpy.context.scene.collection.objects.link(arm)
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.mode_set(mode="EDIT")
    for bone, pivot, _part in parts:
        eb = arm_data.edit_bones.new(bone)
        eb.head = Vector(pivot) - Vector(origin); eb.tail = eb.head + Vector((0, 0, 0.1))
    bpy.ops.object.mode_set(mode="OBJECT")
    ob.parent = arm
    mod = ob.modifiers.new("Armature", "ARMATURE"); mod.object = arm
    return [ob, arm]
