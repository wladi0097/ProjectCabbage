---
name: godotAssetCreate
description: Design and build an original 3D asset for Project Cabbage from scratch (a prop like the cabbage, coin jar or crate, a stall fixture like the chalkboard or chute, a diorama building or machine). Covers ideas and Blender mockups for sign-off, the scripted .blend with shared materials, one skinned mesh for moving parts, Godot import, materials, scene and script, screenshots in Godot and a mandatory independent art review. Use /godotAssetImport for outside assets and /godotSoundCreate for its sounds.
argument-hint: "[what to make, e.g. 'the coin jar that fills as you sell']"
---

# Godot asset create

Make the thing the user describes so it fits Project Cabbage's table scene, stays
cheap enough to show many copies at once, and is checked in Godot before
handover. Every asset is built by a Python script in headless Blender, so a
review round only changes numbers.

The first assets built this way go in a "Worked examples" list at the end of
this file, with their scripts under `examples/`. Copy from them instead of
starting blank. When the user corrects a rule here, fix this skill in the same
turn.

Input: $ARGUMENTS

## 1. Ideas before anything else

- Read the request, then `research/index.md`, the GDD
  (`research/cabbage-incremental-gdd.md`) and `research/gameplan.md` for
  where the asset appears, what it does and which phase it belongs to.
- Offer 2–3 options per part (shape, how it moves or reacts, where it sits),
  recommend one, and ask which. Don't build before the user picks.
- Then **mockups**: quick headless renders (`preview.py`) beside the 1.85 m
  scale capsule, with every state shown (empty/full, closed/open,
  idle/working). Send them with `SendUserFile` and iterate. The user can only
  judge colour on a **textured** mockup, so texture from the second round on.
- Ask once whether the asset needs a texture of its own. Otherwise reuse one
  (§4).

## 2. Style: does it belong in this game?

From the user's decisions (2026-10-30) and the GDD. Update this section as
the user decides more:

- **One fixed scene: a table seen from above at an angle,** like
  `research/camera-reference.webp` (layout in `research/layout-sketch.png`):
  a window to the street along the top (no customers; just a glimpse of street and crates),
  interactables down the left, the cabbage pile in the rest. The camera
  never moves, so every asset must read **from above at that angle and at
  that distance**. Judge the silhouette and the top face first.
- **Shapes like the reference, mood like the capsule.** Chunky, slightly
  exaggerated, readable stylized forms and lots of physical objects, coins and
  particles flying, as in the reference. But the mood is **dark, dystopian
  corporate** like `research/capsule idea.png`: cold, desaturated grey-sage,
  bureaucratic mid-century office (think Severance, Brazil, Papers Please).
  The user rejected a first pass for looking like "a small cute house in the
  suburbs": no red brick, no painted cottage windows, no rustic market table.
  **The fresh green cabbage is the one saturated thing on screen.**
- **Later phases arrive on the table** as new panels, machines and models
  (maps, screens, a little rocket). They must fit beside the earlier props
  and leave room for the cabbage pile.
- **Analog vs. digital.** Everything the player owns is hand-made and
  physical: wood, chalk, burlap, clay, tin, worn paint. Everything from the
  supply chain is a glowing screen or ticker. Keep the two clearly apart.
  Screens slowly replacing hand tools is a deliberate tone lever.
- **Dark from the start, darker later.** The GDD's "cozy, then quietly
  sinister" arc now starts already cold and corporate; later phases get more
  clinical and oppressive. Never cartoon-scary.
- **Corporate satire.** The language around the humble stall is corporate
  (invoices, "units", tickers, notices on the desk).

What to avoid on first passes: detail that disappears from the camera's
distance, thin parts that vanish from above, uniform flat grey, glass or
screens that glow flat white (keep emission low and saturated), details
nobody asked for.
Metal near lettering or numbers (bezels, plates, hoppers) stays matte,
roughness 0.6 or more: the desk lamp glares glossy metal out and the user
could not read the tally machine's digits (2026-10-30).

## 3. Scale, origin, orientation

| Thing | Rule |
| --- | --- |
| Person (scale ref) | ~1.85 m |
| Cabbage | 0.18 m mesh, shown at 1.5× (~0.27 m) in MainStoryWorld; many on screen, keep it cheap (§5) |
| Table | top at y 0.75, x −3.2…+3.2, z −0.75…+1.25; left section x < −0.6, mat x −0.45…+1.85, z −0.6…+1.1, top 0.76 |
| Back wall | inner face z −0.80, outer −1.05; window opening x −0.55…+1.95, y 0.75…1.90, over the mat. Sill top flush at 0.75; lower sash raised, open gap y 0.75…1.07. Street at y 0.5 (ground floor, just below the sill), plain empty crates just outside at z ≈ −1.4 |
| Game camera | (0.25, 3.2, 1.6) looking at (0.25, 0.75, 0.25), vertical FOV 40° |
| Front | Blender −Y = Godot +Z. The camera looks at the table from the front-top; props face it |
| Origin, free-standing | floor centre |
| Origin, on a wall | back centre |
| Origin, thrown/rolled prop (the cabbage) | its centre of mass, so physics and spin look right |
| Origin, moving parts | each bone's head at the part's pivot |

## 4. Materials: reuse first

Every surface is a draw call, so a new material needs a reason. Keep the list
below current: every shared material gets a row when it is made.

