class_name Cabbage
extends RigidBody3D
## One unit of stock, and heavy: held, it accelerates toward the hand with capped force and
## speed, so a throw needs a deliberate drag. Let go and it keeps the momentum it built up.
## Out through the window gap is a sale; the SaleWindow marks it sold, or sends it out and back
## when the street refuses it (`away` meanwhile). Every cabbage is in the "cabbages" group.
## A rotten one (set before it enters the tree) is grey and slumped: sold, it is fined (SaleWindow);
## binned, it is gone (RottenBin). A mid-air catch calls `caught` on the "catch_combo" group; a
## chute unit that lands uncaught (on the desk, or at rest atop something) calls `missed` (a mini
## falling from upstairs never does).

signal bumped(speed: float)

const MESHES: Array[Mesh] = [
	preload("res://assets/meshes/Props/cabbage_a.res"),
	preload("res://assets/meshes/Props/cabbage_b.res"),
	preload("res://assets/meshes/Props/cabbage_c.res"),
]
const HOLD_HEIGHT := 0.9
## The held cabbage stays on the room side of the window wall.
const NEAREST_WALL_Z := -0.68
## Each cabbage is up to this much smaller or bigger (mesh, collider and mass).
const SIZE_SPREAD := 0.1
## How flat a grab squashes it (0.18 = 18% lower, wider to match), springing back over SQUISH_TIME.
const SQUISH := 0.18
const SQUISH_TIME := 0.6
## A mid-air catch spins it once in the hand over this many seconds, easing out.
const CATCH_SPIN_TIME := 0.45
const ROTTEN_MATERIAL := preload("res://assets/materials/cabbage_rotten.tres")
## A rotten one sags: this much lower, a little wider.
const SLUMP := Vector3(1.08, 0.78, 1.08)
## A mini unit's linear size (mesh, collider; mass goes with its cube, about a quarter).
const MINI_SCALE := 0.63
## A research unit: a cold cyan lab glow, and a faint light of the same tint on the mat around it.
const RESEARCH_MATERIAL := preload("res://assets/materials/cabbage_research.tres")
const RESEARCH_LIGHT := Color(0.45, 0.9, 1.0)
## A golden unit (desk card golden_cabbage): cold metallic gold, the one exception to the palette.
const GOLD_MATERIAL := preload("res://assets/materials/cabbage_gold.tres")
## A condensed cabbage (`units` over 1) is denser, never bigger (decision 2026-11-14: one holding 16
## is the size of a plain one; only its count tells): its mass is units times, and it drags behind
## the hand: its carry acceleration is divided by units ^ CONDENSED_WEIGHT (2: ×0.8, 4: ×0.63).
## It also sounds heavier: its bump, grab, chute roll and sale play units ^ -CONDENSED_PITCH lower
## (2: ×0.87, 4: ×0.76). Weight and pitch stop growing at HEFT_MAX cabbages in one (×0.5, ×0.66).
const HEFT_MAX := 8
const CONDENSED_WEIGHT := 0.33
const CONDENSED_PITCH := 0.2
## What it holds shows as a number projected onto its leaves (the Number decal, only on the cabbage
## render layer), upright to the camera however it rolls: white digits (DIGITS, DIGIT_W wide, set
## DIGIT_STEP apart) on a NUMBER_SIZE square, tinted by count_colour.
const DIGITS := preload("res://assets/textures/cabbage_number/cabbage_number_digits.png")
const DIGIT_W := 120
const DIGIT_STEP := 96
const NUMBER_SIZE := 256
## The decal sits this far toward the camera from the centre, so it prints the near side only.
const NUMBER_LIFT := 0.1
## The number's tint by count: 2-3, 4-7, 8-15, 16-31, 32 and up. Cold pale inks, bright, never loud.
const COUNT_COLOURS: Array[Color] = [
	Color(0.93, 0.95, 0.94),  # paper white
	Color(0.56, 0.78, 1.0),  # ice blue
	Color(1.0, 0.8, 0.44),  # docket amber
	Color(1.0, 0.56, 0.5),  # warning salmon
	Color(0.78, 0.62, 1.0),  # carbon-copy lilac
]
## Let go by the hand near the bin (RottenBin.let_go_over), it may drop in for this long (a drop or
## a short toss lands by then).
const BIN_GRACE := 1.0
## With no carry weight (save.carry_weight 0) a held unit keeps up with the hand, up to this speed (m/s).
## 11.2: 20% under the first 14, which the user found too hardcore (2026-11-16); still 2x max_speed.
const FREE_SPEED := 11.2
## A flying unit touching something with its centre this high or lower has landed. The desk top is
## at 0.76, so the biggest unit lies on it at 0.88 (tools/_combo_probe.gd saw desk landings at
## 0.84-0.90); the chute's lip grazes a unit at 1.06 as it is flung.
const LANDED_Y := 0.95
## Slower than this (m/s) for REST_TIME seconds, a flying unit has come to rest wherever it is.
const REST_SPEED := 0.3
const REST_TIME := 0.3
## Once SHIELD_CARD is stamped rotten cabbages are quarantined: a rotten one and a regular one (any
## kind that is not rotten) pass through each other (a collision exception both ways, quarantine), so
## no throw or roll knocks a rotten one out of the window. Everything else (desk, walls, the hands,
## the player, other rotten ones) it still meets as before; its layers and mass never change.
const SHIELD_CARD := "rotten_shield"
## A rotten one left on the desk bursts after FUSE seconds (held by any hand the count pauses; binned
## or sold it never bursts): a grey-green puff (ROT_PUFF) and the same fine as selling it
## (SaleWindow.fine). Its last SWELL_FROM seconds it swells up to SWELL bigger and shakes harder
## (shake_at), its last QUIVER_FROM seconds a fast quiver.
const FUSE := 180.0
const SWELL_FROM := 30.0
const SWELL := 0.25
const QUIVER_FROM := 5.0
## Shake: the mesh's sway (m) as the swelling starts and at the burst, and how fast it shakes
## (rad/s) while swelling and in the quiver.
const SHAKE := Vector2(0.002, 0.008)
const QUIVER := 0.012
const SHAKE_SPEED := Vector2(14.0, 60.0)
const ROT_PUFF := preload("res://entities/cabbage/rot_puff.tscn")

