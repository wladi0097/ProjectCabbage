class_name CoinPile
extends MultiMeshInstance3D
## Every loose coin, drawn as one MultiMesh. Coins are animated, not simulated: they arc in,
## bounce once and land on a height grid. One payout comes as silver ($1), gold ($5), bronze ($10),
## steel ($50) and platinum ($100) coins, and for a big one $500 / $1K / $5K / $10K coins (and with
## CRITICAL_MASS_CARD up to $1B, see coin_values), each bigger and thicker from $10 up, that all aim at one
## spot and stack there, at most MAX_STACK high; extra coins start a stack right beside it. Sweeping an empty hand over them sends them into the deposit.
## The purse has a limit (SaveGame.coin_limit): a payout only throws in what still fits beside the
## coins already out (fitting); the rest never comes in. One coin of it is tossed up to the gap and
## drops back into the street, and `refused` fires (the tally machine's FULL plate; its buzzer only as the purse becomes full).
## Piles spread sideways, never up: a full stack sends the next coin to the nearest stack with room
## inside pile_area (stack_cell), and at most MAX_ON_DESK coins are out at once. What a payout has
## beyond that is held back (_withheld, still pending_value, so never lost): every KNOCK seconds a
## coin shows at the gap and drops back, and as soon as coins are picked up it comes in, as the
## fewest coins.
## Once MERGE_CARD is stamped, every save.merge_every seconds the coins lying on the desk merge: 5 or 2
## of one coin (MERGE_RATIO, merge_pick) fly together over the first of them and pop up as the next
## coin up, at most save.merge_top; the stacks they left drop down onto what is left.

signal thrown(origin: Vector3, count: int)
signal bounced(position: Vector3)
signal landed(position: Vector3)
signal collected(position: Vector3)
signal deposited(position: Vector3)
## Part of a payout did not fit under the coin limit and was lost.
signal refused(position: Vector3)

enum State { FLYING, SETTLING, RESTING, HOMING, MERGING }

const MAX_COINS := 4096
## The MultiMesh grows by this many instances when the coins outgrow it (never shrinks): the whole
## buffer is sent each upload, so it is kept near the coins actually out.
const CHUNK := 256
const CELL := 0.054
const THICKNESS := 0.014
const MAX_STACK := 10
## The most coins out at once (flying, lying, homing): a payout's coins past it are held back. Well
## under what pile_area holds (its cells x MAX_STACK), so a coin always finds a stack with room, and
## the bound on the coins drawn and moved each frame (they are MultiMesh instances, not bodies).
const MAX_ON_DESK := 1500
## Seconds between tries to bring held-back coins in (and between the coins shown waiting at the gap).
const KNOCK := 1.0
const GOLD_VALUE := 5
const BIG_VALUE := 10
const FIFTY_VALUE := 50
const HUNDRED_VALUE := 100
## Every coin face, smallest first: the index is its column in the coin atlas. $1..$100 make change
## for every payout; the high coins from $500 up join a payout only when it would otherwise throw
## more than MAX_THROW of the coin below them (coin_values).
## The seven past $10K pay out and merge only once CRITICAL_MASS_CARD is stamped (coins_open).
const DENOMINATIONS: Array[int] = [1, GOLD_VALUE, BIG_VALUE, FIFTY_VALUE, HUNDRED_VALUE, 500, 1000, 5000, 10000,
		50000, 100000, 500000, 1000000, 10000000, 100000000, 1000000000]
