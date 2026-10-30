---
name: godotSoundCreate
description: Make sound effects for Project Cabbage (a sale thunk, coin into the jar, cabbage splat, chalk squeak, crate drop, chute roll, UI ticks, machines) with ElevenLabs SFX, timed to the real motion. Read the animation and script timings, write one prompt per step, generate takes, measure them, place each hit where its motion stops, mix with assets/audio/sources/mix.sh, add every take to the sound library, wire the scene. Use for any new or replaced game sound effect.
argument-hint: "[what needs sound, e.g. 'the cabbage splatting on the wall']"
---

# Godot sound create

Give a thing in the game a sound that matches what it visibly does, moment by
moment. The method comes from UnitedExpedition, where every interactable got
its sounds this way. The first sounds made here go in a "Worked examples"
list at the end. When the user corrects a rule here, fix this skill in the
same turn.

Input: $ARGUMENTS

Everything lives in `assets/audio/sources/` (Godot ignores it via
`.gdignore`):

- `mix.sh <sound>` builds `assets/audio/effects/<sound>.wav` from
  `sources/<sound>/layers` and the takes beside it.
- `library/` holds every ElevenLabs take generated so far, picked or not, and
  `library/SOUNDS.md` indexes them: prompt, length, peak, peak time, and which
  sound uses each take.
- This skill's `scripts/` folder has `fetch_takes.py`, `peaks.py` and
  `build.sh`. `ffmpeg` must be on the PATH (it is).

**ElevenLabs:** this needs the ElevenLabs MCP connected (`creative_*` tools;
find them with ToolSearch). If it isn't, tell the user and stop; don't use
another generator without asking. The project's flow is **"Project Cabbage
SFX"**. It doesn't exist yet: on first use, create it, write its id here, and
add every new node to it so all takes stay on one canvas the user can open.

- Flow id: `scsqv7XgvNJ5n3B9On71` (created 2026-10-30; the connector is the claude.ai
  ElevenLabs connector, its tools are `mcp__<uuid>__creative_*`).

## Rules

- **Reuse first.** Read `library/SOUNDS.md` before generating. A spare take
  that fits beats a new generation. A short effect may also already exist in
  `C:\Users\wladi\Desktop\UnitedExpedition\assets\audio\effects` or
  `C:\Users\wladi\Desktop\UnitedHeist2\assets\audio\effects`: copy and rename
  it snake_case, but check that it fits this game's tone first.
- **The sound follows the animation's steps.** A move in four steps gets four
  sounds, each starting when its step starts. One prompt describing all four
  steps came out smeared and was rejected.
