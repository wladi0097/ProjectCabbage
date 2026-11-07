# Full-game-only content

Everything in this folder ships in the full game only: the demo export ("Windows Demo" in
export_presets.cfg, feature tag `demo`) excludes `full/*` (see globalScripts/demo.gd,
FULL_ONLY_DIRS). Put later stages and anything the demo must not contain here, and load it
from shared code only behind `Demo.active()` checks or `ResourceLoader.exists()`.
