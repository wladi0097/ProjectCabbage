# Project Cabbage

A 3D incremental game built in **Godot 4.7.2** (GDScript, Forward+, Jolt Physics). A small game for a full Steam release, built in a 3-day sprint. Mouse controls.

Design docs live in `research/`. Start with `research/index.md`. The build order is §0 of `research/cabbage-incremental-gdd.md`, and the Phase 1 details are in `research/gameplan.md`. The `research/paperclips/` docs are reference material from Universal Paperclips (formulas, projects), not our design.

## Vibe and style

Every agent follows this for art, sound, UI and writing:

- **Dark, dystopian corporate.** Cold, desaturated grey-sage, a bureaucratic mid-century office (think Severance, Brazil, Papers Please). The reference is the capsule art `research/capsule idea.png`. It is never cozy and never a cute suburban house or rustic market (an earlier pass was rejected for exactly that). Later phases get more clinical and oppressive, never cartoon-scary.
- **The fresh green cabbage is the only saturated thing on screen.** One exception: research units glow a cold, clinical cyan (lab-grade, never cute).
- **One fixed scene:** a camera looking down at an angle onto a big desk that runs off the screen edges, as in `research/camera-reference.webp`. A window to the street (no customers) along the top, above the cabbage mat on the right, with its sill flush with the desk so cabbages go straight out. It stands a little open, showing a glimpse of the street with crates where sold cabbages "land" (visual only). Interactables on the left, a desk mat on the right where the cabbages are handled. No side walls.
- **Shapes like the reference:** chunky, stylized and readable from above, with lots of physical objects, coins and particles flying.
- **Humour:** deadpan corporate satire, played straight (invoices, quotas, tickers, consultants). Player-facing text always calls the product "cabbage(s)" in every language, never "units".
- Details: the style section of `.claude/skills/godotAssetCreate/SKILL.md` and "Screen layout" in `research/gameplan.md`.

## Todo

`research/todo.md` holds open work only. Keep it short:
- Delete an item in the same turn the work finishes. Never leave done items, logs or history in it.
- Add an item only when the user mentions it or accepts a suggestion. Don't add your own ideas, deferred review points or "nice to have" items unasked; mention them in the reply instead.

## Numbers

`research/numbers.md` lists every number the save tracks, with its meaning and ideas for future use (not how it is calculated). Add a row in the same turn a new number enters `ressources/save/save_game.gd`.

## Credits

The credits show in 3 places that must always agree: `credits.txt` (the single source) and the two in-game screens that read it, the Credits screen in the settings (`ui/sub/credits_ui`) and the end card's credit roll (`ui/sub/end_card`). Any new person, outside asset, font, library, sound or song goes into `credits.txt` in the same turn, and both screens are checked to show it (neither may hold its own copy of the text).

## Pacing

Before proposing any price, unlock threshold or upgrade, calculate how long an average player needs to reach it, and show the timeline. `tools/pace.py` simulates the early game (flick time, refusals, pack prices); extend it as systems arrive. Early on, something new should arrive every 30–90 s, gaps growing slowly and never more than about 2–3 minutes in the first 15 minutes. Each upgrade should be felt (aim for +25% or more on what it improves).

## Scenes over code

Anything that belongs to a scene lives in its `.tscn`, not in code: meshes, models, lights, labels, collision shapes, Interactables, materials, UI layout and styles (a Theme). Never build fixed nodes with `.new()` + `add_child` in `_ready`. Scripts pick nodes up with `@onready var x: Type = $Path` and only change what moves during play (energies, text, visibility). Something reused gets its own scene to instance (`entities/components/light_switch.tscn`). Code only builds what is truly dynamic: one node per data entry (upgrade rows, units bought), generated meshes.

## Tests

gdUnit4 (`addons/gdUnit4`), run by `.\check.ps1` (warning check, then every suite; exit code is the only truth). One suite: `.\check.ps1 tests/entities/cabbage/cabbage_test.gd`. Compile + warnings only, no tests: `.\check.ps1 -WarningsOnly` (`--check-only -s` doesn't work here: it skips the autoloads, so game scripts fail to compile).

- Suites mirror the source tree: `entities/cabbage/cabbage.gd` → `tests/entities/cabbage/cabbage_test.gd`, `extends GdUnitTestSuite`.
- The test name is the game rule, as a sentence: `test_a_mini_weighs_about_a_quarter_of_a_full_cabbage`, never `test_squish_returns_value`.
- A failing test means the rule broke. Fix the code, and change a test only when the rule itself changed.
- Prefer pure logic (static funcs, `SaveGame.new()`). Instantiate a scene only when the rule lives in it, and free it (`auto_free`).

**Before every commit, no exceptions:**
1. Every code change comes with its tests. New rules get new tests, and changed rules get their tests updated in the same commit.
2. Run the full `.\check.ps1` and read the exit code. Commit only on exit 0. Never commit with failing, skipped or unrun tests, and never call something "should pass" without running it.

## Skills

- `/godotAssetCreate`: build an original 3D asset with scripted Blender, then check it in Godot.
- `/godotAssetImport`: bring in outside models, textures and audio.
- `/godotSoundCreate`: make sound effects with ElevenLabs, timed to the motion.

Tools: Godot `C:\Users\wladi\Desktop\Godot_v4.7.2-stable_win64.exe`, Blender 5.2 (headless only), ffmpeg on the PATH.

## Running Godot

You may start Godot yourself to test, probe or screenshot anything, without asking. Two rules:
- **Always close every instance you started before you finish**, including ones a crashed or timed-out run left behind. Before reporting, list the running Godot processes and kill the ones that are yours (by the PID you started, never the user's open editor). This applies to subagents too.
- **Prefer windowed** (a small window). Go bigger or fullscreen only when the thing you are checking needs the size.

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
