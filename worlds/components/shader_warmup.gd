class_name ShaderWarmup
extends Node3D
## Shader warm-up: a small cluster of everything that first appears mid-game (every cabbage look on
## every cabbage mesh incl. the research one under its cyan omni light, the coin MultiMesh, the
## Findings token, the lab's scan glow and jewels, the CRT glass and TV static, card paper and text,
## the associate's sleeve, the particle looks, every shared material), all in shader_warmup.tscn.
## For its first FRAMES frames it hangs in the bottom-left corner of the game camera's view, really
## drawn (lit, casting shadows), so their pipelines compile at boot instead of hitching later; then
## it frees itself. No bodies, nothing saved or logged.

const FRAMES := 4
## Where it hangs in view: this far in front of the camera, at this share of the half-width and
## half-height toward the bottom-left corner.
const DISTANCE := 0.6
const CORNER := Vector2(-0.85, -0.75)
## The cluster is laid out at a readable size in the .tscn and shrunk to this in view.
const SHRINK := 0.2

var _left := FRAMES


func _ready() -> void:
	_follow_camera()


func _process(_delta: float) -> void:
	_left -= 1
	if _left <= 0:
		queue_free()
		return
	_follow_camera()


## Keeps it in the camera's bottom-left corner (the camera may still be framing itself).
func _follow_camera() -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	var half_h := DISTANCE * tan(deg_to_rad(camera.fov) / 2.0)
	var half_w := half_h * get_viewport().get_visible_rect().size.aspect()
	global_transform = camera.global_transform * Transform3D(Basis.from_scale(Vector3.ONE * SHRINK), Vector3(CORNER.x * half_w, CORNER.y * half_h, -DISTANCE))