- **Small details land where the motion ends** (a latch click when a lid
  finishes closing, the coin's clink when it lands in the jar).
- **Merge into one file per direction** when the timing is fixed (the move
  never reverses and its duration never changes). Machines whose script fires
  a list of cues keep one file per cue.
- **Sounds that play hundreds of times** (sale, coin, chute roll) need 3–5
  variations played at random with slight pitch jitter, or they grate. Ask
  for variations rather than one perfect take.
- **Effects and every take are 16-bit `.wav`, never mp3; music is `.ogg`.**
  32 kHz is the maximum sample rate; `mix.sh` writes 32 kHz mono.
- **Sources stay rebuildable.** Never edit an `effects/` wav by hand. Change
  `layers` and rerun `mix.sh`.
- **Only the user can approve a sound, by listening.** Never report a sound as
  good because its numbers look right. Say what it was built from and what to
  listen for.
- Ask before editing a scene that is open in the editor.

## 1. Find the slot and the motion

For each thing, write down:

1. **The slot.** Which export or code plays it, and when. Read the script,
   not the name. If the motion has no slot yet, adding one is code: an
   `@export var <x>_sound: AudioStream`, played from where the motion starts.
   Keep streams null in code and set them in the `.tscn`.
2. **The timeline in seconds.**
   - AnimationPlayer: read `length` and the key `times` in the `.tscn`. The
     `transitions` values only shape the easing.
   - Tween or script-driven: multiply each fraction by the duration. Grep for
     overrides of the duration.
   - `smoothstep(a, b, p)` means the move eases in and out between `a × d` and
     `b × d`: fastest in the middle, nearly still at both ends. That's where
     the dips between steps go.
   - Write it as a table: `0.00–0.30 s: cabbage flies`, `0.30 s: hits wall`,
     and so on.
   - A reverse move runs the same steps backwards: t = (1 − p) × d.
   - Physics-driven sounds (a thrown cabbage) have no fixed timeline: the
     sound plays on the event (a collision, a sale) and its volume follows
     the impact strength.
3. **The hits:** every moment something stops, lands or starts hard. Those
   are what the ear checks against the eye.

An Explore agent can do this for many things at once. Ask it for a per-thing
report: slot, current file, when it plays, timeline with `file:line`.

## 2. Write the prompts

One sound per prompt. Pattern: **what it is + its texture + how it ends + the
space**.

- Body layers (the motion itself) say `no impact` and describe the
  continuous sound: "Wooden cabbage chute, a heavy cabbage rolling slowly
  down a rough plank ramp, continuous soft wooden rumble, no impact".
- Hit layers are short and concrete: "A heavy fresh cabbage landing in a
  wooden crate, dull leafy thud, short".
- Space: `close-mic, dry` for hand-sized things at the stall,
  `small outdoor market` for stall ambience, `distant outdoors` for
  events on the street outside the window.
- Never write a duration in the prompt (it does nothing). Set
  `duration_seconds` instead: about the step's length, plus 0.1–0.3 s.
- **Tone** (GDD §1b, "cozy, then quietly sinister"): early phases are warm,
  organic and tactile (wood, burlap, leaves, chalk, coins, clay), with a soft
  folk feel. Supply-chain screens get small, clean electronic blips. Later
  phases get colder, more mechanical and more sparse, never horror. No
  cartoon boings or slide whistles, no sci-fi whooshes. Pure synth effects
  have read as comedy before.

## 3. Generate (ElevenLabs MCP)

- Create each node with `creative_add_flow_node`:
  - the flow id above
  - `node_type: sfx`
  - `model_id: eleven_text_to_sound_v2`
  - `model_parameters: {"duration_seconds": <s>, "prompt_influence": 0.6, "loop": false}`
  - `creative_get_model_schema` confirms the parameter names.
- Run with `creative_run_flow_nodes`, **at most about 7 nodes (28 takes) per
  call**. A bigger queue returns 429 "too many content generations queued".
  Wait for a batch to finish before sending the next. A refused call isn't
  charged. Never call again just to retry a call that succeeded: that charges
  twice.
- Cost: roughly 2–4 credits for a 0.5–1 s take, about 9 for 2.6 s, about 21
  for 6.4 s; ×4 takes per node. Tell the user the estimate before a big
  batch.
- Poll with `creative_get_flow_run_status`. **Pass 16–20 session ids per
  call** so the result spills to a file under `tool-results/` instead of
  flooding the context. Pad with already-finished session ids if needed.
- Download with `scripts/fetch_takes.py`:
  - `names.tsv` maps a prompt prefix to a short take name, one tab-separated
    line per prompt.
  - Files are named `<name>_<first 4 chars of generation id>.wav`, converted
    to mono 16-bit 32 kHz.

```bash
python -I .claude/skills/godotSoundCreate/scripts/fetch_takes.py names.tsv <scratch>/takes <status file>...
```

`python` works in Git Bash here (tested 2026-10-30, as were `peaks.py`,
`build.sh` and `mix.sh`). If it ever fails as a pyenv shim, call it as
`powershell -NoProfile -Command "python -I ..."`. Keep takes in the
scratchpad while choosing, in their own folder.

## 4. Measure and pick

```bash
python -I .claude/skills/godotSoundCreate/scripts/peaks.py <scratch>/takes "<name>_*.wav"
```

This prints length, peak dB, **peak time**, and a 0.1 s RMS envelope per
take.

**`peaks.py` reads at 8 kHz**, so bright sounds (coins, clicks, ticks) read
10–20 dB quieter than they are. Peak times are still right. For true peaks use
`ffmpeg -i <wav> -af volumedetect -f null -` (tested 2026-10-30).

- **Hit layers:** pick a strong, clean peak (−5 dB or louder) near the start.
  Then **start = hit time − peak time**.
- **Body layers:** pick an envelope that stays level for the whole step.
- **Takes peaking below about −25 dB are near-silent.** Boosting them raises
  the noise floor too. Reuse a better take or regenerate with a stronger
  prompt.
- Use different takes for sounds that play close together, so they don't
  repeat audibly.

## 5. Mix

`sources/<sound>/layers` format:

```
length <seconds> <end fade seconds> [<peak dB, default -1>] [<ffmpeg filter, e.g. highpass=f=250:p=2>]
<file> <start seconds> <gain dB> [<cut seconds>]
```

- `mix.sh` downmixes every take to mono, applies gain, places it, trims (with
  a 0.1 s fade when cut is given), mixes, trims to `length` with the end fade,
  then normalises the peak to the target.
- A **negative start skips** that much of the take's head (a take whose hit
  peaks at 0.18 s gets start `-0.16`, so the hit lands at 0.02 s).
