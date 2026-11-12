class_name CoinPile
extends MultiMeshInstance3D
## Every loose coin, drawn as one MultiMesh. Coins are animated, not simulated: they arc in,
## bounce once and land on a height grid. One payout comes as silver ($1), gold ($5) and big
## bronze ($10, bigger and thicker) coins that all aim at one spot and stack there, at most MAX_STACK high; extra coins
## start a stack right beside it. Sweeping an empty hand over them sends them into the deposit.

signal thrown(origin: Vector3, count: int)
signal bounced(position: Vector3)
signal landed(position: Vector3)
signal collected(position: Vector3)
signal deposited(position: Vector3)

enum State { FLYING, SETTLING, RESTING, HOMING }

const MAX_COINS := 4096
## The MultiMesh grows by this many instances when the coins outgrow it (never shrinks): the whole
## buffer is sent each upload, so it is kept near the coins actually out.
const CHUNK := 256
const CELL := 0.054
const THICKNESS := 0.014
const MAX_STACK := 10
const GOLD_VALUE := 5
const BIG_VALUE := 10
const MAX_THROW := 30
const SILVER := Color(0.8, 0.82, 0.86)
const GOLD := Color(1.0, 0.72, 0.32)
## The $10 coin (and the rare $100+ ones a huge payout is made of): dark bronze, wider and thicker.
const BRONZE := Color(0.62, 0.42, 0.26)
const BIG_SCALE := Vector3(1.2, 1.5, 1.2)
## How far (in cells) a payout's coins scatter around its spot, and sit off a stack's centre.
const AIM_JITTER := 0.25
const STACK_JITTER := 0.12
const FLOATS := 20  # per instance: 12 transform + 4 colour + 4 custom (x: the coin face, 0/1/2 = $1/$5/$10)
const GRAVITY := 9.8
const SETTLE_TIME := 0.12
const HOME_TIME := 0.5
const HOME_STAGGER := 0.03
## How high the homing curve climbs above the start and above the hopper.
const HOME_LIFT := 0.3
## Seconds a thrown coin rises from below the sill to the gap.
const TOSS_TIME := 0.14
const THROW_STAGGER := 0.05
## Seconds a coin popped out of the bin (pop_out) takes from the mouth to the desk.
const POP_TIME := 0.45
const PICKUP_RADIUS := 0.1

@export var desk_height := 0.76
@export var deposit: Node3D
## Thrown-in coins land anywhere in here: the top half of the mat, minus its right 30% where the
## press and the ramp would hide them.
@export var landing_area := AABB(Vector3(-0.3, 0.76, -0.55), Vector3(1.4, 0.0, 0.75))
## Seconds from the gap to the first touch: short keeps the arc flat enough for the gap.
@export var throw_time := Vector2(0.28, 0.36)
## (y, z) where tossed coins come through the window gap. They start out of sight below the
## sill (anything else outside shows through the glass), are tossed up to here, then fly in.
@export var gap_entry := Vector2(0.92, -0.95)


class Coin:
	var state := State.FLYING
	var xf := Transform3D()
	var velocity := Vector3.ZERO
	var spin := Vector3.ZERO
	var has_bounced := false
	var from := Transform3D()
	var to := Transform3D()
	var t := 0.0
	var delay := 0.0
	var toss := 0.0  # seconds left rising from below the sill to the gap
	var inbound := Vector3.ZERO  # velocity from the gap onto the mat
	var value := 1
	var cell := Vector2i.ZERO  # the payout's stack
	var gone := false  # taken by a vacuum, dropped from _coins at the end of vacuum_at
	var slot := -1  # the MultiMesh instance _upload last wrote it to (-1: write it again)


# ponytail: Array of RefCounted coins, the moving ones rewritten each frame (resting ones stay put in
# the buffer); switch to packed arrays if a profile shows the coin loop above ~1 ms.
var _coins: Array[Coin] = []
var _stacks := {}  # Vector2i -> Array[Coin], bottom first
var _buffer := PackedFloat32Array()
## Coins taken off the mat by the coin vacuums and not banked yet (their value).
var _held := 0
## Value of payouts set to arrive by throw_in_after and not thrown yet.
var _scheduled := 0