## How many of DENOMINATIONS are out before CRITICAL_MASS_CARD ($1 .. $10K), and what the Findings
## tokens always use (they stop at ¶10K).
const OLD_COINS := 9
## The desk card that opens the coins past $10K.
const CRITICAL_MASS_CARD := "critical_mass"
## How many of DENOMINATIONS (from $1) every payout may use.
const CHANGE := 5
const MAX_THROW := 30
const SILVER := Color(0.8, 0.82, 0.86)
const GOLD := Color(1.0, 0.72, 0.32)
## The $10 coin: dark bronze, wider and thicker.
const BRONZE := Color(0.62, 0.42, 0.26)
const BIG_SCALE := Vector3(1.2, 1.5, 1.2)
## The $50 coin: dark blue-grey gunmetal with an octagon stamped inside its rim, wider again.
const STEEL := Color(0.42, 0.48, 0.56)
const FIFTY_SCALE := Vector3(1.32, 1.7, 1.32)
## The $100 coin: pale platinum with a dark inlaid centre and a reeded rim.
const PLATINUM := Color(0.92, 0.88, 0.78)
const HUNDRED_SCALE := Vector3(1.5, 1.9, 1.5)
## The $500 coin: grey steel, a pale centre inside a near-black band broken by 8 bars.
const PEWTER := Color(0.68, 0.7, 0.72)
## The $1K coin: pale cold gold (desaturated), a scalloped seal on a dark field.
const PALE_GOLD := Color(0.86, 0.79, 0.6)
## The $5K coin: dark oxidised bronze, a square seal.
const OXIDE := Color(0.55, 0.4, 0.3)
## The $10K coin (and, before CRITICAL_MASS_CARD, the bigger ones a huge payout is made of): blackened steel, a pale double
## reeded rim and numeral on a black field, the biggest and thickest.
const BLACK_STEEL := Color(0.6, 0.63, 0.67)
## CRITICAL MASS ($50K .. $1B), every field dark: blued steel ($50K, hexagon seal), gunmetal ($100K,
## three rings), lead grey ($500K, rays), cold titanium ($1M, turned double square), black steel
## ($10M, notched gear rim), violet-grey tempered steel ($100M, 12-sided seal) and a pale
## uranium-glass tint ($1B, three blades): cold and never cabbage green.
const BLUED := Color(0.48, 0.58, 0.78)
const GUNMETAL := Color(0.5, 0.52, 0.55)
const LEAD := Color(0.66, 0.66, 0.7)
const TITANIUM := Color(0.76, 0.79, 0.86)
const BLACK_IRON := Color(0.42, 0.43, 0.46)
const TEMPERED := Color(0.64, 0.6, 0.72)
const URANIUM := Color(0.86, 0.9, 0.72)
const COLOURS: Array[Color] = [SILVER, GOLD, BRONZE, STEEL, PLATINUM, PEWTER, PALE_GOLD, OXIDE, BLACK_STEEL,
		BLUED, GUNMETAL, LEAD, TITANIUM, BLACK_IRON, TEMPERED, URANIUM]
const SCALES: Array[Vector3] = [Vector3.ONE, Vector3.ONE, BIG_SCALE, FIFTY_SCALE, HUNDRED_SCALE,
		Vector3(1.58, 2.0, 1.58), Vector3(1.66, 2.1, 1.66), Vector3(1.74, 2.2, 1.74), Vector3(1.82, 2.3, 1.82),
		Vector3(1.9, 2.4, 1.9), Vector3(1.98, 2.5, 1.98), Vector3(2.06, 2.6, 2.06), Vector3(2.14, 2.7, 2.14),
		Vector3(2.22, 2.8, 2.22), Vector3(2.3, 2.9, 2.3), Vector3(2.4, 3.0, 2.4)]
## How far (in cells) a payout's coins scatter around its spot, and sit off a stack's centre.
const AIM_JITTER := 0.25
const STACK_JITTER := 0.12
const FLOATS := 20  # per instance: 12 transform + 4 colour + 4 custom (x: the coin face, 0..15 = $1 .. $1B)
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
## The longest step (m on the desk) between two frames' hand points still swept as one stroke; a
## bigger jump (the mouse back from outside the window) starts afresh instead of sweeping a line.
const MAX_STROKE := 0.5
## Everything swept up in one frame has left within this many seconds, however much it is.
const HOME_SPREAD := 0.3
## The desk card that merges the coins on the desk (save.merge_every, merge_top).
const MERGE_CARD := "coin_merge"
## Merging coins first wobble once (MERGE_SHAKE s, MERGE_SHAKE_SIZE m to each side), then fly together
## over MERGE_TIME s to MERGE_LIFT m above the first of them; the new coin hops up once at MERGE_HOP
## m/s (no bounce when it lands) and swells MERGE_SWELL bigger for MERGE_POP s as it goes.
const MERGE_SHAKE := 0.18
const MERGE_SHAKE_SIZE := 0.003
const MERGE_TIME := 0.35
const MERGE_LIFT := 0.06
const MERGE_HOP := 1.6
const MERGE_SWELL := 0.6
const MERGE_POP := 0.3

