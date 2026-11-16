extends GdUnitTestSuite
## A script saved with CRLF line endings puts "\r\n" into every multi-line string literal, so a card's
## text no longer matches its key in game.csv and stays English in German (2026-11-16: the war cards).

const LOCK := preload("res://tests/gdmaim_lock_test.gd")


func test_every_game_script_and_the_translation_table_use_plain_lf_line_endings() -> void:
	var files: Array[String] = ["res://ressources/translations/game.csv"]
	for dir: String in LOCK.SOURCE_DIRS + ["res://tests"]:
		LOCK.collect_scripts(dir, files)
	var crlf: Array[String] = []
	for path in files:
		if FileAccess.get_file_as_bytes(path).has(13):
			crlf.append(path)
	assert_array(crlf).is_empty()