func _ready() -> void:
	# The MultiMesh resource outlives a scene reload (a save reset): empty it before reformatting.
	multimesh.instance_count = 0
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.use_custom_data = true
	multimesh.visible_instance_count = 0
	custom_aabb = AABB(Vector3(-4, -1, -4), Vector3(8, 4, 8))
	# Coins still flying or lying on the mat are banked when the game quits, not lost.
	SaveManager.closing.connect(func() -> void: bank(SaveManager.save, pending_value()))
	# The autosave writes them in as well (only into the file, the live coins stay as they are).
	SaveManager.pending_coins = pending_value


## The value of every coin not banked yet (in the air, on the mat, on its way to the deposit).
func pending_value() -> int:
	var total := _held + _scheduled
	for coin in _coins:
		total += coin.value
	return total


## Throws `amount` in after `delay` seconds; until then pending_value counts it (so it is banked on quit).
func throw_in_after(delay: float, origin: Vector3, amount: int) -> void:
	_scheduled += amount
	get_tree().create_timer(delay).timeout.connect(_throw_scheduled.bind(origin, amount))


func _throw_scheduled(origin: Vector3, amount: int) -> void:
	_scheduled -= amount
	throw_in(origin, amount)


## Pops `amount` out after `delay` seconds; until then pending_value counts it (so it is banked on quit).
func pop_out_after(delay: float, origin: Vector3, spot: Vector3, amount: int) -> void:
	_scheduled += amount
	get_tree().create_timer(delay).timeout.connect(func() -> void:
		_scheduled -= amount
		pop_out(origin, spot, amount))


## Throws `amount` worth of coins in from `origin` (out of sight below the sill): up to the gap,
## then in, all onto one spot.
func throw_in(origin: Vector3, amount: int) -> void:
	var values := coin_values(amount)
	thrown.emit(origin, values.size())
	var spot := landing_area.position + Vector3(randf(), 0.0, randf()) * landing_area.size
	for i in values.size():
		if _coins.size() >= MAX_COINS:
			_deposit_now(values[i])
			continue
		var coin := Coin.new()
		coin.value = values[i]
		coin.cell = cell_of(spot)
		coin.xf = Transform3D(Basis(Quaternion.from_euler(Vector3(randf(), randf(), randf()) * TAU)), origin)
		var target := spot + Vector3(randf_range(-1, 1), 0.0, randf_range(-1, 1)) * AIM_JITTER * CELL
		var gap := Vector3(origin.x, gap_entry.x, gap_entry.y)
		coin.inbound = ballistic(gap, target, randf_range(throw_time.x, throw_time.y))
		coin.velocity = ballistic(origin, gap, TOSS_TIME)
		coin.toss = TOSS_TIME
		coin.spin = Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)).normalized() * randf_range(10, 20)
		coin.delay = i * THROW_STAGGER
		_coins.append(coin)


## Pops `amount` worth of coins up out of `origin` (the bin's mouth) in a short arc onto one spot
## around `spot` on the desk, to be swept up like any payout.
func pop_out(origin: Vector3, spot: Vector3, amount: int) -> void:
	var values := coin_values(amount)
	thrown.emit(origin, values.size())
	for i in values.size():
		if _coins.size() >= MAX_COINS:
			_deposit_now(values[i])
			continue
		var coin := Coin.new()
		coin.value = values[i]
		coin.cell = cell_of(spot)
		coin.xf = Transform3D(Basis(Quaternion.from_euler(Vector3(randf(), randf(), randf()) * TAU)), origin)
		var target := Vector3(spot.x, desk_height, spot.z) + Vector3(randf_range(-1, 1), 0.0, randf_range(-1, 1)) * AIM_JITTER * CELL
		coin.velocity = ballistic(origin, target, POP_TIME)
		coin.spin = Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)).normalized() * randf_range(10, 20)
		coin.delay = i * THROW_STAGGER
		_coins.append(coin)


