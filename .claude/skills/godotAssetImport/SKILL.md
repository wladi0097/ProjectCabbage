---
name: godotAssetImport
description: Bring any outside asset into Project Cabbage the same way every time. Covers Megascans / Fab, Poly Haven, ambientCG, Kenney or other CC0 models, texture sets and audio: where the source is kept, which tier to download, inspection, budgets, origin/scale/decimation/material/collision fixes in Blender, texture and Godot import settings, naming, and verifying in Godot. Use /godotAssetCreate for assets built from scratch.
argument-hint: "[asset names, zip paths in Downloads, or an asset type]"
---

# Godot asset import

The one procedure for every asset that comes from outside the project. Every
step asks two things: does it **fit the style** (see /godotAssetCreate §2:
stylized and chunky like `research/camera-reference.webp`, read from a fixed camera above a table), and what
does it **cost** when the incremental loop puts dozens of copies on screen.

Sections marked **(tried)** were done for real (most of them in the previous
project, UnitedExpedition, with the same tools). Sections marked
**(not tried yet)** are the plan. Whoever does one first here replaces the mark
with what happened, and fixes this skill in the same turn when an import
teaches something new.

Input (asset names, zip paths, or a type; may be empty): $ARGUMENTS

## 1. Source and where it is kept

- Downloads land in `C:\Users\wladi\Downloads` among unrelated files. List
  the folder, read only the files you need, and **never delete, move or
  modify anything there**: copy.