@export var desk_height := 0.76
@export var deposit: Node3D
## Thrown-in coins land anywhere in here: the top half of the mat, minus its right 30% where the
## press and the ramp would hide them.
@export var landing_area := AABB(Vector3(-0.3, 0.76, -0.55), Vector3(1.4, 0.0, 0.75))
## Where coins may lie: a coin whose stack is full goes to the nearest stack with room in here (the
## open mat left of the press and the ramp, down to where the coin robots still drive).
@export var pile_area := AABB(Vector3(-0.3, 0.76, -0.55), Vector3(1.4, 0.0, 1.2))
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
	var lost := false  # a refused payout's coin (worth nothing): up to the gap, then back down into the street
	var merged := 0  # merging: the first of the group, which becomes a coin worth this much (the others 0, they go)
	var pop := 0.0  # seconds left of a merged coin's swell


# ponytail: Array of RefCounted coins, the moving ones rewritten each frame (resting ones stay put in
# the buffer); switch to packed arrays if a profile shows the coin loop above ~1 ms.
var _coins: Array[Coin] = []
var _stacks := {}  # Vector2i -> Array[Coin], bottom first
var _buffer := PackedFloat32Array()
## Coins taken off the mat by the coin vacuums and not banked yet (their value).
var _held := 0
## Value of payouts set to arrive by throw_in_after and not thrown yet.
var _scheduled := 0
## Grid cells no coin lands on: the QA bay and the patch of desk its slips lie on (set by the bay
## once it is in), so coins never end up under the bay or bury the slips.
var keep_clear := Rect2i()
## Value of the coins held back while MAX_ON_DESK are out, where they come in from, and the seconds
## until the next try.
var _withheld := 0
var _withheld_from := Vector3(0.4, 0.6, -1.0)
var _knock := 0.0
## The empty hand's point on the desk last frame (null while it holds something).
var _last_hand: Variant = null
## The tallest a stack can be (m above the desk), for _sweep's window: MAX_STACK of the thickest
## coin, raised by _land should a stack on a full mat spill past MAX_STACK. Never lowered.
var _tallest: float = MAX_STACK * THICKNESS * SCALES.map(func(s: Vector3) -> float: return s.y).max()
## The end and mouse ray of the last stroke _sweep tested, and whether a coin has landed since.
var _swept_to := Vector3.INF
var _swept_rise := Vector3.ZERO
var _landed := false
## Seconds to the next merge (MERGE_CARD).
var _merge_in := 0.0
## How many of DENOMINATIONS pay out, merge and show (coins_open), kept up each frame.
var _open := OLD_COINS


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
	var total := _held + _scheduled + _withheld
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
	var fits := _fit(amount, origin)
	if fits < amount:
		_toss_back(origin)  # The street keeps it: shown at the gap, never on the mat.
	_withheld_from = origin
	var values := _hold_back(coin_values(fits, _open))
	if values.is_empty():
		return
	thrown.emit(origin, values.size())
	var spot := landing_area.position + Vector3(randf(), 0.0, randf()) * landing_area.size
	for _try in 16:
		if not keep_clear.has_point(cell_of(spot)):
			break
		spot = landing_area.position + Vector3(randf(), 0.0, randf()) * landing_area.size
	for i in values.size():
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


## A coin worth nothing shows at the gap above `origin` and drops back into the street.
func _toss_back(origin: Vector3) -> void:
	if _coins.size() >= MAX_COINS:
		return
	var kept := Coin.new()
	kept.value = 0
	kept.lost = true
	kept.xf = Transform3D(Basis(Quaternion.from_euler(Vector3(randf(), randf(), randf()) * TAU)), origin)
	kept.velocity = ballistic(origin, Vector3(origin.x, gap_entry.x, gap_entry.y), TOSS_TIME)
	kept.toss = TOSS_TIME
	kept.spin = Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)).normalized() * randf_range(10, 20)
	_coins.append(kept)


## The coins of `values` there is room for on the desk (MAX_ON_DESK), smallest first as given; the
## value of the rest is held back.
func _hold_back(values: Array[int]) -> Array[int]:
	var room := clampi(MAX_ON_DESK - _coins.size(), 0, values.size())
	for i in range(room, values.size()):
		_withheld += values[i]
	return values.slice(0, room)