func _process(delta: float) -> void:
	if Hand.held == null:
		_sweep(Hand.point_on_height(desk_height))
	var moving := false
	for i in range(_coins.size() - 1, -1, -1):
		var coin := _coins[i]
		match coin.state:
			State.FLYING:
				_fly(coin, delta)
			State.SETTLING:
				coin.t = minf(coin.t + delta / SETTLE_TIME, 1.0)
				coin.xf = coin.from.interpolate_with(coin.to, ease(coin.t, 0.4))
				if coin.t >= 1.0:
					coin.state = State.RESTING
					coin.slot = -1  # its final spot still has to be written
			State.HOMING:
				if _home(coin, delta):
					_coins.remove_at(i)
					bank(SaveManager.save, coin.value)
					deposited.emit(coin.xf.origin)
			State.RESTING:
				continue
		moving = true
	if moving or multimesh.visible_instance_count != _coins.size():
		_upload()


func _fly(coin: Coin, delta: float) -> void:
	if coin.delay > 0.0:
		coin.delay -= delta
		return
	coin.velocity.y -= GRAVITY * delta
	coin.xf.origin += coin.velocity * delta
	coin.xf.basis = Basis(Quaternion(coin.spin.normalized(), coin.spin.length() * delta)) * coin.xf.basis
	if coin.toss > 0.0:
		coin.toss -= delta
		if coin.toss <= 0.0:
			coin.velocity = coin.inbound
		return
	if _stacks.get(coin.cell, []).size() >= MAX_STACK:
		coin.cell = stack_cell(_stacks, coin.cell, MAX_STACK)
	var floor_y := _top(coin.cell) + thickness(coin.value) * 0.5
	if coin.xf.origin.y > floor_y or coin.velocity.y > 0.0:
		return
	coin.xf.origin.y = floor_y
	if not coin.has_bounced and coin.velocity.y < -1.0:
		coin.has_bounced = true
		coin.velocity = Vector3(coin.velocity.x * 0.15, -coin.velocity.y * 0.3, coin.velocity.z * 0.15)
		coin.spin *= 0.5
		bounced.emit(coin.xf.origin)
		return
	_land(coin)


func _land(coin: Coin) -> void:
	var cell := stack_cell(_stacks, coin.cell, MAX_STACK)
	var stack: Array = _stacks.get_or_add(cell, [])
	var below := _top(cell)
	stack.append(coin)
	var centre := cell_centre(cell) + Vector2(randf_range(-1, 1), randf_range(-1, 1)) * STACK_JITTER * CELL
	var tilt := Basis(Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized(), randf_range(0, 0.12))
	coin.from = coin.xf
	coin.to = Transform3D(tilt * Basis(Vector3.UP, randf() * TAU),
			Vector3(centre.x, below + thickness(coin.value) * 0.5, centre.y))
	coin.state = State.SETTLING
	coin.t = 0.0
	landed.emit(coin.to.origin)


## Coins under the empty hand fly off to the deposit, nearest first.
func _sweep(point: Vector3) -> void:
	var reach := ceili(PICKUP_RADIUS / CELL)
	var centre := cell_of(point)
	var order := 0
	for dx in range(-reach, reach + 1):
		for dz in range(-reach, reach + 1):
			var cell := centre + Vector2i(dx, dz)
			if not _stacks.has(cell) or cell_centre(cell).distance_to(Vector2(point.x, point.z)) > PICKUP_RADIUS:
				continue
			for coin: Coin in _stacks[cell]:
				coin.state = State.HOMING
				coin.from = coin.xf
				coin.t = 0.0
				coin.delay = order * HOME_STAGGER
				order += 1
				collected.emit(coin.xf.origin)
			_stacks.erase(cell)