## How hard it is pulled toward the hand per metre of lag.
@export var follow := 18.0
## Acceleration cap (m/s²): the weight. Lower = heavier.
@export var max_accel := 60.0
## Carry speed cap (m/s). The window needs about 3.5 from the bottom half of the mat.
@export var max_speed := 5.5

var sold := false
var rotten := false
## Seconds left before a rotten one bursts (FUSE).
var fuse := FUSE
## A mini unit (entities/mini_drop/): a quarter-size free one, sold at save.mini_value of the price.
## Never rotten. Set before it enters the tree, like rotten.
@warning_ignore("shadowed_global_identifier")
var mini := false
## Grown from a mini in the growing station (grow): a full-size unit that is still no stock, sold at
## the full price and counted as sold.
var grown := false
## A research unit: glows a cold cyan, yields save.research_mult times the Findings in the QA bay. Never rotten.
var research := false
## A golden unit from a golden farm square: stock (save.golden_stock), sold for save.golden_sale times
## the price or analysed for save.golden_lab times the Findings. Never rotten, mini or research.
var golden := false
## How many cabbages from stock it holds: 1, or more for a condensed one (desk card condense,
## CabbageFeeder.condensed): it leaves the stock, sells, is analysed and is counted as that many, and
## shows a number (2) on its leaves. Set before it enters the tree, like rotten. Minis and rotten ones: always 1.
var units := 1
## Last thrown by a hired hand (Associate._throw), not the player: SaleWindow counts its sale as the hand's.
var lobbed := false
## Sent by the mini tube (MiniDrop), into the window gap or the research lab, not thrown by the player.
var tubed := false
## Out of the window or on its way back after a refusal: the SaleWindow leaves it alone.
var away := false
## Seconds the SaleWindow has seen it off the mat in a row.
var stray_time := 0.0
## Flung off the chute and not landed yet (lands_on, settled): grabbing it now is a catch.
var in_flight := false:
	set(flying):
		in_flight = flying
		_still = 0.0
		$Interactable.catchable = flying
## Seconds in a row a flying unit has been nearly still (settled).
var _still := 0.0
var _held := false
## It has left save.stock (leave_stock).
var _left_stock := false
## Until this tick (msec) the RottenBin may take it (aim_for_bin).
var _bin_until := 0
var _look := Basis()
var _squishing: Tween
var _squish := 0.0:
	set(amount):
		_squish = amount
		_pose()
