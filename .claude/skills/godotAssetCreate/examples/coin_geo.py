# Project Cabbage coin: a chunky stamped "unit token", radius 0.042, thickness 0.014.
# Lathed with a raised rim and recessed field on both faces; origin at its centre (it spins
# and stacks). UVs: top projection, the face fills the UV square (coin_tex.py draws the stamp).
# Preview only: a small pile of -noimp copies beside it.
import random
random.seed(5)
ASSET = "coin"
R, H = 0.042, 0.014
gold = material("coin", (1, 1, 1), 1.0, 0.35)
textured(gold, "coin", 1.0)

bm = bmesh.new()
h = H / 2
profile = [(0, -h + 0.0015), (R * 0.8, -h + 0.0015), (R * 0.83, -h), (R * 0.94, -h), (R, -h + 0.0018),
           (R, h - 0.0018), (R * 0.94, h), (R * 0.83, h), (R * 0.8, h - 0.0015), (0, h - 0.0015)]
spin(bm, profile, 0, I, 24)
ob = finish("coin", bm, [gold])
uv = ob.data.uv_layers["UVMap"]
for loop in ob.data.loops:
    co = ob.data.vertices[loop.vertex_index].co
    uv.data[loop.index].uv = (co.x / (2 * R) + 0.5, co.y / (2 * R) + 0.5)

# Preview pile: a loose heap of copies.
for i in range(28):
    c = ob.copy(); c.name = "pile%d-noimp" % i
    bpy.context.scene.collection.objects.link(c)
    a = random.random() * math.tau; d = random.random() ** 0.7 * 0.12
    layer = int((0.12 - d) / 0.035)
    c.location = (0.2 + math.cos(a) * d, math.sin(a) * d, h + layer * H * 0.95)
    c.rotation_euler = (random.uniform(-0.15, 0.15), random.uniform(-0.15, 0.15), random.random() * math.tau)
ob.location = (-0.12, -0.05, R)
ob.rotation_euler = (math.radians(70), 0, math.radians(20))
FRAME = ((0.05, -0.55, 0.55), (0.08, 0.0, 0.02), 50, 1280, 900)