- `mix.sh` resamples to 32 kHz before normalising, so bright takes hit their
  target after the resample too.
- `length` may run past the motion so a hit can ring out.
- Use an end fade of 0.01 when a hit sits right at the end.
- Peak targets: about −1 dB for big events, −4 to −6 dB for frequent small
  ones (sale, coin, UI), −12 dB for subtle ticks. Frequent sounds sit lower
  so a long session doesn't tire the ear. Write down each target you set in
  "Worked examples".
- Gains are relative inside one sound: hit layers at about 0, body layers
  −3 to −4 under them.

`build.sh` copies takes into `sources/<sound>/`, writes `layers` and runs
`mix.sh`, for many sounds at once:

```bash
bash .claude/skills/godotSoundCreate/scripts/build.sh <scratch>/takes \
  'sound crate_drop "0.9 0.2" crate_slide_Ab12 slide "0 -3" crate_thud_Cd34 thud "0.42 0"'
```

To check a result, run `peaks.py` on `assets/audio/effects` with the wav's
name. The beats should line up with the timeline table.

## 6. Library

Copy every new take (picked or not) into `sources/library/` as
`<descriptive_name>_<n>.wav`. Add its rows to `library/SOUNDS.md` and fill
**Used in** for the picked ones. The library is what makes the next sound
cheaper.

## 7. Wire into the game

1. **No Godot running:** check with
   `Get-CimInstance Win32_Process -Filter "Name like 'Godot%'"`. If the user's
   editor is open, ask them to focus it (it imports on focus) and close the
   affected scene tabs, or to close the editor before a headless import
   (concurrent imports corrupt `uid_cache.bin`).
2. **Import the new wavs.** Use an **absolute** `--path` and
   `-WorkingDirectory`; a relative `--path .` from the wrong directory once
   opened `assets/audio/sources` as a project and hung.

   ```powershell
   Start-Process -FilePath 'C:\Users\wladi\Desktop\Godot_v4.7.2-stable_win64.exe' -ArgumentList '--headless','--path','C:\Users\wladi\Desktop\ProjectCabbage','--import' -WorkingDirectory 'C:\Users\wladi\Desktop\ProjectCabbage' -Wait -PassThru -NoNewWindow
   ```

   Every `effects/*.wav` must then have its `.wav.import`.
3. **Edit the `.tscn`.** To replace a sound, change the `ext_resource` path;
   the id can stay. To fill a new slot, add an `ext_resource` line and the
   property on the node. For variations, use an `AudioStreamRandomizer` with
   the takes and `random_pitch` around 1.05.
   Event sounds that can fire in bursts play through a `SoundCue` node
   (`entities/components/sound_cue.gd`, an `AudioStreamPlayer3D`): `cue(at,
   strength)` drops plays inside `min_interval`, maps impact strength to volume
   (`silent_strength`..`full_strength`), and `max_polyphony` caps overlaps. Diorama sounds play from an
   `AudioStreamPlayer3D`, UI sounds from an `AudioStreamPlayer`.
