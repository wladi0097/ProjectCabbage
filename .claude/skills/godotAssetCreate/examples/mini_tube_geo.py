# Project Cabbage mini tube fittings (desk cards mini_tube, tube_lever), for the desk variant
# table_tube.blend: the tube runs hidden under the desk; minis drop into the square intake well right
# of the mat, above the feeder ramp, come up in the trench routed from the mat's notch to the desk's back edge and roll
# under its flush glass lid out toward the window gap. This file: the steel trims, the glass lid, the
# intake name plate and the lever.
# Left of the waste bin: a points lever on a small enamel pedestal, swinging in the plane facing the game
# camera between SALES (right), SPLIT and RESEARCH (left), over a dark quadrant gate.
# Prepend blender_lib.py + desk_vc_common.py.
# Built in Godot world space (one fixed scene): origin = world origin, Godot (x, y, z) = Blender (x, -z, y).
# Objects: mini_tube (static: paint, metal, glass), Lever (origin at its pivot: paint, metal).
ASSET = "mini_tube"
G_, S_, Q_, W_ = 7, 8, 9, 10            # pane glass, dull steel (matte under the desk lamp), pipe glass, pale block floor
COLOURS.update({G_: (1, 1, 1), S_: (0.26, 0.27, 0.27), Q_: (1, 1, 1), W_: (0.42, 0.45, 0.42)})
SURFACE.update({G_: 2, S_: 1, Q_: 3, W_: 0})
pipe_glass = material("tube_pipe_glass", (0.6, 0.66, 0.66), 0.0, 0.05)
pipe_glass.surface_render_method = "BLENDED"
pipe_glass.node_tree.nodes["Principled BSDF"].inputs["Alpha"].default_value = 0.2
glass = material("tube_glass", (0.3, 0.33, 0.33), 0.0, 0.05)
glass.surface_render_method = "BLENDED"
glass.node_tree.nodes["Principled BSDF"].inputs["Alpha"].default_value = 0.12


def gv(x, y, z): return Vector((x, -z, y))
def g2b(v): return gv(v.x, v.y, v.z)


def gbox(bm, a, b, bevel, mat):
    """part_box between two Godot-space corners given in any order."""
    a, b = gv(*a), gv(*b)
    part_box(bm, tuple(map(min, a, b)), tuple(map(max, a, b)), bevel, mat)


DESK = 0.75
EXIT_X, Z0, Z1, HALF = 0.48, -0.53, -0.75, 0.115   # trench in table_tube.blend: x, from z, to the desk's back edge, half width
INTAKE = Vector((1.99, DESK, -0.07))              # Godot, centre of the intake well (half size WELL): right of the mat, above the feeder ramp
WELL = 0.11
TRIM = 0.014


def frame(bm, x0, z0, x1, z1, mat=None):
    """A flush matte steel trim frame round an opening (Godot x/z), proud of the desk by 3 mm."""
    for a, b in (((x0 - TRIM, z0 - TRIM), (x1 + TRIM, z0)), ((x0 - TRIM, z1), (x1 + TRIM, z1 + TRIM)),
                 ((x0 - TRIM, z0), (x0, z1)), ((x1, z0), (x1 + TRIM, z1))):
        gbox(bm, (a[0], DESK - 0.01, a[1]), (b[0], DESK + 0.003, b[1]), 0.0015, S_ if mat is None else mat)


bm = bmesh.new()
# The trench: a pale enamel block set into the desk's cutout, a round glass pipe through it (steel
# rims where it enters and leaves, a saddle clamp between), and over it all a flush glass pane in a
# trim frame. Open at the back, where the minis hop out to the window.
FLOOR, YP, RP, RPI = DESK - 0.198, 0.655, 0.097, 0.09    # block floor, pipe centre height, pipe outer / inner radius
BW = 0.006                                                # block wall thickness
gbox(bm, (EXIT_X - HALF, FLOOR, Z1), (EXIT_X + HALF, FLOOR + 0.006, Z0), 0.0, W_)                       # lit floor
for x0, x1 in ((EXIT_X - HALF, EXIT_X - HALF + BW), (EXIT_X + HALF - BW, EXIT_X + HALF)):
    gbox(bm, (x0, FLOOR, Z1), (x1, DESK - 0.006, Z0), 0.0, W_)                                         # side walls
gbox(bm, (EXIT_X - HALF, FLOOR, Z0), (EXIT_X + HALF, DESK - 0.006, Z0 + BW), 0.0, W_)                    # front wall
L = Z0 - Z1
merge(bm, lathed([(RP, 0), (RP, L), (RPI, L), (RPI, 0), (RP, 0)], 32), at(*gv(EXIT_X, YP, Z0)), Q_)     # pipe (along -z)
for z, w in ((Z0, 0.018), (Z1 + 0.018, 0.018), ((Z0 + Z1) / 2 + 0.008, 0.016)):
    merge(bm, lathed([(RP - 0.002, 0), (RP + 0.008, 0), (RP + 0.011, 0.004), (RP + 0.011, w - 0.004), (RP + 0.008, w), (RP - 0.002, w), (RP - 0.002, 0)], 32),
          at(*gv(EXIT_X, YP, z)), S_)                                                                    # rims, clamp band (matte)