## Caught in mid-air: the turn (rad, about the world's up) of its little spin in the hand.
var _spin := 0.0:
	set(angle):
		_spin = angle
		_pose()
var _spinning: Tween
## Its collision exceptions with the other kind are set (quarantine).
var _quarantined := false
## How much bigger a swelling rotten one is drawn (swell_at).
var _swell := 1.0
## One digits texture per count shown so far, shared by every cabbage holding that many.
static var _count_textures := {}


## A condensed cabbage's count (top level: placed every frame, it never rolls with the body).
@onready var _number: Decal = $Number
@onready var _layer := collision_layer
@onready var _mask := collision_mask


func _ready() -> void:
	add_to_group(&"cabbages")
	$Mesh.mesh = MESHES[randi() % MESHES.size()]
	var size := randf_range(1.0 - SIZE_SPREAD, 1.0 + SIZE_SPREAD) * (MINI_SCALE if mini else 1.0)
	mass *= size * size * size * heft(units)
	max_accel /= pow(heft(units), CONDENSED_WEIGHT)
	_number.visible = units > 1
	set_process(units > 1)
	if units > 1:
		_number.texture_albedo = count_texture(units)
		_number.texture_emission = _number.texture_albedo
		_number.modulate = count_colour(units)
	_look = Basis.from_euler(Vector3(randf(), randf(), randf()) * TAU).scaled(Vector3.ONE * 1.5 * size)
	if rotten:
		$Mesh.material_override = ROTTEN_MATERIAL
		_look = Basis.from_scale(SLUMP) * _look
	elif golden:
		$Mesh.material_override = GOLD_MATERIAL
	elif research:
		$Mesh.material_override = RESEARCH_MATERIAL
		var glow := OmniLight3D.new()
		glow.light_color = RESEARCH_LIGHT
		glow.light_energy = 0.5
		glow.omni_range = 0.35
		add_child(glow)
	$Mesh.basis = _look
	var ball := $Shape.shape.duplicate() as SphereShape3D
	ball.radius *= size
	$Shape.shape = ball
	$Interactable.grabbed.connect(_on_grabbed)
	$Interactable.released.connect(_on_released)
	body_entered.connect(func(body: Node) -> void:
		if in_flight and lands_on(body, global_position.y):
			_land()
		bumped.emit(linear_velocity.length()))
	$Bump.pitch_scale = heavy_pitch(units)
	$Grab.pitch_scale = heavy_pitch(units)
	bumped.connect(func(speed: float) -> void: $Bump.cue(global_position, speed))
	$Interactable.grabbed.connect(func() -> void: $Grab.cue(global_position))
	if SaveManager.save.stamped.has(SHIELD_CARD):
		quarantine()


## The cabbages a cabbage holding `count` weighs and sounds like: `count`, at most HEFT_MAX.
static func heft(count: int) -> int:
	return clampi(count, 1, HEFT_MAX)


## How much lower a cabbage holding `count` cabbages sounds than a plain one (a pitch scale).
static func heavy_pitch(count: int) -> float:
	return pow(heft(count), -CONDENSED_PITCH)


## The tint of the number on a cabbage holding `count`: one colour per doubling (COUNT_COLOURS).
static func count_colour(count: int) -> Color:
	var doublings := String.num_int64(maxi(count, 2), 2).length() - 2  # 2-3: 0, 4-7: 1, 8-15: 2 ...
	return COUNT_COLOURS[mini(doublings, COUNT_COLOURS.size() - 1)]


## The digits of `count`, white, centred on a square (made once per count, then shared).
static func count_texture(count: int) -> Texture2D:
	if not _count_textures.has(count):
		var digits := DIGITS.get_image()
		digits.convert(Image.FORMAT_RGBA8)
		var text := str(count)
		var square := Image.create_empty(NUMBER_SIZE, NUMBER_SIZE, false, Image.FORMAT_RGBA8)
		var left := (NUMBER_SIZE - DIGIT_W - DIGIT_STEP * (text.length() - 1)) / 2.0
		var top := (NUMBER_SIZE - digits.get_height()) / 2.0
		for i in text.length():
			square.blend_rect(digits, Rect2i(text[i].to_int() * DIGIT_W, 0, DIGIT_W, digits.get_height()),
					Vector2i(int(left) + i * DIGIT_STEP, int(top)))
		square.generate_mipmaps()
		_count_textures[count] = ImageTexture.create_from_image(square)
	return _count_textures[count]


