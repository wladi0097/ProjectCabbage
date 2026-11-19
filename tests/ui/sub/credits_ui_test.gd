extends GdUnitTestSuite

const CreditsUi := preload("res://ui/sub/credits_ui.gd")
const SAMPLE := "Game\n\n# ---- Made by\nStudio\n\nhey@studio.com\n\n# --- Music\n\"Song\" Someone\nLicensed under CC BY 4.0\n\n"


func test_the_line_before_the_first_heading_is_the_game_title() -> void:
	assert_str(CreditsUi.parse(SAMPLE).title).is_equal("Game")


func test_a_hash_line_opens_a_section_named_without_its_dashes() -> void:
	var names: Array = CreditsUi.parse(SAMPLE).sections.map(func(s): return s.name)
	assert_array(names).is_equal(["Made by", "Music"])


func test_blank_lines_split_a_section_into_entries_and_trailing_blanks_add_none() -> void:
	var sections: Array = CreditsUi.parse(SAMPLE).sections
	assert_array(sections[0].entries).is_equal([PackedStringArray(["Studio"]), PackedStringArray(["hey@studio.com"])])
	assert_array(sections[1].entries).is_equal([PackedStringArray(["\"Song\" Someone", "Licensed under CC BY 4.0"])])


func test_license_lines_and_links_are_fine_print_but_names_are_not() -> void:
	assert_bool(CreditsUi.is_fine_print("Licensed under the MIT License")).is_true()
	assert_bool(CreditsUi.is_fine_print("http://creativecommons.org/licenses/by/4.0/")).is_true()
	assert_bool(CreditsUi.is_fine_print("ZapSplat (zapsplat.com)")).is_false()


func test_the_shipped_credits_have_no_todo_and_every_section_credits_someone() -> void:
	var text := FileAccess.get_file_as_string(CreditsUi.CREDITS_PATH)
	assert_str(text).not_contains("TODO")
	for section in CreditsUi.parse(text).sections:
		assert_bool(section.entries.is_empty()).override_failure_message(section.name).is_false()


func test_a_logo_line_is_an_image_and_the_settings_credits_show_it_in_ink() -> void:
	assert_str(CreditsUi.image_of("[logo] res://assets/sprites/ui/no_more_sleep_logo.png")).is_equal("res://assets/sprites/ui/no_more_sleep_logo.png")
	assert_str(CreditsUi.image_of("No more Sleep")).is_empty()
	var page: Control = auto_free((load("res://ui/sub/credits_ui.tscn") as PackedScene).instantiate())
	add_child(page)
	var logos := page.find_children("*", "TextureRect", true, false).filter(func(n: Node) -> bool:
		return (n as TextureRect).texture != null and (n as TextureRect).texture.resource_path.ends_with("no_more_sleep_logo.png"))
	assert_int(logos.size()).is_equal(1)
	assert_float((logos[0] as TextureRect).self_modulate.get_luminance()).is_less(0.3)  # Dark on the paper.

