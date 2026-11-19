class_name Ending
extends Node
## Chapter 5, the ending (research/chapter5-ending.md): once the cabbage gun card is stamped
## (GameEvents.chapter_5) the office is converted to cabbage, one STEPS entry after the other. Each
## step moves the camera to its `view`, shows its boss card, then waits until every shootable of its
## `group` (Convertible nodes in MainStoryWorld.tscn, in that group) is converted. The last step has
## no shootables: the gun turns to the player, and the one click it then takes ends the game
## (the chapter select unlocks, EndCard, then a new game with the closing paper first, save.closing_paper).
## During the ending the Hand is locked: nothing
## else on the desk can be touched. Nothing of it is saved: quit midway and it starts again at step 0.
## The gun, the cards and the targets are duck-typed (CabbageGun, BossCard, Convertible by contract),
## so the tests can stand in for them.

signal step_started(index: int)
signal finished
signal _step_cleared
signal _last_shot

const Events := preload("res://globalScripts/game_events.gd")
const Memo := preload("res://entities/milestone/milestone_memo.gd")

## The steps, in order. card: the boss card's text (level: how deranged, voice: its recording);
## view: the camera's (desk, tv, map; the walls show from the desk view); group: its shootables; hum: the low hum's level;
## as_one: groups whose members count as one target (every hand: shoot one, all go);
## raise: the gun comes up first; prompt: the fire prompt shows until the first shot; counter: the
## "remaining" count shows; notice: a line on screen until the step's first hit; player: the gun turns on the player and the last click ends the game.
const STEPS: Array[Dictionary] = [
	{card = "EVERYTHING IS CABBAGE. EXCEPT OUR OFFICE. WE NEED MORE CABBAGES.", level = 0, voice = 1,
		view = &"desk", hum = 0.1, raise = true},
	{view = &"tv", group = &"ending_tv", hum = 0.2, prompt = true},
	{card = "MORE CABBAGES.", level = 1, voice = 2, view = &"map", group = &"ending_map", hum = 0.35},
	{card = "MORE.", level = 2, voice = 3, view = &"desk", group = &"ending_desk", as_one = [&"ending_hands", &"ending_cards",
		&"ending_counters", &"ending_chute"],
		hum = 0.55, counter = true},
	{card = "MOOOORE.", level = 3, voice = 4, view = &"desk", group = &"ending_room", hum = 0.8,
		as_one = [&"ending_table", &"ending_walls"],
		notice = "THE DESK AND THE WALLS ARE NOT CABBAGE."},
	{card = "ONE MORE THING IS NOT CABBAGE.", level = 4, voice = 5, view = &"desk", hum = 1.0, player = true},
]
## The universe ticker: all of it, then all of it but the office, plus this per shot (percent).
const TICKER_FULL := 100.0
const TICKER_OFFICE := 99.999999
const TICKER_PER_SHOT := 0.00000001
## The office is never quite in: the ticker stops creeping here.
const TICKER_TOP := 99.99999999
## A cabbage a pop dropped goes this long after it comes to rest (s), shrinking away over DROP_SHRINK s,
## so the drops never pile up in front of the next shots.
const DROP_LIFE := 5.0
const DROP_SHRINK := 0.35
## Below this speed (m/s) a dropped cabbage counts as landed.
const LANDED := 0.15
## Seconds the camera stays on a station after its last target is converted.
const STEP_HOLD := 1.0
## Seconds the hum takes to fade as the credits start to roll.
const HUM_FADE := 1.0
## Seconds the camera takes between views, and the gun to turn on the player.
const MOVE_TIME := 2.4
const TURN_TIME := 6.0
## How hard a shot shakes the camera (m of view offset, CabbageGun.shake_strength) in the first
## step; it grows by as much with every step.
const SHOT_SHAKE := 0.006

## Unlocked as the end card starts; kept outside the save (ui/sub/chapter_select.gd, by path: it may
## not be there yet).
const CHAPTER_SELECT := "res://ui/sub/chapter_select.gd"