- Keep the untouched download outside the repo, in
  `C:\Users\wladi\Desktop\ProjectCabbage_assetSources\<batch>\` (create it if
  missing).
- Unpack into your own scratchpad subfolder, do all work there, and delete it
  at the end. Never unpack into the repo.
- A requested asset with no file in Downloads is **missing**: list it in the
  report and do the rest.
- **Licence:** this is a commercial Steam game. CC0 (Poly Haven, ambientCG,
  Kenney) is fine. For Fab/Megascans, check the licence tier first. Note the
  licence of everything in `credits.txt` at the project root (create it on the
  first import).

## 2. Pick the tier

| Source | Download | Notes |
| --- | --- | --- |
| Poly Haven model | glTF 1K | metres, Y-up, OpenGL normals, CC0. Check the triangle count first: some are millions |
| Poly Haven / ambientCG surface | 1K PNG | repack ORM from AO/roughness/metal (§6) |
| Kenney / other CC0 low-poly | glTF/GLB | usually already in budget; often close to the target style; check it beside the existing props |
| Megascans 3D asset (Fab) | glTF `_ue_mid` | LOD0 only, one mesh per variant (§3) |
| Megascans plant | glTF `_ue_mid` or `_ue_low` | use the `_LOD1` mesh in mid tier, or the plain one in low tier (§3) |
| Megascans surface | 1K texture set | B, N, ORM |
| Fab Unreal-only pack | export LOD0 glTF from Unreal, never the Nanite source | rebuild materials from raw textures (§6–7) |

Skip raw/high tiers, Nanite-only packs, ZBrush and EXR downloads, and assets
with their own ground baked in (a slab under a rock never matches the
table).

## 3. Inspect before changing anything (tried)

Tools:

- Blender 5.2 in background mode only, never the user's live session:
  `"C:\Program Files\Blender Foundation\Blender 5.2\blender.exe" -b --python script.py`
  (numpy available, no PIL).
- Blender's own Python for plain JSON work:
  `"C:\Program Files\Blender Foundation\Blender 5.2\5.2\python\bin\python.exe"`.
- Image work: the system Python has PIL and numpy, but in Git Bash `python`
  is a broken pyenv shim. Call it as
  `powershell -NoProfile -Command "python script.py"`.
- `ffmpeg` is on the PATH for audio.
- Never name a script `inspect.py` or after any other stdlib module: numpy
  imports it and gets yours.

Read the glTF JSON first (nodes, triangles per mesh = index count / 3,
materials, images, vertex attributes), then import into Blender and measure
size, origin and any open rim (weld first, then count boundary edges;
unwelded glTF vertices are split at UV seams and look like holes).

What Megascans `_ue_` glTF zips contain:

- Every node carries a +90° X rotation and a 0.01 scale: the data is Z-up
  centimetres. Clear parents and apply all transforms before anything else.
- 3D assets: `<id>_tier_2.gltf` with one mesh per variant; all variants share
  one texture set `T_<id>_2K_{B,N,ORM,F}.png`. Drop `F` (a fuzz mask
  StandardMaterial3D can't use). ORM is R occlusion, G roughness, B metal.
- Plants: per variant `SM_<id>_VarA`, `_LOD1`, `_LOD2`, `_LOD3` (a billboard
  with its own material). Import the `standard/*_nonUE.gltf`: its material
  points at `B-O` with MASK. ORT is R occlusion, G roughness, B translucency.
- Read the real sizes in `<id>.json` → `meta` before trusting a name.

### The normal convention: test it, per asset

glTF says OpenGL, Unreal files are often DirectX, and both assumptions have
failed before. A tangent-space normal map baked from a surface has zero curl;
read with the wrong green sign it doesn't:

```python
n = np.asarray(Image.open(path).convert('RGB'), dtype=np.float64) / 127.5 - 1.0
nz = np.clip(n[..., 2], 0.2, None)
gx, gy = -n[..., 0] / nz, -n[..., 1] / nz
for name, s in (('opengl', 1), ('directx', -1)):
    curl = -np.gradient(gx, axis=0) - np.gradient(s * gy, axis=1)
    print(name, np.mean(np.abs(curl[mask])))
```

The smaller mean wins (usually by 1.4–3×). Mask plants by alpha > 200. When
the margin is under ~1.2×, split the texture into 16 × 16 tiles and let the
tiles vote. DirectX → `process/normal_map_invert_y=true` on the normal's
import.

## 4. Budgets

Starting values for a desktop PC (Forward+). Tighten them when a profile says
so. Triangles are for the mesh Godot imports; Godot builds its own LODs.

| Class | Example | Triangles | Texture | Collision | Shadows |
| --- | --- | --- | --- | --- | --- |
| Repeated small prop | cabbage, coin, crate, sprout | ≤ 1.5k | 1K | primitive or none | on near the camera |
| Ground plants, scatter | weeds, straw, pebbles | ≤ 2k | 1K | none | off |
| Diorama dressing | fence, cart, barrel, tree | 2–5k | 1K | box/convex if physics needs it | on |
| Buildings, large pieces | barn, village houses, launch tower | 5–20k | 1–2K | boxes | on |

A 2K set (albedo, RGTC normal, ORM, mips) is about 11 MB of VRAM, a 1K set
2.7 MB. Anything shown more than ~20 times goes in a `MultiMeshInstance3D`.

## 5. Fix the mesh in Blender (tried)

One script processes a whole batch. Per asset: source folder, target folder,
asset name, mesh suffix to use (plants), triangle target, origin mode. In
order:

1. Import (`bpy.ops.import_scene.gltf`), select all meshes, clear parents
   keeping transforms, apply location/rotation/scale.
2. Pick the variants, sort by name, name them `<asset>_a`, `_b`, … (a single
   variant keeps the bare `<asset>` name).
3. Measure any open rim **before** decimating.
4. Decimate only above 1.15× the target: **weld first**
   (`bmesh.ops.remove_doubles(dist=0.0001)`), then a Collapse decimate with
   `use_collapse_triangulate`. Without the weld, collapse opens cracks along
   every UV seam. After decimating, clear custom split normals and shade
   smooth. Don't decimate what is already in budget.
5. Origin, in metres, Y-up after export:
   - XY: the bounding-box centre (plants keep their root where the source put
     it).
   - Open-bottom pieces (stumps, rocks): the origin is where the piece meets
     the ground. Lower the mesh until the rim's top sits at −0.01 m.
   - Closed props that sit on things: origin at the lowest point.
   - Thrown or rolled props (the cabbage): origin at the centre of mass.
6. One material slot per mesh, named exactly like its Godot material, so the
   import maps it. Remove colour attributes, attributes starting with `_`,
   and every UV map but the first.
7. Export **one `.glb` per variant**, selection only:

```python
bpy.ops.export_scene.gltf(filepath=f'{out}/{variant}.glb', export_format='GLB',
    use_selection=True, export_yup=True, export_apply=True,
    export_image_format='NONE', export_materials='EXPORT',
    export_vertex_color='NONE', export_attributes=False, export_tangents=False,
    export_extras=False, export_animations=False, export_skins=False,
    export_morph=False)
```

Re-import every exported file and check: one material slot, one UV map, no
colour attribute, no transform on the node, closed meshes still closed.

**Vertex colours** (if the asset uses them): Blender 5.2 exports a white
`COLOR_0` and the real colours in `COLOR_1` unless `render_color_index` points
at the colour attribute; set it and export with
`export_vertex_color="ACTIVE"`.

## 6. Textures (tried)

- Files: `assets/textures/<asset>/<asset>_albedo.png`, `_normal.png`,
  `_orm.png` (plants: `_ort.png`, albedo RGBA).
- Resize with Lanczos. Renormalise a resized normal map per pixel before
  saving.
- **Style pass:** photoreal scans don't fit this stylized game. Use them only
  as surface textures (wood grain, paper), and expect to flatten the albedo
  (divide by a wide blur of itself, times the mean), simplify it, or store it
  greyscale and tint it in the material. Judge in Godot, not in the PNG.
- Write the `.import` file **before** the first import so it never imports
  with defaults. All of them: `compress/mode=2` (VRAM),
  `compress/high_quality=false`, `mipmaps/generate=true`,
  `process/fix_alpha_border=true`. Then per map:

  | Map | `compress/normal_map` | `roughness/mode` | `roughness/src_normal` | `process/normal_map_invert_y` |
  | --- | --- | --- | --- | --- |
  | albedo | 0 | 0 | `""` | false |
  | normal | 1 (RGTC) | 1 | `""` | true only if the curl test said DirectX |
  | orm / ort | 0 | 3 (green) | the asset's normal map | false |

  Roughness mode 3 with the normal as source raises roughness where the
  normal varies, which keeps rough surfaces from sparkling at distance.
- The first texture imported this way becomes the reference: later `.import`
  files copy its `[params]` block and only change names.

## 7. Materials (tried)

One `StandardMaterial3D` per texture set in `assets/materials/<asset>.tres`.
All variants of a pack share it. Never copy an existing material; share it.
Add every new shared material to /godotAssetCreate §4.

```
[gd_resource type="StandardMaterial3D" format=3]

[ext_resource type="Texture2D" path="res://assets/textures/<a>/<a>_albedo.png" id="1_albedo"]
[ext_resource type="Texture2D" path="res://assets/textures/<a>/<a>_normal.png" id="2_normal"]
[ext_resource type="Texture2D" path="res://assets/textures/<a>/<a>_orm.png" id="3_packed"]

[resource]
albedo_texture = ExtResource("1_albedo")
roughness_texture = ExtResource("3_packed")
roughness_texture_channel = 1
normal_enabled = true
normal_texture = ExtResource("2_normal")
ao_enabled = true
ao_texture = ExtResource("3_packed")
ao_texture_channel = 0
```

Foliage adds `transparency = 2` (alpha scissor, never blend),
`alpha_scissor_threshold = 0.5`, `cull_mode = 2`, `backlight_enabled = true`,
`backlight = Color(0.3, 0.3, 0.3, 1)`. Grass at grazing angles goes
silver-white under the default specular 0.5; lower it (~0.15).

## 8. Godot import settings (not tried yet here)

Each `<variant>.glb.import` is written before the first import. Until a
reference file exists in this project, write the `[remap]` header plus
`[params]` by hand, or let Godot import once with defaults and then edit the
`.import` it wrote. Then set `_subresources`:

- `materials` → `<asset>`: `use_external/enabled` true, `use_external/path`
  and `fallback_path` = `res://assets/materials/<asset>.tres`.
- `meshes` → key `<file stem>_<mesh name>`: `save_to_file/enabled` true,
  `path` and `fallback_path` = the `.res` next to the glb (that's what a
  `MultiMeshInstance3D` uses), `generate/lods` 0 (project default, on).
- `nodes` → `PATH:<mesh node>` only for solid pieces: `generate/physics`
  true, `physics/body_type` 0 (static), `physics/shape_type` 1 (single convex)
  for compact pieces or 0 (decomposition) for long ones. Trimesh (2) only
  where something rolls along the surface.

- Baked light: an outside prop stays out of the LightmapGI bake like every
  other prop. Set `import_script/path="res://assets/meshes/unbaked_import.gd"`
  (gi_mode Disabled on every mesh) and leave `meshes/light_baking=1`. Only a
  piece of the room or desk that never moves gets `meshes/light_baking=2`,
  `meshes/lightmap_texel_size=0.02`, no import script, and a re-bake
  (/godotAssetCreate §5, "Baked light").

Then run, **with the editor closed** (it imports on focus, and concurrent
imports corrupt `uid_cache.bin`):

```powershell
Start-Process -FilePath 'C:\Users\wladi\Desktop\Godot_v4.7.2-stable_win64.exe' -ArgumentList '--headless','--path','C:\Users\wladi\Desktop\ProjectCabbage','--import' -WorkingDirectory 'C:\Users\wladi\Desktop\ProjectCabbage' -Wait -PassThru -NoNewWindow
```

Always use an absolute `--path` and `-WorkingDirectory`. Count the `.res`
files it wrote against the variant count.

## 9. Directories and naming

```
assets/meshes/<Category>/<Asset>/   one folder per asset, Category e.g. Props, Stall, Plants, Buildings
assets/textures/<asset>/            one folder per texture set
assets/materials/<asset>.tres       one material per texture set
assets/audio/effects|music|ui/      see §10
```

Folders are PascalCase, files snake_case: `Props/Crate/crate.glb` +
`crate.res`. The asset name is the source name made short and plain
(`Wooden Crate 02` → `crate`).

## 10. Audio (tried)

- Effects, UI and ambience are 16-bit `.wav`, music is `.ogg` (Vorbis), never
  mp3. Nothing above 32 kHz: resample a source above it to 32 kHz with
  `ffmpeg -ar 32000 -c:a pcm_s16le`; one at or below keeps its rate.
- `.wav` imports with `compress/mode=2` (QOA); music sets `loop` in its import
  when it loops.
- Folders: `assets/audio/effects/`, `assets/audio/ui/`, `assets/audio/music/`.
  Raw packs stay in Downloads or the sources folder; copy only the files you
  use, renamed snake_case.
- Generated sound effects go through /godotSoundCreate instead.

## 11. Verify (tried)

1. `--import` as in §8, then read its log for errors that name your files.
2. A windowed line-up probe in the scratchpad (`extends SceneTree`, run with
   `-s`, needs a window, so say so): ground plane, sun with shadows, sky,
   SSAO. Instance every glb in rows. Print per asset the mesh count,
   surfaces, material path, `.res` path, AABB and collision shapes. Take
   screenshots from the camera distances the game uses (close on the stall,
   the fixed game camera above the table), and print
   `Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME`. Look at every screenshot
   for scale, floating or buried pieces, dark or inverted normals, missing
   alpha, and whether it fits the style next to the existing assets.
3. Kill only the Godot and Blender processes you started (a `-s` probe can
   stay alive after its last frame), and delete the scratchpad folder.

## 12. Hand over

Report per asset: source and licence, final triangles, texture size, material
shared with, collision, path. Then anything missing or deferred. Fix this
skill when an import teaches something new.
