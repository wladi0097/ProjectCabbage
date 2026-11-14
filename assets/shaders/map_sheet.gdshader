shader_type spatial;
render_mode cull_disabled;
// A paper map sheet that rolls itself up (entities/map_table/map_sheet.tscn). The mesh is a flat,
// finely cut plane lying in XZ with its top edge at z = 0 and the paper running to z = sheet_length. The
// part beyond the roll line (z > open * sheet_length) is wound round a roll that sits on the desk at the
// roll line: a spiral whose turns lie `pitch` apart round a core of radius `core`, so the roll grows
// thicker as it takes up paper. The printed face ends up inside; the outside shows the plain back:
// paper grain (grain_tex, grain_normal: a tile of `grain_tile` m), the print faintly showing through
// and a little darker towards the roll's ends.
// MapSheet.roll_radius is the same formula for the script.

uniform sampler2D sheet_tex : source_color, filter_linear, repeat_disable;
// 1 lies flat, 0 is all rolled up at the top edge.
uniform float open = 1.0;
uniform float sheet_length = 1.8;
uniform float core = 0.03;
uniform float pitch = 0.008;
// Paper memory: the free edge stands up this much (0..1) once unrolled, until the weights pin it.
uniform float lift = 0.0;
uniform float lift_height = 0.07;
uniform float lift_reach = 0.45;
uniform vec3 back_color : source_color = vec3(0.55, 0.56, 0.52);
uniform sampler2D grain_tex : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform sampler2D grain_normal : hint_normal, filter_linear_mipmap, repeat_enable;
uniform float sheet_width = 3.2;
uniform float grain_tile = 0.2;
uniform float grain_strength = 0.24;
// Large, soft unevenness of the paper's tone.
uniform float mottle = 0.1;
uniform float grain_depth = 1.0;
// How much of the print shows through the back (0..1), and how much darker the roll's ends are.
uniform float show_through = 0.12;
uniform float end_shade = 0.3;

void vertex() {
	float line = clamp(open, 0.0, 1.0) * sheet_length;
	float c = pitch / PI;
	float outer_sq = core * core + c * (sheet_length - line);
	float outer = sqrt(outer_sq);
	float s = VERTEX.z - line;
	float edge = smoothstep(sheet_length - lift_reach, sheet_length, VERTEX.z);
	VERTEX.y += lift * lift_height * edge * edge;
	if (s > 0.0) {
		float radius = sqrt(max(outer_sq - c * s, core * core));
		float angle = 2.0 * (outer - radius) / c;
		VERTEX.z = line + radius * sin(angle);
		VERTEX.y = outer - radius * cos(angle);
		NORMAL = vec3(0.0, cos(angle), -sin(angle));
		BINORMAL = vec3(0.0, sin(angle), cos(angle));
	}
}

void fragment() {
	vec3 print = texture(sheet_tex, UV).rgb;
	if (FRONT_FACING) {
		ALBEDO = print;
		ROUGHNESS = 0.92;
	} else {
		vec2 paper = UV * vec2(sheet_width, sheet_length) / grain_tile;
		float grain = texture(grain_tex, paper).r - 0.5 + 0.6 * (texture(grain_tex, paper * 5.3 + 0.37).r - 0.5);
		float cloud = texture(grain_tex, paper * 0.13 + 0.71).r - 0.5;
		float ink = 1.0 - dot(print, vec3(0.299, 0.587, 0.114));
		float end = min(UV.x, 1.0 - UV.x) * sheet_width;
		ALBEDO = back_color * (1.0 + grain_strength * grain + mottle * cloud) * (1.0 - show_through * ink)
				* (1.0 - end_shade * (1.0 - smoothstep(0.0, 0.06, end)));
		ROUGHNESS = 0.9 + 0.08 * grain;
		NORMAL_MAP = texture(grain_normal, paper * 2.0).rgb;
		NORMAL_MAP_DEPTH = grain_depth;
	}
	SPECULAR = 0.1;
}
