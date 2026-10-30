# Generate the room textures (no outside sources): painted concrete-block wall,
# the pavement outside and the crate wood.
# python room_tex.py <abs assets/textures>
#   room_wall/room_wall_albedo|normal|orm.png      1024^2, tiles every 2.4 m (uv1_scale 0.41667), blocks 0.4 x 0.2 m
#   room_street/room_street_albedo|normal|orm.png  1024^2, tiles every 2.4 m (uv1_scale 0.41667), slabs 0.6 x 0.6 m
#   room_crates/room_crates_albedo.png             512^2 weathered grey slat wood, grain along u (crates are empty, no label)
import sys, os
import numpy as np
from PIL import Image, ImageFilter
OUT = sys.argv[1]
rng = np.random.default_rng(7)

def blur_wrap(a, r):
    """Tileable gaussian blur (FFT, wraps at the edges)."""
    fy = np.fft.fftfreq(a.shape[0])[:, None]; fx = np.fft.fftfreq(a.shape[1])[None, :]
    return np.real(np.fft.ifft2(np.fft.fft2(a) * np.exp(-2 * (np.pi * r) ** 2 * (fx ** 2 + fy ** 2))))

def save(a, path, mode="L"):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    Image.fromarray(np.clip(a * 255 + 0.5, 0, 255).astype(np.uint8), mode).save(path); print("wrote", path)

# ---------- wall: painted concrete blocks, running bond ----------
R, TILE = 1024, 2.4
ppm = R / TILE; bw, bh = 0.4 * ppm, 0.2 * ppm
y, x = np.mgrid[0:R, 0:R].astype(float) + 0.5
row = np.floor(y / bh).astype(int)
xs = x + (row % 2) * bw / 2
col = np.floor(xs / bw).astype(int) % int(round(TILE / 0.4))
d = np.minimum.reduce([xs % bw, bw - xs % bw, y % bh, bh - y % bh])     # px to nearest joint
h = np.clip((d - 1.5) / 6.0, 0, 1) ** 0.6                              # 0 in the joint, rounded block edge
blk = rng.uniform(-1, 1, (row.max() + 1, col.max() + 1))[row, col]    # per-block paint value
fine = blur_wrap(rng.standard_normal((R, R)), 1.2)
blot = blur_wrap(rng.standard_normal((R, R)), 40); blot /= np.abs(blot).max()
streak = np.asarray(Image.fromarray(rng.standard_normal((16, 96)).astype(np.float32), "F").resize((R, R), Image.BICUBIC))
streak = blur_wrap(streak, 6); streak /= np.abs(streak).max()
alb = 0.80 + 0.035 * blk + 0.05 * fine / np.abs(fine).max() + 0.045 * blot - 0.035 * np.clip(streak, 0, 1)
alb = alb * (0.78 + 0.22 * h)                                           # darker joints
save(alb, OUT + "/room_wall/room_wall_albedo.png")
hh = h + 0.04 * fine / np.abs(fine).max()
gx = (np.roll(hh, -1, 1) - np.roll(hh, 1, 1)) / 2; gy = (np.roll(hh, -1, 0) - np.roll(hh, 1, 0)) / 2
s = 4.0; n = np.dstack([-gx * s, gy * s, np.ones_like(hh)])            # OpenGL (Y+) normal
n /= np.linalg.norm(n, axis=2, keepdims=True)
save(n * 0.5 + 0.5, OUT + "/room_wall/room_wall_normal.png", "RGB")
ao = 0.55 + 0.45 * blur_wrap(h, 2.5)
rough = 0.80 + 0.06 * blot + 0.04 * fine / np.abs(fine).max()
save(np.dstack([ao, rough, np.zeros_like(ao)]), OUT + "/room_wall/room_wall_orm.png", "RGB")

# ---------- street: wet concrete paving slabs (greyscale, tinted in the .tres) ----------
R, TILE = 1024, 2.4
ppm = R / TILE; sw = 0.6 * ppm
y, x = np.mgrid[0:R, 0:R].astype(float) + 0.5
row = np.floor(y / sw).astype(int); col = np.floor(x / sw).astype(int)
d = np.minimum.reduce([x % sw, sw - x % sw, y % sw, sw - y % sw])
h = np.clip((d - 2.0) / 5.0, 0, 1) ** 0.7
slab = rng.uniform(-1, 1, (row.max() + 1, col.max() + 1))[row, col]
fine = blur_wrap(rng.standard_normal((R, R)), 1.0); fine /= np.abs(fine).max()
blot = blur_wrap(rng.standard_normal((R, R)), 30); blot /= np.abs(blot).max()
wet = np.clip(blur_wrap(rng.standard_normal((R, R)), 55) * 3, -1, 1)          # puddle-dark patches
alb = 0.72 + 0.05 * slab + 0.06 * fine + 0.06 * blot - 0.10 * np.clip(wet, 0, 1)
alb = alb * (0.55 + 0.45 * h)
save(alb, OUT + "/room_street/room_street_albedo.png")
hh = h + 0.05 * fine
gx = (np.roll(hh, -1, 1) - np.roll(hh, 1, 1)) / 2; gy = (np.roll(hh, -1, 0) - np.roll(hh, 1, 0)) / 2
n = np.dstack([-gx * 3.0, gy * 3.0, np.ones_like(hh)]); n /= np.linalg.norm(n, axis=2, keepdims=True)
save(n * 0.5 + 0.5, OUT + "/room_street/room_street_normal.png", "RGB")
ao = 0.6 + 0.4 * blur_wrap(h, 2.0)
rough = np.clip(0.82 - 0.30 * np.clip(wet, 0, 1) + 0.04 * fine, 0, 1)
save(np.dstack([ao, rough, np.zeros_like(ao)]), OUT + "/room_street/room_street_orm.png", "RGB")

# ---------- crate wood (sRGB colour baked in, albedo_color stays white) ----------
C = 512
def aniso(a, rx, ry):
    fy = np.fft.fftfreq(a.shape[0])[:, None]; fx = np.fft.fftfreq(a.shape[1])[None, :]
    return np.real(np.fft.ifft2(np.fft.fft2(a) * np.exp(-2 * np.pi ** 2 * ((rx * fx) ** 2 + (ry * fy) ** 2))))
g = aniso(rng.standard_normal((C, C)), 24, 0.8); g /= np.abs(g).max()
g2 = aniso(rng.standard_normal((C, C)), 90, 6); g2 /= np.abs(g2).max()
wood = 0.30 + 0.06 * g + 0.05 * g2                                     # dark weathered grey wood, grain along u
crate = np.dstack([wood * 0.97, wood, wood * 0.98])
save(crate, OUT + "/room_crates/room_crates_albedo.png", "RGB")
