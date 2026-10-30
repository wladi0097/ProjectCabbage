import array
import glob
import math
import os
import subprocess
import sys

if len(sys.argv) < 2:
    sys.exit("usage: peaks.py <dir> [glob, default *.wav]")

pattern = sys.argv[2] if len(sys.argv) > 2 else "*.wav"
for f in sorted(glob.glob(os.path.join(sys.argv[1], pattern))):
    raw = subprocess.run(["ffmpeg", "-loglevel", "error", "-i", f, "-ac", "1", "-ar", "8000", "-f", "s16le", "-"],
                         capture_output=True).stdout
    a = array.array("h", raw)
    window = 800
    env = []
    for i in range(0, len(a), window):
        s = a[i:i + window]
        rms = math.sqrt(sum(x * x for x in s) / max(len(s), 1))
        env.append(int(20 * math.log10(max(rms, 1) / 32768)))
    at = max(range(len(a)), key=lambda i: abs(a[i]))
    peak = 20 * math.log10(max(abs(a[at]), 1) / 32768)
    print(f"{os.path.basename(f):32} {len(a) / 8000:4.2f}s pk {peak:5.1f} @{at / 8000:4.2f}s {env}")
