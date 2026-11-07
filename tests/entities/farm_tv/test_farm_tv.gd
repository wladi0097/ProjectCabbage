extends Node
## Run: Godot --headless --path . res://tests/entities/farm_tv/test_farm_tv.tscn

var _failed := false


func _ready() -> void:
	var save := SaveGame.new()
	_check(not FarmTv.bought(save), "no remote before the card")
	save.stamped.append("family_farm")
	_check(FarmTv.bought(save), "the card brings the remote")

	var desk := Transform3D(Basis(Vector3.RIGHT, deg_to_rad(-61.0)), Vector3(0.25, 3.2, 1.6))
	var screen := Transform3D(Basis(Vector3.UP, PI / 4.0), Vector3(-2.6, 1.08, 0.2))
	var tv := FarmTv.tv_view(screen)
	_check(-tv.basis.z.y < 0.0 and -tv.basis.z.y > -0.3, "the tv view looks down a little at the glass")
	_check(tv.origin.x < desk.origin.x, "the tv is to the left")
	var depth := (tv.origin - screen.origin).dot(tv.basis.z)
	var seen := 2.0 * FarmTv.SCREEN_HALF.y / (2.0 * depth * tan(deg_to_rad(FarmTv.DESK_FOV) / 2.0))
	_check(seen > 0.5 and seen < 0.7, "the glass fills 50-70 % of the view's height, the room shows round the set")
	_check(FarmTv.view_at(desk, tv, 0.0).is_equal_approx(desk), "pan starts on the desk")
	_check(FarmTv.view_at(desk, tv, 1.0).is_equal_approx(tv), "pan ends on the tv")
	_check(FarmTv.view_at(desk, tv, 2.0).is_equal_approx(tv) and FarmTv.view_at(desk, tv, -1.0).is_equal_approx(desk), "pan clamps")
	var mid := FarmTv.view_at(desk, tv, 0.5).origin.x
	_check(is_equal_approx(mid, (desk.origin.x + tv.origin.x) / 2.0), "half way at the middle")
	_check(absf(FarmTv.view_at(desk, tv, 0.1).origin.x - desk.origin.x) < 0.1 * absf(tv.origin.x - desk.origin.x), "eases in")

	# Rays from the TV view onto the glass.
	var centre := FarmTv.glass_uv(screen, tv.origin, screen.origin - tv.origin)
	_check(centre.is_equal_approx(Vector2(0.5, 0.5)), "a ray at the glass's centre hits uv 0.5")
	_check(FarmTv.glass_uv(screen, tv.origin, -tv.basis.z).x > 0.5, "the view looks right of the glass's centre")
	var top_left := screen * Vector3(-FarmTv.SCREEN_HALF.x, FarmTv.SCREEN_HALF.y, 0.0)
	_check(FarmTv.glass_uv(screen, tv.origin, top_left - tv.origin).is_equal_approx(Vector2.ZERO), "top left corner is uv 0,0")
	_check(FarmTv.on_glass(centre) and not FarmTv.on_glass(Vector2(1.1, 0.5)), "off the glass beyond uv 1")
	_check(FarmTv.glass_uv(screen, tv.origin, tv.basis.x) == Vector2(-1, -1), "a ray along the glass misses")
	var back := Transform3D(screen.basis, screen * (FarmTv.BACK_CENTRE - FarmTv.SCREEN_CENTRE))
	_check(FarmTv.on_glass(FarmTv.rect_uv(back, FarmTv.BACK_HALF, tv.origin, back.origin - tv.origin)), "the back button is hit at its centre")
	_check(not FarmTv.on_glass(FarmTv.rect_uv(back, FarmTv.BACK_HALF, tv.origin, screen.origin - tv.origin)), "the glass is not the back button")
	_check(FarmTv.on_glass(FarmTv.rect_uv(back, FarmTv.BACK_HALF, tv.origin, -tv.basis.z)) == false, "the view's centre is not on the button")
	_check(FarmTv.screen_pixel(Vector2(0.5, 0.5)).is_equal_approx(FarmTv.SCREEN_PIXELS / 2.0), "centre pixel stays")
	var edge := FarmTv.screen_pixel(Vector2(1.0, 0.5))
	_check(is_equal_approx(edge.x, FarmTv.SCREEN_PIXELS.x) and is_equal_approx(edge.y, FarmTv.SCREEN_PIXELS.y / 2.0), "mid edges are not warped")
	_check(FarmTv.screen_pixel(Vector2(1.0, 1.0)).x > FarmTv.SCREEN_PIXELS.x, "corners warp outwards like the shader")
	print("farm tv tests failed" if _failed else "farm tv tests passed")
	get_tree().quit(1 if _failed else 0)


func _check(ok: bool, message := "check failed") -> void:
	if not ok:
		_failed = true
		push_error(message)