| Material | Use |
| --- | --- |
| `table_wood.tres` | dark grey-brown desk wood (ambientCG Wood060, stylized), `uv1_scale` 0.6 |
| `table_steel` (embedded in `table.blend`) | dark brushed steel: desk edge band, divider, legs. Extract to a `.tres` when a second asset needs it |
| `table_mat.tres` | the cabbage mat: dark grey-green leather blotter, generated texture (`table_mat_pack.py`), UV 0–1 over the mat. Noise regenerated 2026-10-30 with the pebble grain 2× coarser and fainter and the mottle 4× larger: the finer noise was "too noticeable" |
| `cabbage.tres` | the cabbage: one generated atlas, one tint row per variant, cheap backlight, low specular (0.2), faint rim. No clearcoat: the user found it "way too shiny" |
| `entities/cabbage/cabbage_belt.tres` | the condensed cabbage's paper belt: `cabbage_belt.gdshader` on the `cabbage_belt_print` atlas (row per count, instance uniform) and the `cabbage_belt_reach` table; lit paper, roughness 0.9, emission 0.08 of albedo. Beside its entity; in the shader warm-up |
| `machine_paint_matte.tres` | `machine_paint` with no shine (roughness 1, specular 0.05), for flat paint facing the lamp: the inbox tray's floor glared white with the shared one |
| `room_wall.tres` | grey-sage painted concrete blocks, generated, `uv1_scale` 0.41667 |
| `room_wall_map.tres` | the map corner's walls (right side wall + back wall x > 3.2): cold grey board-formed concrete, ambientCG Concrete029 1K (CC0) via `examples/room_wall_map_pack.py` (greyscale, flattened, normal 0.75), tinted (0.5, 0.51, 0.52), `uv1_scale` 0.41667 (boards 15 cm, a pour joint every 1.2 m). The brick/concrete change at x 3.2 sits under a dark steel cover strip, and a steel rail at desk height (z 0.72..0.80) runs round the corner (both `room_window`) |
| `room_window.tres`, `room_blinds.tres` | flat dark steel / flat grey, no textures |
| `room_street.tres` | wet concrete paving outside, generated, `uv1_scale` 0.41667 |
| `hand.tres` | the player's 3D glove: generated `hand_fabric` weave (`hand_tex.py`), triplanar `uv1_scale` 25 (the remeshed glove has no UVs), tinted by the mesh's `Col` vertex colours (grey glove, charcoal suit, white shirt edge) |
| `room_crates.tres` | weathered grey slat crates, "UNITS LOT 07" stencil, cabbage-green lumps; one generated atlas |
| `price_slate.tres` | dark chalk slate with faint eraser haze, generated (`examples/slate_tex.py`), `uv1_offset` 0.5 so the face sits mid-tile |
| `coin.tres` | worn brass coin, generated (`coin_tex.py`): a 9-wide atlas, one face per denomination ($1/$5/$10 dot ring, $50 octagon, $100 reeded rim + dark inlay, $500 pale centre in a dark barred band, $1K scalloped seal, $5K square seal, $10K double reeded rim on black), each filling its UV square (top projection); `CoinPile` picks the column and sets tint + scale per denomination . Metallic from ORM blue; $50 and up rougher (satin). No glow: the designer liked the coins plain |
| `findings_token_500/1K/5K/10K.tres` | the high Findings tokens: `findings_token.gdshader` on the 4-wide `findings_token_high` atlas (`findings_token_gen.py`), `column` per material, a cold cyan emissive rim on the side wall (no lights, opaque), strength `rim_level` per material (0.35 / 0.65 / 0.85 / 1.0). A glow on the cyan parts was tried and dropped (too loud on the ¶10K). ¶1K+ use `findings_token_2.obj` (both far corners notched) |
| `machine_paint.tres`, `machine_metal.tres` | tiling greyscale enamel / brushed metal (`machine_tex.py`), `uv1_scale` 4, **tinted by vertex colour** (`vertex_color_use_as_albedo`): one surface serves enamel + bakelite, one serves chrome + brass. Reuse for later machines |
| `card_paper.tres` | the upgrade cards' FORM 7-B paper: generated (`examples/card_tex.py`) warm grey stock, sage header band, perforated stub, faint grid and seal; UV 0–1 over a PlaneMesh, double-sided, **unshaded** at 0.78 grey: lit by the lamp it bloomed and the text washed out. `card_paper_on_top.tres` is the same with no depth test for hovered/held cards (drawn over the hand). Text stays Label3D, unshaded |
| `machine_dial.tres` | the tally machine atlas: odometer digits 0-9 along v in u 0-0.11, black drum sides, brass "$$$" plate in u 0.5-1, v 0.8-1, brass "¶¶¶" Findings plate in u 0.25-0.5, v 0.9-1, acceptance gauge face in u 0.5-1, v 0.25-0.75 (all painted by `machine_tex.py`) |
| `machine_digits.tres` | the tally drums' faces: the `machine_dial` atlas **unshaded** at 0.7 grey, so the lamp and shadows never wash out the numbers (user: counters were hard to read). Its own surface in `tally_machine_geo.py`, whose face now rises at 50° so the drums face the game camera |
| `tv_powder.tres` / `tv_chrome.tres` / `remote_plastic.tres` | the farm TV's case (ambientCG Metal028 powder coat, treated as paint), its chrome trim and the remote's chrome band (Metal049B, fixed satin roughness 0.35: its own map at ~0.12 mirrored the dark room black), the remote's body (Plastic018B). Greyscale flattened albedos tinted by the vertex colours, CC0 |
| `qa_glass.tres` | the QA bay's chamber top: tinted glass, alpha 0.28, glossy |
| `tube_glass.tres` | the mini tube trench's flush lid: darker, near-clear glass (alpha 0.12) so the mini shows through; the teal qa_glass read as "a fish tank" there |
| `ramp_steel.tres` | brushed sheet steel for big flat parts (the supply chute, its dock): own tiling texture (`ramp_steel_tex.py`, faint streaks along U, soft grime), `uv1_scale` 2, tint 0.68. The shared `machine_metal` grain looked speckled at that size, an untextured steel was rejected as "no texture", and a first brushed pass with strong streaks read as wood planks |
| `prior_cover_1..3.tres` | the prior venture frames' cover art (`assets/textures/prior_ventures/`, originals in `src/`, muted by `examples/prior_venture_cover_mute.py`: 30% saturation, 75% brightness, cold sage cast), roughness 0.12 for a glass sheen; one per frame, set as the Cover's `material_override` |
| `cabbage_gold.tres` | golden units: the cabbage normal + AO, **no albedo texture** (the rotten albedo under a gold tint read as muddy olive-bronze), pale cold gold `albedo_color` (0.88, 0.8, 0.58), metallic 1, roughness 0.4 (0.3 sparked like foil on the leaf edges), faint emission 0.25 and rim so it holds up in the dark room |
| `mug_print.tres` | the coffee mug's No More Sleep logo print (`assets/textures/no_more_sleep/`, white on transparent from the UnitedHeist2 project), tinted cream, alpha scissor |
| `entities/field_line/field_line_lamps.tres` | the Field Line's 24 jewel lenses: `assets/shaders/jewel_lamps.gdshader`, one mesh and one draw call for the whole bank. Each lens carries its index in UV.x ((index + 0.5) / `lamps`); the instance uniform `lit` lights the first n (dull oxblood emission, energy 0.8; unlit a dark red glass, with a faint `idle` glow of 0.45 so the grid reads in the dim desk corner). Lives beside its entity, not in `assets/materials/`, so it is not in the shader warm-up. Reuse the shader for any lamp bank |

- Shared materials live in `assets/materials/<name>.tres`, textures in
  `assets/textures/<name>/<name>_albedo|normal|orm.png` (ORM = AO,
  roughness, metal). ambientCG or Poly Haven 1K is the default source; see
  /godotAssetImport §6 for the `.import` settings.
- **Store colour textures as greyscale and tint them.** One texture, many
  colours. A shader `vec3` tint is linear; a StandardMaterial `albedo_color`
  is sRGB.
