# Generates the coin texture: <out>/coin_albedo|normal|orm.png   (python coin_tex.py <out dir>)
# Top projection: the coin face fills the UV square (centre 0.5, radius 0.5). The stamp is a
# heavy serif numeral 1 inside a ring of 12 dots and a
# raised rim. Worn brass: raised bits bright and smooth, recesses dark and rough.
import numpy as np, sys
from PIL import Image, ImageDraw, ImageFilter

N = 256
OUT = sys.argv[1]
S = 4 * N  # draw supersampled, then shrink
img = Image.new("L", (S, S), 0)
d = ImageDraw.Draw(img)
c = S / 2
def circ(r, fill=None, outline=None, width=0):
    d.ellipse((c - r, c - r, c + r, c + r), fill=fill, outline=outline, width=width)
R = S / 2
circ(R * 0.99, fill=105)                      # field
circ(R * 0.99, outline=255, width=int(R * 0.13))  # rim
for k in range(12):                            # dot ring
    a = k * np.pi / 6
    x, y = c + np.cos(a) * R * 0.71, c + np.sin(a) * R * 0.71
    d.ellipse((x - R * 0.05, y - R * 0.05, x + R * 0.05, y + R * 0.05), fill=235)
# Stamp: a heavy serif numeral 1, raised, centred in the dot ring.
from PIL import ImageFont
font = ImageFont.truetype('C:/Windows/Fonts/georgiab.ttf', int(R * 1.35))
d.text((c, c + R * 0.05), '1', font=font, fill=245, anchor='mm', stroke_width=int(R * 0.05), stroke_fill=20)
h = np.array(img.filter(ImageFilter.GaussianBlur(S / 300)).resize((N, N), Image.LANCZOS)) / 255.0
gy, gx = np.gradient(h)
k = 9.0
n = np.dstack((-gx * k, gy * k, np.ones_like(h)))
n /= np.linalg.norm(n, axis=2, keepdims=True)
Image.fromarray(((n * 0.5 + 0.5) * 255).astype(np.uint8)).save(OUT + "/coin_normal.png")
rng = np.random.default_rng(3)
grain = np.array(Image.fromarray((rng.random((32, 32)) * 255).astype(np.uint8)).resize((N, N), Image.BICUBIC)) / 255.0
wear = np.clip(h * 0.9 + grain * 0.1, 0, 1)
brass_dark = np.array([0.22, 0.15, 0.05]); brass = np.array([0.66, 0.49, 0.2]); brass_hi = np.array([0.9, 0.74, 0.42])
t = wear[..., None]
alb = np.where(t < 0.5, brass_dark + (brass - brass_dark) * (t / 0.5), brass + (brass_hi - brass) * ((t - 0.5) / 0.5))
Image.fromarray((np.clip(alb, 0, 1) * 255).astype(np.uint8)).save(OUT + "/coin_albedo.png")
ao = 0.55 + 0.45 * np.clip(h * 1.4, 0, 1)
rough = 0.68 - 0.3 * wear
orm = np.dstack((ao, rough, np.ones_like(h)))
Image.fromarray((orm * 255).astype(np.uint8)).save(OUT + "/coin_orm.png")