## The number's turn for a camera turned `view`: it projects along the view (decal -y away from the
## camera) with the digits' tops toward the camera's up.
static func number_basis(view: Basis) -> Basis:
	var turn := view.orthonormalized()
	return Basis(turn.x, turn.z, -turn.y)


## A condensed cabbage's number, every frame: just in front of its centre, facing the camera.
func _process(_delta: float) -> void:
	var camera := get_viewport().get_camera_3d()
	var level := Basis.IDENTITY if camera == null else number_basis(camera.global_basis)
	_number.global_transform = Transform3D(level, global_position + level.y * NUMBER_LIFT)


## Whether it came out of the stock (and so leaves it when sold, binned or analysed): minis and
## grown ones never did.
func is_stock() -> bool:
	return not mini and not grown


## Still counted in save.stock: a stock unit that hasn't left it yet (out of the chute, it can't pay
## a card: UpgradeDesk.units_out).
func in_stock() -> bool:
	return is_stock() and not _left_stock


## It leaves the stock (sold, binned or analysed), once: its `units` off save.stock (one, or what a
## condensed one holds), and off golden_stock if golden, never below 0. Minis and grown ones never were stock.
func leave_stock(save: SaveGame) -> void:
	if not in_stock():
		return
	_left_stock = true
	save.stock = maxi(save.stock - units, 0)
	if golden:
		save.golden_stock = maxi(save.golden_stock - units, 0)


## The growing station's work, out of sight in the tube: the mini becomes a full-size unit (mesh,
## collider and mass back up from MINI_SCALE), still no stock.
func grow() -> void:
	if not mini:
		return
	mini = false
	grown = true
	var up := 1.0 / MINI_SCALE
	_look = Basis.from_scale(Vector3.ONE * up) * _look
	$Mesh.basis = _look
	var ball := $Shape.shape.duplicate() as SphereShape3D
	ball.radius *= up
	$Shape.shape = ball
	mass *= up * up * up


## A flight ends when it lands (lands_on, or settles off the desk): a miss unless it is a mini.
func _land() -> void:
	in_flight = false
	if not mini:
		for combo: CatchCombo in get_tree().get_nodes_in_group(&"catch_combo"):
			combo.missed()


## Whether touching `body` with its centre at `height` lands a flying unit: anything but another
## cabbage (flying, held or lying about), down at desk level. Higher up (grazing the ramp's lip, the
## chute's walls, atop a pile) it is still in the air and catchable; there only coming to rest ends it.
static func lands_on(body: Node, height: float) -> bool:
	return not body is Cabbage and height <= LANDED_Y


## Whether a flying unit has come to rest: below REST_SPEED for `still` seconds (atop a pile, on a
## ledge), so no flight stays catchable forever.
static func settled(still: float) -> bool:
	return still >= REST_TIME


func _physics_process(delta: float) -> void:
	if rotten and not _quarantined and SaveManager.save.stamped.has(SHIELD_CARD):
		quarantine()  # The card was stamped while it lay out.
	if burning():
		_tick_fuse(delta)
	if in_flight:
		_still = _still + delta if linear_velocity.length() < REST_SPEED else 0.0
		if settled(_still):
			_land()
	if not _held:
		return
	var target := Hand.point_on_height(HOLD_HEIGHT)
	target.z = maxf(target.z, NEAREST_WALL_Z)
	if SaveManager.save.carry_weight <= 0.0:
		linear_velocity = free_velocity(target - global_position, delta)
	else:
		linear_velocity = carry_velocity(linear_velocity, target - global_position, delta, follow, max_accel, max_speed)


## Its fuse is burning: rotten, out on the desk and in nobody's hand (the player's, or a hired hand
## carrying it to the bin: frozen, like rolling down the ramp or being pulled into the bin).
func burning() -> bool:
	return rotten and not sold and not away and not _held and not freeze


## A rotten one on the desk burns `delta` of its fuse: in the last SWELL_FROM seconds it swells and
## shakes, at 0 it bursts.
func _tick_fuse(delta: float) -> void:
	fuse -= delta
	if fuse <= 0.0:
		burst()
	elif fuse <= SWELL_FROM:
		_swell = swell_at(fuse)
		var speed := SHAKE_SPEED.y if fuse <= QUIVER_FROM else SHAKE_SPEED.x
		var time := Time.get_ticks_msec() / 1000.0 * speed
		_pose()
		$Mesh.position = global_basis.orthonormalized().inverse() * Vector3(sin(time * 1.3), 0.0, cos(time)) * shake_at(fuse)


