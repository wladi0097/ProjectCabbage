# Coin tally machine textures   (python machine_tex.py <textures dir>)
#  machine_paint/  tiling greyscale enamel (tinted by vertex colour): mottling, grime, orange peel
#  machine_metal/  tiling greyscale brushed metal (tinted by vertex colour: brass, chrome)
#  machine_dial/   atlas. Drum digits 0-9 stacked along v (digit d in v [d/10, (d+1)/10], upright
#                  toward +v) in u [0, DRUM_U]; black drum sides at u [0.15, 0.25]; brass
#                  "$$$" plate in u [0.5, 1], v [0.8, 1]; Findings plate in u [0.25, 0.5], v [0.9, 1];
#                  the chute's cabbage plate in u [0.25, 0.5], v [0.7744, 0.8867] (CAB_BOX).
import math, numpy as np, sys
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
def plate(box, symbol, line, scale):
    x0, y0, x1, y1 = box
    border = round(10 * scale)
    d.rectangle(box, fill=(150, 124, 78)); dm.rectangle(box, fill=255)
    d.rectangle((x0 + border, y0 + border, x1 - border, y1 - border), outline=(30, 24, 14), width=max(3, round(6 * scale)))
    dh.rectangle((x0 + border, y0 + border, x1 - border, y1 - border), outline=60, width=max(3, round(5 * scale)))
    big = ImageFont.truetype("C:/Users/wladi/Desktop/ProjectCabbage/assets/fonts/Oswald.ttf", round(110 * scale))
    small = ImageFont.truetype("C:/Users/wladi/Desktop/ProjectCabbage/assets/fonts/Oswald.ttf", round(27 * scale))
    for font, text, y in ((big, symbol, 0.42), (small, line, 0.82)):
        d.text(((x0 + x1) / 2, y0 + (y1 - y0) * y), text, font=font, fill=(24, 19, 12), anchor="mm")
        dh.text(((x0 + x1) / 2, y0 + (y1 - y0) * y), text, font=font, fill=50, anchor="mm")


plate((N // 2, 0, N, int(0.2 * N)), "$$$", "TALLY MODEL 9  ·  DEPT. OF REVENUE", 1.0)
plate((N // 4, 0, N // 2, int(0.1 * N)), "¶¶¶", "DEPT. OF QUALITY", 0.5)
# The chute's stock plate: one cabbage head (assets/sprites/icons/cabbage_icon.svg, its veins left in
# brass) in u [0.25, 0.5], v [CAB_V0, CAB_V1] (2026-11-17).
CAB_BOX = (N // 4, 116, N // 2, 231)
plate(CAB_BOX, "", "DEPT. OF SUPPLY", 0.5)
cx, cy, r = (CAB_BOX[0] + CAB_BOX[2]) / 2, CAB_BOX[1] + (CAB_BOX[3] - CAB_BOX[1]) * 0.42, 36
k = r / 30
d.ellipse((cx - r, cy - r + k, cx + r, cy + r + k), fill=(24, 19, 12)); dh.ellipse((cx - r, cy - r + k, cx + r, cy + r + k), fill=50)
def quad(p0, p1, p2, n=10):   # the svg's Q curves, sampled
    return [tuple((1 - t) ** 2 * a + 2 * (1 - t) * t * b + t * t * c for a, b, c in zip(p0, p1, p2)) for t in (i / n for i in range(n + 1))]


for pts in ([(0, -21), (0, 25)], quad((0, -5), (-12, -7), (-21, -19)), quad((0, -5), (12, -7), (21, -19)),
            quad((0, 11), (-14, 9), (-25, -1)), quad((0, 11), (14, 9), (25, -1))):
    line = [(cx + x * k, cy + y * k) for x, y in pts]
    d.line(line, fill=(150, 124, 78), width=round(5 * k), joint="curve"); dh.line(line, fill=128, width=round(5 * k), joint="curve")
alb.save(OUT + "machine_dial/machine_dial_albedo.png")
h = np.array(hgt) / 255.0
normal_from(h, 4.0).save(OUT + "machine_dial/machine_dial_normal.png")
m = np.array(metal) / 255.0
r = np.where(m > 0.5, 0.62, 0.7)   # matte: the lamp must not glare over the lettering
Image.fromarray((np.dstack((np.ones_like(h), r, m)) * 255).astype(np.uint8)).save(OUT + "machine_dial/machine_dial_orm.png")

# Acceptance gauge face, painted into the free block u [0.5, 1], v [0.25, 0.75] (centre (768, 512)
# px, radius GAUGE_R). Needle sweep -120..+120 deg from straight up = 0..100 %; the low end inked in.
alb = Image.open(OUT + "machine_dial/machine_dial_albedo.png").convert("RGB"); d = ImageDraw.Draw(alb)
GX, GY, GAUGE_R = 768, 512, 250
INKD, PAPER = (222, 218, 204), (30, 31, 30)   # light print on a dark face
d.ellipse((GX - GAUGE_R, GY - GAUGE_R, GX + GAUGE_R, GY + GAUGE_R), fill=PAPER)


def polar(pct, r):
    a = math.radians(-120 + 240 * pct / 100)
    return GX + r * math.sin(a), GY - r * math.cos(a)


d.arc((GX - 222, GY - 222, GX + 222, GY + 222), -210, -138, fill=(105, 104, 98), width=34)   # dark low band: 0..30 %
d.arc((GX - 222, GY - 222, GX + 222, GY + 222), -210, 30, fill=INKD, width=9)
for pct in range(0, 101, 10):
    major = pct % 50 == 0
    d.line((polar(pct, 222), polar(pct, 168 if major else 190)), fill=INKD, width=16 if major else 9)
num = ImageFont.truetype("C:/Users/wladi/Desktop/ProjectCabbage/assets/fonts/Oswald.ttf", 70)
for pct in (0, 50, 100):
    d.text(polar(pct, 105), str(pct), font=num, fill=INKD, anchor="mm")
lab = ImageFont.truetype("C:/Users/wladi/Desktop/ProjectCabbage/assets/fonts/Oswald.ttf", 50)
d.text((GX, GY + 152), "ACCEPTANCE", font=lab, fill=INKD, anchor="mm")
alb.save(OUT + "machine_dial/machine_dial_albedo.png")
