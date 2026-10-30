extends Camera3D
## Keeps the authored 16:9 view fully visible on every screen shape. Wider screens see more
## at the sides (up to 21:9, black bars beyond), narrower screens see more above and below.

const SAFE_ASPECT := 16.0 / 9.0
const MAX_ASPECT := 21.0 / 9.0
const BASE_SIZE := Vector2i(1920, 1080)

@onready var _vertical_fov := fov


func _ready() -> void:
	get_window().size_changed.connect(_reframe)
	_reframe()


static func horizontal_fov(vertical_fov: float, aspect: float) -> float:
	return rad_to_deg(2.0 * atan(tan(deg_to_rad(vertical_fov) / 2.0) * aspect))


func _reframe() -> void:
	var window := get_window()
	if window.size.y == 0:
		return
	var aspect := float(window.size.x) / window.size.y
	var capped := aspect > MAX_ASPECT
	window.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP if capped \
			else Window.CONTENT_SCALE_ASPECT_EXPAND
	window.content_scale_size = Vector2i(roundi(BASE_SIZE.y * MAX_ASPECT), BASE_SIZE.y) if capped \
			else BASE_SIZE
	if aspect >= SAFE_ASPECT:
		keep_aspect = KEEP_HEIGHT
		fov = _vertical_fov
	else:
		keep_aspect = KEEP_WIDTH
		fov = horizontal_fov(_vertical_fov, SAFE_ASPECT)