@export var gun: Node
@export var cards: Node
@export var end_card: Node
## Greening (entities/cabbage_gun/greening.gd); optional.
@export var greening: Node
@export var farm_tv: FarmTv
@export var map_table: MapTable
## Shot, the radio's music stops for good and the room tone (`ambience`, as with the radio off) comes
## back, through the end card and after.
@export var radio: Node3D
@export var ambience: AudioStreamPlayer

var save: SaveGame
## What follows the credits (tests stand in for it).
var new_game: Callable = start_new_game
## HUM_FADE and STEP_HOLD (tests make them 0).
var hum_fade := HUM_FADE
var step_hold := STEP_HOLD
## MOVE_TIME (a test makes it 0: the camera cuts).
var move_time := MOVE_TIME
var running := false
## Played through in this world: it never starts again here (the new game reloads it).
var ended := false
## The step running (-1 before the first), the shots fired, the conversions so far and in all.
var step := -1
var shots := 0
var converted := 0
var total := 0
## The gun faces the player (the last step): its click ends the game.
var facing := false
## Shots that hit nothing, and when the gun came to face the player (msec): the ending memos (Memo.file_ending).
var missed := 0
var faced_at := 0
var _targets: Array[Node] = []
# The exports, untyped: their classes are met by contract only (duck typing).
var _gun
var _cards
var _end_card
var _greening
var _hidden := false
## Cabbages the pops dropped, and how long each has lain still.
var _drops := {}
## The view the camera is at (or on its way to).
var _view := &"desk"
var _camera: Camera3D
var _desk_view: Transform3D

## The step's line on screen (STEPS notice), until its first hit.
@onready var notice: Label = $Notice/Line
## The cut to black on the last click, the same frame (just under the end card, which takes over).
@onready var cut: CanvasLayer = $Cut


## Whether the ending starts for `save`: the gun card is stamped and it has not been played through.
static func due(for_save: SaveGame) -> bool:
	return Events.chapter_5(for_save)


## The universe ticker: all of it, or (`excluded`) all but the office, up a hair per `shot`. The "*"
## is the ticker's "excl. head office" footnote; two more digits show the hair.
static func ticker_text(excluded: bool, shot: int) -> String:
	if not excluded:
		return "%.6f%%" % TICKER_FULL
	return "%.8f%%*" % minf(TICKER_OFFICE + shot * TICKER_PER_SHOT, TICKER_TOP)


## Whether every target is converted (a step without targets is done at once).
static func cleared(targets: Array[Node]) -> bool:
	return targets.all(done)


## How many of `targets` are not converted yet.
static func left(targets: Array[Node]) -> int:
	return targets.filter(func(t: Node) -> bool: return not done(t)).size()


## The station `node` belongs to: its ancestor that sits in the world beside the ending (the Ledger
## for its binder, the FarmTv for its remote); `node` itself if it is not in the world.
func station_of(node: Node) -> Node:
	var station := node
	while station.get_parent() != null and station.get_parent() != get_parent():
		station = station.get_parent()
	return station if station.get_parent() == get_parent() else node


## What `target` goes with (a coin robot's dock, CoinVacuums.pair_targets; the other hands), if anything.
static func partners_of(target: Node) -> Array:
	return target.get_meta(&"partners") if target.has_meta(&"partners") else []


## Makes `members` one target: shooting any converts them all. Only the first counts in its step.
static func as_one(members: Array) -> void:
	for member: Node in members:
		member.set_meta(&"partners", members.filter(func(m: Node) -> bool: return m != member))


## Whether `target` is out of the way: converted, or gone with something converted around it.
static func done(target: Node) -> bool:
	var parent := target.get_parent() as Node3D
	return target.get("is_converted") or (parent != null and not parent.is_visible_in_tree())


## How green the world is: the share of every shootable converted.
static func green(count: int, of: int) -> float:
	return 1.0 if of <= 0 else clampf(float(count) / of, 0.0, 1.0)


