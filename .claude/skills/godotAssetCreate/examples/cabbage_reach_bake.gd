extends SceneTree
# Bakes how far each cabbage mesh reaches in every direction, for the paper belt's shader
# (assets/shaders/cabbage_belt.gdshader): one 128 x 64 equirect per mesh (cabbage_a/b/c stacked
# top to bottom), longitude atan(z, x) across, latitude from +Y down. A texel is the farthest leaf
# surface within SPREAD of any direction inside it (dilated, so the shader's sparse samples can't
# miss a leaf tip between them, and its bilinear read never blends one away), as a fraction of REACH,
# rounded up. Past that a leaf still counts, fading to SOFT_FLOOR of its reach over SOFT more: the
# table has no cliffs, so the paper laid over it bends smoothly instead of stepping.
# Run: godot --headless --path <project> -s <this> -- <out png>
const MESHES := ["a", "b", "c"]
const W := 128
const H := 64
## Must match the shader's REACH.
const REACH := 0.11
const SPREAD := deg_to_rad(3.5)
## Half a texel's diagonal at the equator: a direction anywhere in a texel is this close to its centre.
const HALF_CELL := deg_to_rad(2.0)
const SOFT := deg_to_rad(6.0)
const SOFT_FLOOR := 0.85


func _initialize() -> void:
	var out := OS.get_cmdline_user_args()[0]
	var image := Image.create(W, H * MESHES.size(), false, Image.FORMAT_L8)
	for m in MESHES.size():
		var mesh: Mesh = load("res://assets/meshes/Props/cabbage_%s.res" % MESHES[m])
		var points := PackedVector3Array()
		var faces := mesh.get_faces()
		for t in range(0, faces.size(), 3):
			var a := faces[t]
			var b := faces[t + 1]
			var c := faces[t + 2]
			points.append_array([a, b, c, (a + b) * 0.5, (b + c) * 0.5, (c + a) * 0.5, (a + b + c) / 3.0])
		var grid := PackedFloat32Array()
		grid.resize(W * H)
		var full := SPREAD + HALF_CELL
		var reach := full + SOFT
		var cos_reach := cos(reach)
		var top := 0.0
		for p in points:
			var r := p.length()
			top = maxf(top, r)
			var d := p / r
			var lat := acos(clampf(d.y, -1.0, 1.0))
			var y0 := maxi(int(floor((lat - reach) / PI * H)), 0)
			var y1 := mini(int(floor((lat + reach) / PI * H)), H - 1)
			for y in range(y0, y1 + 1):
				var lat_c := (y + 0.5) / H * PI
				for x in W:
					var lon_c := ((x + 0.5) / W - 0.5) * TAU
					var c := Vector3(sin(lat_c) * cos(lon_c), cos(lat_c), sin(lat_c) * sin(lon_c))
					var dot := c.dot(d)
					if dot >= cos_reach:
						var fade := 1.0 - (1.0 - SOFT_FLOOR) * smoothstep(full, reach, acos(minf(dot, 1.0)))
						grid[y * W + x] = maxf(grid[y * W + x], r * fade)
		for y in H:
			for x in W:
				image.set_pixel(x, m * H + y, _grey(grid[y * W + x]))
		print("cabbage_%s: %d points, farthest %.4f" % [MESHES[m], points.size(), top])
	image.save_png(out)
	quit()


static func _grey(reach: float) -> Color:
	var v := mini(ceili(reach / REACH * 255.0), 255)
	return Color8(v, v, v)
