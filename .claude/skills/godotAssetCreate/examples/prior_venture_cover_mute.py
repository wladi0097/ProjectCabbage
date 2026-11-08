# Muted copies of the cover art: 30% saturation, 75% brightness and a cold grey-sage cast, so the
# cabbage stays the only saturated thing.
import sys
from PIL import Image, ImageEnhance
d = sys.argv[1]
for i in (1, 2, 3):
    im = Image.open(f"{d}/src/cover_{i}.jpg").convert("RGB")
    im = ImageEnhance.Brightness(ImageEnhance.Color(im).enhance(0.3)).enhance(0.75)
    im = Image.blend(im, Image.new("RGB", im.size, (70, 84, 80)), 0.12)
    im.save(f"{d}/cover_{i}.png")
