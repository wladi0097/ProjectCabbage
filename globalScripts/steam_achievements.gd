extends Node
## Steam achievements: every memo (entities/milestone/, MEMOS) is one, its API name the memo id
## upper-cased (units_25 -> UNITS_25). Starts Steam itself (GodotSteam 4.22, addons/godotsteam) and
## does nothing when Steam is not there (editor without Steam, tests, DRM-free copies), so gameplay
## never needs to know. Steam is only reached through Engine.get_singleton, never the `Steam` class,
## so this script still compiles if the extension is missing.

## TODO(app id): Project Cabbage's Steam app id, once Steamworks has one. 0 = take it from Steam's
## launch (SteamAppId), which is all a build started from the Steam client needs; set it (or put a
## steam_appid.txt next to the Godot exe) to get Steam in editor and dist/ test runs.
const APP_ID := 0

## The running Steam (GodotSteam singleton, or a test's fake); null while Steam is not running.
var steam: Object


func _ready() -> void:
	if DisplayServer.get_name() == "headless" or not Engine.has_singleton("Steam"):
		return
	var api := Engine.get_singleton("Steam")
	# embed_callbacks = true: GodotSteam runs Steam's callbacks every frame itself.
	var result: Dictionary = api.steamInitEx(APP_ID, true)
	if result.get("status") != 0:  # Steam.STEAM_API_INIT_RESULT_OK
		print("Steam not running: %s" % result.get("verbal"))
		return
	start(api)


## Uses `api` from now on and sends every memo already filed (offline, or before this start). Steam
## fetches the player's stats by itself at init; when they arrive, the filed memos go again.
func start(api: Object) -> void:
	steam = api
	if steam.has_signal("user_stats_received"):
		steam.connect("user_stats_received", _on_stats_received)
	sync(Profile.filed())


## Unlocks achievement `id` on Steam and uploads it.
func unlock(id: String) -> void:
	sync(PackedStringArray([id]))


## Marks every id in `ids` achieved on Steam (on load: memos filed offline or before Steam), one upload.
func sync(ids: PackedStringArray) -> void:
	if ids.is_empty() or steam == null:
		return
	for id in ids:
		steam.setAchievement(api_name(id))
	steam.storeStats()


## The Steam API name of memo `id`.
static func api_name(id: String) -> String:
	return id.to_upper()


func _on_stats_received(_game: int, _result: int, _user: int) -> void:
	sync(Profile.filed())