## Held-back coins come in once there is room on the desk (as one payout: the fewest coins, the rest
## held back again); until then one shows at the gap and drops back.
func _release(delta: float) -> void:
	_knock -= delta
	if _knock > 0.0:
		return
	_knock = KNOCK
	if _coins.size() >= MAX_ON_DESK:
		_toss_back(_withheld_from)
		return
	var amount := _withheld
	_withheld = 0
	throw_in(_withheld_from, amount)


## Pops `amount` worth of coins up out of `origin` (the bin's mouth) in a short arc onto one spot
## around `spot` on the desk, to be swept up like any payout.
func pop_out(origin: Vector3, spot: Vector3, amount: int) -> void:
	var values := _hold_back(coin_values(_fit(amount, origin), _open))
	if values.is_empty():
		return
	thrown.emit(origin, values.size())
	for i in values.size():
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
		var now := Hand.point_on_height(desk_height)
		_sweep(stroke_start(_last_hand, now), now, Hand.point_on_height(desk_height + 1.0) - now)
		_last_hand = now
	else:
		_last_hand = null
	if _withheld > 0:
		_release(delta)
	var save := SaveManager.save
	var open := coins_open(save)
	if open != _open:
		_reopen(open)
	if save.stamped.has(MERGE_CARD):
		_merge_in -= delta
		if _merge_in <= 0.0:
			_merge_in = save.merge_every
			merge_once(save.merge_top)
	var moving := false
	for i in range(_coins.size() - 1, -1, -1):
		var coin := _coins[i]
		match coin.state:
			State.FLYING:
				coin.pop = maxf(coin.pop - delta, 0.0)
				_fly(coin, delta)
				if coin.lost and coin.toss <= 0.0 and coin.xf.origin.y < desk_height:
					_coins[i] = _coins[-1]  # Back under the sill, out of sight: gone.
					_coins.pop_back()
			State.SETTLING:
				coin.t = minf(coin.t + delta / SETTLE_TIME, 1.0)
				coin.xf = coin.from.interpolate_with(coin.to, ease(coin.t, 0.4))
				if coin.t >= 1.0:
					coin.state = State.RESTING
					coin.slot = -1  # its final spot still has to be written
			State.HOMING:
				if _home(coin, delta):
					# The last coin (already done this frame) takes its place: only that one is re-uploaded.
					_coins[i] = _coins[-1]
					_coins.pop_back()
					bank(SaveManager.save, coin.value)
					deposited.emit(coin.xf.origin)
			State.MERGING:
				var first := coin.merged > 0
				if _merge_step(coin, delta) and not first:
					_coins[i] = _coins[-1]  # Merged into the first of its group: gone.
					_coins.pop_back()
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
	if coin.lost:
		return
	if _stacks.get(coin.cell, []).size() >= MAX_STACK or keep_clear.has_point(coin.cell):
		coin.cell = stack_cell(_stacks, coin.cell, MAX_STACK, _pile_cells(), keep_clear)
	var floor_y := _top(coin.cell) + thickness(coin.value, _open) * 0.5
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
	var cell := stack_cell(_stacks, coin.cell, MAX_STACK, _pile_cells(), keep_clear)
	var stack: Array = _stacks.get_or_add(cell, [])
	var below := _top(cell)
	stack.append(coin)
	var centre := cell_centre(cell) + Vector2(randf_range(-1, 1), randf_range(-1, 1)) * STACK_JITTER * CELL
	var tilt := Basis(Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized(), randf_range(0, 0.12))
	coin.from = coin.xf
	coin.to = Transform3D(tilt * Basis(Vector3.UP, randf() * TAU),
			Vector3(centre.x, below + thickness(coin.value, _open) * 0.5, centre.y))
	coin.state = State.SETTLING
	coin.t = 0.0
	_landed = true
	_tallest = maxf(_tallest, below + thickness(coin.value, _open) - desk_height)
	landed.emit(coin.to.origin)


