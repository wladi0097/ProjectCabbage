# Generates the cabbage atlas: <out>/cabbage_albedo|normal|orm.png   (python cabbage_tex.py <out dir>)
# Layout (UV, v up): 3 rows = tint variants a/b/c (top to bottom).
# Columns per row: outer leaf [0, .42], inner leaf [.42, .84], head [.84, 1] upper 60 %,
# rim (v .5-1) / stem (v 0-.5) lower 40 %. cabbage_geo.py uses the same cells.
import numpy as np, sys
from PIL import Image, ImageFilter

N = 1024
OUT = sys.argv[1]
TINTS = [  # (leaf base, deep edge, pale crown/base, vein)   sRGB
    ((0.30, 0.62, 0.16), (0.10, 0.33, 0.07), (0.70, 0.87, 0.40), (0.84, 0.95, 0.64)),
    ((0.24, 0.54, 0.18), (0.07, 0.27, 0.09), (0.60, 0.81, 0.40), (0.78, 0.91, 0.64)),
    ((0.40, 0.68, 0.16), (0.16, 0.40, 0.06), (0.80, 0.90, 0.44), (0.90, 0.96, 0.68)),
]
alb = np.zeros((N, N, 3)); hgt = np.zeros((N, N)); ao = np.ones((N, N)); rough = np.full((N, N), 0.45)
rng = np.random.default_rng(7)


def blurred_noise(cells):
    n = rng.random((cells, cells))
    return np.array(Image.fromarray((n * 255).astype(np.uint8)).resize((N, N), Image.BICUBIC)) / 255.0


noise = blurred_noise(N // 32) * 0.65 + blurred_noise(N // 8) * 0.35


def cell(x0, x1, y0, y1):
    """Pixel slice and local coords (u in [-1,1] across, v in [0,1] up) for a UV rect."""
    c0, c1 = int(x0 * N), int(x1 * N); r0, r1 = int((1 - y1) * N), int((1 - y0) * N)
    v, u = np.mgrid[r0:r1, c0:c1].astype(float)
    u = (u - c0 + 0.5) / (c1 - c0) * 2 - 1
    v = 1 - (v - r0 + 0.5) / (r1 - r0)
    return (slice(r0, r1), slice(c0, c1)), u, v


def smooth(e0, e1, x):
    t = np.clip((x - e0) / (e1 - e0), 0, 1); return t * t * (3 - 2 * t)


def mix(a, b, t):
    return np.asarray(a) * (1 - t[..., None]) + np.asarray(b) * t[..., None]


def leaf(sl, u, v, base, deep, pale, vein, n_veins, strength, deep_amt):
    au = np.abs(u)
    mw = 0.17 * (1 - v) ** 1.3 + 0.035                       # midrib: wide and pale at the foot, thin at the tip
    mid = 1 - smooth(mw * 0.5, mw, au)
    phase = (v - 0.5 * au ** 0.7) * n_veins                 # side veins curve up toward the margin
    d = np.abs(phase - np.round(phase)) / n_veins
    vw = (0.010 + 0.016 * (1 - au)) * (1 - 0.35 * v)
    side = (1 - smooth(vw * 0.35, vw, d)) * smooth(0.0, mw * 1.2, au) * (1 - smooth(0.9, 1.0, au))
    ph2 = phase * 2 + 0.5                                   # faint secondary veins
    d2 = np.abs(ph2 - np.round(ph2)) / (n_veins * 2)
    sec = (1 - smooth(0.002, 0.007, d2)) * smooth(0.1, 0.4, au) * (1 - smooth(0.85, 1.0, au)) * 0.35
    veins = np.maximum(np.maximum(mid, side * strength), sec * strength)
    col = mix(pale, base, smooth(0.0, 0.5, v))               # pale at the foot
    col = mix(col, deep, smooth(0.25, 1.0, au * 0.7 + v * 0.45) * deep_amt)   # deeper toward margin and tip
    valley = np.sin(np.clip(np.abs(phase - np.round(phase)) * 2, 0, 1) * np.pi) * smooth(0.1, 0.5, au)
    col = col * (1 - 0.10 * valley[..., None])               # pockets between veins a bit darker
    col = mix(col, pale, smooth(0.93, 1.0, np.maximum(v, au)) * 0.25)  # light margin
    col = col * (0.92 + 0.14 * noise[sl][..., None])
    col = mix(col, vein, np.maximum(mid * 0.95, veins * 0.72))
    alb[sl] = col
    pucker = np.sin(phase * np.pi * 2) ** 2 * smooth(0.15, 0.4, au) * (1 - smooth(0.85, 1, au))
    hgt[sl] = mid * 1.4 + side * strength * 0.8 - pucker * 0.35
    ao[sl] = (0.70 + 0.30 * smooth(0.0, 0.5, v)) * (1 - 0.12 * valley)
    rough[sl] = 0.36 + 0.16 * veins + 0.06 * noise[sl]


for r, (base, deep, pale, vein) in enumerate(TINTS):
    y0, y1 = 1 - (r + 1) / 3, 1 - r / 3
    sl, u, v = cell(0.0, 0.42, y0, y1); leaf(sl, u, v, base, deep, pale, vein, 4.5, 1.0, 1.0)
    inner = tuple(0.42 * a + 0.58 * b for a, b in zip(base, pale))
    sl, u, v = cell(0.42, 0.84, y0, y1); leaf(sl, u, v, inner, base, pale, vein, 3.0, 0.8, 0.3)
    # head: paler toward the crown
    sl, u, v = cell(0.84, 1.0, y0 + (y1 - y0) * 0.4, y1)
    alb[sl] = mix(inner, pale, smooth(0.3, 1.0, v)) * (0.95 + 0.08 * noise[sl][..., None])
    ao[sl] = 0.65 + 0.35 * v
    # rim (v > .5): pale leaf edge; stem (v < .5): dark olive stump, darker cut face at the bottom
    sl, u, v = cell(0.84, 1.0, y0, y0 + (y1 - y0) * 0.4)
    rimc = mix(np.asarray(base), np.asarray(pale), np.full(v.shape, 0.25))
    stem = mix((0.10, 0.16, 0.06), (0.20, 0.30, 0.11), smooth(0.05, 0.3, v))
    alb[sl] = np.where((v > 0.5)[..., None], rimc, stem)
    rough[sl] = np.where(v > 0.5, 0.45, 0.7)

# normal map (OpenGL, +Y = up in the image) from the softened height field
h = np.array(Image.fromarray((np.clip(hgt + 0.5, 0, 2) * 100).astype(np.uint8)).filter(ImageFilter.GaussianBlur(1.5))) / 100.0
s = 2.5
gy, gx = np.gradient(h)
nx, ny = -gx * s, gy * s  # image rows grow downward, v grows upward
nz = np.ones_like(nx)
ln = np.sqrt(nx * nx + ny * ny + nz * nz)
nrm = np.stack([nx / ln, ny / ln, nz / ln], -1) * 0.5 + 0.5

Image.fromarray((np.clip(alb, 0, 1) * 255).astype(np.uint8)).save(OUT + "/cabbage_albedo.png")
Image.fromarray((nrm * 255).astype(np.uint8)).save(OUT + "/cabbage_normal.png")
Image.fromarray((np.stack([ao, rough, np.zeros_like(ao)], -1) * 255).astype(np.uint8)).save(OUT + "/cabbage_orm.png")
print("ok")