func _ready() -> void:
	if save == null:
		save = SaveManager.save
	_gun = gun
	_cards = cards
	_end_card = end_card
	_greening = greening
	_camera = get_viewport().get_camera_3d()
	if _camera != null:
		_desk_view = _camera.global_transform


func _exit_tree() -> void:
	Hand.locked = false
	Hand.locked_cursor = Input.MOUSE_MODE_VISIBLE
	FarmTv.away = false


func _process(delta: float) -> void:
	_age_drops(delta)
	if not running:
		if not _hidden:
			# The hit boxes (built deferred) are off until their step: over the desk they would block the
			# hand's ray (it looks at every layer but the play area's).
			_hidden = true
			_aim_at([])
		if due(save) and not ended:
			start()


## The shootables of step `index`: its group's targets that are in the room (shown).
func targets_of(index: int) -> Array[Node]:
	var out: Array[Node] = _shown(STEPS[index].get("group", &""))
	for group: StringName in STEPS[index].get("as_one", []):
		var members := _shown(group)
		if not members.is_empty():
			as_one(members)
			out.append(members[0])
	return out


func _shown(group: StringName) -> Array[Node]:
	var out: Array[Node] = []
	if group == &"":
		return out
	for node in get_tree().get_nodes_in_group(group):
		var parent := node.get_parent() as Node3D
		if parent == null or parent.is_visible_in_tree():
			out.append(node)
	return out


func start() -> void:
	running = true
	get_tree().node_added.connect(_on_node_added)
	for cabbage in get_tree().get_nodes_in_group(&"cabbages"):
		shootable(cabbage)
	Hand.locked = true
	_gun.armed = false
	total = 0
	for i in STEPS.size():
		for target in targets_of(i):
			total += 1
			target.connect(&"converted", _on_converted.bind(target))
			for partner: Node in partners_of(target):  # Shot, a partner (a robot's dock) takes the target with it.
				partner.connect(&"converted", func() -> void:
					if not target.is_converted:
						target.convert())
	_gun.connect(&"fired", _on_fired)
	_cards.set_ticker(ticker_text(false, 0))
	for i in STEPS.size():
		await _run(i)
	await _end()


func _run(index: int) -> void:
	step = index
	var data := STEPS[index]
	_targets = targets_of(index)
	_aim_at(_targets)
	_gun.armed = false
	_gun.set(&"shake_strength", SHOT_SHAKE * (index + 1))
	step_started.emit(index)
	await _move_to(data.view)
	# What the camera cannot see from here goes with the rest once the step is done: no step waits
	# on a shot nobody can take.
	var unseen := _targets.filter(func(t: Node) -> bool: return not on_screen(t))
	_targets = _targets.filter(on_screen)
	_cards.set_hum(data.hum)
	if data.has("card"):
		await _cards.show_card(data.card, data.level, data.voice)
	if data.get("raise", false):
		_cards.set_ticker(ticker_text(true, shots))
		await _gun.raise()
		_gun.set_crosshair(true)
	if data.get("player", false):
		# No cursor at all from here: the gun turns on the player by itself, the click is implied.
		_gun.set_crosshair(false)
		Hand.locked_cursor = Input.MOUSE_MODE_HIDDEN
		await _gun.turn_to_player(TURN_TIME)
		facing = true  # The hum (at its loudest from here) keeps going under the end card.
		faced_at = Time.get_ticks_msec()
		_cards.show_prompt(true)
		_gun.armed = true
		await _last_shot
		return
	if cleared(_targets):
		_convert_all(unseen)  # Nothing to shoot here in view: what is out of view goes at once.
		return
	if data.get("prompt", false):
		_cards.show_prompt(true)
	if data.has("notice"):
		notice.text = data.notice
		notice.get_parent().visible = true
	if data.get("counter", false):
		_cards.set_remaining(left(_targets))
	_gun.armed = true
	await _step_cleared
	_gun.armed = false
	if step_hold > 0.0:  # A moment on the station before the camera moves on.
		await get_tree().create_timer(step_hold).timeout
	_cards.set_remaining(-1)
	_convert_all(unseen)


