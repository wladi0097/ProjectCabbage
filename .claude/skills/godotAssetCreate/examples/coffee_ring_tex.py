# Coffee ring stains for the desk decal: two overlapping, uneven rings (one partial), muted
# grey-brown on transparent, each a soft thick rim broken in spots with a faint filled interior.
# Writes <dir>/coffee_rings_albedo.png. Pale orange read as a pencil doodle; dark brown vanished.
import math, random, sys
from PIL import Image, ImageChops, ImageDraw, ImageFilter
random.seed(7)
W, H = 512, 256


def ring(cx, cy, r, a0, a1, alpha):
    layer = Image.new("L", (W, H), 0)
    d = ImageDraw.Draw(layer)
    d.ellipse((cx - r, cy - r, cx + r, cy + r), fill=int(alpha * 0.22))   # dried interior
    n = 260
    for i in range(n):
        a = math.radians(a0 + (a1 - a0) * i / n)
        if math.sin(a * 7 + 0.4) > 0.93:                                    # broken spots
            continue
        rr = r + 2.5 * math.sin(a * 5 + 1.3) + random.uniform(-0.8, 0.8)
        x, y = cx + rr * math.cos(a), cy + rr * math.sin(a)
        w = 5.0 + 2.2 * math.sin(a * 3)
        d.ellipse((x - w, y - w, x + w, y + w), fill=alpha)
    return layer.filter(ImageFilter.GaussianBlur(2.2))


mask = ImageChops.lighter(ring(170, 128, 92, 0, 360, 210), ring(330, 118, 90, 40, 300, 160))
Image.merge("RGBA", (*Image.new("RGB", (W, H), (88, 78, 66)).split(), mask)).save(sys.argv[1] + "/coffee_rings_albedo.png")
