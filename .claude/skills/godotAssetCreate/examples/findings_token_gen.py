# QA Findings tokens: one bevelled square bakelite chit (corner notch, like a punched card) and a
# 5-wide texture atlas (¶1 / ¶5 / ¶10 / ¶50 / ¶100), no Blender needed.   python findings_token_gen.py <project dir>
# Writes assets/meshes/Tokens/findings_token.obj and assets/textures/findings_token/*_albedo|normal|orm.png.
# Mesh: side S, thickness T, origin at its centre, top face +Y, the notch at the far right (-Z, +X).
# UVs: top projection, the face fills the UV square (image top = far side, -Z). The Godot material
# picks the column with uv1_offset/uv1_scale (the face is drawn into the middle 96% of each tile).
# Each face: raised frame, a row of 10 punch slots with the value punched through, a big raised
# "¶n", an inked "INSPECTED" line under it. ¶50 and ¶100 add a second, inner frame line (cold cyan on
# the ¶100, whose outer frame is cyan too), and the Godot templates step them up in size like the $50/$100 coins.
import os, sys
import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = sys.argv[1]
S, T = 0.085, 0.016          # side, thickness (m)
BEV, BEV_H = 0.045, 0.003    # top/bottom bevel: inset (fraction of S) and height (m)
C, NOTCH = 0.07, 0.2         # corner chamfer, the far-right notch (fractions of S)
# The outline (x right, y = far side), convex, counter-clockwise.
OUTLINE = list(reversed([(-0.5 + C, 0.5), (0.5 - NOTCH, 0.5), (0.5, 0.5 - NOTCH), (0.5, -0.5 + C),
           (0.5 - C, -0.5), (-0.5 + C, -0.5), (-0.5, -0.5 + C), (-0.5, 0.5 - C)]))


def inset(poly, d):
    """Offsets a convex CCW polygon inwards by d."""
    p = np.array(poly)
    n = len(p)
    out = []
    for i in range(n):
        a, b, c = p[i - 1], p[i], p[(i + 1) % n]
        lines = []
        for u, v in ((a, b), (b, c)):
            e = (v - u) / np.linalg.norm(v - u)
            nrm = np.array([-e[1], e[0]])  # inward for CCW
            lines.append((u + nrm * d, e))
        (p1, e1), (p2, e2) = lines
        t = np.cross(p2 - p1, e2) / np.cross(e1, e2)
        out.append(tuple(p1 + e1 * t))
    return out


# --- mesh ---------------------------------------------------------------------------------------
top, outer = inset(OUTLINE, BEV), OUTLINE
h = T / 2
rings = [(top, h), (outer, h - BEV_H), (outer, -h + BEV_H), (top, -h)]
verts, uvs, normals, faces = [], [], [], []


def vid(p, y):
    x, z = p[0] * S, -p[1] * S
    verts.append((x, y, z))
    uvs.append((p[0] + 0.5, p[1] + 0.5))
    return len(verts)


def face(pts, nrm):
    normals.append(nrm)
    faces.append([(vid(p, y), len(normals)) for p, y in pts])


def unit(v):
    v = np.array(v, float)
    return tuple(v / np.linalg.norm(v))


n = len(OUTLINE)
face([(p, h) for p in top], (0, 1, 0))
face([(p, -h) for p in reversed(top)], (0, -1, 0))
for i in range(n):
    j = (i + 1) % n
    for (ra, ya), (rb, yb) in zip(rings, rings[1:]):
        quad = [(ra[i], ya), (rb[i], yb), (rb[j], yb), (ra[j], ya)]
        ex, ez = outer[j][0] - outer[i][0], -(outer[j][1] - outer[i][1])
        side = unit((-ez, 0, ex))  # outward
        slope = (ya + yb) / 2
        y = 0.0 if abs(ya - yb) > BEV_H * 1.5 else (1.0 if slope > 0 else -1.0)
        face(quad, unit((side[0], y * 0.9, side[2])))

os.makedirs(ROOT + "/assets/meshes/Tokens", exist_ok=True)
with open(ROOT + "/assets/meshes/Tokens/findings_token.obj", "w") as f:
    f.write("# findings_token_gen.py\no findings_token\n")
    for v in verts:
        f.write("v %.5f %.5f %.5f\n" % v)
    for t in uvs:
        f.write("vt %.5f %.5f\n" % t)
    for nm in normals:
        f.write("vn %.4f %.4f %.4f\n" % nm)
    for fc in faces:
        f.write("f " + " ".join("%d/%d/%d" % (v, v, nn) for v, nn in fc) + "\n")

# --- texture ------------------------------------------------------------------------------------
N = 256
SS = 4 * N
FONT = ROOT + "/assets/fonts/Oswald.ttf"
# body, frame, raised lettering, ink; (roughness body, lettering), lettering metallic
DENOMS = [
    ("1", (0.50, 0.51, 0.49), (0.57, 0.58, 0.55), (0.12, 0.14, 0.13), (0.30, 0.33, 0.31), (0.5, 0.7), 0.0),
    ("5", (0.34, 0.41, 0.37), (0.40, 0.47, 0.43), (0.80, 0.82, 0.77), (0.72, 0.75, 0.70), (0.45, 0.65), 0.0),
    ("10", (0.07, 0.08, 0.08), (0.52, 0.47, 0.36), (0.62, 0.56, 0.42), (0.45, 0.42, 0.34), (0.4, 0.6), 0.6),
    # ¶50: dark petrol-slate bakelite, pale cold-steel lettering and frame (no brass: reads apart from ¶10).
    ("50", (0.10, 0.15, 0.17), (0.55, 0.62, 0.64), (0.70, 0.78, 0.80), (0.42, 0.52, 0.55), (0.4, 0.45), 0.5),
    # ¶100: pale ivory lab-grade bakelite (kept below 0.6: brighter blew out under the desk lamp), black lettering, a cold cyan inlay frame.
    ("100", (0.58, 0.59, 0.55), (0.17, 0.42, 0.47), (0.06, 0.07, 0.07), (0.20, 0.30, 0.32), (0.35, 0.5), 0.0),
]
# Denominations with a second, inner frame line (in the frame colour).
INNER = ("50", "100")


