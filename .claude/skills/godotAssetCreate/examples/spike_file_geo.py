# Spike file: a heavy bakelite-weighted base and a steel spike that approved cards are pushed onto.
# Blender Z-up. Origin: floor centre.
ASSET = "spike_file"
bm = bmesh.new()
spin(bm, [(0, 0), (0.06, 0), (0.062, 0.008), (0.056, 0.02), (0.016, 0.028), (0, 0.028)], E, I, 32)
spin(bm, [(0, 0.022), (0.011, 0.022), (0.011, 0.036), (0, 0.036)], H, I, 16)
spin(bm, [(0, 0.034), (0.0065, 0.034), (0.0055, 0.2), (0, 0.245)], H, I, 10)
ob = finish("spike_file", bm, [paint, metal])
colourise(ob)
FRAME = ((0.0, -0.4, 0.35), (0.0, 0.0, 0.08), 50, 960, 960)