## Stacks under the empty hand's stroke this frame (`from` last frame's point to `to`, `rise` the
## mouse ray per metre up) fly off to the deposit whole, each top coin first, all within HOME_SPREAD.
func _sweep(from: Vector3, to: Vector3, rise: Vector3) -> void:
	# Nothing new to find: no coins, or the hand still on the point it was tested on last and no coin
	# landed since (stacks otherwise only shrink, and a shorter stack shows under less of the desk).
	if _stacks.is_empty() or (from == to and to == _swept_to and rise == _swept_rise and not _landed):
		return
	_swept_to = to
	_swept_rise = rise
	_landed = false
	var taken: Array[Coin] = []
	# ponytail: a grid box around the stroke, widened by the tallest possible stack even where the
	# stacks are short; narrow it per stack height if it shows in a profile again.
	for cell in _stacks_near(from, to, rise):
		var at := cell_centre(cell)
		if not under_hand(from, to, rise, Vector3(at.x, desk_height, at.y), Vector3(at.x, _top(cell), at.y)):
			continue
		var stack: Array = _stacks[cell]
		for i in range(stack.size() - 1, -1, -1):
			taken.append(stack[i])
		_stacks.erase(cell)
	for i in taken.size():
		var coin := taken[i]
		coin.state = State.HOMING
		coin.from = coin.xf
		coin.t = 0.0
		coin.delay = home_delay(i, taken.size())
		collected.emit(coin.xf.origin)


## The cells of the stacks that could show under the stroke `from`..`to` (see under_hand): a foot
## within PICKUP_RADIUS of the stroke slid back along `rise` by up to _tallest. Looks them up in that
## box of the grid, or walks the stacks instead when there are fewer of them than cells in the box.
func _stacks_near(from: Vector3, to: Vector3, rise: Vector3) -> Array[Vector2i]:
	var flat := Vector2(rise.x, rise.z)
	var low := flat * (desk_height - from.y)
	var high := flat * (desk_height + _tallest - from.y)
	var reach := Vector2.ONE * (PICKUP_RADIUS + 0.001)  # a hair more: no float edge drops a stack
	var lo := Vector2(minf(from.x, to.x), minf(from.z, to.z)) + low.min(high) - reach
	var hi := Vector2(maxf(from.x, to.x), maxf(from.z, to.z)) + low.max(high) + reach
	var a := cell_of(Vector3(lo.x, 0.0, lo.y))
	var b := cell_of(Vector3(hi.x, 0.0, hi.y))
	var out: Array[Vector2i] = []
	if (b.x - a.x + 1) * (b.y - a.y + 1) < _stacks.size():
		for x in range(a.x, b.x + 1):
			for z in range(a.y, b.y + 1):
				if _stacks.has(Vector2i(x, z)):
					out.append(Vector2i(x, z))
	else:
		for cell: Vector2i in _stacks:
			if cell.x >= a.x and cell.x <= b.x and cell.y >= a.y and cell.y <= b.y:
				out.append(cell)
	return out


## Whether the empty hand's stroke this frame (`from` to `to` on the desk) passes within
## PICKUP_RADIUS of something reaching from `low` up to `high` where the player sees it: each end
## slides down the mouse ray (`rise`: how far it moves per metre up) onto the desk first, so a coin
## high on a heap counts where it shows under the hand, not where its foot is.
static func under_hand(from: Vector3, to: Vector3, rise: Vector3, low: Vector3, high: Vector3) -> bool:
	var a := low - rise * (low.y - from.y)
	var b := high - rise * (high.y - from.y)
	var closest := Geometry3D.get_closest_points_between_segments(from, to, a, b)
	return Vector2(closest[0].x - closest[1].x, closest[0].z - closest[1].z).length() <= PICKUP_RADIUS


## Where this frame's stroke of the empty hand starts: where it was last frame, or where it is now
## (first frame empty-handed, or a jump longer than MAX_STROKE).
static func stroke_start(last: Variant, now: Vector3) -> Vector3:
	return last if last is Vector3 and (last as Vector3).distance_to(now) <= MAX_STROKE else now


## Seconds the `i`th of `count` things swept up at once waits before it flies off: HOME_STAGGER
## apart, closer for a big haul so the last one has left within HOME_SPREAD.
static func home_delay(i: int, count: int) -> float:
	return i * minf(HOME_STAGGER, HOME_SPREAD / maxi(count, 1))