## A coin vacuum at `point` sucks up the resting stacks within `reach`, at most `room` coins, and
## holds them (pending_value still counts them) until bank_from. Returns (coins taken, their value).
func vacuum_at(point: Vector3, reach: float, room: int) -> Vector2i:
	var taken := 0
	var value := 0
	var span := ceili(reach / CELL)
	var centre := cell_of(point)
	for dx in range(-span, span + 1):
		for dz in range(-span, span + 1):
			var cell := centre + Vector2i(dx, dz)
			if taken >= room or not _stacks.has(cell) or cell_centre(cell).distance_to(Vector2(point.x, point.z)) > reach:
				continue
			var stack: Array = _stacks[cell]
			# Whole stacks only once they have settled, top coin first.
			if not _settled(stack):
				continue
			while not stack.is_empty() and taken < room:
				var coin: Coin = stack.pop_back()
				coin.gone = true
				_held += coin.value
				value += coin.value
				taken += 1
				collected.emit(coin.xf.origin)
			if stack.is_empty():
				_stacks.erase(cell)
	if taken > 0:
		# One pass drops the taken coins (order kept, though _upload doesn't need it).
		var kept := 0
		for coin in _coins:
			if not coin.gone:
				_coins[kept] = coin
				kept += 1
		_coins.resize(kept)
	return Vector2i(taken, value)


## The centres (on the desk) of the stacks resting on the mat, for the vacuums to drive to.
func resting_spots() -> Array[Vector3]:
	var out: Array[Vector3] = []
	for cell: Vector2i in _stacks:
		var stack: Array = _stacks[cell]
		if not stack.is_empty() and _settled(stack):
			var at := cell_centre(cell)
			out.append(Vector3(at.x, desk_height, at.y))
	return out


static func _settled(stack: Array) -> bool:
	for coin: Coin in stack:
		if coin.state != State.RESTING:
			return false
	return true


## A vacuum empties its bag at `point`: `value` worth of the held coins fly from there to the deposit.
func bank_from(point: Vector3, value: int) -> void:
	value = mini(value, _held)
	_held -= value
	var order := 0
	for v in coin_values(value):
		if _coins.size() >= MAX_COINS:
			_deposit_now(v)
			continue
		var coin := Coin.new()
		coin.value = v
		coin.state = State.HOMING
		coin.xf = Transform3D(Basis(), point + Vector3(randf_range(-1, 1), 0.0, randf_range(-1, 1)) * 0.02)
		coin.from = coin.xf
		coin.delay = order * HOME_STAGGER
		order += 1
		_coins.append(coin)


## Up, over the hopper, then straight down into its mouth, accelerating. True when it arrives.
func _home(coin: Coin, delta: float) -> bool:
	if coin.delay > 0.0:
		coin.delay -= delta
		return false
	coin.t = minf(coin.t + delta / HOME_TIME, 1.0)
	var target := deposit.global_position if deposit != null else coin.from.origin
	coin.xf.origin = home_point(coin.from.origin, target, coin.t * coin.t)
	# Spins in flight and shrinks only once it is inside the funnel.
	coin.xf.basis = (Basis(Vector3.RIGHT, delta * 18.0) * coin.xf.basis).orthonormalized() \
			.scaled(Vector3.ONE * (1.0 - smoothstep(0.88, 1.0, coin.t)))
	return coin.t >= 1.0


## Cubic curve whose last handle sits straight above the target, so it ends dropping vertically.
static func home_point(start: Vector3, target: Vector3, k: float) -> Vector3:
	var a := start + Vector3.UP * HOME_LIFT
	var b := target + Vector3.UP * HOME_LIFT
	var p := start.lerp(a, k).lerp(a.lerp(b, k), k)
	var q := a.lerp(b, k).lerp(b.lerp(target, k), k)
	return p.lerp(q, k)


static func ballistic(from: Vector3, to: Vector3, time: float) -> Vector3:
	return (to - from) / time + 0.5 * Vector3.UP * GRAVITY * time


## `value` coins reach the save: held, and counted in save.coins_earned.
static func bank(save: SaveGame, value: int) -> void:
	save.coins += value
	save.coins_earned += value


func _deposit_now(value: int) -> void:
	bank(SaveManager.save, value)
	deposited.emit(deposit.global_position if deposit != null else global_position)


func _top(cell: Vector2i) -> float:
	var top := desk_height
	for coin: Coin in _stacks.get(cell, []):
		top += thickness(coin.value)
	return top


static func thickness(value: int) -> float:
	return THICKNESS * BIG_SCALE.y if value >= BIG_VALUE else THICKNESS


