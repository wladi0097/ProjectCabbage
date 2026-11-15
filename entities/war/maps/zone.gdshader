shader_type spatial;
// A deployment zone printed on the war paper: diagonal hatching in world space (so every zone's lines
// run on, whatever its size) inside a thick outline in the toy soldiers' green (army_plastic's vertex
// colour, linear) along every edge, where the placeable squares end. `glow` (per zone, WarSheet)
// lifts it while a figure is held.
render_mode blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

uniform vec3 ink : source_color = vec3(0.24, 0.32, 0.38);
uniform vec3 ours = vec3(0.114, 0.345, 0.016);
uniform vec3 lit : source_color = vec3(0.92, 0.95, 0.93);
uniform float period = 0.03;
uniform float line = 0.28;
// The outline's width (m: one fine grid step), inside the zone from its edge (the grid's heavy line);
// `cell` is the mesh's own size (WarMap.CELL): the zone is scaled in cells.
uniform float outline = 0.016;
uniform float cell = 0.16;
instance uniform float glow = 0.0;

varying vec3 world;

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float d = fract((world.x + world.z) / period);
	float stripe = step(1.0 - line, abs(d - 0.5) * 2.0);
	vec2 size = vec2(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[2].xyz)) * cell;
	vec2 edge = min(UV, 1.0 - UV) * size;
	float band = 1.0 - step(outline, min(edge.x, edge.y));
	vec3 hatch = mix(ink, lit, glow * 0.6);
	ALBEDO = mix(hatch, ours * (1.0 + glow * 0.5), band);
	EMISSION = mix(lit * glow * 0.35, ours * 0.25, band);
	ALPHA = band > 0.5 ? 1.0 : clamp(stripe * 0.42 + glow * 0.18, 0.0, 1.0);
	ROUGHNESS = 1.0;
}
