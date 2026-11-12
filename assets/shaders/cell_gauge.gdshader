shader_type spatial;
render_mode unshaded;
// A row of indicator cells behind a window: `cells` of them across U, the first `filled` lit.
// Per instance, so one material serves every gauge.
instance uniform float filled = 0.0;
instance uniform float cells = 1.0;
uniform vec3 lit : source_color = vec3(0.35, 0.9, 1.0);
uniform vec3 unlit : source_color = vec3(0.1, 0.24, 0.26);
uniform vec3 gap_colour : source_color = vec3(0.0, 0.0, 0.0);
// Half the gap between two cells, as a share of the whole row.
uniform float gap = 0.04;

void fragment() {
	float at = UV.x * cells;
	float edge = gap * cells;
	float inside = step(edge, fract(at)) * step(fract(at), 1.0 - edge) * step(0.08, UV.y) * step(UV.y, 0.92);
	// A lit cell is a little brighter along its middle, like a tube lamp behind the glass.
	vec3 cell = floor(at) < filled ? lit * (0.9 + 0.4 * sin(UV.y * PI)) : unlit;
	ALBEDO = mix(gap_colour, cell, inside);
}