## Seconds the `i`th of `count` things out of a coin robot's bag waits before it flies off: HOME_STAGGER
## apart, or with `bulk` (BULK DISCHARGE) the whole bag within HOME_SPREAD (home_delay).
static func bag_delay(i: int, count: int, bulk: bool) -> float:
	return home_delay(i, count) if bulk else i * HOME_STAGGER


## How many of DENOMINATIONS `save` has open: all once CRITICAL_MASS_CARD is stamped, else OLD_COINS.
static func coins_open(save: SaveGame) -> int:
	return DENOMINATIONS.size() if save.stamped.has(CRITICAL_MASS_CARD) else OLD_COINS


## The coins past $10K open (or close, on a reset): every coin is drawn afresh and the stacks settle
## onto their new thicknesses.
func _reopen(open: int) -> void:
	_open = open
	for coin in _coins:
		coin.slot = -1
	for cell: Vector2i in _stacks.keys():
		_drop_down(cell)


## How many of DENOMINATIONS[i] make one of the next coin up: 5 or 2 (10 from $1M to $1B).
static func merge_ratio(i: int) -> int:
	@warning_ignore("integer_division")
	return DENOMINATIONS[i + 1] / DENOMINATIONS[i]


## The coins of `values` that merge next, as their indices: the first merge_ratio of the smallest
## coin there are enough of whose next coin up is at most `top`. None: nothing to merge.
## Only the first `coins` DENOMINATIONS merge (the Findings tokens stay at the default: ¶10K).
static func merge_pick(values: Array[int], top: int, coins := OLD_COINS) -> Array[int]:
	for i in coins - 1:
		if DENOMINATIONS[i + 1] > top:
			break
		var found: Array[int] = []
		for at in values.size():
			if values[at] == DENOMINATIONS[i]:
				found.append(at)
				if found.size() == merge_ratio(i):
					return found
	return []


## One merge, if the resting stacks hold one (merge_pick, top coins first): the coins leave their
## stacks (which drop down onto what is left) and fly together over the first of them. True if any.
func merge_once(top: int) -> bool:
	var coins: Array[Coin] = []
	var cells: Array[Vector2i] = []
	for cell: Vector2i in _stacks:
		var stack: Array = _stacks[cell]
		if not _settled(stack):
			continue
		for i in range(stack.size() - 1, -1, -1):
			coins.append(stack[i])
			cells.append(cell)
	var values: Array[int] = []
	for coin in coins:
		values.append(coin.value)
	var pick := merge_pick(values, top, _open)
	if pick.is_empty():
		return false
	var spot := coins[pick[0]].xf.origin + Vector3.UP * MERGE_LIFT
	var touched := {}
	for at in pick:
		var coin := coins[at]
		(_stacks[cells[at]] as Array).erase(coin)
		touched[cells[at]] = true
		coin.state = State.MERGING
		coin.from = coin.xf
		coin.to = Transform3D(coin.xf.basis, spot)
		coin.t = 0.0
		coin.delay = MERGE_SHAKE
		coin.merged = 0
	var first := coins[pick[0]]
	first.merged = values[pick[0]] * pick.size()
	first.cell = cells[pick[0]]
	for cell: Vector2i in touched:
		_drop_down(cell)
	return true


## A merging coin wobbles once on its stack, then flies on toward the group's spot, rising a little and
## spinning. Arrived (true), the first of the group becomes the merged coin and hops up off the spot
## once, swelling, and lands without a bounce; the rest are gone.
func _merge_step(coin: Coin, delta: float) -> bool:
	if coin.delay > 0.0:
		coin.delay = maxf(coin.delay - delta, 0.0)
		coin.xf.origin = coin.from.origin + shake_offset(1.0 - coin.delay / MERGE_SHAKE)
		return false
	coin.t = minf(coin.t + delta / MERGE_TIME, 1.0)
	var k := ease(coin.t, 2.0)
	coin.xf.origin = coin.from.origin.lerp(coin.to.origin, k) + Vector3.UP * MERGE_LIFT * 4.0 * k * (1.0 - k)
	coin.xf.basis = (Basis(Vector3.UP, delta * 14.0) * coin.xf.basis).orthonormalized()
	if coin.t < 1.0:
		return false
	if coin.merged > 0:
		coin.value = coin.merged
		coin.merged = 0
		coin.state = State.FLYING
		coin.velocity = Vector3.UP * MERGE_HOP
		coin.spin = Vector3(randf_range(-1, 1), 1.0, randf_range(-1, 1)).normalized() * 12.0
		coin.has_bounced = true  # one jump: it lands without the payout's bounce
		coin.pop = MERGE_POP
		coin.slot = -1
	return true


