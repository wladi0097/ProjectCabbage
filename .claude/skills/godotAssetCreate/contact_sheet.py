# usage: python contact_sheet.py <out.png> <shot.png>...   (needs PIL)
import sys
from PIL import Image

files = sys.argv[2:]
ims = [Image.open(f).convert("RGB").resize((640, 360)) for f in files]
cols = 3
rows = (len(ims) + cols - 1) // cols
out = Image.new("RGB", (640 * cols, 360 * rows))
for i, im in enumerate(ims):
    out.paste(im, ((i % cols) * 640, (i // cols) * 360))
out.save(sys.argv[1])
