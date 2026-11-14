shader_type spatial;
render_mode cull_disabled;
// A paper map sheet that rolls itself up (entities/map_table/map_sheet.tscn). The mesh is a flat,
// finely cut plane lying in XZ with its top edge at z = 0 and the paper running to z = sheet_length. The
// part beyond the roll line (z > open * sheet_length) is wound round a roll that sits on the desk at the
// roll line: a spiral whose turns lie `pitch` apart round a core of radius `core`, so the roll grows
// thicker as it takes up paper. The printed face ends up inside; the outside shows the plain back.
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
	}
}

void fragment() {
	ALBEDO = FRONT_FACING ? texture(sheet_tex, UV).rgb : back_color;
	ROUGHNESS = 0.92;
	SPECULAR = 0.1;
}
