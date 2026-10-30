# Generate the cabbage mat (desk blotter) textures: leather field, darker bound border with
# stitching, brushed steel corner caps. Non-tiling: UV 0..1 covers the mat's bounding box.
#   python table_mat_pack.py <out dir> [field r,g,b] [band r,g,b]
import sys
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

out = sys.argv[1]
FIELD = [int(c) for c in (sys.argv[2] if len(sys.argv) > 2 else "36,47,43").split(",")]
BAND = [int(c) for c in (sys.argv[3] if len(sys.argv) > 3 else "14,15,16").split(",")]
W, H = 2.30, 1.70            # mat size in metres (must match table_geo.py)
PX, PY = 2048, 1536
R, BW = 0.025, 0.06         # outline corner radius, bound-border width
CAP = 0.13                   # steel corner cap leg length
rng = np.random.default_rng(3)

x = (np.arange(PX) + 0.5) / PX * W
y = (np.arange(PY) + 0.5) / PY * H
X, Y = np.meshgrid(x, y)     # row 0 = v 1 = back edge; layout is symmetric so it doesn't matter


def sdf(inset, r):
    qx = np.abs(X - W / 2) - (W / 2 - inset - r)
    qy = np.abs(Y - H / 2) - (H / 2 - inset - r)
    return np.hypot(np.maximum(qx, 0), np.maximum(qy, 0)) + np.minimum(np.maximum(qx, qy), 0) - r


def noise(sigma):
    # float value noise: random grid at 1/sigma resolution, bicubic upsampled (no 8-bit banding)
    g = rng.random((max(2, int(PY / sigma)), max(2, int(PX / sigma)))).astype(np.float32)
    n = np.asarray(Image.fromarray(g, "F").resize((PX, PY), Image.BICUBIC), np.float32)
    return (n - n.mean()) / (n.std() + 1e-6)