## Only `targets` can be hit: every other shootable's hit box is off the gun's layer (the room's box
## would catch every shot over the desk, a later step's could be shot early).
func _aim_at(targets: Array[Node]) -> void:
	var on := {}
	for target in targets:
		on[target] = true
		for partner: Node in partners_of(target):
			on[partner] = true
	for data in STEPS:
		var groups: Array = [data.get("group", &"")] + data.get("as_one", [])
		for group: StringName in groups:
			for target in get_tree().get_nodes_in_group(group):
				for node: Node in [target] + partners_of(target):
					var body := node.get("body") as CollisionObject3D
					if body != null:
						body.collision_layer = Convertible.LAYER if on.has(node) else 0
						# Stays in physics when its station is stopped (one of its things was shot).
						body.process_mode = Node.PROCESS_MODE_ALWAYS


func _on_fired(_hit: Node) -> void:
	shots += 1
	missed += int(_hit == null and not facing)
	_cards.show_prompt(false)
	_cards.set_ticker(ticker_text(true, shots))
	if facing:
		# Black before anything of the shot renders: no kick, flash or shake is ever seen.
		cut.visible = true
		_gun.set(&"visible", false)
		facing = false
		_gun.armed = false
		Memo.file_ending(missed, (Time.get_ticks_msec() - faced_at) / 1000.0)
		_last_shot.emit()


func _on_converted(target: Node) -> void:
	converted += 1
	notice.get_parent().visible = false
	if _greening != null:
		_greening.set_amount(green(converted, total))
	var parent := target.get_parent()
	_stop(target)
	# The partners go from the same spot: one hit's leaf ripple runs on across the whole desk.
	var hit: Variant = _gun.get(&"_last_point") if _gun != null else null
	for partner: Node in partners_of(target):
		if not partner.is_converted:
			if hit is Vector3 and partner.has_method(&"convert_at"):
				partner.convert_at(hit)
			else:
				partner.convert()
		_stop(partner)
	if parent == radio:
		_silence()
		if target in _targets and left(_targets) == _targets.size() - 1:  # The radio, first on the desk.
			Memo.notify("end_radio_first")
	if target in _targets:
		if STEPS[step].get("counter", false):
			_cards.set_remaining(left(_targets))
		if cleared(_targets):
			_step_cleared.emit()


## A pop's cabbage and leaves land beside the object, maybe under its stopped station: they still run.
func _on_node_added(node: Node) -> void:
	if not running:
		return
	var parent := node.get_parent()
	if node is Node3D and parent != null and not parent.can_process():
		node.process_mode = Node.PROCESS_MODE_ALWAYS
	if node is Cabbage:
		_drops[node] = 0.0
		shootable.call_deferred(node)


## Gives `cabbage` a hit box the gun's ray meets: shot, it is gone in a puff (CabbagePuff).
static func shootable(cabbage: Node) -> void:
	if is_instance_valid(cabbage) and cabbage is Node3D and cabbage.get_node_or_null(^"Puff") == null:
		var puff := CabbagePuff.new()
		puff.name = &"Puff"
		puff.process_mode = Node.PROCESS_MODE_ALWAYS
		cabbage.add_child(puff)


## Each dropped cabbage that has lain still DROP_LIFE s shrinks away and is gone.
func _age_drops(delta: float) -> void:
	for key: Variant in _drops.keys():
		if not is_instance_valid(key):
			_drops.erase(key)
			continue
		var drop := key as Node3D
		var body := drop as RigidBody3D
		if _drops[drop] < 0.0 or (body != null and body.linear_velocity.length() > LANDED):
			continue
		_drops[drop] += delta
		if _drops[drop] >= DROP_LIFE:
			_drops[drop] = -1.0  # Going.
			var shrink := drop.create_tween()
			shrink.tween_property(drop, ^"scale", Vector3.ONE * 0.01, DROP_SHRINK).set_ease(Tween.EASE_IN)
			shrink.tween_callback(drop.queue_free)


