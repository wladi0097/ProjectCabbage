# Project Cabbage: hand_fabric, one tileable greyscale weave for the glove and suit sleeve.
# Tinted by the mesh's vertex colours; mapped triplanar in hand.tres (the remeshed glove has no UVs).
#   python hand_tex.py <out dir>  ->  hand_fabric_albedo|normal|orm.png
import sys, os
import numpy as np
from PIL import Image

N = 512
out = sys.argv[1]
os.makedirs(out, exist_ok=True)
rng = np.random.default_rng(7)
y, x = np.mgrid[0:N, 0:N] / N * 2 * np.pi  # integer frequencies only, so it tiles

# twill: diagonal ribs, fine threads across them, and soft slubs
rib = 0.5 + 0.5 * np.sin(12 * (x + y))
thread = 0.5 + 0.5 * np.sin(96 * (x - y) + 1.7 * np.sin(12 * (x + y)))
slub = sum(np.sin(fx * x + fy * y + rng.uniform(0, 6.3)) / (abs(fx) + abs(fy))
        for fx, fy in rng.integers(-7, 8, (14, 2)) if fx or fy)
slub = (slub - slub.min()) / (slub.max() - slub.min())
h = 0.65 * rib + 0.25 * thread + 0.10 * slub

albedo = np.clip(0.78 + 0.16 * h + 0.08 * (slub - 0.5), 0, 1)
Image.fromarray((albedo * 255).astype(np.uint8), "L").convert("RGB").save(out + "/hand_fabric_albedo.png")

strength = 6.0
dx = (np.roll(h, -1, 1) - np.roll(h, 1, 1)) * strength
dy = (np.roll(h, -1, 0) - np.roll(h, 1, 0)) * strength
n = np.dstack([-dx, dy, np.ones_like(h)])
n /= np.linalg.norm(n, axis=2, keepdims=True)
Image.fromarray(((n * 0.5 + 0.5) * 255).astype(np.uint8), "RGB").save(out + "/hand_fabric_normal.png")

orm = np.dstack([1 - 0.3 * (1 - h), 0.82 + 0.14 * (1 - h), np.zeros_like(h)])
Image.fromarray((np.clip(orm, 0, 1) * 255).astype(np.uint8), "RGB").save(out + "/hand_fabric_orm.png")
