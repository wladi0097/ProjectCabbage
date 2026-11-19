# Generates the coin texture: <out>/coin_albedo|normal|orm.png   (python coin_tex.py <out dir>)
# Top projection: the coin face fills the UV square (centre 0.5, radius 0.5). The stamp is a
# heavy serif numeral inside a raised rim, one face each in a 9-wide atlas:
#   $1 / $5 / $10 (ring of 12 dots), $50 (raised octagon), $100 (reeded rim, double ring, dark inlay),
#   $500 (pale centre in a dark outer band broken by 8 bars: the $100 turned inside out),
#   $1K (14-lobed scalloped seal on a dark field), $5K (square seal on a dark field),
#   $10K (double reeded rim, two rings, whole field dark: pale metal lines on black),
#   and a third block for CRITICAL MASS (2026-11-19), every field dark: $50K (hexagon seal),
#   $100K (triple ring), $500K (24 rays in the band), $1M (double square, turned), $10M (notched
#   gear rim), $100M (12-sided seal, reeded), $1B (three trefoil blades in the band).
# Worn brass: raised bits bright and smooth, recesses dark and rough.
# The first five faces keep their old grain and layout (only the numerals were re-centred,
# 2026-11-13), the high ones are a second block.
import numpy as np, sys
from PIL import Image, ImageDraw, ImageFilter, ImageFont

