# price_slate texture: dark slate with faint wiped-chalk haze and streaks. Greyscale albedo, flat-ish normal, ORM.
import sys, os, numpy as np
from PIL import Image, ImageFilter
out = sys.argv[1]; os.makedirs(out, exist_ok=True)
R = 512; rng = np.random.default_rng(7)
def noise(scale):
    small = rng.random((max(2, R // scale), max(2, R // scale))).astype(np.float32)
    return np.asarray(Image.fromarray((small * 255).astype(np.uint8)).resize((R, R), Image.BICUBIC), np.float32) / 255
base = 0.07 + 0.012 * noise(4) + 0.01 * noise(64)
# Wipe haze: broad horizontal swipes of chalk dust left by an eraser.
haze = np.zeros((R, R), np.float32)
for _ in range(9):
    y = rng.integers(0, R); h = rng.integers(20, 70); x0 = rng.integers(-100, 300); w = rng.integers(150, 420)
    band = np.zeros((R, R), np.float32); band[max(0, y):min(R, y + h), max(0, x0):min(R, x0 + w)] = rng.uniform(0.02, 0.05)
    haze += band
haze = np.asarray(Image.fromarray((haze * 255 * 4).clip(0, 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(14)), np.float32) / 255 / 4
streak = (noise(1) > 0.985).astype(np.float32)
streak = np.asarray(Image.fromarray((streak * 255).astype(np.uint8)).resize((R, R)).filter(ImageFilter.BoxBlur(1)), np.float32) / 255
streak = np.asarray(Image.fromarray((streak * 255).astype(np.uint8)).transform((R, R), Image.AFFINE, (1, 0, 0, 0, 0.08, 0)).filter(ImageFilter.GaussianBlur(1)), np.float32) / 255 * 0.03
alb = (base + haze * noise(16) * 1.5 + streak).clip(0, 1)
Image.fromarray((alb * 255).astype(np.uint8)).convert("RGB").save(f"{out}/price_slate_albedo.png")
h = noise(3) * 0.6 + noise(32) * 0.4
gy, gx = np.gradient(h); s = 1.2
n = np.dstack([-gx * s, -gy * s, np.ones_like(h)]); n /= np.linalg.norm(n, axis=2, keepdims=True)
Image.fromarray(((n * 0.5 + 0.5) * 255).astype(np.uint8)).save(f"{out}/price_slate_normal.png")
rough = (0.9 - haze * 1.5).clip(0, 1)
Image.fromarray((np.dstack([np.ones_like(h), rough, np.zeros_like(h)]) * 255).astype(np.uint8)).save(f"{out}/price_slate_orm.png")
print("ok")
