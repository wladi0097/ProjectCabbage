# Requisition form paper (0.36 x 0.2 m card, UV 0-1 over the face): dark carbon-grey stock (the
# print is off-white Label3D text), faint grid, a dark sage header band, typed-field rules, a perforated left edge, a faint department seal.
# Text (title, body, price, APPROVED) stays Label3D in Godot.
import sys, random
from PIL import Image, ImageDraw, ImageFilter
out = sys.argv[1]
W, H = 1152, 640
random.seed(7)
im = Image.new("RGB", (W, H), (40, 42, 41))
noise = Image.effect_noise((W, H), 14).convert("RGB")
im = Image.blend(im, Image.merge("RGB", [noise.getchannel(0)] * 3).point(lambda v: v), 0.06)
d = ImageDraw.Draw(im, "RGBA")
for x in range(60, W, 32):
    d.line([(x, 120), (x, H - 20)], fill=(190, 205, 195, 12))
for y in range(120, H, 32):
    d.line([(50, y), (W - 20, y)], fill=(190, 205, 195, 12))
d.rectangle([0, 0, W, 112], fill=(58, 72, 62, 255))                  # header band
d.line([(0, 112), (W, 112)], fill=(120, 140, 125, 255), width=4)
for y in (300, 380, 460, 540):                                        # typed-field rules
    d.line([(70, y), (W - 300, y)], fill=(200, 200, 190, 40), width=2)
d.rectangle([W - 270, H - 170, W - 40, H - 40], outline=(190, 195, 185, 90), width=4)  # price box
for y in range(20, H, 28):                                            # perforated stub on the left
    d.ellipse([12, y, 26, y + 14], fill=(18, 18, 18, 255))
d.line([(42, 0), (42, H)], fill=(95, 95, 90, 120), width=2)
cx, cy, r = W - 120, 220, 70                                          # faint seal
d.ellipse([cx - r, cy - r, cx + r, cy + r], outline=(170, 190, 175, 45), width=6)
d.ellipse([cx - r + 16, cy - r + 16, cx + r - 16, cy + r - 16], outline=(170, 190, 175, 35), width=3)
for i in range(400):                                                  # handling smudges
    x, y = random.randrange(W), random.randrange(H)
    d.ellipse([x, y, x + random.randint(4, 30), y + random.randint(4, 30)], fill=(0, 0, 0, random.randint(6, 14)))
im = im.filter(ImageFilter.GaussianBlur(0.6))
im.save(out)