zc = (Z0 + Z1) / 2
gbox(bm, (EXIT_X - 0.03, FLOOR, zc + 0.01), (EXIT_X + 0.03, YP - RP + 0.004, zc - 0.01), 0.002, S_)      # clamp foot
frame(bm, EXIT_X - HALF, Z1, EXIT_X + HALF, Z0, H)
gbox(bm, (EXIT_X - HALF, DESK - 0.004, Z1), (EXIT_X + HALF, DESK + 0.001, Z0), 0.0, G_)                 # pane
# Intake: the well's trim (no plate: the ramp hides the desk in front of it).
frame(bm, INTAKE.x - WELL, INTAKE.z - WELL, INTAKE.x + WELL, INTAKE.z + WELL)

# Points lever on a pedestal at the desk's front edge, left of the waste bin; its swing plane faces the game camera.
CAM = Vector((0.25, 3.2, 1.6))
CAM_UP = Vector((0.0, 0.4826, -0.8758))
PIVOT = Vector((0.58, DESK + 0.075, 1.16))         # on the desk strip below the mat, left of the waste bin
TOWARD = (CAM - PIVOT).normalized()
ARMDIR = (CAM_UP - TOWARD * CAM_UP.dot(TOWARD)).normalized()   # "up" on screen
LEVER_AXIS = TOWARD if TOWARD.cross(ARMDIR).x > 0 else -TOWARD  # positive turn = screen right
RIGHT = LEVER_AXIS.cross(ARMDIR)
SWING, ARM = 38.0, 0.15
gbox(bm, (PIVOT.x - 0.07, DESK, PIVOT.z - 0.05), (PIVOT.x + 0.07, DESK + 0.03, PIVOT.z + 0.05), 0.008, E)      # foot
gbox(bm, (PIVOT.x - 0.03, DESK + 0.02, PIVOT.z - 0.03), (PIVOT.x + 0.03, PIVOT.y + 0.01, PIVOT.z + 0.01), 0.006, E)  # post
gate = bmesh.new()
back = PIVOT - TOWARD * 0.012
vs = [gate.verts.new(g2b(back))]
for k in range(13):
    a = math.radians(-SWING - 10 + (2 * SWING + 20) * k / 12)
    vs.append(gate.verts.new(g2b(back + (ARMDIR * math.cos(a) + RIGHT * math.sin(a)) * (ARM + 0.05))))
for k in range(1, 13):
    gate.faces.new((vs[0], vs[k], vs[k + 1]))
geom = bmesh.ops.extrude_face_region(gate, geom=list(gate.faces))
bmesh.ops.translate(gate, verts=[v for v in geom["geom"] if isinstance(v, bmesh.types.BMVert)], vec=g2b(-TOWARD * 0.012))
merge(bm, gate, I, K)
for a in (-SWING, 0.0, SWING):
    r = math.radians(a)
    d = ARMDIR * math.cos(r) + RIGHT * math.sin(r)
    c = back + TOWARD * 0.003 + d * (ARM + 0.03)
    rod(bm, g2b(c - d * 0.014), g2b(c + d * 0.014), 0.006, P, I, 8)
ob = finish("mini_tube", bm, [paint, metal, glass, pipe_glass])
colourise(ob)

lv = bmesh.new()
rod(lv, g2b(PIVOT - TOWARD * 0.006), g2b(PIVOT + TOWARD * 0.03), 0.026, S_, I, 20)                  # hub
rod(lv, g2b(PIVOT + TOWARD * 0.015), g2b(PIVOT + TOWARD * 0.015 + ARMDIR * ARM), 0.011, S_, I, 12)  # arm
KNOB = TOWARD * 0.015 + ARMDIR * ARM
merge(lv, lathed([(0, -0.034), (0.021, -0.031), (0.034, -0.011), (0.034, 0.011), (0.021, 0.031), (0, 0.034)], 20),
      at(*g2b(PIVOT + KNOB)), K)                                                                     # bakelite knob
lo = finish("Lever", lv, [paint, metal], g2b(PIVOT))
colourise(lo)


def g(v): return "Vector3(%.4f, %.4f, %.4f)" % (v.x, v.y, v.z)
print("GODOT PIVOT", g(PIVOT), "AXIS", g(LEVER_AXIS), "KNOB", g(KNOB), "RIGHT", g(RIGHT), "TOWARD", g(TOWARD))
STATES = {}
FRAME = (tuple(gv(-0.2, 1.9, 1.2)), tuple(gv(-0.3, 0.8, -0.2)), 30, 1280, 960)
