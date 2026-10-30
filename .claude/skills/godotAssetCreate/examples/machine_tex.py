# Coin tally machine textures   (python machine_tex.py <textures dir>)
#  machine_paint/  tiling greyscale enamel (tinted by vertex colour): mottling, grime, orange peel
#  machine_metal/  tiling greyscale brushed metal (tinted by vertex colour: brass, chrome)
#  machine_dial/   atlas. Drum digits 0-9 stacked along v (digit d in v [d/10, (d+1)/10], upright
#                  toward +v) in u [0, DRUM_U]; black drum sides at u [0.15, 0.25]; brass
#                  "$$$" plate in u [0.5, 1], v [0.8, 1].
import numpy as np, sys
from PIL import Image, ImageDraw, ImageFont

OUT = sys.argv[1] + "/"
rng = np.random.default_rng(9)
DRUM_U = 0.12


def periodic_noise(n, cutoff, aniso=(1, 1)):
    """Tileable noise: random spectrum, low-passed, inverse FFT."""
    f = np.fft.fftfreq(n)
    fx, fy = np.meshgrid(f * aniso[0], f * aniso[1])
    amp = np.exp(-(fx ** 2 + fy ** 2) / (2 * cutoff ** 2))
    field = np.real(np.fft.ifft2(np.fft.fft2(rng.standard_normal((n, n))) * amp))
    return (field - field.min()) / (field.max() - field.min())


def normal_from(h, k):
    gy, gx = np.gradient(np.pad(h, 1, mode="wrap"))
    gx, gy = gx[1:-1, 1:-1], gy[1:-1, 1:-1]
    n = np.dstack((-gx * k, gy * k, np.ones_like(h)))
    n /= np.linalg.norm(n, axis=2, keepdims=True)
    return Image.fromarray(((n * 0.5 + 0.5) * 255).astype(np.uint8))


def save(name, alb, h, k, rough, metal, ao=None):
    g = (np.clip(alb, 0, 1) * 255).astype(np.uint8)
    Image.fromarray(g if g.ndim == 3 else np.dstack([g] * 3)).save(OUT + name + "/" + name + "_albedo.png")
    normal_from(h, k).save(OUT + name + "/" + name + "_normal.png")
    ao = np.ones_like(h) if ao is None else ao
    Image.fromarray((np.dstack((ao, rough, metal)) * 255).astype(np.uint8)).save(OUT + name + "/" + name + "_orm.png")


N = 512
# Enamel: broad mottling + fine grime specks; orange-peel bumps; grime is rougher.
mottle = periodic_noise(N, 0.01); grime = periodic_noise(N, 0.08) ** 3; peel = periodic_noise(N, 0.12)
save("machine_paint", 0.88 - 0.10 * mottle - 0.25 * grime, peel * 0.6 + mottle * 0.4, 1.0,
     0.38 + 0.25 * grime + 0.08 * mottle, np.zeros((N, N)), 1 - 0.3 * grime)
# Brushed metal: streaks along u, a few soft smudges.
streak = periodic_noise(N, 0.2, (0.02, 1.0)); smudge = periodic_noise(N, 0.01)
save("machine_metal", 0.82 + 0.12 * streak - 0.2 * smudge ** 2, streak, 0.4,
     0.62 + 0.1 * streak + 0.1 * smudge, np.ones((N, N)))

# Dial atlas.
N = 1024
alb = Image.new("RGB", (N, N), (18, 18, 17)); d = ImageDraw.Draw(alb)
hgt = Image.new("L", (N, N), 128); dh = ImageDraw.Draw(hgt)
metal = Image.new("L", (N, N), 0); dm = ImageDraw.Draw(metal)
rough = Image.new("L", (N, N), 140)
digits = ImageFont.truetype("C:/Users/wladi/Desktop/ProjectCabbage/assets/fonts/Oswald.ttf", 84)
digits.set_variation_by_axes([700]) if hasattr(digits, "set_variation_by_axes") else None
cw = int(DRUM_U * N); ch = N // 10
for k in range(10):
    cy = N - (k + 0.5) * ch          # v up
    d.text((cw / 2, cy), str(k), font=digits, fill=(226, 220, 198), anchor="mm")
# Plate: brass with an engraved border and text.
x0, y0, x1, y1 = N // 2, 0, N, int(0.2 * N)
d.rectangle((x0, y0, x1, y1), fill=(150, 124, 78)); dm.rectangle((x0, y0, x1, y1), fill=255)
d.rectangle((x0 + 10, y0 + 10, x1 - 10, y1 - 10), outline=(30, 24, 14), width=6)
dh.rectangle((x0 + 10, y0 + 10, x1 - 10, y1 - 10), outline=60, width=5)
big = ImageFont.truetype("C:/Users/wladi/Desktop/ProjectCabbage/assets/fonts/Oswald.ttf", 110)
small = ImageFont.truetype("C:/Users/wladi/Desktop/ProjectCabbage/assets/fonts/Oswald.ttf", 27)
for font, text, y in ((big, "$$$", 0.42), (small, "TALLY MODEL 9  \u00b7  DEPT. OF REVENUE", 0.82)):
    d.text(((x0 + x1) / 2, y0 + (y1 - y0) * y), text, font=font, fill=(24, 19, 12), anchor="mm")
    dh.text(((x0 + x1) / 2, y0 + (y1 - y0) * y), text, font=font, fill=50, anchor="mm")
alb.save(OUT + "machine_dial/machine_dial_albedo.png")
h = np.array(hgt) / 255.0
normal_from(h, 4.0).save(OUT + "machine_dial/machine_dial_normal.png")
m = np.array(metal) / 255.0
r = np.where(m > 0.5, 0.62, 0.7)   # matte: the lamp must not glare over the lettering
Image.fromarray((np.dstack((np.ones_like(h), r, m)) * 255).astype(np.uint8)).save(OUT + "machine_dial/machine_dial_orm.png")
