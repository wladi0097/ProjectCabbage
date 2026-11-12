extends GdUnitTestSuite

const TREE := preload("res://entities/components/upgrade_tree/upgrade_tree.tscn")

var _real_save: SaveGame
var _demo: Variant


func before_test() -> void:
	_real_save = SaveManager.save
	_demo = ProjectSettings.get_setting("game/demo", false)
	ProjectSettings.set_setting("game/demo", false)


func after_test() -> void:
	SaveManager.save = _real_save
	ProjectSettings.set_setting("game/demo", _demo)


## A lit tree on `rules`, laid out, with SaveManager.save = `save`.
func _tree(rules: Variant, save: SaveGame) -> UpgradeTree:
	SaveManager.save = save
	var tree: UpgradeTree = auto_free(TREE.instantiate())
	tree.rules = rules
	add_child(tree)
	tree.size = Vector2(1200, 700)
	tree._process(0.0)
	return tree


## A press on node `id`, then the mouse held still for `seconds`.
func _hold(tree: UpgradeTree, id: String, seconds: float) -> void:
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = tree._wheel()[0] + tree.rules.node_data(id).at * tree._wheel()[1]
	tree._gui_input(press)
	tree._process(seconds)


func test_the_projector_tree_still_buys_with_coins() -> void:
	var save := SaveGame.new()
	save.stamped = PackedStringArray(["projector", "street_posters"])
	save.coins = 100
	var tree := _tree(Projector, save)
	var paid := []
	tree.bought.connect(func(id: String, price: int) -> void: paid.append([id, price]))
	_hold(tree, "slogan_1", UpgradeTree.HOLD_TIME + 0.05)
	assert_bool(save.tree_bought.has("slogan_1")).is_true()
	assert_int(save.coins).is_equal(100 - Projector.price_of("slogan_1", save))
	assert_array(paid).is_equal([["slogan_1", Projector.price_of("slogan_1", save)]])


func test_a_short_hold_buys_nothing() -> void:
	var save := SaveGame.new()
	save.stamped = PackedStringArray(["projector", "street_posters"])
	save.coins = 100
	var tree := _tree(Projector, save)
	_hold(tree, "slogan_1", UpgradeTree.HOLD_TIME * 0.5)
	assert_bool(save.tree_bought.has("slogan_1")).is_false()
	assert_int(save.coins).is_equal(100)


func test_holding_a_node_the_save_cannot_pay_for_is_refused() -> void:
	var save := SaveGame.new()
	save.stamped = PackedStringArray(["projector", "street_posters"])
	var tree := _tree(Projector, save)
	var refusals := [0]
	tree.denied.connect(func() -> void: refusals[0] += 1)
	_hold(tree, "slogan_1", UpgradeTree.HOLD_TIME + 0.05)
	assert_bool(save.tree_bought.has("slogan_1")).is_false()
	assert_int(refusals[0]).is_equal(1)


func test_the_farm_tree_buys_a_findings_node_with_findings() -> void:
	var save := SaveGame.new()
	save.stamped = PackedStringArray(["farm_terminal", "seasonal_workforce"])
	save.farm_bought = PackedStringArray(["hand_2"])
	save.coins = 100000
	save.findings = 1000
	var tree := _tree(FarmTree, save)
	_hold(tree, "hand_route", UpgradeTree.HOLD_TIME + 0.05)
	assert_int(save.farm_hand_route).is_equal(1)
	assert_int(save.findings).is_equal(1000 - FarmTree.price_of("hand_route", save))
	assert_int(save.coins).is_equal(100000)


func test_closing_the_tree_hands_back_the_nodes_marked_new_once() -> void:
	var save := SaveGame.new()
	save.stamped = PackedStringArray(["projector", "street_posters"])
	save.projector_opened = true
	var tree := _tree(Projector, save)
	assert_array(Array(tree.close())).is_equal(Projector.fresh(save))
	assert_array(Array(tree.close())).is_empty()


func test_a_node_is_paid_in_coins_unless_it_says_findings() -> void:
	assert_str(UpgradeTree.currency_of({})).is_equal("coins")
	assert_str(UpgradeTree.currency_of({currency = "findings"})).is_equal("findings")


func test_an_effect_multiplies_and_adds_the_save_numbers_it_names_keeping_whole_numbers_whole() -> void:
	var save := SaveGame.new()
	var speed := save.farm_hand_speed
	UpgradeTree.apply_effect({mul = {farm_hand_speed = 1.5}, add = {farm_hands = 2}}, save)
	assert_float(save.farm_hand_speed).is_equal_approx(speed * 1.5, 0.0001)
	assert_int(save.farm_hands).is_equal(2)


func test_on_the_projector_the_flavour_line_shines_brighter_than_the_description() -> void:
	assert_float(UpgradeTree.FLAVOUR_ALPHA).is_greater(UpgradeTree.BODY_ALPHA)
