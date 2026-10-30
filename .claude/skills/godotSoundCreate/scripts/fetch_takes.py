import json
import os
import subprocess
import sys
import urllib.request

if len(sys.argv) < 4:
    sys.exit("usage: fetch_takes.py <names.tsv> <out dir> <status.json>...")

names = []
for line in open(sys.argv[1], encoding="utf-8"):
    if line.strip():
        prefix, name = line.rstrip("\n").split("\t")
        names.append((prefix, name))

out = sys.argv[2]
os.makedirs(out, exist_ok=True)
pending = []
for status in sys.argv[3:]:
    for g in json.load(open(status, encoding="utf-8"))["generations"]:
        name = next((n for p, n in names if g["prompt"].startswith(p)), None)
        if not name:
            continue
        path = os.path.join(out, f"{name}_{g['id'][:4]}.wav")
        if g["status"] != "completed":
            pending.append(f"{name}_{g['id'][:4]}:{g['status']}")
        elif not os.path.exists(path):
            mp3 = path[:-4] + ".mp3"
            urllib.request.urlretrieve(g["content_url"], mp3)
            subprocess.run(["ffmpeg", "-loglevel", "error", "-y", "-i", mp3, "-af",
                            "pan=mono|c0=0.5*c0+0.5*c1,aresample=resampler=soxr",
                            "-ar", "32000", "-c:a", "pcm_s16le", path], check=True)
            os.remove(mp3)
print("pending:", pending or "none")