## How much bigger a rotten one is drawn with `left` seconds of fuse: 1 until SWELL_FROM, then
## slowly at first up to 1 + SWELL at the burst.
static func swell_at(left: float) -> float:
	return 1.0 + SWELL * pow(1.0 - clampf(left / SWELL_FROM, 0.0, 1.0), 2.0)


## How far (m) a rotten one shakes with `left` seconds of fuse: still until SWELL_FROM, then harder
## toward the burst, QUIVER in the last QUIVER_FROM seconds.
static func shake_at(left: float) -> float:
	if left > SWELL_FROM:
		return 0.0
	if left <= QUIVER_FROM:
		return QUIVER
	return lerpf(SHAKE.x, SHAKE.y, 1.0 - (left - QUIVER_FROM) / (SWELL_FROM - QUIVER_FROM))


## The fuse ran out on the desk: a grey-green puff where it lay, the fine as for a sale (the
## sales desk's notice says it burst), and it is gone. It pushes nothing on its way out.
func burst() -> void:
	sold = true
	collision_layer = 0
	collision_mask = 0
	var puff := ROT_PUFF.instantiate() as Node3D
	get_parent().add_child(puff)
	puff.global_position = global_position
	var window := get_tree().get_first_node_in_group(&"sale_window") as SaleWindow
	if window != null:
		window.fine(self, true)
	else:
		leave_stock(SaveManager.save)
	queue_free()


## Rotten and regular cabbages stop colliding: this one and every cabbage of the other kind out now
## (a cabbage coming later does the same in its _ready).
func quarantine() -> void:
	_quarantined = true
	for other: Cabbage in get_tree().get_nodes_in_group(&"cabbages"):
		if other != self and other.rotten != rotten:
			add_collision_exception_with(other)
			other.add_collision_exception_with(self)


## The grab squash `time` seconds in: pressed flat, springing back past round once, settling.
static func squish_at(time: float) -> float:
	return SQUISH * exp(-5.0 * time) * cos(10.0 * time) if time < SQUISH_TIME else 0.0


## Squashed down by `amount`, bulging sideways to keep roughly the same volume.
static func squish_scale(amount: float) -> Vector3:
	var wide := 1.0 / sqrt(1.0 - amount)
	return Vector3(wide, 1.0 - amount, wide)


static func carry_velocity(velocity: Vector3, to_target: Vector3, delta: float, pull: float,
		accel: float, top_speed: float) -> Vector3:
	return velocity.move_toward((to_target * pull).limit_length(top_speed), accel * delta)


## Weightless (FRICTIONLESS HANDLING): the speed that closes `to_target` in one step, up to FREE_SPEED.
static func free_velocity(to_target: Vector3, delta: float) -> Vector3:
	return (to_target / maxf(delta, 0.001)).limit_length(FREE_SPEED)


## A golden unit was sold: its cold bell and coin pour plays from where it went out. The player is
## handed to the cabbage's parent first, since the cabbage is freed at the window mid-sound.
func ring_golden_sale() -> void:
	var ring: SoundCue = $GoldSale
	ring.reparent(get_parent())
	ring.finished.connect(ring.queue_free)
	ring.cue(global_position)
	if not ring.playing:  # Dropped by the game-wide cap.
		ring.queue_free()


## Sold: the hand lets go, nothing can grab it, and it is pulled out through the gap to `to`
## (out of sight in the street) instead of dropping onto the pavement.
func suck_out(to: Vector3, time: float) -> void:
	sold = true
	_pull_out(to, time).chain().tween_callback(queue_free)


## Refused: pulled out of the window like a sale, but kept (`away`) for throw_in to bring back.
func send_away(to: Vector3, time: float) -> void:
	away = true
	_pull_out(to, time)


## Thrown back in by the street from `from` at `velocity`. It passes through the window wall for
## `clear` seconds, can't be grabbed for a moment, and is the window's again after `landed` seconds.
func throw_in(from: Vector3, velocity: Vector3, clear: float, landed: float) -> void:
	global_position = from
	visible = true
	freeze = false
	gravity_scale = 1.0
	collision_layer = _layer
	linear_velocity = velocity
	angular_velocity = Vector3(randf_range(-6, 6), randf_range(-6, 6), randf_range(-6, 6))
	# One tween on the cabbage itself, so nothing fires after it is freed.
	var steps := create_tween().set_parallel()
	steps.tween_callback(func() -> void: collision_mask = _mask).set_delay(clear)
	steps.tween_callback(func() -> void: $Interactable.enabled = true).set_delay(0.3)
	steps.tween_callback(func() -> void: away = false).set_delay(landed)


