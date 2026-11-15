# War map terrain tiles (2026-11-15): pond, river, bridge, hedge, road, field, as card / foam / balsa
# planning-model pieces and prints on the war sheet's paper. Prepend blender_lib.py, then maquette_geo.py's
# helpers (awk '/^objs = \[/{exit} {print}'), then this. Blender X = Godot +X (east), Blender +Y =
# Godot -Z (north), Z up. Every tile: origin at its cell's centre on the paper, cell 0.16 m.
# Edges and arms are built for the NORTH side (Blender +Y), corners for the north-east inner corner;
# entities/war/terrain/terrain_piece.gd turns them for the other sides. Hedge arms point east like
# the fences'. GLB=<path> exports every object; without it the mockup lays out a sample patch.
import random

H = CELL / 2
for k, v in {"water": (0.27, 0.31, 0.34), "water_rim": (0.10, 0.125, 0.14), "flock": (0.075, 0.095, 0.075)}.items():
    M[k] = material("maquette_" + k, v, 0.0, 0.8)
W, R, F, B = 5, 6, 7, 8   # extra slots: water, water rim, flock, balsa
ALL = SLOTS + [M["water"], M["water_rim"], M["flock"], M["balsa"]]


def flat(x0, y0, x1, y1, z, mat):
    """A printed patch: one face lying on the paper at height z."""
    part = bmesh.new()
    vs = [part.verts.new(v) for v in ((x0, y0, z), (x1, y0, z), (x1, y1, z), (x0, y1, z))]
    part.faces.new(vs).material_index = mat
    return part


def tile(name, parts):
    bm = bmesh.new()
    for p in parts:
        if isinstance(p, tuple):
            put(bm, p[0], p[1], p[2] if len(p) > 2 else -1)
        else:
            put(bm, p)
    return finish_maquette(name, bm, ALL)


# ---------------------------------------------------------------- pond: a blue-grey card cut-out
POND_TOP, RIM_TOP, RIM = 0.003, 0.0075, 0.018


def pond():
    marks = ripple(-0.03, 0.025, POND_TOP + 0.0004, C) + ripple(0.028, -0.032, POND_TOP + 0.0004, C)
    return [tile("PondBase", [slab((-H, -H, 0), (H, H, POND_TOP), W, E)] + marks),
            tile("PondEdge", [slab((-H, H - RIM, 0), (H, H, RIM_TOP), R, E)]),
            tile("PondCorner", [slab((H - RIM, H - RIM, 0), (H, H, RIM_TOP), R, E)])]


# ---------------------------------------------------------------- river: a card strip, banks, flow lines
RIV_TOP, BANK_TOP, BANK = 0.0025, 0.0065, 0.014
FLOW_W, FLOW_AT = 0.003, (-0.036, 0.0, 0.036)


def ripple(x, y, z, mat, size=0.016):
    """A small printed wave mark across the flow (a shallow zigzag of three strokes), pointing along +Y."""
    out = []
    pts = [(-size, 0.0), (-size / 3, 0.004), (size / 3, -0.004), (size, 0.0)]
    for (ax, ay), (bx, by) in zip(pts, pts[1:]):
        d = Vector((bx - ax, by - ay, 0))
        part = flat(0, -FLOW_W / 2, d.length + FLOW_W * 0.5, FLOW_W / 2, z, mat)
        out.append((part, at(x + ax, y + ay, 0) @ d.to_track_quat("X", "Z").to_matrix().to_4x4()))
    return out


def river():
    marks = []   # wave marks in three staggered files, always across the sheet, so every run and corner matches
    for i, x in enumerate(FLOW_AT):
        y = -H + 0.014 + 0.026 * (i % 2)
        while y < H - 0.008:
            marks += ripple(x, y, RIV_TOP + 0.0004, C)
            y += 0.052
    return [tile("RiverBase", [slab((-H, -H, 0), (H, H, RIV_TOP), W, E)] + marks),
            tile("RiverEdge", [slab((-H, H - BANK, 0), (H, H, BANK_TOP), R, E)]),
            tile("RiverCorner", [slab((H - BANK, H - BANK, 0), (H, H, BANK_TOP), R, E)])]


