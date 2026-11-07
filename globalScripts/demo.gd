extends RefCounted
## The demo build, in one place: everything the demo does differently from the full game is a
## constant here, and the code asks `active()` and reads these instead of branching on its own.
## The demo is the "demo" export preset (feature tag `demo`, export_presets.cfg); in the editor the
## project setting game/demo turns it on. The demo export also leaves out every file under
## FULL_ONLY_DIRS (exclude_filter), so full-game content can't be pulled out of the demo's .pck.
## tools/pace.py demo reads this file.

## Stage 2's warning (the family farm card, GameEvents "supply_warning") comes after this many
## units sold, long before the tray runs dry: at about 15 min (tools/pace.py demo). The farm card
## at Demo.CARD_PRICES follows within a minute, so the end note comes at about 18 min.
const WARNING_SOLD := 240
## Units sold after the warning until wholesale prices explode, not GameEvents.SHOCK_AFTER: soon
## enough that the price jump and the squeeze come before the end note.
const SHOCK_AFTER := 40
## Desk cards that cost less in the demo, by id.
const CARD_PRICES := {family_farm = 60}
## The demo's end note comes this many seconds of farming after the family farm (save.farm_seconds).
const END_AFTER := 180.0
## Projector upgrades dearer than this are locked in the demo.
const NODE_PRICE_CAP := 1000
## Folders of full-game-only content, left out of the demo export (export_presets.cfg).
const FULL_ONLY_DIRS := ["res://full/"]


static func active() -> bool:
	return OS.has_feature("demo") or ProjectSettings.get_setting("game/demo", false)
