shader_type spatial;
// The first-stamp hint's ghost form on the press pad (entities/upgrade_desk/): a dashed outline the size
// of a form, as if printed on the blotter in pale ink, with a faint printed field inside. The dashes
// march around the outline and the ink breathes slowly (TIME: nothing runs in script, nothing at all
// while the mesh is hidden). `draw` (0-1) draws the outline on around the form and `flash` brightens
// it: UpgradeDesk tweens both once each time the ghost appears.
render_mode blend_mix, depth_draw_never, cull_disabled, specular_disabled;

uniform vec4 ink : source_color = vec4(0.92, 0.91, 0.86, 1.0);
uniform float fill = 0.08;
// The plane's size and the line's width, inset from the edge and dash period (metres).
uniform vec2 size = vec2(0.36, 0.2);
uniform float line = 0.006;
uniform float inset = 0.004;
uniform float dash = 0.024;
// March speed (m/s) and the slow pulse: brightness between 1 - pulse and 1, PULSE_RATE rad/s.
uniform float speed = 0.05;
uniform float pulse = 0.3;
uniform float pulse_rate = 3.0;
// Self-lit share of the ink, so it reads in the desk's dark corner (pale grey, never coloured).
uniform float lit = 0.35;
uniform float draw = 1.0;
uniform float flash = 0.0;

void fragment() {
	vec2 p = UV * size;
	vec2 edge = min(p, size - p) - inset;
	float near = min(edge.x, edge.y);
	float aa = fwidth(near);
	float on_line = smoothstep(-aa, 0.0, near) * (1.0 - smoothstep(line, line + aa, near));
	// Where along the outline, clockwise from the first corner (metres, 0 to the perimeter).
	float w = size.x;
	float h = size.y;
	float s;
	if (edge.y <= edge.x) {
		s = p.y < h * 0.5 ? p.x : w + h + (w - p.x);
	} else {
		s = p.x > w * 0.5 ? w + p.y : 2.0 * w + h + (h - p.y);
	}
	float perimeter = 2.0 * (w + h);
	float period = perimeter / round(perimeter / dash);  // A whole number of dashes: no seam.
	float t = (s - TIME * speed) / period;
	float d = abs(fract(t) - 0.5);
	float dashed = smoothstep(0.25 - fwidth(t), 0.25, d);
	float drawn = step(s / perimeter, draw);
	float inside = step(0.0, near);
	float breathe = 1.0 - pulse * (0.5 + 0.5 * sin(TIME * pulse_rate));
	float glow = breathe + flash;
	ALBEDO = ink.rgb;
	EMISSION = ink.rgb * lit * glow * on_line;
	ROUGHNESS = 1.0;
	ALPHA = clamp(ink.a * max(on_line * dashed * drawn * min(glow, 1.0), fill * inside * draw), 0.0, 1.0);
}