# ---------------------------------------------------------------- bridge: a balsa deck with rails
def bridge():
    parts = []
    span, half_w, n = 0.098, 0.044, 9
    gap = 0.0025
    depth = (2 * span - gap * (n - 1)) / n
    for x in (-0.03, 0.03):       # two stringers along the span
        parts.append((slab((x - 0.004, -span, RIV_TOP), (x + 0.004, span, 0.009), B, B), I, 1))
    for k in range(n):            # planks across, sawn ends showing
        y0 = -span + k * (depth + gap)
        parts.append((slab((-half_w, y0, 0.009), (half_w, y0 + depth, 0.0125), B, B), I, 0))
    for x in (-half_w + 0.003, half_w - 0.003):
        for y in (-0.085, 0.0, 0.085):
            parts.append((slab((x - 0.003, y - 0.003, 0.0125), (x + 0.003, y + 0.003, 0.034), B, B), I, 2))
        parts.append((slab((x - 0.0035, -0.092, 0.029), (x + 0.0035, 0.092, 0.036), B, B), I, 1))
    return [tile("BridgeDeck", parts)]


# ---------------------------------------------------------------- hedge: dark sage flock on a card strip
def lump(x0, x1, half, h, rng):
    """A strip of clump foam: a soft core along X under a row of overlapping squashed blobs, so the
    top and the sides read lumpy, not as blocks."""
    core = boxed((x0, -half * 0.85, 0.002), (x1, half * 0.85, h * 0.86), 0.005)
    out = [core]
    n = max(2, round((x1 - x0) / 0.022))
    for k in range(n):
        cx = x0 + (k + 0.5) * (x1 - x0) / n + rng.uniform(-0.003, 0.003)
        for side in (-1, 1):
            blob = bmesh.new()
            bmesh.ops.create_icosphere(blob, subdivisions=2, radius=1.0)
            r = half * rng.uniform(0.5, 0.62)
            bmesh.ops.scale(blob, vec=(r * 1.1, r, h * rng.uniform(0.3, 0.36)), verts=blob.verts)
            bmesh.ops.translate(blob, vec=(cx, side * half * 0.42 + rng.uniform(-0.002, 0.002), h * rng.uniform(0.64, 0.7)), verts=blob.verts)
            out.append(blob)
    for part in out:
        for f in part.faces:
            f.material_index = F
    return out


def hedge():
    rng = random.Random(11)
    post = [slab((-0.031, -0.031, 0), (0.031, 0.031, 0.002), C, E)] + lump(-0.028, 0.028, 0.026, 0.046, rng)
    arm = [slab((0.0, -0.028, 0), (H + 0.001, 0.028, 0.002), C, E)] + lump(0.012, H + 0.002, 0.024, 0.042, rng)
    return [tile("HedgePost", post), tile("HedgeArm", arm)]


# ---------------------------------------------------------------- prints: road and field
PRINT = 0.0003   # under the zones' hatch (0.001)
LINE, INSET = 0.0035, 0.0015


def road():
    y1 = H - INSET
    x0 = H - INSET - LINE
    return [tile("RoadBase", [flat(-H, -H, H, H, PRINT, C)]),
            tile("RoadEdge", [flat(-H, y1 - LINE, H, y1, PRINT + 0.0003, G)]),
            tile("RoadCorner", [flat(x0, y1 - LINE, H, y1, PRINT + 0.0003, G), flat(x0, y1, x0 + LINE, H, PRINT + 0.0003, G)])]


ROWS, ROW_W = 8, 0.003


def field():
    rows = []
    for k in range(ROWS):
        y = -H + (k + 0.5) * CELL / ROWS
        rows.append(flat(-H, y - ROW_W / 2, H, y + ROW_W / 2, PRINT, G))
    wash = flat(-H, -H, H, H, PRINT - 0.0001, B)   # a faint khaki wash under the crop rows
    return [tile("FieldBase", [wash] + rows)]


objs = pond() + river() + bridge() + hedge() + road() + field()
for ob in objs:
    tris = sum(len(p.vertices) - 2 for p in ob.data.polygons)
    print("TRIS_OF", ob.name, tris)
ASSET = "terrain"
GLB = os.environ.get("GLB")
if GLB:
    bpy.ops.object.select_all(action="DESELECT")
    for ob in objs:
        ob.select_set(True)
    bpy.ops.export_scene.gltf(filepath=GLB, use_selection=True, export_apply=True, export_tangents=True,
                              export_materials="EXPORT")
FRAME = ((0.3, -0.6, 0.9), (0.3, 0.2, 0.0), 50, 1400, 900)
