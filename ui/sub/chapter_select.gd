class_name ChapterSelect
## After the ending (unlock(), when the end card starts) the settings show a CHAPTER SELECT: one
## start per chapter. Loading one overwrites the save, so the unlock lives in the Profile
## (globalScripts/profile.gd), outside it. The starts ship in every export (chapter_starts/), apart
## from the debug-only start points (ui/sub/debug_starts), and load the same way.

const DebugStarts := preload("res://ui/sub/debug_starts.gd")
## One start per chapter, in order; "" is chapter 1: a new game.
const STARTS := [
	"",
	"res://ressources/save/chapter_starts/2_the_farm.tres",
	"res://ressources/save/chapter_starts/3_the_map.tres",
	"res://ressources/save/chapter_starts/4_the_stars.tres",
]


static func unlock() -> void:
	Profile.write("chapter_select", "unlocked", true)


static func is_unlocked() -> bool:
	return Profile.read("chapter_select", "unlocked", false)


## Overwrites the save with chapter `index`'s start (0 is chapter 1) and reloads the world.
static func start(index: int) -> void:
	if STARTS[index].is_empty():
		SaveManager.reset_save()
	else:
		DebugStarts.start(STARTS[index])
