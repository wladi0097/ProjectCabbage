class_name Manager
extends Node3D
## The manager drops by (desk card "managerial_oversight"): every few minutes his shadow falls in
## through the window across the top of the mat, he raps on the glass, and a speech bubble at the
## top edge asks for a unit quota in save.manager_time seconds, with a countdown and the units moved
## since. The quota is what was sold in the last QUOTA_WINDOW seconds, scaled to the time given and
## raised by save.manager_raise. Met: the street throws a bonus of quota × price × manager_reward
## coins in through the window. Missed: a performance concern memo, nothing else. Nothing about a
## visit is saved; quitting mid-quota just ends it.

enum Phase { AWAY, ARRIVING, QUOTA, VERDICT, LEAVING }

const CARD := "managerial_oversight"
## Seconds before the first visit: just after the card is stamped CARD_VISIT, after a load
## FIRST_VISIT; then between visits (min..max).
const CARD_VISIT := 5.0
const FIRST_VISIT := 60.0
const VISIT_EVERY := Vector2(150.0, 240.0)
## Sales are sampled every SAMPLE_EVERY seconds; the quota looks back QUOTA_WINDOW seconds.
const SAMPLE_EVERY := 5.0
const QUOTA_WINDOW := 300.0
const MIN_QUOTA := 3
const ARRIVE_TIME := 1.4
const LEAVE_TIME := 1.2
const VERDICT_TIME := 3.0
## The last TICK_FROM seconds of a quota tick once a second.
const TICK_FROM := 5
## The shadow: where it rests (world), how far back toward the street it starts, how dark it gets.
const SHADOW_REST := Vector3(1.05, 0.9, -0.32)
const SHADOW_BACK := 1.4
const SHADOW_ALPHA := 0.95
## Where the bonus coins come up from, hidden below the sill outside (the sale window's throw_from).
const COINS_FROM := Vector3(1.05, 0.42, -1.12)

const ASKS := ["I'll need %d units in the next %d seconds.", "Head office wants %d units. You have %d seconds.",
		"%d units. %d seconds. I'll wait.", "Let's see %d units before %d seconds are up."]
const PRAISE := ["Acceptable.", "That will do.", "Noted. Carry on."]
const SCORN := ["I see.", "Disappointing.", "We'll talk."]

@export var coins: CoinPile
## The milestone memo layer (entities/milestone/), which also posts the performance concern.
@export var memo: Node

var phase := Phase.AWAY
var quota := 0
var sold_at := 0
var left := 0.0
var line := ""
var met := false
var bonus := 0
var _wait := FIRST_VISIT
var _t := 0.0
var _sample_clock := 0.0
var _samples := PackedInt32Array()
var _ticked := 0

@onready var _shadow: Decal = $Shadow
@onready var _bubble: ManagerBubble = $Bubble/Speech


func _ready() -> void:
	_shadow.visible = false
	_bubble.manager = self
	_wait = first_wait(SaveManager.save.stamped.has(CARD))


func _process(delta: float) -> void:
	var save := SaveManager.save
	if not save.stamped.has(CARD):
		return
	# Sampling starts once the card is stamped, so sales from before it don't raise the first quota.
	if _samples.is_empty():
		_samples.append(save.sold)
	_sample_clock += delta
	if _sample_clock >= SAMPLE_EVERY:
		_sample_clock -= SAMPLE_EVERY
		_samples.append(save.sold)
		if _samples.size() > QUOTA_WINDOW / SAMPLE_EVERY + 1:
			_samples.remove_at(0)
	_t += delta
	match phase:
		Phase.AWAY:
			_wait -= delta
			if _wait <= 0.0:
				_arrive(save)
		Phase.ARRIVING:
			_pose_shadow(ease(minf(_t / ARRIVE_TIME, 1.0), -2.0))
			if _t >= ARRIVE_TIME:
				_t = 0.0
				phase = Phase.QUOTA
				_bubble.pop()
		Phase.QUOTA:
			_pose_shadow(1.0)
			left = maxf(save.manager_time - _t, 0.0)
			if save.sold - sold_at >= quota:
				_verdict(save, true)
			elif left <= 0.0:
				_verdict(save, false)
			elif ceili(left) <= TICK_FROM and ceili(left) != _ticked:
				_ticked = ceili(left)
				$Tick.play()
		Phase.VERDICT:
			_pose_shadow(1.0)
			if _t >= VERDICT_TIME:
				_t = 0.0
				phase = Phase.LEAVING
		Phase.LEAVING:
			_pose_shadow(1.0 - ease(minf(_t / LEAVE_TIME, 1.0), 2.0))
			if _t >= LEAVE_TIME:
				_shadow.visible = false
				phase = Phase.AWAY
				_wait = randf_range(VISIT_EVERY.x, VISIT_EVERY.y)


## Units sold in the last stretch of `samples` (save.sold every SAMPLE_EVERY s, oldest first, the
## last one `since` seconds ago), scaled to `time` seconds and raised by `raise`; never below MIN_QUOTA.
static func quota_for(samples: PackedInt32Array, sold: int, time: float, raise: float, since := 0.0) -> int:
	var span := maxf((samples.size() - 1) * SAMPLE_EVERY + since, SAMPLE_EVERY)
	var recent := sold - samples[0] if not samples.is_empty() else 0
	return maxi(MIN_QUOTA, ceili(recent / span * time * raise))


## Seconds to the first visit: FIRST_VISIT when the card was `stamped` before the load, else CARD_VISIT
## (the wait only runs once the card is stamped, so he comes just after it).
static func first_wait(stamped: bool) -> float:
	return FIRST_VISIT if stamped else CARD_VISIT


## The coins thrown in for a met quota of `units` at `price` each.
static func bonus_for(units: int, price: int, reward: float) -> int:
	return maxi(1, ceili(units * price * reward))


func _arrive(save: SaveGame) -> void:
	quota = quota_for(_samples, save.sold, save.manager_time, save.manager_raise, _sample_clock)
	sold_at = save.sold
	left = save.manager_time
	line = tr(ASKS.pick_random()) % [quota, roundi(save.manager_time)]
	_ticked = 0
	_t = 0.0
	phase = Phase.ARRIVING
	_shadow.visible = true
	_pose_shadow(0.0)
	$Knock.play()


func _verdict(save: SaveGame, success: bool) -> void:
	met = success
	_t = 0.0
	phase = Phase.VERDICT
	var moved := save.sold - sold_at
	if success:
		bonus = bonus_for(quota, save.sale_price, save.manager_reward)
		line = tr(PRAISE.pick_random()) + tr(" Bonus: $%d.") % bonus
		save.quotas_met += 1
		SaveManager.log_event("quota_met", "", bonus)
		coins.throw_in_after(0.5, COINS_FROM, bonus)
	else:
		line = tr(SCORN.pick_random())
		save.quotas_missed += 1
		SaveManager.log_event("quota_missed", "", quota)
		memo.post({re = "PERFORMANCE CONCERN", note = tr("A quota of %d units was set. %d were moved.") % [quota, moved],
				bonus = "Nothing. This memo is the consequence."})
	_bubble.pop()


## `shown` 0 (still out in the street) .. 1 (fully in across the mat), with a slow weight shift.
func _pose_shadow(shown: float) -> void:
	var time := Time.get_ticks_msec() / 1000.0
	_shadow.position = SHADOW_REST + Vector3(0.02 * sin(time * 0.6), 0.0, -SHADOW_BACK * (1.0 - shown))
	_shadow.rotation.y = 0.04 * sin(time * 0.45)
	_shadow.modulate.a = SHADOW_ALPHA * shown
