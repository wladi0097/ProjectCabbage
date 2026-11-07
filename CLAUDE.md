# Project Cabbage

A 3D incremental game built in **Godot 4.7.2** (GDScript, Forward+, Jolt Physics). A small game for a full Steam release, built in a 3-day sprint. Mouse controls.

Design docs live in `research/`. Start with `research/index.md`. The build order is §0 of `research/cabbage-incremental-gdd.md`, and the Phase 1 details are in `research/gameplan.md`. The `research/paperclips/` docs are reference material from Universal Paperclips (formulas, projects), not our design.

## Vibe and style

Every agent follows this for art, sound, UI and writing:

- **Dark, dystopian corporate.** Cold, desaturated grey-sage, a bureaucratic mid-century office (think Severance, Brazil, Papers Please). The reference is the capsule art `research/capsule idea.png`. It is never cozy and never a cute suburban house or rustic market (an earlier pass was rejected for exactly that). Later phases get more clinical and oppressive, never cartoon-scary.
- **The fresh green cabbage is the only saturated thing on screen.** One exception: research units glow a cold, clinical cyan (lab-grade, never cute).
- **One fixed scene:** a camera looking down at an angle onto a big desk that runs off the screen edges, as in `research/camera-reference.webp`. A window to the street (no customers) along the top, above the cabbage mat on the right, with its sill flush with the desk so cabbages go straight out. It stands a little open, showing a glimpse of the street with crates where sold cabbages "land" (visual only). Interactables on the left, a desk mat on the right where the cabbages are handled. No side walls.
- **Shapes like the reference:** chunky, stylized and readable from above, with lots of physical objects, coins and particles flying.
- **Humour:** deadpan corporate satire, played straight (invoices, "units", tickers, consultants).
- Details: the style section of `.claude/skills/godotAssetCreate/SKILL.md` and "Screen layout" in `research/gameplan.md`.

## Todo

`research/todo.md` holds open work only. Keep it short:
- Delete an item in the same turn the work finishes. Never leave done items, logs or history in it.
- Add an item only when the user mentions it or accepts a suggestion. Don't add your own ideas, deferred review points or "nice to have" items unasked; mention them in the reply instead.

## Numbers

`research/numbers.md` lists every number the save tracks, with its meaning and ideas for future use (not how it is calculated). Add a row in the same turn a new number enters `ressources/save/save_game.gd`.

## Pacing

Before proposing any price, unlock threshold or upgrade, calculate how long an average player needs to reach it, and show the timeline. `tools/pace.py` simulates the early game (flick time, refusals, pack prices); extend it as systems arrive. Early on, something new should arrive every 30–90 s, gaps growing slowly and never more than about 2–3 minutes in the first 15 minutes. Each upgrade should be felt (aim for +25% or more on what it improves).

## Skills

- `/godotAssetCreate`: build an original 3D asset with scripted Blender, then check it in Godot.
- `/godotAssetImport`: bring in outside models, textures and audio.
- `/godotSoundCreate`: make sound effects with ElevenLabs, timed to the motion.

Tools: Godot `C:\Users\wladi\Desktop\Godot_v4.7.2-stable_win64.exe`, Blender 5.2 (headless only), ffmpeg on the PATH.

## Folder structure

- `assets/` – raw art & audio (audio, fonts, materials, meshes, shaders, sprites, textures)
- `entities/` – scenes + scripts for game objects (`player/`, reusable `components/`)
- `globalScripts/` – autoloads / singletons (game state, save, upgrades)
- `ressources/` – `.tres` resources (input, save, theme, translations)
- `ui/` – menus and HUD (`elements/` reusable widgets, `sub/` sub-menus)
- `worlds/` – `MainStoryWorld.tscn` is the main world for the whole game (one fixed table scene); `components/` holds its pieces
- `tests/` – tests, mirroring the source tree
- `addons/` – third-party plugins
- `tools/`, `reports/`, `research/` – not part of the game (git-/Godot-ignored)