## Binned: like suck_out, but hopped in from the top: lifted to `over_y` (over the rim), across,
## then dropped straight down to `to` (hop_at).
func drop_into(to: Vector3, over_y: float, time: float) -> void:
	sold = true
	_pull_out(to, time, over_y).chain().tween_callback(queue_free)


## The hop from `from` over `over_y` down into `to`, `t` (0..1) of the way: it rises first and
## moves across while high, so the last part is a straight drop.
static func hop_at(from: Vector3, to: Vector3, over_y: float, t: float) -> Vector3:
	var flat := from.lerp(to, smoothstep(0.1, 0.7, t))
	var rise := 1.0 - pow(1.0 - minf(t / 0.45, 1.0), 2.0)
	var fall := pow(maxf(t - 0.45, 0.0) / 0.55, 2.0)
	flat.y = lerpf(lerpf(from.y, maxf(over_y, from.y), rise), to.y, fall)
	return flat


## Torn from the hand, out of reach and out of the physics, pulled to `to` over `time` (hopped over
## `over_y` when given).
func _pull_out(to: Vector3, time: float, over_y := -INF) -> Tween:
	_held = false
	$Interactable.enabled = false
	freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	freeze = true
	collision_layer = 0
	collision_mask = 0
	var tween := create_tween().set_parallel()
	var from := global_position
	if over_y > -INF:
		tween.tween_method(func(t: float) -> void: global_position = hop_at(from, to, over_y, t), 0.0, 1.0, time)
	else:
		tween.tween_property(self, "global_position", to, time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(self, "rotation", rotation + Vector3(-TAU, randf_range(-1, 1), 0), time)
	return tween


## Squashed along the world's up (the hand presses from above) and spun about it, however the body is turned.
func _pose() -> void:
	var turn := global_basis.orthonormalized()
	$Mesh.basis = turn.inverse() * Basis(Vector3.UP, _spin) * Basis.from_scale(squish_scale(_squish) * _swell) * turn * _look


## Last thrown by the player: no hired hand lobbed it and the tube did not send it (managerial work,
## save.own_sale and own_lab).
func by_player() -> bool:
	return not lobbed and not tubed


## The catch spin's turn (rad) `t` (0..1) of the way through: one full turn, fast first, settling.
static func catch_spin_at(t: float) -> float:
	return TAU * (1.0 - pow(1.0 - clampf(t, 0.0, 1.0), 3.0))


func _on_grabbed() -> void:
	if _squishing != null:
		_squishing.kill()
	_squishing = create_tween()
	_squishing.tween_method(func(time: float) -> void: _squish = squish_at(time), 0.0, SQUISH_TIME, SQUISH_TIME)
	lobbed = false
	tubed = false
	if in_flight:
		in_flight = false
		SaveManager.save.catches += 1
		for combo: CatchCombo in get_tree().get_nodes_in_group(&"catch_combo"):
			combo.caught(global_position)
		if _spinning != null:
			_spinning.kill()
		_spinning = create_tween()
		_spinning.tween_method(func(t: float) -> void: _spin = catch_spin_at(t), 0.0, 1.0, CATCH_SPIN_TIME)
	_held = true
	gravity_scale = 0.0
	angular_velocity *= 0.3


func _on_released() -> void:
	_held = false
	gravity_scale = 1.0
	# Only let go near the bin: one dropped elsewhere that later rolls in is popped back out.
	var bin := get_tree().get_first_node_in_group(&"rotten_bin") as RottenBin
	if bin != null and bin.visible and RottenBin.let_go_over(bin.global_position, global_position, bin.mouth_reach()):
		aim_for_bin(BIN_GRACE)


## Let go by the player or thrown by a hired hand: the RottenBin takes it for `seconds` from now.
## A unit only rolled or bumped into the mouth is never binned (meant_for_bin is false).
func aim_for_bin(seconds: float) -> void:
	_bin_until = Time.get_ticks_msec() + int(seconds * 1000.0)


func meant_for_bin() -> bool:
	return Time.get_ticks_msec() < _bin_until
