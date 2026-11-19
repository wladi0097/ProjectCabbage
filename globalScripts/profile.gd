class_name Profile
## What the player keeps across every save: kept outside it (user://profile.cfg), so a new game or a
## chapter loaded (ui/sub/chapter_select) never touches it. Holds the chapter select's unlock, the furthest
## chapter reached and the memos ever filed (MilestoneMemo; the FILES folder and Steam read these). Read once, then cached.

const PATH := "user://profile.cfg"

static var _config: ConfigFile


static func _get_config() -> ConfigFile:
	if _config == null:
		_config = ConfigFile.new()
		_config.load(PATH)  # Missing on a first start: stays empty.
	return _config


static func read(section: String, key: String, default: Variant) -> Variant:
	return _get_config().get_value(section, key, default)


static func write(section: String, key: String, value: Variant) -> void:
	_get_config().set_value(section, key, value)
	_config.save(PATH)


## The memo ids ever filed, oldest first.
static func filed() -> PackedStringArray:
	return read("files", "filed", PackedStringArray())


## Adds `ids` not filed yet to the record (in order); whether any was new.
static func file(ids: PackedStringArray) -> bool:
	var record := filed()
	var before := record.size()
	for id in ids:
		if not record.has(id):
			record.append(id)
	if record.size() == before:
		return false
	write("files", "filed", record)
	return true


## The furthest chapter ever reached (1..5; MilestoneMemo.chapter_of): the FILES hide a later
## chapter's memos until then. A profile with the chapter select unlocked has seen the whole game.
static func reached() -> int:
	return 5 if read("chapter_select", "unlocked", false) else read("files", "chapter", 1)


## Records `chapter` as reached, if it is further than any before.
static func reach(chapter: int) -> void:
	if chapter > read("files", "chapter", 1):
		write("files", "chapter", chapter)


## Once per profile: an old save's filed memos (from before the profile kept them) move into it.
static func migrate(milestones: PackedStringArray) -> void:
	if read("files", "migrated", false):
		return
	file(milestones)
	write("files", "migrated", true)


## Tests only: forgets the cache and the file, as on a first start.
static func clear() -> void:
	_config = null
	DirAccess.remove_absolute(PATH)
