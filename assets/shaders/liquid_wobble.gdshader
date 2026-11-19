shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled;
// Liquid in a glass cylinder (the cabbage gun's canister), no simulation: the mesh is the full
// cylinder, cut off above a fill plane whose normal is `level` (world space; the script keeps it
// upright and springs it from the canister's motion). Front faces below the plane are the liquid seen
// through the glass wall; back faces draw the flat top surface, only where the view ray really
// crosses the plane inside the cylinder. One draw, no screen texture.

// The cylinder in the mesh's own space: axis along Y through `centre`.
uniform vec3 centre = vec3(0.0, 0.165, -0.035);
uniform float radius = 0.058;
// Height of the surface over the centre, and the way it faces (world space).
uniform float fill = 0.04;
uniform vec3 level = vec3(0.0, 1.0, 0.0);
uniform vec4 body : source_color = vec4(0.3, 0.37, 0.3, 0.3);
uniform vec4 surface : source_color = vec4(0.5, 0.6, 0.5, 0.55);
// The pale line where the surface meets the glass: its width (mesh units) and colour.
uniform float meniscus = 0.005;
uniform vec4 meniscus_colour : source_color = vec4(0.82, 0.9, 0.84, 0.85);

varying vec3 local;
varying vec3 up;
varying vec3 eye;

void vertex() {
	local = VERTEX - centre;
	up = normalize((vec4(normalize(level), 0.0) * MODEL_MATRIX).xyz);
	eye = (inverse(MODEL_MATRIX) * vec4(CAMERA_POSITION_WORLD, 1.0)).xyz - centre;
}

void fragment() {
	float height = dot(local, up) - fill;
	if (height > 0.0) {
		discard;
	}
	if (FRONT_FACING) {
		float rim = pow(1.0 - abs(dot(NORMAL, VIEW)), 2.0);
		float line = smoothstep(-meniscus, 0.0, height);
		ALBEDO = mix(mix(body.rgb, surface.rgb, rim * 0.5), meniscus_colour.rgb, line);
		ALPHA = mix(mix(body.a, surface.a, rim * 0.4), meniscus_colour.a, line);
	} else {
		vec3 ray = local - eye;
		float along = (fill - dot(eye, up)) / dot(ray, up);
		vec3 hit = eye + ray * along;
		if (along <= 0.0 || along >= 1.0 || length(hit.xz) > radius) {
			discard;
		}
		ALBEDO = surface.rgb;
		ALPHA = surface.a;
	}
}