- Small coloured parts share one **trim sheet** (one texture with rows of
  paint, metal, wood, chalk and so on) instead of each getting a material.
  Add a row rather than a material.
- State (a jar's fill, a lamp's glow, a phase's desaturation) goes through
  **instance uniforms**, so one material serves every copy. Two materials on
  one mesh that each declare an instance uniform share slot 0 and overwrite
  each other; give the second one `instance_index(1)`.

## 5. Performance

Desktop PC, Forward+. The cost to watch is **many copies** (an incremental
game multiplies everything) and the table filling up every phase. These are
starting values; tighten them when a profile says so.

| Budget | Repeated prop (cabbage, coin, crate) | Hero piece (stall, chalkboard, rocket) |
| --- | --- | --- |
| Surfaces (draw calls) | 1–2 | ≤ 4, moving parts included |
| Triangles | ≤ 1.5k | ≤ 15k |
| Collision | one primitive, or none | a few boxes, never trimesh |
| Lights | none, glow is emission | at most one, only if the scene needs it |

- **More than ~20 copies → `MultiMeshInstance3D`**, not separate nodes. A
  physics-thrown cabbage is a node only while it flies, then it goes back
  into a MultiMesh or is freed.
- **Moving parts are one skinned mesh**: one root bone per part, rigid
  weights, posed from script (§7). Separate objects multiply draws.
- Let Godot generate LODs. Set `visibility_range_end` on small props that the
  camera never sees up close.
- Particles: one-shot `CPUParticles3D` or `GPUParticles3D`, ~24 quads, only
  while emitting.
- Measure with `Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME` in a probe.
- **Baked light (measured 2026-11-12).** `MainStoryWorld`'s LightmapGI bakes
  bounced light and ambient occlusion into the room and the desk only. Every
  other asset stays out of the bake, because it moves, is skinned, is spawned
  or appears later in the game (a baked prop leaves its shadow on the desk
  before it is unlocked). So by default:
  - **Anything else than room or desk:** `import_script/path="res://assets/meshes/unbaked_import.gd"`
    in the `.blend.import` (sets `gi_mode` Disabled on every mesh), keep
    `meshes/light_baking=1`. A `MeshInstance3D` / `MultiMeshInstance3D`
    written in a `.tscn` (a `.res` mesh, a BoxMesh) gets `gi_mode = 0`.
  - **Part of the room or desk that never moves and is there from the first
    second:** no import script, `meshes/light_baking=2` and
    `meshes/lightmap_texel_size=0.02` (Godot unwraps UV2 on import; a
    primitive mesh needs `add_uv2 = true`), `gi_mode` Static (the default),
    then re-bake: select `LightmapGI` in `MainStoryWorld` → Bake Lightmaps.
  - **A light on an asset** gets `light_bake_mode = 0` (Disabled) so its
    bake-time energy is never frozen into the desk. Only the three room
    lights feed the bake (Dynamic: direct light and shadows stay real-time).
  - `gi_mode` Dynamic (probe-lit) is not used: with ~200 moving meshes it
    doubled the render CPU time (0.78 → 1.56 ms).
  `tests/worlds/main_story_world_test.gd` holds these rules.

## 6. Build in Blender (headless)

Blender 5.2: `"C:\Program Files\Blender Foundation\Blender 5.2\blender.exe"`.
Never touch the user's open Blender session.

Write `<asset>_geo.py` in the scratchpad (it defines materials, geometry,
`ASSET`, `FRAME` and optionally `STATES`), then:

```bash
cat .claude/skills/godotAssetCreate/blender_lib.py <scratch>/<asset>_geo.py .claude/skills/godotAssetCreate/preview.py > <scratch>/build.py
"/c/Program Files/Blender Foundation/Blender 5.2/blender.exe" -b --factory-startup -P "$(cygpath -am <scratch>/build.py)" -- "$(cygpath -am assets/meshes/<Category>/<snake_name>.blend)" "$(cygpath -am <scratch>/shots)"
```

Add `SAVE=1` in front to save the `.blend`. `TEX=<dir>/` overrides the
texture folder.

- Always pass **absolute** paths (`cygpath -am`); relative ones land in `C:\`.
- `blender_lib.py` helpers: `material`, `emissive`, `textured`, `box`/`boxed`/
  `part_box` (bevelled boxes), `lathe`/`lathed`/`spin` (lathe profiles; `spin`
  stands upright), `tube`/`rod` (swept tubes), `merge`, `finish`, `boolean`,
  `absorb`, `rig`, `at`.
- `finish()` marks edges sharper than 35° as sharp, adds a WeightedNormal
  modifier, and box-projects UVs at 1 unit = 1 m.
- `preview.py` sets up a neutral backdrop, warm key and cool fill light, and
  the scale capsule. It shoots `<ASSET>_rest.png` plus one png per `STATES`
  entry (each a function that poses the armature's bones; bone-local Y is
  world Z for upright bones), and prints `TRIS`. Preview objects end in
  `-noimp` and are removed before saving.
- Save to `assets/meshes/<Category>/<snake_name>.blend` (Category:
  `Props`, `Stall`, `Buildings`, `Machines`, … in PascalCase; create it if
  missing). Delete only the `<your file>.blend1` your own save just created,
  never a glob: other `.blend1` files are the user's backups.
- Write `<name>.blend.import` before the first import: map every material
  slot to its `.tres` in `_subresources` (as in /godotAssetImport §8). Once a
  first `.blend.import` exists, copy it and drop the `uid=`, `path=` and
  `dest_files=` lines.

**UV traps (each cost a review round in the last project):**
- A mesh pulled in with `absorb()` brings its own `UVMap`. `finish()` reuses
  it; if you create UVs elsewhere, use `layers.uv.get("UVMap") or new`, or
  the projected UVs land on `UVMap.001` and every texture turns flat.
- A second UV map (decals, labels) must not be wired into a Blender
  material's base colour, or Godot's glTF import swaps UV1 and UV2 on that
  surface. Keep the preview material on the first map, with
  `uv_layers["UVMap"]` active and `active_render`.
- Lathe open shapes (a jar, a bowl) as a closed profile. An open one gets its
  normals flipped by `recalc_face_normals` and Godot culls it.
- Vertex colours reach Godot only if the Blender material reads the colour
  attribute and it is the render colour, **and** the `.blend.import` has
  `blender/meshes/vertex_colors=0` (the enum is Material, Active, None: the
  `2` copied from the cabbage's import means None). `1` (Active) works too
  (tally machine).
- `merge()` overwrites every face's material index. For a part that carries
  several materials (a drum with dial + caps), `bmesh.ops.transform` it and
  hand it to `rig()` directly.
- Check what arrived, never assume: run `probe_import_tree.gd` (§7).

## 7. Godot

Godot: `C:\Users\wladi\Desktop\Godot_v4.7.2-stable_win64.exe`.

**Import.** If the editor is open, ask the user to focus it once (it imports
on focus) and to close any scene tab you will edit. Never run `--import`
beside an open editor. An open editor also **saves its in-memory copy of a
`.tres` over your edit**: after the user touches the editor, re-read every
material you changed. With the editor closed:

```powershell
Start-Process -FilePath 'C:\Users\wladi\Desktop\Godot_v4.7.2-stable_win64.exe' -ArgumentList '--headless','--path','C:\Users\wladi\Desktop\ProjectCabbage','--import' -WorkingDirectory 'C:\Users\wladi\Desktop\ProjectCabbage' -Wait -PassThru -NoNewWindow
```

Then print what arrived:

```powershell
& 'C:\Users\wladi\Desktop\Godot_v4.7.2-stable_win64.exe' --headless --path 'C:\Users\wladi\Desktop\ProjectCabbage' -s 'C:/Users/wladi/Desktop/ProjectCabbage/.claude/skills/godotAssetCreate/probe_import_tree.gd' -- res://assets/meshes/<Category>/<name>.blend
```

(Tested 2026-10-30.) A Blender armature arrives as
`<root>/Armature/Skeleton3D/<Mesh>`, with identity bone rests at the pivots.
A bone named like its mesh gets renamed (`Lid` → `Lid_2`), so give bones
their own names (`LidHinge`).

**Hand-written transforms in a `.tscn` list the basis by rows**: `Transform3D(xx, yx, zx, xy, yy, zy, xz, yz, zz, ox, oy, oz)` is wrong, write row 0 = (X.x, Y.x, Z.x) etc. Writing columns transposes the rotation (labels, colliders and sprites came out sideways once). Print the rows from the build script when a collider must match a Blender part (`supply_ramp_geo.py` does).

**Scene.** `entities/<name>/<name>.tscn` for things the player or the
simulation acts on, `worlds/components/<name>.tscn` for table and window dressing.
Root node of the right type, the imported model as a `Model` child, collision
only if physics needs it. Check the folder for a similar scene first and
match it.

**Script.** Keep the logic in `static func`s (progress → pose, value → look)
so it can be tested without a scene. The node only adapts. It **snaps** to
the current state in `_ready` (a loaded save stays silent) and animates only
on change. Pose root bones like this:

```gdscript
skeleton.set_bone_pose_position(i, rest.origin + shift)
skeleton.set_bone_pose_rotation(i, Quaternion(axis, angle) * rest.basis.get_rotation_quaternion())
```

Sound slots stay as exports with null streams. /godotSoundCreate fills them.

**Tests.** Once the project has a test setup in `tests/`, add tests for the
static functions (each state's pose, cue order). Until then, say in the
report that there are none.

## 8. Look at it, then have it judged

1. A **probe scene** in the scratchpad (`extends SceneTree`, run with `-s`,
   needs a window, so say so): instance the asset in a plain lit scene (sun
   with shadows, sky, SSAO), drive every state through its API, and shoot
   each state plus mid-animation at the distances its phase shows it from
   from the fixed game camera (and one close-up). Print the draw calls.
2. Make a contact sheet (`contact_sheet.py`; the system Python has PIL, in Git
   Bash call it as `powershell -NoProfile -Command "python ..."`) and look at
   every shot yourself.
3. **Independent review, every time:** spawn a fresh agent that has seen no
   code. Give it the style of §2, what the asset is and does, and the
   screenshot paths. Ask: does it look good and read at gameplay distance;
   does it match the reference (chunky, stylized, readable from above?); do the
   states read instantly; a ranked list of improvements, cheap ones marked.
   Apply what is cheap and right, re-shoot, and report what was deferred.
4. Kill only the Godot and Blender processes you started.

## 9. Hand over

- Add new shared materials to §4, and the asset to "Worked examples" below
  with its build script copied to `examples/`.
- Report: files built, API and exports, triangles and draw calls, materials
  reused vs new, sound slots, where the screenshots are, and the review
  verdict with what was applied or deferred.

## Worked examples

First vibe check (2026-10-30), scripts in `examples/`: `table_geo.py` + `table_preview.py` + `table_wood_pack.py` / `table_mat_pack.py` (desk + mat), `cabbage_geo.py` + `cabbage_tex.py` + `cabbage_preview.py`, `room_geo.py` + `room_tex.py`. The first pass (rustic table, brick room, street) was rejected as "cute suburban house"; signed off by the user: `research/shots/vibe_check_1.png`.

Hand cursor (2026-10-30): `hand_geo.py` + `hand_save.py`, a cartoon clerk's glove in cold grey (3 fingers + thumb, puffy palm, flared cuff, white shirt edge, short rounded sleeve stub). Blocked out from a palm ball and finger capsules, fused by a voxel remesh (+ smooth, decimate) into one seamless skin, weighted by script per finger chain (`chain_weights`: a vertex follows only its own finger, blended across each knuckle; the rest is Palm) to chained finger bones, which point +Z for identity rests. Heat weights (`ARMATURE_AUTO`) bled between fingers and dragged the palm: don't use them for hands. Stubby fingers can't curl a 265 deg fist without folding into a lump: keep a fist around 175 deg; rigid Sleeve bone that runs right up to the back of the hand (no wrist or glove cuff showing) and stays flatter than the hand's dome, or it hides the glove from the camera; vertex colours, one surface. Keep ~3 voxels of gap between fingers or the remesh webs them; poses live in `entities/hand/hand_model.gd`. User feedback: a boxy realistic hand was "too big and too blocky"; a steep sleeve shows its end cap as a black disc to the camera, so keep it a short stub. No stitch lines on the back: the user found them too Mickey Mouse.

Stage 1 (2026-10-30): `coin_geo.py` + `coin_tex.py` (lathed coin, top-projected stamp UVs, mesh extracted to `coin.res` via `save_to_file` for the MultiMesh); `tally_machine_geo.py` + `machine_tex.py` (boolean window recess, nine seam-split drum bones, vertex-coloured trim surfaces, atlas UVs written after `rig()`). The first machine (adding machine with keys and crank) was rejected: too low poly, untextured, and keys/crank looked operable. The first coin stamp (cabbage-leaf curves) read as anatomy: keep emblems blunt (numerals, seals). In the world the tally machine is shown at 1.3× so the drums read from the game camera.

Stage 1 restock (2026-10-30):
- **`supply_ramp_geo.py`:**
  - a tapered sheet-steel chute in its own frame `CH`, built from `hull()` slabs: wide at the lip so cabbages spread out, narrow at the top so they come down in a line;
  - the wall ends are closed over the bent lip;
  - a drum bar hangs under the front edge, and its drums turn about the wall direction (printed as `DRUM_AXIS`);
  - a dock plate is braced to the legs;
  - the script prints the Godot collider transform.
- **`supply_console_geo.py`:** a slanted terminal with a boolean CRT recess and a `Plunger` bone. The price, sparkline and icon are Godot overlays.
- **`ramp_steel_tex.py`:** the chute steel.

User corrections:
- **One connected unit.** The counter, console and chute must read as one connected unit.
  - A free-standing counter box and a shelf were rejected.
  - A green box on the wall was rejected ("just the bar with the numbers").
  - A steel strip between the wall and the numbers was rejected.
  - The counter became just the drum bar, hung right under the chute's front edge, with full tally-size drums: at 3/4 size the digits were unreadable from the game camera. The chute was raised 7 cm to make room.
- **Layout.** BUY sits in the bottom-right corner below the chute, and the button carries an icon, not text.
- **Variable names.** Never name a variable `OUT` in a geo script: it overwrites `blender_lib.py`'s output path and the save fails.

Stage 1 price slate (2026-10-30): **`price_slate_geo.py`** + **`slate_tex.py`**. A static (unrigged) desk slate tilted 61° back, so its face looks straight at the game camera; a wire kickstand behind and a chalk tray in front. The script prints the face centre, normal and up in Godot space for the Label3D and collider transforms. The chalk text is a Label3D (Oswald, off-white, semi-transparent). The slate texture is not tileable: a face whose box-projected UVs straddle 0 shows four quadrant seams, so the material shifts it with `uv1_offset` 0.5. User corrections: at 1.3× it was too big (now 1×, front-left beside the mat), and a drag-to-scrub control was replaced by clickable chalk `<` `>` labels that brighten and grow on hover; the art review asked for a darker frame (it read near-white under the desk lamp) and a cooler face.

Upgrade desk (2026-10-31), scripts in `examples/` (prepend `desk_vc_common.py` after `blender_lib.py`): `approval_press_geo.py` (skinned: Body, Head slides, Lever rotates about X at its pivot; the handle collider is moved by code, no BoneAttachment), `inbox_tray_geo.py`, `spike_file_geo.py`, `card_tex.py`. The independent review asked for a chunkier press (the first column and arm read as a desk lamp from the game camera), a thicker, taller spike (a 3.5 mm spike was invisible) and a bigger diagonal APPROVED; all applied.

The previous project's examples (industrial machines, doors, skinned rigs,
trim-sheet mapping, decal UV2) are in
`C:\Users\wladi\Desktop\UnitedExpedition\.claude\skills\godotAssetCreate\examples\`.
Read them for technique only: their style, materials and paths don't apply
here.

Acceptance gauge (2026-10-31): `acceptance_gauge_geo.py`, a round steel gauge clamped to the price slate's corner, Body + Needle bones (needle turns about the face normal, Godot `Vector3.BACK`). Its face is painted into the free block of the `machine_dial` atlas by `machine_tex.py` (centre (768, 512) px); the mockup appends `price_slate.blend` as `-noimp` context. User feedback: at desk distance small print vanishes, so a dial gets three bold numbers and one word, no fine ticks or slogans; turn small readouts to face the game camera fully (it was "too small" and foreshortened at the slate's tilt): in the slate scene it is shown at 2× and aimed at the camera.

Coin collector (2026-10-31): `coin_vacuum_geo.py` + `vacuum_dock_geo.py` (prepend `desk_vc_common.py`), a robot-vacuum puck and its dock, static, three objects each (body, `Lamp` with its own material, the puck's `Brush` with its origin at the hub). The puck faces Blender +Y (Godot -Z) for a driving script; both are built at design size and scaled ×2 by `K` at the end. At the brief's 0.11 m (and 1.5×) the puck was barely bigger than a coin and read as a button from the game camera. The review asked for a dark putty shell on `machine_paint_matte` (a pale one read as a silver coin, the glossy one as hammered pewter), a dark brown-amber lamp when off (cream off and lit looked alike) and splayed brush spokes (one thin stick read as a stray pin).

QA bay and Findings counter (2026-10-31): `qa_bay_geo.py`, a steel inspection cabinet filling the window gap's left third (fits under the raised sash: 0.32 m tall), Body + Flap (hinge on the mouth, `Vector3.RIGHT`) + Needle bones, a glass-topped chamber big enough for a cabbage (collider radius 0.11). The tally machine has two rows: money drums low on the slope with the "$$$" plate left of them, and an empty slot above; `findings_counter_geo.py` runs `tally_machine_geo.py` with `COUNTER = "findings"` to build just the 6-drum row with its "¶¶¶" plate in the tally's own space, and it drops into that slot when QA is bought. The mockup shot it from the game camera with the room, table, tally and slate appended as `-noimp` context (`game_context.py` pattern: Godot (x, y, z) = Blender (x, -z, y), vertical sensor fit, lens 12/tan(20°)). User feedback: the wall above the tally is off-screen; a new currency gets a row on the existing tally box (one machine for all counters), arriving when unlocked; a currency plaque goes left of its drums; a currency symbol must not look like "$" (§ was rejected, ¶ chosen).
`findings_token_gen.py` (2026-11-07): the QA Findings tokens, no Blender: writes the bevelled square chit as an `.obj` plus a 5-wide atlas (¶1 grey / ¶5 sage / ¶10 black-and-brass / ¶50 dark petrol-slate with pale steel frame and inner line / ¶100 ivory with a muted cyan frame and inner line, 2026-11-13), one ORMMaterial3D per denomination picks its column by `uv1_offset` (scale 0.192, offset (k + 0.02) / 5); the `Slip50` / `Slip100` templates step up in size like the $50/$100 coins. A first ¶100 frame at (0.2, 0.55, 0.62) was too bright a cyan.

Mini tube (2026-11-07): `table_tube_geo.py` (prepend `blender_lib.py` only) rebuilds the desk from `table_geo.py` with axis-aligned holes cut out of the boards (`holed_box`: exact booleans on the desk and mat wiped the whole mesh) plus steel liners, and the mat with a notch in its outline; shown instead of table.blend's Table + cabbage_mat (a visibility swap, never both). `mini_tube_geo.py` (prepend `desk_vc_common.py`) builds the flush steel trims, the trench's glass lid and a points lever whose swing plane faces the game camera, all in Godot world space. User corrections: a glass pipe along the wall above the window gap was "way too big"; the tube must be built into the desk (routed trench, flush glass top, trim), not a pipe lying on top. Later: the lever's thin flat black quadrant fan "looks kinda bad"; it is now a bevelled sage enamel plate (`quadrant()`: an ngon prism in the swing plane, rim edges bevelled) with a pale inset face, chrome detent ticks and a chamfered hub with a hex nut. Keep big flat parts out of near-black bakelite; black stays for small knobs.

Desk records (2026-11-07): `files_folder_geo.py` and `ledger_binder_geo.py` (prepend `desk_vc_common.py`) build the FILES folder and the ledger binder, which lie side by side on the desk's left, above the card tray.
- **FILES folder** (`entities/milestone/`): skinned, with bones Base, Papers and CoverHinge (hinge at the back edge; the cover opens with `Quaternion(Vector3.RIGHT, -angle)`). A band round the back board is its own surface, `files_glow`. The script copies that material and drives `emission_energy_multiplier` from code; give it an `emission` colour in code, because a Blender strength of 0 imports as black. The FILES stamp is a Label3D on a BoneAttachment3D.
- **Ledger binder** (`entities/ledger/`): static. Hover lifts it and tips it toward the camera.
- **Vertex colours are sRGB bytes:** a manila of 0.19 read as bright tan under the desk lamp, so keep board colours around 0.09.
- **Placement:** the desk's bottom-right corner has no free room at 16:9, because the console and chute fill it.
- **Independent review:** the glow band was too thin to read (now 16 mm and brighter), the manila too warm (now grey-khaki), the ledger hover too weak (now lifted 4.5 cm and tilted), and the stamp too small.

Farm TV and L desk (2026-11-07): `farm_tv_geo.py` + `tv_remote_geo.py` (prepend `desk_vc_common.py`). The TV is four objects: the vertex-coloured case, a separate `Screen` (a 16x12 grid bulged 1.4 cm, UV 0-1 over the glass; in Godot V runs top to bottom) that takes a `ShaderMaterial` showing a SubViewport (`assets/shaders/crt_screen.gdshader`), a `Led` and a `BackArrow` with their own materials (lit from code). Keep the glass edge in front of the well behind it, or only an oval of the glass shows. User corrections: no knobs or speaker vent ("looks kinda bad"); the way back is a BACK button on the set's right panel, not a 2D arrow floating at the screen edge; the TV sits on a 45 degree corner step of the desk, a short pan from the desk view, not on the floor far left. `table_geo.py` / `table_tube_geo.py` now end the main top at x -2.0 and add that L wing (`WING_*`, `plan_prism`); rebuild both blends from the scripts together (they reproduced the old blends exactly before the change). Later corrections: the right panel only a third as wide (a small BACK plate, "the arrow is way too big"), one moulded bezel (a bevelled box minus a bevelled cutter via `boolean`, the cutter's faces given the bezel's colour index) instead of four bars, and `room_geo.py`'s back wall runs to x -8 so the TV view has wall behind the set. Playtest 2026-11-07: a thinner bezel and case rim (`B`, `RIM`; the glass constants and `SCREEN_HALF` unchanged, `BACK_CENTRE` follows `PX`), the L wing is now one desk with the main top (the boards carry on to x -3.4 or get a wing piece cut by the diagonal with the same gaps, bevel and grain offset; backing and bevelled steel band run round the L, the main top's left band stops at the corner), and `room_geo.py` has a side wall at x -3.45 so the TV view has a room corner behind it. Second round: the right panel halved again (`PW` 0.025, a tall narrow BACK plate with a dark arrow and a wrapping Label3D stencil), and the glass widened to 1296:768 (`GW` 0.3206; the SubViewport, `SCREEN_PIXELS` and farm_screen `SIZE`/`FIELD`/`SIDE` follow), framed tighter (`FILL` 0.66). L desk (2026-11-08, user: "both ends the same size"): the main top runs left to x -4.6 at full depth and a second arm as wide as the main top is deep (2 m) runs along the left wall to Godot z 3.0, joined to the main front edge by a 45 degree chamfer (`WX0`, `AX1`, `AY0`, `CH`); the TV stands at 45 degrees in the back-left corner (`CORNER_AT` (-3.95, 0.75, -0.1)) and `room_geo.py`'s side wall moved out to x -4.68. Playtest 2026-11-08: the set moved forward on the desk (`Corner` at (-3.3, 0.75, 0.55)) so the wall behind barely shows; the set and the remote use their own ambientCG materials (`tv_powder`, `tv_chrome`, `remote_plastic`; the machine paint's blotchy albedo read as dirt or felt up close), the glass widened to 1512:768 (~84% of the case width) with a thinner bezel and rim, framed by width (`WIDTH_FILL`, capped by `FILL` on wide screens), the remote's keys only 3-4 mm proud (user: "too hard 3d"); the BACK button is flat (user: "way too 3d"): a plate 5 mm proud in a thin chrome rim, no rivets, the arrow a flush stencil (`BF`; `BACK_CENTRE` z follows). Panel keys (2026-11-08): CH 1 / CH 2 are built like BACK (same pale plate in a chrome rim, `CZ`/`CHZ`, Label3D stencils `Ch1Stencil`/`Ch2Stencil`), each with a flush pilot window object (`Channel1`/`Channel2`, own material) that glows faintly for the channel showing while the set is on and bright + lifted on hover; the hit rects are constants (`CHANNEL_CENTRES`, `CHANNEL_HALF`) like BACK. The power lamp is a stepped chrome bezel with an 8-sided jewel lens (`Led`), dark with the set off, a dull oxblood glow at the TV (review: a bright red read as candy and fought the cabbage).

Prior venture frames (2026-11-08): `prior_venture_frame_geo.py` (prepend `desk_vc_common.py`), a wall-mounted "employee of the month" frame for the developer's earlier game covers: one moulded dark steel surround (bevelled box minus a bevelled cutter), a single mat card, a dull brass paint plate (the "PRIOR VENTURE No. N" text is a Label3D; the plate is sized for the longer German string). Two objects: Frame (matte paint only) and Cover (a UV 0-1 quad, slot `prior_cover`). `worlds/components/prior_venture_frame.tscn` takes `cover` and `plate` exports; three of them hang on the back wall left of the window in MainStoryWorld. The review asked for covers muted further (the reds fought the cabbage) and a plate wide enough for the German text; both applied.

Coffee mug (2026-11-08): `coffee_mug_geo.py` (prepend `desk_vc_common.py`) + `coffee_ring_tex.py`, desk dressing on the patch the camera sweeps past on the way to the TV. A lathed dark enamel mug (one closed profile, inside faces recoloured by radius), a coffee disc and a tube handle on the vertex-coloured paint surface, plus a curved `Print` strip just proud of the body with UV 0-1 over the square logo (arc = print height / radius, so the logo stays square). Built at 1.6x real size and shown at 1.3x in MainStoryWorld (`worlds/components/coffee_mug.tscn`); the coffee rings are a Decal. A pale mug made the white logo vanish; dark brown rings vanished on the dark desk and pale orange ones read as a pencil doodle (review), so the rings are muted grey-brown, thick, soft and broken, with a faint filled interior, and one touches the mug base. Keep it inside the desk lamp's cone (x > -1.7), or it is black during the pan.

Chute lever and growing station (2026-11-08): `chute_lever_geo.py` and `growing_station_geo.py` (prepend `desk_vc_common.py`) replace Godot-primitive props. Moving parts are separate objects with their origins at the pivots (lever: Frame / Flap / Band / Arm), exported with `GLB=<path>` and turned into `assets/meshes/Machines/<asset>_<part>.res` ArrayMeshes with the shared materials baked in by `examples/glb_to_res.gd` (headless, no `--import`: safe beside an open editor). The scenes keep their Node3D pivots (`Arm`, `Flap`) and only swap meshes. **Fit onto another asset by measuring it:** the lever's saddle clamps sit on the chute walls' rolled rims using rim height, slope and centre line measured with `TriangleMesh.intersect_ray` against the supply ramp in the lever's frame (guessed brackets clipped through the walls). User corrections: the open flap swings down the chute to the screen's left (up the chute, or standing up, it hid things), and the SUPPLY SUSPENDED band is its own object, shown only while shut (open it faced up); the growing station's chimney and cabinet hid the finished-cards spike, so it is now just a 10 cm steel collar on the intake trim whose band glows a calm cold blue when a mini grows. Review notes: matte dark axle (chrome rings read as a taped pipe), no quadrant plate (invisible in game), a grip short enough to clear the stock counter.

$50 and $100 coins (2026-11-12): no new mesh, every coin is one MultiMesh of `coin.res`. `coin_tex.py` adds two atlas faces and `CoinPile` gives each a tint and a scale (`DENOMINATIONS`, `COLOURS`, `SCALES`). Review: the first chrome-bright $50 read as a big $1 and the pair blew out under the lamp, so the $50 is dark gunmetal, both are rougher, and the octagon line is thicker. The $100's dark centre is its strongest cue; the reeded rim only shows close up.

Golden and rotten farm squares (2026-11-12): `tools/make_farm_sprites.py` gained `CABBAGE_GOLD` (the ripe map in a cold metal palette, `GOLD_COLOURS`, two white glint pixels) and `ROTTEN` (slumped flat, grey-brown with an olive undertone, `ROT_COLOURS`). Tinting the green sprite read acid yellow; a dark tint read as just a dark cabbage. Review: two symmetric dark marks on the rotten sprite read as closed eyes (a sleepy blob), so the blotches are irregular; one central highlight made the gold read as a coin. New files are imported in a throwaway project in the scratchpad (`project.godot` with only `config_version=5`, the files at the same res:// paths) and their `.import` + `.godot/imported` artifacts copied over, so nothing runs `--import` beside the user's open editor.

Research station load gauge (2026-11-12): `qa_load_gauge_geo.py` (prepend `desk_vc_common.py`), a dark enamel frame with two sunk windows on the QA bay's console face, under the dial and left of the busy lamp, built in the bay's space with `qa_bay_geo.py`'s `FACE_M` and exported with `GLB=` + `glb_to_res.gd` (the user's editor was open: no `--import`). The readout is Godot-side: a QuadMesh with `assets/shaders/cell_gauge.gdshader` (unshaded, instance uniforms `cells` and `filled`: one cell per bench, lit cold cyan per cabbage in the lab) and an Oswald Label3D count ("2/3"). Review: free cells near-black vanished at the game camera (now a visible dark teal), the gaps between cells doubled so two lit cells don't merge into a bar, a bigger count that turns bright only when every bench is busy. Playtest 2026-11-13 (user: "works great but does not fit the vibe", it read as modern UI on an analog console): the shader cells and the digital count are gone. The gauge is now five jewel lamp sockets under one chrome bezel (stepped chrome rings round sage enamel blanking discs, the lab's maximum of five benches); the lenses are faceted SphereMeshes in the scene (`Gauge/Lamps/Lamp1..5`, shaded, two materials: dark glass free, cold cyan busy), hidden for a bench not bought, so the socket reads as blanked off and nothing moves when a bench is bought. Right wall (same day): the cheek was a thin 3 cm leftover short of the window's heavy mullion; it is now 4 cm, centred under the mullion (world x 0.31) with its outer face on `SaleWindow.SPLIT_X`, its front fully chrome-lipped and its top capped by the glass frame (`X1` 0.41, the mouth 3 cm wider).

High coins and Findings tokens (2026-11-13): `coin_tex.py` grew to 9 faces ($500 / $1K / $5K / $10K as a second block, the first five keep their grain) and `findings_token_gen.py` writes a second 4-wide `findings_token_high` atlas and the double-notched `findings_token_2.obj`; thousands are written with K. Numerals are optically centred: across by the ink box, up and down by the ink centroid for the coins' Georgia old-style figures (the font anchor left the $50 10% of the face low; the ink box floated the "0" above the descending "5"), by the ink box for the tokens' "¶n" group. The sign-off lineup is `tools/coins_lineup/coins_lineup.tscn` (MainStoryWorld instanced, rows + heaps, labels), shot by `tools/coins_lineup/_shot.gd` into `reports/coins_lineup/`. Designer: the coins stay plain ("look cool without the glow"). Review: a third silver $1K got mixed up with $100/$50 (now pale cold gold), $500 near the bronzes (now grey steel with a near-black band), a glow on the cyan parts read as a neon chip (dropped; the designer took the edge rim), heavier numeral outlines on the high coins. New materials go into `worlds/components/shader_warmup.tscn` (its test checks every `.tres`). The editor was open: new and changed textures were imported in a throwaway project and the `.import` + `.godot/imported` files copied over.

Field Line (2026-11-13): `field_line_geo.py` (prepend `desk_vc_common.py`), the chapter 3 machine on the supply console's plinth: a sage switchboard box, a bakelite panel with 24 jewel lamp sockets (3 x 8, one per farm) and a count window (an amber Label3D, "7/24"), and a telephone handset in two chrome cradle rings; lifting it is the "go to the maps" control (`entities/field_line/`: `show_farms`, `lift`, `hang_up`, `drop_in`, signal `line_opened`). Two objects: the skinned box (bones Body, Receiver) and `Lamps` (the lenses, see `field_line_lamps.tres` in section 4). **A cord without a bone chain:** the coiled cord (`coil()`: a helix round a Catmull-Rom guide, winding in from the centre line at both ends) is part of the Body part with its own colour index; after `rig()` its vertices get weights blended from Body to Receiver by their place along the cord (smoothstep), and its edges are marked smooth, so it stretches after the lifted handset for free. The handset's hit box hangs on a BoneAttachment3D. Colour, judged in the engine at the desk's dim bottom-right corner: the mockup's brick-red handset became a dull dark oxblood, vertex colour (0.075, 0.017, 0.015); at (0.05, 0.012, 0.011) it went brown-black, so that is the floor. Review: lit lamps at a pure signal red read as candy and as a different red from the handset (now a deeper oxblood glow, judged on the 24/24 frame); unlit lenses as black holes in chrome rings read as a perforated grille (now dark red glass in dull nickel sockets); a 3 mm black cord vanished (now 4 mm wire, grey-brown); a 7 mm hover stir was invisible (now 2 cm and a small swing); a slimmer grip between the cups reads more like a handset than a dumbbell. Deferred: bigger lamps, an arched grip, a chunkier hook switch, the lifted cord's end trailing over the dark front edge. The mockups' `game_context.py` bug (appended objects placed with `@ o.matrix_world`, identity on a just-appended object) is fixed: `matrix_basis`. Several agents can share one scratchpad: name the throwaway project copy after the asset (`fl_proj`), not `proj`; a second agent's `project.godot` replaced the first copy mid-run. `--position 6000,6000` keeps a probe window off the screen. Flipped 2026-11-14 (user: "lights on the bottom and the phone at the top, so it feels natural to reach"): the handset, cradle and cord moved to a raised deck at the back (up the screen, nearer the middle of the desk where the hand is) and the lamp panel with its window to a slope in front, same footprint and slope angle (`SLO`, `SHI`, `TOP`, `HY`). A control the player reaches for goes on the side facing the desk's middle, read-only displays toward the screen edge. The lifted handset rises straight up (toward the player it hung over the lamps). Review: the unlit lenses went flat dark in the dim bottom edge, so the lamp shader got an `idle` glow for unlit glass (0.45 here; at 1.5 unlit and lit looked alike). Deferred: a stronger hover, a thicker cord.

Map table props (2026-11-13): `map_props_geo.py` (prepend `desk_vc_common.py`), one script for the six props of chapter 3's map table (`entities/map_table/props/`): drafting weight, chart rack (two stepped cheeks with saddles; names and numbers are Label3Ds), roll core + label band, farm token, site token, TO DESK button. Static, eleven objects, all on `machine_paint_matte` / `machine_metal`, exported with `GLB=` + `glb_to_res.gd` (prefix `map`) because the editor was open; `map_props.blend` is the saved source. Built in the map camera's screen frame (Blender X = screen right, Y = towards the wall), so a prop is placed with the sheets' basis (`Lay`) or as a child of a MapSheet. **Two looks without a shader:** a common mesh plus one mesh per look (`ForSale`, `Owned`), toggled by `MapBuilding.owned`; cheaper to write and to test than a second vertex-colour set. The paper roll is a shader, so its core is a separate scene on the roll's axis (`MapSheet.core_height`): inside the roll while rolled, lying on its end caps along the top edge while the sheet is open. Colours, judged in the engine from the map camera (almost straight above, one cold light): from above only roofs and tops show, so "pale walls, dark roofs, black board" was a black blob; roofs went to mid grey (0.27), soil and board lighter. Cast iron and pewter are paint, not metal (mirror metal goes black there). Review: the sage cheeks at the desk machines' value read near-black teal (now 0.25, 0.31, 0.26); an all-green owned rim lost the token's outline on green land (now green inside an ivory line); a pale washer read as part of the print (now dark pewter) and the owned stud's green boss was too small; the button cap a step darker than the oxblood plates or it reads candy; the rolls' paper back a little darker and warmer so they stop out-shining the map. The acquisition flash is a ring (a filled disc washed out the tags). Deferred: the pennant pin is invisible from above; rolls could show a paper overlap edge. The probe is `tools/_map_props_shot.gd` (set `root.size` again after the first frames: the window came up 2520 wide once).

Map tally (2026-11-14): `map_tally_geo.py` (prepend `desk_vc_common.py`), the long currency counter along the map table's right edge (the only free strip at 16:9; left of the sheet TO DESK is in the way, below it the desk ends). One static object in the map camera's screen frame, GLB + `glb_to_res.gd` (prefix `map`): sage housing on a cast base, four windows (black flaps, pewter bezels, a hinge line) each with a black sign plate on its left. Numbers and signs are Godot-side in `entities/map_table/props/map_tally.tscn`: unshaded Oswald Label3Ds (ivory, cabbage green, cold cyan), the cabbage icon sprite, a small farm token mesh. A change squashes the label in from nothing and brings it up from dim (a pale flash was invisible on the ivory windows and bleached the green one, which ticks all the time). Review: a cabbage sign bigger than its plate read as a sticker; cast-iron end blocks read as another machine (now a darker sage); ¶ too thin at 720p (outline in its own colour). Deferred: the farm token sign is a grey blob (wants a pale barn glyph), real per-character flaps.

Condensed cabbage belt (2026-11-14): `cabbage_belt_geo.py` (prepend `blender_lib.py`, GLB + `glb_to_res.gd` prefix `cabbage`), `cabbage_belt_tex.py` (33-row print atlas: row 0 the plain back, row k "×k") and `cabbage_reach_bake.gd` (headless Godot: how far each cabbage mesh reaches in every direction, a 128 x 64 equirect per mesh). **Fitting a shell onto something that turns inside it:** the band is modelled round its axis at a nominal radius and `assets/shaders/cabbage_belt.gdshader` moves every vertex out to the cabbage's own reach in that direction, read from the baked table with the turn from belt to mesh space passed as instance uniforms each frame (`Cabbage._process`). The table is dilated (a leaf counts within 3.5° plus a texel) so the samples (every 4° round, every 4° up and down the width) and bilinear reads never undercut a leaf, then softened 6° more so the paper has no cliffs. A per-texel nearest read left visible steps in the paper. Follow-up (user: "curve the ends in", it read as a flat label): a wide sample window (±39°) and a wide dilation stood the band up to 3 cm off the cabbage's outline, and a full ring always shows its widest point at the sides; now the mesh is only the arc the camera sees (±60°, the belt always faces the camera), so its ends tuck in round the sides behind the leaves, shaded off toward the cut, and neighbours' bands barely overlap. `tests/entities/cabbage/cabbage_test.gd` ports the shader's sums and checks no leaf point of any mesh pokes through over 72 rolls and that the ends stay within the outline (keep its constants and the arc in step with the shader and the geo script). The belt is top level, upright to the camera (`Cabbage.belt_basis`), squashed with the grab squish; one draw call per condensed cabbage. User: picked mockup B "but modelled properly so it does not clip". Review: counts read at 720p (band 7.4 cm, digits 76% of it); the side away from the lamp went black (faint emission 0.08 now), end ticks read UI-like (dropped), manila a touch darker. Deferred: a narrower band with leaves lapping over its edges (would clip by design), the player's glove covering the count while held.