N = 256
OUT = sys.argv[1]
S = 4 * N  # draw supersampled, then shrink
def height(num):
    img = Image.new("L", (S, S), 0)
    d = ImageDraw.Draw(img)
    c = S / 2
    def circ(r, fill=None, outline=None, width=0):
        d.ellipse((c - r, c - r, c + r, c + r), fill=fill, outline=outline, width=width)
    def reeds(r0, r1, n, fill=150, w=0.035):
        for k in range(n):
            a = k * 2 * np.pi / n
            d.line((c + np.cos(a) * R * r0, c + np.sin(a) * R * r0, c + np.cos(a) * R * r1, c + np.sin(a) * R * r1), fill=fill, width=int(R * w))
    R = S / 2
    circ(R * 0.99, fill=105)                      # field
    circ(R * 0.99, outline=255, width=int(R * 0.13))  # rim
    if num == '50':                                # octagon border
        pts = [(c + np.cos(a) * R * 0.78, c + np.sin(a) * R * 0.78) for a in np.arange(8) * np.pi / 4 + np.pi / 8]
        d.polygon(pts, outline=240, width=int(R * 0.11))
    elif num == '100':                             # reeded rim + inner ring
        reeds(0.88, 0.99, 48)
        circ(R * 0.72, outline=240, width=int(R * 0.06))
    elif num == '500':                             # inner ring + 8 bars across the outer band
        circ(R * 0.7, outline=240, width=int(R * 0.07))
        reeds(0.72, 0.87, 8, fill=235, w=0.09)
    elif num == '1K':                              # scalloped seal: 14 lobes
        a = np.linspace(0, 2 * np.pi, 400, endpoint=False)
        r = R * (0.74 + 0.05 * np.cos(14 * a))
        d.polygon(list(zip(c + np.cos(a) * r, c + np.sin(a) * r)), outline=240, width=int(R * 0.08))
    elif num == '5K':                              # square seal, its corners near the rim
        q = R * 0.57
        d.rectangle((c - q, c - q, c + q, c + q), outline=240, width=int(R * 0.09))
    elif num == '50K':                             # hexagon seal, reeded rim
        reeds(0.88, 0.99, 60)
        pts = [(c + np.cos(a) * R * 0.78, c + np.sin(a) * R * 0.78) for a in np.arange(6) * np.pi / 3]
        d.polygon(pts, outline=240, width=int(R * 0.08))
    elif num == '100K':                            # three rings
        circ(R * 0.84, outline=240, width=int(R * 0.04))
        circ(R * 0.75, outline=240, width=int(R * 0.04))
        circ(R * 0.66, outline=240, width=int(R * 0.04))
    elif num == '500K':                            # 24 rays across the band
        circ(R * 0.68, outline=240, width=int(R * 0.05))
        reeds(0.71, 0.86, 24, fill=235, w=0.05)
    elif num == '1M':                              # two squares, one turned: an 8-point seal
        for turn in (0, np.pi / 4):
            pts = [(c + np.cos(a + turn) * R * 0.8, c + np.sin(a + turn) * R * 0.8) for a in np.arange(4) * np.pi / 2 + np.pi / 4]
            d.polygon(pts, outline=240, width=int(R * 0.06))
    elif num == '10M':                             # notched gear rim
        for k in range(16):
            a = (k + 0.5) * 2 * np.pi / 16
            x, y = c + np.cos(a) * R * 0.93, c + np.sin(a) * R * 0.93
            d.ellipse((x - R * 0.06, y - R * 0.06, x + R * 0.06, y + R * 0.06), fill=105)
        circ(R * 0.76, outline=240, width=int(R * 0.07))
    elif num == '100M':                            # 12-sided seal, reeded rim
        reeds(0.88, 0.99, 72)
        pts = [(c + np.cos(a) * R * 0.78, c + np.sin(a) * R * 0.78) for a in np.arange(12) * np.pi / 6]
        d.polygon(pts, outline=240, width=int(R * 0.06))
        circ(R * 0.66, outline=240, width=int(R * 0.04))
    elif num == '1B':                              # three blades in the band between two rings
        for k in range(3):
            a0 = k * 120 - 90 - 30
            d.pieslice((c - R * 0.8, c - R * 0.8, c + R * 0.8, c + R * 0.8), a0, a0 + 60, fill=235)
        circ(R * 0.7, fill=105)
        circ(R * 0.86, outline=240, width=int(R * 0.04))
        circ(R * 0.66, outline=240, width=int(R * 0.04))
    elif num == '10K':                             # double reeded rim, two rings
        reeds(0.88, 0.99, 60)
        circ(R * 0.82, outline=240, width=int(R * 0.05))
        circ(R * 0.70, outline=240, width=int(R * 0.05))
    else:
        for k in range(12):                        # dot ring
            a = k * np.pi / 6
            x, y = c + np.cos(a) * R * 0.71, c + np.sin(a) * R * 0.71
            d.ellipse((x - R * 0.05, y - R * 0.05, x + R * 0.05, y + R * 0.05), fill=235)
    # Stamp: the heavy serif numeral, raised, centred in the dot ring.
    size = {'500': 0.58, '1K': 0.86, '5K': 0.64, '10K': 0.56, '50K': 0.54, '100K': 0.42, '500K': 0.4,
            '1M': 0.7, '10M': 0.5, '100M': 0.38, '1B': 0.74}.get(num) or {1: 1.35, 2: 0.95, 3: 0.68}[len(num)]
    font = ImageFont.truetype('C:/Windows/Fonts/georgiab.ttf', int(R * size))
    # Optically centred (2026-11-13), not by the font's anchor: across by the ink box, up and down by
    # the ink's centroid (stroke included). Georgia's old-style figures hang below the line, so anchor
    # 'mm' left the $50 10% of the face low and the $5 15%; centring the ink box instead floated the
    # "0" of "50" high above the descending "5".
    # The high faces get a heavier dark outline so the numeral survives a heap (review 2026-11-13).
    kw = dict(font=font, anchor='mm', stroke_width=int(R * (0.05 if len(num) < 3 or num == '100' else 0.07)))
    probe = Image.new("L", (S, S), 0)
    ImageDraw.Draw(probe).text((c, c), num, fill=255, stroke_fill=255, **kw)
    b = probe.getbbox()
    ink = np.array(probe, float)
    cy = (ink.sum(1) * np.arange(S)).sum() / ink.sum()
    at = (c - ((b[0] + b[2]) / 2 - c), c - (cy - c))
    d.text(at, num, fill=245, stroke_fill=20, **kw)
    return np.array(img.filter(ImageFilter.GaussianBlur(S / 300)).resize((N, N), Image.LANCZOS)) / 255.0