4. **Placeholders:** an old file that's no longer referenced is listed as
   unused. Delete it only once the user says yes.

## 8. Report

Tell the user, per sound:
- what plays when
- which take sits where (timings)
- what to listen for
- anything weak, such as a boosted quiet take or a body that fades out under
  a long move

Give the flow link for re-picking takes. Never claim it sounds right.

## Worked examples

Stage 1 (2026-10-30), 8 sounds, 32 takes, ~90 credits. One file per variation
(`<sound>_<n>.wav`), one take each, played through an `AudioStreamRandomizer`
(`random_volume_offset_db` 1.5) on a `SoundCue`:

| Sound | Plays on | Files | Peak target | Pitch | SoundCue limits |
| --- | --- | --- | --- | --- | --- |
| cabbage_bump | `Cabbage.bumped(speed)` | 3 × 0.35 s | −10 dB, high-pass 220 Hz (user: "too bassy") | 1.12 | silent ≤ 0.4 m/s, full at 3, 2 voices, 80 ms |
| cabbage_grab | `Interactable.grabbed` | 3 × 0.25 s | −11 dB, high-pass 350 Hz | 1.1 | 100 ms |
| cabbage_suck | `SaleWindow` sale (0.35 s pull) | 3 × 0.7 s muffled crate thud outside, hit delayed 0.2–0.3 s to land with the cabbage | −12 dB, low-pass 2.5 kHz (a pneumatic thwump was "way too funky", a soft air hush "still weird"; user picked the crate thud over a leafy sill swish) | 1.08 | 50 ms |
| coin_bounce | `CoinPile.bounced` | 3 × 0.25 s | −6 dB | 1.12 | 3 voices, 35 ms |
| coin_land | `CoinPile.landed` | 2 × 0.22 s | −8 dB, node −4 | 1.15 | 3 voices, 45 ms |
| coin_collect | `CoinPile.collected` (sweeps of dozens) | 3 × 0.12 s | −10 dB, node −6 | 1.12 | 3 voices, 50 ms |
| coin_deposit | `CoinPile.deposited` | 3 × 0.35 s | −6 dB | 1.1 | 3 voices, 50 ms |
| tally_tick | `TallyMachine.ticked` | 3 × 0.1 s | −12 dB | 1.06 | 2 voices, 30 ms |
| console_drop | `SupplyConsole` lands after its 0.45 s drop (also the price slate's drop) | 1 × 0.8 s | −2 dB | 1.03 | — |
| console_press | BUY button pressed (enough coins) | 2 × 0.3 s | −5 dB | 1.06 | 80 ms |
| console_denied | BUY pressed without enough coins | 2 × 0.35 s | −9 dB | 1.04 | 150 ms |
| cabbage_roll | `CabbageFeeder` rolls a cabbage down the chute (0.4 s) | 3 × 0.45 s | −11 dB, `asetrate=25600,aresample=32000,lowpass=f=2500` (the user found it "too high": pitched down 20 %) | 1.1 | 2 voices, 100 ms |
| chalk_tap | `PriceSlate` arrow steps the price | 2 × 0.25 s | −8 dB | 1.08 | 50 ms |
| cabbage_refused | `SaleWindow.refused`: the street throws a cabbage back | 3 × 0.6 s | −4 dB | 1.06 | 100 ms |
| (stock counter) | `CabbageFeeder` drum bar crosses a whole number | reuses `tally_tick_1-3` | node `pitch_scale` 0.75 | 1.06 | 2 voices, 30 ms |

The console's once-a-minute price tick was removed: the user wants silent price updates there. A prompt naming a "CRT display" came back as four steady tones; "a single tiny soft electronic beep ... one short muted blip then silence" gave a usable blip. To pitch a sound down without regenerating, put `asetrate=<32000 × factor>,aresample=32000` in the `layers` filter field.

Prompts are in `library/SOUNDS.md`. Weak takes: `coin_land` had only one
clean take of four (`coin_land_2` is quieter, normalised up), `coin_bounce`
`v5FR` and `cabbage_bump` `9hUU` were too quiet and left out.