## The coins of the stack on `cell` lie on the desk and on each other again: one whose coins below
## left settles down onto what is left.
func _drop_down(cell: Vector2i) -> void:
	var stack: Array = _stacks.get(cell, [])
	if stack.is_empty():
		_stacks.erase(cell)
		return
	var y := desk_height
	for coin: Coin in stack:
		var want := y + thickness(coin.value, _open) * 0.5
		y += thickness(coin.value, _open)
		if absf(coin.xf.origin.y - want) > 0.0001:
			coin.from = coin.xf
			coin.to = Transform3D(coin.xf.basis, Vector3(coin.xf.origin.x, want, coin.xf.origin.z))
			coin.state = State.SETTLING
			coin.t = 0.0


## How far a merging coin (or token) sits off its spot `k` (0..1) through its wobble: one slow sine,
## out to one side and the other and back to rest.
static func shake_offset(k: float) -> Vector3:
	return Vector3.RIGHT * MERGE_SHAKE_SIZE * sin(TAU * clampf(k, 0.0, 1.0))


## The swell of a merged coin with `pop` seconds of it left: 1 (none) up to 1 + MERGE_SWELL halfway.
static func pop_scale(pop: float) -> float:
	return 1.0 + MERGE_SWELL * sin(PI * clampf(1.0 - pop / MERGE_POP, 0.0, 1.0)) if pop > 0.0 else 1.0


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


## A vacuum empties its bag at `point`: `value` worth of the held coins fly from there to the deposit,
## one by one, or all within HOME_SPREAD with `bulk` (BULK DISCHARGE).
func bank_from(point: Vector3, value: int, bulk := false) -> void:
	value = mini(value, _held)
	_held -= value
	var order := 0
	var values := coin_values(value, _open)
	for v in values:
		if _coins.size() >= MAX_COINS:
			_deposit_now(v)
			continue
		var coin := Coin.new()
		coin.value = v
		coin.state = State.HOMING
		coin.xf = Transform3D(Basis(), point + Vector3(randf_range(-1, 1), 0.0, randf_range(-1, 1)) * 0.02)
		coin.from = coin.xf
		coin.delay = bag_delay(order, values.size(), bulk)
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


## `value` coins reach the save: what fits under its coin limit (SaveGame.earn) is held, and counted
## in save.coins_earned.
static func bank(save: SaveGame, value: int) -> void:
	save.coins_earned += save.earn(&"coins", value)


## What of a payout of `amount` comes in: what the purse still has `room` for (SaveGame.room) beside
## the `pending` coins already on their way to it. A full purse takes nothing.
static func fitting(amount: int, room: int, pending: int) -> int:
	return clampi(room - pending, 0, amount)


## fitting for the live save; `refused` fires at `origin` when some of it is lost.
func _fit(amount: int, origin: Vector3) -> int:
	var fits := fitting(amount, SaveManager.save.room(&"coins"), pending_value())
	if fits < amount:
		refused.emit(origin)
	return fits


func _deposit_now(value: int) -> void:
	bank(SaveManager.save, value)
	deposited.emit(deposit.global_position if deposit != null else global_position)


func _top(cell: Vector2i) -> float:
	var top := desk_height
	for coin: Coin in _stacks.get(cell, []):
		top += thickness(coin.value, _open)
	return top


static func thickness(value: int, coins := OLD_COINS) -> float:
	return THICKNESS * SCALES[tier(value, coins)].y


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
			xf.basis = xf.basis * Basis.from_scale(SCALES[tier(_coins[i].value, _open)])
		if _coins[i].state == State.FLYING and _coins[i].pop > 0.0:
			xf.basis = xf.basis * Basis.from_scale(Vector3.ONE * pop_scale(_coins[i].pop))
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
		var colour := coin_colour(_coins[i].value, _open)
		_buffer[o + 12] = colour.r
		_buffer[o + 13] = colour.g
		_buffer[o + 14] = colour.b
		_buffer[o + 15] = 1.0
		_buffer[o + 16] = coin_face(_coins[i].value, _open)
	multimesh.buffer = _buffer
	multimesh.visible_instance_count = _coins.size()