## Resting coins still in the slot they were last written to are skipped: the buffer keeps them.
func _upload() -> void:
	var room := ceili(_coins.size() / float(CHUNK)) * CHUNK
	if room > multimesh.instance_count:
		multimesh.instance_count = room
		_buffer.resize(room * FLOATS)
	for i in _coins.size():
		if _coins[i].state == State.RESTING and _coins[i].slot == i:
			continue
		_coins[i].slot = i
		var xf := _coins[i].xf
		if _coins[i].value >= BIG_VALUE:
			xf.basis = xf.basis * Basis.from_scale(BIG_SCALE)
		if _coins[i].state == State.FLYING and _coins[i].delay > 0.0:
			xf = Transform3D(Basis.from_scale(Vector3.ZERO), xf.origin)
		var o := i * FLOATS
		_buffer[o] = xf.basis.x.x
		_buffer[o + 1] = xf.basis.y.x
		_buffer[o + 2] = xf.basis.z.x
		_buffer[o + 3] = xf.origin.x
		_buffer[o + 4] = xf.basis.x.y
		_buffer[o + 5] = xf.basis.y.y
		_buffer[o + 6] = xf.basis.z.y
		_buffer[o + 7] = xf.origin.y
		_buffer[o + 8] = xf.basis.x.z
		_buffer[o + 9] = xf.basis.y.z
		_buffer[o + 10] = xf.basis.z.z
		_buffer[o + 11] = xf.origin.z
		var colour := coin_colour(_coins[i].value)
		_buffer[o + 12] = colour.r
		_buffer[o + 13] = colour.g
		_buffer[o + 14] = colour.b
		_buffer[o + 15] = 1.0
		_buffer[o + 16] = coin_face(_coins[i].value)
	multimesh.buffer = _buffer
	multimesh.visible_instance_count = _coins.size()


## Which face of the coin atlas (assets/shaders/coin.gdshader) the coin shows.
static func coin_face(value: int) -> float:
	return 2.0 if value >= BIG_VALUE else 1.0 if value >= GOLD_VALUE else 0.0


static func coin_colour(value: int) -> Color:
	return BRONZE if value >= BIG_VALUE else GOLD if value >= GOLD_VALUE else SILVER


static func cell_of(point: Vector3) -> Vector2i:
	return Vector2i(floori(point.x / CELL), floori(point.z / CELL))


static func cell_centre(cell: Vector2i) -> Vector2:
	return (Vector2(cell) + Vector2(0.5, 0.5)) * CELL


## The fewest coins: silver for the change, a gold $5, then a bronze $10 for every full ten of
## `amount`: thrown in this order, the biggest end up on top of the stack where the camera sees
## them. A big amount comes as bronze worth ten times more, and again, so one payout never throws
## much more than MAX_THROW coins.
static func coin_values(amount: int) -> Array[int]:
	var big := BIG_VALUE
	@warning_ignore("integer_division")
	while amount / big > MAX_THROW:
		big *= 10
	var out: Array[int] = []
	for i in amount % GOLD_VALUE:
		out.append(1)
	@warning_ignore("integer_division")
	for i in (amount % BIG_VALUE) / GOLD_VALUE:
		out.append(GOLD_VALUE)
	@warning_ignore("integer_division")
	for i in (amount % big) / BIG_VALUE:
		out.append(BIG_VALUE)
	@warning_ignore("integer_division")
	for i in amount / big:
		out.append(big)
	return out


## Where a coin aimed at `cell` lands: on that stack while it is under `max_height`, else on the
## nearest stack around it with room (a random one of those, so overflow looks loose).
static func stack_cell(stacks: Dictionary, cell: Vector2i, max_height: int) -> Vector2i:
	for ring in 8:
		var free: Array[Vector2i] = []
		for dx in range(-ring, ring + 1):
			for dz in range(-ring, ring + 1):
				var near := cell + Vector2i(dx, dz)
				if maxi(absi(dx), absi(dz)) == ring and stacks.get(near, []).size() < max_height:
					free.append(near)
		if not free.is_empty():
			return free.pick_random()
	return cell