def smooth(a, s):
    return np.asarray(Image.fromarray(a.astype(np.float32)).filter(ImageFilter.GaussianBlur(s)), np.float32) if False else \
        np.asarray(Image.fromarray(np.clip(a * 255, 0, 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(s)), np.float32) / 255

band = (sdf(BW, 0.004) > 0).astype(np.float32)
band_s = smooth(band, 2.0)

# Stitches: dashes along two rounded-rect paths on the border, drawn 2x and downsampled.
SS = 2
st = Image.new("L", (PX * SS, PY * SS), 0); d = ImageDraw.Draw(st)
def path(inset, r, step=0.001):
    pts = []
    cx0, cx1, cy0, cy1 = inset + r, W - inset - r, inset + r, H - inset - r
    for (cx, cy, a0) in ((cx1, cy0, -90), (cx1, cy1, 0), (cx0, cy1, 90), (cx0, cy0, 180)):
        for k in range(13):
            a = np.radians(a0 + k * 7.5); pts.append((cx + r * np.cos(a), cy + r * np.sin(a)))
    pts.append(pts[0]); out_pts = []
    for p, q in zip(pts, pts[1:]):
        n = max(1, int(np.hypot(q[0] - p[0], q[1] - p[1]) / step))
        out_pts += [(p[0] + (q[0] - p[0]) * t / n, p[1] + (q[1] - p[1]) * t / n) for t in range(n)]
    return out_pts
for inset in (0.011, BW - 0.009):
    pts = path(inset, max(R - inset, 0.003)); s = 0.0
    for p, q in zip(pts, pts[1:]):
        s += np.hypot(q[0] - p[0], q[1] - p[1])
        if (s % 0.014) < 0.009:
            d.line([(p[0] / W * PX * SS, p[1] / H * PY * SS), (q[0] / W * PX * SS, q[1] / H * PY * SS)], fill=255, width=int(2.4 * SS))
stitch = np.asarray(st.resize((PX, PY), Image.LANCZOS), np.float32) / 255

# Steel corner caps: right triangles over each corner, rivet near the corner.
ax = np.minimum(X, W - X); ay = np.minimum(Y, H - Y)
capd = (CAP - ax - ay) / np.sqrt(2)          # >0 inside the cap, metres to the hypotenuse
cap = smooth((capd > 0).astype(np.float32), 1.0)
cap_bevel = np.clip(capd / 0.004, 0, 1)
rivet = np.clip(1 - np.hypot(ax - 0.034, ay - 0.034) / 0.0045, 0, 1)
stitch *= 1 - (capd > -0.004)                # stitches stop under the caps

# Albedo
grain = noise(2.5) * 0.5 + noise(8) * 0.5     # leather pebble (user: finer noise was too noticeable)
mottle = noise(240)
field = np.array(FIELD, np.float32) * (1 + 0.035 * grain[..., None] + 0.05 * mottle[..., None])
# a soft worn patch in the middle where the cabbages get handled
wear = np.exp(-(((X - W * 0.55) / (W * 0.33)) ** 2 + ((Y - H * 0.5) / (H * 0.35)) ** 2))
field *= (1 + 0.07 * wear)[..., None]
bandc = np.array(BAND, np.float32) * (1 + 0.06 * grain[..., None] + 0.05 * mottle[..., None])
alb = field * (1 - band_s[..., None]) + bandc * band_s[..., None]
alb *= (1 - 0.35 * np.clip(smooth((np.abs(sdf(BW, 0.004)) < 0.0015).astype(np.float32), 1.5), 0, 1))[..., None]  # dark seam at the binding
thread = np.array([96, 96, 90], np.float32)
alb = alb * (1 - stitch[..., None]) + thread * stitch[..., None]
brushed = np.asarray(Image.fromarray((rng.random((PY, PX // 48)) * 255).astype(np.uint8)).resize((PX, PY), Image.BILINEAR), np.float32) / 255
steel = (92 + 16 * (brushed - 0.5) + 4 * noise(1.0))[..., None] * np.array([1.0, 1.01, 1.03], np.float32)
steel = steel * (0.75 + 0.25 * cap_bevel[..., None]) * (1 - 0.25 * rivet[..., None])
alb = alb * (1 - cap[..., None]) + steel * cap[..., None]
Image.fromarray(np.clip(alb, 0, 255).astype(np.uint8)).save(f"{out}/table_mat_albedo.png")

# Height -> normal (OpenGL, +Y up in UV; image rows run down so dv = -drow)
h = 0.15 * grain * (1 - cap) + 0.6 * band_s + 1.2 * stitch \
    - 1.0 * smooth((np.abs(sdf(BW, 0.004)) < 0.0012).astype(np.float32), 1.2) + 2.5 * cap_bevel * cap + 1.5 * rivet
h = h.astype(np.float32)
k = 0.35
nx = -(np.roll(h, -1, 1) - np.roll(h, 1, 1)) * k
ny = (np.roll(h, -1, 0) - np.roll(h, 1, 0)) * k
n = np.stack([nx, ny, np.ones_like(h)], -1); n /= np.linalg.norm(n, axis=2, keepdims=True)
Image.fromarray(np.clip((n + 1) * 127.5, 0, 255).astype(np.uint8)).save(f"{out}/table_mat_normal.png")

# ORM: AO dips in seams/stitches, roughness leather 0.72 / band 0.6 / steel 0.38, metal on caps
ao = 1 - 0.3 * smooth((np.abs(sdf(BW, 0.004)) < 0.002).astype(np.float32), 2) - 0.15 * stitch
rough = 0.72 + 0.04 * grain + 0.16 * band_s - 0.08 * wear
rough = rough * (1 - cap) + (0.38 + 0.05 * (brushed - 0.5)) * cap
metal = cap
Image.merge("RGB", [Image.fromarray(np.clip(c * 255, 0, 255).astype(np.uint8)) for c in (ao, rough, metal)]).save(f"{out}/table_mat_orm.png")
print("ok")