## Hidden, a station would put its things back on the desk (the radio drops in again, the ledger
## shows its binder, a hired hand its glove): `target`'s whole station stops for good.
func _stop(target: Node) -> void:
	var parent := target.get_parent()
	target.process_mode = Node.PROCESS_MODE_ALWAYS
	parent.process_mode = Node.PROCESS_MODE_DISABLED
	var station := station_of(parent)
	if station != self:
		station.process_mode = Node.PROCESS_MODE_DISABLED


func _silence() -> void:
	for player in radio.find_children("*", "AudioStreamPlayer", true, false):
		(player as AudioStreamPlayer).stop()
	if ambience != null:
		ambience.set(&"radio_gone", true)
	_cards.heartbeat(true)


func _convert_all(targets: Array) -> void:
	for target: Node in targets:
		if not done(target):
			target.convert()


## Whether the camera sees any of `target`'s object (always, without a camera). Its box, not its
## middle: the middle of the table or the walls lies off screen though most of them is in view.
func on_screen(target: Node) -> bool:
	var parent := target.get_parent() as Node3D
	if _camera == null or parent == null:
		return true
	return box_in_view(parent.global_transform * Convertible.bounds(parent), _camera.get_frustum())


## Whether `box` reaches into the view `frustum` (Camera3D.get_frustum: planes facing out): no
## plane has all eight corners outside it.
static func box_in_view(box: AABB, frustum: Array[Plane]) -> bool:
	for plane in frustum:
		var outside := true
		for i in 8:
			if not plane.is_point_over(box.get_endpoint(i)):
				outside = false
				break
		if outside:
			return false
	return true


## The camera's transform for `view`.
func view_of(view: StringName) -> Transform3D:
	match view:
		&"tv":
			var size := get_viewport().get_visible_rect().size
			return FarmTv.tv_view(farm_tv.screen_frame(), size.x / maxf(size.y, 1.0))
		&"map":
			return (map_table.get_node("View") as Node3D).global_transform
	return _desk_view


func _move_to(view: StringName) -> void:
	if _camera == null:
		return
	var from := _camera.global_transform
	var to := view_of(view)
	var left_view := _view
	_view = view
	FarmTv.away = view != &"desk"
	if from.is_equal_approx(to):
		return
	var tween := create_tween()
	tween.tween_method(func(t: float) -> void:
		_camera.global_transform = FarmTv.view_at(from, to, t)
		if left_view != view:  # Lit as in play: the station left dims, the one ahead comes on.
			_light(left_view, 1.0 - t)
			_light(view, t), 0.0, 1.0, maxf(move_time, 0.01))
	await tween.finished


## Lights station `view` (tv, map) `t` of the way, as its own glide there does.
func _light(view: StringName, t: float) -> void:
	if view == &"tv" and farm_tv != null:
		farm_tv.light_up(t)
	elif view == &"map" and map_table != null:
		map_table.light_up(t)


func _end() -> void:
	if ResourceLoader.exists(CHAPTER_SELECT):
		load(CHAPTER_SELECT).unlock()
	# The hum and the heartbeat of the turn run on under the black and the logo; as the credits
	# start to roll they fade, and only the credits' song (and the room tone) is left.
	if _end_card.has_signal(&"scroll_started"):
		_end_card.connect(&"scroll_started", _quiet_turn)
	await _end_card.play()
	running = false
	ended = true
	finished.emit()
	new_game.call()


## The turn's hum fades out over hum_fade s, the heartbeat with it.
func _quiet_turn() -> void:
	if not is_inside_tree():
		return
	var fade := create_tween()
	fade.tween_method(func(level: float) -> void: _cards.set_hum(level), 1.0, 0.0, hum_fade)
	fade.tween_callback(func() -> void: _cards.heartbeat(false))


## The new game after the credits: the save reset as NEW GAME does, its first paper the closing one.
static func start_new_game() -> void:
	SaveManager.reset_save()  # The world reloads at the end of the frame, with the flag written.
	SaveManager.save.closing_paper = true
	SaveManager.write_save()