## Which face of the coin atlas (assets/shaders/coin.gdshader) the coin shows.
static func coin_face(value: int, coins := OLD_COINS) -> float:
	return float(tier(value, coins))


static func coin_colour(value: int, coins := OLD_COINS) -> Color:
	return COLOURS[tier(value, coins)]


## The biggest of the first `coins` DENOMINATIONS `value` reaches (its index): before CRITICAL_MASS_CARD
## $50K+ coins show as $10K, after it $10B+ ones as $1B.
static func tier(value: int, coins := OLD_COINS) -> int:
	for i in range(coins - 1, 0, -1):
		if value >= DENOMINATIONS[i]:
			return i
	return 0


static func cell_of(point: Vector3) -> Vector2i:
	return Vector2i(floori(point.x / CELL), floori(point.z / CELL))


static func cell_centre(cell: Vector2i) -> Vector2:
	return (Vector2(cell) + Vector2(0.5, 0.5)) * CELL


## The fewest coins, largest first ($100, $50, $10, $5, $1), thrown smallest first so the biggest
## end up on top of the stack where the camera sees them. A big amount, one that would take more than
## MAX_THROW of the top coin, brings in the next coin up ($500, $1K, $5K, $10K), and past $10K coins
## worth ten times more (drawn as $10K; with CRITICAL_MASS_CARD $50K .. $1B, then times ten drawn as
## $1B), and again, so one payout never throws much more than
## MAX_THROW coins and a big one still comes as a handful, not one lonely coin.
## Only the first `coins` of DENOMINATIONS are used before the times-ten steps (coins_open).
static func coin_values(amount: int, coins := OLD_COINS) -> Array[int]:
	var denominations := DENOMINATIONS.slice(0, CHANGE)
	@warning_ignore("integer_division")
	while amount / denominations[-1] > MAX_THROW:
		var up := denominations.size()
		denominations.append(DENOMINATIONS[up] if up < coins else denominations[-1] * 10)
	var counts: Array[int] = []
	for i in range(denominations.size() - 1, -1, -1):
		@warning_ignore("integer_division")
		var count := maxi(amount / denominations[i], 0)
		counts.push_front(count)
		amount -= count * denominations[i]
	var out: Array[int] = []
	for i in denominations.size():
		for n in counts[i]:
			out.append(denominations[i])
	return out


## The grid cells of pile_area.
func _pile_cells() -> Rect2i:
	return cells_in(pile_area.position, pile_area.end)


## The grid cells from the one holding `from` to the one holding `to` (desk points).
static func cells_in(from: Vector3, to: Vector3) -> Rect2i:
	return Rect2i(cell_of(from), cell_of(to) - cell_of(from) + Vector2i.ONE)


## The tallest a pile may stand over the desk (m): MAX_STACK of the thickest coin. The hand takes a
## whole stack wherever it shows (under_hand), and this high it shows on screen all over pile_area.
static func reach_height() -> float:
	return MAX_STACK * THICKNESS * SCALES[-1].y


## Where a coin aimed at `cell` lands: on that stack while it is under `max_height`, else on the
## nearest stack around it with room (a random one of those, so overflow looks loose). With an
## `area` (cells) the stacks beside it must lie in there, and it looks as far as the area goes. No
## coin lands in `closed`, not even on the cell it aimed at.
static func stack_cell(stacks: Dictionary, cell: Vector2i, max_height: int, area := Rect2i(), closed := Rect2i()) -> Vector2i:
	# ponytail: whole squares walked ring by ring; only far when a big patch is full. Walk the ring's
	# edge alone if a profile ever shows it.
	for ring in (64 if area.has_area() else 8):
		var free: Array[Vector2i] = []
		for dx in range(-ring, ring + 1):
			for dz in range(-ring, ring + 1):
				var near := cell + Vector2i(dx, dz)
				if maxi(absi(dx), absi(dz)) == ring and stacks.get(near, []).size() < max_height \
						and (ring == 0 or not area.has_area() or area.has_point(near)) and not closed.has_point(near):
					free.append(near)
		if not free.is_empty():
			return free.pick_random()
	return cell
