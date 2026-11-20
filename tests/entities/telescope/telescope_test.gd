extends GdUnitTestSuite

const SCENE := preload("res://entities/telescope/telescope.tscn")

var _real_save: SaveGame


func before_test() -> void:
	_real_save = SaveManager.save


func after_test() -> void:
	SaveManager.save = _real_save


func _telescope(save: SaveGame) -> Telescope:
	SaveManager.save = save
	var telescope: Telescope = auto_free(SCENE.instantiate())
	add_child(telescope)
	return telescope


func _stamped() -> SaveGame:
	var save := SaveGame.new()
	save.stamped.append(Telescope.CARD)
	return save


func test_the_telescope_is_in_the_window_only_once_its_card_is_bought() -> void:
	var save := SaveGame.new()
	var telescope := _telescope(save)
	assert_bool(telescope.visible).is_false()
	assert_bool(Telescope.bought(save)).is_false()
	save.stamped.append(Telescope.CARD)
	telescope._process(0.0)
	assert_bool(telescope.visible).is_true()
	assert_bool(_telescope(_stamped()).visible).is_true()


func test_the_telescope_opens_its_view_only_once_bought() -> void:
	var save := SaveGame.new()
	var telescope := _telescope(save)
	telescope.look()
	assert_bool(telescope.is_looking()).is_false()
	save.stamped.append(Telescope.CARD)
	telescope.look()
	assert_bool(telescope.is_looking()).is_true()


func test_a_click_on_the_telescope_opens_its_view() -> void:
	var telescope := _telescope(_stamped())
	(telescope.get_node("Tube/Hit/Interactable") as Interactable).grabbed.emit()
	assert_bool(telescope.is_looking()).is_true()


func test_the_telescope_says_what_it_is_when_hovered() -> void:
	var hit := _telescope(_stamped()).get_node("Tube/Hit/Interactable") as Interactable
	assert_str(hit.tooltip).is_not_empty()
	assert_bool(hit.pressable).is_true()
