# The condensed cabbage's paper belt: one atlas of 33 rows, each one tile of the band (u once round a
# third of the belt, v across its width, top to bottom). Row 0 is the plain paper back; row k is the
# printed front for a cabbage holding k: grey-khaki manila, an ink line along each edge and "×k" in
# Oswald Bold in the middle.
# Run: python cabbage_belt_tex.py <out png>
import sys
import numpy as np
from PIL import Image, ImageDraw, ImageFont

OUT = sys.argv[1]
FONT = r"C:\Users\wladi\Desktop\ProjectCabbage\assets\fonts\Oswald.ttf"
TW, TH, ROWS = 344, 88, 33   # a tile is about 0.29 x 0.074 m on the belt (a third of the way round): square pixels
PAPER = np.array([0.55, 0.535, 0.47])
INK = np.array([0.07, 0.075, 0.07])
RULES = [(0.025, 0.075), (0.925, 0.975)]   # ink lines along the edges, as fractions of the width
CAP = 0.76                              # the digits' height, as a fraction of the width

rng = np.random.default_rng(7)


def fibres(h, w):
    """Soft paper grain that wraps across u: long faint fibres plus fine speckle."""
    f = np.fft.fft2(rng.standard_normal((h, w)))
    ky = np.fft.fftfreq(h)[:, None]
    kx = np.fft.fftfreq(w)[None, :]
    long = np.real(np.fft.ifft2(f * np.exp(-((kx * 6) ** 2 + (ky * 1.2) ** 2) * 40)))
    long /= np.abs(long).max()
    return 0.035 * long + 0.018 * rng.standard_normal((h, w))


def ink_mask(k):
    """Alpha of the print on a front tile (k == 0: the back, nothing printed)."""
    img = Image.new("L", (TW * 4, TH * 4), 0)   # drawn at 4x, then reduced: smooth edges
    if k == 0:
        return np.zeros((TH, TW))
    d = ImageDraw.Draw(img)
    for a, b in RULES:
        d.rectangle([0, a * TH * 4, TW * 4, b * TH * 4], fill=255)
    font = ImageFont.truetype(FONT, 100)
    font.set_variation_by_axes([700])
    text = "\u00d7%d" % k
    box = font.getbbox("8")
    size = int(100 * CAP * TH * 4 / (box[3] - box[1]))
    font = ImageFont.truetype(FONT, size)
    font.set_variation_by_axes([700])
    box = font.getbbox("8")
    full = font.getbbox(text)
    x = TW * 2 - (full[0] + full[2]) / 2
    y = TH * 2 - (box[1] + box[3]) / 2
    d.text((x, y), text, font=font, fill=255)
    return np.asarray(img.resize((TW, TH), Image.LANCZOS), dtype=float) / 255


rows = []
for k in range(ROWS):
    grain = fibres(TH, TW)
    paper = np.clip(PAPER[None, None, :] * (1 + grain[..., None]), 0, 1)
    wear = np.clip(0.93 + 0.12 * rng.standard_normal((TH, TW)), 0.75, 1.0)
    a = (ink_mask(k) * wear)[..., None]
    rows.append(paper * (1 - a) + INK * a)
atlas = np.concatenate(rows, axis=0)
Image.fromarray((atlas * 255 + 0.5).astype(np.uint8), "RGB").save(OUT)
print("atlas", atlas.shape)
