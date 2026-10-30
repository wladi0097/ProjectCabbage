# Pack ambientCG Wood060 1K into table_wood albedo/normal/orm with a stylizing pass.
import sys
import numpy as np
from PIL import Image, ImageFilter, ImageChops, ImageEnhance, ImageStat
src, out = sys.argv[1], sys.argv[2]
p = lambda k: f"{src}/Wood060_1K-PNG_{k}.png"
a = Image.open(p("Color")).convert("RGB")
# flatten large-scale blotches: a / blur(a) * mean
blur = a.filter(ImageFilter.GaussianBlur(120))
mean = ImageStat.Stat(a).mean
A = np.asarray(a, dtype=np.float32); B = np.asarray(blur, dtype=np.float32) + 1
F = A / B * np.array(mean, dtype=np.float32)
F = np.clip(F, 0, 255).astype(np.uint8)
alb = Image.fromarray(F).filter(ImageFilter.GaussianBlur(float(sys.argv[5]) if len(sys.argv) > 5 else 1.2))
med = int(sys.argv[8]) if len(sys.argv) > 8 else 0  # median = painterly, less photographic grain
if med:
    alb = alb.filter(ImageFilter.MedianFilter(med))
alb = ImageEnhance.Contrast(alb).enhance(float(sys.argv[3]) if len(sys.argv) > 3 else 0.8)
alb = ImageEnhance.Brightness(alb).enhance(float(sys.argv[4]) if len(sys.argv) > 4 else 1.0)
alb = ImageEnhance.Color(alb).enhance(float(sys.argv[7]) if len(sys.argv) > 7 else 1.0)
alb.save(f"{out}/table_wood_albedo.png")
# soften the normal map toward flat (strength argv[6]) and renormalise
N = np.asarray(Image.open(p("NormalGL")).convert("RGB"), dtype=np.float32) / 127.5 - 1
k = float(sys.argv[6]) if len(sys.argv) > 6 else 1.0
N[..., :2] *= k
N /= np.linalg.norm(N, axis=2, keepdims=True)
Image.fromarray(np.clip((N + 1) * 127.5, 0, 255).astype(np.uint8)).save(f"{out}/table_wood_normal.png")
ao = Image.open(p("AmbientOcclusion")).convert("L")
r = Image.open(p("Roughness")).convert("L").resize(ao.size)
Image.merge("RGB", [ao, r, Image.new("L", ao.size, 0)]).save(f"{out}/table_wood_orm.png")
print("ok", mean)
