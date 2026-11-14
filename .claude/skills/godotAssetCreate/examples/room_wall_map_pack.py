# Pack ambientCG Concrete029 1K (CC0, board-formed concrete: 16 vertical boards, one pour joint per tile) into
# room_wall_map albedo/normal/orm for the map corner's walls (room_geo.py, material slot room_wall_map).
# python room_wall_map_pack.py <dir with Concrete029_1K-PNG_*.png> <abs assets/textures/room_wall_map> [normal strength]
# One tile = 2.4 m (boards 15 cm, the joint 1.2 m up the wall): uv1_scale 0.41667 in the .tres, like room_wall.
# Albedo stored greyscale, its blotches flattened (wrapping blur, so the tile stays seamless) and tinted cold in the .tres.
import sys, os
import numpy as np
from PIL import Image
src, out = sys.argv[1], sys.argv[2]
k = float(sys.argv[3]) if len(sys.argv) > 3 else 0.75
p = lambda m: f"{src}/Concrete029_1K-PNG_{m}.png"
os.makedirs(out, exist_ok=True)

def blur_wrap(a, r):
    fy = np.fft.fftfreq(a.shape[0])[:, None]; fx = np.fft.fftfreq(a.shape[1])[None, :]
    return np.real(np.fft.ifft2(np.fft.fft2(a) * np.exp(-2 * (np.pi * r) ** 2 * (fx ** 2 + fy ** 2))))

def save(a, name, mode="L"):
    Image.fromarray(np.clip(a * 255 + 0.5, 0, 255).astype(np.uint8), mode).save(f"{out}/room_wall_map_{name}.png")

c = np.asarray(Image.open(p("Color")).convert("RGB"), dtype=np.float64) / 255
g = c @ [0.2126, 0.7152, 0.0722]
g = g / blur_wrap(g, 90) * g.mean()                    # flatten the large stains, keep board-to-board variation
g = 0.78 + (g - g.mean()) * 1.6                         # mean 0.78 like room_wall, so the tint sets the value
save(g, "albedo")
n = np.asarray(Image.open(p("NormalGL")).convert("RGB"), dtype=np.float64) / 127.5 - 1    # OpenGL (curl test 2.5x)
n[..., :2] *= k
n /= np.linalg.norm(n, axis=2, keepdims=True)
save(n * 0.5 + 0.5, "normal", "RGB")
ao = np.asarray(Image.open(p("AmbientOcclusion")).convert("L"), dtype=np.float64) / 255
r = np.asarray(Image.open(p("Roughness")).convert("L"), dtype=np.float64) / 255
save(np.dstack([0.4 + 0.6 * ao, np.clip(r + 0.1, 0, 1), np.zeros_like(ao)]), "orm", "RGB")   # matte, AO halved
print("albedo mean", g.mean(), "std", g.std())