def block(nums, seed):
    h = np.hstack([height(num) for num in nums])
    gy, gx = np.gradient(h)
    k = 9.0
    n = np.dstack((-gx * k, gy * k, np.ones_like(h)))
    n /= np.linalg.norm(n, axis=2, keepdims=True)
    rng = np.random.default_rng(seed)
    grain = np.array(Image.fromarray((rng.random((32, 32)) * 255).astype(np.uint8)).resize((h.shape[1], N), Image.BICUBIC)) / 255.0
    wear = np.clip(h * 0.9 + grain * 0.1, 0, 1)
    # Neutral greys: the coin's metal colour (silver or gold) is a per-instance tint in Godot.
    brass_dark = np.array([0.24, 0.24, 0.24]); brass = np.array([0.7, 0.7, 0.7]); brass_hi = np.array([0.97, 0.97, 0.97])
    t = wear[..., None]
    alb = np.where(t < 0.5, brass_dark + (brass - brass_dark) * (t / 0.5), brass + (brass_hi - brass) * ((t - 0.5) / 0.5))
    ao = 0.55 + 0.45 * np.clip(h * 1.4, 0, 1)
    rough = 0.68 - 0.3 * wear
    return h, n, alb, ao, rough


LOW = ('1', '5', '10', '50', '100')
HIGH = ('500', '1K', '5K', '10K')
h, n, alb, ao, rough = block(LOW, 3)
# $100: the centre disc inside the inner ring is a darker inlay (a bimetal coin), soft-edged.
yy, xx = np.mgrid[0:N, 0:N]
rr = np.hypot(xx - N / 2 + 0.5, yy - N / 2 + 0.5)
inlay = np.clip((N * 0.35 - rr) / 2.0, 0, 1)
field = np.clip((0.6 - h[:, 4 * N:5 * N]) / 0.2, 0, 1)  # the raised numeral stays bright
alb[:, 4 * N:5 * N] *= (1 - 0.5 * inlay * field)[..., None]
rough[:, 3 * N:] += 0.18  # $50 / $100 satin, not chrome: the desk lamp blew them out

h2, n2, alb2, ao2, rough2 = block(HIGH, 4)
rough2 += 0.18
band = np.clip((rr - N * 0.355) / 2.0, 0, 1)          # $500: the outer band outside the inner ring
# How dark each high face's recessed field is (zone, depth): the raised stamp stays bright.
DARK = {'500': (band, 0.8), '1K': (np.ones((N, N)), 0.45), '5K': (np.ones((N, N)), 0.7), '10K': (np.ones((N, N)), 0.85)}
for i, num in enumerate(HIGH):
    sl = slice(i * N, (i + 1) * N)
    zone, depth = DARK[num]
    fld = np.clip((0.6 - h2[:, sl]) / 0.2, 0, 1)
    alb2[:, sl] *= (1 - depth * zone * fld)[..., None]

TOP = ('50K', '100K', '500K', '1M', '10M', '100M', '1B')
h3, n3, alb3, ao3, rough3 = block(TOP, 5)
rough3 += 0.18
for i, num in enumerate(TOP):
    sl = slice(i * N, (i + 1) * N)
    fld = np.clip((0.6 - h3[:, sl]) / 0.2, 0, 1)
    alb3[:, sl] *= (1 - 0.8 * fld)[..., None]

n, alb, ao, rough = np.hstack((n, n2, n3)), np.hstack((alb, alb2, alb3)), np.hstack((ao, ao2, ao3)), np.hstack((rough, rough2, rough3))
FACES = len(LOW) + len(HIGH) + len(TOP)
Image.fromarray(((n * 0.5 + 0.5) * 255).astype(np.uint8)).save(OUT + "/coin_normal.png")
Image.fromarray((np.clip(alb, 0, 1) * 255).astype(np.uint8)).save(OUT + "/coin_albedo.png")
orm = np.dstack((ao, rough, np.ones((N, FACES * N))))
Image.fromarray((orm * 255).astype(np.uint8)).save(OUT + "/coin_orm.png")
