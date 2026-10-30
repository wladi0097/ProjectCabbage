# Generate the ramp_steel textures: tiling, finely brushed sheet steel (faint streaks along U), soft
# grime. Low contrast on purpose: strong streaks read as wood planks under the warm desk lamp.
#   python ramp_steel_tex.py <out dir>
import sys
import numpy as np
from PIL import Image

out = sys.argv[1]
S = 512
rng = np.random.default_rng(7)


def tile_noise(cutoff):
    """Tileable noise: white noise low-passed in the frequency domain, normalised."""
    f = np.fft.fft2(rng.standard_normal((S, S)))
    fy, fx = np.meshgrid(np.fft.fftfreq(S), np.fft.fftfreq(S), indexing="ij")
    n = np.real(np.fft.ifft2(f * np.exp(-(fx ** 2 + fy ** 2) / (2 * cutoff ** 2))))
    return (n - n.mean()) / n.std()


def streaks():
    """Brushed lines along U: noise smeared horizontally (wrapping), a little across."""
    n = rng.standard_normal((S, S))
    f = np.fft.fft2(n)
    fy, fx = np.meshgrid(np.fft.fftfreq(S), np.fft.fftfreq(S), indexing="ij")
    n = np.real(np.fft.ifft2(f * np.exp(-(fx / 0.004) ** 2 - (fy / 0.25) ** 2)))
    return (n - n.mean()) / n.std()


brush = streaks()
grime = tile_noise(0.012)
spots = np.clip(tile_noise(0.05) - 1.2, 0, None)

alb = 0.62 * (1 + 0.015 * brush - 0.035 * grime - 0.04 * spots)
Image.fromarray(np.clip(alb * 255, 0, 255).astype(np.uint8)).convert("RGB").save(f"{out}/ramp_steel_albedo.png")

h = 0.12 * brush + 0.1 * spots
nx = -(np.roll(h, -1, 1) - np.roll(h, 1, 1)) * 0.25
ny = (np.roll(h, -1, 0) - np.roll(h, 1, 0)) * 0.25
n = np.stack([nx, ny, np.ones_like(h)], -1)
n /= np.linalg.norm(n, axis=2, keepdims=True)
Image.fromarray(np.clip((n + 1) * 127.5, 0, 255).astype(np.uint8)).save(f"{out}/ramp_steel_normal.png")

ao = 1 - 0.08 * np.clip(grime, 0, None)
rough = 0.38 + 0.02 * brush + 0.06 * grime + 0.1 * spots
metal = np.full_like(h, 0.6)
Image.merge("RGB", [Image.fromarray(np.clip(c * 255, 0, 255).astype(np.uint8)) for c in (ao, rough, metal)]).save(f"{out}/ramp_steel_orm.png")
print("ok")