def px(p):
    return ((0.02 + 0.96 * (p[0] + 0.5)) * SS, (0.02 + 0.96 * (0.5 - p[1])) * SS)


def mask():
    img = Image.new("L", (SS, SS), 0)
    return img, ImageDraw.Draw(img)


def arr(img, blur=1.0):
    return np.array(img.filter(ImageFilter.GaussianBlur(SS / 400 * blur)).resize((N, N), Image.LANCZOS)) / 255.0


def tile(num, body, frame, letter, ink, rough, metal):
    fr, d = mask()
    d.polygon([px(p) for p in OUTLINE], fill=255)
    d.polygon([px(p) for p in inset(OUTLINE, 0.085)], fill=0)
    if num in INNER:
        d.polygon([px(p) for p in inset(OUTLINE, 0.1)], fill=255)
        d.polygon([px(p) for p in inset(OUTLINE, 0.113)], fill=0)
    let, d = mask()
    # A small ¶ hung at the numeral's cap line (so "¶1" never reads as "11"), the numeral big.
    big = ImageFont.truetype(FONT, int(SS * {1: 0.52, 2: 0.46, 3: 0.36}[len(num)]))
    big.set_variation_by_name("Bold")
    mark = ImageFont.truetype(FONT, int(SS * 0.24))
    mark.set_variation_by_name("Bold")
    gap = SS * 0.035
    wm, wn = d.textlength("¶", font=mark), d.textlength(num, font=big)
    x0 = SS / 2 - (wm + gap + wn) / 2
    cx, cy = px((0.0, -0.01))
    top = d.textbbox((0, cy), num, font=big, anchor="lm")[1]
    d.text((x0 + wm + gap, cy), num, font=big, fill=255, anchor="lm")
    d.text((x0, top - SS * 0.005), "¶", font=mark, fill=255, anchor="lt")
    holes, d = mask()
    slots, ds = mask()
    for k in range(10):
        x0 = -0.31 + k * 0.058
        box = [px((x0, 0.345)), px((x0 + 0.036, 0.28))]
        box = [box[0][0], box[0][1], box[1][0], box[1][1]]
        ds.rounded_rectangle(box, radius=SS * 0.008, outline=255, width=int(SS * 0.006))
        if k < min(int(num), 10):
            d.rounded_rectangle(box, radius=SS * 0.008, fill=255)
    txt, d = mask()
    small = ImageFont.truetype(FONT, int(SS * 0.062))
    small.set_variation_by_name("Bold")
    d.text(px((0.0, -0.335)), "INSPECTED · QA-%s" % num.zfill(2), font=small, fill=255, anchor="mm")
    F, L, H, SL, TX = arr(fr), arr(let), arr(holes, 0.6), arr(slots, 0.6), arr(txt, 0.5)
    height = 0.4 + 0.35 * F + 0.45 * L - 0.4 * H - 0.08 * SL
    col = np.ones((N, N, 3)) * body
    for m, c in ((F, frame), (SL, ink), (TX, ink), (L, letter)):
        col = col * (1 - m[..., None] * (0.6 if m is SL else 1.0)) + np.array(c) * m[..., None] * (0.6 if m is SL else 1.0)
    col = col * (1 - H[..., None]) + 0.03 * H[..., None]
    lm = np.maximum(L, F)
    rough_m = rough[0] + (rough[1] - rough[0]) * lm
    metal_m = metal * lm
    ao = np.clip(0.55 + 0.45 * np.clip((height - 0.0) * 1.6, 0, 1), 0, 1)
    return height, col, np.dstack((ao, rough_m, metal_m))


tiles = [tile(*dn) for dn in DENOMS]
hgt = np.hstack([t[0] for t in tiles])
gy, gx = np.gradient(hgt)
k = 10.0
nm = np.dstack((-gx * k, gy * k, np.ones_like(hgt)))
nm /= np.linalg.norm(nm, axis=2, keepdims=True)
out = ROOT + "/assets/textures/findings_token"
os.makedirs(out, exist_ok=True)
rng = np.random.default_rng(7)
grain = np.array(Image.fromarray((rng.random((48, 144)) * 255).astype(np.uint8)).resize((hgt.shape[1], N), Image.BICUBIC)) / 255.0
alb = np.hstack([t[1] for t in tiles]) * (0.97 + 0.05 * grain[..., None])
Image.fromarray((np.clip(alb, 0, 1) * 255).astype(np.uint8)).save(out + "/findings_token_albedo.png")
Image.fromarray(((nm * 0.5 + 0.5) * 255).astype(np.uint8)).save(out + "/findings_token_normal.png")
Image.fromarray((np.clip(np.hstack([t[2] for t in tiles]), 0, 1) * 255).astype(np.uint8)).save(out + "/findings_token_orm.png")
print("ok", len(verts), "verts")
