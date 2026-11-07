extends Node
## Steam achievements: every memo (entities/milestone/, MEMOS) is one, its API name the memo id
## upper-cased (units_25 -> UNITS_25). Does nothing unless a Steam singleton is present (GodotSteam,
## initialised elsewhere with steamInit), so gameplay never needs to know whether Steam is there.


## Unlocks achievement `id` on Steam and uploads it.
func unlock(id: String) -> void:
	sync(PackedStringArray([id]))


## Marks every id in `ids` achieved on Steam (on load: memos filed offline or before Steam), one upload.
func sync(ids: PackedStringArray) -> void:
	if ids.is_empty() or not Engine.has_singleton("Steam"):
		return
	var steam := Engine.get_singleton("Steam")
	for id in ids:
		steam.setAchievement(api_name(id))
	steam.storeStats()


## The Steam API name of memo `id`.
static func api_name(id: String) -> String:
	return id.to_upper()
